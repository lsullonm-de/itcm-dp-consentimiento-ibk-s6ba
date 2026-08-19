# Reglas Generales — Principios del Dominio Data

> Aplica a todos los archivos del repositorio.

---

## Principios de Diseño

### ✅ Idempotencia — los procesos deben poder re-ejecutarse sin efectos secundarios

Cada proceso (SP, workflow, pipeline) debe producir el mismo resultado si se ejecuta múltiples veces con los mismos parámetros. No debe dejar datos corruptos ni duplicados si falla a mitad.

```sql
-- ✅ CORRECTO — MERGE es idempotente
MERGE target AS t USING source AS s
ON t.id = s.id AND t.load_date = s.load_date
WHEN MATCHED THEN UPDATE SET ...
WHEN NOT MATCHED THEN INSERT ...

-- ❌ FRÁGIL — INSERT + DELETE no es idempotente si falla entre ambos
DELETE FROM target WHERE load_date = DATE('${process_date}');
INSERT INTO target SELECT ...;
```

### ✅ Sin efectos secundarios en capas no-output

Los SPs de un proceso no deben modificar tablas fuera de su scope definido en el spec. Solo deben escribir en las tablas que el spec declara como outputs.

### ✅ Trazabilidad — todo output debe tener campos de auditoría

Toda tabla en capa business o master debe tener:
- `load_date DATE` — fecha de carga del proceso
- `record_source STRING` — SP o proceso origen
- `creation_user STRING` — SA o usuario que ejecutó la carga

---

## Variables y Configuración

### ✅ Sin valores hardcodeados — ni en SQL ni en YAML ni en Python

Ningún archivo del repositorio debe contener:
- Nombres de proyectos GCP (`prd-itc-customer-services`) usados directamente en lógica
- Nombres de datasets o tablas concretos hardcodeados fuera de variables de entorno
- Tokens, API keys, passwords
- URLs de servicios internos hardcodeadas

En SQL/YAML todos los valores van como `${variable_dataops}`.
En Python todos los valores van como **variables de entorno** — el framework Dataops los inyecta
vía `env_vars` en `deploy_config.yaml`.

```python
# ✅ CORRECTO — variable de entorno, Dataops inyecta el valor real en despliegue
import os
project_id = os.environ["BQ_PROJECT"]           # falla si no está definida (recomendado en prod)
project_id = os.getenv("BQ_PROJECT", "dev-itc-data-governance")  # fallback para dev local

# ❌ INCORRECTO — valor hardcodeado en lógica sin pasar por variable de entorno
project_id = "prd-itc-customer-services"
query = f"SELECT * FROM prd-itc.analytics.ba_itc_attr_education"
```

> **Regla para fallbacks:** `os.getenv("KEY", "valor-por-defecto")` es válido. El valor por
> defecto facilita el desarrollo local — en despliegue Dataops siempre inyecta el valor real
> vía `env_vars`. Lo que **no** está permitido es usar el valor hardcodeado **fuera** de la
> declaración de la variable de entorno (es decir, en la lógica de negocio directamente).

### ✅ Una variable por concepto — no concatenar proyectos y datasets en una sola variable

```
# ✅ CORRECTO — separados
${project_analytics}
${dataset_analytics}

# ❌ INCORRECTO — concatenados, imposible cambiar por partes
${project_dataset_analytics}  → "prd-itc-customer-services.analytics"
```

---

## Estructura de Repositorios

### ✅ Seguir la estructura estándar de repositorios ITC

```
[repo]/
├── deploy/                                          ← deploy_dev.json, deploy_qa.json, deploy_prd.json
├── data/bigquery/{dataset_out}/{tabla_out}/ddl/     ← CREATE TABLE IF NOT EXISTS
├── data/bigquery/{dataset_out}/{tabla_out}/sp/      ← CREATE OR REPLACE PROCEDURE
├── data/bigquery/{dataset_out}/{tabla_out}/dml/     ← CALL, INSERT (solo dev) + config DQ
├── data/bigquery/{dataset_out}/{tabla_out}/test/    ← tests unitarios de SPs
├── data/lineage/{dataset_out}/{tabla_out}/          ← payloads de linaje
├── data/monitoring/{dataset_out}/{tabla_out}/       ← payloads de control de procesos
├── image/{dataset_out}/{tabla_out}/                 ← YAMLs de Docker
├── service/cloud_run/{dataset_out}/{tabla_out}/     ← deploy_config.yaml, Dockerfile
├── service/cloud_function/{dataset_out}/{tabla_out}/ ← deploy_config.yaml, main.py
├── service/vertex/{dataset_out}/{tabla_out}/        ← pipeline_*.py, deploy_config_*.yaml
└── pipeline/workflow/{dataset_out}/{tabla_out}/     ← workflow YAML (uno por fuente)
    pipeline/scheduler/{dataset_out}/{tabla_out}/    ← cloud scheduler YAML (uno por fuente)
```

