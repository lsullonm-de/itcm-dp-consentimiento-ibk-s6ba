# Reglas Cloud Workflows — set_vars, SyncBigQueryJob, Logging, Estructura

> Aplica a: `pipeline/workflow/*.yaml`

---

## Estructura del Archivo

### ✅ El archivo de workflow incluye cabecera con `${...}` variables

El archivo fuente **sí incluye** la cabecera de despliegue (`name`, `region`, `project`, `service_account`).
El framework Dataops lee estos valores para configurar el workflow al desplegar.
La regla es que los valores **nunca deben estar hardcodeados** — siempre usar variables `${...}`.

```yaml
# ✅ CORRECTO — cabecera con variables ${...}
name: ${env}-itc-[nombre]-[accion]
region: us-central1
project: ${project_analytics}
service_account: ${service_account_job}
source:
  main:
    params: [args]
    steps:
      - set_vars: ...

# ❌ INCORRECTO — valores hardcodeados en cabecera
name: prd-itc-ingreso-vii-inference
project: prd-itc-customer-services
region: us-central1
service_account: prd-itc-ingreso-job@prd-itc-customer-services.iam.gserviceaccount.com
source:
  main: ...

# ❌ INCORRECTO — SA construida inline con concatenación
service_account: ${env}-itc-[nombre]-job@${env}-${project_analytics}.iam.gserviceaccount.com
# Fix: usar ${service_account_job} — definida en _DATAOPS_VARIABLES del trigger
```

**Regla de cabecera:**
- `name`: `${env}-{empresa}-{nombre}-{accion}` — usando variable `${env}`
- `region`: valor literal `us-central1` (no varía por ambiente)
- `project`: `${project_analytics}` — nunca hardcodeado
- `service_account`: **siempre `${service_account_job}`** — nunca construida inline con concatenación

---

## Variables y Configuración

### ✅ Primer step siempre es `set_vars`

Todas las referencias a proyectos, datasets, tablas, SPs y URLs se definen en `set_vars`. **Nunca se hardcodean en el cuerpo del workflow.**

```yaml
# ✅ CORRECTO
- set_vars:
    assign:
      - v_billing_project: ${project_analytics}
      - var_sp_retail: ${env}-itc-customer-services.${dataset_sp}.sp_nombre_retail
      - var_proyecto_output: ${project_analytics}
      - var_dataset_stage: ${dataset_stage}
      - email_body: {}      # SIEMPRE inicializar

# ❌ INCORRECTO — valores hardcodeados
- set_vars:
    assign:
      - v_billing_project: "prd-itc-customer-services"
      - var_sp_retail: "prd-itc-customer-services.stored_procedures.sp_nombre_retail"
```

### ✅ `v_billing_project` obligatorio en `set_vars`

Define qué proyecto GCP asume el costo de los jobs de BigQuery. Siempre debe estar presente.

```yaml
- set_vars:
    assign:
      - v_billing_project: ${project_analytics}   # OBLIGATORIO
```

### ✅ `email_body: {}` siempre inicializado en `set_vars`

Permite que el bloque de notificación funcione en cualquier flujo (OK o ERROR):

```yaml
- set_vars:
    assign:
      - email_body: {}   # OBLIGATORIO — siempre vacío al inicio
```

### ✅ Variables de negocio con prefijo `var_`

```yaml
# ✅ CORRECTO
- var_proceso_fecha: ${process_date}
- var_proyecto_input: ${project_input}
- var_sp_consolidar: ${env}-itc-cs.${dataset_sp}.sp_consolidar

# ❌ INCORRECTO — sin prefijo
- proceso_fecha: ${process_date}
- sp_consolidar: ...
```

---

## Parámetro `process_date`

### ✅ Normalización obligatoria antes del primer uso de `var_process_date`

Si el workflow recibe o usa `process_date`, debe incluir un bloque de normalización entre `set_vars`
y el `try/except`. Este bloque establece el valor default (fecha de ayer en Lima) cuando el parámetro
llega vacío o nulo desde el scheduler.

```yaml
# ✅ CORRECTO — bloque de normalización antes del try
- set_vars: ...        # sin var_process_date ni variables que dependan de él

- normalizar_args:
    assign:
      - _param:     ${map.get(args, "process_date")}
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
      text: ${"[INFO] process_date - " + var_process_date}
      severity: INFO

- ejecutar:
    try: ...
```

