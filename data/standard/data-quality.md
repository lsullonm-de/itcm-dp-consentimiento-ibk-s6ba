# Estándar: Framework de Calidad del Dato — ITC Data Platform

> **Última actualización:** 2026-03-26
> **Etapa en la fábrica:** DATA QUALITY — complementaria a CODING
> **Plataforma:** BigQuery + Cloud Workflows + Pub/Sub (GCP)
>
> **Referencias de contexto (no duplicadas aquí):**
> - Dimensiones, tipos de reglas, roles DQ → `@.claude/data/skills/design/intercorp-data-enablement/SKILL.md`
> - Campos `dq_flag_ind`, `dq_control_msg`, `dq_config_id` en tablas destino → `@.claude/data/standard/architecture/data-platform-layers.md`
> - Naming de datasets `dq_` → `@.claude/data/standard/architecture/data-platform-layers.md`

---

## 1. Rol de la Etapa DATA QUALITY en la Fábrica

La etapa DATA QUALITY se ejecuta **después de CODING y en paralelo a COMPLIANCE**. Su objetivo es construir todos los componentes necesarios para medir, registrar y alertar sobre la calidad del dato producido por el proceso.

```
CODING → DATA QUALITY → DATAOPS (despliega todo junto)
                    ↓
         construye: reglas DQ + SP DQ + config DQ + alertas
```

**No se despliega a producción un proceso sin su capa DQ definida.**

### Qué se entrega en esta etapa

| Artefacto | Descripción |
|---|---|
| `dq_spec.md` | Especificación funcional de cada regla: dimensión, criticidad, umbral, columna, lógica |
| DDL `dq_config` | Registros de configuración de reglas en la tabla de control DQ |
| SP DQ | Stored Procedures que ejecutan las validaciones y escriben resultados en `dq_control` |
| Campos DQ en tabla destino | `dq_flag_ind`, `dq_control_msg`, `dq_config_id` (si aplica a nivel fila) |
| Paso DQ en Workflow | Llamada al SP DQ después del paso de carga en el workflow principal |
| Alerta Pub/Sub | Notificación cuando el cumplimiento cae por debajo del umbral crítico |

---

## 2. Modelo de Datos DQ en BigQuery

### Dataset

```
dq_[empresa o dominio]
```

Ejemplos: `dq_itc`, `dq_farmas`, `dq_retail`

### Tablas del modelo DQ

#### `dq_config` — Registro de reglas definidas

```sql
CREATE TABLE IF NOT EXISTS `{project}`.`{dataset_dq}`.`dq_config`
(
  dq_config_id        STRING NOT NULL,   -- ID único: DQ-[EMPRESA]-[TABLA]-[NNN]
  rule_name           STRING NOT NULL,   -- Nombre corto de la regla
  rule_description    STRING,            -- Descripción funcional
  dq_dimension        STRING NOT NULL,   -- completitud | conformidad | consistencia
                                         -- precision | duplicidad | integridad
  rule_type           STRING NOT NULL,   -- technical | business
  criticality         STRING NOT NULL,   -- critical | high | medium | low
  target_table        STRING NOT NULL,   -- proyecto.dataset.tabla evaluada
  target_column       STRING,            -- Columna específica (null si es a nivel tabla)
  sql_rule            STRING NOT NULL,   -- Query que retorna filas INVÁLIDAS
  threshold_pct       FLOAT64 NOT NULL,  -- Umbral mínimo de cumplimiento (0-100)
  alert_enabled       BOOL DEFAULT TRUE, -- Activar alerta Pub/Sub si se incumple
  is_active           BOOL DEFAULT TRUE,
  created_date        DATE,
  created_user        STRING
)
PARTITION BY created_date;
```

#### `dq_control` — Resultados de ejecución por regla

