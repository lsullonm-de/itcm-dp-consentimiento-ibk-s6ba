# Skill: Process Monitor

> **Rol:** Instrumentador de Control de Procesos — ITC Data Platform
> **Activado por:** `/data:implement-stage MONITORING`
> **Aplica a:** módulos `bq_pipeline` con Cloud Workflow que invoca SPs
> **Condición de activación:** `etapas.monitoring: true` en `spec.yaml`
>
> **Estándar de referencia:**
> - `@.claude/data/standard/factory/monitoring.md` — modelo de datos, API endpoints, templates completos
>
> Este skill es **independiente de DATAOPS y ORCHESTRATION**. Puede ejecutarse
> en cualquier orden tras ORCHESTRATION, pero debe ejecutarse antes de hacer el primer
> despliegue con Cloud Build para que la matrícula ocurra al deployar.

---

## 1. Rol y Responsabilidades

El **Process Monitor** instrumenta el módulo para que cada ejecución del pipeline quede
registrada en el framework de control de procesos:

| Responsabilidad | Artefacto que genera |
|---|---|
| Matrícula en deploy time | Payloads JSON en `data/monitoring/{dataset_out}/{tabla_out}/payloads/` |
| Instrumentación del workflow | Modifica `pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml` |
| Firma de SPs con métricas | Modifica `data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql` |
| Config del deploy JSON | Agrega clave `monitoring_register` en `deploy/deploy_[env].json` |
| Variable de entorno | Agrega `METADATA_API_URL` en `deploy/env_[env].json` |

---

## Paso 0 — Leer contexto del módulo

Leer en paralelo:

```
1. {ruta del spec.yaml}                                              → bloque monitoring, componentes, scheduling
2. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml             → variables actuales, SPs invocados, estructura try/except
3. data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql                  → firma de cada SP (parámetros IN actuales)
4. deploy/deploy_dev.json                                            → estructura actual
5. deploy/env_dev.json                                               → variables disponibles
```

---

## Paso 1 — Verificar prerequisitos

Antes de generar cualquier artefacto, verificar:

| Prerequisito | Cómo verificar |
|---|---|
| `etapas.monitoring: true` en spec | Leer spec.yaml → bloque etapas |
| Bloque `monitoring:` en spec con `METADATA_API_URL` | Leer spec.yaml → bloque monitoring |
| `pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml` existe (etapa ORCHESTRATION completada) | Glob pipeline/workflow/{dataset_out}/{tabla_out}/ |
| SPs en `data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql` existen | Glob data/bigquery/{dataset_out}/{tabla_out}/sp/ |

Si falta algún prerequisito → reportar qué falta y detener.

---

## Paso 2 — Generar payloads de matrícula

Crear la estructura `data/monitoring/{dataset_out}/{tabla_out}/payloads/` con los payloads JSON.

> El framework Dataops (`metadata_register.sh`) maneja la autenticación OIDC y las llamadas
> a la API en deploy time — clasifica cada payload por su contenido y llama al endpoint
> correspondiente. El skill solo genera los payloads JSON.

### 2.1 — Leer datos del bloque `monitoring:` del spec

Extraer:
- `monitoring.process.code` → nombre del workflow (= `process_code`)
- `monitoring.process.*` → campos del payload de proceso
- `monitoring.tasks[]` → uno por SP, con `code`, `object_name`, `object_source`, etc.
- `monitoring.METADATA_API_URL` → variable de entorno a usar

### 2.2 — Crear payloads JSON

> Con la regla "un Workflow por fuente" (ver `workflow-orchestration/SKILL.md` Paso 0.5), cada
> fuente `{emp}` tiene su propio proceso y su propia tarea — no se comparte un único proceso
> entre varias fuentes.

Para cada task en `monitoring.tasks[]`, crear `data/monitoring/{dataset_out}/{tabla_out}/payloads/
task_sp_{tabla_out}_{emp}.json`:

