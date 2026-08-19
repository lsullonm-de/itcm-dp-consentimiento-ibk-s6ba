# Skill: wf-atributos-itc
> Generación automática de Workflow YAML + DDL Athena + SP Export para atributos ITC

---

# Skill: Generación de Workflows YAML + DDL Athena para Atributos ITC

## Entrada esperada

El usuario proveerá:
1. El nombre de la tabla del atributo:
```
itc-data-governance-01.gnunurat.ba_itc_attr_{ATRIBUTO}
```
2. El CALL al SP **o la ruta del archivo DML** que lo contiene (obligatorio para armar el YAML correctamente).

El CALL tiene esta forma general:
```sql
CALL `proyecto.dataset.sp_load_ba_itc_attr_{ATRIBUTO}`(
  'param1',
  param2,
  DATE('...'),
  ...
)
```

**⚠️ Los parámetros del CALL varían por atributo.** Algunos SPs reciben solo `start_date`, otros reciben proyecto destino, dataset, proyecto fuente, tabla fuente, etc. Leer el CALL del usuario y mapear cada parámetro a una variable en `set_vars`, reemplazando únicamente el valor de fecha por `var_process_date`.

Extrae `{ATRIBUTO}` del nombre de la tabla. Ese valor se usará para construir automáticamente:
- El nombre del SP de carga: `intercorp-data-storage-pv.master_stage.sp_load_ba_itc_attr_{ATRIBUTO}`
- El nombre del SP de exportación: `silent-matter-270218.shared_attr_aws.prc_export_attribute_aws_{ATRIBUTO}`
- El nombre del archivo YAML: `wf_sp_load_ba_itc_attr_{ATRIBUTO}.yaml`
- El nombre GCP del workflow (para despliegue): `p-itcdo-rdp-cwf-dattribute-{ATRIBUTO}-usct1-{RANDOM}`
- El DDL de Athena: `sand_attr_{ATRIBUTO}.sql`
- La tabla Athena: `sand_attr_{ATRIBUTO}`
- La ruta GCS: `gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{ATRIBUTO}`
- La ruta S3: `s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/{ATRIBUTO}`

---

## Entregables — siempre generar los TRES

Ante cada solicitud de workflow de atributo ITC, generar:

1. **`wf_sp_load_ba_itc_attr_{ATRIBUTO}.yaml`** — workflow de GCP Workflows
2. **`sand_attr_{ATRIBUTO}.sql`** — DDL de tabla externa en Athena AWS
3. **`prc_export_attribute_aws_{ATRIBUTO}.sql`** — Stored Procedure de exportación BigQuery → GCS → AWS

Para el DDL Athena, leer `references/athena-ddl.md` y ejemplos en `references/ddl_examples/`.
Para el SP de exportación, leer `references/sp-export-aws.md` y ejemplos en `references/sp_examples/`.

### Cómo obtener los campos para DDL y SP
- **Normal:** consultar BigQuery con `INFORMATION_SCHEMA.COLUMNS` sobre `ba_itc_attr_{ATRIBUTO}`
- **Primera vez / sin acceso:** el usuario provee la metadata directamente — usarla tal como viene

---

## Reglas de desarrollo — OBLIGATORIAS

### 1. Primer step: `set_vars`
Todas las referencias a proyectos, datasets, tablas, SPs, APIs y variables de mail deben definirse aquí.

```yaml
- set_vars:
    assign:
        - bq_project_id: "silent-matter-270218"
        - sp_{atributo}: "intercorp-data-storage-pv.master_stage.sp_load_ba_itc_attr_{atributo}"
        - sp_export_{atributo}: "silent-matter-270218.shared_attr_aws.prc_export_attribute_aws_{atributo}"
        - gcs_base_path: "gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{atributo}"
        - cloudrun_url: "https://prd-itcibk-trasnferaws-fun-usct1-gpzy-ek36ifuerq-uc.a.run.app"
        - s3_dir: "s3://prd-ibk-bi-sharedattrsanbox-9jtg/input"
        - gcs_dir: "gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws"
        - athena_db: "sand_ibk_itcm_base_rlink"
        - athena_table: "sand_attr_{atributo}"
        - gcs_mode: "base"
        - mail_pubsub_project: "stalwart-motif-270218"
        - mail_pubsub_topic: "itcm-inca-mail"
```

### 2. Manejo de parámetros y fechas

Lee `references/date-logic.md` para el detalle completo de los 3 casos.

Resumen:
- **Caso 1** — sin parámetros: `process_date` = primer día del mes anterior
- **Caso 2** — `process_date` solo: procesa ese único mes
- **Caso 3** — `process_date` + `end_date`: loop mes a mes con `sys.sleep(60)` entre iteraciones

**⚠️ Comparación de fechas en el loop** — GCP Workflows no soporta `<=` entre strings. Convertir a entero `YYYYMMDD` para comparar:

```yaml
- loop_condition:
    steps:
        - compare_dates:
            assign:
                - current_date_int: ${int(text.replace_all(current_date, "-", ""))}
                - end_date_int: ${int(text.replace_all(var_end_date, "-", ""))}
        - check_loop:
            switch:
                - condition: ${current_date_int <= end_date_int}
                  next: build_call_loop
                - condition: true
                  next: end_workflow
```
```yaml
# Lógica robusta — ir al día 1 del mes actual y restar 1 día
- now_epoch: ${sys.now()}
- now_str: ${time.format(now_epoch)}
- day_of_month: ${int(text.substring(now_str, 8, 10))}
- epoch_day1_current: ${now_epoch - ((day_of_month - 1) * 86400)}
- epoch_last_prev: ${epoch_day1_current - 86400}
- prev_str: ${text.substring(time.format(epoch_last_prev), 0, 7)}
- var_process_date: ${prev_str + "-01"}
```

