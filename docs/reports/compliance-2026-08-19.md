# Reporte COMPLIANCE — 2026-08-19

> **Repo:** `itcm-dp-consentimiento-ibk-s6ba` · **SPEC:** spec-ibk-20260819-001 · **Ejecutado por:** lsullon (vía sesión de Claude Code)
> **Resultado:** ⚠️ PASS con advertencias (hallazgo ALTA corregido el mismo día — ver Actualización al final)

Auditoría contra los 5 dominios de `data/rules/`: `bigquery.md`, `security.md`, `workflow.md`, `dataops.md`, `general.md`. A diferencia de `fac-data-rules-check` (10 reglas rápidas, ya corregido el día de hoy), esta pasada revisó las reglas completas de cada dominio.

---

## 🟠 ALTA

### 1. SPs con fecha usan `p_process_date` único, no el par `p_process_date_ini`/`p_process_date_end`
**Regla:** `data/rules/bigquery.md` — "SPs con fechas usan process_date_ini y process_date_end — nunca un único process_date"
**Archivos:**
- `data/bigquery/master_party/t_consent_transaction/sp/sp_t_consent_transaction_ibk.sql` (parámetro `p_process_date DATE`)
- `data/bigquery/master_party/t_consent_transaction/sp/sp_integridad_t_consent_transaction.sql` (parámetro `p_process_date DATE`)

**Contexto:** nuestro Workflow ya itera fecha por fecha en un `for` (normal/manual/reproceso) y llama a cada SP **una vez por fecha** — nunca le pasamos un rango al SP. Por diseño (cada fecha tiene su propia tabla externa `t_consent_transaction_{fecha_archivo}_external`), no tiene sentido que el SP procese un rango internamente.

**Fix sugerido (sin cambiar el comportamiento):** renombrar `p_process_date` → `p_process_date_ini` + agregar `p_process_date_end`, y que el Workflow siga pasando `fecha_actual` en ambos (`ini = end` siempre, exactamente como indica la convención del "Caller" en la regla). Esto cumple la letra de la regla sin rediseñar nada.

---

## 🟡 MEDIA

### 2. Cabecera de despliegue ausente en el Workflow — **conflicto entre dos estándares del propio framework**
**Regla:** `data/rules/workflow.md` exige `name`/`region`/`project`/`service_account` con `${...}` en la cabecera del archivo.
**Pero:** `data/standard/services/workflow.md` ("Estructura General del Archivo") dice explícitamente que durante desarrollo el archivo **solo** debe tener el bloque `source:`, sin cabecera — y `fac-data-stage-orchestration.md` (el comando que ejecutamos) instruye lo mismo ("Solo el bloque `source:` — sin cabecera").
**Archivo:** `pipeline/workflow/master_party/t_consent_transaction/wf-ibk-consentimiento.yaml`
**No se corrige sin definición del equipo:** seguimos la instrucción del comando de ORCHESTRATION. Si `data/rules/workflow.md` es la versión vigente, hay que actualizar también `data/standard/services/workflow.md` y `fac-data-stage-orchestration.md` — no es algo que deba resolver un solo módulo.

### 3. `SELECT *` en SP de producción — **conflicto con el patrón obligatorio de integridad**
**Regla:** `data/rules/bigquery.md` — "Sin SELECT * en SPs de producción"
**Archivo:** `data/bigquery/master_party/t_consent_transaction/sp/sp_t_consent_transaction_ibk.sql` líneas 166, 168, 181, 183 (`SELECT * EXCEPT(rn)` / `SELECT t.*, ROW_NUMBER()...`)
**Pero:** este es exactamente el "patrón obligatorio de exclusión" que exige `data/standard/data-integrity.md` §4 para implementar `accion: excluir_registros` (duplicados/llave nula) — mismo patrón, palabra por palabra, en el estándar de integridad. No se corrige sin decidir cuál regla prevalece.

