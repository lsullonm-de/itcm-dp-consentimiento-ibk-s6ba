# Skill: Customer Attributes Developer

> **Rol:** Desarrollador de Atributos de Cliente — ITC Data Platform
> **Activado por:** creación o modificación de atributos de cliente en el repositorio `itcm-dp-vuci-customer`
>
> **Estándares de referencia:**
> - `@.claude/data/standard/bigquery/development.md` — convenciones SQL y naming BigQuery
> - `@.claude/data/standard/bigquery/nomenclatura_ba_itc_attr_retail.md` — prefijos empresa, métrica, ventana
> - `@.claude/data/standard/bigquery/sql_header_template.sql` — cabeceras DDL y SP
> - `@.claude/data/standard/architecture/data-platform-layers.md` — capas RAW/Master/Business
>
> **Repositorio de trabajo:** `itcm-dp-vuci-customer`
> **Glosario de negocio:** `data/standard/business-glossary/`

---

## 1. Rol y Contexto

Este agente tiene conocimiento profundo del modelo corporativo de datos de cliente de Intercorp. Su responsabilidad es **crear y mantener los atributos de cliente** en el repositorio `itcm-dp-vuci-customer`.

| Capacidad | Descripción |
|---|---|
| **Entender necesidades de información** | Traducir requerimientos de negocio a atributos o columnas concretas |
| **Navegar el modelo corporativo** | Saber qué tabla tiene el dato, cómo hacer JOIN y qué filtros aplicar |
| **Interpretar metadata técnica** | Usar volumetría, campos de partición, perfilamiento, nulos y blancos para escribir queries correctos y eficientes |
| **Desarrollar atributos nuevos** | Crear DDL + SP en el repositorio siguiendo los patrones establecidos |
| **Mantener atributos existentes** | Modificar la lógica de cálculo de atributos ya existentes con mínimo impacto |

---

## 2. Mapa del Modelo de Datos de Cliente

El modelo está en el proyecto BigQuery `intercorp-data-storage-pv`.
Toda la documentación de tablas vive en: `data/standard/business-glossary/`

### Tablas de transacciones (fuentes primarias)

| Tabla | Dataset | Filas aprox. | Partición | Cubre |
|---|---|---|---|---|
| `t_retail_transaction` | `master_transaction` | ~4.7B | `transaction_date` | Ventas retail ítem a ítem: SPSA, OE, Promart, Farmacias |
| `t_transaction` | `master_transaction` | ~3.4B | `itc_process_date` | Transacciones POS/ecommerce procesadas por Izipay |
| `t_payment` | `master_transaction` | ~2.83B | `payment_date` | Medios de pago vinculados a `t_retail_transaction` |
| `t_experience_transaction` | `master_transaction` | ~577M | `transaction_date` | Entretenimiento: Cineplanet (013), NGRestaurant (033) |
| `t_ventas_noretail` | `master_transaction` | ~684K | sin partición | Beneficios no-retail de empleados Intercorp |

### Identidad y vinculación de clientes

| Tabla | Dataset | Filas aprox. | Descripción |
|---|---|---|---|
| `iden_itc_party` | `master_party` | ~467M | Vincula `party_id` con documentos de identidad por empresa |

> **Clave de JOIN estándar:** `id` (documento de identidad del cliente).
> Para cruzar entre empresas del grupo usar `iden_itc_party`.

### Catálogos y maestros

| Tabla | Dataset | Descripción |
|---|---|---|
| `c_itc_company` | `master_party` | 83 empresas del Grupo Intercorp con sus códigos |
| `m_product` | `master_product` | ~3.7M productos con jerarquía jq1–jq8 (OE, Promart, Farmacias) |
| `m_place` | `master_placement` | ~20K tiendas propias (Inkafarma, Mifarma) |
| `m_commerce` | `master_placement` | ~2.9M comercios Izipay (MCC, geodata) |
| `c_bin_card` | `master_transaction` | ~22K BINs de tarjetas (banco emisor, marca) |
| `c_clasificacion_marcas_retail_ibk` | `bi_itc_attribute_party` | ~11K clasificación de SKUs retail por tipo/subtipo |
| `c_flags_categorias_retail_ibk` | `bi_itc_attribute_party` | Flags de categorías retail para segmentación |
| `c_productos_escenciales_retail` | `master_product` | ~3.4K SKUs esenciales vs. discrecionales (retail) |
| `c_productos_escenciales_pos` | `master_placement` | 253 segmentos MCC esenciales vs. discrecionales (POS) |
| `c_entidades_financieras` | `bi_ibk_casos_uso` | 66 bancos — normaliza múltiples grafías a nombre canónico |
| `c_gamas_tarjetas_noibk` | `bi_ibk_casos_uso` | 25 registros — clasifica gamas: CLÁSICA, ORO, PLATINUM, SIGNATURE |
| `c_attribute_metadata` | — | Catálogo de todos los atributos existentes — **consultar siempre primero** |

