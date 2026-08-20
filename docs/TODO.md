# TODO — Centralización de Consentimientos LPDP Interbank (IBK)

**SPEC:** spec-ibk-20260819-001  |  **Status:** draft

### DISCOVERY (sub-etapa de DESIGN)
- [x] Resolver `consentimiento_ibk_archivo` — confirmado: dataset `raw_ibk_dlk`, tabla `t_consent_transaction_{fecha_archivo}_external` (una nueva por fecha, no estática)
- [x] Confirmar project id real de `iden_party` — confirmado `dev-intercorp-data-operation` (guión, no guión bajo; el guión bajo fue rechazado por la API de BigQuery)
- [x] Confirmar qué representa `itc_company_id = '1000'` — confirmado: segundo código de Interbank (misma empresa, 2 códigos)
- [x] Confirmar si `iden_itc_party_prd` tiene la misma estructura que `iden_itc_party` — confirmado por el equipo
- [ ] Generar/cargar glosario propio de `iden_itc_party_prd` (por ahora solo hay glosario de la tabla de referencia `iden_itc_party`, sin acceso BQ para perfilar la `_prd` directamente)
- [ ] Confirmar si `iden_itc_party_prd` también carece de partición (impacto en costo de la SP — la tabla de referencia tiene 467.7M filas sin partición)

### DESIGN
- [x] PHYSICAL_DESIGN completado (2026-08-19) — DDL físico de ambas tablas destino + referencia de tabla externa
  → Ver: data/bigquery/master_party/t_consent_transaction/ddl/, data/bigquery/master_party/ba_customer_consent_group/ddl/
- [x] Cambio de `CREATE OR REPLACE TABLE` → `CREATE TABLE IF NOT EXISTS` en `ba_customer_consent_group.sql` — aceptado por el equipo
- [x] `approval_channel_name` en `ba_customer_consent_group` — confirmado: siempre NULL, no tiene origen en `t_consent_transaction`
- [ ] Confirmar exactitud del offset `folder_date = process_date - 1 día` (RN-IBK-002) con Interbank
- [ ] Definir motor de orquestación (Cloud Workflows / Composer) para los 3 modos de ejecución (normal/manual/reproceso)
- [ ] Confirmar fuentes y volumen con el equipo

### CODING
- [x] SP: `sp_t_consent_transaction_ibk.sql` — `CREATE OR REPLACE EXTERNAL TABLE` dinámico + cruce iden_party (por party_id **e** itc_company_id, ver nota abajo) + DELETE/INSERT por itc_company_id+consent_date + RAISE si el archivo llega vacío
- [x] SP: `sp_ba_customer_consent_group_ibk.sql` — filtro CP_2/otorgado + DELETE/INSERT, acotado al scope que dejó el SP anterior
- [x] Test: `test_sp_t_consent_transaction_ibk.sql` (⚠️ requiere fixture real en GCS para correr — ver notas del archivo) y `test_sp_ba_customer_consent_group_ibk.sql` (ejecutable, sin dependencias externas)
- [ ] ⚠️ Confirmar el JOIN de `sp_t_consent_transaction_ibk`: se igualó `party_id` **y** `itc_company_id` entre el archivo e `iden_itc_party_prd` (para evitar fan-out si la persona está en varias empresas) — validar contra datos reales en cuanto haya acceso BQ
- [ ] ⚠️ `sp_t_consent_transaction_ibk` NO elimina `tmp_t_consent_transaction_ibk` al terminar — lo hace `sp_ba_customer_consent_group_ibk` al final. El Workflow (ORCHESTRATION) debe llamarlos **en secuencia**, nunca en paralelo
- [ ] Confirmar el literal `record_source = 'LPDP_IBK'` usado en ambos SPs — no estaba definido en el requerimiento original
- [ ] Implementar encriptación AEAD para `documento_legal_id` y `signed_document` (confirmado por Data Owner) — no incluida en esta pasada de CODING, evaluar si va en los SPs o en una vista posterior

