# Catálogo de Datos — `informacion_tipificaciones`

**Catalog ID:** `ba_fape_agent.informacion_tipificaciones`
**Proyecto canónico:** `itc-data-governance-01`
**Dataset:** `ba_fape_agent`
**Tabla completa:** `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
**Profiling realizado sobre:** `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
_(tabla origen — el catalog ID es el mismo)_

---

## Descripción

Tabla analítica del **FAPE Agent** (Farmacias — Inkafarma / Mifarma) que consolida la
**tipificación de cupones por campaña**. Cada fila representa un cupón de campaña
(identificado por `llave`, clave única) enriquecido con su categorización de negocio
(jerarquías `jq1`/`jq2`/`jq3`, `marca`, `categoria`), sus métricas económicas
(`venta_cup`, `costo_cupon`, `margen_cupon`, `usos_cupon`, `emisiones`) y — el aporte
central de la tabla — su **tipificación semántica** (`tipificacion_detalle`,
`tipificacion_2_categoria`), obtenida por un proceso de matching que registra su
procedencia en `tipif_fuente` (EXACTO vs FUZZY).

Cubre dos corporaciones farmacéuticas del grupo (**MIFARMA** e **INKAFARMA**) sobre el
período **202401 → 202607** (mensual). Su propósito es permitir al analista responder
qué cupones se emitieron, cuánta venta y margen generaron, y bajo qué categoría/tipificación
de negocio se clasifican — sirviendo de base para análisis de efectividad de cupones y
alimentación del agente conversacional FAPE.

Fue cargada desde el archivo `Informacion tipificaciones.csv` (ver `description` de la tabla
en BigQuery). No sigue la nomenclatura estándar de la plataforma ITC (sin `itc_company_id`,
sin prefijo de capa, sin partición): es una tabla de trabajo analítica del caso de uso FAPE.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | Sin partición |
| Clusterizado | NO |
| Total de filas | 18,110 |
| Número de columnas | 22 |
| Tamaño lógico | ~5.63 MB |
| Tamaño físico | ~5.63 MB |
| Particiones | N/A |
| Rango de período (`periodo`) | 202401 → 202607 (31 meses) |
| Frecuencia | Carga única / batch desde CSV |
| Fuente | `Informacion tipificaciones.csv` |
| Ubicación | US |

---

## Volumen por corporación

| Corporación | Registros | % |
|---|---|---|
| MIFARMA | 9,932 | 54.8% |
| INKAFARMA | 8,178 | 45.2% |
| **Total** | **18,110** | **100%** |

> `llave` es única en las 18,110 filas (clave primaria de facto). `key_norm` tiene solo
> 5,560 valores distintos — es la clave normalizada usada para el matching de tipificación
> (varias `llave` comparten el mismo `key_norm`).

**Totales económicos (toda la tabla):** venta ~S/ 843.8 MM · costo ~S/ 552.8 MM ·
margen ~S/ 291.0 MM · usos 24,412,584 · emisiones 1,227,600,722.

---

## Glosario de Campos

### 1. Identificadores y control

| Campo | Tipo | Descripción |
|---|---|---|
| `llave` | STRING | **Clave primaria** — identificador único del cupón/campaña (18,110 valores distintos = total de filas). Clave de grano de la tabla. |
| `key_norm` | STRING | Abreviatura normalizada de la descripción del cupón (`desc_cupon`), usada para el proceso de tipificación por matching (5,560 valores distintos). Varias `llave` comparten el mismo `key_norm`. Permite identificar la misma campaña a través de distintos períodos — usar como clave de join para comparaciones MoM. |
| `periodo` | INT64 | Período mensual en formato `YYYYMM` (202401 → 202607). Campo de filtro temporal — la tabla no tiene partición física, filtrar por este campo. |
| `corporacion` | STRING | Corporación farmacéutica: `MIFARMA` (9,932) o `INKAFARMA` (8,178). Único discriminador de empresa (esta tabla no usa `itc_company_id`). |
| `cod_campania_cupon` | STRING | Código de la campaña del cupón (13,060 valores distintos). Identificador operacional de la campaña de origen. |
| `desc_cupon` | STRING | Descripción textual del cupón (6,562 valores distintos). Texto libre de la mecánica/oferta del cupón. |

