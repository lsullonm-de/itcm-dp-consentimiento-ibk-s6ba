# Estándar: Manifest de Especificación — `spec.yaml`

> **Etapa:** PLAN — fuente de verdad estructurada para todo flujo de desarrollo de datos
>
> El `spec.yaml` es la forma canónica de capturar los requerimientos de un desarrollo. A partir de él
> se generan automáticamente `docs/brief.md` y `docs/TODO.md`.

---

## Relación entre artefactos

```
spec.yaml  ──► Claude (skill PLAN)
                 ├── docs/brief.md    ← resumen ejecutivo técnico
                 └── docs/TODO.md     ← checklist de tareas por etapa
```

> `spec.yaml` se edita manualmente con `/update-spec`. `docs/brief.md` y `docs/TODO.md` se regeneran desde el manifest.

---

## Ubicación

```
docs/
├── specs/
│   └── spec-[empresa]-[yyyymmdd]-[nnn].yaml   ← fuente de verdad (editado por el equipo técnico)
├── brief.md    ← generado por la etapa PLAN
└── TODO.md     ← generado por la etapa PLAN
```

> Un archivo `.yaml` por módulo. El `project.manifest.yaml` en la raíz del repo los referencia.
> Ver: `@.claude/data/standard/factory/project-manifest.md`

---

## Schema del `spec.yaml`

### Bloque raíz

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | `spec-[empresa]-[yyyymmdd]-[nnn]` |
| `version` | string | ✅ | Versión del manifest. Incrementar con cada cambio aprobado |
| `status` | enum | ✅ | `draft` \| `review` \| `approved` \| `deprecated` |
| `type` | enum | ✅ | Tipo de módulo. Define el skill a aplicar y el schema de spec. Ver tabla de routing en `@.claude/data/standard/factory/project-manifest.md` |
| `empresa` | string | ✅ | Abreviatura de empresa o dominio (`itc`, `far`, `spsa`) |
| `equipo` | string | ✅ | Equipo responsable del desarrollo |
| `fecha` | date | ✅ | Fecha de creación `YYYY-MM-DD` |
| `autor` | string | ✅ | Usuario responsable técnico |
| `aprobador` | string | — | Usuario que aprueba. `~` (null) hasta aprobación formal |

**Valores válidos `type` — Líneas de trabajo:**

Cada `type` define una **línea de trabajo** independiente con su propio skill y schema de spec.
En repos con múltiples líneas, cada una tiene su propio módulo en `project.manifest.yaml`.

| `type` | Línea de trabajo | Skill activado | Schema de spec |
|---|---|---|---|
| `bq_pipeline` | Data Engineering | `@.claude/data/skills/build/coding/customer-attributes-developer/SKILL.md` | Este documento |
| `vertex_ml` | ML Engineering | `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md` | `@.claude/data/standard/factory/spec-types/spec-vertex-ml.md` |
| `cloud_run_api` | API / Servicios | `@apps/skills/api-dev-agent.md` | `@.claude/data/standard/factory/spec-types/spec-cloud-run-api.md` |
| `cloud_function` | Event Processing | skill CF (futuro) | `@.claude/data/standard/factory/spec-types/spec-cloud-function.md` |

> **DDL y SP son transversales** — válidos como `componentes` en cualquier línea de trabajo,
> no exclusivos de `bq_pipeline`. Toda línea que produce o consume tablas BigQuery puede declarar
> componentes `ddl` y `sp` en su spec.
>
> Para repos con múltiples líneas, ver `@.claude/data/standard/factory/project-manifest.md`.

---

### `contexto`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `nombre` | string | ✅ | Nombre descriptivo corto del desarrollo |
| `tipo_flujo` | enum | ✅ | Ver valores válidos abajo |
| `descripcion` | text | ✅ | Qué hace el desarrollo. Máx. 3 oraciones |
| `objetivo_negocio` | text | ✅ | Qué decisión de negocio habilita |
| `data_owner` | string | ✅ | Área de negocio responsable |
| `business_steward` | string | ✅ | Contacto que valida la lógica de negocio |
| `kpis` | list[string] | — | Métricas de éxito medibles |

