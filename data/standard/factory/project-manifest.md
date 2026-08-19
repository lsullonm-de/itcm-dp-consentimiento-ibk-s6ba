# Estándar: Manifest de Proyecto — `project.manifest.yaml`

> Nivel de abstracción superior al `spec.yaml`. Describe el **repositorio en su conjunto**:
> qué módulos contiene, qué stack usa, quiénes consumen los datos, y actúa como
> **router de skills** por tipo de módulo.
>
> **Cuándo usarlo:** siempre — incluso repos con un único módulo.
> Generarlo desde el primer `/spec-create` garantiza que `implement-stage` y todos los commands
> multi-módulo encuentren el punto de entrada correcto sin necesidad de crearlo retroactivamente.

---

## Relación entre artefactos

```
project.manifest.yaml              ← nivel repo (este documento)
  ├── modules[0].spec → docs/spec.yaml                       (módulo bq_pipeline)
  ├── modules[1].spec → service/cloud_run/spec/spec.yaml     (módulo cloud_run_api)
  └── modules[2].spec → service/vertex/spec/spec.yaml        (módulo vertex_ml)

spec.yaml                          ← nivel módulo (@.claude/data/standard/factory/spec-manifest.md)
  └── type: bq_pipeline | cloud_run_api | vertex_ml | cloud_function
```

---

## Líneas de trabajo

Cada módulo del repo pertenece a una **línea de trabajo** determinada por su `type`.
Un mismo repo puede tener módulos de distintas líneas — cada una activa su propio skill.

| `type` | Línea de trabajo | Skill activado | Componentes típicos |
|---|---|---|---|
| `bq_pipeline` | Data Engineering | `@.claude/data/skills/build/coding/customer-attributes-developer/SKILL.md` | ddl + sp + workflow + scheduler |
| `vertex_ml` | ML Engineering | `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md` | ddl + sp + image + vertex_pipeline + scheduler |
| `cloud_run_api` | API / Servicios | `@apps/skills/api-dev-agent.md` | ddl + cloud_run |
| `cloud_function` | Event Processing | skill CF (futuro) | ddl + cloud_function + pubsub |

> **DDL y SP son transversales** — aplican en cualquier línea de trabajo que produce o consume
> tablas BigQuery. No son exclusivos de `bq_pipeline`.

---

## Routing de Skills por tipo de módulo

Cuando Claude ejecuta un comando (`/data:implement-stage`, `/check-rules`, etc.) en un repo con
`project.manifest.yaml`, sigue este flujo:

```
1. Leer project.manifest.yaml
2. Para cada módulo activo (status != deprecated):
   a. Leer modules[n].type  →  determina la línea de trabajo
   b. Cargar skill correspondiente (tabla de líneas de trabajo)
   c. Leer modules[n].spec  →  spec del módulo
   d. Ejecutar comando con ese contexto
3. Componentes ddl/sp: aplicar customer-attributes-developer como skill
   de referencia para SQL, independientemente de la línea del módulo
```

---

## Ubicación del archivo

```
[raiz-del-repo]/
├── project.manifest.yaml    ← este archivo (1 por repo)
├── docs/
│   ├── specs/               ← todos los specs del repo (1 por módulo)
│   │   ├── spec-itc-20260501-001.yaml   ← bq_pipeline: attr_education
│   │   ├── spec-itc-20260501-002.yaml   ← cloud_run_api: scoring_api
│   │   └── spec-itc-20260501-003.yaml   ← vertex_ml: churn_model
│   ├── brief.md
│   └── TODO.md
├── data/bigquery/
├── service/
└── pipeline/
```

> Todos los specs van en `docs/specs/` independientemente del `type`.
> El `project.manifest.yaml` referencia cada spec por su ruta en `modules[n].spec`.

---

## Schema del `project.manifest.yaml`

### Bloque `project`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `name` | string | ✅ | Nombre del proyecto (sin prefijo org). Ej: `itcm-attr-education` |
| `repo` | string | ✅ | Nombre del repositorio en GCP Source Repositories |
| `description` | string | ✅ | Qué resuelve este repo en una oración |
| `team` | string | ✅ | Equipo responsable. Ej: `data-analytics` |
| `env` | list[string] | ✅ | Ambientes disponibles. Ej: `[dev, prd]` |

---

### Bloque `stack`

Lista de tecnologías GCP usadas en el repo. Solo incluir las que realmente aplican.

