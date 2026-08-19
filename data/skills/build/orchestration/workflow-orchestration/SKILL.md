# Skill: Workflow Orchestration

> **Rol:** Orquestador de Procesos con Cloud Workflows — ITC Data Platform
> **Activado por:** `/data:implement-stage ORCHESTRATION`
> **Aplica a:** todos los tipos de módulo (`bq_pipeline`, `vertex_ml`, `cloud_run_api`, `cloud_function`)
>
> **Estándares de referencia:**
> - `@.claude/data/standard/services/workflow.md` — reglas de sintaxis y estructura de Cloud Workflows
> - `@.claude/data/standard/services/service-accounts.md` — cuentas de servicio por componente
> - `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` — config Dataops del scheduler
> > - `@.claude/data/skills/build/monitoring/process-monitor/SKILL.md` — instrumentación de control de procesos (activar cuando `etapas.monitoring: true`)
>
> Este skill define **qué orquestar y cómo decidirlo**. El estándar define **cómo escribirlo**.

---

## 1. Rol y Responsabilidades

El **Workflow Orchestration** implementa el Cloud Workflow y el Cloud Scheduler que orquestan el proceso completo del módulo:
leer el spec → entender las dependencias entre componentes → diseñar la secuencia de ejecución →
escribir el YAML del workflow → escribir el YAML del scheduler.

---

## Paso 0 — Leer contexto del módulo

Leer en paralelo:

```
1. {ruta del spec.yaml}                                              → componentes, type, scheduling, etapas, fuentes[]
2. data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql                  → cantidad de SPs, parámetros de cada uno
3. data/bigquery/{dataset_out}/{tabla_out}/ddl/*.sql                 → tablas que se crean (para el orden DDL → SP)
4. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml (si existe) → workflow parcial de etapas previas
5. deploy/env_dev.json                                               → variables disponibles para set_vars
```

---

## Paso 0.5 — Determinar `{dataset_out}`, `{tabla_out}` y cardinalidad por fuente

Del output principal del spec (`outputs[0]` salvo que el módulo declare varios) derivar:
- `{dataset_out}` = `outputs[].dataset`
- `{tabla_out}` = `outputs[].tabla`
- `{tabla_out_kebab}` = `{tabla_out}` con `_` reemplazado por `-` (GCP no acepta `_` en nombres de
  recursos — workflow, scheduler, imagen, etc. — BigQuery sí, por eso el SQL mantiene `_`)

> **Regla de cardinalidad por fuente:** si `fuentes[]` declara más de un origen/empresa (`{emp}`)
> para la **misma** `{tabla_out}`, no se crea un único workflow con N pasos de SP — se crea
> **un `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml` independiente
> por cada fuente**, cada uno con su propio
> `pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml`. Esto es distinto
> de "paralelizar SPs dentro del mismo workflow" (Paso 2.1) — aquí cada fuente tiene su propio
> ciclo de vida de despliegue, ejecución y monitoreo independiente.
> Si el módulo tiene una sola fuente (o es `vertex_ml`/`cloud_run_api`/`cloud_function` sin el
> concepto de `fuentes[]` múltiples para el mismo output), se genera un único workflow/scheduler
> bajo la misma carpeta `{dataset_out}/{tabla_out}/`, sin sufijo `{emp}` (usar el sufijo que
> corresponda a la operación, ej. `-inference`, `-train`).

---

## Paso 1 — Analizar el spec y mapear componentes

Leer el bloque `componentes` del spec e identificar:

| Componente | Qué genera en el workflow |
|---|---|
| `sp` | Un bloque `build_sql_*` + `SyncBigQueryJob` por cada SP |
| `vertex_pipeline` | Bloque de lanzamiento de pipeline + `Subworkflow_EsperarWorkflow` |
| `cloud_run` / `cloud_function` | Llamada HTTP con `http.post` o `http.get` |
| `workflow` (hijo) | Lanzamiento de sub-workflow + `Subworkflow_EsperarWorkflow` |
| `ddl` | No aparece en el workflow — es solo despliegue Dataops |
| `pubsub` | Pub/Sub para notificaciones (el mail ya está cubierto por el patrón estándar) |

---

## Paso 2 — Decidir la estrategia de orquestación

### 2.1 — Secuencial vs Paralelo

**Regla base: todo es secuencial por defecto.** Solo paralelizar cuando se cumplan
**todas** las condiciones siguientes:

| Condición | Descripción |
|---|---|
| ✅ Independencia de datos | Los SPs no leen el output del otro (sin dependencia de tabla) |
| ✅ Independencia de stage | No comparten tablas temporales (`tmp_*`) en `dataset_stage` |
| ✅ Sin orden de negocio | El spec no impone un orden explícito en `reglas_negocio` |
| ✅ Ganancia real | La ejecución secuencial tomaría > 2x el tiempo de la más lenta |

**Cuándo NO paralelizar:**
```
❌ SP-2 lee una tabla que SP-1 escribe
❌ Los SPs comparten tablas tmp_* en dataset_stage
❌ Hay una regla de negocio que impone orden
❌ Son el mismo SP con distintos parámetros (corren en el mismo slot BQ)
❌ Menos de 2 minutos de diferencia entre secuencial y paralelo
```

**Ejemplos prácticos:**

```
# ✅ PARALELIZAR — atributos independientes de distintas fuentes
sp_calcular_attr_retail    ← lee transacciones SPSA   → escribe ba_attr_retail
sp_calcular_attr_insurance ← lee contratos seguros    → escribe ba_attr_insurance
→ No comparten fuentes ni tablas destino → PARALELO

# ❌ NO PARALELIZAR — pipeline secuencial
sp_preparar_variables   → escribe tmp_mi_ejec
sp_consolidar_variables ← lee tmp_mi_ejec → escribe tmp_mi_ejec_var
sp_insertar_prediccion  ← lee tmp_mi_ejec_var
→ Cada SP depende del anterior → SECUENCIAL
```

### 2.2 — SPs propios vs framework central

Algunos procesos invocan SPs del **framework DQ central** o de **otros repos**. En ese caso
el CALL usa el path completo del SP foráneo, pero el patrón es idéntico (`SyncBigQueryJob`).

---

## Paso 3 — Patrones de invocación por tipo de componente

### 3.1 — Invocar un Stored Procedure (BigQuery)

Patrón estándar. Ver reglas completas en `@.claude/data/standard/services/workflow.md` — Reglas 5 y 6.

```yaml
# En set_vars:
- var_sp_nombre:  ${project_analytics}.${dataset_sp}.sp_nombre_del_sp

# Construcción del CALL (máx 7 variables por parte):
- build_sql_nombre_p1:
    assign:
      - sql_nombre_p1: ${"CALL `" + var_sp_nombre + "`("
          + "DATE '" + var_process_date + "'"
          + ", '" + var_project_analytics + "'"
          + ", '" + var_dataset_analytics + "'"
          + ", '" + var_dataset_stage + "'"
          + ", '" + var_dataset_sp + "'"
          + ", '" + var_tabla_input + "'"
          + ", '" + var_tabla_output + "'"}

- build_sql_nombre_p2:
    assign:
      - sql_nombre_p2: ${")"}

- build_sql_nombre:
    assign:
      - query_nombre: ${sql_nombre_p1 + sql_nombre_p2}

- log_sql_nombre:
    call: sys.log
    args:
      text: ${"[BUILD] query_nombre = " + query_nombre}
      severity: INFO

# Ejecución (dentro del try):
- log_exec_nombre:
    call: sys.log
    args:
      text: "[INFO] Ejecutando sp_nombre_del_sp"
      severity: INFO

- exec_nombre:
    call: SyncBigQueryJob
    args:
      query: ${query_nombre}
      project_id: ${v_billing_project}
    result: result_nombre
```

---

### 3.2 — Lanzar un Pipeline de Vertex AI

El workflow lanza la ejecución del pipeline compilado (JSON en GCS) vía la API de Vertex AI
y luego espera con `Subworkflow_EsperarWorkflow`.