### 4. `DROP TABLE IF EXISTS` en SP de producción
**Regla:** `data/rules/security.md` — "Los SPs de producción no deben contener: DROP TABLE..."
**Archivo:** `data/bigquery/master_party/ba_customer_consent_group/sp/sp_ba_customer_consent_group_ibk.sql` líneas 128, 131
**Contexto:** son 2 `DROP TABLE IF EXISTS` sobre tablas **efímeras que el propio módulo crea** (`tmp_t_consent_transaction_ibk`, `tmp_ba_customer_consent_group_ibk`), no sobre tablas de producción con datos reales — mismo caso que ya documentamos como excepción aceptada para el `CREATE OR REPLACE TABLE` de esas mismas tablas (ver `restricciones[]` del spec), pero la regla de `DROP TABLE` no tiene ese carve-out explícito para tablas `tmp_*`. Recomiendo extender la misma excepción documentada a este caso.

---

## 🟢 BAJA

### 5. Falta `deploy_qa.json` / `env_qa.json`
**Regla:** `data/rules/dataops.md` — "Los archivos deploy_qa.json y deploy_prd.json deben existir aunque sean idénticos a deploy_dev.json. El framework los requiere."
**Estado actual:** solo existen `deploy_dev.json` y `deploy_prd.json` (ver `deploy/`).
**Nota:** ninguna etapa anterior de este flujo (`fac-data-init-project`, `fac-data-stage-dataops`) pidió generar `qa` — es otra inconsistencia entre `data/rules/dataops.md` y los comandos reales del framework, no un olvido puntual de este módulo.

### 6. Naming del workflow/scheduler no sigue literalmente `{tabla_out_kebab}-{emp}`
**Regla:** `data/rules/dataops.md` / `data/rules/general.md` — `cs-{tabla_out_kebab}-{emp}.yaml`, `wf-{tabla_out_kebab}-{emp}.yaml`
**Archivos:** `wf-ibk-consentimiento.yaml`, `cs-ibk-consentimiento.yaml` (el patrón literal sería `wf-t-consent-transaction-ibk.yaml` / `cs-t-consent-transaction-ibk.yaml`)
**Contexto:** nombre definido desde ORCHESTRATION y usado consistentemente en `deploy_[env].json`, payloads de monitoring/integridad y `monitoring.process.code`. Cosmético — cambiar el nombre de archivo ahora implicaría actualizar referencias en varios lugares para un beneficio solo de consistencia de naming.

---

## ✅ Verificado OK (sin hallazgos)

- Sin proyectos/datasets/SAs/URLs hardcodeados en ningún SQL o YAML del módulo (`REGLA 1` bigquery.md/general.md)
- `CREATE TABLE IF NOT EXISTS` en ambos DDL finales; `CREATE OR REPLACE TABLE`/`EXTERNAL TABLE` solo en tablas temporales/externas (bigquery.md)
- `ALTER TABLE` en archivo independiente, solo `ADD COLUMN IF NOT EXISTS`, sin `DROP COLUMN` en ningún archivo (bigquery.md, general.md)
- Ambas tablas destino con partición, clustering donde aplica, `OPTIONS(description=..., labels=[...])` y los 3 campos de auditoría + los 3 campos DQ (agregados hoy vía `alter/`)
- Orden `DECLARE` antes de `SET` respetado en los 4 SPs con `BEGIN` (incluidos los `OUT` de monitoring)
- `DELETE FROM` siempre con `WHERE`/`EXISTS` — nunca un `DELETE` sin filtro (security.md)
- SA correcta por componente: `${service_account_job}` en `cloud_scheduler` (security.md, REGLA 7)
- OIDC para llamadas a la metadata API, OAuth2 para Pub/Sub (security.md)
- `sql_rule` de las 5 reglas DQ retorna filas inválidas, no `COUNT(*)` (REGLA 9)
- `env` no está declarado en `env_dev.json`/`env_prd.json` (REGLA 10)
- `prd` sin entradas en `bigquery_dml` (dataops.md)
- Cada RN relevante referenciada con su ID en comentarios de los SPs (general.md)
- `v_billing_project` y `email_body: {}` presentes en `set_vars`; `verificar_email_body` antes de `enviar_mail`; logs `[BUILD] query_... =` antes de cada invocación (workflow.md)
- Ninguna expresión `${}` contiene el patrón `": "` (verificado con `grep '${.*: '` sobre el workflow — sin matches)
- Gate de integridad completo: ubicado antes del `try`/dentro del loop de fechas, usa `SyncBigQueryJobWithResults`, `registrar_resultado_integridad` antes de `evaluar_integridad`, notifica con el motivo real

---

## Resumen

