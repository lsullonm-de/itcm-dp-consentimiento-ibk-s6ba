# Catálogo de Datos — `dv_rcc_montos_tc`

**Catalog ID:** `bi_vuc_insight.dv_rcc_montos_tc`
**Proyecto canónico:** `dev-intercorp-data-storage`
**Dataset:** `bi_vuc_insight`
**Tabla completa:** `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
**Profiling realizado sobre:** `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
_(ambiente de desarrollo — catalog ID aplica igualmente a versión productiva)_

---

## Descripción

Tabla de **montos de tarjeta de crédito del Reporte Crediticio Consolidado (RCC)** agregados por período (año/mes), entidad financiera, y geografía. Fuente: datos del sistema RCC de la SBS (Superintendencia de Banca y Seguros del Perú), que consolida la deuda crediticia de cada persona en el sistema financiero peruano.

Cada fila representa el promedio de saldo y línea de crédito de los clientes de una entidad financiera específica (`empresa`) en una combinación de periodo + geografía. Incluye flags de tenencia de productos Intercorp: **Tarjeta OH!** (FOH/TOH) e **Interbank** (IBK).

**Caso de uso principal:** cruzar el perfil crediticio de los clientes del sistema financiero con su comportamiento de compra en las empresas del Grupo Intercorp, para análisis de riesgo, segmentación y propensión a productos financieros.

> ⚠️ **`empresa` = entidad financiera** (banco o financiera emisora de la TC), NO empresa retail de Intercorp.

**Granularidad de la fila:** combinación de `(anio, mes, empresa, departamento, provincia, distrito, flag_tc_toh, flag_tc_ibk)`.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | ⚠️ Sin partición |
| Clusterizado por | `anio`, `mes`, `empresa` (en ese orden) |
| Total de filas | 2,361,084 |
| Número de columnas | 20 |
| Tamaño lógico | ~439 MB (0.43 GB) |
| Período de datos | 2022-01 → 2026-12 (42 meses) |
| `load_date` (STRING) | `"2022-05-16"` (única carga, campo STRING no DATE) |
| Require partition filter | N/A (sin partición) |
| Ubicación | US |
| ETL origin | Matillion |
| Creation user | Guillermo Nunura |

