# Skill: MLOps Framework Developer

> **Rol:** Desarrollador de Modelos ML / Vertex AI — ITC Data Platform
> **Activado por:** adaptación de notebooks o scripts Python al framework de pipelines Vertex AI con KFP
>
> **Estándares de referencia:**
> - `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` — configuración YAML de despliegue
> - `@.claude/data/standard/bigquery/nomenclatura-retail.md` — nomenclatura BigQuery
> - `@.claude/data/standard/bigquery/development.md` — queries y stored procedures
>
> **Referencia documental:** `data/skills/build/coding/mlops-framework-developer/references/Framework Modelos ML v1.0.docx`
> **Modelo canónico de referencia:** `service/vertex/itc-recommendation-ml-model/`

---

## 1. Rol y Responsabilidades

El **MLOps Framework Developer** transforma código Python de ciencia de datos a pipelines productivos en Vertex AI con KFP. Cuando el usuario entregue código fuente de un modelo ML:

1. **Analiza** el código fuente para identificar sus etapas lógicas.
2. **Verifica** los requisitos de infraestructura GCP (APIs, IAM, bucket, BQ).
3. **Diseña** la arquitectura de componentes KFP (train / inference).
4. **Transforma** el código al framework: `src/components.py`, `src/pipeline_train.py`,
   `src/pipeline_inference.py`.
5. **Crea** los notebooks de compilación (`notebook/pipeline-train.ipynb`,
   `notebook/pipeline-inference.ipynb`).
6. **Genera** los archivos de configuración Dataops (`deploy_config_train.yaml`,
   `deploy_config_inference.yaml`).
7. **Documenta** con `README.md` siguiendo la estructura estándar.

---

## Estructura de Proyecto

Todo modelo ML vive en `service/vertex/[nombre-modelo]/`.

**Convención de nombre:** `itc-[dominio]-[funcion]-ml-model`
Ejemplos: `itc-recommendation-ml-model`, `itc-churn-prediction-ml-model`

```
service/vertex/[nombre-modelo]/
│
├── notebook/
│   ├── pipeline-train.ipynb        # Orquesta la compilación del pipeline de train
│   └── pipeline-inference.ipynb    # Orquesta la compilación del pipeline de inferencia
│
├── src/
│   ├── __init__.py                 # Archivo vacío — marca el directorio como paquete Python
│   ├── components.py               # Componentes KFP (@dsl.component) — lógica del modelo
│   ├── pipeline_train.py           # Define y compila el pipeline de entrenamiento
│   └── pipeline_inference.py       # Define y compila el pipeline de inferencia
│
├── deploy_config_train.yaml        # Config Dataops — train
├── deploy_config_inference.yaml    # Config Dataops — inference
├── requirements.txt                # Dependencias para desarrollo local ÚNICAMENTE
└── README.md                       # Definición funcional y técnica del modelo
```

---

## Sección 1: Infraestructura GCP Requerida

Antes de desplegar, verificar que el proyecto GCP tenga los siguientes recursos configurados.

### 1.1 APIs habilitadas

```
aiplatform.googleapis.com
storage-component.googleapis.com
artifactregistry.googleapis.com
ml.googleapis.com
bigquery.googleapis.com
bigquerystorage.googleapis.com
compute.googleapis.com
iamcredentials.googleapis.com
```

### 1.2 Variables de identificación del caso de uso

| Variable | Descripción | Ejemplo |
|---|---|---|
| `id` | Identificador único del caso de uso | `itc_modelo_recomendacion_als` |
| `project_id` | ID del proyecto GCP | `prd-itc-customer-services` |
| `env` | Ambiente (`dev` / `prd`) | `prd` |
| `company` | Nombre de la empresa | `intercorp` |
| `company_abbr` | Abreviatura | `itc`, `farmas`, `ibk`, `mif` |
| `module` | Módulo del caso de uso | `recomendacion`, `nbo`, `churn` |

**Labels GCP obligatorios:**

| Label | Descripción |
|---|---|
| `application` | Caso de uso |
| `module` | Módulo del caso de uso |
| `company` | Nombre de la compañía |
| `environment` | `dev` / `prd` |
| `owner` | Responsable del proceso |
| `chapter` | Área de la empresa |

### 1.3 Cloud Storage — Bucket del Pipeline

**Nomenclatura del bucket:**
```
gs://<env>_<company_abbr>_app_stg_mlops_<random[6]>
# Ejemplo:
gs://prd_itc_app_stg_mlops_vdsghr
```

**Estructura de carpetas (3 niveles):**
```
gs://bucket/
└── <company_abbr>-<id>/            # Nivel 1: Caso de uso
    └── <pipeline-key>/             # Nivel 2: Pipeline específico
        ├── pipeline_root/          # Nivel 3: Artefactos de ejecución (pasado al compilador)
        ├── compile/                # Nivel 3: JSONs compilados del pipeline
        └── [otras carpetas]/       # Nivel 3: Según necesidades del caso de uso (models/, outputs/)
```

En la práctica ITC con Dataops, las rutas se simplifican a:
```
gs://${bucket_nombre_modelo}/
├── itc-[nombre]-pipeline/          # JSONs compilados
├── artifacts/train/                # pipeline_root del pipeline de train
├── artifacts/inference/            # pipeline_root del pipeline de inference
└── models/{fecha_proceso}/{seg}/   # Artefactos del modelo (joblib)
```

### 1.4 IAM — Cuentas de Servicio

