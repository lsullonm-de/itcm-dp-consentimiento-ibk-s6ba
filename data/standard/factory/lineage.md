# Estándar: Etapa LINEAGE — Registro de Linaje de Datos

> **Activado por:** `/data:implement-stage LINEAGE`
> **Aplica a:** módulos `bq_pipeline` que cargan tablas BigQuery con transformaciones rastreables
> **Por defecto:** `lineage: false` en `spec.yaml`
> **Dependencia:** requiere que el módulo `itcm-dp-dataops-api-metadata` esté desplegado
>   y accesible en el ambiente destino.
> **Posición en el flujo:** después de MONITORING y DATA_QUALITY, antes de DATAOPS

---

## 1. Qué es el Framework de Linaje de Datos

El **Framework de Linaje** registra el grafo de transformaciones del Data Platform:
qué tablas alimentan a qué otras tablas, qué SP realiza la transformación y,
opcionalmente, qué columna origen origina qué columna destino.

Compuesto por tres entidades en PostgreSQL (schema `data_lineage`):

| Entidad | Tabla | Descripción |
|---|---|---|
| Nodo | `dp_lineage_node` | Un asset: tabla, vista, archivo o query |
| Arista | `dp_lineage_edge` | Relación entre dos nodos vía un proceso |
| Trazabilidad columnar | `dp_lineage_column` | Mapeo columna-a-columna con tipo de transformación |

El grafo es **acíclico dirigido** — los nodos fuente son `input` o `temp`; los destino son `output`.
Los endpoints de grafo (`/graph/downstream`, `/graph/upstream`) permiten analizar impacto hasta 10 niveles.

---

## 2. Cuándo activar `lineage: true`

| Condición | Activar |
|---|---|
| `type: bq_pipeline` con SPs que cargan tablas BigQuery | ✅ SÍ |
| `type: bq_pipeline` sin SP (solo DDL o análisis) | ❌ NO |
| `type: vertex_ml` | ⬜ Futuro |
| `type: cloud_run_api` | ❌ NO |

**Regla simple:** activar cuando el spec tiene al menos 1 componente `tipo: sp` con tabla destino
identificada en `outputs`.

---

## 3. Modelo de Datos — `data_lineage`

### `dp_lineage_node` — Nodos del Grafo

| Campo | Tipo | Descripción |
|---|---|---|
| `node_id` | TEXT PK | Identificador único del nodo. Convención: `NODE-{EMPRESA}-{TABLA}-{NNN}` |
| `asset` | TEXT | FQN del asset: `{project}.{dataset}.{tabla}` (validado por regex) |
| `node_type` | TEXT | `input` \| `output` \| `temp` |
| `node_label` | TEXT | Nombre legible (nombre de tabla sin prefijos de proyecto) |
| `description` | TEXT | Descripción del asset |
| `owner_team` | TEXT | Equipo responsable (ej: `data-platform`) |
| `is_active` | BOOL | `true` por defecto |
| `record_source` | TEXT | Origen del registro (ej: `lineage-api`) |
| `creation_user` | TEXT | SA o usuario que creó el nodo |

> `asset` debe seguir el formato `proyecto.dataset.tabla` — exactamente 3 partes separadas por `.`.
> La API valida con regex `^[^.]+\.[^.]+\.[^.]+$` y retorna 422 si no cumple.

### `dp_lineage_edge` — Aristas (Relaciones)

| Campo | Tipo | Descripción |
|---|---|---|
| `edge_id` | TEXT PK | Identificador único. Convención: `EDGE-{EMPRESA}-{SP_SLUG}-{NNN}` |
| `source_node_id` | TEXT FK | Nodo origen (debe existir y estar activo — RN-ITC-002) |
| `target_node_id` | TEXT FK | Nodo destino (debe existir y estar activo — RN-ITC-002) |
| `process_name` | TEXT | Nombre del SP o proceso que realiza la transformación |
| `edge_type` | TEXT | `direct` \| `derived` \| `aggregated` |
| `is_active` | BOOL | `true` por defecto |
| `record_source` | TEXT | Origen del registro |
| `creation_user` | TEXT | SA o usuario |

### `dp_lineage_column` — Trazabilidad Columnar (opcional)

| Campo | Tipo | Descripción |
|---|---|---|
| `col_lineage_id` | TEXT PK | Convención: `COLLINEAGE-{EMPRESA}-{EDGE_SLUG}-{NNN}` |
| `edge_id` | TEXT FK | Arista a la que pertenece (debe estar activa — RN-ITC-003) |
| `source_column` | TEXT | Columna origen (nullable para columnas calculadas sin fuente directa) |
| `target_column` | TEXT | Columna destino |
| `transformation_type` | TEXT | `direct` \| `sum` \| `avg` \| `count` \| `max` \| `min` \| `isnull` \| `case_when` \| `concat` \| `cast` \| `custom` |
| `transformation_expr` | TEXT | Expresión SQL de la transformación (opcional) |
| `is_active` | BOOL | `true` por defecto |

