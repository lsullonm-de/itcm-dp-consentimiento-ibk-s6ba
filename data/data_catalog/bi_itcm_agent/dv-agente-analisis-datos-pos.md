# Catálogo de Datos — `dv_agente_analisis_datos_pos`

**Catalog ID:** `bi_itcm_agent.dv_agente_analisis_datos_pos`
**Proyecto canónico:** `itc-data-governance-01`
**Dataset:** `bi_itcm_agent`
**Tabla completa:** `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
**Tabla origen:** `itc-data-governance-01.gnunurat.dv_agente_analisis_datos_pos`
_(réplica en dataset operativo del agente de análisis)_

---

## Descripción

Tabla de **gasto de clientes Intercorp en puntos de venta externos** al grupo, agregado por período mensual y tipo de comercio (`segment`). Registra cuánto gastan los clientes portadores de tarjetas Intercorp (TC Interbank, TC OH!) en comercios de terceros, clasificados por categoría MCC (Merchant Category Code).

El sufijo `_pos` hace referencia a **POS externo** (Point of Sale fuera del ecosistema Intercorp). Es la contraparte de `dv_agente_analisis_datos`, que registra el gasto dentro de las tiendas propias.

**Caso de uso principal:** Análisis de **share of wallet** y **comportamiento de gasto externo** de los clientes Intercorp. Permite responder: ¿En qué tipo de comercios gastan los clientes cuando no compran en nuestras tiendas? ¿Cuánto dinero fluye hacia la competencia o hacia categorías no cubiertas por el grupo?

**Granularidad de la fila:** combinación de `(process_date, segment)` → métricas agregadas del período mensual para ese tipo de comercio.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DATE, DAY) |
| Clusterizado por | `segment` |
| Total de filas | 4,618 |
| Número de columnas | 10 |
| Tamaño lógico | ~119 MB (124,687,487 bytes) |
| Número de particiones | 18 (mensual) |
| Período de datos | `2025-01-01` → `2026-06-01` |
| Última carga | `2026-06-19` |
| `record_source` | `t_transaction` |
| `creation_user` | `gnunurat@inside.com.pe` |
| Tabla origen | `itc-data-governance-01.gnunurat.dv_agente_analisis_datos_pos` |

**DDL:**
```sql
CREATE TABLE `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
(
  process_date       DATE,
  segment            STRING,
  mto_venta_neta     FLOAT64,
  cant_clientes      INTEGER,
  clientes_hll       BYTES,
  cant_transacciones INTEGER,
  transacciones_hll  BYTES,
  load_date          DATE,
  record_source      STRING,
  creation_user      STRING
)
PARTITION BY process_date
CLUSTER BY segment;
```

---

## Diccionario de Campos

### 1. Dimensión temporal

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `process_date` | DATE | YES | **Campo de partición.** Primer día del mes del período. Valores: `2025-01-01` → `2026-06-01` (18 particiones mensuales). Filtrar siempre para evitar full scan. |

### 2. Dimensión de segmento de comercio

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `segment` | STRING | YES | **Tipo de comercio externo** donde el cliente realizó la transacción. Basado en categorías MCC (Merchant Category Code). 275 valores distintos. **18 NULLs** (1 por partición — filas sin segmento asignado). Ver top 20 abajo. |

**Top 20 segmentos por clientes acumulados:**

