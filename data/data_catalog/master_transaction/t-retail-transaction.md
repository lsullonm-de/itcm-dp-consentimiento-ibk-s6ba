# t_retail_transaction

## Descripción de la tabla

Tabla transaccional corporativa que consolida las **ventas a nivel de ítem (línea de producto)** de las empresas retail del grupo Intercorp. Cada registro representa un producto vendido dentro de una transacción de venta, devolución o nota de crédito.

Incluye información de:
- Cabecera de transacción (fecha, tipo, canal, tienda, comprobante)
- Ítem de producto (SKU, descripción, cantidades, montos, descuentos)
- Identificación del cliente (`id` homologado Intercorp)
- Clasificación del producto (categoría, subcategoría, familia, subfamilia)
- Datos del empleado que atendió la venta

Las empresas presentes son: **SUPERMERCADOS PERUANOS (010), INKAFARMA (025), MIFARMA (048), PROMART (024), TIENDAS PERUANAS/OECHSLE (011)**. Adicionalmente aparece **REAL PLAZA (015)** con volumen muy marginal y discontinuo (probablemente data de prueba o integración parcial).

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Proyecto | `intercorp-data-storage-pv` |
| Dataset | `master_transaction` |
| Tabla | `t_retail_transaction` |
| Tipo | BASE TABLE |
| Particionado por | `transaction_date` |
| Clustering | `business_unit`, `place_description` |
| Total de filas | 10,657,203,361 |
| Tamaño lógico total | 8.54 TB |
| Número de particiones | 3,721 |
| Fecha de creación | 2021-03-23 |
| Labels | `environment: prd`, `inca_published: si`, `inca_sync: true` |

---

## Volumen por empresa (2026-01-30 — snapshot)

| itc_company_id | itc_company_name | Registros (ítems) | Transacciones únicas | Clientes únicos | Tiendas |
|---|---|---|---|---|---|
| 010 | SUPERMERCADOS PERUANOS | 3,399,468 | 935,503 | 215,628 | 1,683 |
| 025 | INKAFARMA | 638,169 | 334,397 | 260,823 | 1,383 |
| 048 | MIFARMA | 493,680 | 256,798 | 191,857 | 1,136 |
| 024 | PROMART | 87,119 | 31,341 | 25,144 | 38 |
| 011 | TIENDAS PERUANAS | 63,654 | 23,091 | 19,132 | 32 |

---

## Análisis de tendencias — últimos 12 meses (mar 2025 – feb 2026)

> Basado en muestreo de 5 días por mes (días 5, 10, 15, 20, 25).

### Volumen promedio diario por empresa y mes

| Mes | 010 SPSA (ítems/día) | 025 INKF (ítems/día) | 048 MFARM (ítems/día) | 024 PMART (ítems/día) | 011 OE (ítems/día) |
|---|---|---|---|---|---|
| 2025-03 | 3,210,775 | 598,938 | 469,117 | 78,421 | 57,027 |
| 2025-04 | 3,262,584 | 571,843 | 440,216 | 80,248 | 59,945 |
| 2025-05 | 3,434,211 | 627,532 | 484,606 | 78,401 | 77,114 |
| 2025-06 | 2,918,108 | 600,969 | 453,009 | 68,439 | 52,854 |
| 2025-07 | 3,320,317 | 644,536 | 499,723 | 85,972 | 70,870 |
| 2025-08 | 3,265,176 | 619,680 | 459,131 | 77,381 | 53,302 |
| 2025-09 | 3,095,380 | 642,683 | 487,668 | 74,942 | 57,618 |
| 2025-10 | 3,500,169 | 632,454 | 471,693 | 77,503 | 58,231 |
| 2025-11 | 3,309,551 | 652,310 | 493,435 | 90,220 | 64,893 |
| 2025-12 | 3,204,116 | 643,263 | 481,979 | 76,692 | 89,954 |
| 2026-01 | 3,600,518 | 638,863 | 492,917 | 97,631 | 60,106 |
| 2026-02 | 3,562,769 | 612,296 | 472,108 | 90,915 | 60,662 |

### Crecimiento de tiendas activas (place_id por mes)

| Mes | 010 SPSA | 025 INKF | 048 MFARM | 024 PMART | 011 OE |
|---|---|---|---|---|---|
| 2025-03 | 1,436 | 1,324 | 1,092 | 38 | 30 |
| 2025-06 | 1,505 | 1,335 | 1,096 | 37 | 31 |
| 2025-09 | 1,564 | 1,356 | 1,118 | 37 | 32 |
| 2025-12 | 1,620 | 1,374 | 1,124 | 37 | 32 |
| 2026-02 | 1,676 | 1,380 | 1,135 | 38 | 33 |

