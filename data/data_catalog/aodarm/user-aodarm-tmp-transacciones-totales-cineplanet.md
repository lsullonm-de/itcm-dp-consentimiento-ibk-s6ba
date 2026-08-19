# Catálogo de Datos — `tmp_transacciones_totales_cineplanet`

**Proyecto:** `int-advanced-analytics-01`
**Dataset:** `aodarm`
**Tabla completa:** `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet`
**Prefijo de archivo:** `user_aodarm_` (tabla en esquema de usuario)

---

## Descripción

Tabla de **transacciones totales de Cineplanet** preconstruida en el esquema de usuario `aodarm`. Contiene el histórico de un año completo (Nov 2024 – Oct 2025) de todas las transacciones de CINEPLANET (empresa 013), tanto de boletería (entradas de cine) como de dulcería (confitería/snacks).

Es una vista consolidada derivada de `intercorp-data-storage-pv.master_transaction.t_experience_transaction` filtrada para `itc_company_id = '013'`, con un campo adicional `tipo_venta` que clasifica el tipo de transacción.

> **⚠️ Campo `id` = `party_id`**: A diferencia de la tabla fuente (`t_experience_transaction`) donde `id` es el DNI, aquí **`id` es el identificador interno Intercorp (`party_id`)**. Para obtener el DNI, hacer JOIN con `iden_itc_party`.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | **NO** |
| Clusterizado | NO |
| Total de filas | 24,485,759 (~24.5M) |
| Número de columnas | 54 |
| Tamaño lógico | ~11 GB |
| Tamaño físico | ~629 MB |
| Rango de `transaction_date` | 2024-11-01 a 2025-10-31 (365 días) |
| Empresa | Solo CINEPLANET (`itc_company_id = '013'`) |
| Última actualización | Dic 2025 / Feb 2026 (loads parciales) |
| Fuente | `master_transaction.t_experience_transaction` |

---

## Volumen por mes (muestra: 3 días/mes, Feb–Oct 2025)

| Mes | Registros (~3 días) | party_ids únicos |
|---|---|---|
| 2025-10 | 171,791 | 57,890 |
| 2025-09 | 208,342 | 62,853 |
| 2025-08 | 261,779 | 77,797 |
| 2025-07 | 228,179 | 60,677 |
| 2025-06 | 245,546 | 73,391 |
| 2025-05 | 365,809 | 94,988 |
| 2025-04 | 170,395 | 54,131 |
| 2025-03 | 112,365 | 34,978 |
| 2025-02 | 181,048 | 52,458 |

> **Total:** 24.5M filas · 1,683,712 party_ids únicos identificados · 28.6% de filas sin `id`

## Distribución por `business_unit` (Ago–Oct 2025)

| business_unit | Registros | party_ids | Precio promedio |
|---|---|---|---|
| `DULCERÍA` | 3,440,394 | 652,545 | S/. 19.79 |
| `BOLETERÍA` | 2,618,057 | 829,300 | S/. 21.83 |

---

## Glosario de Campos

La tabla tiene 54 columnas — estructura idéntica a `t_experience_transaction` con el campo adicional `tipo_venta`.

### 1. Identificadores

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `transaction_date` | DATE | Fecha de la transacción | 0% NULL |
| `transaction_id` | STRING | ID único de la transacción. **0% NULL** | 0% NULL |
| `transaction_ticket` | STRING | Número de ticket/recibo | — |
| `id` | STRING | **`party_id` de Intercorp** (NO es DNI). Puede ser NULL para clientes no identificados | **28.6% NULL** |
| `itc_company_id` | STRING | Siempre `"013"` (CINEPLANET) | Constante |
| `itc_company_name` | STRING | Siempre `"CINEPLANET"` | Constante |
| `process_date` | DATE | Fecha de procesamiento ETL | 0% NULL |
| `load_date` | TIMESTAMP | Timestamp de carga | 0% NULL |
| `record_source` | STRING | Siempre `"master_transaction"` | Constante |
| `creation_user` | STRING | Service account ETL | Constante |
| `country_id` | STRING | Siempre `"51"` (Perú) | Constante |

