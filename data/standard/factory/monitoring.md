# Estándar: Etapa MONITORING — Control de Procesos en Data Platform

> **Activado por:** `/data:implement-stage MONITORING`
> **Aplica a:** módulos `bq_pipeline` que orquestan SPs vía Cloud Workflows
> **Por defecto:** `monitoring: false` en `spec.yaml`
> **Dependencia:** requiere que el módulo `itcm-dp-dataops-api-metadata` (metadata API) esté desplegado
>   y accesible en el ambiente destino.

---

## 1. Qué es el Framework de Control de Procesos

El **Framework de Control de Procesos** es un sistema de registro y monitoreo de ejecuciones
de pipelines de datos. Compuesto por:

- **Cinco tablas PostgreSQL** (Cloud SQL): catálogo de procesos, catálogo de tareas, historial de
  ejecuciones, catálogo de reglas de integridad e historial de resultados de integridad
- **REST API** (módulo `pipeline-management` de la metadata Cloud Run): endpoints para crear y actualizar registros
- **Instrumentación en workflows**: sub-workflows que envuelven cada invocación de SP y registran su resultado

Cuando un workflow de datos tiene `monitoring: true`:
1. Al desplegarse: se matriculan el proceso (workflow) y sus tareas (SPs) vía API — ejecutado por Cloud Build
2. Al ejecutarse: el workflow registra el inicio, resultado y métricas de cada tarea en tiempo real

---

## 2. Cuándo activar `monitoring: true`

| Condición | Activar |
|---|---|
| `type: bq_pipeline` + tiene SPs que cargan tablas BigQuery + tiene Cloud Workflow | ✅ SÍ |
| `type: vertex_ml` + tiene Vertex Pipeline | ⬜ Futuro (no implementado) |
| `type: cloud_run_api` | ❌ NO — la API tiene su propio registro |
| `type: cloud_function` | ❌ NO |
| `bq_pipeline` sin workflow (solo Looker o análisis) | ❌ NO |

**Regla simple:** activar cuando el módulo tiene un Cloud Workflow que invoca SPs con `SyncBigQueryJob`.

---

## 3. Modelo de Datos — Tablas PostgreSQL

### `ct_datapipeline_process` — Catálogo de Procesos (uno por workflow)

| Campo | Tipo | Descripción |
|---|---|---|
| `code` | TEXT UNIQUE | = nombre del workflow en GCP (`GOOGLE_CLOUD_WORKFLOW_ID`) |
| `technical_name` | TEXT | nombre técnico del workflow (igual a `code`) |
| `zone_code` | TEXT | capa de datos: `stage` \| `master` \| `business` |
| `company_id` | TEXT | código numérico de empresa (ej: `"074"`) |
| `company_code` | TEXT | código alfanumérico (ej: `"ITC"`) |
| `business_name` | TEXT | nombre descriptivo del proceso |
| `flag_active` | TEXT | `"1"` activo / `"0"` inactivo |
| `flag_scheduler` | TEXT | `"1"` si tiene scheduler / `"0"` si no |
| `last_status_code` | TEXT | último estado: `PENDING` \| `RUNNING` \| `SUCCESS` \| `FAILED` |

### `ct_datapipeline_task` — Catálogo de Tareas (una por SP invocado)

| Campo | Tipo | Descripción |
|---|---|---|
| `code` | TEXT | FQN del SP: `{project}.{dataset}.{sp_name}` |
| `process_code` | TEXT FK | = `ct_datapipeline_process.code` |
| `object_catalog` | TEXT | proyecto BQ donde vive la tabla destino |
| `object_schema` | TEXT | dataset BQ de la tabla destino |
| `object_name` | TEXT | nombre de la tabla destino final (sin `tmp_`) |
| `object_type` | TEXT | `TABLE` \| `VIEW` |
| `object_source` | TEXT | FQN de la tabla fuente (JSON array) |

### `de_datapipeline_execution` — Historial de Ejecuciones

