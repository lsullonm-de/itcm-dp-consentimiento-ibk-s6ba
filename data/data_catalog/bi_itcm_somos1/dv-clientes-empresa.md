# Catálogo de Datos — `dv_clientes_empresa`

**Catalog ID:** `bi_itcm_somos1.dv_clientes_empresa`
**Proyecto canónico:** `dev-intercorp-data-storage`
**Dataset:** `bi_itcm_somos1`
**Tabla completa:** `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
**Profiling realizado sobre:** `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
_(ambiente de desarrollo — catalog ID aplica igualmente a versión productiva)_

---

## Descripción

Tabla de **clientes cross-retail del Programa Somos 1** agregados por período (año/mes), empresa(s) donde transaccionan, departamento, y perfil demográfico (edad, género, nivel educativo). Permite analizar el comportamiento multi-empresa de los clientes del Grupo Intercorp: cuántos clientes compran en solo una empresa vs. en varias simultáneamente.

Cada fila representa el conteo de clientes que pertenecen a una combinación específica de dimensiones. El campo clave de análisis es `empresa_cross_retail`, que indica en qué empresas transaccionó el cliente durante el período.

**Dataset `bi_itcm_somos1`:** corresponde al programa **Somos 1**, iniciativa del Grupo Intercorp que vincula a los clientes entre las diferentes empresas del grupo.

**Granularidad de la fila:** combinación de `(anio, mes, departamento, flag_spsa, flag_promart, flag_oec, flag_farmas, n_empresas_retail, Rango_edad, nivel_educativo, genero, empresa_cross_retail)` → `cant_clientes` es el count de clientes con ese perfil.

---

## Metadata Técnica

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `DATE(load_date)` — `load_date` es DATETIME |
| Clusterizado por | `anio`, `mes`, `departamento` (en ese orden) |
| Total de filas | 24,526,662 |
| Número de columnas | 17 |
| Tamaño lógico | ~4.59 GB |
| Partición activa | `2026-06-15` (única partición) |
| Período de datos | 2019 → 2026 (toda la historia en una partición) |
| Primera carga | 2026-06-15 |
| Última carga | 2026-06-15 |
| Frequencia de carga | Batch único (historia completa) |
| ETL origen | Matillion (`prd-itc-dp-matillion-integrati@silent-matter-270218.iam.gserviceaccount.com`) |