**Valores válidos `tipo_flujo`:**
```
etl | atributos | reportes-looker | analisis-informacion | insights |
productivizacion-modelo | productivizacion-proceso-bq | migracion-matillion |
proyecto-data-analytics
```

---

### `etapas`

Mapa booleano de las etapas de desarrollo. Las etapas marcadas `true` generan tareas en el `TODO.md`.
Las etapas se agrupan en 4 fases del flujo de fábrica:

```
PLAN → DESIGN → BUILD → VERIFY → RELEASE
```

> **Nota DISCOVERY:** La etapa DISCOVERY (mapeo e integración de fuentes BigQuery) se invoca manualmente con `/data:implement-stage DISCOVERY` después de spec approval y antes de `/init-project`. NO se controla con un campo booleano en spec.yaml.

| Fase | Campo | Tipo | Default | Descripción |
|---|---|---|---|---|
| — | `plan` | bool | `true` | Siempre true — genera el resto de artefactos |
| **DESIGN** | `design` | bool | `false` | Diseño de arquitectura y naming |
| **BUILD** | `coding` | bool | `false` | DDL, SP, scripts de transformación |
| **BUILD** | `orchestration` | bool | `false` | Workflow, Scheduler |
| **BUILD** | `integridad` | bool | `false` | Solo válido en `type: bq_pipeline`. Gate de entrada sobre `fuentes`: actualidad D-1 de la fuente principal (detiene el proceso si no hay datos), duplicados y llaves nulas (se excluyen) en todas las fuentes. Para `cloud_run_api`, `cloud_function`, `vertex_ml` y cualquier otro tipo siempre `false`. Ver `@.claude/data/standard/data-integrity.md` |
| **BUILD** | `data_quality` | bool | `false` | `true` → matricular tabla en `dq_config` + invocar CF del framework desde el workflow. `false` → no hace nada relacionado con DQ |
| **BUILD** | `dataops` | bool | `false` | `deploy_[env].json`, `env_[env].json` — cierra BUILD, prerequisito para VERIFY |
| **VERIFY** | `compliance` | bool | `false` | Auditoría estática del código: naming, PII, campos de auditoría, reglas de despliegue |
| **RELEASE** | `infraops` | bool | `false` | Generar YAMLs SA e IAM + `infra_dev/prd.json` — prerequisito para los triggers Cloud Build |
| **RELEASE** | `security` | bool | `false` | Auditar permisos definidos en INFRAOPS: least-privilege, PII, Secret Manager |
| **RELEASE** | `documentation` | bool | `false` | README, catálogo de datos, variables de entorno documentadas |
| **TESTING** | `testing` | bool | `false` | Validación dinámica post-despliegue vía MCP BigQuery. **Activar solo después de correr trigger InfraOps + Dataops en dev.** |

---

### `fuentes` (lista)

Cada item representa una tabla de entrada.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | Alias corto para referenciar en reglas (ej. `rcc`) |
| `descripcion` | string | ✅ | Nombre legible de la fuente |
| `proyecto` | string | ✅ | Variable `${project_[tabla]}` o valor literal |
| `dataset` | string | ✅ | Variable `${dataset_[tabla]}` o valor literal |
| `tabla` | string | ✅ | Variable `${table_[tabla]}` o valor literal |
| `volumetria` | string | — | Estimado de filas (`~14M registros`) |
| `particion` | string | — | Campo de partición. `~` si no tiene |
| `pii` | bool | — | `true` si la tabla contiene datos sensibles |
| `rol` | enum | — | `principal` \| `secundaria`. Requerido si `etapas.integridad: true`. Debe haber **exactamente una** fuente `principal` (el universo del proceso) |
| `tipo_fuente` | enum | — | `tabla` \| `archivo`. Requerido si `etapas.integridad: true` — define cómo se identifica la actualidad (ver `@.claude/data/standard/data-integrity.md` §2) |
| `llave` | list[string] | — | Columnas que forman la llave de negocio de la fuente. Requerido si `etapas.integridad: true` — se usa para los checks de duplicados y llave nula |
| `campo_fecha` | string | — | Nombre del campo `load_date` (si `tipo_fuente: tabla` y no se usa `particion`), o patrón de fecha en el nombre del archivo (si `tipo_fuente: archivo`). `~` si se identifica solo por `particion` |

