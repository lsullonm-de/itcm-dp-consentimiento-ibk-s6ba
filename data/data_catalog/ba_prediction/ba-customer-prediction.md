# Catálogo de Datos — `ba_customer_prediction`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `ba_prediction`
**Tabla completa:** `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`

> **Nota de dataset**: Esta tabla está en el dataset `ba_prediction`, **no** en `bi_itc_attribute_party` como las demás tablas `ba_itc_attr_*`. Tener en cuenta al construir JOINs.

---

## Descripción

Predicciones analíticas del cliente en formato **EAV (Entity-Attribute-Value)**. En lugar de una columna por atributo predicho, cada fila representa un atributo predicho para un cliente en una ejecución del modelo. El campo `atributo_nombre` identifica qué se predice y `atributo_valor` contiene el resultado.

Actualmente el atributo principal es `"MES_BEBE"` — mes estimado del nacimiento del bebé para clientes gestantes o con infante reciente. La tabla es extensible: nuevos atributos se incorporan como nuevas filas sin alterar el esquema.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `fecha_ejecucion` (DAY) — fecha de corrida del modelo (NO es `process_date`) |
| Clusterizado por | — |
| Filas aprox. | ~264M |
| Columnas | 14 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Variable (según ejecuciones de modelos) |
| `record_source` | `"MATILLION"` |

---

## 1. Identificadores

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente |
| `id_ejecucion` | STRING | ID único de la ejecución del modelo (para trazabilidad y linaje) |

---

## 2. Partición y control temporal

| Campo | Tipo | Descripción |
|---|---|---|
| `fecha_ejecucion` | DATE | **Campo de partición**. Fecha en que se ejecutó el modelo. No equivale a `process_date` mensual |
| `periodo_inicio` | TIMESTAMP | Inicio del período de validez de la predicción |
| `periodo_fin` | TIMESTAMP | Fin del período de validez de la predicción |
| `periodo_inicio_ejecucion` | TIMESTAMP | Inicio del período de datos usado en la ejecución del modelo |
| `periodo_fin_ejecucion` | TIMESTAMP | Fin del período de datos usado en la ejecución |
| `fecha_vigencia` | TIMESTAMP | Hasta cuándo es válida esta predicción |

---

## 3. Estructura EAV del atributo predicho

| Campo | Tipo | Descripción |
|---|---|---|
| `atributo_nombre` | STRING | Nombre del atributo predicho. Ejemplo: `"MES_BEBE"` |
| `atributo_valor` | STRING | Valor de la predicción. Para `MES_BEBE`: fecha estimada del nacimiento en formato `YYYY-MM-DD` |

### Atributos actualmente disponibles

| `atributo_nombre` | `atributo_valor` (ejemplo) | Descripción |
|---|---|---|
| `MES_BEBE` | `"2025-08-01"` | Mes estimado de nacimiento del bebé. La fecha apunta al primer día del mes estimado |

> La estructura EAV permite incorporar nuevos atributos predichos sin cambiar el esquema de la tabla.

---

## 4. Estado y vigencia

| Campo | Tipo | Descripción |
|---|---|---|
| `estado` | BOOLEAN | `true` = predicción activa/vigente. `false` = desactivada, reemplazada o expirada |

---

## 5. Auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `record_source` | STRING | Origen del registro. Valor: `"MATILLION"` |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |

---

## 6. Formato EAV vs. columnar

```sql
-- Formato EAV (esta tabla: ba_customer_prediction)
id      | atributo_nombre | atributo_valor  | estado
123456  | MES_BEBE        | 2025-08-01      | true

-- Equivalente columnar (ba_itc_attr_prediction)
id      | mes_bebe   | flag_active
123456  | 2025-08-01 | true
```

**Ventajas del EAV**: Permite agregar nuevas predicciones sin alterar el esquema. Un nuevo modelo de ML solo agrega filas con un nuevo `atributo_nombre`.

**Desventajas**: Más complejo de consultar — siempre requiere filtrar por `atributo_nombre`. No permite consultar varios atributos en una sola fila sin pivotear.

---

## 7. Queries de referencia

