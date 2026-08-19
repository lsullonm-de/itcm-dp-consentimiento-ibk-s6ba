# Catálogo de Datos — `dv_inretail_venta`

**Catalog ID:** `bi_vuc_insight.dv_inretail_venta`
**Proyecto canónico:** `dev-intercorp-data-storage`
**Dataset:** `bi_vuc_insight`
**Tabla completa:** `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
**Profiling realizado sobre:** `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
_(copia en desarrollo — el catalog ID aplica igualmente a la versión productiva)_

---

## Descripción

Tabla de **ventas agregadas del grupo InRetail** por combinación de período (año/mes), empresa, marca, canal de venta y punto de venta. Cada fila representa el resumen de ventas de una marca específica en un punto de venta, canal y ubicación geográfica durante un mes calendario.

Cubre las empresas del conglomerado InRetail del Grupo Intercorp: **Farmacias Peruanas** (InkaFarma, MiFarma), **Supermercados Peruanos** (Plaza Vea, Mass, Vivanda, Cash & Carry), **Promart** y **Tiendas Peruanas** (Oechsle). Incluye canales presencial y online (e-commerce).

Las métricas acumuladas por fila son: clientes únicos, monto de venta bruta, monto de venta neta y número de transacciones. Los valores negativos en montos reflejan devoluciones o ajustes de caja.

**Granularidad de la fila:** una combinación única de `(anio, mes, empresa, marca, canal_venta, codigo_punto_venta, departamento, district_names_zonas, flag_venta_mayorista)`.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `load_date` (DAY) |
| Clusterizado por | `anio`, `mes`, `empresa` (en ese orden) |
| Total de filas | 1,195,515 |
| Número de columnas | 17 |
| Tamaño lógico | ~183 MB (0.18 GB) |
| Particiones activas | 1 (`2026-06-10`) |
| Período de datos | 2023-01 → 2026-05 (37 meses) |
| Primera carga | 2026-06-10 |
| Última carga | 2026-06-10 |
| Frecuencia de carga | **Diaria — TRUNCATE + INSERT completo.** Cada día se reemplaza toda la tabla con la historia actualizada. La partición activa cambia de fecha con cada carga. |
| Require partition filter | false |
| Ubicación | US |
| Creation user | Guillermo Nunura |

