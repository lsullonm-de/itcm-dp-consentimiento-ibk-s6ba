-- Test: sp_ba_customer_consent_group_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado

DECLARE v_row_count INT64;
DECLARE v_read       INT64;   -- MONITORING: o_execution_data_read
DECLARE v_write      INT64;   -- MONITORING: o_execution_data_write

-- ============================================================
-- 1. Setup: t_consent_transaction de prueba (fuente única, RN-IBK-006)
-- ============================================================
CREATE OR REPLACE TABLE `${project_t_consent_transaction}.test_master_party.t_consent_transaction` AS
SELECT * FROM UNNEST([
  -- caso válido: CP_2 + otorgado + empresa 000 -> debe pasar el filtro
  STRUCT(
    DATE '2026-04-01' AS process_date, '000' AS itc_company_id, 'INTERBANK' AS itc_company_name,
    'BU01' AS business_unit_id, 'Banca Personal' AS business_unit,
    'CT-001' AS conset_transaction_id, 'CUST-001' AS customer_id, 'PARTY-001' AS id,
    'CP_2' AS conset_id, 'DOC-001' AS documento_legal_id, 'WEB' AS approval_channel_id,
    'EMP-001' AS employee_id, 'PLC-001' AS place_id, 'otorgado' AS consent_type,
    DATE '2026-03-30' AS consent_date, 'gs://bucket/doc1.pdf' AS signed_document
  ),
  -- caso válido: CP_2 + otorgado + empresa 1000 -> debe pasar el filtro (segundo código de Interbank)
  STRUCT(
    DATE '2026-04-01', '1000', 'INTERBANK',
    'BU02', 'Banca Empresa',
    'CT-002', 'CUST-002', 'PARTY-002',
    'CP_2', 'DOC-002', 'APP',
    'EMP-002', 'PLC-002', 'otorgado',
    DATE '2026-03-30', 'gs://bucket/doc2.pdf'
  ),
  -- caso excluido: consent_type = 'rechazado' -> NO debe pasar el filtro
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-003', 'CUST-003', 'PARTY-003',
    'CP_2', 'DOC-003', 'WEB',
    'EMP-003', 'PLC-003', 'rechazado',
    DATE '2026-03-30', 'gs://bucket/doc3.pdf'
  ),
  -- caso excluido: conset_id distinto de CP_2 -> NO debe pasar el filtro
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-004', 'CUST-004', 'PARTY-004',
    'CP_1', 'DOC-004', 'WEB',
    'EMP-004', 'PLC-004', 'otorgado',
    DATE '2026-03-30', 'gs://bucket/doc4.pdf'
  ),
  -- caso "último evento gana" (2026-08-25): 2 eventos otorgado del mismo cliente en fechas
  -- distintas -> debe quedar solo 1 fila, con la fecha más reciente (2026-04-15)
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-005A', 'CUST-005', 'PARTY-005',
    'CP_2', 'DOC-005A', 'WEB',
    'EMP-005', 'PLC-005', 'otorgado',
    DATE '2026-02-01', 'gs://bucket/doc5a.pdf'
  ),
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-005B', 'CUST-005', 'PARTY-005',
    'CP_2', 'DOC-005B', 'APP',
    'EMP-005', 'PLC-005', 'otorgado',
    DATE '2026-04-15', 'gs://bucket/doc5b.pdf'
  ),
  -- caso crítico "último evento gana" (2026-08-25): otorgado viejo + rechazado más reciente del
  -- mismo cliente -> el cliente NO debe aparecer en absoluto (su estado actual es rechazado),
  -- aunque tenga un otorgado histórico. Verifica que el ranking no filtre por consent_type ANTES
  -- de encontrar el evento más reciente.
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-006A', 'CUST-006', 'PARTY-006',
    'CP_2', 'DOC-006A', 'WEB',
    'EMP-006', 'PLC-006', 'otorgado',
    DATE '2026-01-10', 'gs://bucket/doc6a.pdf'
  ),
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-006B', 'CUST-006', 'PARTY-006',
    'CP_2', 'DOC-006B', 'APP',
    'EMP-006', 'PLC-006', 'rechazado',
    DATE '2026-04-20', 'gs://bucket/doc6b.pdf'
  )
]);

