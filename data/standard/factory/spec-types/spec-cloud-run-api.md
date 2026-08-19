# Schema de Spec: `type: cloud_run_api`

> Spec para módulos que exponen una **API REST en Cloud Run**, con acceso a Cloud SQL (PostgreSQL)
> y/o BigQuery como datasources. Aplica al skill `@apps/skills/api-dev-agent.md`.
>
> **Ubicación del archivo:** `docs/specs/SPEC-[EMPRESA]-[YYYYMMDD]-[NNN].yaml`
> (todos los specs van en `docs/specs/` — ver `@.claude/data/standard/factory/project-manifest.md`)

---

## Bloques aplicables

El spec de tipo `cloud_run_api` comparte la estructura raíz de `@.claude/data/standard/factory/spec-manifest.md`
con los siguientes bloques específicos en lugar de `fuentes` / `outputs` / `reglas_negocio`:

| Bloque | ¿Aplica? | Descripción |
|---|---|---|
| Raíz (`id`, `version`, `status`, `type`, ...) | ✅ | Sin cambios |
| `contexto` | ✅ | `tipo_flujo: api` |
| `etapas` | ✅ | Sin cambios |
| `endpoints` | ✅ nuevo | Rutas REST de la API |
| `datasources` | ✅ nuevo | Cloud SQL y/o BigQuery |
| `componentes` | ✅ | `image` (obligatorio) + `cloud_run` (obligatorio) + `cloud_scheduler` (si aplica) |
| `seguridad` | ✅ | Autenticación, secretos, PII |
| `scheduling` | — | Solo si hay jobs programados |
| `restricciones` | ✅ | Sin cambios |
| `fuentes` | — | No aplica (reemplazado por `datasources`) |
| `outputs` | — | No aplica (reemplazado por `endpoints`) |
| `reglas_negocio` | ✅ | Reglas de validación y negocio de la API |
| `data_quality` | — | No aplica para APIs |

---

## Bloque `contexto` — valores para API

```yaml
contexto:
  tipo_flujo: api   # valor fijo para este type
```

---

## Bloque `endpoints` (lista)

Cada item describe una ruta REST expuesta por la API.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | Alias corto. Ej: `get_scoring`, `post_transaction` |
| `method` | enum | ✅ | `GET` \| `POST` \| `PUT` \| `PATCH` \| `DELETE` |
| `path` | string | ✅ | Ruta con path params. Ej: `/v1/scoring/{iden_party_hash}` |
| `descripcion` | string | ✅ | Qué hace este endpoint |
| `autenticacion` | enum | ✅ | `api_key` \| `service_account` \| `none` |
| `request_body` | string | — | Descripción del body o referencia a schema. `~` si no aplica |
| `response` | string | ✅ | Descripción del response o referencia a schema |
| `datasources` | list[string] | — | IDs de datasources que consulta este endpoint |
| `latencia_max_ms` | int | — | SLA de latencia esperado en ms |
| `pii_en_response` | bool | ✅ | `true` si el response contiene datos sensibles |

---

## Bloque `datasources`

Fuentes de datos que consulta la API. Pueden ser Cloud SQL (PostgreSQL) o BigQuery.

### Sub-bloque `cloud_sql` (lista)

Tablas PostgreSQL en Cloud SQL que la API lee o escribe.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | Alias corto. Ej: `scoring_db` |
| `instance` | string | ✅ | Nombre de instancia Cloud SQL. Usa `${variable}` |
| `database` | string | ✅ | Nombre de la base de datos |
| `schema` | string | — | Schema PostgreSQL. Default: `public` |
| `tablas` | list | ✅ | Tablas usadas con operación (read/write) |
| `ddl` | string | — | Ruta relativa al DDL PostgreSQL. Ej: `data/postgresql/ddl/scoring.sql` |
| `conexion` | string | — | Vía de conexión: `unix_socket` (recomendado) \| `tcp` |

**Campos de cada tabla en `cloud_sql[n].tablas`:**

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `nombre` | string | ✅ | Nombre de la tabla |
| `operacion` | enum | ✅ | `read` \| `write` \| `read_write` |
| `descripcion` | string | ✅ | Para qué usa esta tabla el endpoint |

### Sub-bloque `bigquery` (lista)

Tablas BigQuery que la API consulta (generalmente solo lectura).

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | Alias corto |
| `proyecto` | string | ✅ | Variable `${project_[tabla]}` |
| `dataset` | string | ✅ | Variable `${dataset_[tabla]}` |
| `tabla` | string | ✅ | Variable `${table_[tabla]}` |
| `operacion` | enum | ✅ | `read` (APIs no escriben directamente a BQ) |
| `descripcion` | string | ✅ | Qué datos expone este datasource |

---

## Bloque `componentes` para cloud_run_api

