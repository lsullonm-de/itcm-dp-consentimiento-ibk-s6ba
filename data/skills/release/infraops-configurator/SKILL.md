# Skill: Infraops Configurator

> **Rol:** Configurador de Infraestructura GCP — ITC Data Platform
> **Activado por:** etapa INFRAOPS del flujo de fábrica — generación o revisión de `infra_dev.json`, `infra_prd.json` y los YAMLs de `infra/service_accounts/` e `infra/iam/`
>
> **Estándares de referencia:**
> - `@.claude/data/standard/services/service-accounts.md` — convenciones de naming y tipos de SA
> - `@.claude/data/standard/architecture/gcp-organization.md` — proyectos GCP y roles IAM ITC
>
> **Framework de referencia:** `D:\workspace\itc\itcm-dp-infraops-build`

---

## 1. Rol y Responsabilidades

El **Infraops Configurator** genera y revisa las configuraciones declarativas para el framework de despliegue ITC InfraOps. Cuando el usuario pida ayuda para configurar la infraestructura de identidad y acceso de un módulo:

1. Lee `docs/specs/*.yaml` (bloque `seguridad.permisos`) como fuente de verdad.
2. Determina qué Service Accounts deben crearse (derivando sufijo `-app` / `-job` por componente).
3. Genera los YAMLs de `service_account` e `iam_binding` en `infra/`.
4. Genera o actualiza `deploy/infra_dev.json` y `deploy/infra_prd.json`.
5. Actualiza `deploy/env_dev.json` y `deploy/env_prd.json` con las variables de proyecto/dataset referenciadas.
6. Advierte sobre permisos cross-project (cuando el recurso está en un proyecto distinto al de la SA).

> **Cuándo usar:** etapa INFRAOPS — primer paso del bloque RELEASE, antes de SECURITY.
> Prerequisito para que el framework Dataops pueda desplegar con la SA correcta.
>
> **Relación con Dataops:** InfraOps gestiona identidad y acceso (SA + IAM). Dataops gestiona aplicaciones (BigQuery, Cloud Run, Vertex AI). Siempre ejecutar InfraOps **antes** de Dataops.

---

## 2. Arquitectura General del Framework

El framework `itcm-dp-infraops-build` es el análogo de `itcm-dp-dataops-build` para infraestructura de identidad. Funciona con Cloud Build y produce SAs y bindings IAM idempotentes.

### Estructura en el repositorio usuario

```
[repositorio]/
├── deploy/
│   ├── infra_dev.json        ← manifest de componentes infraops a desplegar en dev
│   ├── infra_prd.json        ← manifest de componentes infraops a desplegar en prd
│   ├── env_dev.json          ← variables ${} con valores dev (compartido con Dataops)
│   └── env_prd.json          ← variables ${} con valores prd (compartido con Dataops)
│
└── infra/
    ├── service_accounts/     ← un YAML por Service Account
    │   └── [empresa]-[caso-uso]-[tipo].yaml
    ├── iam/
    │   └── [empresa]-[caso-uso]-[tipo]-bindings.yaml
    ├── bigquery/             ← datasets a crear (solo GitHub triggers)
    │   └── datasets.yaml
    └── cloud_storage/        ← buckets GCS a crear
        └── [nombre-bucket].yaml
```

> **Nota:** `deploy/env_dev.json` y `deploy/env_prd.json` son compartidos con el framework Dataops. Al generar InfraOps, consolidar **todas** las variables (infraops + dataops) en esos archivos.

### Analogía DataOps ↔ InfraOps

| DataOps | InfraOps | Descripción |
|---|---|---|
| `deploy/deploy_dev.json` | `deploy/infra_dev.json` | Manifest de componentes a desplegar |
| `deploy/deploy_prd.json` | `deploy/infra_prd.json` | Manifest de producción |
| `deploy/env_dev.json` | `deploy/env_dev.json` | Variables compartidas (mismo archivo) |
| `data/bigquery/{dataset_out}/{tabla_out}/ddl/*.sql` | `infra/service_accounts/*.yaml` | Declaraciones de recursos |
| `service/cloud_run/{dataset_out}/{tabla_out}/*/deploy_config.yaml` | `infra/iam/*.yaml` | Configuración de componente |

---

## 3. Sistema de Variables y Sustituciones

Todos los YAMLs de `infra/` soportan placeholders `${variable}` resueltos en 3 niveles:

### Nivel 1 — Variables de ambiente (más alta prioridad)
**Origen:** `build/config/{empresa}/replacement/env_{env}.json` del framework infraops

```json
{
  "replacement": [
    {"${env}":        "dev"},
    {"${project_id}": "dev-itc-customer-services"}
  ]
}
```

Estas variables son estáticas por empresa y ambiente — siempre disponibles sin configuración adicional.

### Nivel 2 — Variables del trigger (`_INFRAOPS_VARIABLES`)
Variables dinámicas pasadas en el trigger Cloud Build. Formato `clave=valor`, una por línea:

```
pipeline_bucket=dev-itc-ingreso-vii-pipeline
custom_dataset=mi_dataset
```

### Nivel 3 — Variables del repositorio (fallback)
**Origen:** `deploy/env_{env}.json` en el repositorio usuario. Actúa como fallback si la variable no fue resuelta en niveles anteriores.

