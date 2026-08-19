# Catálogo de Datos — `ba_itc_attr_prediction`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`

---

## Descripción

Predicciones demográficas y de comportamiento del cliente. Contiene atributos inferidos por modelos de ML: datos demográficos estimados (género, edad, ubicación, estado civil), propensión a ser delivery lover, Intercorp lover, propietario de vivienda y el mes estimado del bebé para clientes gestantes o con infante reciente.

A diferencia de `ba_itc_attr_demographic` (datos declarados/fuentes externas como RENIEC), esta tabla contiene atributos **inferidos por modelos** a partir del comportamiento de compra. El campo `flag_active` indica si la predicción sigue vigente.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~554M |
| Columnas | 21 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |
| `record_source` | `"BA_CUSTOMER_PREDICTION"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `id` | STRING | Documento de identidad del cliente |
| `creation_user` | STRING | SA que ejecutó la carga |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `record_source` | STRING | Origen del registro. Valor: `"BA_CUSTOMER_PREDICTION"` |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

---

## 2. Atributos demográficos predichos

| Campo | Tipo | Descripción |
|---|---|---|
| `genero` | STRING | Género predicho del cliente: `"M"` / `"F"` |
| `edad` | STRING | Rango de edad predicho (ej: `"25-34"`) |
| `fecha_nacimiento` | DATE | Fecha de nacimiento estimada |
| `departamento` | STRING | Departamento de residencia predicho |
| `provincia` | STRING | Provincia de residencia predicha |
| `distrito` | STRING | Distrito de residencia predicho |
| `estado_civil` | STRING | Estado civil predicho |
| `propietario_vivienda` | STRING | `"SÍ"` / `"NO"` — propietario de vivienda estimado |

---

## 3. Atributos de comportamiento predichos

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_intercorp_lover_retail` | STRING | `"SÍ"` = cliente fidelizado retail Intercorp. Alta proporción de compras en empresas del grupo vs. externas |
| `flag_delivery_lover_retail` | STRING | `"SÍ"` = compra habitualmente por delivery en tiendas retail Intercorp |
| `mes_bebe` | STRING | Mes estimado de nacimiento del bebé (formato `YYYY-MM-DD`). Indica cliente gestante o con infante reciente |

---

## 4. Control de versión y vigencia

| Campo | Tipo | Descripción |
|---|---|---|
| `version` | BYTES | Hash de versión del registro para control de cambios |
| `flag_active` | BOOLEAN | `true` = predicción activa/vigente. `false` = reemplazada o desactivada |

---

## 5. Queries de referencia

```sql
-- Clientes delivery lovers con predicción activa
SELECT id, genero, edad, distrito, flag_delivery_lover_retail
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`
WHERE process_date = '2026-05-01'
  AND flag_delivery_lover_retail = 'SÍ'
  AND flag_active = true;

-- Clientes con embarazo predicho activo (próximos 3 meses desde referencia)
SELECT id, mes_bebe, genero, distrito, departamento
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`
WHERE process_date = '2026-05-01'
  AND mes_bebe IS NOT NULL
  AND flag_active = true
ORDER BY mes_bebe;

-- Intercorp lovers por departamento
SELECT departamento, COUNT(DISTINCT id) AS clientes_leales
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`
WHERE process_date = '2026-05-01'
  AND flag_intercorp_lover_retail = 'SÍ'
  AND flag_active = true
GROUP BY 1
ORDER BY 2 DESC;

-- Distribución de género en predicciones activas
SELECT genero, COUNT(DISTINCT id) AS clientes,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`
WHERE process_date = '2026-05-01'
  AND flag_active = true
GROUP BY 1;

-- Propietarios de vivienda por rango de edad
SELECT edad, propietario_vivienda, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`
WHERE process_date = '2026-05-01'
  AND flag_active = true
GROUP BY 1, 2
ORDER BY 1, 2;
```

---

## 6. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Filtrar `flag_active = true`** para análisis y campañas — excluye predicciones reemplazadas o con baja confianza.
3. **Atributos son predichos, no declarados**: Pueden diferir de documentos de identidad o formularios. Cruzar con `ba_itc_attr_demographic` para atributos oficiales.
4. **`flag_delivery_lover_retail` y `flag_intercorp_lover_retail` son STRING** (`"SÍ"`/`"NO"`), no INTEGER. Comparar con `= 'SÍ'`, no con `= 1`.
5. **`mes_bebe IS NOT NULL`**: Predicción de embarazo o infante. Dato volátil — puede desaparecer en el siguiente snapshot si el período estimado ya pasó.
6. **`edad` es STRING de rango**: No es un entero. Para filtros numéricos, parsear el rango o usar `fecha_nacimiento`.
7. **`version` de tipo BYTES**: Sirve para detectar si el registro fue actualizado entre snapshots. No usar para joins.
8. **Diferencia con `ba_customer_prediction`**: Esta tabla es columnar (un atributo = una columna). `ba_customer_prediction` usa formato EAV. Ambas pueden tener predicciones de `mes_bebe` — verificar consistencia.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction`*
