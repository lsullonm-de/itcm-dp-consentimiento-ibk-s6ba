# Estándar de Desarrollo — Cloud Workflows ITC

> Lineamientos y buenas prácticas para el desarrollo de workflows en Google Cloud Workflows,
> basados en los workflows productivos de este repositorio.
>
> **Ejemplos de referencia:**
> - `pipeline/workflow/campaign/farmas-recom-model-v2als-consolidated.yaml`
> - `pipeline/workflow/campaign/farmas-recommendation-model-csml.yaml`
> - `pipeline/workflow/campaign/farmas-campaign-engine-generation.yaml`
>
> **Despliegue del workflow:**
> - El archivo YAML debe contener **solo el bloque `source:`** (sin flags de cabecera: `name`, `project`, `region`, `service_account`).
> - Los flags de cabecera se agregan durante la etapa de configuración Dataops.
>   Ver: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` — Sección 7 (workflow).

---

## Estructura General del Archivo

Durante desarrollo, el archivo contiene **únicamente el cuerpo `source:`**:

```yaml
source:
  main:
    params: [args]
    steps:
      - set_vars:
          ...
      - normalizar_process_date:
          ...
      - ejecutar:
          try:
            ...
          except:
            ...
      - notificar_ok:
          ...
      - verificar_email_body:
          ...
      - enviar_mail:
          ...
      - MainResponse:
          return: ...

  SyncBigQueryJob:
    params: [query, project_id]
    steps:
      ...

  BigQueryJobState:
    params: [job_id, project_id]
    steps:
      ...
```

> Cuando el workflow esté listo para desplegar con Dataops, se agrega la cabecera YAML
> (name, project, region, service_account) al archivo. El framework la requiere.

---

## Regla 1: Inicialización de Variables — `set_vars`

Todas las referencias a proyectos, datasets, tablas, APIs y nombres de SPs se definen
en el **primer step** del pipeline, llamado `set_vars`. Nunca se hardcodean en el cuerpo
del workflow.

```yaml
- set_vars:
    assign:
      # Proyecto de billing BigQuery (OBLIGATORIO — define qué proyecto asume el costo de los jobs BQ)
      - v_billing_project: ${project_analytics}

      # Nombres completos de los Stored Procedures
      - var_sp_nombre_sp_1: ${env}-itc-customer-services.${dataset_stage_sp}.sp_nombre_del_sp_1
      - var_sp_nombre_sp_2: ${env}-itc-customer-services.${dataset_stage_sp}.sp_nombre_del_sp_2

      # Variables de proyectos, datasets y tablas (inputs a los SPs)
      - var_proyecto_output: ${env}-itc-customer-services
      - var_proyecto_input: ${proyecto_farmas_input}
      - var_dataset_output: ${dataset_farmas_analytics_output}
      - var_dataset_stage: ${dataset_farmas_recom_stage}
      - var_tabla_entrada: ${tabla_nombre_entrada}
      - var_tabla_salida: tmp_nombre_salida

      # APIs y URLs de servicios
      - var_api_url: ${crun_itc_campaign_loader_api_uri}

      # Inicializar email_body SIEMPRE (obligatorio para el bloque de notificación)
      - email_body: {}
```

**Reglas del bloque `set_vars`:**
- `v_billing_project` **siempre presente** — define el proyecto GCP que asume el costo de los jobs de BigQuery. Usar la variable de deployment correspondiente (`${project_analytics}` u otra según el contexto)
- Los nombres de SPs deben incluir el path completo: `proyecto.dataset.nombre_sp`
- Las variables de deployment `${variable_dataops}` se usan directamente — son reemplazadas por el framework
- El prefijo `var_` para todas las variables de negocio (`var_proyecto_*`, `var_dataset_*`, `var_tabla_*`, `var_sp_*`)
- `email_body: {}` siempre inicializado — permite que el bloque de notificación funcione en cualquier flujo

---

## Regla 2: Parámetro `process_date` — Default Fecha de Ayer

Todo workflow que opere sobre datos con fecha debe recibir `process_date` (o `p_fecha_corte`)
como parámetro. Si no es pasado o viene vacío, debe tomar por default **la fecha de hoy - 1 día**
en zona horaria `America/Lima`.

### Patrón estándar

```yaml
- normalizar_args:
    assign:
      # Leer el parámetro de entrada (null si no se pasa)
      - _param: ${map.get(args, "process_date")}
      # Limpiar espacios y forzar a string
      - _param_str: ${text.replace_all(string(_param), " ", "")}

- decidir_fecha:
    switch:
      - condition: ${_param_str == ""}
        next: usar_ayer
      - condition: ${_param_str == "null"}
        next: usar_ayer
      - condition: ${true}
        next: usar_param