> **Tendencia**: SPSA creció +240 tiendas en 12 meses (+17%). Inkafarma +56 (+4%). Mifarma +43 (+4%). Promart y OE estables.

### % ítems negativos (devoluciones) por empresa — estable en el tiempo

| Empresa | % negativo promedio | Rango |
|---|---|---|
| 010 SPSA | 0.15–0.18% | Muy bajo — solo DEVOLUCION |
| 025 INKF | 0.78–0.91% | Bajo — NOTA DE CREDITO |
| 048 MFARM | 0.55–0.67% | Bajo — NOTA DE CREDITO |
| 024 PMART | 2.15–3.69% | Moderado — incluye NOTA DE CRÉDITO |
| 011 OE | **5.27–6.34%** | **Alto** — mayor tasa de devolución/crédito del grupo |

### Estacionalidad detectada

| Empresa | Observación |
|---|---|
| **010 SPSA** | Picos en días 15 y 25 de cada mes (quincena/fin de mes). Mayo, octubre y enero son los meses de mayor volumen. |
| **011 OE** | Dic 2025 muestra un día con solo 1,093 ítems (cierre por feriado navideño). Mayo pico con 162,487 ítems en un día (liquidación/campaña). |
| **024 PROMART** | Dic-2025 y Ene-2026 muestran valores mínimos ~321 ítems (días de cierre). Noviembre-Febrero con mayor volumen (temporada de construcción/remodelación). |
| **025 INKF** | Abril 2025 tiene el volumen más bajo (~570k). Tendencia creciente hacia fin de año. |
| **048 MFARM** | Abril y junio 2025 bajan. Diciembre con variabilidad alta (min 346k, max 546k). |

### Evolución de business_unit (canales nuevos)

| Empresa | Novedad detectada |
|---|---|
| **025 INKF** | `RAPPI` aparece desde diciembre 2025 (44 ítems), crece a 199 en enero 2026. Canal nuevo en integración. |
| **048 MFARM** | `RAPPI` presente desde marzo 2025 (~2,000 ítems/día). `VENTA MAYORISTA` aparece esporádicamente. |
| **010 SPSA** | Octubre 2025 pierde temporalmente 1 `business_unit` (de 7 a 6). Se recupera en noviembre. |
| **025 INKF** | `n_canales` sube de 5 a 6 `business_units` en diciembre 2025 con la entrada de RAPPI. |

---

## Glosario de campos

### Identificadores y control

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `process_date` | DATE | NO | Fecha de procesamiento ETL. Puede diferir de `transaction_date` |
| `itc_company_id` | STRING | NO | Código de empresa Intercorp (3 dígitos). Ver `c_itc_company` |
| `itc_company_name` | STRING | NO | Nombre de la empresa. Ej: `SUPERMERCADOS PERUANOS`, `INKAFARMA` |
| `id` | STRING | NO | Identificador único del cliente en el ecosistema Intercorp (DNI homologado) |
| `transaction_id` | STRING | YES | Número de transacción generado en el sistema origen |
| `transaction_category` | STRING | YES | Categoría: `RETAIL`, `SEGURO`, `CONTROL` |

### Transacción

| Campo | Tipo | Nullable | Descripción | Valores por empresa |
|---|---|---|---|---|
| `transaction_type_id` | STRING | YES | Código del tipo de transacción | Varía por empresa |
| `transaction_type` | STRING | YES | Tipo de movimiento | 010: `VENTA`,`DEVOLUCION` / 011,024: `VENTA`,`NOTA DE CREDITO`,`COBRO CONCESIONARIO` / 025,048: `VENTAS`,`NOTA DE CREDITO` |
| `transaction_date` | DATE | NO | Fecha de la venta. **Campo de partición** |
| `transaction_datetime` | STRING | YES | Fecha y hora de la transacción (dd/MM/yyyy HH:MM:SS) |
| `transaction_hour` | STRING | YES | Solo la hora de la transacción |
| `transaction_year` | STRING | YES | Año de la transacción |
| `transaction_month` | STRING | YES | Mes de la transacción |
| `transaction_date_number` | STRING | YES | Fecha en formato numérico. Ej: `20260130` |
| `transaction_ticket` | STRING | YES | Número de ticket/recibo |
| `transaction_pre_ticket` | STRING | YES | Documento previo a la transacción final |
| `transaction_status` | STRING | YES | Estado: `PENDIENTE`, `COMPLETA`, `ENTREGADA PARCIALMENTE`, `FACTURADO`, `CANCELADA` |
| `transaction_receipt_datetime` | STRING | YES | Fecha/hora impresa en el comprobante físico |
| `transaction_payment_document_type` | STRING | YES | Tipo de comprobante | 010: `BOLETA`,`FACTURA`,`NOTA CREDITO` / 011,024: `BOLETA`,`FACTURA`,`NOTA DE CRÉDITO` / 025,048: `BOL`,`FAC`,`NCR`,`GRL` |

