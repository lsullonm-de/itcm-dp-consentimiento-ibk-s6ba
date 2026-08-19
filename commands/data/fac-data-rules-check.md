# Rules Check — Verificación de Estándares

Analiza los archivos SQL, YAML y Python modificados y verifica el cumplimiento de las reglas
críticas del ecosistema DataOps ITC. Solo lectura del código — reporta violaciones con archivo,
línea y corrección sugerida.

**Argumento (`$ARGUMENTS`):**
- Sin argumento → analiza `git diff HEAD` (cambios no commiteados)
- `--staged` → analiza `git diff --staged`
- `{ruta}` → analiza solo archivos en esa ruta (ej: `data/bigquery/{dataset_out}/{tabla_out}/sp/`)
- `--all` → analiza todos los archivos del repo (no solo el diff)
- `bigquery` → aplica solo `@.claude/data/rules/bigquery.md`
- `security` → aplica solo `@.claude/data/rules/security.md`
- `workflow` → aplica solo `@.claude/data/rules/workflow.md`
- `dataops` → aplica solo `@.claude/data/rules/dataops.md`

> **Para una auditoría completa estructurada por fases**, usar el skill de compliance:
> `/data:implement-stage COMPLIANCE`
> Este comando es para verificaciones rápidas durante BUILD.

**Reglas de referencia:** `@.claude/data/rules/bigquery.md` · `@.claude/data/rules/security.md` · `@.claude/data/rules/workflow.md` · `@.claude/data/rules/dataops.md` · `@.claude/data/rules/general.md`

---

## Paso 0 — Obtener archivos a analizar

```bash
git diff HEAD          # sin argumento
git diff --staged      # con --staged
```

Filtrar solo archivos relevantes: `.sql`, `.yaml`, `.yml`, `.py`, `.ipynb`.
Ignorar: `.md`, `.json` (env/deploy), `.txt`.

Si `--all`: usar Glob para encontrar todos los archivos en `data/`, `pipeline/`, `service/`, `image/`.

---

## REGLA 1 — Sin valores hardcodeados de proyecto/dataset/tabla en SQL

**Patrón a buscar en archivos `.sql`:**
```sql
-- ❌ Hardcodeado (proyecto literal)
`dev-itc-customer-services.analytics.ba_itc_attr_education`
`int-advanced-analytics-01.stored_procedures`
FROM `central-data-governance`

-- ❌ Correcto en proyecto/dataset pero tabla hardcodeada
`${project_analytics}.${dataset_analytics}.ba_itc_attr_education`

-- ✅ Correcto (3 variables: project + dataset + table)
`${project_ba_itc_attr_education}.${dataset_ba_itc_attr_education}.${table_ba_itc_attr_education}`
-- Excepción SPs (procedimientos, no tablas):
`${project_operation}.${dataset_sp}.sp_nombre`
```

**Violación:** cualquier nombre de proyecto GCP (`*-itc-*`, `*-intercorp-*`, `*-advanced-analytics-*`, etc.)
o dataset hardcodeado en líneas de query SQL.

**Excepción permitida:** comentarios (`--`), strings de documentación en `OPTIONS`.

```
❌ REGLA 1 — Proyecto hardcodeado
   data/bigquery/analytics/ba_itc_attr_education/sp/sp_ba_itc_attr_education_rcc.sql línea 12:
   FROM `dev-itc-customer-services.analytics.ba_itc_attr_rcc`
   Fix: FROM `${project_ba_itc_attr_rcc}.${dataset_ba_itc_attr_rcc}.${table_ba_itc_attr_rcc}`
```

---

## REGLA 2 — Variables de tablas en trío (project + dataset + table) — TODA tabla BQ

**Patrón:** toda referencia a tabla BigQuery (input, output, stage, tmp, aux, master, business)
debe tener las 3 variables juntas: `${project_X}.${dataset_X}.${table_X}`

**Violación:** uso de solo 2 de las 3 variables, o nombre de tabla literal.
**Excepción:** SPs → `${project_operation}.${dataset_sp}.sp_nombre` (procedimiento, no tabla).

