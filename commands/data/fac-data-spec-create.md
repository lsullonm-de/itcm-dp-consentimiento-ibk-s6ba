# Crear Especificación de Desarrollo

Genera un `spec.yaml` scaffoldeado y los `docs/feature_spec/{feature}/spec.md` por output para
un nuevo módulo de desarrollo. Lee el contexto del repo y los glosarios disponibles para
pre-completar lo que puede inferir. Deja `~` en los campos que requieren decisión del equipo.

**Argumento (`$ARGUMENTS`):** descripción libre del desarrollo
```
/spec-create "Atributo de nivel educativo para scoring crediticio"
/spec-create "ETL de transacciones retail para capa Business"
/spec-create "Pipeline de productivización modelo de churn Farmacias"
/spec-create "API REST de consulta de score crediticio"
/spec-create "Cloud Function notificador de carga de atributos"
```

> **Cuándo usar:** al iniciar cualquier nuevo módulo — antes de DESIGN, CODING o cualquier
> otra etapa. El spec.yaml es el input obligatorio de todo el flujo de fábrica.

---

## Paso 0 — Leer contexto del repo

Antes de generar, leer en paralelo:

```
1. project.manifest.yaml    → si existe, tomar nota de módulos activos y stack declarado
2. docs/specs/*.yaml        → si existe spec previo Y no hay project.manifest.yaml, reportar y salir
3. docs/TODO.md             → si existe, tomar nota del estado actual
4. deploy/env_dev.json                                → si existe, extraer variables como candidatas a fuentes/outputs
5. data/bigquery/**/ddl/*.sql                         → si existen DDLs (solo para type bq_pipeline):
                               - extraer nombre de tablas output (y {dataset_out}/{tabla_out} de la ruta si ya sigue el Lineamiento 2026)
                               - detectar campos de negocio y auditoría presentes
                               - identificar si tiene partición (PARTITION BY)
6. data/bigquery/**/sp/*.sql                          → si existen SPs (solo para type bq_pipeline):
                               - extraer todas las variables ${...} usadas → candidatas a fuentes
                               - detectar tablas referenciadas → confirmar fuentes y outputs
                               - detectar dataset_stage, dataset_sp, dataset_dq usados
                               - detectar bloques de lógica DQ si hay sp_dq_*
                               - el sufijo del nombre de archivo (`sp_{tabla}_{emp}.sql`) es candidato a `fuentes[].id`
```

> **Escenario de migración / productivización:** si ya existen DDLs y SPs en el repo (en cualquier
> ruta, incluida la plana de convenciones antiguas), el comando los detecta igual vía glob
> recursivo. Al generar el scaffold con `fac-data-init-project` se reubicarán bajo
> `data/bigquery/{dataset_out}/{tabla_out}/ddl|sp/` (Lineamiento 2026) — ver
> `@.claude/data/standard/factory/repositories.md`. El command pre-completa `fuentes`, `outputs`,
> `componentes` y las variables para `env_dev.json` desde el código real — minimizando los campos
> que quedan en `~`.

Si ya existe un `docs/specs/*.yaml` y **no** hay `project.manifest.yaml` → detener y avisar:
```
⚠️ Ya existe un spec (ID: spec-itc-YYYYMMDD-{slug}, status: draft)
   Usa /spec-update para modificar un campo específico.
   Usa /spec-validate para auditar el spec actual.
   Si quieres agregar un nuevo módulo al repo, crea primero project.manifest.yaml.
```

---

## Paso 1 — Inferir `type` del módulo

Este es el paso más importante: determina el **skill a activar** y el **schema del spec**.

A partir del argumento, inferir el `type`:

| Palabras clave en descripción | `type` inferido | Schema a usar |
|---|---|---|
| atributo, attribute, feature, ETL, pipeline BQ, SP, stored procedure, tabla | `bq_pipeline` | `@.claude/data/standard/factory/spec-manifest.md` |
| API, REST, endpoint, Cloud Run, FastAPI, servicio web, consulta en tiempo real | `cloud_run_api` | `@.claude/data/standard/factory/spec-types/spec-cloud-run-api.md` |
| modelo ML, productivizar, scoring ML, Vertex, KFP, pipeline entrenamiento, inferencia | `vertex_ml` | `@.claude/data/standard/factory/spec-types/spec-vertex-ml.md` |
| Cloud Function, function, notificador, webhook, event-driven, trigger Pub/Sub | `cloud_function` | `@.claude/data/standard/factory/spec-types/spec-cloud-function.md` |

Si no se puede inferir con confianza → preguntar al usuario antes de continuar:
```
❓ No pude determinar el tipo de módulo con confianza.
   ¿Cuál corresponde a tu desarrollo?
   1. bq_pipeline     → BigQuery: DDL + SP + Workflow
   2. cloud_run_api   → API REST en Cloud Run (+ Cloud SQL si aplica)
   3. vertex_ml       → Pipeline ML en Vertex AI / KFP
   4. cloud_function  → Función event-driven (Pub/Sub, GCS, HTTP)
```

Una vez determinado el `type`, cargar el schema correspondiente para los pasos siguientes.

---

## Paso 1b — Inferir `tipo_flujo` (dentro del contexto del type)

Solo para `type: bq_pipeline`. Inferir `tipo_flujo`:

| Palabras clave en descripción | tipo_flujo inferido |
|---|---|
| atributo, attribute, feature, columna nueva | `atributos` |
| ETL, carga, pipeline, transacciones, consolidar | `etl` |
| reporte, looker, dashboard, visualización | `reportes-looker` |
| análisis, exploración, profiling | `analisis-informacion` |
| insight, segmentación, clustering | `insights` |
| migrar, matillion, migración | `migracion-matillion` |
| proceso BQ, stored procedure, SP existente | `productivizacion-proceso-bq` |

Para `cloud_run_api`: `tipo_flujo: api` (fijo).
Para `vertex_ml`: `tipo_flujo: productivizacion-modelo` (fijo).
Para `cloud_function`: `tipo_flujo: api` (fijo).

Si no se puede inferir `tipo_flujo` para bq_pipeline → dejar `~` y agregar comentario.

---

## Paso 2 — Determinar ubicación del spec

Todos los specs van en `docs/specs/` independientemente del `type`:

```
docs/specs/spec-itc-{yyyymmdd}-{slug}.yaml
```

El nombre del archivo es el ID generado en Paso 3.

> Esto aplica para todos los tipos: `bq_pipeline`, `cloud_run_api`, `vertex_ml`, `cloud_function`.
> Ver: `@.claude/data/standard/factory/project-manifest.md` — Sección "Ubicación del archivo"

---

## Paso 3 — Generar ID

```
spec-itc-{yyyymmdd}-{slug}
```

- `YYYYMMDD`: fecha actual
- `NNN`: `001` (si no hay specs previos en `docs/specs/`) o siguiente secuencial
- Verificar si existe algún archivo `spec-itc-{yyyymmdd}-*.yaml` en `docs/specs/`

---

## Paso 4 — Scaffoldear spec.yaml

Generar el spec usando el schema del `type` determinado en Paso 1. Bloques del bloque raíz:

### Bloque raíz
```yaml
id: spec-itc-{yyyymmdd}-{slug}        # calculado en Paso 3
version: "1.0"
status: draft
empresa: itc
equipo: data-platform
fecha: "{YYYY-MM-DD}"                 # fecha actual
autor: ~                              # dejar null — el dev lo completa
aprobador: ~
```

### `contexto`
- `nombre`: extraer de $ARGUMENTS (forma sustantiva breve)
- `tipo_flujo`: inferido en Paso 1 o `~`
- `descripcion`: parafrasear $ARGUMENTS en max 2 oraciones
- `objetivo_negocio`: `~`
- `data_owner`: `~`
- `business_steward`: `~`
- `kpis`: lista vacía `[]`

### `etapas`

Las etapas siguen el orden del flujo de fábrica. Activar según `tipo_flujo`:

```yaml
# Orden canónico — BUILD cierra con dataops, VERIFY inicia con compliance
etapas:
  plan:          true   # siempre true
  design:        false  # DESIGN
  coding:        false  # BUILD
  orchestration: false  # BUILD
  integridad:    false  # BUILD — solo bq_pipeline; gate de actualidad/duplicados/llaves nulas sobre fuentes
  monitoring:    false  # BUILD — control de procesos (bq_pipeline con SPs + workflow)
  data_quality:  false  # BUILD
  lineage:       false  # BUILD — registro de linaje de datos (bq_pipeline con SPs)
  dataops:       false  # BUILD — cierra BUILD: deploy configs + env vars
  compliance:    false  # VERIFY
  testing:       false  # VERIFY
  infraops:      false  # RELEASE — crear SAs + roles IAM (ejecuta equipo infra)
  security:      false  # RELEASE — auditar permisos creados por infraops
  documentation: false  # RELEASE
```

> **`monitoring`:** solo activar para `bq_pipeline` con Cloud Workflow que invoca SPs.
> Requiere que la metadata API (`itcm-dp-dataops-api-metadata`) esté desplegada en el ambiente.
> Ver: `@data/standard/factory/monitoring.md`

| tipo_flujo | Etapas activadas por defecto (`true`) |
|---|---|
| `etl` / `atributos` | design, coding, orchestration, dataops, compliance, infraops, security, documentation |
| `productivizacion-modelo` | design, coding, orchestration, dataops, compliance, infraops, security, documentation |
| `reportes-looker` | design, coding, orchestration, dataops, compliance, infraops, documentation |
| `analisis-informacion` | design, coding, documentation |
| `cloud_function` | design, coding, dataops, compliance, infraops, security, documentation |
| `cloud_run_api` | design, coding, orchestration, dataops, compliance, infraops, security, documentation |
| `vertex_ml` | design, coding, orchestration, dataops, compliance, infraops, security, documentation |

> **`integridad`** solo aplica a `type: bq_pipeline` — para `cloud_run_api`, `cloud_function`
> y `vertex_ml` siempre queda `false`. En `bq_pipeline` el equipo lo activa manualmente cuando
> la fuente principal requiere gate de actualidad D-1, o alguna fuente requiere excluir
> duplicados/llaves nulas. Si se activa, `fuentes[].rol/tipo_fuente/llave` y el bloque
> `reglas_integridad` son obligatorios (ver `@.claude/data/standard/data-integrity.md`).
> **`data_quality`** se deja `false` por defecto en todos los tipos — el equipo lo activa manualmente cuando se requiere implementar reglas DQ.
> **`testing`** se deja `false` por defecto en todos los tipos — el equipo lo activa manualmente cuando el ambiente dev está listo para validación dinámica vía MCP BigQuery.
> **`monitoring`** se deja `false` por defecto en todos los tipos — el equipo lo activa
> manualmente en el spec cuando la metadata API está disponible y el módulo requiere
> trazabilidad de ejecuciones.

---

### Bloques específicos para `cloud_run_api`

> **Para `type: cloud_run_api` los bloques `fuentes`, `outputs` y `data_quality` NO se generan.**
> En su lugar generar `endpoints` y `datasources` como se indica a continuación.
> Los bloques genéricos siguientes (`fuentes`, `outputs`, `data_quality`) aplican solo a `bq_pipeline`.

#### `endpoints` (reemplaza `fuentes` + `outputs` para cloud_run_api)

Scaffoldear 1 placeholder por cada endpoint mencionado en el argumento.
Cada item **debe** tener los siguientes campos como propiedades separadas — **no combinar `method` en `path`**:

```yaml
endpoints:
  - id: {verbo}_{recurso}              # ej: get_rule_config, post_run_stats
    method: GET                         # GET | POST | PUT | PATCH | DELETE
    path: /api/v1/{prefijo}/{recurso}  # solo la ruta — sin método
    descripcion: ~
    autenticacion: service_account      # api_key | service_account | none
    request_body: ~                     # ~ si no aplica (ej: GET)
    response: ~
    datasources: []                     # IDs de datasources que consulta este endpoint
    latencia_max_ms: ~
    pii_en_response: false
```