```json
{
  "project_tee_trn_retail_spsa":  "dev-spsa-data-storage",
  "dataset_tee_trn_retail_spsa":  "retail_spsa_dev",
  "project_analytics":            "dev-itc-customer-services",
  "dataset_analytics":            "modelo_ingresos_analytics",
  "pipeline_bucket":              "dev-itc-ingreso-vii-pipeline"
}
```

**Regla:** En la práctica casi todas las variables van en Nivel 3 (`env_dev.json`) porque son específicas de cada repo. Los Niveles 1 y 2 proveen solo `${env}` y `${project_id}`.

---

## 4. Estructura de `deploy/infra_[env].json`

```json
{
  "service_account": [
    "/infra/service_accounts/[empresa]-[caso-uso]-[tipo].yaml"
  ],
  "iam_binding": [
    "/infra/iam/[empresa]-[caso-uso]-[tipo]-bindings.yaml"
  ],
  "bigquery_datasets": [
    "/infra/bigquery/datasets.yaml"
  ],
  "cloud_storage": [
    "/infra/cloud_storage/[nombre-bucket].yaml"
  ]
}
```

**Reglas:**
- Las rutas son **relativas a la raíz del repositorio** y comienzan con `/`.
- Si una sección no tiene componentes: omitir la clave (no incluir lista vacía).
- `infra_dev.json` e `infra_prd.json` pueden apuntar a los **mismos YAMLs** — las variables `${env}` se resuelven por ambiente.
- **Siempre generar ambos** archivos al crear o actualizar componentes infraops.
- La clave `"bigquery_datasets"` (plural) corresponde al componente `bigquery_dataset`; solo soportado en GitHub triggers.
- Un YAML por bucket en `cloud_storage`.

### Claves soportadas en `infra_[env].json`

| Clave JSON | Componente | Notas |
|---|---|---|
| `service_account` | Crea SA idempotente | CSR y GitHub |
| `iam_binding` | Asigna roles IAM | CSR y GitHub |
| `bigquery_datasets` | Crea datasets BigQuery | **Solo GitHub triggers** |
| `cloud_storage` | Crea buckets Cloud Storage | CSR y GitHub |

---

## 5. Componente: `service_account`

Crea el SA si no existe. Si ya existe, actualiza `display_name`. Operación idempotente.

### Campos del YAML

| Campo | Requerido | Default | Descripción |
|-------|-----------|---------|-------------|
| `service_account.name` | **Sí** | — | Email completo del SA o variable `${service_account_job}` / `${service_account_app}` definida en `env_dev.json`. El framework extrae el nombre del SA del email. |
| `service_account.project` | No | `$PROJECT_ID` del trigger | Proyecto GCP donde se crea el SA |
| `service_account.display_name` | No | igual a `name` | Nombre descriptivo visible en GCP Console |
| `service_account.description` | No | — | Descripción del propósito del SA |

### Convenciones de naming (desde `@.claude/data/standard/services/service-accounts.md`)

| Componente que usa el SA | Sufijo | Ejemplo nombre |
|---|---|---|
| `cloud_run`, `cloud_function` | `-app` | `${env}-itc-ingreso-app` |
| `workflow`, `vertex_pipeline`, `cloud_scheduler` | `-job` | `${env}-itc-ingreso-job` |
| Cloud Build / deployer | `-deployer` | Gestión centralizada — no crear aquí |

**Email resultante:** `{name}@{project_id}.iam.gserviceaccount.com`

### Ubicación convención

```
infra/service_accounts/[empresa]-[caso-uso]-[tipo].yaml
```

Usar el mismo nombre en todos los ambientes — las variables `${env}` se encargan de la diferencia:

```yaml
# infra/service_accounts/itc-ingreso-job.yaml
service_account:
  name:         ${service_account_job}
  project:      ${project_analytics}
  display_name: "SA Pipeline Ingresos VII — ${env}"
  description:  "Service account para workflow, vertex pipeline y cloud scheduler del modelo ingreso VII"
```

> **Regla:** El campo `name` usa la variable de despliegue `${service_account_job}` o `${service_account_app}` — **nunca** el nombre hardcodeado. Estas variables se definen en `deploy/env_dev.json` con el email completo del SA. El framework extrae internamente el nombre antes del `@`.

### Template

```yaml
# Para SAs tipo -job (workflow / vertex_pipeline / cloud_scheduler)
service_account:
  name:         ${service_account_job}
  project:      ${project_analytics}
  display_name: "[Descripción legible] — ${env}"
  description:  "Service account para [componentes] del caso de uso [nombre]"

# Para SAs tipo -app (cloud_run / cloud_function)
service_account:
  name:         ${service_account_app}
  project:      ${project_analytics}
  display_name: "[Descripción legible] — ${env}"
  description:  "Service account para [componentes] del caso de uso [nombre]"
```

### Entrada en `infra_[env].json`

```json
"service_account": [
  "/infra/service_accounts/itc-[caso-uso]-job.yaml",
  "/infra/service_accounts/itc-[caso-uso]-app.yaml"
]
```

---

## 6. Componente: `iam_binding`

Asigna roles IAM al SA sobre recursos específicos. Es **idempotente**: si el binding ya existe no lo duplica.

### Campos del YAML