```sql
CREATE TABLE IF NOT EXISTS `{project}`.`{dataset_dq}`.`dq_control`
(
  dq_control_id       STRING NOT NULL,   -- UUID de la ejecución
  dq_config_id        STRING NOT NULL,   -- FK → dq_config.dq_config_id
  execution_date      DATE NOT NULL,     -- Fecha de ejecución (partición)
  process_date        DATE,              -- Fecha del proceso evaluado
  total_records       INT64,             -- Total de registros analizados
  valid_records       INT64,             -- Registros que cumplen la regla
  invalid_records     INT64,             -- Registros que NO cumplen la regla
  pct_compliance      FLOAT64,           -- valid_records / total_records * 100
  dq_status           STRING,            -- pass | warn | fail
  execution_seconds   INT64,
  error_message       STRING             -- Si el SP falló al ejecutar
)
PARTITION BY execution_date;
```

### Convención del `dq_config_id`

```
DQ-[EMPRESA]-[TABLA_DESTINO]-[NNN]
```

| Parte | Descripción | Ejemplo |
|---|---|---|
| `EMPRESA` | Abreviatura de empresa o dominio | `ITC`, `FAR`, `SPSA` |
| `TABLA_DESTINO` | Nombre corto de la tabla evaluada | `ATTR_RETAIL`, `T_PAYMENT` |
| `NNN` | Número secuencial de 3 dígitos | `001`, `002` |

**Ejemplos:** `DQ-ITC-ATTR_RETAIL-001`, `DQ-FAR-T_PAYMENT-003`

---

## 3. Convención del `sql_rule`

El campo `sql_rule` en `dq_config` debe contener una **query que retorna las filas inválidas**. El SP DQ cuenta esas filas para calcular `invalid_records`.

```sql
-- CORRECTO: retorna filas que NO cumplen la regla
-- Regla: id no puede ser nulo
SELECT id
FROM `{project_analytics}.{dataset_analytics}.{table_ba_itc_attr_retail}`
WHERE process_date = '{process_date}'
  AND id IS NULL

-- CORRECTO: retorna duplicados por clave primaria
SELECT id, COUNT(*) as cnt
FROM `{project_analytics}.{dataset_analytics}.{table_ba_itc_attr_retail}`
WHERE process_date = '{process_date}'
GROUP BY id
HAVING COUNT(*) > 1
```

> El SP DQ reemplaza `{process_date}` con la variable de ejecución antes de ejecutar la query.

---

## 4. SP DQ — Estructura del Stored Procedure

Cada tabla destino tiene un SP DQ dedicado: `sp_dq_[tabla_destino].sql`