---

## 4. API Endpoints del Framework

Base URL: `${METADATA_API_URL}` (variable en `env_[env].json`)

| Operación | Método | Path |
|---|---|---|
| Crear nodo | POST | `/api/v1/lineage/nodes` |
| Actualizar nodo | PUT | `/api/v1/lineage/nodes/{node_id}` |
| Crear arista | POST | `/api/v1/lineage/edges` |
| Actualizar arista | PUT | `/api/v1/lineage/edges/{edge_id}` |
| Crear trazabilidad columnar | POST | `/api/v1/lineage/columns` |
| Actualizar trazabilidad columnar | PUT | `/api/v1/lineage/columns/{col_lineage_id}` |
| Grafo completo de tabla | GET | `/api/v1/lineage/graph/table?asset={fqn}` |
| Downstream recursivo | GET | `/api/v1/lineage/graph/downstream?asset={fqn}&depth={n}` |
| Upstream recursivo | GET | `/api/v1/lineage/graph/upstream?asset={fqn}&depth={n}` |

> **Idempotencia:** la API retorna 409 si el `node_id` o `edge_id` ya existe.
> Los scripts deben ignorar el 409 (registro ya matriculado) y continuar.

---

## 5. Bloque `lineage` en `spec.yaml`

Agregar cuando `etapas.lineage: true`:

```yaml
lineage:
  METADATA_API_URL: "${METADATA_API_URL}"
  owner_team: data-platform

  nodes:
    # Un nodo por cada tabla fuente (input), temporal relevante (temp) y tabla destino (output)
    - node_id: "NODE-{EMPRESA}-{TABLA_FUENTE}-001"
      asset: "${project_fuente}.${dataset_fuente}.{tabla_fuente}"
      node_type: input
      node_label: "{tabla_fuente}"
      description: ~

    - node_id: "NODE-{EMPRESA}-{TABLA_DESTINO}-001"
      asset: "${project_analytics}.${dataset_analytics}.{tabla_destino}"
      node_type: output
      node_label: "{tabla_destino}"
      description: ~

    # Nodos temp opcionales (tablas intermedias relevantes para el linaje)
    # - node_id: "NODE-{EMPRESA}-TMP-{TABLA}-001"
    #   asset: "${project_analytics}.${dataset_stage}.tmp_{tabla}"
    #   node_type: temp

  edges:
    # Una arista por cada SP que transforma datos
    - edge_id: "EDGE-{EMPRESA}-{SP_SLUG}-001"
      source_node_id: "NODE-{EMPRESA}-{TABLA_FUENTE}-001"
      target_node_id: "NODE-{EMPRESA}-{TABLA_DESTINO}-001"
      process_name: "sp_{nombre}"
      edge_type: derived                # direct | derived | aggregated

  columns:  # opcional — completar para trazabilidad columnar
    - col_lineage_id: "COLLINEAGE-{EMPRESA}-{EDGE_SLUG}-001"
      edge_id: "EDGE-{EMPRESA}-{SP_SLUG}-001"
      source_column: "{campo_fuente}"   # null si es columna calculada
      target_column: "{campo_destino}"
      transformation_type: direct       # direct | derived | aggregated | custom | ...
      transformation_expr: ~            # expresión SQL si aplica
```

### Convenciones de naming

| Entidad | Patrón | Ejemplo |
|---|---|---|
| Nodo | `NODE-{EMPRESA}-{TABLA_UPPER}-{NNN}` | `NODE-ITC-MPRODUCT-001` |
| Arista | `EDGE-{EMPRESA}-{SP_SLUG_UPPER}-{NNN}` | `EDGE-ITC-SPSA-LOAD-001` |
| Trazabilidad | `COLLINEAGE-{EMPRESA}-{EDGE_SLUG}-{NNN}` | `COLLINEAGE-ITC-SPSA-LOAD-001` |

> `{NNN}` = secuencial de 3 dígitos dentro del módulo (`001`, `002`, ...).
> El `asset` del nodo usa FQN en minúsculas: `{project}.{dataset}.{tabla}`.

### Tipos de arista

| `edge_type` | Cuándo usar |
|---|---|
| `direct` | La tabla destino es una copia directa (sin agregación ni cálculo) |
| `derived` | Hay transformaciones, joins, filtros o cálculos (caso más común) |
| `aggregated` | El destino es el resultado de una agregación (GROUP BY, SUM, COUNT, etc.) |

---

## 6. Payloads de Registro — Etapa LINEAGE

El framework Dataops (`metadata_register.sh`) lee los payloads JSON desde las rutas indicadas
en `deploy_[env].json`, obtiene el token OIDC y registra nodos y aristas vía API.
No se generan scripts `.sh` en el repositorio del módulo.

### Estructura de archivos