### 2. Identificación del cliente

| Campo | Tipo | Descripción |
|---|---|---|
| `identification_document_type_id` | STRING | Código del tipo de documento (`01`=DNI, `02`=CE, `04`=PASAPORTE, `OTROS`) |
| `identification_document_type` | STRING | Descripción del tipo de documento (`DNI`, `CE`, `OTROS`) |
| `flag_customer_identified` | STRING | `"true"` = cliente identificado con documento válido, `"false"` = anónimo |

### 3. Canal y lugar de venta

| Campo | Tipo | Descripción |
|---|---|---|
| `channel_id` | STRING | Código del canal (`01`=PRESENCIAL, `02`=NO PRESENCIAL). Mayormente NULL. |
| `channel_description` | STRING | Descripción del canal. Mayormente NULL en esta tabla. |
| `place_id` | STRING | Código del cine (formato `país-fuente-sucursal`). Ej: `"001-001-02"` |
| `place_description` | STRING | Nombre del cine. Ej: `"PERÚ-VISTA COMPLEJOS-CP CENTRO"` |
| `business_unit` | STRING | Unidad de negocio: **`BOLETERÍA`** (entradas) o **`DULCERÍA`** (confitería) |

### 4. Producto

| Campo | Tipo | Descripción |
|---|---|---|
| `product_id` | STRING | Código del producto (`"NO APLICA"` para ítems de servicio/refill) |
| `product_item_id` | STRING | ID del ítem en la transacción |
| `product_item_sku` | STRING | SKU del ítem (generalmente igual a `product_item_id`) |
| `product_item_description` | STRING | Descripción del ítem. Ej: `"Loyalty Cumpleaños"`, `"Entrada adulto 2D"`, `"Combo Duo"` |
| `product_description` | STRING | Descripción de la función de cine. Formato: `"SALA X;Película;Fecha;Duración;Asiento"` |
| `product_item_quantity` | FLOAT64 | Cantidad del ítem (generalmente 1.0) |
| `product_item_seq` | INT64 | Correlativo del ítem dentro de la transacción (1, 2, 3...) |
| `master_item` | STRING | ID del producto en catálogo jerárquico (mayormente NULL) |
| `unique_id` | STRING | ID de vínculo entre productos (mayormente NULL) |
| `question_id` | STRING | ID del producto dentro de la transacción (mayormente NULL) |
| `brand_id` | STRING | Código de marca de la unidad de negocio (mayormente NULL) |
| `brand_name` | STRING | Nombre de la marca (mayormente NULL en Cineplanet) |

### 5. Montos

| Campo | Tipo | Descripción |
|---|---|---|
| `product_item_unit_price_amount` | FLOAT64 | Precio unitario de venta (con IGV) |
| `product_item_unit_full_price_amount` | FLOAT64 | Precio base incluyendo subsidio |
| `product_item_gross_amount` | FLOAT64 | **Monto bruto del ítem** (precio - descuentos, sin subsidio). Campo principal para análisis de ventas |
| `product_item_gross_full_amount` | FLOAT64 | Monto bruto incluyendo subsidio |
| `product_item_dsct_amount` | FLOAT64 | Monto de descuento aplicado al ítem |
| `product_item_tax_amount` | FLOAT64 | IGV del ítem |
| `product_item_rc_amount` | FLOAT64 | Recarga al consumo |
| `product_item_subsidy` | FLOAT64 | Monto subsidiado (ej: beneficio de cumpleaños = 0 soles) |
| `product_item_subsidy_provider` | STRING | Entidad que otorga el subsidio |
| `transaction_digital_comission` | FLOAT64 | Comisión digital (compras online) |

### 6. Tipo de transacción y venta

