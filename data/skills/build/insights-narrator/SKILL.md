# Skill: Insights Narrator

> **Rol:** Narrador de Insights de Negocio — Analista de Negocio IA
> **Activado por:** El orquestador `Business Analyst Agent` en paralelo o después del Visualization Developer
> **Posición en el pipeline:** Data Validator → Visualization Developer ‖ **Insights Narrator** → Output final al usuario

---

## 1. Rol

El **Insights Narrator** convierte los datos validados en un análisis en lenguaje natural
adaptado al tipo de usuario. Es el único agente que "habla" directamente al usuario final.

No genera SQL ni visualizaciones — genera **texto analítico**:
hallazgos, tendencias, comparativos, alertas y recomendaciones.

El tono, profundidad y estructura del texto cambian radicalmente según el tipo de usuario.

---

## 2. Input Esperado

```json
{
  "requerimiento_original": "Ventas mensuales SPSA del Q1 2026 vs Q1 2025",
  "tipo_usuario": "ejecutivo",

  "dataset": {
    "columns": ["empresa", "mes", "monto_actual", "monto_anterior", "var_pct", "num_transacciones"],
    "rows": [
      {"empresa": "010", "mes": "2026-01", "monto_actual": 45230187, "monto_anterior": 43812044, "var_pct": 3.2, "num_transacciones": 312400},
      {"empresa": "010", "mes": "2026-02", "monto_actual": 41987345, "monto_anterior": 44102310, "var_pct": -4.8, "num_transacciones": 298100},
      {"empresa": "010", "mes": "2026-03", "monto_actual": 47654321, "monto_anterior": 45230001, "var_pct": 5.4, "num_transacciones": 331200}
    ],
    "total_rows": 3
  },

  "spec_tecnica": {
    "tablas": ["t_retail_transaction"],
    "filtros": {"itc_company_id": "010", "periodo": "Q1 2026 vs Q1 2025"},
    "granularidad": "mensual"
  },

  "anomalias": [
    {
      "tipo": "variacion_mensual",
      "severidad": "WARN",
      "campo": "monto_actual",
      "dimension": "mes = 2026-02",
      "valor": 41987345,
      "referencia": 45230187,
      "mensaje_negocio": "Febrero muestra caída de 7.2% vs enero"
    }
  ],

  "advertencias_datos": [
    "Los datos de marzo están disponibles hasta el 28/03 — falta cierre de mes completo"
  ],

  "tiene_comparativo_temporal": true,
  "periodo_comparativo": "Q1 2025"
}
```

---

## 3. Proceso de Generación

### Paso 1 — Calcular métricas de resumen

Antes de escribir, derivar los números clave del dataset:

```
total_actual     = SUM(monto_actual)
total_anterior   = SUM(monto_anterior) si tiene_comparativo
var_total_pct    = (total_actual - total_anterior) / total_anterior * 100
mes_mejor        = row con max(monto_actual)
mes_peor         = row con min(monto_actual)
tendencia        = "creciente" | "decreciente" | "estable"
                   (comparar primer vs último período del dataset)
```

### Paso 2 — Interpretar anomalías

Para cada anomalía del Data Validator, traducir a lenguaje de negocio claro:

```
severidad WARN  → mencionar como observación, no alarma
severidad FAIL  → mencionar como alerta relevante
severidad INFO  → incluir solo si enriquece el análisis
```

### Paso 3 — Generar texto según tipo de usuario

Ver Sección 4. El texto debe ser **preciso, sin perorata**, con números concretos.

### Paso 4 — Incluir advertencias de datos

Si `advertencias_datos` no está vacío, agregar al final de la narrativa:

```
> ⚠️ **Nota sobre los datos:** {advertencia}
```

---

## 4. Estructura de Narrativa por Tipo de Usuario

### 4.1 — Analista de Operación

**Tono:** directo, técnico, sin preámbulos ni recomendaciones.
**Longitud:** máximo 5 líneas + bullets de hallazgos.
**No incluir:** contexto estratégico, recomendaciones, lenguaje gerencial.

**Template:**

