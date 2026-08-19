# Schema de Spec: `type: vertex_ml`

> Spec para módulos que productivisan un **modelo de ML en Vertex AI Pipelines (KFP)**:
> pipeline de entrenamiento, pipeline de inferencia, o ambos.
> Aplica al skill `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md`.
>
> **Ubicación del archivo:** `docs/specs/SPEC-[EMPRESA]-[YYYYMMDD]-[NNN].yaml`
> (todos los specs van en `docs/specs/` — ver `@.claude/data/standard/factory/project-manifest.md`)

---

## Bloques aplicables

El spec de tipo `vertex_ml` comparte la estructura raíz de `@.claude/data/standard/factory/spec-manifest.md`
con los siguientes bloques específicos:

| Bloque | ¿Aplica? | Descripción |
|---|---|---|
| Raíz (`id`, `version`, `status`, `type`, ...) | ✅ | Sin cambios |
| `contexto` | ✅ | `tipo_flujo: productivizacion-modelo` |
| `etapas` | ✅ | Sin cambios |
| `fuentes` | ✅ | Tablas BigQuery de entrenamiento/inferencia |
| `outputs` | ✅ adaptado | Tabla de predicciones + artefactos de modelo |
| `modelo` | ✅ nuevo | Definición del modelo ML |
| `pipelines` | ✅ nuevo | Configuración de pipelines KFP (train / inference) |
| `componentes` | ✅ | `image`, `vertex_pipeline`, `cloud_scheduler`, `workflow` |
| `reglas_negocio` | ✅ | Reglas de transformación y features |
| `data_quality` | ✅ opcional | Declaración de reglas DQ para la tabla output en el framework `itcm-dp-dataquality-core`. Ver nota abajo. |
| `seguridad` | ✅ | Sin cambios |
| `scheduling` | ✅ | Frecuencia de reentrenamiento / inferencia |
| `restricciones` | ✅ | Sin cambios |

---

## Nota: `etapas.data_quality`

| Valor | Qué hace |
|---|---|
| `true` | DATAOPS genera los DML de inserción en `dq_config` + el workflow invoca la CF del framework (`func_itc_dq_run_rules_uri`) tras escribir el output — DQ inmediato y bloqueante |
| `false` | No se matricula la tabla ni se invoca el framework desde el workflow — no se hace nada relacionado con DQ |

Cuando es `true`, agregar el bloque `data_quality` con las reglas y asegurarse de que el workflow incluye el paso de invocación a la CF tras el componente de escritura del output.

> Regla mínima cuando `data_quality: true`: completitud PK, unicidad PK+fecha, validez del target, volumen mínimo.

---

## Bloque `contexto` — valores para vertex_ml

```yaml
contexto:
  tipo_flujo: productivizacion-modelo   # valor fijo para este type
```

---

## Bloque `outputs` adaptado para vertex_ml

Además de las tablas BigQuery de salida, incluir artefactos del modelo:

| Campo adicional | Tipo | Descripción |
|---|---|---|
| `tipo` | enum | `tabla_predicciones` \| `modelo_artefacto` |
| `gcs_path` | string | Path GCS del artefacto (solo para `modelo_artefacto`) |
| `formato` | string | `pickle` \| `joblib` \| `savedmodel` \| `bqml` |

```yaml
outputs:
  - tipo: tabla_predicciones
    tabla: ba_itc_churn_scores
    proyecto: "${project_analytics}"
    dataset: "${dataset_analytics}"
    descripcion: "Score de churn por cliente, actualizado mensualmente"
    capa: business
    particion: load_date
    tipo_carga: reemplazo
    campos_auditoria: [load_date, record_source, creation_user]
    pii: false

  - tipo: modelo_artefacto
    gcs_path: "${PIPELINE_BUCKET}/models/churn_farmacias/v{version}/"
    formato: joblib
    descripcion: "Modelo XGBoost serializado con pipeline de preprocessing"
```

---

## Bloque `modelo`

