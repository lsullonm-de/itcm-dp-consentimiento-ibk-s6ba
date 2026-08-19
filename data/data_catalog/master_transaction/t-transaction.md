# Catálogo de Datos — `t_transaction`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_transaction`
**Tabla completa:** `intercorp-data-storage-pv.master_transaction.t_transaction`

---

## Descripción

Tabla de transacciones procesadas por **IZIPAY** (itc_company_id = `086`). Registra cada pago realizado con tarjeta (POS / ecommerce) donde Izipay actúa como pasarela de pago. A diferencia de `t_retail_transaction` (que registra transacciones de las tiendas Intercorp), esta tabla captura el **instrumento de pago** (tarjeta, banco, marca, cuotas) con el que el portador de la tarjeta pagó en un comercio afiliado a la red Izipay.

Cada fila representa **un ítem de la transacción** (línea de producto/servicio). El campo `transaction_category = 'MEDIO DE PAGO'` para todos los registros actuales, indicando que no se detallan productos SKU sino el medio de cobro.

> **Nota arquitectural:** La tabla es una **snapshot diaria acumulativa con ventana variable**. Cada valor de `itc_process_date` contiene las transacciones de los últimos N días (N variable, típicamente 15-46 días). Para queries de análisis histórico se recomienda filtrar `WHERE transaction_date = itc_process_date` para obtener únicamente las transacciones del día del snapshot, o usar `transaction_date` para un rango específico sobre el último snapshot disponible.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `itc_process_date` (DAY) |
| Clusterizado por | `channel_id`, `place_id`, `commerce_id` |
| Total de filas | ~3,417,746,240 |
| Total de particiones | 1,891 |
| Tamaño lógico activo | ~951 GB |
| Tamaño físico activo | ~58 GB (alta compresión) |
| Ubicación | US |
| Empresa fuente | IZIPAY S.A.C (`itc_company_id = 086`) |
| record_source | `AZURE IZIPAY T_TRANSACTION` |
| Etiquetas | environment=prd, inca_published=si, inca_sync=true |
| Descripción oficial | "Un tipo de transacción que registra el intercambio de propiedad y/o responsabilidad por artículos, productos, servicios entre la empresa y un party." |

---

## Snapshot del 2026-01-30

| Métrica | Valor |
|---|---|
| Total registros en snapshot | 2,940,178 |
| Rango de transaction_date cubierto | 2025-12-15 → 2026-01-30 (28 fechas) |
| Registros del mismo día (trx_date = 2026-01-30) | 2,159,794 |
| Clientes únicos (día) | 998,054 |
| Comercios únicos (día) | 75,282 |
| Monto bruto total (día) | ~S/. 175.4 MM |
| Ticket promedio (día) | ~S/. 81.2 |
| % Devoluciones | 0.15% |

---

## Glosario de Campos

### 1. Identificadores de empresa y proceso

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `process_date` | DATE (REQUIRED) | Fecha de foto configurada en el ETL | Puede diferir de `itc_process_date` (campo de partición) |
| `itc_process_date` | DATE (REQUIRED) | **Campo de partición**. Fecha de carga del snapshot | Usar siempre en WHERE para eficiencia de costo/tiempo |
| `itc_company_id` | STRING (REQUIRED) | Código de empresa Intercorp | Siempre `086` en esta tabla |
| `itc_company_name` | STRING (REQUIRED) | Nombre de empresa Intercorp | Siempre `IZIPAY` |
| `load_date` | TIMESTAMP (REQUIRED) | Timestamp de inserción en el modelo BigQuery | Auditoría |
| `creation_user` | STRING (REQUIRED) | Usuario que creó el registro | Auditoría |
| `record_source` | STRING | Aplicativo origen de los datos | Siempre `AZURE IZIPAY T_TRANSACTION` |

