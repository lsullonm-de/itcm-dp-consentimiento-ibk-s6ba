# Estándar: Desarrollo de Servicios Cloud Run — ITC Data Platform

> **Última actualización:** 2026-03-05
> **Runtime:** Python 3.11+
> **Framework:** FastAPI + Uvicorn
>
> Todo servicio Cloud Run del ecosistema ITC debe seguir este estándar de estructura,
> configuración y despliegue.

---

## Principios Generales

- Todo servicio se construye con **FastAPI** sobre **Python 3.11 o superior**.
- Cada servicio tiene su propia **SA tipo `-app`** con permisos mínimos — ver `@.claude/data/standard/services/service-accounts.md`.
- Las credenciales de base de datos **nunca se hardcodean**: se leen desde **Secret Manager**. La URI del secreto llega como variable de entorno `SECRET_ID`.
- Si el servicio necesita invocar trabajos de datos (Workflows, Vertex AI, movimientos en GCS), debe **impersonar la SA `-job`** — no ampliar permisos de la SA `-app`.
- Los recursos de la app se inicializan en el arranque del proceso, no en cada request.

---

## Estructura de Carpetas

```
service/cloud_run/[nombre-servicio]/
│
├── Dockerfile
├── requirements.txt
├── deploy_config.yaml              ← configuración de despliegue Dataops
│
└── src/
    └── main/
        ├── main.py                 ← entry point FastAPI
        │
        ├── config/
        │   └── api_config.py       ← inicialización: env, Secret Manager, credenciales DB
        │
        ├── router/
        │   ├── service.py          ← router raíz: agrega todos los sub-routers bajo un prefix
        │   ├── [entidad_a].py      ← endpoints HTTP de la entidad A
        │   └── [entidad_b].py      ← endpoints HTTP de la entidad B
        │
        ├── function/
        │   ├── [entidad_a].py      ← lógica de negocio: orquesta acceso a datos
        │   └── [entidad_b].py
        │
        ├── model/
        │   ├── [entidad_a].py      ← schemas Pydantic (request/response)
        │   └── [entidad_b].py
        │
        └── utils/
            ├── log_event.py        ← utilidad de logging interno
            └── datasource/
                ├── __init__.py
                └── sql/
                    ├── __init__.py
                    ├── sql_postgresql.py        ← engine SQLAlchemy + get_db dependency
                    └── query_templates/         ← queries SQL como funciones Python
                        └── [nombre_query].py
```

### Regla de capas

```
router/ → function/ → utils/datasource/
```

| Capa | Responsabilidad |
|---|---|
| `router/` | Recibir requests HTTP, validar payload (Pydantic), delegar a `function/`, retornar respuesta |
| `function/` | Lógica de negocio: orquestar consultas, transformaciones, llamadas a servicios GCP |
| `model/` | Schemas Pydantic para request/response — sin lógica |
| `utils/datasource/` | Conexiones a fuentes de datos: PostgreSQL, BigQuery, Firebase, etc. |
| `config/api_config.py` | Inicialización única al arranque: leer Secret Manager, configurar variables de entorno internas |

**Regla:** los routers no acceden directamente a la base de datos. Las funciones no conocen nada de HTTP. Las utils de datasource no contienen lógica de negocio.

---

## 1. Entry Point — `main.py`

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from router import service

app = FastAPI(title="[nombre-servicio]", version="1.0.0")

# CORS: restringir origins en producción
_ALLOWED_ORIGINS = ["*"]  # reemplazar por lista explícita en prd si aplica