| Campo | Tipo | Descripción |
|---|---|---|
| `execution_id` | TEXT UNIQUE | = `GOOGLE_CLOUD_WORKFLOW_EXECUTION_ID` |
| `process_code` | TEXT | workflow que ejecutó la tarea |
| `task_code` | TEXT | FQN del SP ejecutado |
| `execution_status_code` | TEXT | `RUNNING` \| `SUCCESS` \| `FAILED` |
| `execution_data_read` | INTEGER | filas leídas (de OUT del SP) |
| `execution_data_write` | INTEGER | filas escritas (de OUT del SP) |
| `execution_data_duplicate` | INTEGER | filas duplicadas descartadas |
| `object_last_load_date` | TIMESTAMP | fecha de última carga (de OUT del SP) |
| `process_date_init` | DATE | fecha inicio del rango procesado |
| `process_date_end` | DATE | fecha fin del rango procesado |

### `ct_datapipeline_integrity_rule` — Catálogo de Reglas de Integridad (una por regla del spec)

| Campo | Tipo | Descripción |
|---|---|---|
| `code` | TEXT | `RI-[EMPRESA]-[TABLA]-NNN` — el `id` de la regla en `reglas_integridad` del spec |
| `process_code` | TEXT FK | = `ct_datapipeline_process.code` |
| `task_code` | TEXT | FQN del SP de integridad: `{project}.{dataset_sp}.sp_integridad_{tabla_out}` |
| `source_id` / `source_role` / `source_asset` | TEXT | fuente evaluada, su rol (`principal` \| `secundaria`) y su FQN |
| `check_type` | TEXT | `actualidad` \| `duplicados` \| `llave_nula` |
| `check_action` | TEXT | `detener_proceso` \| `excluir_registros` |
| `tolerance_days` / `key_columns` / `date_field` | INT / TEXT / TEXT | parámetros del check |
| `last_status_code` | TEXT | último resultado: `PASSED` \| `FAILED` |

### `de_datapipeline_integrity_execution` — Historial del Gate de Integridad

| Campo | Tipo | Descripción |
|---|---|---|
| `execution_id` | TEXT | = `GOOGLE_CLOUD_WORKFLOW_EXECUTION_ID` — **el mismo** de `de_datapipeline_execution` |
| `process_code` / `task_code` / `rule_code` | TEXT | proceso, SP de integridad y regla evaluada |
| `execution_date` / `process_date` | DATE | fecha de la corrida y fecha funcional evaluada |
| `integrity_status_code` | TEXT | `PASSED` \| `FAILED` |
| `flag_stop_process` | VARCHAR(1) | `"1"` si esa regla detuvo el proceso |
| `records_evaluated` / `records_affected` | BIGINT | volumetría de la evaluación |
| `stop_reason` | TEXT | motivo real de la regla (mismo texto del correo de detención) |

> Append-only, un registro por regla evaluada por corrida. Se escribe desde la etapa
> INTEGRIDAD, no desde MONITORING — ver `@.claude/data/standard/data-integrity.md` §6.
> Como comparte `execution_id`, el reporte de ejecución y control puede mostrar el gate en la
> misma línea de tiempo que las tareas del proceso.

---

## 4. API Endpoints del Framework

Base URL: `${METADATA_API_URL}` (variable en `env_[env].json`)

| Operación | Método | Path |
|---|---|---|
| Crear proceso | POST | `/api/v1/pipeline-management/pipelines/process-creation` |
| Actualizar estado proceso | PUT | `/api/v1/pipeline-management/pipelines/{process_code}/update` |
| Crear tarea | POST | `/api/v1/pipeline-management/pipelines/{process_code}/task-management` |
| Actualizar tarea | PUT | `/api/v1/pipeline-management/pipelines/{process_code}/task-management/{task_code}/update` |
| Crear ejecución | POST | `/api/v1/pipeline-management/pipelines/{process_code}/task-execution/creation` |
| Actualizar ejecución | PUT | `/api/v1/pipeline-management/pipelines/{process_code}/task-execution/{execution_id}/{task_code}/update_new` |
| Matricular regla de integridad | POST | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-rules` |
| Listar reglas de integridad | GET | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-rules` |
| Actualizar regla de integridad | PUT | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-rules/{rule_code}/update` |
| Registrar resultados del gate (bulk) | POST | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-execution/creation` |
| Último resultado por regla | GET | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-execution/status` |
| Consolidado de integridad (reporte) | GET | `/api/v1/pipeline-management/pipelines/{process_code}/integrity-execution/summary` |

> Los 6 endpoints de integridad los consume la etapa INTEGRIDAD (matrícula en deploy +
> `RegisterIntegrityResults` en runtime). Contratos completos:
> `@.claude/data/standard/data-integrity.md` §6 y
> `itcm-dp-dataops-api-metadata/docs/feature_spec/integrity_tracking/spec.md`.

---

## 5. Bloque `monitoring` en `spec.yaml`

Agregar a `spec.yaml` cuando `etapas.monitoring: true`:

```yaml
monitoring:
  METADATA_API_URL: "${METADATA_API_URL}"    # variable en env_[env].json

  process:
    code: "${workflow_name}"                  # = nombre del workflow en GCP
    zone_code: stage                          # stage | master | business
    company_id: "074"
    company_code: ITC
    business_name: ~                          # descripción legible del proceso
    flag_active: "1"
    flag_scheduler: "0"                       # "1" si tiene Cloud Scheduler

  tasks:
    - code: "${project_analytics}.${dataset_sp}.{sp_name}"
      object_catalog: "${project_analytics}"
      object_schema: "${dataset_analytics}"    # dataset destino final (sin tmp_)
      object_name: "{tabla_destino}"           # tabla destino (sin tmp_)
      object_type: TABLE
      object_source:
        - "${project_fuente}.${dataset_fuente}.{tabla_fuente}"
      description: ~
    # agregar un item por cada SP que invoca el workflow
