# Skill: Dataops Configurator

> **Rol:** Configurador de Despliegue DataOps — ITC Data Platform
> **Activado por:** creación o revisión de archivos de configuración YAML para el framework de despliegue ITC DataOps
>
> **Estándares de referencia:**
> - `@.claude/data/standard/bigquery/nomenclatura-retail.md` — nomenclatura BigQuery y SQL
> - `@.claude/data/standard/bigquery/development.md` — queries y stored procedures
> - `@.claude/data/standard/services/service-accounts.md` — cuentas de servicio GCP (tipos, nomenclatura, roles IAM)
> - `@.claude/data/standard/services/cloud-run.md` — desarrollo de servicios Cloud Run (estructura, FastAPI, deploy flags)
>
> **Referencia documental:** `data/skills/build/dataops/dataops-configurator/references/Manual de Uso Framework de despliegue ITC Dataops.pdf`

---

## 1. Rol y Responsabilidades

El **Dataops Configurator** genera y revisa configuraciones YAML para el framework de despliegue ITC DataOps. Cuando el usuario pida ayuda para configurar un componente de despliegue:

1. Identifica el tipo de componente (bigquery_ddl, bigquery_sp, bigquery_dml, image, cloud_run,
   cloud_function, workflow, vertex_pipeline, pubsub, cloud_scheduler).
2. Genera el YAML de configuración con los flags correctos según este documento.
3. Indica qué entrada agregar en `deploy/deploy_[env].json`.
4. Advierte sobre dependencias entre componentes (cadena `dataops_variable`).
5. Aplica siempre los estándares de nomenclatura de los documentos referenciados.

---

## Prerrequisitos del Framework

Antes de usar Dataops, el proyecto GCP debe tener estos recursos configurados.

### APIs a habilitar

```
cloudbuild.googleapis.com
workflows.googleapis.com
cloudscheduler.googleapis.com
cloudfunctions.googleapis.com
run.googleapis.com
aiplatform.googleapis.com
```

### Rol customizado de habilitación Dataops (`xops_enabler_role`)

La cuenta de servicio de Cloud Build necesita, como mínimo:

| Rol GCP |
|---|
| Artifact Registry Administrator |
| Cloud Build Service Account |
| Cloud Run Admin |
| Cloud Scheduler Admin |
| Logs Writer |
| Monitoring Editor |
| Service Account User |
| Storage Admin |
| Viewer |
| Workflows Admin |

> El equipo de infraestructura provee el YAML `xops_enabler_role` con todos los permisos.
> Solicitar al Data Operator si no está configurado.

---

## Arquitectura General del Framework

> Ver estructura completa de carpetas en `@.claude/data/standard/factory/repositories.md`.

```
[repositorio]/
├── docs/                        ← Documentación del flujo de fábrica
│   ├── specs/                   ← Specs del proceso (SPEC-[EMPRESA]-[YYYYMMDD]-[NNN].yaml)
│   ├── architecture/            ← Diagramas generados por fac-data-diagrams (etapa DOCUMENTATION)
│   │   ├── context-diagram.md
│   │   ├── data-flow-diagram.md
│   │   ├── component-diagram.md
│   │   ├── sequence-diagram.md
│   │   └── ...
│   └── TODO.md                  ← Estado de avance por etapa del flujo de fábrica
│
├── deploy/
│   ├── deploy_dev.json          ← manifest de componentes a desplegar en dev
│   ├── deploy_prd.json          ← manifest de componentes a desplegar en prd
│   ├── env_dev.json             ← variables de despliegue ${} con valores dev
│   └── env_prd.json             ← variables de despliegue ${} con valores prd
│
├── data/
│   ├── bigquery/                ← Scripts SQL organizados por tabla destino
│   │   └── {tabla_target}/       ← una carpeta por tabla final
│   │       ├── ddl/             ← DDL tabla target + fuentes/raw
│   │       ├── sp/              ← SPs que cargan esa tabla
│   │       └── dml/             ← CALLs de prueba (solo dev)
│   ├── postgresql/              ← Scripts SQL para Cloud SQL (solo cloud_run_api)
│   │   └── ddl/
├── image/                       ← YAMLs de imagen Docker (Artifact Registry)
│   └── [nombre-repo-artifact]/
│       └── [nombre-imagen].yaml
│
├── service/
│   ├── cloud_run/               ← deploy_config.yaml + código fuente
│   │   └── [categoria]/
│   │       └── [nombre-servicio]/
│   ├── cloud_function/          ← deploy_config.yaml + main.py + requirements.txt
│   │   └── [categoria]/
│   │       └── [nombre-function]/
│   ├── vertex/                  ← Pipelines Vertex AI / KFP
│   │   └── [nombre-pipeline]/
│   │       ├── deploy_config_train.yaml
│   │       ├── deploy_config_inference.yaml
│   │       ├── src/             ← components.py, pipeline_train.py, pipeline_inference.py
│   │       ├── notebook/        ← compile_train.ipynb, compile_inference.ipynb
│   │       └── requirements.txt
│   └── pubsub/                  ← YAMLs de tópicos Pub/Sub
│       └── [topico].yaml
│
└── pipeline/
    ├── workflow/                ← YAMLs de Cloud Workflows
    │   └── [categoria]/
    │       └── [nombre-workflow].yaml
    └── scheduler/               ← YAMLs de Cloud Scheduler (triggers de workflows)
        └── [job].yaml
```

### Archivos en `deploy/`

La carpeta `deploy/` contiene **cuatro archivos** por proyecto:

```
deploy/
├── deploy_dev.json   ← manifest de componentes a desplegar en dev
├── deploy_prd.json   ← manifest de componentes a despliegue en prd
├── env_dev.json      ← todas las variables de despliegue ${} con valores dev
└── env_prd.json      ← todas las variables de despliegue ${} con valores prd
```

> **Regla (2026-03-26 amoreno):** Al generar o actualizar cualquier componente, siempre generar o actualizar **ambos** archivos `env_dev.json` y `env_prd.json` dentro de `deploy/`, consolidando **todas** las variables de despliegue definidas en los distintos componentes del proyecto — no solo las del componente que se está editando.

> **Regla (2026-08-17):** Al ejecutar la etapa DATAOPS (`fac-data-stage-dataops`), los archivos `deploy_dev.json` y `deploy_prd.json` se **limpian y reescriben** desde cero con solo los componentes del módulo actual — no se acumulan con ejecuciones anteriores. El backup previo (`deploy/backup/deploy_[env]_YYYYMMDDHHMMSS.json`) se genera obligatoriamente **antes** de cualquier modificación.

#### Formato de env_[env].json

Mismo contenido que `_DATAOPS_VARIABLES` del trigger Cloud Build, pero en formato JSON dentro del repo.

> La variable `env` es global del framework — **no incluirla** en `env_[env].json`.

#### Convención de naming: minúsculas vs MAYÚSCULAS

| Caso | Formato | Ejemplos |
|---|---|---|
| Variables de tabla BQ (project/dataset/table) | `snake_case` minúsculas | `project_operation`, `dataset_sp`, `table_m_product` |
| Variables de infraestructura y SAs | `snake_case` minúsculas | `service_account_job`, `mail_pubsub_project` |
| **URLs y endpoints de servicios externos** | **`UPPER_SNAKE_CASE`** | **`METADATA_API_URL`**, `PIPELINE_BUCKET` |
| Variables de Vertex Pipeline (`env_vars`) | `UPPER_SNAKE_CASE` | `PROJECT_ID`, `DATASET_SP`, `TABLE_INPUT` |

> **Lineamiento:** las variables que representan **URLs de APIs o servicios externos** que el workflow
> consume en tiempo de ejecución se declaran en `UPPER_SNAKE_CASE` en `env_[env].json`.
> Esto las distingue visualmente de las variables de tabla y facilita auditar qué endpoints
> están configurados por ambiente. El framework las inyecta igual que el resto — el formato
> es solo una convención de legibilidad.

**Orden de variables (regla 2026-03-11 lmorales):** agrupar por tabla — primero `project_`, luego `dataset_`, luego `table_` para cada tabla referenciada. Variables generales van al inicio.

```json
{
  "project_operation": "dev-itc-customer-services",
  "project_analytics": "dev-itc-customer-services",
  "project_billing":   "pendiente_definir",

  "dataset_sp": "stored_procedures",

  "service_account_job": "dev-itc-[caso-uso]-job@dev-itc-customer-services.iam.gserviceaccount.com",
  "service_account_app": "dev-itc-[caso-uso]-app@dev-itc-customer-services.iam.gserviceaccount.com",

  "project_ba_itc_attr_demographic":  "intercorp-data-storage-pv",
  "dataset_ba_itc_attr_demographic":  "ba_itc_attribute_party",
  "table_ba_itc_attr_demographic":    "ba_itc_attr_demographic",

  "project_ba_itc_attr_payment_pos":  "intercorp-data-storage-pv",
  "dataset_ba_itc_attr_payment_pos":  "ba_itc_attribute_party",
  "table_ba_itc_attr_payment_pos":    "ba_itc_attr_payment_pos",

  "project_tmp_score_calc":  "dev-itc-customer-services",
  "dataset_tmp_score_calc":  "stage_tmp",
  "table_tmp_score_calc":    "tmp_score_calc",

  "project_ba_itc_customer_score":  "dev-itc-customer-services",
  "dataset_ba_itc_customer_score":  "analytics",
  "table_ba_itc_customer_score":    "ba_itc_customer_score",

  "mail_pubsub_project": "central-data-governance-260223",
  "mail_pubsub_topic":   "itcm-mail"
}
```

> **Valores fijos de mail Pub/Sub por ambiente** (no cambian entre repos):
> | Ambiente | `mail_pubsub_project` | `mail_pubsub_topic` |
> |---|---|---|
> | dev | `central-data-governance-260223` | `itcm-mail` |
> | prd | `stalwart-motif-270218` | `itcm-inca-mail` |

> **Regla SA:** `service_account_job` y `service_account_app` son las SAs creadas por el framework InfraOps en la etapa INFRAOPS. Sus emails completos **deben declararse** en `env_dev.json` y `env_prd.json` para que el framework Dataops los resuelva al desplegar Cloud Functions, Cloud Run, Workflows y Vertex Pipelines. Omitir estas variables causa error al resolver `${service_account_app}` en `deploy_config.yaml`.

En `env_prd.json` se replican las mismas claves con los valores de producción.

---

### Estructura del deploy_[env].json

> **Etapa del flujo de fábrica:** Este archivo se genera/completa en la etapa **DATAOPS**, no antes.
> En etapas anteriores (DESIGN, PLAN) solo existe el `spec.yaml`. El `deploy_[env].json` es el
> output concreto de la configuración Dataops que se escribe al ejecutar `/data:implement-stage DATAOPS`.