| Campo | Requerido | Descripción |
|-------|-----------|-------------|
| `iam_binding.member` | **Sí** | Email completo en formato `serviceAccount:{email}` |
| `iam_binding.bindings[]` | **Sí** | Lista de asignaciones de rol (puede ser vacía) |
| `bindings[].resource_type` | **Sí** | `project` \| `storage_bucket` \| `bigquery_dataset` |
| `bindings[].role` | **Sí** | Rol GCP completo: `roles/bigquery.dataViewer`, `roles/storage.objectAdmin`, etc. |
| `bindings[].project` | Condicional | Requerido para `project` y `bigquery_dataset` |
| `bindings[].dataset` | Para `bigquery_dataset` | Nombre del dataset BigQuery (sin backticks) |
| `bindings[].bucket` | Para `storage_bucket` | Nombre del bucket GCS (sin `gs://`) |

### Tipos de recurso soportados

| `resource_type` | Comando ejecutado | Nivel |
|---|---|---|
| `bigquery_dataset` | Python `google-cloud-bigquery` client | Dataset específico |
| `storage_bucket` | `gcloud storage buckets add-iam-policy-binding` | Bucket específico |
| `project` | `gcloud projects add-iam-policy-binding` | Todo el proyecto |

### Roles comunes por tipo de recurso

| Recurso | Rol | SA que lo necesita | Acceso |
|---|---|---|---|
| `bigquery_dataset` | `roles/bigquery.dataViewer` | `-job`, `-app` | Solo lectura |
| `bigquery_dataset` | `roles/bigquery.dataEditor` | `-job`, `-app` | Lectura + escritura |
| `bigquery_dataset` | `roles/bigquery.dataOwner` | — | Control total del dataset |
| `project` | `roles/bigquery.jobUser` | `-job`, `-app` | Ejecutar queries y SPs BQ |
| `project` | `roles/logging.logWriter` | `-job` | Escribir logs de ejecución en Cloud Logging |
| `project` | `roles/cloudsql.client` | `-app` | Conectarse a instancias Cloud SQL (PostgreSQL) |
| `project` | `roles/aiplatform.user` | `-job` | Ejecutar pipelines Vertex AI |
| `storage_bucket` | `roles/storage.objectViewer` | `-job`, `-app` | Solo lectura de objetos |
| `storage_bucket` | `roles/storage.objectAdmin` | `-job` | Lectura + escritura de objetos |
| `storage_bucket` | `roles/storage.objectCreator` | `-app` | Solo escritura de objetos |

> ⚠️ `roles/bigquery.jobUser` **siempre a nivel `project`** — mínimo requerido para ejecutar jobs BQ. No se asigna a nivel dataset.

> ⚠️ `roles/logging.logWriter` **siempre a nivel `project`** — **lineamiento obligatorio** para toda SA `-job` que ejecute **Cloud Workflows**. Sin este rol las ejecuciones del workflow no escriben logs en Cloud Logging y no hay trazabilidad de errores.

> ⚠️ `roles/cloudsql.client` **siempre a nivel `project`** — **lineamiento obligatorio** para toda SA `-app` (Cloud Run / Cloud Function) que se conecte a **Cloud SQL (PostgreSQL)**. Aplica independientemente del método de conexión (Cloud SQL Auth Proxy, conector de librería). Sin este rol la conexión es rechazada en runtime.

> ⚠️ `roles/aiplatform.user` **siempre a nivel `project`** — necesario para ejecutar Vertex AI pipelines.

### Ubicación convención

```
infra/iam/[empresa]-[caso-uso]-[tipo]-bindings.yaml
```

Un archivo de bindings por SA. Si el SA necesita permisos en muchos datasets, todos van en el mismo archivo:

```yaml
# infra/iam/itc-ingreso-job-bindings.yaml
iam_binding:
  member: serviceAccount:${service_account_job}

  bindings:
    # ── Fuentes — solo lectura ──────────────────────────────
    - resource_type: bigquery_dataset
      project:       ${project_tee_trn_retail_spsa}
      dataset:       ${dataset_tee_trn_retail_spsa}
      role:          roles/bigquery.dataViewer

    - resource_type: bigquery_dataset
      project:       ${project_iden_itc_party}
      dataset:       ${dataset_iden_itc_party}
      role:          roles/bigquery.dataViewer

    # ── Output — lectura/escritura ──────────────────────────
    - resource_type: bigquery_dataset
      project:       ${project_analytics}
      dataset:       ${dataset_analytics}
      role:          roles/bigquery.dataEditor

    # ── BQ Job (nivel proyecto — requerido para queries/SPs) ─
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/bigquery.jobUser

    # ── Cloud Logging (requerido para Cloud Workflows) ──────
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/logging.logWriter

    # ── Artefactos GCS ──────────────────────────────────────
    - resource_type: storage_bucket
      bucket:        ${pipeline_bucket}
      role:          roles/storage.objectAdmin
```

### Patrones adicionales por tipo de componente

#### SA tipo `-job` con Cloud Workflow

```yaml
# roles/logging.logWriter a nivel proyecto — necesario para escribir logs de ejecución del Workflow
- resource_type: project
  project:       ${project_analytics}
  role:          roles/logging.logWriter
```

#### SA tipo `-job` con Vertex AI pipeline

```yaml
# roles/aiplatform.user a nivel proyecto — necesario para enviar y monitorear runs
- resource_type: project
  project:       ${project_analytics}
  role:          roles/aiplatform.user
```