| Segment | Filas | Clientes acumulados | Venta Neta Total (M) |
|---|---|---|---|
| FARMACIAS, BOTICAS | 18 | 50,797,907 | S/ 6,712 M |
| SUPERMERCADOS | 18 | 49,215,360 | S/ 10,887 M |
| BODEGAS, MINIMERCADOS | 18 | 38,621,125 | S/ 3,673 M |
| RESTAURANTES | 18 | 33,114,025 | S/ 7,051 M |
| WHOLESALE CLUBS | 18 | 30,895,906 | S/ 9,145 M |
| ESTACIONES DE SERVICIO, GRIFOS | 18 | 28,283,505 | S/ 9,258 M |
| COMIDA RAPIDA | 18 | 25,985,902 | S/ 2,222 M |
| PANADERIAS, PASTELERIAS, CAFETERIAS | 18 | 18,762,042 | S/ 2,089 M |
| PLAYAS DE ESTACIONAMIENTO | 18 | 10,373,252 | S/ 264 M |
| PEAJES Y TARIFAS DE PUENTE | 18 | 6,662,949 | S/ 691 M |
| TIENDAS POR DEPARTAMENTOS | 18 | 6,482,126 | S/ 2,510 M |
| ACABADOS PARA EL HOGAR | 18 | 6,055,248 | S/ 2,252 M |
| TAXIS, LIMOUSINES | 18 | 5,991,780 | S/ 1,215 M |
| HOSPITALES, CLINICAS | 18 | 5,452,485 | S/ 2,248 M |
| ROPA COMERCIAL (HOMBRES, MUJERES, NIÑOS) | 18 | 5,067,713 | S/ 1,959 M |
| PROGRAMACIÓN INFORMÁTICA, DATOS Y SISTEMAS | 18 | 5,067,670 | S/ 1,288 M |
| MAYORISTA DE ARTÍCULOS DE PAPELERÍA | 18 | 4,442,326 | S/ 525 M |
| BANCOS - SERVICIOS FINANCIEROS | 18 | 4,331,636 | S/ 9,504 M |
| LUZ, AGUA, GAS | 18 | 3,664,196 | S/ 937 M |
| CINES | 18 | 3,564,420 | S/ 357 M |

> Todos los segmentos tienen exactamente 18 filas (una por mes). Los 275 segmentos × 18 meses = 4,950 combinaciones posibles, pero solo existen 4,618 porque no todos los segmentos tienen actividad en todos los meses.

### 3. Métricas de negocio

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `mto_venta_neta` | FLOAT64 | YES | Monto total gastado por clientes Intercorp en ese tipo de comercio durante el período, en soles (S/.). Total acumulado 18 meses: ~S/ 107,120 millones. Promedio por fila: ~S/ 23.2 millones. |
| `cant_clientes` | INTEGER | YES | Cantidad de clientes Intercorp que transaccionaron en ese segmento durante el período. Total acumulado: ~1,290 millones clientes-período. Máximo por fila: 3,077,550. |
| `clientes_hll` | BYTES | YES | **Sketch HyperLogLog** para conteo de clientes únicos sin duplicar. Usar `HLL_COUNT.MERGE(clientes_hll)` al agregar múltiples segmentos. **60 NULLs** (~1.3%). |
| `cant_transacciones` | INTEGER | YES | Cantidad de transacciones en el segmento durante el período. Total acumulado: ~1,465 millones. |
| `transacciones_hll` | BYTES | YES | **Sketch HyperLogLog** de transacciones únicas. 0 NULLs. |

> ⚠️ **Uso de campos HLL:** Para contar clientes únicos al agregar varios segmentos (ej.: "¿cuántos clientes únicos compraron en supermercados Y en restaurantes?"), usar `HLL_COUNT.MERGE(clientes_hll)` en lugar de `SUM(cant_clientes)`.

### 4. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | DATE | YES | Fecha de carga del ETL. Valor: `2026-06-19`. |
| `record_source` | STRING | YES | Tabla de origen. Valor: `t_transaction`. |
| `creation_user` | STRING | YES | Usuario que ejecutó la carga. Valor: `gnunurat@inside.com.pe`. |

---

## Volumetría Global

| Métrica | Valor |
|---|---|
| Total filas | 4,618 |
| Segmentos distintos | 275 |
| Particiones (meses) | 18 |
| Monto total 18 meses | ~S/ 107,120 millones |
| Transacciones totales | ~1,465 millones |
| Clientes-período acumulados | ~1,290 millones |

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `dv_agente_analisis_datos` (bi_itcm_agent) | `process_date` | Share of wallet: gasto externo vs. gasto en tiendas propias Intercorp |
| `dv_rcc_montos_tc` (bi_vuc_insight) | `process_date` (via anio+mes) | Cruzar gasto externo por segmento con saldos y líneas de TC del sistema financiero |
| `dv_clientes_empresa_ytd_tarjetas` (bi_itcm_somos1) | Indirecto (via empresa retail) | Correlacionar penetración de TC IBK/OH! con volumen de gasto externo |

---

## Reglas de Negocio

1. **Filtrar siempre por `process_date`** — `WHERE process_date = '2026-06-01'` para un mes. Sin filtro escanea las 18 particiones completas (~119 MB).

2. **Cada segmento = exactamente 18 filas** (una por mes). Si un segmento tiene menos de 18 filas en un query sin filtro de fecha, significa que no tuvo actividad en algunos meses.

