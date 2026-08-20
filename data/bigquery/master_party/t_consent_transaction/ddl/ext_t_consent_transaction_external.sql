-- ⚠️ ARCHIVO DE REFERENCIA — NO se despliega vía bigquery_ddl (deploy_dev.json / deploy_prd.json)
--
-- El nombre real de esta tabla es dinámico: se crea una tabla externa NUEVA por cada fecha
-- procesada (RN-IBK-001) — t_consent_transaction_{fecha_archivo}_external — por lo que no puede
-- desplegarse como un archivo DDL estático con nombre fijo (el framework Dataops solo ejecuta
-- DDLs con nombre de tabla resuelto en tiempo de deploy, no en tiempo de ejecución del SP).
--
-- Este DDL se ejecuta dinámicamente vía EXECUTE IMMEDIATE dentro de
-- sp_t_consent_transaction_ibk.sql (etapa CODING), sustituyendo:
--   {fecha_archivo}  → folder_date calculado (YYYYMMDD) según RN-IBK-002
--   {UUID} en la ruta GCS → wildcard '*' de BigQuery (no un placeholder literal)
--
-- Contrato original: input/ddl_table_external.txt
-- Reproceso histórico: pueden coexistir varias de estas tablas simultáneamente, una por cada
-- fecha_archivo del rango — limpiar por TTL (2 días) o DROP explícito al final del Workflow.

CREATE OR REPLACE EXTERNAL TABLE `${project_consentimiento_ibk_archivo}.${dataset_consentimiento_ibk_archivo}.t_consent_transaction_{fecha_archivo}_external`
(
  process_date STRING,
  itc_company_id STRING,
  itc_company_name STRING,
  business_unit_id STRING,
  business_unit STRING,
  consent_transaction_id STRING,
  party_id STRING,
  consent_id STRING,
  documento_legal_id STRING,
  approval_channel_id STRING,
  approval_channel_name STRING,
  employee_id STRING,
  place_id STRING,
  consent_type STRING,
  consent_date STRING,
  consent_date_time STRING,
  signed_document STRING,
  record_source STRING,
  load_date STRING,
  creation_user STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://${gcs_bucket_consentimiento_ibk_archivo}/data/m_consent/current/{fecha_archivo}/*/T_IN_LPDP_CONSENTIMIENTO_{fecha_archivo}.txt.gz'],
  field_delimiter = '|',
  skip_leading_rows = 0,
  allow_quoted_newlines = true
);
