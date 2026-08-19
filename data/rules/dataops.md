# Reglas Dataops — Variables de Despliegue, Deploy Configs, Estructura

> Aplica a: `deploy/*.json`, `service/*/deploy_config.yaml`, `pipeline/workflow/*.yaml`

---

## Variables de Despliegue

### ✅ Todo valor de entorno se parametriza con `${variable}`

Ningún archivo del repositorio debe contener valores concretos de proyectos, datasets, tablas, URLs o SAs. Toda referencia al entorno va como `${variable}` y es resuelta por el framework Dataops.

```yaml
# ✅ CORRECTO
service_account: ${service_account_job}
project_id: ${project_analytics}
dataset: ${dataset_analytics}

# ❌ INCORRECTO
service_account: prd-itc-ingreso-job@prd-itc-customer-services.iam.gserviceaccount.com
project_id: prd-itc-customer-services
dataset: analytics
```

### ✅ Variables de SA — `service_account_job` y `service_account_app` en `env_dev.json`

Las Service Accounts deben referenciarse como variables `${service_account_job}` / `${service_account_app}` en cualquier YAML de componente (`workflow`, `cloud_function`, `cloud_run`, `vertex_pipeline`). El valor **debe declararse en `env_dev.json` y `env_prd.json`** — no solo en el trigger Cloud Build.

```json
// ✅ CORRECTO — SA declarada en env_dev.json con email completo
{
  "service_account_job": "dev-itc-[caso-uso]-job@dev-itc-customer-services.iam.gserviceaccount.com",
  "service_account_app": "dev-itc-[caso-uso]-app@dev-itc-customer-services.iam.gserviceaccount.com"
}
```

```yaml
# ✅ CORRECTO en deploy_config.yaml — variable, no hardcodeada
service_account: ${service_account_app}

# ❌ INCORRECTO — inline aunque use variables parciales
service_account: ${env}-itc-[nombre]-app@${env}-${project_analytics}.iam.gserviceaccount.com
```

**Regla:** Si `deploy_config.yaml` usa `${service_account_app}` o `${service_account_job}`, esa variable **debe existir** en `env_dev.json` y `env_prd.json`. Sin ella el framework no puede resolver el valor al desplegar.

---

### ✅ Naming de variables de input — patrón `project_`/`dataset_`/`table_` + nombre tabla

```
# ✅ CORRECTO
project_ba_itc_attr_demographic
dataset_ba_itc_attr_demographic
table_ba_itc_attr_demographic

# ❌ INCORRECTO — nombre genérico, no identifica la tabla
project_input
dataset_fuente1
```

### ✅ Variables auto-inyectadas — NO incluir en `env_vars` de Vertex

Las siguientes variables son inyectadas automáticamente por el framework y **no deben declararse** en `env_vars` del `deploy_config.yaml` de Vertex:

```
PIPELINE_PROJECT_ID
PIPELINE_SERVICE_ACCOUNT
PIPELINE_REGION
PIPELINE_COMPILE_FILE
```

```yaml
# ❌ INCORRECTO — ya las inyecta el framework
env_vars:
  PIPELINE_PROJECT_ID: ${project_analytics}
  PIPELINE_SERVICE_ACCOUNT: ${service_account_job}
  PIPELINE_REGION: us-central1

# ✅ CORRECTO — solo las variables de negocio
env_vars:
  ENV: ${env}
  PIPELINE_DISPLAY_NAME: ingreso-vii-inference
  PROJECT_INPUT: ${project_ba_itc_attr_demographic}
  DATASET_INPUT: ${dataset_ba_itc_attr_demographic}
```

---

## Estructura del Deploy Config

### ✅ Campo `project` obligatorio en deploy_config.yaml de servicios — valor `${project_operation}`

Los `deploy_config.yaml` de componentes de tipo servicio deben declarar explícitamente el campo
`project`. El valor correcto es siempre la variable `${project_operation}` — nunca hardcodeado
ni construido con patrones `${env}-...`.

Aplica a: `cloud_function`, `cloud_run`, `workflow`, `vertex_pipeline`.

```yaml
# ✅ CORRECTO
project: ${project_operation}

# ❌ INCORRECTO — hardcodeado
project: dev-itc-customer-services

# ❌ INCORRECTO — construido con env (double-prefix: project_operation ya incluye el ambiente)
project: ${env}-itc-customer-services
project: ${env}-${project_operation}
```

> `project_operation` ya contiene el prefijo de ambiente en su valor en `env_dev.json`
> (ej. `"project_operation": "dev-itc-customer-services"`). No agregar `${env}-` delante.

---

### ✅ Cuatro bloques en `deploy_config.yaml` de Vertex