#### SA tipo `-app` (Cloud Run / Cloud Function)

```yaml
# Solo accede al dataset de output (no ejecuta SPs directamente)
- resource_type: bigquery_dataset
  project:       ${project_analytics}
  dataset:       ${dataset_analytics}
  role:          roles/bigquery.dataViewer

# Si ejecuta queries o llama SPs, también necesita jobUser
- resource_type: project
  project:       ${project_analytics}
  role:          roles/bigquery.jobUser
```

#### SA tipo `-app` con Cloud Run + PostgreSQL (Cloud SQL)

```yaml
# roles/cloudsql.client a nivel proyecto — requerido para conectarse a Cloud SQL PostgreSQL
# Aplica con Cloud SQL Auth Proxy o con el conector nativo de la librería
- resource_type: project
  project:       ${project_analytics}
  role:          roles/cloudsql.client
```

> La variable de conexión en el Cloud Run (`CLOUD_SQL_CONNECTION_NAME`) sigue siendo necesaria en `deploy_config.yaml`. Este rol solo habilita el acceso IAM; la cadena de conexión la provee la configuración de Dataops.

#### Pub/Sub (notificación de alertas)

```yaml
# El SA -job publica en el topic de mail
- resource_type: project
  project:       ${mail_pubsub_project}
  role:          roles/pubsub.publisher
```

> Nota: `roles/pubsub.publisher` se asigna a nivel proyecto porque el topic de mail (`itcm-mail` / `itcm-inca-mail`) vive en un proyecto centralizado de plataforma. No hay `resource_type: pubsub_topic` soportado aún en el framework.

### Template genérico de bindings

```yaml
iam_binding:
  member: serviceAccount:${service_account_job}   # o ${service_account_app} según el SA

  bindings:
    # ── Fuentes BigQuery (solo lectura) ─────────────────────
    - resource_type: bigquery_dataset
      project:       ${project_[tabla-fuente]}
      dataset:       ${dataset_[tabla-fuente]}
      role:          roles/bigquery.dataViewer

    # ── Output BigQuery (escritura) ─────────────────────────
    - resource_type: bigquery_dataset
      project:       ${project_analytics}
      dataset:       ${dataset_analytics}
      role:          roles/bigquery.dataEditor

    # ── BQ Job User (queries y SPs) ─────────────────────────
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/bigquery.jobUser

    # ── Cloud Logging (requerido si hay workflow) ────────────
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/logging.logWriter

    # ── GCS (si tiene bucket de artefactos) ─────────────────
    - resource_type: storage_bucket
      bucket:        ${pipeline_bucket}
      role:          roles/storage.objectAdmin

    # ── Vertex AI (solo si type: vertex_ml) ─────────────────
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/aiplatform.user
```

---

## 7. Componente: `bigquery_dataset`

> ⚠️ **Solo soportado en GitHub triggers.** No disponible en Cloud Source Repositories (CSR).

Crea datasets BigQuery de forma idempotente. Si el dataset ya existe no falla.

### Campos del YAML

| Campo | Requerido | Descripción |
|-------|-----------|-------------|
| `project` | **Sí** | Proyecto GCP donde se crea el dataset |
| `region` | **Sí** | Región del dataset. Usar `us-central1` para ITC |
| `datasets[]` | **Sí** | Lista de datasets a crear |
| `datasets[].id` | **Sí** | ID del dataset (nombre en BigQuery) |
| `datasets[].description` | No | Descripción del dataset |
| `datasets[].labels` | No | Etiquetas GCP (`clave: valor`) |

### Ubicación convención

```
infra/bigquery/datasets.yaml
```

Un solo archivo puede declarar múltiples datasets del mismo proyecto.

### Template

```yaml
# infra/bigquery/datasets.yaml
project: ${project_analytics}
region:  us-central1
datasets:
  - id:          ${dataset_analytics}
    description: "Dataset de analytics — [nombre del proceso]"
    labels:
      environment: ${env}
      owner:       data-platform

  - id:          ${dataset_stage}
    description: "Dataset de staging temporal"
    labels:
      environment: ${env}
      owner:       data-platform
```

### Entrada en `infra_[env].json`

```json
"bigquery_datasets": [
  "/infra/bigquery/datasets.yaml"
]
```

> **Cuándo usar:** cuando el proceso necesita crear datasets propios (ej. un proceso que usa un dataset nuevo no gestionado por otro repo). Si el dataset ya existe en el proyecto de plataforma, no incluir este componente.

---

## 8. Componente: `cloud_storage`

Crea buckets Cloud Storage de forma idempotente. Si el bucket ya existe, no falla y continúa.

### Campos del YAML

| Campo | Requerido | Default | Descripción |
|-------|-----------|---------|-------------|
| `bucket.name` | **Sí** | — | Nombre del bucket. Convención: `${env}-[empresa]-[caso-uso]-[propósito]` |
| `bucket.project` | No | `$PROJECT_ID` del trigger | Proyecto GCP donde se crea el bucket |
| `bucket.region` | No | `us-central1` | Región del bucket |
| `bucket.storage_class` | No | `STANDARD` | Clase de almacenamiento: `STANDARD` \| `NEARLINE` \| `COLDLINE` \| `ARCHIVE` |
| `bucket.description` | No | — | Descripción del propósito del bucket |
| `bucket.files[]` | No | — | Lista de archivos a subir al bucket tras creación |
| `bucket.files[].source` | Condicional | — | Ruta relativa al archivo fuente (desde la carpeta del YAML) |
| `bucket.files[].destination` | Condicional | — | Ruta destino dentro del bucket |