```yaml
# ❌ INCORRECTO — var_process_date usada antes de ser normalizada
- set_vars:
    assign:
      - var_file_pe: ${"sales/dt=" + var_process_date + "/ventas.csv"}   # ← process_date aún no existe
```

### ✅ Variables que dependen de `var_process_date` van en un step separado, después de la normalización

```yaml
# ✅ CORRECTO — rutas construidas en step propio, después de normalizar
- normalizar_args: ...
- decidir_fecha: ...
- usar_ayer / usar_param: ...
- log_fecha: ...

- build_file_paths:
    assign:
      - var_file_pe: ${"sales/dt=" + var_process_date + "/ventas_peru.csv"}
      - var_file_co: ${"sales/dt=" + var_process_date + "/sales_col.csv"}

- ejecutar:
    try: ...

# ❌ INCORRECTO — dependencia de var_process_date dentro de set_vars
- set_vars:
    assign:
      - var_file_pe: ${"sales/dt=" + var_process_date + "/ventas_peru.csv"}   # ← error en ejecución
```

---

## Integridad de Fuentes (si `etapas.integridad: true`)

### ✅ Gate de integridad presente y ubicado antes de la carga principal

```yaml
# ✅ CORRECTO — orden: log_fecha → gate de integridad → ejecutar (try/except)
- log_fecha: ...
- build_sql_integridad: ...
- concatenar_sql_integridad: ...
- ejecutar_validacion_integridad:
    call: SyncBigQueryJobWithResults
    args:
      query: ${query_integridad}
      project_id: ${v_billing_project}
    result: resultado_integridad
- extraer_resultado_integridad: ...
- registrar_resultado_integridad:
    call: RegisterIntegrityResults
    args: ...
- evaluar_integridad:
    switch:
      - condition: ${integridad_flag_detener == 1}
        next: error_sin_datos_principal
      - condition: ${true}
        next: ejecutar
- ejecutar:
    try: ...

# ❌ INCORRECTO — módulo con etapas.integridad: true pero sin gate en el workflow,
# gate insertado después del try de carga principal, o usando SyncBigQueryJob
# (sin "WithResults") para leer el OUT del SP
```

### ✅ El gate detiene el proceso con el detalle real del error

```yaml
# ✅ CORRECTO — error_sin_datos_principal usa integridad_motivo (del OUT del SP), no continúa hacia la carga
- error_sin_datos_principal:
    assign:
      - email_body:
          subject: "[INTEGRIDAD] Proceso detenido - [tabla]"
          content: ${"<p>" + integridad_motivo + "</p>"}
          toAddress: [...]
    next: enviar_mail

# ❌ INCORRECTO — evaluar_integridad sin rama que corte hacia error_sin_datos_principal
# ❌ INCORRECTO — content con un mensaje genérico en vez de integridad_motivo
```

### ✅ El histórico se registra vía metadata API — nunca desde el SP ni en BigQuery

```yaml
# ✅ CORRECTO — el workflow registra el resultado ANTES del punto de corte, y el registro no puede romper el pipeline
- registrar_resultado_integridad:
    call: RegisterIntegrityResults      # http.post OIDC a /integrity-execution/creation
    args:
      api_url: ${var_METADATA_API_URL}
      execution_id: ${var_execution_id}
      resultados: ${integridad_resultados}   # json.decode del 3er OUT del SP
      ...
    result: integridad_registro_response
- evaluar_integridad: ...

# ❌ INCORRECTO — el SP de integridad hace INSERT/CREATE TABLE en BigQuery para guardar su resultado
# ❌ INCORRECTO — registrar_resultado_integridad colocado después de evaluar_integridad
#                 (se pierde el histórico justo de las corridas que se detienen)
# ❌ INCORRECTO — RegisterIntegrityResults sin try/except propio: un 5xx de la API tumba el pipeline
# ❌ INCORRECTO — etapas.integridad: true con registro_resultados: true pero sin METADATA_API_URL en env_[env].json
```

> Ver detalle completo: `@.claude/data/standard/services/workflow.md` — Regla 2b y
> `@.claude/data/standard/data-integrity.md`.

---

## Invocación de Stored Procedures

### ✅ Toda invocación de SP usa `SyncBigQueryJob` — sin excepción