#### `datasources` (reemplaza `fuentes` para cloud_run_api)

Usar **sub-bloques** `cloud_sql:` y `bigquery:` — **no** lista plana con campo `tipo:`.
Omitir el sub-bloque completo si ese datasource no aplica al módulo.

```yaml
datasources:
  cloud_sql:                              # omitir si no hay Cloud SQL en este módulo
    - id: {nombre_logical}               # ej: metadata_db, dq_db
      instance: "${env}-itc-{caso}-db"
      database: ~
      schema: public
      conexion: unix_socket
      ddl: data/postgresql/ddl/{tabla}.sql
      tablas:
        - nombre: ~
          operacion: read_write           # read | write | read_write
          descripcion: ~

  bigquery:                               # omitir si no hay BigQuery
    - id: {alias}
      proyecto: "${project_{tabla}}"
      dataset: "${dataset_{tabla}}"
      tabla: "${table_{tabla}}"
      operacion: read                     # APIs no escriben directamente a BQ
      descripcion: ~
```

> **El bloque `ddl:` separado no existe en el schema de `cloud_run_api`.**
> Los DDL PostgreSQL van en `componentes` con `tipo: ddl_pg` (ver sección `componentes` más abajo).

---

### `fuentes`

Prioridad de extracción (de mayor a menor confianza):

| Fuente de datos | Qué extrae | Confianza |
|---|---|---|
| `data/bigquery/**/sp/*.sql` | Variables `${project_X}`, `${dataset_X}`, `${table_X}` → cada grupo de 3 = 1 fuente | Alta |
| `deploy/env_dev.json` | Claves con prefijo `project_` / `dataset_` / `table_` agrupadas | Alta |
| Sin contexto | Placeholder con `id: fuente_1`, campos `~` | Baja |

Para cada fuente detectada, generar un item con:
- `id`: derivado del sufijo de la variable (ej: `${table_ba_itc_attr_rcc}` → `id: rcc`)
- `proyecto`: `"${project_ba_itc_attr_rcc}"`
- `dataset`: `"${dataset_ba_itc_attr_rcc}"`
- `tabla`: `"${table_ba_itc_attr_rcc}"`
- `pii`: `~` (el dev lo determina)

**Si `etapas.integridad: true`**, agregar además:
- `rol`: `principal` a la **primera** fuente detectada, `secundaria` al resto. Si el argumento o
  el DDL/SP dejan claro cuál es el universo del proceso, usar esa en su lugar
- `tipo_fuente`: `tabla` si se detectó desde `data/bigquery/**/sp/*.sql` o `env_dev.json`;
  `archivo` si el argumento menciona CSV/GCS/archivo plano; `~` si no se puede inferir
- `llave`: `[]` (placeholder — el dev completa las columnas de la llave de negocio)
- `campo_fecha`: `load_date` si el DDL de la fuente lo declara; sino `~`

### `outputs`

Prioridad de extracción:

| Fuente de datos | Qué extrae | Confianza |
|---|---|---|
| `data/bigquery/**/ddl/*.sql` | Nombre de tabla del `CREATE TABLE`, campos presentes, partición | Alta |
| `data/bigquery/**/sp/*.sql` | Tabla en el `INSERT INTO` o `MERGE INTO` final | Alta |
| Sin contexto | Placeholder con campos `~` | Baja |

Para cada output detectado, completar:
- `tabla`: nombre físico extraído del DDL/SP
- `capa`: inferida del prefijo (`ba_` → `business`, `m_` → `master`, `t_` → `master`)
- `particion`: `load_date` si el DDL tiene `PARTITION BY load_date`, sino `~`
- `campos_auditoria`: los que aparezcan en el DDL (`load_date`, `record_source`, `creation_user`)

### `reglas_integridad`