```json
{
  "bigquery_ddl":      ["/data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql"],
  "bigquery_sp":       ["/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql"],
  "bigquery_dml":      ["/data/bigquery/{dataset_out}/{tabla_out}/dml/call_sp_{tabla_out}_{emp}.sql"],
  "cloudsql_ddl":      ["/data/postgresql/ddl/tabla.sql"],
  "image":             ["/image/{dataset_out}/{tabla_out}/{tabla_out_kebab}-{emp}.yaml"],
  "cloud_run":         ["/service/cloud_run/{dataset_out}/{tabla_out}/nombre/deploy_config.yaml"],
  "cloud_function":    ["/service/cloud_function/{dataset_out}/{tabla_out}/nombre/deploy_config.yaml"],
  "workflow":          ["/pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml"],
  "vertex_pipeline":   ["/service/vertex/{dataset_out}/{tabla_out}/nombre/deploy_config.yaml"],
  "pubsub":            ["/service/pubsub/{dataset_out}/{tabla_out}/topico.yaml"],
  "matillion":         [],
  "matillion_json":    [],
  "cloud_scheduler":   ["/pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml"]
}
```

**Orden de ejecución en Cloud Build:** bigquery_ddl → bigquery_sp → bigquery_dml → cloudsql_ddl → image → cloud_run → vertex_pipeline →
cloud_function → pubsub → workflow → cloud_scheduler

#### ⚠️ REGLA CRÍTICA — deploy_[env].json solo acepta paths simples

Cada valor en el array es **un string con la ruta relativa al YAML de configuración**. El framework bash
lee el path con `jq -r '.KEY[]?'` y luego el script correspondiente lee el YAML internamente.

**NUNCA poner objetos JSON con la configuración embebida dentro de deploy_[env].json:**

```json
// ❌ INCORRECTO — el framework NO lee esto
{
  "cloud_run": [
    {
      "type": "cloud_run_service",
      "config_path": "/service/cloud_run/...",
      "service_name": "...",
      "region": "...",
      "memory": "...",
      "environment_vars": { ... }
    }
  ]
}

// ❌ INCORRECTO — claves inexistentes en el framework
{
  "image_build": [ ... ],
  "postgresql_ddl": [ ... ],
  "ddl_pg": [ ... ]
}

// ✅ CORRECTO — solo path al YAML de configuración
{
  "image":     ["/image/dataops-artifacts/itc-mi-api.yaml"],
  "cloud_run": ["/service/cloud_run/mi-api/deploy_config.yaml"]
}
```

#### Claves válidas (las que tienen script bash en el framework)

| Clave | Script que la lee | Qué procesa |
|---|---|---|
| `bigquery_ddl` | `bigquery_ddl.sh` | Paths a `.sql` con CREATE TABLE / VIEW en BigQuery |
| `bigquery_sp` | `bigquery_sp.sh` | Paths a `.sql` con CREATE OR REPLACE PROCEDURE en BigQuery |
| `bigquery_dml` | `bigquery_dml.sh` | Paths a `.sql` con INSERT / UPDATE / CALL en BigQuery |
| `cloudsql_ddl` | `cloudsql_pg.sh` | Paths a `.sql` con DDL PostgreSQL en Cloud SQL |
| `image` | `image.sh` | Paths a `.yaml` de imagen Docker (Artifact Registry) |
| `cloud_run` | `cloud_run.sh` | Paths a `deploy_config.yaml` de Cloud Run |
| `cloud_function` | `cloud_function.sh` | Paths a `deploy_config.yaml` de Cloud Function |
| `workflow` | `workflow.sh` | Paths a `.yaml` de Cloud Workflow |
| `vertex_pipeline` | `vertex_pipeline.sh` | Paths a `deploy_config.yaml` de Vertex Pipeline |
| `pubsub` | `pubsub.sh` | Paths a `.yaml` de tópico Pub/Sub |
| `cloud_scheduler` | `cloud_scheduler.sh` | Paths a `.yaml` de Cloud Scheduler |
| `matillion` | `matillion.sh` | Strings en formato `"version.job_name"` |

> Claves **NO reconocidas** por el framework (el script las ignora silenciosamente):
> `image_build`, `postgresql_ddl`, `ddl_pg`, `run_service`, `function`, y cualquier clave personalizada.

#### PostgreSQL / Cloud SQL DDL (`cloudsql_ddl`)

Los DDL para **Cloud SQL (PostgreSQL)** se despliegan usando la clave **`cloudsql_ddl`** en `deploy_[env].json`.
El script `cloudsql_pg.sh` levanta el Cloud SQL Auth Proxy, lee las credenciales de Secret Manager
(clave `SECRET_ID` en `env_[env].json`) y ejecuta los archivos `.sql` vía `psql`.

```json
{
  "cloudsql_ddl": [
    "/data/postgresql/ddl/dq_rule_config.sql",
    "/data/postgresql/ddl/dq_rule_control.sql"
  ]
}
```

**Requiere en `env_[env].json`:**
```json
{
  "SECRET_ID": "projects/{project_id}/secrets/{env}-itc-{caso}-db-credentials/versions/latest"
}
```

El secret debe contener un JSON con las claves: `db_user`, `db_pass`, `db_name`, `db_instance_name`, `db_project_id`, `db_region`.

> **Clave incorrecta:** `ddl_pg` es un tipo de componente del `spec.yaml` — **no es** una clave válida en `deploy_[env].json`. La clave correcta es siempre `cloudsql_ddl`.

**Analogía BigQuery vs Cloud SQL:**

| BigQuery | Cloud SQL (PostgreSQL) |
|---|---|
| `bigquery_ddl` | `cloudsql_ddl` |
| `data/bigquery/{dataset_out}/{tabla_out}/ddl/` | `data/postgresql/ddl/` |
| `bigquery_ddl.sh` | `cloudsql_pg.sh` |

---

## Sistema de Variables y Sustituciones

### Tipos de variables disponibles en YAMLs

| Sintaxis | Origen | Cuándo se resuelve |
|---|---|---|
| `${env}` | Archivo `env_[env].json` del framework (`build/config/[empresa]/replacement/`) | Antes de desplegar |
| `${VARIABLE}` | `env_[env].json` — claves de reemplazo estático | Antes de desplegar |
| `${VARIABLE}` | `/workspace/dataops_variable_value.txt` — outputs de steps previos | En tiempo de ejecución del step |

### Cadena dataops_variable

Los componentes pueden **exportar** su output (URL, valor) para que componentes posteriores lo consuman:

```yaml
# En cloud_run/deploy_config.yaml:
dataops_variable: crun_itc_campaign_loader_api_uri
# → Escribe: crun_itc_campaign_loader_api_uri=https://...run.app

# En workflow/mi-workflow.yaml, lo consume:
- url: "${crun_itc_campaign_loader_api_uri}/endpoint"
```

**Regla:** El step que exporta debe ejecutarse antes del que consume (ver orden Cloud Build).
Cloud Run → Cloud Function → Workflow es el flujo típico.

---

## Convenciones de Proyectos, Datasets y Tablas en `_DATAOPS_VARIABLES`

Cada referencia a BigQuery en YAMLs y SQLs debe expresarse **100% mediante variables de despliegue/reemplazo**.
No se hardcodean proyectos, datasets ni nombres de tabla.

> **Última actualización de esta convención:** 2026-03-04

### Proyectos GCP — 3 variables estándar + 1 por tabla input

Cada repo declara tres variables de proyecto fijas y una variable por cada tabla de entrada:

| Variable | Proyecto GCP patrón | Qué se crea aquí |
|---|---|---|
| `project_operation` | `[env]-[company]-data-operation` | Stored Procedures, Cloud Functions, Cloud Run, Workflows, Vertex Pipelines, Cloud Scheduler |
| `project_analytics` | `[env]-[company]-data-storage` | Todas las tablas BigQuery: DDLs definitivos, tablas temporales/stage y tablas de salida (capas master y business) |
| `project_billing` | `cloud-[company]-billing` o definido por proyecto | Proyecto GCP al que se imputa el costo del proceso (BQ jobs, Vertex, etc.) |
| `project_[nombre-tabla-input]` | varía por fuente | Proyecto de cada tabla de entrada — solo lectura, sin crear objetos |

> **Regla práctica:** En proyectos simples `project_operation` y `project_analytics` pueden apuntar
> al mismo proyecto GCP (ej. `dev-itc-customer-services`). Se declaran como variables separadas
> para facilitar la migración cuando se adopta la arquitectura multi-proyecto completa.

**Ejemplos de variables de proyecto input:**
```
project_ba_itc_attr_demographic=prd-itc-data-storage
project_ba_itc_attr_payment_pos=prd-itc-retail-storage
project_ba_itc_attr_insurance=prd-itc-insurance-storage
project_ba_itc_attr_rcc=prd-itc-rcc-storage
```

### Tres variables por tabla BigQuery — regla universal (2026-08-17)

> **TODA referencia a una tabla BigQuery — input, output, stage, tmp, aux, master, business — debe declarar siempre 3 variables de despliegue:**
>
> ```
> project_[nombre-tabla]   ← proyecto GCP donde vive la tabla
> dataset_[nombre-tabla]   ← dataset BigQuery donde vive la tabla
> table_[nombre-tabla]     ← nombre físico de la tabla
> ```
>
> La referencia completa usa siempre este patrón, sin excepción:
> ```
> ${project_[nombre-tabla]}.${dataset_[nombre-tabla]}.${table_[nombre-tabla]}
> ```
>
> Incluso cuando varias tablas internas comparten proyecto o dataset (todas las `tmp_*` y `aux_*`
> del proceso viven en `project_analytics` / `dataset_stage`), **cada tabla recibe sus propias 3 variables**.
> Esto elimina hardcodes residuales de nombres de tabla en SQLs y YAMLs de componentes.

**Tipos de tabla y su convención:**

| Tipo de tabla | Prefijo usual | `project_[tabla]` apunta a | `dataset_[tabla]` apunta a |
|---|---|---|---|
| Input / fuente externa | `ba_`, `m_`, `t_`, `dv_` | proyecto del data storage de origen | dataset del origen |
| Stage / temporal | `tmp_`, `stg_` | `project_analytics` | `[abrev]_stage` |
| Auxiliar | `aux_` | `project_analytics` | `[abrev]_stage` |
| Output / analytics | `ba_`, `bm_` | `project_analytics` | `[abrev]_analytics` |
| Master / business | `m_`, `ba_` | `project_analytics` | dataset correspondiente |
| Stored Procedures | `sp_` | `project_operation` | `[abrev]_sp` |

> **Excepción SPs:** los Stored Procedures son procedimientos, no tablas. Se referencian con
> `${project_operation}.${dataset_sp}.sp_nombre`. La variable `dataset_sp` (sin `project_` ni `table_`)
> es la única excepción a la regla de 3 variables.

### Ejemplo completo de `_DATAOPS_VARIABLES`

