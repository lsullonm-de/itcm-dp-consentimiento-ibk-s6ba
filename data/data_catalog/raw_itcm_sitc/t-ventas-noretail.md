# Catálogo de Datos — `t_ventas_noretail`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `raw_itcm_sitc`
**Tabla completa:** `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`

---

## Descripción

Tabla de **ventas/beneficios no-retail de empleados Intercorp** en empresas del grupo. A diferencia de `t_retail_transaction` (transacciones de clientes externos) y `t_experience_transaction` (entretenimiento), esta tabla registra el uso de beneficios corporativos de los **colaboradores (empleados)** de empresas Intercorp en otras empresas del grupo.

Cada fila representa un mes-empleado-empresa beneficio: cuántas veces un empleado de empresa A utilizó un beneficio en empresa B (ej: un empleado de SPSA que compró en Inkafarma con descuento de empleado), incluyendo el importe total y el descuento aplicado.

La tabla es de **granularidad mensual** (no diaria como las otras tablas de transacciones) y contiene datos históricos desde enero 2023.

> **Uso principal**: `sp_load_tmp_dv_employee_transaction_no_retail.sql` — alimenta el modelo de transacciones de empleados para análisis de beneficios corporativos y permanencia en el club de empleados.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | **NO** (tabla sin partición) |
| Clusterizado | NO |
| Total de filas | 684,280 |
| Número de columnas | 12 |
| Tamaño lógico | ~118 MB |
| Tamaño físico | ~4.3 MB (alta compresión) |
| Rango de `fecha_registro` | 2023-01-01 a 2025-12-01 (36 meses) |
| Rango de `fecha_proceso` | 2024-09-09 a 2026-01-28 |
| Última carga | 2026-01-28 |
| Fuente ETL | Archivos `.txt` cargados vía Matillion |
| Labels | `environment=prd`, `inca_published=si` |

---

## Volumen por empresa que trabaja (empresa_labora)

| empresa_labora | Empresa | Registros | Empleados únicos |
|---|---|---|---|
| 000 | INTERBANK | 137,942 | 11,068 |
| 025 | INKAFARMA | 75,851 | 28,459 |
| 088 | COMPAÑIA FOOD RETAIL S.A.C. | 56,951 | 10,359 |
| 038 | UTP | 51,285 | 6,433 |
| 084 | BOTICAS IP S.A.C. | 42,301 | 7,439 |
| 048 | MIFARMA | 34,075 | 10,504 |
| 024 | PROMART | 25,947 | 4,899 |
| 021 | INNOVA SCHOOL | 25,570 | 3,408 |
| 013 | CINEPLANET | 23,088 | 9,993 |
| 085 | COMPAÑIA HARD DISCOUNT S.A.C. (Mass) | 19,673 | 4,474 |
| ... | *otros 57 empresas* | ... | ... |
| **TOTAL** | **67 empresas distintas** | **684,280** | **88,991** |

## Empresas donde se usa el beneficio (empresa_beneficio)

| empresa_beneficio | Empresa | Registros |
|---|---|---|
| 000 | INTERBANK | 323,046 (47%) |
| 025 | INKAFARMA | 176,254 (26%) |
| 013 | CINEPLANET | 59,750 (9%) |
| 033 | NGRESTAURANT | 46,059 (7%) |
| 048 | MIFARMA | 40,309 (6%) |
| 038 | UTP | 27,864 (4%) |
| 041 | IPAE | 8,082 (1%) |
| 064 | IDAT | 2,438 |
| 014 | CASA ANDINA | 301 |
| 018 | INTELIGO SAB | 131 |
| 005 | CSPE (Centros de Salud) | 28 |
| 021 | INNOVA SCHOOL | 18 |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `empresa_labora` | STRING | **Empresa donde trabaja el empleado** (código `itc_company_id` de 3 dígitos). 67 valores distintos. | 0% NULL |
| `party_id` | STRING | **Identificador del empleado** en el ecosistema Intercorp. **No es DNI** — es el ID interno Intercorp. Join con `iden_itc_party` para obtener `id` (DNI). | 0% NULL |
| `numero_redenciones` | STRING | Número de veces que el empleado usó el beneficio en el mes (guardado como STRING). Ej: `"1"`, `"3"`. | 0% NULL |
| `importe_total` | STRING | Monto total gastado en el mes (STRING con 3 decimales). Ej: `"65.000"`, `"52.000"`. **Convertir a FLOAT para cálculos.** | 0% NULL |
| `descuento_total` | STRING | Monto total de descuento aplicado en el mes (STRING). Ej: `"12.000"`, `"24.000"`. | 0% NULL |
| `empresa_beneficio` | STRING | **Empresa donde se usó el beneficio** (código `itc_company_id` de 3 dígitos). 12 valores. | 0% NULL |
| `fecha_registro` | STRING | **Mes de registro** de las ventas (formato `YYYY-MM-DD`, siempre el día 1 del mes). Granularidad mensual. | 0% NULL |
| `fecha_proceso` | DATE | Fecha de carga/procesamiento ETL en BigQuery. Puede ser varios meses posterior a `fecha_registro`. | 0% NULL |
| `fecha_carga` | TIMESTAMP | Timestamp exacto de inserción en BigQuery. | 0% NULL |
| `usuario_creacion` | STRING | Service account ETL: `prd-itc-dp-matillion-integrati@...` | 0% NULL |
| `origen_registro` | STRING | Nombre del archivo fuente de carga (ej: `T_VENTAS_NORETAIL_2025_05.txt`). 1.5% NULL. | 1.5% NULL |
| `producto` | STRING | Descripción del producto donde se aplicó el beneficio. | **100% NULL** |