El framework define dos cuentas de servicio por modelo:

#### `service_account_process` — Ejecuta la lógica del pipeline
```
Nomenclatura: <env>-<company_abbr>-mlops-<module>-process@<project_id>.iam.gserviceaccount.com
Ejemplo:       prd-itc-mlops-nbo-process@prd-itc-customer-services.iam.gserviceaccount.com
```

Roles GCP requeridos:
- `roles/aiplatform.user`
- `roles/artifactregistry.reader`
- `roles/monitoring.viewer`
- `roles/monitoring.metricWriter`
- `roles/logging.logWriter`
- `roles/bigquery.jobUser`
- `roles/bigquery.readSessionUser`
- `roles/bigquery.resourceViewer`
- `roles/iam.serviceAccountOpenIdTokenCreator`

Roles en el bucket del pipeline:
- `roles/storage.objectCreator`
- `roles/storage.objectViewer`
- `roles/storage.legacyBucketWriter`

#### `service_account_execution` — Gatilla la ejecución del pipeline
```
Nomenclatura: <env>-<company_abbr>-mlops-<module>-execution@<project_id>.iam.gserviceaccount.com
```

Roles GCP: `roles/aiplatform.user`
Roles en bucket: `roles/storage.objectViewer`

> **Nota práctica:** En ITC el framework Dataops usa `${env}-farmas-cupones-job@...` como
> service account unificada. Consultar con el equipo de infraestructura si aplica la
> separación process/execution o un SA único.

#### Usuario supervisor (solo monitoreo)

```
roles/aiplatform.viewer
roles/logging.viewer
roles/bigquery.resourceViewer
```

### 1.5 BigQuery — Nomenclatura de Recursos del Modelo

| Recurso | Nomenclatura | Ejemplo |
|---|---|---|
| Dataset de procesamiento | `<prefix>_model_<user_area>_<model_name>` | `ba_model_farmas_recomendacion` |
| Dataset productivo | `<bi\|ba\|etc>_<concept>_<concept_name>` | `ba_analytics_output` |
| Stored Procedure | `sp_<company_abrev>_<group_action>_<action_name>` | `sp_itc_cupones_consolidar_trx` |
| Tabla temporal | `tmp_<content_name>` | `tmp_recomendaciones_als` |
| Tabla productiva | `<bi\|ba\|etc>_<concept>_<concept_name>` | `ba_monitoreo_modelo_recom_hist` |
| Tabla auxiliar | `aux_<content_name>` | `aux_jq1_excluidos_recom` |

> Ver estándar completo en `@.claude/data/standard/bigquery/nomenclatura-retail.md`

---

## Sección 2: Análisis del Código Fuente

Antes de transformar, identificar las etapas lógicas del código original.

### 2.1 Mapa de etapas → componentes KFP

| Etapa en código original | Componente KFP resultante |
|---|---|
| Consulta de datos de entrada desde BQ | `get_datos_from_bq()` o `get_grupos_from_bq()` |
| Preprocesamiento / feature engineering | `preprocess_datos()` |
| Entrenamiento del modelo | `train_[algoritmo]_[segmento]()` |
| Evaluación del modelo (métricas) | Dentro de `train_` o componente `evaluate_model()` |
| Persistencia del modelo (GCS) | Helper `upload_to_gcs()` dentro de `train_` |
| Carga del modelo desde GCS | Helper `download_from_gcs()` dentro de `inference_` |
| Generación de predicciones | `inference_[algoritmo]_[segmento]()` |
| Escritura de resultados en BQ | Al final de `train_` / `inference_` |
| Truncado de tabla destino | `truncate_bq_table()` — si aplica, al inicio del pipeline |
| Validación de tablas de entrada | `PIPELINE_VALIDATION_BIGQUERY_TABLES` — componente reutilizable |

### 2.2 Preguntas clave de diseño

- ¿El modelo se entrena por segmentos/grupos de forma paralela?
  → Usar `dsl.ParallelFor` + un componente por segmento
- ¿La inferencia carga modelos pre-entrenados desde GCS?
  → Necesita `train_process_date` como parámetro de runtime para localizar el artefacto
- ¿Hay tablas destino que deben truncarse antes de escribir?
  → Agregar componente `truncate_bq_table` al inicio del pipeline
- ¿La inferencia procesa volúmenes grandes (>100k registros)?
  → Considerar almacenamiento intermedio en GCS (parquet) y batch processing
- ¿El pipeline de inferencia es independiente del de entrenamiento?
  → Dos pipelines separados, dos YAMLs de despliegue independientes

### 2.3 Tipos de componentes disponibles

El framework soporta 3 tipos de componentes:

1. **Componentes pre-construidos por Google** — vía librerías Python (`google_cloud_pipeline_components`)
2. **Componentes pre-construidos por el usuario** — archivos JSON compilados y almacenados en GCS
   - `PIPELINE_COMPONENTS_BQ_VAL_PATH`: valida acceso, existencia de columnas y tipos de datos en tablas BQ
   - `PIPELINE_COMPONENTS_BQ_EXPORT_TABLE_TO_GCS`: exporta tablas BQ a Cloud Storage
3. **Componentes creados en el notebook** — funciones decoradas con `@dsl.component` en `src/components.py`

---

## Sección 3: Reglas de Transformación de Código

### 3.1 Patrón obligatorio — `@dsl.component`

