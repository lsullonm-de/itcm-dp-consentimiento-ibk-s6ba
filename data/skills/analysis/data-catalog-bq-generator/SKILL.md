# Skill: Data Catalog BQ Generator

> **Rol:** Data Profiler — ITC Data Platform
> **Activado por:** solicitud de documentación de una tabla BigQuery, generación de glosario de negocio, profiling de datos, análisis de calidad, entendimiento de una fuente de datos, enriquecimiento de spec con metadata de tablas fuente, identificación de tablas "inside project"
>
> **Estándares de referencia:**
> - `@.claude/data/data_catalog/README.md` — Índice de glosarios existentes
> - `@.claude/data/standard/architecture/data-platform-layers.md` — Nomenclatura de capas, prefijos de tabla, campos de auditoría y DQ
> - `@.claude/data/skills/design/intercorp-data-enablement/SKILL.md` — Dimensiones de calidad, Data Profiling, Golden Sources

---

## Propósito

Generar documentación completa y detallada de una tabla BigQuery para que un **analista de información** pueda:

- Responder preguntas de negocio
- Crear nuevos atributos de cliente
- Obtener insights de la información
- Realizar perfilamiento de clientes basado en consumos en las empresas del grupo Intercorp
- Identificar segmentos: clientes con enfermedades crónicas, dieta sana, aficionados al cine, etc.
- Tener nociones técnicas para queries: volumetría, campos de join, nulos, cardinalidad, etc.

El output es un archivo Markdown guardado en `data/data_catalog/{empresa}/{dataset}/`.

---

## ⚠️ Dos entregables obligatorios e irremplazables

Todo catálogo generado por este skill **DEBE** producir sin excepción:

### 1. Metadata técnica de la tabla
Toda información estructural extraída de BigQuery vía `INFORMATION_SCHEMA` o MCP:
- Tipo de tabla, particionado, clustering
- Esquema completo (nombre, tipo, nullable) de **todas** las columnas
- Estadísticas físicas: filas, tamaño lógico/físico, última modificación
- Rango de particiones disponibles
- DDL de la tabla

> No es opcional ni parcial. Si la tabla tiene 2,431 columnas, se documenta el esquema de las 2,431.

### 2. Diccionario completo de datos
Descripción semántica de **cada campo** de la tabla — qué representa, qué valores toma, cómo se usa:

| Estrategia | Cuándo aplicar |
|---|---|
| **Extraer del sistema** | Si la tabla tiene `description` en BigQuery Column → leer vía `INFORMATION_SCHEMA.COLUMN_FIELD_PATHS` |
| **Leer documentación existente** | Si hay un glosario previo en `data/data_catalog/` → enriquecerlo |
| **Inferir del nombre + datos** | Si no hay descripción → inferir el significado a partir del nombre del campo, su tipo, valores distintos, y el contexto de la tabla |
| **Preguntar al usuario** | Si el campo es ambiguo y no hay datos suficientes para inferir → señalarlo explícitamente y preguntar |

> **Ningún campo puede quedar sin descripción.** Si no se puede determinar el significado, documentarlo como `⚠️ Significado desconocido — requiere validación con el equipo de datos` en lugar de omitirlo.

**Señales para inferir el diccionario:**
- Nombre del campo: `product_item_gross_amount` → monto bruto del ítem de producto
- Valores distintos: si un campo `STRING` tiene solo `'Y'`/`'N'` → es un flag booleano
- Cardinalidad alta + formato fecha → campo de timestamp o fecha de evento
- Prefijo de empresa (`spsa_`, `pro_`, `oe_`) → atributo calculado por empresa
- Sufijo de ventana (`_1m`, `_3m`, `_12m`) → métrica agregada en ventana de N meses
- Patrón `_id` → clave foránea o identificador
- Campos de auditoría estándar (`load_date`, `record_source`, `creation_user`, `dq_flag_ind`) → documentar con el patrón estándar de la plataforma

---

## Contexto del Modelo de Datos ITC

### `itc_company_id` — Campo transversal
Todas las tablas del modelo corporativo tienen `itc_company_id`. Identifica la empresa del Grupo Intercorp. La relación completa está en `docs/relacion_company_ids.csv`.

Empresas principales en tablas de transacciones retail:

| itc_company_id | Empresa |
|---|---|
| 010 | SUPERMERCADOS PERUANOS (SPSA / Plaza Vea) |
| 011 | TIENDAS PERUANAS (Oechsle) |
| 013 | CINEPLANET |
| 024 | PROMART |
| 025 | INKAFARMA |
| 033 | NG RESTAURANTES |
| 048 | MIFARMA |
| 086 | IZIPAY |

### Tipos de tabla por prefijo