### Tablas de atributos (output del repositorio)

Todas con granularidad **1 fila por `id` (cliente)** y clave de JOIN `id`.

| Tabla | Dataset | Descripción |
|---|---|---|
| `ba_itc_attr_retail` | `bi_itc_attribute_party` | Comportamiento de compra retail: monto, frecuencia, recencia por empresa/rubro/ventana |
| `ba_itc_attr_payment_pos` | `bi_itc_attribute_party` | Comportamiento en POS Izipay: montos, frecuencia, esencialidad, gama |
| `ba_itc_attr_card_consumption` | `bi_itc_attribute_party` | Consumo por tipo de tarjeta: IBK, OH!, otras |
| `ba_itc_attr_digital` | `bi_itc_attribute_party` | Comportamiento digital: canales, apps, sesiones web |
| `ba_itc_attr_demographic` | `bi_itc_attribute_party` | Atributos demográficos: edad, género, NSE, ubicación |
| `ba_itc_attr_corporate` | `bi_itc_attribute_party` | Atributos corporativos / empresa empleadora |
| `ba_itc_attr_entertainment` | `bi_itc_attribute_party` | Entretenimiento: Cineplanet, restaurantes NGR |
| `ba_itc_attr_prediction` | `bi_itc_attribute_party` | Scores de predicción: churn, propensión, CLV |
| `ba_itc_attr_bienestar` | `bi_itc_attribute_party` | Salud clínica del paciente (Farmacias) |
| `ba_itc_attr_insurance` | `bi_itc_attribute_party` | Tenencia de seguros activos |
| `ba_itc_attr_rcc` | `bi_itc_attribute_party` | Deuda y crédito activo |
| `ba_itc_attr_payment` | `bi_itc_attribute_party` | Consumo con tarjeta OH! |
| `ba_itc_attr_purchase_card` | `bi_itc_attribute_party` | Atributos de compra con tarjeta |
| `ba_itc_attr_purchase_intention` | `bi_itc_attribute_party` | Intención de compra activa |
| `ba_itc_attr_purchase_prediction` | `bi_itc_attribute_party` | Predicciones de compra futura |
| `ba_customer_prediction` | `bi_itc_attribute_party` | Predicciones de ciclo de vida: INFANTES, churn, etc. |
| `ba_itc_audience_contact` | `bi_itc_attribute_party` | Datos de contacto para campañas: email, teléfono |

---

## 3. Cómo Interpretar un Requerimiento de Atributo

### Paso 1 — Consultar `c_attribute_metadata`

Antes de construir cualquier atributo, consultar esta tabla. Contiene el catálogo completo de atributos existentes. Si ya existe el dato, usarlo directamente sin recalcular.

### Paso 2 — Mapear el requerimiento a tablas fuente

| Necesidad de información | Tablas principales |
|---|---|
| Gasto del cliente en retail | `t_retail_transaction`, `ba_itc_attr_retail` |
| Frecuencia de visita a tienda | `t_retail_transaction` + `m_place` |
| Categoría de producto comprado | `t_retail_transaction` + `m_product` (jerarquía jq1–jq8) |
| Medio de pago / banco / tarjeta | `t_payment` + `c_bin_card` + `c_entidades_financieras` |
| Gama de tarjeta (CLÁSICA, PLATINUM…) | `ba_itc_attr_card_consumption`, `c_gamas_tarjetas_noibk` |
| Compras en entretenimiento | `t_experience_transaction` (cod_empresa='013' Cine, '033' NGR) |
| Categorías saludables / esenciales | `c_flags_categorias_retail_ibk`, `c_productos_escenciales_retail` |
| Atributos clínicos / salud | `ba_itc_attr_bienestar`, `m_product` (rubros de medicamentos) |
| Seguros activos | `ba_itc_attr_insurance` |
| Deuda / crédito | `ba_itc_attr_rcc` |
| Canal digital / app / delivery | `ba_itc_attr_digital` |
| Ciclo de vida / predicciones | `ba_itc_attr_prediction`, `ba_customer_prediction` |
| Empresa del grupo Intercorp | `iden_itc_party` + `c_itc_company` |
| Ubicación / geografía | `ba_itc_attr_demographic`, `m_place` |
| Datos de contacto | `ba_itc_audience_contact` |

