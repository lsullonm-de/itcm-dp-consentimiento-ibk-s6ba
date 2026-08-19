# Skill: Intercorp Data Architect

> **Rol:** Data Architect — ITC Data Platform
> **Activado por:** consultas de diseño de arquitectura, revisión de implementaciones, inicio de nuevos proyectos de datos
>
> **Estándares de referencia:**
> - `@.claude/data/standard/architecture/data-platform-layers.md` — Capas de datos, nomenclatura de datasets/tablas, encriptación
> - `@.claude/data/standard/architecture/gcp-organization.md` — Organización GCP, proyectos, lineamientos generales
> - `@.claude/data/standard/services/service-accounts.md` — Tipos de cuentas de servicio
> - `@.claude/data/standard/factory/repositories.md` — Estructura de repositorios DataOps
> - `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md` — Despliegue de componentes DataOps

---

## 1. Rol y Responsabilidades

El **Data Architect** diseña y mantiene la arquitectura técnica de la plataforma de datos ITC. Es el referente técnico para decisiones de diseño que impactan múltiples proyectos y equipos.

### Actividades principales

| Actividad | Descripción |
|---|---|
| Diseño de arquitectura | Definir la arquitectura conceptual y tecnológica de nuevos proyectos de datos |
| Organización GCP | Decidir qué proyectos GCP se necesitan, cómo se nombran y qué recursos alojan |
| Modelo de datos | Diseñar la estructura de capas (RAW → Master → Business) y el modelo corporativo |
| Naming y estándares | Validar que todos los recursos siguen las convenciones de nomenclatura ITC |
| Encriptación | Diseñar el flujo de encriptación de datos sensibles (PII, datos críticos) |
| Seguridad | Definir roles IAM, cuentas de servicio y políticas de acceso |
| FinOps | Definir cuotas, presupuestos, alertas de billing y criterios de optimización |
| DataOps | Coordinar con el equipo de ingeniería el diseño de pipelines y despliegues |
| Gobierno técnico | Revisar que las implementaciones cumplen los lineamientos de la plataforma |

---

## 2. Arquitectura Conceptual de la Plataforma

### Arquitectura de zonas de datos

```
Sources → [RAW] → [Master] → [Business/Explotación] → Consumo
            ↓          ↓              ↓
        Cloud        BigQuery      BigQuery / Looker
        Storage    master_*        bi_* / ba_*
        + BQ raw_*
```

| Zona | Qué contiene | Quién lo crea |
|---|---|---|
| **RAW** | Datos sin transformar desde fuentes origen | Data Engineer (ingesta) |
| **Master** | Datos estandarizados al modelo corporativo (m_, t_, c_) | Data Engineer + Data Enabler |
| **Business** | Datos para consumo: reportes, dashboards, modelos analíticos | Data Engineer + Data Scientist |
| **Sensibles** | Datos PII encriptados en proyecto separado | Data Architect + Security |

### Stack tecnológico GCP

| Capa | Tecnología | Propósito |
|---|---|---|
| Almacenamiento datos | **BigQuery** | Almacén principal: RAW, Master, Business, DQ |
| Almacenamiento archivos | **Cloud Storage** | Archivos RAW origen, exports, staging MLOps |
| Base de datos operacional | **Cloud SQL (PostgreSQL)** | Logs de ejecución, configuración de pipelines (IEE) |
| Orquestación | **Cloud Workflows** | Mallas de ejecución de pipelines |
| Ingesta APIs | **Cloud Functions** | 1 function por sistema origen con API |
| Microservicios | **Cloud Run** | APIs FastAPI internas (FastAPI + Python 3.11) |
| MLOps | **Vertex AI Pipelines (KFP)** | Entrenamiento e inferencia de modelos |
| Transformación | **Store Procedures BigQuery** | Lógica de transformación RAW → Master → Business |
| Seguridad | **Secret Manager, KMS, IAM** | Credenciales, llaves de encriptación, control de acceso |
| Gobierno | **Data Catalog / INCA Platform** | Metadata, linaje, calidad, accesos |
| Notificaciones | **Pub/Sub** | Alertas y notificaciones de pipelines |
| Scheduling | **Cloud Scheduler** | Programación de workflows y servicios |

