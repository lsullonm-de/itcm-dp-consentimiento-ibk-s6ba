# Catálogo de Datos — `dv_agente_analisis_datos`

**Catalog ID:** `bi_itcm_agent.dv_agente_analisis_datos`
**Proyecto canónico:** `itc-data-governance-01`
**Dataset:** `bi_itcm_agent`
**Tabla completa:** `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
**Tabla origen:** `itc-data-governance-01.gnunurat.dv_agente_analisis_datos`
_(réplica en dataset operativo del agente de análisis)_

---

## Descripción

Tabla de **ventas de las empresas retail propias del Grupo Intercorp** agregadas por período mensual, empresa, marca, canal de venta, departamento, categoría y subcategoría de producto. Registra el comportamiento de compra de los clientes en los **puntos de venta propios** del grupo.

Cubre las cuatro empresas del ecosistema:

| Empresa | Marcas incluidas |
|---|---|
| **FARMACIAS PERUANAS** | InkaFarma, MiFarma |
| **SUPERMERCADOS PERUANOS** | Plaza Vea, Mass, Cash & Carry, Plaza Vea Super, Plaza Vea Express, Vivanda, Merkao |
| **TIENDAS PERUANAS** | Oechsle |
| **PROMART** | Promart |

**Caso de uso principal:** Fuente primaria del **Agente de Análisis de Datos** para responder preguntas de negocio sobre ventas, clientes y transacciones dentro del ecosistema Intercorp. Permite calcular share of wallet interno (¿cuánto gasta el cliente en cada empresa/marca?), evolución mensual de métricas clave y segmentación geográfica y por categoría.

**Contraparte:** La tabla `dv_agente_analisis_datos_pos` registra el gasto de esos mismos clientes en comercios **externos** al grupo.

**Granularidad de la fila:** combinación de `(process_date, empresa, marca, canal_venta, departamento, categoria, subcategoria)` → métricas agregadas del período.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DATE, DAY) |
| Clusterizado por | `empresa`, `canal_venta`, `categoria`, `subcategoria` |
| Total de filas | 79,612 |
| Número de columnas | 16 |
| Tamaño lógico | ~882 MB (924,470,594 bytes) |
| Número de particiones | 18 (mensual) |
| Período de datos | `2025-01-01` → `2026-06-01` |
| Última carga | `2026-06-19` |
| `record_source` | `t_retail_transaction` |
| `creation_user` | `gnunurat@inside.com.pe` |
| Tabla origen | `itc-data-governance-01.gnunurat.dv_agente_analisis_datos` |

**DDL:**
```sql
CREATE TABLE `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
(
  process_date       DATE,
  empresa            STRING,
  marca              STRING,
  canal_venta        STRING,
  departamento       STRING,
  categoria          STRING,
  subcategoria       STRING,
  cant_clientes      INTEGER,
  clientes_hll       BYTES,
  mto_venta_bruta    FLOAT64,
  mto_venta_neta     FLOAT64,
  cant_transacciones INTEGER,
  transacciones_hll  BYTES,
  load_date          DATE,
  record_source      STRING,
  creation_user      STRING
)
PARTITION BY process_date
CLUSTER BY empresa, canal_venta, categoria, subcategoria;
```

---

## Diccionario de Campos

### 1. Dimensión temporal

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `process_date` | DATE | YES | **Campo de partición.** Primer día del mes del período de análisis. Valores: `2025-01-01` → `2026-06-01` (mensual). Filtrar siempre: `WHERE process_date = '2026-06-01'` o rango de fechas. |

### 2. Dimensiones de empresa y canal

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `empresa` | STRING | YES | Empresa del Grupo Intercorp. 4 valores. Ver tabla de valores abajo. |
| `marca` | STRING | YES | Enseña comercial de la empresa. 11 marcas distintas. Ver tabla abajo. |
| `canal_venta` | STRING | YES | Canal de la transacción. Valores: `PRESENCIAL` (54.2%), `ONLINE` (45.8%). |

