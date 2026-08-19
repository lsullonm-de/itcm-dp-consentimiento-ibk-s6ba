# Catálogo de Datos — `c_itc_company`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_party`
**Tabla completa:** `intercorp-data-storage-pv.master_party.c_itc_company`

---

## Descripción

Catálogo de **todas las empresas del Grupo Intercorp**. Es la tabla de referencia para decodificar el campo `itc_company_id` presente en prácticamente todas las tablas del modelo corporativo.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado | NO |
| Total de filas | 83 |
| Fuente | CSV `c_itc_company` — SITC |

---

## Empresas Principales — Referencia Rápida

Esta tabla es el puente entre el nombre comercial que usa el negocio y los campos técnicos usados en BigQuery.

| `itc_company_id` | Nombre técnico en BD | Nombre comercial conocido | Prefijo en `ba_*` | Abrev. |
|---|---|---|---|---|
| `010` | SUPERMERCADOS PERUANOS | **PLAZA VEA**, Vivanda, Mass, Makro Eco | `spsa_` | `spsa` |
| `011` | TIENDAS PERUANAS | **OECHSLE** | `oe_` | `oe` |
| `024` | PROMART | Promart Homecenter | `pro_` *(también `pmart` en algunas tablas, preferir `pro_`)* | `pmart` |
| `025` | INKAFARMA | InkaFarma | `far_` *(consolidado con MiFarma)* | `inkf` |
| `048` | MIFARMA | MiFarma | `far_` *(consolidado con InkaFarma)* | `mfarm` |
| `013` | CINEPLANET | Cineplanet | — | `cpla` |
| `033` | REAL PLAZA | Real Plaza | — | `rpla` |
| `086` | IZIPAY S.A.C | Izipay (POS/pagos) | — | `izpay` |
| `000` | INTERBANK | Interbank | — | `ibk` |
| `020` | BEMBOS | Bembos | — | `bemb` |
| `016` | CASA IDEAS | Casa Ideas | — | `cideas` |
| `060` | LA CURACAO | La Curacao | — | `lacu` |
| `040` | FINANCIERA UNO | Financiera Uno | — | `fin1` |
| `074` | FARMACIAS PERUANAS | Farmacias Peruanas | — | — |
| `055` | INTERCORP RETAIL | Intercorp Retail | — | — |
| `777` | (DIRECTORES) | Directores del grupo | — | — |

---

## Equivalencias Nombre Comercial ↔ Nombre Técnico

Esta sección es crítica para el agente analítico — el usuario siempre usa el nombre comercial,
no el técnico registrado en la BD.

| El usuario dice... | Corresponde a... | `itc_company_id` | Prefijo `ba_*` |
|---|---|---|---|
| "Plaza Vea", "Vea", "SPSA", "Mass", "Vivanda", "Makro" | SUPERMERCADOS PERUANOS | `010` | `spsa_` |
| "Oechsle", "Tiendas Peruanas" | TIENDAS PERUANAS | `011` | `oe_` |
| "Promart", "Promart Homecenter" | PROMART | `024` | `pro_` |
| "InkaFarma", "Inka", "farmacias" (puede incluir ambas) | INKAFARMA | `025` | `far_` |
| "MiFarma", "Mi Farma" | MIFARMA | `048` | `far_` |
| "farmacias" (sin especificar) | INKAFARMA + MIFARMA | `025` + `048` | `far_` (consolidado) |
| "Cineplanet", "cine" | CINEPLANET | `013` (usar este, no `009`) | — |
| "Real Plaza", "mall" | REAL PLAZA | `033` (usar este, no `015`) | — |
| "Izipay", "POS", "datáfono" | IZIPAY S.A.C | `086` | — |
| "Interbank", "IBK" | INTERBANK | `000` | — |
| "Bembos" | BEMBOS | `020` | — |

---

## Nota sobre prefijos en tablas `ba_*`

Las tablas `ba_itc_attr_*` **NO tienen campo `itc_company_id`**. Las empresas están
codificadas como prefijos en los nombres de columna:

| Empresa | Prefijo en `ba_itc_attr_retail` | Nota |
|---|---|---|
| Supermercados Peruanos (010) | `spsa_` | Incluye Plaza Vea, Vivanda, Mass, Makro Eco |
| Tiendas Peruanas / Oechsle (011) | `oe_` | — |
| Promart (024) | `pro_` | También aparece como `pmart` en algunas abreviaturas legacy, pero el prefijo de columna es `pro_` |
| InkaFarma (025) + MiFarma (048) | `far_` | Ambas cadenas consolidadas bajo un solo prefijo |

---

## Glosario de Campos

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_company_id` | STRING | **Clave primaria**. Código de 3 dígitos de la empresa. Siempre usar como STRING (`'010'`, no `10`) |
| `itc_company_name` | STRING | Nombre técnico de la empresa en la BD (ej: `"SUPERMERCADOS PERUANOS"`) |
| `itc_company_abrev` | STRING | Abreviatura técnica (ej: `spsa`, `oe`, `pmart`, `inkf`, `mfarm`) |
| `itc_business_name` | STRING | Razón social completa |
| `itc_business_short_name` | STRING | Nombre corto del negocio |
| `itc_business_platform` | STRING | Sector: `FINANCIERO`, `RETAIL`, `ENTRETENIMIENTO` |
| `flag_foreign` | BOOLEAN | `false` en todos los casos observados |
| `record_source` | STRING | Origen del dato |
| `load_date` | DATE | Fecha de carga |
| `creation_user` | STRING | Usuario que creó el registro |

---

## Reglas de negocio

1. **`itc_company_id` es STRING** — siempre filtrar con comillas: `WHERE itc_company_id = '010'`

2. **SUPERMERCADOS PERUANOS (`010`) = Plaza Vea + Vivanda + Mass + Makro Eco** — todos los banners bajo el mismo código y prefijo `spsa_`.

3. **TIENDAS PERUANAS (`011`) = Oechsle** — el nombre técnico en BD es "Tiendas Peruanas" pero comercialmente es Oechsle. Prefijo `oe_`.

4. **PROMART (`024`)** — abreviatura técnica `pmart` en la BD, pero el prefijo de columna en `ba_*` es `pro_`. Usar `pro_` para queries.

5. **Farmacias consolidadas**: InkaFarma (`025`) y MiFarma (`048`) comparten el prefijo `far_` en tablas `ba_*`. Para separarlas hay que ir a `t_retail_transaction` filtrando por `itc_company_id`.

6. **CINEPLANET tiene dos IDs** (`009` y `013`). Usar `013` como el vigente principal. En `t_experience_transaction` verificar cuál aparece.

7. **REAL PLAZA tiene dos IDs** (`015` y `033`). Usar `033` como el vigente principal.

8. **`itc_company_id = '777'`**: Código especial para directores. No corresponde a empresa.

---

## Query de referencia

```sql
-- Decodificar company_id en t_retail_transaction
SELECT t.itc_company_id, c.itc_company_name, c.itc_company_abrev,
       COUNT(DISTINCT t.ticket_id) AS transacciones,
       SUM(t.product_item_gross_amount) AS monto_total
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
JOIN `intercorp-data-storage-pv.master_party.c_itc_company` c
  ON t.itc_company_id = c.itc_company_id
WHERE t.transaction_date = '2026-01-01'
GROUP BY 1, 2, 3
ORDER BY monto_total DESC;
```

---

*Actualizado: 2026-06-06 | Fuente: BigQuery `intercorp-data-storage-pv.master_party.c_itc_company`*