### Clases de almacenamiento

| `storage_class` | Uso recomendado |
|---|---|
| `STANDARD` | Acceso frecuente — pipelines, artefactos ML, datos activos |
| `NEARLINE` | Acceso ~1 vez/mes — backups, archivos de referencia |
| `COLDLINE` | Acceso ~1 vez/trimestre — archivos de auditoría |
| `ARCHIVE` | Acceso <1 vez/año — archivos históricos de cumplimiento |

> Para pipelines Vertex AI y artefactos de modelos ML: usar `STANDARD`.

### Ubicación convención

```
infra/cloud_storage/[nombre-descriptivo].yaml
```

Un archivo por bucket. El nombre del archivo refleja el propósito del bucket.

### Template

```yaml
# infra/cloud_storage/[caso-uso]-pipeline.yaml
bucket:
  name:          ${bucket_pipeline}
  project:       ${project_analytics}
  region:        us-central1
  storage_class: STANDARD
  description:   "Bucket de artefactos del pipeline [nombre del proceso] (${env})"
```

### Template con carga inicial de archivos

```yaml
# infra/cloud_storage/[caso-uso]-pipeline.yaml
bucket:
  name:          ${bucket_pipeline}
  project:       ${project_analytics}
  region:        us-central1
  storage_class: STANDARD
  description:   "Bucket de artefactos del pipeline [nombre] (${env})"
  files:
    - source:      config/params.json
      destination: config/params.json
    - source:      config/schema.json
      destination: config/schema.json
```

> **Ruta `source`:** relativa al directorio que contiene el YAML (`infra/cloud_storage/`).
> Si los archivos están en `infra/cloud_storage/config/`, usar `config/params.json`.

### Entrada en `infra_[env].json`

```json
"cloud_storage": [
  "/infra/cloud_storage/[caso-uso]-pipeline.yaml"
]
```

Si el proceso necesita más de un bucket, agregar una entrada por YAML:

```json
"cloud_storage": [
  "/infra/cloud_storage/[caso-uso]-pipeline.yaml",
  "/infra/cloud_storage/[caso-uso]-datos.yaml"
]
```

### Variable en `env_dev.json`

El nombre del bucket debe declararse como variable para que los demás componentes
(Dataops, IAM bindings) puedan referenciarlo:

```json
"bucket_pipeline": "dev-itc-[caso-uso]-pipeline"
```

> Patrón de naming: `${env}-[empresa]-[caso-uso]-[propósito]`
> Ejemplo: `dev-itc-ingreso-vii-pipeline`, `dev-itc-retail-datos`

---

## 9. Paso a Paso: Generar Configuración InfraOps desde el Spec

### Paso 0 — Leer fuentes de verdad

Leer en paralelo:
1. `docs/specs/*.yaml` → bloque `seguridad.permisos`
2. `docs/specs/*.yaml` → bloques `componentes` (para determinar tipos de SA por componente)
3. `deploy/env_dev.json` → variables existentes (para no duplicar ni sobreescribir)
4. `@.claude/data/standard/services/service-accounts.md` → convenciones naming
5. `@.claude/data/standard/architecture/gcp-organization.md` → proyectos GCP del ecosistema

### Paso 1 — Identificar SAs requeridas

Del spec, mapear cada SA a su tipo y componente:

| SA del spec (`${env}-itc-dq-core-job`) | Tipo | Componentes que la usan |
|---|---|---|
| `${env}-[empresa]-[caso]-job` | `-job` | workflow, vertex_pipeline, cloud_scheduler |
| `${env}-[empresa]-[caso]-app` | `-app` | cloud_run, cloud_function |

### Paso 2 — Generar YAMLs de `service_account`

Un archivo por SA en `infra/service_accounts/`:

```yaml
# infra/service_accounts/[empresa]-[caso]-job.yaml
service_account:
  name:         ${service_account_job}
  project:      ${project_analytics}
  display_name: "[Descripción] — ${env}"
  description:  "Service account para [componentes] del proceso [nombre]"
```

Usar `${service_account_app}` en el YAML correspondiente al SA de tipo `-app`.

### Paso 3 — Generar YAMLs de `iam_binding`

Un archivo por SA en `infra/iam/`, derivando permisos del spec:

- **`seguridad.permisos[].rol`** → campo `role` en el binding
- **`seguridad.permisos[].recurso`** → campo `project`/`dataset`/`bucket` según tipo
- **Tipo de recurso** → derivar de la descripción del recurso (`dataset` = `bigquery_dataset`, `bucket` = `storage_bucket`, `proyecto` = `project`)

Agregar siempre `roles/bigquery.jobUser` a nivel proyecto si el SA ejecuta queries o SPs.

### Paso 3.5 — Generar YAML de `bigquery_dataset` (si aplica)

Si el proceso crea datasets nuevos y el trigger es GitHub:

```yaml
# infra/bigquery/datasets.yaml
project: ${project_analytics}
region:  us-central1
datasets:
  - id:          ${dataset_analytics}
    description: "[Descripción del dataset]"
    labels:
      environment: ${env}
      owner:       data-platform
```

### Paso 3.6 — Generar YAMLs de `cloud_storage` (si aplica)

Si el proceso necesita buckets GCS (pipelines Vertex AI, almacenamiento de datos):

```yaml
# infra/cloud_storage/[caso-uso]-pipeline.yaml
bucket:
  name:          ${bucket_pipeline}
  project:       ${project_analytics}
  region:        us-central1
  storage_class: STANDARD
  description:   "[Descripción del bucket]"
```

Agregar la variable `bucket_pipeline` (y similares) a `deploy/env_dev.json` y `env_prd.json`.

### Paso 4 — Generar `deploy/infra_dev.json` y `deploy/infra_prd.json`

```json
{
  "service_account": [
    "/infra/service_accounts/[empresa]-[caso]-job.yaml"
  ],
  "iam_binding": [
    "/infra/iam/[empresa]-[caso]-job-bindings.yaml"
  ],
  "bigquery_datasets": [
    "/infra/bigquery/datasets.yaml"
  ]
}
```

Ambos archivos apuntan a los mismos YAMLs — las variables `${env}` se resuelven por ambiente. Omitir `bigquery_datasets` si no se crean datasets nuevos, o si el trigger es CSR. Omitir `cloud_storage` si el proceso no necesita buckets propios.

### Paso 5 — Actualizar `deploy/env_dev.json` y `deploy/env_prd.json`

Agregar las variables referenciadas en los YAMLs de `infra/` que no estén ya en los env JSON.

**Incluir siempre los emails completos de las SAs creadas** bajo las claves `service_account_job` y/o `service_account_app`. Estas variables son consumidas por el framework Dataops en `deploy_config.yaml` de Cloud Functions, Cloud Run, Workflows y Vertex Pipelines — sin ellas el framework no puede resolver `${service_account_app}` al desplegar.

```json
{
  "project_analytics": "dev-itc-customer-services",

  "service_account_job": "dev-itc-[caso-uso]-job@dev-itc-customer-services.iam.gserviceaccount.com",
  "service_account_app": "dev-itc-[caso-uso]-app@dev-itc-customer-services.iam.gserviceaccount.com",

  "project_[tabla-fuente-1]": "...",
  "dataset_[tabla-fuente-1]": "...",

  "pipeline_bucket":     "dev-[caso]-pipeline",

  "mail_pubsub_project": "central-data-governance-260223",
  "mail_pubsub_topic":   "itcm-mail"
}
```

> La variable `env` es global del framework — **no incluirla** en `env_[env].json`.
> La variable `project_id` la provee el framework (Nivel 1) — **no incluirla** tampoco.
> Solo incluir `service_account_app` si el proceso tiene componentes `-app` (CF/CR); solo `service_account_job` si tiene `-job` (workflow/vertex/scheduler).

---

## 10. Cloud Build Trigger — Configuración

### Datos del framework

| Parámetro | Valor |
|---|---|
| Proyecto GCP | `itc-data-devops-01` |
| Región | `us-central1` |
| Evento | Invocación manual |
| Repositorio del framework | `itcm-dp-infraops-build` |

### Archivo YAML según ambiente y origen de repo

| Ambiente | Repo origen | Archivo de configuración |
|---|---|---|
| dev | Cloud Source Repositories | `/build/cloudbuild_sourcerepository_dev.yaml` |
| prd | Cloud Source Repositories | `/build/cloudbuild_sourcerepository_prd.yaml` |
| dev | GitHub | `/build/cloudbuild_github_dev.yaml` |
| prd | GitHub | `/build/cloudbuild_github_prd.yaml` |

### Variables del Trigger

| Variable | Descripción | Ejemplo |
|---|---|---|
| `_ABREV_EMPRESA` | Empresa — selecciona `build/config/{empresa}/replacement/` | `itc`, `fape`, `indg`, `ngr` |
| `_PROJECT_ID` | Proyecto GCP destino | `dev-itc-customer-services` |
| `_REPO_NAME` | Nombre del repo (CSR) | `itcm-inca-ingreso-vii` |
| `_REPO_PROJECT_ID` | Proyecto GCP del repo CSR | `itc-data-devops-01` |
| `_SERVICE_ACCOUNT_ID` | SA que ejecuta el pipeline | SA con roles elevados de IAM |
| `_INFRAOPS_VARIABLES` | Variables runtime (Nivel 2, opcional) | `pipeline_bucket=dev-itc-ingreso-vii-pipeline` |
| `_URL_REPO` | URL completa del repo GitHub (solo GitHub) | — |
| `_BRANCH_REPO` | Rama a clonar (solo GitHub) | `dev` |

### SA de Cloud Build InfraOps — permisos requeridos

El SA que ejecuta el trigger InfraOps requiere permisos **elevados y separados** del SA de Dataops:

| Rol requerido | Motivo |
|---|---|
| `roles/iam.serviceAccountAdmin` | Crear y actualizar service accounts |
| `roles/resourcemanager.projectIamAdmin` | Asignar roles a nivel de proyecto |
| `roles/storage.admin` | Asignar IAM en buckets GCS |
| `roles/bigquery.admin` | Asignar IAM en datasets BigQuery |
| `roles/logging.logWriter` | Escribir logs de Cloud Build |
| `roles/cloudbuild.builds.builder` | Ejecutar builds |

