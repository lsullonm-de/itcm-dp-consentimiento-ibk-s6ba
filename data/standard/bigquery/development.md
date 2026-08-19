# Skill: Generacion de Queries BigQuery - Estandar ITC Retail

> Este documento es una guia prescriptiva para generar stored procedures y queries de BigQuery
> siguiendo el estandar del equipo de datos de Intercorp Retail.
> Usar como referencia obligatoria al crear nuevos atributos, metricas o pipelines.

---

## Objetivo

Garantizar que todo query nuevo sea consistente con el ecosistema existente de `ba_itc_attr_retail`,
respetando nomenclaturas, patrones de calculo, estructura de SPs y convenciones de columnas.

---

## 1. Reglas de Naming: Stored Procedures

### Formato obligatorio

```
sp_load_[tmp_]<dominio>_<org>_<tipo>_<vertical>[_<N>]
```

### Reglas

| Regla | Detalle |
|---|---|
| Prefijo siempre `sp_load_` | Indica que es un SP de carga |
| Agregar `tmp_` si genera tablas intermedias | Omitir solo en el SP final consolidador |
| Dominio = `ba_` | Business Analytics |
| Organizacion = `itc_` | Intercorp |
| Tipo = `attr_` | Atributos (o el tipo que corresponda) |
| Vertical en snake_case | `retail`, `banca`, `seguros`, etc. |
| Sufijo numerico `_{N}` | Partir logica compleja en SPs secuenciales |

### Ejemplo para una nueva vertical

```sql
-- SP intermedio #1 para atributos de banca:
CREATE OR REPLACE PROCEDURE `proyecto.master_stage.sp_load_tmp_ba_itc_attr_banca_1`(...)

-- SP final consolidador:
CREATE OR REPLACE PROCEDURE `proyecto.master_stage.sp_load_ba_itc_attr_banca`(...)
```

### Configuracion obligatoria

```sql
OPTIONS(strict_mode=false)
```

---

## 2. Reglas de Naming: Tablas

### Prefijos obligatorios segun tipo

| Prefijo | Cuando usar | Ejemplo |
|---|---|---|
| `ba_` | Tabla de salida final (Business Analytics) | `ba_itc_attr_retail` |
| `tmp_` | Tabla temporal/intermedia de calculo | `tmp_variables_6m` |
| `prd_` | Tabla productiva intermedia reutilizable | `prd_attr_ba_retail_variables1` |
| `t_` | Tabla transaccional de hechos (solo lectura) | `t_retail_transaction` |
| `m_` | Tabla maestra/dimension (solo lectura) | `m_product` |
| `c_` | Tabla catalogo/clasificacion (solo lectura) | `c_bin_card` |
| `iden_` | Tabla de identidad (solo lectura) | `iden_itc_party` |
| `aux_` | Tabla auxiliar de soporte | `aux_tarjetas_fape` |

### Sufijos estandar

| Sufijo | Cuando usar |
|---|---|
| `_v1`, `_v2` | Versionado de tablas que evolucionan |
| `_Nm` (1m, 3m, 6m, 9m, 12m) | Tabla calculada para una ventana temporal especifica |
| `_final` | Resultado consolidado de un bloque de procesamiento |
| `_outliers` | Tabla de registros atipicos |
| `_cliente` | Indicar granularidad a nivel cliente |

### Referencia completa a tablas

Siempre usar formato `proyecto.dataset.tabla` con backticks:

```sql
`proyecto.dataset.tabla`
```

### Opciones de tabla segun tipo

| Tipo de tabla | Patron de creacion | Particion | Cluster |
|---|---|---|---|
| Intermedia de detalle | `CREATE OR REPLACE TABLE` | `PARTITION BY transaction_date` | `CLUSTER BY itc_company_id` |
| Intermedia agregada | `CREATE OR REPLACE TABLE` | (ninguna) | (ninguno) |
| Final definitiva | `DELETE WHERE process_date = X` + `INSERT INTO` | `PARTITION BY codmes` | (opcional) |

---

## 3. Reglas de Naming: Datasets

### Formato: `<capa>_<dominio>`

| Capa | Uso | Ejemplos |
|---|---|---|
| `master_` | Datos maestros y staging del DWH | `master_stage`, `master_product`, `master_party`, `master_transaction`, `master_placement` |
| `bi_` | Business Intelligence y atributos | `bi_attr`, `bi_vuc_insight` |
| `sa_` | Staging area de herramientas ETL | `sa_matillion` |

---

## 4. Reglas de Naming: Parametros y Variables

### 4.1 Parametros del SP

Usar prefijo `v_` como estandar principal:

| Tipo de parametro | Prefijo | Formato | Ejemplo |
|---|---|---|---|
| Fecha de proceso inicio | (sin prefijo) | snake_case | `process_date_ini DATE` |
| Fecha de proceso fin | (sin prefijo) | snake_case | `process_date_end DATE` |
| Proyecto GCP | `v_proyecto` | `v_proyecto[_sufijo]` | `v_proyecto_destino STRING` |
| Dataset | `v_master_*` o `v_bi_*` o `v_sa_*` | `v_<capa>_<dominio>` | `v_master_product STRING` |
| Nombre de tabla | `v_table_*` | `v_table_<prefijo_tabla>_<nombre>` | `v_table_m_product STRING` |