```python
from kfp import dsl
from typing import List

@dsl.component(
    base_image="python:3.10",
    packages_to_install=[
        "google-cloud-bigquery==3.38.0",
        "google-cloud-bigquery-storage==2.34.0",
        "google-cloud-storage==2.19.0",
        "pandas==2.3.3",
        # ... todas las dependencias del componente con versión fijada
    ],
)
def nombre_componente(
    param1: str,
    param2: int,
    param3: float,
) -> str:
    """Docstring: qué hace, qué devuelve."""
    # TODOS los imports van DENTRO del cuerpo de la función
    import logging
    import pandas as pd
    from google.cloud import bigquery

    logging.basicConfig(level=logging.INFO)

    # ... lógica
    return resultado
```

**Reglas críticas:**

| Regla | Motivo |
|---|---|
| Todos los `import` van DENTRO de la función | Cada componente corre en contenedor aislado |
| `packages_to_install` debe ser exhaustivo con versiones fijadas | No hereda del entorno local |
| Tipos de parámetros deben ser primitivos (`str`, `int`, `float`, `bool`, `List[str]`) | KFP los serializa como JSON entre componentes |
| No pasar objetos Python complejos (DataFrames, modelos) entre componentes | Usar GCS o BigQuery como intermediario |
| Un componente = una responsabilidad clara | No mezclar entrenamiento con escritura de métricas |
| Inicializar logging al inicio de cada componente | Visibilidad en logs de Vertex AI |

### 3.2 Lineamientos de código (del framework)

**Environment Variables — siempre via `os.getenv`:**
```python
# Patrón correcto
TABLA_ENTRADA = os.getenv("TABLA_ENTRADA", "default-value")
N_ESTIMATORS  = int(os.getenv("N_ESTIMATORS", 100))
THRESHOLD     = float(os.getenv("THRESHOLD", 0.5))
```

**Logging obligatorio en cada componente:**
```python
import logging
logging.basicConfig(level=logging.INFO)
logging.info(f"[{grupo}] Iniciando proceso con {len(df)} filas")
logging.info(f"[{grupo}] Modelo entrenado. Métricas: HR@30={hr_k:.3f}")
```

**Directorios de artefactos locales (dentro del componente en `/tmp`):**
```
/tmp/model/      # Modelos analíticos (*.joblib, *.pkl, *.h5)
/tmp/inputs/     # Ficheros descargados de Cloud Storage
/tmp/outputs/    # Datos generados (parquets, CSV) antes de subir a BQ/GCS
```

**Función principal / reproducibilidad:**
```python
# En pipeline_train.py y pipeline_inference.py
if __name__ == "__main__":
    compiler.Compiler().compile(
        pipeline_func=train_pipeline,
        package_path=PIPELINE_COMPILE_FILE,
    )
    print(f"Pipeline compilado: {PIPELINE_COMPILE_FILE}")
```

### 3.3 Patrón de persistencia de artefactos

El modelo entrenado se guarda en GCS con path estructurado por fecha y segmento:

```
gs://{bucket}/models/{fecha_proceso}/{segmento}/[nombre]_model.joblib
```

El artefacto `joblib` debe incluir TODO lo necesario para inferencia (sin recalcular):

```python
artifact = {
    "model": model,
    "map_user": map_user,          # índice usuario → id interno
    "map_item": map_item,          # índice ítem → id interno
    "map_item_rev": map_item_rev,  # índice inverso
    "item_ids_excluir": [...],     # listas de exclusión precalculadas
    # cualquier otro mapping necesario
}
joblib.dump(artifact, "/tmp/model/als_model.joblib", compress=3)
```

Helpers estándar de GCS:
```python
def upload_to_gcs(local_file: str, gcs_path: str) -> None:
    bucket_name, blob_path = gcs_path.replace("gs://", "").split("/", 1)
    storage.Client().bucket(bucket_name).blob(blob_path).upload_from_filename(local_file)

def download_from_gcs(gcs_path: str, local_file: str) -> None:
    bucket_name, blob_path = gcs_path.replace("gs://", "").split("/", 1)
    storage.Client().bucket(bucket_name).blob(blob_path).download_to_filename(local_file)
```

### 3.4 Consultas BigQuery dentro de componentes

```python
# Siempre usar BigQueryStorage para mejor performance en grandes volúmenes
bq  = bigquery.Client(project=project_id)
bqs = bigquery_storage.BigQueryReadClient()

df = bq.query(f"""
    SELECT col1, col2
    FROM `{tabla}`
    WHERE filtro = '{valor}'
""").to_dataframe(bqstorage_client=bqs, create_bqstorage_client=False)
```

### 3.5 Escritura en BigQuery

```python
# WRITE_TRUNCATE — pipelines que reemplazan datos completamente
bq.load_table_from_dataframe(
    df_output, tabla_destino,
    job_config=bigquery.LoadJobConfig(write_disposition="WRITE_TRUNCATE"),
).result()

# WRITE_APPEND — tablas históricas y de monitoreo
bq.load_table_from_dataframe(
    df_monitoreo, tabla_monitoreo,
    job_config=bigquery.LoadJobConfig(write_disposition="WRITE_APPEND"),
).result()
```

### 3.6 Diccionarios de mapeo — respetar nombres y valores exactos

Cuando el notebook fuente define diccionarios para mapear o agrupar valores de variables (ej. nivel educativo, segmentos, categorías), se deben **preservar exactamente** tal como están definidos: mismo nombre del diccionario, mismas claves y mismos valores.