**DDL:**
```sql
CREATE TABLE `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
(
  anio INT64,
  mes INT64,
  empresa STRING,
  marca STRING,
  canal_venta STRING,
  codigo_punto_venta STRING,
  punto_venta STRING,
  departamento STRING,
  district_names_zonas STRING,
  flag_venta_mayorista STRING,
  cant_clientes INT64,
  mto_venta_bruta FLOAT64,
  mto_venta_neta FLOAT64,
  cant_transacciones INT64,
  load_date DATE,
  record_source STRING,
  creation_user STRING
)
PARTITION BY load_date
CLUSTER BY anio, mes, empresa;
```

---

## Diccionario de Campos

### 1. Dimensiones de tiempo

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `anio` | INT64 | YES | Año del período de venta. Rango: 2023–2026. Campo de clustering (posición 1). |
| `mes` | INT64 | YES | Mes del período de venta (1–12). Campo de clustering (posición 2). |

### 2. Dimensiones de empresa y marca

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `empresa` | STRING | YES | Razón social del grupo empresarial. Campo de clustering (posición 3). Valores: `FARMACIAS PERUANAS`, `SUPERMERCADOS PERUANOS`, `PROMART`, `TIENDAS PERUANAS`, `REAL PLAZA`, `MAX`. |
| `marca` | STRING | YES | Marca comercial específica dentro de la empresa. Ver tabla de marcas abajo. |

**Relación empresa → marcas:**

| empresa | marcas |
|---|---|
| FARMACIAS PERUANAS | INKAFARMA, MIFARMA |
| SUPERMERCADOS PERUANOS | PLAZA VEA, MASS, VIVANDA, PLAZA VEA SUPER, PLAZA VEA EXPRESS, CASH & CARRY, MERKAO, JOKR |
| PROMART | PROMART |
| TIENDAS PERUANAS | OECHSLE |
| REAL PLAZA | REALPLAZAGO |
| MAX | VENTA MOSTRADOR, SISSA |

### 3. Dimensiones de canal y punto de venta

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `canal_venta` | STRING | YES | Canal de venta. Valores: `ONLINE` (65.1%), `PRESENCIAL` (34.9%), `OTROS` (0.01%). |
| `codigo_punto_venta` | STRING | YES | Código numérico identificador del punto de venta (tienda, local o plataforma digital). Clave de join con tabla de puntos de venta. |
| `punto_venta` | STRING | YES | Nombre descriptivo del punto de venta (ej: `CARPA AREQUIPA RP`, `CARPA CAJAMARCA`). |

### 4. Dimensiones geográficas

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `departamento` | STRING | YES | Ámbito geográfico del punto de venta. Incluye departamentos reales (LIMA, AREQUIPA, etc.) y valores especiales de agregación: `TOTAL PERU` (consolidado nacional), `PROVINCIAS` (fuera de Lima+Callao). **626 nulls (0.05%)** — ocurre en registros online sin geolocalización asignada. |
| `district_names_zonas` | STRING | YES | Nombre de la zona o distrito dentro del departamento. **1,258 nulls (0.11%)** — no disponible para todos los puntos de venta, especialmente online. |

**Valores especiales en `departamento`:**

| Valor | Significado |
|---|---|
| `LIMA` | Departamento de Lima (excluyendo Callao) |
| `CALLAO` | Provincia Constitucional del Callao |
| `PROVINCIAS` | Agregado de todos los departamentos fuera de Lima+Callao |
| `TOTAL PERU` | Consolidado nacional (Lima + Callao + Provincias) |
| Nombre de departamento | Departamento específico del Perú |

### 5. Dimensiones de clasificación de venta

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `flag_venta_mayorista` | STRING | YES | Indicador de venta mayorista. Valores observados: `0` = minorista (retail). **100% de los registros = `0`** — esta tabla cubre únicamente ventas minoristas. |

### 6. Métricas de venta

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `cant_clientes` | INT64 | YES | Cantidad de clientes únicos que realizaron compras en la combinación período/marca/canal/punto de venta. Promedio: 1,274. |
| `mto_venta_bruta` | FLOAT64 | YES | Monto total de venta bruta en soles (S/.), antes de descuentos y ajustes. Promedio: S/197,094. Valores negativos indican devoluciones o ajustes. Rango: -31,271 a 46,472,375. |
| `mto_venta_neta` | FLOAT64 | YES | Monto de venta neta en soles (S/.), después de descuentos. Promedio: S/169,648. Siempre ≤ mto_venta_bruta en valor absoluto. Rango: -26,519 a 39,383,350. |
| `cant_transacciones` | INT64 | YES | Número de transacciones de venta en el período para la combinación. Promedio: 4,017. |

### 7. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | DATE | YES | **Campo de partición.** Fecha de carga del proceso ETL. Valor actual: `2026-06-10`. Todos los registros históricos (2023-2026) están en una única partición — siempre filtrar por `load_date = '2026-06-10'` para obtener la historia completa. |
| `record_source` | STRING | YES | Sistema de origen del registro. ⚠️ **100% vacío en la carga actual** (`''`) — campo no poblado. No usar para filtros. |
| `creation_user` | STRING | YES | Usuario o proceso que realizó la carga. Valor: `Guillermo Nunura`. |

---

## Volumetría por Empresa y Período

### Distribución por empresa (total tabla)

| Empresa | Registros | % |
|---|---|---|
| FARMACIAS PERUANAS | 966,495 | 80.8% |
| SUPERMERCADOS PERUANOS | 200,534 | 16.8% |
| PROMART | 23,761 | 2.0% |
| TIENDAS PERUANAS | 4,659 | 0.4% |
| REAL PLAZA | 64 | 0.005% |
| MAX | 2 | 0.0002% |
| **TOTAL** | **1,195,515** | **100%** |

### Distribución por canal de venta

| Canal | Registros | % |
|---|---|---|
| ONLINE | 777,748 | 65.1% |
| PRESENCIAL | 417,703 | 34.9% |
| OTROS | 64 | 0.01% |

### Muestra de volumetría por período — empresa (últimos meses con datos)

| Año | Mes | Empresa | Venta Neta (S/.) | Clientes | Transacciones | Registros |
|---|---|---|---|---|---|---|
| 2026 | 5 | FARMACIAS PERUANAS | 1,759,456,060 | 31,311,895 | 56,780,626 | 30,087 |
| 2026 | 5 | SUPERMERCADOS PERUANOS | 3,609,083,019 | 14,236,334 | 91,808,919 | 6,512 |
| 2026 | 5 | PROMART | 510,621,521 | 1,635,577 | 2,638,523 | 691 |
| 2026 | 5 | TIENDAS PERUANAS | 350,281,224 | 1,579,862 | 2,009,526 | 120 |
| 2026 | 4 | FARMACIAS PERUANAS | 1,688,503,524 | 30,037,200 | 53,761,157 | 31,372 |
| 2026 | 4 | SUPERMERCADOS PERUANOS | 3,476,733,759 | 13,189,817 | 88,872,835 | 6,608 |
| 2026 | 3 | FARMACIAS PERUANAS | 1,796,963,502 | 31,489,666 | 57,157,580 | 29,267 |
| 2026 | 3 | SUPERMERCADOS PERUANOS | 3,873,762,801 | 13,987,098 | 93,215,666 | 6,564 |

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| Tabla de puntos de venta | `codigo_punto_venta` = `{tabla}.codigo` | Obtener información adicional del local (dirección, formato, geolocalización) |
| Catálogo de empresas ITC | `empresa` | Obtener `itc_company_id` y metadata corporativa |

> No se han identificado campos de join directos con tablas del datalake ITC (`id` de cliente, `transaction_id`, `product_id`). Esta tabla es una **vista agregada de negocio**, no una tabla de transacciones individuales.

---

## Reglas de Negocio

1. **Granularidad de fila** — Cada registro representa la agregación de ventas para una combinación única de `(anio, mes, empresa, marca, canal_venta, codigo_punto_venta, departamento, district_names_zonas, flag_venta_mayorista)`. No hay un ID de fila explícito — la clave compuesta es el conjunto de estas dimensiones.

2. **⚠️ NUNCA hardcodear `load_date` ni `anio`/`mes` con valores fijos** — La tabla se trunca y recarga completa cada día, por lo que un filtro `load_date = '2026-06-10'` devolverá cero filas al día siguiente. **No usar `load_date` como filtro de negocio.** El período se filtra siempre con `DATE(anio, mes, 1)`:
   - Mes cerrado específico: `WHERE DATE(anio, mes, 1) = '2026-06-01'`
   - Último mes cerrado (dinámico): `WHERE DATE(anio, mes, 1) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)`
   - Año en curso hasta último mes cerrado: `WHERE DATE(anio, mes, 1) BETWEEN DATE_TRUNC(DATE_TRUNC(CURRENT_DATE(), YEAR), MONTH) AND DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)`
   - Historia completa: sin filtro de período.

   **La tabla tiene data hasta MES-1 del mes actual** — si hoy es julio 2026, el último mes cerrado disponible es junio 2026. Cuando se pida "el último mes" o "el mes más reciente", usar el filtro dinámico del último mes cerrado.

3. **Período de datos vs fecha de carga** — `anio` y `mes` representan el período comercial de la venta; `load_date` es la fecha de la última ejecución ETL (cambia cada día). No usarlos indistintamente: `load_date` no indica cuándo ocurrió la venta, indica cuándo se procesó la carga.

4. **Valores negativos en montos** — `mto_venta_bruta` y `mto_venta_neta` pueden ser negativos. Representan devoluciones o ajustes contables para el punto de venta en ese período. Considerar `GREATEST(mto_venta_neta, 0)` si se quiere solo ventas positivas.

5. **⚠️ SIEMPRE filtrar `departamento` — omitirlo infla los montos** — La tabla almacena simultáneamente filas para `TOTAL PERU`, `PROVINCIAS`, `LIMA` y cada departamento individual. Todas existen en la misma partición y período. Un `SUM` sin filtro de `departamento` suma todos esos niveles a la vez, multiplicando los montos reales varias veces. **Todo query sobre métricas de venta debe incluir exactamente uno de estos filtros:**
   - `AND departamento = 'TOTAL PERU'` → consolidado nacional (default cuando la pregunta no especifica geografía)
   - `AND departamento = 'LIMA'` → solo Lima
   - `AND departamento = 'PROVINCIAS'` → todo fuera de Lima+Callao
   - `AND departamento = '{departamento_especifico}'` → un departamento puntual
   - `AND departamento NOT IN ('TOTAL PERU', 'PROVINCIAS') AND departamento IS NOT NULL` → todos los departamentos individuales (para ranking o desglose por departamento)

6. **`flag_venta_mayorista = '0'` siempre** — En la carga actual todos los registros son minoristas. Este campo existe para filtros futuros si se incluyen ventas mayoristas.

7. **Empresa ≠ Marca** — `empresa` es la razón social del grupo (ej: FARMACIAS PERUANAS), `marca` es el banner comercial (ej: INKAFARMA, MIFARMA). Para análisis por banner usar `marca`; para consolidados corporativos usar `empresa`.

---

## Observaciones de Calidad de Datos

| Campo | % NULL / Vacío | Observación |
|---|---|---|
| `record_source` | 100% vacío (`''`) | Campo sin poblar en la carga actual. No usar para trazabilidad de origen. |
| `departamento` | 0.05% NULL (626 filas) | Registros online sin geolocalización asignada. |
| `district_names_zonas` | 0.11% NULL (1,258 filas) | No disponible para todos los puntos de venta. Mayor frecuencia en canal online. |
| `mto_venta_bruta` / `mto_venta_neta` | 0% NULL | Presencia de valores negativos (~devoluciones). |
| `flag_venta_mayorista` | 0% NULL | Solo valor `'0'` — no discrimina ventas mayoristas en la carga actual. |

---

## Queries de Referencia

> ⚠️ **REGLA CRÍTICA 1 — Nunca usar `load_date` fijo ni hardcodear `anio`/`mes`.**
> La tabla se recarga diariamente (TRUNCATE + INSERT). Filtrar por período usando siempre `DATE(anio, mes, 1)`:
> | Caso | Filtro |
> |---|---|
> | Mes cerrado específico | `WHERE DATE(anio, mes, 1) = '2026-06-01'` |
> | Último mes cerrado (dinámico) | `WHERE DATE(anio, mes, 1) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)` |
> | Año en curso hasta último mes cerrado | `WHERE DATE(anio, mes, 1) BETWEEN DATE_TRUNC(DATE_TRUNC(CURRENT_DATE(), YEAR), MONTH) AND DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)` |
> | Historia completa | _(sin filtro de período)_ |
>
> **La tabla tiene data hasta MES-1.** Si hoy es julio 2026, el último mes cerrado es junio 2026. Toda referencia a "último mes" o "mes más reciente" debe resolverse con el filtro dinámico.
>
> ⚠️ **REGLA CRÍTICA 2 — `departamento` es OBLIGATORIO en todo query de métricas.**
> La tabla contiene filas simultáneas para `TOTAL PERU`, `PROVINCIAS`, `LIMA` y cada departamento individual en el mismo período. Omitir el filtro genera **doble o triple conteo** de los montos reales.
>
> **Filtro obligatorio — elegir exactamente uno según la pregunta:**
> | Caso | Filtro a usar |
> |---|---|
> | Sin departamento especificado (default) | `AND departamento = 'TOTAL PERU'` |
> | Lima | `AND departamento = 'LIMA'` |
> | Provincias (fuera de Lima+Callao) | `AND departamento = 'PROVINCIAS'` |
> | Departamento puntual (ej: Arequipa) | `AND departamento = 'AREQUIPA'` |
> | Desglose por todos los departamentos | `AND departamento NOT IN ('TOTAL PERU', 'PROVINCIAS') AND departamento IS NOT NULL` |

```sql
-- 1. Venta neta mensual por empresa — año en curso hasta último mes cerrado
SELECT
  anio,
  mes,
  empresa,
  SUM(mto_venta_neta)      AS venta_neta_soles,
  SUM(cant_clientes)       AS clientes_totales,
  SUM(cant_transacciones)  AS transacciones_totales
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
WHERE DATE(anio, mes, 1) BETWEEN DATE_TRUNC(DATE_TRUNC(CURRENT_DATE(), YEAR), MONTH)
                              AND DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND departamento = 'TOTAL PERU'   -- ⚠️ obligatorio: evita doble conteo por niveles geográficos