> **Por qué:** restar días fijos (32 días) puede caer 2 meses atrás si el día actual es pequeño. Ir al día 1 del mes y restar 1 día es siempre exacto.

Para avanzar meses en el loop:
```yaml
- current_epoch: ${int(time.parse(current_date + "T00:00:00Z"))}
- next_epoch: ${current_epoch + 2764800}
- next_str: ${text.substring(time.format(next_epoch), 0, 7)}
- current_date: ${next_str + "-01"}
```

> **⚠️ `time.parse` requiere timestamp completo** — el formato `YYYY-MM-DD` solo no es reconocido. Siempre concatenar `+ "T00:00:00Z"` antes de parsear.

### 3. Armado dinámico del CALL (nunca hardcodear)

El CALL se construye concatenando variables, nunca con strings literales completos.
**Leer el DML del usuario y mapear TODOS sus parámetros** — no asumir que el CALL solo lleva fecha.

**Regla crítica:** dividir en partes de máximo 7 variables cada una para evitar errores de parse.

**Ejemplo con solo fecha (caso simple):**
```yaml
- build_call:
    assign:
        - sql_part1: ${"CALL `" + sp_{atributo} + "`("}
        - sql_part2: ${"DATE('" + var_process_date + "')"}
        - sql_part3: ${")"}
        - sql_call: ${sql_part1 + sql_part2 + sql_part3}
```

**Ejemplo con múltiples parámetros (caso real — basado en el DML del usuario):**
```yaml
# En set_vars, definir todos los parámetros del CALL como variables:
- set_vars:
    assign:
        - sp_{atributo}: "proyecto.dataset.sp_load_ba_itc_attr_{atributo}"
        - v_proyecto_destino: "itc-data-governance-01"
        - v_bi_attr: "gnunurat"
        - v_master_stage: "gnunurat"
        - v_storage: "dev-intercorp-data-storage"
        - v_dataset_fuente: "enablement"
        - v_table_fuente: "t_collections"
        # ... resto de variables del proyecto

# En build_call, cada parámetro como sql_partN:
- build_call:
    assign:
        - sql_part1: ${"CALL `" + sp_{atributo} + "`("}
        - sql_part2: ${"'" + v_proyecto_destino + "',"}
        - sql_part3: ${"'" + v_bi_attr + "',"}
        - sql_part4: ${"'" + v_master_stage + "',"}
        - sql_part5: ${"'" + v_storage + "',"}
        - sql_part6: ${"'" + v_dataset_fuente + "',"}
        - sql_call_a: ${sql_part1 + sql_part2 + sql_part3 + sql_part4 + sql_part5 + sql_part6}
        - sql_part7: ${"'" + v_table_fuente + "',"}
        - sql_part8: ${"DATE('" + var_process_date + "')"}
        - sql_part9: ${")"}
        - sql_call: ${sql_call_a + sql_part7 + sql_part8 + sql_part9}
```

> **Regla de corte:** cuando la concatenación supere 6-7 partes, usar una variable intermedia (`sql_call_a`, `sql_call_b`, etc.) antes de continuar acumulando.

### 4. Log del CALL antes de ejecutarlo

Siempre loggear el CALL armado para trazabilidad:

```yaml
- log_call:
    call: sys.log
    args:
        text: ${"[INFO] Ejecutando - " + sql_call}
```

**⚠️ Nunca usar `:` dentro de strings literales en expresiones `${}`** — el parser de GCP Workflows lo rechaza. Esto incluye los `:` en logs, mensajes de error Y dentro del JSON de mail (`"subject": ...`). Solución: simplemente omitir el `:`:

```yaml
# ❌ INCORRECTO
text: ${"[INFO] Ejecutando: " + sql_call}
- mail_msg_ok: ${"{ \"subject\": \"" + mail_subj_ok + "\", \"body\": \"" + mail_body_ok + "\"}"}

# ✅ CORRECTO
text: ${"[INFO] Ejecutando - " + sql_call}
- mail_msg_ok: ${"{ \"subject\" \"" + mail_subj_ok + "\", \"body\" \"" + mail_body_ok + "\"}"}
```

### 5. Ejecución dentro de try/except

Todo el bloque de invocación al SP debe estar dentro de un `try/except`.

**Patrón correcto para notificación PubSub mail** — usar mapa nativo YAML, nunca construir JSON como string:
```yaml
# Flujo definitivo: MAP → json.encode() → base64.encode()
# ⚠️ NO usar text.encode() — base64.encode() en GCP Workflows acepta STRING directamente
- build_msg_ok:
    assign:
        - payload_ok:
            subject: "[OK] WF sp_load_ba_itc_attr_{atributo}"
            body: ${"Proceso ejecutado correctamente para el mes " + var_process_date}
- notify_ok:
    call: http.post
    args:
        url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
        auth:
            type: OAuth2
        body:
            messages:
                - data: ${base64.encode(json.encode(payload_ok))}
    result: pubsubOkResult
```

Para el bloque de error, mismo patrón:
```yaml
- build_msg_error:
    assign:
        - payload_err:
            subject: "[ERROR] WF sp_load_ba_itc_attr_{atributo}"
            body: ${"Error en proceso " + var_process_date + " - " + json.encode_to_string(e)}
- notify_error:
    call: http.post
    args:
        url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
        auth:
            type: OAuth2
        body:
            messages:
                - data: ${base64.encode(json.encode(payload_err))}
    result: pubsubErrResult
- raise_error:
    raise: ${e}
```