#### Parámetros de fecha — `process_date_ini` y `process_date_end` (obligatorio)

Todo SP que procese datos por fecha de proceso debe declarar **dos parámetros** de fecha: inicio y fin.
Esto permite procesar un rango de fechas o una fecha única sin cambiar la firma del SP.

```sql
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_{nombre}` (
  IN p_process_date_ini  DATE,   -- fecha inicio del rango a procesar
  IN p_process_date_end  DATE,   -- fecha fin del rango (= ini si es fecha única)
  IN p_project_analytics STRING,
  -- ... resto de parámetros
)
```

**Regla de uso:**
- **Fecha única:** pasar el mismo valor en ambos parámetros. El caller (workflow) los asigna así:
  `process_date_ini = process_date_end = process_date`
- **Rango de fechas:** pasar fechas distintas para procesar varios días en una sola ejecución
- **Nunca usar** un único parámetro `process_date` en SPs nuevos — impide el procesamiento por rango

**Filtro estándar en el SP:**

```sql
-- En WHERE de consultas a tablas fuente:
WHERE process_date BETWEEN p_process_date_ini AND p_process_date_end

-- O equivalente:
WHERE process_date >= p_process_date_ini
  AND process_date <= p_process_date_end
```

**CALL desde el workflow** (con `DECLARE` para OUT params de monitoreo):

```sql
DECLARE v_read INT64 DEFAULT 0;
DECLARE v_write INT64 DEFAULT 0;
CALL `${project_operation}.${dataset_sp}.sp_{nombre}`(
  DATE '${process_date_ini}',
  DATE '${process_date_end}',
  '${project_analytics}',
  -- ... resto de args
  v_read,
  v_write
);
SELECT v_read AS execution_data_read, v_write AS execution_data_write
```

> **Compatibilidad hacia atrás:** los SPs legacy con `process_date` único no se migran por defecto.
> Al migrar o crear un SP nuevo, usar siempre el par `process_date_ini` / `process_date_end`.

#### Sub-prefijos de `v_table_*`

El prefijo de la tabla fuente se conserva dentro del nombre del parametro:

```
v_table_m_product       -> tabla master (m_product)
v_table_t_payment       -> tabla transaccional (t_payment)
v_table_c_bin_card      -> tabla catalogo (c_bin_card)
v_table_tee_trn_retail  -> tabla ETL (tee_trn_retail)
v_table_iden_itc_party  -> tabla identidad (iden_itc_party)
```

### 4.2 Variables locales (DECLARE)

| Tipo | Prefijo | Tipo de dato | Ejemplo |
|---|---|---|---|
| Ruta completa a tabla | `v_input_` | STRING | `v_input_t_retail_transaction` |
| SQL dinamico | `v_sql` | STRING | `v_sql` |
| Fecha inicio/fin | `v_start_date`, `v_end_date` | DATE | `v_end_date` |
| Intervalo como fecha | `v_interval_date_{N}M_g` | DATE | `v_interval_date_6M_g` |
| Intervalo como entero | `v_interval_date_{N}M` | INT64 | `v_interval_date_6M` |
| Referencia a tabla tmp | `v_tmp_` | STRING | `v_tmp_ba_itc_attr_retail_outliers` |

### Regla del sufijo `_g`

- **`_g`** = variable de tipo `DATE` (fecha calendario)
- **sin `_g`** = variable de tipo `INT64` (formato `YYYYMMDD`)

```sql
DECLARE v_interval_date_6M_g DATE;  -- 2024-07-01
DECLARE v_interval_date_6M INT64;   -- 20240701

