-- SP: centraliza el archivo diario de consentimientos LPDP de Interbank (IBK) hacia la tabla RAW
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: consentimiento_ibk_archivo
-- Generado por: fac-data-stage-coding
--
-- CAMBIO DE DISEÑO (2026-08-26, confirmado con el usuario, RN-IBK-019): este SP YA NO cruza
-- contra iden_party ni escribe en t_consent_transaction — solo crea la tabla externa del archivo
-- y lo vuelca TAL CUAL a t_consent_transaction_raw (sin cruce, sin colapsar por cliente, "cada
-- evento tal cual"). El cruce con iden_party y la centralización hacia t_consent_transaction
-- ahora viven en sp_centralizar_t_consent_transaction_ibk.sql, que el Workflow llama UNA sola
-- vez por corrida (con el archivo de la ÚLTIMA fecha), no por cada fecha del rango.
--
-- Se invoca una vez por fecha a procesar (p_process_date_ini = p_process_date_end, siempre el
-- mismo valor en ambos — el Workflow llama una vez por día, nunca pasa un rango real en una
-- sola llamada, ver data/rules/bigquery.md). El Workflow decide qué fecha(s) pasar según el
-- modo de ejecución (RN-IBK-009):
--   normal   → fecha = fecha de sistema - 1 día (el offset lo aplica el Workflow, no este SP)
--   manual   → fecha = fecha indicada por el usuario, SIN offset
--   reproceso → una llamada por cada día de [process_date_init, process_date_fin], SIN offset
--
-- p_process_date_ini/end representan DIRECTAMENTE la carpeta a leer (folder_date =
-- p_process_date_ini, sin restarle un día) [RN-IBK-014].
--
-- Ya NO se filtra por ningún consent_date (RN-IBK-012/015 quedaron obsoletas con este cambio,
-- 2026-08-26): la tabla raw guarda el archivo COMPLETO, sin filtro de fecha ni distinción de
-- carga histórica — esa distinción solo tenía sentido cuando t_consent_transaction se cargaba
-- incrementalmente archivo por archivo; ahora t_consent_transaction siempre se centraliza
-- completa desde el archivo de la última fecha (ver sp_centralizar_t_consent_transaction_ibk.sql).
--
-- La tabla raw sí necesita ser idempotente ante un reproceso de la MISMA fecha (RN-IBK-019):
-- antes de insertar, se borra lo que hubiera en raw para ese folder_date.

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  -- Este SP siempre procesa una única fecha (RN-IBK-001: una tabla externa por fecha) — el
  -- Workflow pasa el mismo valor en ambos parámetros (ini = end), según data/rules/bigquery.md.
  -- Representan la carpeta a leer DIRECTAMENTE — ver nota de cabecera [RN-IBK-014].
  p_process_date_ini    DATE,
  p_process_date_end    DATE,

  -- Tabla externa / archivo IBK (fuente: consentimiento_ibk_archivo)
  p_project_archivo     STRING,
  p_dataset_archivo     STRING,

  -- Tabla destino: t_consent_transaction_raw [RN-IBK-019]
  p_project_raw         STRING,
  p_dataset_raw         STRING,
  p_table_raw           STRING,

  -- MONITORING [etapas.monitoring: true] — filas leídas/escritas de esta ejecución
  OUT o_execution_data_read   INT64,
  OUT o_execution_data_write  INT64
)
OPTIONS(strict_mode=false)
BEGIN

  -- ============================================================
  -- 1. DECLARACIÓN DE VARIABLES
  -- ============================================================
  DECLARE v_folder_date      STRING;   -- YYYYMMDD de la ruta GCS y del nombre de la tabla externa
  -- Formato 'YYYY-MM-DD' — v_folder_date (YYYYMMDD, sin guiones) NO es un literal DATE() válido
  -- en BigQuery, hace falta esta segunda variable para el WHERE/columna folder_date del punto 5.
  DECLARE v_folder_date_iso  STRING;
  DECLARE v_ext_table_name   STRING;
  DECLARE v_ext_table_path   STRING;
  DECLARE v_gcs_uri          STRING;
  DECLARE v_raw_path         STRING;
  DECLARE v_sql              STRING;
  DECLARE v_row_count        INT64;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  -- ============================================================
  -- 2. CÁLCULO DE FECHAS [RN-IBK-002, RN-IBK-014]
  -- ============================================================
  -- folder_date = p_process_date_ini DIRECTAMENTE, sin restar un día — el offset de 1 día
  -- (fecha de sistema → archivo de ayer) ya lo aplicó el Workflow ANTES de llamar a este SP,
  -- solo para el modo normal. En manual/reproceso la fecha que llega ya es la carpeta exacta.
  SET v_folder_date = FORMAT_DATE('%Y%m%d', p_process_date_ini);
  SET v_folder_date_iso = FORMAT_DATE('%F', p_process_date_ini);

  -- ============================================================
  -- 3. CREACIÓN DE LA TABLA EXTERNA TEMPORAL [RN-IBK-001]
  -- ============================================================
  -- Una tabla NUEVA por fecha procesada (t_consent_transaction_{fecha_archivo}_external) — no
  -- una tabla estática reemplazada. En un reproceso histórico coexisten varias simultáneamente,
  -- una por cada fecha del rango. expiration_timestamp cubre el TTL de 2 días (RN-IBK-001);
  -- CREATE OR REPLACE además la hace idempotente ante reintentos del mismo día.
  SET v_ext_table_name = 't_consent_transaction_' || v_folder_date || '_external';
  SET v_ext_table_path = p_project_archivo || '.' || p_dataset_archivo || '.' || v_ext_table_name;
  SET v_gcs_uri = 'gs://${gcs_bucket_consentimiento_ibk_archivo}/data/m_consent/current/' || v_folder_date
                  || '/*/T_IN_LPDP_CONSENTIMIENTO_' || v_folder_date || '.txt.gz';
  -- NOTA: el "{UUID}" del contrato original se convierte aquí en el wildcard '*' de BigQuery —
  -- no existe un placeholder literal de UUID en la sintaxis de external table.

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

  -- ============================================================
  -- 4. POLÍTICA ANTE ARCHIVO AUSENTE — no ejecutar DELETE sin INSERT de reemplazo
  -- ============================================================
  SET v_sql = '''SELECT COUNT(*) FROM `''' || v_ext_table_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO v_row_count;

  IF v_row_count = 0 THEN
    RAISE USING MESSAGE = FORMAT(
      'sp_t_consent_transaction_ibk: 0 filas en %s (fecha_archivo=%s) — no se ejecuta DELETE sin INSERT de reemplazo. Verificar si el archivo diario de Interbank llegó a la ruta esperada.',
      v_ext_table_path, v_folder_date
    );
  END IF;

  -- ============================================================
  -- 5. DELETE + INSERT EN LA TABLA RAW, POR ARCHIVO (folder_date) [RN-IBK-019]
  -- ============================================================
  -- Idempotente ante un reproceso de la MISMA fecha: borra lo que hubiera de este folder_date
  -- antes de insertar de nuevo. Fechas DISTINTAS del mismo reproceso NO se tocan entre sí.
  SET v_raw_path = p_project_raw || '.' || p_dataset_raw || '.' || p_table_raw;

  SET v_sql = '''DELETE FROM `''' || v_raw_path || '''` WHERE folder_date = DATE("''' || v_folder_date_iso || '''")''';
  EXECUTE IMMEDIATE v_sql;

  -- [RI-IBK-T_CONSENT_TRANSACTION-002/003] excluir duplicados y llave nula de la fuente
  -- principal — patrón obligatorio de @.claude/data/standard/data-integrity.md Sección 4.
  -- Llave = party_id + consent_date_time (NO consent_transaction_id): confirmado con datos
  -- reales de Interbank (2026-08-21) que ese campo viene SIEMPRE vacío en el archivo, tanto en
  -- dev como en producción. Tie-break por load_date ante duplicados exactos.
  -- SIN cruce contra iden_party aquí (RN-IBK-019) — cada evento del archivo se guarda tal cual,
  -- sin colapsar por cliente (eso ya no aplica en raw, solo al centralizar).
  SET v_sql = '''
    INSERT INTO `''' || v_raw_path || '''`
    (folder_date, process_date, itc_company_id, itc_company_name, business_unit_id, business_unit,
     consent_transaction_id, party_id, consent_id, documento_legal_id, approval_channel_id,
     employee_id, place_id, consent_type, consent_date, consent_date_time, signed_document,
     source_file_name, record_source, load_date, creation_user)
    SELECT
      DATE("''' || v_folder_date_iso || '''")            AS folder_date,
      SAFE_CAST(a.process_date AS DATE)  AS process_date,
      a.itc_company_id                   AS itc_company_id,
      a.itc_company_name                 AS itc_company_name,
      a.business_unit_id                 AS business_unit_id,
      a.business_unit                    AS business_unit,
      a.consent_transaction_id           AS consent_transaction_id,
      a.party_id                         AS party_id,
      a.consent_id                       AS consent_id,
      a.documento_legal_id               AS documento_legal_id,
      a.approval_channel_id              AS approval_channel_id,
      a.employee_id                      AS employee_id,
      a.place_id                         AS place_id,
      a.consent_type                     AS consent_type,
      SAFE_CAST(a.consent_date AS DATE)  AS consent_date,
      a.consent_date_time                AS consent_date_time,
      a.signed_document                  AS signed_document,
      a.source_file_name                 AS source_file_name,
      'LPDP_IBK_' || a.source_file_name  AS record_source,
      CURRENT_DATETIME('America/Lima')   AS load_date,
      SESSION_USER()                     AS creation_user
    FROM (
      SELECT * EXCEPT(rn)
      FROM (
        SELECT t.*,
          -- _FILE_NAME es un pseudo-campo de BigQuery para external tables sobre GCS — no lo
          -- cubre "t.*", hay que seleccionarlo explícito. Solo el nombre del archivo (sin ruta).
          REGEXP_EXTRACT(t._FILE_NAME, r'[^/]+$') AS source_file_name,
          ROW_NUMBER() OVER (
            PARTITION BY party_id, consent_date_time
            ORDER BY load_date DESC
          ) AS rn
        FROM `''' || v_ext_table_path || '''` t
        WHERE party_id IS NOT NULL AND consent_date_time IS NOT NULL
          AND itc_company_id IN ('000','1000')
      )
      WHERE rn = 1
    ) a
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: paso directo (sin cruce/filtro adicional) — write = read.
  SET o_execution_data_write = @@row_count;
  SET o_execution_data_read  = o_execution_data_write;

END;