> **Reglas de tipado en GCP Workflows:**
> - `json.encode(map)` → STRING ✅
> - `base64.encode(string)` → STRING base64 ✅
> - `text.encode(string)` → BYTES ❌ no usar para PubSub
> - `sys.log` siempre recibe STRING — usar `json.encode_to_string(e)` para errores

```yaml
- execute_sp:
    try:
        steps:
            - run_sp:
                call: SyncBigQueryJob
                args:
                    query: ${sql_call}
                    project_id: ${bq_project_id}
                result: queryResult
            - log_ok:
                call: sys.log
                args:
                    text: "[OK] SP ejecutado correctamente"
            # ⚠️ IMPORTANTE: json.encode({...}) con mapa literal NO funciona en GCP Workflows.
            # Siempre armar el mensaje en un assign previo como string concatenado.
            - build_msg_ok:
                assign:
                    - mail_subject_ok: ${"[OK] WF sp_load_ba_itc_attr_{atributo}"}
                    - mail_body_ok: ${"Proceso ejecutado correctamente para: " + var_process_date}
                    - mail_msg_ok: ${"{ \"subject\": \"" + mail_subject_ok + "\", \"body\": \"" + mail_body_ok + "\"}"}
            - notify_ok:
                call: http.post
                args:
                    url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
                    auth:
                        type: OAuth2
                    body:
                        messages:
                            - data: ${base64.encode(mail_msg_ok)}
                result: pubsubOkResult
    except:
        as: e
        steps:
            - log_error:
                call: sys.log
                args:
                    text: ${"[ERROR] Falló el SP: " + json.encode_to_string(e)}
            - build_msg_error:
                assign:
                    - mail_subject_err: ${"[ERROR] WF sp_load_ba_itc_attr_{atributo}"}
                    - mail_body_err: ${"Error en proceso " + var_process_date + ": " + json.encode_to_string(e)}
                    - mail_msg_err: ${"{ \"subject\": \"" + mail_subject_err + "\", \"body\": \"" + mail_body_err + "\"}"}
            - notify_error:
                call: http.post
                args:
                    url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
                    auth:
                        type: OAuth2
                    body:
                        messages:
                            - data: ${base64.encode(mail_msg_err)}
                result: pubsubErrResult
            - raise_error:
                raise: ${e}
```

### 6. Flujo completo dentro del try/except — orden OBLIGATORIO

```
1. SP carga BQ          → SyncBigQueryJob con sp_load_ba_itc_attr_{atributo}
2. DELETE GCS           → listar objetos del periodo via Storage API y eliminar uno a uno
3. Validar DELETE       → relistar; si aún hay items → raise error
4. SP exportación       → SyncBigQueryJob con prc_export_attribute_aws_{atributo}
5. Invocar CloudRun     → http.post OIDC con payload JSON:
                          FECHA, TABLA, DIR_S3, DIR_GCS, ATHENA_DB, ATHENA_TABLE, GCS_MODE
6. Notificación OK      → PubSub mail
```

**Patrón DELETE + Validación GCS:**
```yaml
# Listar objetos
- list_gcs_objects:
    call: http.get
    args:
        url: "https://storage.googleapis.com/storage/v1/b/p-itcibk-datr-stg-sharing-usct1-esta/o"
        auth:
            type: OAuth2
        query:
            prefix: ${"data/shared_aws/{atributo}/" + var_process_date + "/"}
    result: list_result
# Eliminar cada objeto
- delete_objects:
    for:
        value: obj
        in: ${default(map.get(list_result.body, "items"), [])}
        steps:
            - delete_obj:
                call: http.delete
                args:
                    url: ${"https://storage.googleapis.com/storage/v1/b/p-itcibk-datr-stg-sharing-usct1-esta/o/" + text.url_encode(obj.name)}
                    auth:
                        type: OAuth2
                result: delete_result
# Validar que no queden archivos
- validate_delete:
    call: http.get
    args:
        url: "https://storage.googleapis.com/storage/v1/b/p-itcibk-datr-stg-sharing-usct1-esta/o"
        auth:
            type: OAuth2
        query:
            prefix: ${"data/shared_aws/{atributo}/" + var_process_date + "/"}
    result: validate_result
- check_deleted:
    switch:
        - condition: ${not("items" in validate_result.body)}
          next: log_delete_ok
        - condition: true
          next: raise_delete_error
```

**Patrón CloudRun (OIDC, no OAuth2):**
```yaml
- build_cloudrun_body:
    assign:
        - cloudrun_payload:
            FECHA: ${var_process_date}
            TABLA: "{atributo}"
            DIR_S3: ${s3_dir}
            DIR_GCS: ${gcs_dir}
            ATHENA_DB: ${athena_db}
            ATHENA_TABLE: ${athena_table}
            GCS_MODE: ${gcs_mode}
- call_cloudrun:
    call: http.post
    args:
        url: ${cloudrun_url}
        auth:
            type: OIDC
        headers:
            Content-Type: "application/json"
        body: ${cloudrun_payload}
    result: cloudrunResult
```

> **⚠️ CloudRun usa `auth: type: OIDC`**, no OAuth2. PubSub usa OAuth2.

### 7. Subworkflows SyncBigQueryJob y BigQueryJobState