### INTEGRIDAD            ← activada por el usuario (2026-08-19): etapas.integridad: true
- [x] `fuentes[]` completadas con `rol` (principal: `consentimiento_ibk_archivo`, secundaria: `iden_party`), `llave` y `campo_fecha`
- [x] `reglas_integridad` agregado al spec: 1 regla `detener_proceso` (actualidad, D-1) + 4 `excluir_registros` (duplicados/llave_nula en ambas fuentes)
- [x] SP: `sp_integridad_t_consent_transaction.sql` — evalúa actualidad de `consentimiento_ibk_archivo`, sin escribir tablas (solo OUT params)
- [x] Patrón `QUALIFY ROW_NUMBER()` + `WHERE llave IS NOT NULL` aplicado en `sp_t_consent_transaction_ibk.sql` para ambas fuentes
- [x] `deploy_dev.json`/`deploy_prd.json`: SP de integridad agregado en `bigquery_sp`, después del SP de carga principal
- [x] Workflow: gate de integridad insertado dentro del `for` de fechas, antes de cada llamada a `sp_t_consent_transaction_ibk` — si `o_flag_detener=1`, hace `raise` y reutiliza el mecanismo de checkpoint/mail de error ya existente
- [x] `registro_resultados: true` (2026-08-19, tras activar MONITORING) — `registrar_resultado_integridad` (`RegisterIntegrityResults`) agregado al workflow; histórico ahora se matricula en `metadata_operational`
- [x] 5 payloads de matrícula en `data/integrity/master_party/t_consent_transaction/payloads/` (uno por regla), agregados a `deploy_[env].json` bajo `monitoring_register` (después del directorio de monitoring)
- [ ] Confirmar si algún duplicado/llave nula debería escalar a `detener_proceso` en vez de excluirse silenciosamente (hoy los 4 checks secundarios son `excluir_registros`, el default)
- [ ] Validar en TESTING que la tabla externa que crea `sp_integridad_t_consent_transaction.sql` no choque con la que crea `sp_t_consent_transaction_ibk.sql` para la misma fecha (mismo nombre, ambas `CREATE OR REPLACE` — debería ser idempotente pero no se probó en vivo)

### MONITORING            ← activada por el usuario (2026-08-19): etapas.monitoring: true, METADATA_API_URL agregado a env_dev.json
- [x] Bloque `monitoring:` completado en el spec (`METADATA_API_URL` como referencia `${METADATA_API_URL}`, `process.*` con `flag_scheduler`, `tasks[]` con `description`)
- [x] Payloads de matrícula: `data/monitoring/master_party/t_consent_transaction/payloads/{process_t_consent_transaction_ibk, task_sp_t_consent_transaction_ibk, task_sp_ba_customer_consent_group_ibk}.json`
- [x] `deploy_dev.json`/`deploy_prd.json`: clave `monitoring_register` agregada (payloads de monitoring + integridad)
- [x] `env_prd.json`: `METADATA_API_URL` completado con el valor conocido del checklist del estándar
- [x] Workflow: variables monitoring en `set_vars`, `var_execution_type` derivado de `var_modo` (NORMAL/MANUAL/REPROCESO — no fijo como sugiere la plantilla genérica), ambos SPs instrumentados con `TrackedBigQueryJobWithResults`, `UpdateProcessStatus` al final del `try` y en el `except`, `MainResponse` extendido con métricas
- [x] Sub-workflows agregados: `TrackedBigQueryJobWithResults`, `CreateExecution`, `UpdateExecution`, `UpdateProcessStatus`, `RegisterIntegrityResults` (`SyncBigQueryJobWithResults` ya existía desde INTEGRIDAD)
- [x] Ambos SPs (`sp_t_consent_transaction_ibk.sql`, `sp_ba_customer_consent_group_ibk.sql`): 2 parámetros `OUT` (`o_execution_data_read`, `o_execution_data_write`) agregados al final de la firma, capturados con `@@row_count` (write) y `COUNT(1)` sobre la tabla de stage (read)
- [x] Tests actualizados con los 2 argumentos `OUT` nuevos + asserts de las métricas
- [ ] ⚠️ Prerequisito IAM manual: la SA de Cloud Build (`trv-itcbi-devops-app@itc-data-devops-01.iam.gserviceaccount.com`) necesita `roles/run.invoker` sobre la metadata API (`METADATA_API_URL`) para que la matrícula funcione en deploy
- [ ] Confirmar `company_id`/`company_code` (`"000"`/`"IBK"`) en el catálogo de control de procesos — se asumieron iguales a `c_itc_company`, pero es un catálogo distinto
- [ ] Confirmar el nombre real del workflow desplegado en GCP coincide con `${env}-t-consent-transaction-ibk` (usado en `monitoring.process.code` y en los payloads)

