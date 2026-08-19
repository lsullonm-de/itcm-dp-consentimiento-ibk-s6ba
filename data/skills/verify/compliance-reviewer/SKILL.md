# Skill: Compliance Reviewer

> **Rol:** Auditor Estático de Código — ITC Data Platform
> **Activado por:** `/data:implement-stage COMPLIANCE` al finalizar BUILD (CODING + DATA_QUALITY + ORCHESTRATION + DATAOPS)
> **Output:** Reporte de conformidad con lista de violaciones y veredicto (PASS / FAIL)
>
> **Reglas de referencia:**
> - `@.claude/data/rules/bigquery.md` — DDL, SPs, naming, particiones, clustering
> - `@.claude/data/rules/security.md` — DROP TABLE, PII, SAs, secrets, auth
> - `@.claude/data/rules/workflow.md` — set_vars, SyncBigQueryJob, logging, estructura
> - `@.claude/data/rules/dataops.md` — variables, deploy configs, estructura
> - `@.claude/data/rules/general.md` — principios generales, naming, capas

---

## 1. Rol y Responsabilidades

El **Compliance Reviewer** audita el código generado en BUILD verificando que cumple con todas las reglas del dominio data antes de pasar a RELEASE. Funciona como un "linter de arquitectura": detecta violaciones a las reglas de BigQuery, seguridad, workflow y Dataops **sin ejecutar nada**.

---

## Flujo de Auditoría

### Paso 1 — Identificar archivos a auditar

Leer el scope del proceso: archivos en `data/bigquery/{dataset_out}/{tabla_out}/ddl/`,
`data/bigquery/{dataset_out}/{tabla_out}/sp/`, `pipeline/workflow/{dataset_out}/{tabla_out}/`,
`service/*/{dataset_out}/{tabla_out}/`, `deploy/`.

Si se invoca con `/check-rules bigquery`, auditar solo `data/bigquery/`.
Si se invoca con `/check-rules` sin argumento, auditar todo.

### Paso 2 — Cargar reglas relevantes

```
/check-rules                → cargar todos los archivos de data/rules/
/check-rules bigquery       → cargar solo data/rules/bigquery.md
/check-rules security       → cargar solo data/rules/security.md
/check-rules workflow       → cargar solo data/rules/workflow.md
```

### Paso 3 — Auditar DDL (`data/bigquery/{dataset_out}/{tabla_out}/ddl/`)

Para cada archivo `.sql` en `ddl/`:

**Verificar:**
- [ ] Usa `CREATE TABLE IF NOT EXISTS` (no `CREATE OR REPLACE TABLE`) — aplica a tablas finales output/master/business; las tablas `tmp_*` dentro de SPs pueden usar `CREATE OR REPLACE TABLE`
- [ ] La referencia de tabla usa **3 variables**: `${project_X}.${dataset_X}.${table_X}` (no `${project_analytics}.${dataset_analytics}.nombre_hardcodeado`)
- [ ] Tablas con prefijo `t_` o `tipo_carga: incremental` tienen `PARTITION BY` y `CLUSTER BY`
- [ ] Tiene campos de auditoría: `load_date`, `record_source`, `creation_user`
- [ ] Tiene `OPTIONS(description=..., labels=[...])`
- [ ] No contiene `DROP TABLE` ni `DROP SCHEMA`
- [ ] No contiene `ALTER TABLE DROP COLUMN`
- [ ] No contiene columnas nuevas en `CREATE TABLE IF NOT EXISTS` que deberían estar en `alter/` (si la tabla ya existe en prod — indicador: el DDL tiene más columnas que el spec original)
- [ ] Archivos en `alter/` siguen naming: `alter_{tabla_out}_YYYYMMDD_{NNN}.sql`
- [ ] Archivos en `alter/` solo contienen `ADD COLUMN IF NOT EXISTS` — nunca `DROP COLUMN`
- [ ] Archivos en `alter/` están registrados en `deploy_[env].json` bajo `bigquery_ddl` **después** del script CREATE TABLE de la misma tabla
- [ ] Naming de tabla sigue patrón: `ba_`, `t_`, `m_`, `tmp_`

```
VIOLATION [bigquery/ddl] ALTA: t_retail_transaction.sql — sin PARTITION BY (tabla de transacciones)
VIOLATION [bigquery/ddl] MEDIA: ba_itc_attr_retail.sql — falta OPTIONS(labels=[...])
```

