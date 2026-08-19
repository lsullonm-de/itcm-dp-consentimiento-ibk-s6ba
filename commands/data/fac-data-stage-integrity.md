# fac-data-stage-integrity — Reglas de Integridad de Fuentes

Implementa el gate de integridad sobre las fuentes RAW del módulo (actualidad de la fuente
principal, con opción de escalar duplicados/llaves nulas) y lo inserta en el workflow, antes
de la carga principal. **No genera tablas ni DML en BigQuery** — el resultado vive en los
parámetros `OUT` del SP de validación, y su histórico se registra en el Framework de Control de
Procesos (`metadata_operational`) vía metadata API.

**Bloque:** BUILD — después de ORCHESTRATION
**Condición:** exclusivo de `type: bq_pipeline`. Para `cloud_run_api`, `cloud_function`, `vertex_ml`
y cualquier otro tipo, `etapas.integridad` siempre es `false` — esta etapa no aplica.

> Cargar skill: `@.claude/data/skills/build/integrity/integrity-rules-assistant/SKILL.md`
> Estándar: `@.claude/data/standard/data-integrity.md`

**Invocación:**
```
fac-data-stage-integrity
fac-data-stage-integrity {id_modulo}
```

---

## Prerequisito — Verificar scaffold y orquestación

Verificar que `fac-data-init-project` y `fac-data-stage-orchestration` ya se ejecutaron:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json
pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml   ← debe existir (se inserta el gate aquí)
```

Si el workflow no existe todavía → detener y avisar:
```
❌ No existe workflow en pipeline/workflow/{dataset_out}/{tabla_out}/.
   Ejecuta fac-data-stage-orchestration antes de fac-data-stage-integrity.
```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: INTEGRIDAD`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.integridad: true` en el spec antes de continuar. Verificar que existe
exactamente 1 fuente con `rol: principal` — si no, detener y pedir corrección vía
`fac-data-spec-update`.

---

## Paso 1 — Leer contexto

Leer en paralelo:
```
1. {ruta del spec.yaml}                                              → fuentes (rol, tipo_fuente, llave, campo_fecha), reglas_integridad (incl. registro_resultados)
2. data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_*.sql    → SP(s) de carga existentes
3. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml              → workflow donde se inserta el gate; verificar si ya trae SyncBigQueryJobWithResults (por monitoring)
4. deploy/env_dev.json · deploy/deploy_dev.json                       → METADATA_API_URL y clave monitoring_register
```

---

## Paso 2 — Generar el SP de integridad (sin tablas en BigQuery)

Determinar qué reglas de `reglas_integridad.reglas[]` tienen `accion: detener_proceso`
(siempre la actualidad de la fuente principal; opcionalmente duplicados/llave_nula si el spec
lo justifica en `restricciones[]`) y generar/completar
`data/bigquery/{dataset_out}/{tabla_out}/sp/sp_integridad_{tabla_out}.sql` con **un bloque
`IF` por regla** — nunca un loop sobre una tabla de configuración:

```sql
CREATE OR REPLACE PROCEDURE `${project_analytics}.${dataset_sp}.sp_integridad_{tabla_out}` (
  IN  p_process_date     DATE,
  OUT o_flag_detener     INT64,
  OUT o_motivo_detencion STRING,
  OUT o_resultado_json   STRING   -- detalle por regla, para el histórico
)
BEGIN
  DECLARE v_motivos ARRAY<STRING> DEFAULT [];
  DECLARE v_resultados ARRAY<STRING> DEFAULT [];
  DECLARE v_tiene_datos BOOL;

  SET o_flag_detener = 0;
  SET o_motivo_detencion = '';
  SET o_resultado_json = '[]';

  -- Bloque por cada regla accion: detener_proceso — evaluación + append de
  -- TO_JSON_STRING(STRUCT(...)) a v_resultados. Ver patrón completo:
  -- @.claude/data/standard/data-integrity.md — Sección 3

  IF ARRAY_LENGTH(v_motivos) > 0 THEN
    SET o_flag_detener = 1;
    SET o_motivo_detencion = ARRAY_TO_STRING(v_motivos, ' | ');
  END IF;

  SET o_resultado_json = '[' || ARRAY_TO_STRING(v_resultados, ',') || ']';