Define las características del modelo ML a productivizar.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `nombre` | string | ✅ | Nombre del modelo. Ej: `churn_farmacias` |
| `version` | string | ✅ | Versión inicial. Ej: `v1` |
| `tipo` | enum | ✅ | `clasificacion` \| `regresion` \| `clustering` \| `recomendacion` |
| `framework` | enum | ✅ | `sklearn` \| `xgboost` \| `lightgbm` \| `tensorflow` \| `pytorch` \| `bqml` |
| `target` | string | ✅ | Variable objetivo. Ej: `churn_flag` |
| `metrica_principal` | string | ✅ | Métrica de evaluación. Ej: `AUC-ROC`, `RMSE`, `F1` |
| `umbral_aceptacion` | string | ✅ | Valor mínimo de la métrica para aprobar el modelo |
| `features_count` | int | — | Número aproximado de features de entrada |
| `notebook_origen` | string | — | Ruta o URL del notebook de exploración original |

---

## Bloque `pipelines`

Define los pipelines KFP a construir. Puede haber uno o ambos.

### Sub-bloque `train`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `activo` | bool | ✅ | `true` si se productiviza el pipeline de entrenamiento |
| `componentes_kfp` | list | — | Pasos del pipeline (`preprocess`, `train`, `evaluate`, `register`) |
| `archivo_pipeline` | string | — | Ruta al Python del pipeline. Ej: `src/pipeline_train.py` |
| `archivo_compilado` | string | — | Path GCS del JSON compilado |
| `machine_type` | string | — | Tipo de máquina Vertex AI. Ej: `n1-standard-4` |
| `reentrenamiento` | string | — | Frecuencia de reentrenamiento. Ej: `mensual`, `on-demand` |

### Sub-bloque `inference`

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `activo` | bool | ✅ | `true` si se productiviza el pipeline de inferencia |
| `componentes_kfp` | list | — | Pasos del pipeline (`load_model`, `preprocess`, `predict`, `write_output`) |
| `archivo_pipeline` | string | — | Ruta al Python del pipeline. Ej: `src/pipeline_inference.py` |
| `archivo_compilado` | string | — | Path GCS del JSON compilado |
| `machine_type` | string | — | Tipo de máquina Vertex AI |
| `frecuencia` | string | — | Frecuencia de ejecución de inferencia |

---

## Bloque `componentes` para vertex_ml

```yaml
componentes:
  - tipo: image
    archivo: image/{dataset_out}/{tabla_out}/
    descripcion: "Docker image con dependencias del modelo (sklearn, xgboost, etc.)"

  - tipo: vertex_pipeline
    archivo: service/vertex/{dataset_out}/{tabla_out}/{nombre}/
    descripcion: "Pipeline KFP — train + inference"

  - tipo: workflow
    archivo: pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-inference.yaml
    descripcion: "Orquestación: lanza pipeline Vertex, espera resultado, notifica por mail"

  - tipo: cloud_scheduler
    archivo: pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-inference.yaml
    descripcion: "Inferencia mensual — dispara el workflow"
```

> `{dataset_out}`/`{tabla_out}` = dataset y tabla de la tabla de predicciones (output del pipeline
> de inferencia) — ver `@.claude/data/standard/factory/repositories.md` §2.

---

## Estructura de carpetas requerida

```
service/vertex/{dataset_out}/{tabla_out}/{nombre-modelo}/
├── src/
│   ├── components.py          ← @dsl.component (preprocess, train, evaluate, predict)
│   ├── pipeline_train.py      ← pipeline de entrenamiento
│   └── pipeline_inference.py  ← pipeline de inferencia
├── notebook/
│   ├── compile_train.ipynb    ← compila y sube pipeline_train.json a GCS
│   └── compile_inference.ipynb
└── deploy/
    ├── deploy_config_train.yaml     ← deploy_config Dataops para pipeline train
    └── deploy_config_inference.yaml ← deploy_config Dataops para pipeline inference
```

> Ver estructura completa y convenciones KFP: `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md`

---