**DDL:**
```sql
CREATE TABLE `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
(
  anio INT64,
  mes INT64,
  empresa STRING,
  producto STRING,
  departamento STRING,
  provincia STRING,
  distrito STRING,
  flag_tc_toh INT64,
  flag_tc_ibk INT64,
  mto_prom_saldo NUMERIC,
  mto_prom_linea_tc NUMERIC,
  mto_prom_linea_tc_foh NUMERIC,
  mto_prom_saldo_foh NUMERIC,
  mto_prom_linea_tc_ibk NUMERIC,
  mto_prom_saldo_ibk NUMERIC,
  cant_clientes INT64,
  record_source STRING,
  load_date STRING,
  creation_user STRING,
  district_names_zonas STRING
)
CLUSTER BY anio, mes, empresa;
```

---

## Diccionario de Campos

### 1. Dimensiones de tiempo

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `anio` | INT64 | YES | Año del período de reporte RCC. Campo de clustering (posición 1). Rango: 2022–2026. |
| `mes` | INT64 | YES | Mes del período de reporte RCC (1–12). Campo de clustering (posición 2). |

### 2. Dimensión de entidad financiera y producto

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `empresa` | STRING | YES | **Entidad financiera** emisora de la tarjeta de crédito. Campo de clustering (posición 3). ⚠️ No es empresa retail de Intercorp. Ver tabla de valores abajo. |
| `producto` | STRING | YES | Tipo de producto crediticio. **100% = `"Tarjeta de Crédito"`** — tabla especializada en TC. |

**Valores de `empresa` (entidades financieras):**

| Empresa | Registros | % |
|---|---|---|
| BCP | 351,094 | 14.9% |
| BBVA | 345,342 | 14.6% |
| FALABELLA | 338,698 | 14.3% |
| RIPLEY | 279,651 | 11.8% |
| INTERBANK | 246,136 | 10.4% |
| SCOTIABANK | 217,406 | 9.2% |
| CENCOSUD | 215,097 | 9.1% |
| CREDISCOTIA | 207,682 | 8.8% |
| FINANCIERA OH! | 159,978 | 6.8% |

### 3. Dimensiones geográficas

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `departamento` | STRING | YES | Departamento del Perú donde reside el cliente. **48,376 nulls (2.05%)** — clientes sin geolocalización disponible. |
| `provincia` | STRING | YES | Provincia dentro del departamento. **48,376 nulls (2.05%)** — mismo conjunto que `departamento`. |
| `distrito` | STRING | YES | Distrito dentro de la provincia. **48,376 nulls (2.05%)** — mismo conjunto que `departamento`. |
| `district_names_zonas` | STRING | YES | Nombre de zona o agrupación de distritos. **48,376 nulls (2.05%)** — mismo conjunto. |

### 4. Flags de tenencia de productos Intercorp

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `flag_tc_toh` | INT64 | YES | Indicador de tenencia de **Tarjeta OH!** (Financiera OH! / FOH). `1` = cliente tiene TC OH!; `0` = no tiene. 35.2% de registros = 1 (831,934 filas). |
| `flag_tc_ibk` | INT64 | YES | Indicador de tenencia de **Tarjeta Interbank** (IBK). `1` = cliente tiene TC IBK; `0` = no tiene. 44.9% de registros = 1 (1,060,368 filas). |

> Los flags no son mutuamente excluyentes. Un cliente puede tener ambas tarjetas simultáneamente.

### 5. Métricas de crédito (promedios del período)

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `mto_prom_saldo` | NUMERIC | YES | Saldo promedio total de TC del cliente en la entidad financiera (`empresa`), en soles (S/.). Promedio global: S/3,782. |
| `mto_prom_linea_tc` | NUMERIC | YES | Línea de crédito promedio total de TC del cliente en la entidad, en soles (S/.). Promedio global: S/8,586. |
| `mto_prom_linea_tc_foh` | NUMERIC | YES | Línea de crédito promedio de la Tarjeta OH! (FOH). NULL si el cliente no tiene TC FOH. |
| `mto_prom_saldo_foh` | NUMERIC | YES | Saldo promedio de la Tarjeta OH! (FOH). NULL si el cliente no tiene TC FOH. |
| `mto_prom_linea_tc_ibk` | NUMERIC | YES | Línea de crédito promedio de la Tarjeta Interbank (IBK). NULL si el cliente no tiene TC IBK. |
| `mto_prom_saldo_ibk` | NUMERIC | YES | Saldo promedio de la Tarjeta Interbank (IBK). NULL si el cliente no tiene TC IBK. |
| `cant_clientes` | INT64 | YES | Cantidad de clientes en la combinación período + entidad + geografía + flags. |

> Los campos `mto_prom_*_foh` e `mto_prom_*_ibk` solo tienen valor cuando `flag_tc_toh = 1` y `flag_tc_ibk = 1` respectivamente.

### 6. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | STRING | YES | ⚠️ **Tipo STRING, no DATE.** Fecha de carga del ETL. Valor único en toda la tabla: `"2022-05-16"`. No usar como partición ni para filtros de rango de fecha. |
| `record_source` | STRING | YES | Sistema de origen. Valor observado: `""` (vacío). |
| `creation_user` | STRING | YES | Usuario que realizó la carga. Valor: `"Guillermo Nunura"`. |

---

## Volumetría por Entidad Financiera

| Empresa | Registros | % |
|---|---|---|
| BCP | 351,094 | 14.9% |
| BBVA | 345,342 | 14.6% |
| FALABELLA | 338,698 | 14.3% |
| RIPLEY | 279,651 | 11.8% |
| INTERBANK | 246,136 | 10.4% |
| SCOTIABANK | 217,406 | 9.2% |
| CENCOSUD | 215,097 | 9.1% |
| CREDISCOTIA | 207,682 | 8.8% |
| FINANCIERA OH! | 159,978 | 6.8% |
| **TOTAL** | **2,361,084** | **100%** |

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| Tablas de ventas retail (`dv_inretail_venta`, `t_payment`) | `departamento` | Cruzar comportamiento de compra retail con perfil crediticio por geografía |
| Catálogo de clientes (`iden_itc_party`) | No existe clave directa | Esta tabla no tiene `id` de cliente — es un agregado por segmento, no nivel individual |

> ⚠️ **Esta tabla NO tiene campo de cliente individual** (`id`, `iden_party_hash`). Es una agregación por segmento crediticio. No se puede hacer join directo con tablas de clientes individuales.

---

## Reglas de Negocio

1. **`empresa` = banco emisor, no empresa retail** — El campo `empresa` identifica la entidad financiera (BCP, BBVA, etc.), no una empresa del Grupo Intercorp. Para análisis de ventas retail, usar tablas como `dv_inretail_venta`.

2. **Sin partición — siempre escaneará la tabla completa** — La tabla no tiene `PARTITION BY`. Cualquier query escaneará los 0.43 GB completos. Usar el CLUSTER BY (`anio`, `mes`, `empresa`) para orientar las búsquedas.

3. **`load_date` es STRING, no DATE** — El campo `load_date` es tipo STRING con valor `"2022-05-16"`. No puede usarse en filtros de tipo `WHERE load_date >= DATE '2022-01-01'`. Si se necesita filtrar, usar `WHERE load_date = '2022-05-16'`.

4. **`producto` siempre = "Tarjeta de Crédito"** — La tabla está especializada en TC. No hay otros productos en la carga actual.

5. **Montos FOH/IBK solo para los que tienen el producto** — `mto_prom_linea_tc_foh` y `mto_prom_saldo_foh` solo tienen valor cuando `flag_tc_toh = 1`. Ídem para `_ibk`. Filtrar por el flag correspondiente antes de agregar estos montos.

6. **El período de datos (2022–2026) en una sola carga** — Toda la historia está en una carga del 2022-05-16. No hay incrementales.

---

## Observaciones de Calidad de Datos

| Campo | % NULL / Vacío | Observación |
|---|---|---|
| `departamento`, `provincia`, `distrito`, `district_names_zonas` | 2.05% NULL (48,376 filas) | Clientes sin geolocalización en el RCC. Todos los 4 campos nulean al mismo tiempo. |
| `record_source` | 100% vacío (`""`) | Campo sin poblar. No usar. |
| `load_date` | 0% NULL | Tipo STRING con valor único `"2022-05-16"` — no es una fecha real de carga incremental. |
| `mto_prom_*_foh` | NULL cuando flag_tc_toh=0 | Esperado — solo aplica para tenedores de TC OH!. |
| `mto_prom_*_ibk` | NULL cuando flag_tc_ibk=0 | Esperado — solo aplica para tenedores de TC IBK. |

---

## Queries de Referencia

```sql
-- 1. Saldo y línea promedio de TC por entidad financiera y año (tabla sin partición)
SELECT
  anio, mes, empresa,
  ROUND(AVG(CAST(mto_prom_saldo AS FLOAT64)), 2)    AS saldo_promedio,
  ROUND(AVG(CAST(mto_prom_linea_tc AS FLOAT64)), 2) AS linea_promedio,
  SUM(cant_clientes)                                 AS clientes_total
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
WHERE anio = 2026 AND mes = 3
GROUP BY anio, mes, empresa
ORDER BY saldo_promedio DESC;