- usar_param:
    assign:
      - var_process_date: ${_param_str}
    next: log_fecha

- usar_ayer:
    call: googleapis.bigquery.v2.jobs.query
    args:
      projectId: ${v_billing_project}
      body:
        useLegacySql: false
        query: "SELECT FORMAT_DATE('%F', DATE_SUB(CURRENT_DATE('America/Lima'), INTERVAL 1 DAY)) AS fecha"
    result: bqFecha
    next: set_ayer

- set_ayer:
    assign:
      - var_process_date: ${bqFecha.rows[0].f[0].v}
    next: log_fecha

- log_fecha:
    call: sys.log
    args:
      text: ${"[INFO] process_date: " + var_process_date}
      severity: INFO
```

> **Zona horaria:** Siempre usar `America/Lima` para `sys.now()` y `CURRENT_DATE()`.
> El default usando `sys.now()` (sin BQ) es `text.substring(time.format(sys.now(),"America/Lima"), 0, 10)`.
> La consulta BQ es más precisa para obtener "ayer" y es la forma recomendada.

---

## Regla 2b: Step de Validación de Integridad de Fuentes (si `etapas.integridad: true`)

Cuando el módulo tiene `etapas.integridad: true` en el spec, el workflow debe incluir el gate
de integridad **entre la normalización de `process_date` (`log_fecha`) y el bloque `try`** de
la carga principal. Este gate valida la actualidad de la fuente principal (universo) y detiene
el proceso si no hay datos — nunca debe ejecutarse la carga principal sin este chequeo previo.

El SP de integridad **no persiste nada en BigQuery** — devuelve el resultado (el flag de corte,
el detalle del error y el detalle por regla) en tres parámetros `OUT`, con el mismo patrón de
MONITORING (`@.claude/data/standard/factory/monitoring.md` §7-9): un script
`DECLARE + CALL + SELECT` ejecutado con `SyncBigQueryJobWithResults` (no `SyncBigQueryJob`, que
no retorna filas). El histórico se registra en el Framework de Control de Procesos vía metadata
API con el step `registrar_resultado_integridad`, **antes** del punto de corte.

```yaml
- log_fecha: ...        # último step de la Regla 2 (normalización de process_date)

- build_sql_integridad:
    assign:
      - sql_integridad_p1: ${"DECLARE v_flag_detener INT64 DEFAULT 0; "
          + "DECLARE v_motivo_detencion STRING DEFAULT ''; "
          + "DECLARE v_resultado_json STRING DEFAULT '[]'; "
          + "CALL `" + var_sp_integridad + "`("}
      - sql_integridad_p2: ${"DATE '" + var_process_date + "'"
          + ", v_flag_detener, v_motivo_detencion, v_resultado_json); "}
      - sql_integridad_p3: ${"SELECT v_flag_detener AS flag_detener"
          + ", v_motivo_detencion AS motivo_detencion"
          + ", v_resultado_json AS resultado_json"}

- concatenar_sql_integridad:
    assign:
      - query_integridad: ${sql_integridad_p1 + sql_integridad_p2 + sql_integridad_p3}

- log_query_integridad:
    call: sys.log
    args:
      text: ${"[BUILD] query_integridad = " + query_integridad}
      severity: INFO

- ejecutar_validacion_integridad:
    call: SyncBigQueryJobWithResults
    args:
      query: ${query_integridad}
      project_id: ${v_billing_project}
    result: resultado_integridad

- extraer_resultado_integridad:
    assign:
      - integridad_flag_detener: ${int(resultado_integridad.rows[0].f[0].v)}
      - integridad_motivo: ${resultado_integridad.rows[0].f[1].v}
      - integridad_resultados: ${json.decode(resultado_integridad.rows[0].f[2].v)}

- registrar_resultado_integridad:      # histórico — corre siempre, aun si el gate detiene
    call: RegisterIntegrityResults
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_id: ${var_execution_id}
      task_code: ${var_sp_integridad}
      process_date: ${var_process_date}
      flag_detener: ${integridad_flag_detener}
      motivo_detencion: ${integridad_motivo}
      resultados: ${integridad_resultados}
      user: ${var_user}
    result: integridad_registro_response

- evaluar_integridad:
    switch:
      - condition: ${integridad_flag_detener == 1}
        next: error_sin_datos_principal
      - condition: ${true}
        next: ejecutar   # step del try/except con la carga principal (Regla 3)

- error_sin_datos_principal:
    assign:
      - email_body:
          subject: "[INTEGRIDAD] Proceso detenido - [tabla_out]"
          content: ${"<p>" + integridad_motivo + "</p>"}
          toAddress:
            - "[responsable]@empresa.com"
    next: enviar_mail