SET v_interval_date_6M_g = DATE_SUB(DATE_TRUNC(start_date, MONTH), INTERVAL 6 MONTH);
SET v_interval_date_6M = CAST(FORMAT_DATE('%Y%m%d', v_interval_date_6M_g) AS INT64);
```

---

## 5. Reglas de Naming: Columnas

### 5.1 Formula obligatoria para columnas calculadas

```
{empresa}_{metrica}_{dimension}_{ventana}
```

Cada segmento se separa por `_` y todo en **lowercase snake_case**.

### 5.2 Segmento 1: Prefijo de empresa

| Prefijo | itc_company_id | Empresa |
|---|---|---|
| `spsa_` | `010` | Supermercados Peruanos (Plaza Vea, Vivanda, Mass, Makro) |
| `pro_` | `024` | Promart |
| `oe_` | `011` | Oechsle |
| `far_` | `025`, `048` | InkaFarma + MiFarma (agrupadas) |
| (vacio) | Todos | Intercorp Retail consolidado |

> Para nuevas empresas: usar abreviatura de 2-4 letras del nombre comercial.

### 5.3 Segmento 2: Prefijo de metrica

| Prefijo | Significado | Funcion SQL | Tipo resultado |
|---|---|---|---|
| `mtoprom_` | Monto promedio | `SAFE_DIVIDE(SUM(), COUNT())` o `SUM()/N` | NUMERIC |
| `mtomax_` | Monto maximo | `MAX()` | NUMERIC |
| `mtomin_` | Monto minimo | `MIN()` | NUMERIC |
| `mto_` | Monto total acumulado | `SUM()` | NUMERIC |
| `numtrx_` | Numero de transacciones distintas | `COUNT(DISTINCT ticket)` | INTEGER |
| `numdias_` | Numero de dias distintos con compra | `COUNT(DISTINCT date)` | INTEGER |
| `frecuencia_` | Frecuencia de compra | Formula derivada | NUMERIC |
| `recencia` | Dias desde la ultima compra | `DATE_DIFF()` | NUMERIC |
| `ticketprom_` | Ticket promedio | `SAFE_DIVIDE(monto, trx)` | NUMERIC |
| `porc_` | Porcentaje | `SAFE_DIVIDE() * 100` | NUMERIC |
| `flag_` | Indicador binario | `CASE WHEN ... THEN 1 ELSE 0` | INTEGER (0/1) |
| `rubrofrec_` | Rubro mas frecuente | Ranking | STRING |
| `seg_canal_` | Segmento de canal | Clasificacion | STRING |
| `cant_total_trx_` | Cantidad total transacciones | `SUM()` | INTEGER |

> Para nuevas metricas: elegir el prefijo mas cercano de la tabla o crear uno nuevo
> documentando su significado. Abreviar consistentemente (3-6 caracteres).

### 5.4 Segmento 3: Dimension (opcional)

La dimension describe el recorte de producto, canal o cualquier filtro aplicado:

```
{empresa}_{metrica}_{dimension}_{ventana}
```

Ejemplos de dimensiones:

| Tipo de dimension | Valores | Ejemplo completo |
|---|---|---|
| Canal | `presencial`, `digital` | `spsa_numtrx_presencial_1m` |
| Rubro/categoria | `carnes`, `electro`, `belleza` | `far_mto_medicamento_6m` |
| Medio de pago | `efectivo`, `debito`, `credito`, `toh`, `ibk`, `bbva` | `pro_porc_efectivo_3m` |
| Gama de producto | `gama_alta`, `gama_media`, `gama_baja` | `oe_mtomax_ropa_gama_alta_1m` |
| Flag | `alimento_saludable`, `bienestar` | `spsa_mto_alimento_saludable_6m` |

> Usar el nombre exacto del rubro/categoria en snake_case tal como aparece en las tablas fuente.

### 5.5 Segmento 4: Ventana temporal (sufijo)

| Sufijo | Significado | Cuando usar |
|---|---|---|
| `_1m` | Ultimo 1 mes | Estandar para todas las metricas |
| `_3m` | Ultimos 3 meses | Estandar |
| `_6m` | Ultimos 6 meses | Estandar |
| `_9m` | Ultimos 9 meses | Estandar |
| `_12m` | Ultimos 12 meses | Estandar |
| (sin sufijo) | Punto en el tiempo, no ventana | Solo para `recencia`, `fecha_ultimacompra` |

> Usar siempre `_Nm`. Las variantes `_Nmes`, `_uNm` y `_ult_Nm` son legacy y no deben usarse en queries nuevos.

### 5.6 Columnas de control (obligatorias en tabla final)

Toda tabla `ba_*` de salida debe incluir estas columnas:

```sql
process_date        -- DATE: fecha de procesamiento
id_intercorp        -- STRING: identificador unico del cliente
record_source       -- STRING: fuente del registro (ej: 'Retail')
load_date           -- DATETIME: CURRENT_DATETIME('America/Lima')
```

---

## 6. Patrones de Columnas Complejas

### 6.1 Rankings de rubro

```
{empresa}_rubro_top{N}_{criterio}[_name]_{ventana}
```

| Parte | Valores posibles |
|---|---|
| `top{N}` | `top1`, `top2`, `top3` |
| `{criterio}` | `frec` (frecuencia), `monto` |
| `_name` | Agregar si la columna es el nombre del rubro (STRING). Omitir si es el valor numerico |

```
farma_rubro_top1_frec_name_1m  -> STRING: nombre del rubro #1 por frecuencia
farma_rubro_top1_frec_1m       -> INTEGER: valor de frecuencia del rubro #1
farma_rubro_top1_monto_name_1m -> STRING: nombre del rubro #1 por monto
farma_rubro_top1_monto_1m      -> NUMERIC: valor de monto del rubro #1
```

### 6.2 Gamas de producto

```
{empresa}_{metrica}_{tipo_producto}_gama_{nivel}_{ventana}
```

Tipos de producto con gama: `electro`, `ropa`, `jugueteria`, `alimentos`
Niveles: `alta`, `media`, `baja`

```
spsa_mtomax_electro_gama_alta_6m
oe_mto_ropa_gama_baja_3m
pro_mtoprom_alimentos_gama_media_12m
```

### 6.3 Comportamiento IBK

```
comportamiento_{dimension}_{estadistico}_{tipo_trx}_itc_u{ventana}
```

| Segmento | Valores |
|---|---|
| Dimension | `tarjeta`, `efectivo`, `trx`, `cliente`, `compra` |
| Estadistico | `prm`, `max`, `min`, `frec`, `flg`, `prom` |
| Tipo trx | `trxtdefe`, `trxefe`, `trxtd`, `trxtc`, `trxtotal`, `trxpres`, `trxonl`, `trxprom` |

### 6.4 Comportamiento de compra

```
comportamiento_compra_{dimension_mas_criterio}_{ventana}
```

Dimensiones validas: `parte_dia_mas_frec`, `nombre_dia_mas_frec`, `tipo_dia_mas_frec`,
`tipo_distrito_mas_frec`, `entidad_banco_mas_frec`, `patron_mas_frec`

---

## 7. Templates de Calculo

### 7.1 Monto total por empresa y ventana

```sql
SUM(CASE WHEN itc_company_id = '{cod_empresa}'
         AND transaction_date >= "'''||v_interval_date_{N}M_g||'''"
    THEN CAST(product_item_gross_amount AS NUMERIC)
    ELSE 0 END) AS {empresa}_mto_{dimension}_{ventana}
