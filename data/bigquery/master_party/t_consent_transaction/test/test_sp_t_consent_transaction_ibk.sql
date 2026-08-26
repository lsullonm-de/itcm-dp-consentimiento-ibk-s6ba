-- Test: sp_t_consent_transaction_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado
--
-- ⚠️ LIMITACIÓN CONOCIDA: este SP crea una EXTERNAL TABLE sobre un archivo real en GCS
-- (gs://${gcs_bucket_consentimiento_ibk_archivo}/...). No es simulable con datos en memoria como
-- el resto de SPs del framework. Para correr este test end-to-end en dev se necesita:
--   1. Un archivo .txt.gz de prueba subido a la ruta
--      gs://${gcs_bucket_consentimiento_ibk_archivo}/data/m_consent/current/{fecha_prueba}/{cualquier-uuid}/
--      T_IN_LPDP_CONSENTIMIENTO_{fecha_prueba}.txt.gz
--      (dev usa gs://dev-demo-raw-sales-xrt9/... — bucket propio del dev, no el real de IBK,
--      porque service_account_job no tiene storage.objectViewer sobre p-ibkbi-rdp-stg-dlk-us-suoh)
--   2. Al menos una fila con party_id que exista en iden_itc_party_prd para itc_company_id
--      IN ('000','1000'), y al menos una fila con party_id SIN match (para el caso T3)
--
-- Mientras ese fixture no exista, este archivo documenta las aserciones esperadas — no se
-- puede ejecutar tal cual. Ver TODO.md.

-- v_fecha_prueba = la CARPETA directamente [RN-IBK-014, 2026-08-26] — el SP ya no le resta 1
-- día (ese offset ahora solo lo aplica el Workflow, y solo en modo normal).
DECLARE v_fecha_prueba   DATE DEFAULT DATE '2026-04-01';
DECLARE v_row_count      INT64;
DECLARE v_read           INT64;   -- MONITORING: o_execution_data_read
DECLARE v_write          INT64;   -- MONITORING: o_execution_data_write

-- ============================================================
-- T1: ejecución normal — el SP no debe fallar y debe insertar filas
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  v_fecha_prueba, v_fecha_prueba,
  '${project_consentimiento_ibk_archivo}', 'test_raw_ibk_dlk',
  '${project_iden_party}', '${dataset_iden_party}', '${table_iden_party}',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction',
  'test_stage_tmp',
  false,   -- p_carga_historica [RN-IBK-015]: prueba de comportamiento normal, no bootstrap
  v_read, v_write
);

-- T1b: métricas de monitoring coherentes (MONITORING)
ASSERT v_write > 0
  AS 'T1b: o_execution_data_write debía ser > 0, se obtuvo ' || CAST(v_write AS STRING);
ASSERT v_read = v_write
  AS 'T1b: o_execution_data_read debía igualar o_execution_data_write (mismo stage), se obtuvo read=' || CAST(v_read AS STRING) || ' write=' || CAST(v_write AS STRING);

SET v_row_count = (
  SELECT COUNT(*)
  FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE consent_date IS NOT NULL
);

ASSERT v_row_count > 0
  AS 'T1: se esperaban filas insertadas en t_consent_transaction, se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- T2: id resuelto para todos los registros con match en iden_itc_party_prd
-- ============================================================
SET v_row_count = (
  SELECT COUNT(*)
  FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE id IS NULL
);

ASSERT v_row_count = 0
  AS 'T2: se esperaban 0 filas con id NULL en el fixture de test (todas con match en iden_party), se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- T3: reproceso — volver a llamar el SP para la misma fecha no debe duplicar filas
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  v_fecha_prueba, v_fecha_prueba,
  '${project_consentimiento_ibk_archivo}', 'test_raw_ibk_dlk',
  '${project_iden_party}', '${dataset_iden_party}', '${table_iden_party}',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction',
  'test_stage_tmp',
  false,   -- p_carga_historica [RN-IBK-015]
  v_read, v_write
);

SET v_row_count = (
  SELECT COUNT(*)
  FROM (
    SELECT itc_company_id, consent_date, conset_transaction_id, COUNT(*) AS cnt
    FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
    GROUP BY 1, 2, 3
    HAVING cnt > 1
  )
);

ASSERT v_row_count = 0
  AS 'T3: reproceso de la misma fecha no debe generar duplicados (DQ-IBK-T_CONSENT_TRANSACTION-003), se obtuvieron ' || CAST(v_row_count AS STRING) || ' grupos duplicados';

-- ============================================================
-- T4: archivo sin filas → el SP debe fallar (RAISE), no ejecutar DELETE sin INSERT
-- ============================================================
-- Requiere una fecha de prueba cuya carpeta GCS exista vacía o no tenga archivo.
-- Verificar manualmente: CALL ... con una fecha sin fixture debe lanzar el mensaje
-- "0 filas en ... — no se ejecuta DELETE sin INSERT de reemplazo".

-- ============================================================
-- T5 (2026-08-26): solo el ÚLTIMO evento por cliente (id) — cambio de diseño, t_consent_transaction
-- ya no guarda historial completo. No debe haber más de 1 fila por id, sin importar cuántos
-- eventos distintos traiga el archivo de prueba para esa persona.
-- ============================================================
SET v_row_count = (
  SELECT COUNT(*)
  FROM (
    SELECT id, COUNT(*) AS cnt
    FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
    GROUP BY id
    HAVING cnt > 1
  )
);

ASSERT v_row_count = 0
  AS 'T5: no debía haber más de 1 fila por id (solo el último evento por cliente), se obtuvieron ' || CAST(v_row_count AS STRING) || ' ids con más de una fila';

-- ============================================================
-- T6 (2026-08-26): p_carga_historica = TRUE debe traer TODO el historial del archivo, sin
-- filtrar por consent_date. Requiere limpiar t_consent_transaction antes de esta llamada
-- (CALL con p_carga_historica = true) y comparar COUNT(DISTINCT consent_date) > 1 — con
-- p_carga_historica = false (T1) el archivo de prueba solo debería aportar 1 consent_date
-- (el MAX real), con true debería aportar todas las fechas distintas que traiga el archivo.
-- Verificar manualmente, no automatizado aquí (requiere control fino sobre el estado previo
-- de la tabla, que las demás pruebas de este archivo no necesitan).
-- ============================================================

-- ============================================================
-- T7 (2026-08-26): la tabla de stage propia (tmp_t_consent_transaction_ibk_{fecha}) debe quedar
-- eliminada al finalizar el SP — CAMBIO DE DISEÑO: antes la eliminaba sp_ba_customer_consent_group_ibk
-- (su única consumidora); esa SP dejó de tocarla (pasó a ser un TRUNCATE + INSERT completo, sin
-- scope por fecha), así que ahora este SP limpia lo suyo. Sufijo _20260401 = FORMAT_DATE('%Y%m%d',
-- v_fecha_prueba) [RN-IBK-013]. Vive bajo ${project_iden_party}, no bajo project_t_consent_transaction.
-- ============================================================
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_iden_party}.test_stage_tmp.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'tmp_t_consent_transaction_ibk_20260401'
);

ASSERT v_row_count = 0
  AS 'T7: la tabla de stage tmp_t_consent_transaction_ibk_20260401 debía quedar eliminada al finalizar el SP, se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
