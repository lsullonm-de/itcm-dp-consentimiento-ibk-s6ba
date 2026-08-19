# Estándar: Nomenclatura y Estructura de Repositorios Dataops ITC

> **Última actualización:** 2026-03-04
> **Plataformas:** `dp` (Data Platform), `ai` (AI Hub)

---

## 1. Nomenclatura de Repositorios

### Patrón

```
[abrev-empresa]-[plataforma]-[dominio]-[proceso de negocio/caso-de-uso]
```

| Segmento | Descripción | Ejemplos |
|---|---|---|
| `abrev-empresa` | Abreviatura de la empresa o unidad de negocio | `itcm` (Intercorp Management) |
| `plataforma` | Plataforma tecnológica del repositorio | `dp` (Data Platform), `ai` (AI Hub) |
| `dominio` | Dominio de negocio o área funcional | `customer`, `inca`, `aihub`, `arq`, `finops` |
| `proceso de negocio` | Nombre del proceso, caso de uso o producto técnico | `vuci`, `audience-campaign-loader-api`, `knowledge-base` |

### Ejemplos reales

| Repositorio | Desglose |
|---|---|
| `itcm-dp-customer-vuci` | itcm + dp + customer + vuci (Vista Única de Cliente) |
| `itcm-inca-audience-campaign-loader-api` | itcm + inca (dominio) + audience-campaign-loader-api |
| `itcm-aihub-process-execution-engine` | itcm + aihub (plataforma AI) + process-execution-engine |
| `itcm-dp-knowledge-base` | itcm + dp + knowledge-base |
| `itcm-dp-dlv-attributes` | itcm + dp + dlv (delivery) + attributes |
| `itcm-dp-dataops-build` | itcm + dp + dataops-build (framework) |

### Reglas

- Todo en **minúsculas**, separado por guiones `-`
- Ser específico en el proceso/caso de uso — evitar nombres genéricos
- El dominio debe reflejar la unidad de negocio o área funcional, no la tecnología

---

## 2. Estructura de Carpetas del Repositorio

### Principio de organización — Lineamiento 2026

Las carpetas de primer nivel (`data/bigquery/`, `data/lineage/`, `data/monitoring/`, `pipeline/workflow/`,
`pipeline/scheduler/`, `service/vertex/`, `service/cloud_run/`, `service/cloud_function/`,
`service/pubsub/`, `image/`) son **fijas** — representan el tipo de artefacto y no cambian.
Debajo de cada una, el framework anida dos niveles: el **dataset de la tabla final** (`{dataset_out}`)
y la **tabla de salida** (`{tabla_out}`):

```
{carpeta-tipo-fija}/{dataset_out}/{tabla_out}/[subtipo]/[archivo]
```

Ver la regla de nomenclatura por fuente/empresa dentro de cada `{tabla_out}` en la sección 3.

### Árbol completo