| Severidad | Violaciones |
|---|---|
| 🔴 CRÍTICA | 0 |
| 🟠 ALTA | 1 |
| 🟡 MEDIA | 3 |
| 🟢 BAJA | 2 |

### Resultado original: ❌ FAIL — 1 hallazgo ALTA (`p_process_date` sin par `ini`/`end`)

### Próxima etapa
Las 3 MEDIAS son conflictos documentados entre estándares del propio framework (no bugs de este módulo) — quedan como excepción documentada, igual que el resto de casos similares en `restricciones[]` del spec.
Las 2 BAJAS son cosméticas/de proceso del framework, no bloquean.

---

## Actualización — 2026-08-19 (mismo día, tras aplicar corrección)

✅ **Hallazgo ALTA — FIXED.** Se renombró el parámetro en ambos SPs:
- `sp_t_consent_transaction_ibk.sql`: `p_process_date DATE` → `p_process_date_ini DATE, p_process_date_end DATE`. `v_folder_date` ahora se calcula desde `p_process_date_ini`.
- `sp_integridad_t_consent_transaction.sql`: mismo cambio de firma.
- `wf-ibk-consentimiento.yaml`: `build_sql_integridad_p1` y `build_sql_tct_p1` ahora arman el `CALL` con `DATE '<fecha_actual>'` repetido dos veces (ini = end), con comentario explicando por qué.
- `test_sp_t_consent_transaction_ibk.sql`: los 2 `CALL` de prueba actualizados a `v_fecha_prueba, v_fecha_prueba`.

Ambos SPs siguen procesando una única fecha por invocación (el Workflow ya itera fecha por fecha) — el cambio es solo de firma, sin alterar el comportamiento ni el diseño de una tabla externa por fecha.

Los 3 hallazgos MEDIA (cabecera del workflow, `SELECT *` en el patrón de dedup, `DROP TABLE` sobre tablas tmp efímeras) se dejaron inicialmente **sin corregir**, documentados como excepción aceptada por ser contradicciones entre distintos documentos "oficiales" del propio framework.

### Resultado actualizado: ⚠️ PASS con advertencias — 0 CRÍTICA, 0 ALTA, 3 MEDIA (1 confirmada como bug real, ver abajo), 2 BAJA (cosméticas)

---

## Actualización — 2026-08-20 (falla real de deploy confirma el hallazgo MEDIA #2)

El trigger de Cloud Build falló en el paso `deploy-workflow`:
```
ERROR: (gcloud.workflows.deploy) INVALID_ARGUMENT: request contains errors
- field: workflow.service_account
  description: the referenced service account "projects/-/serviceAccounts/" is invalid
```

Esto confirma que el hallazgo MEDIA #2 (cabecera ausente en `wf-ibk-consentimiento.yaml`) **no era solo un conflicto documental — rompía el deploy real**. La guía correcta es `data/skills/build/dataops/dataops-configurator/SKILL.md` §8 ("workflow — Cloud Workflows"): la cabecera (`name`, `region`, `project`, `service_account`) debe estar **en el mismo archivo YAML**, antes de `source:` — el framework no la inyecta automáticamente. `data/standard/services/workflow.md` (que decía lo contrario y que seguimos durante ORCHESTRATION) está desactualizado en este punto.

**Fix aplicado:** agregada la cabecera a `wf-ibk-consentimiento.yaml`:
```yaml
name: ${env}-t-consent-transaction-ibk
region: us-central1
project: ${project_operation}
description: "Centralización de Consentimientos LPDP Interbank (IBK) — t_consent_transaction + ba_customer_consent_group"
service_account: ${service_account_job}
source:
  ...
```
`name` usa el mismo valor que ya referenciaba `cs-ibk-consentimiento.yaml` en `target.workflow` — no requirió cambios en el Scheduler.

Los otros 2 hallazgos MEDIA (`SELECT *` en el patrón de dedup, `DROP TABLE` en tablas tmp efímeras) siguen como excepción documentada — no rompen ningún deploy, son contradicciones puramente de estilo/documentación entre estándares del framework.

### Resultado final: ⚠️ PASS con advertencias — 0 CRÍTICA, 0 ALTA, 1 MEDIA corregida (bug real de deploy) + 2 MEDIA como excepción documentada, 2 BAJA (cosméticas)

---
> 📁 Generado por `fac-data-stage-compliance` · 2026-08-19
> Próximo paso: `fac-data-stage-testing`