app.add_middleware(
    CORSMiddleware,
    allow_origins=_ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(service.router)


@app.get("/health")
def health():
    return {"status": "ok"}


# Solo para ejecución local
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("src.main.main:app", host="127.0.0.1", port=8000, reload=True)
```

> **`/health`** es obligatorio. Cloud Run lo usa para health checks y el equipo de operaciones para monitoreo.

---

## 2. Configuración Inicial — `config/api_config.py`

Se ejecuta una sola vez al importar el módulo. Detecta el ambiente (`CURR_ENVI`) y lee el secreto de PostgreSQL desde Secret Manager.

```python
import os, json
import google.auth, requests
from google.cloud import secretmanager
from dotenv import load_dotenv

# Carga .env solo para desarrollo local
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../../../../.env"))

_curr_envi = os.getenv("CURR_ENVI")   # ← env var obligatoria en deploy_config.yaml
_secret_id = os.getenv("SECRET_ID")   # ← URI completa del secreto, ej: projects/xxx/secrets/yyy/versions/latest

if not _curr_envi:
    raise RuntimeError("CURR_ENVI no está configurado")
if not _secret_id:
    raise RuntimeError("SECRET_ID no está configurado")

# Obtener SA activa del servicio (solo en GCP; en local usa ADC)
if _curr_envi in ("dev", "qa", "prd"):
    _meta_url = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
    os.environ["API_USER"] = requests.get(_meta_url, headers={"Metadata-Flavor": "Google"}).text
else:
    creds, _ = google.auth.default()
    os.environ["API_USER"] = getattr(creds, "service_account_email", "local")

# Leer secreto de PostgreSQL y exponer como variables de entorno internas
with secretmanager.SecretManagerServiceClient() as client:
    payload = client.access_secret_version(name=_secret_id).payload.data.decode("UTF-8")
    params = json.loads(payload)
    os.environ["DB_USER"] = params["db_user"]
    os.environ["DB_PASS"] = params["db_pass"]
    os.environ["DB_IPAD"] = params["db_ipad"]
    os.environ["DB_NAME"] = params["db_name"]
    os.environ["DB_PRID"] = params["db_project_id"]
    os.environ["DB_REGI"] = params["db_region"]
    os.environ["DB_INST"] = params["db_instance_name"]
    os.environ["DB_PORT"] = params["db_port"]

APP_DEBUG = os.getenv("APP_DEBUG", "false").lower() == "true"
```

> El secreto debe contener exactamente las claves: `db_user`, `db_pass`, `db_ipad`, `db_name`, `db_project_id`, `db_region`, `db_instance_name`, `db_port`.

---

## 3. Router Raíz — `router/service.py`

Agrega todos los sub-routers bajo un prefix de dominio.

```python
from fastapi import APIRouter
from .entidad_a import router as entidad_a_router
from .entidad_b import router as entidad_b_router

router = APIRouter(prefix="/[nombre-dominio]")

router.include_router(entidad_a_router)
router.include_router(entidad_b_router)
```

Las rutas finales quedan como: `GET /[nombre-dominio]/[entidad]/[accion]`.

---

## 4. Routers por Entidad — `router/[entidad].py`

Cada router maneja los endpoints de una entidad. Responsabilidades:
- Validar campos obligatorios del payload (devolver `400` con detalle).
- Validar reglas de negocio simples (rangos, coherencia de fechas).
- Delegar a `function/` para la lógica.
- Capturar excepciones y devolver `HTTPException` con código apropiado.

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from utils.datasource.sql.sql_postgresql import get_db
from model.entidad import EntidadCreate, EntidadResponse
from function.entidad import crear_entidad

router = APIRouter(prefix="/entidad", tags=["Entidad"])


@router.post("/", response_model=EntidadResponse, status_code=201)
def crear(payload: EntidadCreate, db: Session = Depends(get_db)):
    # Validación de campos obligatorios
    missing = [f for f in ["campo_a", "campo_b"] if not getattr(payload, f, None)]
    if missing:
        raise HTTPException(status_code=400, detail=f"Campos obligatorios faltantes: {', '.join(missing)}")

    try:
        return crear_entidad(db=db, payload=payload)
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{entidad_id}", response_model=EntidadResponse)
def obtener(entidad_id: str, db: Session = Depends(get_db)):
    result = obtener_entidad(db=db, entidad_id=entidad_id)
    if not result:
        raise HTTPException(status_code=404, detail="No encontrado")
    return result
```

---

## 5. Funciones de Negocio — `function/[entidad].py`

Contienen la lógica de negocio. No conocen nada de HTTP (`Request`, `Response`, `HTTPException` solo se re-lanza si viene de una capa inferior). Reciben objetos de sesión de DB como parámetros.

```python
from sqlalchemy.orm import Session
from sqlalchemy import text
from datetime import datetime, timezone
import os

SCHEMA = os.getenv("SCHEMA_PG", "nombre_schema")


def crear_entidad(db: Session, payload) -> dict:
    q = text(f"""
        INSERT INTO {SCHEMA}.entidad (campo_a, campo_b, load_date)
        VALUES (:campo_a, :campo_b, :load_date)
        RETURNING entidad_id
    """)
    result = db.execute(q, {
        "campo_a": payload.campo_a,
        "campo_b": payload.campo_b,
        "load_date": datetime.now(timezone.utc),
    })
    entidad_id = result.scalar()
    db.commit()
    return {"entidad_id": entidad_id}
```

### Impersonación de SA `-job` para invocar Workflows

Si el servicio necesita disparar un Workflow u otro trabajo de datos, usa ADC para obtener un token de la SA `-app` y luego impersona la SA `-job`:

```python
import google.auth
from google.auth.transport.requests import Request as GARequest


def _bearer_token() -> str:
    creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
    if not creds.valid:
        creds.refresh(GARequest())
    return creds.token


def invocar_workflow(workflow_url: str, body: dict) -> dict:
    import requests
    token = _bearer_token()
    response = requests.post(
        workflow_url,
        json=body,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    response.raise_for_status()
    return response.json()
```

> La SA `-app` debe tener `roles/workflows.invoker` para poder disparar el workflow. La SA `-job` es la que ejecuta el workflow internamente.

---

## 6. Modelos Pydantic — `model/[entidad].py`

Solo definen el schema de datos. Sin lógica de negocio.

```python
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import date, datetime


class EntidadCreate(BaseModel):
    campo_a: str = Field(..., example="valor_a")
    campo_b: Optional[str] = Field(None, example="valor_b")
    fecha: Optional[date] = Field(None, example="2025-11-01")
    parametros: Optional[Dict[str, Any]] = Field(default_factory=dict)


class EntidadResponse(BaseModel):
    entidad_id: str
    campo_a: str
    campo_b: Optional[str] = None
```

---

## 7. Conexión PostgreSQL — `utils/datasource/sql/sql_postgresql.py`

Usa Cloud SQL Auth Proxy (socket Unix) en GCP y TCP directo en local. El `APP_DEBUG` flag controla el modo.

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from singleton_decorator import singleton
from config.api_config import APP_DEBUG
import os

db_user = os.environ["DB_USER"]
db_pass = os.environ["DB_PASS"]
db_name = os.environ["DB_NAME"]
db_port = os.environ.get("DB_PORT", "5432")
db_ipad = os.environ.get("DB_IPAD", "localhost")
db_prid = os.environ["DB_PRID"]
db_regi = os.environ["DB_REGI"]
db_inst = os.environ["DB_INST"]

if not APP_DEBUG:
    # GCP: conexión via Cloud SQL Auth Proxy (socket Unix)
    host_param = f"?host=/cloudsql/{db_prid}:{db_regi}:{db_inst}"
    db_url = f"postgresql://{db_user}:{db_pass}@/{db_name}{host_param}"
else:
    # Local: TCP directo
    db_url = f"postgresql://{db_user}:{db_pass}@{db_ipad}:{db_port}/{db_name}"

engine = create_engine(db_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@singleton
class DBAdmin:
    def __init__(self):
        self.db = SessionLocal()


def get_db():
    db = DBAdmin()
    try:
        yield db.db
    finally:
        db.db.close()
```

> El patrón `@singleton` de `DBAdmin` reutiliza la misma sesión para el ciclo de vida del contenedor — apropiado para servicios de baja concurrencia (`concurrency: 1`). Para servicios con alta concurrencia, usar `get_db2()` que crea una sesión por request.

---

## 8. Acceso a BigQuery

No requiere configuración adicional: `bigquery.Client()` usa las credenciales de la SA `-app` via ADC. El proyecto de billing se configura como variable de entorno.

```python
from google.cloud import bigquery
import os

BQ_PROJECT_ID = os.getenv("BQ_PROJECT_ID")
BQ_DATASET    = os.getenv("BQ_DATASET")


def query_bigquery(sql: str) -> list:
    client = bigquery.Client(project=BQ_PROJECT_ID)
    rows = client.query(sql).result()
    return [dict(r) for r in rows]
```

> `BQ_PROJECT_ID` y `BQ_DATASET` deben declararse en `env_vars` del `deploy_config.yaml` usando variables de `_DATAOPS_VARIABLES`.

---

## 9. Dockerfile

### Patrón estándar — `src/main` como raíz Python

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/main /app

EXPOSE 8080
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

Con `COPY src/main /app`, el directorio `/app` **es** `src/main`. Python resuelve los imports desde `/app`, por eso los módulos se importan directamente sin prefijos:

```python
# ✅ Imports correctos con COPY src/main /app
from router import process_router
from function import execution_function
from model import process_model
from config import settings
```

> **Regla:** Si el código usa `from src.main.X import Y` en todos sus archivos, entonces el WORKDIR de Python es la raíz del servicio (no `src/main`). En ese caso usar `COPY src ./src` y `CMD ["uvicorn", "src.main.main:app", ...]`. Ambos patrones funcionan, pero **no mezclarlos** dentro del mismo repo.

```dockerfile
# Patrón alternativo (cuando imports usan ruta completa src.main.X)
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src ./src
EXPOSE 8080
CMD ["uvicorn", "src.main.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**El patrón canónico recomendado es el primero** (`COPY src/main /app`) porque los imports son más cortos y el CMD es más simple. Al iniciar un nuevo servicio, usar siempre este patrón.

### Explicación de cada instrucción

| Instrucción | Por qué |
|---|---|
| `FROM python:3.11-slim` | Imagen base liviana (~130MB vs ~900MB de la full). Python 3.11 es la versión estándar ITC. |
| `WORKDIR /app` | Directorio de trabajo único y simple. No usar variables de entorno (`$APP_HOME`) ni múltiples WORKDIRs. |
| `COPY requirements.txt .` | Se copia **antes** que el código para aprovechar el caché de capas Docker: si el código cambia pero no las dependencias, `pip install` no se re-ejecuta. |
| `RUN pip install --no-cache-dir -r requirements.txt` | `--no-cache-dir` reduce el tamaño de la imagen al no guardar el caché de pip dentro del contenedor. |
| `COPY src/main /app` | Solo se copia el subdirectorio de la aplicación, **no el repo completo**. El `main.py` queda en `/app/main.py`. |
| `EXPOSE 8080` | Documentación del puerto; Cloud Run siempre enruta al 8080. |
| `CMD ["uvicorn", "main:app", ...]` | Uvicorn en formato array (exec form) — el proceso arranca directamente sin shell intermedio. |

### ⚠️ Anti-patrones comunes

```dockerfile
# ❌ INCORRECTO — copia el repo entero (tests, .git, docs, .env, notebooks)
COPY . ./

# ❌ INCORRECTO — doble WORKDIR con variable de entorno
ENV APP_HOME=/usr/app
WORKDIR $APP_HOME
COPY ./requirements.txt ./requirements.txt
WORKDIR $APP_HOME/src/main        ← confuso y no estándar

# ❌ INCORRECTO — gunicorn como wrapper de uvicorn (innecesario para Cloud Run)
CMD exec gunicorn main:app \
    --workers 1 \
    --worker-class uvicorn.workers.UvicornWorker \
    --bind :${PORT:-8080}

# ❌ INCORRECTO — python:3.12-slim (versión no estándar ITC)
FROM python:3.12-slim

# ❌ INCORRECTO — pip install antes de COPY requirements.txt
# (invalida el caché en cada build aunque las dependencias no cambien)
COPY src/main /app
RUN pip install --no-cache-dir -r requirements.txt
```

**Por qué uvicorn directo y no gunicorn:**
Cloud Run gestiona el escalado horizontalmente (instancias), no verticalmente (workers por instancia).
Con `concurrency: 1` (stateful) o `concurrency: N` (APIs livianas), un único proceso uvicorn es
suficiente. Gunicorn agrega complejidad sin beneficio en este entorno.

### .dockerignore recomendado

Crear `service/cloud_run/[nombre-servicio]/.dockerignore`:

```
.env
*.pyc
__pycache__/
.git/
*.md
tests/
*.ipynb
.pytest_cache/
dist/
build/
```

> `.dockerignore` aplica al contexto de build — impide que archivos sensibles o innecesarios
> entren al contenedor, incluso si `COPY . ./` se usara accidentalmente.

---

## 10. `requirements.txt`

Fijar versiones exactas para builds reproducibles. Dependencias mínimas para un servicio con PostgreSQL, BigQuery y Secret Manager:

```
fastapi==0.117.1
uvicorn==0.23.2
pydantic[email]>=2.0.0
python-dotenv>=1.0.0
SQLAlchemy==2.0.40
psycopg2-binary==2.9.10
singleton-decorator==1.0.0
google-auth==2.22.0
google-cloud-secret-manager==2.16.3
google-cloud-bigquery==3.38.0
google-cloud-bigquery-storage>=2.0.0
requests==2.31.0
```

Agregar según necesidad del servicio:
```
google-cloud-workflows==1.11.0    # si invoca Workflows
google-cloud-pubsub               # si publica/consume Pub/Sub
google-cloud-storage==2.10.0      # si accede a GCS
google-cloud-aiplatform==1.95.1   # si invoca Vertex AI
pandas==2.0.3                     # si procesa DataFrames
```

---

## 11. `deploy_config.yaml`

El script `cloud_run.sh` lee este archivo y construye el comando `gcloud run deploy`. Todos los valores con `${variable}` se resuelven desde `_DATAOPS_VARIABLES` del trigger Cloud Build.

### Flags completos

| Flag | Requerido | Default | Descripción |
|---|---|---|---|
| `name` | No | nombre del directorio | Nombre del servicio en Cloud Run. El script agrega `${env}-` si no lo tiene. |
| `dataops_variable` | No | — | Nombre de la variable que recibirá la URL del servicio (exportada a `dataops_variable_value.txt` para steps posteriores). |
| `region` | No | `us-central1` | Región GCP de despliegue. |
| `image` | **Sí** | — | URL completa de la imagen en Artifact Registry: `[region]-docker.pkg.dev/[proyecto]/dataops-artifacts/[env]-[nombre]:latest` |
| `project` | No | `$PROJECT_ID` (Cloud Build) | Proyecto GCP donde se despliega el servicio. |
| `service_account` | No | `$SERVICE_ACCOUNT_ID` | SA del servicio. Usar SA tipo **`-app`** — ver `@.claude/data/standard/services/service-accounts.md`. |
| `allow_unauthenticated` | No | `false` | Si `true`: acceso público sin autenticación. Si `false`: requiere token Bearer. |
| `memory` | No | `2Gi` | Memoria RAM. Opciones: `512Mi`, `1Gi`, `2Gi`, `4Gi`, `8Gi`, `16Gi`, `32Gi`. Para 8Gi+ se requieren 4+ CPUs. |
| `cpu` | No | `1` | CPUs. Opciones: `1`, `2`, `4`, `6`, `8`. Regla: 1 CPU/2Gi mínimo; 4 CPUs para 16Gi. |
| `concurrency` | No | `1` | Requests simultáneos por instancia (1–1000). Usar `1` para procesamiento stateful; mayor valor para APIs livianas. |
| `timeout` | No | `1800` | Timeout en segundos. Máximo `3600` (1 hora). |
| `max_instances` | No | Sin límite | Máximo de instancias para escalar. Omitir si no se necesita límite. |
| `add_cloudsql_instances` | No | — | Lista de instancias Cloud SQL en formato `proyecto:región:instancia`. Necesario para conexión via socket Unix. |
| `env_vars` | No | — | Mapa de variables de entorno del contenedor. Cada valor es un string YAML. Se escribe a `env_vars.yaml` y se pasa con `--env-vars-file`. |

> **Nota:** el flag `platform: managed` está implícito en el script (`--platform=managed`) — no es necesario incluirlo en el YAML.

### Template

```yaml
name: ${env}-[nombre]-[sufijo]
dataops_variable: crun_[nombre_snake]_uri
region: us-central1
image: us-central1-docker.pkg.dev/${env}-[proyecto]/dataops-artifacts/${env}-[nombre-imagen]:latest
project: ${env}-[proyecto]
service_account: ${env}-[empresa]-[caso-de-uso]-app@${env}-[proyecto].iam.gserviceaccount.com
allow_unauthenticated: false
memory: 2Gi
cpu: 1
concurrency: 1
timeout: 3600
max_instances: 10
add_cloudsql_instances:
  - ${cloudsql_instance}       # ← variable de _DATAOPS_VARIABLES
env_vars:
  CURR_ENVI: "${env}"
  APP_DEBUG: "false"
  SECRET_ID: "${SECRET_ID}"    # ← URI del secreto con credenciales DB
  SCHEMA_PG: "${schema_pg}"    # ← nombre del schema PostgreSQL
  BQ_PROJECT_ID: "${env}-[proyecto]"
  BQ_DATASET: "[nombre_dataset]"
```

### Ejemplo real (itc-execution-engine-api)

```yaml
name: ${env}-itc-execution-engine-api-i9r3
dataops_variable: crun_itc_execution_engine_api_uri
region: us-central1
image: us-central1-docker.pkg.dev/${env}-itc-ai-hub-services/dataops-artifacts/${env}-itc-execution-engine-api:latest
project: ${env}-itc-ai-hub-services
service_account: ${env}-itc-execution-engine-app@${env}-itc-ai-hub-services.iam.gserviceaccount.com
allow_unauthenticated: true
memory: 16Gi
cpu: 4
concurrency: 1
timeout: 3600
max_instances: 10
add_cloudsql_instances:
  - ${inca_cloudsql_instance}
env_vars:
  CURR_ENVI: "${env}"
  APP_DEBUG: "false"
  SECRET_ID: "${SECRET_ID}"
  SCHEMA_PG: "${schema_pg_app}"
  BQ_PROJECT_ID: "${env}-itc-ai-hub-services"
  BQ_DATASET: "execution_engine"
  TOPIC_NAME_EXECUTION_TRIGGER: "projects/${env}-itc-ai-hub-services/topics/${env}-process-execution-trigger-1"
  PROJECT_ID_PUBSUB_MAIL: "${mail_pubsub_project}"
  TOPIC_NAME_MAIL: "${mail_pubsub_topic}"
```

---

## 12. Variables de Entorno Estándar

Variables obligatorias en todo servicio Cloud Run ITC:

| Variable | Descripción |
|---|---|
| `CURR_ENVI` | Ambiente actual: `dev`, `qa`, `prd`. Controla el modo de conexión (GCP vs local). |
| `APP_DEBUG` | `"false"` en GCP (usa Cloud SQL socket); `"true"` en local (usa TCP). |
| `SECRET_ID` | URI completa del secreto en Secret Manager: `projects/[proyecto]/secrets/[nombre]/versions/latest` |

Variables para acceso a PostgreSQL (resueltas internamente por `api_config.py` desde el secreto, **no declarar en `env_vars`**):
`DB_USER`, `DB_PASS`, `DB_IPAD`, `DB_NAME`, `DB_PRID`, `DB_REGI`, `DB_INST`, `DB_PORT`

Variables opcionales según capacidades del servicio:

| Variable | Descripción |
|---|---|
| `SCHEMA_PG` | Nombre del schema PostgreSQL (ej: `execution_engine`) |
| `BQ_PROJECT_ID` | Proyecto GCP de BigQuery |
| `BQ_DATASET` | Dataset de BigQuery |
| `TOPIC_NAME_*` | Nombre completo del topic Pub/Sub: `projects/[proyecto]/topics/[nombre]` |
| `PROJECT_ID_PUBSUB_MAIL` | Proyecto del topic de mail (`${mail_pubsub_project}`) |
| `TOPIC_NAME_MAIL` | Topic de notificaciones por mail (`${mail_pubsub_topic}`) |

---

## 13. Buenas Prácticas

### Seguridad
- `allow_unauthenticated: false` por defecto. Poner `true` solo si el servicio es un endpoint público o recibe mensajes Pub/Sub push (que no pueden enviar token).
- No hardcodear proyectos, datasets ni IPs en el código — usar `os.getenv()`.
- Restringir `CORS allow_origins` en producción si el servicio es invocado desde frontends conocidos.

### Resiliencia
- Usar `timeout: 3600` para operaciones largas; ajustar `max_instances` según carga esperada.
- Para servicios que procesan cola (Pub/Sub push), mantener `concurrency: 1` para evitar condiciones de carrera.
- Implementar `try/except` en routers: capturar `HTTPException` primero (no re-envolver), luego `Exception` genérica con `500`.

### Observabilidad
- Usar `print()` o `logging` estándar — Cloud Run reenvía stdout/stderr a Cloud Logging automáticamente.
- Incluir el endpoint `/health` en `main.py` para monitoreo.
- Los logs estructurados (JSON) son preferibles para consultas en Cloud Logging.

### Mantenibilidad
- Fijar versiones exactas en `requirements.txt` para builds reproducibles.
- Un router por entidad — no mezclar entidades en el mismo archivo.
- Las funciones de negocio no deben recibir `Request` ni `Response` de FastAPI — son independientes del transporte HTTP.
- Usar `model/` exclusivamente para Pydantic schemas — sin lógica de negocio.

---

## Checklist de Validación

Antes de hacer deploy de un nuevo Cloud Run:

- [ ] Estructura sigue el patrón `router/ → function/ → utils/datasource/`
- [ ] `main.py` incluye endpoint `/health`
- [ ] `config/api_config.py` lee credenciales desde Secret Manager (`SECRET_ID`)
- [ ] `CURR_ENVI` y `APP_DEBUG` declarados en `env_vars` del `deploy_config.yaml`
- [ ] `service_account` usa SA tipo `-app`
- [ ] Si conecta a Cloud SQL: `add_cloudsql_instances` definido con variable `_DATAOPS_VARIABLES`
- [ ] `APP_DEBUG: "false"` en `deploy_config.yaml` (no dejar en `true` en GCP)
- [ ] Imagen base es `python:3.11-slim`
- [ ] Puerto `8080` expuesto en Dockerfile
- [ ] `requirements.txt` con versiones fijas
- [ ] Variables de entorno con `${variable}` definidas en `_DATAOPS_VARIABLES` del trigger Cloud Build
- [ ] `BQ_PROJECT_ID` y `BQ_DATASET` usan `${env}-[proyecto]` — sin hardcodear ambiente