```
data/lineage/{dataset_out}/{tabla_out}/
└── payloads/
    ├── node_{tabla_out}.json                    ← nodo de la tabla final (único, sin sufijo de empresa)
    ├── node_{tabla_out}_{emp}.json               ← nodo de staging, uno por fuente/empresa
    ├── edge_sp_{tabla_out}_{emp}.json            ← una arista por SP/fuente
    └── column_{tabla_out}_{emp}_{nnn}.json       ← uno por trazabilidad (si aplica)
```

> El nombre de archivo siempre se deriva de `{tabla_out}` (prefijo) y `{emp}` (sufijo, si aplica) —
> nunca un slug libre — para que dos desarrollos no nombren distinto el mismo tipo de payload.
> El framework garantiza el orden correcto: nodos antes que aristas (RN-ITC-002),
> aristas antes que trazabilidad columnar (RN-ITC-003).
> Los 409 (ya existe) se tratan como no-error — la operación es idempotente.

### Template: `payloads/node_{tabla_out}[_{emp}].json`

```json
{
  "node_id": "NODE-{EMPRESA}-{TABLA}-001",
  "asset": "{project}.{dataset}.{tabla}",
  "node_type": "input",
  "node_label": "{tabla}",
  "description": "{descripción del asset}",
  "owner_team": "data-platform",
  "is_active": true,
  "record_source": "lineage-api",
  "creation_user": "dataops-deploy"
}
```

### Template: `payloads/edge_sp_{tabla_out}_{emp}.json`

```json
{
  "edge_id": "EDGE-{EMPRESA}-{SP_SLUG}-001",
  "source_node_id": "NODE-{EMPRESA}-{TABLA_FUENTE}-001",
  "target_node_id": "NODE-{EMPRESA}-{TABLA_DESTINO}-001",
  "process_name": "sp_{nombre}",
  "edge_type": "derived",
  "is_active": true,
  "record_source": "lineage-api",
  "creation_user": "dataops-deploy"
}
```

### Template: `payloads/column_{tabla_out}_{emp}_{nnn}.json`

```json
{
  "col_lineage_id": "COLLINEAGE-{EMPRESA}-{EDGE_SLUG}-001",
  "edge_id": "EDGE-{EMPRESA}-{SP_SLUG}-001",
  "source_column": "{campo_fuente}",
  "target_column": "{campo_destino}",
  "transformation_type": "direct",
  "transformation_expr": null,
  "is_active": true,
  "record_source": "lineage-api",
  "creation_user": "dataops-deploy"
}
```

---

## 7. Integración en `deploy/deploy_[env].json`

```json
{
  "bigquery_ddl":  [...],
  "bigquery_sp":   [...],
  "workflow":      [...],
  "cloud_scheduler": [...],
  "monitoring_register": [...],
  "lineage_register": [
    "/data/lineage/{dataset_out}/{tabla_out}/payloads"
  ]
}
```

> `lineage_register` se ejecuta **después de `monitoring_register`** en la cadena de Cloud Build.
> La entrada puede ser un directorio (procesa todos los `.json`) o archivos individuales.
> El framework detecta por contenido: `edge_id` → arista, `node_id` → nodo.
> Orden garantizado: nodos antes que aristas.

---

## 8. Checklist de la etapa LINEAGE

- [ ] Bloque `lineage:` en spec con `nodes[]` y `edges[]` definidos
- [ ] `node_id` único por nodo; convención `NODE-{EMPRESA}-{TABLA}-{NNN}`
- [ ] `asset` de cada nodo sigue formato `{project}.{dataset}.{tabla}` (3 partes con `.`)
- [ ] `node_type` correcto: `input` para fuentes, `output` para destino, `temp` para intermedias
- [ ] `edge_id` único; convención `EDGE-{EMPRESA}-{SP_SLUG}-{NNN}`
- [ ] `source_node_id` y `target_node_id` coinciden con `node_id` de nodos registrados
- [ ] `edge_type` apropiado: `derived` para transformaciones, `direct` para copias, `aggregated` para GROUP BY
- [ ] `process_name` en arista = nombre del SP que realiza la transformación
- [ ] Payloads JSON en `data/lineage/{dataset_out}/{tabla_out}/payloads/`, nombrados
      `node_{tabla_out}[_{emp}].json` / `edge_sp_{tabla_out}_{emp}.json` (nunca un slug libre)
- [ ] `deploy_dev.json` contiene clave `lineage_register` apuntando al directorio de payloads
- [ ] `env_dev.json` contiene `METADATA_API_URL` (compartida con monitoring si ya existe)
- [ ] `env_prd.json` contiene `METADATA_API_URL`: `https://prd-itcbi-spld-run-usct1-pv01-947655304508.us-central1.run.app`
- [ ] Si hay trazabilidad columnar: `col_lineage_id` único; `source_column` null si es columna calculada

---

## 9. Referencia cruzada

- `@data/standard/factory/monitoring.md` — patrón análogo para registro de procesos
- `@data/skills/build/lineage/lineage-configurator/SKILL.md` — skill operativo
- Framework de linaje: `D:\workspace\google\cloud_sdk\source_repositories\dataops\itcm-dp-dataops-api-metadata` — módulo `/api/v1/lineage/`