> `{dataset_out}` = dataset de la tabla final. `{tabla_out}` = tabla de salida.
> Ver estándar completo: `@.claude/data/standard/factory/repositories.md`

### ❌ No usar `source/` — la carpeta correcta es `data/bigquery/`

```
# ❌ PATRÓN ANTIGUO — no usar
source/business/customer/retail/ddl/

# ✅ PATRÓN CORRECTO
data/bigquery/{dataset_out}/{tabla_out}/ddl/
data/bigquery/{dataset_out}/{tabla_out}/sp/
```

---

## Naming de Objetos

### ✅ Todo en minúsculas y con guiones o underscores según el contexto

| Contexto | Separador | Ejemplo |
|---|---|---|
| Repositorios GCP | `-` guión | `itcm-dp-customer-vuci` |
| Recursos GCP (Cloud Run, Workflow, Scheduler) | `-` guión | `wf-ingreso-vii-inference` |
| Tablas BigQuery | `_` underscore | `ba_itc_attr_retail` |
| Archivos SQL | `_` underscore | `sp_load_attr_retail.sql` |
| Variables Dataops | `_` underscore | `project_ba_itc_attr_retail` |

### ✅ Naming de workflows y schedulers incluye el caso de uso

```
# ✅ CORRECTO — identifica el proceso
wf-ingreso-vii-inference.yaml
cs-ingreso-vii-inference.yaml

# ❌ INCORRECTO — genérico
wf-proceso.yaml
cs-job.yaml
```

---

## Capas de Datos

### ✅ Respetar las capas de datos y no saltar capas

```
RAW   → ingestión directa sin transformación
Master → consolidación y limpieza (m_, t_, c_, h_)
Business → lógica de negocio aplicada (ba_, bm_, dv_, v_)
```

Un SP de capa Business no debe leer directamente de tablas RAW. Si necesita datos RAW debe existir una tabla Master que los haya procesado.

### ✅ Tablas temporales solo en `${dataset_stage}`, nunca en `${dataset_analytics}`

```sql
-- ✅ CORRECTO
CREATE OR REPLACE TABLE `${project_analytics}.${dataset_stage}.tmp_proceso_1` AS (...)

-- ❌ INCORRECTO
CREATE OR REPLACE TABLE `${project_analytics}.${dataset_analytics}.tmp_proceso_1` AS (...)
```

---

## Documentación del Código

### ✅ Cada regla de negocio tiene su comentario `-- [RN-ITC-NNN]`

```sql
-- [RN-ITC-001] Mapeo de estado civil según diccionario aprobado
CASE estado_civil
  WHEN 'S' THEN 1
  WHEN 'C' THEN 2
  ...
```

### ✅ Cada SP de producción tiene un comentario de cabecera

```sql
-- ============================================================
-- SP: sp_prc_prod_mdlo_ingresos_vii_retail
-- Descripción: Prepara variables retail SPSA/FOH para modelo de ingresos VII
-- Parámetros:
--   p_process_date   DATE    — Fecha de corte
--   p_project_output STRING  — Proyecto output
--   p_dataset_stage  STRING  — Dataset stage temporal
-- Destino: ${dataset_stage}.tmp_mi_ejec
-- Autor: [SA/equipo]
-- Fecha: [YYYY-MM-DD]
-- ============================================================
```

---

## Checklist General

- [ ] Estructura de carpetas sigue el estándar (`data/bigquery/`, no `source/`)
- [ ] No hay valores hardcodeados en lógica de negocio (proyectos, datasets, SAs, tokens) — se usan variables de entorno (`os.environ` / `os.getenv`) o `${variables}` Dataops
- [ ] Todo en minúsculas; repositorios y recursos GCP con `-`; BQ y archivos con `_`
- [ ] Tablas temporales en `${dataset_stage}`, no en analytics
- [ ] Todos los outputs tienen campos de auditoría (`load_date`, `record_source`, `creation_user`)
- [ ] Procesos son idempotentes (pueden re-ejecutarse sin duplicados)
- [ ] Cada regla de negocio comentada con `-- [RN-ITC-NNN]`
- [ ] Cada SP tiene comentario de cabecera con descripción, parámetros y destino
- [ ] No se salta capas de datos (RAW → Master → Business)