```sql
-- Clientes con predicción MES_BEBE activa
SELECT id, atributo_valor AS mes_bebe_estimado,
       fecha_ejecucion, fecha_vigencia, id_ejecucion
FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
WHERE fecha_ejecucion = (
  SELECT MAX(fecha_ejecucion)
  FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
)
  AND atributo_nombre = 'MES_BEBE'
  AND estado = true
ORDER BY atributo_valor;

-- Clientes con bebé esperado en los próximos 2 meses
SELECT id, atributo_valor AS mes_bebe_estimado, fecha_vigencia
FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
WHERE atributo_nombre = 'MES_BEBE'
  AND estado = true
  AND SAFE.PARSE_DATE('%Y-%m-%d', atributo_valor) BETWEEN CURRENT_DATE()
      AND DATE_ADD(CURRENT_DATE(), INTERVAL 2 MONTH)
ORDER BY atributo_valor;

-- Cantidad de clientes por mes estimado del bebé (en la última ejecución)
SELECT atributo_valor AS mes_bebe, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
WHERE fecha_ejecucion = (
  SELECT MAX(fecha_ejecucion)
  FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
)
  AND atributo_nombre = 'MES_BEBE'
  AND estado = true
GROUP BY 1
ORDER BY 1;

-- Cruce con datos de contacto para campaña de maternidad
SELECT bc.id,
       bc.atributo_valor AS mes_bebe,
       ac.hash_email,
       ac.cell_phone,
       ac.full_name
FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction` bc
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact` ac
  ON bc.id = ac.id AND ac.process_date = '2026-05-01'
     AND ac.flag_intercorp_authorized = true
WHERE bc.atributo_nombre = 'MES_BEBE'
  AND bc.estado = true
  AND bc.fecha_ejecucion = (
    SELECT MAX(fecha_ejecucion)
    FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
  )
  AND ac.hash_email IS NOT NULL;

-- Todas las ejecuciones disponibles y sus atributos
SELECT fecha_ejecucion, atributo_nombre,
  COUNT(DISTINCT id) AS clientes, COUNT(*) AS filas
FROM `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`
GROUP BY 1, 2
ORDER BY 1 DESC, 2;
```

---

## 8. Reglas de negocio

1. **Particionar por `fecha_ejecucion`**, no por `process_date` — esta tabla no tiene `process_date`. Siempre filtrar por fecha de ejecución para controlar el costo de la query.
2. **Filtrar `estado = true`**: Solo predicciones activas en campañas. `false` = versiones anteriores o expiradas.
3. **Filtrar por `atributo_nombre`**: Siempre incluir `WHERE atributo_nombre = 'MES_BEBE'` (o el atributo deseado). Sin este filtro se leen todos los atributos disponibles.
4. **`atributo_valor` para `MES_BEBE`** contiene la fecha estimada como STRING en formato `YYYY-MM-DD`. Usar `SAFE.PARSE_DATE('%Y-%m-%d', atributo_valor)` para operar con fechas.
5. **Tabla acumulativa**: No reemplaza particiones anteriores — acumula ejecuciones históricas. Para la predicción vigente, usar `MAX(fecha_ejecucion)` o filtrar por la ejecución conocida.
6. **`id_ejecucion`**: Identifica de forma unívoca cada corrida del modelo. Útil para auditoría y linaje — permite rastrear qué version del pipeline generó cada predicción.
7. **Diferencia con `ba_itc_attr_prediction`**: El campo `mes_bebe` en `ba_itc_attr_prediction` es la versión columnar de esta predicción. Puede haber inconsistencias si los modelos se actualizan a distinta frecuencia — esta tabla (`ba_customer_prediction`) es la fuente origen.
8. **Dataset diferente**: Está en `ba_prediction`, no en `bi_itc_attribute_party`. Al cruzar con tablas `ba_itc_attr_*`, especificar el dataset completo en cada tabla del JOIN.
9. **Nuevos atributos**: Cuando se incorpore una nueva predicción (ej: `DEPORTISTA`, `SENIOR`), aparecerá como nuevas filas con un `atributo_nombre` diferente. No se altera el esquema.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.ba_prediction.ba_customer_prediction`*
