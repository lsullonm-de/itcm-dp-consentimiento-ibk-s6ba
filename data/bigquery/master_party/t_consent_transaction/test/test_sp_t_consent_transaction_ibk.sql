-- Test: sp_t_consent_transaction_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado
--
-- CAMBIO DE DISEÑO (2026-08-26, RN-IBK-019): este SP ya NO cruza contra iden_party ni escribe en
-- t_consent_transaction — solo crea la tabla externa del archivo y lo vuelca TAL CUAL a
-- t_consent_transaction_raw. El cruce con iden_party y la centralización viven ahora en
-- sp_centralizar_t_consent_transaction_ibk.sql (ver su propio test).
--
-- ⚠️ LIMITACIÓN CONOCIDA: este SP crea una EXTERNAL TABLE sobre un archivo real en GCS
-- (gs://${gcs_bucket_consentimiento_ibk_archivo}/...). No es simulable con datos en memoria como
-- el resto de SPs del framework. Para correr este test end-to-end en dev se necesita un archivo
-- .txt.gz de prueba subido a la ruta
--   gs://${gcs_bucket_consentimiento_ibk_archivo}/data/m_consent/current/{fecha_prueba}/{cualquier-uuid}/
--   T_IN_LPDP_CONSENTIMIENTO_{fecha_prueba}.txt.gz
-- (dev usa gs://dev-demo-raw-sales-xrt9/... — bucket propio del dev, no el real de IBK, porque
-- service_account_job no tiene storage.objectViewer sobre p-ibkbi-rdp-stg-dlk-us-suoh).
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
-- T1: ejecución normal — el SP no debe fallar y debe insertar filas en raw
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  v_fecha_prueba, v_fecha_prueba,
  '${project_consentimiento_ibk_archivo}', 'test_raw_ibk_dlk',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction_raw',
  v_read, v_write
);

-- T1b: métricas de monitoring coherentes (MONITORING) — paso directo, read = write
ASSERT v_write > 0
  AS 'T1b: o_execution_data_write debía ser > 0, se obtuvo ' || CAST(v_write AS STRING);
ASSERT v_read = v_write
  AS 'T1b: o_execution_data_read debía igualar o_execution_data_write, se obtuvo read=' || CAST(v_read AS STRING) || ' write=' || CAST(v_write AS STRING);

SET v_row_count = (
  SELECT COUNT(*)
  FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction_raw`
  WHERE folder_date = v_fecha_prueba
);

ASSERT v_row_count > 0
  AS 'T1: se esperaban filas insertadas en t_consent_transaction_raw, se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- T2: cada evento del archivo se guarda TAL CUAL — sin colapsar por cliente (RN-IBK-019).
-- Si el fixture de prueba trae más de un evento para el mismo party_id, deben verse ambos en raw
-- (a diferencia del comportamiento anterior de este SP, que sí colapsaba). No automatizado aquí
-- porque depende de que el archivo de prueba real tenga ese caso — verificar manualmente.
-- ============================================================

-- ============================================================
-- T3: reproceso — volver a llamar el SP para la MISMA fecha reemplaza su lote en raw, no duplica
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  v_fecha_prueba, v_fecha_prueba,
  '${project_consentimiento_ibk_archivo}', 'test_raw_ibk_dlk',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction_raw',
  v_read, v_write
);

SET v_row_count = (
  SELECT COUNT(*)
  FROM (
    SELECT party_id, consent_date_time, COUNT(*) AS cnt
    FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction_raw`
    WHERE folder_date = v_fecha_prueba
    GROUP BY 1, 2
    HAVING cnt > 1
  )
);

ASSERT v_row_count = 0
  AS 'T3: reproceso de la misma fecha no debe generar duplicados en raw, se obtuvieron ' || CAST(v_row_count AS STRING) || ' grupos duplicados';

-- ============================================================
-- T4: archivo sin filas → el SP debe fallar (RAISE), no ejecutar DELETE sin INSERT
-- ============================================================
-- Requiere una fecha de prueba cuya carpeta GCS exista vacía o no tenga archivo.
-- Verificar manualmente: CALL ... con una fecha sin fixture debe lanzar el mensaje
-- "0 filas en ... — no se ejecuta DELETE sin INSERT de reemplazo".

-- ============================================================
-- T5: fechas DISTINTAS no se pisan entre sí en raw — cada folder_date acumula su propio lote.
-- No automatizado aquí (requiere un segundo archivo de prueba con otra fecha) — verificar
-- manualmente subiendo un segundo archivo y confirmando que ambos folder_date coexisten en raw.
-- ============================================================

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction_raw`;
