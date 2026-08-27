-- Test: sp_t_consent_transaction_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado
--
-- ROLLBACK (2026-08-27, RN-IBK-020): revierte RN-IBK-019 — este SP vuelve a cruzar contra
-- iden_party y a escribir directo en t_consent_transaction (ya no existen t_consent_transaction_raw
-- ni sp_centralizar_t_consent_transaction_ibk.sql). t_consent_transaction guarda el HISTORIAL
-- COMPLETO por cliente (ya NO "solo el último evento", RN-IBK-011 revertida) — el cruce por
-- party_id ÚNICAMENTE (sin igualar itc_company_id, RN-IBK-019) SÍ se mantiene.
--
-- FIXES (2026-08-27, RN-IBK-021): (a) el cruce por party_id ahora filtra DESPUÉS del match a
-- itc_company_id IN ('000','1000') sobre el lado de iden_party — descarta registros de otras
-- empresas del grupo; (b) el DELETE de la carga final es por (itc_company_id, record_source),
-- NO por consent_date — evita que dos archivos con el mismo MAX(consent_date) se borren entre sí
-- (ver T8).
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

-- v_fecha_prueba = la CARPETA directamente [RN-IBK-014] — el SP no le resta 1 día (ese offset
-- solo lo aplica el Workflow, y solo en modo normal).
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
-- T2: id resuelto para todos los registros con match en iden_itc_party_prd (cruce solo por
-- party_id, RN-IBK-019 — no se revierte con este rollback)
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
-- T5 (2026-08-27, RN-IBK-020 — ROLLBACK de RN-IBK-011): t_consent_transaction guarda el
-- HISTORIAL COMPLETO por cliente, ya NO solo el último evento. Si un mismo id aparece en
-- archivos de fechas DISTINTAS (ej. otorgado el día X, revocado el día Y), ambas filas deben
-- convivir en la tabla, una por cada consent_date real — el DELETE+INSERT es por
-- (itc_company_id, record_source) [RN-IBK-021], nunca colapsa por id. No automatizado aquí
-- (requiere procesar 2 fechas de prueba distintas con el mismo party_id) — verificar
-- manualmente: tras procesar 2 archivos de prueba con un id repetido en fechas distintas,
-- confirmar COUNT(*) FROM t_consent_transaction WHERE id = '<ese id>' >= 2.
-- ============================================================

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
-- eliminada al finalizar el SP. Sufijo _20260401 = FORMAT_DATE('%Y%m%d', v_fecha_prueba)
-- [RN-IBK-013]. Vive bajo ${project_stage} [RN-IBK-022] — NO ${project_iden_party} (bug real en
-- prod: ese proyecto no siempre hospeda el dataset de stage, ver cabecera del SP).
-- ============================================================
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_stage}.test_stage_tmp.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'tmp_t_consent_transaction_ibk_20260401'
);

ASSERT v_row_count = 0
  AS 'T7: la tabla de stage tmp_t_consent_transaction_ibk_20260401 debía quedar eliminada al finalizar el SP, se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- T8 (2026-08-27, RN-IBK-021 — corrige la colisión real confirmada entre
-- t_consent_transaction_20260813_external y ..._20260814_external, mismo MAX(consent_date)):
-- procesar dos folder_dates DISTINTOS cuyos archivos calculen el MISMO v_max_consent_date real
-- NO debe hacer que el segundo borre las filas insertadas por el primero. No automatizado aquí
-- (requiere 2 archivos de prueba con MAX(consent_date) idéntico pero contenido/record_source
-- distinto) — verificar manualmente:
--   1. Procesar folder_date A (su archivo trae MAX(consent_date) = X) — anotar
--      COUNT(*) FROM t_consent_transaction WHERE consent_date = X.
--   2. Procesar folder_date B, con un archivo de prueba armado para que su propio
--      MAX(consent_date) sea TAMBIÉN X.
--   3. Confirmar que las filas de A (identificables por su record_source, que embebe el
--      folder_date A) siguen presentes — el COUNT(*) WHERE consent_date = X debe ser
--      >= lo anotado en el paso 1, nunca caer a solo lo que aportó B.
-- ============================================================

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