### Negocio / Canal / Tienda

| Campo | Tipo | Nullable | Descripción | Valores por empresa |
|---|---|---|---|---|
| `business_unit_id` | STRING | YES | Código de unidad de negocio |  |
| `business_unit` | STRING | YES | Unidad de negocio (**campo de clustering**) | 010: `MASS`,`PLAZA VEA`,`CASH & CARRY`,`PLAZA VEA SUPER`,`VIVANDA`,`MERKAO`,`PLAZA VEA EXPRESS` / 011: `TIENDA_FISICO`,`TIENDA_VIRTUAL` / 024: `TIENDA_FISICO`,`TIENDA_VIRTUAL` / 025: `VENTA MOSTRADOR`,`APP`,`VENTA CONVENIO`,`VENTA DELIVERY`,`VENTA VANTTIVE`,`RAPPI` / 048: `VENTA MOSTRADOR`,`APP`,`RAPPI`,`VENTA CONVENIO`,`VENTA DELIVERY`,`VENTA MAYORISTA` |
| `channel_id` | STRING | YES | Código del canal de venta |  |
| `channel` | STRING | YES | Canal de venta | 010: `VENTA POS -FISICO`,`VENTA EC -ONLINE`,`VENTA CN -FISICO` / 011,024: `OFFLINE`,`ONLINE` / 025,048: `PRESENCIAL`,`NO PRESENCIAL` |
| `place_id` | STRING | YES | Código de la tienda/punto de venta |  |
| `place_description` | STRING | YES | Nombre de la tienda (**campo de clustering**) |  |
| `delivery_type` | STRING | YES | Tipo de entrega del pedido |  |
| `order_id` | STRING | YES | Código de la orden del cliente |  |
| `order_status` | STRING | YES | Estado de la orden: `Asignado`, `Facturado`, `Enviado`, `Cancelar`, entre otros |  |
| `order_type` | STRING | YES | Tipo de orden |  |
| `session_id` | STRING | YES | ID de sesión o token |  |
| `approval_date` | STRING | YES | Fecha de aprobación |  |
| `bill_id` | STRING | YES | ID del comprobante de pago |  |
| `bill_date` | STRING | YES | Fecha del comprobante |  |
| `currency_id` | STRING | YES | Código de moneda |  |
| `currency` | STRING | YES | Descripción de moneda. Ej: `PEN` |  |

### Cliente

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `identification_document_type_id` | STRING | YES | Código tipo documento: `01`=DNI, `02`=Carnet extranjería, `03`=RUC, `04`=Pasaporte, etc. |
| `identification_document_type` | STRING | YES | Descripción del tipo de documento |
| `customer_id` | STRING | YES | ID del cliente en el sistema origen de la empresa |
| `customer_account_id` | STRING | YES | ID de cuenta/membresía del cliente |
| `customer_method_identification` | STRING | YES | Cómo se capturó el cliente: `ESCANEADO`, `LLAVE`, `ALT_ID_PHONE`, `ANONYMOUS` |