```json
{
  "code": "{project_analytics}.{dataset_sp}.{sp_name}",
  "process_code": "{workflow_name}",
  "process_parent_code": null,
  "company_id": "{monitoring.process.company_id}",
  "company_code": "{monitoring.process.company_code}",
  "business_name": "{task.description}",
  "technical_name": "{project_analytics}.{dataset_sp}.{sp_name}",
  "object_catalog": "{project_analytics}",
  "object_schema": "{dataset_analytics}",
  "object_name": "{task.object_name}",
  "object_type": "TABLE",
  "object_source": ["{task.object_source[0]}"],
  "flag_active": "1",
  "last_status_code": null,
  "flag_reprocess": "0",
  "creation_user": "dataops-deploy"
}
```

> `process_parent_code`, `last_status_code` y `flag_reprocess` son requeridos por el modelo
> `TaskCreate` (Pydantic `Field(...)`). Enviar `null` — no omitir estos campos o la API retorna 422.

Crear `data/monitoring/{dataset_out}/{tabla_out}/payloads/process_{tabla_out}_{emp}.json` (uno por fuente/workflow):

```json
{
  "code": "{monitoring.process.code}",
  "parent_code": null,
  "zone_code": "{monitoring.process.zone_code}",
  "company_id": "{monitoring.process.company_id}",
  "company_code": "{monitoring.process.company_code}",
  "business_name": "{monitoring.process.business_name}",
  "technical_name": "{monitoring.process.code}",
  "execution_date": null,
  "flag_active": "{monitoring.process.flag_active}",
  "flag_reprocess": "0",
  "interval_months": null,
  "last_status_code": null,
  "execution_user": null,
  "creation_user": "dataops-deploy",
  "flag_scheduler": "{monitoring.process.flag_scheduler}"
}
```

> Todos los campos de `ProcessCreate` son requeridos (Pydantic `Field(...)`). Enviar `null`
> para `parent_code`, `execution_date`, `interval_months`, `last_status_code`, `execution_user`.

---

## Paso 3 — Actualizar `deploy/deploy_[env].json`

Agregar la clave `monitoring_register` **al final** del JSON existente:

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
> El framework (`metadata_register.sh`) detecta el tipo de cada payload por contenido y llama
> al endpoint correspondiente — procesos primero, tareas después.

---

## Paso 4 — Actualizar `deploy/env_[env].json`

Agregar si no existe:

```json
{
  "METADATA_API_URL": "{monitoring.METADATA_API_URL}"
}
```

---

## Paso 5 — Modificar el Cloud Workflow

Abrir cada `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml` (uno por
fuente) y aplicar las modificaciones indicadas en
`@.claude/data/standard/factory/monitoring.md` — Secciones 7 y 8.

### Resumen de cambios al workflow

**En `set_vars` — agregar al final del bloque:**
```yaml
# --- MONITORING ---
- var_METADATA_API_URL: ${METADATA_API_URL}
- var_process_code: ${sys.get_env("GOOGLE_CLOUD_WORKFLOW_ID")}
- var_execution_id: ${sys.get_env("GOOGLE_CLOUD_WORKFLOW_EXECUTION_ID")}
- var_execution_date: ${text.substring(time.format(sys.now(), "America/Lima"), 0, 10)}
- var_user: ${sys.get_env("GOOGLE_CLOUD_SERVICE_ACCOUNT_NAME")}
- var_process_flag_active: "1"
- var_process_flag_reprocess: "0"
- var_process_flag_scheduler: "{monitoring.process.flag_scheduler}"
- var_execution_type: "NORMAL"
- execution_data_read: 0
- execution_data_write: 0
- object_last_load_date: null
```

**En cada `build_sql_*` — envolver el CALL con DECLARE + SELECT (2 variables):**

