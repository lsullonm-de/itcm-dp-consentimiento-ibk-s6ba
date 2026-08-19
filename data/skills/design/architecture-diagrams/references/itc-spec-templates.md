# Templates de Diagramas ITC — Generación desde `spec.yaml`

> Referencia del skill `architecture-diagrams`. Contiene los 6 templates que mapean los
> bloques del `spec.yaml` de la fábrica de datos a diagramas Mermaid.
> Los carga `fac-data-diagrams` — no duplicar estos templates en ningún comando.

## Matriz de aplicabilidad por `type`

| Diagrama | `bq_pipeline` | `vertex_ml` | `cloud_run_api` | `cloud_function` |
|---|---|---|---|---|
| `context-diagram.md` | ✅ | ✅ | ✅ | ✅ |
| `data-flow-diagram.md` | ✅ | ✅ | — | — |
| `component-diagram.md` | ✅ | ✅ | ✅ | ✅ |
| `sequence-diagram.md` | ✅ | ✅ | ✅ | ✅ |
| `pipeline-diagram.md` | — | ✅ | — | — |
| `deployment-diagram.md` | — | ✅ | ✅ | — |

## Cabecera obligatoria de cada diagrama generado

```markdown
> Generado desde: {spec_id} v{version}
> Actualizado: {YYYY-MM-DD}
> type: {spec.type}
```

Sin esta cabecera, `fac-data-diagrams` no puede detectar si el diagrama quedó desactualizado.

---

### `context-diagram.md` — C4 Level 1

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/c4-context-diagram.md`

Muestra los actores externos (fuentes), el proceso central y los consumidores del output.

```markdown
# Context Diagram — {contexto.nombre}

> Generado desde: {spec_id} v{version} | Actualizado: {fecha}

## Descripción
{contexto.descripcion}

**Objetivo de negocio:** {contexto.objetivo_negocio}
**Data Owner:** {contexto.data_owner} | **Frecuencia:** {scheduling.frecuencia_legible}

## Diagrama

```mermaid
graph LR
    subgraph "Fuentes de Datos"
        {por cada fuente en fuentes[]:}
        SRC_{id}["{fuente.id}<br/>{fuente.descripcion_corta}<br/><i>{fuente.volumetria}</i>"]
    end

    PROC["**{contexto.nombre}**<br/>{type}<br/>{modelo.framework si vertex_ml}"]

    subgraph "Outputs"
        {por cada output tipo tabla:}
        OUT_{tabla}["{output.tabla}<br/>capa: {output.capa}<br/>carga: {output.tipo_carga}"]
    end

    subgraph "Consumidores"
        {por cada consumidor en scheduling.consumidores[]:}
        CON_N["{consumidor}"]
    end

    {fuentes} -->|"load_date"| PROC
    PROC --> {outputs}
    {outputs} --> {consumidores}

    style PROC fill:#1168bd,color:#fff
    style {cada SRC_} fill:#08427b,color:#fff
    style {cada OUT_} fill:#2e7d32,color:#fff
    style {cada CON_} fill:#999,color:#fff
```

## Dependencias de scheduling
{por cada dep en scheduling.dependencias[]:}
- {dep}
```

---

### `data-flow-diagram.md` — Flujo de Datos

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/data-flow-diagram.md`

Muestra la transformación de datos paso a paso desde las tablas de entrada hasta el output.

**Para `bq_pipeline`:**
```markdown
```mermaid
flowchart TD
    subgraph SRC["Capa Entrada"]
        {por cada fuente:}
        F_{id}[("{fuente.id}<br/>{fuente.dataset}<br/>{fuente.tabla}")]
    end

    subgraph PROC["Procesamiento — BigQuery"]
        SP["sp_{tabla_output}()<br/>Stored Procedure"]
        TMP["tmp_{tabla_output}_N<br/>${dataset_stage}"]
        SP --> TMP --> MERGE
        MERGE["INSERT/MERGE → output"]
    end

    subgraph OUT["Capa Salida — {outputs[0].capa}"]
        RES[("{outputs[0].tabla}<br/>Partición: {outputs[0].particion}<br/>Carga: {outputs[0].tipo_carga}")]
    end

    {fuentes} --> SP
    MERGE --> RES

    {si etapas.data_quality:}
    DQ["DQ Framework<br/>itcm-dp-dataquality-core"]
    RES --> DQ
```
```