| Prefijo | Tipo | Partición habitual | Estrategia de muestreo |
|---|---|---|---|
| `t_` | Transacciones / eventos | `transaction_date`, `payment_date`, `process_date` | 3 días aleatorios por mes, últimos 12 meses |
| `m_` | Maestros (entidades) | Sin partición o `load_date` | Toda la data |
| `c_` | Catálogos | Sin partición | Toda la data |
| `ba_` | Atributos de cliente | `process_date` | 3 días aleatorios por mes, últimos 12 meses |
| `iden_` | Identidad / vinculación | Sin partición o `load_date` | Muestra reciente (último mes) |
| `dv_` | Data Vault (temporal/staging) | Variable | Muestra representativa |

---

## Proceso Paso a Paso

### Paso 1 — Obtener metadata técnica de la tabla

> **Este paso produce el primer entregable obligatorio.** Extraer la información estructural completa de BigQuery.

Usar BigQuery MCP o consultar `INFORMATION_SCHEMA` para obtener:

```sql
-- Metadata general de la tabla (tipo, DDL)
SELECT
  table_name,
  table_type,
  creation_time,
  ddl
FROM `{project}.{dataset}.INFORMATION_SCHEMA.TABLES`
WHERE table_name = '{table}';

-- Esquema completo de TODAS las columnas (incluye descriptions si existen)
SELECT
  column_name,
  ordinal_position,
  is_nullable,
  data_type,
  is_partitioning_column,
  clustering_ordinal_position,
  description          -- descripción registrada en BigQuery, si existe
FROM `{project}.{dataset}.INFORMATION_SCHEMA.COLUMN_FIELD_PATHS`
WHERE table_name = '{table}'
ORDER BY ordinal_position;

-- Metadata de particionado y clustering
SELECT *
FROM `{project}.{dataset}.INFORMATION_SCHEMA.TABLE_OPTIONS`
WHERE table_name = '{table}';

-- Estadísticas de almacenamiento (tamaño, filas)
SELECT
  project_id, dataset_id, table_id,
  row_count, size_bytes,
  ROUND(size_bytes / POW(1024,3), 2) AS size_gb,
  TIMESTAMP_MILLIS(last_modified_time) AS last_modified,
  TIMESTAMP_MILLIS(creation_time) AS created_at
FROM `{project}.{dataset}.__TABLES__`
WHERE table_id = '{table}';
```

**Outputs esperados del Paso 1:**
- Lista completa de columnas con tipo y nullable
- Campo de partición identificado — crítico para todas las consultas siguientes
- Tamaño y volumetría de la tabla
- Descriptions de columnas desde BigQuery (input para el diccionario en Paso 5)

> Si `COLUMN_FIELD_PATHS` no devuelve `description` (columna vacía), no es error — significa que la tabla no tiene descripciones registradas. En ese caso el diccionario se construye por inferencia en el Paso 5.

---

### Paso 2 — Determinar la estrategia de muestreo

**Tablas de eventos/transacciones** (`t_`, `ba_` con `process_date`):

```sql
-- Verificar el rango de fechas disponibles
SELECT
  MIN(partition_id) AS primera_particion,
  MAX(partition_id) AS ultima_particion,
  COUNT(*) AS total_particiones
FROM `{project}.{dataset}.INFORMATION_SCHEMA.PARTITIONS`
WHERE table_name = '{table}'
  AND partition_id != '__NULL__';
```

Luego seleccionar 3 días aleatorios por mes de los últimos 12 meses:

```sql
-- Identificar las particiones disponibles por mes
WITH meses AS (
  SELECT
    DATE_TRUNC(PARSE_DATE('%Y%m%d', partition_id), MONTH) AS mes,
    partition_id,
    row_count
  FROM `{project}.{dataset}.INFORMATION_SCHEMA.PARTITIONS`
  WHERE table_name = '{table}'
    AND partition_id != '__NULL__'
    AND PARSE_DATE('%Y%m%d', partition_id) >= DATE_SUB(CURRENT_DATE(), INTERVAL 12 MONTH)
),
ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY mes ORDER BY RAND()) AS rn
  FROM meses
)
SELECT mes, partition_id
FROM ranked
WHERE rn <= 3
ORDER BY mes DESC, partition_id;
```

**Catálogos y maestros** (`c_`, `m_`): tomar toda la data disponible.

---

### Paso 3 — Perfilado de datos

#### 3a. Volumetría por empresa y mes