```

---

## 6. Scripts de Matrícula — Etapa MONITORING

La matrícula se realiza **vía API REST con autenticación OIDC** durante el despliegue
con Cloud Build — no con inserts directos a PostgreSQL.

### Por qué usar APIs (no INSERT directo)

| Aspecto | API REST | INSERT directo |
|---|---|---|
| Acoplamiento | Solo necesita URL + OIDC token | Requiere credenciales DB, Cloud SQL Proxy |
| Idempotencia | La API maneja conflictos (upsert) | Requiere lógica ON CONFLICT propia |
| Evolución del schema | Transparente (backend absorbe cambios) | Rompe scripts al cambiar columnas |
| Seguridad | SA con `roles/run.invoker` | SA con acceso directo a DB |
| Observabilidad | Log en Cloud Run logs | Sin trazabilidad |

### Prerequisitos en `env_[env].json`

```json
// env_dev.json
{
  "METADATA_API_URL": "https://{dev-url-metadata-api}.us-central1.run.app"
}

// env_prd.json
{
  "METADATA_API_URL": "https://prd-itcbi-spld-run-usct1-pv01-947655304508.us-central1.run.app"
}
```

### Prerequisito IAM

El SA de Cloud Build (`trv-itcbi-devops-app@itc-data-devops-01.iam.gserviceaccount.com`)
debe tener `roles/run.invoker` sobre la metadata API.

### Estructura de archivos

```
data/monitoring/{dataset_out}/{tabla_out}/
└── payloads/
    ├── process_{tabla_out}_{emp}.json       ← un proceso por fuente/workflow — POST /pipelines/process-creation
    └── task_sp_{tabla_out}_{emp}.json       ← una tarea por SP/fuente — POST /task-management
