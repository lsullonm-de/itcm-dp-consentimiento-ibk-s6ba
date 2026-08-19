# Estándar: Visualización de Datos — Analista de Negocio IA

> **Aplica a:** skill `visualization-developer/SKILL.md`
> **Librería canónica:** Plotly (JSON spec como formato de intercambio universal)
> **Modos de output:** `playground` (HTML artifact) · `api` (JSON spec puro)

---

## 1. Principio de Diseño

El agente **genera specs Plotly** — no renderiza directamente. La spec es el contrato entre el
agente y la capa de presentación (playground o web app). El mismo JSON spec funciona en ambos modos;
lo único que cambia es el envoltorio.

```
Dataset validado
  → Visualization Developer
      → Plotly JSON spec
          ├── modo playground → <html> + Plotly CDN + spec embebida  → Claude.ai Artifact
          └── modo api        → { data, layout, config }             → Plotly.js en web app
```

---

## 2. Modos de Output

### 2.1 — Modo `playground` (HTML Artifact)

El agente devuelve un HTML completo y autocontenido. Claude.ai lo renderiza como Artifact
interactivo (zoom, hover, filtros).

```html
<!DOCTYPE html>
<html>
<head>
  <script src="https://cdn.plot.ly/plotly-2.26.0.min.js"></script>
  <style>
    body { margin: 0; font-family: 'Inter', sans-serif; background: #f8f9fa; }
    #chart { width: 100%; height: 480px; }
    .titulo { padding: 16px 20px 4px; font-size: 15px; font-weight: 600; color: #1e3a5f; }
    .subtitulo { padding: 0 20px 12px; font-size: 12px; color: #6b7280; }
  </style>
</head>
<body>
  <div class="titulo">{titulo}</div>
  <div class="subtitulo">{subtitulo}</div>
  <div id="chart"></div>
  <script>
    const data = {plotly_data_json};
    const layout = {plotly_layout_json};
    const config = { responsive: true, displayModeBar: true,
                     modeBarButtonsToRemove: ['lasso2d','select2d'] };
    Plotly.newPlot('chart', data, layout, config);
  </script>
</body>
</html>
```

### 2.2 — Modo `api` (JSON Spec puro)

El agente devuelve un objeto JSON que la web app consume directamente:

```json
{
  "chart_type": "bar",
  "titulo": "Ventas mensuales SPSA — Q1 2026",
  "subtitulo": "Monto total (S/) por mes · Empresa 010",
  "data": [ { "x": [...], "y": [...], "type": "bar", ... } ],
  "layout": { "xaxis": {...}, "yaxis": {...}, ... },
  "config": { "responsive": true }
}
```

La web app renderiza con:
```javascript
Plotly.newPlot('div-id', response.data, response.layout, response.config);
```

---

## 3. Paleta de Colores ITC

### Colores primarios (series de datos)

```python
ITC_COLORS = [
    "#1e3a5f",   # Azul corporativo oscuro
    "#2d8c9e",   # Teal
    "#43a047",   # Verde
    "#f57c00",   # Naranja
    "#8e24aa",   # Púrpura
    "#e53935",   # Rojo
    "#00897b",   # Verde esmeralda
    "#3949ab",   # Índigo
]
```

### Colores semánticos (para KPIs y alertas)

```python
ITC_SEMANTIC = {
    "positivo":   "#43a047",   # verde — crecimiento, meta cumplida
    "negativo":   "#e53935",   # rojo — caída, meta no cumplida
    "neutro":     "#90a4ae",   # gris azulado — sin variación
    "destacado":  "#f57c00",   # naranja — dato relevante
    "fondo":      "#f8f9fa",   # gris muy claro — background
    "texto":      "#1e3a5f",   # azul oscuro — títulos
    "texto_sec":  "#6b7280",   # gris — subtítulos y ejes
}
```

### Escala de calor (mapas y heatmaps)

```python
ITC_COLORSCALE = [
    [0.0,  "#e8f5e9"],
    [0.25, "#a5d6a7"],
    [0.5,  "#2d8c9e"],
    [0.75, "#1e3a5f"],
    [1.0,  "#0d1b2e"],
]
```

---

## 4. Selección de Tipo de Chart

### Regla principal: dato → chart

| Tipo de dato | Chart recomendado | Cuándo NO usarlo |
|---|---|---|
| Comparación entre categorías (pocas) | `bar` horizontal o vertical | > 15 categorías → usar tabla |
| Evolución temporal (tendencia) | `line` o `scatter` con línea | Períodos < 3 puntos → usar bar |
| Composición / proporción | `pie` o `donut` | > 6 segmentos → usar bar apilado |
| Distribución de valores | `histogram` o `box` | Si se necesita exactitud → tabla |
| Correlación entre dos variables | `scatter` | — |
| Magnitud geográfica | `choropleth` o `scattermapbox` | Sin ubigeo → usar bar |
| KPI único puntual | `indicator` (gauge o number) | — |
| Múltiples métricas comparadas | `bar` agrupado o `radar` | > 6 métricas → tabla |
| Ranking | `bar` horizontal ordenado | — |
| Dos ejes con escalas distintas | `bar` + `scatter` (eje secundario) | — |

### Regla secundaria: tipo de usuario → complejidad

| Usuario | Charts permitidos | Interactividad |
|---|---|---|
| Analista Operación | `bar`, `line`, tabla HTML | Hover básico |
| Analista Comercial | todos + filtros por dropdown | Hover + zoom + filtros |
| Ejecutivo | `indicator` (KPIs) + `choropleth` + `bar` | Hover + drill-down simple |

---

## 5. Layout Base (Plotly)