### 2. Jerarquía y categorización de negocio

| Campo | Tipo | Descripción |
|---|---|---|
| `tipo_desc_campana` | STRING | Tipo de campaña del cupón. Valores: `D` (Digital, 9,096), `FD` (Personalizado, 2,698), `M` (Masivo, 2,364), `FLASH` (2,148), `RULETA` (1,804). |
| `jq1` | STRING | Jerarquía de categoría nivel 1. Valores: `NUTRICION` (7,787), `CONSUMO` (7,239), `FARMA` (1,141), `OTROS` (144), NULL (1,799). |
| `jq2` | STRING | Jerarquía de categoría nivel 2 (16 valores distintos). **2,200 NULL (~12%)**. Subcategoría dentro de `jq1`. |
| `jq3` | STRING | Jerarquía de categoría nivel 3 (52 valores distintos). Nivel más fino de la jerarquía de categoría comercial. |
| `marca` | STRING | Marca del producto asociado al cupón (328 valores distintos). **1,799 NULL (~9.9%)**. |
| `categoria` | STRING | Categoría comercial resumida (6 valores distintos). **1,799 NULL (~9.9%)**. |
| `mecanica` | STRING | Porcentaje de descuento del cupón (330 valores distintos) — ej. `15%`, `20%`. Representa el nivel de descuento aplicado en la mecánica del cupón. |

### 3. Métricas económicas

| Campo | Tipo | Descripción |
|---|---|---|
| `venta_cup` | FLOAT64 | Venta atribuida al cupón (S/). Rango [-753.97 ; 5,349,115.34], promedio ~51,734. **1,799 NULL; 1,021 valores negativos** (devoluciones/ajustes). |
| `usos_cupon` | INT64 | Número de usos/redenciones del cupón. Rango [-21 ; 170,748]. **1,799 NULL**. Valores negativos indican ajustes/anulaciones. |
| `costo_cupon` | FLOAT64 | Costo asociado al cupón (S/). **1,799 NULL**. Base para el cálculo de `margen_cupon`. |
| `margen_cupon` | FLOAT64 | Margen del cupón (S/) = venta − costo (aprox.). Rango [-186,718.18 ; 2,144,481.76]. **1,799 NULL; 2,975 negativos** (cupones con margen negativo). |
| `emisiones` | INT64 | Número de emisiones del cupón. Rango [1 ; 3,749,612]. **1,483 NULL**. |

### 4. Tipificación semántica (aporte central de la tabla)

| Campo | Tipo | Descripción |
|---|---|---|
| `tipificacion_detalle` | STRING | Tipificación detallada del cupón (485 valores distintos). Etiqueta semántica de negocio asignada por el proceso de tipificación. |
| `tipificacion_2_categoria` | STRING | Categoría de segundo nivel de la tipificación (237 valores distintos). Ej.: `VITAMINAS Y MINERALES`, `TODO BUCAL`, `DESECHABLE INFANTIL`, `COLAGENO`. **289 NULL**. |
| `tipif_fuente` | STRING | Control interno del proceso de tipificación: `EXACTO` (17,094 — match exacto), `FUZZY` (717 — match aproximado), NULL (299 — sin tipificar). No es una dimensión de análisis de negocio — usar `tipificacion_detalle` para análisis. Útil solo para filtrar calidad: excluir `FUZZY` y NULL en análisis de tipificación sensibles. |
| `flag_sin_tipificar` | STRING | Control interno: `VERDADERO` (285 cupones sin tipificar) / `FALSO` (17,825 tipificados). Campo auxiliar del proceso, no de análisis de negocio. Equivalente a `tipif_fuente IS NULL` para filtrar. |

---

## Relación con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `ba_fape_agent.ventas_jq3_cupon` | `jq3` (+ `categoria`, `periodo`) | Contrastar tipificación de cupón con la venta agregada por JQ3 y tipo de cupón |
| `ba_fape_agent.ventas_zonas` | `jq3` / `categoria` / `marca` | Cruzar cupones tipificados con la venta de mesón por zona y jerarquía |
| Fuente de tipificaciones (externa/CSV) | `key_norm` | Origen del matching que pobló `tipificacion_detalle` y `tipif_fuente` |

