# Catálogo de Datos — `m_commerce`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_placement`
**Tabla completa:** `intercorp-data-storage-pv.master_placement.m_commerce`

---

## Descripción

Maestro de **comercios afiliados a la red IZIPAY** (itc_company_id = `086`). Registra cada punto de venta (físico o virtual) que opera con terminales POS o pasarela de pago de Izipay. Contiene datos de identificación del comercio, giro comercial (segmento MCC), ubicación geográfica, datos de contacto, banco de pago y coordenadas geocodificadas.

Es la tabla de referencia principal para enriquecer las transacciones de `t_transaction` con el contexto del lugar donde se realizó el pago: tipo de negocio, rubro, ubicación, y si opera con Izi Virtual (pagos QR/app).

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DAY) |
| Clusterizado por | `commerce_id`, `commerce_status_id`, `segment_id`, `payment_bank_id` |
| Total de filas | ~2,943,391 |
| Tamaño lógico | ~1.99 GB |
| Snapshot más reciente | 2026-03-10 |
| Empresa fuente | IZIPAY S.A.C (`itc_company_id = 086`) |
| record_source | AZURE IZIPAY |

---

## Perfil de datos (snapshot 2026-03-10)

| Métrica | Valor |
|---|---|
| Total comercios | 2,943,226 |
| Comercios con estado ACTIVO | 0 (campo `commerce_status` no disponible actualmente) |
| Comercios con Izi Virtual | 2,942,659 (~99.98%) |
| Segmentos MCC distintos | 324 |
| Departamentos cubiertos | 81 |
| Comercios con coordenadas | 612,337 (20.8%) |
| Comercios sin coordenadas | 2,330,889 (79.2%) |

### Top 10 segmentos MCC por número de comercios

| segment_id | Segmento | Comercios |
|---|---|---|
| 5499 | BODEGAS, MINIMERCADOS | 1,134,334 |
| 5812 | RESTAURANTES | 259,720 |
| 5331 | TIENDAS DE ARTICULOS VARIOS | 106,261 |
| 8999 | OTROS SERVICIOS PROFESIONALES | 87,477 |
| 7299 | OTROS SERVICIOS PERSONALES | 76,030 |
| 5621 | ROPA PARA MUJERES, BOUTIQUES | 47,260 |
| 7230 | PELUQUERIAS | 46,291 |
| 5912 | FARMACIAS, BOTICAS | 43,517 |
| 5947 | BAZARES, REGALOS | 42,154 |
| 5999 | OTRAS TIENDAS MINORISTAS | 41,479 |

---

## Glosario de Campos

### 1. Control y proceso

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `process_date` | DATE | **Campo de partición**. Fecha de carga del snapshot | Siempre filtrar por este campo |
| `itc_company_id` | STRING | Código empresa Intercorp | Siempre `086` (IZIPAY) |
| `itc_company_name` | STRING | Nombre empresa | Siempre `IZIPAY` |
| `record_source` | STRING | Aplicativo origen | |
| `load_date` | TIMESTAMP | Fecha de inserción en el modelo | |
| `creation_user` | STRING | Usuario que creó el registro | |
| `hk_diff` | STRING | Hash del registro para detectar cambios | |

### 2. Identificación del comercio

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `commerce_id` | STRING | **Clave primaria**. Código identificador del comercio | Join con `t_transaction.commerce_id` |
| `commerce_name` | STRING | Nombre del comercio / punto de venta | Nombre operativo |
| `business_commercial_name` | STRING | Razón social del comercio | Nombre legal |
| `id` | STRING | Código del dueño/representante en el ecosistema Intercorp | party_id del propietario |
| `id_relationship` | STRING | Código alternativo de la persona en Intercorp | |
| `pos_type` | STRING | Tipo de POS (terminal de cobro) | |
| `izipay_app_telephone` | STRING | Número de celular afiliado a la app Izipay | |
| `flag_izi_virtual` | BOOLEAN | Indica si el comercio tiene activa la opción de Izi Virtual (pagos QR) | ~99.98% de comercios tienen esta bandera activa |

### 3. Estado del comercio

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `commerce_status_id` | STRING | Código del estado del comercio | Parte del clustering |
| `commerce_status` | STRING | Estado: ACTIVO, BLOQUEADO, BAJA, etc. | Valores observados: 9 estados distintos |
| `commerce_distribution_id` | STRING | Código de distribución/segmentación del comercio | |
| `commerce_distribution` | STRING | Nombre de la distribución | |
| `open_commerce_date` | DATE | Fecha de apertura del comercio | |
| `mod_commerce_date` | DATE | Fecha de última modificación | |
| `blocking_date_commerce` | DATE | Fecha de bloqueo (si aplica) | |
| `blocking_reason_commerce` | STRING | Motivo de bloqueo | |
| `last_purchase_date` | DATE | Fecha de la última compra registrada en el comercio | Útil para detectar comercios inactivos |

### 4. Clasificación / Giro comercial

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `segment_id` | STRING | **Código MCC** (Merchant Category Code). Identifica el giro del comercio | Clave para segmentar comportamiento de compra |
| `segment` | STRING | Descripción del giro: BODEGAS, RESTAURANTES, FARMACIAS, etc. | 324 categorías distintas |
| `currency` | STRING | Tipo de moneda de recepción del comercio | |

### 5. Dirección del comercio (punto de atención)

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `commerce_address` | STRING | Dirección del comercio | |
| `commerce_address_street_type` | STRING | Tipo de vía (AV., JR., CALLE, etc.) | |
| `commerce_department_name` | STRING | Departamento | |
| `commerce_province_name` | STRING | Provincia | |
| `commerce_district_name` | STRING | Distrito | |
| `commerce_address_reference` | STRING | Referencia de la dirección | |
| `commerce_ubigeo` | STRING | Código UBIGEO del comercio | |
| `commerce_telephone` | STRING | Teléfono del comercio | |