**Valores de `empresa` y `marca`:**

| empresa | marca | Filas |
|---|---|---|
| TIENDAS PERUANAS | OECHSLE | 21,479 |
| FARMACIAS PERUANAS | INKAFARMA | 15,263 |
| FARMACIAS PERUANAS | MIFARMA | 14,968 |
| PROMART | PROMART | 11,510 |
| SUPERMERCADOS PERUANOS | PLAZA VEA | 6,817 |
| SUPERMERCADOS PERUANOS | MASS | 3,452 |
| SUPERMERCADOS PERUANOS | CASH & CARRY | 2,894 |
| SUPERMERCADOS PERUANOS | PLAZA VEA SUPER | 1,653 |
| SUPERMERCADOS PERUANOS | PLAZA VEA EXPRESS | 782 |
| SUPERMERCADOS PERUANOS | VIVANDA | 502 |
| SUPERMERCADOS PERUANOS | MERKAO | 292 |

### 3. Dimensiones geográfica y de producto

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `departamento` | STRING | YES | Departamento del punto de venta. 26 departamentos distintos. **1,633 NULLs (2.05%)** — compras online sin geolocalización de POS. |
| `categoria` | STRING | YES | Categoría de producto. 30 categorías distintas. **107 NULLs (0.13%)**. Ver top categorías abajo. |
| `subcategoria` | STRING | YES | Subcategoría de producto. 98 subcategorías distintas. **107 NULLs (0.13%)** — mismo conjunto que `categoria`. |

**Top 10 categorías por filas:**

| Categoría | Filas |
|---|---|
| CONSUMO | 10,677 |
| NUTRICION | 8,941 |
| FRESCOS | 6,140 |
| NON FOOD | 4,762 |
| ABARROTES | 4,482 |
| MEDICAMENTO ETICO | 3,600 |
| ELECTROHOGAR | 3,426 |
| MEDICAMENTO POPULAR | 3,165 |
| HOGAR Y DECO | 3,047 |
| OTROS | 3,028 |

### 4. Métricas de negocio

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `cant_clientes` | INTEGER | YES | Cantidad de clientes únicos que compraron en la combinación de dimensiones del período. Promedio por fila: 7,157. Máximo: 1,093,911. |
| `clientes_hll` | BYTES | YES | **Sketch HyperLogLog** del conteo de clientes únicos. Usar con `HLL_COUNT.MERGE()` para combinar sin duplicar al agregar varias filas. Ver nota abajo. |
| `mto_venta_bruta` | FLOAT64 | YES | Monto de venta bruta en soles (S/.) antes de descuentos y devoluciones. Promedio por fila: S/ 497,073. Total acumulado: ~S/ 39,572 millones. |
| `mto_venta_neta` | FLOAT64 | YES | Monto de venta neta en soles (S/.) después de descuentos. Promedio por fila: S/ 427,739. Total acumulado: ~S/ 34,053 millones. |
| `cant_transacciones` | INTEGER | YES | Cantidad de transacciones del período. Total acumulado: ~1,524 millones. |
| `transacciones_hll` | BYTES | YES | **Sketch HyperLogLog** de transacciones únicas. Usar con `HLL_COUNT.MERGE()` para agregaciones sin duplicar. **122 NULLs (0.15%)**. |

> ⚠️ **Uso de campos HLL:** Los campos `clientes_hll` y `transacciones_hll` almacenan sketches de HyperLogLog para conteo aproximado de distintos. Para obtener clientes únicos al cruzar múltiples filas usar `HLL_COUNT.MERGE(clientes_hll)` en lugar de `SUM(cant_clientes)`. Esto evita doble conteo de clientes que compraron en varias categorías o marcas en el mismo período.

### 5. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | DATE | YES | Fecha de carga del ETL. Valor: `2026-06-19`. |
| `record_source` | STRING | YES | Tabla origen de los datos. Valor: `t_retail_transaction`. |
| `creation_user` | STRING | YES | Usuario que ejecutó la carga. Valor: `gnunurat@inside.com.pe`. |