```
[repositorio]/
├── docs/                            ← Documentación del flujo de fábrica
│   ├── specs/                       ← Specs del proceso (spec-[empresa]-[yyyymmdd]-[nnn].yaml)
│   │       └── spec-itc-yyyymm.yaml     ← se genera al ejecutar /spec-create
│   ├── feature_spec/          ← specs markdown por output (siempre; creados por /spec-create)
│   │   └── {module/feature}/
│   │       └── spec.md        ← ya existe si se ejecutó /spec-create
│   ├── architecture/                ← Diagramas generados por fac-data-diagrams (etapa DOCUMENTATION)
│   │   ├── context-diagram.md
│   │   ├── data-flow-diagram.md
│   │   ├── component-diagram.md
│   │   ├── sequence-diagram.md
│   │   └── ...
│   └── TODO.md                      ← Estado de avance por etapa del flujo de fábrica
│
├── deploy/                          ← Manifiestos de despliegue por ambiente
│   ├── deploy_dev.json
│   ├── deploy_prd.json
│   ├── env_dev.json
│   ├── env_prd.json
│   ├── infra_dev.json
│   └── infra_prd.json
│
├── data/                            ← Scripts de definición y manipulación de datos
│   ├── bigquery/                    ← Scripts SQL para BigQuery
│   │   └── {dataset_out}/           ← dataset de la tabla final (ej. master_product)
│   │       └── {tabla_out}/         ← tabla final que se carga (ej. m_promotion)
│   │           ├── ddl/             ← DDL de la tabla final + staging por fuente
│   │           │   ├── tmp_{tabla_out}_{emp1}.sql
│   │           │   └── {tabla_out}.sql                          ← CREATE TABLE IF NOT EXISTS
│   │           ├── alter/           ← Scripts ALTER TABLE ADD COLUMN (migraciones; DROP COLUMN prohibido)
│   │           │   └── alter_{tabla_out}_YYYYMMDD_{NNN}.sql     ← un archivo por migración
│   │           ├── sp/              ← SP de carga por fuente/empresa + SP DQ (único)
│   │           │   ├── sp_{tabla_out}_{emp1}.sql
│   │           │   └── sp_dq_{tabla_out}.sql
│   │           ├── dml/             ← CALL de prueba por fuente (dev) + DML config DQ (únicos)
│   │           │   ├── call_sp_{tabla_out}_{emp1}.sql
│   │           │   ├── dml_dq_config_{tabla_out}.sql
│   │           │   └── dml_dq_monitor_config_{tabla_out}.sql
│   │           └── test/            ← Test unitario por SP/fuente
│   │               └── test_sp_{tabla_out}_{emp1}.sql
│   ├── lineage/                     ← Payloads JSON de registro de linaje
│   │   └── {dataset_out}/
│   │       └── {tabla_out}/
│   │           └── payloads/
│   │               ├── node_{tabla_out}.json           ← nodo de la tabla final (único)
│   │               ├── node_{tabla_out}_{emp1}.json     ← nodo de staging por fuente
│   │               └── edge_sp_{tabla_out}_{emp1}.json  ← arista por SP/fuente
│   ├── monitoring/                  ← Payloads JSON de registro de monitoreo
│   │   └── {dataset_out}/
│   │       └── {tabla_out}/
│   │           └── payloads/
│   │               ├── process_{tabla_out}_{emp1}.json  ← un proceso por fuente/workflow
│   │               └── task_sp_{tabla_out}_{emp1}.json  ← una tarea por SP/fuente
│   ├── postgresql/                  ← Scripts SQL para Cloud SQL (PostgreSQL)
│   │   └── ddl/                     ← CREATE TABLE, CREATE INDEX, ALTER TABLE
│   │       └── [categoria]/
│   └── cloud_storage/               ← Cloud Storage: definición de buckets
│       └── [nombre-bucket]/
│           └── bucket.yaml          ← Configuración del bucket + lista de archivos a subir
│
├── input/                           ← Archivos y scripts crudos referenciados en bucket.yaml (files.source)
│   └── [categoria]/                 ← Ej: Modelos/*.pkl, Scripts/*.txt
│       └── [archivos]
│
├── image/                           ← YAMLs de imágenes Docker (Artifact Registry)
│   └── {dataset_out}/
│       └── {tabla_out}/
│           └── {tabla_out_kebab}-{emp}.yaml   ← una imagen por fuente/servicio si aplica
│
├── service/                         ← YAMLs de servicios GCP
│   ├── cloud_run/
│   │   └── {dataset_out}/{tabla_out}/
│   │       └── [nombre-servicio]/
│   │           ├── deploy_config.yaml
│   │           ├── Dockerfile
│   │           └── ...
│   ├── cloud_function/
│   │   └── {dataset_out}/{tabla_out}/
│   │       └── [nombre-function]/
│   │           ├── deploy_config.yaml
│   │           ├── main.py
│   │           └── requirements.txt
│   ├── vertex/                      ← Pipelines de Vertex AI
│   │   └── {dataset_out}/{tabla_out}/
│   │       └── [nombre-pipeline]/
│   │           ├── deploy_config_train.yaml
│   │           ├── deploy_config_inference.yaml
│   │           ├── notebook/
│   │           │   ├── pipeline-train.ipynb
│   │           │   └── pipeline-inference.ipynb
│   │           ├── src/
│   │           │   ├── pipeline_train.py
│   │           │   └── pipeline_inference.py
│   │           └── requirements.txt
│   └── pubsub/                      ← YAMLs de tópicos Pub/Sub
│       └── {dataset_out}/{tabla_out}/
│           └── [topico].yaml
│
└── pipeline/
    ├── workflow/                    ← YAMLs de Cloud Workflows
    │   └── {dataset_out}/
    │       └── {tabla_out}/
    │           ├── wf-{tabla_out_kebab}-{emp1}.yaml   ← uno por fuente/empresa
    │           └── wf-{tabla_out_kebab}-{emp2}.yaml
    └── scheduler/                   ← YAMLs de Cloud Scheduler (triggers de workflows)
        └── {dataset_out}/
            └── {tabla_out}/
                ├── cs-{tabla_out_kebab}-{emp1}.yaml    ← uno por workflow
                └── cs-{tabla_out_kebab}-{emp2}.yaml
```