### 6. Dirección del negocio (oficina/sede principal)

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `business_address` | STRING | Dirección de la sede principal del negocio | Puede diferir de la del comercio |
| `business_address_street_type` | STRING | Tipo de vía de la oficina | |
| `business_department_name` | STRING | Departamento de la sede | |
| `business_province_name` | STRING | Provincia de la sede | |
| `business_district_name` | STRING | Distrito de la sede | |
| `business_address_reference` | STRING | Referencia de la sede | |
| `business_ubigeo` | STRING | UBIGEO de la sede | |
| `business_telephone` | STRING | Teléfono de oficina del negocio | |

### 7. Representante legal

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `legal_representant` | STRING | Nombre del representante legal | |
| `legal_representant_email` | STRING | Correo del representante legal | Dato sensible |

### 8. Medio de pago del comercio

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `payment_bank_id` | STRING | Código del banco donde el comercio recibe los pagos | Parte del clustering |
| `payment_bank` | STRING | Nombre del banco de pago del comercio | |

### 9. Geocodificación (API Google)

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `itc_geocoding_latitude` | FLOAT | Latitud geocodificada por Google API | Solo 20.8% de comercios tienen coordenadas |
| `itc_geocoding_longitude` | FLOAT | Longitud geocodificada por Google API | |
| `itc_geocoding_address` | STRING | Dirección normalizada por Google | |
| `itc_geocoding_tpe` | STRING | Tipo de dirección (Google) | |
| `itc_geocoding_type` | STRING | Tipo de dirección normalizada | |
| `itc_commerce_address` | STRING | Dirección formateada para envío a Google Geocoding | |
| `itc_geocoding_result_id` | STRING | Código de resultado de geocodificación | Indica si dirección es nueva/con calidad/sin calidad/ya referenciada |
| `itc_geocoding_result_description` | STRING | Descripción del resultado de geocodificación | |

---

## Reglas de negocio

1. **Un proceso_date = un snapshot diario.** La tabla acumula snapshots diarios. Para obtener el estado actual usar `WHERE process_date = (SELECT MAX(process_date) FROM ...)`.

2. **MCC (segment_id):** Es el estándar internacional de categorización de comercios. Fundamental para identificar el tipo de negocio donde el cliente realizó su pago. Equivale al código de categoría de la tarjeta. Ej: `5912` = Farmacias, `5812` = Restaurantes, `5814` = Fast food.

3. **Izi Virtual:** El 99.98% de los comercios tienen `flag_izi_virtual = true`, lo que indica que prácticamente toda la red Izipay soporta pagos QR/app.

4. **Comercios vs. negocios:** Un mismo negocio (razón social) puede tener múltiples `commerce_id` si tiene varios puntos de venta.

5. **commerce_id vs. place_id:** En `t_transaction`, `place_id` es siempre NULL; `commerce_id` es el campo de join activo con esta tabla.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Coordenadas incompletas | Solo el 20.8% de comercios tiene `itc_geocoding_latitude`. No es viable un análisis geoespacial completo. |
| `commerce_status = 'ACTIVO'` = 0 | En el snapshot actual (2026-03-10) no hay registros con estado ACTIVO. Verificar si el campo está poblado en snapshots anteriores. |
| Inconsistencia nombre banco | El campo `payment_bank` puede tener variaciones de escritura para un mismo banco (igual que en `t_transaction`). |
| 81 departamentos | El Perú tiene 25 departamentos. Los 81 valores pueden incluir valores nulos, texto libre o errores. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.t_transaction` | `commerce_id` | Enriquecer transacciones con datos del comercio (giro, ubicación) |
| `master_party.iden_itc_party` | `id` → `party_id` | Vincular dueño del comercio con el ecosistema ITC |

---

## Queries de referencia

```sql
-- Estado actual de comercios por segmento
SELECT segment_id, segment, COUNT(*) AS comercios,
  COUNTIF(flag_izi_virtual = true) AS con_izi_virtual,
  COUNTIF(itc_geocoding_latitude IS NOT NULL) AS con_coordenadas
FROM `intercorp-data-storage-pv.master_placement.m_commerce`
WHERE process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_placement.m_commerce`)
GROUP BY 1,2 ORDER BY comercios DESC;

-- Enriquecer transacciones Izipay con giro del comercio
SELECT t.transaction_date, t.id, c.segment_id, c.segment,
  c.commerce_district_name, t.product_item_gross_amount
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
LEFT JOIN `intercorp-data-storage-pv.master_placement.m_commerce` c
  ON t.commerce_id = c.commerce_id
  AND c.process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_placement.m_commerce`)
WHERE t.itc_process_date = '2026-01-30'
  AND t.transaction_date = t.itc_process_date;

-- Identificar segmentos clave para perfilamiento de clientes
-- (ej: clientes con gastos en farmacias/salud)
SELECT id, SUM(product_item_gross_amount) AS monto_farmacias
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
JOIN `intercorp-data-storage-pv.master_placement.m_commerce` c
  ON t.commerce_id = c.commerce_id
  AND c.process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_placement.m_commerce`)
WHERE t.itc_process_date BETWEEN '2025-01-01' AND '2026-01-01'
  AND t.transaction_date = t.itc_process_date
  AND c.segment_id IN ('5912', '5047', '5122')  -- Farmacias y salud
GROUP BY 1;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_placement.m_commerce`*