**Para `vertex_ml`:**
```markdown
```mermaid
flowchart TD
    subgraph SRC["Capa Entrada"]
        {por cada fuente:}
        F_{id}[("{fuente.id}<br/>{fuente.dataset}")]
    end

    subgraph PIPE["Vertex AI Pipeline — {modelo.nombre} v{modelo.version}"]
        direction LR
        {por cada paso en pipelines.inference.componentes_kfp:}
        KFP_{n}["{paso}"]
        {KFP_1 --> KFP_2 --> ...}
    end

    GCS[("GCS<br/>{modelo_artefacto.gcs_path}")]

    subgraph OUT["Capa Salida"]
        PRED[("{tabla_predicciones.tabla}<br/>target: {modelo.target}<br/>Partición: {tabla_predicciones.particion}")]
    end

    {fuentes} --> PIPE
    GCS -->|"load_model"| PIPE
    PIPE --> PRED

    {si etapas.data_quality:}
    DQ["DQ Framework"]
    PRED --> DQ

    style GCS fill:#e65100,color:#fff
    style PRED fill:#2e7d32,color:#fff
```
```

---

### `component-diagram.md` — Componentes GCP

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/component-diagram.md`

Derivado directamente de `componentes[]` del spec. Muestra todos los servicios GCP
y sus relaciones de invocación/dependencia.

```markdown
```mermaid
graph TB
    subgraph ORCH["Orquestación"]
        SCHED["☁️ Cloud Scheduler<br/>cs-{nombre}<br/>{scheduling.frecuencia}"]
        WF["☁️ Cloud Workflow<br/>wf-{nombre}"]
    end

    {si vertex_ml:}
    subgraph PROC["Vertex AI"]
        IMG["🐳 Docker Image<br/>{image.archivo}<br/>Artifact Registry"]
        VERTEX["⚙️ Vertex AI Pipeline<br/>{modelo.nombre} v{modelo.version}<br/>{modelo.framework}"]
        GCS[("🪣 Cloud Storage<br/>{modelo_artefacto.gcs_path_corto}")]
        IMG --> VERTEX
        GCS -->|"modelo pkl/joblib"| VERTEX
    end

    {si bq_pipeline:}
    subgraph PROC["BigQuery"]
        BQ_SP["📋 Stored Procedure<br/>sp_{tabla_output}"]
    end

    subgraph DATA["BigQuery — Datos"]
        {por cada fuente resumida:}
        BQ_SRC[("📊 {fuentes[*].id}<br/>{fuentes[*].dataset}")]
        BQ_OUT[("📊 {outputs[0].tabla}<br/>{outputs[0].dataset}")]
    end

    {si etapas.data_quality:}
    subgraph DQ_BLOCK["Calidad de Datos"]
        DQ_CF["☁️ Cloud Function<br/>func_itc_dq_run_rules_uri<br/>itcm-dp-dataquality-core"]
        DQ_CONF[("📋 dq_config<br/>Reglas matriculadas")]
        DQ_CF -->|"evalúa"| DQ_CONF
    end

    subgraph NOTIF["Notificaciones"]
        PUBSUB["📨 Pub/Sub<br/>{mail_pubsub_topic}"]
        MAIL["📧 Mail<br/>{scheduling.consumidores[0]}"]
        PUBSUB --> MAIL
    end

    SCHED -->|"trigger"| WF
    WF --> PROC
    BQ_SRC -->|"lee"| PROC
    PROC -->|"escribe"| BQ_OUT
    {si dq:} WF -->|"tras output"| DQ_CF
    WF -->|"notifica"| PUBSUB

    style SCHED fill:#7b1fa2,color:#fff
    style WF fill:#7b1fa2,color:#fff
    style VERTEX fill:#1565c0,color:#fff
    style GCS fill:#e65100,color:#fff
    style BQ_OUT fill:#2e7d32,color:#fff
    {si dq:} style DQ_CF fill:#c62828,color:#fff
```
```

---

### `sequence-diagram.md` — Secuencia de Orquestación

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/sequence-diagram.md`

Flujo completo de ejecución desde el trigger hasta la notificación.

```markdown
```mermaid
sequenceDiagram
    autonumber
    participant SCHED as ☁️ Scheduler
    participant WF as ☁️ Workflow
    {si vertex_ml:}
    participant VERTEX as ⚙️ Vertex AI
    {si bq_pipeline:}
    participant BQ as 📊 BigQuery
    {si dq:}
    participant DQ as 🔍 DQ CF
    participant MAIL as 📧 Pub/Sub Mail

    SCHED->>WF: trigger ({scheduling.frecuencia})
    WF->>WF: set_vars(v_billing_project, email_body={})

    Note over WF: Verificar disponibilidad de fuentes
    {por cada dep en scheduling.dependencias:}
    WF->>BQ: check {dep}
    BQ-->>WF: OK

    {si vertex_ml:}
    WF->>VERTEX: run pipeline — {modelo.nombre} v{modelo.version}
    activate VERTEX
    Note over VERTEX: {pipelines.inference.componentes_kfp[0..N]}
    VERTEX->>BQ: read fuentes (fecha_proceso)
    VERTEX->>BQ: write {tabla_predicciones.tabla}
    deactivate VERTEX

    {si bq_pipeline:}
    WF->>BQ: CALL sp_{tabla_output}(fecha_proceso)
    activate BQ
    Note over BQ: tablas tmp → INSERT final
    BQ-->>WF: OK ({n} filas)
    deactivate BQ

    {si dq:}
    WF->>DQ: invocar func_itc_dq_run_rules_uri({tabla_output})
    activate DQ
    Note over DQ: evalúa reglas dq_config
    DQ-->>WF: {passed: N, failed: M}
    deactivate DQ

    WF->>MAIL: publicar resultado proceso
    MAIL-->>WF: ACK