```

### 7.2 Monto promedio (SAFE_DIVIDE)

```sql
SAFE_DIVIDE(
  SUM(CASE WHEN {filtros} THEN amount ELSE 0 END),
  COUNT(DISTINCT CASE WHEN {filtros} THEN transaction_ticket ELSE NULL END)
) AS {empresa}_mtoprom_{dimension}_{ventana}
```

### 7.3 Promedio mensual (division por N meses)

```sql
SUM(CASE WHEN {filtros} THEN amount ELSE 0 END) / {N}
  AS {empresa}_mtoprom_{dimension}_{ventana}
```

### 7.4 Numero de transacciones distintas

```sql
COUNT(DISTINCT IF(
  itc_company_id = '{cod}' AND transaction_date >= "'''||v_interval_date_{N}M_g||'''",
  transaction_ticket, NULL
)) AS {empresa}_numtrx_{dimension}_{ventana}
```

### 7.5 Porcentaje

```sql
SAFE_DIVIDE(
  IF(a.{empresa}_montoprom_{ventana} > 0, b.{empresa}_mtoprom_{medio_pago}_{ventana}, 0),
  b.{empresa}_mtoprom_tot_{ventana}
) * 100 AS {empresa}_porc_{medio_pago}_{ventana}
```

### 7.6 Flag binario

```sql
CASE WHEN {condicion} THEN 1 ELSE 0 END AS flag_{nombre_flag}

-- Defaults para NULLs:
COALESCE(flag_{nombre}, 0) AS flag_{nombre}
```

### 7.7 Recencia

```sql
DATE_DIFF(v_end_date, MAX(CASE WHEN itc_company_id = '{cod}'
  THEN transaction_date ELSE NULL END), DAY) AS {empresa}_recencia
```

### 7.8 Ranking de rubro (top N)

```sql
FIRST_VALUE(rubro) OVER (
  PARTITION BY id
  ORDER BY frecuencia DESC
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) AS {empresa}_rubro_top1_frec_name_{ventana}
```

### 7.9 Deduplicacion

```sql
SELECT * EXCEPT(rn) FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY process_date, id ORDER BY process_date DESC) rn
  FROM tabla
)
WHERE rn = 1
```

---

## 8. Estructura de un Stored Procedure Nuevo

### Template completo

```sql
CREATE OR REPLACE PROCEDURE `{proyecto}.master_stage.sp_load_[tmp_]ba_itc_attr_{vertical}[_{N}]`(
  start_date DATE
  , v_proyecto STRING
  , v_proyecto_destino STRING
  , v_master_stage STRING
  , v_master_product STRING
  , v_master_party STRING
  , v_master_transaction STRING
  -- ... parametros necesarios segun tablas fuente
)
OPTIONS(strict_mode=false)
BEGIN

  -- ============================================================
  -- 1. DECLARACION DE VARIABLES
  -- ============================================================
  DECLARE v_sql STRING;
  DECLARE v_start_date DATE;
  DECLARE v_end_date DATE;
  DECLARE v_interval_date_1M_g DATE;
  DECLARE v_interval_date_1M INT64;
  -- ... declarar todos los intervalos necesarios (1M a 12M)

  -- ============================================================
  -- 2. CALCULO DE FECHAS
  -- ============================================================
  SET v_start_date = DATE_SUB(DATE_TRUNC(start_date, MONTH), INTERVAL 12 MONTH);
  SET v_end_date = LAST_DAY(DATE_SUB(DATE_TRUNC(start_date, MONTH), INTERVAL 1 MONTH));
  SET v_interval_date_1M_g = DATE_SUB(DATE_TRUNC(start_date, MONTH), INTERVAL 1 MONTH);
  SET v_interval_date_1M = CAST(FORMAT_DATE('%Y%m%d', v_interval_date_1M_g) AS INT64);
  -- ... repetir para 2M, 3M, ..., 12M

  -- ============================================================
  -- 3. CONSTRUCCION DE RUTAS A TABLAS
  -- ============================================================
  -- SET v_input_tabla = v_proyecto||'.'||v_dataset||'.'||v_table_nombre;

  -- ============================================================
  -- 4. CREACION DE TABLAS INTERMEDIAS (si aplica)
  -- ============================================================
  SET v_sql = '''
    CREATE OR REPLACE TABLE `'''||v_proyecto_destino||'''.'''||v_master_stage||'''.tmp_{nombre}` AS
    SELECT ...
    FROM ...
  ''';
  EXECUTE IMMEDIATE v_sql;

  -- ============================================================
  -- 5. CARGA EN TABLA FINAL (solo en SP consolidador)
  -- ============================================================
  -- Opcion A: incremental por fecha
  SET v_sql = '''
    DELETE FROM `'''||v_proyecto_destino||'''.'''||v_bi_attr||'''.ba_itc_attr_{vertical}`
    WHERE process_date = "'''||v_end_date||'''"
  ''';
  EXECUTE IMMEDIATE v_sql;

  SET v_sql = '''
    INSERT INTO `'''||v_proyecto_destino||'''.'''||v_bi_attr||'''.ba_itc_attr_{vertical}`
    SELECT
      process_date,
      id AS id_intercorp,
      "NombreVertical" AS record_source,
      CURRENT_DATETIME("America/Lima") AS load_date,
      -- ... columnas calculadas
    FROM ...
  ''';
  EXECUTE IMMEDIATE v_sql;