### DATA QUALITY          ← activada por el usuario (2026-08-19): etapas.data_quality: true
- [x] SP DQ: `sp_dq_t_consent_transaction.sql` (3 reglas), `sp_dq_ba_customer_consent_group.sql` (2 reglas) — iteran `dq_config`, registran en `dq_control`
- [x] `dml_dq_config_t_consent_transaction.sql` / `dml_dq_config_ba_customer_consent_group.sql` — INSERT de las 5 reglas, agregados a `bigquery_dml` (solo `deploy_dev.json`, per regla del framework "DML solo corre en dev")
- [x] Workflow: `ejecutar_dq_tct`/`ejecutar_dq_bccg` agregados después de cada SP de carga (dentro del `for` de fechas); chequeo agregado `validar_dq_criticas` después del loop, no detiene el pipeline — solo marca el asunto del mail como "[⚠️ OK CON DQ FAILS]" si hay reglas críticas en fail
- [ ] ⚠️ Mapeo de vocabulario asumido: spec usa `dimension: unicidad|validez`, el framework central (`data-quality.md`) usa `dq_dimension: duplicidad|conformidad` — mapeé `unicidad→duplicidad` y `validez→conformidad`. Confirmar que es el mapeo correcto con el equipo dueño de `itcm-dp-dataquality-core`
- [ ] ⚠️ No se generó `bigquery_dml` en `deploy_prd.json` (regla del framework: DML solo en dev) — esto deja sin resolver cómo se registran las reglas DQ en producción; confirmar con el equipo el mecanismo real
- [ ] ⚠️ `validar_dq_criticas` cuenta fails por `execution_date = CURRENT_DATE()` sin distinguir `execution_id` — si se corre más de una vez el mismo día (normal + reproceso manual), el conteo mezcla ambas corridas
- [ ] No se generaron `dml_dq_monitor_config_*.sql` — el spec no declara monitores DQ explícitos, solo reglas
- [x] **BUG (2026-08-20):** trigger Cloud Build falló en `deploy-dml` — `Not found: Table dev-itc-customer-services:demo_migracion.dq_config was not found`. Nunca se creó el DDL de `dq_config`/`dq_control`, solo el `INSERT` (`dml_dq_config_*`). Fix: agregados `ddl_dq_config.sql`/`ddl_dq_control.sql` en `t_consent_transaction/ddl/` (`CREATE TABLE IF NOT EXISTS`, tablas compartidas del `dataset_dq`), registrados en `componentes[]` del spec y al inicio de `bigquery_ddl` en `deploy_dev.json`/`deploy_prd.json`. Pendiente: re-disparar el trigger Dataops dev

