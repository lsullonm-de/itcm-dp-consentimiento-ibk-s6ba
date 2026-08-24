-- SP: deriva ba_customer_consent_group a partir de t_consent_transaction (RN-IBK-006)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: t_consent_transaction
-- Generado por: fac-data-stage-coding
--
-- Se invoca inmediatamente después de sp_t_consent_transaction_ibk dentro del mismo Workflow,
-- para la misma fecha. No vuelve a leer el archivo ni la tabla externa (RN-IBK-006):
-- toma como fuente única t_consent_transaction, acotado a las particiones (itc_company_id +
-- consent_date) que sp_t_consent_transaction_ibk acaba de cargar (tabla de scope
-- tmp_t_consent_transaction_ibk, que esta SP también elimina al finalizar).

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_ba_customer_consent_group_ibk`(
  -- Tabla destino: ba_customer_consent_group
  p_project_output   STRING,
  p_dataset_output   STRING,
  p_table_output     STRING,

  -- Fuente: t_consent_transaction
  p_project_source   STRING,
  p_dataset_source   STRING,
  p_table_source     STRING,

  -- Stage (mismo dataset que usó sp_t_consent_transaction_ibk para el scope)
  p_dataset_stage    STRING,

  -- MONITORING [etapas.monitoring: true] — filas leídas/escritas de esta ejecución
  OUT o_execution_data_read   INT64,
  OUT o_execution_data_write  INT64
)
OPTIONS(strict_mode=false)
BEGIN

  -- ============================================================
  -- 1. DECLARACIÓN DE VARIABLES
  -- ============================================================
  DECLARE v_sql            STRING;
  DECLARE v_scope_path     STRING;   -- tmp_t_consent_transaction_ibk, generada por el SP anterior
  DECLARE v_source_path    STRING;
  DECLARE v_output_path    STRING;
  DECLARE v_filtered_path  STRING;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  -- Sufijos de tabla hardcodeados a propósito (excepción aceptada, ver restricciones del spec,
  -- fac-data-rules-check REGLA 2/3): tablas efímeras internas de este módulo, no varían entre
  -- ambientes. El dataset de stage (p_dataset_stage) vive físicamente bajo ${project_iden_party}
  -- (dev-intercorp-data-operation), no bajo p_project_output (dev-intercorp-data-storage) — el
  -- dataset "demo_migracion" de stage no existe en ese proyecto. Aplica a AMBAS tablas de stage,
  -- no solo a la que genera sp_t_consent_transaction_ibk.sql (bug real 2026-08-21: v_filtered_path
  -- seguía usando p_project_output y falló con "Dataset ... was not found").
  SET v_scope_path    = '${project_iden_party}' || '.' || p_dataset_stage  || '.tmp_t_consent_transaction_ibk';
  SET v_source_path   = p_project_source || '.' || p_dataset_source || '.' || p_table_source;
  SET v_output_path   = p_project_output || '.' || p_dataset_output || '.' || p_table_output;
  SET v_filtered_path = '${project_iden_party}' || '.' || p_dataset_stage  || '.tmp_ba_customer_consent_group_ibk';

  -- ============================================================
  -- 2. FILTRO DE NEGOCIO [RN-IBK-006]
  -- ============================================================
  -- conset_id = 'CP_2' AND consent_type = 'otorgado' AND itc_company_id IN ('000','1000'),
  -- acotado a las particiones que el paso anterior acaba de tocar (evita reescanear todo
  -- t_consent_transaction en cada corrida).
  -- approval_channel_name queda siempre NULL — no tiene origen en t_consent_transaction
  -- (confirmado por el equipo, 2026-08-19). Se conserva la columna por compatibilidad
  -- con el contrato original de ba_customer_consent_group.
  --
  -- BUG REAL (2026-08-21): esto era un INNER JOIN contra scope en vez de EXISTS. scope
  -- (tmp_t_consent_transaction_ibk) tiene UNA FILA POR EVENTO (no una fila por itc_company_id+
  -- consent_date) — el JOIN multiplicaba cada fila de tct por cada fila de scope que compartiera
  -- la misma fecha (fan-out), insertando miles de millones de filas duplicadas en vez de ~3.7M.
  -- scope solo debe usarse para ACOTAR el escaneo (semi-join), nunca para hacer JOIN real de
  -- columnas — de ahí EXISTS en vez de INNER JOIN.
  SET v_sql = '''
    CREATE OR REPLACE TABLE `''' || v_filtered_path || '''` AS
    SELECT
      tct.process_date,
      tct.itc_company_id,
      tct.itc_company_name,
      tct.business_unit_id,
      tct.business_unit,
      tct.id,
      tct.documento_legal_id,
      tct.approval_channel_id,
      CAST(NULL AS STRING) AS approval_channel_name,
      tct.employee_id,
      tct.place_id,
      tct.consent_date,
      tct.signed_document
    FROM `''' || v_source_path || '''` tct
    WHERE tct.conset_id = 'CP_2'
      AND tct.consent_type = 'otorgado'
      AND tct.itc_company_id IN ('000','1000')
      AND EXISTS (
        SELECT 1 FROM `''' || v_scope_path || '''` scope
        WHERE scope.itc_company_id = tct.itc_company_id
          AND scope.consent_date   = tct.consent_date
      )
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 3. DELETE + INSERT por itc_company_id + consent_date [RN-IBK-007]
  -- ============================================================
  SET v_sql = '''
    DELETE FROM `''' || v_output_path || '''` t
    WHERE EXISTS (
      SELECT 1 FROM `''' || v_filtered_path || '''` s
      WHERE s.itc_company_id = t.itc_company_id
        AND s.consent_date   = t.consent_date
    )
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- record_source: literal 'LPDP_IBK' — confirmar con el equipo si debe ser otro valor estándar
  SET v_sql = '''
    INSERT INTO `''' || v_output_path || '''`
    (process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
     id, documento_legal_id, approval_channel_id, approval_channel_name, employee_id,
     place_id, consent_date, signed_document, record_source, load_date, creation_user)
    SELECT
      process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
      id, documento_legal_id, approval_channel_id, approval_channel_name, employee_id,
      place_id, consent_date, signed_document,
      'LPDP_IBK'                          AS record_source,
      CURRENT_DATETIME('America/Lima')    AS load_date,
      SESSION_USER()                      AS creation_user
    FROM `''' || v_filtered_path || '''`
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: write = filas insertadas en ba_customer_consent_group; read = filas del
  -- filtro de negocio (fuente del INSERT anterior). Debe capturarse antes de la limpieza.
  SET o_execution_data_write = @@row_count;

  SET v_sql = '''SELECT COUNT(1) FROM `''' || v_filtered_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO o_execution_data_read;

  -- ============================================================
  -- 4. LIMPIEZA — esta SP es la última consumidora del scope generado
  --    por sp_t_consent_transaction_ibk
  -- ============================================================
  SET v_sql = '''DROP TABLE IF EXISTS `''' || v_filtered_path || '''`''';
  EXECUTE IMMEDIATE v_sql;

  SET v_sql = '''DROP TABLE IF EXISTS `''' || v_scope_path || '''`''';
  EXECUTE IMMEDIATE v_sql;

END;
