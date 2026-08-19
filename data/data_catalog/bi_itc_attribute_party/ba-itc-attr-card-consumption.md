# Catálogo de Datos — `ba_itc_attr_card_consumption`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`

---

## Descripción

Atributos de **consumo con tarjeta en retail y POS** del cliente, agregados por mes. Registra montos y cantidades de transacciones segmentados por:
- **Esencialidad del producto**: esencial vs. no esencial
- **Banco emisor**: Interbank (IBK) vs. otros bancos (noIBK)
- **Tipo de tarjeta**: débito (TD) vs. crédito (TC)
- **Gama de tarjeta de crédito**: clásica, oro, platinum, signature, infinite
- **Contexto**: retail POS general vs. supermercados específicamente

Fuente principal para análisis de comportamiento de pago con tarjeta en el ecosistema retail ITC.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la información del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~364M |
| Columnas | 74 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |
| `record_source` | `"Bases Transaccionales"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente. Campo clustered. ⚠️ Usa `id`, no `id_intercorp` |
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `load_date` | TIMESTAMP | Fecha y hora de carga del proceso |
| `record_source` | STRING | Origen del registro. Valor: `"Bases Transaccionales"` |
| `creation_user` | STRING | SA que ejecutó la carga |

> ⚠️ Para cruzar con `ba_itc_attr_retail`: `card.id = retail.id_intercorp`

---

## 2. Naming Convention

Todas las métricas siguen el patrón:

```
{metrica}_{esencialidad}_{banco}_{tipo_tarjeta}[_{gama}][_{contexto}]_1m
```

| Dimensión | Valores | Descripción |
|---|---|---|
| `metrica` | `mto`, `cant_trx` | Monto (S/) o cantidad de transacciones |
| `esencialidad` | `escencial`, `no_escencial`, `total` | Clasificación del producto comprado |
| `banco` | `noibk`, *(sin prefijo = todos)* | `noibk` = bancos distintos a Interbank |
| `tipo_tarjeta` | `td`, `tc`, `td_efectivo` | Débito, crédito, o débito+efectivo |
| `gama` | `clasica`, `oro`, `platinum`, `signature`, `infinite` | Gama de TC (solo para TC) |
| `contexto` | `retail_pos`, `supermercado_retail_pos` | POS retail general o supermercados |
| `ventana` | `1m` | Solo ventana de 1 mes (mes del `process_date`) |

**Claves de lectura:**
- **`noibk`**: tarjetas de bancos distintos a Interbank (BBVA, Scotiabank, BCP, etc.)
- **Sin `noibk`**: todos los bancos incluido Interbank
- **`escencial`/`no_escencial`**: basado en la clasificación de `c_productos_escenciales_retail`
- **`td_efectivo`**: agrupa débito + efectivo como canal de pago no-crédito

---

## 3. Métricas de Monto — `mto_*_1m` (FLOAT)

### Monto total por tipo de tarjeta — contexto retail POS

| Campo | Descripción |
|---|---|
| `mto_total_retail_pos_1m` | Monto total con cualquier medio de pago en retail POS |
| `mto_total_td_retail_pos_1m` | Monto total con tarjeta débito (todos los bancos) en retail POS |
| `mto_total_tc_retail_pos_1m` | Monto total con tarjeta crédito (todos los bancos) en retail POS |
| `mto_total_noibk_retail_pos_1m` | Monto total con tarjetas no-IBK (TD + TC) en retail POS |
| `mto_total_noibk_td_retail_pos_1m` | Monto total con TD no-IBK en retail POS |
| `mto_total_noibk_tc_retail_pos_1m` | Monto total con TC no-IBK en retail POS |

### Monto por esencialidad del producto — débito

| Campo | Descripción |
|---|---|
| `mto_escencial_td_retail_pos_1m` | Monto en productos esenciales con TD (todos los bancos) |
| `mto_no_escencial_td_retail_pos_1m` | Monto en productos no esenciales con TD (todos los bancos) |
| `mto_escencial_noibk_td_retail_pos_1m` | Monto en esenciales con TD no-IBK |
| `mto_no_escencial_noibk_td_retail_pos_1m` | Monto en no esenciales con TD no-IBK |
| `mto_escencial_noibk_td_efectivo_retail_pos_1m` | Monto en esenciales con débito+efectivo no-IBK |
| `mto_no_escencial_noibk_td_efectivo_retail_pos_1m` | Monto en no esenciales con débito+efectivo no-IBK |

### Monto por esencialidad del producto — crédito

| Campo | Descripción |
|---|---|
| `mto_escencial_tc_retail_pos_1m` | Monto en productos esenciales con TC (todos los bancos) |
| `mto_no_escencial_tc_retail_pos_1m` | Monto en productos no esenciales con TC (todos los bancos) |
| `mto_escencial_noibk_tc_retail_pos_1m` | Monto en esenciales con TC no-IBK |
| `mto_no_escencial_noibk_tc_retail_pos_1m` | Monto en no esenciales con TC no-IBK |

### Monto por gama de TC — retail POS (todos los bancos)

| Campo | Descripción |
|---|---|
| `mto_total_tc_clasica_retail_pos_1m` | Monto total con TC Clásica en retail POS |
| `mto_total_tc_oro_retail_pos_1m` | Monto total con TC Oro en retail POS |
| `mto_total_tc_platinum_retail_pos_1m` | Monto total con TC Platinum en retail POS |
| `mto_total_tc_signature_retail_pos_1m` | Monto total con TC Signature en retail POS |
| `mto_total_tc_infinite_retail_pos_1m` | Monto total con TC Infinite en retail POS |

### Monto por gama de TC — retail POS (solo no-IBK)

| Campo | Descripción |
|---|---|
| `mto_total_noibk_tc_clasica_retail_pos_1m` | Monto con TC Clásica no-IBK en retail POS |
| `mto_total_noibk_tc_oro_retail_pos_1m` | Monto con TC Oro no-IBK en retail POS |
| `mto_total_noibk_tc_platinum_retail_pos_1m` | Monto con TC Platinum no-IBK en retail POS |
| `mto_total_noibk_tc_signature_retail_pos_1m` | Monto con TC Signature no-IBK en retail POS |
| `mto_total_noibk_tc_infinite_retail_pos_1m` | Monto con TC Infinite no-IBK en retail POS |

### Monto por gama de TC — supermercados (todos los bancos)

| Campo | Descripción |
|---|---|
| `mto_total_tc_clasica_supermercado_retail_pos_1m` | Monto con TC Clásica en supermercados |
| `mto_total_tc_oro_supermercado_retail_pos_1m` | Monto con TC Oro en supermercados |
| `mto_total_tc_platinum_supermercado_retail_pos_1m` | Monto con TC Platinum en supermercados |
| `mto_total_tc_signature_supermercado_retail_pos_1m` | Monto con TC Signature en supermercados |
| `mto_total_tc_infinite_supermercado_retail_pos_1m` | Monto con TC Infinite en supermercados |

### Monto por gama de TC — supermercados (solo no-IBK)

| Campo | Descripción |
|---|---|
| `mto_total_noibk_tc_clasica_supermercado_retail_pos_1m` | Monto con TC Clásica no-IBK en supermercados |
| `mto_total_noibk_tc_oro_supermercado_retail_pos_1m` | Monto con TC Oro no-IBK en supermercados |
| `mto_total_noibk_tc_platinum_supermercado_retail_pos_1m` | Monto con TC Platinum no-IBK en supermercados |
| `mto_total_noibk_tc_signature_supermercado_retail_pos_1m` | Monto con TC Signature no-IBK en supermercados |
| `mto_total_noibk_tc_infinite_supermercado_retail_pos_1m` | Monto con TC Infinite no-IBK en supermercados |

---

## 4. Métricas de Cantidad — `cant_trx_*_1m` (INTEGER)

Mismo esquema de segmentación que `mto_*`, pero cuenta el número de transacciones.

### Cantidad total por tipo de tarjeta

| Campo | Descripción |
|---|---|
| `cant_trx_total_retail_pos_1m` | Total transacciones con cualquier medio en retail POS |
| `cant_trx_total_td_retail_pos_1m` | Transacciones con TD (todos los bancos) |
| `cant_trx_total_tc_retail_pos_1m` | Transacciones con TC (todos los bancos) |
| `cant_trx_total_noibk_retail_pos_1m` | Transacciones con tarjetas no-IBK (TD + TC) |
| `cant_trx_total_noibk_td_retail_pos_1m` | Transacciones con TD no-IBK |
| `cant_trx_total_noibk_tc_retail_pos_1m` | Transacciones con TC no-IBK |

### Cantidad por esencialidad — débito

| Campo | Descripción |
|---|---|
| `cant_trx_escencial_td_retail_pos_1m` | Transacciones en esenciales con TD (todos) |
| `cant_trx_no_escencial_td_retail_pos_1m` | Transacciones en no esenciales con TD (todos) |
| `cant_trx_escencial_noibk_td_retail_pos_1m` | Transacciones en esenciales con TD no-IBK |
| `cant_trx_no_escencial_noibk_td_retail_pos_1m` | Transacciones en no esenciales con TD no-IBK |
| `cant_trx_escencial_noibk_td_efectivo_retail_pos_1m` | Transacciones esenciales con débito+efectivo no-IBK |
| `cant_trx_no_escencial_noibk_td_efectivo_retail_pos_1m` | Transacciones no esenciales con débito+efectivo no-IBK |

### Cantidad por esencialidad — crédito

| Campo | Descripción |
|---|---|
| `cant_trx_escencial_tc_retail_pos_1m` | Transacciones en esenciales con TC (todos) |
| `cant_trx_no_escencial_tc_retail_pos_1m` | Transacciones en no esenciales con TC (todos) |
| `cant_trx_escencial_noibk_tc_retail_pos_1m` | Transacciones en esenciales con TC no-IBK |
| `cant_trx_no_escencial_noibk_tc_retail_pos_1m` | Transacciones en no esenciales con TC no-IBK |

### Cantidad por gama de TC — retail POS (todos los bancos)

| Campo | Descripción |
|---|---|
| `cant_trx_tc_clasica_retail_pos_1m` | Transacciones con TC Clásica en retail POS |
| `cant_trx_tc_oro_retail_pos_1m` | Transacciones con TC Oro en retail POS |
| `cant_trx_tc_platinum_retail_pos_1m` | Transacciones con TC Platinum en retail POS |
| `cant_trx_tc_signature_retail_pos_1m` | Transacciones con TC Signature en retail POS |
| `cant_trx_tc_infinite_retail_pos_1m` | Transacciones con TC Infinite en retail POS |

### Cantidad por gama de TC — retail POS (solo no-IBK)

| Campo | Descripción |
|---|---|
| `cant_trx_noibk_tc_clasica_retail_pos_1m` | Transacciones con TC Clásica no-IBK en retail POS |
| `cant_trx_noibk_tc_oro_retail_pos_1m` | Transacciones con TC Oro no-IBK en retail POS |
| `cant_trx_noibk_tc_platinum_retail_pos_1m` | Transacciones con TC Platinum no-IBK en retail POS |
| `cant_trx_noibk_tc_signature_retail_pos_1m` | Transacciones con TC Signature no-IBK en retail POS |
| `cant_trx_noibk_tc_infinite_retail_pos_1m` | Transacciones con TC Infinite no-IBK en retail POS |

### Cantidad por gama de TC — supermercados (todos los bancos)

| Campo | Descripción |
|---|---|
| `cant_trx_tc_clasica_supermercado_retail_pos_1m` | Transacciones con TC Clásica en supermercados |
| `cant_trx_tc_oro_supermercado_retail_pos_1m` | Transacciones con TC Oro en supermercados |
| `cant_trx_tc_platinum_supermercado_retail_pos_1m` | Transacciones con TC Platinum en supermercados |
| `cant_trx_tc_signature_supermercado_retail_pos_1m` | Transacciones con TC Signature en supermercados |
| `cant_trx_tc_infinite_supermercado_retail_pos_1m` | Transacciones con TC Infinite en supermercados |

### Cantidad por gama de TC — supermercados (solo no-IBK)

| Campo | Descripción |
|---|---|
| `cant_trx_noibk_tc_clasica_supermercado_retail_pos_1m` | Transacciones con TC Clásica no-IBK en supermercados |
| `cant_trx_noibk_tc_oro_supermercado_retail_pos_1m` | Transacciones con TC Oro no-IBK en supermercados |
| `cant_trx_noibk_tc_platinum_supermercado_retail_pos_1m` | Transacciones con TC Platinum no-IBK en supermercados |
| `cant_trx_noibk_tc_signature_supermercado_retail_pos_1m` | Transacciones con TC Signature no-IBK en supermercados |
| `cant_trx_noibk_tc_infinite_supermercado_retail_pos_1m` | Transacciones con TC Infinite no-IBK en supermercados |

---

## 5. Resumen de todas las combinaciones disponibles

| Métrica | Banco | TD/TC | Esencialidad | Gama TC | Contexto |
|---|---|---|---|---|---|
| `mto_`, `cant_trx_` | todos / `noibk` | `td`, `tc`, `td_efectivo` | `escencial`, `no_escencial`, `total` | `clasica`, `oro`, `platinum`, `signature`, `infinite` | `retail_pos`, `supermercado_retail_pos` |

---

## 6. Queries de referencia

```sql
-- Consumo total con tarjeta en retail POS mayo 2026
SELECT id,
       mto_total_retail_pos_1m,
       mto_total_td_retail_pos_1m,
       mto_total_tc_retail_pos_1m,
       cant_trx_total_retail_pos_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`
WHERE process_date = '2026-05-01'
  AND mto_total_retail_pos_1m > 0;

-- Clientes que usan TC de gama alta (platinum + signature + infinite)
SELECT id,
       mto_total_tc_platinum_retail_pos_1m,
       mto_total_tc_signature_retail_pos_1m,
       mto_total_tc_infinite_retail_pos_1m,
       cant_trx_tc_platinum_retail_pos_1m + cant_trx_tc_signature_retail_pos_1m
         + cant_trx_tc_infinite_retail_pos_1m AS total_trx_gama_alta
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`
WHERE process_date = '2026-05-01'
  AND (mto_total_tc_platinum_retail_pos_1m > 0
    OR mto_total_tc_signature_retail_pos_1m > 0
    OR mto_total_tc_infinite_retail_pos_1m > 0);