```sql
-- Para tablas de eventos: distribución por itc_company_id y mes
WITH sample_days AS (
  -- reemplazar con las fechas seleccionadas en el paso 2
  SELECT fecha FROM UNNEST([
    DATE '2025-03-07', DATE '2025-03-14', DATE '2025-03-21',
    DATE '2025-04-03', DATE '2025-04-11', DATE '2025-04-19',
    -- ... continuar para los 12 meses
  ]) AS fecha
)
SELECT
  DATE_TRUNC({partition_field}, MONTH) AS mes,
  itc_company_id,
  itc_company_name,
  COUNT(*) AS registros,
  COUNT(DISTINCT id) AS clientes_unicos
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} IN (SELECT fecha FROM sample_days)
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2;
```

#### 3b. Calidad de datos — completitud de campos clave

```sql
-- Nulos y completitud de TODOS los campos
SELECT
  'campo_ejemplo' AS campo,
  COUNTIF(campo_ejemplo IS NULL) AS nulos,
  ROUND(COUNTIF(campo_ejemplo IS NULL) * 100.0 / COUNT(*), 2) AS pct_null,
  COUNT(DISTINCT campo_ejemplo) AS valores_unicos,
  COUNT(*) AS total
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} IN ({sample_dates})
```

> **Tip**: generar esta consulta para cada columna del schema o usar una consulta dinámica con `INFORMATION_SCHEMA`.

#### 3c. Distribución de campos categóricos clave

```sql
-- Para campos categóricos importantes (payment_method, channel, etc.)
SELECT
  itc_company_id,
  {campo_categorico},
  COUNT(*) AS frecuencia,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY itc_company_id), 2) AS pct
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} IN ({sample_dates})
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

#### 3d. Estadísticas de campos numéricos

```sql
SELECT
  itc_company_id,
  COUNT(*) AS n,
  ROUND(AVG({campo_numerico}), 2) AS promedio,
  ROUND(MIN({campo_numerico}), 2) AS minimo,
  ROUND(MAX({campo_numerico}), 2) AS maximo,
  ROUND(APPROX_QUANTILES({campo_numerico}, 4)[OFFSET(1)], 2) AS p25,
  ROUND(APPROX_QUANTILES({campo_numerico}, 4)[OFFSET(2)], 2) AS mediana,
  ROUND(APPROX_QUANTILES({campo_numerico}, 4)[OFFSET(3)], 2) AS p75
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} IN ({sample_dates})
  AND {campo_numerico} IS NOT NULL
GROUP BY 1;
```

#### 3e. Campos de calidad DQ

```sql
-- Estado de los flags DQ (si existen en la tabla)
SELECT
  itc_company_id,
  dq_flag_ind,
  COUNT(*) AS registros,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY itc_company_id), 2) AS pct
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} IN ({sample_dates})
GROUP BY 1, 2
ORDER BY 1, 2;
```

---

### Paso 4 — Analizar y documentar relaciones con otras tablas

Identificar campos de join con otras tablas del modelo. Guiarse por los patrones:

| Campo en la tabla | Join con | Propósito |
|---|---|---|
| `id` | Cualquier tabla con `id` (DNI/CE) | Vincular cliente entre empresas |
| `transaction_id` | `t_payment.transaction_id` | Obtener medios de pago de la venta |
| `product_id` / `sku` | `m_product` | Obtener jerarquía de producto |
| `place_id` | `m_place` | Obtener tienda/sucursal |
| `bin_card_id` | `c_bin_card` | Obtener banco emisor y marca de tarjeta |
| `itc_company_id` | `c_itc_company` | Obtener nombre y datos de la empresa |
| `id` (DNI) | `iden_itc_party` | Obtener `party_id` único del cliente |

---

### Paso 5 — Construir el diccionario de datos e inferir significados

> **Este paso produce el segundo entregable obligatorio.** Para cada campo del esquema obtenido en el Paso 1, determinar su descripción usando la siguiente jerarquía:

```
¿BigQuery tiene `description` para el campo?
  SÍ → usar esa descripción (complementar con datos si es vaga)
  NO → ¿existe catálogo previo en data/data_catalog/?
    SÍ → extraer descripción del catálogo existente
    NO → INFERIR a partir de:
           - nombre del campo + tipo de dato
           - muestra de valores distintos (query de ejemplo abajo)
           - contexto de la tabla y prefijo del campo
         Si no es posible inferir → marcar como ⚠️ pendiente
```

**Query para apoyar la inferencia (valores distintos de un campo):**
```sql
-- Usar para campos cuyo significado no es obvio por el nombre
SELECT
  {campo} AS valor,
  COUNT(*) AS frecuencia,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS pct
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} = '{fecha_muestra}'
  AND {campo} IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