### Ítem / Producto

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `product_item_id` | STRING | YES | ID del ítem en la transacción |
| `product_item_sku` | STRING | YES | SKU del producto vendido |
| `product_item_description` | STRING | YES | Descripción del producto vendido |
| `product_item_seq` | STRING | YES | Secuencia del ítem en el ticket |
| `product_item_quantity` | STRING | YES | Cantidad vendida del producto |
| `product_item_unit_price_amount` | STRING | YES | Precio unitario de lista |
| `product_item_price_amount` | STRING | YES | Precio de venta por unidad |
| `product_item_gross_amount` | STRING | YES | Monto bruto de la línea (sin descuentos) |
| `product_item_amount` | STRING | YES | **Monto neto de venta** (precio × cantidad, aplicando descuentos) |
| `product_item_original_amount` | STRING | YES | Monto original antes de descuentos. Usado principalmente en Farmacias (025, 048) |
| `product_item_dsct_amount` | STRING | YES | Descuento total aplicado al ítem |
| `product_item_itc_dsct_amount` | STRING | YES | Descuento aplicado por beneficio Club Intercorp |
| `product_item_foh_dsct_amount` | STRING | YES | Descuento por programa FOH (Friends of Homecenters / Promart) |
| `product_item_tax_amount` | STRING | YES | Monto de impuesto (IGV) |
| `product_item_profit` | STRING | YES | Margen de ganancia del ítem |
| `product_item_price_credit_card` | STRING | YES | Precio especial con tarjeta de crédito |
| `product_item_unit_acquisition_price` | STRING | YES | Precio de adquisición unitario |
| `product_item_acquisition_price` | STRING | YES | Precio de adquisición total de la línea |
| `product_item_unit_measure` | STRING | YES | Unidad de medida. Ej: `UND`, `KG`, `LT` |
| `ticket_product_quantity` | STRING | YES | Cantidad total de productos en el ticket |
| `ticket_product_amount` | STRING | YES | Monto total del ticket |
| `ticket_product_gross_amount` | STRING | YES | Monto bruto total del ticket |
| `saving_amount` | STRING | YES | Ahorro total aplicado al ítem |
| `campaign_saving_amount` | STRING | YES | Ahorro por campaña específica |
| `saving_pack_amount` | STRING | YES | Ahorro por oferta de pack/combo |
| `saving_points_amount` | STRING | YES | Ahorro canjeado con puntos |
| `product_retrieve_amount` | STRING | YES | Monto recuperado (devoluciones parciales) |

### Clasificación del producto

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `product_id` | STRING | YES | ID interno del producto en el maestro |
| `product_description` | STRING | YES | Descripción del producto en el maestro |
| `product_group_ID` | STRING | YES | ID del grupo de producto |
| `product_group` | STRING | YES | Grupo de producto (nivel 1 de clasificación) |
| `product_type_id` | STRING | YES | ID del tipo de producto |
| `product_type` | STRING | YES | Tipo de producto |
| `product_category_id` | STRING | YES | ID de categoría |
| `product_category` | STRING | YES | Categoría del producto |
| `product_subcategory_id` | STRING | YES | ID de subcategoría |
| `product_subcategory` | STRING | YES | Subcategoría del producto |
| `product_family_id` | STRING | YES | ID de familia |
| `product_family` | STRING | YES | Familia del producto |
| `product_subfamily_id` | STRING | YES | ID de subfamilia |
| `product_subfamily` | STRING | YES | Subfamilia del producto |
| `product_price_list_id` | STRING | YES | ID de lista de precios |
| `product_price_list` | STRING | YES | Descripción de la lista de precios |
| `product_bundle_id` | STRING | YES | ID del bundle/combo al que pertenece el producto |
| `product_bundle_description` | STRING | YES | Descripción del bundle |
| `product_offering_id` | STRING | YES | ID de oferta comercial |
| `product_offering_description` | STRING | YES | Descripción de la oferta |
| `product_external_group` | STRING | YES | Clasificación externa del producto |

### Campaña y membresía

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `campaign_id` | STRING | YES | ID de la campaña de marketing aplicada |
| `campaign_desc` | STRING | YES | Descripción de la campaña |
| `campaign_type` | STRING | YES | Tipo de campaña |
| `membership_program_id` | STRING | YES | ID del programa de membresía (Club Intercorp, etc.) |
| `membership_program_description` | STRING | YES | Descripción del programa |
| `membership_program_type` | STRING | YES | Tipo de programa de membresía |

### Empleado de atención

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `employee_id` | STRING | YES | ID del empleado que atendió la venta |
| `employee_name` | STRING | YES | Nombre del empleado |
| `employee_job` | STRING | YES | Cargo del empleado |
| `employee_job_department` | STRING | YES | Departamento del empleado |

### Acuerdo comercial

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `aggreement_id` | STRING | YES | ID del acuerdo comercial (proveedor/alianza) |
| `aggreement_description` | STRING | YES | Descripción del acuerdo comercial |

---

## Reglas de datos observadas