### Paso 4 — Auditar SPs (`data/bigquery/{dataset_out}/{tabla_out}/sp/`)

Para cada archivo `.sql` en `sp/`:

**Verificar:**
- [ ] No contiene `SELECT *`
- [ ] No contiene valores hardcodeados de proyectos/datasets (buscar patrones como `prd-`, `dev-`, `.analytics.`, `.stored_procedures.`)
- [ ] Toda referencia a tabla usa 3 variables: `${project_X}.${dataset_X}.${table_X}` — incluye tablas tmp, aux y output dentro del SP
- [ ] `CREATE OR REPLACE TABLE` solo aparece para tablas `tmp_*` / `aux_*` en `${dataset_stage}`, nunca para tablas de output finales
- [ ] Tablas temporales usan `${dataset_stage}` (no `${dataset_analytics}`)
- [ ] No contiene `DROP TABLE`
- [ ] No contiene `DELETE FROM` sin `WHERE`
- [ ] Naming de SP: `sp_{proceso}` o `sp_dq_{tabla}`
- [ ] Cargas incrementales usan `MERGE` (no DELETE + INSERT)
- [ ] Cada regla de negocio del spec tiene comentario `-- [RN-ITC-NNN]`
- [ ] Cabecera de SP presente (descripción, parámetros, destino)

```
VIOLATION [bigquery/sp] ALTA: sp_prc_retail.sql — contiene SELECT *
VIOLATION [bigquery/sp] ALTA: sp_prc_retail.sql — valor hardcodeado: 'prd-itc-customer-services'
VIOLATION [bigquery/sp] MEDIA: sp_prc_retail.sql — RN-ITC-003 del spec sin comentario en SP
```

### Paso 5 — Auditar Workflows (`pipeline/workflow/`)

Para cada archivo `.yaml` en `workflow/`:

**Verificar:**
- [ ] El archivo NO contiene flags de cabecera (`name:`, `project:`, `region:`, `service_account:` fuera de `source:`)
- [ ] Primer step es `set_vars`
- [ ] `v_billing_project` presente en `set_vars`
- [ ] `email_body: {}` inicializado en `set_vars`
- [ ] Variables de negocio con prefijo `var_`
- [ ] No hay valores hardcodeados de proyectos/datasets/URLs
- [ ] **Si el workflow usa `var_process_date` o `process_date`:** existe bloque de normalización (`normalizar_args` / `decidir_fecha` / `usar_ayer` / `usar_param`) entre `set_vars` y el `try/except`
- [ ] **Si el workflow usa `var_process_date`:** ninguna variable dentro de `set_vars` se construye concatenando `var_process_date` — esas variables deben estar en un step separado posterior a la normalización (ej. `build_file_paths`)
- [ ] Toda invocación SP usa `SyncBigQueryJob` (no `googleapis.bigquery.v2.jobs.query` directo en main)
- [ ] Existe bloque `try/except`
- [ ] `except` tiene `next: enviar_mail` (o hace raise después de notificar)
- [ ] Step `verificar_email_body` presente
- [ ] `enviar_mail` usa `${mail_pubsub_project}` y `${mail_pubsub_topic}`
- [ ] Subworkflows `SyncBigQueryJob` y `BigQueryJobState` al final del archivo
- [ ] Cloud Run/CF usa `auth.type: OIDC`; APIs Google usa `auth.type: OAuth2`

```
VIOLATION [workflow] ALTA: wf-ingreso-vii-inference.yaml — falta bloque try/except
VIOLATION [workflow] ALTA: wf-ingreso-vii-inference.yaml — SP invocado directo sin SyncBigQueryJob
VIOLATION [workflow] ALTA: wf-demo-sales-pipeline.yaml — usa var_process_date pero falta bloque de normalización (normalizar_args/decidir_fecha/usar_ayer)
VIOLATION [workflow] ALTA: wf-demo-sales-pipeline.yaml — var_file_pe construida con var_process_date dentro de set_vars (debe ir en step separado post-normalización)
VIOLATION [workflow] MEDIA: wf-ingreso-vii-inference.yaml — falta step verificar_email_body
```

### Paso 6 — Auditar Deploy Configs

Para cada `deploy_[env].json` en `deploy/`:

