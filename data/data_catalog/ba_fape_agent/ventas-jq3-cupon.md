# Catálogo de Datos — `ventas_jq3_cupon`

**Catalog ID:** `ba_fape_agent.ventas_jq3_cupon`
**Proyecto canónico:** `itc-data-governance-01`
**Dataset:** `ba_fape_agent`
**Tabla completa:** `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
**Profiling realizado sobre:** `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
_(tabla origen — el catalog ID es el mismo)_

---

## Descripción

Tabla analítica del **FAPE Agent** (Farmacias) que agrega la **venta de cupones por
jerarquía JQ3, tipo de cupón y segmento de cliente**. Cada fila es una combinación de
`periodo` × `categoria` × `jq3` × `tipo_cupon` × `flag`, con dos métricas agregadas:
número de clientes que usaron el cupón (`clientes_cupon`) y venta generada (`venta_cupon`).

Es la vista agregada más compacta del dataset (2,793 filas): resume el desempeño de los
cupones por el tipo de mecánica (DIGITAL, RULETA, MASIVO, PERSONALIZADO, FLASH) y por el
segmento del cliente (`flag`: NUEVO, REENGANCHE, OTRO). Sirve para comparar rápidamente
qué tipo de cupón y qué segmento generan más venta y captan más clientes por categoría.

Cubre el período **202601 → 202607** (7 meses). Cargada desde `VENTAS_JQ3_CUPON.csv`.
No usa nomenclatura estándar ITC ni contiene datos de cliente individual/PII.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | Sin partición |
| Clusterizado | NO |
| Total de filas | 2,793 |
| Número de columnas | 7 |
| Tamaño lógico | ~0.20 MB |
| Tamaño físico | ~0.20 MB |
| Particiones | N/A |
| Rango de período (`periodo`) | 202601 → 202607 (7 meses) |
| Frecuencia | Carga única / batch desde CSV |
| Fuente | `VENTAS_JQ3_CUPON.csv` |
| Ubicación | US |

---

## Volumen por tipo de cupón y segmento

| Tipo de cupón | Segmento (`flag`) | Filas | Clientes | Venta (S/) |
|---|---|---|---|---|
| RULETA | NUEVO | 340 | 199,274 | 6,714,574 |
| RULETA | OTRO | 305 | 580,459 | 20,732,118 |
| DIGITAL | NUEVO | 302 | 463,854 | 25,647,514 |
| RULETA | REENGANCHE | 296 | 205,143 | 6,007,928 |
| DIGITAL | OTRO | 294 | 705,637 | 30,572,416 |
| DIGITAL | REENGANCHE | 289 | 392,252 | 17,610,334 |
| FLASH | NUEVO | 142 | 751,329 | 20,174,157 |
| FLASH | OTRO | 140 | 828,491 | 22,068,690 |
| FLASH | REENGANCHE | 134 | 541,501 | 14,601,486 |
| PERSONALIZADO | NUEVO | 110 | 67,491 | 2,853,396 |
| PERSONALIZADO | OTRO | 110 | 114,027 | 4,726,199 |
| PERSONALIZADO | REENGANCHE | 104 | 57,230 | 2,103,622 |
| MASIVO | NUEVO | 78 | 71,389 | 2,636,938 |
| MASIVO | OTRO | 74 | 81,361 | 3,559,906 |
| MASIVO | REENGANCHE | 75 | 46,435 | 1,931,513 |

> **Totales:** clientes 5,105,873 · venta ~S/ 181.9 MM. Sin valores NULL en ninguna columna.

---

## Glosario de Campos

| Campo | Tipo | Descripción |
|---|---|---|
| `periodo` | INT64 | Período mensual `YYYYMM` (202601 → 202607). Campo de filtro temporal (sin partición física). |
| `categoria` | STRING | Categoría comercial (5 valores distintos). Nivel superior de agregación de producto. |
| `jq3` | STRING | Jerarquía de categoría nivel 3 (60 valores distintos). Grano de producto de la agregación. Clave de join con `informacion_tipificaciones.jq3` y `ventas_zonas.jq3`. |
| `tipo_cupon` | STRING | Mecánica del cupón (5 valores): `DIGITAL`, `RULETA`, `MASIVO`, `PERSONALIZADO`, `FLASH`. |
| `flag` | STRING | Segmento del cliente respecto al cupón (3 valores): `NUEVO` (nunca ha comprado en esa jerarquía JQ3 — captación pura), `REENGANCHE` (no compró en los últimos 3 a 12 meses en esa JQ3 — cliente inactivo reactivado), `OTRO` (fuera de ambas ventanas — base activa recurrente). |
| `clientes_cupon` | INT64 | Número de clientes que usaron/redimieron cupones en esa combinación. Métrica agregada, sin NULL. Total: 5,105,873. |
| `venta_cupon` | FLOAT64 | Venta (S/) generada por los cupones en esa combinación. Métrica agregada, sin NULL. Total: ~S/ 181.9 MM. |

---