| Valor | Descripción |
|---|---|
| `bigquery` | Tablas, SPs, DDLs en BigQuery |
| `cloud_workflows` | Orquestación con Cloud Workflows |
| `cloud_scheduler` | Ejecución programada |
| `cloud_run` | APIs o servicios web |
| `cloud_function` | Funciones event-driven |
| `vertex_ai` | Pipelines ML / KFP |
| `cloud_sql` | PostgreSQL para APIs |
| `pubsub` | Mensajería / triggers |
| `dataops_itc` | Framework de despliegue ITC (siempre presente) |

---

### Bloque `modules` (lista)

Corazón del manifest. Cada módulo es una unidad de desarrollo independiente con su propio `spec.yaml`.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | Slug del módulo. Ej: `attr_education`, `scoring_api`, `churn_model` |
| `type` | enum | ✅ | Línea de trabajo: `bq_pipeline` \| `vertex_ml` \| `cloud_run_api` \| `cloud_function` |
| `linea_trabajo` | string | — | Nombre descriptivo de la línea. Ej: `Data Engineering`, `ML Engineering` |
| `description` | string | ✅ | Qué hace este módulo en una oración |
| `spec` | string | ✅ | Ruta relativa al `spec.yaml` del módulo |
| `status` | enum | ✅ | `draft` \| `in_progress` \| `done` \| `deprecated` |
| `etapa_actual` | string | — | Etapa de fábrica en curso. Ej: `CODING`, `DATAOPS` |
| `outputs` | list | — | Resumen de entregables (tabla, endpoint, modelo) — para documentación |
| `dependencias` | list[string] | — | IDs de módulos que deben completarse antes |

**Valores válidos `type`:** `bq_pipeline` \| `vertex_ml` \| `cloud_run_api` \| `cloud_function`

---

### Bloque `architecture`

Restricciones y convenciones transversales a todos los módulos del repo.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `layers` | list[string] | — | Capas BQ activas: `[raw, master, business]` |
| `audit_fields` | list[string] | — | Campos de auditoría en toda tabla output BQ |
| `pii_handling` | string | — | Estrategia PII: `aead_encrypt` \| `hash_only` \| `none` |
| `temp_tables` | string | — | Dataset para tablas temporales. Default: `${dataset_stage}` |
| `variable_pattern` | string | — | Convención de variables. Default: `dataops_variables` |

---

### Bloque `infrastructure`

Recursos GCP centrales del repo.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `gcp_project_pattern` | string | ✅ | Patrón del proyecto GCP. Ej: `${env}-itc-customer-services` |
| `region` | string | — | Región principal. Default: `us-central1` |
| `datasets` | map | — | Datasets BQ usados: `analytics`, `sp`, `stage`, `dq` |
| `service_accounts` | map | — | SAs disponibles: `job`, `app` con su patrón |

---

### Bloque `consumers`

Quiénes consumen los outputs de este repo.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `name` | string | ✅ | Nombre del sistema consumidor |
| `system` | string | ✅ | Tipo de sistema: `crm`, `modelo_ml`, `campaña`, `reporte`, `api` |
| `modulo` | string | — | ID del módulo que produce el output que consume |
| `descripcion` | string | — | Qué consume y para qué |

---

### Bloque `constraints`

Lista de strings. Restricciones técnicas transversales a todo el repo que Claude debe respetar.
Complementa las reglas de `/check-rules` con restricciones específicas del proyecto.

---

### Bloque `never_do`

Lista de strings. Acciones explícitamente prohibidas en este repo.

---

## Ejemplo completo

