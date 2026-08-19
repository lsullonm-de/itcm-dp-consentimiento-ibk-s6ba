# Catálogo de Datos — `ba_itc_attr_purchase_prediction`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`

---

## Descripción

Scores de propensión de compra del cliente por categoría de producto, generados por modelos de ML. Registra la probabilidad de compra, la prioridad del cliente como audiencia, el precio promedio estimado y la categoría más probable de compra en 3 ventanas temporales: 1 semana (`1s`), 1 mes (`1m`) y 3 meses (`3m`).

A diferencia de `ba_itc_attr_purchase_intention` (señales de navegación — pasado) y `ba_itc_attr_purchase_card` (historial real — pasado), esta tabla usa **modelos ML** que combinan múltiples señales para predecir comportamiento **futuro**.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | — |
| Filas aprox. | No confirmado |
| Columnas | 1,096 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `clientid` | STRING | Identificador del cliente (verificar si equivale a `id` DNI o a `party_id`) |
| `record_source` | STRING | Origen del registro |
| `load_date` | TIMESTAMP o DATE | Fecha de carga |
| `creation_user` | STRING | SA que ejecutó la carga |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

> **Nota**: El campo identificador es `clientid` (no `id`). Verificar el tipo de identificador al hacer JOINs con otras tablas `ba_itc_attr_*` que usan `id`.

---

## 2. Convención de naming de las columnas de predicción

El patrón de las columnas de métricas es:

```
itc_{familia}_{detalle}_{ventana}
```

| Dimensión | Valores |
|---|---|
| `ventana` | `1s` (1 semana), `1m` (1 mes), `3m` (3 meses) |
| `familia` | Ver secciones 3–9 |

---

## 3. Prioridad del cliente como audiencia — `itc_prioridad_cliente_{v}`

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_prioridad_cliente_1s` | STRING | Prioridad del cliente para activación en 1 semana: `alta` / `media` / `baja` |
| `itc_prioridad_cliente_1m` | STRING | Prioridad del cliente para activación en 1 mes |
| `itc_prioridad_cliente_3m` | STRING | Prioridad del cliente para activación en 3 meses |

---

## 4. Flags de prioridad alta y media

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_itc_prioridad_alta_1s` | STRING | `"SÍ"` = cliente de alta prioridad en ventana 1 semana |
| `flag_itc_prioridad_alta_1m` | STRING | `"SÍ"` = cliente de alta prioridad en ventana 1 mes |
| `flag_itc_prioridad_alta_3m` | STRING | `"SÍ"` = cliente de alta prioridad en ventana 3 meses |
| `flag_itc_prioridad_media_1s` | STRING | `"SÍ"` = cliente de prioridad media en ventana 1 semana |
| `flag_itc_prioridad_media_1m` | STRING | `"SÍ"` = cliente de prioridad media en ventana 1 mes |
| `flag_itc_prioridad_media_3m` | STRING | `"SÍ"` = cliente de prioridad media en ventana 3 meses |

---

## 5. Tipo de audiencia más probable — `itc_tipo_aud_mas_prob_{v}`

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_tipo_aud_mas_prob_1s` | STRING | Categoría de audiencia con mayor probabilidad de compra en 1 semana |
| `itc_tipo_aud_mas_prob_1m` | STRING | Categoría de audiencia con mayor probabilidad de compra en 1 mes |
| `itc_tipo_aud_mas_prob_3m` | STRING | Categoría de audiencia con mayor probabilidad de compra en 3 meses |

---

## 6. Precio promedio estimado

### Precio promedio total

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_precio_prom_total_1s` | FLOAT | Precio promedio total esperado para la compra en 1 semana (S/) |
| `itc_precio_prom_total_1m` | FLOAT | Precio promedio total esperado para la compra en 1 mes (S/) |
| `itc_precio_prom_total_3m` | FLOAT | Precio promedio total esperado para la compra en 3 meses (S/) |

### Precio promedio por audiencia — `itc_precio_prom_aud_{audiencia}_{v}`

Un campo por cada combinación de audiencia × ventana. Ejemplos representativos:

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_precio_prom_aud_deportes_1s` | FLOAT | Precio promedio esperado en audiencia deportes — 1 semana |
| `itc_precio_prom_aud_electrohogar_1m` | FLOAT | Precio promedio esperado en audiencia electrohogar — 1 mes |
| `itc_precio_prom_aud_belleza_3m` | FLOAT | Precio promedio esperado en audiencia belleza — 3 meses |
| `itc_precio_prom_aud_tecnologia_1m` | FLOAT | Precio promedio esperado en audiencia tecnología — 1 mes |
| `itc_precio_prom_aud_infantil_1m` | FLOAT | Precio promedio esperado en audiencia infantil — 1 mes |

---

## 7. Categoría con mayor probabilidad de compra — `itc_max_prob_compra_cliente_{v}`

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_max_prob_compra_cliente_1s` | STRING | Nombre de la categoría con mayor score de compra en 1 semana |
| `itc_max_prob_compra_cliente_1m` | STRING | Nombre de la categoría con mayor score de compra en 1 mes |
| `itc_max_prob_compra_cliente_3m` | STRING | Nombre de la categoría con mayor score de compra en 3 meses |