```

> El nombre de archivo siempre se deriva de `{tabla_out}` (prefijo) y `{emp}` (sufijo) — nunca un
> slug libre. El campo interno `code`/`technical_name` sigue siendo el nombre real del workflow
> en GCP (`${env}-{tabla_out_kebab}-{emp}`, ver `@.claude/data/standard/factory/repositories.md`).
> El framework Dataops (`metadata_register.sh`) lee estas rutas desde `deploy_[env].json`,
> obtiene el token OIDC, clasifica cada payload por su contenido (`code` sin `process_code` =
> proceso; `process_code` presente = tarea) y llama a los endpoints en orden correcto.
> No se generan scripts `.sh` en el repositorio del módulo.

### Template: `payloads/process_{tabla_out}_{emp}.json`

```json
{
  "code": "{workflow_name}",
  "parent_code": null,
  "zone_code": "stage",
  "company_id": "074",
  "company_code": "ITC",
  "business_name": "{descripción del proceso}",
  "technical_name": "{workflow_name}",
  "execution_date": null,
  "flag_active": "1",
  "flag_reprocess": "0",
  "interval_months": null,
  "last_status_code": null,
  "execution_user": null,
  "creation_user": "dataops-deploy",
  "flag_scheduler": "0"
}
```

> Todos los campos del modelo `ProcessCreate` son requeridos por la API (Pydantic `Field(...)`),
> incluso los opcionales en negocio. Enviar `null` explícito para los que no apliquen al momento
> de la matrícula — no omitirlos.

### Template: `payloads/task_sp_{tabla_out}_{emp}.json`

```json
{
  "code": "{project}.{dataset_sp}.{sp_name}",
  "process_code": "{workflow_name}",
  "process_parent_code": null,
  "company_id": "074",
  "company_code": "ITC",
  "business_name": "{descripción de la tarea}",
  "technical_name": "{project}.{dataset_sp}.{sp_name}",
  "object_catalog": "{project_analytics}",
  "object_schema": "{dataset_analytics}",
  "object_name": "{tabla_destino_final}",
  "object_type": "TABLE",
  "object_source": ["{project_fuente}.{dataset_fuente}.{tabla_fuente}"],
  "flag_active": "1",
  "last_status_code": null,
  "flag_reprocess": "0",
  "creation_user": "dataops-deploy"
}
```

> Los campos `process_parent_code`, `last_status_code` y `flag_reprocess` son requeridos por
> el modelo `TaskCreate` (Pydantic `Field(...)`). Enviar `null` para los que no apliquen —
> no omitirlos o la API retorna error 422.

### Integración en `deploy_[env].json`

```json
{
  "bigquery_ddl":  [...],
  "bigquery_sp":   [...],
  "workflow":      [...],
  "cloud_scheduler": [...],
  "monitoring_register": [
    "/data/monitoring/{dataset_out}/{tabla_out}/payloads"
  ]
}
```

> `monitoring_register` se ejecuta **después de `cloud_scheduler`** en la cadena de Cloud Build.
> La entrada puede ser un directorio (procesa todos los `.json`) o un archivo individual.
> El framework detecta el tipo de payload por contenido: `check_type` presente → regla de
> integridad; `process_code` presente → tarea; solo `code` → proceso. Orden garantizado:
> procesos primero, luego tareas y reglas de integridad.
>
> Si el módulo tiene `etapas.integridad: true`, su directorio
> `data/integrity/{dataset_out}/{tabla_out}/payloads` se agrega a la misma clave, después del
> de monitoring — ver `@.claude/data/standard/data-integrity.md` §6.3.

---

## 7. Modificaciones al Cloud Workflow

Cuando `etapas.monitoring: true`, el workflow generado en etapa ORCHESTRATION debe extenderse
con los siguientes cambios:

### 7.1 — Variables adicionales en `set_vars`

Agregar al bloque `set_vars` existente:

```yaml
# --- MONITORING ---
- var_METADATA_API_URL: ${METADATA_API_URL}      # desde env_[env].json
- var_process_code: ${sys.get_env("GOOGLE_CLOUD_WORKFLOW_ID")}
- var_execution_id: ${sys.get_env("GOOGLE_CLOUD_WORKFLOW_EXECUTION_ID")}
- var_execution_date: ${text.substring(time.format(sys.now(), "America/Lima"), 0, 10)}
- var_user: ${sys.get_env("GOOGLE_CLOUD_SERVICE_ACCOUNT_NAME")}
- var_process_flag_active: "1"
- var_process_flag_reprocess: "0"
- var_process_flag_scheduler: "0"          # "1" si tiene Cloud Scheduler
- var_execution_type: "NORMAL"
# acumuladores de métricas (valor inicial)
- execution_data_read: 0
- execution_data_write: 0
- object_last_load_date: null
```

### 7.2 — Construir query con OUT parameters

Reemplazar el `build_sql_*` estándar por la versión con DECLARE + SELECT de métricas:

```yaml
# ANTES (sin monitoring):
- build_sql_sp_nombre_p1:
    assign:
      - sql_sp_nombre_p1: ${"CALL `" + var_sp_nombre + "`("
          + "DATE '" + var_process_date_init + "'"
          + ", '" + var_proyecto + "'"
          + ")"}

# DESPUÉS (con monitoring — agregar DECLARE + SELECT al final):
- build_sql_sp_nombre_p1:
    assign:
      - sql_sp_nombre_p1: ${"DECLARE v_read INT64 DEFAULT 0; "
          + "DECLARE v_write INT64 DEFAULT 0; "
          + "CALL `" + var_sp_nombre + "`("
          + "DATE '" + var_process_date_init + "'"
          + ", '" + var_proyecto + "'"}

