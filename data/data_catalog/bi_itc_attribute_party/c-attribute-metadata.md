# Catálogo de Datos — `c_attribute_metadata`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`

---

## Descripción

Catálogo de **metadatos de todos los atributos** del repositorio de clientes Intercorp. Para cada campo de las tablas `ba_itc_attr_*` registra: la tabla origen, nombre del atributo, descripción, fórmula de cálculo, tipo de dato, y las empresas para las que aplica.

Es el **diccionario central** del modelo de atributos — permite descubrir qué atributos existen, entender su significado sin leer el código del SP, y encontrar atributos por grupo/subgrupo/categoría temática.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | ~18,000 (~18K) |
| Número de columnas | 33 |
| Tamaño | ~2 MB |
| Actualización | Con cada release de nuevos atributos |

---

## Glosario de Campos

### 1. Identificación del atributo

| Campo | Tipo | Descripción |
|---|---|---|
| `attribute_id` | STRING | ID único del atributo en el catálogo |
| `name` | STRING | Nombre del campo tal como aparece en BigQuery (ej: `spsa_mtoprom_tienda_1m`) |
| `description` | STRING | Descripción en lenguaje natural del atributo |
| `formula` | STRING | Fórmula o lógica de cálculo del atributo |
| `data_type` | STRING | Tipo de dato (`INTEGER`, `FLOAT`, `STRING`, `DATE`, `BOOLEAN`) |

### 2. Ubicación en BigQuery

| Campo | Tipo | Descripción |
|---|---|---|
| `attribute_project` | STRING | Proyecto BigQuery (ej: `intercorp-data-storage-pv`) |
| `dataset` | STRING | Dataset BigQuery (ej: `bi_itc_attribute_party`) |
| `table` | STRING | Tabla BigQuery (ej: `ba_itc_attr_retail`) |

### 3. Taxonomía / Clasificación

| Campo | Tipo | Descripción |
|---|---|---|
| `group` | STRING | Grupo temático del atributo (ej: `RETAIL`, `DIGITAL`, `FINANCIERO`) |
| `subgroup` | STRING | Subgrupo dentro del grupo (ej: `SPSA`, `FARMACIAS`, `TARJETA`) |
| `category` | STRING | Categoría más específica (ej: `FRECUENCIA`, `MONTO`, `RECENCIA`) |

### 4. Cobertura por empresa

| Campo | Tipo | Descripción |
|---|---|---|
| `companies` | STRING | Lista de `itc_company_id` para los cuales aplica el atributo (ej: `010,025,048`) |
| `flag_spsa` | INTEGER | `1` = el atributo aplica a SPSA |
| `flag_oe` | INTEGER | `1` = el atributo aplica a Oechsle |
| `flag_promart` | INTEGER | `1` = el atributo aplica a Promart |
| `flag_inkf` | INTEGER | `1` = el atributo aplica a Inkafarma |
| `flag_mfarm` | INTEGER | `1` = el atributo aplica a Mifarma |
| `flag_ibk` | INTEGER | `1` = el atributo aplica a Interbank |
| `flag_cplt` | INTEGER | `1` = el atributo aplica a Cineplanet |

### 5. Metadatos de gestión

| Campo | Tipo | Descripción |
|---|---|---|
| `version` | STRING | Versión del atributo (permite trackear cambios en la definición) |
| `status` | STRING | Estado del atributo (`ACTIVO`, `DEPRECADO`, `EN_DESARROLLO`) |
| `owner` | STRING | Equipo o persona responsable del atributo |
| `load_date` | TIMESTAMP | Fecha de última actualización del registro en el catálogo |
| `sp_name` | STRING | Nombre del SP que genera este atributo |

---

## Reglas de negocio

1. **Sin partición** — tabla estática/de referencia. Escanear completa para búsquedas.

2. **`status = 'ACTIVO'`**: Filtrar por status activo para obtener solo atributos vigentes. Los deprecados pueden existir en tablas históricas pero no se calculan en nuevos snapshots.

3. **`formula IS NOT NULL`**: Atributos con fórmula documentada permiten reproducir el cálculo sin ver el SP. Atributos con `formula IS NULL` requieren revisar el SP generador.

4. **Descubrimiento de atributos**: Para encontrar todos los atributos de una empresa y tema específico, filtrar por `flag_{empresa} = 1` y `group` o `category`.

5. **`sp_name`**: Permite trazar desde el atributo hasta el SP que lo genera, para debugging o actualización de lógica.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Cobertura parcial | No todos los atributos de todas las tablas están documentados — 18K filas no cubre los ~15K+ campos totales del repositorio |
| `formula` puede estar desactualizada | Si el SP fue modificado sin actualizar el catálogo, la fórmula puede diferir del cálculo real |
| Catálogo vivo | Se actualiza con cada nuevo release de atributos — puede haber lag entre la creación del atributo y su documentación |

---

## Queries de referencia

```sql
-- Todos los atributos activos de consumo retail en SPSA
SELECT name, description, formula, category, sp_name
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`
WHERE flag_spsa = 1
  AND `group` = 'RETAIL'
  AND status = 'ACTIVO'
ORDER BY category, name;

-- Buscar atributos por descripción (texto libre)
SELECT name, table, description, formula
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`
WHERE LOWER(description) LIKE '%recencia%'
  AND status = 'ACTIVO';

-- Atributos de la tabla ba_itc_attr_digital
SELECT name, data_type, description, companies
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`
WHERE table = 'ba_itc_attr_digital'
  AND status = 'ACTIVO'
ORDER BY name;

-- Conteo de atributos por tabla y grupo
SELECT table, `group`, COUNT(*) AS total_atributos
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`
WHERE status = 'ACTIVO'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_itc_attribute_party.c_attribute_metadata`*