```yaml
- build_sql_sp_nombre_p1:
    assign:
      - sql_sp_nombre_p1: ${"DECLARE v_read INT64 DEFAULT 0; "
          + "DECLARE v_write INT64 DEFAULT 0; "
          + "CALL `" + var_sp_nombre + "`("
          + "DATE '" + var_process_date_init + "'"
          + ", '" + var_param_n + "'"}

- build_sql_sp_nombre_p2:
    assign:
      - sql_sp_nombre_p2: ${", v_read, v_write); "
          + "SELECT v_read AS execution_data_read, "
          + "v_write AS execution_data_write"}

- build_sql_sp_nombre:
    assign:
      - query_sp_nombre: ${sql_sp_nombre_p1 + sql_sp_nombre_p2}
```

> El SP expone solo 2 OUT params (`o_execution_data_read`, `o_execution_data_write`).
> `execution_data_duplicate` y `object_last_load_date` los calcula el sub-workflow
> `TrackedBigQueryJobWithResults` internamente — no vienen del SP.

**En cada `exec_*` dentro del try — reemplazar `SyncBigQueryJob` por `TrackedBigQueryJobWithResults`:**
- Cambiar `call: SyncBigQueryJob` → `call: TrackedBigQueryJobWithResults`
- Agregar args: `api_url`, `process_code`, `execution_id`, `task_code`, `execution_type`, `process_date_init`, `process_date_end`, `user`
- Agregar step `set_metricas_*` — los 4 campos están disponibles en el result (2 del SP + 2 calculados en WF):

```yaml
- set_metricas_sp_nombre:
    assign:
      - execution_data_read: ${tracked_result.execution_data_read}
      - execution_data_write: ${tracked_result.execution_data_write}
      - object_last_load_date: ${tracked_result.object_last_load_date}
```

**Al final del `try` (antes de `notificar_ok`) — agregar:**
```yaml
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
```

**En el `except` (después de `log_error`) — agregar:**
```yaml
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

**En `MainResponse` — extender con métricas:**
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

**Al final del archivo — agregar sub-workflows** (copiar desde `monitoring.md` Sección 8):
`TrackedBigQueryJobWithResults`, `CreateExecution`, `UpdateExecution`,
`UpdateProcessStatus`, `SyncBigQueryJobWithResults`

> `SyncBigQueryJob` y `BigQueryJobState` ya existen — NO duplicar.

---

## Paso 6 — Modificar los Stored Procedures

Para cada SP en `data/bigquery/{dataset_out}/{tabla_out}/sp/` invocado por su workflow, aplicar los cambios
indicados en `@.claude/data/standard/factory/monitoring.md` — Sección 9.

### Resumen de cambios al SP

**1. Agregar 2 parámetros OUT al final de la firma:**
```sql
OUT o_execution_data_read   INT64,
OUT o_execution_data_write  INT64
```

**2. Inicializar OUT al inicio del cuerpo (después de todos los `DECLARE`):**
```sql
SET o_execution_data_read  = 0;
SET o_execution_data_write = 0;
```

> ⚠️ Todos los `DECLARE` del SP deben ir antes de estos `SET`. Ver regla en `data/rules/bigquery.md`.

**3. Capturar `write` con `@@row_count` inmediatamente después del último `EXECUTE IMMEDIATE`:**
```sql
EXECUTE IMMEDIATE v_sql;                       -- último INSERT del SP
SET o_execution_data_write = @@row_count;      -- filas insertadas por ese INSERT
```

**4. Capturar `read` con COUNT de la tmp fuente del último INSERT (después del write):**
```sql
EXECUTE IMMEDIATE CONCAT('SELECT COUNT(1) FROM `', v_path_tmp_{tabla}_final, '`')
  INTO o_execution_data_read;
```

> `execution_data_duplicate` y `object_last_load_date` **no se calculan en el SP**.
> El workflow calcula `object_last_load_date = sys.now()`.
> `execution_data_duplicate` no se envía a la API.

---

## Paso 7 — Reporte de etapa

```
## Etapa completada: MONITORING
SPEC: {id}  |  type: {type}  |  módulo: {nombre}