```python
BASE_LAYOUT = {
    "font": {
        "family": "Inter, Helvetica, Arial, sans-serif",
        "color": "#1e3a5f",
        "size": 12
    },
    "paper_bgcolor": "#f8f9fa",
    "plot_bgcolor": "#ffffff",
    "margin": {"l": 60, "r": 30, "t": 20, "b": 60},
    "legend": {
        "orientation": "h",
        "yanchor": "bottom",
        "y": -0.25,
        "xanchor": "center",
        "x": 0.5
    },
    "xaxis": {
        "showgrid": False,
        "linecolor": "#e5e7eb",
        "tickfont": {"size": 11, "color": "#6b7280"}
    },
    "yaxis": {
        "gridcolor": "#e5e7eb",
        "linecolor": "rgba(0,0,0,0)",
        "tickfont": {"size": 11, "color": "#6b7280"},
        "tickformat": ",.0f"
    },
    "hoverlabel": {
        "bgcolor": "#1e3a5f",
        "font_color": "#ffffff",
        "bordercolor": "#1e3a5f"
    }
}
```

---

## 6. Plantillas por Chart Type

### Bar vertical (comparación por categoría)

```python
{
    "type": "bar",
    "x": [lista_categorias],
    "y": [lista_valores],
    "name": "Serie",
    "marker": {
        "color": ITC_COLORS[0],
        "line": {"width": 0}
    },
    "text": [f"{v:,.0f}" for v in valores],
    "textposition": "outside",
    "textfont": {"size": 10},
    "hovertemplate": "<b>%{x}</b><br>%{y:,.0f}<extra></extra>"
}
```

### Line (tendencia temporal)

```python
{
    "type": "scatter",
    "mode": "lines+markers",
    "x": [lista_fechas],
    "y": [lista_valores],
    "name": "Serie",
    "line": {"color": ITC_COLORS[0], "width": 2.5},
    "marker": {"size": 6, "color": ITC_COLORS[0]},
    "hovertemplate": "<b>%{x}</b><br>%{y:,.0f}<extra></extra>"
}
```

### Indicator (KPI ejecutivo)

```python
{
    "type": "indicator",
    "mode": "number+delta",
    "value": valor_actual,
    "delta": {
        "reference": valor_anterior,
        "relative": True,
        "valueformat": ".1%",
        "increasing": {"color": ITC_SEMANTIC["positivo"]},
        "decreasing": {"color": ITC_SEMANTIC["negativo"]}
    },
    "number": {
        "valueformat": ",.0f",
        "font": {"size": 36, "color": ITC_COLORS[0]}
    },
    "title": {"text": titulo_kpi, "font": {"size": 13}}
}
```

### Choropleth (mapa por departamento Perú)

```python
{
    "type": "choropleth",
    "geojson": "{url_geojson_peru_departamentos}",
    "locations": [lista_cod_departamento],
    "z": [lista_valores],
    "featureidkey": "properties.cod_dep",
    "colorscale": ITC_COLORSCALE,
    "hovertemplate": "<b>%{location}</b><br>%{z:,.0f}<extra></extra>",
    "colorbar": {
        "title": titulo_escala,
        "tickformat": ",.0f"
    }
}
```

---

## 7. Tabla HTML (fallback y modo operación)

Cuando el resultado tiene > 15 categorías o el usuario es Analista de Operación y no requiere gráfico:

```html
<style>
  .itc-table { width:100%; border-collapse:collapse; font-family:Inter,sans-serif; font-size:13px; }
  .itc-table th { background:#1e3a5f; color:#fff; padding:10px 12px; text-align:left; }
  .itc-table td { padding:8px 12px; border-bottom:1px solid #e5e7eb; color:#374151; }
  .itc-table tr:hover td { background:#f0f9ff; }
  .itc-table .num { text-align:right; font-variant-numeric:tabular-nums; }
</style>
<table class="itc-table">
  <thead><tr>{headers}</tr></thead>
  <tbody>{rows}</tbody>
</table>
```

---

## 8. Formato de números

| Tipo de valor | Formato Python | Formato Plotly |
|---|---|---|
| Monto S/ (miles) | `f"S/ {v:,.0f}"` | `"S/ ,.0f"` |
| Monto S/ (millones) | `f"S/ {v/1e6:.1f}M"` | — |
| Porcentaje | `f"{v:.1f}%"` | `".1%"` |
| Número entero | `f"{v:,.0f}"` | `",.0f"` |
| Número decimal | `f"{v:,.2f}"` | `",.2f"` |
| Variación (delta) | `f"{v:+.1f}%"` | `"+.1%"` |

---

## 9. Dashboard Multi-panel (Analista Comercial)

Para dashboards con múltiples gráficos usar `make_subplots` de Plotly:

```python
from plotly.subplots import make_subplots

fig = make_subplots(
    rows=2, cols=2,
    subplot_titles=["Ventas por mes", "Top 10 tiendas", "Mix canal", "Tendencia YoY"],
    specs=[
        [{"type": "bar"}, {"type": "bar"}],
        [{"type": "pie"}, {"type": "scatter"}]
    ],
    vertical_spacing=0.12,
    horizontal_spacing=0.08
)
# Agregar cada trace a su subplot
fig.add_trace(trace_ventas_mes, row=1, col=1)
fig.add_trace(trace_top_tiendas, row=1, col=2)
# ...
fig.update_layout(**BASE_LAYOUT, height=700)
```

---

## 10. Referencia cruzada

- `@.claude/data/skills/build/visualization-developer/SKILL.md` — skill que implementa este estándar
- `@.claude/data/skills/verify/data-validator/SKILL.md` — fuente del dataset validado
- `@.claude/data/data_catalog/README.md` — contexto de los datos graficados