```yaml
# ✅ CORRECTO
- invoque_sp_retail:
    call: SyncBigQueryJob
    args:
      query: ${query_sp_retail}
      project_id: ${v_billing_project}
    result: resultado_sp_retail

# ❌ INCORRECTO — llamada directa sin polling
- invoque_sp_retail:
    call: googleapis.bigquery.v2.jobs.query
    args:
      projectId: ${v_billing_project}
      body:
        query: ${query_sp_retail}
        useLegacySql: false
```

### ✅ El CALL al SP se construye con variables — nunca hardcodeado

```yaml
# ✅ CORRECTO — CALL dinámico
- build_sql_retail_p1:
    assign:
      - sql_retail_p1: ${"CALL `" + var_sp_retail + "`("
          + "'" + var_process_date + "'"
          + ", '" + var_proyecto_output + "'"
          + ", '" + var_dataset_stage + "'"
          + ", '" + var_dataset_analytics + "'"}

- build_sql_retail_p2:
    assign:
      - sql_retail_p2: ${", '" + var_tabla_entrada + "'"
          + ", '" + var_tabla_salida + "'"
          + ")"}

- build_sql_retail:
    assign:
      - query_sp_retail: ${sql_retail_p1 + sql_retail_p2}

# ❌ INCORRECTO — hardcodeado
- build_sql_retail:
    assign:
      - query_sp_retail: "CALL `prd-itc-customer-services.stored_procedures.sp_retail`('2025-03-01', ...)"
```

**Regla de partes:** Cada parte del CALL concatena **máximo 7 variables** para evitar errores de expresión de Cloud Workflows.

### ✅ Los subworkflows `SyncBigQueryJob` y `BigQueryJobState` van al final de cada workflow

Son obligatorios y deben copiarse íntegramente en cada archivo de workflow.

> Ver implementación completa: `@.claude/data/standard/services/workflow.md` — Regla 5

---

## Manejo de Errores

### ✅ Toda la lógica de negocio va dentro de `try/except`

```yaml
# ✅ CORRECTO
- ejecutar:
    try:
      steps:
        - paso_1: ...
        - paso_2: ...
    except:
      as: e
      steps:
        - handle_error:
            assign:
              - email_body:
                  subject: "[PROCESO] Nombre [❌ ERROR]"
                  content: ${"<p>Error: " + text.decode(json.encode(e)) + "</p>"}
                  toAddress: ["responsable@empresa.com"]
            next: enviar_mail
```

### ✅ El `except` siempre arma `email_body` y redirige a `enviar_mail`

```yaml
# ❌ INCORRECTO — except sin notificación
except:
  as: e
  steps:
    - re_raise:
        raise: ${e}

# ✅ CORRECTO — notificar antes de terminar
except:
  as: e
  steps:
    - handle_error:
        assign:
          - email_body:
              subject: "[PROCESO] Nombre [❌ ERROR]"
              content: ${"<p>Detalle: " + text.decode(json.encode(e)) + "</p>"}
              toAddress: ["responsable@empresa.com"]
        next: enviar_mail
```

---

## Strings en Expresiones de Workflow

### ❌ Nunca usar `:` seguido de espacio dentro de strings literales en `${}`

El parser YAML interpreta cualquier patrón `texto: ` (dos puntos seguidos de espacio) como
separador clave-valor y lanza error al desplegar el workflow, incluso dentro de una expresión `${}`.

**El problema no requiere espacio antes del `:`** — basta con que haya espacio (u otro caracter no alfanumérico) después.

```yaml
# ❌ INCORRECTO — todas estas formas rompen el despliegue
raise:   ${"CF Perú error : " + text.decode(json.encode(e))}   # espacio-:-espacio
content: ${"<p>Filas leídas: " + string(v_read) + "</p>"}      # :-espacio (sin espacio previo)
content: ${"Status: OK - " + var_result}                        # :-espacio al inicio de valor
subject: ${"[ERROR]: " + var_proceso}                          # :-espacio después de ]

# ✅ CORRECTO — reemplazar : por - en todos los casos
raise:   ${"CF Perú error - " + text.decode(json.encode(e))}
content: ${"<p>Filas leidas - " + string(v_read) + "</p>"}
content: ${"Status - OK - " + var_result}
subject: ${"[ERROR] - " + var_proceso}
```

**Regla:** dentro de cualquier expresión `${}`, los strings literales **no pueden contener `:`
seguido de espacio** (patrón `": "`). Reemplazar siempre por ` - `.

**Aplica a todos los campos que aceptan expresiones `${}`:** `raise`, `content`, `subject`, `text`
(logs), `url` construida dinámicamente, y cualquier concatenación de strings.