### COMPLIANCE
- [x] `fac-data-rules-check` ejecutado (2026-08-19) — 2 críticas + 2 advertencias encontradas y corregidas. Reporte: `docs/reports/rules-check-2026-08-19.md`
- [x] Campos DQ (`dq_flag_ind`, `dq_control_msg`, `dq_config_id`) agregados vía `alter/` a ambas tablas destino — quedan `NULL`, el modelo DQ actual valida a nivel de tabla, no de fila
- [x] Nombres de tabla temporal hardcodeados (`tmp_t_consent_transaction_ibk`, `tmp_ba_customer_consent_group_ibk`) — documentados como excepción aceptada en `restricciones[]`, no se crearon variables Dataops nuevas
- [x] Verificar campos de auditoría (load_date, record_source, creation_user) — presentes en ambos DDL
- [x] `fac-data-stage-compliance` ejecutado (2026-08-19) contra los 5 dominios completos de `data/rules/` — 1 ALTA, 3 MEDIA, 2 BAJA. Reporte: `docs/reports/compliance-2026-08-19.md`
- [x] Hallazgo ALTA corregido: `sp_t_consent_transaction_ibk.sql` y `sp_integridad_t_consent_transaction.sql` ahora reciben `p_process_date_ini`/`p_process_date_end` (mismo valor en ambos) en vez de un único `p_process_date` — actualizado también el workflow (`build_sql_integridad_p1`, `build_sql_tct_p1`) y el test `test_sp_t_consent_transaction_ibk.sql`
- [ ] ⚠️ 3 hallazgos MEDIA aceptados como excepción documentada (no corregidos — son contradicciones entre documentos del propio framework, no bugs del módulo): cabecera ausente en el workflow (`data/rules/workflow.md` vs `data/standard/services/workflow.md`), `SELECT *`/`t.*` en el patrón de dedup de `sp_t_consent_transaction_ibk.sql` (`data/rules/bigquery.md` vs `data/standard/data-integrity.md` §4), `DROP TABLE IF EXISTS` sobre las 2 tablas tmp efímeras en `sp_ba_customer_consent_group_ibk.sql`
- [ ] 2 hallazgos BAJA sin corregir (cosméticos): falta `deploy_qa.json`/`env_qa.json` en el repo; naming de `wf-`/`cs-` no sigue literalmente `{tabla_out_kebab}-{emp}`
- [x] **BUG real confirmado (2026-08-20):** trigger Cloud Build falló en `deploy-workflow` (`service_account` inválido/vacío) — el hallazgo MEDIA de cabecera ausente en `wf-ibk-consentimiento.yaml` sí rompía el deploy. `data/standard/services/workflow.md` ("sin cabecera") está desactualizado; la guía correcta es `dataops-configurator/SKILL.md` §8. Fix: agregada cabecera `name: ${env}-t-consent-transaction-ibk` / `region` / `project` / `service_account: ${service_account_job}` antes de `source:`. `name` coincide con el que ya usaba `cs-ibk-consentimiento.yaml`, sin cambios ahí
- [x] **BUG real confirmado (2026-08-20):** `gcloud workflows deploy` falló con `parse error: maximum length for an expression is 400 characters` en el step `handle_error` (408 bytes). Auditados TODOS los `${...}` del workflow (script con plegado YAML + conteo en bytes UTF-8, no caracteres) — solo esa expresión superaba el límite; `build_sql_tct_p1` quedaba a 26 bytes del límite tras agregar `p_process_date_ini/end`. Fix: `handle_error` partido en `build_content_error_p1`/`p2` (con sus `next:` corregidos en `sugerencia_reproceso`/`sugerencia_simple`, que antes saltaban directo a `handle_error` saltándose el build); `build_sql_tct` repartido de 2 a 3 partes. Máximo verificado tras el fix: 324 bytes en todo el archivo
- [x] **BUG de framework confirmado (2026-08-20):** `metadata_register_build` falló con HTTP 422 al matricular `RI-IBK-T_CONSENT_TRANSACTION-001` — la API de metadata NO tiene la tabla `ct_datapipeline_integrity_rule` documentada en `data/standard/data-integrity.md` §6.3; matricula todo (SPs y reglas de integridad) como `ct_datapipeline_task` (mismo endpoint/schema que los 2 SPs de carga que sí pasaron). El 422 devolvió los campos exactos requeridos (`object_catalog/schema/name/type`, `flag_reprocess`) y prohibidos (`task_code`, `source_id`, `check_type`, `tolerance_days`, `key_columns`, `date_field`, etc.). Fix: reescritos los 5 `integrity_rule_t_consent_transaction_ibk_00{1..5}.json` con la forma real de task — `object_catalog/schema/name` apuntando a la fuente validada (`consentimiento_ibk_archivo` para 001-003, `iden_party` para 004-005), `technical_name` = SP que implementa la regla, `code` = el ID de regla (único por archivo)
- [ ] ⚠️ **Riesgo no verificado:** el sub-workflow `RegisterIntegrityResults` (runtime) postea `task_code: ${var_sp_integridad_tct}` (el path del SP `sp_integridad_t_consent_transaction`) al endpoint `.../integrity-execution/creation`. Ese SP nunca quedó matriculado como task por sí mismo (solo aparece como `technical_name` dentro de los 5 payloads de reglas, cuyo `code` es el ID de regla, no el path del SP) — si ese endpoint valida `task_code` por FK contra `ct_datapipeline_task.code`, la matrícula del **resultado en runtime** podría fallar aunque el deploy ya pasó. Verificar en TESTING al correr el workflow por primera vez; si falla, matricular `sp_integridad_t_consent_transaction` como task propio