**Verificar:**
- [ ] Existen los 3 archivos: `deploy_dev.json`, `deploy_qa.json`, `deploy_prd.json`
- [ ] `deploy_prd.json` no tiene entradas `bigquery_dml`
- [ ] Paths relativos comienzan con `/`
- [ ] Cloud Scheduler referenciado en `pipeline/scheduler/` (no `service/scheduler/`)

Para cada `deploy_config.yaml` de Vertex:

**Verificar:**
- [ ] No declara `PIPELINE_PROJECT_ID`, `PIPELINE_SERVICE_ACCOUNT`, `PIPELINE_REGION`, `PIPELINE_COMPILE_FILE` en `env_vars`
- [ ] SA referenciada via variable (`${service_account_job}`) — no hardcodeada
- [ ] Tiene los 4 bloques (framework vars, BQ inputs, GCS paths, hyperparams)

```
VIOLATION [dataops] ALTA: deploy_prd.json — contiene entradas bigquery_dml
VIOLATION [dataops] MEDIA: deploy_config.yaml — PIPELINE_PROJECT_ID declarado en env_vars (ya la inyecta el framework)
```

### Paso 7 — Auditar Seguridad

Revisar **todos** los archivos SQL, YAML y Python del proceso:

**Verificar:**
- [ ] No hay `DROP TABLE` en ningún archivo de producción
- [ ] No hay `DELETE FROM` sin `WHERE` en SPs de producción
- [ ] Campos PII del spec no persisten en outputs (buscar nombres de columnas: `tipo_doc`, `nro_doc`, `nombre`, `apellido`, `email`, `telefono`)
- [ ] No hay valores de SA hardcodeados (buscar `@dev-`, `@prd-`, `.iam.gserviceaccount.com`)
- [ ] No hay secrets o tokens en el código (buscar `password`, `api_key`, `token`, `AIzaSy`)

```
VIOLATION [security] CRÍTICA: sp_prc_retail.sql — contiene DROP TABLE en línea 45
VIOLATION [security] CRÍTICA: pipeline_inference.py — contiene valor hardcodeado de SA
```

### Paso 8 — Auditar Costo, Scan Safety y Observabilidad (Python pipelines)

> Aplica a módulos `vertex_ml` con scripts Python (`components.py`, `pipeline_inference.py`).
> Para módulos `bq_pipeline` puros (solo SQL), solo aplicar las verificaciones D y E.
>
> **Fuente externa:** `bigquery-pipeline-audit` skill
> **Repositorio:** `https://github.com/github/awesome-copilot`
> **Instalación local:** `npx skills add https://github.com/github/awesome-copilot --skill bigquery-pipeline-audit`
> **Para refrescar:** re-instalar el skill, leer el SKILL.md y actualizar este paso con secciones nuevas o modificadas.

#### A) Costo — maximum_bytes_billed

Revisar todo `client.query(...)` en scripts Python:

- [ ] Cada `client.query` tiene `QueryJobConfig(maximum_bytes_billed=N)` configurado
- [ ] Ninguna query BQ corre dentro de un loop por fecha o por entidad
- [ ] Si hay loop: worst-case de jobs BQ no supera 20

```
VIOLATION [cost] ALTA: components.py — client.query() sin maximum_bytes_billed en línea 45
VIOLATION [cost] CRÍTICA: pipeline_inference.py — query BQ dentro de loop por fecha (worst-case: N fechas × M retries jobs)
```

#### B) Modos dry-run / execute (Python scripts)

- [ ] El script tiene flag `--mode` con al menos `dry_run` y `execute`
- [ ] `dry_run` no ejecuta jobs reales ni llama APIs externas
- [ ] `execute` en `prod` requiere confirmación explícita (`--env=prod --confirm`)
- [ ] El default no es `prod`

#### C) Scan safety — filtros de partición

Revisar queries SQL en Python y en `sp/`:

- [ ] Filtros de partición sobre columna raw — no `DATE(ts)`, no `CAST(...)`
- [ ] Sin `SELECT *` — solo columnas usadas downstream
- [ ] JOINs no generan explosión de filas (claves únicas verificadas o acotadas)
- [ ] Operaciones costosas (`REGEXP`, `JSON_EXTRACT`, UDFs) corren **después** del filtro de partición

