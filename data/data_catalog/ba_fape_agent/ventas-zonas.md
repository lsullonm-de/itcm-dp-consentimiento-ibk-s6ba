# Catálogo de Datos — `ventas_zonas`

**Catalog ID:** `ba_fape_agent.ventas_zonas`
**Proyecto canónico:** `itc-data-governance-01`
**Dataset:** `ba_fape_agent`
**Tabla completa:** `itc-data-governance-01.ba_fape_agent.ventas_zonas`
**Profiling realizado sobre:** `itc-data-governance-01.ba_fape_agent.ventas_zonas`
_(tabla origen — el catalog ID es el mismo)_

---

## Descripción

Tabla analítica del **FAPE Agent** (Farmacias) que registra la **venta de mesón por zona
geográfica y jerarquía de categoría**. Cada fila agrega la venta (`venta_meson`) y los usos
(`usos_meson`) para una combinación de período comparativo, corporación, región/zona de Lima
y la jerarquía completa de producto (`categoria` → `jq3` → `jq4` → `jq5` → `marca`).

Su diseño está orientado al **análisis comparativo temporal**: el campo `tipo_periodo`
clasifica cada `periodo` en `MES_ACTUAL` (202607), `MES_ANTERIOR` (202606) y
`MISMO_MES_AÑO_PASADO` (202507), permitiendo comparaciones mes-a-mes (MoM) y
año-contra-año (YoY) de la venta de mesón por zona y categoría directamente en la tabla.

Es la tabla más voluminosa del dataset (317,371 filas). Cubre cuatro corporaciones
(INKAFARMA, MIFARMA, MIA, MAX) y las zonas de Lima más "OTROS". Cargada desde
`ventaszonas.csv`. No usa nomenclatura estándar ITC ni contiene PII.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | Sin partición |
| Clusterizado | NO |
| Total de filas | 317,371 |
| Número de columnas | 12 |
| Tamaño lógico | ~47.24 MB |
| Tamaño físico | ~47.24 MB |
| Particiones | N/A |
| Períodos (`periodo`) | 202507, 202606, 202607 (3 meses comparativos) |
| Frecuencia | Carga única / batch desde CSV |
| Fuente | `ventaszonas.csv` |
| Ubicación | US |

---

## Volumen por período comparativo

| `tipo_periodo` | `periodo` | Filas |
|---|---|---|
| MES_ACTUAL | 202607 | 114,253 |
| MES_ANTERIOR | 202606 | 111,658 |
| MISMO_MES_AÑO_PASADO | 202507 | 91,460 |

### Volumen por corporación

| Corporación | Filas | Categorías | Venta (S/) |
|---|---|---|---|
| INKAFARMA | 160,976 | 6 | 442,047,218 |
| MIFARMA | 153,573 | 6 | 383,214,627 |
| MIA | 2,591 | 4 | 1,077,936 |
| MAX | 231 | 1 | 64,656 |

### Venta por categoría (toda la tabla)

| Categoría | Venta (S/) | Usos |
|---|---|---|
| FARMA | 329,137,248 | 26,250,633 |
| BABY CARE | 129,879,792 | 3,687,996 |
| WELLNESS | 122,739,496 | 5,329,055 |
| OTROS | 107,113,985 | 8,308,025 |
| BEAUTY | 69,129,600 | 1,709,056 |
| PERSONAL CARE | 68,404,316 | 5,191,014 |

> **Totales:** venta ~S/ 826.4 MM · usos 50,475,779. Sin valores NULL en las métricas.

---

## Glosario de Campos

### 1. Dimensiones de tiempo y empresa

| Campo | Tipo | Descripción |
|---|---|---|
| `periodo` | INT64 | Período mensual `YYYYMM`. Solo 3 valores: 202507, 202606, 202607. Campo de filtro temporal (sin partición física). |
| `tipo_periodo` | STRING | Clasificación comparativa del período: `MES_ACTUAL` (202607), `MES_ANTERIOR` (202606), `MISMO_MES_AÑO_PASADO` (202507). Dimensión clave para comparaciones MoM y YoY. |
| `corporacion` | STRING | Corporación/cadena: `INKAFARMA`, `MIFARMA`, `MIA`, `MAX`. Discriminador de empresa (no usa `itc_company_id`). |

### 2. Dimensiones geográficas

| Campo | Tipo | Descripción |
|---|---|---|
| `ubicacion_region` | STRING | Región de ubicación (8 valores distintos). Nivel geográfico superior. |
| `zonalima` | STRING | Zona de Lima (8 valores): `LIMA ESTE`, `LIMA CENTRO NORTE`, `LIMA CENTRO SUR`, `LIMA SUR`, `LIMA NORTE`, `LIMA NORTE CHICO`, `CALLAO`, `OTROS`. |

