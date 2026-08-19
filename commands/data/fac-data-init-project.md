# Inicializar Proyecto DataOps

Genera la estructura de carpetas y archivos base de un nuevo repositorio DataOps ITC. Lee el
`spec.yaml` del módulo para derivar qué artefactos crear según el tipo de módulo.
No implementa lógica de negocio — eso es responsabilidad de `/data:implement-stage`.

**Argumento (`$ARGUMENTS`):**
- Sin argumento → scaffold completo desde el spec activo en `docs/specs/`
- `{id_modulo}` → scaffold para ese módulo específico (requiere `project.manifest.yaml`)
- `--check` → reporta qué archivos faltan sin crear nada
- `--force` → crea estructura aunque ya existan archivos (no sobreescribe contenido existente)
- `--with-manifest` → fuerza la creación de `project.manifest.yaml` aunque sea un solo módulo

> **Cuándo usar:** una sola vez por módulo, al iniciar el desarrollo. Requiere que el `spec.yaml`
> exista y esté en status `review` o `approved`.

---

## Paso 0 — Leer las fuentes de verdad

Leer en paralelo:

```
1. project.manifest.yaml             → si existe, tomar nota de módulos y routing
2. docs/specs/*.yaml                 → fuente de verdad del desarrollo
3. @.claude/data/standard/factory/repositories.md   → estructura canónica de carpetas
4. @.claude/data/skills/build/dataops/dataops-configurator/SKILL.md → YAMLs de despliegue
```

Verificar que el spec existe y su status no es `draft`:
```
⚠️ spec.yaml tiene status=draft
   Se recomienda completar y validar el spec (/spec-validate) antes de init-project.
   ¿Continuar de todas formas? (s para continuar)
```

Determinar el `type` del spec:
- Si `spec.type` existe → usar ese valor
- Si no existe → asumir `bq_pipeline` (compatibilidad con specs anteriores)

---

## Paso 0.5 — Determinar `{dataset_out}` y `{tabla_out}`

Del output principal del spec (`outputs[0]`, o uno por cada output si hay varios) derivar:
- `{dataset_out}` = `outputs[].dataset` (valor real, ej. `master_product`)
- `{tabla_out}` = `outputs[].tabla` (ej. `m_promotion`)
- `{tabla_out_kebab}` = `{tabla_out}` con `_` reemplazado por `-` (para nombres de recursos GCP)

Todas las carpetas de artefactos del módulo cuelgan de `{dataset_out}/{tabla_out}/` — ver
`@.claude/data/standard/factory/repositories.md` §2. Si `fuentes[]` tiene más de un origen para
la misma tabla, cada fuente `{emp}` genera su propio SP, test, Workflow y Scheduler dentro de
esa misma carpeta (nunca en carpetas separadas por empresa).

---

## Paso 1 — Detectar estado actual del repo

Las carpetas a crear dependen del `type`. `{dataset_out}/{tabla_out}` reemplaza los valores
determinados en el Paso 0.5:

| Carpeta | `bq_pipeline` | `cloud_run_api` | `vertex_ml` | `cloud_function` |
|---|---|---|---|---|
| `data/bigquery/{dataset_out}/{tabla_out}/ddl/` | ✅ | — | — | — |
| `data/bigquery/{dataset_out}/{tabla_out}/sp/` | ✅ | — | — | — |
| `data/bigquery/{dataset_out}/{tabla_out}/dml/` | si incremental o data_quality | — | — | — |
| `data/bigquery/{dataset_out}/{tabla_out}/test/` | ✅ | — | — | — |
| `data/lineage/{dataset_out}/{tabla_out}/` | si lineage=true | — | — | — |
| `data/monitoring/{dataset_out}/{tabla_out}/` | si monitoring=true | — | — | — |
| `data/postgresql/ddl/` | — | si Cloud SQL | — | — |
| `pipeline/workflow/{dataset_out}/{tabla_out}/` | si orquestacion=true | — | si Workflow | — |
| `pipeline/scheduler/{dataset_out}/{tabla_out}/` | si orquestacion=true | — | si Workflow | — |
| `service/cloud_run/{dataset_out}/{tabla_out}/` | — | ✅ | — | — |
| `service/vertex/{dataset_out}/{tabla_out}/` | — | — | ✅ | — |
| `service/cloud_function/{dataset_out}/{tabla_out}/` | — | — | — | ✅ |
| `image/{dataset_out}/{tabla_out}/` | si componente image | — | ✅ | — |
| `deploy/` | ✅ | ✅ | ✅ | ✅ |
| `docs/specs/` | ✅ | ✅ | ✅ | ✅ |
| `docs/feature_spec/` | ✅ | ✅ | ✅ | ✅ |

