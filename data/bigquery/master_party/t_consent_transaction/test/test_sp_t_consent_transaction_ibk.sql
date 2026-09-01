-- Test: sp_t_consent_transaction_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado
--
-- ROLLBACK (2026-08-27, RN-IBK-020): revierte RN-IBK-019 — este SP vuelve a cruzar contra
-- iden_party y a escribir directo en t_consent_transaction (ya no existen t_consent_transaction_raw
-- ni sp_centralizar_t_consent_transaction_ibk.sql). t_consent_transaction guarda el HISTORIAL
-- COMPLETO por cliente (ya NO "solo el último evento", RN-IBK-011 revertida) — el cruce por
-- party_id ÚNICAMENTE (sin igualar itc_company_id, RN-IBK-019) SÍ se mantiene.
--
-- FIX (2026-08-27, RN-IBK-021): el cruce por party_id ahora filtra DESPUÉS del match a
-- itc_company_id IN ('000','1000') sobre el lado de iden_party — descarta registros de otras
-- empresas del grupo.
--
-- CORRECCIÓN (2026-08-28, RN-IBK-025, pedido por el usuario) — SUPERA RN-IBK-012/RN-IBK-015/parte
-- de RN-IBK-021: el archivo de origen es un extracto COMPLETO/acumulado, no incremental. Se
-- elimina el parámetro p_carga_historica (ya no existe en la firma) y el filtro por
-- MAX(consent_date) — cada llamada carga el archivo COMPLETO, sin filtro de consent_date. El
-- DELETE de la carga final vuelve a ser por itc_company_id (espejo completo de Interbank), ya no
-- por record_source.
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
-- HISTORIAL COMPLETO por cliente, ya NO solo el último evento. Si un mismo id aparece más de
-- una vez dentro del MISMO archivo (ej. otorgado el día X, revocado el día Y, ambos en el mismo
-- extracto — esperado bajo RN-IBK-025, el archivo es un acumulado completo), todas esas filas
-- deben convivir en la tabla, una por cada consent_date real. No automatizado aquí (requiere un
-- fixture con un id repetido en más de un consent_date) — verificar manualmente: tras T1,
-- confirmar COUNT(*) FROM t_consent_transaction WHERE id = '<ese id>' >= 2 si el fixture lo trae.
-- ============================================================

-- ============================================================
-- T6 (2026-08-28, RN-IBK-025 — SUPERA el T6 anterior sobre p_carga_historica, parámetro
-- eliminado): el SP ya NO filtra por MAX(consent_date) — SIEMPRE carga el archivo COMPLETO.
-- ============================================================
SET v_row_count = (
  SELECT COUNT(DISTINCT consent_date)
  FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
);

ASSERT v_row_count >= 1
  AS 'T6: se esperaba al menos 1 consent_date distinto tras la carga completa del archivo, se obtuvo ' || CAST(v_row_count AS STRING);
-- Si el fixture de prueba trae más de un consent_date real por id, v_row_count debe ser > 1 —
-- confirma que ya no se descarta nada por no ser el MAX(consent_date) del archivo.

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
-- T8 (2026-08-28, RN-IBK-025 — SUPERA RN-IBK-021, el escenario que motivó ese fix ya no aplica):
-- el DELETE de la carga final es por itc_company_id, no por record_source — cada corrida es un
-- espejo completo de Interbank. Procesar un SEGUNDO folder_date NO acumula sobre el primero: el
-- contenido del primer archivo se pierde por completo si el segundo no lo trae también (esperado
-- bajo RN-IBK-025 — se asume que cada archivo procesado es el extracto completo vigente). No
-- automatizado aquí — verificar manualmente:
--   1. Procesar folder_date A, anotar COUNT(*) FROM t_consent_transaction WHERE itc_company_id
--      IN ('000','1000').
--   2. Procesar folder_date B (archivo de prueba distinto, con menos filas).
--   3. Confirmar que el COUNT(*) tras B refleja SOLO el contenido de B (no A + B) — el DELETE
--      por itc_company_id borró todo antes del segundo INSERT.
-- ============================================================

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
