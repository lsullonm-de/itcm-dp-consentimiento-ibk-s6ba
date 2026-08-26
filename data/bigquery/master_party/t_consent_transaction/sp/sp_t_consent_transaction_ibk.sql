-- SP: centraliza el archivo diario de consentimientos LPDP de Interbank (IBK) en t_consent_transaction
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: consentimiento_ibk_archivo
-- Generado por: fac-data-stage-coding
--
-- Se invoca una vez por fecha a procesar (p_process_date_ini = p_process_date_end, siempre el
-- mismo valor en ambos — el Workflow llama una vez por día, nunca pasa un rango real en una
-- sola llamada, ver data/rules/bigquery.md). El Workflow decide qué fecha(s) pasar según el
-- modo de ejecución (RN-IBK-009):
--   normal   → fecha = fecha de sistema
--   manual   → fecha = fecha indicada por el usuario
--   reproceso → una llamada por cada día de [process_date_init, process_date_fin]
--
-- p_process_date_ini decide qué CARPETA leer (folder_date = p_process_date_ini - 1 día).
-- p_process_date_ini/end TAMBIÉN filtran los DATOS (consent_date real del contenido debe caer
-- en ese rango) — fix 2026-08-26: antes se insertaba el archivo completo sin filtrar por fecha,
-- lo que traía basura histórica (incluido consent_date de 1900) en cada reproceso.
--
-- NOTA: la tabla temporal tmp_t_consent_transaction_ibk NO se elimina al final de este SP —
-- sp_ba_customer_consent_group_ibk la usa para acotar su propio DELETE+INSERT (RN-IBK-006) y
-- es quien la elimina al terminar. Si este SP se llama sin encadenar el segundo, limpiar a mano.

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  -- Este SP siempre procesa una única fecha (RN-IBK-001: una tabla externa por fecha) — el
  -- Workflow pasa el mismo valor en ambos parámetros (ini = end), según data/rules/bigquery.md.
  p_process_date_ini    DATE,
  p_process_date_end    DATE,

  -- Tabla externa / archivo IBK (fuente: consentimiento_ibk_archivo)
  p_project_archivo     STRING,
  p_dataset_archivo     STRING,

  -- iden_itc_party_prd (fuente: iden_party)
  p_project_iden_party  STRING,
  p_dataset_iden_party  STRING,
  p_table_iden_party    STRING,

  -- Tabla destino: t_consent_transaction
  p_project_output      STRING,
  p_dataset_output      STRING,
  p_table_output         STRING,

  -- Stage
  p_dataset_stage       STRING,

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
  DECLARE v_ext_table_name   STRING;
  DECLARE v_ext_table_path   STRING;
  DECLARE v_gcs_uri          STRING;
  DECLARE v_iden_party_path  STRING;
  DECLARE v_stage_path       STRING;
  DECLARE v_output_path      STRING;
  DECLARE v_sql              STRING;
  DECLARE v_row_count        INT64;
  -- Literales de fecha para embeber en el SQL dinámico [RN-IBK-012]: dentro de EXECUTE IMMEDIATE
  -- no se puede referenciar un parámetro del SP por nombre (ej. p_process_date_ini) — hay que
  -- concatenar su valor como literal, igual que v_folder_date/v_ext_table_path más abajo.
  DECLARE v_date_ini_lit     STRING;
  DECLARE v_date_end_lit     STRING;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  -- ============================================================
  -- 2. CÁLCULO DE FECHAS [RN-IBK-002]
  -- ============================================================
  -- folder_date = process_date - 1 día. Este offset SOLO determina qué archivo/carpeta leer.
  -- El consent_date real de cada registro (usado para el DELETE+INSERT) se lee del propio
  -- contenido del archivo en el paso 5 — NO se deriva de este cálculo [RN-IBK-004].
  SET v_folder_date = FORMAT_DATE('%Y%m%d', DATE_SUB(p_process_date_ini, INTERVAL 1 DAY));

  -- Literales para el filtro de consent_date [RN-IBK-012] — ver DECLARE arriba.
  SET v_date_ini_lit = FORMAT_DATE('%F', p_process_date_ini);
  SET v_date_end_lit = FORMAT_DATE('%F', p_process_date_end);

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
  -- 5. RESOLUCIÓN DE id UNIFICADO ITC [RN-IBK-003]
  -- ============================================================
  -- Cruce por party_id contra iden_itc_party_prd. El JOIN también iguala itc_company_id en
  -- ambos lados (no solo party_id): iden_itc_party_prd trae una fila por cada empresa donde la
  -- persona tiene registro (confirmado en el glosario de la tabla de referencia iden_itc_party,
  -- ver docs/specs — fuentes.iden_party.observaciones), así que igualar solo por party_id
  -- multiplicaría filas si la persona también está registrada en otras empresas del grupo.
  -- SUPUESTO A VALIDAR con datos reales una vez haya acceso BQ (ver TODO).
  SET v_iden_party_path = p_project_iden_party || '.' || p_dataset_iden_party || '.' || p_table_iden_party;
  -- Sufijo de tabla hardcodeado a propósito (excepción aceptada, ver restricciones del spec,
  -- fac-data-rules-check REGLA 2/3): tabla efímera interna compartida solo entre este SP y
  -- sp_ba_customer_consent_group_ibk.sql, no varía entre ambientes.
  -- Proyecto resuelto vía ${project_iden_party} (Dataops, en deploy) y no con p_project_output:
  -- el dataset de stage (p_dataset_stage) vive físicamente bajo el proyecto de iden_party
  -- (dev-intercorp-data-operation), no bajo el proyecto de salida de t_consent_transaction.
  SET v_stage_path = '${project_iden_party}' || '.' || p_dataset_stage || '.tmp_t_consent_transaction_ibk';

  SET v_sql = '''
    CREATE OR REPLACE TABLE `''' || v_stage_path || '''` AS
    SELECT
      SAFE_CAST(a.process_date AS DATE)  AS process_date,
      a.itc_company_id                   AS itc_company_id,
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
      SAFE_CAST(a.consent_date AS DATE)  AS consent_date,
      a.signed_document                  AS signed_document
    FROM (
      -- [RI-IBK-T_CONSENT_TRANSACTION-002/003] excluir duplicados y llave nula de la fuente
      -- principal — patrón obligatorio de @.claude/data/standard/data-integrity.md Sección 4.
      -- Llave = party_id + consent_date_time (NO consent_transaction_id): confirmado con datos
      -- reales de Interbank (2026-08-21) que ese campo viene SIEMPRE vacío en el archivo, tanto
      -- en dev como en producción — no es utilizable como parte de la llave del evento. Se sigue
      -- seleccionando como conset_transaction_id más abajo (columna de auditoría, casi siempre
      -- NULL), pero ya no participa en el dedup ni en el filtro de llave nula. Tie-break por
      -- load_date (timestamp de escritura del archivo origen) ante duplicados exactos de
      -- party_id + consent_date_time.
      SELECT * EXCEPT(rn)
      FROM (
        SELECT t.*,
          ROW_NUMBER() OVER (
            PARTITION BY party_id, consent_date_time
            ORDER BY load_date DESC
          ) AS rn
        FROM `''' || v_ext_table_path || '''` t
        WHERE party_id IS NOT NULL AND consent_date_time IS NOT NULL
      )
      WHERE rn = 1
    ) a
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
      ON  p.party_id       = a.party_id
      AND p.itc_company_id = a.itc_company_id
    WHERE a.itc_company_id IN ('000','1000')
      -- FIX REAL (2026-08-26): hasta esta línea, p_process_date_end nunca se usaba — el archivo
      -- completo se insertaba sin importar su consent_date real (confirmado con el usuario:
      -- reprocesos de fechas acotadas seguían trayendo basura histórica, incluso consent_date
      -- de 1900). p_process_date_ini/end ahora SÍ filtran los datos, no solo eligen qué carpeta
      -- leer (eso lo sigue haciendo folder_date = p_process_date_ini - 1 día, sin cambios).
      -- Los parámetros del SP no son visibles dentro de EXECUTE IMMEDIATE por nombre — se
      -- concatenan como literal vía v_date_ini_lit/v_date_end_lit (ver DECLARE). Se usa
      -- DATE("...") con comillas dobles para el argumento, evitando anidar comillas simples
      -- dentro del string delimitado por ''' que arma toda esta query.
      AND SAFE_CAST(a.consent_date AS DATE) BETWEEN DATE("''' || v_date_ini_lit || '''") AND DATE("''' || v_date_end_lit || '''")
    -- CAMBIO DE DISEÑO (2026-08-26, confirmado con el usuario): t_consent_transaction pasa de
    -- "historial completo de eventos" a "solo el último evento por cliente" (id) DENTRO del
    -- rango de fechas solicitado — el mismo criterio que ya se aplicó a ba_customer_consent_group
    -- el 2026-08-25, pero movido un nivel arriba: aquí se resuelve una sola vez (independiente
    -- del consent_type, cubre 'otorgado' Y 'rechazado') y ba_customer_consent_group_ibk.sql ya
    -- NO necesita su propio ROW_NUMBER — solo filtra CP_2/otorgado sobre esta tabla, que ya
    -- viene deduplicada por cliente.
    QUALIFY ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY a.consent_date DESC) = 1
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 6. DELETE + INSERT EN LA TABLA FINAL [RN-IBK-004] [RN-IBK-005]
  -- ============================================================
  -- Se eliminan solo las particiones (itc_company_id, consent_date) presentes en el batch —
  -- consent_date es el valor real de cada registro del archivo, no un offset calculado.
  SET v_output_path = p_project_output || '.' || p_dataset_output || '.' || p_table_output;

  SET v_sql = '''
    DELETE FROM `''' || v_output_path || '''` t
    WHERE EXISTS (
      SELECT 1 FROM `''' || v_stage_path || '''` s
      WHERE s.itc_company_id = t.itc_company_id
        AND s.consent_date   = t.consent_date
    )
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- record_source: literal 'LPDP_IBK' — confirmar con el equipo si debe ser otro valor estándar
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
      signed_document,
      'LPDP_IBK'                        AS record_source,
      CURRENT_DATETIME('America/Lima') AS load_date,
      SESSION_USER()                    AS creation_user
    FROM `''' || v_stage_path || '''`
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: write = filas insertadas en la tabla final; read = filas resueltas en stage
  -- (fuente del INSERT anterior). Debe ir en este orden — @@row_count solo vale para la
  -- sentencia dinámica inmediatamente anterior.
  SET o_execution_data_write = @@row_count;

  SET v_sql = '''SELECT COUNT(1) FROM `''' || v_stage_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO o_execution_data_read;

  -- tmp_t_consent_transaction_ibk se deja viva a propósito — ver nota de cabecera.

END;