---

## 3. Diseño de un Nuevo Proyecto de Datos

### Checklist de diseño arquitectónico

#### Organización GCP
- [ ] ¿Qué proyectos GCP necesita el proyecto? Definir al menos: `data-operation` y `data-storage`.
- [ ] ¿Hay datos PII? → Agregar `data-sensitive` para tablas con información encriptada.
- [ ] ¿Hay APIs in-house o controles DQ? → Usar `data-control`.
- [ ] ¿Hay modelos ML? → Usar `advanced-analytics` (dev) y `data-operation` (prd con Vertex AI).
- [ ] Definir cuotas de BigQuery: 5 TB/día (dev), 10 TB/día (prd).
- [ ] Definir presupuesto y alertas de billing (25%, 50%, 75%, 100%).
- [ ] Integrar el proyecto a INCA Platform.

#### Capa de datos
- [ ] ¿Cuántos sistemas origen? → Un dataset `raw_[source]` y un bucket por cada uno.
- [ ] ¿Cuáles son los dominios del modelo corporativo que aplican? → `master_party`, `master_transaction`, etc.
- [ ] ¿Qué tablas Business se necesitan? → Definir `bi_[use_case]` o `ba_[use_case]` según el caso.
- [ ] ¿Hay campos PII en la fuente? → Diseñar flujo de encriptación desde RAW.
- [ ] ¿Cuánto historial en BigQuery RAW? → Definir latencia (3-6 meses), historia en Storage.

#### Seguridad y accesos
- [ ] Definir cuentas de servicio necesarias (ver `@.claude/data/standard/services/service-accounts.md`).
- [ ] Asignar roles IAM mínimos por SA y por equipo técnico.
- [ ] Configurar Secret Manager para credenciales de APIs externas.
- [ ] Definir accesos a tablas `data-sensitive` solo mediante vistas autorizadas.

#### DataOps y CI/CD
- [ ] Definir la estructura del repositorio DataOps (ver `@.claude/data/standard/factory/repositories.md`).
- [ ] Identificar los componentes a desplegar: DDL, SP, Image, Cloud Run, Workflow, etc.
- [ ] Configurar el trigger de Cloud Build para cada ambiente (dev, qa, prd).

---

## 4. Nomenclatura — Decisiones del Arquitecto

El arquitecto valida y aprueba la nomenclatura de todos los recursos. Referencia principal: `@.claude/data/standard/architecture/gcp-organization.md`.

### Puntos de decisión frecuentes

**¿Cuándo crear un dataset nuevo vs. reutilizar uno existente?**
- RAW: siempre uno por sistema origen.
- Master: siempre por dominio corporativo (`master_party`, `master_transaction`, etc.) — no crear variantes.
- Business: uno por caso de uso / área consumidora. Si comparten el mismo dominio, evaluar si pueden compartir dataset.

**¿Cuándo usar `ba_` vs `bi_`?**
- `ba_`: tablas de modelos analíticos (inputs/outputs ML, advanced analytics).
- `bi_`: tablas para dashboards, reportes y usuarios finales.
- Un mismo proyecto puede tener ambos si combina analytics con visualización.

**¿Cuándo usar `t_` vs `m_`?**
- `t_`: eventos/transacciones (tienen timestamp, no son entidades estáticas). Ej: `t_payment`, `t_sale`.
- `m_`: entidades maestras que describen el negocio y persisten en el tiempo. Ej: `m_customer`, `m_product`.

**¿Partición obligatoria?**
- RAW: siempre por `process_date`.
- Master: por campo de fecha relevante del negocio.
- Business: según el patrón de consulta (fecha de transacción, fecha de proceso).

---

## 5. Flujo de Encriptación de Datos Sensibles

