# Reglas BigQuery — DDL, SP, Naming, Particiones

> Aplica a: `data/bigquery/{dataset_out}/{tabla_out}/ddl/*.sql`, `.../sp/*.sql`, `.../dml/*.sql`

---

## DDL — Creación de Tablas

### ✅ Usar siempre `CREATE TABLE IF NOT EXISTS` en DDL de tablas finales

```sql
-- ✅ CORRECTO — idempotente + 3 variables (project + dataset + table)
CREATE TABLE IF NOT EXISTS `${project_ba_itc_attr_retail}.${dataset_ba_itc_attr_retail}.${table_ba_itc_attr_retail}`
(...)

-- ❌ INCORRECTO — destruye la tabla existente en producción
CREATE OR REPLACE TABLE `...`

-- ❌ INCORRECTO — solo 2 variables (tabla hardcodeada)
CREATE TABLE IF NOT EXISTS `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
```

> **Excepción:** dentro de SPs, las tablas intermedias (`tmp_*`, `aux_*`) en `${dataset_stage}`
> pueden usar `CREATE OR REPLACE TABLE` — no son tablas finales y necesitan sobreescribirse cada ejecución.

### ✅ Tablas de transacciones y eventos: partición + clustering obligatorios

Las tablas que registran **transacciones, eventos o cargas incrementales** (prefijo `t_`, `ba_` con tipo_carga incremental) deben tener:
- `PARTITION BY` sobre el campo de fecha de la transacción o `load_date`
- `CLUSTER BY` sobre los campos más usados en filtros (`WHERE`, `JOIN`)

```sql
-- ✅ CORRECTO — tabla de transacciones con partición y clustering
CREATE TABLE IF NOT EXISTS `${project_analytics}.${dataset_analytics}.t_retail_transaction`
(
  id_intercorp     STRING,
  fecha_transaccion DATE,
  monto            FLOAT64,
  load_date        DATE,
  ...
)
PARTITION BY fecha_transaccion
CLUSTER BY id_intercorp, fecha_transaccion
OPTIONS (description = '...');

-- ❌ INCORRECTO — tabla de transacciones sin partición
CREATE TABLE IF NOT EXISTS `...t_retail_transaction`
(...) -- sin PARTITION BY → riesgo de full scan en producción
```

**Regla:** si la tabla tiene más de 1M filas estimadas en el spec o `tipo_carga: incremental`, partición y clustering son **obligatorios**.

### ✅ Campos de auditoría en todas las tablas output

Toda tabla en capa business o master debe incluir los 3 campos de auditoría:

```sql
-- ✅ OBLIGATORIO en todas las tablas de analytics
load_date       DATE       OPTIONS(description='Fecha de carga del proceso'),
record_source   STRING     OPTIONS(description='SP o proceso origen'),
creation_user   STRING     OPTIONS(description='SA o usuario que ejecutó la carga')
```

### ✅ Labels en todas las tablas

```sql
OPTIONS (
  description = 'Descripción funcional de la tabla',
  labels      = [("team", "data-platform"), ("env", "${env}")]
)
```

### ❌ ALTER TABLE — solo ADD COLUMN; DROP COLUMN prohibido

Los cambios de esquema en tablas BigQuery se gestionan con scripts **ALTER TABLE** independientes,
ubicados en `data/bigquery/{dataset_out}/{tabla_out}/alter/` — **nunca** embebidos en el DDL de
`CREATE TABLE IF NOT EXISTS`.

```sql
-- ✅ CORRECTO — ADD COLUMN idempotente (archivo: alter/alter_{tabla}_YYYYMMDD_NNN.sql)
ALTER TABLE `${project_ba_itc_attr_retail}.${dataset_ba_itc_attr_retail}.${table_ba_itc_attr_retail}`
ADD COLUMN IF NOT EXISTS nuevo_campo STRING OPTIONS (description = 'Campo agregado en migración YYYYMMDD');

-- ❌ PROHIBIDO — DROP COLUMN elimina datos en producción de forma irreversible
ALTER TABLE `...`
DROP COLUMN campo_viejo;

-- ❌ INCORRECTO — ALTER embebido en el archivo CREATE TABLE
CREATE TABLE IF NOT EXISTS `...`
(
  campo_existente STRING,
  nuevo_campo     STRING    -- ← debe ir en alter/ separado, no aquí
)
```

**Reglas de naming:**
- Un archivo por migración: `alter_{tabla_out}_{YYYYMMDD}_{NNN}.sql`
  - Ej.: `alter_ba_itc_attr_retail_20260817_001.sql`
- Mismo prefijo de fecha agrupa migraciones del mismo release
- Siempre incluir `IF NOT EXISTS` para idempotencia (re-ejecución segura)
- Registrar en `deploy_[env].json` bajo `bigquery_ddl`, **DESPUÉS** del `{tabla_out}.sql`

---

### ❌ No usar `DROP TABLE` en código de producción

```sql
-- ❌ PROHIBIDO — riesgo de pérdida irreversible de datos en producción
DROP TABLE `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`;