LIMIT 30;
```

**Reglas de inferencia por patrón de nombre:**

| Patrón | Inferencia |
|---|---|
| `{emp}_mto_{x}_{Nm}` | Monto total de {x} para empresa {emp} en ventana de N meses |
| `{emp}_numtrx_{x}_{Nm}` | Número de transacciones de {x} para empresa {emp} en N meses |
| `{emp}_frecuencia_{Nm}` | Número de visitas/transacciones del cliente en la empresa en N meses |
| `{emp}_mtoprom_{Nm}` | Ticket promedio del cliente en la empresa en N meses |
| `{emp}_recencia` | Días desde la última transacción en la empresa (sin ventana) |
| `{campo}_id` | Identificador clave foránea — documentar tabla a la que apunta |
| `_flag_ind` | Indicador booleano — listar valores posibles |
| `dq_` | Campo de calidad de datos — estándar de la plataforma |
| `process_date` / `load_date` | Campo de control de proceso/carga — no fecha del evento |
| `record_source` | Sistema de origen del registro |
| `creation_user` | Usuario/SA que realizó la carga |

**Campos que nunca deben quedar sin descripción:**
- Campos de partición y clustering → descripción técnica + rol en queries
- Campos de join (`id`, `transaction_id`, `product_id`, etc.) → apuntar a qué tabla se une
- Campos de auditoría → descripción estándar de la plataforma
- Campos con >50% NULL → documentar el NULL explícitamente ("Campo actualmente sin uso", etc.)
- Campos categóricos → listar los valores posibles conocidos

---

### Paso 6 — Generar el archivo Markdown

#### Estructura de carpetas y naming

El catálogo se organiza por **empresa → dataset → tabla** dentro de `data/data_catalog/`:

```
data/data_catalog/
└── {empresa}/
    └── {dataset}/
        └── {tabla}.md
```

El slug `{empresa}` identifica la unidad de negocio dueña de los datos (no el proyecto GCP). Ejemplos de slugs: `fape`, `promart`, `oechsle`, `intercorp`, `izipay`, `ibk`.

**Ejemplos:**

| Tabla completa | Empresa | Ruta del catálogo |
|---|---|---|
| `prd-farma-peru-data-storage-pv.sand_comercial_agents.dv_fact_ventas` | `fape` | `data/data_catalog/fape/sand_comercial_agents/dv-fact-ventas.md` |
| `intercorp-data-storage-pv.bi_vuc_insight.dv_inretail_venta` | `intercorp` | `data/data_catalog/intercorp/bi_vuc_insight/dv-inretail-venta.md` |
| `intercorp-data-storage-pv.master_transaction.t_payment` | `intercorp` | `data/data_catalog/intercorp/master_transaction/t-payment.md` |
| `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` | `intercorp` | `data/data_catalog/intercorp/bi_itc_attribute_party/ba-itc-attr-retail.md` |

**Reglas de naming:**
- La **carpeta empresa** usa el slug del negocio en minúsculas (sin proyecto GCP, sin guiones)
- La **carpeta dataset** usa el nombre del dataset **tal como está** (con guiones bajos si los tiene)
- El **archivo** convierte guiones bajos del nombre de tabla a **guiones medios `-`**
- ✅ `fape/sand_comercial_agents/dv-fact-ventas.md`
- ❌ `sand_comercial_agents/dv-fact-ventas.md` — falta carpeta empresa
- ❌ `fape/sand_comercial_agents/dv_fact_ventas.md` — guiones bajos en el archivo
- ❌ `dv-fact-ventas.md` — suelto sin carpeta empresa/dataset

**Si no es claro qué slug de empresa usar:** preguntar al usuario antes de guardar.

#### Catalog ID — identificador independiente del proyecto

El **catalog ID** es `{empresa}.{dataset}.{tabla}` — **sin el proyecto GCP**. Es el identificador único del catálogo independientemente del ambiente donde se consulte la tabla.

```
Tabla en producción:  prd-farma-peru-data-storage-pv.sand_comercial_agents.dv_fact_ventas
Tabla en desarrollo:  dev-farma-peru-data-storage.sand_comercial_agents.dv_fact_ventas

Catalog ID (ambas):   fape.sand_comercial_agents.dv_fact_ventas
Ruta (ambas):         data/data_catalog/fape/sand_comercial_agents/dv-fact-ventas.md
```

> El catálogo describe la **tabla** (su schema, semántica, reglas de negocio), no el **proyecto** donde se aloja. Un profiling realizado sobre la copia de desarrollo es válido para documentar la tabla canónica — registrar en `Profiling realizado sobre:` sobre cuál instancia se ejecutó.

El archivo debe seguir esta estructura **exacta**:

---

```markdown
# Catálogo de Datos — `{nombre_tabla}`

**Catalog ID:** `{empresa}.{dataset}.{table}`
**Empresa:** `{empresa}`
**Proyecto canónico:** `{project}`
**Dataset:** `{dataset}`
**Tabla completa:** `{project}.{dataset}.{table}`
**Profiling realizado sobre:** `{profiling_project}.{profiling_dataset}.{profiling_table}`
_(puede ser una copia en dev o la tabla origen en prod — el catalog ID es el mismo)_