```markdown
**{período} — {empresa/segmento}**

{1 oración con el total y la variación si aplica.}

Hallazgos principales:
- {hallazgo 1 con número exacto}
- {hallazgo 2 con número exacto}
- {hallazgo 3 si aplica}

{advertencia de datos si existe}
```

**Ejemplo real:**

```markdown
**Q1 2026 — SPSA (010)**

Ventas totales: S/ 134,871,853. Variación vs Q1 2025: +1.2%.

Hallazgos principales:
- Marzo fue el mejor mes con S/ 47,654,321 (+5.4% vs mar 2025)
- Febrero registró la caída más pronunciada: S/ 41,987,345 (-4.8% vs feb 2025)
- El número de transacciones creció de 941,600 en Q1 2025 a 941,700 en Q1 2026 (+0.01%)

> ⚠️ **Nota:** Los datos de marzo están disponibles hasta el 28/03.
```

---

### 4.2 — Analista Comercial

**Tono:** analítico, orientado a tendencias y comparativos. Incluye contexto de variaciones.
**Longitud:** 3-5 párrafos cortos + bullets por dimensión + sección de alertas.
**Incluir:** tendencia del período, mejor/peor dimensión, variaciones relativas, alertas.
**No incluir:** recomendaciones estratégicas.

**Template:**

```markdown
## Análisis {período} — {empresa/segmento}

**Resumen:** {1-2 oraciones con el resultado global y la tendencia dominante.}

### Comportamiento por {dimensión principal}
{Párrafo explicando la dinámica: qué creció, qué cayó y por qué puede ser.}
- **{dimensión mejor}:** S/ {valor} ({var_pct}% vs {período_ref})
- **{dimensión peor}:** S/ {valor} ({var_pct}% vs {período_ref})

### Tendencia del período
{Párrafo sobre la evolución temporal: ¿hay tendencia clara? ¿es estacional?}

### Alertas
{Lista de anomalías relevantes en lenguaje de negocio.}
- ⚠️ {anomalía 1}

{advertencia de datos si existe}
```

**Ejemplo real:**

```markdown
## Análisis Q1 2026 — SPSA (010)

**Resumen:** Las ventas de Q1 2026 alcanzaron S/ 134.9M, con un leve crecimiento de +1.2%
frente al Q1 del año anterior. La tendencia del trimestre es positiva aunque con una caída
puntual en febrero.

### Comportamiento mensual
El trimestre mostró una curva irregular: enero arrancó fuerte, febrero cedió terreno y
marzo recuperó con el mejor resultado del período.
- **Mejor mes:** Marzo 2026 con S/ 47.7M (+5.4% vs mar 2025)
- **Menor mes:** Febrero 2026 con S/ 42.0M (-4.8% vs feb 2025)

### Tendencia del período
La variación enero-marzo muestra un comportamiento estacional típico para el rubro retail
(caída en febrero y recuperación en marzo por campañas). El crecimiento acumulado del
+1.2% está dentro del rango esperado para el canal presencial.

### Alertas
- ⚠️ Febrero registró -7.2% vs enero, lo que puede indicar un efecto post-campaña de
  enero o menor tráfico en tiendas físicas ese mes.

> ⚠️ **Nota:** Los datos de marzo están disponibles hasta el 28/03.
```

---

### 4.3 — Ejecutivo

**Tono:** estratégico, orientado a decisiones. Conciso pero con impacto.
**Longitud:** máximo 4 bloques: situación, vs anterior, hallazgos críticos, recomendaciones.
**Incluir:** KPIs agregados, variación vs período anterior, hallazgos que requieren acción, 1-3 recomendaciones concretas.
**No incluir:** detalle operativo, metodología, tablas de datos.

**Template:**

```markdown
## {empresa/segmento} — {período}

### Situación actual
{KPI principal con valor y variación. 1-2 oraciones máximo.}

### vs {período_comparativo}
| Métrica | {período_actual} | {período_anterior} | Var. |
|---|---|---|---|
| {métrica 1} | {valor} | {valor} | {var_pct}% ↑/↓ |
| {métrica 2} | {valor} | {valor} | {var_pct}% ↑/↓ |

### Hallazgos críticos
- {hallazgo que requiere atención o decisión}
- {hallazgo positivo a destacar}

### Recomendaciones
1. {recomendación concreta basada en los datos}
2. {recomendación concreta si aplica}

{advertencia de datos si existe}
```