Siempre incluirlos al final del YAML, **idénticos en todos los workflows**. Ver `references/subworkflows.md`.

---

## Ambientes (variables de mail)

| Ambiente     | mail_pubsub_project              | mail_pubsub_topic   |
|--------------|----------------------------------|---------------------|
| Producción   | stalwart-motif-270218            | itcm-inca-mail      |

Por defecto, usar los valores de **producción**.

---

## Checklist antes de entregar el YAML

- [ ] `bq_project_id: "silent-matter-270218"` en `set_vars`
- [ ] SP referenciado como variable en `set_vars`, nunca hardcodeado en el CALL
- [ ] Variables de mail definidas en `set_vars`
- [ ] Lógica de fecha según los 3 casos implementada
- [ ] CALL construido por concatenación de partes (sql_part1, sql_part2, ...)
- [ ] CALL loggeado antes de ejecutar
- [ ] Toda ejecución del SP dentro de `try/except`
- [ ] Notificación OK y ERROR via PubSub de mail
- [ ] Subworkflows `SyncBigQueryJob` y `BigQueryJobState` incluidos al final
- [ ] YAML inicia con `main:` (sin cabecera de flags)
- [ ] Nombre GCP para despliegue proporcionado: `p-itcdo-rdp-cwf-dattribute-{ATRIBUTO}-usct1-{RANDOM}` (generar 4 chars aleatorios alfanuméricos para {RANDOM})

---

## Referencias

- `references/date-logic.md` — Detalle de los 3 casos de fecha con código YAML
- `references/subworkflows.md` — Subworkflows reutilizables SyncBigQueryJob y BigQueryJobState
- `references/full-example.md` — Ejemplo completo de workflow generado para el atributo `entertainment`
- `references/athena-ddl.md` — Reglas y estructura del DDL de Athena
- `references/ddl_examples/sand_attr_entertainment.sql` — DDL ejemplo atributo entertainment
- `references/ddl_examples/sand_attr_insurance.sql` — DDL ejemplo atributo insurance

---

## Checklist DDL Athena

- [ ] Nombre de tabla: `sand_attr_{atributo}`
- [ ] Todos los campos como `string`
- [ ] Campo de partición `process_date` en `PARTITIONED BY`, no en la lista de columnas
- [ ] LOCATION apunta a `s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/{atributo}`
- [ ] SerDe y clases son las de Parquet (no ORC, no texto)
- [ ] `TBLPROPERTIES` incluido con `transient_lastDdlTime`
- `references/sp-export-aws.md` — Reglas y estructura del SP de exportación BigQuery → GCS
- `references/sp_examples/prc_export_attribute_aws_entertainment.sql` — SP ejemplo atributo entertainment

## Checklist SP Export AWS

- [ ] Nombre: `prc_export_attribute_aws_{atributo}` en `silent-matter-270218.shared_attr_aws`
- [ ] Parámetro: `periodo STRING`
- [ ] Ruta GCS: `gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{atributo}/%t/{atributo}_*.parquet`
- [ ] EXECUTE IMMEDIATE de validación de data incluido (fijo)
- [ ] CTE base con todos los campos `CAST(campo AS STRING) AS campo`
- [ ] `id` en el CTE pero NO en el SELECT final
- [ ] SELECT final inicia con `COALESCE(b.id_sandbox, '0') AS id_sandbox`
- [ ] JOIN con `prd-itc-data-sensitive.master_pii.iden_equiv_sandbox`
- [ ] FORMAT args en orden: `({atributo}_var, periodo)`
- [ ] `ORDER BY b.id_sandbox DESC` al final
# Lógica de Fechas — 3 Casos

El workflow recibe parámetros opcionales. La lógica se implementa en los steps de resolución de fechas, justo después de `set_vars`.

---

## Caso 1 — Ejecución normal automática (sin parámetros)

Input: `{}`

Comportamiento: `process_date` = primer día del mes anterior a hoy.

Ejemplo: Si hoy es 15 marzo 2026 → procesa `2026-02-01`

```yaml
- resolve_dates:
    assign:
        - var_process_date: ${if(default(map.get(input, "process_date"), "") == "", text.substring(time.format(date.subtract(sys.now(), duration("P1D"))), 0, 7) + "-01", input.process_date)}
        - var_end_date: ${default(map.get(input, "end_date"), "")}
```

> **Nota:** La expresión `text.substring(..., 0, 7) + "-01"` obtiene `YYYY-MM` del mes anterior y agrega `-01` para el primer día.

Para obtener el primer día del mes anterior correctamente en Workflows:

```yaml
- resolve_process_date:
    steps:
        - check_input_date:
            switch:
                - condition: ${default(map.get(input, "process_date"), "") == ""}
                  next: use_default_date
                - condition: true
                  next: use_input_date
        - use_default_date:
            assign:
                # Primer día del mes anterior: restar 1 mes a hoy, tomar YYYY-MM-01
                - today_str: ${time.format(sys.now(), "America/Lima")}
                - var_process_date: ${text.substring(time.format(date.subtract(sys.now(), duration("P32D"))), 0, 7) + "-01"}
            next: resolve_end_date
        - use_input_date:
            assign:
                - var_process_date: ${input.process_date}
            next: resolve_end_date
        - resolve_end_date:
            assign:
                - var_end_date: ${default(map.get(input, "end_date"), "")}
```

---

## Caso 2 — Reprocesar un mes puntual

Input: `{"process_date": "2023-05-01"}`

Comportamiento: procesa solo `2023-05-01`. No hay loop.