```yaml
componentes:
  - tipo: ddl_pg          # DDL PostgreSQL (tablas Cloud SQL) — si aplica
    archivo: data/postgresql/ddl/{tabla}.sql
    descripcion: "Schema de tabla PostgreSQL"

  - tipo: image           # ⚠️ OBLIGATORIO para todo cloud_run_api
    archivo: image/{dataset_out}/{tabla_out}/itc-{nombre-api}.yaml
    descripcion: "Imagen Docker del servicio en Artifact Registry"

  - tipo: cloud_run       # OBLIGATORIO
    archivo: service/cloud_run/{dataset_out}/{tabla_out}/{nombre-api}/deploy_config.yaml
    descripcion: "Servicio FastAPI desplegado en Cloud Run"

  - tipo: cloud_scheduler   # solo si hay jobs programados
    archivo: pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{nombre-api}.yaml
```

**Valores válidos de `tipo` para este spec-type:**
`ddl_pg` \| `image` \| `cloud_run` \| `cloud_scheduler` \| `pubsub`

> `{dataset_out}`/`{tabla_out}` = dataset y tabla del output principal del módulo (ver
> `@.claude/data/standard/factory/repositories.md` §2). Si el módulo `cloud_run_api` no escribe
> en BigQuery, usar el dataset/tabla lógicos que agrupan el servicio (ej. el dominio del API).

> ⚠️ **`image` es OBLIGATORIO** para todo módulo `cloud_run_api`.
> El framework Dataops necesita construir la imagen Docker antes de desplegar el Cloud Run.
> Sin el YAML de imagen en `image/`, el deploy falla porque `cloud_run.sh` espera que la imagen ya exista.
>
> El YAML de imagen va en `image/{dataset_out}/{tabla_out}/itc-{nombre-api}.yaml`.
> El Cloud Run YAML va en `service/cloud_run/{dataset_out}/{tabla_out}/{nombre-api}/deploy_config.yaml`.
> Son dos artefactos distintos que se despliegan en orden: **`image` → `cloud_run`**.

> El DDL PostgreSQL va en `data/postgresql/ddl/` (no en `data/bigquery/ddl/`).
> Ver estructura de carpetas: `@.claude/data/standard/factory/repositories.md`

> **Mapeo a deploy_[env].json:** `tipo: ddl_pg` en el spec → clave **`cloudsql_ddl`** en `deploy_dev.json` / `deploy_prd.json`.
> Análogo a `bigquery_ddl` para BigQuery. El framework ejecuta estos archivos vía `cloudsql_pg.sh`.
> **Nunca usar `ddl_pg` como clave en el deploy JSON** — solo es válido como tipo de componente en el spec.

---

## Contenido del YAML de imagen (`image/{dataset_out}/{tabla_out}/itc-{nombre-api}.yaml`)

El archivo referenciado en `componentes[tipo=image].archivo` debe tener **exactamente estos 5 campos**:

```yaml
dockerfile: service/cloud_run/{dataset_out}/{tabla_out}/{nombre-api}/Dockerfile
name:        itc-{nombre-api}
repo:        dataops-artifacts
region:      us-central1
project:     ${project_operation}
description: "Imagen Docker del servicio {nombre-api}"
```

| Campo | Obligatorio | Descripción |
|---|---|---|
| `dockerfile` | ✅ | Ruta relativa al Dockerfile desde la raíz del repo |
| `name` | ✅ | Nombre de la imagen en Artifact Registry (sin tag ni proyecto) |
| `repo` | ✅ | Repositorio en Artifact Registry. Valor fijo: `dataops-artifacts` |
| `region` | ✅ | Región del registro. Valor fijo: `us-central1` |
| `project` | ✅ | Proyecto GCP donde vive el Artifact Registry y el Cloud Run. Usar `${project_operation}` — mismo proyecto que el servicio |
| `description` | ✅ | Descripción legible del servicio — usada en el registro de la imagen |

> `image.sh` construye: `us-central1-docker.pkg.dev/{project_operation}/dataops-artifacts/{env}-{name}`
> El campo `image:` en `deploy_config.yaml` del Cloud Run debe coincidir con este nombre.
> `project` apunta siempre al mismo proyecto que el Cloud Run — nunca al proyecto de datos (`project_analytics`).

---

## Bloque `seguridad` para cloud_run_api

| Campo adicional | Tipo | Descripción |
|---|---|---|
| `autenticacion_api` | string | Mecanismo de autenticación de la API: `api_key` \| `service_account` |
| `secrets` | list | Secretos en Secret Manager que la API consume |
| `cors_origins` | list[string] | Orígenes permitidos para CORS. `["*"]` solo en dev |

```yaml
seguridad:
  autenticacion_api: api_key
  secrets:
    - nombre: db-password
      secret_manager_id: "${env}-itc-scoring-db-password"
      descripcion: "Password de Cloud SQL"
  campos_pii_output: []
  encriptacion_requerida: false
  cors_origins:
    - "https://crm.intercorp.com.pe"
```

---

## Reglas de desarrollo para este type

Al ejecutar `/check-rules` sobre un módulo `cloud_run_api`, Claude aplica adicionalmente:

1. **Sin credenciales hardcodeadas** — passwords, API keys y connection strings siempre en Secret Manager
2. **Cloud SQL vía Unix socket** — no TCP directo en producción
3. **SA tipo `-app`** para Cloud Run — nunca `-job`
4. **Estructura FastAPI obligatoria** — capas `router → function → datasource`
   Ver: `@.claude/data/standard/services/cloud-run.md`
5. **Variables de entorno** desde Secret Manager o `_DATAOPS_VARIABLES` — no hardcodeadas en Dockerfile
6. **PII en response** — si `pii_en_response=true`, verificar enmascaramiento o autenticación estricta

---

## Ejemplo completo

```yaml
id: SPEC-ITC-20260501-001
version: "1.0"
status: draft
type: cloud_run_api
empresa: itc
equipo: data-analytics
fecha: "2026-05-01"
autor: amoreno
aprobador: ~

contexto:
  nombre: "API de Scoring Crediticio"
  tipo_flujo: api
  descripcion: >
    API REST que expone el score crediticio de un cliente ITC dado su
    hash de identidad. Consulta BigQuery y cachea resultados en Cloud SQL.
  objetivo_negocio: >
    Permitir consulta en tiempo real del score para decisiones de crédito
    en punto de venta y canal digital.
  data_owner: "Área de Riesgo Crediticio"
  business_steward: "rgarcia"
  kpis:
    - "Latencia p95 < 200ms"
    - "Disponibilidad > 99.5%"

etapas:
  plan: true
  design: true
  coding: true
  data_quality: false
  compliance: true
  orchestration: false
  testing: true
  dataops: true
  calidad: true
  security: true
  documentation: true
  monitoreo: true

endpoints:
  - id: get_scoring
    method: GET
    path: /v1/scoring/{iden_party_hash}
    descripcion: Retorna el score crediticio de un cliente por su hash de identidad
    autenticacion: api_key
    request_body: ~
    response: "{ score: float, nivel: string, fecha_calculo: date }"
    datasources: [scoring_cache, ba_scoring]
    latencia_max_ms: 200
    pii_en_response: false

  - id: post_batch_scoring
    method: POST
    path: /v1/scoring/batch
    descripcion: Calcula scores para una lista de hashes en lote
    autenticacion: service_account
    request_body: "{ iden_party_hashes: list[string] }"
    response: "list[{ iden_party_hash, score, nivel }]"
    datasources: [ba_scoring]
    latencia_max_ms: 5000
    pii_en_response: false

datasources:
  cloud_sql:
    - id: scoring_cache
      instance: "${env}-itc-scoring-db"
      database: scoring
      schema: public
      conexion: unix_socket
      ddl: data/postgresql/ddl/scoring_cache.sql
      tablas:
        - nombre: scoring_cache
          operacion: read_write
          descripcion: Cache de scores calculados, TTL 24h

  bigquery:
    - id: ba_scoring
      proyecto: "${project_ba_itc_scoring}"
      dataset: "${dataset_ba_itc_scoring}"
      tabla: "${table_ba_itc_scoring}"
      operacion: read
      descripcion: Tabla BigQuery con scores precalculados por el pipeline ML

componentes:
  - tipo: ddl_pg
    archivo: data/postgresql/ddl/scoring_cache.sql
    descripcion: Schema PostgreSQL para cache de scoring

  - tipo: cloud_run
    archivo: service/cloud_run/services/scoring-api/
    descripcion: FastAPI — router scoring → function scoring → datasource BQ/SQL
    # {dataset_out}/{tabla_out} = services/scoring-api — módulo sin output BQ propio,
    # se agrupa por el dominio lógico del servicio (ver nota en §"Bloque componentes")

reglas_negocio:
  - id: RN-ITC-001
    descripcion: El score se retorna con máximo 4 decimales redondeados hacia abajo
    criticidad: alta
    campo_afectado: score
    validado_por: rgarcia

  - id: RN-ITC-002
    descripcion: >
      Si el score no está en cache o tiene más de 24h → recalcular desde BigQuery.
      No retornar datos desactualizados.
    criticidad: alta
    campo_afectado: score
    validado_por: rgarcia

seguridad:
  autenticacion_api: api_key
  secrets:
    - nombre: db-password
      secret_manager_id: "${env}-itc-scoring-db-password"
      descripcion: "Password de instancia Cloud SQL scoring"
    - nombre: api-key
      secret_manager_id: "${env}-itc-scoring-api-key"
      descripcion: "API Key para autenticación de clientes externos"
  campos_pii_fuente: []
  campos_pii_output: []
  encriptacion_requerida: false
  hash_iden_party: false
  cors_origins:
    - "https://crm.intercorp.com.pe"
  permisos:
    - sa: "${env}-itc-scoring-app@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_ba_itc_scoring}.${dataset_ba_itc_scoring}"
      permiso: roles/bigquery.dataViewer
  nota: El iden_party_hash ya viene hasheado desde el cliente — la API no procesa PII directamente.

restricciones:
  - Cloud SQL vía Unix socket únicamente — no TCP en producción
  - API Key rotación trimestral — gestión en Secret Manager
  - Cache invalidation automática a las 24h — no manual
```