## Relación con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `ba_fape_agent.informacion_tipificaciones` | `jq3`, `categoria`, `periodo` | Vincular la venta agregada por JQ3 con la tipificación detallada de cada cupón |
| `ba_fape_agent.ventas_zonas` | `jq3`, `categoria`, `periodo` | Contrastar venta por cupón contra venta de mesón por zona geográfica |

---

## Empresas cubiertas

> La tabla **no discrimina corporación**: agrega el total de cupones de Farmacias
> (Inkafarma + Mifarma combinadas) por jerarquía y segmento. Para desglose por corporación
> usar `informacion_tipificaciones` (campo `corporacion`) o `ventas_zonas`.

---

## Reglas de negocio

1. **Grano = `periodo` × `categoria` × `jq3` × `tipo_cupon` × `flag`.** No hay una fila por
   cliente ni por cupón individual — es una agregación. Para totales usar `SUM(...)`, nunca
   `COUNT(*)` como métrica de negocio.
2. **`clientes_cupon` no es sumable entre segmentos sin duplicación conceptual.** Un mismo
   cliente puede aparecer en más de una combinación (distinto `jq3` o `tipo_cupon`);
   la suma da clientes-cupón, no clientes únicos.
3. **Filtrar por `periodo`** (`YYYYMM`) para acotar el análisis temporal.
4. **Segmento `flag`** habilita análisis de captación vs retención. Definiciones exactas:
   - `NUEVO`: nunca ha comprado en la jerarquía JQ3 (captación pura).
   - `REENGANCHE`: no compró en los últimos 3 a 12 meses en esa JQ3 (reactivación de inactivo).
   - `OTRO`: fuera de ambas ventanas (base activa recurrente).
5. **Calidad alta:** sin NULL en ninguna columna; datos listos para agregación directa.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| Todas las columnas | 0% | Tabla completa sin valores nulos |

> Tabla agregada de alta calidad — sin nulos, valores consistentes. La única precaución es
> no interpretar `clientes_cupon` sumados como clientes únicos (ver regla 2).

---

## Queries de referencia

```sql
-- 1. Venta y clientes por tipo de cupón y segmento (ranking de efectividad)
SELECT
  tipo_cupon, flag,
  SUM(clientes_cupon) AS clientes,
  ROUND(SUM(venta_cupon), 2) AS venta,
  ROUND(SUM(venta_cupon) / NULLIF(SUM(clientes_cupon), 0), 2) AS venta_x_cliente
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
GROUP BY 1, 2
ORDER BY venta DESC;

-- 2. Evolución mensual de la venta por cupón
SELECT periodo, ROUND(SUM(venta_cupon), 2) AS venta, SUM(clientes_cupon) AS clientes
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
GROUP BY 1
ORDER BY 1;

-- 3. Top JQ3 por venta de cupón en el último período
SELECT categoria, jq3, ROUND(SUM(venta_cupon), 2) AS venta
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
WHERE periodo = 202607
GROUP BY 1, 2
ORDER BY venta DESC
LIMIT 20;

-- 4. Captación de clientes nuevos por tipo de cupón
SELECT tipo_cupon, SUM(clientes_cupon) AS clientes_nuevos
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
WHERE flag = 'NUEVO'
GROUP BY 1
ORDER BY clientes_nuevos DESC;

-- 5. Desempeño por categoría × JQ3 × tipo de cupón en el último período
-- (¿Cómo se desempeña cada categoría por JQ3 por tipo de campaña de cupón?)
SELECT
  categoria, jq3, tipo_cupon,
  SUM(clientes_cupon)                                              AS clientes,
  ROUND(SUM(venta_cupon), 2)                                       AS venta,
  ROUND(SAFE_DIVIDE(SUM(venta_cupon), SUM(clientes_cupon)), 2)     AS venta_x_cliente
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
WHERE periodo = 202607
GROUP BY 1, 2, 3
ORDER BY 1, 2, venta DESC;

-- 6. Variación MoM de venta de cupones por JQ3 (último mes vs anterior)
-- (¿Qué JQ3 presenta variaciones en su venta de cupones vs. mes anterior?)
SELECT
  categoria, jq3,
  ROUND(SUM(IF(periodo = 202607, venta_cupon, 0)), 2)  AS venta_actual,
  ROUND(SUM(IF(periodo = 202606, venta_cupon, 0)), 2)  AS venta_mes_ant,
  ROUND(SAFE_DIVIDE(
    SUM(IF(periodo = 202607, venta_cupon, 0)) - SUM(IF(periodo = 202606, venta_cupon, 0)),
    SUM(IF(periodo = 202606, venta_cupon, 0))) * 100, 1) AS var_mom_pct
FROM `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`
WHERE periodo IN (202607, 202606)
GROUP BY 1, 2
HAVING SUM(IF(periodo = 202607, venta_cupon, 0)) > 0
ORDER BY ABS(var_mom_pct) DESC
LIMIT 20;
```

---

> **Nota de profiling:** Este glosario fue generado con datos extraídos de
> `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon` (tabla origen del caso de uso
> FAPE Agent, cargada desde `VENTAS_JQ3_CUPON.csv`).

*Generado: 2026-07-17 | Fuente: BigQuery `itc-data-governance-01.ba_fape_agent.ventas_jq3_cupon`*
