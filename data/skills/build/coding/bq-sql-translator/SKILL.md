# Skill: BigQuery SQL Translator

> **Rol:** Generador de Queries BigQuery — Analista de Negocio IA
> **Activado por:** El orquestador `Business Analyst Agent` después de que el Data Catalog Specialist entrega la especificación técnica
> **Estándar base obligatorio:** `@.claude/data/standard/bigquery/development.md`
>
> **Contexto de entrada esperado** (desde Data Catalog Specialist):
> - Tablas y datasets involucrados
> - Campos solicitados con su descripción de negocio
> - Filtros identificados (empresa, período, zona, segmento)
> - Granularidad del resultado (cliente, tienda, SKU, fecha)
> - Advertencias de PII o datos sensibles

---

## 1. Rol

El **BigQuery SQL Translator** toma la especificación técnica del Data Catalog Specialist y genera
el query BigQuery óptimo, listo para ejecutar. No interpreta requerimientos de negocio — eso ya
lo hizo el agente anterior. Su foco es **escribir SQL correcto, eficiente y seguro**.

A diferencia de los skills de pipeline ETL, este agente genera **queries ad-hoc de análisis**:
`SELECT` con aggregations, window functions, CTEs y filtros dinámicos — no `CREATE PROCEDURE` ni `INSERT`.

---

## 2. Principios Obligatorios (basados en `development.md`)

### 2.0 — Prioridad de tablas: `ba_*` antes que `t_*`

El Data Catalog Specialist ya habrá elegido la tabla óptima, pero el SQL Translator
debe respetar esa elección y conocer sus implicaciones de costo y filtro.

| Tipo de tabla | Costo relativo | Usar cuando |
|---|---|---|
| `ba_itc_attr_*` | ✅ Bajo — agrupadas mensualmente | Métricas, perfiles, atributos, ventanas temporales |
| `m_*` / `c_*` | ✅ Muy bajo — catálogos pequeños | Joins de enriquecimiento |
| `t_retail_transaction` | ❌ Alto — ~4.7B filas | Solo ítem/SKU/ticket individual o granularidad diaria |
| `t_experience_transaction` | ❌ Alto — ~577M filas | Solo detalle de función/sesión Cineplanet o NGR |
| `t_transaction` | ❌ Alto — ~3.4B filas | Solo detalle por comercio Izipay/POS |

Si la spec técnica recibida usa una `t_*` donde una `ba_*` hubiera bastado,
incluir una nota de optimización en el output (no bloquear la ejecución).

### 2.1 — Siempre filtrar por partición

La regla más crítica para costo y rendimiento. Aplicar siempre el filtro sobre la **columna raw de partición**
— nunca sobre una función aplicada a esa columna.

```sql
-- ✅ CORRECTO — usa la columna de partición directamente
WHERE transaction_date BETWEEN '2026-01-01' AND '2026-03-31'
WHERE itc_process_date >= '2026-01-01'

-- ❌ INCORRECTO — impide partition pruning, escanea toda la tabla
WHERE DATE(transaction_timestamp) >= '2026-01-01'
WHERE CAST(transaction_date AS DATE) >= '2026-01-01'
```

| Tabla | Columna de partición |
|---|---|
| `t_retail_transaction` | `transaction_date` |
| `t_transaction` | `itc_process_date` |
| `t_payment` | `payment_date` |
| `t_experience_transaction` | `transaction_date` |
| `ba_itc_attr_*` | `process_date` |

**Filtro de partición en tablas `ba_*` — `process_date` = primer día del mes:**

```sql
-- ✅ CORRECTO — process_date es siempre el 1ro del mes
WHERE process_date = '2026-05-01'                          -- mayo 2026 exacto
WHERE process_date >= '2026-01-01'                         -- desde enero 2026
WHERE process_date BETWEEN '2025-01-01' AND '2026-05-01'   -- rango de meses

-- Para "datos del mes actual":
WHERE process_date = DATE_TRUNC(CURRENT_DATE(), MONTH)

-- Para "últimos 6 meses":
WHERE process_date >= DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH), MONTH)

-- ❌ INCORRECTO — fecha intermedia no existe como partición → retorna 0 filas
WHERE process_date = '2026-05-15'
WHERE process_date >= '2026-05-15'   -- pierde la partición completa de mayo
```

> Si el usuario pide datos de un mes específico (ej: "mayo 2026"), usar
> `process_date = DATE_TRUNC(DATE '{fecha_solicitada}', MONTH)`.

