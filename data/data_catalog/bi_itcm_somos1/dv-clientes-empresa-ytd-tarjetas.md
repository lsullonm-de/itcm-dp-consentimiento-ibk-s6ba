# Catálogo de Datos — `dv_clientes_empresa_ytd_tarjetas`

**Catalog ID:** `bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
**Proyecto canónico:** `dev-intercorp-data-storage`
**Dataset:** `bi_itcm_somos1`
**Tabla completa:** `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
**Profiling realizado sobre:** `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
_(ambiente de desarrollo — catalog ID aplica igualmente a versión productiva)_

---

## Descripción

Tabla de **clientes por empresa retail segmentados por tenencia de productos financieros Intercorp** (Tarjeta Interbank, Tarjeta OH!, Agora), con corte **YTD (Year-To-Date)**. Muestra cuántos clientes de cada empresa y canal de venta tienen o no tienen cada producto financiero, a una fecha de corte específica (`process_date`).

Pertenece al programa **Somos 1** de Intercorp (`bi_itcm_somos1`), cuyo objetivo es vincular a los clientes entre las empresas retail y los productos financieros del Grupo.

**Caso de uso:** identificar la penetración de productos financieros Intercorp (IBK, TOH, Agora) en la base de clientes de cada empresa retail, por canal y departamento. Útil para campañas de cross-sell financiero.

**Granularidad de la fila:** combinación de `(process_date, empresa, departamento, canal_venta, Flag_tiene_tc_ibk, Flag_tiene_tc_toh, Flag_tiene_agora)` → `cant_clientes` es el count de clientes con ese perfil a la fecha de corte.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DATE NOT NULL) |
| Clusterizado por | Sin clustering |
| Total de filas | 20,878 |
| Número de columnas | 12 |
| Tamaño lógico | ~3.5 MB (tabla pequeña) |
| Partición activa | `2026-04-01` (única partición) |
| `process_date` | `2026-04-01` — fecha de corte YTD |
| Fecha de carga | `2026-06-15T10:03:44` |
| ETL origen | Matillion (`prd-itc-dp-matillion-integrati@silent-matter-270218.iam.gserviceaccount.com`) |

**DDL:**
```sql
CREATE TABLE `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
(
  process_date DATE NOT NULL OPTIONS(description="Fecha de corte de información"),
  empresa STRING NOT NULL OPTIONS(description="Nombre de empresa retail"),
  departamento STRING OPTIONS(description="Departamento donde está ubicado el punto de venta"),
  canal_venta STRING OPTIONS(description="Canal de venta: ONLINE/ PRESENCIAL"),
  Flag_tiene_tc_ibk INT64 OPTIONS(description="Flag de tarjeta de crédito IBK: 1 = Si. 0 = No"),
  Flag_tiene_tc_toh INT64 OPTIONS(description="Flag de tarjeta de crédito FOH. 1 = Si. 0 = No"),
  Flag_tiene_agora INT64 OPTIONS(description="Flag de tenencia de Agora. 1 = Si. 0 = No"),
  cant_clientes INT64 OPTIONS(description="Cantidad de clientes"),
  record_source STRING OPTIONS(description="Fecha y hora de inserción del registro en el modelo"),
  load_date DATETIME OPTIONS(description="Dato de Auditoría: Descripción del aplicativo origen de los datos"),
  creation_user STRING OPTIONS(description="Usuario que crea el registro"),
  district_names_zonas STRING
)
PARTITION BY process_date;
```

---

## Diccionario de Campos

### 1. Dimensión de fecha de corte

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `process_date` | DATE | NOT NULL | **Campo de partición.** Fecha de corte de la información YTD. Valor actual: `2026-04-01` (corte al 1 de abril de 2026). Filtrar siempre: `WHERE process_date = '2026-04-01'`. |

