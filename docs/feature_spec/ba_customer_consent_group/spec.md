# Centralización de Consentimientos LPDP Interbank (IBK) — ba_customer_consent_group

> **SPEC:** spec-ibk-20260819-001 · **Status:** draft
> **Tipo:** etl · **Capa:** business · **Partición:** consent_date

---

## Descripción

Consentimientos CP_2 otorgados vigentes por cliente IBK, derivados exclusivamente de
`t_consent_transaction` (no vuelve a leer el archivo ni la tabla externa).

## Objetivo de Negocio

_(pendiente — completar contexto.objetivo_negocio en el spec)_

---

## Fuentes de Entrada

| ID | Proyecto | Dataset | Tabla | PII |
|----|---------|---------|-------|-----|
| t_consent_transaction (output previo del mismo spec) | `dev-intercorp-data-storage` | `master_party` | `t_consent_transaction` | ⚠️ true |

**Filtro de entrada:** `conset_id = 'CP_2'` AND `consent_type = 'otorgado'` AND `itc_company_id IN ('000','1000')`

---

## Output

**Tabla:** `dev-intercorp-data-storage.master_party.ba_customer_consent_group`
**Tipo de carga:** `incremental` (delete+insert por `itc_company_id` + `consent_date`)
**Partición:** `consent_date`

### Campos

> Completar en etapa DESIGN. Los campos de auditoría son obligatorios.

| Campo | Tipo BQ | Descripción | Fuente | Regla | PII |
|-------|---------|-------------|--------|-------|-----|
| process_date | DATE | Fecha de foto del ETL | t_consent_transaction | — | No |
| itc_company_id / itc_company_name | STRING | Código/nombre de la empresa | t_consent_transaction | Filtro RN-IBK-006 | No |
| business_unit_id / business_unit | STRING | Unidad de negocio | t_consent_transaction | — | No |
| id | STRING | Identificador unificado ITC | t_consent_transaction.id | — | Sí (identificador) |
| documento_legal_id | STRING | ID del documento legal firmado | t_consent_transaction | — | Sí |
| approval_channel_id | STRING | Canal de aprobación | t_consent_transaction | — | No |
| approval_channel_name | STRING | Nombre del canal de aprobación | **Siempre NULL** — no existe origen en t_consent_transaction, confirmado por el equipo (2026-08-19) | — | No |
| employee_id | STRING | ID del empleado | t_consent_transaction | — | Sí |
| place_id | STRING | ID del lugar de venta/canal | t_consent_transaction | — | No |
| consent_date | DATE | Fecha de respuesta del cliente (partición) | t_consent_transaction | — | No |
| signed_document | STRING | Ruta del documento firmado | t_consent_transaction | — | Sí |
| `load_date` | `DATETIME` | Fecha de carga del proceso | Framework | Auditoría | No |
| `record_source` | `STRING` | Origen del registro | Framework | Auditoría | No |
| `creation_user` | `STRING` | SA que ejecutó la carga | Framework | Auditoría | No |

---

## Reglas de Negocio

| ID | Descripción | Criticidad | Capa |
|----|-------------|-----------|------|
| RN-IBK-006 | Se genera exclusivamente desde t_consent_transaction, filtrando conset_id='CP_2', consent_type='otorgado', itc_company_id IN ('000','1000') | alta | — |
| RN-IBK-007 | Carga DELETE + INSERT por itc_company_id + consent_date | alta | — |
| RN-IBK-008 | Pipeline implementado como SPs orquestados en un Workflow | media | — |
| RN-IBK-009 | Workflow soporta modos normal / manual / reproceso | media | — |

> RN-IBK-008/009 se bajaron a `media`: son reglas de arquitectura/orquestación compartidas con
> `t_consent_transaction`, no verificables con una regla DQ sobre datos.

---

## Reglas de Calidad de Datos

| ID | Dimensión | Descripción | Crítica | Umbral máx. inválidos |
|----|----------|-------------|---------|----------------------|
| DQ-IBK-BA_CUSTOMER_CONSENT_GROUP-001 | validez | `itc_company_id` debe estar en ('000','1000') — cubre RN-IBK-006 (proxy: conset_id/consent_type no se persisten en este output) | true | 0% |
| DQ-IBK-BA_CUSTOMER_CONSENT_GROUP-002 | unicidad | Sin duplicados de `id` por `itc_company_id + consent_date` — cubre RN-IBK-007 | true | 0% |

---

## Flujo de Transformación

```
dev-intercorp-data-storage.master_party.t_consent_transaction
    → FILTER conset_id='CP_2' AND consent_type='otorgado' AND itc_company_id IN ('000','1000')
    → SP `sp_ba_customer_consent_group_ibk`
    → DELETE + INSERT `dev-intercorp-data-storage.master_party.ba_customer_consent_group`
      (llave: itc_company_id + consent_date)
```

> Componentes: ddl, sp — reutiliza el mismo workflow y cloud_scheduler de t_consent_transaction
> Scheduling: por definir · America/Lima

---

> 📄 Generado por `fac-data-spec-create` desde `spec-ibk-20260819-001`.
> Completar sección **Campos** (origen definitivo de `approval_channel_name`) y
> **Reglas de Calidad de Datos** en etapa DESIGN.
> Actualizar con `/spec-update` si cambia el diseño.
