# Catálogo de Datos — `t_experience_transaction`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_transaction`
**Tabla completa:** `intercorp-data-storage-pv.master_transaction.t_experience_transaction`

---

## Descripción

Tabla de **transacciones de experiencia y entretenimiento**. Registra ventas, anulaciones e ítems de transacción de empresas de experiencias del Grupo Intercorp. Actualmente cubre dos empresas:

- **CINEPLANET (013)**: Entradas de cine (boletería) y confitería (dulcería). Ticket promedio S/. 400–1,100. Clientes mayoritariamente identificados.
- **NGRESTAURANT (033)**: Restaurantes de comida rápida (Bembos, Don Belisario, Dunkin, Papa Johns, China Wok, Popeyes, etc.) — empresas del grupo Delosi/NGR. Ticket muy bajo (~S/. 5). Prácticamente anónimas (99.9% sin identificación de cliente).

La estructura de campos es homologada con `t_retail_transaction` (mismo modelo corporativo) pero adaptada para el dominio de experiencias: usa `product_item_sku` como código de ítem de menú o entrada, y `business_unit` para distinguir entre BOLETERÍA y DULCERÍA en Cineplanet, o por local/marca en restaurantes.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `transaction_date` (DAY) |
| Clusterizado por | `process_date`, `itc_company_id`, `business_unit` |
| Total de filas | ~577,278,773 (~577M) |
| Número de columnas | 53 |
| Tamaño lógico | ~255 GB |
| Tamaño físico | ~13 GB (alta compresión) |
| Particiones | 1,728 |
| Última fecha disponible | 2026-03-09 |
| Primera fecha disponible | 2025-01-01 (en BQ activo) |
| Frecuencia | Diaria |
| Fuente | `master_transaction` |
| Ubicación | US |

---

## Volumen por empresa y mes (muestra: 3 días/mes, Feb 2025–Ene 2026)

| Mes | Empresa | Registros (~3 días) | Clientes únicos | Precio unitario promedio (S/.) |
|---|---|---|---|---|
| 2026-01 | 013 CINEPLANET | 268,050 | 65,525 | 631.38 |
| 2026-01 | 033 NGRESTAURANT | 1,899,263 | 262 | 4.95 |
| 2025-12 | 013 CINEPLANET | 357,047 | 72,127 | 470.47 |
| 2025-12 | 033 NGRESTAURANT | 1,902,169 | 1,796 | 5.02 |
| 2025-06 | 013 CINEPLANET | 190,921 | 39,846 | **1,102.38** (pico) |
| 2025-05 | 013 CINEPLANET | 422,197 | 90,871 | 1,029.25 |

> **Snapshot de un día (2026-01-30):** 698,537 filas · 16,253 clientes únicos identificados (5.4% del total)
> - 013 CINEPLANET: 58,558 filas · 55 ubicaciones · 1,863 productos · avg S/. 623.80
> - 033 NGRESTAURANT: 639,979 filas · 200 ubicaciones · 5,257 productos · avg S/. 4.71

**Enero 2026 completo:**
- NGRESTAURANT (033): 17.5M filas, 2,029 clientes identificados, S/. 84M total
- CINEPLANET (013): 2.3M filas, 395K clientes identificados, S/. 1,352M total

---

## Glosario de Campos

### 1. Identificadores y control

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `transaction_date` | DATE | **Campo de partición**. Fecha de la transacción | 0% NULL |
| `transaction_id` | STRING | ID único de la transacción en el sistema origen | 0% NULL |
| `transaction_ticket` | STRING | Número de ticket/recibo asociado a la transacción | — |
| `id` | STRING | Documento de identidad del cliente (DNI/CE) | **94.8% NULL** |
| `itc_company_id` | STRING | Código de empresa Intercorp (`013`=Cineplanet, `033`=NGR) | 0% NULL |
| `itc_company_name` | STRING | Nombre de la empresa | 0% NULL |
| `process_date` | DATE | Fecha de foto/extracción ETL | 0% NULL |
| `load_date` | TIMESTAMP | Timestamp de carga en BigQuery | 0% NULL |
| `record_source` | STRING | Siempre `master_transaction` | 0% NULL |
| `creation_user` | STRING | Service account de ETL | 0% NULL |
| `country_id` | STRING | Código de país (ej: `51` = Perú) | — |

