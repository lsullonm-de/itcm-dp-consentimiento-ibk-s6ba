# fac-data-stage-coding — Implementación de Código

Implementa DDL y SP con lógica de negocio completa, y el código de servicio según el tipo
de módulo (KFP components, FastAPI, Cloud Function).

**Bloque:** BUILD — primer paso
**Invocación:**
```
fac-data-stage-coding
fac-data-stage-coding {id_modulo}   ← módulo específico del project.manifest.yaml
```

> **Prerequisito:** PHYSICAL_DESIGN completado — el **contrato de datos** (DDL físico) está
> definido y el scaffold del repo existe.
>
> CODING **crea desde cero** los archivos de código del servicio (SPs, componentes KFP, FastAPI,
> Cloud Function). PHYSICAL_DESIGN ya no deja skeletons con `TODO`: producir archivos que esta
> etapa reescribe entera solo genera ruido en el diff y estados intermedios que no ejecutan.

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json · data/bigquery/
```
Si no existe → ejecutar `fac-data-init-project` automáticamente antes de continuar.

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` en $ARGUMENTS → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: CODING` en el manifest
3. Si hay ambigüedad → listar módulos activos y pedir al usuario que especifique

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.coding: true` en el spec antes de continuar.

---

## Paso 1 — Cargar skill

**Skill a cargar según `type`:**

| `type` | Skill |
|---|---|
| `bq_pipeline` (DDL + SP) | `@.claude/data/skills/build/coding/bigquery-pipeline-developer/SKILL.md` |
| `vertex_ml` (DDL + SP + KFP) | `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md` |
| `cloud_run_api` | `@apps/skills/api-dev-agent.md` |
| `cloud_function` | skill CF (futuro) |

> Para repos del dominio de atributos de cliente (`itcm-dp-vuci-customer`), usar
> `@.claude/data/skills/build/coding/customer-attributes-developer/SKILL.md` en su lugar.

Leer en paralelo:
```
1. {ruta del spec.yaml}            → fuente de verdad del módulo
2. deploy/env_dev.json             → variables de despliegue actuales
3. Archivos existentes de la etapa → para no sobreescribir trabajo hecho
```

---

## Paso 2 — Implementar DDL

Completar `data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql` con todas las columnas
definidas en PHYSICAL_DESIGN:
- Usar `CREATE TABLE IF NOT EXISTS`
- Partición por `load_date` (default para tablas business)
- Clustering en campos de consulta frecuente (opcional)
- Labels GCP: `{"env": "${env}", "team": "data-platform"}`
- Descripción de tabla y columnas en `OPTIONS`

```sql
CREATE TABLE IF NOT EXISTS `${project_analytics}.${dataset_analytics}.{tabla}`
(
  iden_party_hash    STRING  OPTIONS (description = 'Hash SHA256 tipo_doc+nro_doc'),
  -- ... columnas de negocio

  -- Auditoría
  load_date          DATE,
  record_source      STRING,
  creation_user      STRING
)
PARTITION BY load_date
OPTIONS (
  description = '{descripcion del output}',
  labels      = [("team", "data-platform")]
);
```

---

## Paso 3 — Implementar SP

Por cada fuente `{emp}` en `fuentes[]`, completar `data/bigquery/{dataset_out}/{tabla_out}/sp/
sp_{tabla_out}_{emp}.sql`:
- Todas las referencias a tablas con `${project_*}.${dataset_*}.${table_*}` — **nunca hardcodeadas**
- SP creado en `${project_operation}.${dataset_sp}` — **no** en `project_analytics`
- Tablas temporales en `${project_operation}.${dataset_stage}.tmp_{tabla_out}_{emp}`
- Implementar cada RN del spec con comentario `-- [RN-ITC-NNN]`
- Respetar diccionarios de mapeo exactamente como están en el spec
- Cierre con INSERT/MERGE a `${project_analytics}.${dataset_analytics}.{tabla_out}` con campos de auditoría

> Si hay múltiples fuentes, **no** consolidar en un solo SP — un SP por fuente, todos en la
> misma carpeta `{dataset_out}/{tabla_out}/sp/` (ver `@.claude/data/standard/factory/repositories.md` §3).