---

### `reglas_integridad`

Solo aplica si `etapas.integridad: true`. Reglas derivadas de `fuentes[].rol` y `fuentes[].llave`
— no se redactan reglas SQL a mano.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `fuente_principal` | string | ✅ | `id` de la fuente en `fuentes` con `rol: principal` |
| `dias_tolerancia` | int | — | Antigüedad máxima aceptable en días para el check de actualidad. Default `1` (exige datos de ayer, D-1) |
| `registro_resultados` | bool | — | Default `true`. Registra el histórico del gate en el Framework de Control de Procesos (`ct_datapipeline_integrity_rule` + `de_datapipeline_integrity_execution`) vía metadata API. Requiere `METADATA_API_URL` en `env_[env].json`. Ponerlo en `false` obliga a justificarlo en `restricciones[]` |
| `reglas` | list | ✅ | Lista de reglas de integridad |

**Campos de cada regla:**

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | `RI-[EMPRESA]-[TABLA]-NNN` |
| `fuente_id` | string | ✅ | `id` de la fuente en `fuentes` a la que aplica |
| `tipo_check` | enum | ✅ | `actualidad` \| `duplicados` \| `llave_nula` |
| `accion` | enum | ✅ | `detener_proceso` \| `excluir_registros` |

> Reglas: `tipo_check: actualidad` solo es válido para `fuente_id == fuente_principal` y siempre
> con `accion: detener_proceso` — es la única regla que genera código en el SP de integridad
> por default. `tipo_check: duplicados` y `llave_nula` aplican a cualquier fuente (principal o
> secundaria) y por default usan `accion: excluir_registros` (se resuelven en el SP de carga,
> no en el SP de integridad). `accion: detener_proceso` también es válido para `duplicados`/
> `llave_nula` si el spec documenta la razón de negocio en `restricciones[]` — en ese caso esa
> regla sí se implementa en el SP de integridad.
>
> El SP de integridad no escribe en ninguna tabla BigQuery — devuelve `o_flag_detener`,
> `o_motivo_detencion` y `o_resultado_json` como parámetros `OUT`. El workflow consume los dos
> primeros para decidir si corta, y envía el tercero a la metadata API para dejar el histórico
> por regla (`registro_resultados: true`).
>
> El `id` de cada regla es también su `code` en el catálogo `ct_datapipeline_integrity_rule` —
> no renombrarlo una vez matriculado, o se rompe la continuidad del histórico.
>
> Framework completo: `@.claude/data/standard/data-integrity.md`

---

### `outputs` (lista)

Cada item representa una tabla de salida.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `tabla` | string | ✅ | Nombre físico de la tabla destino |
| `proyecto` | string | ✅ | Variable `${project_analytics}` o literal |
| `dataset` | string | ✅ | Variable `${dataset_analytics}` o literal |
| `descripcion` | string | ✅ | Qué representa esta tabla |
| `capa` | enum | ✅ | `raw` \| `master` \| `business` |
| `particion` | string | — | Campo de partición. `~` si no aplica |
| `tipo_carga` | enum | ✅ | `reemplazo` \| `incremental` \| `acumulativo` |
| `campos_auditoria` | list | — | Campos de auditoría requeridos. Ver `@.claude/data/standard/architecture/data-platform-layers.md` |
| `pii` | bool | — | `true` si el output contiene datos sensibles |

---

### `reglas_negocio` (lista)

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | `RN-[empresa]-NNN` |
| `descripcion` | string | ✅ | Descripción de la regla en lenguaje de negocio |
| `criticidad` | enum | ✅ | `alta` \| `media` \| `baja` |
| `campo_afectado` | string | — | Columna o tabla impactada |
| `validado_por` | string | — | Business Steward que confirma la regla |
| `referencia` | string | — | Enlace a estándar o documento de respaldo |

