-- SP: centraliza hacia t_consent_transaction el archivo de UNA sola fecha (folder_date) desde
-- t_consent_transaction_raw — cruce con iden_party y colapso a 1 fila por cliente.
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: t_consent_transaction_raw
-- Generado por: fac-data-stage-coding
--
-- CAMBIO DE DISEÑO (2026-08-26, confirmado con el usuario, RN-IBK-019): reemplaza la parte de
-- sp_t_consent_transaction_ibk.sql que antes cruzaba contra iden_party y escribía directo en
-- t_consent_transaction. Ahora esa SP solo vuelca el archivo tal cual a t_consent_transaction_raw
-- (una vez POR CADA fecha del rango); esta SP se llama UNA sola vez por corrida del Workflow,
-- con p_folder_date = la ÚLTIMA fecha que sí tuvo archivo (no necesariamente process_date_fin,
-- si las últimas fechas del rango no tuvieran archivo) — el resto de fechas del reproceso quedan
-- solo en raw, con fines de trazabilidad.
--
-- CRUCE CON iden_party [RN-IBK-019, corregido 2026-08-26]: por party_id ÚNICAMENTE, SIN igualar
-- también itc_company_id (a diferencia del diseño anterior, RN-IBK-003). Confirmado con datos
-- reales de dev (2026-08-26): el archivo de Interbank siempre trae itc_company_id='000', pero
-- una misma persona puede tener en iden_itc_party_prd un registro bajo '000' Y otro bajo '1000'
-- (ambos códigos son Interbank) — antes, exigir que coincidiera el itc_company_id del archivo
-- excluía ~2.78M de esas filas (un evento por persona, en vez de uno por cada registro de
-- empresa que tiene esa persona). Pedido explícito del usuario: "no excluir nada" — cada
-- coincidencia de iden_party (party_id) genera su propia fila en t_consent_transaction, con el
-- itc_company_id e id de ESE registro de iden_party (no el itc_company_id del archivo).
--
-- Ya NO se filtra por ningún consent_date (RN-IBK-012 quedó obsoleta, 2026-08-26): se centraliza
-- el archivo COMPLETO de p_folder_date, sin acotar por fecha — ya no puede competir con otro
-- archivo por la misma consent_date (cada corrida centraliza UN solo archivo).
--
-- DELETE por EMPRESA, no por fecha ni TRUNCATE (RN-IBK-019): se reemplaza TODO lo que haya de
-- itc_company_id IN ('000','1000') en t_consent_transaction — la tabla siempre queda como el
-- espejo del último archivo centralizado. TRUNCATE se descartó a propósito: t_consent_transaction
-- podría tener filas de otras empresas en el futuro y un TRUNCATE las borraría también.

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_centralizar_t_consent_transaction_ibk`(
  -- Fecha del archivo (folder_date) de t_consent_transaction_raw a centralizar — la última
  -- fecha que sí tuvo archivo en la corrida del Workflow, no siempre process_date_fin.
  p_folder_date        DATE,

  -- Fuente: t_consent_transaction_raw
  p_project_raw        STRING,
  p_dataset_raw        STRING,
  p_table_raw          STRING,

  -- iden_itc_party_prd (fuente: iden_party)
  p_project_iden_party STRING,
  p_dataset_iden_party STRING,
  p_table_iden_party   STRING,

  -- Tabla destino: t_consent_transaction
  p_project_output     STRING,
  p_dataset_output     STRING,
  p_table_output       STRING,

  -- Stage
  p_dataset_stage      STRING,

  -- MONITORING [etapas.monitoring: true] — filas leídas/escritas de esta ejecución
  OUT o_execution_data_read   INT64,
  OUT o_execution_data_write  INT64
)
OPTIONS(strict_mode=false)
BEGIN

  -- ============================================================
  -- 1. DECLARACIÓN DE VARIABLES
  -- ============================================================
  DECLARE v_raw_path         STRING;
  DECLARE v_iden_party_path  STRING;
  DECLARE v_output_path      STRING;
  DECLARE v_stage_path       STRING;
  DECLARE v_sql              STRING;
  DECLARE v_folder_date_lit  STRING;   -- YYYYMMDD, sufijo de la tabla temporal [RN-IBK-013]
  -- Formato 'YYYY-MM-DD' — v_folder_date_lit (YYYYMMDD, sin guiones) NO es un literal DATE()
  -- válido en BigQuery, hace falta esta segunda variable para el WHERE del punto 2.
  DECLARE v_folder_date_iso  STRING;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  SET v_folder_date_lit = FORMAT_DATE('%Y%m%d', p_folder_date);
  SET v_folder_date_iso = FORMAT_DATE('%F', p_folder_date);

  SET v_raw_path        = p_project_raw || '.' || p_dataset_raw || '.' || p_table_raw;
  SET v_iden_party_path = p_project_iden_party || '.' || p_dataset_iden_party || '.' || p_table_iden_party;
  SET v_output_path     = p_project_output || '.' || p_dataset_output || '.' || p_table_output;
  -- Prefijo de tabla hardcodeado a propósito (excepción aceptada, ver restricciones del spec,
  -- fac-data-rules-check REGLA 2/3): tabla efímera interna de este módulo, no varía entre
  -- ambientes. Vive bajo ${project_iden_party} (Dataops, en deploy), no bajo p_project_output —
  -- el dataset de stage no existe físicamente bajo el proyecto de salida.
  SET v_stage_path = '${project_iden_party}' || '.' || p_dataset_stage || '.tmp_centralizar_t_consent_transaction_ibk_' || v_folder_date_lit;

  -- ============================================================
  -- 2. RESOLUCIÓN DE id UNIFICADO ITC [RN-IBK-003, cruce corregido 2026-08-26]
  -- ============================================================
  -- Cruce por party_id ÚNICAMENTE — ver nota de cabecera (RN-IBK-019). NO se excluye ninguna
  -- coincidencia: si la persona tiene varios registros en iden_party (uno por empresa), cada
  -- uno genera su propia fila aquí, con el itc_company_id/id de ESE registro.
  SET v_sql = '''
    CREATE OR REPLACE TABLE `''' || v_stage_path || '''` AS
    SELECT
      SAFE_CAST(a.process_date AS DATE)  AS process_date,
      p.itc_company_id                   AS itc_company_id,
      a.itc_company_name                 AS itc_company_name,
      a.business_unit_id                 AS business_unit_id,
      a.business_unit                    AS business_unit,
      a.consent_transaction_id           AS conset_transaction_id,
      a.party_id                         AS customer_id,
      p.id                               AS id,
      a.consent_id                       AS conset_id,
      a.documento_legal_id               AS documento_legal_id,
      a.approval_channel_id              AS approval_channel_id,
      a.employee_id                      AS employee_id,
      a.place_id                         AS place_id,
      a.consent_type                     AS consent_type,
      a.consent_date                     AS consent_date,
      a.signed_document                  AS signed_document,
      a.record_source                    AS record_source
    FROM `''' || v_raw_path || '''` a
    INNER JOIN (
      -- [RI-IBK-T_CONSENT_TRANSACTION-004/005] excluir duplicados (se queda con el registro
      -- más reciente por process_date) y llave nula de iden_party
      SELECT * EXCEPT(rn)
      FROM (
        SELECT t.*,
          ROW_NUMBER() OVER (
            PARTITION BY party_id, itc_company_id
            ORDER BY process_date DESC
          ) AS rn
        FROM `''' || v_iden_party_path || '''` t
        WHERE party_id IS NOT NULL AND itc_company_id IS NOT NULL
      )
      WHERE rn = 1
    ) p
      ON  p.party_id = a.party_id
    WHERE a.folder_date = DATE("''' || v_folder_date_iso || '''")
    -- Último evento por cliente (RN-IBK-011) — ahora particionado por p.id, que puede repetirse
    -- el mismo evento del archivo en varias filas (una por cada registro de empresa de esa
    -- persona en iden_party), cada una con su propio id.
    QUALIFY ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY a.consent_date DESC) = 1
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 3. DELETE POR EMPRESA + INSERT [RN-IBK-019]
  -- ============================================================
  -- Reemplaza TODO lo que haya de Interbank en t_consent_transaction — nunca TRUNCATE (ver
  -- cabecera): la tabla podría tener filas de otras empresas.
  SET v_sql = '''DELETE FROM `''' || v_output_path || '''` WHERE itc_company_id IN ('000','1000')''';
  EXECUTE IMMEDIATE v_sql;

  SET v_sql = '''
    INSERT INTO `''' || v_output_path || '''`
    (process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
     conset_transaction_id, customer_id, id, conset_id, documento_legal_id,
     approval_channel_id, employee_id, place_id, consent_type, consent_date,
     signed_document, record_source, load_date, creation_user)
    SELECT
      process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
      conset_transaction_id, customer_id, id, conset_id, documento_legal_id,
      approval_channel_id, employee_id, place_id, consent_type, consent_date,
      signed_document, record_source,
      CURRENT_DATETIME('America/Lima')   AS load_date,
      SESSION_USER()                     AS creation_user
    FROM `''' || v_stage_path || '''`
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: write = filas insertadas; read = filas resueltas en stage.
  SET o_execution_data_write = @@row_count;

  SET v_sql = '''SELECT COUNT(1) FROM `''' || v_stage_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO o_execution_data_read;

  -- ============================================================
  -- 4. LIMPIEZA
  -- ============================================================
  SET v_sql = '''DROP TABLE IF EXISTS `''' || v_stage_path || '''`''';
  EXECUTE IMMEDIATE v_sql;

END;