### 2. Dimensiones de empresa y geografía

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `empresa` | STRING | NOT NULL | Empresa retail del Grupo Intercorp. 5 empresas distintas. Ver tabla de valores abajo. |
| `departamento` | STRING | YES | Departamento del Perú. 22 departamentos distintos. NULL en algunos registros. |
| `canal_venta` | STRING | YES | Canal de compra del cliente. Valores: `Online`, `Presencial`, `Todos` (agregado de ambos canales). |
| `district_names_zonas` | STRING | YES | Nombre de zona o agrupación de distritos. Presente en datos pero puede ser null. |

**Nota sobre `canal_venta`:** el valor `"Todos"` representa la agregación de Online + Presencial para esa combinación empresa/departamento/flags. Las filas con `"Todos"` no se deben sumar con las filas de `"Online"` y `"Presencial"` para evitar doble conteo.

### 3. Flags de tenencia de productos financieros Intercorp

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `Flag_tiene_tc_ibk` | INT64 | YES | Flag de tenencia de **Tarjeta de Crédito Interbank (IBK)**. `1` = tiene TC IBK; `0` = no tiene. 8,884 filas con valor 1. |
| `Flag_tiene_tc_toh` | INT64 | YES | Flag de tenencia de **Tarjeta OH! (TOH/FOH)**. `1` = tiene TC OH!; `0` = no tiene. 8,181 filas con valor 1. |
| `Flag_tiene_agora` | INT64 | YES | Flag de tenencia de **Agora** (plataforma de pagos/billetera Intercorp). `1` = tiene Agora; `0` = no tiene. 12,076 filas con valor 1. Es el producto con mayor penetración en esta tabla. |

> Los flags no son mutuamente excluyentes. Un cliente puede tener los 3 productos simultáneamente.

### 4. Métrica principal

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `cant_clientes` | INT64 | YES | Cantidad de clientes con el perfil (empresa + canal + departamento + flags de productos) a la fecha de corte. Suma total en tabla: ~260 millones de registros cliente-combinación. |

### 5. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | DATETIME | YES | Fecha y hora de carga del ETL. Valor: `2026-06-15T10:03:44`. ⚠️ No confundir con `process_date` (fecha de corte del negocio). |
| `record_source` | STRING | YES | Sistema ETL de origen. Valor: `"MATILLION"`. |
| `creation_user` | STRING | YES | SA del proceso de carga. Valor: `"prd-itc-dp-matillion-integrati@silent-matter-270218.iam.gserviceaccount.com"`. |

---

## Volumetría

| Dimensión | Valores distintos | Detalle |
|---|---|---|
| `process_date` | 1 | `2026-04-01` |
| `empresa` | 5 | Retail companies |
| `canal_venta` | 3 | Online, Presencial, Todos |
| `departamento` | 22 | Todos los departamentos del Perú |
| Filas con `Flag_tiene_tc_ibk = 1` | 8,884 | |
| Filas con `Flag_tiene_tc_toh = 1` | 8,181 | |
| Filas con `Flag_tiene_agora = 1` | 12,076 | Agora es el más penetrado |
| Suma de `cant_clientes` | ~260 millones | Total de ocurrencias cliente-combinación |

**Tabla pequeña:** 20,878 filas, ~3.5 MB. Full scan es barato.

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `dv_clientes_empresa` (bi_itcm_somos1) | `empresa`, `departamento`, `anio`, `mes` | Enriquecer perfil cross-retail con tenencia de productos financieros |
| `dv_inretail_venta` (bi_vuc_insight) | `empresa`, `departamento`, `canal_venta` | Cruzar volumen de ventas con penetración de productos financieros |
| `dv_rcc_montos_tc` (bi_vuc_insight) | `departamento` | Cruzar uso de TC Intercorp con contexto crediticio por zona |

---

## Reglas de Negocio

1. **`process_date` = fecha de corte YTD** — Los datos son acumulados hasta el `process_date` (`2026-04-01`). No representa transacciones de un mes específico sino el acumulado del año hasta esa fecha.

2. **Filtrar siempre por `process_date`** — `WHERE process_date = '2026-04-01'` para evitar full scan. Toda la tabla es una sola partición.