**DDL:**
```sql
CREATE TABLE `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
(
  anio INT64 NOT NULL OPTIONS(description="Año de transacciones de venta"),
  mes INT64 NOT NULL OPTIONS(description="Mes de transacciones de venta"),
  departamento STRING NOT NULL OPTIONS(description="Departamento de ubicación del punto de venta"),
  flag_spsa INT64 NOT NULL OPTIONS(description="Flag que indica si el cliente realizó alguna transacción en SPSA. 1=si. 0 =no."),
  flag_promart INT64 NOT NULL OPTIONS(description="Flag que indica si el cliente realizó alguna transacción en Promart. 1=si. 0 =no."),
  flag_oec INT64 NOT NULL OPTIONS(description="Flag que indica si el cliente realizó alguna transacción en Oechsle. 1=si. 0 =no."),
  flag_farmas INT64 NOT NULL OPTIONS(description="Flag que indica si el cliente realizó alguna transacción en Farmacias Peruanas. 1=si. 0 =no."),
  n_empresas_retail INT64 NOT NULL OPTIONS(description="Cantidad de empresas retail en las que el cliente transaccionó."),
  Rango_edad STRING OPTIONS(description="Rango de edad del cliente"),
  nivel_educativo STRING OPTIONS(description="Nivel educativo del cliente"),
  genero STRING OPTIONS(description="Género del cliente"),
  empresa_cross_retail STRING NOT NULL OPTIONS(description="Empresa(s) retail"),
  cant_clientes INT64 NOT NULL OPTIONS(description="Cantidad de clientes"),
  record_source STRING NOT NULL OPTIONS(description="Fecha y hora de inserción del registro en el modelo"),
  load_date DATETIME NOT NULL OPTIONS(description="Dato de Auditoría: Descripción del aplicativo origen de los datos"),
  creation_user STRING NOT NULL OPTIONS(description="Usuario que crea el registro"),
  district_names_zonas STRING
)
PARTITION BY DATE(load_date)
CLUSTER BY anio, mes, departamento;
```

---

## Diccionario de Campos

### 1. Dimensiones de tiempo

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `anio` | INT64 | NOT NULL | Año del período de transacciones. Campo de clustering (posición 1). Rango: 2019–2026. |
| `mes` | INT64 | NOT NULL | Mes del período (1–12). Campo de clustering (posición 2). |

### 2. Dimensión geográfica

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `departamento` | STRING | NOT NULL | Departamento del Perú. Campo de clustering (posición 3). 22 departamentos distintos. Incluye "LIMA", "CALLAO", y los demás departamentos del Perú. |
| `district_names_zonas` | STRING | YES | Nombre de zona o agrupación de distritos. Presente en los datos pero con alta frecuencia de nulls. |

### 3. Flags de empresa retail

Indican en qué empresas del Grupo Intercorp transaccionó el cliente durante el período. Los 4 flags son NOT NULL y pueden ser 0 o 1.

| Campo | Tipo | Nullable | Descripción (desde BigQuery column description) |
|---|---|---|---|
| `flag_spsa` | INT64 | NOT NULL | Flag de transacción en SPSA (Supermercados Peruanos — Plaza Vea, Mass, Vivanda). `1` = sí transaccionó; `0` = no. |
| `flag_promart` | INT64 | NOT NULL | Flag de transacción en Promart. `1` = sí; `0` = no. |
| `flag_oec` | INT64 | NOT NULL | Flag de transacción en Oechsle (Tiendas Peruanas). `1` = sí; `0` = no. |
| `flag_farmas` | INT64 | NOT NULL | Flag de transacción en Farmacias Peruanas (InkaFarma + MiFarma). `1` = sí; `0` = no. |

### 4. Métricas de cross-retail

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `n_empresas_retail` | INT64 | NOT NULL | Cantidad de empresas retail distintas en las que el cliente transaccionó en el período. Valores posibles: 1, 2, 3, 4. |
| `empresa_cross_retail` | STRING | NOT NULL | Combinación de empresas donde transaccionó el cliente, usando abreviaciones separadas por `+`. Ver tabla de combinaciones abajo. |

**Abreviaciones en `empresa_cross_retail`:**

| Abreviación | Empresa |
|---|---|
| `FP` | Farmacias Peruanas (InkaFarma + MiFarma) |
| `SPSA` | Supermercados Peruanos (Plaza Vea, Mass, Vivanda, etc.) |
| `OE` | Oechsle / Tiendas Peruanas |
| `PROMART` | Promart Homecenter |

**Top combinaciones de `empresa_cross_retail` (total tabla):**

| Combinación | Registros | % |
|---|---|---|
| FP | 5,004,740 | 20.4% |
| SPSA | 3,761,314 | 15.3% |
| FP+SPSA | 3,063,355 | 12.5% |
| PROMART | 1,744,162 | 7.1% |
| OE | 1,733,218 | 7.1% |
| FP+SPSA+PROMART | 1,460,515 | 6.0% |
| SPSA+PROMART | 1,418,196 | 5.8% |
| FP+PROMART | 1,247,653 | 5.1% |
| FP+SPSA+OE | 1,118,937 | 4.6% |
| FP+OE | 1,094,309 | 4.5% |
| SPSA+OE | 1,079,203 | 4.4% |
| FP+SPSA+OE+PROMART | 576,790 | 2.4% |
| SPSA+OE+PROMART | 477,960 | 2.0% |
| OE+PROMART | 380,433 | 1.6% |
| FP+OE+PROMART | 365,877 | 1.5% |

### 5. Perfil demográfico del cliente

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `Rango_edad` | STRING | YES | Rango etario del cliente. Valores: `18 a 25 años`, `26 a 35 años`, `36 a 45 años`, `46 a 55 años`, `56 a 65 años`, `Mayor a 65 años`, y uno más. NULL cuando no se conoce la edad. |
| `nivel_educativo` | STRING | YES | Nivel educativo del cliente. Valores observados en muestra: `UNIVERSITARIA`, `UNIVERSIDAD COMPLETA`, `TECNICO`, `SECUNDARIA`. ⚠️ Se detectaron 90 valores distintos — puede incluir variantes granulares o combinaciones. NULL frecuente. |
| `genero` | STRING | YES | Género del cliente. Valores: `F` (femenino), `M` (masculino). |

### 6. Métrica principal

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `cant_clientes` | INT64 | NOT NULL | Cantidad de clientes con el perfil demográfico y cross-retail de la fila. Es el count agregado de clientes únicos con esa combinación de dimensiones. |

### 7. Campos de auditoría

| Campo | Tipo | Nullable | Descripción |
|---|---|---|---|
| `load_date` | DATETIME | NOT NULL | **Campo de partición** (via `DATE(load_date)`). Fecha y hora de carga. Valor: `2026-06-15T09:30:48`. Filtrar con `WHERE DATE(load_date) = '2026-06-15'`. |
| `record_source` | STRING | NOT NULL | Sistema ETL de origen. Valor: `"MATILLION"`. |
| `creation_user` | STRING | NOT NULL | SA del proceso de carga. Valor: `"prd-itc-dp-matillion-integrati@silent-matter-270218.iam.gserviceaccount.com"`. |

---

## Volumetría

| Dimensión | Valores distintos |
|---|---|
| Años | 2019–2026 |
| Empresas cross-retail | 15 combinaciones |
| Departamentos | 22 |
| Rangos de edad | 7 |
| Géneros | 2 (F, M) |
| n_empresas_retail | 4 (1, 2, 3, 4) |

**Única partición:** `2026-06-15` — toda la historia (2019–2026) está en una sola partición.

---

## Relaciones con Otras Tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `dv_inretail_venta` (bi_vuc_insight) | `departamento`, `anio`, `mes` | Cruzar ventas por geografía con perfil de clientes cross-retail |
| Tablas demográficas de clientes | Sin join directo | Esta tabla es un agregado — no tiene `id` de cliente individual |

> ⚠️ **Esta tabla NO tiene campo de cliente individual.** Es un agregado estadístico por segmento. No se puede hacer join con tablas de transacciones individuales a nivel de cliente.

---

## Reglas de Negocio

1. **Filtrar siempre por partición** — `WHERE DATE(load_date) = '2026-06-15'` para evitar full scan. Toda la historia está en esta única partición.

2. **`n_empresas_retail` es la suma de los flags** — `n_empresas_retail = flag_spsa + flag_promart + flag_oec + flag_farmas`. Valores 1–4. Útil para segmentar clientes mono-empresa vs. multi-empresa.

3. **`empresa_cross_retail` es derivado de los flags** — Concatenación ordenada de las abreviaciones donde el flag = 1. Un cliente con `flag_spsa=1, flag_farmas=1` → `empresa_cross_retail = 'FP+SPSA'`.

4. **Período = mes de la transacción** — `anio` y `mes` son el período en que el cliente realizó compras, no la fecha de carga (`load_date`).

5. **`nivel_educativo` tiene 90 valores distintos** — Investigar si incluye variantes de escritura, valores compuestos o categorías no estandarizadas. Aplicar normalización antes de agrupar por este campo.

6. **NULL en demográficos es frecuente** — `Rango_edad`, `nivel_educativo` y `genero` pueden ser NULL cuando el cliente no tiene perfil demográfico disponible. Considerar esto en análisis de segmentación.

---

## Observaciones de Calidad de Datos

| Campo | Observación |
|---|---|
| `nivel_educativo` | 90 valores distintos — inconsistencia esperada. Estandarizar antes de usar en agrupaciones. |
| `district_names_zonas` | Presente pero con alta proporción de nulls. Complementario a `departamento`. |
| `load_date` | Es DATETIME pero se usa como partición vía `DATE(load_date)`. Filtrar con `DATE(load_date)`. |
| `record_source` | Valor siempre `"MATILLION"`. Útil para trazabilidad ETL pero no para filtros de negocio. |

---

## Queries de Referencia

```sql
-- 1. Distribución de clientes por empresa cross-retail (último año)
SELECT
  anio, mes,
  empresa_cross_retail,
  n_empresas_retail,
  SUM(cant_clientes) AS clientes
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
WHERE DATE(load_date) = '2026-06-15'
  AND anio = 2026