Solo generar este bloque si `etapas.integridad: true`. Derivar las reglas de `fuentes[].rol` y
`fuentes[].llave` — no se redactan a mano:

```yaml
reglas_integridad:
  fuente_principal: {id de la fuente con rol: principal}
  dias_tolerancia: 1
  registro_resultados: true      # histórico del gate en metadata_operational vía metadata API
  reglas:
    - id: RI-ITC-{ASSET_CORTO}-001
      fuente_id: {id fuente principal}
      tipo_check: actualidad
      accion: detener_proceso
    - id: RI-ITC-{ASSET_CORTO}-002
      fuente_id: {id fuente principal}
      tipo_check: duplicados
      accion: excluir_registros
    - id: RI-ITC-{ASSET_CORTO}-003
      fuente_id: {id fuente principal}
      tipo_check: llave_nula
      accion: excluir_registros
    # ... repetir el par (duplicados, llave_nula) por cada fuente secundaria
```

> Ver framework completo: `@.claude/data/standard/data-integrity.md`

### `reglas_negocio`
- Generar 1 placeholder: `id: RN-ITC-001`, `descripcion: ~`, `criticidad: alta`

### `componentes`

`ddl` y `sp` son **transversales** — incluirlos siempre que el módulo produzca o consuma
tablas BigQuery, independientemente del `type`. El resto de componentes depende de la línea
de trabajo.

| `type` / `tipo_flujo` | Componentes mínimos |
|---|---|
| `bq_pipeline` etl / atributos | **ddl + sp** + workflow + cloud_scheduler |
| `bq_pipeline` productivizacion-proceso-bq | **ddl + sp** + workflow + cloud_scheduler |
| `bq_pipeline` reportes-looker | **ddl + sp** + cloud_scheduler |
| `vertex_ml` | **ddl + sp** + bucket + image + vertex_pipeline + cloud_scheduler |
| `cloud_run_api` (cualquier variante) | `ddl_pg` (por cada tabla PostgreSQL, si aplica) + **`image` (obligatorio)** + `cloud_run` (obligatorio) + `cloud_scheduler` (si aplica) + `pubsub` (si aplica) |
| `cloud_function` con BQ output | **ddl** + cloud_function + pubsub (si aplica) |
| `cloud_function` solo event | cloud_function + pubsub (si aplica) |

> **Nota `vertex_ml`:** `ddl` crea las tablas de features y output del modelo.
> `sp` implementa la lógica de preparación de datos o consolidación de resultados.
> Ambos se despliegan antes del `vertex_pipeline` en la cadena Dataops.

> **`cloud_run_api` — tipos válidos de `componente.tipo`:** `ddl_pg` | `image` | `cloud_run` | `cloud_scheduler` | `pubsub`
> **`image` es OBLIGATORIO** para todo `cloud_run_api` — sin la imagen Docker el despliegue falla.
> El YAML de imagen va en `image/{repo-artifact}/itc-{nombre-api}.yaml`; el Cloud Run en `service/cloud_run/{nombre}/deploy_config.yaml`.
> **No usar:** `cloud_sql`, `bigquery_client`, `docker`, `secret_manager` — no son tipos de componente en este schema.
> El DDL PostgreSQL va en `componentes` con `tipo: ddl_pg` (ruta `data/postgresql/ddl/`). **No** crear un bloque `ddl:` separado.
>
> **Mapeo a deploy_[env].json:** `tipo: ddl_pg` (spec) → clave `cloudsql_ddl` (deploy JSON). Análogo a `bigquery_ddl` para BigQuery.
> Al generar `deploy_dev.json` en etapa DATAOPS: usar siempre `"cloudsql_ddl": [...]`, nunca `"ddl_pg": [...]`.

### `componentes` — template para `cloud_run_api`

Scaffoldear siempre con `image` + `cloud_run` como componentes obligatorios.
Si hay Cloud SQL, agregar `ddl_pg` antes de `image`.