> Los joins entre tablas del dataset `ba_fape_agent` se hacen por las jerarquías de negocio
> (`jq3`, `categoria`, `marca`, `periodo`), no por identificadores de cliente — ninguna de
> estas tablas contiene datos de cliente individual ni PII.

---

## Empresas cubiertas

| Corporación | Registros | Nota |
|---|---|---|
| MIFARMA | 9,932 | Farmacia (`itc_company_id` equivalente = 048) |
| INKAFARMA | 8,178 | Farmacia (`itc_company_id` equivalente = 025) |

> La tabla usa el campo `corporacion` (texto), no el estándar `itc_company_id`.

---

## Reglas de negocio

1. **Grano = cupón de campaña.** Cada fila es un cupón único identificado por `llave`.
   Para contar cupones usar `COUNT(*)` o `COUNT(DISTINCT llave)` (equivalentes).
2. **Filtrar por `periodo`** (formato `YYYYMM`) para acotar temporalmente — no existe
   partición física, así que el filtro es lógico sobre esta columna.
3. **Tipificación y su confiabilidad.** `tipif_fuente = 'EXACTO'` (94.4%) es match directo
   y confiable; `'FUZZY'` (4.0%) es aproximado y debe validarse; NULL o
   `flag_sin_tipificar = 'VERDADERO'` (~1.6%) son cupones sin clasificar — excluirlos en
   análisis de tipificación.
4. **1,799 filas sin métricas ni jerarquía.** El mismo grupo de 1,799 filas tiene NULL
   simultáneo en `jq1`, `marca`, `categoria`, `venta_cup`, `usos_cupon`, `costo_cupon` y
   `margen_cupon`. Son cupones tipificados pero sin venta/atribución económica asociada —
   filtrarlos con `venta_cup IS NOT NULL` para análisis financieros.
5. **Valores negativos.** `venta_cup` (1,021 filas), `margen_cupon` (2,975 filas) y
   `usos_cupon` pueden ser negativos por devoluciones, anulaciones o ajustes. Considerarlos
   según el análisis (sumar netos) o excluirlos según el caso.
6. **Márgenes.** El margen puede ser negativo (2,975 cupones): el descuento del cupón
   superó el margen del producto. Relevante para análisis de rentabilidad de campañas.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `venta_cup`, `usos_cupon`, `costo_cupon`, `margen_cupon` | ~9.9% (1,799) | Mismo conjunto de filas sin atribución económica |
| `jq1`, `marca`, `categoria` | ~9.9% (1,799) | Coincide con las filas sin métricas — cupones sin jerarquía comercial |
| `jq2` | ~12.1% (2,200) | Nivel intermedio de jerarquía frecuentemente vacío |
| `emisiones` | ~8.2% (1,483) | Sin dato de emisiones |
| `tipificacion_2_categoria` | ~1.6% (289) | Sin categoría de tipificación de 2º nivel |
| `tipif_fuente` | ~1.7% (299) | Cupones no tipificados |
| `venta_cup` (negativos) | — | 1,021 filas < 0 (devoluciones/ajustes) |
| `margen_cupon` (negativos) | — | 2,975 filas < 0 (cupones con pérdida de margen) |

---

## Queries de referencia