---

## 8. Probabilidad general de compra — `itc_prob_compra_{v}`

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_prob_compra_1s` | FLOAT | Probabilidad general de realizar una compra en 1 semana (0.0–1.0) |
| `itc_prob_compra_1m` | FLOAT | Probabilidad general de realizar una compra en 1 mes (0.0–1.0) |
| `itc_prob_compra_3m` | FLOAT | Probabilidad general de realizar una compra en 3 meses (0.0–1.0) |

---

## 9. Probabilidad de compra por categoría — `itc_prob_compra_{categoria}_{v}`

Categorías disponibles: `deportes`, `electrohogar`, `decohogar`, `infantil`, `zapatos`, `zapatillas`, `supermercado`, `moda`, `belleza`, `dormitorio`, `tecnologia`, `otros`.

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_prob_compra_deportes_1s` | FLOAT | Probabilidad de compra en deportes — 1 semana |
| `itc_prob_compra_deportes_1m` | FLOAT | Probabilidad de compra en deportes — 1 mes |
| `itc_prob_compra_deportes_3m` | FLOAT | Probabilidad de compra en deportes — 3 meses |
| `itc_prob_compra_electrohogar_1s` | FLOAT | Probabilidad de compra en electrohogar — 1 semana |
| `itc_prob_compra_electrohogar_1m` | FLOAT | Probabilidad de compra en electrohogar — 1 mes |
| `itc_prob_compra_electrohogar_3m` | FLOAT | Probabilidad de compra en electrohogar — 3 meses |
| `itc_prob_compra_decohogar_1s` | FLOAT | Probabilidad de compra en decohogar — 1 semana |
| `itc_prob_compra_decohogar_1m` | FLOAT | Probabilidad de compra en decohogar — 1 mes |
| `itc_prob_compra_decohogar_3m` | FLOAT | Probabilidad de compra en decohogar — 3 meses |
| `itc_prob_compra_infantil_1s` | FLOAT | Probabilidad de compra en infantil — 1 semana |
| `itc_prob_compra_infantil_1m` | FLOAT | Probabilidad de compra en infantil — 1 mes |
| `itc_prob_compra_infantil_3m` | FLOAT | Probabilidad de compra en infantil — 3 meses |
| `itc_prob_compra_zapatos_1s` | FLOAT | Probabilidad de compra en zapatos — 1 semana |
| `itc_prob_compra_zapatos_1m` | FLOAT | Probabilidad de compra en zapatos — 1 mes |
| `itc_prob_compra_zapatos_3m` | FLOAT | Probabilidad de compra en zapatos — 3 meses |
| `itc_prob_compra_zapatillas_1s` | FLOAT | Probabilidad de compra en zapatillas — 1 semana |
| `itc_prob_compra_zapatillas_1m` | FLOAT | Probabilidad de compra en zapatillas — 1 mes |
| `itc_prob_compra_zapatillas_3m` | FLOAT | Probabilidad de compra en zapatillas — 3 meses |
| `itc_prob_compra_supermercado_1s` | FLOAT | Probabilidad de compra en supermercado — 1 semana |
| `itc_prob_compra_supermercado_1m` | FLOAT | Probabilidad de compra en supermercado — 1 mes |
| `itc_prob_compra_supermercado_3m` | FLOAT | Probabilidad de compra en supermercado — 3 meses |
| `itc_prob_compra_moda_1s` | FLOAT | Probabilidad de compra en moda — 1 semana |
| `itc_prob_compra_moda_1m` | FLOAT | Probabilidad de compra en moda — 1 mes |
| `itc_prob_compra_moda_3m` | FLOAT | Probabilidad de compra en moda — 3 meses |
| `itc_prob_compra_belleza_1s` | FLOAT | Probabilidad de compra en belleza — 1 semana |
| `itc_prob_compra_belleza_1m` | FLOAT | Probabilidad de compra en belleza — 1 mes |
| `itc_prob_compra_belleza_3m` | FLOAT | Probabilidad de compra en belleza — 3 meses |
| `itc_prob_compra_dormitorio_1s` | FLOAT | Probabilidad de compra en dormitorio — 1 semana |
| `itc_prob_compra_dormitorio_1m` | FLOAT | Probabilidad de compra en dormitorio — 1 mes |
| `itc_prob_compra_dormitorio_3m` | FLOAT | Probabilidad de compra en dormitorio — 3 meses |
| `itc_prob_compra_tecnologia_1s` | FLOAT | Probabilidad de compra en tecnología — 1 semana |
| `itc_prob_compra_tecnologia_1m` | FLOAT | Probabilidad de compra en tecnología — 1 mes |
| `itc_prob_compra_tecnologia_3m` | FLOAT | Probabilidad de compra en tecnología — 3 meses |
| `itc_prob_compra_otros_1s` | FLOAT | Probabilidad de compra en otras categorías — 1 semana |
| `itc_prob_compra_otros_1m` | FLOAT | Probabilidad de compra en otras categorías — 1 mes |
| `itc_prob_compra_otros_3m` | FLOAT | Probabilidad de compra en otras categorías — 3 meses |