3. **`canal_venta = 'Todos'` es un agregado** — Las filas con `canal_venta = 'Todos'` suman Online + Presencial. Para análisis por canal, filtrar con `canal_venta IN ('Online', 'Presencial')` y no incluir `'Todos'` para evitar doble conteo.

4. **Los flags son independientes entre sí** — Un cliente puede tener `Flag_tiene_tc_ibk = 1` y `Flag_tiene_tc_toh = 1` y `Flag_tiene_agora = 1` simultáneamente. Hay filas para cada combinación posible de los 3 flags (2³ = 8 combinaciones).

5. **Tabla estática de corte** — Esta tabla representa un snapshot a `2026-04-01`. Si se necesita evolución mensual, consultar si existen versiones anteriores con distintos `process_date`.

6. **`cant_clientes` no es suma directa** — Sumar `cant_clientes` sin filtrar por `canal_venta` puede generar doble conteo por la presencia de filas `"Todos"`. Usar siempre un filtro de canal.

---

## Observaciones de Calidad de Datos

| Campo | Observación |
|---|---|
| `canal_venta = 'Todos'` | Valor de agregación — no sumar con Online/Presencial para evitar doble conteo. |
| `departamento` | Puede ser NULL en algunos registros — probablemente online sin geolocalización. |
| `load_date` | Diferente a `process_date` — `load_date` es la fecha ETL (junio 2026), `process_date` es el corte de negocio (abril 2026). |
| `record_source` | Siempre `"MATILLION"` — trazabilidad del ETL. |

---

## Queries de Referencia

```sql
-- 1. Penetración de productos financieros por empresa retail
SELECT
  empresa,
  SUM(CASE WHEN Flag_tiene_tc_ibk = 1 THEN cant_clientes ELSE 0 END) AS con_tc_ibk,
  SUM(CASE WHEN Flag_tiene_tc_toh = 1 THEN cant_clientes ELSE 0 END) AS con_tc_toh,
  SUM(CASE WHEN Flag_tiene_agora = 1 THEN cant_clientes ELSE 0 END)  AS con_agora,
  SUM(cant_clientes)                                                  AS total_clientes
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
WHERE process_date = '2026-04-01'
  AND canal_venta = 'Todos'  -- usar agregado para no duplicar
GROUP BY empresa
ORDER BY total_clientes DESC;

-- 2. Tasa de penetración de Tarjeta IBK por departamento (canal presencial)
SELECT
  departamento,
  SUM(CASE WHEN Flag_tiene_tc_ibk = 1 THEN cant_clientes ELSE 0 END)       AS con_ibk,
  SUM(cant_clientes)                                                         AS total,
  ROUND(SUM(CASE WHEN Flag_tiene_tc_ibk = 1 THEN cant_clientes ELSE 0 END)
        * 100.0 / NULLIF(SUM(cant_clientes), 0), 2)                         AS pct_penetracion_ibk
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
WHERE process_date = '2026-04-01'
  AND canal_venta = 'Presencial'
  AND departamento IS NOT NULL
GROUP BY departamento
ORDER BY pct_penetracion_ibk DESC;

-- 3. Clientes con todos los productos Intercorp (IBK + TOH + Agora) por empresa
SELECT
  empresa, canal_venta,
  SUM(CASE WHEN Flag_tiene_tc_ibk = 1
            AND Flag_tiene_tc_toh = 1
            AND Flag_tiene_agora  = 1 THEN cant_clientes ELSE 0 END) AS full_intercorp,
  SUM(cant_clientes)                                                  AS total
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`
WHERE process_date = '2026-04-01'
  AND canal_venta != 'Todos'  -- solo niveles granulares
GROUP BY empresa, canal_venta
ORDER BY empresa, canal_venta;
```

---

> **Nota de profiling:** Catálogo generado con datos de `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas`. El catalog ID `bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas` aplica a cualquier proyecto que exponga esta tabla.

*Generado: 2026-06-24 | Fuente: BigQuery `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas` | 20,878 filas · 3.5 MB · 12 columnas*