### 2. Identificadores de transacción

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `transaction_id` | STRING | Número de transacción generado en el sistema origen | **SIEMPRE NULL** en datos actuales — no usar para deduplicación |
| `transaction_category` | STRING | Categoría de la transacción | Siempre `MEDIO DE PAGO` en registros actuales. El modelo prevé: RETAIL, SEGURO, CONTROL |
| `transaction_type_id` | STRING | Código del tipo de transacción | Generalmente NULL |
| `transaction_type` | STRING | Tipo: VENTA / DEVOLUCIÓN / CAMBIO / EXTORNO | `VENTA` ~99.85%, `DEVOLUCIÓN` ~0.15% |
| `transaction_ticket` | STRING | Número de ticket/voucher | Identificador del comprobante |
| `transaction_date` | DATE | Fecha real de la transacción | Usar con `itc_process_date` para evitar escanear todos los snapshots |
| `transaction_datetime` | STRING | Fecha y hora completa de la transacción | Formato STRING, convertir si se necesita ordenar temporalmente |
| `transaction_hour` | STRING | Hora de la transacción | Dígitos de la hora |
| `transaction_year` | STRING | Año de la transacción | Derivado de transaction_date |
| `transaction_month` | STRING | Mes de la transacción | Derivado de transaction_date |
| `transaction_date_number` | STRING | Número de día del mes de la transacción | Derivado de transaction_date |
| `approval_date` | STRING | Fecha de aprobación del pago | Relacionado al proceso de autorización |

### 3. Cliente / Portador

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `id` | STRING | Identificador del cliente (documento de identidad) en el ecosistema Intercorp | **NUNCA NULL** — 100% completitud en datos observados |
| `identification_document_type_id` | STRING | Código del tipo de documento | Ej: DNI, CE, RUC |
| `identification_document_type` | STRING | Descripción del tipo de documento | |
| `business_id` | STRING | Código de cliente en el sistema origen a nivel Grupo Intercorp | Complementa `id` |
| `flag_customer_identified` | STRING | Indica si el cliente tiene documento correctamente registrado | `1` = identificado (~99.98%), NULL en casos residuales |

### 4. Canal y negocio

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `channel_id` | STRING | Código del canal: `01`=PRESENCIAL, `02`=NO PRESENCIAL | Parte del clustering — eficiente para filtrar |
| `channel_description` | STRING | Descripción del canal | **SIEMPRE NULL** en datos actuales a pesar de tener channel_id |
| `channel_source_id` | STRING | Código del canal en la fuente origen | |
| `channel_source_description` | STRING | Descripción del canal en la fuente origen | |
| `business_unit_id` | STRING | Código de la unidad de negocio | |
| `business_unit` | STRING | Descripción de la unidad de negocio | Tienda, departamento, quiosco, etc. |

### 5. Comercio y lugar

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `commerce_id` | STRING | Código del comercio donde se realiza la venta | Parte del clustering. ~80K comercios distintos por día |
| `business_description` | STRING | Nombre del comercio (punto de venta) | |
| `place_id` | STRING | Código del lugar físico | **SIEMPRE NULL** en datos actuales |
| `place_description` | STRING | Descripción del lugar | |

### 6. Producto / Ítem

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `product_id` | STRING | Código del producto | Generalmente vacío en transacciones de pago POS |
| `product_description` | STRING | Descripción del producto | |
| `product_item_id` | STRING | Código del ítem de la transacción | |
| `product_item_sku` | STRING | SKU del ítem | |
| `product_item_quantity` | FLOAT64 | Cantidad de ítems | |
| `product_item_unit_price_amount` | FLOAT64 | Precio base unitario de venta | |
| `product_item_unit_full_price_amount` | FLOAT64 | Precio unitario full (sin descuentos) | |
| `product_item_gross_amount` | FLOAT64 | **Monto del ítem**: incluye IGV, resta descuentos. Es el monto que aparece en el ticket para pagar. Fórmula: `product_item_price_amount - product_item_dsct_amount` | **Campo monetario principal para análisis de consumo** |
| `product_item_acquisition_price` | FLOAT64 | Precio total de adquisición: `unit_acquisition_price × quantity` | Costo para la empresa |
| `ticket_product_gross_amount` | FLOAT64 | Venta bruta sin IGV del ticket completo | Agregado a nivel ticket |
| `transaction_digital_comission` | FLOAT64 | Monto de comisión digital | Relacionado a canal online |

