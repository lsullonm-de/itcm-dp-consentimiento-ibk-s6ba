-- Tabla destino: centraliza cada evento de consentimiento/rechazo LPDP de clientes Interbank (IBK)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk
-- Generado por: fac-data-stage-physical-design
-- Contrato original: input/ddl_output_t_consent_transaction.txt

CREATE TABLE IF NOT EXISTS `${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}`
(
  process_date DATE OPTIONS(description="Fecha de foto/datos configurada en el ETL para la extracción de datos"),
  itc_company_id STRING OPTIONS(description="Código identificador de la compañía que genera el registro único del cliente"),
  itc_company_name STRING OPTIONS(description="Nombre de la empresa que genera el registro único de cliente"),
  business_unit_id STRING OPTIONS(description="Código identificador de la Unidad de negocio"),
  business_unit STRING OPTIONS(description="Descripción de la Unidad de negocio"),
  conset_transaction_id STRING OPTIONS(description="Código identificador del evento por el cual el cliente da el consentimiento o rechazo del tratamiento de sus datos (origen: consent_transaction_id del archivo)"),
  customer_id STRING OPTIONS(description="Código identificador del cliente en el sistema origen IBK (origen: party_id del archivo)"),
  id STRING OPTIONS(description="Identificador unificado ITC de la persona, resuelto vía JOIN por party_id contra iden_itc_party_prd filtrando itc_company_id IN ('000','1000') — RN-IBK-003"),
  conset_id STRING OPTIONS(description="Código identificador del consentimiento que da el cliente a la empresa (origen: consent_id del archivo). 'CP_2' = consentimiento LPDP consumido por ba_customer_consent_group"),
  documento_legal_id STRING OPTIONS(description="Código identificador del documento legal que contiene la información que el cliente firma"),
  approval_channel_id STRING OPTIONS(description="Código identificador del canal por el cual se contactó al cliente y dio su aprobación o rechazo"),
  employee_id STRING OPTIONS(description="Código identificador del empleado en el sistema origen"),
  place_id STRING OPTIONS(description="Código identificador del lugar donde se realiza la venta, físico o canal online"),
  consent_type STRING OPTIONS(description="Indica la aprobación ('otorgado') o rechazo del tratamiento de datos"),
  consent_date DATE OPTIONS(description="Fecha en la que el cliente responde — valor real contenido en el archivo, NO se calcula por offset fijo respecto al folder_date (RN-IBK-004). Campo de partición y llave de DELETE+INSERT junto con itc_company_id"),
  signed_document STRING OPTIONS(description="Ruta donde se almacena el documento firmado por el cliente"),
  record_source STRING OPTIONS(description="Dato de auditoría: aplicativo origen de los datos"),
  -- DATETIME, no TIMESTAMP como indicaba el contrato original (input/ddl_output_t_consent_transaction.txt):
  -- la tabla real en dev-intercorp-data-storage.master_party ya existía con load_date DATETIME antes de
  -- este deploy (CREATE TABLE IF NOT EXISTS no la recreó) — confirmado por el error de tipo en el INSERT
  -- de sp_t_consent_transaction_ibk.sql (2026-08-21). Se documenta aquí lo real, no lo contratado.
  load_date DATETIME OPTIONS(description="Fecha y hora de inserción del registro en el modelo"),
  creation_user STRING OPTIONS(description="Usuario/SA del proceso de carga que crea el registro en la BD")
)
PARTITION BY consent_date
CLUSTER BY itc_company_name
OPTIONS(
  description="Centraliza cada evento de consentimiento/rechazo de tratamiento de datos personales (LPDP) de clientes Interbank (IBK). Carga DELETE+INSERT por itc_company_id + consent_date (RN-IBK-005).",
  labels=[("team","data-platform"),("env","${env}")]
);
