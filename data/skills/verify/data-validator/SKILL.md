# Skill: Data Validator

> **Rol:** Validador de Resultados — Analista de Negocio IA
> **Activado por:** El orquestador `Business Analyst Agent` después de recibir los resultados del query BigQuery
> **Posición en el pipeline:** SQL Translator → **Data Validator** → Visualization Developer / Insights Narrator

---

## 1. Rol

El **Data Validator** recibe los resultados del query ejecutado y verifica que sean correctos,
completos y coherentes con lo que el usuario solicitó. No modifica los datos — emite un
veredicto y anota anomalías para que los agentes siguientes los comuniquen apropiadamente.

Es el único agente del pipeline que puede devolver control al SQL Translator si detecta
un problema grave (`status: FAIL`).

---

## 2. Input — Formato de Entrada

El input puede llegar de dos fuentes según cómo se ejecutó el query:

### 2.1 — Desde MCP BigQuery (Claude Code embebido)

El resultado llega como respuesta directa de la herramienta MCP:

```json
{
  "source": "mcp_bigquery",
  "query_metadata": {
    "bytes_processed": 15728640,
    "rows_returned": 248,
    "execution_time_ms": 1823,
    "query": "SELECT ...",
    "parameters": {
      "fecha_ini": "2026-01-01",
      "fecha_fin": "2026-03-31",
      "empresa": "010"
    }
  },
  "schema": [
    {"name": "empresa", "type": "STRING"},
    {"name": "mes", "type": "DATE"},
    {"name": "monto_total", "type": "FLOAT64"},
    {"name": "num_transacciones", "type": "INT64"}
  ],
  "rows": [
    {"empresa": "010", "mes": "2026-01-01", "monto_total": 45230187.5, "num_transacciones": 312400},
    {"empresa": "010", "mes": "2026-02-01", "monto_total": 41987345.2, "num_transacciones": 298100}
  ]
}
```

### 2.2 — Desde BigQuery Client API (agente externo)

El resultado llega como objeto JSON de la librería `google-cloud-bigquery` o REST API:

```json
{
  "source": "bigquery_client",
  "query_metadata": {
    "job_id": "project:region.job_id_abc123",
    "total_bytes_processed": "15728640",
    "total_rows": "248",
    "schema": {
      "fields": [
        {"name": "empresa", "type": "STRING", "mode": "NULLABLE"},
        {"name": "mes", "type": "DATE", "mode": "NULLABLE"},
        {"name": "monto_total", "type": "FLOAT", "mode": "NULLABLE"},
        {"name": "num_transacciones", "type": "INTEGER", "mode": "NULLABLE"}
      ]
    }
  },
  "rows": [
    ["010", "2026-01-01", 45230187.5, 312400],
    ["010", "2026-02-01", 41987345.2, 298100]
  ]
}
```

### 2.3 — Normalización del input

Independientemente de la fuente, **normalizar a estructura común** antes de validar:

```python
# Estructura normalizada interna del validador
dataset = {
    "columns": ["empresa", "mes", "monto_total", "num_transacciones"],
    "types":   {"empresa": "STRING", "mes": "DATE",
                "monto_total": "FLOAT", "num_transacciones": "INT"},
    "rows": [
        {"empresa": "010", "mes": "2026-01-01", "monto_total": 45230187.5, "num_transacciones": 312400},
        ...
    ],
    "total_rows": 248,
    "bytes_processed": 15728640
}
```

**Contexto adicional requerido** (entregado por el orquestador junto con el resultado):

```json
{
  "requerimiento_original": "Ventas mensuales SPSA del Q1 2026",
  "tipo_usuario": "analista_operacion",
  "spec_tecnica": {
    "tablas": ["t_retail_transaction"],
    "filtros": {"itc_company_id": "010", "periodo": "2026-01-01 a 2026-03-31"},
    "granularidad": "mensual",
    "metricas_esperadas": ["monto_total", "num_transacciones"],
    "filas_esperadas_aprox": "3 filas (3 meses)"
  },
  "datos_referencia": {
    "periodo_anterior": "Q1 2025",
    "monto_referencia_aprox": 130000000
  }
}
```

---

## 3. Checks de Validación

