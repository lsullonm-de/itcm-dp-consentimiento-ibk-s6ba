# Catálogo de Datos — `t_payment`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_transaction`
**Tabla completa:** `intercorp-data-storage-pv.master_transaction.t_payment`

---

## Descripción

Tabla de **detalle de medios de pago** asociados a las transacciones de venta retail. Para cada pago registra: el método de pago utilizado (tarjeta, QR, efectivo, etc.), el monto pagado, la clase de pago (`payment_tender_class`), el canal, programa de membresía, y datos de autorización del pago.

Se relaciona con `t_retail_transaction` vía `transaction_id` — cada fila en `t_payment` representa **un medio de pago** usado en una transacción de venta. Una misma transacción puede tener múltiples filas (pago mixto: parte en tarjeta, parte en efectivo).

Cubre las mismas empresas retail que `t_retail_transaction`: SPSA (010), Inkafarma (025), Mifarma (048), Promart (024) y Tiendas Peruanas (011).

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `payment_date` (DAY) |
| Clusterizado | NO |
| Total de filas | ~2,827,787,142 (~2.83 B) |
| Número de columnas | 75 |
| Tamaño lógico | ~928 GB |
| Tamaño físico | ~44 GB (alta compresión) |
| Particiones | 2,991 |
| Última fecha disponible | 2026-03-09 |
| Primera fecha disponible | 2025-01-01 (en BigQuery activo) |
| Frecuencia | Diaria |
| Fuente | `MATILLION-INTERCORP` |
| Ubicación | US |

---

## Volumen por empresa y mes (muestra: 3 días/mes, Feb 2025–Ene 2026)

| Mes | Empresa | Registros (~3 días) | Clientes únicos |
|---|---|---|---|
| 2026-01 | 010 SPSA | 2,725,066 | 553,556 |
| 2026-01 | 025 Inkafarma | 1,061,776 | 732,249 |
| 2026-01 | 048 Mifarma | 817,430 | 536,873 |
| 2026-01 | 024 Promart | 97,587 | 73,057 |
| 2026-01 | 011 Tiendas Peruanas | 61,158 | 48,299 |
| 2025-12 | 010 SPSA | 3,391,045 | 751,598 |
| 2025-12 | 025 Inkafarma | 1,092,490 | 751,065 |
| 2025-12 | 048 Mifarma | 834,621 | 533,309 |

> **Snapshot de un día (2026-01-30):** 1,632,232 filas · 680,479 clientes únicos · 5 empresas.

---

## Glosario de Campos

### 1. Identificadores y control

| Campo | Tipo | Descripción |
|---|---|---|
| `payment_date` | DATE | **Campo de partición**. Fecha en que se realizó el pago |
| `payment_id` | STRING | Identificador único del pago (nunca NULL) |
| `transaction_id` | STRING | ID de la transacción de venta origen — **clave de join con `t_retail_transaction`** |
| `id` | STRING | Documento de identidad del cliente (DNI/CE). 354 NULLs (~0.02%) |
| `customer_id` | STRING | ID interno del cliente en el sistema origen. 38.2% NULL |
| `itc_company_id` | STRING | Código de la empresa Intercorp (3 dígitos) |
| `itc_company_name` | STRING | Nombre de la empresa (ej: `INKAFARMA`, `SUPERMERCADOS PERUANOS`) |
| `process_date` | DATE | Fecha de procesamiento ETL — suele llegar con ~13 días de rezago respecto a `payment_date` |
| `load_date` | TIMESTAMP | Timestamp de carga en BigQuery |
| `record_source` | STRING | Siempre `MATILLION-INTERCORP` |
| `creation_user` | STRING | Service account de ETL |

### 2. Monto y moneda