**❌ Nunca hacer:**
- Renombrar el diccionario (`nivel_map` → `educ_map`)
- Cambiar los valores de salida (`'Sin_educacion'` → `'Sin educacion'`)
- Reducir o reagrupar las claves (`'ANALFABETO/A'` absorbido en otro valor no definido)
- Crear un diccionario numérico en lugar del categórico original

**✅ Correcto — preservar tal cual:**
```python
# Respetar el nombre del diccionario y todos sus pares clave:valor
nivel_map = {
    'ANALFABETO/A': 'Sin_educacion',
    'PRIMARIA COMPLETA': 'Primaria',
    'SECUNDARIA COMPLETA': 'Secundaria_c',
    'SUPERIOR COMPLETA': 'Universitaria_c',
    # ... todos los valores originales sin excepción
}
df['nivel_educativo'] = df['nivel_educativo'].map(nivel_map).fillna('Sin categoria')
```

> Esta regla aplica a cualquier diccionario de transformación presente en el notebook fuente. Si el notebook define el mapeo, ese mapeo es la fuente de verdad — no se reinterpreta ni se simplifica.

### 3.7 Recursos de máquina por componente

```python
# En la definición del pipeline (no en el YAML)
train_task.set_cpu_limit("8").set_memory_limit("60G")   # Entrenamiento
infer_task.set_cpu_limit("4").set_memory_limit("32G")   # Inferencia
```

---

## Sección 4: Definición de Pipelines

### 4.1 Variables de entorno del framework (completas)

Estas son las variables estándar del framework que todo pipeline debe leer/exponer:

| Variable | Descripción | Origen |
|---|---|---|
| `PIPELINE_CONFIG_ID` | ID único del caso de uso | `config.yaml → config.id` |
| `PIPELINE_CONFIG_COMPANY` | Nombre del negocio | `config.yaml → config.company` |
| `PIPELINE_CONFIG_COMPANY_ABBR` | Abreviatura del negocio | `config.yaml → config.company_abbr` |
| `PIPELINE_DISPLAY_NAME` | Nombre único del pipeline en Vertex | `deploy_config_*.yaml → env_vars` |
| `PIPELINE_DESCRIPTION` | Descripción del pipeline | `deploy_config_*.yaml → env_vars` |
| `PIPELINE_KEY` | Identificador único del pipeline | (ej. `train`, `inference`) |
| `PIPELINE_COMPILE_FILE` | Ruta local del JSON compilado | `deploy_config_*.yaml → env_vars` |
| `PIPELINE_SERVICE_ACCOUNT` | SA de procesamiento (email) | `deploy_config_*.yaml → service_account` |
| `PIPELINE_PROJECT_ID` | ID del proyecto GCP | `deploy_config_*.yaml → project` |
| `PIPELINE_REGION` | Región de Vertex AI | `deploy_config_*.yaml → region` |
| `PIPELINE_BUCKET` | Nombre del bucket pipeline | `deploy_config_*.yaml → env_vars` |
| `PIPELINE_LABEL` | Labels GCP (JSON string) | `config.yaml → gcp_config.label` |
| `PIPELINE_PATH_ROOT` | Carpeta `pipeline_root` en bucket | `deploy_config_*.yaml → env_vars` |
| `PIPELINE_PATH_PROCESS` | Carpeta de datos procesados en bucket | (si aplica) |
| `PIPELINE_PATH_COMPILE` | Carpeta de JSONs compilados en bucket | (ej. `itc-[nombre]-pipeline`) |
| `PIPELINE_RECIPIENTS` | Lista de emails para notificaciones | `config.yaml → config.recipients` |
| `PIPELINE_VALIDATION_BIGQUERY_TABLES` | Validaciones de tablas BQ pre-ejecución | `config-pipeline-x.yaml → validations` |
| `PIPELINE_COMPONENTS_BQ_VAL_PATH` | Path GCS del componente validador BQ | Componente reutilizable del framework |
| `PIPELINE_COMPONENTS_BQ_EXPORT_TABLE_TO_GCS` | Path GCS del exportador BQ→GCS | Componente reutilizable del framework |

### 4.2 `src/pipeline_train.py` — Plantilla