**Qué campo usar según la ventana temporal solicitada:**

```sql
-- "ventas de mayo 2026" → un solo mes → campo _1m
SELECT id, spsa_mto_retail_1m, spsa_numtrx_retail_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-05-01'          -- partición de mayo

-- "ventas mes a mes de Q1 2026" → cada mes por separado → campo _1m + GROUP BY process_date
SELECT process_date, SUM(spsa_mto_retail_1m) AS monto_total
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date BETWEEN '2026-01-01' AND '2026-03-01'   -- 3 particiones
GROUP BY process_date
ORDER BY process_date

-- "acumulado últimos 6 meses a mayo" → ya acumulado → campo _6m en UNA sola partición
-- ❌ NO sumar _6m de varias particiones — duplicaría el conteo
SELECT id, spsa_mto_retail_6m, spsa_numtrx_retail_6m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-05-01'          -- solo la partición del mes final

-- "comparativo mayo 2026 vs mayo 2025" → mismo campo _1m, dos particiones
SELECT
  process_date,
  SUM(spsa_mto_retail_1m) AS monto
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date IN ('2026-05-01', '2025-05-01')
GROUP BY process_date
```

> **Regla de oro:** `_1m` = ese mes exacto (sumable entre particiones).
> `_3m`, `_6m`, `_12m` = ventanas acumuladas (NO sumar entre particiones).

### 2.1b — Campos CORRECTOS para monto total de ventas en `ba_itc_attr_retail`

**Anti-patrones frecuentes — estos campos NO existen:**

```sql
-- ❌ CAMPOS QUE NO EXISTEN — nunca generar estos nombres
spsa_mto_retail_1m        pro_mto_retail_1m
oe_mto_retail_1m          far_mto_retail_1m
spsa_numtrx_retail_1m     pro_numtrx_retail_1m
```

**El monto total de ventas = `mto_trx_presencial_1m` + `mto_trx_digital_1m`:**

| Empresa | Monto total de ventas | Transacciones totales |
|---|---|---|
| SPSA | `spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m` | `spsa_frecuencia_1m` |
| Promart | `pro_mto_trx_presencial_1m + pro_mto_trx_digital_1m` | `pro_frecuencia_1m` |
| Oechsle | `oe_mto_trx_presencial_1m + oe_mto_trx_digital_1m` | `oe_frecuencia_1m` |
| Farmacias | `far_mto_trx_presencial_1m + far_mto_trx_digital_1m` | `far_frecuencia_1m` |

### 2.1c — Agregar totales desde `ba_*`: SUM de todos los clientes del mes

Las tablas `ba_itc_attr_*` están **a nivel de cliente** (`id_intercorp`).
Para obtener el total mensual de una empresa, hay que **sumar todos los registros** de la partición.
No existe filtro por `itc_company_id` — la empresa se selecciona por el **prefijo del campo**.

**Patrón canónico para totales mensuales por empresa:**

```sql
-- Total ventas SPSA en enero 2026
-- USAR mto_trx_presencial_1m + mto_trx_digital_1m (no existe spsa_mto_retail_1m)
SELECT
  process_date,
  SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m)    AS monto_total,
  SUM(spsa_frecuencia_1m)                                        AS total_transacciones,
  COUNT(DISTINCT id_intercorp)                                   AS clientes_unicos,
  SAFE_DIVIDE(
    SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m),
    SUM(spsa_frecuencia_1m)
  )                                                              AS ticket_promedio
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND spsa_frecuencia_1m > 0          -- solo clientes con actividad en SPSA ese mes
GROUP BY process_date
```

**Comparativo mes a mes (tendencia mensual):**

```sql
-- Ventas SPSA mes a mes Q1 2026
SELECT
  process_date,
  SUM(spsa_monto_1m)        AS monto_spsa,
  SUM(pro_monto_1m)         AS monto_promart,
  SUM(oe_monto_1m)          AS monto_oechsle,
  SUM(far_monto_1m)         AS monto_farmacias,
  COUNT(DISTINCT id_intercorp) AS clientes_activos
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date BETWEEN '2026-01-01' AND '2026-03-01'
GROUP BY process_date
ORDER BY process_date
```

**Ticket promedio real (monto total / transacciones totales, no promedio de promedios):**