---

## Descripción

{Descripción clara en 2-4 párrafos: qué representa cada fila, qué empresas cubre,
qué casos de uso resuelve, cómo se relaciona con otras tablas}

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE / VIEW |
| Particionado por | `{campo_particion}` (DAY) o Sin partición |
| Clusterizado | `{campo_cluster}` o NO |
| Total de filas | ~{N} |
| Número de columnas | {N} |
| Tamaño lógico | ~{N} GB / TB |
| Tamaño físico | ~{N} GB |
| Particiones | {N} |
| Última fecha disponible | {fecha} |
| Primera fecha disponible | {fecha} |
| Frecuencia | Diaria / Mensual / Única |
| Fuente | {record_source} |
| Ubicación | US |

---

## Volumen por empresa y mes (muestra: 3 días/mes, {período})

| Mes | Empresa | Registros (~3 días) | Clientes únicos |
|---|---|---|---|
| ... | ... | ... | ... |

> **Snapshot de un día ({fecha}):** {N} filas · {N} clientes únicos · {N} empresas.

---

## Glosario de Campos

### 1. {Grupo de campos — ej. "Identificadores y control"}

| Campo | Tipo | Descripción |
|---|---|---|
| `{campo}` | {tipo} | **Campo de partición** (si aplica). {descripción} |
| ... | ... | ... |

### 2. {Siguiente grupo de campos}
...

> Para cada campo indicar:
> - Si es **campo de partición** o **clave primaria** (resaltar en negrita)
> - Si tiene nulos relevantes: `{N}% NULL`
> - Si es **clave de join** con otra tabla: documentarlo
> - Si varía por `itc_company_id`: documentar diferencias
> - Si el campo está **100% NULL** o es no usable: indicarlo claramente

---

## Relación con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `{tabla}` | `{campo}` = `{tabla}.{campo}` | {propósito} |
| ... | ... | ... |

---

## Empresas cubiertas

| itc_company_id | Empresa | Volumen diario aprox. |
|---|---|---|
| {id} | {nombre} | ~{N} registros/día |
| ... | ... | ... |

---

## Reglas de negocio

1. **{Nombre de la regla}** — {descripción detallada}.
2. ...

> Incluir al menos:
> - Cómo filtrar correctamente (siempre por campo de partición)
> - Granularidad de la tabla (qué representa cada fila)
> - Cómo contar entidades únicas (transacciones, clientes, etc.)
> - Campos no confiables o siempre nulos
> - Rezago del ETL (process_date vs fecha real)
> - Diferencias de comportamiento por empresa

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `{campo}` | {N}% | {observación} |
| ... | ... | ... |

---

## Queries de referencia

```sql
-- {Descripción del caso de uso}
SELECT ...
FROM `{project}.{dataset}.{table}`
WHERE {partition_field} = '{fecha}'
...;

-- {Segundo caso de uso}
...
```

---

---

> **Nota de profiling:** Este glosario fue generado con datos extraídos de
> `{profiling_project}.{profiling_dataset}.{profiling_table}`.
> {Si es distinta a la tabla canónica, indicar el motivo: "copia en dev para etapa de diseño",
> "vista materializada en proyecto de usuario", etc.}