| Campo | Tipo | Descripción |
|---|---|---|
| `payment_amount` | FLOAT64 | **Monto del pago** (en la moneda indicada). Siempre poblado (0% NULL) |
| `payment_applied` | FLOAT64 | Monto efectivamente aplicado (puede diferir de `payment_amount` en pagos parciales) |
| `currency` | STRING | Descripción de la moneda (ej: `SOLES`) |
| `currency_id` | STRING | Código de moneda (ej: `01` = Soles) |
| `cash_back_amount` | FLOAT64 | Monto de cashback recibido |
| `cash_back_amount_foreign_currency` | FLOAT64 | Cashback en moneda extranjera |
| `foreign_currency_amount` | STRING | Monto en moneda extranjera |
| `exchange_rate` | STRING | Tipo de cambio aplicado |
| `tip_amount` | FLOAT64 | Propina incluida en el pago |

### 3. Método y tipo de pago

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `payment_method` | STRING | Método de pago (ej: `AGORA QR`, `TARJETA`, `EFECTIVO`) | 0% NULL |
| `payment_method_id` | STRING | Código del método de pago | — |
| `payment_tender_class` | STRING | Clase del medio de pago (ej: `CREDIT/DEBIT CARD`, `CASH`) | 0% NULL |
| `payment_tender_type` | STRING | Tipo de tender (detalle de la clase) | 75.7% NULL |
| `payment_type` | STRING | Tipo de pago general | **100% NULL** |
| `payment_type_id` | STRING | Código del tipo de pago | — |
| `payment_status` | STRING | Estado del pago (`APROBADO`, `RECHAZADO`) | — |
| `flag_change` | STRING | Indica si hubo vuelto/cambio en el pago | — |
| `flag_co_payment` | STRING | Indica si es un co-pago (pago compartido) | — |
| `flag_tender_authorization_permission` | STRING | Permiso de autorización del medio de pago | — |

### 4. Datos de banco y tarjeta

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `payment_bank` | STRING | Banco del medio de pago | **100% NULL** |
| `payment_bank_id` | STRING | Código del banco | **100% NULL** |
| `payment_media_brand_identifier` | STRING | Identificador de la marca del medio (Visa, MC, etc.) | **100% NULL** |
| `payment_authorization_id` | STRING | Código de autorización del pago | 73.3% NULL |
| `payment_authorization_date` | STRING | Fecha de autorización del pago | — |
| `payment_authorization_provider` | STRING | Proveedor de la autorización (ej: VISA, Mastercard) | — |
| `payment_authorization_provider_id` | STRING | Código del proveedor de autorización | — |
| `bin_card_id` | STRING | BIN de la tarjeta — **join con `c_bin_card`** para obtener banco emisor y marca | — |
| `customer_account_id` | STRING | ID de cuenta del cliente en el banco | — |
| `customer_account_number` | STRING | Número de cuenta del cliente | — |
| `address_verification_code` | STRING | Código AVS (verificación de dirección para e-commerce) | — |

### 5. Datos de pago programado y acuerdo

| Campo | Tipo | Descripción |
|---|---|---|
| `payment_due_date` | STRING | Fecha de vencimiento del pago |
| `payment_datetime` | STRING | Fecha y hora del pago (STRING, no TIMESTAMP) |
| `payment_schedule_type` | STRING | Tipo de programación del pago |
| `payment_schedule_type_id` | STRING | Código del tipo de programación |
| `payment_reason` | STRING | Razón del pago |
| `payment_document_id` | STRING | ID del documento de pago (boleta/factura) |
| `payment_document_type` | STRING | Tipo de documento del pago |
| `aggreement_id` | STRING | Código del acuerdo comercial asociado |
| `aggreement_category` | STRING | Categoría del acuerdo comercial |
| `aggreement_description` | STRING | Descripción del acuerdo comercial |
| `aggreement_start_date` | STRING | Fecha de inicio del acuerdo |
| `aggreement_end_date` | STRING | Fecha de fin del acuerdo |

### 6. Membresía y fidelización

| Campo | Tipo | Descripción |
|---|---|---|
| `membership_program_id` | STRING | Código del programa de membresía (ej: `04` = INKACLUB) |
| `membership_program_description` | STRING | Nombre del programa de membresía (ej: `INKACLUB`) |
| `membership_program_type` | STRING | Tipo de membresía |

### 7. Canal y lugar