### Paso 3 — Leer el glosario de cada tabla antes de escribir el query

Antes de usar una tabla, leer su `.md` en `data/standard/business-glossary/` para conocer:
- **Campo de JOIN** (clave de cliente: generalmente `id`)
- **Cómo filtrar por empresa** (`cod_empresa`, `itc_company_id`, etc.)
- **Campos con nulos o blancos** frecuentes
- **Partición** (necesaria para evitar full scan)
- **Volumetría** (para decidir si necesita CTE intermedia o tabla temp)

---

## 4. Estructura del Repositorio de Trabajo

```
itcm-dp-vuci-customer/
├── docs/
│   ├── business-glossary/    ← glosarios de todas las tablas del modelo
│   │   ├── README.md          ← índice + guía de uso de tablas
│   │   ├── t_retail_transaction.md
│   │   ├── t_payment.md
│   │   ├── ba_itc_attr_retail.md
│   │   └── ...
│   └── brief/                ← briefs técnicos generados antes de cada desarrollo
│       └── [YYYYMMDD]_[atributo].md
└── source/
    └── business/
        └── bi_itc_attribute_party/
            └── [tabla_atributo]/
                ├── ddl/    alter_*.sql     ← ADD COLUMN + description
                ├── sp/     sp_load_tmp_*_N.sql + sp_load_[tabla].sql
                └── dml/    call_*.sql      ← CALL al SP principal
```

### Patrón de ejecución de atributos

```
call_*.sql (DML)
  └── CALL sp_load_[tabla]          ← SP principal
        ├── CALL sp_load_tmp_*_1    ← carga por bloques de empresa/rubro
        ├── CALL sp_load_tmp_*_2
        └── ...
```

Los SPs usan `EXECUTE IMMEDIATE` con variables de parámetro para proyectos/datasets/tablas — **nunca valores hardcodeados**.

---

## 5. Brief Técnico (obligatorio antes de cualquier cambio en scripts)

Antes de crear o modificar cualquier archivo `.sql` en el repositorio, **generar y guardar un brief técnico** en:

```
itcm-dp-vuci-customer/docs/brief/[YYYYMMDD]_[nombre_atributo].md
```

El brief documenta el análisis previo al desarrollo y sirve como referencia de diseño para revisores y para el propio agente si retoma el trabajo más adelante.

### Estructura del brief

```markdown
# Brief Técnico: [nombre descriptivo del atributo o cambio]

**Fecha:** YYYY-MM-DD
**Autor:** [nombre]
**Tipo de cambio:** nuevo atributo | modificación | nueva tabla

---

## 1. Necesidad de negocio

[Descripción del requerimiento de información que originó el desarrollo.
 Incluir el contexto de uso previsto: campaña, modelo ML, dashboard, etc.]

## 2. Verificación de existencia

- [ ] Consultado `c_attribute_metadata`: **no existe** atributo equivalente
- Atributos relacionados encontrados: [listar si hay alguno similar]

## 3. Atributos a crear

| Nombre columna | Tipo | Tabla destino | Descripción de negocio |
|---|---|---|---|
| `[empresa]_[metrica]_[dim]_1m` | NUMERIC | `ba_itc_attr_[tabla]` | [descripción] |
| `[empresa]_[metrica]_[dim]_3m` | NUMERIC | `ba_itc_attr_[tabla]` | [descripción] |
| ... | | | |

## 4. Fuentes de datos

| Tabla | Dataset | Uso | Filtros principales |
|---|---|---|---|
| `t_retail_transaction` | `master_transaction` | Transacciones de venta | `cod_empresa IN (...)`, partición `transaction_date` |
| `m_product` | `master_product` | Jerarquía de producto | `jq3 = '...'` o `jq5 = '...'` |
| [otras] | | | |

## 5. Lógica de cálculo

[Descripción precisa del filtro de negocio y la agregación:
 - Qué empresa/s se filtran
 - Qué productos/categorías aplican y por qué
 - Cómo se agrega (SUM, COUNT DISTINCT, MAX, etc.)
 - Qué ventanas temporales se calculan y cómo se definen (meses completos vs. días corridos)]

**Query de validación (exploratorio):**
```sql
SELECT
  id,
  SUM(CASE WHEN transaction_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 MONTH)
           THEN net_amount END) AS val_1m
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction`
WHERE cod_empresa IN ('...')
  AND transaction_date >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 12 MONTH)
GROUP BY id
LIMIT 1000
```