- ejecutar:
    try: ...   # Regla 3 — nunca se alcanza si evaluar_integridad detectó integridad_flag_detener == 1
```

**Reglas del gate de integridad:**
- Se inserta **siempre** antes del `try` de la carga principal — nunca después
- El step `evaluar_integridad` es el único punto de corte: si `o_flag_detener = 1`, el workflow
  termina en `error_sin_datos_principal` → `enviar_mail`, con el **detalle real del error**
  (`integridad_motivo`) en el cuerpo del correo — nunca un mensaje genérico
- El SP `sp_integridad_[tabla_out]` solo implementa las reglas con `accion: detener_proceso`
  (por default, solo la actualidad de la fuente principal) — la exclusión de
  duplicados/llaves nulas (`accion: excluir_registros`) ocurre en la query de staging del SP de
  carga (patrón `QUALIFY ROW_NUMBER()` + `WHERE llave IS NOT NULL`), nunca en este SP ni en el workflow
- `registrar_resultado_integridad` se inserta entre `extraer_resultado_integridad` y
  `evaluar_integridad` — nunca después del corte, o se pierde el histórico de las corridas
  detenidas. El sub-workflow `RegisterIntegrityResults` atrapa su propio error y loguea
  `WARNING`: la disponibilidad de la metadata API jamás decide si el pipeline continúa
- Si el workflow no tiene ya el sub-workflow `SyncBigQueryJobWithResults` (porque
  `etapas.monitoring` no está activo), copiarlo desde
  `@.claude/data/standard/factory/monitoring.md` §8. `RegisterIntegrityResults` se copia desde
  `@.claude/data/standard/data-integrity.md` §6.4
- No requiere dataset BigQuery adicional. Única variable de despliegue: `METADATA_API_URL`
  (la misma de MONITORING), más `var_process_code` / `var_execution_id` / `var_user` en `set_vars`

> Ver framework completo (SP de integridad, patrón de exclusión):
> `@.claude/data/standard/data-integrity.md`

---

## Regla 3: Bloque `try/except` — Ejecución con Manejo de Errores

Toda la lógica de negocio va **dentro de un bloque `try`**. El bloque `except` captura
cualquier error, arma el cuerpo del email de error y delega al step de envío de correo.

```yaml
- ejecutar:
    try:
      steps:
        # --- Aquí van todos los steps de negocio ---
        - paso_1:
            call: sys.log
            args:
              text: "[INFO] Paso 1: Ejecutando SP..."
              severity: INFO
        - invoque_sp_1:
            call: SyncBigQueryJob
            args:
              query: ${query_sp_1}
              project_id: ${v_billing_project}
            result: resultado_sp_1

        - paso_2:
            call: sys.log
            args:
              text: "[INFO] Paso 2: Ejecutando SP..."
              severity: INFO
        - invoque_sp_2:
            call: SyncBigQueryJob
            args:
              query: ${query_sp_2}
              project_id: ${v_billing_project}
            result: resultado_sp_2

    except:
      as: e
      steps:
        - handle_error:
            assign:
              - email_body:
                  subject: "[PROCESO] Nombre del Proceso [❌ ERROR]"
                  content: ${"<p>Se detectó un error en el proceso.</p><p>Detalle - " + text.decode(json.encode(e)) + "</p>"}
                  toAddress:
                    - "responsable1@empresa.com"
                    - "responsable2@empresa.com"
            next: enviar_mail
```

**Reglas del try/except:**
- El `except` captura el error `as: e` y arma `email_body` con el detalle del error
- El `next: enviar_mail` al final del `except` redirige al step de notificación
- El mensaje de `content` debe incluir `text.decode(json.encode(e))` para serializar el error
- No hacer `raise` del error si se quiere continuar con la notificación; si el WF debe fallar igual, hacer `raise: ${e}` después del envío de correo

---

## Regla 4: Notificación por Email vía Pub/Sub

Toda notificación de email (éxito o error) se hace publicando en el tópico Pub/Sub de mail.

### Variables de despliegue del servicio de mail

| Ambiente | `mail_pubsub_project` | `mail_pubsub_topic` |
|---|---|---|
| `dev` | `central-data-governance-260223` | `itcm-mail` |
| `prd` | `stalwart-motif-270218` | `itcm-inca-mail` |

Estas variables están definidas en `_DATAOPS_VARIABLES` del trigger Cloud Build.

### Patrón completo de notificación

```yaml
# Step inmediatamente después del try/except (rama OK):
- notificar_ok:
    assign:
      - email_body:
          subject: "[PROCESO] Nombre del Proceso [✅ OK]"
          content: "<p>El proceso finalizó correctamente.</p>"
          toAddress:
            - "responsable1@empresa.com"
            - "responsable2@empresa.com"