3. **`segment IS NULL` = filas de residual sin clasificar** — 18 filas (una por partición) con segmento NULL representan transacciones sin MCC asignado. Excluir con `WHERE segment IS NOT NULL` para análisis por categoría.

4. **`cant_clientes` es acumulado de portadores de TC Intercorp** — No representa todos los clientes Intercorp, sino los que usaron su tarjeta (IBK u OH!) en ese tipo de comercio. No es representativo de clientes que pagaron en efectivo o con otras tarjetas.

5. **`mto_venta_neta` es gasto del cliente, no ingreso de Intercorp** — Esta tabla mide cuánto gastan los clientes en terceros. El gasto en comercios externos no genera ingreso directo al grupo, pero es clave para entender la vida financiera del cliente.

6. **Comparación interna vs. externa** — Para share of wallet: comparar `SUM(mto_venta_neta)` de esta tabla (gasto externo) vs. `SUM(mto_venta_neta)` de `dv_agente_analisis_datos` (gasto interno) filtrados por el mismo `process_date`.

---

## Observaciones de Calidad de Datos

| Campo | % NULL / Observación |
|---|---|
| `segment` | 18 NULLs (0.39%) — 1 fila por partición sin MCC asignado |
| `clientes_hll` | 60 NULLs (1.3%) — sketches no generados en algunos segmentos |
| `transacciones_hll` | 0 NULLs — sketch siempre presente |
| `mto_venta_neta` | 0 NULLs — siempre con valor |
| `record_source` | Siempre `t_transaction` — fuente de datos de transacciones de TC |

---

## Queries de Referencia

```sql
-- 1. Top 10 segmentos externos por venta neta (mes más reciente)
SELECT
  segment,
  ROUND(SUM(mto_venta_neta) / 1e6, 2) AS venta_neta_MM,
  SUM(cant_transacciones)              AS transacciones,
  SUM(cant_clientes)                   AS clientes_periodos
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
WHERE process_date = '2026-06-01'
  AND segment IS NOT NULL
GROUP BY segment
ORDER BY venta_neta_MM DESC
LIMIT 10;

-- 2. Share of wallet: gasto interno Intercorp vs. gasto externo (mensual)
WITH interno AS (
  SELECT process_date, ROUND(SUM(mto_venta_neta)/1e6, 2) AS venta_interna_MM
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
  WHERE process_date >= '2026-01-01'
  GROUP BY process_date
),
externo AS (
  SELECT process_date, ROUND(SUM(mto_venta_neta)/1e6, 2) AS venta_externa_MM
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
  WHERE process_date >= '2026-01-01'
    AND segment IS NOT NULL
  GROUP BY process_date
)
SELECT
  i.process_date,
  i.venta_interna_MM,
  e.venta_externa_MM,
  ROUND(i.venta_interna_MM / (i.venta_interna_MM + e.venta_externa_MM) * 100, 2) AS pct_share_interno
FROM interno i
JOIN externo e USING (process_date)
ORDER BY i.process_date;

-- 3. Clientes únicos usando HLL por segmento (último mes)
SELECT
  segment,
  HLL_COUNT.MERGE(clientes_hll) AS clientes_unicos_aprox,
  SUM(mto_venta_neta)           AS venta_total
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
WHERE process_date = '2026-06-01'
  AND segment IS NOT NULL
  AND clientes_hll IS NOT NULL
GROUP BY segment
ORDER BY clientes_unicos_aprox DESC
LIMIT 15;

-- 4. Evolución mensual de gasto en supermercados externos (competencia)
SELECT
  process_date,
  ROUND(SUM(mto_venta_neta) / 1e6, 2) AS venta_supermercados_externos_MM,
  SUM(cant_clientes)                   AS clientes_periodos
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos`
WHERE segment = 'SUPERMERCADOS'
GROUP BY process_date
ORDER BY process_date;
```

---

> **Nota de profiling:** Catálogo generado desde `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos` (réplica de `gnunurat.dv_agente_analisis_datos_pos`). El Catalog ID `bi_itcm_agent.dv_agente_analisis_datos_pos` es el identificador canónico para el agente de análisis.

*Generado: 2026-06-26 | Fuente: BigQuery `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos_pos` | 4,618 filas · 119 MB · 10 columnas · 18 particiones*