---

## Fuentes de datos (origen_registro)

Los datos provienen de archivos planos cargados mensualmente via Matillion:

| Archivo origen | Registros | Descripción |
|---|---|---|
| `T_VENTAS_INTERBANK2025.txt` | 230,945 | Beneficios en Interbank — 2025 |
| `T_VENTAS_NORETAIL_2024_07.txt` | 154,769 | No-retail genérico — Jul 2024 |
| `T_VENTAS_NORETAIL_2023.txt` | 138,521 | No-retail histórico — 2023 |
| `T_VENTAS_CINEPLANET2025.txt` | 22,923 | Beneficios en Cineplanet — 2025 |
| `T_VENTAS_NORETAIL_2024_*.txt` | ~67K total | No-retail mensual 2024 (Nov-Dic) |
| `T_VENTAS_NORETAIL_2025_*.txt` | ~46K total | No-retail mensual 2025 |
| `T_VENTAS_INTELIGO2025.txt` | 131 | Beneficios en Inteligo |
| `T_VENTAS_CASAANDINA2025.txt` | 31 | Beneficios en Casa Andina |
| `T_VENTAS_AVIVA_10_25.txt` | 28 | Beneficios en Aviva (Médicos) |
| `(NULL)` | 10,105 | Sin origen registrado (1.5%) |

---

## Diferencias con otras tablas de transacciones

| Característica | `t_retail_transaction` | `t_experience_transaction` | `t_ventas_noretail` |
|---|---|---|---|
| **Sujeto** | Clientes externos | Clientes externos | **Empleados Intercorp** |
| **Granularidad** | Por ítem de transacción | Por ítem de transacción | **Por mes-empleado** |
| **Clave de cliente** | `id` (DNI) | `id` (DNI) | `party_id` (ID interno) |
| **Partición** | `transaction_date` | `transaction_date` | **Sin partición** |
| **Tamaño** | ~4.7B filas | ~577M filas | 684K filas |
| **Empresas** | 5 retail | 2 entretenimiento | **67 empleadoras / 12 beneficio** |
| **Monto** | FLOAT64 | FLOAT64 | STRING (convertir) |
| **Producto** | Detallado por SKU | Detallado por ítem | **100% NULL** |

---

## Reglas de negocio

1. **Sin partición — tabla pequeña**: La tabla tiene solo 684K filas. No requiere filtro de fecha para escaneos completos (es barata de consultar).

2. **Granularidad mensual**: Cada fila representa el **total del mes** para un empleado en una empresa beneficio. No hay detalle de transacciones individuales dentro del mes.

3. **`party_id`, no `id`**: La clave de empleado es `party_id` (identificador interno Intercorp). Para cruzar con tablas que usan `id` (DNI), hacer join con `iden_itc_party`:
   ```sql
   JOIN `intercorp-data-storage-pv.master_party.iden_itc_party` i
     ON t.party_id = i.party_id
   ```

4. **`importe_total` y `descuento_total` son STRING**: Convertir siempre antes de operar:
   ```sql
   CAST(importe_total AS FLOAT64) AS importe_total
   CAST(descuento_total AS FLOAT64) AS descuento_total
   ```

5. **`fecha_registro` es STRING en formato YYYY-MM-DD**: Para filtrar por mes:
   ```sql
   WHERE fecha_registro >= '2025-01-01' AND fecha_registro <= '2025-12-01'
   ```
   O convertir: `PARSE_DATE('%Y-%m-%d', fecha_registro)`.