-- ✅ ALTERNATIVA para limpiar antes de carga full
TRUNCATE TABLE `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`;

-- ✅ ALTERNATIVA para limpiar partición específica
DELETE FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
WHERE load_date = DATE('${process_date}');
```

### ❌ No usar `ALTER TABLE DROP COLUMN`

```sql
-- ❌ PROHIBIDO en producción — puede romper consumers downstream
ALTER TABLE `...` DROP COLUMN campo_sensible;

-- ✅ ALTERNATIVA — deprecar con comentario, eliminar en ventana de mantenimiento
-- [DEPRECATED] campo_sensible: marcar en DDL y coordinar con consumers
```

---

## SP — Stored Procedures

### ✅ Naming de SPs

```
sp_{nombre_proceso}.sql          ← SP de carga principal
sp_dq_{tabla_destino}.sql        ← SP de Data Quality
```

### ✅ Header del SP usa `${project_operation}.${dataset_sp}`

El `CREATE OR REPLACE PROCEDURE` debe referenciar el proyecto de operación y el dataset de SPs mediante variables — nunca hardcodeado ni construido con `${env}-...`.

```sql
-- ✅ CORRECTO — project_operation ya incluye el ambiente en su valor
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_calcular_score`(process_date STRING)

-- ❌ INCORRECTO — hardcodeado
CREATE OR REPLACE PROCEDURE `dev-itc-customer-services.stored_procedures.sp_calcular_score`(process_date STRING)

-- ❌ INCORRECTO — project_operation ya contiene el env, este patrón lo duplica
CREATE OR REPLACE PROCEDURE `${env}-itc-customer-services.${dataset_sp}.sp_calcular_score`(process_date STRING)

-- ❌ INCORRECTO — los SPs NO se crean en project_analytics
CREATE OR REPLACE PROCEDURE `${project_analytics}.${dataset_sp}.sp_calcular_score`(process_date STRING)
```

### ✅ Sin valores hardcodeados — siempre `${variables}`

```sql
-- ✅ CORRECTO
INSERT INTO `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`

-- ❌ INCORRECTO — hardcoded, rompe en otro ambiente
INSERT INTO `prd-itc-customer-services.analytics.ba_itc_attr_retail`
```

### ✅ Tablas temporales en `project_analytics` + `dataset_stage`

Todas las tablas BigQuery — tanto temporales/stage como definitivas — se crean en `project_analytics`. Solo los Stored Procedures usan `project_operation`.

```sql
-- ✅ CORRECTO — temporales en project_analytics, dataset_stage
CREATE OR REPLACE TABLE `${project_analytics}.${dataset_stage}.tmp_attr_retail_1` AS (...)

-- ❌ INCORRECTO — project_operation es para SPs y servicios, no para tablas BQ
CREATE OR REPLACE TABLE `${project_operation}.${dataset_stage}.tmp_attr_retail_1` AS (...)

-- ❌ INCORRECTO — temporal en dataset_analytics
CREATE OR REPLACE TABLE `${project_analytics}.${dataset_analytics}.tmp_attr_retail_1` AS (...)
```

### ✅ Naming de tablas temporales

```
tmp_{tabla_destino}_{n}     ← n = número de paso (1, 2, 3...)
```

### ✅ Sin `SELECT *` en SPs de producción

```sql
-- ✅ CORRECTO — columnas explícitas
SELECT id_intercorp, fecha, monto, load_date FROM ...

-- ❌ INCORRECTO — fragile si cambia el schema de la fuente
SELECT * FROM ...
```

### ✅ Cada regla de negocio comentada con su ID

```sql
-- [RN-ITC-001] Mapeo de nivel educativo según diccionario aprobado
CASE nivel_educativo
  WHEN 'Primaria incompleta' THEN 1
  ...
```

### ✅ SPs con fechas usan `process_date_ini` y `process_date_end` — nunca un único `process_date`

Todo SP que filtre datos por fecha de proceso debe declarar el par completo de parámetros,
permitiendo procesar tanto una fecha única como un rango sin cambiar la firma.

```sql
-- ✅ CORRECTO — par de fechas, soporta fecha única y rango
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_{nombre}` (
  IN p_process_date_ini  DATE,
  IN p_process_date_end  DATE,
  ...
)
...
-- Filtro estándar dentro del SP:
WHERE process_date BETWEEN p_process_date_ini AND p_process_date_end

-- ❌ INCORRECTO — parámetro único, no soporta rango
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_{nombre}` (
  IN p_process_date  DATE,
  ...
)
...
WHERE process_date = p_process_date
```

**Caller (workflow):** cuando se procesa una fecha única, pasar el mismo valor en ambos:
```sql
CALL `...sp_{nombre}`(DATE '${process_date_ini}', DATE '${process_date_end}', ...)
-- Si process_date_ini = process_date_end → equivale a filtro de fecha única
```