### 3. Jerarquía de producto

| Campo | Tipo | Descripción |
|---|---|---|
| `categoria` | STRING | Categoría comercial (6 valores): `FARMA`, `BABY CARE`, `WELLNESS`, `OTROS`, `BEAUTY`, `PERSONAL CARE`. Nivel superior de la jerarquía. |
| `jq3` | STRING | Jerarquía de categoría nivel 3 (71 valores distintos). Clave de join con `ventas_jq3_cupon.jq3` e `informacion_tipificaciones.jq3`. |
| `jq4` | STRING | Jerarquía de categoría nivel 4 (253 valores distintos). Subnivel de `jq3`. |
| `jq5` | STRING | Jerarquía de categoría nivel 5 (635 valores distintos). Nivel más fino de la jerarquía de categoría. |
| `marca` | STRING | Marca del producto (3,251 valores distintos). Grano más específico de producto. |

### 4. Métricas

| Campo | Tipo | Descripción |
|---|---|---|
| `venta_meson` | FLOAT64 | Venta de mesón/mostrador (S/) agregada para la combinación de dimensiones. "Mesón" = canal de venta sobre el mostrador, sin aplicación de cupón (venta total del canal). Sin NULL. Total: ~S/ 826.4 MM. |
| `usos_meson` | INT64 | Número de tickets de compra en el canal mesón/mostrador. Cada "uso" equivale a un ticket de venta. Sin NULL. Total: 50,475,779. |

---

## Relación con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `ba_fape_agent.ventas_jq3_cupon` | `jq3`, `categoria`, `periodo` | Comparar venta de mesón (total) contra venta de cupones por jerarquía |
| `ba_fape_agent.informacion_tipificaciones` | `jq3`, `categoria`, `marca` | Cruzar venta por zona con la tipificación de cupones de la misma jerarquía |

---

## Empresas cubiertas

| Corporación | Filas | Venta aprox. |
|---|---|---|
| INKAFARMA | 160,976 | ~S/ 442.0 MM |
| MIFARMA | 153,573 | ~S/ 383.2 MM |
| MIA | 2,591 | ~S/ 1.1 MM |
| MAX | 231 | ~S/ 64.7 K |

> INKAFARMA y MIFARMA concentran >99% de la venta; MIA y MAX son cadenas menores del grupo
> con cobertura parcial de categorías.

---

## Reglas de negocio

1. **Grano = período × corporación × región × zona × jerarquía completa (categoria→jq5) × marca.**
   Cada fila es una agregación de venta de mesón; usar `SUM(venta_meson)` / `SUM(usos_meson)`
   para métricas, nunca `COUNT(*)`.
2. **Comparaciones temporales con `tipo_periodo`.** La tabla trae los tres cortes
   (`MES_ACTUAL`, `MES_ANTERIOR`, `MISMO_MES_AÑO_PASADO`) ya clasificados — usar este campo
   para MoM (actual vs anterior) y YoY (actual vs año pasado) sin necesidad de calcular fechas.
3. **Solo 3 períodos disponibles** (202507, 202606, 202607). No es una serie histórica
   continua: es un snapshot comparativo de un mes contra sus dos referencias.
4. **`ventas_zonas` = venta total de mesón; `ventas_jq3_cupon` = venta atribuida a cupones.**
   No confundir: esta tabla no filtra por cupón, mide la venta total del canal mesón.
5. **Jerarquía anidada.** Respetar el orden `categoria` → `jq3` → `jq4` → `jq5` → `marca`
   al agregar; agrupar por un nivel implica sumar todos los inferiores.
6. **Calidad alta:** sin NULL en métricas ni dimensiones principales.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `venta_meson`, `usos_meson` | 0% | Métricas completas |
| Dimensiones (`corporacion`, `zonalima`, `categoria`, jq*) | 0% | Sin nulos en las dimensiones perfiladas |

> Tabla de alta calidad. Precaución principal: es un corte comparativo de 3 períodos, no una
> serie histórica — no extrapolar tendencias de largo plazo.

---

## Queries de referencia