- build_sql_sp_nombre_p2:
    assign:
      - sql_sp_nombre_p2: ${", v_read"
          + ", v_write"
          + "); "
          + "SELECT "
          + "v_read AS execution_data_read, "
          + "v_write AS execution_data_write"}

- build_sql_sp_nombre:
    assign:
      - query_sp_nombre: ${sql_sp_nombre_p1 + sql_sp_nombre_p2}
```

> **Regla de los 7 segmentos:** Cloud Workflows limita a 7 variables por `assign`.
> Dividir el build en partes `_p1`, `_p2`, `_p3` si se excede.

### 7.3 — Reemplazar `SyncBigQueryJob` por `TrackedBigQueryJobWithResults`

Dentro del bloque `try`, reemplazar cada llamada `SyncBigQueryJob` por `TrackedBigQueryJobWithResults`.

El SP retorna solo `execution_data_read` y `execution_data_write` (2 columnas del SELECT final).
El sub-workflow calcula `object_last_load_date = sys.now()` internamente.
`execution_data_duplicate` **ya no se envía a la API** — solo `read` y `write`.

```yaml
# ANTES (sin monitoring):
- exec_sp_nombre:
    call: SyncBigQueryJob
    args:
      query: ${query_sp_nombre}
      project_id: ${v_billing_project}
    result: result_sp_nombre

# DESPUÉS (con monitoring):
- exec_sp_nombre_tracked:
    call: TrackedBigQueryJobWithResults
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_id: ${var_execution_id}
      task_code: ${var_sp_nombre}          # FQN del SP
      execution_type: ${var_execution_type}
      process_date_init: ${var_process_date_init}
      process_date_end: ${var_process_date_end}
      user: ${var_user}
      query: ${query_sp_nombre}
      project_id: ${v_billing_project}
    result: tracked_result_sp_nombre

# El result contiene los 4 valores: read y write (del SP) + duplicate y last_load_date (calculados en el WF)
- set_metricas_sp_nombre:
    assign:
      - execution_data_read: ${tracked_result_sp_nombre.execution_data_read}
      - execution_data_write: ${tracked_result_sp_nombre.execution_data_write}
      - object_last_load_date: ${tracked_result_sp_nombre.object_last_load_date}
```

### 7.4 — `UpdateProcessStatus` al final del try y en el except

Al final del bloque `try` (antes de `notificar_ok`) y en el `except`:

```yaml
# En el try — después del último SP:
- update_process_success:
    call: UpdateProcessStatus
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_date: ${var_execution_date}
      status: "SUCCESS"
      user: ${var_user}
      flag_active: ${var_process_flag_active}
      flag_reprocess: ${var_process_flag_reprocess}
      flag_scheduler: ${var_process_flag_scheduler}
    result: process_success_response

# En el except — después del log_error:
- update_process_failed:
    call: UpdateProcessStatus
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_date: ${var_execution_date}
      status: "FAILED"
      user: ${var_user}
      flag_active: ${var_process_flag_active}
      flag_reprocess: ${var_process_flag_reprocess}
      flag_scheduler: ${var_process_flag_scheduler}
    result: process_failed_response
```

### 7.5 — `MainResponse` extendido

Agregar las métricas al objeto de retorno del workflow:

```yaml
- MainResponse:
    return:
      status: "SUCCESS"
      process_code: ${var_process_code}
      execution_id: ${var_execution_id}
      process_date_init: ${var_process_date_init}
      process_date_end: ${var_process_date_end}
      execution_data_read: ${execution_data_read}
      execution_data_write: ${execution_data_write}
      object_last_load_date: ${object_last_load_date}