Si `--check`: mostrar tabla y salir sin crear nada.

---

## Paso 2 — Plan de scaffold

Antes de crear, mostrar el plan derivado del `spec.yaml`:

```
## Plan de scaffold — {spec-ID}

### Estructura de carpetas
  docs/specs/                                          ← specs de todos los módulos del repo
  docs/feature_spec/                                   ← specs en markdown por output (generados por /spec-create)
  data/bigquery/{dataset_out}/{tabla_out}/ddl/         ← {N} tablas output detectadas  (solo bq_pipeline)
  data/bigquery/{dataset_out}/{tabla_out}/sp/          ← SP de carga (uno por fuente) + SP DQ (si data_quality=true)
  pipeline/workflow/{dataset_out}/{tabla_out}/         ← un workflow por fuente (orquestacion=true)
  pipeline/scheduler/{dataset_out}/{tabla_out}/        ← un scheduler por fuente (orquestacion=true)

### Archivos generados
  deploy/deploy_dev.json
  deploy/deploy_prd.json
  deploy/env_dev.json        ← {N} variables (desde fuentes + outputs del spec)
  deploy/env_prd.json        ← ídem
  docs/brief.md              ← generado desde contexto del spec
  docs/TODO.md               ← checklist de etapas aplicables

### Componentes detectados en spec.yaml
  {lista de componentes del bloque `componentes`}

¿Procedo con la creación? (s/n)
```

---

## Paso 3 — Crear estructura de carpetas

Crear las carpetas necesarias con un `.gitkeep` donde corresponde:

```
docs/
├── specs/                                   ← todos los specs del repo (siempre)
├── feature_spec/                            ← specs markdown por output (siempre; creados por /spec-create)
│   └── {feature_slug}/
│       └── spec.md                          ← ya existe si se ejecutó /spec-create
data/
├── bigquery/
│   └── {dataset_out}/{tabla_out}/
│       ├── ddl/
│       ├── sp/
│       ├── dml/                             ← solo si tipo_carga: incremental o data_quality=true
│       └── test/
├── lineage/{dataset_out}/{tabla_out}/       ← solo si etapas.lineage=true
└── monitoring/{dataset_out}/{tabla_out}/    ← solo si etapas.monitoring=true
image/{dataset_out}/{tabla_out}/            ← solo si componente tipo=image
service/
│   ├── cloud_run/{dataset_out}/{tabla_out}/         ← solo si componente tipo=cloud_run
│   ├── cloud_function/{dataset_out}/{tabla_out}/    ← solo si componente tipo=cloud_function
│   └── vertex/{dataset_out}/{tabla_out}/            ← solo si componente tipo=vertex_pipeline
pipeline/
│   ├── workflow/{dataset_out}/{tabla_out}/   ← solo si etapas.orquestacion=true (uno por fuente)
│   └── scheduler/{dataset_out}/{tabla_out}/  ← solo si etapas.orquestacion=true (uno por fuente)
deploy/
```

---

## Paso 4 — Generar `deploy/env_dev.json` y `deploy/env_prd.json`

Construir los archivos de variables desde el spec.yaml, siguiendo la regla de orden por tabla
(`@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`):