---

## Volumetría por Empresa

| Empresa | Filas | Clientes-período acumulados | Venta Neta Total |
|---|---|---|---|
| FARMACIAS PERUANAS | 30,231 | 283,943,291 | ~S/ 9,793 M |
| SUPERMERCADOS PERUANOS | 16,392 | 246,906,892 | ~S/ 19,404 M |
| TIENDAS PERUANAS | 21,479 | 18,821,627 | ~S/ 1,981 M |
| PROMART | 11,510 | 20,139,708 | ~S/ 2,875 M |
| **TOTAL** | **79,612** | **569,811,518** | **~S/ 34,053 M** |

> Los "Clientes-período acumulados" representan sumas de `cant_clientes` por fila (no clientes únicos). Para clientes únicos, usar `HLL_COUNT.MERGE(clientes_hll)`.

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `dv_agente_analisis_datos_pos` (bi_itcm_agent) | `process_date` | Share of wallet total: venta interna vs. gasto externo de clientes Intercorp |
| `dv_clientes_empresa` (bi_itcm_somos1) | `empresa`, `process_date` (via anio+mes) | Enriquecer con perfil cross-retail y demográfico |
| `dv_inretail_venta` (bi_vuc_insight) | `empresa`, `departamento`, `process_date` | Comparar con fuente alternativa de ventas InRetail |

---

## Reglas de Negocio

1. **Filtrar siempre por `process_date`** — `WHERE process_date = '2026-06-01'` para un mes específico. Sin filtro escanea todas las 18 particiones.

2. **`cant_clientes` vs. `HLL_COUNT.MERGE(clientes_hll)`** — Para contar clientes únicos al agregar por empresa o período, usar el HLL. `SUM(cant_clientes)` cuenta la misma persona múltiples veces si compró en varias categorías.

3. **`mto_venta_neta` es la métrica principal** — Es el monto después de descuentos y devoluciones. Usar para análisis de ingresos. `mto_venta_bruta` para análisis de precio tarjeta.

4. **`departamento` NULL = compra online sin POS físico** — Al analizar por geografía, excluir o tratar por separado los registros con `departamento IS NULL` (2.05%).

5. **`marca` = enseña comercial** — Una empresa puede tener varias marcas. Al analizar a nivel empresa, agrupar por `empresa`, no por `marca`.

6. **Período = mes del proceso** — `process_date` es el primer día del mes. Agrupar por `FORMAT_DATE('%Y-%m', process_date)` para análisis mensual.

7. **Si no se menciona empresa, mostrar todas agrupadas** — Cuando la pregunta no filtra ni especifica una empresa en particular, el resultado debe desglosarse por todas las empresas disponibles (`GROUP BY empresa`). No consolidar en un total único a menos que se pida explícitamente el total del grupo.

8. **⚠️ NUNCA usar `SUM(cant_transacciones)` para contar transacciones** — El grano de la tabla incluye `categoria` y `subcategoria`: un mismo ticket con productos de varias categorías aparece en múltiples filas. `SUM(cant_transacciones)` puede inflar el resultado hasta 2x. Usar siempre `HLL_COUNT.MERGE(transacciones_hll)` para conteos de transacciones cuando se agrupa por empresa, canal, departamento o cualquier dimensión más gruesa que el grano de la tabla.

9. **⚠️ NUNCA usar `SUM(cant_clientes)` para contar clientes únicos entre períodos o dimensiones** — Misma razón que la regla anterior. Usar `HLL_COUNT.MERGE(clientes_hll)` para obtener clientes únicos al combinar filas de distintas categorías, marcas o meses.

10. **NUNCA hardcodear `process_date`** — El período más reciente cambia con cada carga. Usar siempre `(SELECT MAX(process_date) FROM \`itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos\`)` como ancla dinámica para "último mes".

---

## Observaciones de Calidad de Datos