Ejecutar todos los checks aplicables en paralelo. Cada check produce:
`{"check": "nombre", "status": "PASS|WARN|FAIL", "detalle": "mensaje"}`

### CHECK-01 — Resultado no vacío

```
¿El dataset retornó al menos 1 fila?

PASS: rows > 0
FAIL: rows = 0
  → Detalle: "El query no retornó datos para el período {fecha_ini} a {fecha_fin}.
    Posibles causas: (1) no hay datos en ese rango, (2) filtro incorrecto,
    (3) partición no coincide con el campo usado."
```

### CHECK-02 — Completitud temporal

```
¿Hay datos para todos los períodos del rango solicitado?

Ejemplo: si se pidió Q1 2026 con granularidad mensual → esperar enero, febrero, marzo.

PASS: todos los períodos tienen datos
WARN: faltan períodos pero hay datos parciales
  → Detalle: "Faltan datos para {períodos_faltantes}. El resultado es parcial."
FAIL: más del 50% de los períodos están vacíos
```

### CHECK-03 — Cobertura de dimensiones

```
¿Están presentes todas las empresas/tiendas/segmentos solicitados?

PASS: todas las dimensiones esperadas aparecen en el resultado
WARN: falta alguna dimensión
  → Detalle: "No hay datos para {dimensión_faltante} en el período solicitado."
```

### CHECK-04 — Nulos en campos clave

```
¿Hay NULL en columnas que no deberían tenerlos (métricas, IDs)?

PASS: 0 nulos en columnas de métrica
WARN: < 5% de filas con nulos en columnas de métrica
FAIL: > 5% de filas con nulos en columnas clave
  → Detalle: "La columna {columna} tiene {N}% de valores nulos."
```

### CHECK-05 — Outliers numéricos

```
¿Algún valor de métrica es estadísticamente inusual?

Método: comparar con rango esperado si hay datos de referencia.
Si no hay referencia: marcar valores que superen 10x el promedio del mismo resultado.

PASS: todos los valores dentro de rango plausible
WARN: valor(es) atípicos detectados
  → Detalle: "{campo} = {valor} en {dimensión} parece anómalo
    (promedio del período: {promedio}, diferencia: {pct}x)."
```

### CHECK-06 — Sanity de totales

```
Si el resultado tiene subtotales y totales (ROLLUP), ¿suman correctamente?

PASS: subtotales cuadran con total (tolerancia ±0.1% por redondeo)
WARN: diferencia entre 0.1% y 1%
FAIL: diferencia > 1%
  → Detalle: "La suma de subtotales ({suma_sub}) no coincide con el total
    reportado ({total}). Diferencia: {pct}%."
```

### CHECK-07 — Variación vs período de referencia

```
Si el requerimiento incluye comparativo (YoY, MoM), ¿la variación es plausible?

PASS: variación dentro de [-90%, +300%]
WARN: variación en [-90%, -50%] o [+300%, +1000%] — posible pero llamativa
FAIL: variación fuera de [-90%, +1000%] — probable error de query o datos
  → Detalle: "{métrica} muestra variación de {pct}% vs {período_referencia}.
    Verificar si el período de referencia está correcto."
```

### CHECK-08 — Frescura de datos

```
¿El dato más reciente del resultado corresponde a lo esperado?

Aplica para tablas de atributos ba_itc_attr_* donde process_date
debería ser el último proceso ejecutado.

PASS: max(process_date) dentro de los últimos 7 días
WARN: max(process_date) entre 7 y 30 días
FAIL: max(process_date) > 30 días
  → Detalle: "Los datos más recientes son del {fecha}. Pueden estar desactualizados."
```

### CHECK-09 — Consistencia de granularidad

```
¿El número de filas es coherente con la granularidad esperada?

Ejemplo: se esperan 3 filas (Q1, mensual) pero llegaron 248 → posible error de GROUP BY.

PASS: filas dentro del rango esperado (±20%)
WARN: filas > 3x lo esperado o < 50% de lo esperado
  → Detalle: "Se esperaban ~{N} filas ({granularidad}), se recibieron {M}.
    Revisar GROUP BY o filtros."
```

---

## 4. Lógica de Veredicto Global

