# Catálogo de Datos — `ba_itc_attr_entertainment`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment`

---

## Descripción

Atributos de **entretenimiento en Cineplanet** del cliente, agregados por mes. Registra métricas de consumo en boletería (entradas) y confitería (snacks/bebidas), fechas de última compra, cine favorito, día de preferencia y cantidades de productos consumidos. Fuente principal para análisis del perfil cinéfilo del cliente Intercorp.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~60M |
| Columnas | 62 |
| Última fecha de proceso | `2026-05-01` |
| Ventanas disponibles | `1m`, `3m`, `6m`, `9m`, `12m` |
| `record_source` | `"ENTRETENIMIENTO CINEPLANET"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp`. **Nota: es el primer campo** |
| `process_date` | DATE | Campo de partición. Primer día del mes |
| `record_source` | STRING | Valor: `"ENTRETENIMIENTO CINEPLANET"` |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

> ⚠️ En esta tabla `id` es el **primer campo** (no `process_date`). Para cruzar con otras tablas: `entertainment.id = retail.id_intercorp`

---

## 2. Monto Promedio de Consumo Total — `mto_prom_con_{Nm}`

Monto promedio por visita (boletería + confitería combinado).

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_prom_con_1m` | FLOAT | Ticket promedio total en Cineplanet en el mes |
| `mto_prom_con_3m` | FLOAT | Ticket promedio total en últimos 3 meses |
| `mto_prom_con_6m` | FLOAT | Ticket promedio total en últimos 6 meses |
| `mto_prom_con_9m` | FLOAT | Ticket promedio total en últimos 9 meses |
| `mto_prom_con_12m` | FLOAT | Ticket promedio total en últimos 12 meses |

---

## 3. Promedio de Boletos por Visita — `cant_prom_boletos_{Nm}`

Número promedio de boletos comprados por visita al cine.

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_prom_boletos_1m` | FLOAT | Promedio de boletos por visita en el mes |
| `cant_prom_boletos_3m` | FLOAT | Promedio en últimos 3 meses |
| `cant_prom_boletos_6m` | FLOAT | Promedio en últimos 6 meses |
| `cant_prom_boletos_9m` | FLOAT | Promedio en últimos 9 meses |
| `cant_prom_boletos_12m` | FLOAT | Promedio en últimos 12 meses |

---

## 4. Monto Promedio por Categoría — Boletería y Confitería

### Boletería (entradas de cine)

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_prom_boleteria_1m` | FLOAT | Ticket promedio en boletería en el mes |
| `mto_prom_boleteria_3m` | FLOAT | Ticket promedio en boletería en 3 meses |
| `mto_prom_boleteria_6m` | FLOAT | Ticket promedio en boletería en 6 meses |
| `mto_prom_boleteria_9m` | FLOAT | Ticket promedio en boletería en 9 meses |
| `mto_prom_boleteria_12m` | FLOAT | Ticket promedio en boletería en 12 meses |

### Confitería (snacks, bebidas, combos)

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_prom_confiteria_1m` | FLOAT | Ticket promedio en confitería en el mes |
| `mto_prom_confiteria_3m` | FLOAT | Ticket promedio en confitería en 3 meses |
| `mto_prom_confiteria_6m` | FLOAT | Ticket promedio en confitería en 6 meses |
| `mto_prom_confiteria_9m` | FLOAT | Ticket promedio en confitería en 9 meses |
| `mto_prom_confiteria_12m` | FLOAT | Ticket promedio en confitería en 12 meses |

---

## 5. Fechas de Última Compra

| Campo | Tipo | Descripción |
|---|---|---|
| `fecha_ultima_compra` | DATE | Fecha de la última compra en Cineplanet (boletería o confitería) |
| `fecha_ultima_compra_boleteria` | DATE | Fecha de la última compra de entradas |
| `fecha_ultima_compra_confiteria` | DATE | Fecha de la última compra en confitería |

---

## 6. Cantidad de Productos — `cant_product_{categoria}_{Nm}`

Número total de productos (ítems) comprados en cada categoría.

### Total (boletería + confitería)

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_product_1m` | FLOAT | Total de productos comprados en el mes |
| `cant_product_3m` | FLOAT | Total en 3 meses |
| `cant_product_6m` | FLOAT | Total en 6 meses |
| `cant_product_9m` | FLOAT | Total en 9 meses |
| `cant_product_12m` | FLOAT | Total en 12 meses |

### Solo Boletería

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_product_bole_1m` | FLOAT | Entradas compradas en el mes |
| `cant_product_bole_3m` | FLOAT | Entradas en 3 meses |
| `cant_product_bole_6m` | FLOAT | Entradas en 6 meses |
| `cant_product_bole_9m` | FLOAT | Entradas en 9 meses |
| `cant_product_bole_12m` | FLOAT | Entradas en 12 meses |