```yaml
# En set_vars:
- var_vertex_project:   ${project_analytics}
- var_vertex_location:  "us-central1"
- var_vertex_pipeline:  "nombre-del-pipeline"          # nombre del pipeline en Vertex
- var_pipeline_json:    ${PIPELINE_BUCKET}/compiled/nombre_pipeline.json

# Lanzar el pipeline (dentro del try):
- log_lanzar_vertex:
    call: sys.log
    args:
      text: ${"[INFO] Lanzando Vertex Pipeline: " + var_vertex_pipeline}
      severity: INFO

- lanzar_vertex_pipeline:
    call: http.post
    args:
      url: ${"https://" + var_vertex_location + "-aiplatform.googleapis.com/v1/projects/"
             + var_vertex_project + "/locations/" + var_vertex_location
             + "/pipelineJobs"}
      auth:
        type: OAuth2
      body:
        displayName: ${var_vertex_pipeline + "_" + var_process_date}
        pipelineSpec:
          pipelineInfo:
            name: ${var_vertex_pipeline}
        runtimeConfig:
          gcsOutputDirectory: ${var_pipeline_json}
          parameterValues:
            process_date: ${var_process_date}
    result: vertex_response

- extraer_pipeline_job_id:
    assign:
      - var_pipeline_job_id: ${vertex_response.body.name}

- log_pipeline_job_id:
    call: sys.log
    args:
      text: ${"[INFO] Pipeline lanzado. Job ID: " + var_pipeline_job_id}
      severity: INFO

# Esperar a que el pipeline termine:
- esperar_vertex_pipeline:
    call: Subworkflow_EsperarVertexPipeline
    args:
      project:    ${var_vertex_project}
      location:   ${var_vertex_location}
      job_name:   ${var_pipeline_job_id}
    result: vertex_result

- verificar_resultado_vertex:
    switch:
      - condition: ${vertex_result.state == "PIPELINE_STATE_FAILED"}
        raise: ${vertex_result}
      - condition: ${vertex_result.state == "PIPELINE_STATE_CANCELLED"}
        raise: ${vertex_result}
```

**Subworkflow para esperar un Vertex Pipeline:**

```yaml
Subworkflow_EsperarVertexPipeline:
  params: [project, location, job_name]
  steps:
    - obtener_estado:
        call: http.get
        args:
          url: ${"https://" + location + "-aiplatform.googleapis.com/v1/" + job_name}
          auth:
            type: OAuth2
        result: status

    - revisar_estado:
        switch:
          - condition: ${status.body.state == "PIPELINE_STATE_SUCCEEDED"
                        or status.body.state == "PIPELINE_STATE_FAILED"
                        or status.body.state == "PIPELINE_STATE_CANCELLED"}
            next: devolver_status
          - condition: ${true}
            next: esperar_y_reintentar

    - esperar_y_reintentar:
        call: sys.sleep
        args:
          seconds: 60    # Vertex pipelines duran minutos — polling cada 60s
        next: obtener_estado

    - devolver_status:
        return: ${status.body}
```

> **Nota:** el `job_name` retornado por la API de Vertex tiene el formato
> `projects/{project}/locations/{location}/pipelineJobs/{id}` — usarlo directamente como URL.

---

### 3.3 — Invocar una Cloud Run API (HTTP)

Para llamar a un endpoint de una API REST desplegada en Cloud Run.
Usar autenticación OIDC (no OAuth2) para Cloud Run.

```yaml
# En set_vars:
- var_api_url:         ${crun_itc_nombre_api_uri}    # URI inyectada por Dataops
- var_api_endpoint:    "/v1/recurso/accion"

# Llamada GET (consulta):
- log_llamar_api:
    call: sys.log
    args:
      text: ${"[INFO] Llamando API: " + var_api_url + var_api_endpoint}
      severity: INFO

- llamar_api_get:
    call: http.get
    args:
      url: ${var_api_url + var_api_endpoint}
      auth:
        type: OIDC
        audience: ${var_api_url}
      query:
        process_date: ${var_process_date}
        param2: ${var_param2}
      timeout: 300
    result: api_response

- log_api_response:
    call: sys.log
    args:
      json:
        status_code: ${api_response.code}
        body:        ${api_response.body}
      severity: INFO

# Llamada POST (envío de datos):
- llamar_api_post:
    call: http.post
    args:
      url: ${var_api_url + var_api_endpoint}
      auth:
        type: OIDC
        audience: ${var_api_url}
      body:
        process_date: ${var_process_date}
        parametros:
          campo1: ${var_campo1}
          campo2: ${var_campo2}
      timeout: 300
    result: api_post_response
```

**Manejo de errores HTTP:**

```yaml
- verificar_respuesta_api:
    switch:
      - condition: ${api_response.code >= 400}
        raise: ${"Error API " + string(api_response.code) + " - " + json.encode_to_string(api_response.body)}
      - condition: ${true}
        next: siguiente_paso
```

> **Separador en strings dentro de `${}`:** usar ` - ` en lugar de `: ` (con o sin espacio previo).
> El parser YAML interpreta cualquier `texto: ` (dos puntos seguido de espacio) como separador
> clave-valor y lanza error al desplegar, incluso dentro de expresiones `${}`.
> Aplica a `raise`, `content`, `subject`, logs y toda concatenación de strings en el workflow.
> Ver regla completa: `data/rules/workflow.md` — "Strings en Expresiones de Workflow"

