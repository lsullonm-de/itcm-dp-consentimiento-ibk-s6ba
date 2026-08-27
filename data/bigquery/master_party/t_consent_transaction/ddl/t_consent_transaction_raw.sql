-- Tabla raw: guarda TODOS los eventos de CADA archivo IBK procesado, tal como vienen del
-- archivo (sin cruzar con iden_party, sin colapsar a 1 fila por cliente) — trazabilidad completa
-- por archivo (CAMBIO DE DISEÑO 2026-08-26, confirmado con el usuario, RN-IBK-019).
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk
-- Generado por: fac-data-stage-physical-design
--
-- Un mismo folder_date puede reprocesarse (mismo archivo corrido de nuevo) — sp_t_consent_transaction_ibk.sql
-- hace DELETE+INSERT por folder_date para que un reproceso de la MISMA fecha reemplace su propio
-- lote en vez de acumular copias. Fechas DISTINTAS sí se acumulan todas — esta tabla nunca se
-- trunca por completo.
--
-- Solo el archivo de la ÚLTIMA fecha de cada corrida se centraliza hacia t_consent_transaction
-- (ver sp_centralizar_t_consent_transaction_ibk.sql) — el resto de fechas de un reproceso
-- quedan únicamente aquí, con fines de trazabilidad/auditoría.

CREATE TABLE IF NOT EXISTS `${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction_raw}`
(
  folder_date DATE OPTIONS(description="Fecha de la carpeta GCS procesada (p_process_date_ini) — NO el consent_date real del contenido. Llave del DELETE+INSERT por archivo"),
  process_date DATE OPTIONS(description="Fecha de foto/datos configurada en el ETL para la extracción de datos — origen: process_date del archivo"),
  itc_company_id STRING OPTIONS(description="Código identificador de la compañía, tal como viene en el archivo (origen: itc_company_id)"),
  itc_company_name STRING OPTIONS(description="Nombre de la empresa, tal como viene en el archivo"),
  business_unit_id STRING OPTIONS(description="Código identificador de la Unidad de negocio"),
  business_unit STRING OPTIONS(description="Descripción de la Unidad de negocio"),
  consent_transaction_id STRING OPTIONS(description="Origen: consent_transaction_id del archivo. Confirmado con Interbank (2026-08-21) que viene SIEMPRE vacío en el archivo real"),
  party_id STRING OPTIONS(description="Código identificador del cliente en el sistema origen IBK — SIN cruzar todavía contra iden_itc_party_prd (el cruce se hace al centralizar, no aquí)"),
  consent_id STRING OPTIONS(description="Código identificador del consentimiento que da el cliente a la empresa (origen: consent_id del archivo)"),
  documento_legal_id STRING OPTIONS(description="Código identificador del documento legal que contiene la información que el cliente firma"),
  approval_channel_id STRING OPTIONS(description="Código identificador del canal por el cual se contactó al cliente y dio su aprobación o rechazo"),
  employee_id STRING OPTIONS(description="Código identificador del empleado en el sistema origen"),
  place_id STRING OPTIONS(description="Código identificador del lugar donde se realiza la venta, físico o canal online"),
  consent_type STRING OPTIONS(description="Indica la aprobación ('otorgado') o rechazo del tratamiento de datos"),
  consent_date DATE OPTIONS(description="Fecha en la que el cliente responde — valor real contenido en el archivo, tal cual, sin filtrar"),
  consent_date_time STRING OPTIONS(description="Timestamp de contenido del archivo — llave de dedup de eventos duplicados junto con party_id (RI-IBK-T_CONSENT_TRANSACTION-002/003)"),
  signed_document STRING OPTIONS(description="Ruta donde se almacena el documento firmado por el cliente"),
  source_file_name STRING OPTIONS(description="Nombre del archivo de origen (vía _FILE_NAME de la tabla externa), sin la ruta — trazabilidad por archivo"),
  record_source STRING OPTIONS(description="'LPDP_IBK_' || source_file_name — dato de auditoría: aplicativo y archivo origen de los datos"),
  load_date DATETIME OPTIONS(description="Fecha y hora de inserción del registro en el modelo"),
  creation_user STRING OPTIONS(description="Usuario/SA del proceso de carga que crea el registro en la BD")
)
PARTITION BY folder_date
CLUSTER BY itc_company_id
OPTIONS(
  description="Guarda TODOS los eventos de cada archivo IBK procesado, sin cruzar con iden_party ni colapsar por cliente — trazabilidad completa por archivo (RN-IBK-019). Solo el archivo de la última fecha de cada corrida se centraliza hacia t_consent_transaction.",
  labels=[("team","data-platform"),("env","${env}")]
);