```
⚠️ REGLA 2 — Referencia incompleta de tabla
   data/bigquery/analytics/ba_itc_attr_education/sp/sp_ba_itc_attr_education_rcc.sql línea 25:
   `${project_ba_itc_attr_rcc}.${dataset_ba_itc_attr_rcc}.ba_itc_attr_rcc`
   El nombre de tabla está hardcodeado — debe ser ${table_ba_itc_attr_rcc}

⚠️ REGLA 2 — Tabla stage sin variable table_
   sp_calcular_score.sql línea 41:
   `${project_analytics}.${dataset_stage}.tmp_score_calc`
   Fix: `${project_tmp_score_calc}.${dataset_tmp_score_calc}.${table_tmp_score_calc}`
```

---

## REGLA 2B — DDL de tablas finales: `CREATE TABLE IF NOT EXISTS` obligatorio

**Aplica a:** archivos `.sql` en `data/bigquery/{dataset_out}/{tabla_out}/ddl/`

```sql
-- ❌ INCORRECTO — destruye la tabla en producción si existe
CREATE OR REPLACE TABLE `${project_X}.${dataset_X}.${table_X}`

-- ✅ CORRECTO — idempotente, no toca la tabla si ya existe
CREATE TABLE IF NOT EXISTS `${project_X}.${dataset_X}.${table_X}`
```

**Excepción permitida:** `CREATE OR REPLACE TABLE` dentro de SPs para tablas intermedias
(`tmp_*`, `aux_*`) en `${dataset_stage}` — esas no son DDL de tablas finales.

```
❌ REGLA 2B — CREATE OR REPLACE TABLE en DDL de tabla final
   data/bigquery/analytics/ba_itc_attr_education/ddl/ba_itc_attr_education.sql línea 1:
   CREATE OR REPLACE TABLE `...` — usar CREATE TABLE IF NOT EXISTS
```

---

## REGLA 2C — ALTER TABLE: solo ADD COLUMN en archivo independiente; DROP COLUMN prohibido

**Aplica a:** todos los archivos `.sql` en `data/bigquery/{dataset_out}/{tabla_out}/`

```sql
-- ❌ INCORRECTO — DROP COLUMN prohibido (irreversible en producción)
ALTER TABLE `...`
DROP COLUMN campo_viejo;

-- ❌ INCORRECTO — ALTER embebido en el archivo CREATE TABLE
CREATE TABLE IF NOT EXISTS `...`
(
  campo_existente STRING,
  nuevo_campo     STRING    -- ← debe estar en alter/ independiente
)

-- ✅ CORRECTO — ADD COLUMN idempotente, archivo separado: alter/alter_{tabla}_YYYYMMDD_NNN.sql
ALTER TABLE `${project_X}.${dataset_X}.${table_X}`
ADD COLUMN IF NOT EXISTS nuevo_campo STRING OPTIONS (description = '...');
```

**Verificar:**
1. No existe ningún `DROP COLUMN` en el repo
2. No hay nuevas columnas en el `CREATE TABLE IF NOT EXISTS` de una tabla ya existente en prod — deben estar en `alter/`
3. Los scripts `alter/` siguen naming: `alter_{tabla_out}_YYYYMMDD_{NNN}.sql`
4. Los scripts `alter/` están registrados en `bigquery_ddl` del `deploy_[env].json` **después** del script de CREATE TABLE de la misma tabla

```
❌ REGLA 2C — DROP COLUMN encontrado
   data/bigquery/analytics/ba_itc_attr_retail/alter/alter_ba_itc_attr_retail_20260817_001.sql línea 3:
   DROP COLUMN campo_viejo — PROHIBIDO, usar solo ADD COLUMN IF NOT EXISTS

❌ REGLA 2C — ALTER embebido en CREATE TABLE
   data/bigquery/analytics/ba_itc_attr_retail/ddl/ba_itc_attr_retail.sql:
   Columna 'nuevo_campo' agregada directamente en CREATE TABLE — debe ir en alter/
```

---

## REGLA 3 — Tablas temporales solo en `${dataset_stage}`