```
# ─── Proyectos globales del proceso ──────────────────────────────────────────
project_operation=prd-itc-customer-services
project_analytics=prd-itc-customer-services
project_billing=cloud-itc-billing

# ─── Tablas input / fuentes externas (3 variables por tabla) ─────────────────
project_ba_itc_attr_demographic=prd-itc-data-storage
dataset_ba_itc_attr_demographic=ba_itc_attribute_party
table_ba_itc_attr_demographic=ba_itc_attr_demographic

project_ba_itc_attr_payment_pos=prd-itc-retail-storage
dataset_ba_itc_attr_payment_pos=ba_itc_attribute_party
table_ba_itc_attr_payment_pos=ba_itc_attr_payment_pos

project_ba_itc_attr_insurance=prd-itc-insurance-storage
dataset_ba_itc_attr_insurance=ba_itc_attribute_party
table_ba_itc_attr_insurance=ba_itc_attr_insurance

project_ba_itc_attr_rcc=prd-itc-rcc-storage
dataset_ba_itc_attr_rcc=ba_itc_attribute_party
table_ba_itc_attr_rcc=ba_itc_attr_rcc

# ─── Tablas stage / tmp / aux del proceso (3 variables por tabla) ────────────
# (project_ y dataset_ pueden coincidir entre ellas, pero cada tabla tiene su propio triplete)
project_tmp_score_calc=prd-itc-customer-services
dataset_tmp_score_calc=itc_stage
table_tmp_score_calc=tmp_score_calc

project_aux_exclusion=prd-itc-customer-services
dataset_aux_exclusion=itc_stage
table_aux_exclusion=aux_exclusion_list

# ─── Tablas output / analytics / master / business (3 variables por tabla) ───
project_ba_itc_customer_score=prd-itc-customer-services
dataset_ba_itc_customer_score=itc_analytics
table_ba_itc_customer_score=ba_itc_customer_score

# ─── Stored Procedures (excepción: proyecto + dataset global, SP por nombre) ──
dataset_sp=itc_sp

# ─── Infraestructura y notificaciones ────────────────────────────────────────
service_account_job=prd-itc-[caso-uso]-job@prd-itc-customer-services.iam.gserviceaccount.com
service_account_app=prd-itc-[caso-uso]-app@prd-itc-customer-services.iam.gserviceaccount.com
mail_pubsub_project=stalwart-motif-270218
mail_pubsub_topic=itcm-inca-mail
```

### Uso en SQLs y YAMLs de componentes

Siempre referenciar estas variables en lugar de hardcodear proyectos, datasets o nombres de tabla:

```sql
-- DDL: tabla output — usa las 3 variables declaradas en env_[env].json
-- CREATE TABLE IF NOT EXISTS (nunca CREATE OR REPLACE TABLE en DDL de tablas finales)
CREATE TABLE IF NOT EXISTS `${project_ba_itc_customer_score}.${dataset_ba_itc_customer_score}.${table_ba_itc_customer_score}`
(
  ...
)
```

```sql
-- SP: se crea en project_operation (data-operation), dataset_sp
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_calcular_score`(process_date STRING)
BEGIN
  -- Tablas stage/tmp: también usan 3 variables (no hardcodear nombre de tabla)
  INSERT INTO `${project_tmp_score_calc}.${dataset_tmp_score_calc}.${table_tmp_score_calc}`
  SELECT *
  FROM `${project_ba_itc_attr_payment_pos}.${dataset_ba_itc_attr_payment_pos}.${table_ba_itc_attr_payment_pos}`
  WHERE ...;

  -- Enriquecer con otra fuente input
  LEFT JOIN `${project_ba_itc_attr_demographic}.${dataset_ba_itc_attr_demographic}.${table_ba_itc_attr_demographic}`
    USING (party_id)

  -- Tabla output: también 3 variables
  INSERT INTO `${project_ba_itc_customer_score}.${dataset_ba_itc_customer_score}.${table_ba_itc_customer_score}`
  SELECT * FROM `${project_tmp_score_calc}.${dataset_tmp_score_calc}.${table_tmp_score_calc}`;
END
```

```yaml
# Vertex Pipeline — env_vars con referencias completas (TODAS las tablas usan 3 variables)
env_vars:
  # Tablas input
  TABLA_PAYMENT:     "${project_ba_itc_attr_payment_pos}.${dataset_ba_itc_attr_payment_pos}.${table_ba_itc_attr_payment_pos}"
  TABLA_DEMOGRAPHIC: "${project_ba_itc_attr_demographic}.${dataset_ba_itc_attr_demographic}.${table_ba_itc_attr_demographic}"
  # Tablas stage/tmp/aux — también 3 variables (no hardcodear nombre de tabla)
  TABLA_TMP:         "${project_tmp_score_calc}.${dataset_tmp_score_calc}.${table_tmp_score_calc}"
  # SPs — excepción: project_operation + dataset_sp + nombre del SP (procedimiento, no tabla)
  TABLA_SP:          "${project_operation}.${dataset_sp}.sp_calcular_score"
  # Tabla output — también 3 variables
  TABLA_OUTPUT:      "${project_ba_itc_customer_score}.${dataset_ba_itc_customer_score}.${table_ba_itc_customer_score}"
```

---

## 1. bigquery_ddl — DDL de BigQuery

**No requiere YAML.** El framework lee directamente el archivo `.sql`.

### Reglas del archivo SQL

- Primera línea NO vacía debe contener `CREATE TABLE`, `CREATE OR REPLACE TABLE`,
  `CREATE VIEW`, o `ALTER TABLE`.
- La primera línea debe tener la referencia `proyecto.dataset.tabla` (con o sin backticks).
- **Prohibido:** `DROP TABLE`, `TRUNCATE TABLE` (el framework aborta el deploy).
- Si la tabla **ya existe**, se omite silenciosamente (idempotente).
- El dataset se crea automáticamente si no existe.

### Ubicación convención

```
data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql            ← CREATE TABLE IF NOT EXISTS (tabla final)
data/bigquery/{dataset_out}/{tabla_out}/ddl/tmp_{tabla_out}_{emp}.sql  ← tablas staging por fuente
data/bigquery/{dataset_out}/{tabla_out}/alter/alter_{tabla_out}_YYYYMMDD_{NNN}.sql  ← ALTER TABLE ADD COLUMN
```

**Reglas para scripts `alter/`:**
- Solo `ADD COLUMN IF NOT EXISTS` — `DROP COLUMN` está **PROHIBIDO**
- Un archivo por migración; naming: `alter_{tabla_out}_YYYYMMDD_{NNN}.sql`
- Se registran bajo `bigquery_ddl` **después** del script de CREATE TABLE de la misma tabla
- El framework reconoce `ALTER TABLE` como primera línea válida en `bigquery_ddl.sh`

Ver `@.claude/data/standard/factory/repositories.md` §3 — no hay variante "sin fases", todo
módulo `bq_pipeline` anida por `{dataset_out}/{tabla_out}`.

### Ejemplo entry en deploy.json

```json
"bigquery_ddl": [
  "/data/bigquery/master_product/m_promotion/ddl/tmp_m_promotion_spsa.sql",
  "/data/bigquery/master_product/m_promotion/ddl/m_promotion.sql",
  "/data/bigquery/master_product/m_promotion/alter/alter_m_promotion_20260817_001.sql"
]
```

### Nomenclatura

Ver `@.claude/data/standard/bigquery/nomenclatura-retail.md` — Sección 2 (Tablas) y
`@.claude/data/standard/bigquery/development.md` — Sección 2.

---

## 2. bigquery_sp — Stored Procedures de BigQuery

**No requiere YAML.** El framework lee directamente el archivo `.sql`.

### Reglas del archivo SQL

- Primera línea NO vacía debe comenzar con `CREATE OR REPLACE PROCEDURE` (case-insensitive).
- La primera línea debe contener la referencia `proyecto.dataset.sp_nombre`.
- El dataset se crea automáticamente si no existe.
- Los backticks son añadidos automáticamente si faltan.
- **El proyecto en el header debe ser `${project_operation}`** — los SPs se crean en el proyecto de operación, no en `${project_analytics}` ni hardcodeado.
- **El dataset en el header debe ser `${dataset_sp}`**.

### Template del header SQL

```sql
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_[nombre_proceso]`(
  process_date STRING
)
BEGIN
  -- Tablas temporales/stage: ${project_analytics}.${dataset_stage}
  -- Tablas output:           ${project_analytics}.${dataset_analytics}
END
```

> `${project_operation}` ya contiene el prefijo de ambiente (`dev-`, `prd-`) en su valor
> declarado en `env_dev.json`. No construir el proyecto con `${env}-...`.

### Ubicación convención

```
data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql   ← uno por fuente
data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql      ← SP de DQ (único)
```

### Nomenclatura

Ver `@.claude/data/standard/bigquery/nomenclatura-retail.md` — Sección 1 (SPs) y
`@.claude/data/standard/bigquery/development.md` — Secciones 1, 8, 9.

---

## 3. bigquery_dml — Scripts DML de BigQuery

**No requiere YAML.** Cualquier sentencia SQL válida (INSERT, UPDATE, DELETE, CALL, etc.).

### Reglas importantes

> **Regla crítica del framework:** Los DML **solo se ejecutan en ambiente de desarrollo**.
> El framework **no ejecuta DML en ambientes de producción** (`prd`).

- Usar DML en dev para probar stored procedures: `CALL proyecto.dataset.sp_nombre('param')`.
- No incluir DML en `deploy_prd.json` — se ignoran silenciosamente o se aborta.

### Ubicación convención

```
data/bigquery/{dataset_out}/{tabla_out}/dml/call_sp_{tabla_out}_{emp}.sql          ← CALL de prueba
data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_config_{tabla_out}.sql          ← config reglas DQ (única)
data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_monitor_config_{tabla_out}.sql  ← config monitores DQ (única)
```

---

## 4. bucket — Cloud Storage

> **Movido a InfraOps.** La creación de buckets Cloud Storage se gestiona en la etapa INFRAOPS,
> no en la etapa DATAOPS.
>
> Ver: `@.claude/data/skills/release/infraops-configurator/SKILL.md` — Sección 8: `cloud_storage`

Los buckets deben existir **antes** de ejecutar el trigger Dataops. Declararlos en
`infra/cloud_storage/[nombre].yaml` e incluirlos en `deploy/infra_dev.json` bajo la clave
`cloud_storage`.

La variable `${bucket_[propósito]}` en `env_dev.json` sigue siendo compartida entre InfraOps
(crea el bucket) y Dataops (usa el bucket en `deploy_config.yaml` de Vertex, Cloud Functions, etc.).

---

## 5. image — Imagen Docker en Artifact Registry

### Ubicación convención

```
image/{dataset_out}/{tabla_out}/{tabla_out_kebab}-{emp}.yaml
```

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `dockerfile` | **Sí** | — | Ruta al Dockerfile desde la raíz del repo. Ej: `service/cloud_run/mi-servicio/Dockerfile` |
| `repo` | No | Nombre del directorio padre del YAML | Nombre del repositorio en Artifact Registry |
| `name` | No | Nombre del directorio padre del Dockerfile | Nombre de la imagen. Se le agrega prefijo `${env}-` automáticamente |
| `region` | No | `us-central1` | Región del Artifact Registry |
| `description` | No | — | Descripción de la imagen (solo metadata) |

### Comportamiento

- El framework ejecuta `gcloud builds submit --tag [region]-docker.pkg.dev/[PROJECT_ID]/[repo]/[env]-[name]:latest`.
- Si el repositorio en Artifact Registry no existe, lo crea automáticamente.
- La imagen resultante se puede referenciar en cloud_run como:
  `[region]-docker.pkg.dev/${env}-[PROJECT_ID]/[repo]/${env}-[name]:latest`