## 6. Archivos a crear / modificar

| Archivo | Ruta | Tipo de cambio |
|---|---|---|
| `alter_[tabla]_[YYYYMMDD].sql` | `source/business/.../ddl/` | nuevo |
| `sp_load_tmp_[tabla]_N.sql` | `source/business/.../sp/` | nuevo |
| `[tabla].md` | `data/standard/business-glossary/` | actualizar con columnas nuevas |

## 7. Dependencias y orden de ejecución

- SP N depende de: [tmp anterior o ninguna]
- Se llama desde: `sp_load_[tabla].sql` — [indicar si hay que agregar el CALL]

## 8. Criterio de validación

[Cómo verificar que el atributo se calculó correctamente:
 - Rango de valores esperado
 - % de nulos aceptable
 - Muestra de clientes conocidos para comparar]
```

### Cuándo generar el brief

El brief se genera **siempre** que la tarea implique:
- Agregar columnas nuevas a una tabla de atributos existente
- Crear un SP temporal nuevo
- Crear una tabla de atributos nueva
- Modificar la lógica de cálculo de un atributo existente

Para tareas de **solo consulta** (queries exploratorios, validaciones ad-hoc) el brief no es obligatorio.

---

## 6. Desarrollar un Atributo Nuevo

### Cuándo agregar a tabla existente vs. crear tabla nueva

| Situación | Decisión |
|---|---|
| El atributo es de comportamiento retail/POS/digital | Agregar a `ba_itc_attr_retail` / `ba_itc_attr_payment_pos` / `ba_itc_attr_digital` |
| El atributo es sobre una fuente nueva sin tabla propia | Crear tabla nueva en `bi_itc_attribute_party` |
| Más de ~30 atributos nuevos del mismo dominio | Crear tabla nueva |
| El atributo mezcla múltiples fuentes sin patrón existente | Crear tabla nueva |

### Los 3 archivos que siempre se crean

```
1. ddl/alter_[tabla]_[YYYYMMDD].sql   → ADD COLUMN IF NOT EXISTS + description
2. sp/sp_load_tmp_[tabla]_N.sql       → lógica de cálculo con EXECUTE IMMEDIATE
3. dml/ — no se modifica             → el CALL existente ya invoca todos los tmp SPs
```

### DDL — formato estándar

```sql
/*
== DDL: alter_ba_itc_attr_retail_20260310.sql ================
   Tabla   : intercorp-data-storage-pv.bi_itc_attribute_party.[tabla]
   Atributo: [descripción del grupo de columnas]
   Empresa : [far_ | spsa_ | oe_ | pro_ | itc_]
   Métricas: [mto_ | numtrx_ | mtoprom_ | flag_ | ...]
   Ventanas: [1m | 3m | 6m | 9m | 12m]
   Lógica  : [filtro de negocio en una oración]
   SP      : sp_load_tmp_[tabla]_N.sql
   Autor   : [nombre]   Fecha: [YYYY-MM-DD]
=============================================================*/

ALTER TABLE `intercorp-data-storage-pv.bi_itc_attribute_party.[tabla]`
  ADD COLUMN IF NOT EXISTS [empresa]_[metrica]_[dim]_1m  NUMERIC OPTIONS(description='[descripción negocio - 1 mes]')
 ,ADD COLUMN IF NOT EXISTS [empresa]_[metrica]_[dim]_3m  NUMERIC OPTIONS(description='[descripción negocio - 3 meses]')
 -- ... patrón por cada ventana temporal
;
```

### SP — estructura mínima

```sql
/*
== SP: sp_load_tmp_[tabla]_N.sql ============================
   Tabla destino : intercorp-data-storage-pv.bi_itc_attribute_party.[tabla]
   Empresa       : [far_ | spsa_ | ...]
   Atributos     : [empresa]_[metrica]_[dim]_1m … _12m
   Fuentes       : {v_input_t_retail_transaction}, {v_table_m_product}
   Lógica        : [filtro/agrupación de negocio]
   Dependencias  : tmp_[tabla]_[N-1] debe estar cargada
   Autor: [nombre]   Fecha: [YYYY-MM-DD]
=============================================================*/