*Generado: {fecha} | Fuente: BigQuery `{project}.{dataset}.{table}`*
```

---

## Checklist de Completitud

Antes de guardar el archivo, verificar:

**Metadata técnica (Entregable 1):**
- [ ] Tabla y proyecto identificados correctamente
- [ ] Esquema completo extraído — **ninguna columna omitida** (verificar `COUNT(*)` de INFORMATION_SCHEMA vs columnas documentadas)
- [ ] Campo de partición identificado y documentado
- [ ] Clustering documentado (campos y orden)
- [ ] Estadísticas físicas completas: filas, tamaño lógico, tamaño físico, última modificación
- [ ] Rango de particiones disponibles (primera y última fecha)
- [ ] Frecuencia de carga documentada (diaria / mensual / única)

**Diccionario de datos (Entregable 2):**
- [ ] **Todos** los campos tienen descripción — ninguno en blanco
- [ ] Campos sin descripción en BigQuery → inferidos y marcados con fuente de inferencia, o marcados como ⚠️ pendiente
- [ ] Campos de partición y clustering → descritos con su rol técnico
- [ ] Campos de join → apuntan a la tabla de destino
- [ ] Campos categóricos → valores posibles listados (obtenidos por query o inferidos)
- [ ] Campos de auditoría (`load_date`, `record_source`, `creation_user`, `dq_*`) → descritos con el estándar de la plataforma
- [ ] Campos con nulos significativos (>5%) → documentados con porcentaje
- [ ] Campos 100% NULL → marcados explícitamente como "no usar" o "sin datos disponibles"
- [ ] Variaciones por `itc_company_id` documentadas donde aplica

**Análisis y relaciones:**
- [ ] Volumetría por empresa y mes calculada (o toda la data para catálogos)
- [ ] Relaciones con otras tablas identificadas
- [ ] Empresas cubiertas listadas con volumen aproximado
- [ ] Al menos 4 reglas de negocio documentadas
- [ ] Al menos 3 queries de referencia útiles para analistas

**Archivo:**
- [ ] Catalog ID calculado como `{empresa}.{dataset}.{tabla}` (sin proyecto GCP) y registrado en el encabezado del markdown
- [ ] Campo **Empresa** identificado y registrado en el encabezado del markdown
- [ ] Carpeta creada si no existe: `data/data_catalog/{empresa}/{dataset}/`
- [ ] Archivo guardado en: `data/data_catalog/{empresa}/{dataset}/{tabla-con-guiones}.md`
  - La carpeta empresa usa el slug del negocio en minúsculas
  - La carpeta dataset usa el nombre del dataset tal como está
  - El archivo convierte guiones bajos del nombre de tabla a **guiones medios `-`**
  - ✅ Correcto: `data/data_catalog/fape/sand_comercial_agents/dv-fact-ventas.md`
  - ❌ Incorrecto: `data/data_catalog/sand_comercial_agents/dv-fact-ventas.md` (falta empresa)
  - ❌ Incorrecto: `data/data_catalog/fape/sand_comercial_agents/dv_fact_ventas.md` (guiones bajos en archivo)

---

## Ejemplos de Glosarios de Referencia

Para calibrar el nivel de detalle esperado, revisar:

- `@.claude/data/data_catalog/fape/sand_comercial_agents/dv-fact-ventas.md` — tabla FACT de ventas FAPE (empresa: fape)
- `@.claude/data/data_catalog/intercorp/master_transaction/t-payment.md` — tabla de detalle de pagos (75 campos)
- `@.claude/data/data_catalog/intercorp/master_transaction/t-retail-transaction.md` — transacciones retail (~10B filas)
- `@.claude/data/data_catalog/intercorp/master_product/m-product.md` — catálogo de productos (ejemplo de maestro)
- `@.claude/data/data_catalog/intercorp/bi_itc_attribute_party/ba-itc-attr-retail.md` — atributo de cliente (2,431 columnas)

---

## Herramienta: Data Profiler Cloud Function

**⚠️ IMPORTANTE: Este skill NO contiene código de extracción. Usa la herramienta centralizada:**

### Ubicación
📍 `tools/fun-data-profiler-bq/` — Herramienta de profiling producción-ready

### Componentes
- **Cloud Function:** `service/cloud_function/data-profiler-bq/main.py`
  - Desplegada en GCP
  - Extrae metadata desde INFORMATION_SCHEMA
  - Genera análisis de campos (categorías, riesgo PII)
  
- **Cliente Local:** `tools/fun-data-profiler-bq/`
  - `main.py` — CLI invocador
  - `run_profiler.py` — Runner integrado (CF + markdown)
  - `client.py` — Cliente HTTP con autenticación
  - `markdown_generator.py` — Generador de catálogos markdown

### Cómo usarla
```bash
# Opción 1: Desde Cloud Shell (con autenticación)
TOKEN=$(gcloud auth print-identity-token)
curl -X POST https://dev-fun-data-profiler-test-232282934791.us-central1.run.app \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"table_ref": "dev-itc-customer-services.farmas_stage.dv_productos"}'

# Opción 2: Desde máquina local (Python)
cd tools/fun-data-profiler-bq/
python run_profiler.py \
  --config config.json \
  --table-ref dev-itc-customer-services.farmas_stage.dv_productos \
  --output-dir data/data_catalog/
```

### Output
- `metadata.json` — JSON con metadata + análisis (field categories, PII risk, field profiling)
- `{dataset}-{tabla}.md` — Catálogo markdown (Overview, Diccionario, Seguridad, Estadísticas)
  - **NAMING:** usar guiones medios `-` en lugar de guiones bajos `_`
  - Ejemplo: `farmas-stage-dv-productos.md` ✅

### Referencia
- 📖 `tools/fun-data-profiler-bq/README.md` — Setup completo
- 📖 `tools/fun-data-profiler-bq/QUICKSTART.md` — Guía rápida

---

## Notas sobre herramientas complementarias

- **BigQuery MCP**: usar `mcp__claude_ai_Google_Cloud_BigQuery__authenticate` para ejecutar queries directamente cuando esté disponible
- **SQL estático**: si MCP no está disponible, generar todos los SQLs y pedirle al usuario que los ejecute y pegue los resultados
- **Encoding**: al leer CSVs con Python en Windows usar `encoding='cp1252'` o `encoding='utf-8-sig'`
- **Archivo company_ids**: la relación de `itc_company_id` → empresa está en `docs/relacion_company_ids.csv`

---

## Patrón "Inside Project" — Vistas en proyectos de usuario

En entornos de desarrollo/análisis, las tablas de producción suelen estar expuestas como **vistas** en proyectos intermedios. Identificar este patrón antes de comenzar el profiling.

### Estructura del patrón

```
Proyecto real (prod):   intercorp-data-storage-pv.master_transaction.t_payment
                                        │
                                        ▼  (vista en proyecto de usuario)