```json
{
  "project_operation": "pendiente_definir",
  "project_analytics": "pendiente_definir",
  "project_billing":   "pendiente_definir",

  "dataset_sp":        "stored_procedures",
  "dataset_stage":     "stage_tmp",
  "dataset_analytics": "pendiente_definir",

  // DQ (si etapas.data_quality=true)
  "dataset_dq":        "pendiente_definir",

  // SA creadas por InfraOps — completar tras etapa INFRAOPS
  "service_account_job": "pendiente_definir",
  "service_account_app": "pendiente_definir",

  // Variables por tabla de entrada — ordenadas: project → dataset → table
  "project_{fuente_id}":   "pendiente_definir",
  "dataset_{fuente_id}":   "pendiente_definir",
  "table_{fuente_id}":     "pendiente_definir",

  // Buckets (si el spec declara componentes tipo bucket)
  "bucket_{nombre}":       "pendiente_definir",

  // Pub/Sub para mail (si el spec tiene orchestration=true o notificaciones)
  "mail_pubsub_project": "central-data-governance-260223",
  "mail_pubsub_topic":   "itcm-mail"
}
```

`env_prd.json`: misma estructura con los siguientes valores fijos de producción para mail:
```json
  "mail_pubsub_project": "stalwart-motif-270218",
  "mail_pubsub_topic":   "itcm-inca-mail"
```
El resto de valores va como `"pendiente_definir"`.

> **Regla:** la variable `env` no se incluye — es global del framework Dataops.
> Omitir secciones que no apliquen al spec (buckets, DQ, mail) para no generar variables huérfanas.
> Ver: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

---

## Paso 5 — Generar `deploy/deploy_dev.json` y `deploy/deploy_prd.json`

Generar los archivos de despliegue con los componentes del spec. El formato es **una clave por
tipo de componente con la lista de rutas** — no una lista de objetos:

```json
{
  "bigquery_ddl":  ["/data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql"],
  "bigquery_sp":   ["/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql"],
  "cloudsql_ddl":  ["/data/postgresql/ddl/{tabla}.sql"],
  "image":         ["/image/dataops-artifacts/itc-{nombre-api}.yaml"],
  "cloud_run":     ["/service/cloud_run/{nombre-api}/deploy_config.yaml"],
  "workflow":      ["/pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml"],
  "cloud_scheduler": ["/pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml"]
}
```

- Rutas **absolutas desde la raíz del repo**, con `/` inicial
- El orden dentro de cada lista importa: FK en DDL, `image` antes de `cloud_run`,
  `monitoring_register` después de `cloud_scheduler`
- `tipo: ddl_pg` del spec mapea a la clave **`cloudsql_ddl`** — nunca `ddl_pg` en el deploy JSON
- Solo incluir las claves de componentes que el módulo realmente tiene

---

## Paso 5b — Generar YAML de imagen (solo `cloud_run_api`)

Si el spec tiene `type: cloud_run_api`, crear `image/dataops-artifacts/itc-{nombre-api}.yaml`
con los 5 campos obligatorios:

```yaml
dockerfile: service/cloud_run/{nombre-api}/Dockerfile
name:        itc-{nombre-api}
repo:        dataops-artifacts
region:      us-central1
project:     ${project_operation}
description: “Imagen Docker del servicio {nombre-api}”
```

> Derivar `{nombre-api}` del `contexto.nombre` del spec en kebab-case.
> `repo`, `project` y `description` son **obligatorios** — sin ellos `image.sh` falla.
> `project` apunta al mismo proyecto que el Cloud Run (`${project_operation}` en `env_dev.json`).
> El valor de `name:` debe coincidir con el campo `image:` del `deploy_config.yaml` del Cloud Run.
> Ver: `@.claude/data/standard/factory/spec-types/spec-cloud-run-api.md` — sección “Contenido del YAML de imagen”

---