GROUP BY anio, mes, empresa_cross_retail, n_empresas_retail
ORDER BY anio, mes, clientes DESC;

-- 2. Clientes multi-empresa (2+ empresas) por departamento
SELECT
  departamento,
  SUM(CASE WHEN n_empresas_retail = 1 THEN cant_clientes ELSE 0 END) AS mono_empresa,
  SUM(CASE WHEN n_empresas_retail = 2 THEN cant_clientes ELSE 0 END) AS dos_empresas,
  SUM(CASE WHEN n_empresas_retail >= 3 THEN cant_clientes ELSE 0 END) AS tres_o_mas,
  SUM(cant_clientes) AS total
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
WHERE DATE(load_date) = '2026-06-15'
  AND anio = 2025
GROUP BY departamento
ORDER BY total DESC;

-- 3. Perfil demográfico de clientes que compran en todas las empresas (FP+SPSA+OE+PROMART)
SELECT
  genero, Rango_edad,
  SUM(cant_clientes) AS clientes
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
WHERE DATE(load_date) = '2026-06-15'
  AND empresa_cross_retail = 'FP+SPSA+OE+PROMART'
  AND genero IS NOT NULL
  AND Rango_edad IS NOT NULL
GROUP BY genero, Rango_edad
ORDER BY clientes DESC;

-- 4. Evolución mensual de clientes cross-retail (FP + SPSA)
SELECT
  anio, mes,
  SUM(CASE WHEN flag_farmas = 1 AND flag_spsa = 1 THEN cant_clientes ELSE 0 END) AS clientes_fp_spsa,
  SUM(cant_clientes) AS total_clientes
FROM `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`
WHERE DATE(load_date) = '2026-06-15'
GROUP BY anio, mes
ORDER BY anio, mes;
```

---

> **Nota de profiling:** Catálogo generado con datos de `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa`. El catalog ID `bi_itcm_somos1.dv_clientes_empresa` aplica a cualquier proyecto que exponga esta tabla.

*Generado: 2026-06-24 | Fuente: BigQuery `dev-intercorp-data-storage.bi_itcm_somos1.dv_clientes_empresa` | 24,526,662 filas · 4.59 GB · 17 columnas*