Proyecto inside:        prd-[empresa]-data-storage-pv.[usuario]_inside.prd_itc_data_storage_pv_master_transaction_t_payment
```

### Reglas de resolución

| Elemento | Patrón | Ejemplo |
|---|---|---|
| Proyecto inside | `prd-[abrev_empresa]-data-storage-pv` | `prd-itc-data-storage-pv` |
| Dataset inside | `[usuario]_inside` | `amoreno_inside` |
| Nombre de la vista | `{proyecto}_{dataset}_{tabla}` (guiones → guiones bajos) | `prd_itc_data_storage_pv_master_transaction_t_payment` |

### Cómo resolver la tabla canónica desde una vista inside

Cuando el spec indica una tabla con patrón inside, hacer:

```sql
-- 1. Leer la definición de la vista para obtener la tabla origen real
SELECT view_definition
FROM `{inside_project}.{inside_dataset}.INFORMATION_SCHEMA.VIEWS`
WHERE table_name = '{nombre_vista}';
-- La definición apuntará a la tabla real en el proyecto origen.

-- 2. Alternativamente, decodificar el nombre de la vista:
--    prd_itc_data_storage_pv_master_transaction_t_payment
--    → proyecto: prd-itc-data-storage-pv
--    → dataset:  master_transaction
--    → tabla:    t_payment
```

### Decisión sobre dónde hacer el profiling

| Situación | Tabla a usar para profiling | Nota en glosario |
|---|---|---|
| Se tiene acceso al proyecto prod | Tabla canónica en prod | "Profiling sobre tabla canónica" |
| Solo se tiene acceso al proyecto inside | Vista en `[usuario]_inside` | "Profiling sobre vista en proyecto de usuario — misma data" |
| El spec indica copia en dev | Tabla copiada en dev | "Profiling sobre copia en dev — validar que es representativa" |
| No hay acceso | No se puede generar glosario | `glosario_status: sin_acceso` |

**Siempre registrar en el glosario sobre qué tabla exacta se hizo el profiling** (campo `Profiling realizado sobre:`).

---

## Etapa: Enriquecimiento de Spec con Glosarios

Cuando el usuario proporciona un documento de especificación (YAML, Markdown u otro formato), seguir este flujo para enriquecer las fuentes con su glosario correspondiente.

### Flujo general

```
Leer spec
  └── Para cada fuente en fuentes[]:
        ├── Resolver tabla canónica (si es inside o tiene variables ${...})
        ├── Buscar catálogo existente en data/data_catalog/
        │     ├── ENCONTRADO → extraer metadata relevante → enriquecer fuente en spec
        │     └── NO ENCONTRADO → ejecutar flujo de profiling (Pasos 1-5 de este skill)
        │           └── Generar glosario → luego enriquecer fuente en spec
        └── Actualizar campo glosario_status en spec
```

### Campos a agregar/actualizar en cada `fuente` del spec

```yaml
fuentes:
  - id: t_payment
    descripcion: "Detalle de medios de pago"
    proyecto: "${project_t_payment}"
    dataset: "${dataset_t_payment}"
    tabla: "${table_t_payment}"

    # ── Campos de referencia canónica ──────────────────────────────
    tabla_canonica: "intercorp-data-storage-pv.master_transaction.t_payment"
    # Tabla real en producción. Si el spec usa variables ${...} o patrón inside,
    # anotar aquí la referencia resuelta para que el glosario sea inequívoco.

    # ── Datos para profiling ───────────────────────────────────────
    tabla_profiling: "intercorp-data-storage-pv.master_transaction.t_payment"
    # Tabla exacta sobre la que SE REALIZÓ el profiling.
    # Puede ser la canónica, una copia en dev, o una vista inside.
    # Ejemplo inside: "prd-itc-data-storage-pv.amoreno_inside.prd_itc_data_storage_pv_master_transaction_t_payment"

    # ── Estado del glosario ────────────────────────────────────────
    empresa: "intercorp"                                # slug de empresa dueña de los datos
    catalog_id: "intercorp.master_transaction.t_payment"  # {empresa}.{dataset}.{tabla} — sin proyecto GCP
    glosario_status: generado       # valores: generado | pendiente | sin_acceso | no_aplica
    catalog_path: "data/data_catalog/intercorp/master_transaction/t-payment.md"

    # ── Metadata enriquecida desde el glosario ─────────────────────
    particion: payment_date         # campo de partición confirmado
    volumetria: "~2.83B filas · ~928 GB lógico · diaria"
    empresas_cubiertas: [010, 025, 048, 024, 011]
    campos_join_clave: [payment_date, transaction_id, id, bin_card_id]
    pii: false                      # confirmar si tiene datos PII
    observaciones: >
      payment_type y payment_bank siempre NULL — no usar.
      Rezago ETL ~13 días. Usar bin_card_id para identificar banco emisor.
