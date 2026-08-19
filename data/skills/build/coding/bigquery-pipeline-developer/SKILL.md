# Skill: BigQuery Pipeline Developer

> Skill para la implementación de DDL y Stored Procedures en BigQuery bajo la arquitectura
> y estándares de la Data Platform ITC. Aplica a cualquier repo `bq_pipeline` que no sea
> exclusivamente el repo de atributos de cliente (`itcm-dp-vuci-customer`).
>
> Fuentes de verdad:
> - `@.claude/data/standard/architecture/data-platform-layers.md` — capas RAW/Master/Business, prefijos, campos de auditoría
> - `@.claude/data/standard/architecture/gcp-organization.md` — proyectos GCP, naming de recursos, lineamientos
> - `@.claude/data/standard/bigquery/development.md` — patrones SQL, optimización, EXECUTE IMMEDIATE

---

## Rol

Implementas DDL (tablas BigQuery) y Stored Procedures para pipelines de datos en cualquier
capa de la arquitectura (RAW, Master o Business), siguiendo los estándares corporativos ITC.
No generas código de orquestación (Workflow/Scheduler) ni configuración Dataops (deploy.json).

---

## 1. Arquitectura de Capas — Referencia rápida

La Data Platform tiene tres zonas. Cada zona determina el proyecto GCP, naming de dataset y prefijos de tabla:

| Zona | Proyecto GCP | Dataset naming | Prefijos de tabla |
|---|---|---|---|
| RAW | `[env]-[company]-data-storage` | `raw_[application]` | (nombres del sistema origen — sin estándar ITC) |
| Master | `[env]-[company]-data-storage` | `master_[domain]` | `m_`, `c_`, `t_`, `h_`, `s_`, `iden_`, `aux_`, `tmp_`, `v_` |
| Business | `[env]-[company]-data-storage` | `bi_`, `ba_`, `dq_` | `bm_`, `ba_`, `dv_`, `vm_`, `v_` |
| Processing (SPs) | `[env]-[company]-data-operation` | `master_stage` | — |

> Ver detalle completo: `@.claude/data/standard/architecture/data-platform-layers.md`

---

## 2. Naming de Tablas

### Prefijos según capa y tipo

**Capa Master:**

| Prefijo | Tipo | Ejemplo |
|---|---|---|
| `m_` | Entidad maestra / dimensión | `m_customer`, `m_product`, `m_place` |
| `c_` | Catálogo (código + descripción) | `c_identification_document_type`, `c_campaign` |
| `t_` | Transacción / evento | `t_transaction`, `t_payment`, `t_sale` |
| `h_` | Hash / equivalencia de código | `h_party` |
| `s_` | Snapshot periódico | `s_customer_monthly`, `s_account_daily` |
| `iden_` | Identificador compartido nivel grupo | `iden_party`, `iden_party_digital` |
| `aux_` | Auxiliar / precalculados persistentes | `aux_customer_account` |
| `tmp_` | Tabla temporal del proceso | `tmp_ecai_solicitud` |
| `v_` | Vista de consumo | `v_party_individual` |

**Capa Business:**

| Prefijo | Tipo | Ejemplo |
|---|---|---|
| `ba_` | Analítica / inputs-outputs de modelos | `ba_customer_loyalty`, `ba_churn_score` |
| `bi_` | BI / reportes / dashboards | `bi_priorizacion_lead`, `bi_venta` |
| `bm_` | Datamart interno de área | `bm_campaign`, `bm_riesgo` |
| `dv_` | Visualización para usuarios finales | `dv_loyalty_segmentacion` |
| `vm_` | Vista materializada precalculada | `vm_venta_producto` |

### Referencia completa a tablas

Siempre con backticks y tres partes: `proyecto.dataset.tabla`, usando las 3 variables declaradas en `env_[env].json`:

```sql
`${project_ba_customer_loyalty}.${dataset_ba_customer_loyalty}.${table_ba_customer_loyalty}`
```

### Regla: sin hardcoding de proyecto/dataset/tabla

Todos los nombres de proyecto, dataset y tabla deben referenciarse vía variables `${...}` —
nunca con valores hardcodeados. Los valores se resuelven desde `env_dev.json` / `env_prd.json`.

---

## 3. Campos de Auditoría (obligatorios en tablas Master y Business)

Todas las tablas finales deben incluir estos campos:

```sql
-- Auditoría estándar
load_date       TIMESTAMP   OPTIONS (description = 'Fecha/hora de inserción del registro'),
record_source   STRING      OPTIONS (description = 'Sistema/proceso origen de los datos'),
creation_user   STRING      OPTIONS (description = 'SA del proceso de carga')
```

Si el módulo tiene `etapas.data_quality: true`, agregar también:

```sql
-- Calidad de datos (DQ)
dq_flag_ind     BOOLEAN     OPTIONS (description = 'true = registro válido, false = incumple reglas DQ'),
dq_control_msg  STRING      OPTIONS (description = 'Detalle de columnas o reglas que no pasaron DQ'),
dq_config_id    STRING      OPTIONS (description = 'ID de metadatos del proceso DQ asociado')
```

---

## 4. Template DDL — `CREATE TABLE IF NOT EXISTS`

```sql
CREATE TABLE IF NOT EXISTS `${project_{prefijo}_{nombre_tabla}}.${dataset_{prefijo}_{nombre_tabla}}.${table_{prefijo}_{nombre_tabla}}`
(
  -- Campos de negocio (ejemplos — adaptar al caso de uso)
  iden_party_hash     STRING    OPTIONS (description = 'Hash SHA256 tipo_doc+nro_doc'),
  {campo_negocio_1}   STRING    OPTIONS (description = '{descripción}'),
  {campo_negocio_2}   INT64     OPTIONS (description = '{descripción}'),
  {campo_negocio_3}   FLOAT64   OPTIONS (description = '{descripción}'),

  -- Campos de auditoría (obligatorios)
  load_date           TIMESTAMP OPTIONS (description = 'Fecha/hora de inserción'),
  record_source       STRING    OPTIONS (description = 'Sistema origen'),
  creation_user       STRING    OPTIONS (description = 'SA del proceso de carga')

  -- DQ (solo si data_quality: true en el spec)
  -- dq_flag_ind      BOOLEAN,
  -- dq_control_msg   STRING,
  -- dq_config_id     STRING
)
PARTITION BY DATE(load_date)
CLUSTER BY {campo_clave_consulta}    -- opcional, elegir campo de filtro frecuente
OPTIONS (
  description = '{Descripción funcional de la tabla — qué contiene y para qué}',
  labels      = [("team", "data-platform"), ("env", "${env}")]
);
```

### Tipos de dato BigQuery disponibles

| Tipo BigQuery | Cuándo usar |
|---|---|
| `STRING` | Texto, códigos, IDs |
| `INT64` | Enteros (conteos, flags 0/1, códigos numéricos) |
| `FLOAT64` | Decimales no monetarios |
| `NUMERIC` | Montos monetarios — alta precisión |
| `BOOL` | Indicadores true/false (campos DQ) |
| `DATE` | Fecha sin hora (`YYYY-MM-DD`) |
| `TIMESTAMP` | Fecha con hora y zona (`YYYY-MM-DD HH:MM:SS UTC`) |
| `BYTES` | Datos encriptados (PII con `AEAD.ENCRYPT`) |

### Particionamiento y clustering

- Tablas de hechos (`t_*`) y Business con carga incremental: `PARTITION BY {campo_fecha}`
- Tablas master (`m_*`) de gran volumen: `PARTITION BY load_date`
- Tablas pequeñas / de referencia: sin partición
- Clustering: elegir 1-4 columnas de filtro frecuente (ej: `iden_party_hash`, `company_id`)

---

## 4B. ALTER TABLE — Agregar Columnas (migraciones de esquema)

Cuando se necesita agregar columnas a una tabla existente en producción, se crean scripts
`ALTER TABLE` **independientes** — nunca modificando el `CREATE TABLE IF NOT EXISTS` existente.

### Regla fundamental

| Operación | Permitida | Archivo |
|---|---|---|
| `ADD COLUMN IF NOT EXISTS` | ✅ Sí | `alter/alter_{tabla}_YYYYMMDD_{NNN}.sql` |
| `DROP COLUMN` | ❌ Prohibido | — |

### Carpeta y naming

```
data/bigquery/{dataset_out}/{tabla_out}/
├── ddl/
│   └── {tabla_out}.sql                              ← CREATE TABLE IF NOT EXISTS (base)
├── alter/
│   ├── alter_{tabla_out}_20260817_001.sql            ← primera migración del release
│   └── alter_{tabla_out}_20260817_002.sql            ← segunda migración del mismo release
├── sp/
└── dml/
```

