# Reporte /rules-check — 2026-08-19

> **Repo:** `itcm-dp-consentimiento-ibk-s6ba`
> **Ejecutado por:** lsullon (vía sesión de Claude Code)
> **Scope:** sin `--all`/`--staged` explícito. El repo no tiene `.git` inicializado, así que no
> existe `git diff HEAD` — se auditaron todos los archivos SQL/YAML del módulo
> `consentimiento-ibk` (equivalente a `--all` acotado a `data/bigquery/master_party/`,
> `pipeline/workflow/master_party/` y `pipeline/scheduler/master_party/`).
> **Archivos analizados:** 12 SQL · 2 YAML

---

## 📄 data/bigquery/master_party/t_consent_transaction/ddl/t_consent_transaction.sql

✅ REGLA 1 — Sin hardcoding de proyectos: OK
✅ REGLA 2 — Variables en trío: OK (`${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}`)
✅ REGLA 2B — `CREATE TABLE IF NOT EXISTS`: OK
✅ REGLA 2C — Sin `DROP COLUMN`, sin columnas nuevas embebidas: OK
❌ REGLA 4 — Campos DQ obligatorios (`etapas.data_quality: true`): **VIOLACIÓN**
   Faltan `dq_flag_ind INT64`, `dq_control_msg STRING`, `dq_config_id STRING`
✅ REGLA 5 — Naming (`t_` = transacción): OK

## 📄 data/bigquery/master_party/ba_customer_consent_group/ddl/ba_customer_consent_group.sql

✅ REGLA 1, 2, 2B, 2C: OK
❌ REGLA 4 — Campos DQ obligatorios: **VIOLACIÓN** (mismos 3 campos faltantes)
✅ REGLA 5 — Naming (`ba_` = business): OK

## 📄 data/bigquery/master_party/t_consent_transaction/ddl/ext_t_consent_transaction_external.sql

✅ REGLA 1 — Sin hardcoding de proyecto (usa `${project_consentimiento_ibk_archivo}.${dataset_consentimiento_ibk_archivo}`): OK
⚪ REGLA 2B/4 — No aplica: es un archivo de **referencia**, no se despliega vía `bigquery_ddl` (nombre de tabla dinámico, documentado en su propia cabecera)

## 📄 data/bigquery/master_party/t_consent_transaction/sp/sp_t_consent_transaction_ibk.sql

✅ REGLA 1 — Sin hardcoding: OK
⚠️ REGLA 2/3 — Tabla temporal con nombre hardcodeado: **ADVERTENCIA**
   Línea 138: `p_project_output || '.' || p_dataset_stage || '.tmp_t_consent_transaction_ibk'`
   El sufijo `tmp_t_consent_transaction_ibk` es literal, no `${table_tmp_...}`. Regla 2 pide project+dataset+**table** en variable para toda tabla BQ, incluidas las `tmp_*`
✅ REGLA 3 — Vive en `${dataset_stage}` (vía `p_dataset_stage`): OK en cuanto a dataset
✅ REGLA 5 — Naming (`sp_{tabla}_{emp}`): OK

## 📄 data/bigquery/master_party/t_consent_transaction/sp/sp_integridad_t_consent_transaction.sql

✅ REGLA 1, 2B (no aplica, sin tabla final), 5: OK
📝 Nota fuera de las 10 reglas: el comentario de cabecera (línea 11) dice
   `registro_resultados = false ... el workflow NO envía este resultado a la metadata API`,
   pero desde la etapa MONITORING `registro_resultados: true` y el workflow sí llama a
   `RegisterIntegrityResults`. Comentario desactualizado — no se corrigió (este comando es de
   solo lectura), queda para compliance/limpieza.

## 📄 data/bigquery/master_party/t_consent_transaction/sp/sp_dq_t_consent_transaction.sql

✅ REGLA 1, 5: OK
✅ REGLA 9 — No aplica (no contiene `sql_rule`, solo las ejecuta dinámicamente): OK

## 📄 data/bigquery/master_party/ba_customer_consent_group/sp/sp_ba_customer_consent_group_ibk.sql

✅ REGLA 1: OK
⚠️ REGLA 2/3 — Tablas temporales con nombre hardcodeado: **ADVERTENCIA**
   Línea 44: `.tmp_t_consent_transaction_ibk` (scope heredado del SP anterior)
   Línea 47: `.tmp_ba_customer_consent_group_ibk`
   Mismo patrón que el hallazgo anterior — ninguna usa `${table_tmp_...}`
✅ REGLA 5: OK

## 📄 data/bigquery/master_party/ba_customer_consent_group/sp/sp_dq_ba_customer_consent_group.sql

✅ REGLA 1, 5, 9 (no aplica): OK

## 📄 data/bigquery/master_party/{t_consent_transaction,ba_customer_consent_group}/dml/dml_dq_config_*.sql

✅ REGLA 1 — Variables `${project_*}`/`${dataset_*}` en `target_table` y dentro de `sql_rule`: OK
✅ REGLA 9 — Los 5 `sql_rule` retornan filas inválidas (`SELECT *` o `GROUP BY ... HAVING cnt > 1`), ninguno usa `SELECT COUNT(*)` como retorno final: OK

## 📄 data/bigquery/master_party/{t_consent_transaction,ba_customer_consent_group}/test/test_sp_*.sql

