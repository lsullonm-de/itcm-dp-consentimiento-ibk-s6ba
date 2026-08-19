# Centralización de Consentimientos LPDP Interbank (IBK) — t_consent_transaction

> **SPEC:** spec-ibk-20260819-001 · **Status:** draft
> **Tipo:** etl · **Capa:** master · **Partición:** consent_date

---

## Descripción

Centraliza diariamente los eventos de consentimiento/rechazo de tratamiento de datos
personales (LPDP) de clientes Interbank: lee el archivo GCS vía tabla externa temporal,
resuelve el identificador unificado ITC contra iden_itc_party y carga t_consent_transaction
(delete+insert por itc_company_id + consent_date). Deriva de allí ba_customer_consent_group
con los consentimientos CP_2 otorgados vigentes.

## Objetivo de Negocio

_(pendiente — completar contexto.objetivo_negocio en el spec)_

---

## Fuentes de Entrada

| ID | Proyecto | Dataset | Tabla | PII |
|----|---------|---------|-------|-----|
| consentimiento_ibk_archivo | `dev-intercorp-data-storage` | `raw_ibk_dlk` | `t_consent_transaction_{fecha_archivo}_external` | ⚠️ true |
| iden_party | `dev-intercorp-data-operation` | `matillion_dev` | `iden_itc_party_prd` | ⚠️ true |

> ⚠️ Ambas fuentes contienen PII (documento_legal_id, signed_document, employee_id / identidad
> de persona). La tabla externa se crea NUEVA por cada fecha procesada (no una tabla estática
> reemplazada) — en un reproceso histórico coexisten varias simultáneamente; limpiar por TTL
> (2 días) o DROP explícito para no acumular objetos huérfanos en `raw_ibk_dlk` (RN-IBK-001).

---

## Output

**Tabla:** `dev-intercorp-data-storage.master_party.t_consent_transaction`
**Tipo de carga:** `incremental` (delete+insert por `itc_company_id` + `consent_date`)
**Partición:** `consent_date`

### Campos

> Completar en etapa DESIGN. Los campos de auditoría son obligatorios.

| Campo | Tipo BQ | Descripción | Fuente | Regla | PII |
|-------|---------|-------------|--------|-------|-----|
| process_date | DATE | Fecha de foto del ETL | Archivo IBK | — | No |
| itc_company_id / itc_company_name | STRING | Código/nombre de la empresa | Archivo IBK | Filtro RN-IBK-003/006 | No |
| business_unit_id / business_unit | STRING | Unidad de negocio | Archivo IBK | — | No |
| conset_transaction_id | STRING | ID del evento de consentimiento | Archivo IBK (`consent_transaction_id`) | — | No |
| customer_id | STRING | ID del cliente en sistema origen IBK | Archivo IBK (`party_id`) | — | No |
| id | STRING | Identificador unificado ITC | `iden_party` (JOIN por party_id) | RN-IBK-003 | Sí (identificador) |
| conset_id | STRING | Código de consentimiento | Archivo IBK (`consent_id`) | — | No |
| documento_legal_id | STRING | ID del documento legal firmado | Archivo IBK | — | Sí |
| approval_channel_id | STRING | Canal de aprobación | Archivo IBK | — | No |
| employee_id | STRING | ID del empleado | Archivo IBK | — | Sí |
| place_id | STRING | ID del lugar de venta/canal | Archivo IBK | — | No |
| consent_type | STRING | Aprobación/rechazo | Archivo IBK | — | No |
| consent_date | DATE | Fecha de respuesta del cliente (partición) | Archivo IBK | RN-IBK-004 — se usa el valor real, no offset calculado | No |
| signed_document | STRING | Ruta del documento firmado | Archivo IBK | — | Sí |
| `load_date` | `TIMESTAMP` | Fecha de carga del proceso | Framework | Auditoría | No |
| `record_source` | `STRING` | Origen del registro | Framework | Auditoría | No |
| `creation_user` | `STRING` | SA que ejecutó la carga | Framework | Auditoría | No |

> Campos del archivo **sin destino definido** en esta tabla: `approval_channel_name`,
> `consent_date_time` — ver restricciones del spec.

---

## Reglas de Negocio

| ID | Descripción | Criticidad | Capa |
|----|-------------|-----------|------|
| RN-IBK-001 | Tabla externa NUEVA por fecha (t_consent_transaction_{fecha_archivo}_external), vigencia máxima 2 días — varias coexisten en reproceso histórico | media | — |
| RN-IBK-002 | folder_date = process_date - 1 día (a confirmar) | media | — |
| RN-IBK-003 | Cruce por party_id contra iden_itc_party_prd (itc_company_id IN ('000','1000')) para obtener `id` | alta | — |
| RN-IBK-004 | consent_date usado en delete/insert es el valor real del archivo, no calculado | alta | — |
| RN-IBK-005 | Carga DELETE + INSERT por itc_company_id + consent_date | alta | — |
| RN-IBK-008 | Pipeline implementado como SPs orquestados en un Workflow | media | — |
| RN-IBK-009 | Workflow soporta modos normal / manual / reproceso | media | — |

> RN-IBK-001/002/008/009 se bajaron a `media`: son reglas de arquitectura/orquestación, no
> verificables con una regla DQ sobre datos. Las de `alta` (003/004/005) sí tienen regla DQ asociada.

---

## Reglas de Calidad de Datos

| ID | Dimensión | Descripción | Crítica | Umbral máx. inválidos |
|----|----------|-------------|---------|----------------------|
| DQ-IBK-T_CONSENT_TRANSACTION-001 | completitud | `id` no debe ser nulo (registros sin match en iden_itc_party_prd) — cubre RN-IBK-003 | true | 0% |
| DQ-IBK-T_CONSENT_TRANSACTION-002 | completitud | `consent_date` no debe ser nulo — cubre RN-IBK-004 | true | 0% |
| DQ-IBK-T_CONSENT_TRANSACTION-003 | unicidad | Sin duplicados de `conset_transaction_id` por `itc_company_id + consent_date` — cubre RN-IBK-005 | true | 0% |

---

## Flujo de Transformación

```
consentimiento_ibk_archivo (tabla externa t_consent_transaction_{fecha_archivo}_external, TTL 2 días)
    → JOIN iden_party por party_id (filtro itc_company_id IN ('000','1000'))
    → SP `sp_t_consent_transaction_ibk`
    → DELETE + INSERT `dev-intercorp-data-storage.master_party.t_consent_transaction`
      (llave: itc_company_id + consent_date)
```

> Componentes: ddl (tabla externa), ddl (t_consent_transaction), sp, workflow, cloud_scheduler
> Scheduling: por definir · America/Lima

---

> 📄 Generado por `fac-data-spec-create` desde `spec-ibk-20260819-001`.
> Completar sección **Campos** (tipos definitivos, origen de `approval_channel_name`) y
> **Reglas de Negocio** en etapa DESIGN.
> Actualizar con `/spec-update` si cambia el diseño.