> **Cuándo usar OAuth2 vs OIDC:**
> - `OIDC` → Cloud Run, Cloud Functions HTTP (valida el token del SA del workflow)
> - `OAuth2` → APIs Google (Pub/Sub, BigQuery, Vertex AI, Workflows)

---

### 3.4 — Invocar un Sub-Workflow (Cloud Workflows)

Cuando el proceso llama a otro workflow y debe esperar su resultado.
Usar `Subworkflow_EsperarWorkflow` (definido en `@.claude/data/standard/services/workflow.md` — Regla 9).

```yaml
# En set_vars:
- var_proyecto_wf:   ${project_analytics}
- var_location_wf:   "us-central1"
- var_nombre_wf:     "dev-nombre-del-subworkflow"   # nombre del workflow en GCP

# Lanzar el sub-workflow (dentro del try):
- log_lanzar_subworkflow:
    call: sys.log
    args:
      text: ${"[INFO] Lanzando sub-workflow: " + var_nombre_wf}
      severity: INFO

- lanzar_subworkflow:
    call: googleapis.workflowexecutions.v1.projects.locations.workflows.executions.create
    args:
      parent: ${"projects/" + var_proyecto_wf + "/locations/" + var_location_wf
                + "/workflows/" + var_nombre_wf}
      body:
        argument: ${json.encode_to_string({"process_date": var_process_date})}
    result: wf_execution

- esperar_subworkflow:
    call: Subworkflow_EsperarWorkflow
    args:
      project:      ${var_proyecto_wf}
      location:     ${var_location_wf}
      workflow:     ${var_nombre_wf}
      execution_id: ${text.split(wf_execution.name, "/")[7]}
    result: wf_result

- verificar_subworkflow:
    switch:
      - condition: ${wf_result.state == "FAILED" or wf_result.state == "CANCELLED"}
        raise: ${wf_result}
```

---

### 3.5 — Ejecución en Paralelo de SPs independientes

Aplicar solo cuando se cumplen las condiciones del Paso 2.1.

```yaml
# Inicializar la variable compartida en set_vars:
- parallel_results: {}

# Bloque parallel (dentro del try):
- ejecutar_en_paralelo:
    parallel:
      shared: [parallel_results]
      branches:
        - rama_sp_retail:
            steps:
              - log_rama_retail:
                  call: sys.log
                  args:
                    text: "[INFO] Rama paralela: sp_calcular_attr_retail"
                    severity: INFO
              - exec_sp_retail:
                  call: SyncBigQueryJob
                  args:
                    query: ${query_sp_retail}
                    project_id: ${v_billing_project}
                  result: _result_retail
              - set_result_retail:
                  assign:
                    - parallel_results:
                        retail:    ${_result_retail}
                        insurance: ${map.get(parallel_results, "insurance")}

        - rama_sp_insurance:
            steps:
              - log_rama_insurance:
                  call: sys.log
                  args:
                    text: "[INFO] Rama paralela: sp_calcular_attr_insurance"
                    severity: INFO
              - exec_sp_insurance:
                  call: SyncBigQueryJob
                  args:
                    query: ${query_sp_insurance}
                    project_id: ${v_billing_project}
                  result: _result_insurance
              - set_result_insurance:
                  assign:
                    - parallel_results:
                        retail:    ${map.get(parallel_results, "retail")}
                        insurance: ${_result_insurance}

- recoger_resultados:
    assign:
      - resultado_retail:    ${parallel_results.retail}
      - resultado_insurance: ${parallel_results.insurance}
```

---

### 3.6 — Invocar un SP con Control de Procesos (monitoring: true)

Cuando el spec tiene `etapas.monitoring: true`, reemplazar el patrón `SyncBigQueryJob`
por `TrackedBigQueryJobWithResults`. La instrumentación completa la realiza la etapa MONITORING.
Ver: `@.claude/data/skills/build/monitoring/process-monitor/SKILL.md`

**Diferencia clave respecto al patrón estándar:**

El SP expone **2 OUT params** (`o_execution_data_read`, `o_execution_data_write`).
El workflow calcula los otros 2: `duplicate = read - write` y `last_load_date = sys.now()`.

