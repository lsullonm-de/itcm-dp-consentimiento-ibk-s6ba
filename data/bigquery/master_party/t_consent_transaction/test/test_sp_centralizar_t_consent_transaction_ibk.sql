-- Test: sp_centralizar_t_consent_transaction_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado
-- RN-IBK-019 (2026-08-26): cruce con iden_party por party_id ÚNICAMENTE (sin igualar
-- itc_company_id) — cada coincidencia de iden_party genera su propia fila, "no excluir nada".

DECLARE v_fecha_prueba DATE DEFAULT DATE '2026-08-13';   -- folder_date a centralizar
DECLARE v_otra_fecha   DATE DEFAULT DATE '2026-08-12';   -- otro archivo en raw, NO debe centralizarse
DECLARE v_row_count    INT64;
DECLARE v_read         INT64;   -- MONITORING: o_execution_data_read
DECLARE v_write        INT64;   -- MONITORING: o_execution_data_write

-- ============================================================
-- 1. Setup: t_consent_transaction_raw de prueba
-- ============================================================
CREATE OR REPLACE TABLE `${project_t_consent_transaction}.test_master_party.t_consent_transaction_raw` AS
SELECT * FROM UNNEST([
  -- PARTY-001: 1 solo match en iden_party (empresa '000') -> 1 fila en el output
  STRUCT(
    v_fecha_prueba AS folder_date, v_fecha_prueba AS process_date, '000' AS itc_company_id,
    'INTERBANK' AS itc_company_name, 'BU01' AS business_unit_id, 'Banca Personal' AS business_unit,
    'CT-001' AS consent_transaction_id, 'PARTY-001' AS party_id, 'CP_2' AS consent_id,
    'DOC-001' AS documento_legal_id, 'WEB' AS approval_channel_id, 'EMP-001' AS employee_id,
    'PLC-001' AS place_id, 'otorgado' AS consent_type, DATE '2026-08-13' AS consent_date,
    'gs://bucket/doc1.pdf' AS signed_document, 'LPDP_IBK_archivo1.txt.gz' AS record_source
  ),
  -- PARTY-003: coincide con DOS registros en iden_party (empresa '000' Y '1000', misma persona
  -- con doble registro) -> deben salir 2 filas, una por cada empresa/id [RN-IBK-019, "no excluir
  -- nada" — el caso real que motivó este cambio de diseño, 2026-08-26]
  STRUCT(
    v_fecha_prueba, v_fecha_prueba, '000',
    'INTERBANK', 'BU01', 'Banca Personal',
    'CT-003', 'PARTY-003', 'CP_2',
    'DOC-003', 'WEB', 'EMP-003',
    'PLC-003', 'otorgado', DATE '2026-08-13',
    'gs://bucket/doc3.pdf', 'LPDP_IBK_archivo1.txt.gz'
  ),
  -- PARTY-004: SIN ningún match en iden_party -> excluido (INNER JOIN)
  STRUCT(
    v_fecha_prueba, v_fecha_prueba, '000',
    'INTERBANK', 'BU01', 'Banca Personal',
    'CT-004', 'PARTY-004', 'CP_2',
    'DOC-004', 'WEB', 'EMP-004',
    'PLC-004', 'otorgado', DATE '2026-08-13',
    'gs://bucket/doc4.pdf', 'LPDP_IBK_archivo1.txt.gz'
  ),
  -- PARTY-005: DOS eventos del mismo archivo para el mismo cliente (mismo match iden_party) ->
  -- QUALIFY debe quedarse con el de consent_date MÁS RECIENTE (RN-IBK-011, se mantiene)
  STRUCT(
    v_fecha_prueba, v_fecha_prueba, '000',
    'INTERBANK', 'BU01', 'Banca Personal',
    'CT-005A', 'PARTY-005', 'CP_2',
    'DOC-005A', 'WEB', 'EMP-005',
    'PLC-005', 'rechazado', DATE '2026-08-10',
    'gs://bucket/doc5a.pdf', 'LPDP_IBK_archivo1.txt.gz'
  ),
  STRUCT(
    v_fecha_prueba, v_fecha_prueba, '000',
    'INTERBANK', 'BU01', 'Banca Personal',
    'CT-005B', 'PARTY-005', 'CP_2',
    'DOC-005B', 'WEB', 'EMP-005',
    'PLC-005', 'otorgado', DATE '2026-08-13',
    'gs://bucket/doc5b.pdf', 'LPDP_IBK_archivo1.txt.gz'
  ),
  -- PARTY-006: pertenece a OTRO folder_date (v_otra_fecha) -> NO debe centralizarse en esta corrida
  STRUCT(
    v_otra_fecha, v_otra_fecha, '000',
    'INTERBANK', 'BU01', 'Banca Personal',
    'CT-006', 'PARTY-006', 'CP_2',
    'DOC-006', 'WEB', 'EMP-006',
    'PLC-006', 'otorgado', DATE '2026-08-12',
    'gs://bucket/doc6.pdf', 'LPDP_IBK_archivo0.txt.gz'
  )
]);

-- ============================================================
-- 2. Setup: iden_itc_party_prd de prueba
-- ============================================================
CREATE OR REPLACE TABLE `${project_iden_party}.${dataset_iden_party}.test_iden_itc_party_prd` AS
SELECT * FROM UNNEST([
  STRUCT('PARTY-001' AS party_id, '000' AS itc_company_id, 'ID-001-000' AS id, DATE '2026-08-01' AS process_date),
  STRUCT('PARTY-003', '000', 'ID-003-000', DATE '2026-08-01'),
  STRUCT('PARTY-003', '1000', 'ID-003-1000', DATE '2026-08-01'),
  STRUCT('PARTY-005', '000', 'ID-005-000', DATE '2026-08-01'),
  STRUCT('PARTY-006', '000', 'ID-006-000', DATE '2026-08-01')
]);

-- Fila preexistente que el DELETE por empresa debe reemplazar
CREATE OR REPLACE TABLE `${project_t_consent_transaction}.test_master_party.t_consent_transaction` AS
SELECT
  DATE '2026-01-01' AS process_date, '000' AS itc_company_id, 'INTERBANK' AS itc_company_name,
  'BU01' AS business_unit_id, 'Banca Personal' AS business_unit,
  'CT-OLD' AS conset_transaction_id, 'CUST-OLD' AS customer_id, 'PARTY-OLD' AS id,
  'CP_2' AS conset_id, 'DOC-OLD' AS documento_legal_id, 'WEB' AS approval_channel_id,
  'EMP-OLD' AS employee_id, 'PLC-OLD' AS place_id, 'otorgado' AS consent_type,
  DATE '2026-01-01' AS consent_date, 'gs://bucket/old.pdf' AS signed_document,
  'LPDP_IBK_viejo.txt.gz' AS record_source, CURRENT_DATETIME('America/Lima') AS load_date,
  'setup' AS creation_user;

-- ============================================================
-- 3. Invocar el SP
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_centralizar_t_consent_transaction_ibk`(
  v_fecha_prueba,
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction_raw',
  '${project_iden_party}', '${dataset_iden_party}', 'test_iden_itc_party_prd',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction',
  'test_stage_tmp',
  v_read, v_write
);

-- ============================================================
-- 4. Assertions
-- ============================================================

-- T0: métricas de monitoring — 3 filas esperadas (PARTY-001, PARTY-003x000, PARTY-003x1000);
-- PARTY-004 excluido (sin match), PARTY-005 colapsado a 1 (QUALIFY), PARTY-006 es otro folder_date
ASSERT v_write = 3
  AS 'T0: o_execution_data_write debía ser 3, se obtuvo ' || CAST(v_write AS STRING);
ASSERT v_read = v_write
  AS 'T0: o_execution_data_read debía igualar o_execution_data_write, se obtuvo read=' || CAST(v_read AS STRING) || ' write=' || CAST(v_write AS STRING);

-- T1: PARTY-001 resuelve a un único id, con el itc_company_id de iden_party (no del archivo)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-001' AND id = 'ID-001-000' AND itc_company_id = '000'
);
ASSERT v_row_count = 1
  AS 'T1: PARTY-001 debía resolver a ID-001-000/000, se obtuvo ' || CAST(v_row_count AS STRING);

-- T2: PARTY-003 genera 2 filas — una por cada empresa donde tiene registro en iden_party
-- (RN-IBK-019, "no excluir nada" — el caso real que motivó este cambio)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-003'
);
ASSERT v_row_count = 2
  AS 'T2: PARTY-003 debía generar 2 filas (una por empresa en iden_party), se obtuvo ' || CAST(v_row_count AS STRING);

SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-003' AND id IN ('ID-003-000', 'ID-003-1000')
    AND itc_company_id IN ('000','1000')
);
ASSERT v_row_count = 2
  AS 'T2b: las 2 filas de PARTY-003 debían tener el id/itc_company_id de CADA registro de iden_party, se obtuvo ' || CAST(v_row_count AS STRING);

-- T3: PARTY-004 (sin match en iden_party) queda excluido
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-004'
);
ASSERT v_row_count = 0
  AS 'T3: PARTY-004 no tiene match en iden_party y no debía centralizarse, se obtuvo ' || CAST(v_row_count AS STRING);

-- T4: PARTY-006 pertenece a otro folder_date (v_otra_fecha) — no debía centralizarse en esta corrida
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-006'
);
ASSERT v_row_count = 0
  AS 'T4: PARTY-006 es de otro folder_date y no debía centralizarse, se obtuvo ' || CAST(v_row_count AS STRING);

-- T5: PARTY-005 tenía 2 eventos (rechazado 08-10, otorgado 08-13) — QUALIFY se queda con el más
-- reciente por consent_date (RN-IBK-011, se mantiene)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-005'
);
ASSERT v_row_count = 1
  AS 'T5: PARTY-005 debía colapsar a 1 fila (último evento), se obtuvo ' || CAST(v_row_count AS STRING);

SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE customer_id = 'PARTY-005' AND consent_type = 'otorgado' AND consent_date = DATE '2026-08-13'
);
ASSERT v_row_count = 1
  AS 'T5b: PARTY-005 debía quedarse con el evento otorgado del 2026-08-13 (el más reciente), se obtuvo ' || CAST(v_row_count AS STRING);

-- T6: la fila preexistente (PARTY-OLD) debe haber sido eliminada por el DELETE por empresa
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`
  WHERE id = 'PARTY-OLD'
);
ASSERT v_row_count = 0
  AS 'T6: la fila preexistente PARTY-OLD (itc_company_id 000) debía eliminarse con el DELETE por empresa, se obtuvo ' || CAST(v_row_count AS STRING);

-- T7: la tabla de stage se limpia al finalizar. Sufijo _20260813 = FORMAT_DATE('%Y%m%d', v_fecha_prueba)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_iden_party}.test_stage_tmp.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'tmp_centralizar_t_consent_transaction_ibk_20260813'
);
ASSERT v_row_count = 0
  AS 'T7: la tabla de stage debía quedar eliminada al finalizar el SP, se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction_raw`;
DROP TABLE IF EXISTS `${project_iden_party}.${dataset_iden_party}.test_iden_itc_party_prd`;
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