END;
```

### Orden de secciones dentro del SP

1. **DECLARE** de todas las variables
2. **SET** de fechas e intervalos
3. **SET** de rutas completas a tablas (`v_input_*`)
4. **CREATE TABLE** temporales via `EXECUTE IMMEDIATE`
5. **DELETE + INSERT** en tabla final (solo SP consolidador)

---

## 9. Reglas de SQL Dinamico

### Siempre usar EXECUTE IMMEDIATE

```sql
SET v_sql = '''
  <sentencia SQL>
''';
EXECUTE IMMEDIATE v_sql;
```

### Inyeccion de variables

```sql
-- Proyecto + dataset + tabla (todo parametrizado):
`'''||v_proyecto||'''.'''||v_master_product||'''.'''||v_table_m_product||'''`

-- Proyecto + dataset parametrizado, tabla fija:
`'''||v_proyecto_destino||'''.'''||v_master_stage||'''.tmp_nombre_fijo`

-- Fecha en filtro WHERE:
WHERE transaction_date >= "'''||v_interval_date_6M_g||'''"
WHERE transaction_date_number >= '''||v_interval_date_6M||'''
```

---

## 10. Aliases de Tabla

| Situacion | Convencion | Ejemplo |
|---|---|---|
| JOINs con pocas tablas | Letras secuenciales `a`, `b`, `c` | `FROM tabla a LEFT JOIN tabla2 b` |
| Tablas fuente conocidas | Abreviatura descriptiva | `trx`, `mp`, `fp`, `cm` |
| JOINs de ventanas temporales | `m{N}` donde N = meses | `m1`, `m3`, `m6`, `m9`, `m12` |
| CTEs numeradas | `TMP{N}` en mayusculas | `TMP1`, `TMP2` |
| JOINs masivos (>5 tablas) | Sin alias, usar `USING (id)` | `LEFT JOIN (...) USING (id)` |

---

## 11. Diccionario de Empresas y Codigos

### Empresas Intercorp Retail

| itc_company_id | Empresa | Prefijo columna | Marcas |
|---|---|---|---|
| `010` | Supermercados Peruanos | `spsa_` | Plaza Vea, Vivanda, Mass, Makro |
| `011` | Tiendas Peruanas | `oe_` | Oechsle |
| `024` | Promart | `pro_` | Promart |
| `025` | InkaFarma | `far_` | InkaFarma |
| `048` | MiFarma | `far_` | MiFarma |

> InkaFarma (025) y MiFarma (048) se agrupan bajo el prefijo `far_` en las tablas de salida.

### Medios de pago

| Codigo | Medio | Abreviatura en columna |
|---|---|---|
| -- | Efectivo | `efectivo` / `efe` |
| -- | Debito | `debito` / `deb` |
| -- | Credito | `credito` / `cre` |
| -- | Tarjeta OH | `toh` |
| -- | BBVA | `bbva` |
| -- | Interbank | `ibk` |
| -- | Scotiabank | `sco` |
| -- | Cencosud | `csc` / `cen` |
| -- | Ripley | `rip` |
| -- | CMR Falabella | `cmr` |

---

## 12. Categorias de Producto (Rubros) por Empresa

### SPSA (010)
bazar, bebidas, bebidas_alcoholicas, carnes, comestibles, comestibles_especiales, comidas_preparadas, cuidado_personal_limpieza, electro, fiambres_quesos, frutas_verduras, hogar, lacteos_congelados, miscelaneos, panaderia_pasteleria, pescados_mariscos, textil, otros

### Promart (024)
acabados, ferreteria, hogar_deco, jardin_temp, obra_gruesa, otros

### Oechsle (011)
autoliquidables, belleza, calzado, decohogar, deportes, electrohogar, hombre, infantil, marcas_boutique, mujer, otros, ropa

### Farmacias (025 + 048)
adulto, bazar, bebes_ninos, belleza, bienestar, cuidado_infantil, cuidado_personal, dermacosmetica, dispositivo_medico, generico, marca, medicamento, mimarket, nutricion_adultos, otros, wellnes, antibiotico

---

## 13. Tipos de Dato por Prefijo de Columna

| Prefijo | Tipo BigQuery | Usar CAST como |
|---|---|---|
| `mto*_`, `montototal_`, `ticketprom_`, `porc_` | NUMERIC | `CAST(x AS NUMERIC)` |
| `numtrx_`, `numdias_`, `cant_*`, `caja_*` | INTEGER | `CAST(x AS INTEGER)` |
| `flag_` | INTEGER | `CAST(x AS INTEGER)` -- solo 0 o 1 |
| `rubrofrec_`, `rubro_prom_`, `seg_canal_`, `descestab_*` | STRING | `CAST(x AS STRING)` |
| `fecha_*`, `process_date` | DATE | (mantener DATE) |
| `load_date` | DATETIME | `CURRENT_DATETIME('America/Lima')` |
| `id`, `id_intercorp` | STRING | (mantener STRING) |

---

## 14. Checklist para Nuevos Queries

Antes de enviar un query nuevo a revision, verificar:

### Nomenclatura
- [ ] Nombre del SP sigue el formato `sp_load_[tmp_]ba_itc_attr_{vertical}[_{N}]`
- [ ] Tablas temporales tienen prefijo `tmp_`
- [ ] Tabla final tiene prefijo `ba_`
- [ ] Columnas siguen el formato `{empresa}_{metrica}_{dimension}_{ventana}`
- [ ] Ventanas temporales usan sufijo `_Nm` (no `_Nmes`, `_uNm` ni `_ult_Nm`)
- [ ] Prefijos de empresa son los estandar: `spsa_`, `pro_`, `oe_`, `far_`
- [ ] Variables usan prefijo `v_` (no `var_`)
- [ ] Variables de intervalo usan sufijo `_g` para DATE y sin sufijo para INT64

### Estructura
- [ ] SP usa `OPTIONS(strict_mode=false)`
- [ ] Todo SQL se ejecuta via `EXECUTE IMMEDIATE`
- [ ] Tablas referenciadas con backticks y ruta completa parametrizada
- [ ] Variables de fecha calculadas con `DATE_SUB` + `DATE_TRUNC` + `FORMAT_DATE`
- [ ] Tabla final incluye: `process_date`, `id_intercorp`, `record_source`, `load_date`
- [ ] SP con lógica de fecha declara `process_date_ini` y `process_date_end` (nunca un único `process_date`)
- [ ] Filtros de fecha en el SP usan `BETWEEN p_process_date_ini AND p_process_date_end`

### Calculos
- [ ] Promedios usan `SAFE_DIVIDE` (nunca division directa con `/` sin proteccion)
- [ ] Flags usan `COALESCE(flag, 0)` para defaults
- [ ] Deduplicacion via `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) rn` + `WHERE rn = 1`
- [ ] Rankings usan `FIRST_VALUE` o `ROW_NUMBER` con ventana OVER
- [ ] Montos por empresa usan `SUM(CASE WHEN itc_company_id = '{cod}' THEN ... ELSE 0 END)`
- [ ] Porcentajes usan `SAFE_DIVIDE() * 100`

### Calidad
- [ ] Sin divisiones por cero sin proteccion
- [ ] NULLs manejados con `COALESCE` donde corresponda
- [ ] Columnas con `CAST` explicito en la tabla de salida final
- [ ] Comentarios separadores entre secciones logicas

### Tablas maestras
- [ ] Tablas `m_*` usan detección incremental (hash diff) + INSERT de nuevos y modificados — **nunca TRUNCATE ni UPDATE directo**
- [ ] La tabla maestra queda con datos en todo momento durante la carga (sin ventana de vacío)

---

## 15. Ejemplo: Crear un Nuevo Atributo

**Escenario**: agregar el atributo "monto promedio en canal digital" para SPSA, en ventanas de 1m, 3m y 6m.

### Paso 1: Definir nombres de columna

```
spsa_mtoprom_digital_1m   -- NUMERIC
spsa_mtoprom_digital_3m   -- NUMERIC
spsa_mtoprom_digital_6m   -- NUMERIC
```

### Paso 2: Escribir el calculo

```sql
SAFE_DIVIDE(
  SUM(CASE WHEN itc_company_id = '010'
           AND channel = 'ONLINE'
           AND transaction_date >= "'''||v_interval_date_1M_g||'''"
      THEN CAST(product_item_gross_amount AS NUMERIC) ELSE 0 END),
  COUNT(DISTINCT CASE WHEN itc_company_id = '010'
                      AND channel = 'ONLINE'
                      AND transaction_date >= "'''||v_interval_date_1M_g||'''"
                 THEN transaction_ticket ELSE NULL END)
) AS spsa_mtoprom_digital_1m
```

### Paso 3: Replicar para otras ventanas

Cambiar `v_interval_date_1M_g` por `3M_g` y `6M_g`, y el sufijo `_1m` por `_3m` y `_6m`.

### Paso 4: Agregar a la tabla de salida con CAST

```sql
CAST(spsa_mtoprom_digital_1m AS NUMERIC) AS spsa_mtoprom_digital_1m,
CAST(spsa_mtoprom_digital_3m AS NUMERIC) AS spsa_mtoprom_digital_3m,
CAST(spsa_mtoprom_digital_6m AS NUMERIC) AS spsa_mtoprom_digital_6m
```

---

## 16. Patrón de Carga para Tablas Maestras (`m_*`)

### Regla — nunca TRUNCATE ni UPDATE directo en tablas maestras

Las tablas con prefijo `m_*` son tablas maestras de alta disponibilidad consumidas por otros procesos.
Un TRUNCATE o una carga full deja la tabla **vacía por un lapso de tiempo**, lo que puede causar
resultados incorrectos en procesos que la consultan concurrentemente.

| Estrategia | Efecto en disponibilidad | Usar en |
|---|---|---|
| `TRUNCATE` + `INSERT` | ❌ Tabla vacía durante la carga | Solo tablas `tmp_*` o `ba_*` de carga completa |
| `UPDATE` directo | ❌ Lock parcial, riesgo de inconsistencia | Nunca en producción para maestros |
| `DELETE` by partition + `INSERT` | ✅ Solo afecta la partición del día | Tablas `ba_*` con partición por fecha |
| **Detección incremental + `INSERT` de delta** | ✅ No toca registros existentes | **Tablas `m_*` — patrón obligatorio** |

### Patrón obligatorio para `m_*` — detección incremental con hash diferencial

El patrón consiste en:
1. Calcular un **hash SHA256** de los campos clave del registro en la fuente
2. Hacer **LEFT JOIN** con la tabla maestra existente para detectar:
   - `b_pk IS NULL` → registro **nuevo** (no existe en el maestro)
   - `b_pk IS NOT NULL AND hkdiff_new <> hk_diff_hist` → registro **modificado** (hash cambió)
3. Insertar **solo** los nuevos y los modificados — los registros sin cambio no se tocan

```sql
-- STEP 1: calcular hash diferencial en la fuente
CREATE OR REPLACE TABLE `{proyecto}.{dataset_stage}.tmp_{tabla}_base` AS
SELECT
  *,
  SHA256(
    IFNULL(campo_clave_1, '') ||
    IFNULL(campo_clave_2, '') ||
    IFNULL(campo_clave_3, '')
    -- ... todos los campos que determinan si el registro cambió
  ) AS hkdiff_new