# Verificar si hay email_body antes de enviar (evita envíos vacíos):
- verificar_email_body:
    switch:
      - condition: ${"subject" in email_body and email_body.subject != "" and
                    "content" in email_body and email_body.content != "" and
                    "toAddress" in email_body and len(email_body.toAddress) > 0}
        next: enviar_mail
      - condition: ${true}
        next: MainResponse

# Envío al tópico Pub/Sub:
- enviar_mail:
    call: http.post
    args:
      url: ${"https://pubsub.googleapis.com/v1/projects/${mail_pubsub_project}/topics/${mail_pubsub_topic}:publish"}
      auth:
        type: OAuth2
      body:
        messages:
          - data: ${base64.encode(json.encode(email_body))}
    result: pubResp

- MainResponse:
    return: ${"[INFO] Proceso ejecutado con éxito"}
```

**Estructura del `email_body`:**
```yaml
email_body:
  subject: "string — asunto del correo"
  content: "string — cuerpo HTML del correo"
  toAddress:          # lista de destinatarios
    - "email@empresa.com"
```

**Reglas de notificación:**
- `email_body: {}` siempre inicializado en `set_vars`
- El step `verificar_email_body` evita publicar mensajes vacíos en Pub/Sub
- Para notificación de error: el `except` arma `email_body` y hace `next: enviar_mail`
- Para notificación de OK: un step antes de `verificar_email_body` asigna `email_body`
- El paso de OK es opcional si el proceso no requiere notificación al completar exitosamente

---

## Regla 5: Invocación de Stored Procedures — `SyncBigQueryJob` + `BigQueryJobState`

**Toda** invocación de SP de BigQuery **debe** usar los subworkflows `SyncBigQueryJob` y
`BigQueryJobState`. Esto aplica **sin excepción** para todos los steps que ejecutan SPs u
otros workflows que retornan un resultado.

- ❌ Nunca usar `googleapis.bigquery.v2.jobs.query` directamente en `main` para invocar SPs
- ❌ Nunca invocar un SP sin esperar su resultado (fire-and-forget no aplica para SPs de datos)
- ✅ Siempre usar `SyncBigQueryJob` — encapsula el job submission y el polling de estado
- ✅ Para invocar **otros workflows** y esperar su resultado, usar `Subworkflow_EsperarWorkflow` (Regla 9)

### Patrón de invocación

```yaml
- invoque_sp_nombre:
    call: SyncBigQueryJob
    args:
      query: ${query_nombre_sp}   # Variable con el CALL armado previamente
      project_id: ${v_billing_project}
    result: resultado_nombre_sp
```

### Subworkflows obligatorios (copiar en cada workflow)

```yaml
SyncBigQueryJob:
  params: [query, project_id]
  steps:
    - JobQuery:
        call: googleapis.bigquery.v2.jobs.query
        args:
          projectId: ${project_id}
          body:
            query: ${query}
            useLegacySql: false
        result: jobQueryResponse

    - JobWait:
        call: BigQueryJobState
        args:
          job_id: ${jobQueryResponse.jobReference.jobId}
          project_id: ${project_id}
        result: jobGetResponse

    - Return:
        return: ${jobGetResponse}

BigQueryJobState:
  params: [job_id, project_id]
  steps:
    - Sleep:
        call: sys.sleep
        args:
          seconds: 30

    - JobInfo:
        call: googleapis.bigquery.v2.jobs.get
        args:
          jobId: ${job_id}
          projectId: ${project_id}
        result: jobGetResponse

    - CheckRunning:
        switch:
          - condition: ${jobGetResponse.status.state == "RUNNING"}
            next: Sleep
          - condition: ${jobGetResponse.status.state == "DONE"}
            next: CheckDone

    - CheckDone:
        switch:
          - condition: ${"errorResult" in jobGetResponse.status}
            raise: ${jobGetResponse}
          - condition: ${true}
            next: Return

    - Return:
        return: ${jobGetResponse}
```

> `BigQueryJobState` hace polling cada 30 segundos y propaga el error (`raise`) si el job
> de BigQuery falla, lo que dispara el `except` del bloque padre.

---

## Regla 6: Construcción Dinámica del CALL a SP

El CALL del SP se arma dinámicamente concatenando el nombre del SP (de `var_sp_*`) con
los parámetros (de `var_*`). Nunca hardcodear proyectos o datasets en el CALL.

### Reglas de construcción

1. **Cada parte no debe concatenar más de 7 variables** (`var_*`) para evitar errores de
   expresión de Workflows.
2. **El CALL final es la suma de todas las partes:** `sql_part1 + sql_part2 + sql_part3`.
3. **Loguear el CALL construido** para trazabilidad y debugging.
4. **Nombrar las partes** como `sql_[nombre_sp]_p1`, `sql_[nombre_sp]_p2`, etc.

### Patrón para SP con pocos parámetros (≤ 7 variables)

```yaml
- build_sql_nombre_sp:
    assign:
      - query_nombre_sp: ${"CALL `" + var_sp_nombre_sp + "`("
          + "'" + var_proceso_fecha + "'"
          + ", '" + var_proyecto_output + "'"
          + ", '" + var_dataset_output + "'"
          + ", '" + var_tabla_salida + "'"
          + ")"}

