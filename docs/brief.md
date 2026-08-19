# Brief Técnico — Centralización de Consentimientos LPDP Interbank (IBK)

**SPEC:** spec-ibk-20260819-001  |  **Tipo:** etl  |  **Fecha:** 2026-08-19  |  **Autor:** lsullon

## Qué se construye

Centraliza diariamente los eventos de consentimiento/rechazo de tratamiento de datos
personales (LPDP) de clientes Interbank: lee el archivo GCS vía tabla externa temporal,
resuelve el identificador unificado ITC contra iden_itc_party y carga t_consent_transaction
(delete+insert por itc_company_id + consent_date). Deriva de allí ba_customer_consent_group
con los consentimientos CP_2 otorgados vigentes.

## Por qué

Registra cuando un individuo otorgando o revoca un consentimiento para un propósito específico.

> ⚠️ Este objetivo de negocio quedó pendiente de precisar en el spec — repite la descripción
> técnica de la tabla en vez del impacto de negocio (cumplimiento LPDP, auditoría, etc.).

## Etapas aplicables

plan, design, coding, orchestration, dataops, compliance, infraops, security, documentation

> No activas: integridad, data_quality, testing (ver restricciones — `data_quality` tiene
> reglas ya definidas en el spec pero la etapa sigue en `false`).

## Componentes GCP

- ddl: tabla externa temporal `ext_t_consent_transaction_external.sql` (nombre real: `t_consent_transaction_{fecha_archivo}_external`, una por fecha)
- ddl: tabla destino `t_consent_transaction.sql`
- sp: `sp_t_consent_transaction_ibk.sql`
- ddl: tabla destino `ba_customer_consent_group.sql`
- sp: `sp_ba_customer_consent_group_ibk.sql`
- workflow: `wf-ibk-consentimiento.yaml`
- cloud_scheduler: `cs-ibk-consentimiento.yaml`

## Fuentes → Output

`consentimiento_ibk_archivo` (tabla externa GCS), `iden_party` (`iden_itc_party_prd`)
→ `t_consent_transaction` (master) → `ba_customer_consent_group` (business)

## KPIs de éxito

_(pendiente — `contexto.kpis` vacío en el spec)_

## Restricciones

- Offset folder_date = process_date - 1 día asumido de un único ejemplo de negocio — confirmar con Interbank (RN-IBK-002)
- consent_date de contenido no tiene offset fijo (~2 días, variable) — se lee del archivo, no se calcula (RN-IBK-004)
- approval_channel_name requerido en ba_customer_consent_group pero no existe en t_consent_transaction — definir origen antes de CODING
- consent_date_time del archivo no tiene destino definido en ninguna tabla — confirmar si se descarta
- Dataset de la tabla externa en el DDL de referencia es personal (lsullon) — reubicar a dataset compartido antes de productivo
- Motor de orquestación del Workflow (Cloud Workflows / Composer) no especificado — definir en DESIGN
- Política ante archivo ausente en el folder_date esperado no definida — no debe ejecutarse DELETE sin INSERT de reemplazo