FROM `{proyecto}.{dataset_fuente}.{tabla_fuente}`
WHERE {filtros_basicos};

-- STEP 2: LEFT JOIN con el maestro para detectar nuevos y modificados
CREATE OR REPLACE TABLE `{proyecto}.{dataset_stage}.tmp_{tabla}_joined` AS
SELECT
  a.*,
  b.{pk} AS b_pk,             -- NULL si el registro no existe en el maestro
  b.hk_diff AS b_hk_diff_hist,
  CASE
    WHEN b.{pk} IS NULL       THEN NULL   -- nuevo
    WHEN a.hkdiff_new <> b.hk_diff THEN 1  -- modificado
    ELSE 0                                  -- sin cambio
  END AS flag_modified
FROM `{proyecto}.{dataset_stage}.tmp_{tabla}_base` a
LEFT JOIN `{proyecto}.{dataset_maestro}.{tabla_maestra}` b
  ON a.{pk} = b.{pk}
  -- agregar claves adicionales si el PK es compuesto
;

-- Capturar métricas de monitoreo (si aplica)
EXECUTE IMMEDIATE v_sql;                        -- último INSERT
SET o_execution_data_write = @@row_count;
EXECUTE IMMEDIATE CONCAT('SELECT COUNT(1) FROM `', v_path_tmp_joined, '`')
  INTO o_execution_data_read;