```sql
-- 1. Comparativo YoY de venta por categoría (MES_ACTUAL vs MISMO_MES_AÑO_PASADO)
SELECT
  categoria,
  ROUND(SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)), 2)            AS venta_actual,
  ROUND(SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)), 2)  AS venta_año_pasado,
  ROUND(SAFE_DIVIDE(
      SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0))
    - SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)),
      SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0))) * 100, 1) AS var_yoy_pct
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
GROUP BY 1
ORDER BY venta_actual DESC;

-- 2. Venta por zona de Lima y corporación en el mes actual
SELECT corporacion, zonalima, ROUND(SUM(venta_meson), 2) AS venta, SUM(usos_meson) AS usos
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
WHERE tipo_periodo = 'MES_ACTUAL'
GROUP BY 1, 2
ORDER BY venta DESC;

-- 3. Top marcas por venta en el mes actual
SELECT marca, ROUND(SUM(venta_meson), 2) AS venta
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
WHERE tipo_periodo = 'MES_ACTUAL'
GROUP BY 1
ORDER BY venta DESC
LIMIT 25;

-- 4. Ticket promedio (venta por uso) por categoría y zona
-- (¿Cuál es el ticket promedio del JQ3 XX de la categoría XX?)
SELECT categoria, jq3, zonalima,
  ROUND(SAFE_DIVIDE(SUM(venta_meson), SUM(usos_meson)), 2) AS ticket_promedio
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
WHERE tipo_periodo = 'MES_ACTUAL'
GROUP BY 1, 2, 3
ORDER BY 1, 2, ticket_promedio DESC;

-- 5. Variación MoM y YoY de venta por categoría (división comercial)
-- (¿Qué división comercial presenta variaciones en su venta vs. mes anterior y año anterior?)
SELECT
  categoria,
  ROUND(SUM(IF(tipo_periodo = 'MES_ACTUAL',          venta_meson, 0)), 2) AS venta_actual,
  ROUND(SUM(IF(tipo_periodo = 'MES_ANTERIOR',         venta_meson, 0)), 2) AS venta_mes_ant,
  ROUND(SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)), 2) AS venta_anio_ant,
  ROUND(SAFE_DIVIDE(
    SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)) - SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0)),
    SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0))) * 100, 1) AS var_mom_pct,
  ROUND(SAFE_DIVIDE(
    SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)) - SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)),
    SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0))) * 100, 1) AS var_yoy_pct
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
GROUP BY 1
ORDER BY ABS(var_mom_pct) DESC;

-- 6. Variación MoM de venta por JQ3
-- (¿Qué JQ3 presenta variaciones en su venta vs. mes anterior?)
SELECT
  categoria, jq3,
  ROUND(SUM(IF(tipo_periodo = 'MES_ACTUAL',  venta_meson, 0)), 2) AS venta_actual,
  ROUND(SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0)), 2) AS venta_mes_ant,
  ROUND(SAFE_DIVIDE(
    SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)) - SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0)),
    SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0))) * 100, 1) AS var_mom_pct
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
GROUP BY 1, 2
ORDER BY ABS(var_mom_pct) DESC
LIMIT 30;

-- 7. Variación MoM y YoY de venta por zona de Lima
-- (¿Qué zonas presentan variación de venta vs. mes anterior y año anterior?)
SELECT
  zonalima,
  ROUND(SUM(IF(tipo_periodo = 'MES_ACTUAL',          venta_meson, 0)), 2) AS venta_actual,
  ROUND(SUM(IF(tipo_periodo = 'MES_ANTERIOR',         venta_meson, 0)), 2) AS venta_mes_ant,
  ROUND(SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)), 2) AS venta_anio_ant,
  ROUND(SAFE_DIVIDE(
    SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)) - SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0)),
    SUM(IF(tipo_periodo = 'MES_ANTERIOR', venta_meson, 0))) * 100, 1) AS var_mom_pct,
  ROUND(SAFE_DIVIDE(
    SUM(IF(tipo_periodo = 'MES_ACTUAL', venta_meson, 0)) - SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0)),
    SUM(IF(tipo_periodo = 'MISMO_MES_AÑO_PASADO', venta_meson, 0))) * 100, 1) AS var_yoy_pct
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
GROUP BY 1
ORDER BY var_mom_pct DESC;

-- 8. Top 5 marcas por JQ3 y categoría en el mes actual (parametrizar @jq3 y @categoria)
-- (¿Cuáles son el TOP 5 de marcas que se venden en el JQ3 XX de la categoría XX?)
SELECT marca,
  ROUND(SUM(venta_meson), 2) AS venta,
  SUM(usos_meson)            AS tickets
FROM `itc-data-governance-01.ba_fape_agent.ventas_zonas`
WHERE tipo_periodo = 'MES_ACTUAL'
  AND jq3      = @jq3
  AND categoria = @categoria
GROUP BY 1
ORDER BY venta DESC
LIMIT 5;
```

---

> **Nota de profiling:** Este glosario fue generado con datos extraídos de
> `itc-data-governance-01.ba_fape_agent.ventas_zonas` (tabla origen del caso de uso
> FAPE Agent, cargada desde `ventaszonas.csv`).

*Generado: 2026-07-17 | Fuente: BigQuery `itc-data-governance-01.ba_fape_agent.ventas_zonas`*
