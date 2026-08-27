-- SP: centraliza el archivo diario de consentimientos LPDP de Interbank (IBK) en t_consent_transaction
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | Fuente: consentimiento_ibk_archivo
-- Generado por: fac-data-stage-coding
--
-- ROLLBACK (2026-08-27, pedido por el usuario, RN-IBK-020): revierte RN-IBK-019 — vuelve a hacer
-- TODO directo (tabla externa + cruce + DELETE/INSERT) por cada fecha del rango, sin pasar por
-- una tabla raw ni centralizar solo el último archivo. Se elimina t_consent_transaction_raw y
-- sp_centralizar_t_consent_transaction_ibk.sql (vivieron menos de un día).
--
-- t_consent_transaction vuelve a guardar el HISTORIAL COMPLETO por cliente (ya NO "solo el
-- último evento", RN-IBK-011 revertida) — si un id viene otorgado, luego revocado, luego
-- otorgado de nuevo (en fechas/archivos distintos), las 3 filas conviven en la tabla, una por
-- cada consent_date real. La deduplicación "cuál es el estado vigente de cada cliente" ahora es
-- responsabilidad de ba_customer_consent_group_ibk.sql (ver su propio QUALIFY).
--
-- El cruce con iden_party SIGUE siendo solo por party_id, sin igualar itc_company_id (RN-IBK-019,
-- NO se revierte esa parte) — cada coincidencia de iden_party genera su propia fila, con el
-- itc_company_id/id de ESE registro.
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
-- Los DATOS se filtran por consent_date = v_max_consent_date (el MÁXIMO real del archivo,
-- RN-IBK-012) — NO contra p_process_date_ini/end directamente, porque el desfase entre
-- folder_date y el consent_date de contenido resultó variable ENTRE ARCHIVOS.
-- EXCEPCIÓN: si p_carga_historica = TRUE (RN-IBK-015), no se aplica ningún filtro de consent_date
-- — se toma TODO el historial del archivo. Reservado para el primer archivo de un reproceso
-- cuando t_consent_transaction todavía no tiene ninguna fila de Interbank (carga inicial).

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_t_consent_transaction_ibk`(
  -- Este SP siempre procesa una única fecha (RN-IBK-001: una tabla externa por fecha) — el
  -- Workflow pasa el mismo valor en ambos parámetros (ini = end), según data/rules/bigquery.md.
  -- Representan la carpeta a leer DIRECTAMENTE — ver nota de cabecera [RN-IBK-014].
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
  p_table_output        STRING,

  -- Stage
  p_dataset_stage       STRING,

  -- Carga histórica [RN-IBK-015]: TRUE solo para el primer archivo de un reproceso cuando
  -- t_consent_transaction no tiene ninguna fila de Interbank todavía — omite el filtro de
  -- consent_date, trae TODO el historial del archivo. El Workflow decide este valor, no el SP.
  p_carga_historica     BOOL,

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
  -- Fecha real más reciente del archivo [RN-IBK-012] — calculada, no asumida a partir de
  -- p_process_date_ini/end (ver punto 4b).
  DECLARE v_max_consent_date DATE;
  -- Literales de fecha para embeber en el SQL dinámico: dentro de EXECUTE IMMEDIATE no se puede
  -- referenciar una variable/parámetro por nombre — hay que concatenar su valor como literal.
  DECLARE v_date_ini_lit     STRING;
  DECLARE v_date_end_lit     STRING;
  -- Cláusula de filtro de consent_date, armada condicionalmente [RN-IBK-015]: vacía si
  -- p_carga_historica = TRUE (trae todo el historial del archivo), o el filtro por
  -- v_max_consent_date en caso contrario (ver punto 4b).
  DECLARE v_date_filter_clause STRING;
  -- Sufijo de fecha para la tabla temporal [RN-IBK-013] — evita choques entre ejecuciones
  -- concurrentes (ej. el scheduler normal disparando mientras corre un reproceso manual).
  DECLARE v_process_date_lit STRING;

  SET o_execution_data_read  = 0;
  SET o_execution_data_write = 0;

  -- ============================================================
  -- 2. CÁLCULO DE FECHAS [RN-IBK-002, RN-IBK-014]
  -- ============================================================
  -- folder_date = p_process_date_ini DIRECTAMENTE, sin restar un día — el offset de 1 día
  -- (fecha de sistema → archivo de ayer) ya lo aplicó el Workflow ANTES de llamar a este SP,
  -- solo para el modo normal. En manual/reproceso la fecha que llega ya es la carpeta exacta.
  SET v_folder_date = FORMAT_DATE('%Y%m%d', p_process_date_ini);

  -- Fecha del proceso (YYYYMMDD) para el sufijo de la tabla temporal [RN-IBK-013].
  SET v_process_date_lit = FORMAT_DATE('%Y%m%d', p_process_date_ini);

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
  -- 4b. FECHA DE REFERENCIA REAL DEL ARCHIVO [RN-IBK-012]
  -- ============================================================
  -- Se calcula el MAX(consent_date) REAL del archivo y se usa como referencia — se adapta a
  -- cualquier desfase entre folder_date y el consent_date de contenido, y de paso excluye la
  -- basura histórica tipo 1900 (nunca va a ser el máximo real de un archivo con actividad
  -- genuina).
  --
  -- EXCEPCIÓN [RN-IBK-015]: si p_carga_historica = TRUE, no se calcula ni se aplica ningún
  -- filtro — v_date_filter_clause queda vacío y el archivo se carga completo. Reservado para el
  -- primer archivo de un reproceso cuando t_consent_transaction todavía no tiene ninguna fila de
  -- Interbank (el Workflow decide esto, ver wf-ibk-consentimiento.yaml).
  IF p_carga_historica THEN
    SET v_date_filter_clause = '';
  ELSE
    SET v_sql = '''SELECT SAFE_CAST(MAX(consent_date) AS DATE) FROM `''' || v_ext_table_path || '''`''';
    EXECUTE IMMEDIATE v_sql INTO v_max_consent_date;

    SET v_date_ini_lit = FORMAT_DATE('%F', v_max_consent_date);
    SET v_date_end_lit = FORMAT_DATE('%F', v_max_consent_date);

    -- String simple (no triple-comillado) — los dobles comillas internas no necesitan escape
    -- dentro de un literal delimitado por comillas simples.
    SET v_date_filter_clause = ' AND SAFE_CAST(a.consent_date AS DATE) BETWEEN DATE("' || v_date_ini_lit || '") AND DATE("' || v_date_end_lit || '")';
  END IF;

  -- ============================================================
  -- 5. RESOLUCIÓN DE id UNIFICADO ITC [RN-IBK-019 — cruce solo por party_id]
  -- ============================================================
  -- Cruce por party_id ÚNICAMENTE, SIN igualar también itc_company_id (RN-IBK-019, 2026-08-26,
  -- NO se revierte con este rollback): confirmado con datos reales de dev que una misma persona
  -- puede tener en iden_itc_party_prd un registro bajo '000' Y otro bajo '1000' (ambos códigos
  -- son Interbank) — exigir que coincidiera el itc_company_id del archivo excluía esas filas.
  -- Cada coincidencia de iden_party genera su propia fila, con el itc_company_id/id de ESE
  -- registro (no el itc_company_id del archivo).
  SET v_iden_party_path = p_project_iden_party || '.' || p_dataset_iden_party || '.' || p_table_iden_party;
  -- Prefijo de tabla hardcodeado a propósito (excepción aceptada, ver restricciones del spec,
  -- fac-data-rules-check REGLA 2/3): tabla efímera interna compartida solo entre este SP y
  -- sp_ba_customer_consent_group_ibk.sql, no varía entre ambientes. El sufijo de FECHA
  -- (v_process_date_lit, RN-IBK-013) sí es dinámico — evita que dos ejecuciones concurrentes
  -- (ej. scheduler normal + reproceso manual corriendo al mismo tiempo) se pisen la tabla.
  -- Proyecto resuelto vía ${project_iden_party} (Dataops, en deploy) y no con p_project_output:
  -- el dataset de stage (p_dataset_stage) vive físicamente bajo el proyecto de iden_party
  -- (dev-intercorp-data-operation), no bajo el proyecto de salida de t_consent_transaction.
  SET v_stage_path = '${project_iden_party}' || '.' || p_dataset_stage || '.tmp_t_consent_transaction_ibk_' || v_process_date_lit;

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
      SAFE_CAST(a.consent_date AS DATE)  AS consent_date,
      a.signed_document                  AS signed_document,
      a.source_file_name                 AS source_file_name
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
          -- _FILE_NAME es un pseudo-campo de BigQuery para external tables sobre GCS — no lo
          -- cubre "t.*", hay que seleccionarlo explícito. Solo el nombre del archivo (sin ruta),
          -- para armar record_source = LPDP_IBK_{archivo} más abajo [RN-IBK-016].
          REGEXP_EXTRACT(t._FILE_NAME, r'[^/]+$') AS source_file_name,
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
      -- más reciente por process_date) y llave nula de iden_party. Filtro por itc_company_id
      -- IN ('000','1000') AGREGADO 2026-08-27 (pedido por el usuario): el cruce sigue siendo
      -- por party_id únicamente (RN-IBK-019, no se toca), pero recién SOBRE ese match se
      -- descartan los registros de iden_party de OTRAS empresas (Interseguro, Interfondos,
      -- etc.) — antes no se filtraban y una persona con registro en otra empresa además de
      -- Interbank podía colarse en t_consent_transaction con ese otro itc_company_id.
      SELECT * EXCEPT(rn)
      FROM (
        SELECT t.*,
          ROW_NUMBER() OVER (
            PARTITION BY party_id, itc_company_id
            ORDER BY process_date DESC
          ) AS rn
        FROM `''' || v_iden_party_path || '''` t
        WHERE party_id IS NOT NULL AND itc_company_id IS NOT NULL
          AND itc_company_id IN ('000','1000')
      )
      WHERE rn = 1
    ) p
      ON  p.party_id = a.party_id
    WHERE a.itc_company_id IN ('000','1000')
      -- v_date_filter_clause ya viene armado desde el punto 4b — vacío si p_carga_historica,
      -- o " AND SAFE_CAST(...) BETWEEN DATE(...) AND DATE(...)" en caso contrario. Se concatena
      -- entero de una vez (nunca escribir comillas triples dentro de un comentario aquí adentro
      -- — cierran el string antes de tiempo, ya pasó una vez).
      ''' || v_date_filter_clause || '''
    -- ROLLBACK (2026-08-27, RN-IBK-020): sin QUALIFY — t_consent_transaction guarda el
    -- HISTORIAL COMPLETO por cliente, no solo el último evento (RN-IBK-011 revertida). Cada
    -- consent_date distinto de un mismo id queda como su propia fila; la dedup "estado vigente"
    -- vive ahora en ba_customer_consent_group_ibk.sql.
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 6. DELETE + INSERT EN LA TABLA FINAL [RN-IBK-004] [RN-IBK-021]
  -- ============================================================
  -- CORREGIDO 2026-08-27 (RN-IBK-021) — BUG REAL confirmado con datos de dev: el DELETE por
  -- (itc_company_id, consent_date) asumía que cada consent_date "pertenece" a un solo archivo,
  -- pero dos folder_dates DISTINTOS pueden calcular el mismo v_max_consent_date real (confirmado:
  -- t_consent_transaction_20260813_external y t_consent_transaction_20260814_external, ambos con
  -- MAX(consent_date) = 2026-08-13) — al procesar el segundo archivo, su DELETE borraba TODO lo
  -- que el primero acababa de insertar para esa fecha, aunque fueran archivos distintos. Pérdida
  -- de datos real.
  --
  -- FIX: el DELETE ahora es por record_source (identifica el ARCHIVO que insertó cada fila, vía
  -- source_file_name — el nombre del archivo embebe el folder_date, es determinístico por fecha
  -- de carpeta), no por consent_date. Así, reprocesar la MISMA fecha sigue siendo idempotente
  -- (reemplaza exactamente lo que ese mismo archivo insertó antes), pero un archivo NUEVO nunca
  -- toca las filas insertadas por OTRO archivo, así compartan el mismo consent_date real.
  -- Costo aceptado: si dos archivos distintos traen genuinamente al mismo cliente con el mismo
  -- consent_date, ahora pueden convivir 2 filas en vez de que el segundo reemplace al primero —
  -- preferible a perder datos silenciosamente.
  SET v_output_path = p_project_output || '.' || p_dataset_output || '.' || p_table_output;

  SET v_sql = '''
    DELETE FROM `''' || v_output_path || '''` t
    WHERE t.itc_company_id IN ('000','1000')
      AND EXISTS (
        SELECT 1 FROM `''' || v_stage_path || '''` s
        WHERE t.record_source = 'LPDP_IBK_' || s.source_file_name
      )
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- record_source = LPDP_IBK_{nombre del archivo de carga} [RN-IBK-016] — source_file_name
  -- viene de _FILE_NAME (paso 5, vía v_stage_path).
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
      'LPDP_IBK_' || source_file_name    AS record_source,
      CURRENT_DATETIME('America/Lima')   AS load_date,
      SESSION_USER()                     AS creation_user
    FROM `''' || v_stage_path || '''`
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- MONITORING: write = filas insertadas en la tabla final; read = filas resueltas en stage
  -- (fuente del INSERT anterior). Debe ir en este orden — @@row_count solo vale para la
  -- sentencia dinámica inmediatamente anterior.
  SET o_execution_data_write = @@row_count;

  SET v_sql = '''SELECT COUNT(1) FROM `''' || v_stage_path || '''`''';
  EXECUTE IMMEDIATE v_sql INTO o_execution_data_read;

  -- ============================================================
  -- 7. LIMPIEZA — tabla de stage propia
  -- ============================================================
  SET v_sql = '''DROP TABLE IF EXISTS `''' || v_stage_path || '''`''';
  EXECUTE IMMEDIATE v_sql;

END;