- log_query_nombre_sp:
    call: sys.log
    args:
      text: ${"[BUILD] query_nombre_sp: " + query_nombre_sp}
      severity: INFO
```

### Patrón para SP con muchos parámetros (> 7 variables → dividir en partes)

```yaml
- build_sql_nombre_sp_p1:
    assign:
      - sql_nombre_sp_p1: ${"CALL `" + var_sp_nombre_sp + "`("
          + "'" + var_proceso_fecha + "'"
          + ", '" + var_proyecto_output + "'"
          + ", '" + var_proyecto_input + "'"
          + ", '" + var_proyecto_tmp + "'"
          + ", '" + var_dataset_output + "'"
          + ", '" + var_dataset_input + "'"
          + ", '" + var_dataset_tmp + "'"}
          # ← máx 7 variables (incluyendo var_sp_nombre_sp)

- build_sql_nombre_sp_p2:
    assign:
      - sql_nombre_sp_p2: ${", '" + var_tabla_entrada + "'"
          + ", '" + var_tabla_salida + "'"
          + ", '" + var_tabla_auxiliar + "'"
          + ", '" + var_tabla_tmp + "'"
          + ", DATE '" + var_proceso_fecha + "'"}
          # ← máx 7 variables

- build_sql_nombre_sp_p3:
    assign:
      - sql_nombre_sp_p3: ${", " + string(var_numero_param) + "'"
          + ", '" + var_ultimo_param + "'"
          + ")"}

- build_sql_nombre_sp:
    assign:
      - query_nombre_sp: ${sql_nombre_sp_p1 + sql_nombre_sp_p2 + sql_nombre_sp_p3}

- log_query_nombre_sp:
    call: sys.log
    args:
      text: ${"[BUILD] query_nombre_sp: " + query_nombre_sp}
      severity: INFO
```

### Tipos de parámetros en el CALL

| Tipo de parámetro | Formato en el CALL |
|---|---|
| `STRING` | `"'" + var_campo + "'"` |
| `DATE` | `"DATE '" + var_fecha + "'"` |
| `INT64` / `FLOAT64` | `string(var_numero)` (sin comillas) |
| `BOOL` | `string(var_bool)` → `"true"` / `"false"` |

---

## Regla 7: Logging Obligatorio

Todo step relevante debe tener un log antes de ejecutar su lógica. Esto es indispensable
para diagnóstico en la consola de Cloud Workflows.

```yaml
# Log simple (texto)
- log_inicio_paso_1:
    call: sys.log
    args:
      text: "[INFO] Paso 1: Iniciando ejecución SP de consolidado"
      severity: INFO

# Log de variables (JSON estructurado — mejor para debugging)
- log_parametros:
    call: sys.log
    args:
      json:
        process_date: ${var_process_date}
        sp_ejecutado: ${var_sp_nombre_sp}
        proyecto: ${bq_project_id}
      severity: INFO

# Log de query construido (obligatorio después de build_sql_*)
- log_query_construido:
    call: sys.log
    args:
      text: ${"[BUILD] query_nombre_sp = " + query_nombre_sp}
      severity: INFO

# Log de error (en except)
- log_error:
    call: sys.log
    args:
      json:
        status: FAILED
        process_date: ${var_process_date}
        error: ${e}
      severity: ERROR
```

**Niveles de severidad:**
- `INFO` — flujo normal, inicio/fin de pasos, queries construidos
- `WARNING` — errores recuperables, reintentos, datos inesperados
- `ERROR` — en el bloque `except`, antes de notificar y terminar

---

## Regla 8: Ejecución Paralela

Para SPs o llamadas HTTP que son independientes entre sí, usar el bloque `parallel`.

```yaml
- ejecutar_en_paralelo:
    parallel:
      shared: [parallel_results]    # variables compartidas entre ramas
      branches:
        - rama_sp_1:
            steps:
              - log_rama_1:
                  call: sys.log
                  args:
                    text: "[INFO] Rama paralela 1: SP de priorizacion"
                    severity: INFO
              - run_sp_1:
                  call: SyncBigQueryJob
                  args:
                    query: ${query_sp_1}
                    project_id: ${v_billing_project}
                  result: _result_sp_1
              - set_result_sp_1:
                  assign:
                    - parallel_results:
                        sp_1: ${_result_sp_1}
                        sp_2: ${map.get(parallel_results, "sp_2")}

        - rama_sp_2:
            steps:
              - log_rama_2:
                  call: sys.log
                  args:
                    text: "[INFO] Rama paralela 2: SP sin segmento"
                    severity: INFO
              - run_sp_2:
                  call: SyncBigQueryJob
                  args:
                    query: ${query_sp_2}
                    project_id: ${v_billing_project}
                  result: _result_sp_2
              - set_result_sp_2:
                  assign:
                    - parallel_results:
                        sp_1: ${map.get(parallel_results, "sp_1")}
                        sp_2: ${_result_sp_2}