```
```

---

### `pipeline-diagram.md` — Pasos KFP (solo `vertex_ml`)

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/data-flow-diagram.md`

Muestra los componentes `@dsl.component` del pipeline de inferencia y de entrenamiento.

```markdown
# Pipeline Diagram — {modelo.nombre}

> Generado desde: {spec_id} v{version} | Actualizado: {fecha}

## Pipeline de Inferencia
**Machine type:** {pipelines.inference.machine_type} | **Frecuencia:** {pipelines.inference.frecuencia}

```mermaid
flowchart LR
    {por cada paso en pipelines.inference.componentes_kfp:}
    I_{n}["{paso}"]
    {I_1 --> I_2 --> ...}

    style I_1 fill:#1565c0,color:#fff
    style I_{ultimo} fill:#2e7d32,color:#fff
```

## Pipeline de Entrenamiento
**Machine type:** {pipelines.train.machine_type} | **Reentrenamiento:** {pipelines.train.reentrenamiento}

```mermaid
flowchart LR
    {por cada paso en pipelines.train.componentes_kfp:}
    T_{n}["{paso}"]
    {T_1 --> T_2 --> ...}

    style T_1 fill:#7b1fa2,color:#fff
    style T_{ultimo} fill:#2e7d32,color:#fff
```

## Artefactos
| Pipeline | Archivo fuente | Compilado GCS |
|---|---|---|
| Inference | `{pipelines.inference.archivo_pipeline}` | `{pipelines.inference.archivo_compilado}` |
| Train | `{pipelines.train.archivo_pipeline}` | `{pipelines.train.archivo_compilado}` |
```

---

### `deployment-diagram.md` — Despliegue GCP (vertex_ml / cloud_run_api)

Referencia: `@.claude/data/skills/design/architecture-diagrams/references/deployment-diagram.md`

Muestra los proyectos GCP y la ubicación física de cada componente.

```markdown
```mermaid
graph TB
    subgraph PRJ_SRC["Proyectos fuente"]
        {por cada proyecto distinto en fuentes[]:}
        DS_{proyecto}[("{fuentes.proyecto}<br/>{fuentes.dataset}")]
    end

    subgraph PRJ_CTRL["${env}-itc-customer-services<br/>(control / procesamiento)"]
        WF_NODE["Cloud Workflow"]
        SCHED_NODE["Cloud Scheduler"]
        {si vertex_ml:}
        VERTEX_NODE["Vertex AI Pipeline<br/>region: us-central1"]
        AR["Artifact Registry<br/>Docker image"]
    end

    subgraph PRJ_ANALYTICS["${project_analytics}<br/>(analytics / output)"]
        BQ_OUT_NODE[("BigQuery<br/>${dataset_analytics}<br/>{outputs[0].tabla}")]
        {si bucket:}
        GCS_NODE[("Cloud Storage<br/>{bucket_mlops}<br/>modelos + pipelines compilados")]
    end

    {si dq:}
    subgraph PRJ_DQ["itcm-dp-dataquality-core"]
        CF_DQ["Cloud Function<br/>func_itc_dq_run_rules_uri"]
    end

    SCHED_NODE -->|"trigger"| WF_NODE
    WF_NODE -->|"run pipeline"| VERTEX_NODE
    VERTEX_NODE -->|"lee"| DS_{fuente_1}
    VERTEX_NODE -->|"escribe"| BQ_OUT_NODE
    GCS_NODE -->|"modelos"| VERTEX_NODE
    {si dq:} WF_NODE -->|"invoca"| CF_DQ

    style PRJ_CTRL fill:#e3f2fd,stroke:#1565c0
    style PRJ_ANALYTICS fill:#e8f5e9,stroke:#2e7d32
    {si dq:} style PRJ_DQ fill:#fce4ec,stroke:#c62828
```
```

---

