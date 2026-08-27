-- Test: sp_ba_customer_consent_group_ibk
-- Spec: spec-ibk-20260819-001 | Ejecutar en fac-data-stage-testing, dataset de test aislado

-- v_fecha_prueba ya no filtra nada dentro del SP (CAMBIO DE DISEÑO 2026-08-26: DELETE por
-- empresa + INSERT completo, sin scope por fecha) — se sigue pasando solo porque el parámetro
-- se mantuvo en la firma (decisión del usuario), para trazabilidad en monitoring.
DECLARE v_fecha_prueba DATE DEFAULT DATE '2026-04-01';
DECLARE v_row_count    INT64;
DECLARE v_read         INT64;   -- MONITORING: o_execution_data_read
DECLARE v_write        INT64;   -- MONITORING: o_execution_data_write

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
  -- caso válido con consent_date MUY antiguo (2020) -> debe pasar el filtro igual: prueba que
  -- el SP ya NO filtra por fecha/scope [CAMBIO DE DISEÑO 2026-08-26, "quitamos el filtro de
  -- consent_date" — ver T5].
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-005', 'CUST-005', 'PARTY-005',
    'CP_2', 'DOC-005', 'WEB',
    'EMP-005', 'PLC-005', 'otorgado',
    DATE '2020-01-15', 'gs://bucket/doc5.pdf'
  ),
  -- PARTY-006: 2 eventos del MISMO id, otorgado (más viejo) y luego rechazado (más reciente) ->
  -- el último evento es 'rechazado', NO debe aparecer en el output aunque haya tenido un
  -- 'otorgado' antes [RN-IBK-020, rollback 2026-08-27: t_consent_transaction ya no colapsa por
  -- cliente, esta SP recupera su propio QUALIFY — ver T6].
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-006A', 'CUST-006', 'PARTY-006',
    'CP_2', 'DOC-006A', 'WEB',
    'EMP-006', 'PLC-006', 'otorgado',
    DATE '2026-01-01', 'gs://bucket/doc6a.pdf'
  ),
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-006B', 'CUST-006', 'PARTY-006',
    'CP_2', 'DOC-006B', 'WEB',
    'EMP-006', 'PLC-006', 'rechazado',
    DATE '2026-02-01', 'gs://bucket/doc6b.pdf'
  ),
  -- PARTY-007: 3 eventos del MISMO id — otorgado, rechazado, otorgado de nuevo (el más
  -- reciente) -> SÍ debe aparecer, con los datos del ÚLTIMO evento (el segundo otorgado,
  -- DOC-007C) [ver T7].
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-007A', 'CUST-007', 'PARTY-007',
    'CP_2', 'DOC-007A', 'WEB',
    'EMP-007', 'PLC-007', 'otorgado',
    DATE '2026-01-01', 'gs://bucket/doc7a.pdf'
  ),
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-007B', 'CUST-007', 'PARTY-007',
    'CP_2', 'DOC-007B', 'WEB',
    'EMP-007', 'PLC-007', 'rechazado',
    DATE '2026-02-01', 'gs://bucket/doc7b.pdf'
  ),
  STRUCT(
    DATE '2026-04-01', '000', 'INTERBANK',
    'BU01', 'Banca Personal',
    'CT-007C', 'CUST-007', 'PARTY-007',
    'CP_2', 'DOC-007C', 'WEB',
    'EMP-007', 'PLC-007', 'otorgado',
    DATE '2026-03-01', 'gs://bucket/doc7c.pdf'
  )
]);

-- Fila preexistente que el DELETE por empresa + INSERT completo debe reemplazar (CAMBIO DE
-- DISEÑO 2026-08-26: ya no es un DELETE+INSERT por partición de fecha, es un espejo completo de
-- Interbank — NUNCA TRUNCATE, RN-IBK-019, para no tocar filas de otras empresas).
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
  v_fecha_prueba, v_fecha_prueba,
  '${project_ba_customer_consent_group}', 'test_master_party', 'ba_customer_consent_group',
  '${project_t_consent_transaction}', 'test_master_party', 't_consent_transaction',
  'test_stage_tmp',
  v_read, v_write
);