- recoger_resultados:
    assign:
      - resultado_sp_1: ${parallel_results.sp_1}
      - resultado_sp_2: ${parallel_results.sp_2}
```

**Reglas del bloque `parallel`:**
- Declarar las variables compartidas en `shared: [nombre_var]` e inicializarlas en `set_vars: {}`.
- Para acceder a una variable compartida sin sobrescribir otras ramas, usar `map.get(parallel_results, "clave")`.
- El bloque `parallel` completo puede ir dentro del `try` para que los errores sean capturados.

---

## Regla 9: Subworkflow para Esperar Workflows Hijos

Cuando un workflow lanza otro workflow y debe esperar su resultado:

```yaml
Subworkflow_EsperarWorkflow:
  params: [project, location, workflow, execution_id]
  steps:
    - obtener_estado:
        call: http.get
        args:
          url: ${"https://workflowexecutions.googleapis.com/v1/projects/" + project
               + "/locations/" + location
               + "/workflows/" + workflow
               + "/executions/" + execution_id}
          auth:
            type: OAuth2
        result: status

    - revisar_estado:
        switch:
          - condition: ${status.body.state == "SUCCEEDED" or
                        status.body.state == "FAILED" or
                        status.body.state == "CANCELLED"}
            next: devolver_status
          - condition: ${true}
            next: esperar_y_reintentar

    - esperar_y_reintentar:
        call: sys.sleep
        args:
          seconds: 30
        next: obtener_estado

    - devolver_status:
        return: ${status.body}
