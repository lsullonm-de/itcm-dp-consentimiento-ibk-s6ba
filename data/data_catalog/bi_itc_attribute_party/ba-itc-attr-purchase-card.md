# Catálogo de Datos — `ba_itc_attr_purchase_card`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`

---

## Descripción

Atributos de compras con tarjeta por categoría de salud, belleza y bienestar, capturadas via POS Izipay. Registra transacciones y montos en 12 categorías especializadas en múltiples ventanas temporales: clínicas/hospitales, boticas, salud, belleza/dermacosméticos, deportes, infantil, fragancias, cuidado capilar, suplementos, higiene/cuidado bucal, mamá & bebé y seguros.

Permite identificar el perfil de intereses del cliente según sus hábitos de compra con tarjeta en rubros de salud y cuidado personal, con granularidad de 1, 3, 6, 9 y 12 meses.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | — |
| Filas aprox. | ~17M |
| Columnas | 125 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |
| `record_source` | `"Bases Transaccionales"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente |
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `record_source` | STRING | Origen del registro. Valor: `"Bases Transaccionales"` |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |

---

## 2. Convención de naming de las 120 métricas

El patrón de las columnas de métricas es:

```
{metrica}_{categoria}_{ventana}
```

| Dimensión | Valores |
|---|---|
| `metrica` | `trx` = número de transacciones (INTEGER) / `mto` = monto en S/ (FLOAT) |
| `categoria` | 12 categorías (ver sección 3) |
| `ventana` | `1m`, `3m`, `6m`, `9m`, `12m` |

Cada combinación de `{metrica} × {categoria} × {ventana}` produce un campo: **2 × 12 × 5 = 120 campos de métricas**.

---

## 3. Categorías de compra (12)

| Categoría | Descripción |
|---|---|
| `clinica_hospital` | Pagos en clínicas y hospitales |
| `botica` | Compras en boticas y farmacias |
| `salud` | Productos y servicios de salud en general |
| `belleza_dermo` | Productos de belleza y dermocosmética |
| `deportista` | Artículos deportivos y equipamiento fitness |
| `infantil` | Productos para bebés y niños |
| `fragancia` | Perfumes y fragancias |
| `cuidado_capilar` | Productos para el cuidado del cabello |
| `suplementos` | Suplementos nutricionales y vitaminas |
| `higiene_cuidado_bucal` | Productos de higiene personal y cuidado bucal |
| `mama_bebe` | Productos especializados para mamá y bebé |
| `seguros` | Pagos relacionados a seguros vía POS |

---

## 4. Métricas por categoría y ventana

### Ejemplo completo para la categoría `botica`

| Campo | Tipo | Descripción |
|---|---|---|
| `trx_botica_1m` | INTEGER | Transacciones en boticas — último 1 mes |
| `mto_botica_1m` | FLOAT | Monto en boticas en S/ — último 1 mes |
| `trx_botica_3m` | INTEGER | Transacciones en boticas — últimos 3 meses |
| `mto_botica_3m` | FLOAT | Monto en boticas en S/ — últimos 3 meses |
| `trx_botica_6m` | INTEGER | Transacciones en boticas — últimos 6 meses |
| `mto_botica_6m` | FLOAT | Monto en boticas en S/ — últimos 6 meses |
| `trx_botica_9m` | INTEGER | Transacciones en boticas — últimos 9 meses |
| `mto_botica_9m` | FLOAT | Monto en boticas en S/ — últimos 9 meses |
| `trx_botica_12m` | INTEGER | Transacciones en boticas — últimos 12 meses |
| `mto_botica_12m` | FLOAT | Monto en boticas en S/ — últimos 12 meses |

> El mismo patrón aplica para las 11 categorías restantes: `clinica_hospital`, `salud`, `belleza_dermo`, `deportista`, `infantil`, `fragancia`, `cuidado_capilar`, `suplementos`, `higiene_cuidado_bucal`, `mama_bebe`, `seguros`.

### Referencia rápida de campos por categoría (ventana 1m)

| Campo `trx_*_1m` | Campo `mto_*_1m` | Categoría |
|---|---|---|
| `trx_clinica_hospital_1m` | `mto_clinica_hospital_1m` | Clínicas y hospitales |
| `trx_botica_1m` | `mto_botica_1m` | Boticas y farmacias |
| `trx_salud_1m` | `mto_salud_1m` | Salud general |
| `trx_belleza_dermo_1m` | `mto_belleza_dermo_1m` | Belleza y dermocosmética |
| `trx_deportista_1m` | `mto_deportista_1m` | Artículos deportivos |
| `trx_infantil_1m` | `mto_infantil_1m` | Productos para bebés/niños |
| `trx_fragancia_1m` | `mto_fragancia_1m` | Perfumes y fragancias |
| `trx_cuidado_capilar_1m` | `mto_cuidado_capilar_1m` | Cuidado capilar |
| `trx_suplementos_1m` | `mto_suplementos_1m` | Suplementos nutricionales |
| `trx_higiene_cuidado_bucal_1m` | `mto_higiene_cuidado_bucal_1m` | Higiene y cuidado bucal |
| `trx_mama_bebe_1m` | `mto_mama_bebe_1m` | Mamá y bebé |
| `trx_seguros_1m` | `mto_seguros_1m` | Seguros vía POS |

---

## 5. Queries de referencia

```sql
-- Clientes con perfil de estilo de vida saludable (deportes + suplementos en 3m)
SELECT id, trx_deportista_3m, mto_deportista_3m,
       trx_suplementos_3m, mto_suplementos_3m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`
WHERE process_date = '2026-05-01'
  AND trx_deportista_3m > 0
  AND trx_suplementos_3m > 0;

-- Madres recientes: compras en mamá-bebé e infantil (6 meses)
SELECT id, trx_mama_bebe_6m, mto_mama_bebe_6m,
       trx_infantil_6m, mto_infantil_6m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`