-- Mix esencial vs no esencial con TD en supermercados
SELECT process_date,
       SUM(mto_total_tc_clasica_supermercado_retail_pos_1m) AS mto_clasica_super,
       SUM(mto_total_tc_oro_supermercado_retail_pos_1m)     AS mto_oro_super,
       SUM(mto_total_tc_platinum_supermercado_retail_pos_1m) AS mto_platinum_super
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`
WHERE process_date BETWEEN '2026-01-01' AND '2026-05-01'
GROUP BY process_date ORDER BY process_date;

-- Penetración de TC no-IBK vs total
SELECT id,
       mto_total_retail_pos_1m,
       mto_total_noibk_retail_pos_1m,
       SAFE_DIVIDE(mto_total_noibk_retail_pos_1m, mto_total_retail_pos_1m) * 100
         AS pct_noibk
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`
WHERE process_date = '2026-05-01'
  AND mto_total_retail_pos_1m > 0;
```

---

## 7. Ventanas temporales

> Esta tabla **solo tiene ventana `_1m`** — el mes del `process_date`. No hay `_3m`, `_6m`, `_9m` ni `_12m`.
> Para acumular varios meses, filtrar múltiples particiones y sumar `_1m`.

```sql
-- Acumulado Q1 2026 sumando particiones _1m
SELECT id, SUM(mto_total_retail_pos_1m) AS mto_total_q1
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`
WHERE process_date BETWEEN '2026-01-01' AND '2026-03-01'
GROUP BY id;
```

---

## 8. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes con toda la info del mes.
2. **Clave: `id`** — para cruzar con `ba_itc_attr_retail`: `card.id = retail.id_intercorp`.
3. **Solo ventana `_1m`** — para acumulados, sumar entre particiones.
4. **`noibk`** = tarjetas de bancos distintos a Interbank. El complemento (IBK) = `total - noibk`.
5. **Esencialidad** basada en `c_productos_escenciales_retail` y `c_productos_escenciales_pos`.
6. **`retail_pos`** = todos los puntos de venta retail. **`supermercado_retail_pos`** = subconjunto de supermercados.
7. **NULL = sin actividad** en esa combinación en el mes.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery (`itc-data-governance-01`) | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_card_consumption`*