### 2. Tipo e identificación del documento

| Campo | Tipo | Descripción |
|---|---|---|
| `identification_document_type_id` | STRING | Código del tipo de documento: `01`=DNI, `02`=CE, `04`=PASAPORTE, `OTROS` |
| `identification_document_type` | STRING | Descripción del tipo de documento |
| `flag_customer_identified` | STRING | `true` = cliente con documento identificado correctamente, `false` = anónimo |

### 3. Canal y lugar de venta

| Campo | Tipo | Descripción | Calidad (013) | Calidad (033) |
|---|---|---|---|---|
| `channel_id` | STRING | Código de canal: `01`=PRESENCIAL, `02`=NO PRESENCIAL | Mayormente NULL | NULL |
| `channel_description` | STRING | Descripción: PRESENCIAL / NO PRESENCIAL | Mayormente NULL | NULL |
| `place_id` | STRING | Código del lugar de venta (formato `país-fuente-sucursal`, ej: `001-001-02`) | Bien poblado | Bien poblado |
| `place_description` | STRING | Nombre del local (ej: `PERÚ-VISTA COMPLEJOS-CP CENTRO`) | Bien poblado | Bien poblado |
| `business_unit` | STRING | Unidad de negocio (ej: `DULCERÍA`, `BOLETERÍA` para Cineplanet; local/marca para NGR) | Bien poblado | Bien poblado |

### 4. Producto / ítem

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `product_id` | STRING | Código del producto/función. `NO APLICA` para ítems de servicio en Cineplanet | — |
| `product_item_id` | STRING | ID del ítem en la transacción | 0% NULL |
| `product_item_sku` | STRING | SKU del ítem (igual a `product_item_id` en muchos casos para experiencias) | 0% NULL |
| `product_item_description` | STRING | Descripción del ítem (ej: `REFILL CANCHITA PLATA SALADA`, `Entrada adulto 2D`) | Bien poblado |
| `product_description` | STRING | Descripción de la categoría de producto | — |
| `product_item_quantity` | FLOAT64 | Cantidad del ítem (generalmente 1.0) | — |
| `product_item_seq` | INT64 | Secuencia/correlativo del ítem dentro de la transacción (1, 2, 3...) | — |
| `master_item` | STRING | Identificador único del producto en el catálogo jerárquico | Mayormente NULL |
| `unique_id` | STRING | ID de relación/vínculo entre productos | Mayormente NULL |
| `question_id` | STRING | ID del producto dentro de la transacción | Mayormente NULL |
| `brand_id` | STRING | Código de la empresa a nivel unidad de negocio | Mayormente NULL (Cineplanet) |
| `brand_name` | STRING | Nombre de marca (útil en NGR para distinguir Bembos / Dunkin / etc.) | Mayormente NULL |

### 5. Montos

| Campo | Tipo | Descripción | Cineplanet | NGR |
|---|---|---|---|---|
| `product_item_unit_price_amount` | FLOAT64 | **Precio unitario de venta** (con IGV) | Principal campo | Principal campo |
| `product_item_unit_full_price_amount` | FLOAT64 | Precio base unitario incluyendo subsidio | — | — |
| `product_item_gross_amount` | FLOAT64 | Monto bruto del ítem (precio - descuentos, sin subsidio) | Bien poblado | Bien poblado |
| `product_item_gross_full_amount` | FLOAT64 | Monto bruto incluyendo subsidio | — | — |
| `product_item_dsct_amount` | FLOAT64 | Monto de descuento del ítem | Mayormente NULL | — |
| `product_item_tax_amount` | FLOAT64 | IGV del ítem | Mayormente NULL | — |
| `product_item_rc_amount` | FLOAT64 | Monto por recarga al consumo | Mayormente NULL | — |
| `product_item_subsidy` | FLOAT64 | Monto subsidiado | — | — |
| `product_item_subsidy_provider` | STRING | Entidad que otorga subsidio | — | — |
| `transaction_digital_comission` | FLOAT64 | Comisión digital (para ventas online) | — | — |