| Campo | % NULL / Observación |
|---|---|
| `departamento` | 2.05% NULL (1,633 filas) — compras online sin ubicación POS |
| `categoria` / `subcategoria` | 0.13% NULL (107 filas) — productos sin clasificación |
| `transacciones_hll` | 0.15% NULL (122 filas) — sketch no generado para esas combinaciones |
| `clientes_hll` | 0% NULL — presente en todas las filas |
| `record_source` | Siempre `t_retail_transaction` |

---

## Queries de Referencia

> **Reglas que todo query debe respetar:**
> - `process_date` → siempre dinámico con `MAX(process_date)`, nunca hardcodeado.
> - Transacciones → siempre `HLL_COUNT.MERGE(transacciones_hll)`, nunca `SUM(cant_transacciones)`.
> - Clientes únicos → siempre `HLL_COUNT.MERGE(clientes_hll)`, nunca `SUM(cant_clientes)`.
> - Sin empresa especificada → `GROUP BY empresa` (mostrar todas).
> - Ticket promedio → `SAFE_DIVIDE(SUM(mto_venta_neta), HLL_COUNT.MERGE(transacciones_hll))`.

```sql
-- ══════════════════════════════════════════════════════════════
-- A. ÚLTIMO MES
-- ══════════════════════════════════════════════════════════════

-- A1. Venta neta del último mes por empresa (todas las empresas)
SELECT
  empresa,
  ROUND(SUM(mto_venta_neta) / 1e6, 2) AS venta_neta_MM_soles
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa
ORDER BY venta_neta_MM_soles DESC;

-- A2. Venta neta y transacciones del último mes — online vs presencial, por empresa
SELECT
  empresa,
  canal_venta,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)       AS venta_neta_MM_soles,
  HLL_COUNT.MERGE(transacciones_hll)         AS transacciones  -- ⚠️ HLL obligatorio: SUM infla hasta 2x por grano categoria/subcategoria
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa, canal_venta
ORDER BY empresa, canal_venta;

-- A3. Ticket promedio del último mes por empresa, marca y canal
SELECT
  empresa,
  marca,
  canal_venta,
  SAFE_DIVIDE(
    SUM(mto_venta_neta),
    HLL_COUNT.MERGE(transacciones_hll)       -- ⚠️ HLL obligatorio: SUM subestima ticket hasta 4x
  ) AS ticket_promedio_soles
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa, marca, canal_venta
ORDER BY ticket_promedio_soles DESC;

-- A4. Participación (%) de cada marca dentro de su empresa en el último mes
SELECT
  empresa,
  marca,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)                                                          AS venta_neta_MM,
  ROUND(SAFE_DIVIDE(SUM(mto_venta_neta),
        SUM(SUM(mto_venta_neta)) OVER (PARTITION BY empresa)) * 100, 1)                         AS pct_empresa
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa, marca
ORDER BY empresa, pct_empresa DESC;

-- A5. Clientes únicos del último mes por empresa (HLL)
SELECT
  empresa,
  HLL_COUNT.MERGE(clientes_hll)  AS clientes_unicos  -- ⚠️ HLL obligatorio: evita doble conteo por categoria/subcategoria
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa
ORDER BY clientes_unicos DESC;

-- A6. Top 10 categorías por venta neta en el último mes (todas las empresas o filtrar por marca)
SELECT
  categoria,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)    AS venta_neta_MM,
  HLL_COUNT.MERGE(transacciones_hll)      AS transacciones
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
  AND categoria IS NOT NULL
  -- AND marca = 'PLAZA VEA'  -- ← descomentar para filtrar por marca específica
GROUP BY categoria
ORDER BY venta_neta_MM DESC
LIMIT 10;

-- A7. Venta neta y transacciones por departamento en el último mes (todas las empresas)
SELECT
  departamento,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)    AS venta_neta_MM,
  HLL_COUNT.MERGE(transacciones_hll)      AS transacciones  -- ⚠️ HLL obligatorio
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
  AND departamento IS NOT NULL
GROUP BY departamento
ORDER BY venta_neta_MM DESC;


-- ══════════════════════════════════════════════════════════════
-- B. MES A MES (MoM) — último mes vs. mes anterior
-- ══════════════════════════════════════════════════════════════

-- B1. Variación de venta neta MoM por empresa
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  ROUND(SUM(CASE WHEN process_date = mes_actual
                 THEN mto_venta_neta END) / 1e6, 2)                                   AS venta_mes_actual_MM,
  ROUND(SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH)
                 THEN mto_venta_neta END) / 1e6, 2)                                   AS venta_mes_anterior_MM,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN process_date = mes_actual THEN mto_venta_neta END) -
    SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN mto_venta_neta END),
    SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN mto_venta_neta END)
  ) * 100, 1)                                                                          AS var_pct_mom
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY venta_mes_actual_MM DESC;

-- B2. Variación de ticket promedio MoM por empresa
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN process_date = mes_actual THEN mto_venta_neta END),
    HLL_COUNT.MERGE(CASE WHEN process_date = mes_actual THEN transacciones_hll END)
  ), 2)                                                                                 AS ticket_mes_actual,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN mto_venta_neta END),
    HLL_COUNT.MERGE(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN transacciones_hll END)
  ), 2)                                                                                 AS ticket_mes_anterior,
  ROUND(SAFE_DIVIDE(
    SAFE_DIVIDE(SUM(CASE WHEN process_date = mes_actual THEN mto_venta_neta END),
                HLL_COUNT.MERGE(CASE WHEN process_date = mes_actual THEN transacciones_hll END)) -
    SAFE_DIVIDE(SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN mto_venta_neta END),
                HLL_COUNT.MERGE(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN transacciones_hll END)),
    SAFE_DIVIDE(SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN mto_venta_neta END),
                HLL_COUNT.MERGE(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 1 MONTH) THEN transacciones_hll END))
  ) * 100, 1)                                                                           AS var_pct_ticket_mom
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY ticket_mes_actual DESC;


-- ══════════════════════════════════════════════════════════════
-- C. INTERANUAL MENSUAL — último mes vs. mismo mes año anterior
-- ══════════════════════════════════════════════════════════════

-- C1. Variación interanual mensual de venta neta por empresa
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  ROUND(SUM(CASE WHEN process_date = mes_actual
                 THEN mto_venta_neta END) / 1e6, 2)                                   AS venta_mes_actual_MM,
  ROUND(SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 12 MONTH)
                 THEN mto_venta_neta END) / 1e6, 2)                                   AS venta_mismo_mes_anio_ant_MM,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN process_date = mes_actual THEN mto_venta_neta END) -
    SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 12 MONTH) THEN mto_venta_neta END),
    SUM(CASE WHEN process_date = DATE_SUB(mes_actual, INTERVAL 12 MONTH) THEN mto_venta_neta END)
  ) * 100, 1)                                                                          AS var_pct_yoy
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY venta_mes_actual_MM DESC;


-- ══════════════════════════════════════════════════════════════
-- D. ÚLTIMO TRIMESTRE (3 meses cerrados)
-- ══════════════════════════════════════════════════════════════

-- D1. Venta neta del último trimestre por empresa
SELECT
  empresa,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date BETWEEN
    DATE_SUB((SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`), INTERVAL 2 MONTH)
    AND (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa
ORDER BY venta_neta_MM DESC;

-- D2. Evolución trimestral (por trimestre calendario) de venta neta — últimos 4 trimestres
--     Reemplazar marca = 'INKAFARMA' por la solicitada, o quitar filtro de marca para ver todas las empresas
SELECT
  DATE_TRUNC(process_date, QUARTER)        AS trimestre,
  empresa,
  -- marca,                                -- descomentar si se quiere desglose por marca
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date > DATE_SUB(
    (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`),
    INTERVAL 12 MONTH)
  -- AND marca = 'INKAFARMA'               -- descomentar para filtrar por marca específica
GROUP BY trimestre, empresa  -- agregar marca si se descomenta arriba
ORDER BY trimestre, empresa;


-- ══════════════════════════════════════════════════════════════
-- E. ÚLTIMOS 12 MESES, YTD E INTERANUAL AJUSTADO
-- ══════════════════════════════════════════════════════════════

-- E1. Venta neta y transacciones — últimos 12 meses por empresa
SELECT
  empresa,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM,
  HLL_COUNT.MERGE(transacciones_hll)       AS transacciones  -- ⚠️ HLL obligatorio
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date BETWEEN
    DATE_SUB((SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`), INTERVAL 11 MONTH)
    AND (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa
ORDER BY venta_neta_MM DESC;

-- E2. YTD — venta neta desde enero del año en curso hasta último mes cerrado
SELECT
  empresa,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_ytd_MM
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date BETWEEN
    DATE_TRUNC((SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`), YEAR)
    AND (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY empresa
ORDER BY venta_ytd_MM DESC;

-- E3. YTD actual vs. YTD mismo período año anterior
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  ROUND(SUM(CASE WHEN EXTRACT(YEAR FROM process_date) = EXTRACT(YEAR FROM mes_actual)
                 THEN mto_venta_neta END) / 1e6, 2)                                    AS venta_ytd_actual_MM,
  ROUND(SUM(CASE WHEN EXTRACT(YEAR FROM process_date) = EXTRACT(YEAR FROM mes_actual) - 1
                  AND EXTRACT(MONTH FROM process_date) <= EXTRACT(MONTH FROM mes_actual)
                 THEN mto_venta_neta END) / 1e6, 2)                                    AS venta_ytd_anio_ant_MM,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN EXTRACT(YEAR FROM process_date) = EXTRACT(YEAR FROM mes_actual) THEN mto_venta_neta END) -
    SUM(CASE WHEN EXTRACT(YEAR FROM process_date) = EXTRACT(YEAR FROM mes_actual) - 1
              AND EXTRACT(MONTH FROM process_date) <= EXTRACT(MONTH FROM mes_actual) THEN mto_venta_neta END),
    SUM(CASE WHEN EXTRACT(YEAR FROM process_date) = EXTRACT(YEAR FROM mes_actual) - 1
              AND EXTRACT(MONTH FROM process_date) <= EXTRACT(MONTH FROM mes_actual) THEN mto_venta_neta END)
  ) * 100, 1)                                                                           AS var_pct_ytd
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY venta_ytd_actual_MM DESC;

-- E4. Comparación interanual ajustada a historia disponible (ventana dinámica)
--     Compara los últimos N meses vs. los mismos N meses del año anterior.
--     N = LEAST(12, meses_de_historia - 12). Con 18 meses disponibles N=6; sube a 12 con 24+ meses.
WITH rango AS (
  SELECT
    MAX(process_date) AS mes_actual,
    MIN(process_date) AS mes_min
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
),
params AS (
  SELECT
    mes_actual,
    LEAST(12, DATE_DIFF(mes_actual, mes_min, MONTH) + 1 - 12) AS n_meses
  FROM rango
)
SELECT
  empresa,
  ROUND(SUM(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL (n_meses - 1) MONTH) AND mes_actual
                 THEN mto_venta_neta END) / 1e6, 2)                                    AS venta_periodo_actual_MM,
  ROUND(SUM(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL (n_meses + 11) MONTH)
                                       AND DATE_SUB(mes_actual, INTERVAL 12 MONTH)
                 THEN mto_venta_neta END) / 1e6, 2)                                    AS venta_periodo_anterior_MM,
  ROUND(SAFE_DIVIDE(
    SUM(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL (n_meses - 1) MONTH) AND mes_actual
             THEN mto_venta_neta END) -
    SUM(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL (n_meses + 11) MONTH)
                                   AND DATE_SUB(mes_actual, INTERVAL 12 MONTH)
             THEN mto_venta_neta END),
    SUM(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL (n_meses + 11) MONTH)
                                   AND DATE_SUB(mes_actual, INTERVAL 12 MONTH)
             THEN mto_venta_neta END)
  ) * 100, 1)                                                                           AS var_pct
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN params
GROUP BY empresa, mes_actual, n_meses
ORDER BY venta_periodo_actual_MM DESC;

-- E5. Evolución mensual de venta neta de una marca — últimos 12 meses
SELECT
  process_date,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE marca = 'MIFARMA'                    -- reemplazar por la marca solicitada
  AND process_date BETWEEN
      DATE_SUB((SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`), INTERVAL 11 MONTH)
      AND (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY process_date
ORDER BY process_date;


-- ══════════════════════════════════════════════════════════════
-- F. TRANSACCIONES Y CLIENTES (HLL) — MULTI-PERÍODO
-- ══════════════════════════════════════════════════════════════

-- F1. Transacciones totales por empresa — último mes, último trimestre, últimos 12 meses y YTD
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  HLL_COUNT.MERGE(CASE WHEN process_date = mes_actual
                       THEN transacciones_hll END)                                     AS txn_ultimo_mes,
  HLL_COUNT.MERGE(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL 2 MONTH) AND mes_actual
                       THEN transacciones_hll END)                                     AS txn_ultimo_trimestre,
  HLL_COUNT.MERGE(CASE WHEN process_date BETWEEN DATE_SUB(mes_actual, INTERVAL 11 MONTH) AND mes_actual
                       THEN transacciones_hll END)                                     AS txn_ultimos_12m,
  HLL_COUNT.MERGE(CASE WHEN process_date BETWEEN DATE_TRUNC(mes_actual, YEAR) AND mes_actual
                       THEN transacciones_hll END)                                     AS txn_ytd
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY txn_ultimo_mes DESC;

-- F2. Clientes únicos por empresa — último mes y YTD (HLL)
WITH ancla AS (
  SELECT MAX(process_date) AS mes_actual
  FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
)
SELECT
  empresa,
  HLL_COUNT.MERGE(CASE WHEN process_date = mes_actual
                       THEN clientes_hll END)                                          AS clientes_ultimo_mes,
  HLL_COUNT.MERGE(CASE WHEN process_date BETWEEN DATE_TRUNC(mes_actual, YEAR) AND mes_actual
                       THEN clientes_hll END)                                          AS clientes_ytd
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
CROSS JOIN ancla
GROUP BY empresa, mes_actual
ORDER BY clientes_ultimo_mes DESC;


-- ══════════════════════════════════════════════════════════════
-- G. CATEGORÍAS Y GEOGRAFÍA
-- ══════════════════════════════════════════════════════════════

-- G1. Top categorías por venta neta de una marca — YTD
SELECT
  categoria,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE marca = 'PLAZA VEA'                  -- reemplazar por la marca solicitada
  AND categoria IS NOT NULL
  AND process_date BETWEEN
      DATE_TRUNC((SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`), YEAR)
      AND (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
GROUP BY categoria
ORDER BY venta_neta_MM DESC
LIMIT 10;

-- G2. Venta neta y clientes únicos por departamento — último mes (todas las empresas)
SELECT
  departamento,
  ROUND(SUM(mto_venta_neta) / 1e6, 2)     AS venta_neta_MM,
  HLL_COUNT.MERGE(clientes_hll)            AS clientes_unicos,
  HLL_COUNT.MERGE(transacciones_hll)       AS transacciones
FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`
WHERE process_date = (SELECT MAX(process_date) FROM `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos`)
  AND departamento IS NOT NULL
GROUP BY departamento
ORDER BY venta_neta_MM DESC;
```

---

> **Nota de profiling:** Catálogo generado desde `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos` (réplica de `gnunurat.dv_agente_analisis_datos`). El Catalog ID `bi_itcm_agent.dv_agente_analisis_datos` es el identificador canónico para el agente de análisis.

*Generado: 2026-06-26 | Fuente: BigQuery `itc-data-governance-01.bi_itcm_agent.dv_agente_analisis_datos` | 79,612 filas · 882 MB · 16 columnas · 18 particiones*