> **Importante:** Este SA nunca debe usarse para el framework Dataops. La separación garantiza que un pipeline de aplicación no pueda modificar IAM.

---

## 11. Ejemplo Completo — DQ Core Framework

Basado en `SPEC-ITC-20260409-001.yaml` (Framework DQ):

### Estructura generada

```
itcm-dp-dataquality-core/
├── deploy/
│   ├── infra_dev.json
│   ├── infra_prd.json
│   ├── env_dev.json              ← agregar variables nuevas
│   └── env_prd.json              ← agregar variables nuevas
└── infra/
    ├── service_accounts/
    │   ├── itc-dq-core-job.yaml
    │   └── itc-dq-core-app.yaml
    └── iam/
        ├── itc-dq-core-job-bindings.yaml
        └── itc-dq-core-app-bindings.yaml
```

### `deploy/infra_dev.json`

```json
{
  "service_account": [
    "/infra/service_accounts/itc-dq-core-job.yaml",
    "/infra/service_accounts/itc-dq-core-app.yaml"
  ],
  "iam_binding": [
    "/infra/iam/itc-dq-core-job-bindings.yaml",
    "/infra/iam/itc-dq-core-app-bindings.yaml"
  ]
}
```

### `infra/service_accounts/itc-dq-core-job.yaml`

```yaml
service_account:
  name:         ${service_account_job}
  project:      ${project_analytics}
  display_name: "SA DQ Core — Job (${env})"
  description:  "Service account para Cloud Scheduler del framework de calidad del dato ITC DQ Core"
```

### `infra/service_accounts/itc-dq-core-app.yaml`

```yaml
service_account:
  name:         ${service_account_app}
  project:      ${project_analytics}
  display_name: "SA DQ Core — App (${env})"
  description:  "Service account para Cloud Functions (itc-dq-run-stats, itc-dq-run-psi, itc-dq-run-rules) del framework DQ Core"
```

### `infra/iam/itc-dq-core-job-bindings.yaml`

```yaml
iam_binding:
  member: serviceAccount:${service_account_job}

  bindings:
    # Acceso al proyecto para ejecutar Cloud Build/Scheduler
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/bigquery.jobUser
```

### `infra/iam/itc-dq-core-app-bindings.yaml`

```yaml
iam_binding:
  member: serviceAccount:${service_account_app}

  bindings:
    # Escritura en dataset DQ (dq_stats, dq_control, dq_psi_result — los SPs insertan bajo esta SA)
    - resource_type: bigquery_dataset
      project:       ${project_analytics}
      dataset:       ${dataset_dq}
      role:          roles/bigquery.dataEditor

    # BQ Job User — necesario para que los SPs invocados por las CFs puedan ejecutar
    - resource_type: project
      project:       ${project_analytics}
      role:          roles/bigquery.jobUser
```

---

## 12. Guía de Preguntas Diagnósticas

Cuando el usuario pida generar la configuración InfraOps, recopilar:

1. **¿Qué componentes tiene el proceso?** (cloud_run, cloud_function, workflow, vertex_pipeline, cloud_scheduler) → determina cuántas SAs y de qué tipo.
2. **¿Cuál es el proyecto GCP de analytics (output)?** → `project_analytics` → `${project_id}` del trigger + en `env_dev.json`.
3. **¿Qué datasets BigQuery de fuente necesita leer?** → bindings `dataViewer` por cada dataset.
4. **¿El SA ejecuta queries o SPs directamente?** → si sí, agregar `roles/bigquery.jobUser` a nivel proyecto.
5. **¿El proceso necesita buckets GCS propios?** → componente `cloud_storage` en `infra/cloud_storage/`. Definir `bucket_[propósito]` en `env_dev.json`. Agregar binding `roles/storage.objectAdmin` al SA que lo usa.
6. **¿Ejecuta Vertex AI pipelines?** → binding `roles/aiplatform.user` a nivel proyecto. Casi siempre acompañado de un bucket de pipeline.
7. **¿Envía notificaciones Pub/Sub?** → binding `roles/pubsub.publisher` en proyecto de mail.
8. **¿El Cloud Build SA necesita actuar como el SA del módulo?** → binding `roles/iam.serviceAccountUser` (SA sobre SA).
9. **¿El proceso tiene Cloud Workflow?** → agregar `roles/logging.logWriter` a nivel proyecto en el SA `-job`. **Lineamiento obligatorio.**
10. **¿El Cloud Run se conecta a PostgreSQL (Cloud SQL)?** → agregar `roles/cloudsql.client` a nivel proyecto en el SA `-app`. **Lineamiento obligatorio.**

---

## 13. Validación post-deploy

Después de ejecutar el trigger InfraOps:

```bash
# Verificar que el SA fue creado
gcloud iam service-accounts describe \
  "${ENV}-itc-[caso]-job@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}"

# Verificar permisos sobre dataset BQ
bq get-iam-policy "${PROJECT_ID}:${DATASET_ID}" \
  --format=prettyjson | grep "[sa-name]" -A 2

# Verificar permisos a nivel proyecto
gcloud projects get-iam-policy "${PROJECT_ID}" \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:${ENV}-itc-[caso]-job@*" \
  --format="table(bindings.role)"

# Verificar permisos sobre bucket GCS
gcloud storage buckets get-iam-policy "gs://${BUCKET_NAME}" \
  --filter="bindings.members:serviceAccount:${ENV}-itc-[caso]-*"
```

