-- SP de integridad (gate de entrada) — RI-IBK-T_CONSENT_TRANSACTION-001
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | etapas.integridad: true
-- Generado por: fac-data-stage-integrity
--
-- Evalúa únicamente la regla con accion: detener_proceso (actualidad de la fuente principal
-- consentimiento_ibk_archivo). Las reglas de duplicados/llave_nula (excluir_registros) de
-- ambas fuentes se resuelven en sp_t_consent_transaction_ibk.sql (patrón QUALIFY ROW_NUMBER()),
-- no aquí.
--
-- No escribe ninguna tabla — todo el resultado viaja en los OUT. reglas_integridad.
-- registro_resultados = true (desde etapas.monitoring: true) — el workflow envía este resultado
-- a la metadata API vía RegisterIntegrityResults, además de usar o_flag_detener para cortar
-- el proceso si corresponde.
--
-- NOTA de diseño: al ser tipo_fuente: archivo con tabla externa de nombre dinámico (una por
-- fecha, RN-IBK-001), este SP recrea la MISMA tabla externa que luego usará
-- sp_t_consent_transaction_ibk.sql (CREATE OR REPLACE es idempotente, no duplica objetos) para
-- poder contar filas. Si la ruta/nombre de la tabla externa cambia, actualizar ambos SPs.

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_integridad_t_consent_transaction`(
  -- Este SP siempre evalúa una única fecha (una tabla externa por fecha, RN-IBK-001) — el
  -- Workflow pasa el mismo valor en ambos parámetros (ini = end), según data/rules/bigquery.md.
  IN  p_process_date_ini DATE,
  IN  p_process_date_end DATE,
  IN  p_project_archivo  STRING,
  IN  p_dataset_archivo  STRING,
  OUT o_flag_detener     INT64,
  OUT o_motivo_detencion STRING,
  OUT o_resultado_json   STRING
)
BEGIN

  DECLARE v_motivos        ARRAY<STRING> DEFAULT [];
  DECLARE v_resultados     ARRAY<STRING> DEFAULT [];
  DECLARE v_folder_date    STRING;
  DECLARE v_ext_table_path STRING;
  DECLARE v_gcs_uri        STRING;
  DECLARE v_registros      INT64;
  DECLARE v_tiene_datos    BOOL;
  DECLARE v_motivo_regla   STRING;
  DECLARE v_sql            STRING;

  SET o_flag_detener     = 0;
  SET o_motivo_detencion = '';
  SET o_resultado_json   = '[]';

  -- ============================================================
  -- RI-IBK-T_CONSENT_TRANSACTION-001 (actualidad, fuente: consentimiento_ibk_archivo, detener_proceso)
  -- ============================================================
  -- dias_tolerancia = 1 → coincide con RN-IBK-002 (folder_date = process_date - 1 día)
  SET v_folder_date = FORMAT_DATE('%Y%m%d', DATE_SUB(p_process_date_ini, INTERVAL 1 DAY));
  SET v_ext_table_path = p_project_archivo || '.' || p_dataset_archivo
                         || '.t_consent_transaction_' || v_folder_date || '_external';
  SET v_gcs_uri = 'gs://p-ibkbi-rdp-stg-dlk-us-suoh/data/m_consent/current/' || v_folder_date
                  || '/*/T_IN_LPDP_CONSENTIMIENTO_' || v_folder_date || '.txt.gz';

  SET v_sql = '''
    CREATE OR REPLACE EXTERNAL TABLE `''' || v_ext_table_path || '''`
    (
      process_date            STRING,
      itc_company_id          STRING,
      itc_company_name        STRING,
      business_unit_id        STRING,
      business_unit           STRING,
      consent_transaction_id  STRING,
      party_id                STRING,
      consent_id              STRING,
      documento_legal_id      STRING,
      approval_channel_id     STRING,
      approval_channel_name   STRING,
      employee_id             STRING,
      place_id                STRING,
      consent_type            STRING,
      consent_date            STRING,
      consent_date_time       STRING,
      signed_document         STRING,
      record_source           STRING,
      load_date               STRING,
      creation_user           STRING
    )
    OPTIONS (
      format = 'CSV',
      uris = ["''' || v_gcs_uri || '''"],
      field_delimiter = '|',
      skip_leading_rows = 0,
      allow_quoted_newlines = true,
      expiration_timestamp = TIMESTAMP_ADD(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)
    )
  ''';
  EXECUTE IMMEDIATE v_sql;

  SET v_sql = '''SELECT COUNT(*) FROM `''' || v_ext_table_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO v_registros;

  SET v_tiene_datos = v_registros > 0;
  SET v_motivo_regla = IF(v_tiene_datos, '',
    'Sin datos en fuente principal (consentimiento_ibk_archivo) para folder_date=' || v_folder_date
    || ' — ' || v_gcs_uri);

  IF NOT v_tiene_datos THEN
    SET v_motivos = ARRAY_CONCAT(v_motivos, [v_motivo_regla]);
  END IF;

  SET v_resultados = ARRAY_CONCAT(v_resultados, [TO_JSON_STRING(STRUCT(
    'RI-IBK-T_CONSENT_TRANSACTION-001'    AS rule_code,
    'consentimiento_ibk_archivo'          AS source_id,
    'actualidad'                          AS check_type,
    'detener_proceso'                     AS check_action,
    IF(v_tiene_datos, 'PASSED', 'FAILED') AS integrity_status_code,
    IF(v_tiene_datos, '0', '1')           AS flag_stop_process,
    v_registros                           AS records_evaluated,
    0                                     AS records_affected,
    v_motivo_regla                        AS stop_reason
  ))]);

  -- Las reglas RI-IBK-T_CONSENT_TRANSACTION-002 a 005 (duplicados/llave_nula, ambas fuentes)
  -- tienen accion: excluir_registros — no generan bloque aquí (ver Sección 4 del estándar de
  -- integridad). Se resuelven en sp_t_consent_transaction_ibk.sql.

  IF ARRAY_LENGTH(v_motivos) > 0 THEN
    SET o_flag_detener     = 1;
    SET o_motivo_detencion = ARRAY_TO_STRING(v_motivos, ' | ');
  END IF;

  SET o_resultado_json = '[' || ARRAY_TO_STRING(v_resultados, ',') || ']';

END;