1. **Granularidad ítem**: Un registro = una línea de producto en un ticket. Para obtener la cabecera de la venta se debe agrupar por `transaction_id`.
2. **Montos como STRING**: Todos los campos de monto (`product_item_amount`, `product_item_dsct_amount`, etc.) son tipo `STRING` y requieren `CAST AS FLOAT64` para operar numéticamente.
3. **Montos negativos = devoluciones**: Los registros con `product_item_amount < 0` corresponden a devoluciones (`transaction_type` = `DEVOLUCION` o `NOTA DE CREDITO`). Presentes en todas las empresas.
4. **Descuento Club Intercorp (`product_item_itc_dsct_amount`)**: Solo populado significativamente en empresa `010` (SPSA). Las demás empresas no lo usan o está en cero.
5. **Nomenclatura no homologada por empresa**:
   - `transaction_payment_document_type`: SPSA/OE/Promart usan texto completo (`BOLETA`, `FACTURA`), Farmacias usan abreviaturas (`BOL`, `FAC`, `NCR`).
   - `channel`: SPSA usa `VENTA POS -FISICO`, OE/Promart usan `OFFLINE`, Farmacias usan `PRESENCIAL`.
   - `transaction_type`: SPSA usa `VENTA`/`DEVOLUCION`, Farmacias usan `VENTAS`/`NOTA DE CREDITO`.
6. **Monto de referencia por empresa**: Para SPSA/Promart usar `product_item_amount` como monto neto. Para Farmacias (025, 048) usar `product_item_original_amount` como precio de lista y `product_item_amount` como neto efectivo.
7. **`product_item_itc_dsct_amount` vs `product_item_dsct_amount`**: El primero es el descuento exclusivo de Club Intercorp; el segundo es el descuento total (incluye promociones, ofertas del día, etc.).
8. **MASS es el formato con más volumen en SPSA**: Representa el ~50% de los ítems diarios de `010`.
9. **Canales digitales con volumen menor**: Online/App/Delivery representa menos del 5% del total de ítems en todas las empresas.
10. **SKUs únicos**: SPSA tiene ~38,860 SKUs activos diarios vs ~8,000 en Farmacias, reflejando la amplitud de surtido.

---

## Observaciones de calidad de datos

| Observación | Empresas afectadas | Impacto |
|---|---|---|
| `transaction_payment_document_type` con valores no homologados (abreviaturas vs texto) | 025, 048 vs 010, 011, 024 | Requiere normalización para análisis cross-empresa |
| `transaction_type` con valores distintos para el mismo tipo de movimiento (`VENTA` vs `VENTAS`) | 025, 048 | Requiere normalización al filtrar |
| Todos los campos de monto son `STRING`, no `NUMERIC`/`FLOAT` | Todas | Siempre hacer `SAFE_CAST` para evitar errores con valores vacíos o mal formateados |
| `product_item_itc_dsct_amount` no populado en Farmacias (025, 048) | 025, 048 | No usar este campo para análisis de descuento Club en farmacias |
| `channel` con nomenclatura diferente por empresa sin mapeo estándar | Todas | Requiere tabla de equivalencias para análisis de canal unificado |
| `transaction_datetime` es STRING, no TIMESTAMP | Todas | Convertir con `PARSE_DATETIME` para análisis por hora |
| `product_item_quantity` es STRING, no NUMERIC | Todas | Requiere `SAFE_CAST` para sumas |
| Empresa `010` tiene formato de `business_unit` con subformatos (`PLAZA VEA`, `PLAZA VEA SUPER`, `PLAZA VEA EXPRESS`) | 010 | Al agrupar SPSA conviene usar `itc_company_id` + filtrar `business_unit` según análisis |
| Registro `GRL` en `transaction_payment_document_type` de INKAFARMA (116 casos) | 025 | Tipo de comprobante no estándar, revisar origen |
| `COBRO CONCESIONARIO` como `transaction_type` en OE (81 casos) | 011 | Transacciones de concesionarios dentro de tienda, distinto flujo de venta |

---

## Queries de referencia

```sql
-- Venta neta del día por empresa (nivel ticket)
SELECT
  itc_company_id,
  itc_company_name,
  transaction_id,
  id,
  SUM(SAFE_CAST(product_item_amount AS FLOAT64)) AS monto_neto
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
WHERE transaction_date = '2026-01-30'
  AND transaction_type NOT IN ('DEVOLUCION','NOTA DE CREDITO','NOTA DE CRÉDITO')
GROUP BY 1,2,3,4;

-- Descuento Club Intercorp (solo SPSA)
SELECT
  id,
  SUM(SAFE_CAST(product_item_itc_dsct_amount AS FLOAT64)) AS ahorro_club
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
WHERE transaction_date = '2026-01-30'
  AND itc_company_id = '010'
GROUP BY 1;
```