| Campo | Tipo | Descripción |
|---|---|---|
| `channel` | STRING | Descripción del canal (ej: `PRESENCIAL`) |
| `channel_id` | STRING | Código del canal (ej: `01` = PRESENCIAL) |
| `place_id` | STRING | Código del punto de venta |
| `place_description` | STRING | Nombre del punto de venta |
| `pos_store_number` | STRING | Número de tienda en el sistema POS |
| `pos_tender_id` | STRING | ID del tender en el POS |
| `pos_terminal_id` | STRING | ID del terminal POS |
| `pos_transaction_flow_id` | STRING | ID del flujo de transacción en POS |

### 8. Producto y unidad de negocio

| Campo | Tipo | Descripción |
|---|---|---|
| `product_item_id` | STRING | ID del ítem de producto asociado al pago |
| `product_item_seq` | STRING | Secuencia del ítem en la transacción |
| `business_unit` | STRING | Descripción de la unidad de negocio |
| `business_unit_id` | STRING | Código de la unidad de negocio |

### 9. Empleado (datos de colaborador)

| Campo | Tipo | Descripción |
|---|---|---|
| `employee_id` | STRING | ID del empleado (en compras de colaboradores) |
| `employee_job` | STRING | Puesto del empleado |
| `employee_job_department` | STRING | Departamento del empleado |
| `employee_name` | STRING | Nombre del empleado |

### 10. Calidad de datos

| Campo | Tipo | Descripción |
|---|---|---|
| `dq_flag_ind` | BOOL | Flag de calidad de datos |
| `dq_control_msg` | STRING | Mensaje de error de calidad |
| `dq_config_id` | STRING | Configuración de calidad aplicada |
| `identification_document_type` | STRING | Tipo de documento del cliente |
| `identification_document_type_id` | STRING | Código del tipo de documento |

---

## Relación con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `t_retail_transaction` | `transaction_id` = `t_retail_transaction.transaction_id` | Obtener detalle de medio de pago de cada venta retail |
| `c_bin_card` | `bin_card_id` = `c_bin_card.bin_card_id` | Identificar banco emisor, marca y tipo de tarjeta |
| `c_entidades_financieras` | Vía `c_bin_card.bank_name` | Normalizar nombre de banco emisor |
| `c_gamas_tarjetas_noibk` | Vía `c_bin_card` banco+marca | Clasificar gama de tarjeta no-IBK |

---

## Empresas cubiertas

| itc_company_id | Empresa | Volumen diario aprox. |
|---|---|---|
| 010 | SUPERMERCADOS PERUANOS (SPSA) | ~1M registros/día |
| 025 | INKAFARMA | ~350K registros/día |
| 048 | MIFARMA | ~270K registros/día |
| 024 | PROMART | ~32K registros/día |
| 011 | TIENDAS PERUANAS (OE) | ~24K registros/día |

---

## Reglas de negocio

1. **Particionado por `payment_date`** — SIEMPRE filtrar por este campo. Sin filtro se escanean ~928 GB (2.83B filas).

2. **Un `transaction_id` puede tener N filas en `t_payment`**: Representa pagos mixtos (ej: parte en tarjeta + parte en efectivo). Hacer `COUNT(DISTINCT transaction_id)` para contar ventas únicas.

3. **`payment_tender_class`** es el campo más confiable para clasificar el medio de pago (0% NULL). Valores: `CREDIT/DEBIT CARD`, `CASH`, `AGORA QR`, etc.

4. **`payment_bank`, `payment_type`, `payment_media_brand_identifier` son siempre NULL** — no usar para segmentación. Para identificar banco emisor usar `bin_card_id` → `c_bin_card`.

5. **`process_date` vs `payment_date`**: El ETL carga los datos con ~13 días de rezago. `process_date` es la fecha de disponibilidad en BigQuery, `payment_date` es la fecha real del pago.

6. **Membresía por empresa**:
   - INKAFARMA (025): `membership_program_description = 'INKACLUB'`, `membership_program_id = '04'`
   - Otras empresas pueden tener distintos programas de fidelización

7. **`id` field vs `customer_id`**: Usar `id` (DNI/CE) como clave de cliente. `customer_id` tiene 38.2% de NULLs y es el ID interno del sistema origen — menos confiable para cruce entre empresas.

