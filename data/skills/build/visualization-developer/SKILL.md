# Skill: Visualization Developer

> **Rol:** Generador de Visualizaciones — Analista de Negocio IA
> **Activado por:** El orquestador `Business Analyst Agent` después del Data Validator (`status: PASS | WARN`)
> **Estándar base obligatorio:** `@.claude/data/standard/visualization/chart-design.md`
> **Posición en el pipeline:** Data Validator → **Visualization Developer** → Insights Narrator

---

## 1. Rol

El **Visualization Developer** convierte el dataset validado en una visualización lista para
presentar al usuario. Selecciona el tipo de chart correcto según los datos y el perfil del
usuario, construye la spec Plotly y la entrega en el modo adecuado:

- **`playground`** → HTML artifact que Claude.ai renderiza directamente
- **`api`** → JSON spec Plotly puro que la web app renderiza con `Plotly.js`

No interpreta el negocio — eso lo hace el Insights Narrator. Su foco es que la visualización
sea **correcta, legible y estéticamente consistente** con el estándar ITC.

---

## 2. Input Esperado

Recibido del orquestador junto con el dataset validado:

```json
{
  "output_mode": "playground",
  "tipo_usuario": "analista_comercial",
  "requerimiento_original": "Ventas mensuales SPSA Q1 2026 por región",
  "dataset": {
    "columns": ["empresa", "region", "mes", "monto_total", "num_transacciones"],
    "types": { "empresa": "STRING", "region": "STRING", "mes": "DATE",
               "monto_total": "FLOAT", "num_transacciones": "INT" },
    "rows": [ ... ],
    "total_rows": 36
  },
  "spec_tecnica": {
    "granularidad": "mensual por región",
    "metricas": ["monto_total", "num_transacciones"],
    "dimensiones": ["empresa", "region", "mes"],
    "tiene_comparativo_temporal": false,
    "tiene_dimension_geografica": true
  },
  "anomalias": [
    {
      "campo": "monto_total",
      "dimension": "mes = 2026-02",
      "mensaje_negocio": "Febrero muestra caída estacional de 7.2%"
    }
  ]
}
```

---

## 3. Proceso de Decisión

### Paso 1 — Seleccionar tipo de chart

Aplicar las reglas del estándar `visualization.md` §4:

```
1. ¿Cuántas dimensiones tiene el dataset?
   → 1 dimensión + 1 métrica           → bar vertical
   → 1 dimensión temporal + 1 métrica  → line
   → 2+ dimensiones                    → bar agrupado o subplots

2. ¿Hay dimensión geográfica (ubigeo, región)?
   → sí + tipo_usuario = ejecutivo     → choropleth + bar (subplots)
   → sí + otros usuarios               → bar con región como eje

3. ¿El tipo_usuario es ejecutivo y solo hay KPIs?
   → indicators (gauge/number + delta)

4. ¿Hay más de 15 categorías en el eje X?
   → tabla HTML (no gráfico de barras)

5. ¿El tipo_usuario es analista_comercial y hay múltiples métricas?
   → dashboard multi-panel (make_subplots)
```

### Paso 2 — Construir el chart

Seguir las plantillas de `visualization.md` §6 para el tipo seleccionado.
Aplicar paleta `ITC_COLORS` y `BASE_LAYOUT` del estándar.

### Paso 3 — Marcar anomalías en el chart

Si el Data Validator envió `anomalias[]`, anotarlas visualmente:

```python
# Añadir anotación en el punto anómalo
fig.add_annotation(
    x=dimension_anomala,
    y=valor_anomalo,
    text="⚠",
    showarrow=True,
    arrowhead=2,
    arrowcolor="#f57c00",
    font={"size": 14, "color": "#f57c00"}
)
```

### Paso 4 — Formatear output según `output_mode`

Ver Sección 5.

---

## 4. Patrones por Tipo de Usuario

### 4.1 — Analista de Operación

**Objetivo:** ver el dato concreto, no tendencias. Priorizar tabla cuando hay muchas categorías.

```
Regla de decisión:
  total_rows ≤ 20 Y dimensiones ≤ 2  → bar vertical + tabla debajo
  total_rows > 20                    → solo tabla HTML
  hay dimensión temporal (mes/día)   → line chart
```

**Output:** chart simple (1 panel) + tabla HTML siempre incluida.

### 4.2 — Analista Comercial

**Objetivo:** explorar por dimensiones, comparar períodos, filtrar.

```
Regla de decisión:
  1 métrica + tiempo              → line con markers
  2 métricas + tiempo             → line doble eje (eje secundario)
  categorías + tiempo             → bar agrupado por período
  tiene_dimension_geografica      → choropleth + bar (2 subplots)
  3+ métricas distintas           → dashboard make_subplots (2×2)
```

**Output:** chart interactivo con hover detallado. Sin tabla (el dashboard es suficiente).

### 4.3 — Ejecutivo

**Objetivo:** KPIs de un vistazo, comparativo vs período anterior, mapa de calor geográfico.

```
Regla de decisión:
  métricas con comparativo YoY    → indicators (number + delta) en fila
  tiene_dimension_geografica      → choropleth de Perú
  siempre incluir                 → bar horizontal de ranking (top 5)
```

**Output:** layout ejecutivo = indicators arriba + mapa/ranking abajo.

**Template layout ejecutivo:**

```python
fig = make_subplots(
    rows=2, cols=3,
    specs=[
        [{"type": "indicator"}, {"type": "indicator"}, {"type": "indicator"}],
        [{"type": "choropleth", "colspan": 2}, None, {"type": "bar"}]
    ],
    row_heights=[0.3, 0.7]
)
```

