# Reglas de Seguridad — Operaciones Destructivas, PII, SA, Secrets

> Aplica a: `data/bigquery/`, `pipeline/workflow/`, `service/`, `deploy/`

---

## Operaciones Destructivas

### ❌ No usar `DROP TABLE` en producción

```sql
-- ❌ PROHIBIDO — pérdida irreversible de datos en producción
DROP TABLE `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`;

-- ✅ ALTERNATIVA para limpiar antes de recarga full
TRUNCATE TABLE `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`;

-- ✅ ALTERNATIVA para limpiar una partición específica
DELETE FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
WHERE load_date = DATE('${process_date}');
```

**Regla:** `DROP TABLE` solo es válido en scripts de migración de entornos no-productivos, y debe estar aprobado por el Data Owner con evidencia en el ticket correspondiente.

### ❌ No usar `DROP DATASET` en código de proceso

```sql
-- ❌ PROHIBIDO — elimina todos los objetos del dataset
DROP SCHEMA IF EXISTS `${project_analytics}.${dataset_analytics}` CASCADE;

-- ✅ Si necesitas limpiar temporales, elimina tabla por tabla en el script de limpieza
```

### ❌ No ejecutar DDL destructivo en SPs de producción

Los Stored Procedures de producción (`sp/`) **no deben contener**:
- `DROP TABLE`
- `DROP SCHEMA`
- `DROP PROCEDURE`
- `DELETE FROM` sin cláusula `WHERE` (full table delete)

```sql
-- ❌ PROHIBIDO — delete sin filtro
DELETE FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`;

-- ✅ CORRECTO — delete con filtro de partición
DELETE FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
WHERE load_date = DATE('${process_date}');
```

---

## PII — Datos Personales

### ✅ Campos PII deben estar identificados en el spec

Todo campo que contenga datos personales directos (tipo_doc, nro_doc, nombre, apellido, email, teléfono, dirección) debe estar marcado como `pii: true` en el spec del proceso.

```yaml
# ✅ CORRECTO — PII identificado en spec
fuentes:
  - id: iden_itc_party
    tabla: "${table_iden_itc_party}"
    pii: true
    campos_pii: [tipo_doc, nro_doc]
    tratamiento: "Solo se usa para lookup — no persiste en output"
```

### ✅ Campos PII no deben persistir en tablas output de analytics

```sql
-- ❌ INCORRECTO — tipo_doc y nro_doc en tabla output
INSERT INTO `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
SELECT tipo_doc, nro_doc, id_sandbox, ...

-- ✅ CORRECTO — solo id_sandbox (hash de identidad) en output
INSERT INTO `${project_analytics}.${dataset_analytics}.ba_itc_attr_retail`
SELECT id_sandbox, ...   -- id_sandbox = hash SHA-256 derivado de iden_itc_party
```

### ✅ Encriptación AEAD para campos PII que deben persistir

Si un campo PII debe persistir en la capa analytics/master, debe estar encriptado con AEAD:

```sql
-- ✅ CORRECTO — campo PII encriptado antes de persistir
AEAD.ENCRYPT(
  (SELECT keyset FROM `${project_analytics}.${dataset_keysets}.customer_keyset`),
  CAST(nro_doc AS BYTES),
  CAST(tipo_doc AS BYTES)
) AS nro_doc_enc
```

> Ver lineamientos completos de encriptación: `@.claude/data/standard/architecture/data-platform-layers.md`

---

## Cuentas de Servicio

### ✅ SA correcta por tipo de componente

| Componente | SA a usar |
|---|---|
| `cloud_run`, `cloud_function` | `-app` |
| `workflow`, `vertex_pipeline`, `cloud_scheduler` | `-job` |
| Cloud Build (deploy) | `-deployer` (centralizado) |

### ❌ No hardcodear SA en archivos del repositorio

```yaml
# ❌ INCORRECTO — SA hardcodeada
service_account: prd-itc-ingreso-job@prd-itc-customer-services.iam.gserviceaccount.com

# ✅ CORRECTO — SA vía variable Dataops
service_account: ${service_account_job}
```

### ✅ Principio de mínimo privilegio

Cada SA debe tener **solo los roles necesarios** para su función. No asignar roles de editor o propietario a nivel de proyecto.

```
# ❌ INCORRECTO — demasiado amplio
roles/editor sobre el proyecto

# ✅ CORRECTO — mínimo privilegio
roles/bigquery.dataViewer sobre el dataset de input
roles/bigquery.dataEditor sobre el dataset de output
roles/bigquery.jobUser sobre el proyecto
```

> Ver estándar completo: `@.claude/data/standard/services/service-accounts.md`

---

## Secrets y Configuración Sensible

### ❌ No hardcodear secrets en archivos de repositorio

```python
# ❌ PROHIBIDO — credenciales en código
connection_string = "postgresql://user:password@host:5432/db"
api_key = "AIzaSy..."

# ✅ CORRECTO — vía Secret Manager
from google.cloud import secretmanager
secret = client.access_secret_version(name="projects/.../secrets/db-password/versions/latest")
```

### ❌ No incluir archivos `.env` con secrets en el repositorio

```gitignore
# ✅ OBLIGATORIO en .gitignore
.env
*.key
credentials.json
service_account_key.json
```

### ✅ Secrets accesibles vía variables de entorno en Cloud Run / Cloud Function

```yaml
# ✅ CORRECTO — secret inyectado como env var en deploy_config.yaml
env_vars:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-password
        key: latest
```

---

## Workflow — Permisos y Autenticación

### ✅ OIDC para Cloud Run y Cloud Functions

```yaml
# ✅ CORRECTO — OIDC para servicios GCP
- call_api:
    call: http.post
    args:
      url: ${var_api_url}
      auth:
        type: OIDC
        audience: ${var_api_url}
```

### ✅ OAuth2 para APIs de Google (Pub/Sub, BQ, Vertex AI)

```yaml
# ✅ CORRECTO — OAuth2 para APIs Google
- enviar_mail:
    call: http.post
    args:
      url: "https://pubsub.googleapis.com/..."
      auth:
        type: OAuth2
```

**Regla:** OIDC para servicios propios (Cloud Run/CF). OAuth2 para APIs de Google (Pub/Sub, BigQuery, Vertex AI, Workflows). Nunca usar `auth.type: None` en producción.

---

## Checklist de Seguridad

- [ ] No hay `DROP TABLE` ni `DROP SCHEMA` en SPs de producción
- [ ] No hay `DELETE FROM` sin cláusula `WHERE`
- [ ] Campos PII identificados en el spec (`pii: true`, `campos_pii: [...]`, `tratamiento: ...`)
- [ ] Campos PII no persisten en outputs de analytics (solo `id_sandbox` o hash)
- [ ] Si PII persiste, está encriptado con AEAD
- [ ] SA correcta por componente (`-app` vs `-job`)
- [ ] SA referenciada vía `${service_account_*}` — nunca hardcodeada
- [ ] No hay secrets, API keys ni passwords en archivos del repositorio
- [ ] `.gitignore` incluye `.env`, `credentials.json`, `*.key`
- [ ] Cloud Run/CF usa `auth.type: OIDC`
- [ ] Google APIs (Pub/Sub, BQ, Vertex) usan `auth.type: OAuth2`