```

### Valores válidos para `glosario_status`

| Valor | Significado |
|---|---|
| `generado` | Catálogo existe en `data/data_catalog/` — enriquecimiento completado |
| `pendiente` | Tabla identificada pero sin glosario — profiling por ejecutar |
| `sin_acceso` | No hay acceso a la tabla para hacer profiling |
| `no_aplica` | Tabla temporal, staging o sin relevancia para el glosario |

### Algoritmo de búsqueda de glosario existente

Dado una tabla `{project}.{dataset}.{table}` y su empresa, calcular el **catalog ID** = `{empresa}.{dataset}.{table}` (ignorar el proyecto GCP):

1. Buscar ruta principal: `data/data_catalog/{empresa}/{dataset}/{table-con-guiones}.md`
   - Ejemplo: `fape`, `sand_comercial_agents.dv_fact_ventas` → `data/data_catalog/fape/sand_comercial_agents/dv-fact-ventas.md`
2. Si no existe la carpeta empresa/dataset, buscar en estructura legacy sin empresa: `data/data_catalog/{dataset}/{table-con-guiones}.md`
3. Si tampoco existe → `glosario_status: pendiente` → ejecutar Pasos 1-6

> El catalog ID es siempre `{empresa}.{dataset}.{table}`. Una tabla `dev-intercorp-data-storage.bi_vuc_insight.dv_inretail_venta` (dev) y `intercorp-data-storage-pv.bi_vuc_insight.dv_inretail_venta` (prod) comparten el mismo catálogo en `data/data_catalog/intercorp/bi_vuc_insight/dv-inretail-venta.md`.

Para tablas `inside`, resolver primero la tabla canónica y usar empresa+dataset+tabla para construir el catalog ID.

### Qué información extraer del glosario para el spec

Al encontrar un glosario existente, extraer y agregar al spec:

```yaml
# Desde la sección "Metadata BigQuery" del glosario:
particion: {campo_particion}
volumetria: "{filas} · {tamaño} · {frecuencia}"

# Desde la sección "Glosario de Campos":
campos_join_clave: [lista de campos de join identificados en el glosario]

# Desde la sección "Empresas cubiertas":
empresas_cubiertas: [lista de itc_company_id]

# Desde "Reglas de negocio" y "Observaciones de calidad":
observaciones: >
  {resumen de las observaciones más relevantes para el proyecto}
```

### Uso del glosario en la construcción de scripts

Una vez enriquecido el spec, al generar scripts (SPs, pipelines, DDLs), aprovechar la metadata:

- **Campo de partición**: siempre filtrar por él en los WHERE de los SPs
- **Campos de join clave**: usar los documentados para los JOINs — no inventar campos
- **Empresas cubiertas**: filtrar por `itc_company_id IN (...)` según lo documentado
- **Observaciones de calidad**: excluir campos nulos, manejar tipos STRING en fecha, etc.
- **Volumetría**: dimensionar timeouts, recursos de máquina y estrategia de muestreo

### Checklist de enriquecimiento de spec

Antes de dar por completada la etapa de enriquecimiento:

- [ ] Todas las fuentes tienen `tabla_canonica` resuelta (sin variables `${...}` sin resolver ni nombres ambiguos)
- [ ] Todas las fuentes tienen `tabla_profiling` indicando la tabla real usada para profiling
- [ ] Todas las fuentes tienen `glosario_status` distinto de vacío
- [ ] Las fuentes con `glosario_status: pendiente` tienen un plan de cuándo se generará el glosario
- [ ] Las fuentes con `glosario_status: generado` tienen `empresa` y `catalog_path` apuntando al archivo correcto (`data/data_catalog/{empresa}/{dataset}/{tabla}.md`)
- [ ] Los campos `particion`, `volumetria` y `campos_join_clave` están poblados para las fuentes críticas
- [ ] Las observaciones de calidad relevantes para el proyecto están copiadas al spec