> Toda RN de criticidad `alta` debe tener al menos una regla DQ asociada en el bloque `data_quality`.

---

### `componentes` (lista)

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `tipo` | enum | ✅ | Ver tabla de componentes por línea de trabajo abajo |
| `archivo` | string | ✅ | Ruta relativa dentro del repo |
| `descripcion` | string | — | Para qué sirve este componente |

**Orden de despliegue:** `ddl → sp → bucket → image → cloud_run → vertex_pipeline → cloud_function → pubsub → workflow → cloud_scheduler`
Ver: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

#### Componentes por línea de trabajo

| Componente | `bq_pipeline` | `vertex_ml` | `cloud_run_api` | `cloud_function` | Notas |
|---|:---:|:---:|:---:|:---:|---|
| `ddl` | ✅ siempre | ✅ siempre | ✅ si hay BQ output | ✅ si hay BQ output | **Transversal** — válido en cualquier línea |
| `sp` | ✅ siempre | ✅ siempre | opt | opt | **Transversal** — válido en cualquier línea |
| `workflow` | ✅ recomendado | ✅ recomendado | opt | — | Orquesta, maneja errores, notifica por mail |
| `cloud_scheduler` | ✅ recomendado | ✅ recomendado | opt | — | Dispara el workflow según frecuencia |
| `vertex_pipeline` | — | ✅ siempre | — | — | Pipeline KFP compilado |
| `image` | — | ✅ siempre | ✅ siempre | — | Imagen Docker en Artifact Registry — **obligatorio para `cloud_run_api`** |
| `bucket` | opt | ✅ siempre | — | — | GCS bucket del pipeline |
| `cloud_run` | — | — | ✅ siempre | — | Servicio Cloud Run |
| `cloud_function` | — | — | — | ✅ siempre | Función event-driven |
| `pubsub` | opt | opt | opt | opt | Tópico Pub/Sub (mail o trigger) |

> **Lineamiento workflow:** Todo spec con `orchestration: true` debe incluir `workflow` + `cloud_scheduler`.
> El Workflow orquesta la ejecución, maneja errores y notifica por mail (Pub/Sub).
> Excepción: repos tipo framework-plataforma o servicios que exponen solo APIs/CFs
> como interfaz pueden declarar `orchestration: false` y omitir workflow.

---

### `data_quality`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `dataset_dq` | string | ✅ | Variable `${dataset_dq}` |
| `reglas` | list | ✅ | Lista de reglas DQ |

**Campos de cada regla DQ:**

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `id` | string | ✅ | `DQ-[empresa]-[TABLA]-NNN` |
| `dimension` | enum | ✅ | `completitud` \| `unicidad` \| `validez` \| `precision` \| `consistencia` \| `oportunidad` |
| `tipo` | enum | ✅ | `technical` \| `business` |
| `campo` | string | ✅ | Columna que valida |
| `critica` | bool | ✅ | Si falla → detiene el workflow |
| `umbral_max_pct_invalidos` | int | ✅ | % máximo de filas inválidas aceptable (0–100) |
| `sql_rule` | text | ✅ | Query que retorna **filas inválidas**. Usa `${variables}` |

> Framework completo: `@.claude/data/standard/data-quality.md`

---

### `seguridad`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `campos_pii_fuente` | list[string] | — | Campos PII en tablas fuente |
| `campos_pii_output` | list[string] | — | Campos PII en tablas output. `[]` si no aplica |
| `encriptacion_requerida` | bool | ✅ | AEAD.ENCRYPT para campos PII en output |
| `hash_iden_party` | bool | — | SHA256(tipo_doc+nro_doc) para identificar persona |
| `permisos` | list | — | SAs y permisos a solicitar |
| `nota` | string | — | Aclaraciones adicionales |

> Estándar de encriptación y hash: `@.claude/data/standard/architecture/data-platform-layers.md`

---