### 7. Medio de pago

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `payment_bank_id` | STRING | Código de entidad financiera intermediaria | |
| `payment_bank` | STRING | Nombre del banco/entidad emisora | BCP ~55%, Interbank ~13%, BBVA ~11% |
| `payment_card_brand` | STRING | Marca de la tarjeta | VISA ~68%, MASTERCARD ~5%, NULL ~4% |
| `payment_card_type` | STRING | Tipo de tarjeta (por BIN) | DÉBITO ~69%, CRÉDITO ~27%, NULL ~4% |
| `payment_card_type_source` | STRING | Tipo de tarjeta según la fuente origen | |
| `number_card` | STRING | Número de tarjeta **encriptado** | Dato sensible — no contiene número real |
| `card_itc_id` | STRING | Código de tarjeta en el sistema origen | |
| `quotas_number` | INT64 | Número de cuotas seleccionadas por el cliente | 0 cuando no aplica cuotas |
| `flag_quotas` | STRING | Indica si el cliente paga en cuotas | `1` = con cuotas (~0.8%), `0` = sin cuotas |
| `flag_voided` | STRING | Indica si la transacción fue anulada | **SIEMPRE NULL** en datos actuales |
| `itc_number_card_mask_bin_6` | STRING | BIN de 6 dígitos de la tarjeta enmascarado | Para asociar a c_bin_card |
| `itc_number_card_mask_bin_8` | STRING | BIN de 8 dígitos de la tarjeta enmascarado | Para mayor precisión en clasificación |
| `bin_card_id` | STRING | ID del BIN de tarjeta | Clave para join con catálogo de BINs |
| `bin_card_8_id` | STRING | ID del BIN de 8 dígitos | |

### 8. Moneda y geografía

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `currency_id` | STRING | Código de moneda | |
| `currency` | STRING | Descripción de moneda | Predominantemente SOLES (PEN) |
| `country_id` | STRING | Código de país | |

---

## Reglas de uso y observaciones de calidad

### Estructura snapshot (crítico)

1. **Partición vs. fecha de transacción:** El campo de partición es `itc_process_date`, NO `transaction_date`. Siempre incluir `WHERE itc_process_date = 'YYYY-MM-DD'` para evitar full table scan.

2. **Ventana rolling variable:** Cada snapshot `itc_process_date` contiene transacciones de los últimos N días (N variable: ~28 días en snapshots recientes, puede llegar a años en snapshots históricos). Esto significa que el mismo `transaction_id` o la misma transacción puede aparecer en múltiples particiones. **No agregar sin filtro de transaction_date.**

3. **Snapshot diario:** Hay un snapshot por cada día del calendario (~31 snapshots por mes). El volumen por snapshot es ~2.9M registros.

### Campos con calidad deficiente (siempre NULL en datos observados)

| Campo | Estado | Impacto |
|---|---|---|
| `transaction_id` | Siempre NULL | No se puede usar como PK, ni contar transacciones distintas |
| `channel_description` | Siempre NULL | Usar `channel_id` en su lugar |
| `place_id` | Siempre NULL | El clustering por este campo no aporta beneficio actual |
| `flag_voided` | Siempre NULL | No usar para filtrar anulados |

### Deduplicación

Dado que `transaction_id` es siempre NULL, la **granularidad real** de esta tabla no es por transacción sino por evento de ítem procesado. Para contar transacciones únicas usar `transaction_ticket` o combinación de `(id, commerce_id, transaction_date, transaction_datetime)`.

### Tipo de tarjeta

- `payment_card_type` proviene del BIN (clasificación Intercorp)
- `payment_card_type_source` proviene del sistema Izipay origen
- Pueden diferir — para consistencia usar siempre el mismo campo en análisis comparativos

### Clientes identificados

- `flag_customer_identified = '1'` en ~99.98% de los registros
- El campo `id` tiene 100% de completitud — todos los pagos procesados tienen el documento del pagador

---

## Análisis de tendencias — últimos 12 meses (mar 2025 – feb 2026)

Muestreo: día 15 de cada mes, filtrando `transaction_date = itc_process_date` (transacciones del día).

### Volumen diario promedio