## `env_vars` obligatorias en `deploy_config.yaml`

Para pipelines Vertex AI, el bloque `env_vars` debe incluir:

```yaml
# Bloque 1 — Framework
ENV: ~
PIPELINE_DISPLAY_NAME: ~
PIPELINE_BUCKET: ~

# Bloque 2 — Tablas BigQuery input (por cada fuente)
PROJECT_[TABLA]: ~
DATASET_[TABLA]: ~
TABLE_[TABLA]: ~

# Bloque 3 — Output
PROJECT_ANALYTICS: ~
DATASET_ANALYTICS: ~
TABLE_OUTPUT: ~

# Bloque 4 — Hiperparámetros y recursos
N_ESTIMATORS: ~
MAX_DEPTH: ~
MACHINE_TYPE: ~
REPLICA_COUNT: "1"
```

Variables **auto-inyectadas** (NO van en `env_vars`):
`PIPELINE_PROJECT_ID`, `PIPELINE_SERVICE_ACCOUNT`, `PIPELINE_REGION`, `PIPELINE_COMPILE_FILE`

> Ver detalle completo: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

---

## Reglas de desarrollo para este type

Al ejecutar `/check-rules` sobre un módulo `vertex_ml`, Claude aplica adicionalmente:

1. **Diccionarios de mapeo sin alteraciones** — nombre, claves y valores exactos del notebook origen (Regla 8 de check-rules)
2. **SA tipo `-job`** para Vertex Pipeline y Cloud Scheduler
3. **Image en Artifact Registry** — no usar imágenes públicas en producción
4. **`@dsl.component` con tipos explícitos** — todos los inputs/outputs tipados
5. **Sin lógica de negocio en notebooks** — notebooks solo compilan y suben; la lógica va en `components.py`
6. **Variables de entrada en `env_vars`** — no hardcodear proyectos ni paths GCS

---

## Ejemplo completo