> **`{dataset_out}`** = dataset de la tabla final (ej. `master_product`). **`{tabla_out}`** = tabla de
> salida (ej. `m_promotion`). **`{tabla_out_kebab}`** = `{tabla_out}` con `_` reemplazado por `-`, usado
> solo en nombres de archivo/recurso GCP (`wf-`, `cs-`, imagen, cloud_run, cloud_function, vertex,
> pubsub) porque GCP no acepta `_` en esos nombres — BigQuery sí, por eso el SQL mantiene `_`.
> `data/postgresql/` y `data/cloud_storage/` no anidan por `{dataset_out}` — no son objetos de
> BigQuery y no tienen dataset asociado.
> Los payloads de `data/lineage/` y `data/monitoring/` se registran vía API por el framework Dataops
> compartido (`metadata_register.sh`, fuera de este repo) — no se generan scripts `.sh` locales.

---

## 3. Carpeta `data/bigquery/` — Scripts SQL

### Por qué `data/bigquery/` y no `source/`

La carpeta `source/` es ambigua: puede confundirse con código fuente Python u otras fuentes de datos. El nombre `data/bigquery/` describe con precisión el contenido: **scripts SQL para crear y mantener objetos de datos en BigQuery**.

Si el proyecto usa múltiples motores de datos, se pueden agregar carpetas hermanas:

```
data/
├── bigquery/     ← Scripts BigQuery
├── postgresql/   ← Scripts PostgreSQL
└── json/         ← Datos estáticos JSON
```

### Organización por dataset y tabla destino — Lineamiento 2026

**Cada SP debe trabajar para cargar UNA SOLA tabla final (target).**
La organización refleja esto: `data/bigquery/{dataset_out}/{tabla_out}/`, y dentro sus DDLs, SPs,
DMLs y tests asociados.

```
data/bigquery/
├── master_product/                         ← dataset de salida: master_product
│   └── m_promotion/                        ← tabla destino: m_promotion
│       ├── ddl/
│       │   ├── tmp_m_promotion_spsa.sql    ← tabla fuente/staging SPSA
│       │   ├── tmp_m_promotion_pmrt.sql    ← tabla fuente/staging Promart
│       │   ├── tmp_m_promotion_oec.sql     ← tabla fuente/staging Oeschle
│       │   └── m_promotion.sql             ← CREATE TABLE IF NOT EXISTS (tabla destino final)
│       ├── alter/                          ← ALTER TABLE ADD COLUMN (migraciones; DROP COLUMN prohibido)
│       │   └── alter_m_promotion_20260817_001.sql  ← un archivo por migración
│       ├── sp/
│       │   ├── sp_m_promotion_spsa.sql     ← SP que carga desde SPSA
│       │   ├── sp_m_promotion_pmrt.sql     ← SP que carga desde Promart
│       │   ├── sp_m_promotion_oec.sql      ← SP que carga desde Oeschle
│       │   └── sp_dq_m_promotion.sql       ← SP de DQ (único, valida el merge)
│       ├── dml/
│       │   ├── call_sp_m_promotion_spsa.sql    ← CALL de prueba (solo dev)
│       │   ├── dml_dq_config_m_promotion.sql   ← config de reglas DQ (única)
│       │   └── dml_dq_monitor_config_m_promotion.sql   ← config de monitores DQ (única)
│       └── test/
│           └── test_sp_m_promotion_spsa.sql
│
└── analytics/                              ← otro dataset de salida en el mismo repo
    ├── ba_customer_retail/                 ← tabla destino: ba_customer_retail
    │   ├── ddl/
    │   ├── alter/
    │   ├── sp/
    │   ├── dml/
    │   └── test/
    └── ba_itc_attr_retail/                 ← tabla destino: ba_itc_attr_retail
        ├── ddl/
        ├── sp/
        ├── dml/
        └── test/
```

### Subcarpetas por dataset/tabla