### Template ALTER TABLE

```sql
-- alter_{tabla_out}_YYYYMMDD_NNN.sql
-- Descripción: {qué se agrega y por qué}
ALTER TABLE `${project_{prefijo}_{nombre}}.${dataset_{prefijo}_{nombre}}.${table_{prefijo}_{nombre}}`
ADD COLUMN IF NOT EXISTS {campo_nuevo_1} {TIPO} OPTIONS (description = '{descripcion}'),
ADD COLUMN IF NOT EXISTS {campo_nuevo_2} {TIPO} OPTIONS (description = '{descripcion}');
```

**Nota:** BigQuery acepta múltiples `ADD COLUMN IF NOT EXISTS` en un solo `ALTER TABLE`.
El `IF NOT EXISTS` garantiza idempotencia — re-ejecutar el script no falla si la columna ya existe.

### Registro en `deploy_[env].json`

Los scripts `alter/` se registran bajo `bigquery_ddl`, **después** del script de CREATE TABLE:

```json
"bigquery_ddl": [
  "/data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql",
  "/data/bigquery/{dataset_out}/{tabla_out}/alter/alter_{tabla_out}_20260817_001.sql"
]
```

### Por qué no modificar el CREATE TABLE

El DDL `CREATE TABLE IF NOT EXISTS` es idempotente: si la tabla ya existe en producción,
el framework lo omite silenciosamente. Agregar columnas ahí no las crearía en tablas existentes.
El script `alter/` sí modifica la tabla existente sin destruirla.

---

## 5. Naming de Stored Procedures

### Patrón general

```
sp_[company]_[accion]_[tabla_o_dominio]
```

| Segmento | Descripción | Ejemplo |
|---|---|---|
| `company` | Código de la empresa o área | `itc`, `itcm`, `oe`, `far` |
| `accion` | Operación principal del SP | `load`, `merge`, `update`, `build` |
| `tabla_o_dominio` | Tabla output o dominio de datos | `m_customer`, `t_payment`, `customer_loyalty` |

**Ejemplos:**

```sql
sp_itc_load_m_customer          -- carga tabla maestra de clientes
sp_itc_merge_t_payment          -- merge incremental de pagos
sp_itcm_build_ba_churn_score    -- construcción de score de churn
sp_itc_load_bi_venta_diaria     -- carga reporte de venta diaria
```

Para SPs intermedios que generan tablas temporales, agregar prefijo `tmp_` al nombre:

```sql
sp_itcm_load_tmp_ba_churn_features    -- paso previo al SP consolidador
sp_itcm_load_ba_churn_score           -- SP consolidador final
```

Para lógica compleja partida en pasos secuenciales:

```sql
sp_itcm_load_tmp_ba_churn_features_1  -- paso 1
sp_itcm_load_tmp_ba_churn_features_2  -- paso 2
sp_itcm_load_ba_churn_score           -- consolidador
```

### Dataset de los SPs

Los SPs siempre se crean en el proyecto `data-operation`, dataset `master_stage`:

```sql
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_itcm_load_ba_{dominio}`(...)
```

Donde `${dataset_sp}` = `master_stage` (o `stored_procedures` en repos más nuevos — respetar el que ya existe).

---

## 6. Template de Stored Procedure

```sql
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_itcm_{accion}_{tabla}`(
  -- Parámetros de control
  p_process_date      DATE,

  -- Parámetros de tablas input (proyectos y datasets como variables)
  p_project_input     STRING,
  p_dataset_input     STRING,
  p_table_input       STRING,

  -- Parámetros de output
  p_project_output    STRING,
  p_dataset_output    STRING,
  p_dataset_stage     STRING,
  p_dataset_sp        STRING
)
OPTIONS(strict_mode=false)
BEGIN

  -- ============================================================
  -- 1. DECLARACIÓN DE VARIABLES
  -- ============================================================
  DECLARE v_sql           STRING;
  DECLARE v_input_path    STRING;
  DECLARE v_output_path   STRING;
  DECLARE v_tmp_path      STRING;

  -- ============================================================
  -- 2. CONSTRUCCIÓN DE RUTAS A TABLAS
  -- ============================================================
  SET v_input_path  = p_project_input  || '.' || p_dataset_input  || '.' || p_table_input;
  SET v_output_path = p_project_output || '.' || p_dataset_output || '.{tabla_output}';
  SET v_tmp_path    = p_project_output || '.' || p_dataset_stage  || '.tmp_{nombre_intermedio}';

  -- ============================================================
  -- 3. TABLAS INTERMEDIAS (si aplica)
  -- ============================================================
  SET v_sql = '''
    CREATE OR REPLACE TABLE `''' || v_tmp_path || '''` AS
    SELECT
      {campos}
    FROM `''' || v_input_path || '''`
    WHERE {filtros}
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 4. CARGA EN TABLA FINAL
  -- ============================================================

  -- Opción A: carga completa (TRUNCATE + INSERT)
  SET v_sql = '''
    CREATE OR REPLACE TABLE `''' || v_output_path || '''` AS
    SELECT
      {campos_negocio},
      CURRENT_TIMESTAMP()              AS load_date,
      '{record_source}'                AS record_source,
      SESSION_USER()                   AS creation_user
    FROM `''' || v_tmp_path || '''`
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- Opción B: carga incremental (DELETE + INSERT por partición)
  -- SET v_sql = '''DELETE FROM `''' || v_output_path || '''` WHERE DATE(load_date) = "''' || p_process_date || '''"''';
  -- EXECUTE IMMEDIATE v_sql;
  --
  -- SET v_sql = '''
  --   INSERT INTO `''' || v_output_path || '''`
  --   SELECT {campos}, CURRENT_TIMESTAMP(), '{source}', SESSION_USER()
  --   FROM `''' || v_tmp_path || '''`
  -- ''';
  -- EXECUTE IMMEDIATE v_sql;

END;
```

### Reglas de SQL dinámico

- Todo SQL que use variables de proyecto/dataset/tabla se ejecuta con `EXECUTE IMMEDIATE`.
- Concatenar rutas con `||`:
  ```sql
  `''' || v_proyecto || '.' || v_dataset || '.' || v_tabla || '''`
  ```
- Fechas en filtros WHERE dentro de SQL dinámico:
  ```sql
  WHERE fecha_campo >= "''' || p_process_date || '''"
  ```

---

## 7. Manejo de Datos Sensibles (PII)

Si el output incluye campos PII (DNI, teléfono, correo, nombre, sueldo, cuenta):

```sql
-- Encriptar al escribir en la tabla
AEAD.ENCRYPT(
  (SELECT keyset FROM `${project_control}.config_protected_data` WHERE key_type = 'DNI'),
  CAST(nro_documento AS BYTES),
  b''
) AS nro_documento_enc
```

- La tabla encriptada va al proyecto `prd-[company]-data-sensitive`.
- Se crea una vista autorizada en `data-storage` para consumo controlado.
- Ver detalle completo: `@.claude/data/standard/architecture/data-platform-layers.md` sección 7.

---

## 8. Patrones SQL — Reglas de uso general

### EXECUTE IMMEDIATE siempre para SQL dinámico

```sql
SET v_sql = '''
  SELECT ...
''';
EXECUTE IMMEDIATE v_sql;
```

### SAFE_DIVIDE para divisiones

```sql
-- ✅ CORRECTO — nunca lanza error por division por cero
SAFE_DIVIDE(numerador, denominador) AS ratio_campo

-- ❌ EVITAR — falla si denominador = 0
numerador / denominador
```

### SAFE_CAST para conversiones null-safe

```sql
-- ✅ Retorna NULL si el valor no es convertible
SAFE_CAST(campo_string AS NUMERIC)

-- ❌ Puede lanzar error en producción
CAST(campo_string AS NUMERIC)
```

### NOT IN con subqueries — patrón peligroso

```sql
-- ❌ PELIGROSO: retorna 0 filas si la subquery tiene NULLs
WHERE id NOT IN (SELECT id FROM otra_tabla)

-- ✅ CORRECTO: usar NOT EXISTS
WHERE NOT EXISTS (SELECT 1 FROM otra_tabla b WHERE b.id = a.id)

-- ✅ ALTERNATIVA: LEFT JOIN con NULL check
SELECT a.* FROM tabla a
LEFT JOIN otra_tabla b ON a.id = b.id
WHERE b.id IS NULL
```

### Filtros de partición sobre columna raw

```sql
-- ❌ ESCANEA TODA LA TABLA — DATE() impide partition pruning
WHERE DATE(load_date) >= '2024-01-01'

-- ✅ CORRECTO — filtro directo sobre columna de partición
WHERE load_date >= '2024-01-01'
```