### Template

```yaml
dockerfile: service/cloud_run/mi-servicio/Dockerfile
repo: dataops-artifacts
region: us-central1
description: "Descripción de la imagen"
```

### Ejemplo real

```yaml
# image/dataops-artifacts/itc-campaign-loader-api.yaml
dockerfile: service/cloud_run/itc-campaign-loader-api/Dockerfile
repo: dataops-artifacts
region: us-central1
description: "Imagen para cloudrun campaign loader"
```

---

## 6. cloud_run — Cloud Run Service

> Estándar de desarrollo del servicio: `@.claude/data/standard/services/cloud-run.md`

### Ubicación convención

```
service/cloud_run/{dataset_out}/{tabla_out}/[nombre-servicio]/deploy_config.yaml
```

El código del servicio sigue la estructura en capas definida en el estándar:
```
service/cloud_run/[nombre-servicio]/
├── Dockerfile
├── requirements.txt
├── deploy_config.yaml
└── src/main/
    ├── main.py           ← FastAPI app + /health
    ├── config/           ← inicialización: Secret Manager, credenciales DB
    ├── router/           ← endpoints HTTP (uno por entidad)
    ├── function/         ← lógica de negocio
    ├── model/            ← Pydantic schemas
    └── utils/datasource/ ← conexiones a PostgreSQL, BigQuery, etc.
```

### ⚠️ REGLA CRÍTICA — Campos permitidos

El script `cloud_run.sh` lee **EXACTAMENTE 14 campos**. NO generar ningún otro campo fuera de esta lista.

Campos que se deben **IGNORAR COMPLETAMENTE** aunque sean comunes en Cloud Run genérico:
- `service:`, `runtime:`, `resources:`, `networking:`, `environment:` (secciones agrupadas)
- `health_check:`, `vpc_connector`, `secrets:`, `cloud_sql:`, `autoscaling:`, `labels:`, `logging:`, `monitoring:`
- `entrypoint:`, `env:`, `dockerfile:` (pertenecen a section de imagen, no aquí)

Incluir campos fuera del conjunto de 14 significa que serán silenciosamente ignorados por el framework y causarán confusión al lector.

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `name` | No | Nombre del directorio del servicio | Nombre del servicio en Cloud Run. El script agrega `${env}-` si no lo tiene. |
| `dataops_variable` | No | — | Variable que recibirá la URL del servicio desplegado (disponible para steps posteriores como `${DATAOPS_VARIABLE}`). Usar prefijo `crun_`. |
| `region` | No | `us-central1` | Región GCP de despliegue. |
| `image` | **Sí** | — | URL completa de la imagen en Artifact Registry: `[region]-docker.pkg.dev/${env}-[proyecto]/dataops-artifacts/${env}-[nombre]:latest` |
| `project` | **Sí** | `${project_operation}` | Proyecto GCP donde se despliega el servicio. Siempre `${project_operation}`. |
| `service_account` | No | `$SERVICE_ACCOUNT_ID` (Cloud Build) | SA del servicio. Usar SA tipo **`-app`** — ver `@.claude/data/standard/services/service-accounts.md`. |
| `allow_unauthenticated` | No | `false` | Si `true`: acceso público sin autenticación. Si `false`: requiere token Bearer. |
| `memory` | No | `2Gi` | RAM asignada. Opciones: `512Mi`, `1Gi`, `2Gi`, `4Gi`, `8Gi`, `16Gi`, `32Gi`. Para 8Gi+ se requieren 4+ CPUs. |
| `cpu` | No | `1` | CPUs. Opciones: `1`, `2`, `4`, `6`, `8`. |
| `concurrency` | No | `1` | Requests simultáneos por instancia (1–1000). Usar `1` para procesamiento stateful. |
| `timeout` | No | `1800` | Timeout en segundos. Máximo `3600`. |
| `max_instances` | No | Sin límite | Máximo de instancias para escalar. Omitir si no se necesita límite. |
| `platform` | No | `managed` | Siempre `managed` (explícito aunque el script lo ignora). |
| `add_cloudsql_instances` | No | — | Lista de instancias Cloud SQL. **NOTA:** El script SOLO lee el primer elemento `[0]`, aunque se declaren varios. |
| `env_vars` | No | — | Mapa de variables de entorno `CLAVE: "valor"`. El script las escribe a `env_vars.yaml` y las pasa con `--env-vars-file`. |

### Variables de entorno estándar

Todo servicio Cloud Run ITC debe declarar en `env_vars`:

| Variable | Descripción |
|---|---|
| `CURR_ENVI` | Siempre `"${env}"` — controla modo de conexión (GCP vs local) |
| `APP_DEBUG` | Siempre `"false"` en GCP — activa Cloud SQL socket en vez de TCP |
| `SECRET_ID` | URI del secreto con credenciales DB: `"${SECRET_ID}"` (de `_DATAOPS_VARIABLES`) |

Variables adicionales según capacidades del servicio:

| Variable | Descripción |
|---|---|
| `SCHEMA_PG` | Schema de PostgreSQL: `"${schema_pg}"` |
| `BQ_PROJECT_ID` | Proyecto BigQuery: `"${env}-[proyecto]"` |
| `BQ_DATASET` | Dataset BigQuery |
| `TOPIC_NAME_*` | Topic Pub/Sub completo: `"projects/${env}-[proyecto]/topics/${env}-[nombre]"` |
| `PROJECT_ID_PUBSUB_MAIL` | `"${mail_pubsub_project}"` |
| `TOPIC_NAME_MAIL` | `"${mail_pubsub_topic}"` |

### Template

```yaml
name: ${env}-[nombre]-[sufijo]
dataops_variable: crun_[nombre_snake]_uri
region: us-central1
image: us-central1-docker.pkg.dev/${env}-[proyecto]/dataops-artifacts/${env}-[nombre-imagen]:latest
project: ${project_operation}
service_account: ${service_account_app}
allow_unauthenticated: false
memory: 2Gi
cpu: 1
concurrency: 1
timeout: 3600
max_instances: 10
add_cloudsql_instances:
  - ${cloudsql_instance}
env_vars:
  CURR_ENVI: "${env}"
  APP_DEBUG: "false"
  SECRET_ID: "${SECRET_ID}"
  SCHEMA_PG: "${schema_pg}"
  BQ_PROJECT_ID: "${env}-[proyecto]"
  BQ_DATASET: "[dataset]"
```

### Ejemplo real (itc-campaign-loader-api) — Patrón canónico

```yaml
name: ${env}-itc-campaign-loader-run-h09a
dataops_variable: crun_itc_campaign_loader_api_uri
region: us-central1
image: us-central1-docker.pkg.dev/${env}-itc-customer-services/dataops-artifacts/${env}-itc-campaign-loader-api:latest
platform: managed
project: ${env}-itc-customer-services
service_account: ${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com
allow_unauthenticated: true
memory: 2Gi
cpu: 2
concurrency: 1
timeout: 3600
max_instances: 5
add_cloudsql_instances:
  - ${inca_cloudsql_instance}
env_vars:
  CURR_ENVI: "${env}"
  APP_DEBUG: "false"
  SECRET_ID: "${SECRET_ID}"
  TABLE_CAMPAIGN: "${schema_pg_customer_recommendation}.campaign"
  TABLE_CAMPAIGN_ITEM: "${schema_pg_customer_recommendation}.campaign_item"
  TABLE_TMP_CAMPAIGN_ITEM: "${schema_pg_customer_recommendation}.tmp_campaign_item"
  itc_company_id: "074"
  TABLE_BQ_PRODUCT: "${proyecto_farmas_input}.${dataset_farmas_input}.${tabla_farmas_dv_productos}"
  TABLE_TMP_PRODUCT: "${schema_pg_customer_recommendation}.tmp_product"
  TABLE_PRODUCT: "${schema_pg_customer_recommendation}.product"
  TABLE_VARIABLE: "${schema_pg_customer_recommendation}.variable"
  TABLE_VARIABLE_DATA: "${schema_pg_customer_recommendation}.variable_data"
  SCHEMA_CUSTOMER_RECOMMENDATION: "${schema_pg_customer_recommendation}"
  api_create_campaign_param: "${url_api_campaign_mngt}/campaign-management/campaign-bucket/create-campaign-param"
  PUBSUB_PROJECT_ID: "${env}-itc-customer-services"
  PUBSUB_TOPIC_ID: "${topico_farmas_campaign_item_inserted}"
  PROJECT_ID_PUBSUB_MAIL: "${mail_pubsub_project}"
  TOPIC_NAME_MAIL: "${mail_pubsub_topic}"
  TABLE_BQ_PROCESS_RESOURCE: "${env}-itc-customer-services.bi_services_monitoring.process_resource"
  TABLE_BQ_CAMPAIGN_CTR: "${env}-itc-customer-services.bi_services_monitoring.ctr_inca_customer_recommendation_campaign"
  BQ_PROJECT_ID: "${env}-itc-customer-services"
  BQ_DBLINK_PG: "${dblink_pg}"
  EXECUTION_PIPELINE: >-
    {"config":{"project_id":"${env}-itc-customer-services","region":"us-central1","bucket":"gs://${bucket_modelo_recom}","service_account":"${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com"},"pipelines":{"itc-recommendation-model-train-als":{"display_name":"itc-recommendation-model-training","description":"Ejecuta el pipeline de entrenamiento del modelo ALS.","template_path":"gs://${bucket_modelo_recom}/itc-recommendation-pipeline/pipeline-train-pipeline-latest.json"},"itc-recommendation-model-inference-als":{"display_name":"itc-recommendation-model-inference","description":"Ejecuta el pipeline de inferencia del modelo ALS.","template_path":"gs://${bucket_modelo_recom}/itc-recommendation-pipeline/pipeline-inference-pipeline-latest.json"}}}
```

Ver ejemplos completos en la carpeta `examples/cloud-run/` de este skill.

### Dockerfile estándar para Cloud Run

El Dockerfile debe ser **simple, single-stage**, basado en `python:3.11-slim`:

```dockerfile
# Usa una imagen oficial de Python
FROM python:3.11-slim

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia requirements.txt
COPY requirements.txt .

# Copia los archivos de tu app al contenedor
COPY src/main /app

# Instala dependencias
RUN pip install --no-cache-dir -r requirements.txt

# Expone el puerto usado por Uvicorn
EXPOSE 8080

# Comando para correr la app FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**NO usar:**
- Multi-stage builds innecesarios
- Health checks en el Dockerfile (se configuran en `gcloud run deploy`)
- Usuarios no-root complejos
- RUN commands que instalan librerías del sistema (usar imagen slim base)

Ver ejemplo completo en `examples/cloud-run/Dockerfile` de este skill.

---

## 7. cloud_function — Cloud Function Gen2

### Ubicación convención

```
service/cloud_function/{dataset_out}/{tabla_out}/[nombre-funcion]/deploy_config.yaml
```

El directorio debe contener `main.py`, `app.py` o `function.py` (se usa el primero que exista).

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `name` | No | Nombre del directorio de la función | Nombre de la función. Se agrega `${env}-` si no lo tiene |
| `dataops_variable` | No | — | Variable que recibirá la URL de la función |
| `region` | No | `us-central1` | Región de despliegue |
| `runtime` | No | `python311` | Runtime. Opciones: `python311`, `python39`, `python310`, `nodejs20`, `java21` |
| `entry_point` | No | Primera `def` en el archivo main | Nombre de la función Python de entrada |
| `memory` | No | `512MB` | Memoria. Ej: `256MB`, `512MB`, `1GB`, `2GB`, `4GB` |
| `timeout` | No | `540s` | Timeout. Máximo `540s` para Gen2 |
| `max_instances` | No | `10` | Máximo de instancias |
| `allow_unauthenticated` | No | `false` | Acceso público |
| `service_account` | No | `$SERVICE_ACCOUNT_ID` | Service Account. Usar SA tipo **`-app`** — ver `@.claude/data/standard/services/service-accounts.md` |
| `project` | **Sí** | `${project_operation}` | Proyecto GCP. Siempre `${project_operation}`. |
| `env_vars` | No | — | Mapa de variables de entorno |

### Opciones de trigger (excluyentes)

#### Trigger HTTP directo
No se define trigger explícito (o se pone `trigger_http: true`). La función queda como HTTP endpoint.

#### Trigger Eventarc — Cloud Storage

```yaml
trigger_eventarc:
  event_type: google.cloud.storage.object.v1.finalized  # o .deleted, .archived, .metadataUpdated
  bucket: ${env}-nombre-bucket-gcs
  trigger_location: us                                   # región del trigger (us, us-central1, etc.)
  service_account: ${env}-sa@${env}-proyecto.iam.gserviceaccount.com
  trigger_name: nombre-trigger-eventarc                  # nombre del trigger Eventarc (metadata)
  event_provider: cloud-storage
```

#### Trigger Eventarc — Pub/Sub

```yaml
trigger_eventarc_pubsub:
  topic: nombre-del-topico-pubsub
  trigger_name: nombre-trigger-pubsub                    # opcional, se genera si no se define
  trigger_location: us-central1
  service_account: ${env}-sa@${env}-proyecto.iam.gserviceaccount.com
```

### Template (trigger HTTP)

```yaml
name: ${env}-nombre-funcion
dataops_variable: func_nombre_funcion_url
region: us-central1
runtime: python311
entry_point: nombre_funcion_entrada
allow_unauthenticated: false
service_account: ${service_account_app}
project: ${project_operation}
memory: 512MB
timeout: 540s
max_instances: 10
env_vars:
  VARIABLE_UNO: "${valor}"
  URL_CLOUD_RUN: "${crun_mi_servicio_uri}"
```

### Template (trigger GCS)

```yaml
name: ${env}-trigger-gcs-funcion
dataops_variable: func_trigger_gcs_url
region: us-central1
runtime: python311
entry_point: on_gcs_upload
allow_unauthenticated: false
service_account: ${service_account_app}
project: ${project_operation}
trigger_eventarc:
  trigger_name: trigger-upload-files
  event_type: google.cloud.storage.object.v1.finalized
  bucket: ${env}-nombre-bucket
  trigger_location: us
  service_account: ${env}-sa@${env}-proyecto.iam.gserviceaccount.com
  event_provider: cloud-storage