```

---

## 8. Sub-Workflows Requeridos

Cuando `monitoring: true`, agregar estos sub-workflows al archivo YAML del workflow
(después del `BigQueryJobState` existente):

### `TrackedBigQueryJobWithResults`

Encapsula el ciclo completo: crear ejecución (RUNNING) → ejecutar SP → actualizar ejecución (SUCCESS/FAILED).

```yaml
TrackedBigQueryJobWithResults:
  params:
    - api_url
    - process_code
    - execution_id
    - task_code
    - execution_type
    - process_date_init
    - process_date_end
    - user
    - query
    - project_id
  steps:
    - create_execution_running:
        call: CreateExecution
        args:
          api_url: ${api_url}
          process_code: ${process_code}
          execution_id: ${execution_id}
          task_code: ${task_code}
          execution_type: ${execution_type}
          execution_status_code: "RUNNING"
          execution_data_read: 0
          execution_data_write: 0
          process_date_init: ${process_date_init}
          process_date_end: ${process_date_end}
          user: ${user}
        result: create_execution_response

    - ejecutar_bigquery:
        try:
          steps:
            - execute_query:
                call: SyncBigQueryJobWithResults
                args:
                  query: ${query}
                  project_id: ${project_id}
                result: sp_result

            - set_metrics:
                assign:
                  - execution_data_read: ${int(sp_result.rows[0].f[0].v)}
                  - execution_data_write: ${int(sp_result.rows[0].f[1].v)}
                  - object_last_load_date: ${text.substring(time.format(sys.now(), "America/Lima"), 0, 19)}

            - update_execution_success:
                call: UpdateExecution
                args:
                  api_url: ${api_url}
                  process_code: ${process_code}
                  execution_id: ${execution_id}
                  task_code: ${task_code}
                  object_last_load_date: ${object_last_load_date}
                  execution_type: ${execution_type}
                  execution_status_code: "SUCCESS"
                  execution_data_read: ${execution_data_read}
                  execution_data_write: ${execution_data_write}
                              process_date_init: ${process_date_init}
                  process_date_end: ${process_date_end}
                  user: ${user}
                result: update_execution_success_response

            - return_success:
                return:
                  status: "SUCCESS"
                  execution_data_read: ${execution_data_read}
                  execution_data_write: ${execution_data_write}
                              object_last_load_date: ${object_last_load_date}
                  bq_result: ${sp_result}

        except:
          as: e
          steps:
            - update_execution_failed:
                call: UpdateExecution
                args:
                  api_url: ${api_url}
                  process_code: ${process_code}
                  execution_id: ${execution_id}
                  task_code: ${task_code}
                  object_last_load_date: null
                  execution_type: ${execution_type}
                  execution_status_code: "FAILED"
                  execution_data_read: 0
                  execution_data_write: 0
                  process_date_init: ${process_date_init}
                  process_date_end: ${process_date_end}
                  user: ${user}
                result: update_execution_failed_response

            - raise_error:
                raise: ${e}
```

### `CreateExecution`

```yaml
CreateExecution:
  params:
    - api_url
    - process_code
    - execution_id
    - task_code
    - execution_type
    - execution_status_code
    - execution_data_read
    - execution_data_write
    - process_date_init
    - process_date_end
    - user
  steps:
    - call_api:
        call: http.post
        args:
          url: ${api_url + "/api/v1/pipeline-management/pipelines/" + process_code + "/task-execution/creation"}
          auth:
            type: OIDC
            audience: ${api_url}
          body:
            execution_id: ${execution_id}
            process_code: ${process_code}
            task_code: ${task_code}
            object_last_load_date: null
            execution_type: ${execution_type}
            execution_status_code: ${execution_status_code}
            execution_data_read: ${execution_data_read}
            execution_data_write: ${execution_data_write}
                  creation_user: ${user}
            process_date_init: ${process_date_init}
            process_date_end: ${process_date_end}
        result: api_response

    - return_response:
        return: ${api_response.body}
```

### `UpdateExecution`

```yaml
UpdateExecution:
  params:
    - api_url
    - process_code
    - execution_id
    - task_code
    - object_last_load_date
    - execution_type
    - execution_status_code
    - execution_data_read
    - execution_data_write
    - process_date_init
    - process_date_end
    - user
  steps:
    - call_api:
        call: http.put
        args:
          url: ${api_url + "/api/v1/pipeline-management/pipelines/" + process_code + "/task-execution/" + execution_id + "/" + task_code + "/update_new"}
          auth:
            type: OIDC
            audience: ${api_url}
          body:
            execution_id: ${execution_id}
            process_code: ${process_code}
            task_code: ${task_code}
            object_last_load_date: ${object_last_load_date}
            execution_type: ${execution_type}
            execution_status_code: ${execution_status_code}
            execution_data_read: ${execution_data_read}
            execution_data_write: ${execution_data_write}
                  process_date_init: ${process_date_init}
            process_date_end: ${process_date_end}
            update_user: ${user}
        result: api_response

    - return_response:
        return: ${api_response.body}