### CTEs vs tablas temporales

```sql
-- ❌ CTE referenciada 2+ veces se re-ejecuta cada vez
WITH base AS (SELECT ... FROM tabla_grande)
SELECT * FROM base t1 JOIN base t2 ...

-- ✅ Materializar si se usa más de una vez
CREATE OR REPLACE TEMP TABLE tmp_base AS SELECT ... FROM tabla_grande;
SELECT * FROM tmp_base t1 JOIN tmp_base t2 ...
```

### Deduplicación

```sql
SELECT * EXCEPT(rn) FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY {pk_columns} ORDER BY load_date DESC) AS rn
  FROM `{tabla}`
)
WHERE rn = 1
```

### Aliases de tabla

| Situación | Convención |
|---|---|
| JOINs con pocas tablas | Letras `a`, `b`, `c` |
| Tablas fuente conocidas | Abreviatura descriptiva: `trx`, `cust`, `prod` |
| JOINs masivos (>5 tablas) | Sin alias, usar `USING (id)` |
| CTEs numeradas | `TMP1`, `TMP2` en mayúsculas |

---

## 9. Flujo de trabajo por etapa

### PHYSICAL_DESIGN — artefactos esqueleto

Todos los artefactos viven en `data/bigquery/{dataset_out}/{tabla_out}/` — ver
`@.claude/data/standard/factory/repositories.md` §3.

1. Crear `data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql` (tabla final) con columnas
   físicas completas (sin lógica).
2. Por cada fuente `{emp}` en `fuentes[]`, crear `data/bigquery/{dataset_out}/{tabla_out}/ddl/
   tmp_{tabla_out}_{emp}.sql` (staging) y `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}
   _{emp}.sql` con skeleton: cabecera, parámetros tipados, comentarios de alto nivel.
3. Las referencias de tabla en el skeleton usan `${project_*}.${dataset_*}.${table_*}` — sin hardcoding.

### CODING — implementación completa

1. Completar DDL: agregar `OPTIONS`, labels, partición, clustering.
2. Completar cada `sp_{tabla_out}_{emp}.sql`: implementar lógica de negocio en cada sección del
   skeleton, uno por fuente.
3. Por cada fuente, crear `data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_{tabla_out}_
   {emp}.sql` con tests unitarios del SP.
4. Verificar que toda variable `${...}` usada en DDL y SP tiene su entrada en `env_dev.json`.

---

## 10. Checklist pre-revisión

### Naming y estructura

- [ ] Tabla output tiene prefijo correcto según capa (`m_`, `t_`, `ba_`, `bi_`, etc.)
- [ ] SP sigue el patrón `sp_[company]_[accion]_[tabla]`
- [ ] SPs intermedios llevan `tmp_` en el nombre
- [ ] Dataset de SPs = `master_stage` o `stored_procedures` (según repo)
- [ ] Todas las referencias de proyecto/dataset/tabla con `${variable}` — sin hardcoding

### DDL

- [ ] `CREATE TABLE IF NOT EXISTS` (no `CREATE OR REPLACE`)
- [ ] Campos de auditoría presentes: `load_date`, `record_source`, `creation_user`
- [ ] Campos DQ si `etapas.data_quality: true`: `dq_flag_ind`, `dq_control_msg`, `dq_config_id`
- [ ] `OPTIONS(description=..., labels=...)` completos
- [ ] Partición configurada en tablas con carga incremental

### SP

- [ ] `OPTIONS(strict_mode=false)`
- [ ] Todo SQL dinámico usa `EXECUTE IMMEDIATE`
- [ ] No hay hardcoding de proyectos, datasets o tablas (solo variables)
- [ ] `creation_user` usa `SESSION_USER()` — nunca hardcodeado
- [ ] `load_date` usa `CURRENT_TIMESTAMP()` — nunca hardcodeado

### SQL

- [ ] Divisiones protegidas con `SAFE_DIVIDE`
- [ ] Conversiones con `SAFE_CAST` en campos con posibles valores inválidos
- [ ] Sin `NOT IN` con subqueries — usar `NOT EXISTS` o `LEFT JOIN ... IS NULL`
- [ ] Filtros de partición sobre columna raw (no `DATE(ts)`, no `CAST(...)`)
- [ ] CTEs referenciadas más de una vez → materializadas en tabla temporal
- [ ] Sin `SELECT *` en queries de producción — columnas explícitas