El step de resolución detecta que `process_date` viene en el input y lo usa directamente. `end_date` queda vacío, por lo que se ejecuta una sola vez.

---

## Caso 3 — Reprocesar histórico (loop mensual)

Input: `{"process_date": "2021-01-01", "end_date": "2023-12-01"}`

Comportamiento: loop mes a mes desde `process_date` hasta `end_date`, con `sys.sleep(60)` entre cada iteración.

```yaml
- check_loop_mode:
    switch:
        - condition: ${var_end_date != ""}
          next: loop_historic
        - condition: true
          next: single_execution

- loop_historic:
    assign:
        - current_date: ${var_process_date}
    next: loop_condition

- loop_condition:
    switch:
        - condition: ${current_date <= var_end_date}
          next: build_call_loop
        - condition: true
          next: end_workflow

- build_call_loop:
    assign:
        - sql_part1: ${"CALL `" + sp_{atributo} + "`("}
        - sql_part2: ${" DATE('" + current_date + "')"}
        - sql_part3: ${")"}
        - sql_call: ${sql_part1 + sql_part2 + sql_part3}
    next: log_call_loop

- log_call_loop:
    call: sys.log
    args:
        text: ${"[INFO] Loop histórico - Ejecutando: " + sql_call}
    next: execute_sp_loop

- execute_sp_loop:
    try:
        steps:
            - run_sp_loop:
                call: SyncBigQueryJob
                args:
                    query: ${sql_call}
                    project_id: ${bq_project_id}
                result: queryResult
            - log_ok_loop:
                call: sys.log
                args:
                    text: ${"[OK] Procesado: " + current_date}
    except:
        as: e
        steps:
            - log_err_loop:
                call: sys.log
                args:
                    text: ${"[ERROR] Falló en " + current_date + ": " + json.encode_to_string(e)}
            - raise_loop:
                raise: ${e}
    next: sleep_between_iterations

- sleep_between_iterations:
    call: sys.sleep
    args:
        seconds: 60
    next: advance_month

- advance_month:
    assign:
        # Avanzar al siguiente mes (sumar ~31 días y truncar al día 1)
        - next_ts: ${date.add(time.parse(current_date), duration("P32D"))}
        - current_date: ${text.substring(time.format(next_ts), 0, 7) + "-01"}
    next: loop_condition

- single_execution:
    # Aquí va el bloque normal de build_call → log_call → execute_sp → notify
    next: build_call
```

---

## Patrón general del flujo de fechas

```
resolve_dates
    ↓
check_loop_mode
    ├─ end_date vacío → single_execution (Casos 1 y 2)
    └─ end_date presente → loop_historic (Caso 3)
```
# Subworkflows Reutilizables

Estos dos subworkflows deben incluirse **siempre al final de cada YAML**, sin modificación.
Son idénticos en todos los workflows de atributos ITC.

---

## SyncBigQueryJob

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
            result: BigQueryJobStateResponse
        - SyncBigQueryJobResponse:
            return: ${BigQueryJobStateResponse}
```

---

## BigQueryJobState

```yaml
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
        - JobRunningCheck:
            switch:
              - condition: ${jobGetResponse.status.state == "RUNNING"}
                next: Sleep
              - condition: ${jobGetResponse.status.state == "DONE"}
                next: WorkflowDone
        - WorkflowDone:
            switch:
              - condition: ${"errorResult" in jobGetResponse.status}
                raise: ${jobGetResponse}
        - BigQueryJobStateResponse:
            return: ${jobGetResponse}
```
# DDL Athena — Generación de External Tables

## Patrón general

Todo atributo ITC tiene su tabla externa en Athena con el nombre:
```
sand_attr_{ATRIBUTO}
```

Y su ubicación en S3:
```
s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/{ATRIBUTO}
```

Donde `{ATRIBUTO}` es el mismo nombre dinámico extraído del SP del workflow.

---

## Cómo obtener los campos

### Caso normal (producción): consultar BigQuery
Conectarse a BigQuery y ejecutar:
```sql
SELECT column_name, data_type
FROM `intercorp-data-storage-pv`.master_stage.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'ba_itc_attr_{ATRIBUTO}'
ORDER BY ordinal_position;
```

También obtener el campo de partición:
```sql
SELECT column_name
FROM `intercorp-data-storage-pv`.master_stage.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'ba_itc_attr_{ATRIBUTO}'
  AND is_partitioning_column = 'YES';
```

### Caso especial (primera vez / sin acceso a BQ)
El usuario proveerá la metadata directamente. Usar los campos tal como los entregue.

---

## Reglas de construcción del DDL

1. **Todos los campos van como `string`** — Athena lee Parquet desde S3, los tipos se resuelven en tiempo de lectura
2. **El campo de partición va en `PARTITIONED BY`**, nunca dentro de la lista de columnas principal
3. **El campo de partición es siempre `process_date string`** para todos los atributos ITC
4. **El formato es siempre Parquet** — usar el SerDe y clases estándar de Hive para Parquet
5. **`TBLPROPERTIES`** incluir siempre con `transient_lastDdlTime` usando timestamp Unix actual

---

## Estructura del DDL

```sql
CREATE EXTERNAL TABLE `sand_attr_{ATRIBUTO}`(
  `campo_1` string,
  `campo_2` string,
  -- ... todos los campos del atributo como string
  -- EXCEPTO el campo de partición, que va abajo
)
PARTITIONED BY (
  `process_date` string)
ROW FORMAT SERDE
  'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
STORED AS INPUTFORMAT
  'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat'