```yaml
componentes:
  # ── DDL PostgreSQL (solo si hay Cloud SQL) ───────────────
  - tipo: ddl_pg
    archivo: data/postgresql/ddl/{tabla}.sql
    descripcion: "Schema de tabla PostgreSQL"

  # ── Imagen Docker (OBLIGATORIO para todo cloud_run_api) ──
  - tipo: image
    archivo: image/{dataset_out}/{tabla_out}/{nombre-api}.yaml
    descripcion: "Imagen Docker del servicio en Artifact Registry"

  # ── Servicio Cloud Run (OBLIGATORIO) ──────────────────────
  - tipo: cloud_run
    archivo: service/cloud_run/{dataset_out}/{tabla_out}/{nombre-api}/deploy_config.yaml
    descripcion: "API REST FastAPI en Cloud Run"

  # ── Scheduler (solo si tiene jobs programados) ────────────
  # - tipo: cloud_scheduler
  #   archivo: pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{nombre-api}.yaml
```

> Si se detecta un Cloud Run en el requerimiento pero no hay `image` en los componentes → agregarlo automáticamente. La imagen es un prerequisito de despliegue — sin ella el `cloud_run.sh` falla.

**Contenido del archivo `image/dataops-artifacts/itc-{nombre-api}.yaml` (scaffoldear en `init-project`):**

```yaml
dockerfile: service/cloud_run/{nombre-api}/Dockerfile
name:        itc-{nombre-api}
repo:        dataops-artifacts
region:      us-central1
project:     ${project_operation}
description: "Imagen Docker del servicio {nombre-api}"
```

> Los 6 campos son **obligatorios**. `repo`, `project` y `description` son requeridos por `image.sh` del framework Dataops.
> `project` apunta al mismo GCP project que el Cloud Run — valor resuelto desde `env_dev.json` vía `_DATAOPS_VARIABLES`.
> El campo `name:` en este YAML debe coincidir con el campo `image:` del `deploy_config.yaml` del Cloud Run.

### `data_quality`
- `dataset_dq: "${dataset_dq}"`
- 1 regla placeholder: completitud de la tabla output inferida (si existe)

### `seguridad`
- `campos_pii_fuente: []`
- `campos_pii_output: []`
- `encriptacion_requerida: false`
- `hash_iden_party: false`
- `permisos: []`

**Para `cloud_run_api`, agregar además `autenticacion_api`, `secrets` y `cors_origins`:**

```yaml
seguridad:
  autenticacion_api: service_account   # api_key | service_account
  secrets:
    - nombre: db-password
      secret_manager_id: "${env}-itc-{caso}-db-password"
      descripcion: ~
    # agregar un secret por cada credencial que usa la API
  campos_pii_fuente: []
  campos_pii_output: []
  encriptacion_requerida: false
  hash_iden_party: false
  cors_origins:
    - "*"                              # solo dev — cambiar a dominio real en prd
  permisos: []
```

### `scheduling`
- `frecuencia: ~`
- `zona_horaria: America/Lima`
- `dependencias: []`
- `consumidores: []`

### `restricciones`
- Lista vacía `[]`

---

## Paso 5 — Derivar slug del feature

Para cada output del spec, derivar un `feature_slug`:
- Tomar el nombre de la tabla output (ej: `ba_itc_attr_digital`)
- Convertir a snake_case (ya lo está)
- Este slug se usará como carpeta en `docs/feature_spec/{feature_slug}/`

Si hay más de un output → un `feature_slug` por output.
Si no hay outputs definidos → usar el slug del `contexto.nombre` en minúsculas con guiones bajos.

---

## Paso 6 — Escribir el spec.yaml y generar project.manifest.yaml

Crear el spec en `docs/specs/spec-itc-{yyyymmdd}-{slug}.yaml`.
Si `docs/specs/` no existe → crearlo.

### Generación obligatoria de project.manifest.yaml

**`project.manifest.yaml` se genera SIEMPRE — incluso con un solo módulo.**

Buscar si ya existe en la raíz del repo:
- **Existe** → agregar el nuevo módulo a `modules[]` con `status: draft`, `etapa_actual: PLAN`
- **No existe** → crear con el módulo actual como primer entry