### Solo Confitería

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_product_confi_1m` | FLOAT | Productos de confitería en el mes |
| `cant_product_confi_3m` | FLOAT | En 3 meses |
| `cant_product_confi_6m` | FLOAT | En 6 meses |
| `cant_product_confi_9m` | FLOAT | En 9 meses |
| `cant_product_confi_12m` | FLOAT | En 12 meses |

---

## 7. Preferencias de Asistencia

| Campo | Tipo | Descripción |
|---|---|---|
| `cine_frecuente` | STRING | Nombre del cine Cineplanet más visitado por el cliente. Ej: `"PERÚ-VISTA COMPLEJOS-CP SAN BORJA"` |
| `cant_asistencia_cine_1m` | INTEGER | Número de visitas al cine en el mes |
| `dia_frecuente` | STRING | Día de la semana con más visitas. Ej: `"Sunday"`, `"Wednesday"` |

---

## 8. Número de Transacciones — `cine_numtrx_{categoria}_total_{Nm}`

Conteo de transacciones (tickets de compra) por categoría.

### Boletería

| Campo | Tipo | Descripción |
|---|---|---|
| `cine_numtrx_boleteria_total_1m` | INTEGER | Transacciones de boletería en el mes |
| `cine_numtrx_boleteria_total_3m` | INTEGER | En 3 meses |
| `cine_numtrx_boleteria_total_6m` | INTEGER | En 6 meses |
| `cine_numtrx_boleteria_total_9m` | INTEGER | En 9 meses |
| `cine_numtrx_boleteria_total_12m` | INTEGER | En 12 meses |

### Confitería

| Campo | Tipo | Descripción |
|---|---|---|
| `cine_numtrx_confiteria_total_1m` | INTEGER | Transacciones de confitería en el mes |
| `cine_numtrx_confiteria_total_3m` | INTEGER | En 3 meses |
| `cine_numtrx_confiteria_total_6m` | INTEGER | En 6 meses |
| `cine_numtrx_confiteria_total_9m` | INTEGER | En 9 meses |
| `cine_numtrx_confiteria_total_12m` | INTEGER | En 12 meses |

---

## 9. Monto Total — `cine_mto_trx_{categoria}_total_{Nm}`

Monto total gastado (suma de todas las transacciones) por categoría.

### Boletería

| Campo | Tipo | Descripción |
|---|---|---|
| `cine_mto_trx_boleteria_total_1m` | FLOAT | Monto total en boletería en el mes (S/) |
| `cine_mto_trx_boleteria_total_3m` | FLOAT | Monto total en 3 meses |
| `cine_mto_trx_boleteria_total_6m` | FLOAT | Monto total en 6 meses |
| `cine_mto_trx_boleteria_total_9m` | FLOAT | Monto total en 9 meses |
| `cine_mto_trx_boleteria_total_12m` | FLOAT | Monto total en 12 meses |

### Confitería

| Campo | Tipo | Descripción |
|---|---|---|
| `cine_mto_trx_confiteria_total_1m` | FLOAT | Monto total en confitería en el mes (S/) |
| `cine_mto_trx_confiteria_total_3m` | FLOAT | Monto total en 3 meses |
| `cine_mto_trx_confiteria_total_6m` | FLOAT | Monto total en 6 meses |
| `cine_mto_trx_confiteria_total_9m` | FLOAT | Monto total en 9 meses |
| `cine_mto_trx_confiteria_total_12m` | FLOAT | Monto total en 12 meses |

---

## 10. Ventanas temporales

| Sufijo | Contenido | Sumable entre particiones |
|---|---|---|
| `_1m` | Solo el mes de `process_date` | ✅ Sí |
| `_3m` / `_6m` / `_9m` / `_12m` | Acumulado | ❌ No |

---

## 11. Queries de referencia

```sql
-- Cinéfilos frecuentes mayo 2026 (2+ visitas al mes)
SELECT id, cant_asistencia_cine_1m, cine_frecuente, dia_frecuente,
       mto_prom_con_1m, cine_mto_trx_boleteria_total_1m,
       cine_mto_trx_confiteria_total_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment`
WHERE process_date = '2026-05-01'
  AND cant_asistencia_cine_1m >= 2;

-- Ticket promedio boletería vs confitería por cine
SELECT cine_frecuente,
       AVG(mto_prom_boleteria_6m) AS ticket_prom_boleteria,
       AVG(mto_prom_confiteria_6m) AS ticket_prom_confiteria,
       COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment`
WHERE process_date = '2026-05-01'
  AND cine_frecuente IS NOT NULL
GROUP BY 1 ORDER BY clientes DESC;

-- Distribución por día favorito
SELECT dia_frecuente, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment`
WHERE process_date = '2026-05-01'
  AND dia_frecuente IS NOT NULL
GROUP BY 1 ORDER BY clientes DESC;

-- Cruce entretenimiento + retail: cinéfilos compradores en farmacias
SELECT e.id, e.cant_asistencia_cine_1m, e.cine_frecuente,
       r.far_frecuencia_1m, r.far_mtoprom_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment` e
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` r
  ON e.id = r.id_intercorp AND e.process_date = r.process_date
WHERE e.process_date = '2026-05-01'
  AND e.cant_asistencia_cine_1m > 0
  AND r.far_frecuencia_1m > 0;
```

---

## 12. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **`id` es el primer campo** — no `process_date`. Para cruzar: `entertainment.id = retail.id_intercorp`.
3. **`_1m` es sumable** entre particiones. `_3m` a `_12m` son acumulados.
4. **`cant_product_*`** tipo FLOAT (no INTEGER) — puede reflejar promedios internos del cálculo.
5. **`cine_frecuente`** contiene el nombre completo del complejo. Ej: `"PERÚ-VISTA COMPLEJOS-CP SAN BORJA"`.
6. **`dia_frecuente`** en inglés: `"Sunday"`, `"Monday"`, etc.
7. NULL = sin actividad en esa categoría/ventana.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_entertainment`*