**Patrón a buscar en `.sql`:**
```sql
-- ❌ Temporal en dataset incorrecto
CREATE TEMP TABLE ...
CREATE TABLE `${project_analytics}.${dataset_analytics}.tmp_...`
CREATE TABLE `${project_analytics}.bi_itc.tmp_...`

-- ✅ Correcto (también usa 3 variables para la tabla tmp)
CREATE OR REPLACE TABLE `${project_tmp_{tabla}_{n}}.${dataset_tmp_{tabla}_{n}}.${table_tmp_{tabla}_{n}}` AS
```

**Violación:** tablas temporales creadas fuera de `${dataset_stage}`, o usando `CREATE TEMP TABLE`
(no se puede referenciar entre sesiones).

---

## REGLA 4 — Campos de auditoría obligatorios en tablas output

**Patrón a buscar en archivos DDL (`.sql` en `data/bigquery/{dataset_out}/{tabla_out}/ddl/`):**

Los siguientes campos deben estar presentes en toda tabla output:
- `load_date DATE`
- `record_source STRING`
- `creation_user STRING`

Si `etapas.data_quality=true` en el spec → también requeridos:
- `dq_flag_ind INT64`
- `dq_control_msg STRING`
- `dq_config_id STRING`

```
❌ REGLA 4 — Campo de auditoría faltante en DDL
   data/bigquery/analytics/ba_itc_attr_education/ddl/ba_itc_attr_education.sql:
   Falta campo: creation_user STRING
   Fix: agregar 'creation_user STRING' al DDL
   Ver: @.claude/data/standard/architecture/data-platform-layers.md
```

---

## REGLA 5 — Naming de objetos BQ

**Tablas:** verificar prefijo correcto según capa:
| Prefijo | Capa | Ejemplo |
|---|---|---|
| `ba_` | Business Analytics | `ba_itc_attr_education` |
| `bi_` | Business Intelligence | `bi_itc_attr_party` |
| `m_` | Master | `m_customer_hist` |
| `t_` | Transaction | `t_retail_transaction` |
| `tmp_` | Stage (temporales) | `tmp_attr_education_1` |
| `sp_` | Stored Procedures | `sp_ba_itc_attr_education` |
| `dq_` | Data Quality | `dq_config` |

**SPs:** verificar que el nombre sigue `sp_{nombre_tabla}` o `sp_dq_{nombre_tabla}`.

---

## REGLA 6 — Cabecera y variables en Workflows

Los archivos de workflow **sí incluyen** cabecera de despliegue. Las violaciones son de dos tipos:

### 6-A — Cabecera con valores hardcodeados

```yaml
# ❌ INCORRECTO — valores hardcodeados en cabecera
name: prd-itc-ingreso-vii-inference
project: prd-itc-customer-services
service_account: prd-itc-ingreso-job@prd-itc-customer-services.iam.gserviceaccount.com

# ✅ CORRECTO — cabecera con variables ${...}
name: ${env}-itc-ingreso-vii-inference
project: ${project_analytics}
service_account: ${service_account_job}
```

### 6-B — SA construida inline con concatenación

```yaml
# ❌ INCORRECTO — SA inline (doble prefijo potencial)
service_account: ${env}-itc-nombre-job@${env}-${project_analytics}.iam.gserviceaccount.com

# ✅ CORRECTO — SA desde variable del trigger
service_account: ${service_account_job}
```

### 6-C — Hardcodeado en el cuerpo del workflow

```yaml
# ❌ Hardcodeado en set_vars o steps
projectId: "dev-itc-customer-services"
query: "CALL `dev-itc.stored_procedures.sp_education`()"

# ✅ Correcto
projectId: ${v_billing_project}
query: ${"CALL `" + var_sp_education + "`(...)"}
```

**Violación:** valores de proyecto, dataset, SA o tabla hardcodeados en cabecera o cuerpo del workflow.

---

## REGLA 7 — SA tipo correcto por componente

**Verificar en YAMLs de deploy:**

| Componente | SA esperada |
|---|---|
| `cloud_run`, `cloud_function` | SA tipo `-app` |
| `workflow`, `vertex_pipeline`, `cloud_scheduler` | SA tipo `-job` |

```
⚠️ REGLA 7 — SA incorrecta para componente
   pipeline/scheduler/analytics/ba_itc_attr_education/cs-ba-itc-attr-education-rcc.yaml:
   service_account usa SA '-app' en un cloud_scheduler
   Fix: usar SA tipo '-job' para orquestación
   Ver: @.claude/data/standard/services/service-accounts.md
```