```yaml
# ============================================================
# MANIFEST DE PROYECTO — Data Platform ITC
# ============================================================

project:
  name: itcm-attr-scoring
  repo: itcm-dp-attr-scoring
  description: >
    Pipeline de atributos de scoring crediticio y API de consulta para
    el modelo de churn de Farmacias Peruanas.
  team: data-analytics
  env: [dev, prd]

# ------------------------------------------------------------
# STACK GCP
# ------------------------------------------------------------
stack:
  - bigquery
  - cloud_workflows
  - cloud_scheduler
  - cloud_run
  - vertex_ai
  - cloud_sql
  - dataops_itc

# ------------------------------------------------------------
# MÓDULOS (unidades de desarrollo independientes)
# ------------------------------------------------------------
modules:
  # ── Línea: Data Engineering ──────────────────────────────────
  - id: attr_education
    type: bq_pipeline
    linea_trabajo: Data Engineering
    description: Atributo de nivel educativo desde RCC hacia capa Business
    spec: docs/specs/spec-itc-20260401-001.yaml
    status: done
    etapa_actual: ~
    outputs:
      - table: ba_itc_attr_education
        layer: business
    dependencias: []

  - id: attr_payment
    type: bq_pipeline
    linea_trabajo: Data Engineering
    description: Atributo de comportamiento de pago POS del cliente ITC
    spec: docs/specs/spec-itc-20260415-001.yaml
    status: in_progress
    etapa_actual: CODING
    outputs:
      - table: ba_itc_attr_payment
        layer: business
    dependencias: [attr_education]

  # ── Línea: ML Engineering ─────────────────────────────────────
  # DDL y SP son transversales: churn_model también declara ddl + sp
  # en su spec (tablas de features, output del modelo) además de vertex_pipeline
  - id: churn_model
    type: vertex_ml
    linea_trabajo: ML Engineering
    description: Pipeline de productivización del modelo de churn Farmacias
    spec: docs/specs/spec-itc-20260601-001.yaml
    status: draft
    etapa_actual: DESIGN
    outputs:
      - model: churn_farmacias_v1
        pipeline: train + inference
      - table: ba_itc_churn_output
        layer: business
    dependencias: [attr_education, attr_payment]

  # ── Línea: API / Servicios ────────────────────────────────────
  - id: scoring_api
    type: cloud_run_api
    linea_trabajo: API / Servicios
    description: API REST de consulta de score crediticio por cliente
    spec: docs/specs/spec-itc-20260501-001.yaml
    status: in_progress
    etapa_actual: DESIGN
    outputs:
      - endpoint: GET /v1/scoring/{iden_party_hash}
    dependencias: [attr_education, attr_payment, churn_model]

# ------------------------------------------------------------
# ARQUITECTURA
# ------------------------------------------------------------
architecture:
  layers: [master, business]
  audit_fields: [load_date, record_source, creation_user]
  pii_handling: hash_only
  temp_tables: "${dataset_stage}"
  variable_pattern: dataops_variables

# ------------------------------------------------------------
# INFRAESTRUCTURA GCP
# ------------------------------------------------------------
infrastructure:
  gcp_project_pattern: "${env}-itc-customer-services"
  region: us-central1
  datasets:
    analytics: analytics
    sp: stored_procedures
    stage: stage_tmp
    dq: data_quality
  service_accounts:
    job: "${env}-itc-scoring-job@${env}-itc-customer-services.iam.gserviceaccount.com"
    app: "${env}-itc-scoring-app@${env}-itc-customer-services.iam.gserviceaccount.com"

# ------------------------------------------------------------
# CONSUMIDORES
# ------------------------------------------------------------
consumers:
  - name: CRM Intercorp
    system: crm
    modulo: scoring_api
    descripcion: Consulta el score en tiempo real para decisiones de crédito
  - name: Modelo de Churn
    system: modelo_ml
    modulo: attr_education
    descripcion: Consume ba_itc_attr_education como feature del pipeline de churn

# ------------------------------------------------------------
# RESTRICCIONES GLOBALES
# ------------------------------------------------------------
constraints:
  - Sin valores hardcodeados de proyecto/dataset en SQL o YAML
  - Variables de tabla input siempre en trío (project + dataset + table)
  - Tablas temporales solo en ${dataset_stage}
  - SA tipo -job para workflow/scheduler, -app para Cloud Run/CF
  - No exponer PII en outputs — usar hash SHA256 para iden_party

never_do:
  - Hardcodear proyectos GCP en SQL o YAML
  - Usar CREATE TEMP TABLE (no persiste entre sesiones BigQuery)
  - Incluir variable 'env' en env_dev.json / env_prd.json
  - Modificar diccionarios de mapeo sin aprobación del Business Steward
  - Commitear archivos env_prd.json con valores de producción en texto plano
```

---

## Cómo lo usa Claude

### Al inicio de sesión en un repo

```
1. Glob project.manifest.yaml en la raíz del repo
2. Si existe: leer y mapear módulos activos + routing de skills
3. Si no existe: operar con docs/spec.yaml directamente (repo de módulo único)
```

### Al ejecutar /data:implement-stage

```
/data:implement-stage CODING attr_payment
                 ↑ etapa      ↑ id del módulo (opcional si hay uno solo activo)

→ Lee modules[attr_payment].type = bq_pipeline
→ Carga skill: @.claude/data/skills/build/coding/customer-attributes-developer/SKILL.md
→ Lee modules[attr_payment].spec
→ Ejecuta etapa CODING con ese contexto
```

### Al ejecutar /check-rules

```
→ Lee todos los módulos activos
→ Para cada módulo: aplica las reglas correspondientes a su type
→ Reporte unificado por módulo
```

---

## Scaffolding

El comando `/init-repo` genera un `project.manifest.yaml` pre-completado con los módulos
declarados en la descripción inicial. Ver `@commands/data/init-repo.md`.


