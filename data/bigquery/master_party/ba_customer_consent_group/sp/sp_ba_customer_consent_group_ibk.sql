-- SP: deriva ba_customer_consent_group a partir de t_consent_transaction (RN-IBK-006)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: t_consent_transaction
-- Generado por: fac-data-stage-coding
--
-- CAMBIO DE DISEÑO (2026-08-26, confirmado con el usuario): dejó de acotarse por fecha/scope.
-- Ahora es un DELETE por empresa + INSERT de TODO lo que haya en t_consent_transaction que
-- cumpla CP_2/otorgado — un espejo completo de Interbank, no incremental (NUNCA TRUNCATE,
-- RN-IBK-019: la tabla podría tener filas de otras empresas). El Workflow ya NO la llama una
-- vez por cada fecha del rango: la llama UNA sola vez, después de procesar todas las fechas de
-- la corrida (ver wf-ibk-consentimiento.yaml) — llamarla por fecha reconstruiría la tabla
-- completa N veces en el mismo reproceso, puro desperdicio.
--
-- p_process_date_ini/end y p_dataset_stage quedan en la firma sin usarse para filtrar (decisión
-- del usuario, 2026-08-26): esta SP ya no lee ninguna tabla de scope (tmp_t_consent_transaction_ibk
-- la elimina ahora sp_t_consent_transaction_ibk.sql, que es quien la crea — ver su cabecera).
-- El Workflow les pasa el rango de fechas de la corrida solo para trazabilidad en monitoring.
--
-- Guarda solo el ÚLTIMO evento 'otorgado' por cliente (id) —no el histórico completo—, pero
-- el dedup en sí ya lo garantiza sp_t_consent_transaction_ibk.sql (2026-08-26): esta SP solo
-- filtra CP_2/otorgado, no necesita su propio ROW_NUMBER.

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_ba_customer_consent_group_ibk`(
  -- No se usan para filtrar (ver cabecera) — se mantienen en la firma por decisión del usuario.
  p_process_date_ini DATE,
  p_process_date_end DATE,

  -- Tabla destino: ba_customer_consent_group
  p_project_output   STRING,
  p_dataset_output   STRING,
  p_table_output     STRING,

  -- Fuente: t_consent_transaction
  p_project_source   STRING,
  p_dataset_source   STRING,
  p_table_source     STRING,

  -- No se usa (ver cabecera) — se mantiene en la firma por decisión del usuario.
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
  DECLARE v_sql          STRING;
  DECLARE v_source_path  STRING;
  DECLARE v_output_path  STRING;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  SET v_source_path = p_project_source || '.' || p_dataset_source || '.' || p_table_source;
  SET v_output_path = p_project_output || '.' || p_dataset_output || '.' || p_table_output;

  -- ============================================================
  -- 2. DELETE por EMPRESA — espejo completo de Interbank, no incremental (ver cabecera)
  -- ============================================================
  -- NUNCA TRUNCATE (corregido 2026-08-26, RN-IBK-019): un TRUNCATE borraría también filas de
  -- OTRAS empresas que pudiera tener ba_customer_consent_group — se acota el DELETE a Interbank.
  SET v_sql = '''DELETE FROM `''' || v_output_path || '''` WHERE itc_company_id IN ('000','1000')''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 3. INSERT — TODO t_consent_transaction filtrado por CP_2/otorgado [RN-IBK-006]
  -- ============================================================
  -- approval_channel_name queda siempre NULL — no tiene origen en t_consent_transaction
  -- (confirmado por el equipo, 2026-08-19). Se conserva la columna por compatibilidad
  -- con el contrato original de ba_customer_consent_group.
  -- record_source: literal 'LPDP_IBK' — confirmar con el equipo si debe ser otro valor estándar.
  SET v_sql = '''
    INSERT INTO `''' || v_output_path || '''`
    (process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
     id, documento_legal_id, approval_channel_id, approval_channel_name, employee_id,
     place_id, consent_date, signed_document, record_source, load_date, creation_user)
    SELECT
      tct.process_date, tct.itc_company_id, tct.itc_company_name, tct.business_unit_id,
      tct.business_unit, tct.id, tct.documento_legal_id, tct.approval_channel_id,
      CAST(NULL AS STRING)                AS approval_channel_name,
      tct.employee_id, tct.place_id, tct.consent_date, tct.signed_document,
      'LPDP_IBK'                          AS record_source,
      CURRENT_DATETIME('America/Lima')    AS load_date,
      SESSION_USER()                      AS creation_user
    FROM `''' || v_source_path || '''` tct
    WHERE tct.conset_id = 'CP_2'
      AND tct.consent_type = 'otorgado'
      AND tct.itc_company_id IN ('000','1000')
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: espejo directo (sin filtro adicional entre lectura e inserción) — read = write.
  SET o_execution_data_write = @@row_count;
  SET o_execution_data_read  = o_execution_data_write;

END;