END;
```

> `o_resultado_json` se llena para **toda** regla evaluada, pase o falle — es la fuente del
> histórico que el workflow envía a la metadata API (Paso 5).

---

## Paso 3 — Aplicar patrón de exclusión en los SPs de carga

Para cada fuente con `llave` definida y `accion: excluir_registros` (default), verificar/editar
su query de staging dentro del SP de carga correspondiente para aplicar
`ROW_NUMBER() OVER (...) = 1` + `WHERE {llave} IS NOT NULL`. Ver patrón completo:
`@.claude/data/standard/data-integrity.md` — Sección 4.

---

## Paso 4 — Registrar SP en deploy_[env].json

Agregar el SP de integridad al arreglo `bigquery_sp` de `deploy/deploy_dev.json` (y `deploy_prd.json`),
**después del SP de carga principal** del mismo módulo:

```json
"bigquery_sp": [
  "/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}.sql",
  "/data/bigquery/{dataset_out}/{tabla_out}/sp/sp_integridad_{tabla_out}.sql"
]
```

> El orden importa: el SP de integridad referencia columnas de la tabla de destino —
> el framework lo compila después de que el SP de carga ya existe.

---

## Paso 5 — Matricular las reglas en el catálogo de control de procesos

Solo si `reglas_integridad.registro_resultados: true` (default). Generar un payload por regla
—**todas**, también las de `excluir_registros`— y registrarlos en el deploy:

```
data/integrity/{dataset_out}/{tabla_out}/payloads/integrity_rule_{tabla_out}_{emp}_{nnn}.json
```

```json
"monitoring_register": [
  "/data/monitoring/{dataset_out}/{tabla_out}/payloads",
  "/data/integrity/{dataset_out}/{tabla_out}/payloads"
]
```

Plantilla del payload y reglas de la matrícula:
`@.claude/data/standard/data-integrity.md` — Sección 6.3.

Verificar `METADATA_API_URL` en `env_dev.json` / `env_prd.json`. Si falta:
```
⚠️ registro_resultados: true pero no hay METADATA_API_URL en env_[env].json.
   Agregar la variable o poner registro_resultados: false con justificación en restricciones[].
```

Si `etapas.monitoring: false`, agregar también `process_{tabla_out}_{emp}.json` al directorio
de payloads — sin proceso matriculado la API rechaza las reglas (FK sobre `process_code`).

---

## Paso 6 — Insertar steps de integridad en el workflow

Editar `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml`: insertar
`build_sql_integridad → concatenar_sql_integridad → log_query_integridad →
ejecutar_validacion_integridad (SyncBigQueryJobWithResults) → extraer_resultado_integridad →
registrar_resultado_integridad → evaluar_integridad → error_sin_datos_principal` entre el step
`log_fecha` y el step `ejecutar` (try/except de carga principal). Ver snippet completo:
`@.claude/data/standard/data-integrity.md` — Sección 5.

- `registrar_resultado_integridad` (sub-workflow `RegisterIntegrityResults`, §6.4) va **antes**
  de `evaluar_integridad`: el histórico debe incluir las corridas que se detienen
- El sub-workflow lleva `try/except` propio y solo loguea `WARNING` — un fallo de la metadata
  API nunca detiene el pipeline
- Si `registro_resultados: false`, omitir ese step y el sub-workflow

Si el workflow no tiene el sub-workflow `SyncBigQueryJobWithResults` ni las variables
`var_METADATA_API_URL` / `var_process_code` / `var_execution_id` / `var_user` (porque
`monitoring` no está activo), copiarlos desde
`@.claude/data/standard/factory/monitoring.md` §7.1 y §8.

---

## Paso 7 — Actualizar docs/TODO.md

```
## Etapa completada: INTEGRIDAD
→ Próximo paso: fac-data-stage-monitoring (si aplica) o fac-data-stage-data-quality
```

---

## Reporte

```
## Etapa completada: INTEGRIDAD
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos generados/modificados
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_integridad_{tabla_out}.sql (OUT o_flag_detener / o_motivo_detencion / o_resultado_json)
- ✅ SP(s) de carga con patrón de exclusión aplicado: {lista de fuentes}
- ✅ data/integrity/{dataset_out}/{tabla_out}/payloads/: {n} reglas matriculadas
- ✅ deploy/deploy_dev.json + deploy_prd.json: SP de integridad en bigquery_sp, payloads en monitoring_register
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml: steps de integridad + RegisterIntegrityResults (+ SyncBigQueryJobWithResults si no existía)
- ✅ docs/TODO.md: ítems de INTEGRIDAD marcados

### Trazabilidad habilitada
- Resultados por regla y por corrida en de_datapipeline_integrity_execution
- Consulta: GET {METADATA_API_URL}/api/v1/pipeline-management/pipelines/{process_code}/integrity-execution/status

### Próxima etapa
fac-data-stage-monitoring {id_modulo}    (si etapas.monitoring: true)
fac-data-stage-data-quality {id_modulo}  (si etapas.monitoring: false)
```
