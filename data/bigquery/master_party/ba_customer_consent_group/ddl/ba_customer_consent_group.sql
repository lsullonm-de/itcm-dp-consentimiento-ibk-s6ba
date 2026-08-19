-- Tabla destino: consentimientos CP_2 otorgados vigentes por cliente Interbank (IBK)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk
-- Generado por: fac-data-stage-physical-design
-- Contrato original: input/ddl_output_ba_customer_consent_group.txt
--
-- DECISIÓN DE DISEÑO (confirmada por el equipo, 2026-08-19): el contrato original usaba
-- CREATE OR REPLACE TABLE, lo cual borraría todo el histórico acumulado en cada redeploy
-- (esta tabla se carga incrementalmente por itc_company_id + consent_date, no por reemplazo
-- total). Se cambia a CREATE TABLE IF NOT EXISTS siguiendo el estándar del framework
-- (bigquery-pipeline-developer/SKILL.md §4).

CREATE TABLE IF NOT EXISTS `${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.${table_ba_customer_consent_group}`
(
  process_date DATE OPTIONS(description="Fecha de foto/datos configurada en el ETL"),
  itc_company_id STRING OPTIONS(description="Código identificador de la compañía — filtrado a ('000','1000'), ambos códigos de Interbank (RN-IBK-006)"),
  itc_company_name STRING OPTIONS(description="Nombre de la empresa"),
  business_unit_id STRING OPTIONS(description="Código identificador de la Unidad de negocio"),
  business_unit STRING OPTIONS(description="Descripción de la Unidad de negocio"),
  id STRING OPTIONS(description="Identificador unificado ITC de la persona, heredado de t_consent_transaction.id"),
  documento_legal_id STRING OPTIONS(description="Código identificador del documento legal firmado"),
  approval_channel_id STRING OPTIONS(description="Código identificador del canal de aprobación"),
  approval_channel_name STRING OPTIONS(description="Nombre del canal de aprobación — SIEMPRE NULL: no existe origen en t_consent_transaction, confirmado por el equipo (2026-08-19). Campo conservado por compatibilidad con el contrato original"),
  employee_id STRING OPTIONS(description="Código identificador del empleado"),
  place_id STRING OPTIONS(description="Código identificador del lugar de venta o canal"),
  consent_date DATE OPTIONS(description="Fecha del consentimiento, heredada de t_consent_transaction.consent_date. Campo de partición y llave de DELETE+INSERT junto con itc_company_id"),
  signed_document STRING OPTIONS(description="Ruta del documento firmado por el cliente"),
  record_source STRING OPTIONS(description="Dato de auditoría: aplicativo origen de los datos"),
  load_date DATETIME OPTIONS(description="Fecha y hora de inserción del registro"),
  creation_user STRING OPTIONS(description="Usuario/SA del proceso de carga que crea el registro")
)
PARTITION BY consent_date
OPTIONS(
  description="Consentimientos CP_2 otorgados vigentes por cliente Interbank (IBK) — conset_id='CP_2' AND consent_type='otorgado' — derivado exclusivamente de t_consent_transaction. Carga DELETE+INSERT por itc_company_id + consent_date (RN-IBK-007).",
  labels=[("team","data-platform"),("env","${env}")]
);