-- Scope generado por sp_t_consent_transaction_ibk: itc_company_id + consent_date tocados en la
-- corrida. Vive en ${project_iden_party}, no en ${project_t_consent_transaction} — ver esa SP.
CREATE OR REPLACE TABLE `${project_iden_party}.test_stage_tmp.tmp_t_consent_transaction_ibk` AS
SELECT DISTINCT itc_company_id, consent_date
FROM `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;

-- Fila preexistente en la partición que el DELETE+INSERT debe reemplazar
CREATE OR REPLACE TABLE `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group` AS
SELECT
  DATE '2026-04-01' AS process_date, '000' AS itc_company_id, 'INTERBANK' AS itc_company_name,
  'BU01' AS business_unit_id, 'Banca Personal' AS business_unit,
  'PARTY-OLD' AS id, 'DOC-OLD' AS documento_legal_id, 'WEB' AS approval_channel_id,
  CAST(NULL AS STRING) AS approval_channel_name, 'EMP-OLD' AS employee_id, 'PLC-OLD' AS place_id,
  DATE '2026-03-30' AS consent_date, 'gs://bucket/old.pdf' AS signed_document,
  'LPDP_IBK' AS record_source, CURRENT_DATETIME('America/Lima') AS load_date, 'setup' AS creation_user;

-- ============================================================
-- 2. Invocar el SP
-- ============================================================
CALL `${project_operation}.${dataset_sp}.sp_ba_customer_consent_group_ibk`(
  '${project_ba_customer_consent_group}', 'test_master_party', 'ba_customer_consent_group',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction',
  'test_stage_tmp',
  v_read, v_write
);

-- ============================================================
-- 3. Assertions
-- ============================================================

-- T0: métricas de monitoring — 3 filas válidas (PARTY-001, PARTY-002, PARTY-005) pasan el
-- filtro RN-IBK-006; PARTY-006 se excluye porque su evento más reciente es 'rechazado'
ASSERT v_write = 3
  AS 'T0: o_execution_data_write debía ser 3, se obtuvo ' || CAST(v_write AS STRING);
ASSERT v_read = v_write
  AS 'T0: o_execution_data_read debía igualar o_execution_data_write, se obtuvo read=' || CAST(v_read AS STRING) || ' write=' || CAST(v_write AS STRING);

-- T1: la fila preexistente (PARTY-OLD) debe haber sido reemplazada por el DELETE+INSERT
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-OLD'
);
ASSERT v_row_count = 0
  AS 'T1: la fila preexistente PARTY-OLD debía eliminarse en el DELETE por partición, se obtuvo ' || CAST(v_row_count AS STRING);

-- T2: solo los 3 casos válidos (CP_2 + último evento otorgado) deben quedar en el output
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
);
ASSERT v_row_count = 3
  AS 'T2: se esperaban 3 filas (PARTY-001, PARTY-002, PARTY-005), se obtuvo ' || CAST(v_row_count AS STRING);

-- T3: el caso rechazado y el caso CP_1 no deben aparecer
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id IN ('PARTY-003', 'PARTY-004')
);
ASSERT v_row_count = 0
  AS 'T3: PARTY-003 (rechazado) y PARTY-004 (conset_id != CP_2) no debían pasar el filtro RN-IBK-006, se obtuvo ' || CAST(v_row_count AS STRING);

-- T4: approval_channel_name siempre NULL (confirmado — sin origen en t_consent_transaction)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE approval_channel_name IS NOT NULL
);
ASSERT v_row_count = 0
  AS 'T4: approval_channel_name debe ser siempre NULL, se obtuvo ' || CAST(v_row_count AS STRING) || ' filas no nulas';

-- T5: las tablas temporales de scope se limpiaron al finalizar — ambas viven bajo
-- ${project_iden_party} (dataset de stage), no bajo project_ba_customer_consent_group
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_iden_party}.test_stage_tmp.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'tmp_t_consent_transaction_ibk'
) + (
  SELECT COUNT(*) FROM `${project_iden_party}.test_stage_tmp.INFORMATION_SCHEMA.TABLES`
  WHERE table_name = 'tmp_ba_customer_consent_group_ibk'
);
ASSERT v_row_count = 0
  AS 'T5: las tablas temporales de scope deben quedar eliminadas al finalizar el SP, se obtuvieron ' || CAST(v_row_count AS STRING);

-- T6 (2026-08-25): PARTY-005 tiene 2 eventos otorgado -> debe quedar 1 sola fila, con la fecha
-- del evento MÁS RECIENTE (2026-04-15), no la más vieja (2026-02-01)
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-005'
);
ASSERT v_row_count = 1
  AS 'T6: PARTY-005 debía quedar con exactamente 1 fila (el último evento), se obtuvieron ' || CAST(v_row_count AS STRING);

SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-005' AND consent_date = DATE '2026-04-15'
);
ASSERT v_row_count = 1
  AS 'T6b: PARTY-005 debía quedar con consent_date = 2026-04-15 (el más reciente), no 2026-02-01';

-- T7 (2026-08-25, caso crítico): PARTY-006 tiene un otorgado viejo y un rechazado más reciente
-- -> NO debe aparecer en absoluto (su estado actual es rechazado). Si el filtro consent_type
-- se aplicara antes del ranking (bug), PARTY-006 aparecería igual con el otorgado viejo.
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-006'
);
ASSERT v_row_count = 0
  AS 'T7: PARTY-006 no debía aparecer (su evento más reciente es rechazado), se obtuvieron ' || CAST(v_row_count AS STRING);

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
DROP TABLE IF EXISTS `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`;