### ORCHESTRATION
- [x] Workflow: `wf-ibk-consentimiento.yaml` — normal (fecha de sistema, NO "ayer" — desviación intencional del default del framework, ver RN-IBK-009)/manual (`process_date`)/reproceso (`process_date_init`+`process_date_fin`, loop interno vía `GENERATE_DATE_ARRAY` + `for`)
- [x] Cloud Scheduler: `cs-ibk-consentimiento.yaml` — diario `0 10 * * *` America/Lima, dispara modo normal (`argument: {"process_date": ""}`)
- [ ] ⚠️ Validar en TESTING el parseo de `bqRangoFechas.rows` (formato REST de BigQuery para arrays) en el step `construir_lista_fechas` — es la parte más frágil del workflow, no se pudo probar contra una ejecución real
- [x] Confirmado: si una fecha falla a mitad de un reproceso, el workflow se detiene ahí (comportamiento esperado, no todo-o-nada). Se agregó `var_ultima_fecha_intentada` como checkpoint — el `except` lo imprime en logs (`severity: ERROR`) y en el mail de error, con la sugerencia exacta de con qué `process_date_init`/`process_date` reanudar
- [x] Correos reemplazados por `lsullonm@intercorp.com.pe` **solo para pruebas** — ⚠️ pendiente reemplazar por los destinatarios reales antes de producción (queda marcado inline en el YAML)

### TESTING
- [x] `fac-data-stage-testing` ejecutado (2026-08-19) — **⛔ BLOCKED**: sin acceso MCP a `dev-intercorp-data-storage`/`dev-intercorp-data-operation`, y ningún SP del módulo existe en `dev-itc-customer-services.demo_migracion` → ningún artefacto está desplegado en dev todavía. Reporte: `docs/reports/testing-2026-08-19.md`
- [ ] Ejecutar trigger InfraOps (SAs + permisos IAM) y trigger Dataops dev (DDL/SPs/Workflow/Scheduler), confirmar SUCCESS en ambos
- [ ] Re-ejecutar `fac-data-stage-testing` una vez desplegado
- [ ] Ejecutar DDL en dev
- [ ] Validar conteos vs archivo fuente
- [ ] Validar las 5 reglas DQ (una vez activada la etapa)
- [ ] Probar los 3 escenarios: normal, manual (`process_date` único), reproceso (rango de fechas)