### `scheduling`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `frecuencia` | string | ✅ | Expresión cron o `on-demand` |
| `zona_horaria` | string | — | Default: `America/Lima` |
| `dependencias` | list[string] | — | Procesos upstream que deben completarse antes |
| `consumidores` | list[string] | — | Procesos downstream que consumen el output |
| `tiempo_max_ejecucion` | string | — | Ej. `45m`, `2h` |

---

### `restricciones`

Lista de strings. Supuestos y restricciones que el equipo debe conocer antes de comenzar.

---

## Convención de ID

```
spec-[empresa]-[yyyymmdd]-[nnn]
```

| Parte | Descripción | Ejemplo |
|---|---|---|
| `EMPRESA` | Abreviatura de empresa o dominio | `ITC`, `FAR`, `SPSA` |
| `YYYYMMDD` | Fecha de creación | `20260401` |
| `NNN` | Secuencial del día (3 dígitos) | `001`, `002` |

**Ejemplos:** `spec-itc-20260401-001`, `spec-far-20260401-002`

---

## Ejemplo completo: Atributo de Nivel Educativo

```yaml
# ============================================================
# MANIFEST DE ESPECIFICACIÓN — Data Platform ITC
# ============================================================

id: spec-itc-20260401-001
version: "1.0"
status: draft
empresa: itc
equipo: data-platform
fecha: "2026-04-01"
autor: amoreno
aprobador: ~

# ------------------------------------------------------------
# 1. CONTEXTO
# ------------------------------------------------------------
contexto:
  nombre: "Atributo de Nivel Educativo"
  tipo_flujo: atributos
  descripcion: >
    Generar el atributo ba_itc_attr_education con el nivel educativo
    agrupado de cada cliente ITC, normalizado desde fuentes RCC.
  objetivo_negocio: >
    Enriquecer el perfil del cliente para modelos de scoring crediticio
    y campañas de segmentación educacional.
  data_owner: "Área de Analítica de Clientes"
  business_steward: "lmorales"
  kpis:
    - "Cobertura > 85% de iden_itc_party activos"
    - "Refresh mensual, disponible antes del día 3 de cada mes"

# ------------------------------------------------------------
# 2. ETAPAS APLICABLES
# ------------------------------------------------------------
etapas:
  plan: true
  design: true
  coding: true
  orchestration: true
  integridad: true
  data_quality: true
  dataops: true
  compliance: true
  infraops: true
  testing: false      # activar solo después de correr el trigger InfraOps + Dataops en dev
  security: true
  documentation: true

# ------------------------------------------------------------
# 3. FUENTES DE DATOS
# ------------------------------------------------------------
fuentes:
  - id: rcc
    descripcion: "Reporte de Crédito Consolidado — nivel educativo reportado"
    proyecto: "${project_ba_itc_attr_rcc}"
    dataset: "${dataset_ba_itc_attr_rcc}"
    tabla: "${table_ba_itc_attr_rcc}"
    volumetria: "~14M registros"
    particion: load_date
    pii: true
    rol: principal
    tipo_fuente: tabla
    llave: [tipo_doc, nro_doc]
    campo_fecha: load_date

  - id: iden_party
    descripcion: "Identificación unificada de persona ITC"
    proyecto: "${project_iden_itc_party}"
    dataset: "${dataset_iden_itc_party}"
    tabla: "${table_iden_itc_party}"
    volumetria: "~20M registros"
    particion: ~
    pii: true
    rol: secundaria
    tipo_fuente: tabla
    llave: [party_id]
    campo_fecha: ~

# ------------------------------------------------------------
# 4. OUTPUTS
# ------------------------------------------------------------
outputs:
  - tabla: ba_itc_attr_education
    proyecto: "${project_analytics}"
    dataset: "${dataset_analytics}"
    descripcion: "Nivel educativo agrupado por cliente ITC (hash iden_party)"
    capa: business
    particion: load_date
    tipo_carga: reemplazo
    campos_auditoria: [load_date, record_source, creation_user]
    pii: false

# ------------------------------------------------------------
# 4b. REGLAS DE INTEGRIDAD (solo si etapas.integridad: true)
# ------------------------------------------------------------
reglas_integridad:
  fuente_principal: rcc
  dias_tolerancia: 1
  registro_resultados: true      # histórico por regla en metadata_operational vía metadata API
  reglas:
    - id: RI-ITC-BA_ITC_ATTR_EDUCATION-001
      fuente_id: rcc
      tipo_check: actualidad
      accion: detener_proceso

    - id: RI-ITC-BA_ITC_ATTR_EDUCATION-002
      fuente_id: rcc
      tipo_check: duplicados
      accion: excluir_registros

    - id: RI-ITC-BA_ITC_ATTR_EDUCATION-003
      fuente_id: rcc
      tipo_check: llave_nula
      accion: excluir_registros

    - id: RI-ITC-BA_ITC_ATTR_EDUCATION-004
      fuente_id: iden_party
      tipo_check: duplicados
      accion: excluir_registros

    - id: RI-ITC-BA_ITC_ATTR_EDUCATION-005
      fuente_id: iden_party
      tipo_check: llave_nula
      accion: excluir_registros

# ------------------------------------------------------------
# 5. REGLAS DE NEGOCIO
# ------------------------------------------------------------
reglas_negocio:
  - id: RN-ITC-001
    descripcion: >
      Aplicar el diccionario nivel_map con los valores exactos definidos.
      No renombrar claves ni alterar los valores de salida.
    criticidad: alta
    campo_afectado: nivel_educativo
    validado_por: lmorales
    referencia: "data/skills/build/coding/mlops-framework-developer/SKILL.md — Sección 3.6"

  - id: RN-ITC-002
    descripcion: >
      Si el valor de nivel_educativo no está en el diccionario → asignar 'Sin categoria'.
      No dejar nulls en el campo.
    criticidad: alta
    campo_afectado: nivel_educativo
    validado_por: lmorales

  - id: RN-ITC-003
    descripcion: >
      El join con iden_party se realiza vía hash SHA256(tipo_doc + nro_doc).
      No exponer tipo_doc ni nro_doc en el output.
    criticidad: alta
    campo_afectado: iden_party_hash
    validado_por: amoreno

# ------------------------------------------------------------
# 6. COMPONENTES GCP
# ------------------------------------------------------------
componentes:
  # Rutas con nesting {dataset_out}/{tabla_out} — ver @.claude/data/standard/factory/repositories.md §2-3
  # {dataset_out} = analytics (valor real de ${dataset_analytics}), {tabla_out} = ba_itc_attr_education
  - tipo: ddl
    archivo: data/bigquery/analytics/ba_itc_attr_education/ddl/ba_itc_attr_education.sql
    descripcion: "Crear tabla destino con partición por load_date"

  - tipo: ddl
    archivo: data/bigquery/analytics/ba_itc_attr_education/ddl/tmp_ba_itc_attr_education_rcc.sql
    descripcion: "Staging desde RCC (fuente rcc)"

  - tipo: sp
    archivo: data/bigquery/analytics/ba_itc_attr_education/sp/sp_ba_itc_attr_education_rcc.sql
    descripcion: "Carga y normalización del atributo desde RCC"

  - tipo: workflow
    archivo: pipeline/workflow/analytics/ba_itc_attr_education/wf-ba-itc-attr-education-rcc.yaml
    descripcion: "Orquestación: ejecutar SP → validar DQ → notificar"

  - tipo: cloud_scheduler
    archivo: pipeline/scheduler/analytics/ba_itc_attr_education/cs-ba-itc-attr-education-rcc.yaml
    descripcion: "Ejecución mensual, día 1 a las 3:00am"

# ------------------------------------------------------------
# 7. DATA QUALITY
# ------------------------------------------------------------
data_quality:
  dataset_dq: "${dataset_dq}"
  reglas:
    - id: DQ-ITC-BA_ITC_ATTR_EDUCATION-001
      dimension: completitud
      tipo: technical
      campo: nivel_educativo
      critica: true
      umbral_max_pct_invalidos: 0
      sql_rule: >
        SELECT *
        FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_education`
        WHERE nivel_educativo IS NULL

    - id: DQ-ITC-BA_ITC_ATTR_EDUCATION-002
      dimension: validez
      tipo: business
      campo: nivel_educativo
      critica: true
      umbral_max_pct_invalidos: 5
      sql_rule: >
        SELECT *
        FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_education`
        WHERE nivel_educativo NOT IN (
          'Sin_educacion', 'Primaria', 'Secundaria_c', 'Secundaria_i',
          'Tecnica_c', 'Tecnica_i', 'Universitaria_c', 'Universitaria_i',
          'Postgrado', 'Sin categoria'
        )

    - id: DQ-ITC-BA_ITC_ATTR_EDUCATION-003
      dimension: unicidad
      tipo: technical
      campo: iden_party_hash
      critica: true
      umbral_max_pct_invalidos: 0
      sql_rule: >
        SELECT iden_party_hash, load_date, COUNT(*) AS cnt
        FROM `${project_analytics}.${dataset_analytics}.ba_itc_attr_education`
        GROUP BY iden_party_hash, load_date
        HAVING cnt > 1

# ------------------------------------------------------------
# 8. SECURITY
# ------------------------------------------------------------
seguridad:
  campos_pii_fuente: [tipo_doc, nro_doc, nivel_educativo]
  campos_pii_output: []
  encriptacion_requerida: false
  hash_iden_party: true
  permisos:
    - sa: "${env}-itc-attr-education-job@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_ba_itc_attr_rcc}.${dataset_ba_itc_attr_rcc}.${table_ba_itc_attr_rcc}"
      permiso: roles/bigquery.dataViewer
    - sa: "${env}-itc-attr-education-job@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_analytics}.${dataset_analytics}"
      permiso: roles/bigquery.dataEditor
  nota: >
    El output no expone PII. El join con iden_party se realiza internamente
    en el SP usando hash SHA256 — el hash no se persiste en el output final.

# ------------------------------------------------------------
# 9. SCHEDULING
# ------------------------------------------------------------
scheduling:
  frecuencia: "0 3 1 * *"
  zona_horaria: America/Lima
  dependencias:
    - "ba_itc_attr_rcc cargada con datos del mes anterior (lag: D-1 del mes)"
  consumidores:
    - "Modelos de scoring crediticio que consumen ba_itc_attr_education"
  tiempo_max_ejecucion: 45m

# ------------------------------------------------------------
# 10. RESTRICCIONES
# ------------------------------------------------------------
restricciones:
  - "No modificar el diccionario nivel_map — claves y valores definidos por negocio (RN-ITC-001)"
  - "El SP no debe crear tablas intermedias fuera de ${dataset_stage}"
  - "Refresh mensual — no diario por volumen de RCC (~14M filas)"
  - "ADD COLUMN únicamente — no alterar columnas existentes de ba_itc_attr_education"
```

---

## Checklist de validación del manifest

Antes de pasar a la etapa DESIGN, el `spec.yaml` debe cumplir:

- [ ] `id` con formato `spec-[empresa]-[yyyymmdd]-[nnn]`
- [ ] `status: review` o `approved` (no `draft`)
- [ ] Al menos una fuente definida con proyecto/dataset/tabla como `${variables}`
- [ ] Al menos un output con `tipo_carga` y `campos_auditoria`
- [ ] Si `etapas.integridad: true` → exactamente 1 fuente con `rol: principal`, todas las fuentes con `llave` definida, y `reglas_integridad.fuente_principal` coincide con esa fuente
- [ ] Toda RN de `criticidad: alta` tiene al menos una regla DQ con `critica: true`
- [ ] `data_quality.reglas` con `sql_rule` que usa `${variables}` (no valores hardcodeados)
- [ ] `seguridad.campos_pii_output: []` o encriptación declarada si hay PII en output
- [ ] `scheduling.frecuencia` definido o `on-demand` explícito
- [ ] `aprobador` distinto de `~` (aprobado por Data Owner o Business Steward)