```
VIOLATION [scan] ALTA: sp_prc_retail.sql — WHERE DATE(transaction_ts) impide partition pruning
VIOLATION [scan] MEDIA: components.py — SELECT * en query de carga inicial
```

#### D) Idempotencia de escrituras

- [ ] Cada write usa `MERGE` con clave determinista, staging table, o `QUALIFY ROW_NUMBER() = 1`
- [ ] Sin `INSERT` / append plano sin lógica de deduplicación
- [ ] `WRITE_TRUNCATE` vs `WRITE_APPEND` es intencional y documentado
- [ ] Re-ejecución con misma fecha no duplica filas

#### E) Observabilidad (Python scripts)

- [ ] Cada BQ job loguea: job ID, bytes procesados, duración
- [ ] Existe `run_id` consistente en todos los logs del script
- [ ] No hay `except: pass` ni bloques que silencian errores
- [ ] Al finalizar se loguea un resumen: `run_id, env, mode, date_range, tables written, total BQ jobs`

```
VIOLATION [observability] MEDIA: components.py — except genérico sin re-raise en línea 89
VIOLATION [observability] BAJA: pipeline_inference.py — sin run_id en logs
```

### Paso 9 — Generar Reporte

```markdown
## Reporte de Compliance — [nombre-proceso] — [fecha]

### Resumen
| Severidad | Cantidad |
|---|---|
| CRÍTICA  | 0 |
| ALTA     | 2 |
| MEDIA    | 3 |
| BAJA     | 1 |

**Veredicto: ⚠️ FAIL — hay violaciones ALTAS que deben corregirse antes de RELEASE**

### Violaciones

#### ALTA
1. `data/bigquery/analytics/ba_itc_attr_retail/sp/sp_prc_retail.sql` línea 23 — `SELECT *` encontrado
   → Reemplazar con columnas explícitas

2. `data/bigquery/analytics/ba_itc_attr_retail/ddl/tmp_ba_itc_attr_retail_transaction.sql` — sin PARTITION BY
   → Tabla de transacciones requiere PARTITION BY + CLUSTER BY

#### MEDIA
3. `data/bigquery/analytics/ba_itc_attr_retail/ddl/ba_itc_attr_retail.sql` — falta OPTIONS(labels=[...])
   → Agregar labels: [("team", "data-platform"), ("env", "${env}")]

4. `pipeline/workflow/analytics/ba_itc_attr_retail/wf-ba-itc-attr-retail.yaml` — falta step verificar_email_body
   → Agregar antes de enviar_mail

5. `data/bigquery/analytics/ba_itc_attr_retail/sp/sp_prc_retail.sql` — RN-ITC-003 sin comentario
   → Agregar -- [RN-ITC-003] antes del bloque correspondiente

#### BAJA
6. `data/bigquery/analytics/ba_itc_attr_retail/sp/sp_prc_retail.sql` — falta cabecera de SP
   → Agregar comentario de cabecera con descripción y parámetros

### Archivos verificados
- data/bigquery/analytics/ba_itc_attr_retail/ddl/tmp_ba_itc_attr_retail_transaction.sql ❌
- data/bigquery/analytics/ba_itc_attr_retail/ddl/ba_itc_attr_retail.sql ⚠️
- data/bigquery/analytics/ba_itc_attr_retail/sp/sp_prc_retail.sql ❌
- pipeline/workflow/analytics/ba_itc_attr_retail/wf-ba-itc-attr-retail.yaml ⚠️
- deploy/deploy_dev.json ✅
- deploy/deploy_prd.json ✅
```

### Criterio de paso

| Resultado | Condición |
|---|---|
| ✅ PASS | 0 violaciones CRÍTICAS y 0 ALTAS |
| ⚠️ PASS con advertencias | 0 CRÍTICAS, 0 ALTAS, pero hay MEDIAS o BAJAS |
| ❌ FAIL | Al menos 1 CRÍTICA o ALTA |

**Si el resultado es FAIL**, el proceso vuelve a BUILD para correcciones antes de continuar a RELEASE.

---

## Invocación

```
/check-rules                    ← audita todas las reglas del proceso actual
/check-rules bigquery           ← solo reglas BigQuery
/check-rules security           ← solo reglas de seguridad
/check-rules workflow           ← solo reglas de workflow
/check-rules dataops            ← solo reglas Dataops
```