```

### `UpdateProcessStatus`

```yaml
UpdateProcessStatus:
  params:
    - api_url
    - process_code
    - execution_date
    - status
    - user
    - flag_active
    - flag_reprocess
    - flag_scheduler
  steps:
    - call_api:
        call: http.put
        args:
          url: ${api_url + "/api/v1/pipeline-management/pipelines/" + process_code + "/update"}
          auth:
            type: OIDC
            audience: ${api_url}
          body:
            execution_date: ${execution_date}
            flag_active: ${flag_active}
            flag_reprocess: ${flag_reprocess}
            last_status_code: ${status}
            execution_user: ${user}
            update_user: ${user}
            flag_scheduler: ${flag_scheduler}
        result: api_response

    - return_response:
        return: ${api_response.body}
```

### `SyncBigQueryJobWithResults`

Versión extendida de `SyncBigQueryJob` que retorna los resultados del query (necesario para leer los OUT del SP):

```yaml
SyncBigQueryJobWithResults:
  params: [query, project_id]
  steps:
    - JobQuery:
        call: googleapis.bigquery.v2.jobs.query
        args:
          projectId: ${project_id}
          body:
            query: ${query}
            useLegacySql: false
            timeoutMs: 1000
        result: jobQueryResponse

    - JobWait:
        call: BigQueryJobState
        args:
          job_id: ${jobQueryResponse.jobReference.jobId}
          project_id: ${project_id}
        result: jobGetResponse

    - GetResults:
        call: googleapis.bigquery.v2.jobs.getQueryResults
        args:
          projectId: ${project_id}
          jobId: ${jobQueryResponse.jobReference.jobId}
          maxResults: 10
        result: queryResults

    - Return:
        return: ${queryResults}
```

> `SyncBigQueryJob` (sin results) sigue presente para SPs sin monitoring.
> `SyncBigQueryJobWithResults` y `BigQueryJobState` son compartidos entre ambos.

### `RegisterIntegrityResults` (etapa INTEGRIDAD)

Si el módulo tiene `etapas.integridad: true`, el workflow lleva además el sub-workflow
`RegisterIntegrityResults` — un `http.post` con OIDC al endpoint
`/integrity-execution/creation` que persiste el resultado del gate. A diferencia de
`TrackedBigQueryJobWithResults`, atrapa su propio error y loguea `WARNING` sin propagarlo: el
registro nunca debe romper el pipeline. Definición completa:
`@.claude/data/standard/data-integrity.md` §6.4.

---

## 9. Modificaciones al Stored Procedure

Todo SP invocado por un workflow con `monitoring: true` debe:

### 9.1 — Agregar 2 parámetros OUT al final de la firma

```sql
CREATE OR REPLACE PROCEDURE `${project_analytics}.${dataset_sp}.sp_{nombre}` (
  -- Parámetros IN existentes (no cambiar):
  IN p_project_source  STRING,
  IN p_dataset_source  STRING,
  IN p_table_source    STRING,
  IN p_project_target  STRING,
  IN p_dataset_target  STRING,
  IN p_table_target    STRING,
  IN p_process_date    DATE,
  -- Parámetros OUT de métricas (agregar al final):
  OUT o_execution_data_read   INT64,
  OUT o_execution_data_write  INT64
)
```

> Solo 2 parámetros OUT. `object_last_load_date` lo calcula el workflow con `sys.now()`.
> `execution_data_duplicate` ya no se envía a la API.
>
> Los OUT van **siempre al final** para no romper los CALLs existentes
> que pasan argumentos posicionalmente.

### 9.2 — Capturar métricas después del último INSERT

El orden es: primero `write` con `@@row_count` inmediatamente después del `EXECUTE IMMEDIATE`,
luego `read` con COUNT de la tabla temporal que alimentó ese INSERT.

```sql
-- Último INSERT del SP:
EXECUTE IMMEDIATE v_sql;
SET o_execution_data_write = @@row_count;  -- filas insertadas por este INSERT

-- Después del write, contar filas en la tmp que fue la fuente del INSERT:
EXECUTE IMMEDIATE CONCAT('SELECT COUNT(1) FROM `', v_path_tmp_{tabla}_final, '`')
  INTO o_execution_data_read;