```sql
-- 1. Efectividad de cupones tipificados por categoría de tipificación (solo matches confiables)
SELECT
  tipificacion_2_categoria,
  COUNT(*) AS cupones,
  ROUND(SUM(venta_cup), 2) AS venta_total,
  ROUND(SUM(margen_cupon), 2) AS margen_total,
  SUM(usos_cupon) AS usos_total
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE tipif_fuente = 'EXACTO'
  AND venta_cup IS NOT NULL
GROUP BY 1
ORDER BY venta_total DESC;

-- 2. Venta y margen por corporación y tipo de campaña, por período
SELECT
  periodo, corporacion, tipo_desc_campana,
  COUNT(*) AS cupones,
  ROUND(SUM(venta_cup), 2) AS venta,
  ROUND(SUM(margen_cupon), 2) AS margen
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE venta_cup IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY periodo DESC, venta DESC;

-- 3. Cupones con margen negativo (alerta de rentabilidad)
SELECT
  corporacion, jq1, categoria, desc_cupon,
  venta_cup, costo_cupon, margen_cupon, usos_cupon
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE margen_cupon < 0
ORDER BY margen_cupon ASC
LIMIT 100;

-- 4. Cupones sin tipificar (para revisión / mejora del matching)
SELECT llave, key_norm, corporacion, desc_cupon, mecanica
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE flag_sin_tipificar = 'VERDADERO' OR tipif_fuente IS NULL;

-- 5. Campañas con mayor venta en el mes más reciente vs mes anterior
-- (¿Cuáles son las campañas de cupón que generan mayor venta vs. mes pasado?)
SELECT
  key_norm, desc_cupon, corporacion, tipo_desc_campana,
  ROUND(SUM(IF(periodo = 202607, venta_cup, 0)), 2) AS venta_actual,
  ROUND(SUM(IF(periodo = 202606, venta_cup, 0)), 2) AS venta_mes_ant,
  ROUND(SAFE_DIVIDE(
    SUM(IF(periodo = 202607, venta_cup, 0)) - SUM(IF(periodo = 202606, venta_cup, 0)),
    SUM(IF(periodo = 202606, venta_cup, 0))) * 100, 1) AS var_pct
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE venta_cup IS NOT NULL
GROUP BY 1, 2, 3, 4
HAVING SUM(IF(periodo = 202607, venta_cup, 0)) > 0
ORDER BY venta_actual DESC
LIMIT 20;

-- 6. Campañas que disminuyeron su redención vs mes anterior
-- (¿Cuáles son las campañas que han disminuido su redención vs. mes pasado?)
SELECT
  key_norm, desc_cupon, corporacion, tipo_desc_campana,
  SUM(IF(periodo = 202607, usos_cupon, 0)) AS usos_actual,
  SUM(IF(periodo = 202606, usos_cupon, 0)) AS usos_mes_ant,
  SUM(IF(periodo = 202607, usos_cupon, 0)) - SUM(IF(periodo = 202606, usos_cupon, 0)) AS delta_usos
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE usos_cupon IS NOT NULL
GROUP BY 1, 2, 3, 4
HAVING delta_usos < 0
ORDER BY delta_usos ASC
LIMIT 20;

-- 7. Desempeño por tipo de campaña: venta, emisiones, usos y tasa de redención
-- (¿Cómo se desempeña cada tipo de campaña a nivel de venta, emisiones, usos y redención?)
SELECT
  tipo_desc_campana,
  COUNT(*)                                                                      AS cupones,
  ROUND(SUM(venta_cup), 2)                                                      AS venta_total,
  SUM(emisiones)                                                                AS emisiones_total,
  SUM(usos_cupon)                                                               AS usos_total,
  ROUND(SAFE_DIVIDE(SUM(usos_cupon), SUM(emisiones)) * 100, 2)                 AS tasa_redencion_pct
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE venta_cup IS NOT NULL AND emisiones IS NOT NULL
GROUP BY 1
ORDER BY venta_total DESC;

-- 8. Campañas donde creció la emisión y cayó el uso vs mes anterior (alerta de baja redención)
-- (¿En qué campañas creció la emisión y disminuyó el uso vs. mes pasado?)
SELECT
  key_norm, desc_cupon, corporacion, tipo_desc_campana,
  SUM(IF(periodo = 202607, emisiones, 0))  - SUM(IF(periodo = 202606, emisiones, 0))  AS delta_emisiones,
  SUM(IF(periodo = 202607, usos_cupon, 0)) - SUM(IF(periodo = 202606, usos_cupon, 0)) AS delta_usos
FROM `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`
WHERE venta_cup IS NOT NULL AND emisiones IS NOT NULL
GROUP BY 1, 2, 3, 4
HAVING delta_emisiones > 0 AND delta_usos < 0
ORDER BY delta_usos ASC
LIMIT 30;
```

---

> **Nota de profiling:** Este glosario fue generado con datos extraídos de
> `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones` (tabla origen del
> caso de uso FAPE Agent, cargada desde `Informacion tipificaciones.csv`).

*Generado: 2026-07-17 | Fuente: BigQuery `itc-data-governance-01.ba_fape_agent.informacion_tipificaciones`*