GROUP BY anio, mes, empresa
ORDER BY anio, mes, empresa;

-- 2. Venta neta por marca y canal — último mes cerrado (dinámico)
SELECT
  empresa,
  marca,
  canal_venta,
  SUM(mto_venta_neta)     AS venta_neta,
  SUM(cant_transacciones) AS transacciones
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
WHERE DATE(anio, mes, 1) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND departamento = 'TOTAL PERU'   -- ⚠️ obligatorio: evita doble conteo por niveles geográficos
GROUP BY empresa, marca, canal_venta
ORDER BY venta_neta DESC;

-- 3. Top departamentos por venta neta — último mes cerrado (desglose por departamento individual)
SELECT
  departamento,
  SUM(mto_venta_neta)     AS venta_neta,
  SUM(cant_transacciones) AS transacciones
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
WHERE DATE(anio, mes, 1) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND departamento NOT IN ('TOTAL PERU', 'PROVINCIAS')  -- excluir agregados para ver granular
  AND departamento IS NOT NULL
GROUP BY departamento
ORDER BY venta_neta DESC;

-- 4. Evolución mensual de venta neta por empresa — historia completa
SELECT
  anio,
  mes,
  empresa,
  SUM(mto_venta_neta)  AS venta_neta,
  SUM(cant_clientes)   AS clientes
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
WHERE departamento = 'TOTAL PERU'   -- ⚠️ obligatorio: evita doble conteo por niveles geográficos
  AND mto_venta_neta > 0            -- excluir devoluciones
GROUP BY anio, mes, empresa
ORDER BY anio, mes, empresa;

-- 5. Distribución presencial vs online por empresa — último mes cerrado
SELECT
  empresa,
  canal_venta,
  SUM(mto_venta_neta)                                                  AS venta_neta,
  ROUND(SUM(mto_venta_neta) * 100.0 /
    SUM(SUM(mto_venta_neta)) OVER (PARTITION BY empresa), 2)           AS pct_canal
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta`
WHERE DATE(anio, mes, 1) = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
  AND departamento = 'TOTAL PERU'   -- ⚠️ obligatorio: evita doble conteo por niveles geográficos
GROUP BY empresa, canal_venta
ORDER BY empresa, canal_venta;
```

---

> **Nota de profiling:** Catálogo generado con datos extraídos de `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta` (ambiente de desarrollo). El catalog ID `bi_vuc_insight.dv_inretail_venta` aplica a cualquier proyecto que exponga esta tabla (dev o producción).

*Generado: 2026-06-24 | Fuente: BigQuery `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta` | 1,195,515 filas · 0.18 GB · 17 columnas*