WHERE process_date = '2026-05-01'
  AND (trx_mama_bebe_6m > 0 OR trx_infantil_6m > 0);

-- Clientes de alto gasto en belleza (top de monto 12m)
SELECT id, trx_belleza_dermo_12m, mto_belleza_dermo_12m,
       trx_fragancia_12m, mto_fragancia_12m,
       trx_cuidado_capilar_12m, mto_cuidado_capilar_12m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`
WHERE process_date = '2026-05-01'
  AND mto_belleza_dermo_12m > 500
ORDER BY mto_belleza_dermo_12m DESC
LIMIT 1000;

-- Distribución de gasto promedio por categoría (1 mes)
SELECT
  AVG(mto_botica_1m)           AS avg_botica,
  AVG(mto_clinica_hospital_1m) AS avg_clinica,
  AVG(mto_belleza_dermo_1m)    AS avg_belleza,
  AVG(mto_deportista_1m)       AS avg_deportes,
  AVG(mto_infantil_1m)         AS avg_infantil,
  AVG(mto_suplementos_1m)      AS avg_suplementos,
  AVG(mto_mama_bebe_1m)        AS avg_mama_bebe,
  COUNT(*)                     AS total_clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`
WHERE process_date = '2026-05-01';

-- Pacientes con visita médica reciente y compras en botica (1m)
SELECT id, trx_clinica_hospital_1m, trx_botica_1m,
       mto_clinica_hospital_1m, mto_botica_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`
WHERE process_date = '2026-05-01'
  AND trx_clinica_hospital_1m > 0
  AND trx_botica_1m >= 2;
```

---

## 6. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Solo ~17M registros**: Subconjunto de clientes con compras en estas categorías específicas. No incluye todo el universo de clientes.
3. **NULL = sin transacciones** en esa categoría en la ventana — no es un error. Tratar igual que 0 para sumas.
4. **`trx_infantil_*` + `trx_mama_bebe_*`**: Combinados indican cliente con hijo pequeño o gestante. Cruzar con `ba_itc_attr_prediction.mes_bebe` para validar.
5. **`trx_seguros_*`**: Pagos de primas de seguro via POS Izipay. Puede solapar con datos de `ba_itc_attr_insurance` — fuentes distintas.
6. **Ventanas acumuladas**: `_12m` incluye el período de `_1m`. Para actividad reciente usar `_1m` o `_3m`. Para cliente activo histórico usar `_12m`.
7. **Fuente Izipay (POS)**: Solo captura transacciones con tarjeta en comercios afiliados a Izipay. No cubre efectivo ni otras redes de POS.
8. **`botica` vs `salud`**: Pueden solapar — una compra en farmacia puede clasificarse en ambas según el MCC del comercio.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_card`*