```

---

## Plantilla Completa

Template listo para usar. Reemplazar los placeholders `[...]`:

```yaml
source:
  main:
    params: [args]
    steps:

      # ============================================================
      # 1. INICIALIZACIÓN DE VARIABLES
      # ============================================================
      - set_vars:
          assign:
            # Proyecto de billing BigQuery (OBLIGATORIO)
            - v_billing_project: ${project_analytics}

            # SPs (path completo)
            - var_sp_[nombre]: ${env}-itc-customer-services.${dataset_[stage]_sp}.sp_[nombre_sp]

            # Proyectos, datasets y tablas (inputs a los SPs)
            - var_proyecto_output: ${env}-itc-customer-services
            - var_proyecto_input: ${[variable_proyecto_externo]}
            - var_dataset_output: ${[variable_dataset_output]}
            - var_dataset_stage: ${[variable_dataset_stage]}
            - var_tabla_[nombre]: [nombre_tabla_literal]

            # APIs (si aplica)
            - var_api_url: ${crun_itc_campaign_loader_api_uri}

            # Email body — inicializar siempre
            - email_body: {}

      # ============================================================
      # 2. NORMALIZACIÓN DEL PARÁMETRO DE FECHA
      # ============================================================
      - normalizar_args:
          assign:
            - _param: ${map.get(args, "process_date")}
            - _param_str: ${text.replace_all(string(_param), " ", "")}

      - decidir_fecha:
          switch:
            - condition: ${_param_str == ""}
              next: usar_ayer
            - condition: ${_param_str == "null"}
              next: usar_ayer
            - condition: ${true}
              next: usar_param

      - usar_param:
          assign:
            - var_process_date: ${_param_str}
          next: log_fecha

      - usar_ayer:
          call: googleapis.bigquery.v2.jobs.query
          args:
            projectId: ${v_billing_project}
            body:
              useLegacySql: false
              query: "SELECT FORMAT_DATE('%F', DATE_SUB(CURRENT_DATE('America/Lima'), INTERVAL 1 DAY)) AS fecha"
          result: bqFecha
          next: set_ayer

      - set_ayer:
          assign:
            - var_process_date: ${bqFecha.rows[0].f[0].v}
          next: log_fecha

      - log_fecha:
          call: sys.log
          args:
            text: ${"[INFO] process_date: " + var_process_date}
            severity: INFO

      # ============================================================
      # 3. CONSTRUCCIÓN DINÁMICA DE QUERIES (CALLS A SPs)
      # ============================================================
      - build_sql_[nombre_sp]_p1:
          assign:
            - sql_[nombre_sp]_p1: ${"CALL `" + var_sp_[nombre] + "`("
                + "'" + var_process_date + "'"
                + ", '" + var_proyecto_output + "'"
                + ", '" + var_proyecto_input + "'"
                + ", '" + var_dataset_output + "'"
                + ", '" + var_dataset_stage + "'"
                + ", '" + var_tabla_entrada + "'"
                + ", '" + var_tabla_salida + "'"}
                # ← máx 7 vars por parte

      - build_sql_[nombre_sp]_p2:
          assign:
            - sql_[nombre_sp]_p2: ${", '" + var_tabla_auxiliar + "'"
                + ", DATE '" + var_process_date + "'"
                + ")"}

      - build_sql_[nombre_sp]:
          assign:
            - query_[nombre_sp]: ${sql_[nombre_sp]_p1 + sql_[nombre_sp]_p2}

      - log_query_[nombre_sp]:
          call: sys.log
          args:
            text: ${"[BUILD] query_[nombre_sp] = " + query_[nombre_sp]}
            severity: INFO

      # ============================================================
      # 4. EJECUCIÓN CON MANEJO DE ERRORES
      # ============================================================
      - ejecutar:
          try:
            steps:
              - log_paso_1:
                  call: sys.log
                  args:
                    text: "[INFO] Paso 1: Ejecutando [nombre_sp]"
                    severity: INFO

              - invoque_[nombre_sp]:
                  call: SyncBigQueryJob
                  args:
                    query: ${query_[nombre_sp]}
                    project_id: ${v_billing_project}
                  result: resultado_[nombre_sp]

          except:
            as: e
            steps:
              - handle_error:
                  assign:
                    - email_body:
                        subject: "[PROCESO] [nombre_proceso] [❌ ERROR]"
                        content: ${"<p>Error en el proceso.</p><p>Detalle - " + text.decode(json.encode(e)) + "</p>"}
                        toAddress:
                          - "[responsable]@empresa.com"
                  next: enviar_mail

      # ============================================================
      # 5. NOTIFICACIÓN OK
      # ============================================================
      - notificar_ok:
          assign:
            - email_body:
                subject: "[PROCESO] [nombre_proceso] [✅ OK]"
                content: "<p>Proceso finalizado correctamente.</p>"
                toAddress:
                  - "[responsable]@empresa.com"

      # ============================================================
      # 6. ENVÍO DE MAIL VÍA PUB/SUB
      # ============================================================
      - verificar_email_body:
          switch:
            - condition: ${"subject" in email_body and email_body.subject != "" and
                          "content" in email_body and email_body.content != "" and
                          "toAddress" in email_body and len(email_body.toAddress) > 0}
              next: enviar_mail
            - condition: ${true}
              next: MainResponse

      - enviar_mail:
          call: http.post
          args:
            url: ${"https://pubsub.googleapis.com/v1/projects/${mail_pubsub_project}/topics/${mail_pubsub_topic}:publish"}
            auth:
              type: OAuth2
            body:
              messages:
                - data: ${base64.encode(json.encode(email_body))}
          result: pubResp

      - MainResponse:
          return: ${"[INFO] [nombre_proceso] ejecutado con éxito"}

  # ============================================================
  # SUBWORKFLOWS REUTILIZABLES (copiar en cada workflow)
  # ============================================================
  SyncBigQueryJob:
    params: [query, project_id]
    steps:
      - JobQuery:
          call: googleapis.bigquery.v2.jobs.query
          args:
            projectId: ${project_id}
            body:
              query: ${query}
              useLegacySql: false
          result: jobQueryResponse

      - JobWait:
          call: BigQueryJobState
          args:
            job_id: ${jobQueryResponse.jobReference.jobId}
            project_id: ${project_id}
          result: jobGetResponse

      - Return:
          return: ${jobGetResponse}

  BigQueryJobState:
    params: [job_id, project_id]
    steps:
      - Sleep:
          call: sys.sleep
          args:
            seconds: 30

      - JobInfo:
          call: googleapis.bigquery.v2.jobs.get
          args:
            jobId: ${job_id}
            projectId: ${project_id}
          result: jobGetResponse

      - CheckRunning:
          switch:
            - condition: ${jobGetResponse.status.state == "RUNNING"}
              next: Sleep
            - condition: ${jobGetResponse.status.state == "DONE"}
              next: CheckDone

      - CheckDone:
          switch:
            - condition: ${"errorResult" in jobGetResponse.status}
              raise: ${jobGetResponse}
            - condition: ${true}
              next: Return

      - Return:
          return: ${jobGetResponse}