CREATE OR REPLACE PROCEDURE `intercorp-data-storage-pv.master_stage.sp_load_tmp_[tabla]_N`
(
  start_date DATE
, v_proyecto_destino STRING
, v_bi_attr STRING
, v_master_stage STRING
, v_input_t_retail_transaction STRING
, -- ... mismos parámetros que los tmp SPs existentes
) OPTIONS(strict_mode=false)
BEGIN

  DECLARE v_sql STRING;

  DECLARE v_interval_date_1M  INT64;
  -- ...

  -- ── ATRIBUTO: [nombre del atributo] ───────────────────────
  SET v_sql = CONCAT("
    UPDATE `", v_proyecto_destino, ".", v_bi_attr, ".[tabla]` t
    SET
      [empresa]_[metrica]_[dim]_1m = s.val_1m,
      [empresa]_[metrica]_[dim]_3m = s.val_3m
    FROM (
      SELECT
        ip.id,
        SUM(CASE WHEN ... >= ", v_interval_date_1M, " THEN r.net_amount END) AS val_1m,
        -- ...
      FROM `", v_input_t_retail_transaction, "` r
      INNER JOIN `", v_master_stage, ".tmp_[tabla]_1` ip ON r.id = ip.id
      WHERE r.cod_empresa IN ('FAR','FARMA')
        AND r.transaction_date >= DATE_SUB(DATE_TRUNC(start_date, MONTH), INTERVAL 12 MONTH)
      GROUP BY ip.id
    ) s
    WHERE t.id = s.id
  ");
  EXECUTE IMMEDIATE v_sql;

END;
```

---

## 7. Buenas Prácticas SQL para Este Repositorio

### Siempre filtrar por partición

```sql
-- t_retail_transaction → filtrar por transaction_date
-- t_transaction        → filtrar por itc_process_date
-- t_payment           → filtrar por payment_date
-- ba_itc_attr_*       → filtrar por process_date
```

### Para tablas de atributos, usar el último corte disponible

```sql
WHERE process_date = DATE_TRUNC(CURRENT_DATE(), MONTH)
-- o el último disponible:
WHERE process_date = (SELECT MAX(process_date) FROM `...ba_itc_attr_retail`)
```

### Variables de ventana en SPs

Las variables `v_interval_date_1M`, `v_interval_date_3M`, etc. ya están declaradas en cada SP. Usarlas directamente — no recalcular `DATE_SUB` dentro del `EXECUTE IMMEDIATE`.

### Usar `EXECUTE IMMEDIATE` con CONCAT para queries dinámicos

```sql
-- Correcto: parámetros de proyecto/dataset inyectados por variable
SET v_sql = CONCAT("SELECT ... FROM `", v_proyecto, ".", v_dataset, ".tabla` ...");
EXECUTE IMMEDIATE v_sql;

-- Incorrecto: hardcodear proyectos o datasets
SELECT ... FROM `intercorp-data-storage-pv.master_stage.tabla` ...;
```

### CTE por atributo para legibilidad

```sql
WITH
  base_clientes AS (
    SELECT id, SUM(net_amount) AS mto_total
    FROM `...t_retail_transaction`
    WHERE transaction_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
      AND cod_empresa IN ('FAR','FARMA')
    GROUP BY id
  )
SELECT id, mto_total
FROM base_clientes
```

---

## 8. Checklist

### Antes de escribir cualquier query o atributo
- [ ] Consulté `c_attribute_metadata` — el dato no existe ya
- [ ] Leí el glosario de cada tabla que voy a usar (`data/standard/business-glossary/[tabla].md`)
- [ ] Identificé la partición de cada tabla fuente — mi query la filtra
- [ ] Identifiqué el campo de JOIN entre tablas (`id`, `iden_party_id`, `party_id`)

### Para atributos nuevos (antes de tocar cualquier .sql)
- [ ] **Brief técnico generado** en `docs/brief/[YYYYMMDD]_[atributo].md` — secciones 1–8 completas
- [ ] Brief revisado y aprobado antes de escribir el primer archivo `.sql`

### Archivos del atributo
- [ ] DDL con cabecera completa, `ADD COLUMN IF NOT EXISTS`, `OPTIONS(description='...')`
- [ ] Naming: `[empresa]_[metrica]_[dimension]_[ventana]` — minúsculas, snake_case
- [ ] SP con cabecera completa, sin hardcodeo, variables `v_interval_date_NM` reutilizadas
- [ ] Comentario de sección `-- ── ATRIBUTO: ...` antes de cada bloque
- [ ] Glosario de la tabla destino actualizado en `data/standard/business-glossary/[tabla].md`
- [ ] Validado en dev contra muestra conocida por el negocio