---

## 10. Score promedio de propensión — `itc_prom_score_{v}`

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_prom_score_1s` | FLOAT | Score promedio de propensión de compra en todas las categorías — 1 semana |
| `itc_prom_score_1m` | FLOAT | Score promedio de propensión de compra en todas las categorías — 1 mes |
| `itc_prom_score_3m` | FLOAT | Score promedio de propensión de compra en todas las categorías — 3 meses |

---

## 11. Comparación con otras tablas de intención/compra

| Tabla | Fuente de señal | Horizonte | Tipo de output |
|---|---|---|---|
| `ba_itc_attr_purchase_intention` | Navegación digital (Promart, Oechsle) | Pasado reciente | Flag binario (vio/no vio) |
| `ba_itc_attr_purchase_card` | Historial de compras con tarjeta POS | Pasado (1m–12m) | Cantidad + monto real |
| `ba_itc_attr_purchase_prediction` | Modelo ML (combina múltiples señales) | **Futuro** (1s, 1m, 3m) | Score de propensión (0–1) |

---

## 12. Queries de referencia

```sql
-- Clientes de alta prioridad para activación inmediata (1 semana)
SELECT clientid, itc_prioridad_cliente_1s, itc_max_prob_compra_cliente_1s,
       itc_prob_compra_1s, itc_precio_prom_total_1s
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`
WHERE process_date = '2026-05-01'
  AND flag_itc_prioridad_alta_1s = 'SÍ'
ORDER BY itc_prob_compra_1s DESC
LIMIT 10000;

-- Propensión en tecnología: top clientes ordenados por score (1 mes)
SELECT clientid, itc_prob_compra_tecnologia_1m, itc_precio_prom_total_1m,
       itc_prioridad_cliente_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`
WHERE process_date = '2026-05-01'
  AND itc_prob_compra_tecnologia_1m > 0.7
ORDER BY itc_prob_compra_tecnologia_1m DESC;

-- Doble señal: intención digital + score ML en electrohogar
SELECT pred.clientid,
       pred.itc_prob_compra_electrohogar_1m,
       intent.flag_electrohogar_add_to_cart_1s
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction` pred
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention` intent
  ON pred.clientid = intent.id AND pred.process_date = intent.process_date
WHERE pred.process_date = '2026-05-01'
  AND pred.itc_prob_compra_electrohogar_1m > 0.6
  AND intent.flag_electrohogar_add_to_cart_1s = 1;

-- Distribución de audiencia más probable en 1 mes
SELECT itc_tipo_aud_mas_prob_1m AS audiencia,
  COUNT(DISTINCT clientid) AS clientes,
  AVG(itc_prob_compra_1m) AS score_promedio
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`
WHERE process_date = '2026-05-01'
GROUP BY 1
ORDER BY 2 DESC;

-- Comparar scores por ventana temporal para detectar urgencia
SELECT clientid,
  itc_prob_compra_tecnologia_1s AS prob_1s,
  itc_prob_compra_tecnologia_1m AS prob_1m,
  itc_prob_compra_tecnologia_3m AS prob_3m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`
WHERE process_date = '2026-05-01'
  AND itc_prob_compra_tecnologia_1s > itc_prob_compra_tecnologia_3m
ORDER BY itc_prob_compra_tecnologia_1s DESC;
```

---

## 13. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **`clientid` como clave**: Verificar si equivale al DNI (`id`) de otras tablas antes de hacer JOINs. Puede requerir tabla de mapeo `clientid → id`.
3. **Prioridad vs. score**: Usar `itc_prioridad_cliente_*` para segmentación simple (alta/media/baja). Usar `itc_prob_compra_*` para ranking fino y ordenamiento de audiencias.
4. **`flag_itc_prioridad_alta_*` es STRING**: Comparar con `= 'SÍ'`, no con `= 1`.
5. **Doble señal = máxima prioridad**: Clientes con `itc_prob_compra_{cat}_1s > 0.7` + `flag_{cat}_add_to_cart_1s = 1` (de `purchase_intention`) tienen señal ML y señal conductual — activar primero.
6. **`itc_prom_score_*`**: Útil para rankear clientes sin especificar categoría. Combinar con `itc_max_prob_compra_cliente_*` para saber cuál es la mejor categoría por cliente.
7. **Actualización mensual**: El score refleja el estado en `process_date`. Usar siempre la partición más reciente para campañas activas.
8. **1,096 columnas**: Cargar solo las columnas necesarias en las queries. Evitar `SELECT *` en esta tabla.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_prediction`*
