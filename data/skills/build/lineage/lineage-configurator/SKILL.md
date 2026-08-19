# Skill: Lineage Configurator

> **Rol:** Registrador de Linaje de Datos — ITC Data Platform
> **Activado por:** `/data:implement-stage LINEAGE`
> **Aplica a:** módulos `bq_pipeline` con SPs que cargan tablas BigQuery
> **Condición de activación:** `etapas.lineage: true` en `spec.yaml`
>
> **Estándar de referencia:**
> - `@.claude/data/standard/factory/lineage.md` — modelo de datos, endpoints, templates completos
>
> Este skill es **independiente de MONITORING y DATAOPS**. Se ejecuta después de MONITORING
> y DATA_QUALITY. Los scripts generados se registran en `deploy_dev.json` y se ejecutan
> durante el despliegue con Cloud Build.

---

## 1. Rol y Responsabilidades

El **Lineage Configurator** registra el grafo de transformaciones del pipeline en el
framework de linaje de datos:

| Responsabilidad | Artefacto que genera |
|---|---|
| Definir nodos (assets) | Payloads JSON en `data/lineage/{dataset_out}/{tabla_out}/payloads/node_{tabla_out}[_{emp}].json` |
| Definir aristas (relaciones) | Payloads JSON en `data/lineage/{dataset_out}/{tabla_out}/payloads/edge_sp_{tabla_out}_{emp}.json` |
| Definir trazabilidad columnar | Payloads JSON en `data/lineage/{dataset_out}/{tabla_out}/payloads/column_{tabla_out}_{emp}_{nnn}.json` (opcional) |
| Config del deploy JSON | Agrega clave `lineage_register` en `deploy/deploy_[env].json` |

---

## Paso 0 — Leer contexto del módulo

Leer en paralelo:

```
1. {ruta del spec.yaml}                                    → bloque lineage, fuentes, outputs, componentes
2. data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql        → parámetros IN (fuentes), tablas tmp y destino
3. data/bigquery/{dataset_out}/{tabla_out}/ddl/*.sql       → campos del output (para trazabilidad columnar)
4. deploy/deploy_dev.json                                  → estructura actual
5. deploy/env_dev.json                                     → verificar METADATA_API_URL
```

---

## Paso 1 — Verificar prerequisitos

| Prerequisito | Cómo verificar |
|---|---|
| `etapas.lineage: true` en spec | Leer spec.yaml → bloque etapas |
| Bloque `lineage:` en spec con `nodes[]` y `edges[]` | Leer spec.yaml → bloque lineage |
| `METADATA_API_URL` en `env_dev.json` | Leer deploy/env_dev.json |

Si el bloque `lineage:` no existe en el spec → generarlo a partir de las fuentes y outputs
antes de continuar (ver Paso 2.1).

---

## Paso 2 — Derivar el grafo desde el spec y los SPs

### 2.1 — Identificar nodos

Fuentes de cada tipo de nodo:

| `node_type` | Fuente de datos | Cómo identificarlo |
|---|---|---|
| `input` | `spec.fuentes[]` | Tablas de entrada del pipeline (proyecto + dataset + tabla) |
| `output` | `spec.outputs[]` | Tabla destino final (capa business/master) |
| `temp` | Tablas `tmp_*` del SP | Opcional — solo si son relevantes para el linaje |

Para cada nodo, construir:
- `node_id`: `NODE-{EMPRESA_UPPER}-{TABLA_UPPER}-{NNN}` — ej: `NODE-ITC-SPSA-MPRODUCT-001`
- `asset`: FQN exacto `{project}.{dataset}.{tabla}` — extraer de variables del spec o del SP
- `node_type`: según tabla
- `node_label`: nombre corto de la tabla (sin proyecto ni dataset)

### 2.2 — Identificar aristas

Una arista por cada SP del pipeline:
- `source_node_id`: nodo de la tabla fuente principal del SP
- `target_node_id`: nodo de la tabla destino del SP
- `process_name`: nombre del SP (sin FQN — solo el nombre)
- `edge_type`: inferir del tipo de transformación:
  - `derived` → JOIN, CASE WHEN, cálculos, SHA256, filtros
  - `direct` → copia simple sin transformación
  - `aggregated` → GROUP BY, SUM, COUNT, AVG como lógica central

### 2.3 — Trazabilidad columnar (opcional)

Completar solo si el spec o el equipo lo solicitan explícitamente.
Leer el SP para mapear columnas origen → destino con su `transformation_type`.

---