Ver: `@.claude/data/standard/bigquery/development.md` — Secciones de SPs y manejo de temporales.

---

## Paso 4 — Verificar nomenclatura

- Objetos BQ: aplicar prefijos y naming del estándar
- Variables: seguir el patrón `${project_*}`, `${dataset_*}`, `${table_*}`
- Ningún valor hardcodeado de proyecto, dataset o tabla

---

## Paso 5 — Crear tests unitarios de SPs (`bq_pipeline`)

Para cada SP con lógica de negocio (uno por fuente), crear `data/bigquery/{dataset_out}/
{tabla_out}/test/test_sp_{tabla_out}_{emp}.sql`.

```sql
-- test/bigquery/test_sp_nombre.sql

-- 1. Setup: datos de entrada controlados
CREATE OR REPLACE TEMP TABLE tmp_test_input AS
SELECT ... -- casos: válido, borde, exclusión

-- 2. Invocar el SP apuntando a dataset de test aislado
CALL `{project}.stored_procedures.sp_nombre`(
  DATE '{fecha_prueba}',
  '{project}',
  'test_analytics',   -- dataset aislado, nunca el dataset de producción
  'stage_tmp',
  'stored_procedures',
  'tmp_test_input',
  'nombre_tabla_output'
);

-- 3. Assertions con ASSERT + mensaje descriptivo
DECLARE resultado INT64;
SET resultado = (SELECT COUNT(*) FROM `{project}.test_analytics.nombre_tabla_output`
                 WHERE process_date = '{fecha_prueba}');

ASSERT resultado = {valor_esperado}
  AS 'T2: se esperaban {valor_esperado} filas, se obtuvo ' || CAST(resultado AS STRING);

-- 4. Cleanup
DROP TABLE IF EXISTS `{project}.test_analytics.nombre_tabla_output`;
```

> Los tests se crean en CODING (junto al SP) y se **ejecutan** en `fac-data-stage-testing`.

---

## Paso 6 — Actualizar docs/TODO.md

Marcar ítems de CODING completados.

```
## Etapa completada: CODING
→ Próximo paso: fac-data-stage-orchestration (o fac-data-stage-monitoring si aplica)
```

---

## Routing por tipo: comportamiento específico

> En todos los casos CODING **crea** los archivos de código; no los completa. El único
> artefacto que llega hecho desde PHYSICAL_DESIGN es el DDL (contrato de datos).

### `cloud_run_api`

| Bloque | Qué hace |
|---|---|
| CODING | Crear la estructura FastAPI completa — `model/` (Pydantic con `extra="forbid"` y `Literal` espejando los CHECK del DDL), `router/` (un `APIRouter` por recurso), `function/` (reglas de negocio), `repository/` (reutilizar el genérico; archivo propio solo si hay SQL a mano). Registrar los routers en `main.py`, agregar las tablas a `TABLE_RESOURCE_LABELS` de `utils/response.py`, y el DDL PostgreSQL si aplica |

### `vertex_ml`

| Bloque | Qué hace |
|---|---|
| CODING | **DDL/SP** con lógica BQ completa + crear `src/__init__.py`, `src/components.py` (un `@dsl.component` por paso, tipos explícitos), `src/pipeline_inference.py` (encadenado con `.after()` y límites CPU/memoria), `notebook/pipeline-inference.ipynb` (5 celdas: instalación → vars dev → compilación → upload GCS → ejecución comentada) y `requirements.txt` |

### `cloud_function`

| Bloque | Qué hace |
|---|---|
| CODING | **DDL/SP** si aplica + crear `main.py` con entry point, manejo de errores e idempotencia |

---

## Reporte

```
## Etapa completada: CODING
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos modificados
- ✅ data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql     (DDL con lógica completa)
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql  (SP con lógica de negocio, uno por fuente)
- ✅ data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_*.sql (tests unitarios — bq_pipeline)
- ✅ docs/TODO.md: ítems de CODING marcados

### Pendientes (si los hay)
- ⬜ {archivo}: {razón}

### Próxima etapa
fac-data-stage-orchestration {id_modulo}
```
