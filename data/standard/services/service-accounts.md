# Estándar: Cuentas de Servicio GCP — ITC Data Platform

> **Última actualización:** 2026-03-05
> **Plataformas:** `dp` (Data Platform), `ai` (AI Hub)
>
> Las cuentas de servicio **no se crean con Dataops**. Son creadas una única vez por el framework
> de infraestructura (IaC) o por el Cloud Operator. Una vez creadas, se referencian en los YAMLs
> de despliegue mediante variables `_DATAOPS_VARIABLES`.

---

## Tipos de Cuentas de Servicio

El ecosistema ITC utiliza tres tipos de SA con propósitos claramente diferenciados:

| Tipo | Sufijo | Propósito |
|---|---|---|
| **App** | `-app` | Ejecuta servicios en tiempo de corrida (Cloud Run, Cloud Function, Workflow) |
| **Job** | `-job` | Ejecuta trabajos de procesamiento de datos (BigQuery, Vertex AI) |
| **Deployer** | `-deployer` | Despliega componentes vía Cloud Build (uso exclusivo de Dataops) |

---

## 1. SA de Servicios (`-app`)

Cuenta utilizada por servicios en ejecución: Cloud Run, Cloud Functions, Cloud Workflows y APIs.

### Nomenclatura

```
[env]-[abrev-empresa]-[caso-de-uso]-app@[proyecto].iam.gserviceaccount.com
```

| Segmento | Descripción |
|---|---|
| `[env]` | Ambiente: `dev`, `qa`, `prd` |
| `[abrev-empresa]` | Abreviatura de la empresa/unidad de negocio (ej. `farmas`, `itc`) |
| `[caso-de-uso]` | Nombre corto del proceso o producto (ej. `cupones`, `execution-engine`) |
| `[proyecto]` | Proyecto GCP donde opera el servicio |

### Ejemplos

```
dev-farmas-cupones-app@dev-itc-customer-services.iam.gserviceaccount.com
prd-itc-execution-engine-app@prd-itc-ai-hub-services.iam.gserviceaccount.com
```

### Roles mínimos requeridos

Asignados sobre el proyecto GCP donde opera el servicio:

| Rol IAM | Propósito |
|---|---|
| `roles/bigquery.dataEditor` | Leer y escribir datos en BigQuery |
| `roles/bigquery.jobUser` | Ejecutar jobs de BigQuery |
| `roles/run.invoker` | Invocar otros Cloud Run services |
| `roles/iam.serviceAccountTokenCreator` | Generar tokens para impersonación |
| `roles/iam.serviceAccountUser` | Actuar como otra cuenta de servicio |
| `roles/workflows.invoker` | Disparar Cloud Workflows |
| `roles/pubsub.publisher` o `roles/pubsub.subscriber` | Publicar o consumir mensajes Pub/Sub |

> Asignar solo los roles estrictamente necesarios para el servicio. No todos los servicios requieren todos los roles listados.

---

## 2. SA de Procesamiento de Datos (`-job`)

Cuenta utilizada por trabajos de procesamiento: pipelines de datos, Vertex AI pipelines, ejecución de SPs.

### Nomenclatura

```
[env]-[abrev-empresa]-[caso-de-uso]-job@[proyecto].iam.gserviceaccount.com
```

### Ejemplos

```
dev-farmas-cupones-job@dev-itc-customer-services.iam.gserviceaccount.com
prd-itc-recommendation-job@prd-itc-customer-services.iam.gserviceaccount.com
```

### Roles mínimos requeridos

| Rol IAM | Propósito |
|---|---|
| `roles/bigquery.connectionUser` | Usar conexiones de BigQuery (ej. BigQuery Omni) |
| `roles/bigquery.dataEditor` | Leer y escribir datos en BigQuery |
| `roles/bigquery.jobUser` | Ejecutar jobs de BigQuery |
| `roles/logging.logWriter` | Escribir logs en Cloud Logging |
| `roles/aiplatform.user` | Ejecutar y monitorear pipelines en Vertex AI |

---

## 3. SA de Despliegue Dataops (`-deployer`)