```sql
-- ✅ CORRECTO: sumar primero, dividir después
SELECT SAFE_DIVIDE(SUM(spsa_monto_1m), SUM(spsa_frecuencia_1m)) AS ticket_prom

-- ❌ INCORRECTO: promedio de promedios — resultado distorsionado por clientes con pocas compras
SELECT AVG(spsa_mtoprom_1m) AS ticket_prom
```

**Canal presencial vs digital (usar campos específicos de canal):**

```sql
SELECT
  process_date,
  SUM(spsa_numtrx_presencial_1m)                    AS trx_presencial,
  SUM(spsa_numtrx_digital_1m)                       AS trx_digital,
  SUM(spsa_numtrx_presencial_1m + spsa_numtrx_digital_1m) AS trx_total
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
GROUP BY process_date
```

**Prefijos por empresa (no usar `itc_company_id` en ba_*):**

| Empresa | Prefijo campo | Ejemplo campo monto |
|---|---|---|
| SPSA (Plaza Vea / Mass / Vivanda / Makro) | `spsa_` | `spsa_monto_1m` |
| Promart | `pro_` | `pro_monto_1m` ⚠️ ver nota |
| Oechsle | `oe_` | `oe_monto_1m` |
| Farmacias (InkaFarma + MiFarma) | `far_` | `far_monto_1m` |

> ⚠️ `pro_monto_Nm` existe en la tabla. Si no estuviera disponible, calcular como:
> `SAFE_DIVIDE(SUM(pro_mtoprom_1m * pro_frecuencia_1m), COUNT(*))` — pero preferir `pro_monto_1m`.

### 2.2 — Usar `SAFE_DIVIDE` para todos los promedios y porcentajes

```sql
-- ✅ CORRECTO
SAFE_DIVIDE(SUM(monto), COUNT(DISTINCT ticket)) AS ticket_promedio
SAFE_DIVIDE(SUM(monto_digital), SUM(monto_total)) * 100 AS pct_digital

-- ❌ INCORRECTO — puede fallar con división por cero
SUM(monto) / COUNT(DISTINCT ticket)
```

### 2.3 — Usar `SAFE_CAST` para conversiones

```sql
-- ✅ CORRECTO
SAFE_CAST(campo_string AS NUMERIC)
SAFE_CAST(codigo AS INT64)

-- ❌ INCORRECTO — falla con valores no convertibles
CAST(campo_string AS NUMERIC)
```

### 2.4 — Materializar CTEs costosas antes de reutilizarlas

```sql
-- ❌ CTE referenciada múltiples veces = se ejecuta múltiples veces
WITH base AS (SELECT ... FROM `tabla_grande`)
SELECT ... FROM base t1 JOIN base t2 ON ...

-- ✅ Materializar si se referencia más de una vez
CREATE TEMP TABLE tmp_base AS SELECT ... FROM `tabla_grande`;
SELECT ... FROM tmp_base t1 JOIN tmp_base t2 ON ...
```

### 2.5 — Evitar `NOT IN` con subqueries

```sql
-- ❌ Peligroso: si la subquery retorna NULLs, devuelve 0 filas sin error
WHERE id NOT IN (SELECT id FROM otra_tabla)

-- ✅ Seguro
WHERE NOT EXISTS (SELECT 1 FROM otra_tabla b WHERE b.id = a.id)
-- ✅ Alternativa
LEFT JOIN otra_tabla b ON a.id = b.id WHERE b.id IS NULL
```

### 2.6 — Columnas explícitas — nunca `SELECT *`

```sql
-- ✅ CORRECTO
SELECT id_intercorp, itc_company_id, transaction_date, monto_total
FROM `proyecto.dataset.tabla`

-- ❌ INCORRECTO
SELECT * FROM `proyecto.dataset.tabla`
```

---

## 3. Patrones de Query por Tipo de Usuario

El tipo de usuario (recibido del orquestador) determina la estructura del query:

### 3.1 — Analista de Operación: tabular directo

Resultado fila a fila o agregado simple, sin ventanas temporales complejas.

```sql
-- Patrón: SELECT directo con filtros y aggregation básica
SELECT
  t.itc_company_id,
  c.company_name,
  DATE_TRUNC(t.transaction_date, MONTH) AS mes,
  COUNT(DISTINCT t.ticket_id)           AS num_transacciones,
  SUM(t.product_item_gross_amount)      AS monto_total,
  SAFE_DIVIDE(
    SUM(t.product_item_gross_amount),
    COUNT(DISTINCT t.ticket_id)
  )                                     AS ticket_promedio
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
LEFT JOIN `intercorp-data-storage-pv.master_party.c_itc_company` c
  ON t.itc_company_id = c.company_id
WHERE t.transaction_date BETWEEN @fecha_ini AND @fecha_fin  -- partición siempre
  AND t.itc_company_id IN ('010', '011', '024')             -- empresas solicitadas
  AND t.product_id IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY mes DESC, monto_total DESC
```