```python
"""
Definición y compilación del pipeline de ENTRENAMIENTO.
Lee configuración desde variables de entorno — inyectadas por deploy_config_train.yaml.
"""
import os
import sys
from kfp import compiler, dsl

# Variables del framework
PIPELINE_DISPLAY_NAME    = os.getenv("PIPELINE_DISPLAY_NAME", "[nombre]-training")
PIPELINE_DESCRIPTION     = os.getenv("PIPELINE_DESCRIPTION", "Pipeline de entrenamiento [modelo]")
PIPELINE_COMPILE_FILE    = os.getenv("PIPELINE_COMPILE_FILE", "pipeline-train-pipeline-latest.json")
PIPELINE_PROJECT_ID      = os.getenv("PIPELINE_PROJECT_ID", "dev-itc-customer-services")
PIPELINE_REGION          = os.getenv("PIPELINE_REGION", "us-central1")
PIPELINE_SERVICE_ACCOUNT = os.getenv("PIPELINE_SERVICE_ACCOUNT", "")
PIPELINE_BUCKET          = os.getenv("PIPELINE_BUCKET", "")
PIPELINE_PATH_ROOT       = os.getenv("PIPELINE_PATH_ROOT", "artifacts/train")
PIPELINE_BUCKET_PROJECT_PATH = os.getenv("PIPELINE_BUCKET_PROJECT_PATH", f"gs://{PIPELINE_BUCKET}/")
PIPELINE_ROOT = f"{PIPELINE_BUCKET_PROJECT_PATH}{PIPELINE_PATH_ROOT}"

# Variables del modelo (hiperparámetros, tablas)
TABLA_ENTRADA   = os.getenv("TABLA_ENTRADA", "")
TABLA_SALIDA    = os.getenv("TABLA_SALIDA", "")
TABLA_MONITOREO = os.getenv("TABLA_MONITOREO", "")
# ... hiperparámetros
PARAM_1 = int(os.getenv("PARAM_1", 100))

print("=== TRAIN PIPELINE CONFIG ===")
print(f"PROJECT      : {PIPELINE_PROJECT_ID}")
print(f"PIPELINE ROOT: {PIPELINE_ROOT}")
print("==============================\n")

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.components import get_datos_from_bq, train_modelo

@dsl.pipeline(name=PIPELINE_DISPLAY_NAME, description=PIPELINE_DESCRIPTION,
              pipeline_root=PIPELINE_ROOT)
def train_pipeline(fecha_proceso: str, project_id: str = PIPELINE_PROJECT_ID,
                   region: str = PIPELINE_REGION):
    paso1 = get_datos_from_bq(...).set_display_name("GET DATA FROM BQ")
    paso2 = train_modelo(...).set_display_name("TRAIN MODEL")
    paso2.set_cpu_limit("8").set_memory_limit("60G")

if __name__ == "__main__":
    compiler.Compiler().compile(
        pipeline_func=train_pipeline,
        package_path=PIPELINE_COMPILE_FILE,
    )
    print(f"Pipeline compilado: {PIPELINE_COMPILE_FILE}")
```

**Parámetros de runtime obligatorios:**

| Parámetro | Tipo | Descripción |
|---|---|---|
| `fecha_proceso` | `str` | Fecha de ejecución `YYYY-MM-DD`. Partition key y path GCS. |
| `project_id` | `str` | Proyecto GCP (con default desde env var). |
| `region` | `str` | Región Vertex AI (default `us-central1`). |

### 4.3 `src/pipeline_inference.py` — Diferencias clave

- Usa componentes `inference_*` en vez de `train_*`
- Agrega parámetro `train_process_date: str` para localizar modelo en GCS
- `PIPELINE_PATH_ROOT = "artifacts/inference"`
- `PIPELINE_COMPILE_FILE = "pipeline-inference-pipeline-latest.json"`
- Recursos de máquina más bajos: `cpu=4`, `memory=32G`

### 4.4 Patrón de paralelización por segmento (`ParallelFor`)

```python
# Paso 1: Obtener lista de grupos/segmentos
grupos_task = get_grupos_from_bq(
    tabla=TABLA_ENTRADA,
    columna_grupo=COLUMNA_GRUPO,
    project_id=project_id,
).set_display_name("GET GROUPS FROM BQ")

# Paso 2: Procesar cada grupo en paralelo (Vertex escala automáticamente)
with dsl.ParallelFor(grupos_task.output) as grupo:
    task = train_modelo_grupo(
        grupo=grupo,
        # ... resto de params desde env vars
    ).set_display_name("TRAIN MODEL")
    task.set_cpu_limit("8").set_memory_limit("60G")
```

---

## Sección 5: Notebooks de Compilación

Los notebooks **no contienen lógica del modelo** — solo compilan y lanzan el pipeline.

### Estructura de celdas — `notebook/pipeline-train.ipynb`

**Celda 1 — Instalación de librerías del framework:**
```python
%pip install kfp==2.6.0 google-cloud-aiplatform google-cloud-storage
```

**Celda 2 — Variables del framework (para desarrollo local; en despliegue las inyecta Dataops):**
```python
import os
# Variables del framework
os.environ["PIPELINE_DISPLAY_NAME"]         = "itc-[nombre]-training"
os.environ["PIPELINE_DESCRIPTION"]          = "Pipeline de entrenamiento [descripcion]"
os.environ["PIPELINE_COMPILE_FILE"]         = "pipeline-train-pipeline-latest.json"
os.environ["PIPELINE_PROJECT_ID"]           = "dev-itc-customer-services"
os.environ["PIPELINE_REGION"]               = "us-central1"
os.environ["PIPELINE_SERVICE_ACCOUNT"]      = "dev-sa@dev-proj.iam.gserviceaccount.com"
os.environ["PIPELINE_BUCKET"]               = "dev-bucket-nombre-modelo"
os.environ["PIPELINE_BUCKET_PROJECT_PATH"]  = "gs://dev-bucket-nombre-modelo/"
os.environ["PIPELINE_PATH_ROOT"]            = "artifacts/train"
# Variables del modelo
os.environ["TABLA_ENTRADA"]  = "dev-itc-customer-services.dataset.tabla_entrada"
os.environ["TABLA_SALIDA"]   = "dev-itc-customer-services.dataset.tabla_salida"
os.environ["PARAM_1"]        = "100"
```

**Celda 3 — Compilación del pipeline:**
```python
%run ../src/pipeline_train.py
```

**Celda 4 — Subida del JSON compilado a GCS:**
```python
from google.cloud import storage
bucket_name = os.environ["PIPELINE_BUCKET"]
compile_file = os.environ["PIPELINE_COMPILE_FILE"]
storage.Client().bucket(bucket_name).blob(
    f"itc-[nombre]-pipeline/{compile_file}"
).upload_from_filename(compile_file)
print(f"Pipeline subido: gs://{bucket_name}/itc-[nombre]-pipeline/{compile_file}")
```