Cuenta utilizada exclusivamente por Cloud Build para desplegar componentes a través del framework Dataops. **No debe usarse para ejecución de servicios o trabajos.**

### Nomenclatura

```
[env]-[abrev-empresa]-dataops-deployer@[proyecto-dataops].iam.gserviceaccount.com
```

Donde `[proyecto-dataops]` es el proyecto GCP centralizado donde se alojan los triggers de Cloud Build.

### Ejemplo

```
prd-trv-itcbi-devops-app-itc-d@itc-data-devops-01.iam.gserviceaccount.com
```

### Roles mínimos requeridos

Asignados sobre el proyecto que se va a desplegar:

| Rol IAM | Propósito |
|---|---|
| `roles/artifactregistry.admin` | Crear y gestionar imágenes Docker en Artifact Registry |
| `roles/cloudbuild.builds.builder` | Ejecutar builds en Cloud Build |
| `roles/run.admin` | Desplegar y gestionar Cloud Run services |
| `roles/cloudscheduler.admin` | Crear y actualizar Cloud Scheduler jobs |
| `roles/logging.logWriter` | Escribir logs del proceso de despliegue |
| `roles/monitoring.editor` | Escribir métricas de monitoreo |
| `roles/iam.serviceAccountUser` | Actuar como la SA del servicio desplegado |
| `roles/storage.admin` | Subir artefactos al bucket de Cloud Build |
| `roles/viewer` | Leer configuración del proyecto |
| `roles/workflows.admin` | Crear y actualizar Cloud Workflows |

---

## Uso en el Framework Dataops

Las SAs se referencian en los YAMLs de despliegue mediante variables `_DATAOPS_VARIABLES` del trigger Cloud Build. **Nunca se hardcodean en los archivos del repositorio.**

### Definición en `_DATAOPS_VARIABLES`

```
service_account_app: dev-farmas-cupones-app@dev-itc-customer-services.iam.gserviceaccount.com
service_account_job: dev-farmas-cupones-job@dev-itc-customer-services.iam.gserviceaccount.com
```

### Uso en `deploy_config.yaml`

```yaml
# Cloud Run — usa SA de tipo app
service_account: ${service_account_app}

# Vertex AI Pipeline — usa SA de tipo job
service_account: ${service_account_job}
```

### Regla de asignación por componente

| Componente Dataops | Tipo de SA a usar |
|---|---|
| `cloud_run` | `-app` |
| `cloud_function` | `-app` |
| `workflow` | `-job` |
| `vertex_pipeline` | `-job` |
| `cloud_scheduler` | `-job` (la que invoca el target) |
| Cloud Build (deployer) | `-deployer` (gestionada por el framework) |

---

## Cuándo Crear una Nueva Cuenta de Servicio

- Al iniciar un **nuevo proyecto** que requiera ejecutar servicios o jobs en GCP
- Cuando un servicio existente requiera **permisos distintos** a los de la SA actual (no ampliar permisos — crear una SA específica)
- Las SAs se crean **una única vez** por ambiente (`dev` y `prd`) — no se recrean por cada despliegue

### Quién las crea

| Tipo | Responsable |
|---|---|
| `-app` y `-job` | Cloud Operator / equipo de infraestructura (IaC o manual) |
| `-deployer` | Equipo de DevOps (Dataops Build team) — gestión centralizada |

> Una vez creadas, el Data/ML Engineer solo necesita conocer el nombre de la SA para incluirlo en `_DATAOPS_VARIABLES`. No requiere acceso IAM para crearlas.

---

## Checklist de Validación

Antes de referenciar una SA en un YAML de despliegue:

- [ ] La SA existe en el proyecto GCP correspondiente (verificar con `gcloud iam service-accounts list`)
- [ ] El nombre sigue el patrón `[env]-[empresa]-[caso-de-uso]-[tipo]@[proyecto].iam.gserviceaccount.com`
- [ ] El tipo es correcto: `-app` para servicios, `-job` para procesamiento de datos
- [ ] Está definida en `_DATAOPS_VARIABLES` del trigger Cloud Build — no hardcodeada en el YAML
- [ ] Los roles IAM mínimos ya fueron asignados por el Cloud Operator