| Campo | Tipo | Descripción | Valores observados |
|---|---|---|---|
| `transaction_type` | STRING | Tipo de la transacción | `"VENTA"`, `"ANULACION"` |
| `flag_voided` | STRING | `"true"` si la transacción fue anulada/revertida | `"true"` / `"false"` |
| `tipo_venta` | STRING | **Campo adicional (no en `t_experience_transaction`)** — Clasifica el tipo de venta | `"VENTA IDENTIFICADA"`, `"VENTA ANÓNIMA"` |
| `flag_load_type` | STRING | `"AUTOMATICO"` = carga normal, `"MANUAL"` = subsanación | — |

### 7. Promociones

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_promotion` | INT64 | `1` = ítem con promoción activa |
| `promotion_id` | STRING | ID de la promoción aplicada |
| `sale_type_id` | STRING | Código del medio de venta |
| `sale_type` | STRING | Descripción del medio de venta |

### 8. Campos de fecha adicionales

| Campo | Tipo | Descripción |
|---|---|---|
| `transaction_datetime` | STRING | Fecha y hora en formato STRING — convertir para análisis por hora |
| `transaction_hour` | STRING | Hora de la transacción |
| `transaction_date_number` | STRING | Fecha en formato `YYYYMMDD` |
| `transaction_month` | STRING | Mes de la transacción (1–12 como STRING) |
| `transaction_year` | STRING | Año de la transacción como STRING |

---

## Diferencias clave con `t_experience_transaction`

| Característica | `t_experience_transaction` (fuente prod) | `tmp_transacciones_totales_cineplanet` (usuario) |
|---|---|---|
| Proyecto | `intercorp-data-storage-pv` | `int-advanced-analytics-01` |
| Partición | `transaction_date` (DAY) | **Sin partición** |
| Clustering | `process_date, itc_company_id, business_unit` | Ninguno |
| Empresas | 013 + 033 | Solo 013 (CINEPLANET) |
| Campo `id` | DNI / CE del cliente | **`party_id` de Intercorp** |
| Campo `tipo_venta` | No existe | Sí (`"VENTA IDENTIFICADA"` / `"VENTA ANÓNIMA"`) |
| Período cubierto | Desde 2025-01-01 activo | Nov 2024 – Oct 2025 (1 año fijo) |
| Actualización | Diaria | **Estática** (carga puntual) |

---

## Reglas de negocio

1. **`id` = `party_id`** — NO es DNI. Para cruzar con tablas de atributos (que usan `id` = DNI), hacer JOIN con `iden_itc_party`:
   ```sql
   JOIN `intercorp-data-storage-pv.master_party.iden_itc_party` i
     ON t.id = i.party_id AND i.itc_company_id = '013'
   ```

2. **Sin partición** — la tabla tiene 11 GB lógicos. Filtrar siempre por `transaction_date` o `business_unit` para evitar scans costosos.

3. **28.6% de filas sin `id`**: Transacciones anónimas (cliente no identificado). Para análisis de cliente, filtrar `WHERE id IS NOT NULL AND flag_customer_identified = 'true'`.

4. **`product_item_gross_amount = 0`**: Entradas de cortesía, beneficios de cumpleaños, o subsidios totales. Excluir del análisis de ingresos si se quiere solo ventas pagadas:
   ```sql
   WHERE product_item_gross_amount > 0
   ```

5. **`flag_voided = 'true'`**: Excluir anulaciones en análisis de ventas. `WHERE flag_voided = 'false'`.

6. **`tipo_venta`** es el campo que diferencia esta tabla de la fuente:
   - `"VENTA IDENTIFICADA"` → cliente con party_id conocido
   - `"VENTA ANÓNIMA"` → cliente sin identificación

7. **Boletería vs. Dulcería**:
   - `business_unit = 'BOLETERÍA'` → análisis de asistencia, películas, frecuencia de visita
   - `business_unit = 'DULCERÍA'` → análisis de gasto complementario (snacks/bebidas)

8. **`product_description` contiene información de la función**: En boletería, el formato es `"SALA;Película;Fecha hora;Duración;Asiento"` — parseable para obtener película, sala, y horario.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| `id` = `party_id` | Diferencia crítica con otras tablas. Confirmar siempre antes de hacer JOINs directos por `id`. |
| **Sin partición** | Consultar con filtros de fecha obligatorios (`transaction_date`). Sin filtro: scan de 11 GB. |
| Tabla estática | Cubre Nov 2024–Oct 2025. Para datos más recientes usar `t_experience_transaction` en prod. |
| 28.6% `id` NULL | Transacciones de clientes no identificados — no se puede asociar a un `party_id`. |
| `channel_description` NULL | El canal no se reporta consistentemente en esta fuente. |
| `product_item_gross_amount = 0` | Frecuente en ítems de beneficio/cortesía — no indica error. |

---

## Queries de referencia

```sql
-- Asistencia mensual a Cineplanet (clientes identificados, boletería)
SELECT DATE_TRUNC(transaction_date, MONTH) as mes,
  COUNT(DISTINCT transaction_id) as tickets,
  COUNT(DISTINCT id) as party_ids,
  ROUND(SUM(product_item_gross_amount), 2) as monto_boleteria