| Carpeta | Tipos de script | Convención de nombre de archivo |
|---|---|---|
| `{dataset_out}/{tabla_out}/ddl/` | `CREATE TABLE IF NOT EXISTS` de la tabla final (único) + tablas raw/staging fuente (una por empresa) | `{tabla_out}.sql`, `tmp_{tabla_out}_{emp}.sql` |
| `{dataset_out}/{tabla_out}/alter/` | `ALTER TABLE ADD COLUMN IF NOT EXISTS` — migraciones de esquema independientes (**`DROP COLUMN` prohibido**) | `alter_{tabla_out}_YYYYMMDD_{NNN}.sql` |
| `{dataset_out}/{tabla_out}/sp/` | SPs que cargan esa tabla (uno por fuente/empresa) + SP de DQ (único) | `sp_{tabla_out}_{emp}.sql`, `sp_dq_{tabla_out}.sql` |
| `{dataset_out}/{tabla_out}/dml/` | CALLs de prueba por fuente (solo dev) + DML de config DQ (únicos) | `call_sp_{tabla_out}_{emp}.sql`, `dml_dq_config_{tabla_out}.sql`, `dml_dq_monitor_config_{tabla_out}.sql` |
| `{dataset_out}/{tabla_out}/test/` | Test unitario por SP/fuente | `test_sp_{tabla_out}_{emp}.sql` |

### Regla de nomenclatura: prefijo `{tabla_out}`, sufijo `{emp}`

- **Un SP = una tabla destino final** (no puede cargar varias tablas en un mismo SP)
- **Si hay múltiples fuentes/empresas** para la misma tabla (ej: m_promotion centraliza SPSA, Promart, Oeschle) → **un SP, un Workflow y un Cloud Scheduler por fuente**, todos viviendo en la misma carpeta `{dataset_out}/{tabla_out}/...` — nunca en carpetas separadas por empresa
- El **prefijo siempre es la tabla de salida** (`{tabla_out}`) y el **sufijo siempre es la empresa/fuente** (`{emp}`, ej. `spsa`, `pmrt`, `oec`) — nunca al revés
- Los artefactos que operan sobre la **tabla final ya mergeada** (DDL final, SP de DQ, config DQ, config de monitores DQ, nodo de linaje final) son **únicos**, sin sufijo de empresa
- **Si hay múltiples tablas destino** en el mismo repo → una carpeta `{dataset_out}/{tabla_out}/` por cada tabla; si además pertenecen a datasets distintos, cada una cuelga de su propio `{dataset_out}/`

> Razón: facilita el control de ejecución, monitoreo y linaje. Cada SP/Workflow es una unidad atómica de carga por fuente.

---

## 4. Carpeta `data/postgresql/` — Scripts SQL para Cloud SQL

Aplica cuando la solución incluye un componente `cloud_run_api` que trabaja con **Cloud SQL (PostgreSQL)** para persistencia transaccional, en lugar de BigQuery.

### Subcarpetas

| Carpeta | Tipos de script | Convención de nombre de archivo |
|---|---|---|
| `ddl/` | `CREATE TABLE`, `CREATE INDEX`, `ALTER TABLE` | `[nombre_tabla].sql` |

> `sp/` y `dml/` no aplican para PostgreSQL en este contexto — la lógica de acceso a datos va en el código de la API (capa `datasource/`). Ver: `@.claude/data/standard/services/cloud-run.md`

### Cuándo usar `data/postgresql/` vs `data/bigquery/`

| Motor | Cuándo usarlo |
|---|---|
| `data/bigquery/` | Procesos batch, analytics, pipelines de datos, modelos ML |
| `data/postgresql/` | APIs REST transaccionales, lectura/escritura en tiempo real, estado mutable |

---

## 5. Carpeta `data/cloud_storage/` — Cloud Storage

### Propósito

Contiene los archivos `bucket.yaml` que definen los **buckets de Cloud Storage** que el proceso necesita: su configuración y los archivos estáticos a subir en el despliegue (modelos `.pkl`, configs, datos de referencia).

Vive dentro de `data/` porque es una fuente de datos/artefactos del proceso — análogo a `data/bigquery/` para BQ y `data/postgresql/` para Cloud SQL.

### Estructura

```
data/cloud_storage/
└── [nombre-bucket]/
    └── bucket.yaml      ← configuración del bucket + lista de archivos a subir

input/           ← archivos y scripts crudos referenciados en bucket.yaml (source)
└── [categoria]/
    └── [archivos]
```

**Naming del bucket:** seguir el patrón GCP: `[env]-[empresa]-[caso-de-uso]-[sufijo]`
El nombre va como variable `${bucket_[sufijo]}` — nunca hardcodeado.