### DATAOPS
- [x] Backup de `deploy_dev.json`/`deploy_prd.json`/`env_dev.json`/`env_prd.json` en `deploy/backup/*_20260819172956.json` antes de regenerar
- [x] `deploy_dev.json`/`deploy_prd.json` regenerados desde cero a partir de `componentes[]` — 2 `bigquery_ddl`, 5 `bigquery_sp`, `bigquery_dml` (solo dev, 2 configs DQ), `workflow`, `cloud_scheduler`, `monitoring_register`
- [x] Confirmado: el componente `ddl` de referencia `ext_t_consent_transaction_external.sql` quedó excluido de `bigquery_ddl` (como se venía marcando desde PHYSICAL_DESIGN)
- [x] Cobertura de variables validada: todo `${...}` genuino de Dataops usado en `data/bigquery/master_party/`, `data/monitoring/`, `data/integrity/` y `pipeline/` ya está en `env_dev.json`. No hizo falta agregar ninguna variable nueva
- [ ] Completar `env_prd.json`: `project_operation`, `project_analytics`, `project_billing`, `dataset_sp`, `dataset_stage`, `dataset_dq`, `service_account_job`, `service_account_app`, `project_consentimiento_ibk_archivo`, `dataset_consentimiento_ibk_archivo`, `project_iden_party`, `dataset_iden_party`, `project_t_consent_transaction`, `project_ba_customer_consent_group` siguen en `pendiente_definir`
- [ ] Variables huérfanas detectadas (no usadas por ningún artefacto, no bloqueante): `project_analytics`, `project_billing` en ambos env — el módulo usa el patrón de 3-variables-por-tabla en su lugar. `table_consentimiento_ibk_archivo` tampoco se referencia directamente (el nombre real se arma dinámico en el SP) — se dejó solo como documentación

### SECURITY
- [x] `fac-data-stage-reality-check` (2026-08-19): confirmado que `project_operation`/`project_analytics`/`dataset_sp`/`dataset_stage`/`dataset_dq` y `service_account_job` en `env_dev.json` son valores de un proyecto/SA operativo **compartido** (no exclusivos del módulo) — patrón esperado, no un resto de otro módulo. `seguridad.permisos` del spec ahora referencia `${service_account_job}` en vez de un literal distinto
- [ ] Solicitar/confirmar que `${service_account_job}` tenga efectivamente `dataViewer` sobre `iden_itc_party_prd` y `dataEditor` sobre `master_party` (el equipo indica que sí, pendiente de verificación formal en INFRAOPS)
- [x] **BUG real confirmado (2026-08-20), primera corrida del workflow en dev:** `Access Denied: ... does not have storage.objects.list access to the Google Cloud Storage bucket ... p-ibkbi-rdp-stg-dlk-us-suoh`. La SA `dev-demo-migra-matillion-job@dev-itc-customer-services.iam.gserviceaccount.com` (`service_account_job`) no tiene permiso de lectura sobre el bucket GCS donde IBK deposita el archivo diario — necesario porque `sp_t_consent_transaction_ibk.sql`/`sp_integridad_t_consent_transaction.sql` crean una EXTERNAL TABLE apuntando directo a `gs://p-ibkbi-rdp-stg-dlk-us-suoh/...`. **Pendiente: otorgar rol `roles/storage.objectViewer` (o `Storage Object Viewer`) sobre el bucket `p-ibkbi-rdp-stg-dlk-us-suoh` a esa SA** — esto es un cambio de IAM en infraestructura compartida (el bucket es de Interbank/otro proyecto), no algo que se resuelva en este repo. Coordinar con el equipo dueño del bucket o InfraOps

### DOCUMENTATION
- [ ] Actualizar glosario de `t_consent_transaction` y `ba_customer_consent_group`
- [ ] Actualizar README del repo
- [ ] Generar diagramas de arquitectura (`fac-data-diagrams`)