---

## REGLA 8 — Diccionarios de mapeo en Python/notebooks sin alteraciones

**Patrón a buscar en `.py` e `.ipynb`:**
```python
# ❌ Diccionario renombrado o valores cambiados
educ_map = {
    "Sin educacion": 1, "Primaria incompleta": 2,  # claves distintas al original
}

# ✅ Correcto — nombre y valores exactos del notebook fuente
nivel_map = {
    'ANALFABETO/A': 'Sin_educacion',
    'PRIMARIA COMPLETA': 'Primaria',
    # ... mismo que en el notebook original
}
```

---

## REGLA 9 — DQ sql_rule retorna filas inválidas (no conteo)

**Patrón a buscar en sql_rule dentro de SP DQ o spec:**
```sql
-- ❌ Retorna conteo en lugar de filas
SELECT COUNT(*) FROM tabla WHERE campo IS NULL

-- ✅ Correcto — retorna las filas inválidas
SELECT * FROM `${project}.${dataset}.tabla` WHERE campo IS NULL
```

---

## REGLA 10 — Variable `env` no incluida en `env_dev.json` / `env_prd.json`

**Verificar en `deploy/env_dev.json` y `deploy/env_prd.json`:**
```json
// ❌ env presente
{
  "env": "dev",   ← no debe estar
  "project_analytics": "..."
}
```

```
❌ REGLA 10 — Variable 'env' en env_dev.json
   deploy/env_dev.json línea 2: "env": "dev"
   Fix: eliminar — 'env' es global del framework Dataops, no va en env_[dev/prd].json
   Ver: @.claude/data/skills/build/dataops/dataops-configurator/SKILL.md
```

---

## Formato del reporte

Para cada archivo analizado:

```
## 📄 data/bigquery/analytics/ba_itc_attr_education/sp/sp_ba_itc_attr_education_rcc.sql

✅ REGLA 1 — Sin hardcoding de proyectos: OK
❌ REGLA 2 — Variables input en trío: VIOLACIÓN
   Línea 25: tabla hardcodeada 'ba_itc_attr_rcc' — debe ser ${table_ba_itc_attr_rcc}
✅ REGLA 3 — Temporales en dataset_stage: OK
✅ REGLA 5 — Naming de objetos: OK
```

Al final, resumen global:

```
## Resumen /rules-check

- Archivos analizados: N
- Violaciones críticas (🔴): M
- Advertencias (🟡): K
- Archivos limpios: P

| Regla | Violaciones |
|---|---|
| REGLA 1 — Sin hardcoding | 2 |
| REGLA 3 — Temporales en stage | 1 |

### Acciones requeridas antes de DATAOPS
1. sp_ba_itc_attr_education_rcc.sql línea 25: reemplazar tabla hardcodeada
2. wf-ba-itc-attr-education-rcc.yaml línea 8: reemplazar proyecto hardcodeado
```

Si no hay violaciones:
```
✅ Todos los archivos cumplen las reglas verificadas.
   Apto para /data:implement-stage DATAOPS
```

---

## Paso final — Guardar reporte en `docs/reports/`

**Siempre** guardar el reporte generado como archivo Markdown en el repo:

```
docs/reports/rules-check-{YYYY-MM-DD}.md
```

Si ya existe un reporte de la misma fecha → reemplazarlo (es una re-ejecución del mismo día).

### Estructura del archivo guardado

```markdown
# Reporte /rules-check — {YYYY-MM-DD}

> **Repo:** `{nombre-repo}`
> **Ejecutado por:** {autor}
> **Scope:** {argumento usado: --all | --staged | ruta | regla}
> **Archivos analizados:** N SQL · M YAML · K Python

{contenido completo del reporte}

---
> 📁 Generado por `/rules-check {args}` · `{repo}` · {fecha}
> Próximo paso: {acción sugerida según resultado}
```

> **Por qué guardar el reporte:** permite comparar evoluciones entre ejecuciones,
> tener trazabilidad de qué violaciones existían en cada fecha, y servir como
> evidencia de auditoría en el flujo de fábrica.
> El reporte NO se commitea automáticamente — el developer decide cuándo hacerlo.


