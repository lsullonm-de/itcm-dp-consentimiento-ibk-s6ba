# Cómo se construyeron los skills

---

## `customer-attributes-developer/SKILL.md`

```mermaid
flowchart TD
    subgraph INPUTS["📥 INPUTS "]
        A["📋 OPERATIVA 
        Rol, capacidades y requerimientos"]
        B["📚 BUSINESS GLOSSARY
        37 archivos · tablas, volumetría, joins"]
        C["🗄️ REPOSITORIO VUCI
        DDL, SPs, patrones de código"]
        D["📐 ESTÁNDARES 
        Naming, capas, buenas prácticas SQL"]
    end

    subgraph PROCESO["⚙️ ANÁLISIS Y SÍNTESIS"]
        E["🗺️ Mapeo del modelo de datos"]
        F["🔧 Patrones de desarrollo"]
        G["🔗 Guía requerimiento → tabla fuente"]
    end

    subgraph OUTPUT["📤 OUTPUT"]
        H["📄 customer-attributes-developer/SKILL.md
        "]
    end

    A --> E & G
    B --> E & G
    C --> F & E
    D --> F & G

    E --> H
    F --> H
    G --> H
```

| Input | Qué aportó |
|---|---|
| **Descripción del usuario** | Rol, capacidades (desarrollo y mantenimiento de atributos), alcance sin insights |
| **Catálogo de Datos** | Mapa de tablas: volumetría, particiones, campos de JOIN, guía requerimiento→tabla |
| **Scripts reales del repo** | Patrón `EXECUTE IMMEDIATE`, firma de SPs, cadena tmp, DDL `ALTER TABLE` |
| **Estándares knowledge-base** | Naming, capas de arquitectura, buenas prácticas BigQuery |

> Renombrado desde `insights-attr-dev-agent.md` — eliminadas capacidades de generación de insights e identificación de segmentos. Brief Técnico se incorporó como sección obligatoria.

---

## `dataops-configurator/SKILL.md`

```mermaid
flowchart TD
    subgraph INPUTS["📥 INPUTS"]
        A["📋 Descripción del usuario\nProyectos, datasets y variables\nde despliegue · reglas Vertex AI"]
        B["📄 Manual Dataops PDF\nManual de Uso Framework ITC"]
        C["🔧 Scripts bash del framework\nitcm-dp-dataops-build/build/bash/"]
        D["📦 Repos canónicos del ecosistema\nYAMLs reales por componente"]
    end

    subgraph PROCESO["⚙️ ANÁLISIS Y SÍNTESIS"]
        E["🗂️ Catálogo de componentes\nDDL · SP · DML · Image · CR · CF\nWorkflow · Vertex · PubSub · Scheduler"]
        F["🔧 Flags y estructura de cada YAML"]
        G["🔗 Convenciones _DATAOPS_VARIABLES\ny cadena dataops_variable"]
    end

    subgraph OUTPUT["📤 OUTPUT"]
        H["📄 SKILL.md (dataops-configurator)
─────────────────\nRol del agente\nYAML por componente (10 tipos)\nConvenciones _DATAOPS_VARIABLES\nenv_vars Vertex AI\nCadena de dependencias"]
    end

    A --> G
    B --> E & F & G
    C --> F & G
    D --> F & E

    E --> H
    F --> H
    G --> H
```

| Input | Qué aportó |
|---|---|
| **Descripción del usuario** | Estructura de proyectos/datasets, variables de despliegue, reglas Vertex AI |
| **Manual Dataops PDF** | Flujo completo del framework, componentes soportados, orden de ejecución |
| **Scripts bash del framework** | Flags exactos por componente, parámetros requeridos vs. opcionales |
| **Repos canónicos** | YAMLs reales, patrones `dataops_variable`, `env_vars` de producción |

---

## `mlops-framework-developer/SKILL.md`

```mermaid
flowchart TD
    subgraph INPUTS["📥 INPUTS"]
        A["📋 Descripción del usuario\nTransformar código Python/notebooks\nal framework Vertex AI KFP"]
        B["📄 Framework Modelos ML v1.0\nDocx + PDF · Proceso oficial"]
        C["📦 Repo canónico de referencia\nservice/vertex/itc-recommendation-ml-model/"]
        D["📐 Skill Dataops
dataops-configurator/SKILL.md"]
    end

    subgraph PROCESO["⚙️ ANÁLISIS Y SÍNTESIS"]
        E["🏗️ Estructura de proyecto\nsrc/ · notebook/ · deploy/"]
        F["🔧 Patrón de componentes KFP\n@dsl.component · train · inference"]
        G["⚙️ Integración con Dataops\ndeploy_config YAMLs · env_vars"]
    end

    subgraph OUTPUT["📤 OUTPUT"]
        H["📄 mlops-framework-developer/SKILL.md\n─────────────────\nRol del agente\nEstructura de proyecto\nComponentes KFP train/inference\nNotebooks de compilación\ndeploy_config YAMLs\nenv_vars obligatorias\nChecklist infraestructura GCP"]
    end

    A --> E & F
    B --> E & F & G
    C --> E & F
    D --> G

    E --> H
    F --> H
    G --> H
```

| Input | Qué aportó |
|---|---|
| **Descripción del usuario** | Objetivo: transformar código externo al framework ITC; casos de uso |
| **Framework Modelos ML v1.0** | Proceso oficial, estructura de carpetas, convenciones KFP, checklist GCP |
| **Repo canónico** | Estructura real de `src/components.py`, notebooks de compilación, YAMLs reales |
| **Skill Dataops** | Integración con el framework de despliegue: `deploy_config`, `env_vars`, `vertex_pipeline` |
