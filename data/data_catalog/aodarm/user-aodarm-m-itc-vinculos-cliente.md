# Catálogo de Datos — `m_itc_vinculos_cliente`

**Proyecto:** `int-advanced-analytics-01`
**Dataset:** `aodarm`
**Tabla completa:** `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
**Prefijo de archivo:** `user_aodarm_` (tabla en esquema de usuario)

---

## Descripción

Maestro de **vínculos entre clientes** del ecosistema Intercorp. Cada fila representa un par de personas (`persona_1`, `persona_2`) que tienen una relación detectada algorítmicamente, clasificada por tipo de relación probable (pareja, padre-hijo, abuelo-nieto, otro) e intensidad de la relación.

Permite enriquecer perfiles de cliente con su red de vínculos familiares: identificar parejas que compran juntas, detectar unidades familiares completas (padres + hijos), construir segmentos por composición del hogar, y personalizar campañas considerando el contexto familiar del cliente.

Los vínculos son **inferidos** a partir del comportamiento de compra compartido — no son datos declarados. La relación se identifica cuando dos personas compran en los mismos lugares, horarios y productos de manera consistente.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | **NO** |
| Clusterizado | NO |
| Total de filas | 3,540,868 |
| Número de columnas | 5 |
| Tamaño lógico | ~174 MB |
| Tamaño físico | ~33 MB |
| Última `recencia` | 2026-01-31 |
| Primera `recencia` | 2024-01-01 |
| Nulos | **0 en todos los campos** |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Valores | Calidad |
|---|---|---|---|---|
| `persona_1` | STRING | **Identificador de la primera persona** del vínculo. Puede ser `party_id` o DNI según la fuente | Numérico como string. Ej: `"123866679"`, `"1415227103"` | 0% NULL |
| `persona_2` | STRING | **Identificador de la segunda persona** vinculada a `persona_1` | Numérico como string | 0% NULL |
| `tipo_relacion_probable` | STRING | **Tipo de relación inferida** entre las dos personas | Ver tabla abajo | 0% NULL |
| `intensidad_relacion` | STRING | **Intensidad** del vínculo detectado | `BAJO`, `MEDIO`, `ALTA` | 0% NULL |
| `recencia` | DATE | **Fecha de la última interacción compartida** registrada entre el par. Indica qué tan reciente es la evidencia del vínculo | 2024-01-01 a 2026-01-31 (762 fechas distintas) | 0% NULL |

---

## Distribución de tipos de relación

| `tipo_relacion_probable` | Registros | % |
|---|---|---|
| `PAREJA MUY PROBABLE` | 1,077,591 | 30.4% |
| `PADRE - HIJO` | 940,287 | 26.6% |
| `OTRO` | 804,854 | 22.7% |
| `PAREJA PROBABLE` | 640,001 | 18.1% |
| `ABUELO - NIETO` | 78,135 | 2.2% |

> La distinción entre `PAREJA MUY PROBABLE` y `PAREJA PROBABLE` refleja el nivel de evidencia acumulada: a mayor co-ocurrencia en compras, mayor probabilidad de pareja.

## Distribución de intensidad de relación

| `intensidad_relacion` | Registros | % |
|---|---|---|
| `BAJO` | 2,228,788 | 62.9% |
| `MEDIO` | 849,906 | 24.0% |
| `ALTA` | 462,174 | 13.1% |

---

## Cardinalidad

| Métrica | Valor |
|---|---|
| Total de pares únicos | 3,540,868 |
| `persona_1` distintos | 2,488,106 |
| `persona_2` distintos | 2,463,386 |
| Personas únicas total (union) | ~3M (estimado) |

> Los IDs en `persona_1` y `persona_2` no son mutuamente excluyentes: una persona puede aparecer como `persona_1` en un par y como `persona_2` en otro.

---

## Reglas de negocio

1. **Sin partición** — tabla pequeña (~174MB). Escanear completa es viable y económico.

2. **La relación es direccional en la tabla pero simétrica en significado**: El par `(A, B)` y `(B, A)` representan el mismo vínculo. Antes de cruzar con otras tablas, considerar si hace falta buscar en ambas direcciones:
   ```sql
   WHERE persona_1 = 'X' OR persona_2 = 'X'
   ```

3. **`recencia` como señal de vigencia del vínculo**: Vínculos con `recencia < 90 días` tienen mayor probabilidad de seguir activos. Vínculos con `recencia > 365 días` pueden estar inactivos o corresponder a relaciones pasadas.

4. **`intensidad_relacion = 'ALTA'`**: Los 462K pares con intensidad alta son los vínculos más sólidos — mayor co-ocurrencia y menor variabilidad en el patrón de compra compartido.

5. **Casos de uso principales**:
   - **Campaña familiar**: Si se activa a `persona_1`, considerar ofrecer el mismo producto/servicio a `persona_2` (cross-sell familiar).
   - **Construcción de hogar**: Agrupar todos los pares de una persona para estimar la composición del hogar (número de integrantes, generaciones).
   - **Filtro de duplicados**: Un cliente `persona_1` que compra en pareja (PAREJA MUY PROBABLE) puede compartir decisiones de compra → la campaña dirigida a uno influye en el otro.

6. **`tipo_relacion_probable = 'OTRO'`**: 22.7% de los pares no encajan en las categorías familiares definidas. Pueden ser amigos, compañeros de trabajo, o relaciones de compra eventual.

7. **`persona_1` y `persona_2` son IDs del formato del ecosistema Intercorp** — pueden ser `party_id` o DNI dependiendo de la fuente que generó el vínculo. Verificar cruzando con `iden_itc_party` para distinguir.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| 0% NULLs | Todos los campos están completamente poblados — alta calidad de datos |
| Vínculos inferidos | La relación es probabilística — `tipo_relacion_probable` es una estimación. No es un dato declarado por el cliente. |
| Sin fecha de creación del vínculo | Solo hay `recencia` (última co-ocurrencia). No es posible saber cuándo se detectó por primera vez el vínculo. |
| `OTRO` sin subclasificación | 804K pares no clasificables en familia — los casos de uso con este tipo son más limitados. |
| Sin `process_date` | No hay control de versión temporal. La tabla refleja el estado actual del modelo de vínculos. |
| Pares posiblemente duplicados | No se verifica si `(A, B)` y `(B, A)` coexisten. Deduplicar si se necesita conteo único de pares. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `intercorp-data-storage-pv.master_party.iden_itc_party` | `persona_1` / `persona_2` = `party_id` o `id` | Obtener DNI o datos adicionales de cada persona vinculada |
| `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic` | `persona_1` / `persona_2` = `id` | Enriquecer con datos demográficos (edad, NSE) de cada integrante del vínculo |
| `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc` | `persona_1` / `persona_2` = `id` | Obtener segmento, consumo y perfil completo del par |

---

## Queries de referencia

```sql
-- Todos los vínculos de un cliente (en cualquier posición del par)
SELECT
  CASE WHEN persona_1 = '12345678' THEN persona_2 ELSE persona_1 END AS persona_vinculada,
  tipo_relacion_probable,
  intensidad_relacion,
  recencia
FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
WHERE persona_1 = '12345678' OR persona_2 = '12345678'
ORDER BY recencia DESC;

-- Parejas con alta intensidad activas en últimos 90 días
SELECT persona_1, persona_2, tipo_relacion_probable, recencia
FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
WHERE tipo_relacion_probable IN ('PAREJA MUY PROBABLE', 'PAREJA PROBABLE')
  AND intensidad_relacion = 'ALTA'
  AND recencia >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY);

-- Distribución de vínculos por tipo e intensidad
SELECT tipo_relacion_probable, intensidad_relacion,
  COUNT(*) as pares,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY tipo_relacion_probable), 2) as pct_intensidad
FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
GROUP BY 1, 2
ORDER BY 1, 3 DESC;

-- Personas con más vínculos (posibles "nodos" familiares o sociales)
SELECT persona_id, COUNT(*) as total_vinculos,
  COUNT(CASE WHEN tipo_relacion_probable LIKE '%PAREJA%' THEN 1 END) as vinculos_pareja,
  COUNT(CASE WHEN tipo_relacion_probable = 'PADRE - HIJO' THEN 1 END) as vinculos_hijo
FROM (
  SELECT persona_1 AS persona_id, tipo_relacion_probable FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
  UNION ALL
  SELECT persona_2, tipo_relacion_probable FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente`
)
GROUP BY 1
ORDER BY total_vinculos DESC
LIMIT 50;

-- Unidades familiares: padres con hijos (enriquecer con datos demográficos)
SELECT v.persona_1 AS padre, v.persona_2 AS hijo,
  d1.edad AS edad_padre, d2.edad AS edad_hijo,
  v.intensidad_relacion, v.recencia
FROM `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente` v
LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic` d1
  ON v.persona_1 = d1.id AND d1.process_date = '2026-02-01'
LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic` d2
  ON v.persona_2 = d2.id AND d2.process_date = '2026-02-01'
WHERE v.tipo_relacion_probable = 'PADRE - HIJO'
  AND v.intensidad_relacion IN ('MEDIA', 'ALTA')
ORDER BY v.recencia DESC;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `int-advanced-analytics-01.aodarm.m_itc_vinculos_cliente` — Tabla de usuario (esquema `aodarm`)*