6. **`empresa_labora` ≠ `empresa_beneficio`**: El cruce entre empresa donde trabaja y empresa donde usa el beneficio permite analizar movilidad de empleados entre empresas del grupo.

7. **`producto` siempre NULL**: No usar para filtrar o analizar productos. Dato no disponible en la fuente actual.

8. **Rezago de carga**: Los datos de un mes pueden llegar varios meses después. `fecha_registro = '2025-10-01'` puede tener `fecha_proceso = '2026-01-28'` (3 meses de rezago en algunos archivos).

9. **67 empresas empleadoras**: Cubre prácticamente todas las empresas del grupo Intercorp (ver `relacion_company_ids.csv`). Interbank (000) es la mayor empleadora por registros.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| `producto` 100% NULL | Campo no poblado en la fuente. No usar. |
| Tipos de dato inconsistentes | `importe_total`, `descuento_total`, `numero_redenciones` son STRING en lugar de FLOAT/INT. Convertir explícitamente. |
| `fecha_registro` como STRING | Podría causar errores en filtros de fecha. Convertir con `PARSE_DATE`. |
| Rezago variable de carga | El lag entre `fecha_registro` y `fecha_proceso` varía por empresa fuente: Interbank más rápido, otras más lentas. |
| Origen NULL (10,105 filas) | 1.5% de registros sin archivo de origen identificado — no permite trazabilidad de esos registros. |
| `numero_redenciones` como STRING | Contiene valores numéricos enteros. Convertir a INT64 para cálculos: `CAST(numero_redenciones AS INT64)`. |
| Histórico desde 2023 | Los datos de 2023-2024 están consolidados en archivos anuales, los de 2025 en archivos mensuales. |

---

## Queries de referencia

```sql
-- Beneficios usados por empresa (mes más reciente disponible)
SELECT empresa_labora, empresa_beneficio,
  COUNT(*) as empleados,
  SUM(CAST(numero_redenciones AS INT64)) as total_usos,
  ROUND(SUM(CAST(importe_total AS FLOAT64)), 2) as monto_total,
  ROUND(SUM(CAST(descuento_total AS FLOAT64)), 2) as descuento_total
FROM `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`
WHERE fecha_registro = '2025-12-01'
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- Empleados de Inkafarma que usan beneficio en Interbank
SELECT party_id,
  CAST(numero_redenciones AS INT64) as usos,
  CAST(importe_total AS FLOAT64) as monto,
  CAST(descuento_total AS FLOAT64) as descuento,
  fecha_registro
FROM `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`
WHERE empresa_labora = '025'
  AND empresa_beneficio = '000'
  AND fecha_registro >= '2025-01-01'
ORDER BY fecha_registro DESC;

-- Cruce con iden_itc_party para obtener DNI del empleado
SELECT v.party_id, i.id AS dni, v.empresa_labora, v.empresa_beneficio,
  CAST(v.importe_total AS FLOAT64) AS monto,
  CAST(v.descuento_total AS FLOAT64) AS descuento,
  v.fecha_registro
FROM `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail` v
JOIN `intercorp-data-storage-pv.master_party.iden_itc_party` i
  ON v.party_id = i.party_id
WHERE v.fecha_registro >= '2025-01-01'
  AND v.empresa_beneficio = '013'  -- Cineplanet
ORDER BY CAST(v.importe_total AS FLOAT64) DESC;

-- Tendencia mensual de beneficios (todos los meses disponibles)
SELECT PARSE_DATE('%Y-%m-%d', fecha_registro) as mes,
  empresa_beneficio,
  COUNT(DISTINCT party_id) as empleados,
  SUM(CAST(numero_redenciones AS INT64)) as usos,
  ROUND(SUM(CAST(importe_total AS FLOAT64)), 2) as monto_total
FROM `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`
GROUP BY 1, 2
ORDER BY 1 DESC, 3 DESC;

-- Empleados con mayor uso de beneficios (top 50)
SELECT party_id, empresa_labora,
  COUNT(DISTINCT empresa_beneficio) as empresas_beneficio,
  SUM(CAST(numero_redenciones AS INT64)) as total_usos,
  ROUND(SUM(CAST(importe_total AS FLOAT64)), 2) as monto_total_historico,
  ROUND(SUM(CAST(descuento_total AS FLOAT64)), 2) as descuento_total
FROM `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`
GROUP BY 1, 2
ORDER BY total_usos DESC
LIMIT 50;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.raw_itcm_sitc.t_ventas_noretail`*