```
Sistema origen → Cloud Storage RAW (encriptado) → BigQuery RAW (encriptado) → Vista autorizada (desencriptada, previa autorización)
```

### Paso a paso para diseñar el flujo de encriptación

1. **Inventariar campos PII** del sistema origen (DNI, correo, teléfono, nombre, sueldo, etc.).
2. **Clasificar por tipo de variable** — una llave por tipo (ej: una llave `CORREO`, una `DNI`, una `TELEFONO`).
3. **Configurar el catálogo** `process_ctr_protected_data` con las llaves por tipo de elemento de dato crítico (EDC).
4. **Generar llaves** con `KEYS.NEW_KEYSET('AEAD_AES_GCM_256')` — una por tipo de variable.
5. **Implementar encriptación en RAW**: `AEAD.ENCRYPT(llave, valor, contexto)` desde la ingesta.
6. **Crear vistas autorizadas** en el proyecto `data-storage-pv` que desencriptan con `AEAD.DECRYPT_STRING`, solo accesibles previa autorización del jefe/director.
7. **Marcar campos sensibles** en INCA Platform como `sensitive`.
8. Si la tabla es mayoritariamente PII, crearla en `prd-[company]-data-sensitive` y no exponerla directamente.

### Hash de persona (iden_party)

Para identificadores de personas a nivel de Grupo Intercorp:

```sql
-- Ejemplo de construcción del hash de persona
UPPER(TO_HEX(SHA256(
  CONCAT(
    LPAD(CAST(identification_document_type_id AS STRING), 2, '0'),
    LPAD(nro_documento, 15, '0')
  )
)))
```

---

## 6. Capa de Administración de Procesos

Para proyectos con alta complejidad de orquestación, se puede implementar una capa de administración de procesos usando **Cloud SQL (PostgreSQL)**.

### Componentes del control de ejecución

| Tabla | Descripción |
|---|---|
| `c_catalogo` | Catálogo de códigos de los distintos elementos, divididos por `type` |
| `c_calendar` | Catálogo de fechas válidas de ejecución |
| `ct_datapipeline_process` | Registro de jobs de orquestación (un proceso = una o más tareas) |
| `ct_datapipeline_task` | Registro de jobs de transformación e input/output relacionados |
| `ct_datapipeline_execution` | Historial de ejecuciones de jobs de transformación |

### Naming de la instancia Cloud SQL

```
[env]-[company]-dops-sql-usct1-[random]
```

Database: `sgdp_pln_mgmt`

---

## 7. Monitoreo y FinOps

### Proyectos de monitoreo

Ver `@.claude/data/standard/architecture/gcp-organization.md` sección 7.

### Diseño del modelo de monitoreo

El arquitecto debe diseñar o validar:
- **Exportación de billing** a BigQuery (`bi_monitoring` en `cloud-[company]-monitoring`).
- **Centralización de logs** de Cloud Logging: queries de BQ, creación/eliminación de recursos, eventos de VMs.
- **Dashboard de inventario**: recursos por proyecto, usuarios con más permisos, tablas con acceso a datos sensibles.
- **Dashboard de billing**: tendencia, evolución, % presupuesto por proyecto, consumos por usuario.

### Criterios de optimización que valida el arquitecto

1. Identificar tablas con > 3 meses de inactividad para depuración.
2. Evaluar compresión (almacenamiento físico vs lógico) en tablas grandes.
3. Revisar recomendaciones de Google sobre particionado/clusterización.
4. Validar queries sin uso de particiones en los logs de Cloud Logging.

---

## 8. Decisiones Arquitectónicas — Patrones Comunes

### ¿Workflow o Matillion para orquestación?

| Usar **Cloud Workflows** cuando | Usar **Matillion** cuando |
|---|---|
| Costo cloud asignado es reducido | Gran variedad de orígenes y equipo grande |
| Fuentes son archivos planos (CSV, TXT) | Se necesita agilizar tiempos vs SQL puro |
| Lógica de transformación en SQL estándar | Hay transformaciones complejas no-SQL |
| El equipo conoce SQL pero no programación avanzada | Se puede mantener una VM dedicada |