OUTPUTFORMAT
  'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat'
LOCATION
  's3://prd-ibk-bi-sharedattrsanbox-9jtg/input/{ATRIBUTO}'
TBLPROPERTIES (
  'transient_lastDdlTime'='<unix_timestamp_actual>')
```

---

## Ejemplos de referencia

### Ejemplo 1 — `entertainment`
- Tabla: `sand_attr_entertainment`
- Location: `s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/entertainment`
- Partición: `process_date`
- Ver: `references/ddl_examples/sand_attr_entertainment.sql`

### Ejemplo 2 — `insurance`
- Tabla: `sand_attr_insurance`
- Location: `s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/insurance`
- Partición: `process_date`
- Ver: `references/ddl_examples/sand_attr_insurance.sql`

---

## Checklist DDL antes de entregar

- [ ] Nombre de tabla: `sand_attr_{atributo}`
- [ ] Todos los campos como `string`
- [ ] Campo de partición `process_date` en `PARTITIONED BY`, no en la lista de columnas
- [ ] LOCATION apunta a `s3://prd-ibk-bi-sharedattrsanbox-9jtg/input/{atributo}`
- [ ] SerDe y clases son las de Parquet (no ORC, no texto)
- [ ] `TBLPROPERTIES` incluido con `transient_lastDdlTime`
# Stored Procedure Export AWS — Generación de prc_export_attribute_aws_{ATRIBUTO}

## Patrón general

Cada atributo ITC tiene un SP de exportación en BigQuery que:
1. Valida que exista data para el periodo solicitado
2. Exporta los datos a GCS en formato Parquet
3. Aplica un join con la tabla de sandbox para enmascarar el ID real → `id_sandbox`

---

## Identificadores dinámicos

| Elemento | Patrón |
|---|---|
| Nombre del SP | `prc_export_attribute_aws_{ATRIBUTO}` |
| Proyecto del SP | `silent-matter-270218.shared_attr_aws` |
| Ruta GCS de exportación | `gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{ATRIBUTO}/%t/{ATRIBUTO}_*.parquet` |
| Tabla fuente BQ | `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_{ATRIBUTO}` |
| Tabla sandbox (join fijo) | `prd-itc-data-sensitive.master_pii.iden_equiv_sandbox` |

---

## Cómo obtener los campos para el SP

Exactamente igual que para el DDL Athena — los campos vienen de BigQuery:
```sql
SELECT column_name
FROM `intercorp-data-storage-pv`.bi_itc_attribute_party.INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'ba_itc_attr_{ATRIBUTO}'
  AND is_partitioning_column = 'NO'
ORDER BY ordinal_position;
```

O bien el usuario los provee directamente desde la metadata.

---

## Estructura del SP — secciones obligatorias

### 1. Cabecera y declaraciones

```sql
CREATE OR REPLACE PROCEDURE `silent-matter-270218.shared_attr_aws.prc_export_attribute_aws_{ATRIBUTO}`(periodo STRING)
OPTIONS (strict_mode=false)
BEGIN

    DECLARE fecha_procesada DATE;
    DECLARE {ATRIBUTO} STRING;
```

### 2. Resolución de fecha y ruta GCS

```sql
    SET fecha_procesada = DATE_SUB(
        DATE_TRUNC(
          CASE
            WHEN SAFE.PARSE_DATE('%Y-%m-%d', periodo) IS NOT NULL
              THEN SAFE.PARSE_DATE('%Y-%m-%d', periodo)
            ELSE DATE(TIMESTAMP(periodo))
          END,
          MONTH
        ),
        INTERVAL 1 MONTH
    );

    SET {ATRIBUTO} = (SELECT FORMAT(
        "gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{ATRIBUTO}/%t/{ATRIBUTO}_*.parquet",
        periodo
    ));

    SET @@query_label='attr_model:shared-aws';
```

### 3. Validación de existencia de data (EXECUTE IMMEDIATE fijo)