| Mes | Transacciones/día | Clientes únicos | Comercios | Monto (MM S/.) | Ticket prom. (S/.) | % Devoluciones |
|---|---|---|---|---|---|---|
| Mar 2025 | 2,214,092 | 1,127,692 | 91,020 | 188.7 | 85.2 | 0.05% |
| Abr 2025 | 1,890,999 | 967,845 | 80,619 | 152.4 | 80.6 | 0.26% |
| May 2025 | 1,946,822 | 983,974 | 79,448 | 157.2 | 80.8 | 0.15% |
| Jun 2025 | 1,975,180 | 977,712 | 65,491 | 152.2 | 77.1 | 0.04% |
| Jul 2025 | 1,938,796 | 961,342 | 75,920 | 175.4 | 90.5 | 0.15% |
| Ago 2025 | 1,981,852 | 950,807 | 77,168 | 162.0 | 81.8 | 0.14% |
| Sep 2025 | 1,955,790 | 924,304 | 75,017 | 154.2 | 78.9 | 0.20% |
| Oct 2025 | 1,909,288 | 878,884 | 75,952 | 152.3 | 79.8 | 0.30% |
| Nov 2025 | 2,415,726 | 1,116,747 | 83,388 | 181.8 | 75.2 | 0.03% |
| Dic 2025 | 2,226,883 | 1,042,710 | 76,757 | 198.9 | 89.3 | 0.19% |
| Ene 2026 | 2,085,842 | 983,607 | 74,131 | 177.1 | 84.9 | 0.16% |
| Feb 2026 | 2,320,821 | 1,030,143 | 62,419 | 159.9 | 68.9 | 0.05% |

**Observaciones de estacionalidad:**
- **Pico de Mar 2025:** Mayor volumen del año (2.21M), con el mayor número de comercios (91K) — posiblemente inicio de año académico / verano
- **Mínimo de Oct 2025:** Menor volumen de clientes únicos (878K) y monto
- **Nov 2025:** Segundo pico de volumen (2.42M) coincide con campañas de fin de año y pre-navidad
- **Dic 2025:** Ticket promedio más alto del año (S/. 89.3) — compras navideñas de mayor valor
- **Feb 2026:** Menor ticket promedio (S/. 68.9) con muchos comercios activos — regreso a clases, consumo masivo de bajo monto
- **Comercios activos:** caída de 91K (Mar) → 62K (Feb) sugiere ciclo de actividad de comercios afiliados

### Evolución de marcas de tarjeta

| Marca | Mar 2025 | Jun 2025 | Sep 2025 | Dic 2025 | Feb 2026 |
|---|---|---|---|---|---|
| VISA Débito | 65.1% | 66.4% | 67.0% | 69.5% | 67.5% |
| VISA Crédito | 20.8% | 19.6% | 18.4% | 16.3% | 16.1% |
| VISA NULL | 4.6% | 5.3% | 6.0% | 6.4% | 9.0% |
| MC Crédito | 2.7% | 2.4% | 2.4% | 2.0% | 2.0% |
| MC Débito | 2.3% | 1.8% | 1.9% | 1.9% | 1.7% |

**Tendencia:** VISA Débito crece sostenidamente (+2.4pp en 12 meses). VISA Crédito cae (-4.7pp). El campo NULL en payment_card_brand crece (4.6% → 9.0% en Feb 2026) — posible degradación de clasificación o nuevos tipos de tarjetas no catalogadas.

### Evolución de bancos emisores (top 6)

| Banco | Mar 2025 | Jun 2025 | Sep 2025 | Dic 2025 | Feb 2026 |
|---|---|---|---|---|---|
| BCP | 53.7% | 55.2% | 57.0% | 57.8% | 56.5% |
| Interbank | 13.3% | 13.1% | 12.5% | 12.7% | 12.2% |
| BBVA | 11.9% | 11.4% | 10.7% | 10.7% | 10.6% |
| Financiera Uno | 3.9% | 4.0% | 3.4% | 3.0% | 3.4% |
| Falabella | 3.1% | 3.1% | 2.8% | 2.4% | 2.6% |
| BANBIF / Wiese | 2.9% | 2.5% | 2.5% | 2.3% | — |
| Visa Local | — | — | — | — | 3.5% |

**Tendencia:** BCP consolida su liderazgo (+2.8pp). Interbank y BBVA ceden participación. Visa Local aparece en Feb 2026 con 3.5% — posible nueva fuente de datos de tarjetas prepago.