### 3.2 — Analista Comercial: múltiples dimensiones con subtotales

Resultado por segmento, zona, período — preparado para filtros dinámicos en dashboard.

```sql
-- Patrón: GROUP BY con ROLLUP o dimensiones múltiples
SELECT
  IFNULL(t.itc_company_id, 'TOTAL')       AS empresa,
  IFNULL(p.store_region, 'TOTAL')         AS region,
  DATE_TRUNC(t.transaction_date, WEEK)    AS semana,
  COUNT(DISTINCT t.ticket_id)             AS transacciones,
  COUNT(DISTINCT t.id_intercorp)          AS clientes_unicos,
  SUM(t.product_item_gross_amount)        AS monto_total,
  SAFE_DIVIDE(
    SUM(t.product_item_gross_amount),
    COUNT(DISTINCT t.id_intercorp)
  )                                       AS spend_por_cliente
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
LEFT JOIN `intercorp-data-storage-pv.master_placement.m_place` p
  ON t.store_id = p.place_id
    AND t.itc_company_id = p.company_id
WHERE t.transaction_date BETWEEN @fecha_ini AND @fecha_fin
  AND t.itc_company_id = @empresa
GROUP BY ROLLUP(empresa, region, semana)
ORDER BY empresa, region, semana
```

### 3.3 — Ejecutivo: KPIs con comparativo vs período anterior

Resultado compacto con variaciones porcentuales y ranking.

```sql
-- Patrón: Window functions para comparativos y rankings
WITH periodo_actual AS (
  SELECT
    itc_company_id,
    SUM(product_item_gross_amount)     AS monto,
    COUNT(DISTINCT id_intercorp)       AS clientes,
    COUNT(DISTINCT ticket_id)          AS transacciones
  FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
  WHERE transaction_date BETWEEN @fecha_ini AND @fecha_fin
  GROUP BY itc_company_id
),
periodo_anterior AS (
  SELECT
    itc_company_id,
    SUM(product_item_gross_amount)     AS monto_ant
  FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
  WHERE transaction_date BETWEEN
    DATE_SUB(@fecha_ini, INTERVAL 1 YEAR) AND DATE_SUB(@fecha_fin, INTERVAL 1 YEAR)
  GROUP BY itc_company_id
)
SELECT
  a.itc_company_id,
  a.monto,
  a.clientes,
  a.transacciones,
  SAFE_DIVIDE(a.monto - p.monto_ant, p.monto_ant) * 100  AS var_pct_vs_anio_ant,
  RANK() OVER (ORDER BY a.monto DESC)                    AS ranking_monto
FROM periodo_actual a
LEFT JOIN periodo_anterior p USING (itc_company_id)
ORDER BY ranking_monto
```

---

## 4. Patrones de Aggregation Estándar ITC

Seguir los prefijos y fórmulas de `development.md` §7 para nombrar columnas de output:

| Métrica | Prefijo columna | Fórmula BigQuery |
|---|---|---|
| Monto total | `mto_` | `SUM(product_item_gross_amount)` |
| Monto promedio | `mtoprom_` | `SAFE_DIVIDE(SUM(monto), COUNT(DISTINCT ticket))` |
| Nro. transacciones distintas | `numtrx_` | `COUNT(DISTINCT ticket_id)` |
| Nro. días distintos con compra | `numdias_` | `COUNT(DISTINCT transaction_date)` |
| Porcentaje | `porc_` | `SAFE_DIVIDE(x, total) * 100` |
| Flag binario | `flag_` | `CASE WHEN condición THEN 1 ELSE 0 END` |
| Recencia (días) | `recencia` | `DATE_DIFF(hoy, MAX(transaction_date), DAY)` |
| Ticket promedio | `ticketprom_` | `SAFE_DIVIDE(SUM(monto), COUNT(DISTINCT ticket))` |

**Ejemplo con prefijos correctos:**