8. **Pago con tarjeta IBK**: `bin_card_id` IN (BINs de Interbank en `c_bin_card`) identifica pagos realizados con tarjeta Interbank.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `payment_type` | **100%** | No usar. Campo no poblado en el modelo actual. |
| `payment_bank` | **100%** | No usar. Identificar banco vía `bin_card_id` → `c_bin_card`. |
| `payment_media_brand_identifier` | **100%** | No usar. |
| `payment_tender_type` | 75.7% | Baja cobertura — usar `payment_tender_class` como alternativa. |
| `payment_authorization_id` | 73.3% | Solo poblado para pagos con tarjeta que requieren autorización. |
| `customer_id` | 38.2% | ID interno del sistema origen — preferir `id` (DNI) para JOINs. |
| `id` | ~0.02% | Muy pocos NULLs — confiable como clave de cliente. |
| `payment_datetime` | — | Tipo STRING (no TIMESTAMP) — convertir con `PARSE_DATETIME` para cálculos. |
| `aggreement_*` campos | Alta | Mayormente NULL salvo para pagos con acuerdos comerciales específicos. |
| Rezago ETL | 13 días | Los datos de un `payment_date` estarán disponibles ~13 días después. |

---

## Queries de referencia

```sql
-- Distribución de medios de pago por empresa (un día específico)
SELECT itc_company_id, payment_tender_class, payment_method,
  COUNT(*) as pagos, ROUND(SUM(payment_amount), 2) as monto_total
FROM `intercorp-data-storage-pv.master_transaction.t_payment`
WHERE payment_date = '2026-01-30'
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC;

-- Pagos con tarjeta IBK (cruce con c_bin_card)
SELECT p.id, p.payment_amount, p.payment_tender_class, b.bank_name, b.card_brand
FROM `intercorp-data-storage-pv.master_transaction.t_payment` p
JOIN `intercorp-data-storage-pv.master_transaction.c_bin_card` b
  ON p.bin_card_id = b.bin_card_id
WHERE p.payment_date = '2026-01-30'
  AND b.bank_name LIKE '%INTERBANK%';

-- Pagos mixtos: transacciones con más de un medio de pago
SELECT transaction_id, COUNT(*) as medios_pago,
  STRING_AGG(payment_tender_class, ' + ' ORDER BY payment_tender_class) as combinacion
FROM `intercorp-data-storage-pv.master_transaction.t_payment`
WHERE payment_date = '2026-01-30'
  AND itc_company_id = '010'
GROUP BY 1
HAVING medios_pago > 1
ORDER BY medios_pago DESC
LIMIT 100;

-- Monto promedio de pago con tarjeta por empresa y mes
WITH sample AS (
  SELECT DATE_TRUNC(payment_date, MONTH) as mes, itc_company_id,
    payment_amount, payment_tender_class
  FROM `intercorp-data-storage-pv.master_transaction.t_payment`
  WHERE payment_date BETWEEN '2025-02-01' AND '2026-01-31'
    AND payment_tender_class = 'CREDIT/DEBIT CARD'
)
SELECT mes, itc_company_id,
  COUNT(*) as pagos_tarjeta,
  ROUND(AVG(payment_amount), 2) as ticket_prom,
  ROUND(SUM(payment_amount), 0) as monto_total
FROM sample
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- Clientes que pagan principalmente con tarjeta no-IBK (cross-sell IBK)
SELECT p.id,
  COUNT(CASE WHEN b.bank_name LIKE '%INTERBANK%' THEN 1 END) as pagos_ibk,
  COUNT(*) as total_pagos
FROM `intercorp-data-storage-pv.master_transaction.t_payment` p
LEFT JOIN `intercorp-data-storage-pv.master_transaction.c_bin_card` b
  ON p.bin_card_id = b.bin_card_id
WHERE p.payment_date BETWEEN '2026-01-01' AND '2026-01-31'
  AND p.payment_tender_class = 'CREDIT/DEBIT CARD'
  AND p.id IS NOT NULL
GROUP BY 1
HAVING pagos_ibk = 0 AND total_pagos >= 3;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_transaction.t_payment`*