## Paso 6 — Estructura de código: solo carpetas, sin skeletons

Crear las carpetas que el módulo va a necesitar y dejarlas versionadas con un `.gitkeep`.
**No generar archivos DDL, SP ni workflow con contenido placeholder.**

```
data/bigquery/{dataset_out}/{tabla_out}/ddl/.gitkeep
data/bigquery/{dataset_out}/{tabla_out}/sp/.gitkeep
data/bigquery/{dataset_out}/{tabla_out}/test/.gitkeep
data/postgresql/ddl/.gitkeep                                  (cloud_run_api con Cloud SQL)
pipeline/workflow/{dataset_out}/{tabla_out}/.gitkeep          (si orquestacion=true)
pipeline/scheduler/{dataset_out}/{tabla_out}/.gitkeep         (si orquestacion=true)
```

### Quién crea cada artefacto

| Artefacto | Etapa dueña |
|---|---|
| DDL con columnas, tipos y constraints | `fac-data-stage-physical-design` |
| SP con lógica de negocio | `fac-data-stage-coding` |
| Código de servicio (FastAPI, KFP, Cloud Function) | `fac-data-stage-coding` |
| Tests de SP | `fac-data-stage-coding` |
| Workflow y scheduler | `fac-data-stage-orchestration` |
| Diagramas de arquitectura | `fac-data-diagrams`, desde `fac-data-stage-documentation` |

> **Por qué se eliminaron los skeletons:** un archivo con `-- implementar en etapa CODING` se
> reescribe entero dos etapas después. Se paga tres veces el mismo archivo (scaffold, diseño,
> implementación), ensucia el diff y deja el repo con SQL que no compila. Las carpetas sí se
> crean acá: fijan la convención de rutas que el spec y el deploy JSON ya referencian.

---

## Paso 7 — Generar `docs/brief.md`

Resumen ejecutivo del desarrollo, derivado del spec:

```markdown
# Brief Técnico — {contexto.nombre}

**SPEC:** {id}  |  **Tipo:** {tipo_flujo}  |  **Fecha:** {fecha}  |  **Autor:** {autor}

## Qué se construye
{contexto.descripcion}

## Por qué
{contexto.objetivo_negocio}

## Etapas aplicables
{lista de etapas marcadas true}

## Componentes GCP
{lista de componentes del spec}

## Fuentes → Output
{lista de fuentes} → {lista de outputs}

## KPIs de éxito
{contexto.kpis}

## Restricciones
{restricciones del spec}
```

---

## Paso 8 — Generar `docs/TODO.md`

Checklist de tareas derivado de las etapas activas del spec:

```markdown
# TODO — {contexto.nombre}

**SPEC:** {id}  |  **Status:** {status}

### DISCOVERY (sub-etapa de DESIGN)
- [ ] Resolver tablas canónicas de fuentes con ${variables}
- [ ] Generar/cargar glosarios para fuentes sin glosario

### DESIGN
- [ ] Definir arquitectura de tablas (naming, capas, particiones)
  → Ver: docs/feature_spec/{feature}/spec.md — sección Campos
- [ ] Confirmar fuentes y volumen con el equipo
- [ ] Aprobar naming con estándares

### CODING
- [ ] DDL: {tabla_out}.sql en data/bigquery/{dataset_out}/{tabla_out}/ddl/
- [ ] SP: sp_{tabla_out}_{emp}.sql en data/bigquery/{dataset_out}/{tabla_out}/sp/ (uno por fuente)
- [ ] Test: test_sp_{tabla_out}_{emp}.sql en data/bigquery/{dataset_out}/{tabla_out}/test/

### DATA QUALITY          ← solo si etapas.data_quality=true
- [ ] SP DQ: sp_dq_{tabla_out}.sql
- [ ] Configurar registros en dq_config (dml_dq_config_{tabla_out}.sql)
- [ ] Configurar monitores (dml_dq_monitor_config_{tabla_out}.sql)

### COMPLIANCE
- [ ] /rules-check sin violaciones
- [ ] Verificar campos de auditoría (load_date, record_source, creation_user)

### ORCHESTRATION          ← solo si etapas.orquestacion=true
- [ ] Workflow: wf-{tabla_out_kebab}-{emp}.yaml (uno por fuente)
- [ ] Cloud Scheduler: cs-{tabla_out_kebab}-{emp}.yaml (uno por fuente)

### TESTING
- [ ] Ejecutar DDL en dev
- [ ] Validar conteos vs fuente
- [ ] Validar reglas DQ

### DATAOPS
- [ ] Completar env_dev.json con valores reales
- [ ] Completar env_prd.json
- [ ] Completar deploy_dev.json y deploy_prd.json

### SECURITY              ← solo si etapas.seguridad=true
- [ ] Solicitar permisos SA

### DOCUMENTATION
- [ ] Actualizar glosario de la tabla destino
- [ ] Actualizar README del repo
```