---

## Uso en SPs del repositorio

| SP | Tipo de uso | Descripción del uso |
|---|---|---|
| `sp_atributos_izi.sql` | Input principal | Genera ~500 atributos de comportamiento transaccional Izipay por cliente (ventana 365 días) |
| `sp_t_transaction_izipay_load.sql` | ETL / carga | Carga incremental de registros en esta tabla |
| `sp_load_ba_itc_attr_card_consumption.sql` | Input | Calcula atributos de consumo con tarjeta |
| `sp_load_ibk_cuenta_sueldo_adobe.sql` | Input | Identifica clientes con cuenta sueldo IBK vía transacciones Izipay |
| `sp_m_customer_card.sql` | Input | Actualiza maestro de tarjetas de clientes |

---

## Queries de referencia

```sql
-- Transacciones del día más reciente disponible
SELECT
  transaction_date,
  COUNT(*) AS items,
  COUNT(DISTINCT id) AS clientes,
  COUNT(DISTINCT commerce_id) AS comercios,
  ROUND(SUM(product_item_gross_amount)/1e6, 2) AS monto_MM_soles,
  ROUND(AVG(product_item_gross_amount), 2) AS ticket_promedio
FROM `intercorp-data-storage-pv.master_transaction.t_transaction`
WHERE itc_process_date = '2026-01-30'
  AND transaction_date = itc_process_date  -- Solo el día del snapshot
GROUP BY 1;

-- Distribución de medios de pago
SELECT
  payment_card_brand,
  payment_card_type,
  payment_bank,
  COUNT(*) AS total,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM `intercorp-data-storage-pv.master_transaction.t_transaction`
WHERE itc_process_date = '2026-01-30'
  AND transaction_date = itc_process_date
GROUP BY 1,2,3
ORDER BY total DESC;

-- Análisis de comercios por monto (top 20)
SELECT
  commerce_id,
  business_description,
  COUNT(*) AS transacciones,
  COUNT(DISTINCT id) AS clientes,
  ROUND(SUM(product_item_gross_amount)/1000, 1) AS monto_miles_soles
FROM `intercorp-data-storage-pv.master_transaction.t_transaction`
WHERE itc_process_date = '2026-01-30'
  AND transaction_date = itc_process_date
  AND transaction_type = 'VENTA'
GROUP BY 1,2
ORDER BY monto_miles_soles DESC
LIMIT 20;

-- Historial mensual del último año (usando el snapshot del día 15 de cada mes)
SELECT
  itc_process_date AS fecha_snapshot,
  COUNT(*) AS transacciones,
  COUNT(DISTINCT id) AS clientes_unicos,
  ROUND(SUM(product_item_gross_amount)/1e6, 2) AS monto_MM_soles
FROM `intercorp-data-storage-pv.master_transaction.t_transaction`
WHERE itc_process_date BETWEEN '2025-03-15' AND '2026-02-15'
  AND MOD(EXTRACT(DAY FROM itc_process_date), 30) = 15  -- Aproximación día 15
  AND transaction_date = itc_process_date
GROUP BY 1
ORDER BY 1;

-- Clientes con cuotas en el último mes
SELECT
  id,
  payment_bank,
  payment_card_brand,
  quotas_number,
  ROUND(SUM(product_item_gross_amount), 2) AS monto_total
FROM `intercorp-data-storage-pv.master_transaction.t_transaction`
WHERE itc_process_date = '2026-01-30'
  AND transaction_date BETWEEN '2026-01-01' AND '2026-01-30'
  AND flag_quotas = '1'
GROUP BY 1,2,3,4
ORDER BY monto_total DESC;
```

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.c_bin_card` | `bin_card_id` o `itc_number_card_mask_bin_6` | Obtener detalles del BIN (banco, tipo, marca enriquecida) |
| `master_placement.m_commerce` | `commerce_id` | Obtener segmento, rubro, coordenadas del comercio |
| `master_party.iden_itc_party` | `id` → `party_id` | Vincular con el party_id del cliente en el ecosistema ITC |
| `bi_ibk_casos_uso.c_entidades_financieras` | `payment_bank_id` | Obtener clasificación de entidades financieras |

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_transaction.t_transaction`*