```yaml
# project.manifest.yaml
version: "1.0"
repo: {nombre-del-repo}
equipo: data-platform
stack:
  - {type del spec}

modules:
  - id: {slug}
    type: {type}
    spec: docs/specs/spec-itc-{yyyymmdd}-{slug}.yaml
    status: draft
    etapa_actual: PLAN
    descripcion: {contexto.nombre del spec}
```

> **Por qué siempre:** el manifest es el punto de entrada para `implement-stage` y todos los
> commands multi-módulo. Generarlo desde el primer spec evita tener que crearlo retroactivamente.
---

## Paso 7 — Generar `docs/feature_spec/{feature}/spec.md`

Por cada output del spec (o por el feature_slug si no hay outputs), crear:
`docs/feature_spec/{feature_slug}/spec.md`

Este archivo es el spec detallado en markdown del output — complementa el YAML y es la
referencia de diseño que consume `/data:implement-stage DESIGN`, `/data:implement-stage CODING` y
`/data:implement-stage DATA_QUALITY`.

### Template del spec.md

```markdown
# {contexto.nombre} — {tabla_output}

> **SPEC:** {spec_id} · **Status:** draft
> **Tipo:** {tipo_flujo} · **Capa:** {capa} · **Partición:** {particion}

---

## Descripción

{contexto.descripcion}

## Objetivo de Negocio

{contexto.objetivo_negocio}

---

## Fuentes de Entrada

| ID | Proyecto | Dataset | Tabla | PII |
|----|---------|---------|-------|-----|
{por cada fuente del spec}
| {id} | `{proyecto}` | `{dataset}` | `{tabla}` | {pii} |

---

## Output

**Tabla:** `${project_analytics}.${dataset_analytics}.{tabla}`
**Tipo de carga:** `{tipo_carga}`
**Partición:** `{particion}`

### Campos

> Completar en etapa DESIGN. Los campos de auditoría son obligatorios.

| Campo | Tipo BQ | Descripción | Fuente | Regla | PII |
|-------|---------|-------------|--------|-------|-----|
| _(campos de negocio — definir en DESIGN)_ | | | | | |
| `load_date` | `DATE` | Fecha de carga del proceso | Framework | Auditoría | No |
| `record_source` | `STRING` | Origen del registro | Framework | Auditoría | No |
| `creation_user` | `STRING` | SA que ejecutó la carga | Framework | Auditoría | No |

---

## Reglas de Negocio

| ID | Descripción | Criticidad | Capa |
|----|-------------|-----------|------|
{por cada regla en reglas_negocio del spec}
| {id} | {descripcion} | {criticidad} | — |

---

## Reglas de Calidad de Datos

| ID | Dimensión | Descripción | Crítica | Umbral máx. inválidos |
|----|----------|-------------|---------|----------------------|
{por cada regla en data_quality.reglas del spec}
| {id} | {dimension} | {descripcion} | {critica} | {umbral_max_pct_invalidos}% |

---

## Flujo de Transformación

```
{lista de ids de fuentes} 
    → SP `sp_{tabla}` 
    → `${dataset_stage}.tmp_{tabla}`
    → INSERT `${dataset_analytics}.{tabla}`
```

> Componentes: {lista de tipos de componentes del spec}
> Scheduling: {frecuencia} · {zona_horaria}

---

> 📄 Generado por `/spec-create` desde `{spec_id}`.
> Completar sección **Campos** y **Reglas de Negocio** en etapa DESIGN.
> Actualizar con `/spec-update` si cambia el diseño.
```

### Reglas de generación del spec.md
- Si `descripcion = ~` o `objetivo_negocio = ~` → dejar el placeholder entre paréntesis
- Si `reglas_negocio` solo tiene el placeholder → listar con estado `pendiente`
- Si `data_quality.reglas` está vacío y `etapas.data_quality = true` → agregar fila placeholder
- Si hay campos PII en fuentes → agregar nota ⚠️ en la sección Fuentes

---