**Celda 5 — Ejecución manual en Vertex AI (comentar para despliegue con Dataops):**
```python
# NOTA: Comentar esta celda cuando se despliega con Dataops (run_after_deploy: false)
from google.cloud import aiplatform
aiplatform.init(project=os.environ["PIPELINE_PROJECT_ID"], location="us-central1")
job = aiplatform.PipelineJob(
    display_name=os.environ["PIPELINE_DISPLAY_NAME"],
    template_path=os.environ["PIPELINE_COMPILE_FILE"],
    parameter_values={"fecha_proceso": "2025-01-01"},
    pipeline_root=f"gs://{bucket_name}/artifacts/train",
)
job.submit(service_account=os.environ["PIPELINE_SERVICE_ACCOUNT"])
```

> El framework de Dataops convierte el notebook a script `.py` y lo ejecuta,
> inyectando las variables definidas en `env_vars` del YAML. La celda de ejecución
> manual (celda 5) debe estar comentada para despliegues automáticos.
> Si `run_after_deploy: true`, Dataops también ejecuta el pipeline al compilarlo.

---

## Sección 6: Archivos de Configuración Dataops

### `deploy_config_train.yaml`

```yaml
project: ${env}-itc-customer-services
region: us-central1
service_account: ${env}-[sa-name]@${env}-itc-customer-services.iam.gserviceaccount.com

pipeline_bucket_dataops: ${bucket_nombre_modelo}
pipeline_path_dataops: itc-[nombre]-pipeline

pipelines:
  - "./notebook/pipeline-train.ipynb"

run_after_deploy: false   # true solo en dev para pruebas; siempre false en prd

dataops_variable: VERTEX_PIPELINE_[NOMBRE]_URL   # nombre único en el repo

env_vars:
  # Variables del framework
  PIPELINE_BUCKET: ${bucket_nombre_modelo}
  PIPELINE_DISPLAY_NAME: "itc-[nombre]-training"
  PIPELINE_DESCRIPTION: "Pipeline de entrenamiento [descripcion]"
  PIPELINE_PATH_ROOT: "artifacts/train"
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_nombre_modelo}/"
  PIPELINE_SERVICE_ACCOUNT: "${env}-[sa]@${env}-itc-customer-services.iam.gserviceaccount.com"

  # Tablas BigQuery — TODAS usan 3 variables: project_ + dataset_ + table_
  # Tabla de entrada (input)
  TABLA_ENTRADA: "${project_[nombre_tabla_entrada]}.${dataset_[nombre_tabla_entrada]}.${table_[nombre_tabla_entrada]}"
  # Tabla stage/tmp de trabajo — también 3 variables (declaradas en env_[env].json)
  TABLA_SALIDA:    "${project_tmp_resultado}.${dataset_tmp_resultado}.${table_tmp_resultado}"
  # Tabla output/analytics de monitoreo — también 3 variables
  TABLA_MONITOREO: "${project_ba_monitoreo_nombre_hist}.${dataset_ba_monitoreo_nombre_hist}.${table_ba_monitoreo_nombre_hist}"

  # Hiperparámetros del modelo (versionados aquí, no en el código)
  PARAM_1: valor1
  PARAM_2: valor2
```

### `deploy_config_inference.yaml`

```yaml
project: ${env}-itc-customer-services
region: us-central1
service_account: ${env}-[sa-name]@${env}-itc-customer-services.iam.gserviceaccount.com

pipeline_bucket_dataops: ${bucket_nombre_modelo}
pipeline_path_dataops: itc-[nombre]-pipeline

pipelines:
  - "./notebook/pipeline-inference.ipynb"

run_after_deploy: false

dataops_variable: VERTEX_PIPELINE_[NOMBRE]_INFERENCE_URL

env_vars:
  PIPELINE_BUCKET: ${bucket_nombre_modelo}
  PIPELINE_DISPLAY_NAME: "itc-[nombre]-inference"
  PIPELINE_DESCRIPTION: "Pipeline de inferencia [descripcion]"
  PIPELINE_PATH_ROOT: "artifacts/inference"
  PIPELINE_BUCKET_PROJECT_PATH: "gs://${bucket_nombre_modelo}/"
  PATH_MODELS: "models"   # subfolder donde se guardan los modelos entrenados

  # Tablas de inferencia — también 3 variables por tabla
  TABLA_ENTRADA: "${project_[nombre_tabla_entrada]}.${dataset_[nombre_tabla_entrada]}.${table_[nombre_tabla_entrada]}"
  TABLA_SALIDA:  "${project_tmp_resultado_infe}.${dataset_tmp_resultado_infe}.${table_tmp_resultado_infe}"

  # Recursos de máquina (se leen en pipeline_inference.py y se aplican con set_*_limit)
  MACHINE_CPU_LIMIT: "4"
  MACHINE_MEMORY_LIMIT: "32G"
```

### Entrada en `deploy/deploy_[env].json`

```json
"vertex_pipeline": [
  "/service/vertex/itc-[nombre]-ml-model/deploy_config_train.yaml",
  "/service/vertex/itc-[nombre]-ml-model/deploy_config_inference.yaml"
]
```

---

## Sección 7: Dev → Producción (sin modificar código)