```yaml
env_vars:
  # Bloque 1 — Variables de framework
  ENV: ${env}
  PIPELINE_DISPLAY_NAME: nombre-pipeline
  PIPELINE_BUCKET: ${pipeline_bucket}

  # Bloque 2 — Tablas BigQuery input (PROJECT_*, DATASET_*, TABLE_*)
  PROJECT_BA_ATTR_DEMOGRAPHIC: ${project_ba_itc_attr_demographic}
  DATASET_BA_ATTR_DEMOGRAPHIC: ${dataset_ba_itc_attr_demographic}
  TABLE_BA_ATTR_DEMOGRAPHIC: ${table_ba_itc_attr_demographic}

  # Bloque 3 — Paths GCS
  MODEL_ARTIFACTS_PATH: ${pipeline_bucket}/models/ingreso_vii/v1/
  COMPILED_PIPELINE_PATH: ${pipeline_bucket}/compiled/ingreso_vii_inference.json

  # Bloque 4 — Hiperparámetros y recursos
  MACHINE_TYPE: n1-standard-4
  MAX_RETRIES: "3"
```

### ✅ Estructura del `deploy_[env].json` — paths relativos desde raíz del repo

```json
{
  "bigquery_ddl": [
    "/data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql"
  ],
  "bigquery_sp": [
    "/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql"
  ],
  "workflow": [
    "/pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml"
  ],
  "cloud_scheduler": [
    "/pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml"
  ]
}
```

**Regla:** Los paths son relativos a la raíz del repositorio y comienzan con `/`.

### ✅ Orden de ejecución en el deploy

El framework Dataops ejecuta los componentes en este orden fijo:

```
DDL → SP → Image → Cloud Run → Vertex Pipeline → Cloud Function → Pub/Sub → Workflow → Cloud Scheduler
```

Los componentes en `deploy_[env].json` deben respetar dependencias de datos (un SP que requiere que exista su DDL debe estar listado después del DDL en el mismo tipo de componente, no entre tipos distintos).

### ✅ Un `deploy_config.yaml` por componente — no compartir entre servicios distintos

```
# ✅ CORRECTO
service/cloud_run/{dataset_out}/{tabla_out}/api-ingresos/deploy_config.yaml
service/cloud_run/{dataset_out}/{tabla_out}/api-segmentos/deploy_config.yaml

# ❌ INCORRECTO — config compartida
service/cloud_run/deploy_config.yaml  ← no saber a qué servicio aplica
```

---

## Ambientes

### ✅ Un archivo de deploy por ambiente (`dev`, `qa`, `prd`)

```
deploy/
├── deploy_dev.json
├── deploy_qa.json
└── deploy_prd.json
```

**Regla:** Los archivos `deploy_qa.json` y `deploy_prd.json` deben existir aunque sean idénticos a `deploy_dev.json`. El framework los requiere.

### ✅ El ambiente `dev` puede incluir DML para pruebas — `prd` no

```json
// deploy_dev.json — puede tener DML
{
  "bigquery_dml": ["/data/bigquery/{dataset_out}/{tabla_out}/dml/call_sp_{tabla_out}_{emp}.sql"],
  "bigquery_sp": ["/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql"]
}

// deploy_prd.json — sin DML
{
  "bigquery_sp": ["/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql"]
}
```

---

## Scheduler

### ✅ Cloud Scheduler en `pipeline/scheduler/` — no en `service/`

```
# ✅ CORRECTO
pipeline/scheduler/{dataset_out}/{tabla_out}/cs-ingreso-vii-inference.yaml

# ❌ INCORRECTO — ubicación antigua
service/scheduler/cs-ingreso-vii-inference.yaml
```

> Esta regla ya marcaba `service/scheduler/` como incorrecto, pero
> `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` §11 decía lo contrario
> (corregido en esa misma migración — ver plan_cambios_v1_a_v2.txt).

### ✅ Naming del scheduler: `cs-{tabla_out_kebab}-{emp}.yaml`

```
pipeline/scheduler/{dataset_out}/{tabla_out}/cs-ingreso-vii-inference.yaml
pipeline/scheduler/{dataset_out}/{tabla_out}/cs-customer-attr-daily.yaml
```

---

## Checklist Dataops

- [ ] `deploy_config.yaml` de servicios (`cloud_function`, `cloud_run`, `workflow`, `vertex_pipeline`) incluye `project: ${project_operation}`
- [ ] No hay valores hardcodeados de proyectos, datasets, tablas, SAs, URLs
- [ ] `service_account_job` y/o `service_account_app` declaradas en `env_dev.json` y `env_prd.json` con email completo (si algún componente las usa como `${service_account_*}`)
- [ ] Variables de input siguen patrón `project_`/`dataset_`/`table_` + nombre tabla
- [ ] Variables auto-inyectadas de Vertex NO declaradas en `env_vars`
- [ ] `deploy_config.yaml` de Vertex tiene los 4 bloques bien separados
- [ ] `deploy_[env].json` usa paths relativos desde raíz con `/`
- [ ] Existe `deploy_dev.json`, `deploy_qa.json`, `deploy_prd.json`
- [ ] `prd` no tiene entradas en `bigquery_dml`
- [ ] Cloud Scheduler en `pipeline/scheduler/{dataset_out}/{tabla_out}/` (no en `service/`)
- [ ] Naming de scheduler: `cs-{tabla_out_kebab}-{emp}.yaml`
- [ ] Un `deploy_config.yaml` por componente — no compartido