-- STEP 3: INSERT de NUEVOS (b_pk IS NULL)
INSERT INTO `{proyecto}.{dataset_maestro}.{tabla_maestra}` (...)
SELECT ...
FROM `{proyecto}.{dataset_stage}.tmp_{tabla}_joined`
WHERE b_pk IS NULL;               -- solo registros nuevos

-- STEP 4: INSERT de MODIFICADOS (existentes con hash diferente)
INSERT INTO `{proyecto}.{dataset_maestro}.{tabla_maestra}` (...)
SELECT ...
FROM `{proyecto}.{dataset_stage}.tmp_{tabla}_joined`
WHERE b_pk IS NOT NULL            -- registro existente
  AND flag_modified = 1;          -- con cambios en hash
```

> **Por qué INSERT en lugar de UPDATE/MERGE para maestros:**
> Las tablas `m_*` suelen ser de tipo APPEND (históricas con `start_date`/`end_date`/`flag_active`).
> Insertar el registro modificado como fila nueva preserva el historial de cambios y
> no requiere locks que puedan afectar consultas concurrentes.
>
> Si la tabla maestra es de tipo **last-version-wins** (sin historial), usar
> `MERGE ... WHEN MATCHED THEN UPDATE ... WHEN NOT MATCHED THEN INSERT ...`
> en lugar de los dos INSERTs separados.

### Cuándo usar cada variante

| Tipo de tabla maestra | Variante recomendada |
|---|---|
| Con historial (`start_date`, `end_date`, `flag_active`) | Detección incremental + 2 INSERTs separados |
| Sin historial (última versión siempre vigente) | `MERGE ... WHEN MATCHED ... WHEN NOT MATCHED ...` |
| Tabla de atributos `ba_*` con partición diaria | `DELETE` by `process_date` + `INSERT` |
| Tabla temporal `tmp_*` | `CREATE OR REPLACE TABLE` (sin restricción) |

---

## 17. Optimización y Anti-patrones de Rendimiento

> **Fuente externa:** `bq-query-optimization` skill
> **Repositorio:** `https://github.com/FunnelEnvy/agents_webinar_demos`
> **Instalación local:** `npx skills add https://github.com/FunnelEnvy/agents_webinar_demos --skill bq-query-optimization`
> **Para refrescar:** re-instalar el skill, leer el SKILL.md y actualizar esta sección con reglas nuevas o modificadas.