El framework gestiona los ambientes **únicamente via variables de reemplazo**. Nunca se
modifica código Python ni notebooks entre `dev` y `prd`.

| Variable | `dev` | `prd` |
|---|---|---|
| `${env}` | `dev` | `prd` |
| `${bucket_nombre_modelo}` | `dev-bucket-nombre-modelo` | `prd-bucket-nombre-modelo` |
| `${dataset_stage}` | `dataset_farmas_recom_stage_dev` | `dataset_farmas_recom_stage` |
| `${dataset_analytics}` | `dataset_farmas_analytics_dev` | `dataset_farmas_analytics_output` |

Los valores se definen en `build/config/[empresa]/replacement/env_[dev|prd].json`
del repositorio `itcm-dp-dataops-build`.

---

## Sección 8: Arquitectura de Orquestación

Vertex Pipeline **no se invoca directamente** desde Cloud Scheduler. La arquitectura es:

```
Cloud Scheduler
      │
      ▼
Cloud Workflow (orquestación)
      │
      ├─ [Stored Procedures BQ] — preparación de datos
      │
      ├─ Cloud Function / Cloud Run — gatilla el pipeline Vertex
      │         │
      │         └─ Vertex Pipeline Job
      │               ├─ Componente 1
      │               ├─ Componente 2 (paralelo)
      │               └─ Componente N
      │
      └─ [Post-procesamiento BQ / notificaciones]
```

**Reglas de orquestación (del framework):**
- La invocación a Vertex debe ser vía **Cloud Function** o **API de Cloud Run**
- La orquestación de pipelines Vertex + SPs BQ se hace con **Cloud Workflows**
- El scheduler invoca el Workflow, no directamente el pipeline
- Los scripts de ejecución devuelven `exit(0)` (SUCCESS) o `exit(1)` (FAILED)
  para que el orquestador capture el estado

> Ver configuración de Cloud Workflow y Cloud Scheduler en
> `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

---

## Sección 9: `requirements.txt` — Solo Desarrollo Local

```
google-cloud-aiplatform
google-cloud-storage
google-cloud-bigquery
google-cloud-bigquery-storage
kfp==2.6.0
# Librerías ML del modelo (ejemplo)
pandas
scikit-learn
joblib
implicit      # para ALS
scipy
```

> **Importante:** Las dependencias declaradas aquí NO se instalan en los contenedores
> de Vertex AI. Cada componente `@dsl.component` debe declarar sus propias dependencias
> en `packages_to_install`.

---

## Sección 10: `README.md` Estándar

```markdown
# [Nombre del Modelo] — [nombre-carpeta]
> Descripción breve: qué hace el modelo, para qué proceso de negocio.

## Responsabilidad
Qué predice/recomienda, con qué datos, para qué segmento.
Qué NO está en scope (fronteras del modelo).

## Estructura
Árbol de carpetas del modelo.

## Flujo del Modelo
Diagrama ASCII: entrada → componentes → salida.

## Dependencias
### Tablas BigQuery de entrada (con template ${env})
### Tablas BigQuery de salida
### GCS — paths de artefactos

## Variables de Entorno por Pipeline
Tabla separada por pipeline (train / inference).

## Hiperparámetros del Modelo
Tabla con nombre, valor actual y descripción.

## Métricas de Evaluación
Tabla con métrica, descripción y umbral/objetivo.

## Desarrollo Local
Instrucciones bash: venv, instalar deps, compilar pipeline.

## Despliegue con Dataops
Entradas en deploy_[env].json.

## Decisiones de Diseño
Por qué se eligió el algoritmo, la arquitectura, los patrones.

## Changelog
Tabla versión / cambio / fecha.

## Responsable
Equipo + fecha de última actualización.
```

---

## Checklist de Transformación

### Código fuente (`src/`)
- [ ] Todo `import` está DENTRO del cuerpo de cada `@dsl.component`
- [ ] `packages_to_install` lista TODAS las dependencias con versión fijada
- [ ] Ningún componente recibe DataFrames u objetos Python como parámetro
- [ ] Los artefactos (modelos, parquets) se pasan entre componentes vía GCS path (`str`)
- [ ] Las tablas BQ se reciben como parámetros `str`, no hardcodeadas
- [ ] Los hiperparámetros se leen con `os.getenv(..., default)` en `pipeline_*.py`
- [ ] Se inicializa `logging.basicConfig(level=logging.INFO)` en cada componente
- [ ] Los recursos (`set_cpu_limit`, `set_memory_limit`) están configurados
- [ ] El artefacto joblib incluye mappings y todo lo necesario para inferencia sin recalcular
- [ ] Se usan helpers `upload_to_gcs` / `download_from_gcs` consistentes
- [ ] Los diccionarios de mapeo del notebook fuente se preservan con el mismo nombre, claves y valores — sin renombrar ni simplificar

### Estructura de archivos
- [ ] `src/__init__.py` existe (aunque vacío)
- [ ] `src/components.py` contiene todos los `@dsl.component`
- [ ] `src/pipeline_train.py` lee vars de env y compila el pipeline de entrenamiento
- [ ] `src/pipeline_inference.py` lee vars de env y compila el pipeline de inferencia
- [ ] `notebook/pipeline-train.ipynb` estructura: instalación → env vars → compilación → upload → ejecución (comentada)
- [ ] `notebook/pipeline-inference.ipynb` igual que train
- [ ] `deploy_config_train.yaml` con todos los flags requeridos
- [ ] `deploy_config_inference.yaml` con todos los flags requeridos
- [ ] `requirements.txt` contiene solo dependencias de desarrollo local
- [ ] `README.md` sigue la estructura estándar completa

### Infraestructura GCP
- [ ] APIs habilitadas en el proyecto GCP
- [ ] `service_account_process` con roles correctos en GCP y bucket
- [ ] Bucket GCS con nomenclatura `gs://<env>_<company_abbr>_app_stg_mlops_<random[6]>`
- [ ] Estructura de carpetas en bucket (compile/, pipeline_root/, models/)
- [ ] Datasets BQ con nomenclatura correcta (`ba_model_*`, `ba_analytics_*`)
- [ ] Tablas creadas previamente con DDL (si aplica)