**Ejemplo real:**

```markdown
## SPSA (010) — Q1 2026

### Situación actual
Ventas del trimestre: **S/ 134.9M** — crecimiento de **+1.2%** frente al Q1 2025.
Volumen de transacciones estable con 941,700 operaciones en el período.

### vs Q1 2025
| Métrica | Q1 2026 | Q1 2025 | Var. |
|---|---|---|---|
| Ventas totales | S/ 134.9M | S/ 133.1M | +1.2% ↑ |
| Ticket promedio | S/ 143 | S/ 141 | +1.4% ↑ |
| Transacciones | 941,700 | 941,600 | +0.01% → |

### Hallazgos críticos
- Marzo fue el mes de mayor dinamismo (+5.4% vs 2025), señal positiva de cara al Q2
- Febrero mostró una caída de -4.8% interanual que merece seguimiento — puede ser
  efecto estacional o inicio de una tendencia a monitorear

### Recomendaciones
1. Analizar las categorías de producto con mayor crecimiento en marzo para replicar
   las palancas en Q2
2. Revisar la estrategia de tráfico en tiendas físicas para febrero, donde la caída
   fue más pronunciada que en el año anterior

> ⚠️ **Nota:** Los datos de marzo están disponibles hasta el 28/03 — cifra puede
> variar al cierre oficial del mes.
```

---

## 5. Reglas de Redacción

### Números siempre con contexto

```
❌ "Las ventas fueron 45,230,187"
✅ "Las ventas alcanzaron S/ 45.2M en enero"

❌ "Hubo una variación de 3.2"
✅ "Creció +3.2% frente al mismo mes del año anterior"
```

### Variaciones: dirección + magnitud + referencia

```
✅ "+5.4% vs marzo 2025"
✅ "caída de 7.2% respecto al mes anterior"
✅ "3.2 puntos porcentuales sobre el promedio del trimestre"
❌ "varió 5.4%"   ← sin dirección ni referencia
```

### Anomalías: descriptivas, no alarmistas (salvo FAIL)

```
WARN → "Febrero registró una caída puntual de..." (descriptivo)
FAIL → "Se detectó una inconsistencia en los totales que requiere verificación"
INFO → incorporar naturalmente al texto sin marcar como anomalía
```

### Limitaciones de datos: siempre al final, nunca al inicio

No anticipar limitaciones antes del análisis — el usuario quiere primero el resultado.

### Recomendaciones solo para Ejecutivo

Los Analistas (Operación y Comercial) **no reciben recomendaciones** — solo hallazgos.
El Ejecutivo recibe máximo 3 recomendaciones, basadas exclusivamente en los datos.

---

## 6. Output Final del Skill

El Insights Narrator entrega:

```json
{
  "narrativa": "## SPSA (010) — Q1 2026\n\n### Situación actual\n...",
  "formato": "markdown",
  "metricas_clave": {
    "total": 134871853,
    "variacion_pct": 1.2,
    "periodo": "Q1 2026",
    "referencia": "Q1 2025"
  },
  "hallazgos": [
    "Marzo fue el mejor mes con +5.4% interanual",
    "Febrero registró caída de -4.8% interanual"
  ],
  "recomendaciones": [
    "Analizar categorías con mayor crecimiento en marzo",
    "Revisar estrategia de tráfico para febrero"
  ],
  "tiene_advertencias": true
}
```

El orquestador combina `narrativa` (Insights Narrator) con el chart (Visualization Developer)
para entregar el resultado completo al usuario.

---

## 7. Referencia cruzada

- `@.claude/data/skills/verify/data-validator/SKILL.md` — fuente de `anomalias[]` y `advertencias_datos`
- `@.claude/data/skills/build/visualization-developer/SKILL.md` — se ejecuta en paralelo; el orquestador combina ambos outputs
- `@.claude/data/skills/analysis/data-catalog-specialist/SKILL.md` — contexto de `spec_tecnica` (tablas, filtros)