```yaml
id: SPEC-ITC-20260601-001
version: "1.0"
status: draft
type: vertex_ml
empresa: itc
equipo: data-analytics
fecha: "2026-06-01"
autor: amoreno
aprobador: ~

contexto:
  nombre: "Pipeline de Churn Farmacias"
  tipo_flujo: productivizacion-modelo
  descripcion: >
    Productivizar el modelo XGBoost de churn de clientes de Farmacias Peruanas
    en Vertex AI KFP. Genera score mensual en BigQuery.
  objetivo_negocio: >
    Identificar clientes en riesgo de abandono para activar campañas de retención
    con anticipación de 30 días.
  data_owner: "Área de Fidelización Farmacias"
  business_steward: "jfernandez"
  kpis:
    - "AUC-ROC > 0.78 en conjunto de validación"
    - "Score disponible antes del día 5 de cada mes"
    - "Cobertura > 90% de clientes activos en los últimos 3 meses"

etapas:
  plan: true
  design: true
  coding: true
  data_quality: false
  compliance: true
  orchestration: true
  testing: true
  dataops: true
  calidad: true
  security: true
  documentation: true
  monitoreo: true

fuentes:
  - id: attr_education
    descripcion: "Atributo de nivel educativo del cliente"
    proyecto: "${project_ba_itc_attr_education}"
    dataset: "${dataset_ba_itc_attr_education}"
    tabla: "${table_ba_itc_attr_education}"
    volumetria: "~8M clientes activos"
    particion: load_date
    pii: false

  - id: attr_retail
    descripcion: "Atributo de comportamiento retail"
    proyecto: "${project_ba_itc_attr_retail}"
    dataset: "${dataset_ba_itc_attr_retail}"
    tabla: "${table_ba_itc_attr_retail}"
    volumetria: "~8M clientes activos"
    particion: load_date
    pii: false

outputs:
  - tipo: tabla_predicciones
    tabla: ba_itc_churn_farmacias_scores
    proyecto: "${project_analytics}"
    dataset: "${dataset_analytics}"
    descripcion: "Score de churn mensual por cliente activo de Farmacias"
    capa: business
    particion: load_date
    tipo_carga: reemplazo
    campos_auditoria: [load_date, record_source, creation_user]
    pii: false

  - tipo: modelo_artefacto
    gcs_path: "${PIPELINE_BUCKET}/models/churn_farmacias/v1/"
    formato: joblib
    descripcion: "XGBoost + preprocessing pipeline serializado"

modelo:
  nombre: churn_farmacias
  version: v1
  tipo: clasificacion
  framework: xgboost
  target: churn_flag
  metrica_principal: AUC-ROC
  umbral_aceptacion: "> 0.78"
  features_count: 42
  notebook_origen: "notebooks/churn_farmacias_exploration.ipynb"

pipelines:
  train:
    activo: true
    componentes_kfp: [preprocess, train, evaluate, register_model]
    archivo_pipeline: src/pipeline_train.py
    archivo_compilado: "${PIPELINE_BUCKET}/compiled/churn_farmacias_train.json"
    machine_type: n1-standard-4
    reentrenamiento: on-demand

  inference:
    activo: true
    componentes_kfp: [load_model, preprocess, predict, write_output]
    archivo_pipeline: src/pipeline_inference.py
    archivo_compilado: "${PIPELINE_BUCKET}/compiled/churn_farmacias_inference.json"
    machine_type: n1-standard-4
    frecuencia: mensual

componentes:
  - tipo: image
    archivo: image/analytics/ba_itc_churn_farmacias_scores/
    descripcion: "Docker image con xgboost, scikit-learn, pandas, joblib"

  - tipo: vertex_pipeline
    archivo: service/vertex/analytics/ba_itc_churn_farmacias_scores/churn-farmacias/
    descripcion: "Pipelines KFP train e inference"

  - tipo: workflow
    archivo: pipeline/workflow/analytics/ba_itc_churn_farmacias_scores/wf-ba-itc-churn-farmacias-scores-inference.yaml
    descripcion: "Orquestación: lanza pipeline Vertex, espera resultado, notifica por mail"

  - tipo: cloud_scheduler
    archivo: pipeline/scheduler/analytics/ba_itc_churn_farmacias_scores/cs-ba-itc-churn-farmacias-scores-inference.yaml
    descripcion: "Inferencia mensual, día 3 a las 2:00am"

reglas_negocio:
  - id: RN-ITC-001
    descripcion: >
      El diccionario nivel_map para nivel_educativo debe usarse con claves y valores
      exactos del notebook de exploración. No renombrar ni alterar valores.
    criticidad: alta
    campo_afectado: nivel_educativo_encoded
    validado_por: jfernandez

  - id: RN-ITC-002
    descripcion: >
      Clientes sin transacciones en los últimos 90 días se consideran inactivos
      y no se incluyen en la inferencia.
    criticidad: alta
    campo_afectado: churn_flag
    validado_por: jfernandez

seguridad:
  campos_pii_fuente: []
  campos_pii_output: []
  encriptacion_requerida: false
  hash_iden_party: false
  permisos:
    - sa: "${env}-itc-churn-job@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_ba_itc_attr_education}.${dataset_ba_itc_attr_education}"
      permiso: roles/bigquery.dataViewer
    - sa: "${env}-itc-churn-job@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_analytics}.${dataset_analytics}"
      permiso: roles/bigquery.dataEditor

scheduling:
  frecuencia: "0 2 3 * *"
  zona_horaria: America/Lima
  dependencias:
    - "ba_itc_attr_education cargada (lag: D-2 del mes)"
    - "ba_itc_attr_retail cargada (lag: D-2 del mes)"
  consumidores:
    - "Plataforma de campañas de retención Farmacias"
  tiempo_max_ejecucion: 90m

restricciones:
  - No modificar el diccionario nivel_map sin aprobación del Business Steward
  - La versión del modelo en GCS es inmutable — reentrenamiento genera nueva versión (v2, v3...)
  - El pipeline de inferencia lee el modelo desde GCS — no re-entrena en inferencia
```