---

## Paso 9 — Generar `project.manifest.yaml` (condicional)

Crear `project.manifest.yaml` en la raíz del repo **solo si**:
- Se pasó el flag `--with-manifest`, **o**
- Ya existe `project.manifest.yaml` (agregar el módulo scaffoldeado), **o**
- El spec declara más de un tipo de componente heterogéneo (ej: bq_pipeline + cloud_run)

Si corresponde crear, generar el scaffold con los valores del spec:

```yaml
project:
  name: ~
  repo: ~
  description: "{contexto.descripcion}"
  team: data-analytics
  env: [dev, prd]

stack:
  - bigquery          # si hay ddl/sp
  - cloud_workflows   # si hay workflow
  - cloud_scheduler   # si hay cloud_scheduler
  - dataops_itc

modules:
  - id: {slug derivado del contexto.nombre}
    type: {spec.type}
    description: "{contexto.nombre}"
    spec: {ruta del spec.yaml}
    feature_spec: docs/feature_spec/{feature_slug}/
    status: review
    etapa_actual: DESIGN

architecture:
  layers: [master, business]
  audit_fields: [load_date, record_source, creation_user]
  pii_handling: hash_only
  temp_tables: "${dataset_stage}"
  variable_pattern: dataops_variables

infrastructure:
  gcp_project_pattern: "${env}-itc-customer-services"
  region: us-central1
  datasets:
    analytics: analytics
    sp: stored_procedures
    stage: stage_tmp

consumers: []
constraints: []
never_do: []
```

Si ya existe `project.manifest.yaml` → solo agregar el módulo a la lista `modules`.

---

## Paso 10 — Reporte final

```
## Scaffold completado — init-project

SPEC: {id}  |  type: {type}

### Carpetas creadas: N
### Archivos creados: N

| Tipo | Archivo |
|---|---|
| Estructura | {carpetas según type} + docs/specs/ + docs/feature_spec/ |
| Deploy | deploy/env_dev.json, env_prd.json, deploy_dev.json, deploy_prd.json |
| Carpetas de código | data/bigquery/{dataset_out}/{tabla_out}/{ddl,sp,test}/ · data/postgresql/ddl/ · pipeline/{workflow,scheduler}/ — con `.gitkeep`, sin archivos placeholder |
| Manifest | project.manifest.yaml                    (si corresponde) |
| Docs | docs/brief.md, docs/TODO.md |

### Feature specs disponibles
{lista de docs/feature_spec/*/spec.md existentes}

### Variables pendientes de completar en env_dev.json
{lista de variables con valor "pendiente_definir"}

### Próximos pasos
1. Completar variables en deploy/env_dev.json y env_prd.json
2. /data:implement-stage DISCOVERY → resolver fuentes y enriquecer glosarios
3. /data:implement-stage DESIGN → definir arquitectura (Campos en feature_spec/)
4. /data:implement-stage CODING → implementar lógica
```