## Paso 3 — Generar payloads JSON

### Nodos — `data/lineage/{dataset_out}/{tabla_out}/payloads/node_{tabla_out}[_{emp}].json`

```json
{
  "node_id": "NODE-{EMPRESA}-{TABLA}-{NNN}",
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

### Aristas — `data/lineage/{dataset_out}/{tabla_out}/payloads/edge_sp_{tabla_out}_{emp}.json`

```json
{
  "edge_id": "EDGE-{EMPRESA}-{SP_SLUG}-{NNN}",
  "source_node_id": "NODE-{EMPRESA}-{TABLA_FUENTE}-{NNN}",
  "target_node_id": "NODE-{EMPRESA}-{TABLA_DESTINO}-{NNN}",
  "process_name": "sp_{nombre}",
  "edge_type": "derived",
  "is_active": true,
  "record_source": "lineage-api",
  "creation_user": "dataops-deploy"
}
```

### Trazabilidad columnar — `data/lineage/{dataset_out}/{tabla_out}/payloads/column_{tabla_out}_{emp}_{nnn}.json` (si aplica)

```json
{
  "col_lineage_id": "COLLINEAGE-{EMPRESA}-{EDGE_SLUG}-{NNN}",
  "edge_id": "EDGE-{EMPRESA}-{SP_SLUG}-{NNN}",
  "source_column": "{campo_fuente}",
  "target_column": "{campo_destino}",
  "transformation_type": "direct",
  "transformation_expr": null,
  "is_active": true,
  "record_source": "lineage-api",
  "creation_user": "dataops-deploy"
}
```

> `source_column` puede ser `null` para columnas calculadas sin fuente directa (ej: `SESSION_USER()`, `CURRENT_DATE()`).
> Ver tipos válidos de `transformation_type` en `@.claude/data/standard/factory/lineage.md` — Sección 3.

---

## Paso 4 — Actualizar `deploy/deploy_[env].json`

Agregar `lineage_register` **después de `monitoring_register`**:

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

> El framework (`metadata_register.sh`) detecta el tipo de cada payload por su contenido
> (`edge_id` → arista, `node_id` → nodo) y garantiza el orden de registro: nodos antes que aristas.
> Los payloads de trazabilidad columnar se incluyen en el mismo directorio — el framework los
> clasifica automáticamente si se agregan en el futuro.

---

## Paso 5 — Reporte de etapa

```
## Etapa completada: LINEAGE
SPEC: {id}  |  type: {type}  |  módulo: {nombre}

### Artefactos generados
- ✅ data/lineage/{dataset_out}/{tabla_out}/payloads/node_{tabla_out}[_{emp}].json  ({N} nodos)
- ✅ data/lineage/{dataset_out}/{tabla_out}/payloads/edge_sp_{tabla_out}_{emp}.json  ({N} aristas)
- ✅ data/lineage/{dataset_out}/{tabla_out}/payloads/column_*.json     ({N} trazabilidades — si aplica)
- ✅ deploy/deploy_dev.json — clave lineage_register agregada

### Grafo registrado
{Describir brevemente: N nodos (input/output/temp), N aristas, tipo predominante}

### Prerequisito IAM (si no está configurado)
- ⬜ SA de Cloud Build debe tener roles/run.invoker sobre la metadata API
  SA: trv-itcbi-devops-app@itc-data-devops-01.iam.gserviceaccount.com

### Próxima etapa sugerida
/data:implement-stage DATAOPS {id_modulo}
```

---

## Checklist de calidad

- [ ] Bloque `lineage:` en spec con `nodes[]` y `edges[]` definidos
- [ ] `node_id` único; convención `NODE-{EMPRESA}-{TABLA}-{NNN}`
- [ ] `asset` de cada nodo en formato `{project}.{dataset}.{tabla}` — exactamente 3 partes separadas por `.`
- [ ] `node_type` correcto: `input` / `output` / `temp`
- [ ] `edge_id` único; convención `EDGE-{EMPRESA}-{SP_SLUG}-{NNN}`
- [ ] `source_node_id` y `target_node_id` referencian `node_id` existentes en los payloads
- [ ] `edge_type` apropiado para el tipo de transformación
- [ ] Payloads JSON en `data/lineage/{dataset_out}/{tabla_out}/payloads/`, nombrados por `{tabla_out}[_{emp}]`
- [ ] `deploy_dev.json` contiene clave `lineage_register` apuntando al directorio de payloads
- [ ] `METADATA_API_URL` en `env_dev.json` (compartida con monitoring)