---

## 14. Checklist de Validación

Antes de ejecutar el trigger InfraOps:

### Estructura general

- [ ] Carpeta `infra/service_accounts/` existe con al menos un YAML
- [ ] Carpeta `infra/iam/` existe con al menos un YAML de bindings
- [ ] `deploy/infra_dev.json` generado con las claves correctas (ver Sección 4)
- [ ] `deploy/infra_prd.json` generado (misma estructura que dev)
- [ ] Rutas en `infra_[env].json` comienzan con `/` y son relativas a la raíz del repo
- [ ] `deploy/env_dev.json` y `deploy/env_prd.json` actualizados con todas las variables nuevas
- [ ] `service_account_app` declarada en `env_dev.json`/`env_prd.json` si el proceso tiene CF o CR (Dataops la consume en `deploy_config.yaml`)
- [ ] `service_account_job` declarada en `env_dev.json`/`env_prd.json` si el proceso tiene workflow, vertex pipeline o scheduler
- [ ] Si se crean datasets: `infra/bigquery/datasets.yaml` existe y el trigger es GitHub (no CSR)
- [ ] Si hay buckets: un YAML por bucket en `infra/cloud_storage/` + variable `bucket_[propósito]` en `env_dev.json`

### Por YAML de `service_account`

- [ ] Campo `name` usa `${service_account_job}` o `${service_account_app}` — **nunca** el nombre hardcodeado
- [ ] Campo `project` usa variable `${project_analytics}` — no hardcodeado
- [ ] `display_name` incluye `${env}` para distinguir dev/prd en GCP Console
- [ ] Una SA por tipo de componente (no mezclar `-app` y `-job` en la misma SA)
- [ ] El valor de `service_account_job` / `service_account_app` en `env_dev.json` es el email completo del SA

### Por YAML de `iam_binding`

- [ ] `member` usa `serviceAccount:${service_account_job}` o `serviceAccount:${service_account_app}` — **no** el email hardcodeado
- [ ] Datasets de fuente: `roles/bigquery.dataViewer` (no más)
- [ ] Dataset de output: `roles/bigquery.dataEditor`
- [ ] `roles/bigquery.jobUser` asignado a nivel `project` si el SA ejecuta queries o SPs
- [ ] `roles/logging.logWriter` asignado a nivel `project` en SA `-job` si el proceso tiene **Cloud Workflow** _(lineamiento obligatorio)_
- [ ] `roles/cloudsql.client` asignado a nivel `project` en SA `-app` si el **Cloud Run se conecta a PostgreSQL** _(lineamiento obligatorio)_
- [ ] `roles/aiplatform.user` a nivel `project` si hay `vertex_pipeline`
- [ ] `roles/storage.objectAdmin` sobre bucket GCS si hay artefactos — referenciar con `${bucket_[propósito]}`
- [ ] Permisos cross-project: proyecto del recurso es diferente al proyecto de la SA — revisar que las variables `${project_[tabla]}` estén en `env_dev.json`
- [ ] Principio least-privilege: no asignar `dataOwner` si `dataEditor` es suficiente

### Por YAML de `cloud_storage`

- [ ] `bucket.name` usa variable `${bucket_[propósito]}` — nunca el nombre hardcodeado
- [ ] `bucket.project` usa variable `${project_analytics}` — no hardcodeado
- [ ] `bucket.storage_class` es `STANDARD` para pipelines/artefactos activos
- [ ] La variable `bucket_[propósito]` está declarada en `env_dev.json` y `env_prd.json`
- [ ] El binding `roles/storage.objectAdmin` en el YAML de IAM apunta al mismo bucket con `${bucket_[propósito]}`
- [ ] Si hay `files[]`: las rutas `source` existen en `infra/cloud_storage/` relativas al YAML

---

## Qué NO hace este skill

| Responsabilidad | Dónde va |
|---|---|
| Generar `deploy_config.yaml` y `deploy_[env].json` de Dataops | `/data:implement-stage DATAOPS` |
| Configurar ciclo de vida o retención de buckets GCS | Hacerlo manualmente en GCP Console post-deploy |
| Crear topics Pub/Sub | Componente `pubsub` en el framework Dataops |
| Crear datasets BigQuery desde CSR triggers | Limitación del framework — usar GitHub trigger o crear manualmente |
| Auditar least-privilege post-asignación | `/data:implement-stage SECURITY` |
| Crear proyectos GCP o configurar VPCs | Gestión centralizada de plataforma |
| Ejecutar comandos IAM manualmente sin Cloud Build | Usar `gcloud`/`bq` directamente siguiendo `@.claude/data/standard/services/service-accounts.md` |

---

## Referencias

- Framework InfraOps: `D:\workspace\itc\itcm-dp-infraops-build`
- Framework DataOps: `D:\workspace\itc\itcm-dp-dataops-build`
- Estándar SAs: `@.claude/data/standard/services/service-accounts.md`
- Proyectos GCP ITC: `@.claude/data/standard/architecture/gcp-organization.md`
- Skill análogo DataOps: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`