### Dataops
- [ ] Pipeline referenciado en `deploy/deploy_[env].json` bajo `vertex_pipeline`
- [ ] `dataops_variable` con nombre único en todo el repositorio
- [ ] Tablas BQ en `env_vars` usan `${env}` y variables de reemplazo
- [ ] Bucket GCS usa variable de reemplazo (ej. `${bucket_nombre_modelo}`)
- [ ] `run_after_deploy: false` en producción

---

## Ejemplo Canónico: `itc-recommendation-ml-model`

Este modelo implementa TODAS las convenciones del framework. Usarlo como referencia primaria.

### Identificadores del caso de uso

| Variable | Valor |
|---|---|
| `id` | `itc_modelo_recomendacion_als` |
| `company_abbr` | `itc` |
| `module` | `recomendacion` |
| `env` | `dev` / `prd` |

### Mapa de transformación aplicado

| Código original (notebook monolítico) | Componente KFP en framework |
|---|---|
| `df_grupos = bq.query("SELECT DISTINCT segmento_itc...")` | `get_grupos_from_bq()` → `List[str]` |
| `for grupo in grupos: train_als(grupo, df)` | `dsl.ParallelFor` + `train_als_grupo()` |
| `model = AlternatingLeastSquares(...); model.fit(...)` | Dentro de `train_als_grupo()` |
| `joblib.dump(artifact, path)` + GCS upload | Helper `upload_to_gcs()` dentro del componente |
| `model = joblib.load(path)` desde GCS | Dentro de `inference_als_grupo()` |
| `bq.load_table_from_dataframe(df_output, tabla)` | Al final de cada componente de train/inference |
| `df_monitoreo = pd.DataFrame([{métricas}])` | Al final de `train_als_grupo()` con `WRITE_APPEND` |

### Hiperparámetros como env vars

```python
# En src/pipeline_train.py — leer de env con default
FACTORS        = int(os.getenv("FACTORS", 304))
REGULARIZATION = float(os.getenv("REGULARIZATION", 0.061827298031334625))
ITERATIONS     = int(os.getenv("ITERATIONS", 46))
ALPHA          = float(os.getenv("ALPHA", 49.153))
```

```yaml
# En deploy_config_train.yaml — valores por ambiente
env_vars:
  FACTORS: 304
  REGULARIZATION: 0.061827298031334625
  ITERATIONS: 46
  ALPHA: 49.15300275537158
```

### Separación train / inference (patrón de versionado)

```
Train → guarda:     gs://bucket/models/{fecha_proceso}/{segmento}/als_model.joblib
Inference ← carga:  gs://bucket/models/{train_process_date}/{segmento}/als_model.joblib
```

El parámetro `train_process_date` permite cargar modelos de cualquier fecha de entrenamiento,
desacoplando inference de train.

### `packages_to_install` del modelo canónico

```python
packages_to_install=[
    "google-cloud-bigquery==3.38.0",
    "google-cloud-bigquery-storage==2.34.0",
    "google-cloud-storage==2.19.0",
    "db-dtypes==1.4.4",
    "pandas==2.3.3",
    "implicit==0.7.2",    # librería ALS
    "scipy==1.15.3",
    "joblib==1.5.2",
    "pyarrow==22.0.0",
]
```

---

## Errores Comunes al Transformar Código

| Error | Síntoma | Solución |
|---|---|---|
| Imports fuera del componente | `ModuleNotFoundError` en Vertex | Mover todos los `import` al interior de la función |
| Dependencia faltante en `packages_to_install` | `ImportError` en log del componente | Agregar el paquete con versión exacta |
| Pasar DataFrame entre componentes | Error de serialización KFP | Usar GCS (parquet/joblib) o BQ como intermediario |
| Hardcodear project_id / tabla | Falla en ambientes distintos | Recibir siempre como parámetro con default en env var |
| Recursos insuficientes | OOM kill en Vertex | Aumentar `set_memory_limit` en el componente |
| `WRITE_TRUNCATE` en tabla historial | Se pierden datos históricos | Usar `WRITE_APPEND` para tablas de monitoreo |
| `run_after_deploy: true` en producción | Pipeline se ejecuta en cada deploy | Mantener `false` en prd |
| `dataops_variable` duplicado | Conflicto en cadena de variables Dataops | Verificar que el nombre sea único en todo el repo |
| Sin logging en componentes | Sin visibilidad en Vertex AI console | Inicializar `logging.basicConfig(level=logging.INFO)` |
| Artefacto joblib incompleto | Error de `KeyError` en inferencia | Incluir mappings + listas + modelo en el mismo diccionario |
| Celda de ejecución no comentada en despliegue | Pipeline se ejecuta dos veces | Comentar celda 5 del notebook cuando `run_after_deploy: true` |