## Paso 8 — Reporte

```
## Spec creado: {ID}

📄 {ruta del spec.yaml}
📋 {ruta(s) de feature_spec/*/spec.md}
🔧 type: {type}

### Pre-completado automáticamente
- id, fecha, type: {type}, tipo_flujo (inferido: {tipo_flujo})
- etapas activadas: {lista}
- fuentes/endpoints/trigger candidatos: {N}
- componentes inferidos: {lista}
- feature_spec/ generados: {N} (uno por output)
- project.manifest.yaml: {actualizado con módulo X / no existe}

### Campos que requieren completar manualmente
- contexto.objetivo_negocio
- contexto.data_owner / business_steward
- contexto.kpis
- [bq_pipeline] fuentes.proyecto / dataset / tabla (con ${variables} correctas)
- [si etapas.integridad: true] fuentes.rol / tipo_fuente / llave / campo_fecha y bloque reglas_integridad
- [cloud_run_api] endpoints.path / datasources
- [vertex_ml] modelo.umbral_aceptacion / pipelines.machine_type
- reglas_negocio (todas las RN del negocio)
- scheduling.frecuencia (si aplica)
- seguridad.campos_pii_fuente (si aplica)
- feature_spec/{feature}/spec.md → sección Campos (en etapa DESIGN)

### Próximos pasos
1. Completar los campos ~ en {ruta del spec}
2. /spec-validate → auditar el spec antes de avanzar
3. Una vez aprobado → /init-project para scaffoldear el repo
4. /data:implement-stage DISCOVERY → enriquecer fuentes con metadata BQ
```

---

## Checklist de calidad del scaffold

- [ ] `type` determinado (no `~`)
- [ ] ID generado con formato `spec-itc-YYYYMMDD-{slug}` (slug = nombre tabla o palabras clave de la funcionalidad)
- [ ] Spec en la ruta correcta `docs/specs/`
- [ ] `project.manifest.yaml` generado o actualizado (obligatorio siempre)
- [ ] Si tabla destino ya tiene spec → nuevo proceso agregado como módulo, no como spec nuevo
- [ ] `tipo_flujo` inferido o marcado `~` con comentario (solo bq_pipeline)
- [ ] Etapas activadas coherentes con el type
- [ ] Al menos 1 fuente/endpoint/trigger (aunque sea placeholder)
- [ ] **[si etapas.integridad: true]** exactamente 1 fuente con `rol: principal`; todas las fuentes con `llave` (aunque sea `[]` placeholder); bloque `reglas_integridad` generado
- [ ] Componentes mínimos definidos
- [ ] `seguridad` completo (aunque sea con valores false / [])
- [ ] **[cloud_run_api]** `endpoints[]` tienen `method`, `autenticacion`, `response`, `pii_en_response` como campos separados (no combinar `method` en `path`)
- [ ] **[cloud_run_api]** `datasources` usa sub-bloques `cloud_sql:` / `bigquery:` — no lista plana con `tipo:`
- [ ] **[cloud_run_api]** `componentes` incluye `image` (obligatorio) y `cloud_run` (obligatorio)
- [ ] **[cloud_run_api]** `componentes` solo contiene tipos válidos: `ddl_pg`, `image`, `cloud_run`, `cloud_scheduler`, `pubsub`
- [ ] **[cloud_run_api]** `seguridad` contiene `autenticacion_api`, `secrets`, `cors_origins`
- [ ] **[cloud_run_api]** NO existe bloque `ddl:` separado — los DDL PG van en `componentes` con `tipo: ddl_pg`
- [ ] **[cloud_run_api]** Al generar `deploy_dev.json` en etapa DATAOPS: usar clave `cloudsql_ddl` (no `ddl_pg`)
- [ ] **[cloud_run_api]** NO existen bloques `fuentes`, `outputs` ni `data_quality`
- [ ] Spec YAML creado exitosamente
- [ ] `docs/feature_spec/{feature}/spec.md` creado por cada output
- [ ] `project.manifest.yaml` actualizado (si existe)