**Cómo detectarlo en compliance (grep):**
```bash
# Buscar ": " dentro de expresiones ${} en archivos YAML de workflow
grep -n '${.*": ' pipeline/workflow/*.yaml
grep -n "${.*: " pipeline/workflow/*.yaml
```

> La variante más peligrosa es `": "` (con comilla antes) porque es la forma habitual en
> strings de HTML o mensajes (`"Filas leídas: "`, `"Error: "`) y no siempre se ve como
> un `:` separador de YAML — pero lo es.

---

## Notificación

### ✅ Notificación via Pub/Sub — variables `${mail_pubsub_project}` y `${mail_pubsub_topic}`

```yaml
# ✅ CORRECTO — variables Dataops para mail
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

# ❌ INCORRECTO — proyecto/tópico hardcodeado
      url: "https://pubsub.googleapis.com/v1/projects/central-data-governance-260223/topics/itcm-mail:publish"
```

### ✅ Step `verificar_email_body` antes de `enviar_mail`

```yaml
# ✅ OBLIGATORIO — evita publicar mensajes vacíos
- verificar_email_body:
    switch:
      - condition: ${"subject" in email_body and email_body.subject != "" and
                    "content" in email_body and email_body.content != "" and
                    "toAddress" in email_body and len(email_body.toAddress) > 0}
        next: enviar_mail
      - condition: ${true}
        next: MainResponse
```

---

## Logging

### ✅ Log antes de cada SP y después de construir el CALL

```yaml
# ✅ CORRECTO — log antes de ejecutar SP
- log_paso_retail:
    call: sys.log
    args:
      text: "[INFO] Paso 1: Ejecutando SP retail"
      severity: INFO

# ✅ CORRECTO — log del CALL construido (obligatorio después de build_sql_*)
- log_query_sp_retail:
    call: sys.log
    args:
      text: ${"[BUILD] query_sp_retail = " + query_sp_retail}
      severity: INFO
```

### ✅ Log de error en el `except` con `severity: ERROR`

```yaml
- log_error:
    call: sys.log
    args:
      json:
        status: FAILED
        process_date: ${var_process_date}
        error: ${e}
      severity: ERROR
```

**Niveles:** `INFO` para flujo normal · `WARNING` para condiciones recuperables · `ERROR` en el `except`.

---

## Checklist Workflow

- [ ] Cabecera presente con `name`, `region`, `project`, `service_account` usando `${...}` variables
- [ ] `service_account` usa `${service_account_job}` — nunca construida inline
- [ ] Primer step es `set_vars` con todas las variables
- [ ] `v_billing_project` definido en `set_vars`
- [ ] `email_body: {}` inicializado en `set_vars`
- [ ] Variables de negocio con prefijo `var_`
- [ ] No hay valores hardcodeados (proyectos, datasets, tablas, SPs, URLs)
- [ ] Toda invocación de SP usa `SyncBigQueryJob`
- [ ] CALL construido dinámicamente (máx 7 variables por parte)
- [ ] Toda lógica de negocio dentro del `try/except`
- [ ] `except` arma `email_body` y hace `next: enviar_mail`
- [ ] `verificar_email_body` presente antes de `enviar_mail`
- [ ] `enviar_mail` usa `${mail_pubsub_project}` y `${mail_pubsub_topic}`
- [ ] Hay log antes de cada SP con `severity: INFO`
- [ ] Hay log del CALL construido (`[BUILD] query_... = ...`)
- [ ] `except` loguea el error con `severity: ERROR`
- [ ] Subworkflows `SyncBigQueryJob` y `BigQueryJobState` al final del archivo
- [ ] Ninguna expresión `${}` contiene el patrón `": "` (dos puntos seguido de espacio) en strings literales — reemplazar por `" - "`
- [ ] **[si etapas.integridad: true]** Gate de integridad presente, ubicado antes del `try` de carga principal, usa `SyncBigQueryJobWithResults`, y notifica con el detalle real (`integridad_motivo`) si `o_flag_detener = 1` — sin tablas de catálogo/control en BigQuery
- [ ] **[si etapas.integridad: true y registro_resultados: true]** `registrar_resultado_integridad` (`RegisterIntegrityResults`) está entre `extraer_resultado_integridad` y `evaluar_integridad`, y el sub-workflow atrapa su propio error con `severity: WARNING`