```sql
SELECT
  id_intercorp,
  SUM(product_item_gross_amount)                              AS mto_retail_6m,
  SAFE_DIVIDE(SUM(product_item_gross_amount),
    COUNT(DISTINCT ticket_id))                                AS ticketprom_retail_6m,
  COUNT(DISTINCT ticket_id)                                   AS numtrx_retail_6m,
  COUNT(DISTINCT transaction_date)                            AS numdias_retail_6m,
  DATE_DIFF(CURRENT_DATE(), MAX(transaction_date), DAY)       AS recencia_retail,
  CASE WHEN COUNT(DISTINCT ticket_id) > 0 THEN 1 ELSE 0 END  AS flag_comprador_retail_6m
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)
  AND itc_company_id = '010'
GROUP BY id_intercorp
```

---

## 5. Joins — Reglas de Eficiencia

### Orden de tablas en JOIN: tabla grande a la izquierda, pequeña a la derecha

```sql
-- ✅ Tabla transaccional grande (izquierda) + catálogo pequeño (derecha)
FROM `...t_retail_transaction` t          -- ~4.7B filas
LEFT JOIN `...m_product` mp               -- ~3.7M filas
  ON t.product_id = mp.product_id
  AND t.itc_company_id = mp.itc_company_id
```

### JOIN con atributos pre-calculados — usar siempre la misma `process_date`

```sql
-- ✅ Filtrar ambas tablas por partición antes del JOIN
WITH trans AS (
  SELECT id_intercorp, itc_company_id, SUM(product_item_gross_amount) AS monto
  FROM `...t_retail_transaction`
  WHERE transaction_date BETWEEN @fecha_ini AND @fecha_fin
  GROUP BY 1, 2
),
attr AS (
  SELECT id, spsa_numtrx_retail_1m, spsa_mtoprom_retail_1m
  FROM `...ba_itc_attr_retail`
  WHERE process_date = @process_date   -- partición de atributos
)
SELECT t.*, a.*
FROM trans t
LEFT JOIN attr a ON t.id_intercorp = a.id
```

### Aliases de tablas

| Situación | Convención |
|---|---|
| JOINs simples (2-4 tablas) | Letras secuenciales: `a`, `b`, `c` |
| Tablas fuente conocidas | Abreviatura: `trx`, `mp`, `fp`, `attr` |
| Múltiples ventanas temporales | `m1`, `m3`, `m6`, `m12` |
| CTEs numeradas | `TMP1`, `TMP2` en mayúsculas |
| JOINs masivos (>5 tablas) | `USING (id)` sin alias |

---

## 6. Funciones BigQuery Frecuentes para Análisis

### Fechas

```sql
-- Truncar a período
DATE_TRUNC(transaction_date, MONTH)         -- primer día del mes
DATE_TRUNC(transaction_date, WEEK)          -- lunes de la semana
DATE_TRUNC(transaction_date, QUARTER)       -- primer día del trimestre

-- Diferencias
DATE_DIFF(CURRENT_DATE(), fecha, DAY)       -- días de diferencia
DATE_DIFF(CURRENT_DATE(), fecha, MONTH)     -- meses de diferencia

-- Rangos dinámicos
DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH) -- últimos 6 meses
DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR)  -- mismo período año anterior
LAST_DAY(DATE_TRUNC(fecha, MONTH))          -- último día del mes

-- Formato
FORMAT_DATE('%Y-%m', fecha)                  -- "2026-03"
FORMAT_DATE('%Q-%Y', fecha)                  -- "Q1-2026"
```

### Window Functions para análisis

```sql
-- Ranking
RANK() OVER (PARTITION BY empresa ORDER BY monto DESC)
DENSE_RANK() OVER (ORDER BY clientes DESC)
ROW_NUMBER() OVER (PARTITION BY id ORDER BY fecha DESC)

-- Acumulados
SUM(monto) OVER (PARTITION BY empresa ORDER BY mes ROWS UNBOUNDED PRECEDING)
AVG(monto) OVER (PARTITION BY empresa ORDER BY mes ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)

-- Lag/Lead (comparativos)
LAG(monto, 1) OVER (PARTITION BY empresa ORDER BY mes)   -- mes anterior
LEAD(monto, 1) OVER (PARTITION BY empresa ORDER BY mes)  -- mes siguiente

-- First/Last value
FIRST_VALUE(producto) OVER (PARTITION BY cliente ORDER BY monto DESC
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) -- producto más comprado
```

### Geográfico (para ejecutivos)

```sql
-- Ubigeo → departamento (basado en los primeros 2 dígitos del ubigeo)
LEFT(ubigeo, 2) AS cod_departamento

-- Joins con datos geográficos de m_commerce
m.store_latitude, m.store_longitude
```