```yaml
# build_sql_* — 2 DECLARE + SELECT 2 columnas:
- build_sql_sp_nombre_p1:
    assign:
      - sql_sp_nombre_p1: ${"DECLARE v_read INT64 DEFAULT 0; "
          + "DECLARE v_write INT64 DEFAULT 0; "
          + "CALL `" + var_sp_nombre + "`(...)"}
- build_sql_sp_nombre_p2:
    assign:
      - sql_sp_nombre_p2: ${", v_read, v_write); "
          + "SELECT v_read AS execution_data_read, "
          + "v_write AS execution_data_write"}

# exec — TrackedBigQueryJobWithResults ejecuta el SP, lee las 2 columnas
# y calcula duplicate + last_load_date internamente antes de retornar:
- exec_sp_nombre:
    call: TrackedBigQueryJobWithResults
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_id: ${var_execution_id}
      task_code: ${var_sp_nombre}
      execution_type: ${var_execution_type}
      process_date_init: ${var_process_date_init}
      process_date_end: ${var_process_date_end}
      user: ${var_user}
      query: ${query_sp_nombre}
      project_id: ${v_billing_project}
    result: tracked_result

# El result contiene los 4 valores listos para acumular:
- set_metricas_sp_nombre:
    assign:
      - execution_data_read: ${tracked_result.execution_data_read}
      - execution_data_write: ${tracked_result.execution_data_write}
      - object_last_load_date: ${tracked_result.object_last_load_date}
```

Sub-workflows requeridos (agregar al YAML): `TrackedBigQueryJobWithResults`, `CreateExecution`,
`UpdateExecution`, `UpdateProcessStatus`, `SyncBigQueryJobWithResults`.

---

## Paso 4 — Diseñar la secuencia completa del workflow

Con los patrones del Paso 3, diseñar el flujo completo leyendo el spec:

```
1. set_vars
   └── todas las variables: v_billing_project, SPs, APIs, parámetros
   ⚠️  NO incluir aquí variables que dependan de var_process_date
2. normalizar_process_date  ← OBLIGATORIO si el proceso trabaja con fechas
   └── normalizar_args → decidir_fecha → usar_ayer/usar_param → log_fecha
3. build_file_paths / build_sql_vars  ← variables que dependen de var_process_date
4. build_sql_* + log_sql_*  (un bloque por cada SP, antes del try)
5. ejecutar (try/except)
   ├── Pasos secuenciales o paralelos según Paso 2
   ├── [SP1 → SP2 → ... ] o [parallel(SP1, SP2) → SP3]
   ├── [Vertex pipeline: lanzar → esperar]
   ├── [API: llamar → verificar respuesta]
   └── [Sub-workflow: lanzar → esperar]
6. notificar_ok
7. verificar_email_body → enviar_mail
8. MainResponse
```

> **⚠️ REGLA CRÍTICA — `normalizar_process_date`:**
> Si el workflow recibe `process_date` como argumento o cualquier componente (SP, CF, Vertex)
> trabaja con fechas, el bloque de normalización es **obligatorio**. Su ausencia hace que el
> workflow falle silenciosamente cuando el scheduler lo dispara sin argumento (valor `null`).
>
> Dos restricciones derivadas:
> 1. `set_vars` **nunca** construye variables que concatenen `var_process_date`
>    (ej. rutas de archivo `"sales/dt=" + var_process_date + ...`) — `var_process_date` no
>    existe aún en ese punto.
> 2. Variables que dependen de `var_process_date` van en un step separado **después** de la
>    normalización (ej. `build_file_paths`).

### Decisiones de diseño por `type` de módulo

#### `bq_pipeline`
```
set_vars → process_date → build_sql_* →
try:
  [SP carga] → [SP DQ si etapas.data_quality] → notificar_ok
except: notificar_error
```

#### `vertex_ml`
```
set_vars → process_date →
try:
  [SPs de preparación secuenciales]
  → lanzar_vertex_pipeline → esperar_vertex_pipeline
  → [SP de inserción de resultados]
  → notificar_ok
except: notificar_error
```

#### Híbrido `bq_pipeline` + `cloud_run_api`
```
set_vars → process_date → build_sql_* →
try:
  [SP preparación]
  → llamar_api (enriquecimiento o scoring)
  → verificar_respuesta_api
  → [SP inserción resultado]
  → notificar_ok
except: notificar_error
```

---

## Paso 5 — Generar el archivo del Workflow

Antes de escribir el YAML, verificar mentalmente:

- [ ] Si el proceso trabaja con fechas: ¿incluí el bloque `normalizar_args` / `decidir_fecha` / `usar_ayer` / `usar_param` entre `set_vars` y el `try`?
- [ ] ¿`set_vars` contiene alguna variable que concatene `var_process_date`? Si es así, moverla a un step `build_file_paths` posterior a la normalización.
- [ ] ¿Todos los strings de mensajes de error/log usan ` - ` como separador (no ` : `)?

Por cada fuente `{emp}` en `fuentes[]` (o una sola vez si no hay cardinalidad múltiple, ver Paso
0.5), crear `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml` con la
estructura completa.

**Reglas del archivo (ver detalles en `@.claude/data/standard/services/workflow.md`):**
- Solo el bloque `source:` — sin cabecera (`name`, `project`, `region`, `service_account`)
- Subworkflows `SyncBigQueryJob` y `BigQueryJobState` siempre presentes
- Agregar `Subworkflow_EsperarWorkflow` si hay sub-workflows
- Agregar `Subworkflow_EsperarVertexPipeline` si hay pipeline Vertex

---

## Paso 6 — Generar el Cloud Scheduler

Por cada workflow creado en el Paso 5, crear su
`pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml` correspondiente:

```yaml
name: ${env}-{tabla_out_kebab}-{emp}-scheduler
project: ${project_analytics}
region: us-central1
description: "Scheduler para {contexto.nombre} — fuente {emp}"
schedule: "{scheduling.frecuencia del spec}"    # ej: "0 2 3 * *"
timeZone: "America/Lima"
target:
  type: workflow
  workflow: ${env}-{tabla_out_kebab}-{emp}
  location: us-central1
  serviceAccount: ${env}-{caso-uso}-job@${env}-itc-customer-services.iam.gserviceaccount.com
  argument: |
    {"process_date": ""}
```

> La SA es de tipo `-job` (orquestación). Ver: `@.claude/data/standard/services/service-accounts.md`
> Los flags de cabecera del scheduler (`name`, `project`) los completa el framework Dataops.
> El `argument` vacío hace que el workflow use el default (fecha de ayer).

---

## Paso 7 — Actualizar `deploy/env_dev.json`

Verificar que todas las variables usadas en `set_vars` del workflow estén en `env_dev.json`.
Prestar atención especial a:
- URIs de Cloud Run: `crun_{nombre}_uri`
- Nombres de workflows hijos (si aplica)
- `PIPELINE_BUCKET` para Vertex (si aplica)

```bash
# Verificar variables sin cubrir:
grep -r '\${' pipeline/workflow/{dataset_out}/{tabla_out}/ | grep -v '\.git'
```

---

## Paso 8 — Actualizar `docs/TODO.md`

```markdown
### ORCHESTRATION
- [x] pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml: implementado (uno por fuente)
- [x] pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml: implementado (uno por fuente)
- [ ] Desplegar y probar workflow en dev
- [ ] Verificar notificación de éxito y error
```

---

## Decisiones frecuentes — guía rápida

| Situación | Decisión |
|---|---|
| 2 SPs que cargan tablas distintas desde fuentes distintas | Paralelo |
| SP-2 depende del output de SP-1 | Secuencial |
| Pipeline Vertex + SP de inserción de resultados | Secuencial: SP prep → Vertex → SP inserción |
| API que enriquece datos antes de insertar en BQ | Secuencial: SP prep → API → SP inserción |
| Varios atributos BQ del mismo proceso de negocio | Evaluar: si misma fuente → secuencial; si fuentes distintas → paralelo |
| SP DQ después de carga | Siempre secuencial, después del SP de carga |
| Sub-workflow que puede tardar > 30 min | `Subworkflow_EsperarWorkflow` con polling 30s (ajustar si necesario) |
| API con latencia alta (> 5 min) | Aumentar `timeout` en http.post/get. Default 300s puede no alcanzar |

---

## Reporte de etapa

```
## Etapa completada: ORCHESTRATION
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos generados
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml (uno por fuente)
    Pasos: {lista de pasos del try}
    Estrategia: {secuencial / paralelo / híbrido}
- ✅ pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml (uno por fuente)
    Frecuencia: {scheduling.frecuencia}
- ✅ docs/TODO.md: ítems de ORCHESTRATION marcados

### Variables nuevas en env_dev.json (si aplica)
- {lista de variables agregadas}

### Próxima etapa sugerida
/data:implement-stage TESTING {id_modulo}
```