> **Nota sobre precios negativos en NGR (033)**: `product_item_unit_price_amount` puede ser negativo (mín observado: -89.85) — representa anulaciones/reversiones.

### 6. Tipo y estado de transacción

| Campo | Tipo | Descripción |
|---|---|---|
| `transaction_type` | STRING | Tipo: `VENTA` (venta normal) o `ANULACION`/`DEVOLUCION` |
| `flag_voided` | STRING | `true` = transacción anulada/revertida |
| `flag_load_type` | STRING | `AUTOMATICO` = carga normal, `MANUAL` = registros de subsanación |

### 7. Descuentos y promociones

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_promotion` | INT64 | `1` = ítem tiene promoción activa |
| `promotion_id` | STRING | ID de la promoción aplicada |
| `sale_type_id` | STRING | Código del medio de venta |
| `sale_type` | STRING | Descripción del medio de venta |

### 8. Campos de fecha adicionales

| Campo | Tipo | Descripción |
|---|---|---|
| `transaction_datetime` | STRING | Fecha y hora de la transacción (STRING — convertir para cálculos de hora) |
| `transaction_hour` | STRING | Hora de la transacción (extracción del datetime) |
| `transaction_date_number` | STRING | Fecha en formato numérico `YYYYMMDD` |
| `transaction_month` | STRING | Mes de la transacción (valor numérico como STRING: `1`–`12`) |
| `transaction_year` | STRING | Año de la transacción como STRING |

---

## Diferencias por empresa

| Atributo | 013 — CINEPLANET | 033 — NGRESTAURANT |
|---|---|---|
| `business_unit` | `BOLETERÍA` o `DULCERÍA` | Nombre del local/marca (Bembos, Dunkin...) |
| `flag_customer_identified` | ~60% `true` | ~0.01% `true` |
| Ticket promedio | S/. 400 – 1,100 | S/. 4.7 – 5.1 |
| Ubicaciones (`place_id`) | 55 cines (Jan 2026) | 200+ locales (Jan 2026) |
| Productos distintos | 1,863 (entradas + productos dulcería) | 5,257 (ítems de menú) |
| Precios negativos | Raros | Frecuentes (anulaciones) |
| `product_id` | `NO APLICA` (servicio/refill) | Código de ítem |
| `brand_name` | NULL generalmente | Puede identificar submarca |

---

## Reglas de negocio

1. **Particionado por `transaction_date`** — SIEMPRE filtrar por este campo. Sin filtro se escanean ~255 GB.

2. **94.8% de filas sin `id`**: La mayoría de transacciones son anónimas. Para análisis de cliente, filtrar `WHERE id IS NOT NULL AND flag_customer_identified = 'true'`.

3. **Un `transaction_id` puede tener N ítems**: Cada fila es un ítem del ticket. Para contar tickets únicos usar `COUNT(DISTINCT transaction_id)`.

4. **`flag_voided = 'true'` y precios negativos**: Excluir anulaciones en análisis de ventas. `WHERE flag_voided = 'false' AND transaction_type = 'VENTA'`.

5. **Cineplanet boletería vs. dulcería**:
   - `business_unit = 'BOLETERÍA'` → venta de entradas → análisis de asistencia al cine
   - `business_unit = 'DULCERÍA'` → venta de snacks/bebidas → análisis de consumo de confitería

6. **NGR (033) es de alta volumen pero baja utilidad para segmentación de clientes**: Sin identificación del cliente, solo es útil para análisis de tendencias de ventas por local. Para segmentación de clientes cinéfilos, usar solo `itc_company_id = '013'`.

7. **`transaction_datetime` en formato STRING**: Para análisis por hora del día:
   ```sql
   EXTRACT(HOUR FROM PARSE_DATETIME('%Y-%m-%d %H:%M:%S', transaction_datetime)) AS hora
   ```

8. **Alimenta `ba_itc_attr_entertainment`**: Este SP procesa `itc_company_id = '013'` de esta tabla para calcular atributos de frecuencia y gasto en Cineplanet.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `id` | **94.8%** | Casi toda la tabla es anónima. Solo usar con `WHERE id IS NOT NULL` para perfiles de cliente. |
| `channel_id` / `channel_description` | Alta (Cineplanet) | NULL en muestra — Cineplanet no reporta canal regularmente. |
| `product_item_dsct_amount` | Alta | NULL en muchos registros de Cineplanet — descuentos no siempre detallados. |
| `product_item_tax_amount` | Alta | NULL en Cineplanet — IGV no siempre desglosado. |
| `brand_name` | Mayormente NULL en 013 | Útil en NGR para identificar submarca del restaurante. |
| `master_item`, `unique_id`, `question_id` | Alta | Campos del modelo corporativo sin uso activo en este dominio. |
| Precios negativos (033) | — | Min observado: -89.85. Representan anulaciones — no son errores. |
| `transaction_datetime` | — | STRING, no TIMESTAMP — calcular horas requiere conversión explícita. |
| `process_date` > `transaction_date` | ~33 días | El ETL de Cineplanet tiene un rezago mayor al usual (~33 días en enero 2026). |

---

## Queries de referencia

```sql
-- Asistencia mensual identificada a Cineplanet (boletería)
SELECT DATE_TRUNC(transaction_date, MONTH) as mes,
  COUNT(DISTINCT transaction_id) as tickets,
  COUNT(DISTINCT id) as clientes,
  ROUND(SUM(product_item_gross_amount), 2) as monto_boleteria