```sql
    EXECUTE IMMEDIATE FORMAT(
        """
        SELECT
        IF((SELECT COUNT(1) FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_{ATRIBUTO}`
            WHERE process_date = '%t') > 0,
            'SI HAY DATA DEL PERIODO ACTUAL',
            ERROR('No rows in the table'))
        """
        ,periodo
    );
```

### 4. EXPORT DATA con CAST y JOIN sandbox (dinámico por atributo)

```sql
    EXECUTE IMMEDIATE FORMAT(
        """
        EXPORT DATA
        OPTIONS (
          uri='%s',
          format='PARQUET',
          overwrite=true
        )
        AS
        WITH base AS (
          SELECT
            -- Aquí van todos los campos con CAST(campo AS STRING) AS campo
            -- EXCEPTO id y process_date que se manejan aparte
            cast(id as string) as id,
            cast(process_date as string) as process_date,
            cast(record_source as string) as record_source,
            cast(load_date as string) as load_date,
            cast(creation_user as string) as creation_user,
            cast(dq_flag_ind as string) as dq_flag_ind,
            cast(dq_control_msg as string) as dq_control_msg,
            cast(dq_config_id as string) as dq_config_id,
            -- ... resto de campos del atributo con CAST AS STRING
          FROM
            `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_{ATRIBUTO}`
          WHERE
            process_date = '%t'
        )
        SELECT
          COALESCE(b.id_sandbox, '0') AS id_sandbox,
          -- Todos los campos de base EXCEPTO id (reemplazado por id_sandbox)
          a.process_date,
          a.record_source,
          -- ...
        FROM base a
        LEFT JOIN `prd-itc-data-sensitive.master_pii.iden_equiv_sandbox` b
          ON CAST(a.id AS STRING) = CAST(b.id AS STRING)
        ORDER BY b.id_sandbox DESC
        """
        ,{ATRIBUTO}, periodo
    );

END;
```

---

## Reglas críticas de construcción

1. **`id` nunca va en el SELECT final** — se reemplaza por `id_sandbox` del join con sandbox
2. **`id_sandbox` siempre es el primer campo** del SELECT final con `COALESCE(b.id_sandbox, '0')`
3. **Todos los campos van con `CAST(campo AS STRING) AS campo`** en el CTE base
4. **`process_date` va como `cast(process_date as string)`** en el CTE pero se selecciona de `a.process_date` en el SELECT final
5. **El EXECUTE IMMEDIATE de validación es FIJO** — no varía entre atributos
6. **Los FORMAT args del EXECUTE IMMEDIATE final** siempre son `({ATRIBUTO}_var, periodo)` — en ese orden
7. **`dq_flag_ind`, `dq_control_msg`, `dq_config_id`** son campos de calidad de datos presentes en todos los atributos — incluirlos siempre en el CTE si existen en la tabla fuente
8. **`record_source`, `load_date`, `creation_user`** también son campos estándar de auditoría — incluirlos siempre

---

## Campos estándar presentes en todos los atributos

Estos campos siempre aparecen y tienen orden fijo en el SELECT final:

```
id_sandbox          ← del join (primer campo siempre)
process_date        ← de la tabla
record_source       ← auditoría
load_date           ← auditoría
creation_user       ← auditoría
dq_flag_ind         ← calidad de datos
dq_control_msg      ← calidad de datos
dq_config_id        ← calidad de datos
{campos propios del atributo...}
```

---

## Ejemplo de referencia

Ver `references/sp_examples/prc_export_attribute_aws_entertainment.sql` para el SP completo del atributo `entertainment`.

---

## Checklist SP antes de entregar

- [ ] Nombre: `prc_export_attribute_aws_{atributo}` en proyecto `silent-matter-270218.shared_attr_aws`
- [ ] Parámetro: `periodo STRING`
- [ ] Variable declarada con el nombre del atributo para la ruta GCS
- [ ] Ruta GCS correcta: `gs://p-itcibk-datr-stg-sharing-usct1-esta/data/shared_aws/{atributo}/%t/{atributo}_*.parquet`
- [ ] EXECUTE IMMEDIATE de validación incluido (fijo, no modificar)
- [ ] CTE base con CAST de todos los campos como STRING
- [ ] `id` presente en el CTE base pero NO en el SELECT final
- [ ] SELECT final inicia con `COALESCE(b.id_sandbox, '0') AS id_sandbox`
- [ ] JOIN con `prd-itc-data-sensitive.master_pii.iden_equiv_sandbox`
- [ ] `ORDER BY b.id_sandbox DESC` al final
- [ ] FORMAT args en orden correcto: `({atributo}_var, periodo)`
# Ejemplo Completo — Atributo `entertainment`

CALL de entrada:
```
CALL `intercorp-data-storage-pv.master_stage.sp_load_ba_itc_attr_entertainment`(var_fecha)
```

---

```yaml
main:
    params: [input]
    steps:

    # ─────────────────────────────────────────────────────────────
    # STEP 1: Definición de variables — nunca referenciar literales
    #         de proyectos/SPs/APIs fuera de este bloque
    # ─────────────────────────────────────────────────────────────
    - set_vars:
        assign:
            - bq_project_id: "dev-intercorp-data-operation"
            - sp_entertainment: "intercorp-data-storage-pv.master_stage.sp_load_ba_itc_attr_entertainment"
            - mail_pubsub_project: "central-data-governance-260223"
            - mail_pubsub_topic: "itcm-mail"

    # ─────────────────────────────────────────────────────────────
    # STEP 2: Resolución de fechas (3 casos)
    # ─────────────────────────────────────────────────────────────
    - check_input_date:
        switch:
            - condition: ${default(map.get(input, "process_date"), "") == ""}
              next: use_default_date
            - condition: true
              next: use_input_date

    - use_default_date:
        assign:
            # Primer día del mes anterior (ej: hoy 15-mar-2026 → 2026-02-01)
            - var_process_date: ${text.substring(time.format(date.subtract(sys.now(), duration("P32D"))), 0, 7) + "-01"}
            - var_end_date: ""
        next: check_loop_mode

    - use_input_date:
        assign:
            - var_process_date: ${input.process_date}
            - var_end_date: ${default(map.get(input, "end_date"), "")}
        next: check_loop_mode

    # ─────────────────────────────────────────────────────────────
    # STEP 3: Decide si es ejecución única o loop histórico
    # ─────────────────────────────────────────────────────────────
    - check_loop_mode:
        switch:
            - condition: ${var_end_date != ""}
              next: init_loop
            - condition: true
              next: build_call

    # ─────────────────────────────────────────────────────────────
    # CASO 3: Loop histórico mes a mes
    # ─────────────────────────────────────────────────────────────
    - init_loop:
        assign:
            - current_date: ${var_process_date}
        next: loop_condition

    - loop_condition:
        switch:
            - condition: ${current_date <= var_end_date}
              next: build_call_loop
            - condition: true
              next: end_workflow

    - build_call_loop:
        assign:
            - sql_part1: ${"CALL `" + sp_entertainment + "`("}
            - sql_part2: ${" DATE('" + current_date + "')"}
            - sql_part3: ${")"}
            - sql_call: ${sql_part1 + sql_part2 + sql_part3}
        next: log_call_loop

    - log_call_loop:
        call: sys.log
        args:
            text: ${"[INFO] Loop histórico - Ejecutando: " + sql_call}
        next: execute_sp_loop

    - execute_sp_loop:
        try:
            steps:
                - run_sp_loop:
                    call: SyncBigQueryJob
                    args:
                        query: ${sql_call}
                        project_id: ${bq_project_id}
                    result: queryResult
                - log_ok_loop:
                    call: sys.log
                    args:
                        text: ${"[OK] Procesado mes: " + current_date}
        except:
            as: e
            steps:
                - log_err_loop:
                    call: sys.log
                    args:
                        text: ${"[ERROR] Falló en " + current_date + ": " + json.encode_to_string(e)}
                - build_msg_err_loop:
                    assign:
                        - mail_subject_err_loop: ${"[ERROR] WF sp_load_ba_itc_attr_entertainment"}
                        - mail_body_err_loop: ${"Error en proceso histórico " + current_date + ": " + json.encode_to_string(e)}
                        - mail_msg_err_loop: ${"{ \"subject\": \"" + mail_subject_err_loop + "\", \"body\": \"" + mail_body_err_loop + "\"}"}
                - notify_error_loop:
                    call: http.post
                    args:
                        url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
                        auth:
                            type: OAuth2
                        body:
                            messages:
                                - data: ${base64.encode(mail_msg_err_loop)}
                    result: pubsubErrLoopResult
                - raise_loop:
                    raise: ${e}
        next: sleep_between_iterations

    - sleep_between_iterations:
        call: sys.sleep
        args:
            seconds: 60
        next: advance_month

    - advance_month:
        assign:
            - next_ts: ${date.add(time.parse(current_date), duration("P32D"))}
            - current_date: ${text.substring(time.format(next_ts), 0, 7) + "-01"}
        next: loop_condition

    # ─────────────────────────────────────────────────────────────
    # CASOS 1 y 2: Ejecución única
    # ─────────────────────────────────────────────────────────────
    - build_call:
        assign:
            - sql_part1: ${"CALL `" + sp_entertainment + "`("}
            - sql_part2: ${" DATE('" + var_process_date + "')"}
            - sql_part3: ${")"}
            - sql_call: ${sql_part1 + sql_part2 + sql_part3}

    - log_call:
        call: sys.log
        args:
            text: ${"[INFO] Ejecutando: " + sql_call}

    - execute_sp:
        try:
            steps:
                - run_sp:
                    call: SyncBigQueryJob
                    args:
                        query: ${sql_call}
                        project_id: ${bq_project_id}
                    result: queryResult
                - log_ok:
                    call: sys.log
                    args:
                        text: ${"[OK] sp_load_ba_itc_attr_entertainment ejecutado para " + var_process_date}
                - build_msg_ok:
                    assign:
                        - mail_subject_ok: ${"[OK] WF sp_load_ba_itc_attr_entertainment"}
                        - mail_body_ok: ${"Proceso ejecutado correctamente para el mes: " + var_process_date}
                        - mail_msg_ok: ${"{ \"subject\": \"" + mail_subject_ok + "\", \"body\": \"" + mail_body_ok + "\"}"}
                - notify_ok:
                    call: http.post
                    args:
                        url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
                        auth:
                            type: OAuth2
                        body:
                            messages:
                                - data: ${base64.encode(mail_msg_ok)}
                    result: pubsubOkResult
        except:
            as: e
            steps:
                - log_error:
                    call: sys.log
                    args:
                        text: ${"[ERROR] sp_load_ba_itc_attr_entertainment - " + json.encode_to_string(e)}
                - build_msg_error:
                    assign:
                        - mail_subject_err: ${"[ERROR] WF sp_load_ba_itc_attr_entertainment"}
                        - mail_body_err: ${"Error en proceso " + var_process_date + ": " + json.encode_to_string(e)}
                        - mail_msg_err: ${"{ \"subject\": \"" + mail_subject_err + "\", \"body\": \"" + mail_body_err + "\"}"}
                - notify_error:
                    call: http.post
                    args:
                        url: ${"https://pubsub.googleapis.com/v1/projects/" + mail_pubsub_project + "/topics/" + mail_pubsub_topic + ":publish"}
                        auth:
                            type: OAuth2
                        body:
                            messages:
                                - data: ${base64.encode(mail_msg_err)}
                    result: pubsubErrResult
                - raise_error:
                    raise: ${e}

    - end_workflow:
        return: ${"[INFO] Workflow sp_load_ba_itc_attr_entertainment finalizado. Último proceso: " + var_process_date}

# ═══════════════════════════════════════════════════════════════
# SUBWORKFLOWS — No modificar, son estándar para todos los WF
# ═══════════════════════════════════════════════════════════════

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
            result: BigQueryJobStateResponse
        - SyncBigQueryJobResponse:
            return: ${BigQueryJobStateResponse}

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
        - JobRunningCheck:
            switch:
              - condition: ${jobGetResponse.status.state == "RUNNING"}
                next: Sleep
              - condition: ${jobGetResponse.status.state == "DONE"}
                next: WorkflowDone
        - WorkflowDone:
            switch:
              - condition: ${"errorResult" in jobGetResponse.status}
                raise: ${jobGetResponse}
        - BigQueryJobStateResponse:
            return: ${jobGetResponse}
```