-- ============================================================
-- 3. Assertions
-- ============================================================

-- T0: métricas de monitoring — 4 filas válidas (PARTY-001, PARTY-002, PARTY-005, PARTY-007) pasan
-- el filtro RN-IBK-006 y el QUALIFY de último evento (PARTY-006 queda excluido — su último
-- evento es 'rechazado')
ASSERT v_write = 4
  AS 'T0: o_execution_data_write debía ser 4, se obtuvo ' || CAST(v_write AS STRING);
ASSERT v_read = v_write
  AS 'T0: o_execution_data_read debía igualar o_execution_data_write, se obtuvo read=' || CAST(v_read AS STRING) || ' write=' || CAST(v_write AS STRING);

-- T1: la fila preexistente (PARTY-OLD, itc_company_id 000) debe haber sido eliminada por el
-- DELETE por empresa
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-OLD'
);
ASSERT v_row_count = 0
  AS 'T1: la fila preexistente PARTY-OLD debía eliminarse con el DELETE por empresa, se obtuvo ' || CAST(v_row_count AS STRING);

-- T2: solo los 4 casos válidos (CP_2 + último evento otorgado) deben quedar en el output
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
);
ASSERT v_row_count = 4
  AS 'T2: se esperaban 4 filas (PARTY-001, PARTY-002, PARTY-005, PARTY-007), se obtuvo ' || CAST(v_row_count AS STRING);

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

-- T5: NO debe filtrar por fecha/scope [CAMBIO DE DISEÑO 2026-08-26] — PARTY-005, con un
-- consent_date de 2020 (muy fuera de cualquier ventana de proceso), debe quedar igual que
-- PARTY-001/002. Esta SP ya no toca ninguna tabla de scope (la elimina sp_t_consent_transaction_ibk,
-- ver su propio test).
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-005'
);
ASSERT v_row_count = 1
  AS 'T5: PARTY-005 (consent_date 2020-01-15) debía quedar igual, sin filtro de fecha — se obtuvo ' || CAST(v_row_count AS STRING);

-- T6 (RN-IBK-020): PARTY-006 — último evento 'rechazado' (más reciente que su 'otorgado'
-- anterior) — NO debe aparecer, aunque tuvo un 'otorgado' en el historial.
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-006'
);
ASSERT v_row_count = 0
  AS 'T6: PARTY-006 (último evento rechazado) no debía aparecer, se obtuvo ' || CAST(v_row_count AS STRING);

-- T7 (RN-IBK-020): PARTY-007 — 3 eventos (otorgado, rechazado, otorgado) — debe aparecer 1 sola
-- vez, con los datos del ÚLTIMO evento (el segundo otorgado, DOC-007C / 2026-03-01), no del
-- primero.
SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-007'
);
ASSERT v_row_count = 1
  AS 'T7: PARTY-007 debía aparecer exactamente 1 vez (último evento), se obtuvo ' || CAST(v_row_count AS STRING);

SET v_row_count = (
  SELECT COUNT(*) FROM `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`
  WHERE id = 'PARTY-007' AND documento_legal_id = 'DOC-007C' AND consent_date = DATE '2026-03-01'
);
ASSERT v_row_count = 1
  AS 'T7b: PARTY-007 debía quedarse con los datos del último evento (DOC-007C, 2026-03-01), se obtuvo ' || CAST(v_row_count AS STRING);

-- ============================================================
-- Cleanup
-- ============================================================
DROP TABLE IF EXISTS `${project_t_consent_transaction}.test_master_party.t_consent_transaction`;
DROP TABLE IF EXISTS `${project_ba_customer_consent_group}.test_master_party.ba_customer_consent_group`;