### Estructura del `bucket.yaml`

```yaml
bucket:
  name:          ${bucket_mlops}           # variable Dataops — nunca hardcodeado
  description:   "Descripción funcional del bucket"
  project:       ${project_analytics}
  region:        ${pipeline_region}        # ej: us-central1
  storage_class: STANDARD                  # STANDARD | NEARLINE | COLDLINE | ARCHIVE

  files:                                   # (opcional) archivos a subir en el deploy
    - source:      input/[categoria]/[archivo]   # path relativo en el repo
      destination: ${gcs_path}/[archivo]                 # path destino en GCS (con variables)
```

**Notas del esquema:**
- Todo el contenido vive bajo la clave raíz `bucket:`
- `files` es opcional — omitir si el bucket no requiere contenido inicial
- `source` es relativo a la raíz del repositorio — los archivos crudos viven en `input/`
- `destination` acepta variables `${...}` que el framework resuelve antes de subir

### Ejemplo completo — bucket de artefactos MLOps

```yaml
bucket:
  name:          ${bucket_mlops}
  description:   "Bucket de artefactos MLOps — Modelo de Ingresos VII (modelos .pkl entrenados)"
  project:       ${project_analytics}
  region:        ${pipeline_region}
  storage_class: STANDARD

  files:
    - source:      input/modelo_ingreso/Modelos/ingreso_vii_rango1.pkl
      destination: ${gcs_models_path}/ingreso_vii_rango1.pkl

    - source:      input/modelo_ingreso/Modelos/ingreso_vii_rango2.pkl
      destination: ${gcs_models_path}/ingreso_vii_rango2.pkl

    - source:      input/modelo_ingreso/Modelos/ingreso_vii_rango3.pkl
      destination: ${gcs_models_path}/ingreso_vii_rango3.pkl

    - source:      input/modelo_ingreso/Modelos/ingreso_vii_rango4.pkl
      destination: ${gcs_models_path}/ingreso_vii_rango4.pkl

    - source:      input/modelo_ingreso/Modelos/modelo_ingreso_mul_clase3_upd.pkl
      destination: ${gcs_models_path}/modelo_ingreso_mul_clase3_upd.pkl

    - source:      input/modelo_ingreso/Modelos/modelo_ingreso_clase2.pkl
      destination: ${gcs_models_path}/modelo_ingreso_clase2.pkl
```

Y la estructura en el repo:

```
data/cloud_storage/
└── itc-ingreso-vii-pipeline/
    └── bucket.yaml

input/
└── modelo_ingreso/
    └── Modelos/
        ├── ingreso_vii_rango1.pkl
        ├── ingreso_vii_rango2.pkl
        ├── ingreso_vii_rango3.pkl
        ├── ingreso_vii_rango4.pkl
        ├── modelo_ingreso_mul_clase3_upd.pkl
        └── modelo_ingreso_clase2.pkl
```

### Variables de despliegue requeridas para Cloud Storage

| Variable | Descripción | Ejemplo |
|---|---|---|
| `bucket_[sufijo]` | Nombre del bucket por ambiente | `dev-itc-ingreso-vii-mlops` |
| `pipeline_region` | Región GCP del bucket | `us-central1` |
| `gcs_models_path` | Prefijo GCS para los artefactos | `gs://dev-itc-ingreso-vii-mlops/models/ingreso_vii/v1` |

### Cuándo usar `files`

| Caso | ¿Usar `files`? |
|---|---|
| Modelos `.pkl` / `.joblib` pre-entrenados que el pipeline lee en inferencia | ✅ Sí |
| Archivos de configuración estáticos (diccionarios, mappings JSON) | ✅ Sí |
| Datos de referencia pequeños que no cambian entre ejecuciones | ✅ Sí |
| Artefactos generados por el pipeline en runtime | ❌ No — el pipeline los genera |
| Datos de entrada grandes (tablas BigQuery) | ❌ No — van en BigQuery |

### Entrada en `deploy_[env].json`

```json
"bucket": [
  "/data/cloud_storage/itc-ingreso-vii-pipeline/bucket.yaml"
]
```

El framework crea el bucket y sube los archivos declarados en `files` en un solo paso. No se requieren entradas adicionales por cada archivo.

---

## 6. Carpeta `deploy/` — Manifiestos de Despliegue

Los archivos `deploy_[env].json` declaran qué artefactos se despliegan en cada ambiente y en qué orden. Ver el skill `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` para la estructura completa.