---

## 5. Output — Formato de Salida

### 5.1 — Modo `playground` (HTML Artifact)

El agente produce un bloque HTML completo que Claude.ai renderiza como Artifact:

````markdown
```html
<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.plot.ly/plotly-2.26.0.min.js"></script>
  <style>
    body { margin:0; font-family:'Inter',sans-serif; background:#f8f9fa; }
    #chart { width:100%; height:480px; }
    .titulo { padding:16px 20px 4px; font-size:15px; font-weight:600; color:#1e3a5f; }
    .subtitulo { padding:0 20px 12px; font-size:12px; color:#6b7280; }
  </style>
</head>
<body>
  <div class="titulo">{titulo}</div>
  <div class="subtitulo">{subtitulo}</div>
  <div id="chart"></div>
  <script>
    Plotly.newPlot('chart',
      {data_json},
      {layout_json},
      {responsive:true, displayModeBar:true,
       modeBarButtonsToRemove:['lasso2d','select2d']}
    );
  </script>
</body>
</html>
```
````

### 5.2 — Modo `api` (JSON Spec)

El agente produce un JSON que la web app consume:

```json
{
  "chart_type": "bar",
  "titulo": "Ventas mensuales SPSA — Q1 2026",
  "subtitulo": "Monto total (S/) por mes",
  "data": [
    {
      "type": "bar",
      "x": ["Ene 2026", "Feb 2026", "Mar 2026"],
      "y": [45230187, 41987345, 47654321],
      "marker": { "color": "#1e3a5f" },
      "hovertemplate": "<b>%{x}</b><br>S/ %{y:,.0f}<extra></extra>"
    }
  ],
  "layout": {
    "paper_bgcolor": "#f8f9fa",
    "plot_bgcolor": "#ffffff",
    "font": { "family": "Inter, Helvetica, Arial, sans-serif", "color": "#1e3a5f" },
    "xaxis": { "showgrid": false },
    "yaxis": { "gridcolor": "#e5e7eb", "tickformat": ",.0f" },
    "margin": { "l": 60, "r": 30, "t": 20, "b": 60 }
  },
  "config": { "responsive": true },
  "tabla_html": "<table class='itc-table'>...</table>",
  "anomalias_anotadas": ["2026-02: caída estacional -7.2%"]
}
```

---

## 6. Reglas de Formato de Números en Charts

Aplicar el estándar `visualization.md` §8:

| Campo | Detección automática | Formato aplicado |
|---|---|---|
| Nombre contiene `mto_` o `monto` | `FLOAT > 1000` | `"S/ {:,.0f}"` o `"S/ {:.1f}M"` si > 1M |
| Nombre contiene `porc_` o `pct` | `FLOAT 0-100` | `"{:.1f}%"` |
| Nombre contiene `numtrx_` o `num_` | `INT` | `"{:,.0f}"` |
| Nombre contiene `var_` o `delta` | `FLOAT` con signo | `"{:+.1f}%"` |
| Nombre contiene `recencia` o `dias` | `INT` | `"{:,.0f} días"` |

---

## 7. Tabla HTML siempre incluida para Analista Operación

```python
def generar_tabla_html(columns, rows, types):
    headers = "".join(
        f'<th class="num">{c}</th>' if types[c] in ("FLOAT","INT")
        else f'<th>{c}</th>'
        for c in columns
    )
    filas = ""
    for row in rows:
        celdas = ""
        for c in columns:
            v = row[c]
            if types[c] == "FLOAT":
                celdas += f'<td class="num">S/ {v:,.0f}</td>'
            elif types[c] == "INT":
                celdas += f'<td class="num">{v:,.0f}</td>'
            else:
                celdas += f'<td>{v}</td>'
        filas += f"<tr>{celdas}</tr>"
    return f"""
    <style>
      .itc-table {{width:100%;border-collapse:collapse;font-family:Inter,sans-serif;font-size:13px;margin-top:16px}}
      .itc-table th {{background:#1e3a5f;color:#fff;padding:10px 12px;text-align:left}}
      .itc-table td {{padding:8px 12px;border-bottom:1px solid #e5e7eb;color:#374151}}
      .itc-table tr:hover td {{background:#f0f9ff}}
      .itc-table .num {{text-align:right;font-variant-numeric:tabular-nums}}
    </style>
    <table class="itc-table">
      <thead><tr>{headers}</tr></thead>
      <tbody>{filas}</tbody>
    </table>"""
```

---

## 8. Checklist de Calidad

Antes de entregar el output, verificar:

- [ ] El chart type corresponde al tipo de dato y tipo de usuario (reglas §4 del estándar)
- [ ] Se aplica `ITC_COLORS` y `BASE_LAYOUT` del estándar
- [ ] Eje Y formateado con separador de miles (no `45230187`, sí `45,230,187`)
- [ ] Hover template incluye etiqueta limpia con unidad (`S/`, `%`, etc.)
- [ ] Anomalías del Data Validator anotadas visualmente con `⚠`
- [ ] Modo `playground`: HTML es autocontenido y válido
- [ ] Modo `api`: JSON tiene `data`, `layout`, `config` como claves raíz
- [ ] Analista Operación: siempre incluir tabla HTML además del chart
- [ ] Ejecutivo: siempre incluir comparativo (delta) en indicators

---

## 9. Referencia cruzada

- `@.claude/data/standard/visualization/chart-design.md` — paleta, layouts, plantillas, selección de chart
- `@.claude/data/skills/verify/data-validator/SKILL.md` — dataset de entrada + anomalías
- `@.claude/data/skills/build/coding/bq-sql-translator/SKILL.md` — contexto del query ejecutado