```sql
-- sp_dq_ba_itc_attr_retail.sql
CREATE OR REPLACE PROCEDURE `${dataset_sp}`.sp_dq_ba_itc_attr_retail(
  v_project         STRING,
  v_dataset_dq      STRING,
  v_dataset_sp      STRING,
  v_project_analytics STRING,
  v_dataset_analytics STRING,
  v_table_destino   STRING,
  v_process_date    DATE
)
BEGIN

  DECLARE v_dq_config_id  STRING;
  DECLARE v_sql_rule      STRING;
  DECLARE v_total         INT64;
  DECLARE v_invalidos     INT64;
  DECLARE v_pct           FLOAT64;
  DECLARE v_status        STRING;
  DECLARE v_threshold     FLOAT64;

  -- Iterar sobre reglas activas para esta tabla
  FOR rule IN (
    SELECT dq_config_id, sql_rule, threshold_pct, criticality
    FROM `{v_project}.{v_dataset_dq}.dq_config`
    WHERE target_table = CONCAT(v_project_analytics, '.', v_dataset_analytics, '.', v_table_destino)
      AND is_active = TRUE
  )
  DO

    -- Reemplazar process_date en la query
    SET v_sql_rule = REPLACE(rule.sql_rule, '{process_date}', CAST(v_process_date AS STRING));

    -- Contar registros inválidos
    EXECUTE IMMEDIATE CONCAT(
      'SELECT COUNT(*) FROM (', v_sql_rule, ')'
    ) INTO v_invalidos;

    -- Contar total de registros en el proceso
    EXECUTE IMMEDIATE CONCAT(
      'SELECT COUNT(*) FROM `', v_project_analytics, '.', v_dataset_analytics, '.', v_table_destino,
      '` WHERE process_date = ''', CAST(v_process_date AS STRING), ''''
    ) INTO v_total;

    -- Calcular cumplimiento
    SET v_pct = IF(v_total = 0, 100.0, ROUND((v_total - v_invalidos) / v_total * 100, 2));

    -- Determinar status
    SET v_status = CASE
      WHEN v_pct >= rule.threshold_pct THEN 'pass'
      WHEN v_pct >= rule.threshold_pct - 5 THEN 'warn'
      ELSE 'fail'
    END;

    -- Insertar resultado en dq_control
    INSERT INTO `{v_project}.{v_dataset_dq}.dq_control`
      (dq_control_id, dq_config_id, execution_date, process_date,
       total_records, valid_records, invalid_records, pct_compliance, dq_status)
    VALUES
      (GENERATE_UUID(), rule.dq_config_id, CURRENT_DATE(), v_process_date,
       v_total, v_total - v_invalidos, v_invalidos, v_pct, v_status);

  END FOR;

END;
```

---

## 5. Integración en el Workflow

El paso DQ se agrega **después del paso de carga principal** y **antes de la notificación de éxito**:

```yaml
# Fragmento del workflow YAML
- ejecutar_carga:
    call: SyncBigQueryJob
    args:
      query: ${sp_ba_itc_attr_retail}

- ejecutar_dq:
    call: SyncBigQueryJob
    args:
      query: ${"CALL `" + dataset_sp + "`.sp_dq_ba_itc_attr_retail('" +
              project_analytics + "','" + dataset_dq + "','" +
              dataset_sp + "','" + project_analytics + "','" +
              dataset_analytics + "','" + table_destino + "'," +
              "CURRENT_DATE())"}

- validar_dq:
    call: SyncBigQueryJob
    args:
      query: ${
        "SELECT COUNT(*) as fails FROM `" + project_analytics + "." +
        dataset_dq + ".dq_control` " +
        "WHERE execution_date = CURRENT_DATE() " +
        "AND dq_status = 'fail' AND criticality = 'critical'"
      }
    result: dq_fails

- alertar_si_falla:
    switch:
      - condition: ${dq_fails > 0}
        next: publicar_alerta_dq

- publicar_alerta_dq:
    call: http.post
    args:
      url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
      body:
        messages:
          - data: ${base64.encode(json.encode({
              "to": mail_recipients,
              "subject": "[DQ FAIL] Proceso con reglas críticas incumplidas",
              "body": "Se detectaron reglas DQ críticas con status FAIL. Revisar tabla dq_control."
            }))}
```

---

## 6. Campos DQ en la Tabla Destino (nivel fila)

Para reglas que aplican a nivel de **fila individual** (no a nivel tabla), agregar los campos DQ directamente en la tabla destino. Ver convención completa en `@.claude/data/standard/architecture/data-platform-layers.md`.

| Campo | Tipo | Descripción |
|---|---|---|
| `dq_flag_ind` | `INT64` | `0` = registro válido, `1` = registro con observaciones |
| `dq_control_msg` | `STRING` | Mensaje descriptivo de la regla incumplida |
| `dq_config_id` | `STRING` | FK → `dq_config.dq_config_id` de la regla que marcó el registro |

```sql
-- DDL para agregar campos DQ a tabla existente
ALTER TABLE `${project_analytics}.${dataset_analytics}.${table_destino}`
  ADD COLUMN IF NOT EXISTS dq_flag_ind INT64 OPTIONS(description='0=válido, 1=con observaciones DQ'),
  ADD COLUMN IF NOT EXISTS dq_control_msg STRING OPTIONS(description='Mensaje de regla DQ incumplida'),
  ADD COLUMN IF NOT EXISTS dq_config_id STRING OPTIONS(description='ID de regla DQ: DQ-[EMPRESA]-[TABLA]-[NNN]');
```

> Los campos DQ a nivel fila aplican principalmente en capas **Master** y **Business** donde hay lógica de negocio validable por registro. En capa RAW solo aplica el monitoreo a nivel tabla en `dq_control`.

---

## 7. Definición de Reglas — Plantilla `dq_spec.md`

Antes de desarrollar, documentar las reglas en `docs/dq_spec.md` del repositorio:

```markdown
## Especificación DQ — [Nombre del proceso]
**Tabla evaluada:** `proyecto.dataset.tabla`
**Fecha:** YYYY-MM-DD
**Responsable técnico:** [nombre]
**Business Steward:** [nombre]

| dq_config_id | Dimensión | Tipo | Criticidad | Columna | Lógica de validación | Umbral |
|---|---|---|---|---|---|---|
| DQ-ITC-ATTR_RETAIL-001 | Completitud | technical | critical | `id` | `id IS NULL` | 100% |
| DQ-ITC-ATTR_RETAIL-002 | Precisión | technical | high | `far_mto_medicamento_1m` | `far_mto_medicamento_1m < 0` | 99% |
| DQ-ITC-ATTR_RETAIL-003 | Duplicidad | technical | critical | `id` | duplicados por `id` y `process_date` | 100% |
| DQ-ITC-ATTR_RETAIL-004 | Integridad | business | high | `id` | `id` no existe en `iden_itc_party` | 98% |
```

### Niveles de criticidad y umbral recomendado

| Criticidad | Umbral mínimo recomendado | Acción si falla |
|---|---|---|
| `critical` | 100% | Bloquear proceso, alerta inmediata |
| `high` | 99% | Alerta inmediata, proceso continúa |
| `medium` | 95% | Alerta en reporte diario |
| `low` | 85% | Registro en dashboard, sin alerta |

---

## 8. Variables de Despliegue (_DATAOPS_VARIABLES)

Agregar al `deploy_[env].json` las variables del dataset DQ:

```json
{
  "dataset_dq": "dq_itc"
}
```

Referencia en SPs y workflows:
```
${project_analytics}.${dataset_dq}.dq_config
${project_analytics}.${dataset_dq}.dq_control
```

---

## 9. Estructura de Archivos en el Repositorio

```
[repo]/
├── deploy/
│   ├── deploy_dev.json          ← incluye dataset_dq
│   └── deploy_prd.json
│
├── docs/
│   └── dq_spec.md               ← especificación de reglas (OUTPUT etapa DQ)
│
├── data/bigquery/
│   ├── ddl/
│   │   ├── ddl_ba_itc_attr_retail.sql       ← tabla destino (con campos dq_*)
│   │   ├── ddl_dq_config.sql                ← tabla de configuración DQ
│   │   └── ddl_dq_control.sql               ← tabla de resultados DQ
│   ├── sp/
│   │   ├── sp_load_ba_itc_attr_retail.sql   ← carga principal
│   │   └── sp_dq_ba_itc_attr_retail.sql     ← SP de validación DQ
│   └── dml/
│       └── dml_dq_config_inserts.sql        ← INSERT de reglas en dq_config
│
└── pipeline/workflow/
    └── workflow.yaml             ← incluye paso ejecutar_dq + alertar_si_falla
```

---

## 10. Checklist de la Etapa DATA QUALITY

- [ ] `docs/dq_spec.md` redactado con todas las reglas: dimensión, criticidad, umbral, lógica SQL
- [ ] `sql_rule` de cada regla retorna **filas inválidas** (no válidas)
- [ ] DDL `dq_config` y `dq_control` creados en el dataset `dq_[dominio]`
- [ ] DML con `INSERT` de todas las reglas en `dq_config`
- [ ] SP DQ creado: `sp_dq_[tabla_destino].sql`
- [ ] Campos `dq_flag_ind`, `dq_control_msg`, `dq_config_id` agregados a la tabla destino (si aplica nivel fila)
- [ ] Paso `ejecutar_dq` agregado al Workflow después de la carga principal
- [ ] Paso `alertar_si_falla` configurado para reglas `critical`
- [ ] Variable `dataset_dq` registrada en `deploy_dev.json` y `deploy_prd.json`
- [ ] Umbrales validados con el Business Steward o Data Owner