### Ejemplo con la nueva estructura

Caso `m_promotion` (dataset `master_product`) con dos fuentes/empresas (`spsa`, `pmrt`):

```json
{
  "bigquery_ddl": [
    "/data/bigquery/master_product/m_promotion/ddl/tmp_m_promotion_spsa.sql",
    "/data/bigquery/master_product/m_promotion/ddl/tmp_m_promotion_pmrt.sql",
    "/data/bigquery/master_product/m_promotion/ddl/m_promotion.sql"
  ],
  "bigquery_sp": [
    "/data/bigquery/master_product/m_promotion/sp/sp_m_promotion_spsa.sql",
    "/data/bigquery/master_product/m_promotion/sp/sp_m_promotion_pmrt.sql",
    "/data/bigquery/master_product/m_promotion/sp/sp_dq_m_promotion.sql"
  ],
  "bigquery_dml": [
    "/data/bigquery/master_product/m_promotion/dml/call_sp_m_promotion_spsa.sql",
    "/data/bigquery/master_product/m_promotion/dml/call_sp_m_promotion_pmrt.sql",
    "/data/bigquery/master_product/m_promotion/dml/dml_dq_config_m_promotion.sql",
    "/data/bigquery/master_product/m_promotion/dml/dml_dq_monitor_config_m_promotion.sql"
  ],
  "bucket":         ["/data/cloud_storage/nombre-bucket/bucket.yaml"],
  "image":          ["/image/master_product/m_promotion/m-promotion-spsa.yaml"],
  "cloud_run":      ["/service/cloud_run/master_product/m_promotion/m-promotion-spsa/deploy_config.yaml"],
  "vertex_pipeline":["/service/vertex/master_product/m_promotion/m-promotion-oec/deploy_config_train.yaml"],
  "cloud_function": ["/service/cloud_function/master_product/m_promotion/m-promotion-spsa/deploy_config.yaml"],
  "pubsub":         ["/service/pubsub/master_product/m_promotion/m-promotion-spsa.yaml"],
  "workflow":       [
    "/pipeline/workflow/master_product/m_promotion/wf-m-promotion-spsa.yaml",
    "/pipeline/workflow/master_product/m_promotion/wf-m-promotion-pmrt.yaml"
  ],
  "cloud_scheduler":[
    "/pipeline/scheduler/master_product/m_promotion/cs-m-promotion-spsa.yaml",
    "/pipeline/scheduler/master_product/m_promotion/cs-m-promotion-pmrt.yaml"
  ],
  "monitoring_register": ["/data/monitoring/master_product/m_promotion/payloads"],
  "lineage_register":    ["/data/lineage/master_product/m_promotion/payloads"]
}
```

> Cada entrada de `bigquery_sp`, `workflow` y `cloud_scheduler` corresponde a una fuente/empresa
> declarada en `fuentes[]` del spec — el framework no colapsa múltiples fuentes en un único archivo.

---

## 7. Repositorios de Referencia

| Repositorio | Patrón usado | Notas |
|---|---|---|
| `itcm-inca-audience-campaign-loader-api` | `source/fase1/`, `source/fase2/` | Patrón antiguo — migrar a `data/bigquery/{dataset_out}/{tabla_out}/` |
| `itcm-aihub-process-execution-engine` | `data/bigquery/ddl/`, `data/bigquery/sp/` | Patrón intermedio (2024) — sin `{dataset_out}/{tabla_out}` — migrar al Lineamiento 2026 |
| `itcm-dp-arquetipo-xops` | `source/business/[dominio]/[proceso]/` | Patrón antiguo — migrar a `data/bigquery/{dataset_out}/{tabla_out}/` |
| `itcm-dp-dlv-attributes` | `source/` | Patrón antiguo — migrar a `data/bigquery/{dataset_out}/{tabla_out}/` |
| `itcm-dp-demo-migration-matillion` | `data/bigquery/{dataset_out}/{tabla_out}/ddl\|sp\|dml\|test/` | Patrón nuevo correcto (Lineamiento 2026) — repo de referencia para este estándar |

> **Nota de migración:** Los repos que usan `source/` o el patrón plano de 2024 son correctos
> funcionalmente (el framework solo lee el path declarado en `deploy_[env].json`). Migrar al
> Lineamiento 2026 es una mejora de legibilidad y trazabilidad — basta con mover los archivos y
> actualizar los paths en los archivos `deploy_*.json`.