FROM `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet`
WHERE business_unit = 'BOLETERÍA'
  AND flag_voided = 'false'
  AND product_item_gross_amount > 0
  AND id IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- Top clientes por frecuencia de visita (party_id + DNI)
SELECT t.id AS party_id, i.id AS dni,
  COUNT(DISTINCT t.transaction_ticket) AS visitas,
  ROUND(SUM(t.product_item_gross_amount), 2) AS gasto_total
FROM `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet` t
JOIN `intercorp-data-storage-pv.master_party.iden_itc_party` i
  ON t.id = i.party_id AND i.itc_company_id = '013'
WHERE t.business_unit = 'BOLETERÍA'
  AND t.flag_voided = 'false'
  AND t.id IS NOT NULL
GROUP BY 1, 2
ORDER BY visitas DESC
LIMIT 100;

-- Ticket promedio por cine y mes
SELECT place_description, DATE_TRUNC(transaction_date, MONTH) as mes,
  COUNT(DISTINCT transaction_ticket) as tickets,
  ROUND(SUM(product_item_gross_amount) / COUNT(DISTINCT transaction_ticket), 2) as ticket_prom
FROM `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet`
WHERE flag_voided = 'false' AND product_item_gross_amount > 0
GROUP BY 1, 2 ORDER BY 2 DESC, 3 DESC;

-- Ventas identificadas vs. anónimas por mes
SELECT DATE_TRUNC(transaction_date, MONTH) as mes, tipo_venta,
  COUNT(DISTINCT transaction_ticket) as tickets,
  ROUND(SUM(product_item_gross_amount), 2) as monto
FROM `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet`
WHERE flag_voided = 'false' AND product_item_gross_amount > 0
GROUP BY 1, 2 ORDER BY 1, 2;

-- Clientes que compraron boletería Y dulcería (ticket completo)
SELECT id,
  SUM(CASE WHEN business_unit = 'BOLETERÍA' THEN product_item_gross_amount ELSE 0 END) AS gasto_boleteria,
  SUM(CASE WHEN business_unit = 'DULCERÍA' THEN product_item_gross_amount ELSE 0 END) AS gasto_dulceria
FROM `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet`
WHERE flag_voided = 'false' AND id IS NOT NULL
GROUP BY 1
HAVING gasto_boleteria > 0 AND gasto_dulceria > 0
ORDER BY gasto_boleteria + gasto_dulceria DESC;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `int-advanced-analytics-01.aodarm.tmp_transacciones_totales_cineplanet` — Tabla de usuario (esquema `aodarm`) — Carga estática Nov 2024–Oct 2025*