```
FAIL  → si al menos 1 check es FAIL
WARN  → si al menos 1 check es WARN (y ninguno es FAIL)
PASS  → todos los checks son PASS
```

**Acción por veredicto:**

| Veredicto | Acción del orquestador |
|---|---|
| `PASS` | Continuar al Visualization Developer |
| `WARN` | Continuar pero pasar `anomalias[]` al Insights Narrator para mencionar al usuario |
| `FAIL` en CHECK-01 o CHECK-09 | Devolver al SQL Translator con instrucción de corrección |
| `FAIL` en CHECK-07 | Pedir confirmación al usuario antes de continuar |
| `FAIL` en CHECK-08 | Advertir al usuario y continuar (frescura no bloquea el análisis) |

---

## 5. Output — Formato de Salida

```json
{
  "status": "WARN",

  "checks": [
    {"check": "CHECK-01", "status": "PASS", "detalle": "248 filas retornadas"},
    {"check": "CHECK-02", "status": "PASS", "detalle": "Los 3 meses del Q1 tienen datos"},
    {"check": "CHECK-03", "status": "PASS", "detalle": "Empresa 010 presente"},
    {"check": "CHECK-04", "status": "PASS", "detalle": "Sin nulos en columnas de métrica"},
    {"check": "CHECK-05", "status": "WARN",
      "detalle": "monto_total en febrero (41,987,345) es 7.2% menor que enero. Puede reflejar temporada."},
    {"check": "CHECK-06", "status": "PASS", "detalle": "Subtotales cuadran con total"},
    {"check": "CHECK-07", "status": "PASS", "detalle": "Variación vs Q1 2025: +3.2% (dentro de rango)"},
    {"check": "CHECK-08", "status": "PASS", "detalle": "Datos actualizados al 2026-03-31"},
    {"check": "CHECK-09", "status": "PASS", "detalle": "3 filas recibidas, 3 esperadas (mensual)"}
  ],

  "anomalias": [
    {
      "tipo": "variacion_mensual",
      "severidad": "INFO",
      "campo": "monto_total",
      "dimension": "mes = 2026-02-01",
      "valor": 41987345.2,
      "referencia": 45230187.5,
      "mensaje_negocio": "Febrero muestra una caída de 7.2% vs enero, posiblemente estacional."
    }
  ],

  "datos_validados": {
    "columns": ["empresa", "mes", "monto_total", "num_transacciones"],
    "rows": [ ... ]
  },

  "advertencias_usuario": [
    "Los datos de febrero muestran una ligera baja estacional (7.2% vs enero). Es esperable para el rubro retail."
  ],

  "instruccion_reintento": null
}
```

**Si `status: FAIL` con instrucción de reintento:**

```json
{
  "status": "FAIL",
  "checks": [
    {"check": "CHECK-01", "status": "FAIL",
     "detalle": "El query retornó 0 filas para el período 2026-01-01 a 2026-03-31"}
  ],
  "anomalias": [],
  "datos_validados": null,
  "advertencias_usuario": [],
  "instruccion_reintento": {
    "dirigido_a": "sql_translator",
    "problema": "Query sin datos — posible filtro de partición incorrecto",
    "sugerencia": "Verificar que el campo de partición sea transaction_date (no itc_process_date) para t_retail_transaction"
  }
}
```

---

## 6. Consideraciones por Tipo de Usuario

| Tipo usuario | Checks prioritarios | Tolerancia a WARN |
|---|---|---|
| Analista Operación | CHECK-01, CHECK-04, CHECK-09 | Alta — continúa con advertencia |
| Analista Comercial | CHECK-02, CHECK-03, CHECK-05, CHECK-06 | Media — detalla anomalías en el dashboard |
| Ejecutivo | CHECK-07, CHECK-08 | Baja — el Insights Narrator menciona limitaciones en el resumen |

---

## 7. Referencia cruzada

- `@.claude/data/skills/analysis/data-catalog-specialist/SKILL.md` — spec técnica del input
- `@.claude/data/skills/build/coding/bq-sql-translator/SKILL.md` — origen del query y resultado
- `@.claude/data/data_catalog/README.md` — volumetrías de referencia por tabla