```

---

## Checklist de Desarrollo

### Estructura y variables
- [ ] El archivo contiene **solo el bloque `source:`** — sin flags de cabecera
- [ ] Primer step es `set_vars` con TODAS las referencias a proyectos, datasets, tablas y SPs
- [ ] `v_billing_project` definido en `set_vars` con la variable de deployment correspondiente
- [ ] Todos los nombres de SP son paths completos: `proyecto.dataset.nombre_sp`
- [ ] `email_body: {}` inicializado en `set_vars`
- [ ] Variables de negocio con prefijo `var_`

### Parámetro de fecha
- [ ] El workflow acepta `process_date` (o `p_fecha_corte`) como parámetro
- [ ] Si el parámetro llega vacío o `null`, se usa **fecha de ayer** en `America/Lima`
- [ ] Se loguea la fecha usada después de decidirla

### Integridad de fuentes (si `etapas.integridad: true`)
- [ ] Gate de integridad insertado entre `log_fecha` y el `try` de carga principal — nunca después
- [ ] `ejecutar_validacion_integridad` usa `SyncBigQueryJobWithResults` (no `SyncBigQueryJob`, que no retorna filas)
- [ ] El `SELECT` final del script devuelve 3 columnas (`flag_detener`, `motivo_detencion`, `resultado_json`)
- [ ] `registrar_resultado_integridad` (`RegisterIntegrityResults`) insertado **antes** de `evaluar_integridad`
- [ ] `RegisterIntegrityResults` presente al final del archivo y con `try/except` propio que solo loguea `WARNING`
- [ ] Step `evaluar_integridad` detiene el workflow (`error_sin_datos_principal` → `enviar_mail`) si `o_flag_detener = 1`
- [ ] El contenido del correo de error usa `integridad_motivo` (detalle real, tomado del `OUT` del SP) — no un mensaje genérico
- [ ] Sub-workflow `SyncBigQueryJobWithResults` presente en el archivo (propio o compartido con MONITORING)
- [ ] SPs de carga aplican el patrón `QUALIFY ROW_NUMBER()` + `WHERE llave IS NOT NULL` para toda fuente con `accion: excluir_registros`
- [ ] Ninguna tabla ni DML de catálogo **en BigQuery** generado para esta etapa (el histórico va a `metadata_operational` vía API)

### Try/except
- [ ] Toda la lógica de negocio está dentro del bloque `try:`
- [ ] El `except:` arma `email_body` con subject, content y toAddress
- [ ] El `except:` hace `next: enviar_mail` (no `raise` si se quiere notificar primero)

### Invocación de SPs
- [ ] **Toda** invocación de SP usa `SyncBigQueryJob` — sin excepción
- [ ] `project_id: ${v_billing_project}` en todos los calls a `SyncBigQueryJob`
- [ ] Los subworkflows `SyncBigQueryJob` y `BigQueryJobState` están definidos al final del archivo
- [ ] Para invocar workflows hijos y esperar resultado: usar `Subworkflow_EsperarWorkflow`
- [ ] El CALL se construye con variables de `set_vars` — nunca hardcodeado

### Construcción dinámica del CALL
- [ ] El CALL se arma en steps separados `build_sql_[sp]_p1`, `build_sql_[sp]_p2`, etc.
- [ ] Cada parte concatena **máximo 7 variables** (`var_*`)
- [ ] El CALL final es la suma de todas las partes: `sql_p1 + sql_p2 + sql_p3`
- [ ] Siempre hay un step `log_query_[sp]` que loguea el CALL construido con `severity: INFO`

### Notificación
- [ ] Hay un step de notificación OK después del `try/except`
- [ ] Hay un step `verificar_email_body` antes de `enviar_mail` para evitar envíos vacíos
- [ ] El step `enviar_mail` usa Pub/Sub con las variables `${mail_pubsub_project}` y `${mail_pubsub_topic}`
- [ ] Los destinatarios (`toAddress`) están correctamente definidos

### Logging
- [ ] Hay logs `sys.log` antes de cada invocación de SP importante
- [ ] Los queries construidos se loguean antes de invocar el SP
- [ ] El bloque `except` loguea el error con `severity: ERROR`

---

## Valores de Variables de Despliegue para Referencia

| Variable Dataops | Dev | Prd |
|---|---|---|
| `mail_pubsub_project` | `central-data-governance-260223` | `stalwart-motif-270218` |
| `mail_pubsub_topic` | `itcm-mail` | `itcm-inca-mail` |
| `crun_itc_campaign_loader_api_uri` | URL dev del Cloud Run | URL prd del Cloud Run |

Estas variables se definen en `_DATAOPS_VARIABLES` del trigger Cloud Build.
Ver `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` — Sección "Configuración del Trigger Cloud Build".