---

## 7. Estimación de Costo Antes de Ejecutar

Antes de ejecutar cualquier query sobre tablas grandes (`t_*` con >1B filas), incluir la estimación:

```sql
-- Usar DRY RUN para estimar: el query no se ejecuta, solo calcula bytes
-- En BQ: ejecutar con el botón "Estimar" o via API con dryRun=true

-- Regla de costo BQ: $6.25 por TB procesado (on-demand)
-- Estimación rápida:
-- Tabla t_retail_transaction (~4.7B filas) sin partición = ~2TB = ~$12.50
-- Con filtro de 1 mes de transaction_date = ~15GB = ~$0.09

-- Siempre verificar antes de ejecutar:
-- 1. ¿Hay filtro de partición en todas las tablas grandes?
-- 2. ¿El rango de fechas es razonable (días/semanas, no años completos)?
-- 3. ¿Las columnas del SELECT son necesarias (no SELECT *)?
```

**Alertas de costo:** si el query no tiene filtro de partición en una tabla con >500M filas,
advertir al orquestador antes de ejecutar:

```
⚠️ ALERTA DE COSTO
El query sobre `t_retail_transaction` sin filtro de partición procesará ~2TB (~$12.50).
Alternativa: usar `ba_itc_attr_retail` (atributos pre-calculados) si el análisis
no requiere detalle por ítem.
¿Confirmar ejecución?
```

---

## 8. Restricciones de Seguridad

### Datos sensibles — nunca incluir en output directo sin autorización

| Tabla | Tipo de sensibilidad | Acción |
|---|---|---|
| `ba_itc_attr_rcc` | Información crediticia SBS | Alertar al orquestador — requiere autorización explícita |
| `ba_itc_audience_contact` | PII: email, nombre, teléfono, dirección | Alertar — solo usar `id_intercorp` hasheado |
| Cualquier campo `*_email*`, `*_nombre*`, `*_telefono*` | PII directo | No incluir en SELECT sin aprobación |

```sql
-- ✅ Si se requieren datos de contacto, usar solo el hash
SELECT id_intercorp, hash_email  -- nunca raw_email
FROM `...ba_itc_audience_contact`

-- ❌ No exponer PII directo
SELECT id_intercorp, email_address, full_name, phone_number
FROM `...ba_itc_audience_contact`
```

---

## 9. Output del SQL Translator

El agente entrega siempre:

1. **El query listo para ejecutar** — con parámetros nombrados (`@fecha_ini`, `@fecha_fin`, `@empresa`) que el ejecutor puede reemplazar
2. **Estimación de costo** — bytes procesados estimados y costo aproximado
3. **Parámetros requeridos** — lista de variables que el orquestador debe completar
4. **Notas de optimización** — si hay alternativas más eficientes disponibles

```
## Query generado

**Propósito:** {descripción en lenguaje de negocio}
**Granularidad:** {nivel del resultado}
**Costo estimado:** ~{N} GB procesados (~${X} USD)

**Parámetros:**
  @fecha_ini = DATE '{YYYY-MM-DD}'
  @fecha_fin  = DATE '{YYYY-MM-DD}'
  @empresa    = STRING '{código empresa}'

**Query:**
```sql
{query completo y ejecutable}
```

**Notas:**
- {optimización o alternativa si aplica}
- {advertencia PII si aplica}
```

---

## 10. Queries de Referencia

Ver la colección de queries listos para ejecutar en:
`@.claude/data/data_catalog/queries/` — organizados por caso de uso de negocio.

| Archivo | Caso de uso |
|---|---|
| [`ventas-mensuales-empresa.sql`](@.claude/data/data_catalog/queries/ventas-mensuales-empresa.sql) | Ventas totales y ticket promedio SPSA/Promart/Oechsle por mes |

> Estos queries son la **fuente de verdad** para cómo se usan los campos `_1m` de las tablas `ba_*`
> para obtener totales de empresa. Usarlos como base antes de generar variantes.

---

## 11. Referencia a Estándares

- `@.claude/data/standard/bigquery/development.md` — reglas de SQL, naming, particiones, optimización
- `@.claude/data/standard/bigquery/nomenclatura-retail.md` — naming de columnas (prefijos empresa/métrica/ventana)
- `@.claude/data/data_catalog/README.md` — tablas disponibles y sus particiones
- `@.claude/data/skills/analysis/data-catalog-specialist/SKILL.md` — especificación técnica de entrada