### ✅ DECLARE siempre antes de cualquier SET u otro statement en el BEGIN block

BigQuery requiere que todas las sentencias `DECLARE` estén al inicio del bloque `BEGIN`, antes de cualquier otro statement (`SET`, `CREATE`, `INSERT`, `CALL`, etc.). Violar este orden causa error de parsing al desplegar.

Esto aplica también cuando se agregan parámetros `OUT`: los `SET` de inicialización de los OUT params deben ir **después** de todos los `DECLARE`, no antes.

```sql
-- ✅ CORRECTO — todos los DECLARE primero, luego los SET
BEGIN
  -- 1. Variables locales
  DECLARE v_project_source   STRING;
  DECLARE v_dataset_source   STRING;
  DECLARE v_read             INT64;
  DECLARE v_write            INT64;

  -- 2. Inicialización de OUT params (después de todos los DECLARE)
  SET o_execution_data_read      = 0;
  SET o_execution_data_write     = 0;
  SET o_execution_data_duplicate = 0;
  SET o_object_last_load_date    = CURRENT_DATETIME('America/Lima');

  -- 3. Resto de la lógica
  SET v_project_source = p_project_source;
  ...

-- ❌ INCORRECTO — SET antes de DECLARE → BigQuery rechaza con error de parsing
BEGIN
  SET o_execution_data_read = 0;   -- ← error: statement antes de DECLARE
  SET o_execution_data_write = 0;

  DECLARE v_project_source STRING;  -- demasiado tarde
  DECLARE v_dataset_source STRING;
```

**Orden obligatorio dentro de `BEGIN`:**
1. `DECLARE` de todas las variables locales (incluidas las auxiliares)
2. `SET` de inicialización (OUT params y variables con valor fijo)
3. Resto de la lógica del SP

> **Contexto frecuente de error:** al agregar los 4 parámetros `OUT` de monitoring
> (`o_execution_data_read`, etc.) e inicializarlos al principio del cuerpo, es fácil
> colocar los `SET` antes de los `DECLARE` ya existentes. Siempre verificar el orden
> completo del bloque `BEGIN` después de esta modificación.

### ✅ MERGE preferido sobre DELETE + INSERT para cargas incrementales

```sql
-- ✅ CORRECTO — idempotente
MERGE `${project_analytics}.${dataset_analytics}.{tabla}` AS target
USING staging AS source
ON target.id = source.id AND target.load_date = source.load_date
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...

-- ❌ EVITAR — no idempotente si el SP falla a mitad
DELETE FROM `...` WHERE load_date = ...;
INSERT INTO `...` SELECT ...;
```

---

## Naming — Objetos BigQuery

| Objeto | Patrón | Ejemplo |
|---|---|---|
| Tabla business | `ba_{empresa}_{dominio}_{atributo}` | `ba_itc_attr_retail` |
| Tabla master transaccional | `t_{nombre}` | `t_retail_transaction` |
| Tabla master | `m_{nombre}` | `m_customer` |
| Tabla temporal | `tmp_{tabla}_{n}` | `tmp_attr_retail_1` |
| SP de carga | `sp_{proceso}` | `sp_load_attr_retail` |
| SP de DQ | `sp_dq_{tabla}` | `sp_dq_ba_itc_attr_retail` |
| Dataset analytics | `analytics` | — |
| Dataset stage | `stage_tmp` | — |
| Dataset SPs | `stored_procedures` | — |

> Ver naming completo: `@.claude/data/standard/bigquery/nomenclatura-retail.md`

---

## Checklist BigQuery

- [ ] Todas las tablas usan `CREATE TABLE IF NOT EXISTS`
- [ ] Tablas de transacciones/eventos tienen `PARTITION BY` y `CLUSTER BY`
- [ ] Todos los outputs tienen campos de auditoría (`load_date`, `record_source`, `creation_user`)
- [ ] Todas las tablas tienen `OPTIONS(description=..., labels=[...])`
- [ ] No hay `DROP TABLE` en ningún archivo SQL
- [ ] No hay `SELECT *` en SPs de producción
- [ ] No hay valores hardcodeados (proyectos, datasets, tablas)
- [ ] Temporales en `${dataset_stage}`, nunca en `${dataset_analytics}`
- [ ] Naming de SPs: `sp_{proceso}` y `sp_dq_{tabla}`
- [ ] Cada RN del spec tiene comentario `-- [RN-ITC-NNN]` en el SP
- [ ] En todo SP con `BEGIN`: todos los `DECLARE` preceden a cualquier `SET` u otro statement
- [ ] Si el SP tiene parámetros `OUT`: los `SET` de inicialización van después de todos los `DECLARE`
- [ ] SPs con filtro por fecha de proceso declaran `p_process_date_ini` y `p_process_date_end` (no un único `p_process_date`)
- [ ] Filtros de fecha en el SP usan `BETWEEN p_process_date_ini AND p_process_date_end`