### 16.1 — CTEs vs tablas temporales

**Anti-patrón:** las CTEs se re-ejecutan cada vez que se referencian en la query. Si una CTE es costosa y se usa más de una vez, está corriendo múltiples veces.

```sql
-- ❌ EVITAR: cte_base se ejecuta 3 veces
WITH cte_base AS (SELECT ... FROM tabla_grande)
SELECT * FROM cte_base t1 JOIN cte_base t2 ... JOIN cte_base t3 ...

-- ✅ CORRECTO: materializar en tabla temporal
CREATE OR REPLACE TEMP TABLE tmp_base AS SELECT ... FROM tabla_grande;
SELECT * FROM tmp_base t1 JOIN tmp_base t2 ... JOIN tmp_base t3 ...
```

**Regla:** usar CTEs solo cuando se referencian **una sola vez**. Para múltiples referencias, materializar en `CREATE OR REPLACE TABLE` con `EXECUTE IMMEDIATE`.

### 16.2 — NOT IN con NULLs

**Anti-patrón crítico:** `NOT IN` con una subquery que puede devolver NULLs retorna 0 filas — resultado vacío silencioso.

```sql
-- ❌ PELIGROSO: si la subquery tiene NULLs, retorna vacío sin error
SELECT * FROM tabla WHERE id NOT IN (SELECT id FROM otra_tabla)

-- ✅ CORRECTO: usar NOT EXISTS o LEFT JOIN
SELECT a.* FROM tabla a
WHERE NOT EXISTS (SELECT 1 FROM otra_tabla b WHERE b.id = a.id)

-- ✅ ALTERNATIVA: LEFT JOIN con NULL check
SELECT a.* FROM tabla a
LEFT JOIN otra_tabla b ON a.id = b.id
WHERE b.id IS NULL
```

### 16.3 — Filtros de partición: columna raw vs funciones

**Regla crítica:** el filtro de partición debe aplicarse sobre la **columna raw**, no sobre una expresión de función. Las funciones impiden el partition pruning y obligan a escanear toda la tabla.

```sql
-- ❌ ESCANEA TODA LA TABLA — DATE() sobre columna TIMESTAMP impide pruning
WHERE DATE(transaction_timestamp) >= '2024-01-01'
WHERE CAST(transaction_date AS DATE) >= '2024-01-01'

-- ✅ CORRECTO — filtro sobre columna de partición directamente
WHERE transaction_date >= '2024-01-01'
WHERE transaction_date BETWEEN v_start_date AND v_end_date
```

Aplicar esta regla especialmente en tablas `t_*` y `m_*` de gran volumen que tienen partición por fecha.

### 16.4 — SAFE_CAST para conversiones null-safe

Preferir `SAFE_CAST` sobre `CAST` cuando el valor puede ser inválido o nulo. `CAST` falla con error; `SAFE_CAST` retorna NULL.

```sql
-- ❌ Puede fallar con error en producción si hay valores no convertibles
CAST(campo_string AS NUMERIC)

-- ✅ Retorna NULL si el valor no es convertible — más seguro en pipelines
SAFE_CAST(campo_string AS NUMERIC)
SAFE_DIVIDE(numerador, denominador)  -- ya lo usamos; mismo principio
```

### 16.5 — Checklist de optimización

Agregar al checklist de la sección 14:

**Rendimiento y costo:**
- [ ] CTEs referenciadas más de una vez → reemplazar por tabla temporal materializada
- [ ] No usar `NOT IN` con subqueries → usar `NOT EXISTS` o `LEFT JOIN ... IS NULL`
- [ ] Filtros de partición sobre columna raw (no `DATE(ts)`, no `CAST(...)`)
- [ ] `SAFE_CAST` en lugar de `CAST` para campos con posibles valores inválidos
- [ ] `SELECT` con columnas explícitas (nunca `SELECT *` en queries de producción)

---

## 18. Ejemplo: Crear un Nuevo Flag

**Escenario**: agregar flag de "cliente que compro productos organicos en el ultimo mes".

### Nombre de columna

```
flag_compra_organico_1m   -- INTEGER (0/1)
```

### Calculo

```sql
CASE WHEN COUNT(DISTINCT CASE
  WHEN product_category = 'ORGANICO'
       AND transaction_date >= "'''||v_interval_date_1M_g||'''"
  THEN transaction_ticket ELSE NULL END) > 0
THEN 1 ELSE 0 END AS flag_compra_organico_1m
```

### En la salida final

```sql
COALESCE(flag_compra_organico_1m, 0) AS flag_compra_organico_1m
```