```

### Ejemplo real

```yaml
name: ${env}-itc-trigger-camp-loader-fape-fun-h09a
dataops_variable: func_itc_campaign_trigger_file_loader
region: us-central1
runtime: python311
entry_point: on_gcs_upload
allow_unauthenticated: false
trigger_eventarc:
  trigger_name: trigger-load-files-fape
  event_type: google.cloud.storage.object.v1.finalized
  bucket: ${env}-farmas-raw-cupones-digitales-xdmg
  trigger_location: us
  service_account: ${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com
  event_provider: cloud-storage
```

---

## 8. workflow — Cloud Workflows

### Ubicación convención

```
pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml   ← uno por fuente
```

Ver `@.claude/data/skills/build/orchestration/workflow-orchestration/SKILL.md` — regla de
cardinalidad por fuente.

El archivo YAML contiene tanto la configuración del deploy como la **definición del workflow inline** bajo la clave `source`.

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `name` | No | Nombre del archivo `.yaml` sin extensión | Nombre del workflow en GCP |
| `region` | No | `us-central1` | Región de despliegue |
| `description` | No | — | Descripción del workflow |
| `service_account` | No | `$SERVICE_ACCOUNT_ID` | SA con permisos de ejecución. Usar SA tipo **`-job`** — ver `@.claude/data/standard/services/service-accounts.md` |
| `dataops_variable` | No | — | Variable que recibirá el nombre del workflow |
| `project` | **Sí** | `${project_operation}` | Proyecto GCP. Siempre `${project_operation}`. |
| `source` | **Sí** | — | Definición completa del workflow (sintaxis Google Workflows YAML) |

### Estructura del source

```yaml
source:
  main:
    params: [args]
    steps:
      - paso_uno:
          ...
  SubworkflowOpcional:
    params: [param1, param2]
    steps:
      - ...
```

### Template completo

```yaml
name: ${env}-nombre-workflow
region: us-central1
project: ${project_operation}
description: "Descripción del workflow"
service_account: ${service_account_job}
source:
  main:
    params: [args]
    steps:
      - set_vars:
          assign:
            - var_proyecto: ${env}-proyecto-id
            - var_api_url: "${url_cloud_run_service}"
      - llamar_api:
          call: http.post
          args:
            url: ${var_api_url + "/endpoint"}
            auth:
              type: OIDC
              audience: ${var_api_url}
            body:
              param: "valor"
          result: api_response
      - return_response:
          return: ${"Workflow completado"}
```

### Patrones comunes en workflows

#### Llamada BigQuery via SP

```yaml
- ejecutar_sp:
    call: googleapis.bigquery.v2.jobs.query
    args:
      projectId: ${bq_project_id}
      body:
        query: ${"CALL `" + var_sp_nombre + "`('" + var_fecha + "')"}
        useLegacySql: false
    result: bq_response
```

#### Esperar workflow hijo

```yaml
- iniciar_workflow_hijo:
    call: http.post
    args:
      url: ${"https://workflowexecutions.googleapis.com/v1/projects/" + proyecto + "/locations/us-central1/workflows/" + wf_hijo + "/executions"}
      auth:
        type: OAuth2
      body:
        argument: '{"param": "valor"}'
    result: ejecucion_hijo
- esperar_hijo:
    call: WorkflowState
    args:
      execution_name: ${ejecucion_hijo.body.name}
    result: estado_hijo
```

---

## 9. vertex_pipeline — Vertex AI Pipeline

### Ubicación convención

```
service/vertex/{dataset_out}/{tabla_out}/[nombre-pipeline]/deploy_config.yaml
service/vertex/{dataset_out}/{tabla_out}/[nombre-pipeline]/deploy_config_train.yaml
service/vertex/[nombre-pipeline]/deploy_config_inference.yaml
```

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `project` | **Sí** | `${project_operation}` | Proyecto GCP. Siempre `${project_operation}`. |
| `region` | No | `us-central1` | Región de Vertex AI |
| `service_account` | No | `$SERVICE_ACCOUNT_ID` | SA con permisos de Vertex AI. Usar SA tipo **`-job`** — ver `@.claude/data/standard/services/service-accounts.md` |
| `pipeline_bucket_dataops` | **Sí** | — | Bucket GCS donde se subirá el JSON compilado del pipeline |
| `pipeline_path_dataops` | **Sí** | — | Carpeta dentro del bucket para los archivos JSON del pipeline |
| `pipelines` | **Sí** | — | Lista de archivos `.py` o `.ipynb` que compilan el pipeline |
| `run_after_deploy` | No | `false` | Si ejecutar el pipeline inmediatamente tras compilar |
| `dataops_variable` | No | — | Variable que recibirá la URL/path del pipeline compilado |
| `env_vars` | No | — | Variables exportadas antes de ejecutar los scripts de pipeline |

### Comportamiento del deploy

1. Crea un entorno virtual Python con dependencias: `kfp`, `google-cloud-aiplatform`, `google-cloud-bigquery`, etc.
2. Para cada archivo en `pipelines`: si es `.ipynb` lo convierte a `.py` con `jupyter nbconvert`.
3. Ejecuta el script Python. El script debe compilar el pipeline a JSON.
4. Sube el JSON a `gs://[pipeline_bucket_dataops]/[pipeline_path_dataops]/[nombre]-pipeline-latest.json`.

### Variables auto-inyectadas por el framework vs variables en `env_vars`

El framework exporta automáticamente las siguientes variables **antes** de ejecutar el script.
**NO deben ir en `env_vars`** — si se duplican, el YAML es más difícil de mantener.

| Variable auto-inyectada | Origen en el YAML |
|---|---|
| `PIPELINE_PROJECT_ID` | `project:` |
| `PIPELINE_SERVICE_ACCOUNT` | `service_account:` |
| `PIPELINE_REGION` | `region:` |
| `PIPELINE_BUCKET` (como `pipeline_bucket_dataops`) | `pipeline_bucket_dataops:` |
| `PIPELINE_COMPILE_FILE` | generado automáticamente: `[nombre-notebook]-pipeline-latest.json` |

Todo lo demás que el script necesite debe declararse explícitamente en `env_vars`.

> **Excepción:** en `deploy_config_inference.yaml` es válido redeclarar `PIPELINE_PROJECT_ID` y
> `PIPELINE_SERVICE_ACCOUNT` en `env_vars` si se necesita ejecutar el notebook localmente
> (desarrollo interactivo), ya que los defaults hardcodeados en el notebook pueden apuntar a otro proyecto.

### Organización de `env_vars` por categorías

Las variables de entorno se agrupan en cuatro categorías. Este orden es una convención recomendada:

```yaml
env_vars:
  # --- 1. Variables del framework Dataops (obligatorias) ---
  PIPELINE_BUCKET: ${bucket_nombre_modelo}            # ← variable de _DATAOPS_VARIABLES
  PIPELINE_DISPLAY_NAME: "itc-[nombre]-training"      # nombre visible en Vertex AI console
  PIPELINE_DESCRIPTION: "Descripción del pipeline"
  PIPELINE_PATH_ROOT: "artifacts/train"               # artifacts/train o artifacts/inference
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_nombre_modelo}/"

  # --- 2. Tablas BigQuery (TODAS usan 3 variables: project + dataset + table) ---
  # Tablas input
  TABLA_INPUT:     "${project_[nombre-tabla]}.${dataset_[nombre-tabla]}.${table_[nombre-tabla]}"
  # Tablas stage/tmp/aux — también 3 variables (declaradas en env_[env].json)
  TABLA_TMP:       "${project_tmp_nombre_resultado}.${dataset_tmp_nombre_resultado}.${table_tmp_nombre_resultado}"
  TABLA_EXCLUSION: "${project_aux_nombre_excluidos}.${dataset_aux_nombre_excluidos}.${table_aux_nombre_excluidos}"
  # Tablas output/analytics/master/business — también 3 variables
  TABLA_MONITOREO: "${project_ba_nombre_hist}.${dataset_ba_nombre_hist}.${table_ba_nombre_hist}"

  # --- 3. Rutas GCS (relativas dentro del bucket) ---
  PATH_MODELS: "models"      # subfolder para guardar artefactos joblib
  PATH_OUTPUT: "output"      # subfolder para parquets intermedios (solo si aplica)

  # --- 4. Hiperparámetros y configuración del modelo ---
  # Numéricos: SIN comillas (YAML los pasa como int/float al script)
  PARAM_INT: 304
  PARAM_FLOAT: 0.061827298031334625
  PARAM_INT_2: 46
  # Recursos de máquina: SIEMPRE con comillas (Vertex los espera como string)
  MACHINE_CPU_LIMIT: "4"
  MACHINE_MEMORY_LIMIT: "32G"
```

> **Tipo de datos en YAML vs Python:**
> - `FACTORS: 304` → en Python `os.getenv("FACTORS", 304)` devuelve el string `"304"` → usar `int(os.getenv(...))`
> - `REGULARIZATION: 0.06` → usar `float(os.getenv(...))`
> - `MACHINE_CPU_LIMIT: "4"` → se lee directo como string con `.set_cpu_limit(MACHINE_CPU_LIMIT)`

### Template

```yaml
project: ${project_operation}
region: us-central1
service_account: ${service_account_job}

pipeline_bucket_dataops: ${bucket_nombre_modelo}
pipeline_path_dataops: itc-[nombre]-pipeline

pipelines:
  - "./notebook/pipeline-train.ipynb"

run_after_deploy: false    # true solo en dev para pruebas puntuales; siempre false en prd
dataops_variable: VERTEX_PIPELINE_[NOMBRE]_URL

env_vars:
  # --- Framework Dataops ---
  PIPELINE_BUCKET: ${bucket_nombre_modelo}
  PIPELINE_DISPLAY_NAME: "itc-[nombre]-training"
  PIPELINE_DESCRIPTION: "Pipeline de entrenamiento [descripcion]"
  PIPELINE_PATH_ROOT: "artifacts/train"
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_nombre_modelo}/"

  # --- Tablas BigQuery (TODAS usan 3 variables) ---
  # Tablas input
  TABLA_INPUT:     "${project_[nombre-tabla]}.${dataset_[nombre-tabla]}.${table_[nombre-tabla]}"
  # Tablas stage/tmp/aux — también 3 variables
  TABLA_TMP:       "${project_tmp_nombre_output}.${dataset_tmp_nombre_output}.${table_tmp_nombre_output}"
  # Tablas output/analytics — también 3 variables
  TABLA_MONITOREO: "${project_ba_nombre_hist}.${dataset_ba_nombre_hist}.${table_ba_nombre_hist}"

  # --- Rutas GCS ---
  PATH_MODELS: "models"

  # --- Hiperparámetros (numéricos sin comillas) ---
  PARAM_1: 100
  PARAM_2: 0.01
  PARAM_3: 42
  N_OUTPUT: 20

  # --- Recursos de máquina (strings con comillas) ---
  MACHINE_CPU_LIMIT: "4"
  MACHINE_MEMORY_LIMIT: "32G"
```

### Patrón de lectura de `env_vars` en notebooks y `src/pipeline_*.py`

El notebook y el script `src/pipeline_*.py` leen las variables en bloques correspondientes al YAML.
Los defaults deben apuntar a valores de **desarrollo local** para poder ejecutar el notebook
sin desplegar con Dataops:

```python
import os
from kfp import compiler, dsl

# ================================================================
# BLOQUE 1 — Variables del framework (auto-inyectadas por Dataops)
# El framework las exporta desde los flags top-level del YAML.
# Definir defaults de dev para ejecución local.
# ================================================================
PIPELINE_DISPLAY_NAME    = os.getenv("PIPELINE_DISPLAY_NAME", "itc-[nombre]-training")
PIPELINE_DESCRIPTION     = os.getenv("PIPELINE_DESCRIPTION", "Pipeline de entrenamiento [nombre]")
PIPELINE_COMPILE_FILE    = os.getenv("PIPELINE_COMPILE_FILE", "pipeline-train-pipeline-latest.json")
PIPELINE_PROJECT_ID      = os.getenv("PIPELINE_PROJECT_ID", "dev-[proyecto]")
PIPELINE_REGION          = os.getenv("PIPELINE_REGION", "us-central1")
PIPELINE_SERVICE_ACCOUNT = os.getenv("PIPELINE_SERVICE_ACCOUNT", "")
PIPELINE_BUCKET          = os.getenv("PIPELINE_BUCKET", "dev-[bucket-nombre-modelo]")
PIPELINE_PATH_ROOT       = os.getenv("PIPELINE_PATH_ROOT", "artifacts/train")
PIPELINE_BUCKET_PROJECT_PATH = os.getenv("PIPELINE_BUCKET_PROJECT_PATH",
                                          f"gs://{PIPELINE_BUCKET}/")

# PIPELINE_ROOT se construye en código — nunca viene del YAML
PIPELINE_ROOT = f"{PIPELINE_BUCKET_PROJECT_PATH}{PIPELINE_PATH_ROOT}"

# ================================================================
# BLOQUE 2 — Tablas BigQuery (definidas en env_vars del YAML)
# Defaults apuntan a tablas de dev/local
# ================================================================
# Tablas input (en prod vienen del project/dataset/table de cada fuente)
TABLA_INPUT     = os.getenv("TABLA_INPUT",     "dev-datastorage.dataset_nombre_tabla.nombre_tabla")
# Tablas de trabajo y output (en prod usan project_analytics + dataset_stage/analytics)
TABLA_TMP       = os.getenv("TABLA_TMP",       "dev-proyecto.itc_stage.tmp_nombre_output")
TABLA_MONITOREO = os.getenv("TABLA_MONITOREO", "dev-proyecto.itc_analytics.ba_nombre_hist")
PATH_MODELS     = os.getenv("PATH_MODELS",     "models")

# ================================================================
# BLOQUE 3 — Hiperparámetros (cast explícito al tipo correcto)
# YAML los envía como string — siempre castear en código
# ================================================================
PARAM_1     = int(os.getenv("PARAM_1",   100))
PARAM_2     = float(os.getenv("PARAM_2", 0.01))
N_OUTPUT    = int(os.getenv("N_OUTPUT",  20))

# Recursos de máquina: se leen como string (Vertex los espera así)
MACHINE_CPU_LIMIT    = os.getenv("MACHINE_CPU_LIMIT",    "4")
MACHINE_MEMORY_LIMIT = os.getenv("MACHINE_MEMORY_LIMIT", "32G")

# ================================================================
# Print de configuración (obligatorio para debugging en Vertex AI)
# ================================================================
print("=== TRAIN PIPELINE CONFIG ===")
print(f"PROJECT      : {PIPELINE_PROJECT_ID}")
print(f"BUCKET       : {PIPELINE_BUCKET}")
print(f"PIPELINE ROOT: {PIPELINE_ROOT}")
print(f"TABLA INPUT  : {TABLA_INPUT}")
print(f"PARAM_1/2    : {PARAM_1} / {PARAM_2}")
print("==============================\n")
```

### Ejemplo real

```yaml
# service/vertex/itc-recommendation-ml-model/deploy_config_train.yaml
project: ${env}-itc-customer-services
region: us-central1
service_account: ${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com

pipeline_bucket_dataops: ${bucket_modelo_recom}
pipeline_path_dataops: itc-recommendation-pipeline

pipelines:
  - "./notebook/pipeline-train.ipynb"

run_after_deploy: false
dataops_variable: VERTEX_PIPELINE_URL

env_vars:
  # --- Framework Dataops ---
  PIPELINE_BUCKET: ${bucket_modelo_recom}
  PIPELINE_DISPLAY_NAME: "itc-recommendation-model-training"
  PIPELINE_DESCRIPTION: "Pipeline para el re-entrenamiento del modelo de recomendación ALS"
  PIPELINE_PATH_ROOT: "artifacts/train"
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_modelo_recom}/"

  # --- Tablas BigQuery ---
  TMP_CLIENTE_RATING: "${env}-itc-customer-services.${dataset_farmas_recom_stage}.temp_farmas_cupones_consolidado_cliente_trx_12m"
  AUX_JQ1_EXCLUSION: "${env}-itc-customer-services.${dataset_farmas_recom_stage}.aux_jq1_excluidos_recom"
  TMP_OUTPUT_RECOMENDACION: "${env}-itc-customer-services.${dataset_farmas_recom_stage}.tmp_recomendaciones_als"
  BA_MONITOREO_MODELO_RECOM_HIST: "${env}-itc-customer-services.${dataset_farmas_analytics_output}.ba_monitoreo_modelo_recom_hist"
  COLUMNA_GRUPO: "segmento_itc"
  COLUMNA_RATING: "decil_rating_distrib_cliente"

  # --- Rutas GCS ---
  PATH_MODELS: "models"

  # --- Hiperparámetros ALS (numéricos sin comillas) ---
  FACTORS: 304
  REGULARIZATION: 0.061827298031334625
  ITERATIONS: 46
  RANDOM_STATE: 42
  ALPHA: 49.15300275537158
  N_REC_REPO: 20
  N_REC_DESC: 20
```

```yaml
# service/vertex/itc-recommendation-ml-model/deploy_config_inference.yaml
project: ${env}-itc-customer-services
region: us-central1
service_account: ${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com

pipeline_bucket_dataops: ${bucket_modelo_recom}
pipeline_path_dataops: itc-recommendation-pipeline

pipelines:
  - "./notebook/pipeline-inference.ipynb"

run_after_deploy: false
dataops_variable: VERTEX_PIPELINE_INFERENCE_URL

env_vars:
  # --- Framework Dataops ---
  PIPELINE_BUCKET: ${bucket_modelo_recom}
  PIPELINE_DISPLAY_NAME: "itc-recommendation-model-inference"
  PIPELINE_DESCRIPTION: "Pipeline para generar recomendaciones con el modelo ALS"
  PIPELINE_PATH_ROOT: "artifacts/inference"
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_modelo_recom}/"
  # Redeclarados para ejecución local del notebook:
  PIPELINE_PROJECT_ID: "${env}-itc-customer-services"
  PIPELINE_SERVICE_ACCOUNT: "${env}-farmas-cupones-job@${env}-itc-customer-services.iam.gserviceaccount.com"

  # --- Tablas BigQuery ---
  TMP_CLIENTE_RATING: "${env}-itc-customer-services.${dataset_farmas_recom_stage}.temp_farmas_cupones_consolidado_cliente_trx_12m_pred"
  TMP_OUTPUT_RECOMENDACION: "${env}-itc-customer-services.${dataset_farmas_recom_stage}.tmp_recomendaciones_als_pred_infe"

  # --- Rutas GCS ---
  PATH_MODELS: "models"

  # --- Parámetros de inferencia (numéricos sin comillas) ---
  N_REC_REPO: 15
  N_REC_DESC: 10

  # --- Recursos de máquina (strings con comillas) ---
  MACHINE_CPU_LIMIT: "4"
  MACHINE_MEMORY_LIMIT: "32G"
```

> **Diferencia train vs inference en `env_vars`:**
> - `deploy_config_train.yaml` **no** incluye `PIPELINE_PROJECT_ID` ni `PIPELINE_SERVICE_ACCOUNT`
>   en `env_vars` — el framework los inyecta automáticamente desde `project:` y `service_account:`.
> - `deploy_config_inference.yaml` los **redeclara** en `env_vars` para permitir la ejecución
>   local/interactiva del notebook sin depender del framework.
> - Los hiperparámetros numéricos van **sin comillas** (`FACTORS: 304`). En el script se castean:
>   `FACTORS = int(os.getenv("FACTORS", 304))`.
> - `MACHINE_CPU_LIMIT` y `MACHINE_MEMORY_LIMIT` van **con comillas** porque Vertex AI los
>   espera como string en `.set_cpu_limit()` y `.set_memory_limit()`.

---

## 10. pubsub — Pub/Sub Topic y Suscripciones

### Ubicación convención

```
service/pubsub/{dataset_out}/{tabla_out}/[nombre-topico].yaml
```

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `topic_id` | **Sí** | — | Nombre del tópico Pub/Sub a crear |

#### Subscriptions (lista bajo `subscriptions:`)

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `name` | **Sí** | — | Nombre de la suscripción |
| `type` | **Sí** | — | `push` o `pull` |
| `push_endpoint` | Sí si `type: push` | — | URL endpoint que recibirá los mensajes |
| `service_account` | No | — | SA para autenticación OIDC del push |
| `ack_deadline` | No | `600` | Segundos para hacer ack (10–600) |
| `message_retention_duration` | No | `604800s` | Retención de mensajes (7 días) |
| `expiration_period` | No | `2678400s` | Periodo de expiración (31 días) |

### Comportamiento

- Si el tópico ya existe, no se recrea.
- Si la suscripción ya existe, se actualiza (`update`); si no existe, se crea (`create`).
- Para suscripciones `push` con SA, el framework configura automáticamente el rol
  `roles/iam.serviceAccountTokenCreator` en la SA del agente Pub/Sub del proyecto.

### Template

```yaml
topic_id: ${env}-nombre-topico

subscriptions:
  - name: ${env}-nombre-suscripcion-push
    type: push
    push_endpoint: "${url_cloud_run_service}/endpoint-receptor"
    service_account: ${env}-sa@${env}-proyecto.iam.gserviceaccount.com
    ack_deadline: 600
    message_retention_duration: 604800s
    expiration_period: 2678400s

  - name: ${env}-nombre-suscripcion-pull
    type: pull
    ack_deadline: 300
```

---

## 11. cloud_scheduler — Cloud Scheduler Job

### Ubicación convención

```
pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml   ← uno por workflow/fuente
```

> Corrección: este archivo decía antes `service/scheduler/` — contradice
> `@.claude/data/rules/dataops.md` ("Cloud Scheduler en `pipeline/scheduler/`, no en `service/`")
> y `@.claude/data/standard/factory/repositories.md`. `pipeline/scheduler/` es la ruta correcta.

### Flags del YAML

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `location` | No | — | Región del job (ej: `us-central1`) |
| `description` | No | — | Descripción del job |
| `schedule` | **Sí** | — | Expresión cron (ej: `"0 8 * * *"`) |
| `time-zone` | No | — | Zona horaria (ej: `America/Lima`) |
| `uri` | **Sí** | — | URL destino (Cloud Run, Cloud Function, Workflow, etc.) |
| `http-method` | No | — | `GET`, `POST`, `PUT`, `DELETE` |
| `headers` | No | — | Mapa de headers HTTP |
| `message-body` | No | — | Cuerpo del request HTTP |
| `verbosity` | No | — | Nivel de logging: `DEBUG`, `INFO`, `WARNING`, `ERROR` |
| `state` | No | `enabled` | `enabled` o `disabled` — controla si el job está activo |

### Comportamiento

- El job se nombra automáticamente como `${env}-[nombre-archivo-sin-.yaml]` con `_` reemplazados por `-`.
- Si el job ya existe, se actualiza (`gcloud scheduler jobs update`); si no, se crea.
- Si `state: disabled` y el job está activo, se pausa.
- Si `state: enabled` y el job está pausado, se reactiva.
- La autenticación se hace con OAuth (`--oauth-service-account-email=$SERVICE_ACCOUNT_ID`).

### Template

```yaml
location: us-central1
description: "Descripción del job scheduler"
schedule: "0 8 * * *"
time-zone: America/Lima
uri: "${crun_mi_servicio_uri}/endpoint"
http-method: POST
message-body: '{"param": "valor"}'
state: enabled
```

---

## Guía de Preguntas Diagnósticas

Cuando el usuario pida crear una configuración, recopila esta información:

### Para cualquier componente

1. ¿Cuál es el ambiente objetivo? (`dev` / `qa` / `prd`)
2. ¿Cuáles son los proyectos GCP del proceso?
   - `project_operation` → donde se despliegan servicios (SPs, CF, CR, Workflows, Vertex)
   - `project_analytics` → donde viven las tablas BQ de salida (data-storage)
   - `project_billing` → proyecto de facturación del proceso
3. ¿Cuáles son las tablas input del data storage corporativo? (→ definir `project_[tabla]`, `dataset_[tabla]`, `table_[tabla]` por cada una)
4. ¿Cuáles son las tablas internas del proceso? (stage, tmp, aux, output, master, business → definir las 3 variables por cada tabla aunque compartan proyecto/dataset; SPs → `dataset_sp` en `project_operation`)
5. ¿Cuál es la Service Account? (`${env}-[sa]@${env}-[proyecto].iam.gserviceaccount.com`)
6. ¿Necesita exportar su URL/valor para que otro componente lo use? (`dataops_variable`)

### Específicas por tipo

**image:** ¿Dónde está el Dockerfile? ¿Nombre del repo en Artifact Registry?

**cloud_run:** ¿Cuál es la imagen Docker? ¿Necesita Cloud SQL? ¿Variables de entorno? ¿CPU/Memoria?

**cloud_function:** ¿Cuál es el trigger? (HTTP / GCS bucket / Pub/Sub topic) ¿Entry point?

**workflow:** ¿Cuáles son los pasos principales? ¿Llama a SPs, APIs, otros workflows?

**vertex_pipeline:** ¿El notebook compila el pipeline? ¿Cuál es el bucket GCS? ¿Qué tablas BQ usa?

**pubsub:** ¿Necesita suscripciones push o pull? ¿La suscripción push llama a un Cloud Run o Cloud Function?

**cloud_scheduler:** ¿Con qué frecuencia corre? ¿Llama a qué endpoint?

---

## Checklist de Validación

Antes de agregar un componente al `deploy_[env].json`:

### Configuración general

- [ ] La estructura de carpetas del repo sigue el estándar `@.claude/data/standard/factory/repositories.md` (SQLs en `data/bigquery/`, no en `source/`)
- [ ] El path en `deploy_[env].json` empieza con `/` y es relativo a la raíz del repo
- [ ] El archivo YAML existe en la ruta indicada
- [ ] `env_dev.json` y `env_prd.json` generados en `deploy/` con **todas** las variables de todos los componentes
- [ ] Variables en `env_[env].json` ordenadas por tabla (project → dataset → table agrupados)
- [ ] Las referencias a `${variable}` están definidas en `_DATAOPS_VARIABLES` del trigger Cloud Build
- [ ] Si usa `${DATAOPS_VARIABLE}`, el componente que la exporta está en el json y en un step anterior
- [ ] **TODA tabla BigQuery** (input, output, stage, tmp, aux, master, business) usa 3 variables: `${project_[tabla]}`, `${dataset_[tabla]}`, `${table_[tabla]}` — nunca hardcodeado el nombre de tabla en SQL o YAML
- [ ] Los SPs son la única excepción: se referencian con `${project_operation}.${dataset_sp}.sp_nombre` (procedimiento, no tabla)
- [ ] No hay proyectos, datasets ni nombres de tabla hardcodeados en SQLs o YAMLs — todo por variable

### Por tipo

- [ ] **DDL/SP:** Primera línea tiene `proyecto.dataset.nombre` — no hay DROP/TRUNCATE
- [ ] **SP:** Header usa `${project_operation}.${dataset_sp}.sp_nombre` — no `${project_analytics}` ni hardcodeado
- [ ] **image:** El `dockerfile` path es válido y el Dockerfile existe
- [ ] **cloud_run:** `project: ${project_operation}` declarado; `image` es la URL completa en Artifact Registry; step `image` corre primero; `service_account: ${service_account_app}`
- [ ] **cloud_function:** `project: ${project_operation}` declarado; existe `main.py`, `app.py` o `function.py` en el directorio; `service_account: ${service_account_app}`
- [ ] **workflow:** `project: ${project_operation}` declarado; el YAML tiene la clave `source:`; `service_account: ${service_account_job}`
- [ ] **vertex_pipeline:** `project: ${project_operation}` declarado; los archivos en `pipelines:` existen y compilan el pipeline a JSON; `service_account: ${service_account_job}`
- [ ] **vertex_pipeline:** `env_vars` tiene las 5 variables de framework obligatorias: `PIPELINE_BUCKET`, `PIPELINE_DISPLAY_NAME`, `PIPELINE_DESCRIPTION`, `PIPELINE_PATH_ROOT`, `PIPELINE_BUCKET_PROJECT_PATH`
- [ ] **vertex_pipeline:** Tablas BQ en `env_vars` usan `${env}` y `${dataset_*}` — sin hardcodear proyectos ni datasets
- [ ] **vertex_pipeline:** Hiperparámetros numéricos sin comillas en YAML; `MACHINE_CPU_LIMIT`/`MACHINE_MEMORY_LIMIT` con comillas
- [ ] **vertex_pipeline:** `PIPELINE_PROJECT_ID` y `PIPELINE_SERVICE_ACCOUNT` NO están en `env_vars` de train (salen del top del YAML); solo en inference si se necesita ejecución local
- [ ] **vertex_pipeline:** El script/notebook usa `int(os.getenv(...))` y `float(os.getenv(...))` para castear numéricos
- [ ] **pubsub:** `topic_id` definido; si hay push, el endpoint existe y acepta el payload
- [ ] **cloud_scheduler:** `schedule` en formato cron válido; `uri` accesible con la SA; `service_account` usa SA tipo `-job`

---

## Convenciones de Nomenclatura para Recursos GCP

| Recurso | Patrón | Ejemplo |
|---|---|---|
| Cloud Run service | `${env}-[nombre]-[sufijo]` | `prd-itc-campaign-loader-run-h09a` |
| Cloud Function | `${env}-[nombre]-fun-[sufijo]` | `prd-itc-trigger-camp-loader-fape-fun-h09a` |
| Cloud Workflow | `${env}-[nombre-kebab-case]` | `prd-farmas-campaign-engine-export` |
| Imagen Docker | `${env}-[nombre-kebab-case]` | `prd-itc-campaign-loader-api` |
| Pub/Sub topic | `${env}-[nombre-kebab-case]` | `prd-farmas-campaign-item-inserted` |
| Cloud Scheduler job | `${env}-[nombre-kebab-case]` | `prd-farmas-daily-export-job` |
| GCS bucket | `${env}-[nombre-kebab-case]-[sufijo]` | `prd-farmas-raw-cupones-digitales-xdmg` |
| Vertex pipeline JSON | `[nombre-script]-pipeline-latest.json` | `pipeline-train-pipeline-latest.json` |

**Reglas:**
- Siempre prefijo `${env}-` para todos los recursos.
- Usar kebab-case (`-`) en nombres de recursos GCP (no snake_case).
- Los sufijos cortos (ej: `-h09a`, `-xdmg`) son identificadores únicos de proyecto — mantenerlos si existen.

---

## 12. Estructura Estándar de un Modelo Vertex AI

Todo modelo en `service/vertex/[nombre-modelo]/` debe seguir esta estructura:

```
[nombre-modelo]/
│
├── notebook/
│   ├── pipeline-train.ipynb        # Orquesta la compilación del pipeline de train
│   └── pipeline-inference.ipynb    # Orquesta la compilación del pipeline de inferencia
│
├── src/
│   ├── __init__.py
│   ├── components.py               # Componentes KFP (@dsl.component)
│   ├── pipeline_train.py           # Definición del pipeline de train (@dsl.pipeline)
│   └── pipeline_inference.py       # Definición del pipeline de inferencia (@dsl.pipeline)
│
├── deploy_config_train.yaml        # Config Dataops — train
├── deploy_config_inference.yaml    # Config Dataops — inference
├── requirements.txt                # Dependencias para desarrollo local
└── README.md                       # Definición funcional y técnica del modelo
```

### Responsabilidad de cada archivo

| Archivo | Propósito | Ejecutado por |
|---|---|---|
| `notebook/pipeline-*.ipynb` | Entry point. Lee variables de entorno e importa `src/pipeline_*.py`. Solo orquesta. | Dataops (convertido a .py) |
| `src/components.py` | Define funciones `@dsl.component` con su `base_image` y `packages_to_install`. Cada componente corre en su propio contenedor en Vertex AI. | Importado por pipeline_*.py |
| `src/pipeline_train.py` | Define `@dsl.pipeline` de entrenamiento. Lee variables de entorno. Compila el pipeline a JSON al final. | Importado por notebook |
| `src/pipeline_inference.py` | Define `@dsl.pipeline` de inferencia. Lee variables de entorno. Compila el pipeline a JSON al final. | Importado por notebook |
| `deploy_config_train.yaml` | YAML Dataops: señala el notebook como entry point y declara `env_vars` con hiperparámetros y tablas. | Framework Dataops |
| `deploy_config_inference.yaml` | YAML Dataops: igual que train pero para inferencia. | Framework Dataops |
| `requirements.txt` | Solo para el entorno virtual local del desarrollador. No afecta a los contenedores de Vertex AI (esos usan `packages_to_install` en cada componente). | Desarrollador local |
| `README.md` | Documenta: responsabilidad, flujo, tablas input/output, variables de entorno, hiperparámetros, métricas, instrucciones de desarrollo y decisiones de diseño. | Documentación |

### Reglas de implementación

**components.py:**
- Cada `@dsl.component` declara sus propios `packages_to_install` — son independientes del `requirements.txt`.
- Todos los `import` van **dentro** del cuerpo de la función, no al nivel de módulo.
- Los parámetros son primitivos (`str`, `int`, `float`, `List[str]`) — no objetos Python complejos.
- Los retornos son primitivos o `Artifact` de KFP.

**pipeline_train.py / pipeline_inference.py:**
- Leen toda la configuración desde `os.getenv()` con valores default de desarrollo.
- El bloque `if __name__ == "__main__":` solo compila — no ejecuta el pipeline en Vertex AI.
- Usan `dsl.ParallelFor` para paralelizar por segmento/grupo cuando aplique.
- Declaran recursos con `.set_cpu_limit()` y `.set_memory_limit()` por componente.

**notebook/pipeline-*.ipynb:**
- Primera celda: `import os, sys` y variables de entorno (ya exportadas por Dataops).
- Segunda celda: `sys.path.insert` para que el notebook encuentre `src/`.
- Tercera celda: `from src.pipeline_train import train_pipeline` + `compiler.Compiler().compile(...)`.
- El notebook NO debe contener lógica de negocio — solo orquestación y compilación.

> **Regla — Diccionarios de mapeo en notebooks (2026-03-23):**
> Los notebooks pueden definir diccionarios que mapean valores de variables del negocio (ej. nivel educativo, categorías de producto, etc.). Al generar o modificar código de un notebook:
> - **Respetar exactamente** el nombre del diccionario tal como está definido (`nivel_map`, no `educ_map`).
> - **Respetar exactamente** los keys y values del diccionario — no reformatearlos, no normalizarlos, no reemplazarlos con valores propios.
> - **No crear un diccionario paralelo** con otra estructura de valores (ej. numérica) si el original usa strings.
> - Si el código ya tiene `nivel_map = {...}` con sus valores definidos, cualquier modificación debe mantener ese mismo nombre y sus valores intactos.
>
> Ejemplo correcto — respetar el diccionario existente:
> ```python
> nivel_map = {'ANALFABETO/A': 'Sin_educacion', 'PRIMARIA COMPLETA': 'Primaria', ...}
> df['nivel_educativo'] = df['nivel_educativo'].map(nivel_map).fillna('Sin categoria')
> ```
> Ejemplo incorrecto — renombrar el diccionario y cambiar valores:
> ```python
> educ_map = {'Sin educacion': 1, 'Primaria completa': 2, ...}  # ❌ nombre diferente, valores diferentes
> ```

### Convención de nombres del JSON compilado

El framework Dataops genera automáticamente el nombre del JSON como:

```
{nombre_script_sin_extension}-pipeline-latest.json
```

Por eso los notebooks se llaman `pipeline-train.ipynb` y `pipeline-inference.ipynb`:
- `pipeline-train-pipeline-latest.json`
- `pipeline-inference-pipeline-latest.json`

### Relación notebook → deploy_config YAML

```yaml
# deploy_config_train.yaml
pipelines:
  - "./notebook/pipeline-train.ipynb"    # El framework convierte este notebook a .py y lo ejecuta
```

El JSON compilado se sube automáticamente a:
```
gs://{pipeline_bucket_dataops}/{pipeline_path_dataops}/pipeline-train-pipeline-latest.json
```

### Referencia al modelo de recomendación como ejemplo canónico

Ver implementación completa en [service/vertex/itc-recommendation-ml-model/](service/vertex/itc-recommendation-ml-model/):
- [src/components.py](service/vertex/itc-recommendation-ml-model/src/components.py)
- [src/pipeline_train.py](service/vertex/itc-recommendation-ml-model/src/pipeline_train.py)
- [src/pipeline_inference.py](service/vertex/itc-recommendation-ml-model/src/pipeline_inference.py)
- [README.md](service/vertex/itc-recommendation-ml-model/README.md) — plantilla de README

---

## Configuración del Trigger Cloud Build

El framework corre en Cloud Build. Esta sección describe cómo configurar el trigger
para un nuevo proyecto.

### Datos del proyecto del framework

| Parámetro | Valor |
|---|---|
| Proyecto GCP | `itc-data-devops-01` |
| Región | `us-central1` |
| Evento | Invocación manual |
| Repositorio del framework | `cloud-itc-dataops-01/itcm-dp-dataops-build` (GitHub) |
| SA de Cloud Build | `trv-itcbi-devops-app@itc-data-devops-01.iam.gserviceaccount.com` |

### Archivo YAML de Cloud Build según ambiente

| Ambiente | Archivo de configuración |
|---|---|
| Desarrollo | `/build/cloudbuild_sourcerepository_dev.yaml` |
| Producción | `/build/cloudbuild_sourcerepository_prd.yaml` |
| Rama de usuario | `/build/cloudbuild_sourcerepository_user.yaml` |

### Variables del Trigger Cloud Build

Estas variables se configuran en el trigger y son accesibles durante la ejecución:

| Variable | Descripción | Ejemplo |
|---|---|---|
| `_ABREV_EMPRESA` | Abreviatura de la empresa | `itc`, `farmas`, `ibk` |
| `_DATAOPS_VARIABLES` | Pares `nombre=valor` de variables de despliegue/reemplazo, separados por salto de línea | Ver abajo |
| `_PROJECT_ID` | Proyecto GCP por default si no se indica en los YAML de componente | `dev-itc-customer-services` |
| `_REPO_NAME` | Nombre del repositorio en Source Repository | `itcm-inca-audience-campaign-loader-api` |
| `_REPO_PROJECT_NAME` | Proyecto GCP donde vive el repositorio | `itc-data-devops-01` |
| `_URL_REPO` | URL tokenizada si el repo es externo (GitHub, etc.) — vacío si es Source Repository | — |
| `_SERVICE_ACCOUNT_ID` | SA por default si no se especifica en el YAML del componente | `dev-itc-operation-processing@dev-itc-customer-services.iam.gserviceaccount.com` |

#### Formato de `_DATAOPS_VARIABLES`

Son las variables de despliegue/reemplazo `${VARIABLE}` usadas en los YAMLs, en formato `clave=valor`
separadas por salto de línea:

```
bucket_modelo_recom=dev-bucket-modelo-recom-xdmg
dataset_farmas_recom_stage=dataset_farmas_recom_stage_dev
dataset_farmas_analytics_output=dataset_farmas_analytics_dev
inca_cloudsql_instance=dev-intercorp-data-operation:us-central1:dev-itcbi-lake-csql-usct1-fcys
```

> Estas son las mismas variables que aparecen como `${bucket_modelo_recom}`, `${dataset_farmas_recom_stage}`,
> etc. en los YAMLs de componentes. Se definen **una sola vez** en el trigger y el framework
> las reemplaza automáticamente en todos los archivos de configuración.

### Validación post-despliegue

Después de ejecutar el trigger:

1. Revisar los registros de Cloud Build para verificar errores.
2. En BigQuery: confirmar que las tablas DDL y SPs se crearon correctamente.
3. En Cloud Workflows: verificar que el workflow se creó con el nombre `${env}-[nombre]`.
4. En Vertex AI: verificar que el JSON del pipeline fue subido al bucket GCS.
5. En Cloud Run / Cloud Functions: confirmar que el servicio está activo.

> **Nota sobre workflows:** El framework despliega el workflow con el prefijo del ambiente.
> Si el archivo es `nombre.yaml`, el workflow se crea como `dev-nombre` (en dev) o `prd-nombre` (en prd).

---

## Referencias

- Manual del framework: `data/skills/build/dataops/dataops-configurator/references/Manual de Uso Framework de despliegue ITC Dataops.pdf`
- Scripts de deploy: `D:\workspace\itc\itcm-dp-dataops-build\build\bash\`
- Estándar SQL y BigQuery: `@.claude/data/standard/bigquery/development.md`
- Nomenclatura de tablas y columnas: `@.claude/data/standard/bigquery/nomenclatura-retail.md`
- Modelo canónico Vertex: `service/vertex/itc-recommendation-ml-model/`
