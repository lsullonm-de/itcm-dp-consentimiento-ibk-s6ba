# C4 Container Diagram (Nivel 2)

El **Container Diagram** descompone el sistema del C4 Context en sus contenedores
ejecutables: aplicaciones web, APIs, bases de datos, colas de mensajes, pipelines, etc.
Cada contenedor es una unidad desplegable de forma independiente.

> **Cuándo usar:** cuando el Context Diagram ya está aprobado y el equipo necesita
> entender qué tecnologías componen el sistema y cómo se comunican entre sí.

---

## Ejemplo genérico — plataforma de datos (GCP)

```mermaid
graph TB
    %% Actores externos
    Analyst["👤 Analista de Negocio<br/>(usuario externo)"]
    MLEngineer["👤 ML Engineer<br/>(usuario interno)"]

    subgraph boundary["Sistema: Plataforma de Datos ITC [GCP]"]

        subgraph orchestration["Orquestación"]
            Scheduler["Cloud Scheduler<br/>[GCP Cloud Scheduler]<br/>Dispara el pipeline mensual"]
            Workflow["Workflow<br/>[GCP Cloud Workflows]<br/>Coordina pasos del proceso"]
        end

        subgraph compute["Cómputo"]
            VertexPipeline["Vertex AI Pipeline<br/>[KFP / Kubeflow]<br/>Ejecuta componentes ML"]
            VertexJob["Vertex AI Job<br/>[GCP Vertex AI]<br/>Entrena modelos"]
        end

        subgraph storage["Almacenamiento"]
            BQStage["BigQuery Stage<br/>[Google BigQuery]<br/>Tablas temporales (tmp_*)"]
            BQAnalytics["BigQuery Analytics<br/>[Google BigQuery]<br/>Tablas de salida (ba_*, bm_*)"]
            GCSModels["GCS Bucket<br/>[Google Cloud Storage]<br/>Artefactos .pkl del modelo"]
        end

        subgraph notifications["Notificaciones"]
            PubSub["Pub/Sub Topic<br/>[GCP Pub/Sub]<br/>Publica eventos de estado"]
            MailService["Mail Service<br/>[Cloud Function]<br/>Envía alertas por correo"]
        end

    end

    %% Fuentes externas
    SourceBQ["BigQuery Fuentes<br/>[intercorp-data-storage-pv]<br/>Atributos de cliente, POS, RCC"]

    %% Relaciones
    Scheduler -->|"dispara (cron)"| Workflow
    Workflow -->|"ejecuta pipeline"| VertexPipeline
    VertexPipeline -->|"lee features"| SourceBQ
    VertexPipeline -->|"escribe tablas stage"| BQStage
    VertexPipeline -->|"carga modelos"| GCSModels
    VertexPipeline -->|"escribe predicciones"| BQAnalytics
    Workflow -->|"publica evento"| PubSub
    PubSub -->|"trigger"| MailService
    BQAnalytics -->|"consulta"| Analyst
    GCSModels -->|"versiona modelos"| MLEngineer

    %% Estilos
    style Scheduler fill:#e8f4f8,stroke:#0277bd
    style Workflow fill:#e8f4f8,stroke:#0277bd
    style VertexPipeline fill:#e8f5e9,stroke:#2e7d32
    style VertexJob fill:#e8f5e9,stroke:#2e7d32
    style BQStage fill:#fff8e1,stroke:#f9a825
    style BQAnalytics fill:#fff8e1,stroke:#f9a825
    style GCSModels fill:#fff8e1,stroke:#f9a825
    style PubSub fill:#fce4ec,stroke:#c62828
    style MailService fill:#fce4ec,stroke:#c62828
    style SourceBQ fill:#f5f5f5,stroke:#9e9e9e
    style Analyst fill:#ede7f6,stroke:#4527a0
    style MLEngineer fill:#ede7f6,stroke:#4527a0
```

---

## Convenciones del C4 Container Diagram

| Elemento | Representación | Descripción |
|----------|---------------|-------------|
| Contenedor interno | Nodo con subgraph + tecnología entre `[]` | Unidad desplegable del sistema |
| Sistema externo | Nodo fuera del boundary, color gris | Sistema que el tuyo consume o del que dependes |
| Actor / Usuario | Nodo con ícono 👤, fuera del boundary | Persona que interactúa con el sistema |
| Relación | Flecha con etiqueta describiendo el protocolo/acción | Comunicación entre contenedores |

### Leyenda de colores recomendada (ITC)

| Color | Significado |
|-------|------------|
| `#e8f4f8` azul claro | Orquestación (Scheduler, Workflow) |
| `#e8f5e9` verde claro | Cómputo / ML (Vertex AI, Cloud Run) |
| `#fff8e1` amarillo claro | Almacenamiento (BigQuery, GCS, Cloud SQL) |
| `#fce4ec` rosa claro | Eventos / Notificaciones (Pub/Sub, CF) |
| `#f5f5f5` gris | Sistemas externos |
| `#ede7f6` violeta claro | Actores / Usuarios |

---

## Plantilla mínima

```mermaid
graph TB
    UserA["👤 Actor<br/>(rol)"]

    subgraph boundary["Sistema: Nombre [Plataforma]"]
        ContainerA["Nombre Contenedor A<br/>[Tecnología]<br/>Responsabilidad"]
        ContainerB["Nombre Contenedor B<br/>[Tecnología]<br/>Responsabilidad"]
        DB[("Base de Datos<br/>[Tecnología]<br/>Qué almacena")]
    end

    ExternalSystem["Sistema Externo<br/>[Tecnología]<br/>Qué provee"]

    UserA -->|"acción"| ContainerA
    ContainerA -->|"protocolo/acción"| ContainerB
    ContainerB -->|"lee/escribe"| DB
    ContainerA -->|"llama API"| ExternalSystem
```

---

## Relación con los otros niveles C4

| Nivel | Diagrama | Pregunta que responde |
|-------|----------|----------------------|
| L1 | [Context](c4-context-diagram.md) | ¿Quién usa el sistema y con qué otros sistemas se integra? |
| **L2** | **Container** *(este archivo)* | **¿Qué tecnologías componen el sistema y cómo se comunican?** |
| L3 | [Component](component-diagram.md) | ¿Qué componentes hay dentro de cada contenedor? |
| L4 | [Class / Code](class-diagram.md) | ¿Cómo está implementado cada componente? |