FROM `intercorp-data-storage-pv.master_transaction.t_experience_transaction`
WHERE transaction_date BETWEEN '2025-02-01' AND '2026-01-31'
  AND itc_company_id = '013'
  AND business_unit = 'BOLETERÍA'
  AND flag_voided = 'false'
  AND id IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- Top clientes frecuentes en Cineplanet
SELECT id,
  COUNT(DISTINCT transaction_id) as visitas,
  COUNT(DISTINCT place_id) as cines_distintos,
  ROUND(SUM(product_item_gross_amount), 2) as gasto_total
FROM `intercorp-data-storage-pv.master_transaction.t_experience_transaction`
WHERE transaction_date BETWEEN '2025-08-01' AND '2026-01-31'
  AND itc_company_id = '013'
  AND business_unit = 'BOLETERÍA'
  AND flag_voided = 'false'
  AND id IS NOT NULL
GROUP BY 1
ORDER BY visitas DESC
LIMIT 100;

-- Cine favorito por cliente (último año)
SELECT id, place_description, COUNT(DISTINCT transaction_id) as visitas
FROM (
  SELECT id, place_description, transaction_id,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY COUNT(*) DESC) as rn
  FROM `intercorp-data-storage-pv.master_transaction.t_experience_transaction`
  WHERE transaction_date BETWEEN '2025-02-01' AND '2026-01-31'
    AND itc_company_id = '013'
    AND business_unit = 'BOLETERÍA'
    AND id IS NOT NULL
  GROUP BY 1, 2, 3
)
WHERE rn = 1;

-- Ventas NGR por local (con precios válidos, excluir anulaciones)
SELECT place_description,
  COUNT(DISTINCT transaction_id) as tickets,
  ROUND(SUM(product_item_gross_amount), 2) as ventas_total,
  ROUND(AVG(product_item_unit_price_amount), 2) as ticket_prom
FROM `intercorp-data-storage-pv.master_transaction.t_experience_transaction`
WHERE transaction_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND itc_company_id = '033'
  AND flag_voided = 'false'
  AND product_item_gross_amount > 0
GROUP BY 1
ORDER BY ventas_total DESC
LIMIT 20;

-- Asistencia por hora del día en Cineplanet
SELECT EXTRACT(HOUR FROM PARSE_DATETIME('%Y-%m-%d %H:%M:%S', transaction_datetime)) AS hora,
  COUNT(DISTINCT transaction_id) as tickets
FROM `intercorp-data-storage-pv.master_transaction.t_experience_transaction`
WHERE transaction_date = '2026-01-30'
  AND itc_company_id = '013'
  AND business_unit = 'BOLETERÍA'
  AND flag_voided = 'false'
GROUP BY 1 ORDER BY 1;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_transaction.t_experience_transaction`*