-- 2. Clientes con TC TOH vs TC IBK por entidad financiera
SELECT
  empresa,
  SUM(CASE WHEN flag_tc_toh = 1 THEN cant_clientes ELSE 0 END) AS clientes_con_toh,
  SUM(CASE WHEN flag_tc_ibk = 1 THEN cant_clientes ELSE 0 END) AS clientes_con_ibk,
  SUM(CASE WHEN flag_tc_toh = 1 AND flag_tc_ibk = 1 THEN cant_clientes ELSE 0 END) AS clientes_ambos,
  SUM(cant_clientes)                                            AS clientes_total
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
WHERE anio = 2025
GROUP BY empresa ORDER BY clientes_total DESC;

-- 3. Evolución mensual de saldo promedio (Tarjeta OH!) por departamento
SELECT
  anio, mes, departamento,
  ROUND(AVG(CAST(mto_prom_saldo_foh AS FLOAT64)), 2) AS saldo_toh_promedio,
  SUM(CASE WHEN flag_tc_toh = 1 THEN cant_clientes ELSE 0 END) AS clientes_toh
FROM `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`
WHERE flag_tc_toh = 1
  AND departamento IS NOT NULL
GROUP BY anio, mes, departamento
ORDER BY anio, mes, saldo_toh_promedio DESC;
```

---

> **Nota de profiling:** Catálogo generado con datos de `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc`. El catalog ID `bi_vuc_insight.dv_rcc_montos_tc` aplica a cualquier proyecto que exponga esta tabla.

*Generado: 2026-06-24 | Fuente: BigQuery `dev-intercorp-data-storage.bi_vuc_insight.dv_rcc_montos_tc` | 2,361,084 filas · 0.43 GB · 20 columnas*