✅ REGLA 1 — Sin hardcoding de proyecto: OK (usan `${project_*}` + datasets de prueba literales tipo `test_master_party`, aceptable en tests)
✅ REGLA 3 — `CREATE OR REPLACE TABLE` de setup en datasets `test_*`: aceptable, son fixtures de prueba, no tablas de producción

## 📄 pipeline/workflow/master_party/t_consent_transaction/wf-ibk-consentimiento.yaml

✅ REGLA 6-A — Sin cabecera (solo bloque `source:`, como exige el estándar): OK
✅ REGLA 6-B — Sin SA construida inline: OK
✅ REGLA 6-C — Sin hardcoding en `set_vars` ni en los `steps` (todo vía `${project_operation}`, `${dataset_sp}`, etc. o variables locales derivadas de ellos): OK
✅ REGLA 7 — No aplica (el header con `service_account` no existe en este archivo, se define en Dataops): OK

## 📄 pipeline/scheduler/master_party/t_consent_transaction/cs-ibk-consentimiento.yaml

✅ REGLA 6-A/6-B — `project: ${project_operation}`, `serviceAccount: ${service_account_job}`: OK
✅ REGLA 7 — SA tipo `-job` (`${service_account_job}`) para `cloud_scheduler`: OK

---

## Resumen /rules-check

- Archivos analizados: 14 (12 SQL, 2 YAML)
- Violaciones críticas (🔴): 2
- Advertencias (🟡): 2
- Archivos limpios: 10

| Regla | Violaciones |
|---|---|
| REGLA 4 — Campos DQ obligatorios en DDL output | 2 (ambas tablas destino) |
| REGLA 2/3 — Nombre de tabla temporal hardcodeado | 2 (3 ocurrencias en 2 archivos) |

### Acciones requeridas antes de COMPLIANCE

1. **`t_consent_transaction.sql`** y **`ba_customer_consent_group.sql`**: agregar `dq_flag_ind INT64`, `dq_control_msg STRING`, `dq_config_id STRING` — obligatorios porque `etapas.data_quality: true`. Esto es un `ALTER TABLE ADD COLUMN IF NOT EXISTS` en `alter/`, **no** un cambio directo al `CREATE TABLE IF NOT EXISTS` (ya está desplegado conceptualmente como "existente" desde DATAOPS — ver Regla 2C).
2. **`sp_t_consent_transaction_ibk.sql`** línea 138 y **`sp_ba_customer_consent_group_ibk.sql`** líneas 44/47: evaluar si conviene declarar `table_tmp_t_consent_transaction_ibk` / `table_tmp_ba_customer_consent_group_ibk` como variables Dataops, o documentar en `restricciones[]` por qué se aceptan como excepción (son tablas internas efímeras, compartidas solo entre estos 2 SPs del mismo módulo — no es el mismo escenario multi-ambiente que motiva la regla, pero la regla no distingue este caso).

### Nota adicional (fuera de las 10 reglas)
`sp_integridad_t_consent_transaction.sql` tiene un comentario de cabecera desactualizado sobre `registro_resultados` — cosmético, no bloqueante.

### Veredicto
❌ **NO apto tal cual para `/data:implement-stage COMPLIANCE`** — 2 violaciones críticas de REGLA 4 (campos DQ faltantes). Las 2 advertencias de REGLA 2/3 son discutibles y se pueden aceptar con justificación documentada.

---

## Actualización — 2026-08-19 (mismo día, tras aplicar correcciones)

- ✅ **REGLA 4 — FIXED.** Agregados `data/bigquery/master_party/t_consent_transaction/alter/alter_t_consent_transaction_20260819_001.sql` y `.../ba_customer_consent_group/alter/alter_ba_customer_consent_group_20260819_001.sql` con `ADD COLUMN IF NOT EXISTS dq_flag_ind/dq_control_msg/dq_config_id`. Registrados en `componentes[]` del spec y en `bigquery_ddl` de `deploy_dev.json`/`deploy_prd.json`, después del `CREATE TABLE` de cada tabla. **Nota:** las columnas quedan `NULL` — el modelo DQ de este módulo valida a nivel de tabla (`dq_control`), no a nivel de fila.
- ✅ **REGLA 2/3 — SKIPPED (excepción documentada).** No se crearon variables `${table_tmp_...}` nuevas. Se documentó como excepción aceptada en `restricciones[]` del spec y con comentarios inline en ambos SPs: son tablas efímeras internas compartidas solo entre `sp_t_consent_transaction_ibk.sql` y `sp_ba_customer_consent_group_ibk.sql`, sin variación entre ambientes.
- 📝 Bonus: corregido el comentario desactualizado en `sp_integridad_t_consent_transaction.sql` sobre `registro_resultados` (decía `false`, ya es `true` desde MONITORING).

### Veredicto actualizado
✅ Apto para `/data:implement-stage COMPLIANCE` — sin violaciones críticas pendientes.

---
> 📁 Generado por `fac-data-rules-check` (sin argumentos, repo sin git → equivalente a `--all` acotado al módulo) · `itcm-dp-consentimiento-ibk-s6ba` · 2026-08-19
> Próximo paso: decidir si se agregan los campos DQ (`alter/`) antes de `fac-data-stage-compliance`, o se documenta por qué no aplican a este módulo.