```

> `@@row_count` captura exactamente las filas afectadas por el `EXECUTE IMMEDIATE` inmediato anterior.
> Siempre colocarlo en la línea siguiente al `EXECUTE IMMEDIATE` del último INSERT — nunca separado por otro statement.
>
> `execution_data_duplicate` y `object_last_load_date` **no se calculan en el SP**.
> `object_last_load_date` lo calcula el workflow con `sys.now()`.
> `execution_data_duplicate` ya no se envía a la API.

### 9.3 — Inicializar OUT al inicio del SP

```sql
-- Al inicio del cuerpo del SP (después de TODOS los DECLARE):
SET o_execution_data_read  = 0;
SET o_execution_data_write = 0;
```

> ⚠️ **Orden crítico:** BigQuery requiere que **todos los `DECLARE` precedan a cualquier `SET`**
> dentro del bloque `BEGIN`. Al agregar estos `SET` a un SP existente, colocarlos siempre
> **después** del último `DECLARE` del SP, no al inicio absoluto del cuerpo.
> Ver regla completa: `data/rules/bigquery.md` — "DECLARE siempre antes de cualquier SET"

---

## 10. Variables en `env_[env].json`

Agregar cuando `monitoring: true`:

```json
// env_dev.json
{
  "METADATA_API_URL": "https://{dev-url-metadata-api}.us-central1.run.app"
}

// env_prd.json
{
  "METADATA_API_URL": "https://prd-itcbi-spld-run-usct1-pv01-947655304508.us-central1.run.app"
}
```

---

## 11. Checklist de la etapa MONITORING

### Matrícula (deploy time)
- [ ] `data/monitoring/{dataset_out}/{tabla_out}/payloads/process_{tabla_out}_{emp}.json` creado con datos reales (uno por fuente)
- [ ] `data/monitoring/{dataset_out}/{tabla_out}/payloads/task_sp_{tabla_out}_{emp}.json` creado por cada SP del workflow
- [ ] `deploy_dev.json` contiene clave `monitoring_register` apuntando al directorio de payloads
- [ ] `env_dev.json` contiene `METADATA_API_URL`
- [ ] SA de Cloud Build tiene `roles/run.invoker` sobre la metadata API

### Instrumentación workflow
- [ ] Variables de monitoring en `set_vars` (`var_process_code`, `var_execution_id`, `var_user`, etc.)
- [ ] `build_sql_*` usa versión con `DECLARE v_read/v_write/v_duplicate/v_last_load` + `SELECT ... AS execution_data_*`
- [ ] Cada `SyncBigQueryJob` reemplazado por `TrackedBigQueryJobWithResults` + `set_metricas_*`
- [ ] `UpdateProcessStatus` llamado con `"SUCCESS"` al final del try
- [ ] `UpdateProcessStatus` llamado con `"FAILED"` en el except
- [ ] `MainResponse` incluye `execution_data_read/write/duplicate` y `object_last_load_date`
- [ ] Sub-workflows agregados: `TrackedBigQueryJobWithResults`, `CreateExecution`, `UpdateExecution`, `UpdateProcessStatus`, `SyncBigQueryJobWithResults`

### Stored Procedures
- [ ] Firma del SP tiene 4 parámetros OUT al final
- [ ] OUT inicializados al inicio del cuerpo
- [ ] `o_execution_data_read` asignado antes del INSERT
- [ ] `o_execution_data_write` asignado después del INSERT
- [ ] `object_last_load_date` calculado en el workflow con `sys.now()` (no en el SP)
- [ ] `execution_data_duplicate` NO se envía a la API

---

## 12. Referencia cruzada

- `@data/standard/services/workflow.md` — estructura base del workflow (SyncBigQueryJob, try/except)
- `@data/skills/build/orchestration/workflow-orchestration/SKILL.md` — patrones de orquestación
- `@data/skills/build/dataops/dataops-configurator/SKILL.md` — clave `monitoring_register` en deploy JSON
- Framework de control: `D:\workspace\google\cloud_sdk\source_repositories\dataops\itcm-dp-dataops-api-metadata`
- Demo de referencia: `...itcm-dp-dataops-api-metadata/data/demo-pipeline-con-framework-control/`