### Artefactos generados
- ✅ data/monitoring/{dataset_out}/{tabla_out}/payloads/process_{tabla_out}_{emp}.json  (uno por fuente)
- ✅ data/monitoring/{dataset_out}/{tabla_out}/payloads/task_sp_{tabla_out}_{emp}.json  (uno por SP/fuente)
- ✅ deploy/deploy_dev.json — clave monitoring_register agregada
- ✅ deploy/env_dev.json — METADATA_API_URL agregada

### Artefactos modificados
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml  (uno por fuente)
    Variables monitoring en set_vars
    SPs instrumentados con TrackedBigQueryJobWithResults: {lista de SPs}
    UpdateProcessStatus en try y except
    Sub-workflows agregados: TrackedBigQueryJobWithResults, CreateExecution, UpdateExecution, UpdateProcessStatus, SyncBigQueryJobWithResults
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql  (uno por SP modificado)
    Parámetros OUT agregados
    Métricas capturadas

### Prerequisito IAM (acción manual)
- ⬜ SA de Cloud Build debe tener roles/run.invoker sobre la metadata API
  SA: trv-itcbi-devops-app@itc-data-devops-01.iam.gserviceaccount.com
  Recurso: {METADATA_API_URL}

### Próxima etapa sugerida
/data:implement-stage COMPLIANCE {id_modulo}
```

---

## Checklist de calidad

- [ ] Bloque `monitoring:` en spec tiene `process.code` y al menos 1 tarea
- [ ] `data/monitoring/{dataset_out}/{tabla_out}/payloads/process_{tabla_out}_{emp}.json` con `code` = nombre del workflow en GCP (uno por fuente)
- [ ] `data/monitoring/{dataset_out}/{tabla_out}/payloads/task_sp_{tabla_out}_{emp}.json` por cada SP del workflow
- [ ] `task.code` = FQN del SP: `{project}.{dataset}.{sp_name}`
- [ ] Payload proceso incluye todos los campos del modelo: `parent_code`, `flag_reprocess`, `last_status_code`, `execution_date`, `execution_user`, `interval_months` (con `null` si no aplican)
- [ ] Payload tarea incluye `process_parent_code`, `last_status_code`, `flag_reprocess` (con `null`/`"0"` — no omitir)
- [ ] `deploy_dev.json` tiene clave `monitoring_register` apuntando al directorio de payloads
- [ ] `env_dev.json` tiene `METADATA_API_URL`
- [ ] `env_prd.json` tiene `METADATA_API_URL`: `https://prd-itcbi-spld-run-usct1-pv01-947655304508.us-central1.run.app`
- [ ] Workflow: variables monitoring en `set_vars` (4 vars sistema + 4 acumuladores + flags)
- [ ] Workflow: cada `SyncBigQueryJob` reemplazado por `TrackedBigQueryJobWithResults`
- [ ] Workflow: `UpdateProcessStatus` "SUCCESS" al final del try
- [ ] Workflow: `UpdateProcessStatus` "FAILED" en el except
- [ ] Workflow: 5 sub-workflows nuevos al final del YAML
- [ ] SPs: firma con **2** parámetros OUT al final (`o_execution_data_read`, `o_execution_data_write`)
- [ ] SPs: todos los `DECLARE` existentes preceden a los `SET` de inicialización OUT (BigQuery lo exige)
- [ ] SPs: `SET o_execution_data_read/write = 0` colocados **después del último `DECLARE`**
- [ ] SPs: `o_execution_data_read` contabilizado ANTES del INSERT (COUNT en tmp)
- [ ] SPs: `o_execution_data_write` contabilizado DESPUÉS del INSERT (COUNT en tabla destino)
- [ ] `execution_data_duplicate` y `object_last_load_date` calculados en el workflow (no en el SP)