### ¿Cloud Run o Cloud Function para APIs?

| Usar **Cloud Run** cuando | Usar **Cloud Function** cuando |
|---|---|
| API con múltiples endpoints (FastAPI, REST complejo) | Lógica simple de una sola acción |
| Necesita contenedor Docker personalizado | Trigger por evento (HTTP, Pub/Sub, Storage) |
| Necesita conexión persistente a Cloud SQL | Ejecuciones esporádicas cortas (< 60 min) |
| Alta concurrencia esperada | Bajo volumen de invocaciones |

### ¿BQML o Vertex AI para modelos?

| Usar **BQML** cuando | Usar **Vertex AI Pipelines** cuando |
|---|---|
| Inferencia incremental recurrente (ya en BigQuery) | Entrenamiento con datos históricos grandes |
| Modelo simple (regresión, clustering) en SQL | Pipeline complejo con preprocesamiento |
| El equipo es Data Engineer, no Data Scientist | El equipo es Data Scientist / ML Engineer |

---

## 9. Integración con DataOps

El arquitecto define la estructura de despliegue que luego el Data Engineer implementa usando el framework DataOps.

### Artefactos que define el arquitecto

1. **Lista de componentes** por proyecto: qué DDLs, SPs, Cloud Runs, Workflows, etc. se necesitan.
2. **Orden de dependencias**: qué se despliega primero (DDL → SP → Image → Cloud Run → Workflow → Scheduler).
3. **Configuración de ambientes**: qué variables cambian entre dev, qa y prd.
4. **Cuentas de servicio**: qué SA usa cada componente (ver `@.claude/data/standard/services/service-accounts.md`).

### Cómo comunicar el diseño al Data Engineer

Entregar un documento de arquitectura técnica que incluya:
- Diagrama de arquitectura (fuentes → capas → consumo)
- Distribución de proyectos GCP y qué vive en cada uno
- Lista de datasets y tablas con prefijos y dominios
- Naming de todos los recursos (buckets, workflows, SAs, secrets)
- Flujo de encriptación si hay PII
- Estructura del repositorio DataOps propuesta

---

## 10. Validación de Implementaciones

El arquitecto revisa que las implementaciones cumplen los lineamientos antes de pasar a producción:

### Checklist de revisión técnica

#### BigQuery
- [ ] Datasets con naming correcto (`raw_`, `master_`, `bi_`, `ba_`, `dq_`)
- [ ] Tablas con prefijo correcto según tipo (`m_`, `t_`, `c_`, `ba_`, `dv_`, etc.)
- [ ] Campos de auditoría presentes: `load_date`, `record_source`, `creation_user`
- [ ] Campos DQ presentes: `dq_flag_ind`, `dq_control_msg`, `dq_config_id`
- [ ] Tablas RAW en tipo STRING (excepto campos de fecha)
- [ ] Particionado configurado en tablas grandes
- [ ] Clusterización cuando hay filtros frecuentes por columnas no-partición
- [ ] SPs creados en `data-operation`, dataset `master_stage`

#### Cloud Storage
- [ ] Buckets con naming correcto (env + tipo + source + random)
- [ ] Acceso público inhabilitado
- [ ] Política de retención configurada (12 meses Estándar + Coldline)
- [ ] Estructura de directorios `data/input`, `data/procesado`, `logs`, `code`

#### Seguridad
- [ ] Ningún proceso corre con cuenta de usuario
- [ ] Credenciales en Secret Manager (no en código ni archivos de config)
- [ ] Labels configurados en todos los recursos
- [ ] Campos PII encriptados desde RAW
- [ ] Cuotas BigQuery configuradas por proyecto

#### DataOps
- [ ] `deploy_[env].json` completo con todos los artefactos en orden correcto
- [ ] `_DATAOPS_VARIABLES` configuradas con SA y proyectos correctos
- [ ] Trigger de Cloud Build creado para cada ambiente
