# Skill: Integrity Rules Assistant

> **Rol:** Desarrollador de Integridad de Fuentes — ITC Data Platform
> **Activado por:** `/data:implement-stage INTEGRIDAD` (o `fac-data-stage-integrity`) cuando `etapas.integridad: true` en el spec
> **Aplica a:** módulos de tipo `bq_pipeline` (y cualquier línea que declare `fuentes` con `reglas_integridad`)
>
> **Estándares de referencia:**
> - `@.claude/data/standard/data-integrity.md` — SP de integridad (`OUT` params, sin tablas BQ), patrón de exclusión, integración en workflow, §6 registro histórico
> - `@.claude/data/standard/factory/spec-manifest.md` — schema de `fuentes[].rol/tipo_fuente/llave/campo_fecha` y del bloque `reglas_integridad` (incl. `registro_resultados`)
> - `@.claude/data/standard/factory/monitoring.md` §3-4, §6-9 — Framework de Control de Procesos: tablas, endpoints, matrícula vía API, patrón SP con `OUT` + `SyncBigQueryJobWithResults`
> - `@.claude/data/standard/services/workflow.md` — Regla 2b: posición de los steps de integridad en el workflow

---

## 1. Rol y Responsabilidades

El **Integrity Rules Assistant** implementa el gate de integridad de fuentes **antes** de la
carga principal de cada módulo. El SP de validación **no escribe en ninguna tabla BigQuery**:
todo su resultado vive en parámetros `OUT`. El histórico de esos resultados sí se persiste —
lo envía el workflow al Framework de Control de Procesos (`metadata_operational`, vía metadata
API), igual que MONITORING registra las ejecuciones de tareas.

1. Identificar la fuente principal (universo) y las fuentes secundarias del spec
2. Determinar cómo se identifica la actualidad de cada fuente (`tabla` vs `archivo`)
3. Generar el SP de validación con solo las reglas `accion: detener_proceso`, devolviendo también el detalle por regla en `o_resultado_json`
4. Asegurar que los SPs de carga apliquen el patrón de exclusión de duplicados/llaves nulas para las reglas `accion: excluir_registros`
5. Generar los payloads de matrícula de las reglas y registrarlos en `deploy_[env].json`
6. Insertar los steps de integridad en el workflow del módulo (con `SyncBigQueryJobWithResults` + `RegisterIntegrityResults`), antes de la carga principal

---

## Paso 0 — Leer contexto

Leer en paralelo:

```
1. {ruta del spec.yaml}                                              → fuentes (rol, tipo_fuente, llave, campo_fecha), reglas_integridad (incl. registro_resultados)
2. data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_*.sql    → SP(s) de carga existentes (para insertar el patrón de exclusión)
3. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml              → workflow existente donde se integrará el gate (y si ya trae SyncBigQueryJobWithResults por monitoring)
4. deploy/env_dev.json · deploy/deploy_dev.json                       → METADATA_API_URL y clave monitoring_register (para la matrícula de reglas)
```

Verificar que `etapas.integridad: true` en el spec. Si es `false`:
```
❌ etapas.integridad = false en el spec.
   Esta etapa no aplica para este módulo.
   Usa fac-data-spec-update "etapas: activar integridad" si es necesario.
```

Verificar que existe **exactamente 1** fuente con `rol: principal`. Si no:
```
❌ El spec no declara ninguna fuente con rol: principal (o declara más de una).
   Fix: fac-data-spec-update "fuentes: marcar {id} como rol principal"
```

---

## Paso 1 — Clasificar fuentes y completar campos faltantes

Para cada fuente en `fuentes[]`:

| Campo | Si falta (`~`), inferir de |
|---|---|
| `tipo_fuente` | `data/bigquery/**/ddl/*.sql` (si existe tabla física con `PARTITION BY` → `tabla`); si la fuente viene de GCS/CSV en el spec/descripción → `archivo` |
| `llave` | Columnas mencionadas como identificador en `reglas_negocio` o DDL (`PRIMARY KEY` lógico, `id`, `party_id`, `iden_party_hash`, etc.) |
| `campo_fecha` | Si `tipo_fuente: tabla` → `fuentes[].particion` si existe, sino `load_date`. Si `tipo_fuente: archivo` → buscar patrón de fecha en nombre de archivo (`_FILE_NAME`) o campo `load_date` dentro del archivo |

Si no se puede inferir con confianza → dejar `~` y advertir en el reporte (Paso 6).

---

## Paso 2 — Determinar qué reglas gatean el proceso (`accion: detener_proceso`)

Leer `reglas_integridad.reglas[]` del spec y separar:

| `tipo_check` | `accion` por default | ¿Genera código en el SP de integridad? |
|---|---|---|
| `actualidad` (solo fuente `rol: principal`) | `detener_proceso` (obligatorio) | **Sí** — siempre |
| `duplicados` / `llave_nula` (cualquier fuente) | `excluir_registros` (default) | No — se resuelve en el SP de carga (Paso 4) |
| `duplicados` / `llave_nula` con `accion: detener_proceso` explícito | Excepción documentada en `restricciones[]` del spec | **Sí** — un bloque `IF` adicional |

El resultado de este paso es la lista de reglas que efectivamente van dentro del SP de
integridad — normalmente solo 1 (la actualidad de la fuente principal).

---

## Paso 3 — Generar/completar el SP de integridad (`sp_integridad_{tabla_out}.sql`)

Crear o completar `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_integridad_{tabla_out}.sql`
con la firma `(IN p_process_date DATE, OUT o_flag_detener INT64, OUT o_motivo_detencion STRING,
OUT o_resultado_json STRING)` y **un bloque `IF` por cada regla identificada en el Paso 2** —
nunca un loop sobre una tabla de configuración. Ver patrón completo y ejemplo en
`@.claude/data/standard/data-integrity.md` — Sección 3.

Reglas de generación:
- `o_flag_detener`, `o_motivo_detencion` y `o_resultado_json` se inicializan en `0` / `''` / `'[]'`
  después de todos los `DECLARE`
- Cada regla que falla agrega un string a un `ARRAY<STRING> v_motivos` vía `ARRAY_CONCAT`
- **Cada regla evaluada** — falle o no — agrega un `TO_JSON_STRING(STRUCT(...))` a
  `ARRAY<STRING> v_resultados` con `rule_code`, `source_id`, `check_type`, `check_action`,
  `integrity_status_code` (`PASSED`/`FAILED`), `flag_stop_process`, `records_evaluated`,
  `records_affected` y `stop_reason`
- El `rule_code` es literalmente el `id` de la regla en `reglas_integridad.reglas[]` del spec
- `records_evaluated` sale del mismo `COUNT(*)` que decide la regla — no agregar una query extra
- Al final: si `ARRAY_LENGTH(v_motivos) > 0` → `o_flag_detener = 1` y
  `o_motivo_detencion = ARRAY_TO_STRING(v_motivos, ' | ')`; y siempre
  `o_resultado_json = '[' || ARRAY_TO_STRING(v_resultados, ',') || ']'`
- **No** generar ningún `CREATE TABLE`, `INSERT` ni referencia a un dataset de catálogo BigQuery

---

## Paso 4 — Aplicar el patrón de exclusión en los SPs de carga

Para cada fuente con `llave` definida y `accion: excluir_registros` (el caso por default),
verificar que su query de staging dentro del SP de carga (`sp_{tabla_out}_{fuente}.sql`) usa
el patrón de la Sección 4 de `@.claude/data/standard/data-integrity.md`:

```sql
SELECT * EXCEPT(rn)
FROM (
  SELECT t.*, ROW_NUMBER() OVER (PARTITION BY {llave} ORDER BY {campo_fecha} DESC) AS rn
  FROM `{asset_fuente}` t
  WHERE {llave_col_1} IS NOT NULL
)
WHERE rn = 1
```

Si el SP existente lee la fuente con un `SELECT * FROM {asset}` plano → reemplazar por el
patrón anterior. Esta es la **única** exclusión real de duplicados/llaves nulas — el SP de
integridad del Paso 3 no las evalúa cuando `accion: excluir_registros`.

---

## Paso 5 — Generar los payloads de matrícula de las reglas

Solo si `reglas_integridad.registro_resultados` es `true` (el default). Un archivo JSON por
cada regla de `reglas_integridad.reglas[]` — **todas**, incluidas las de
`accion: excluir_registros`, porque el catálogo describe qué controla el módulo:

```
data/integrity/{dataset_out}/{tabla_out}/payloads/integrity_rule_{tabla_out}_{emp}_{nnn}.json
```

Cada payload se arma cruzando la regla con su fuente en `fuentes[]` (`source_role`,
`source_asset`, `key_columns`, `date_field`) y con el proceso (`process_code` = nombre del
workflow, `task_code` = FQN del SP de integridad). Plantilla completa:
`@.claude/data/standard/data-integrity.md` — Sección 6.3.

Luego agregar el directorio a `monitoring_register` en `deploy/deploy_dev.json` y
`deploy_prd.json`, **después** del directorio de monitoring:

```json
"monitoring_register": [
  "/data/monitoring/{dataset_out}/{tabla_out}/payloads",
  "/data/integrity/{dataset_out}/{tabla_out}/payloads"
]
```

Verificar que `METADATA_API_URL` existe en `env_dev.json` / `env_prd.json`. Si no está:

```
⚠️ registro_resultados: true pero falta METADATA_API_URL en env_[env].json.
   Fix: agregar la variable (ver @.claude/data/standard/factory/monitoring.md §10)
   o poner reglas_integridad.registro_resultados: false y justificarlo en restricciones[].
```

Si `etapas.monitoring: false`, el proceso no está matriculado por MONITORING → agregar también
`process_{tabla_out}_{emp}.json` en el mismo directorio de payloads (plantilla en
`@.claude/data/standard/factory/monitoring.md` §6); sin proceso no hay dónde colgar las reglas.

---

## Paso 6 — Insertar steps de integridad en el workflow

Editar `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml`:
insertar `build_sql_integridad → concatenar_sql_integridad → log_query_integridad →
ejecutar_validacion_integridad (SyncBigQueryJobWithResults) → extraer_resultado_integridad →
registrar_resultado_integridad → evaluar_integridad → error_sin_datos_principal` **entre** el
step `log_fecha` (fin de la normalización de `process_date`) y el step `ejecutar` (bloque `try`
de la carga principal). Ver snippet completo:
`@.claude/data/standard/data-integrity.md` — Sección 5.

- El `SELECT` final del script construido devuelve **3 columnas**; `extraer_resultado_integridad`
  hace `json.decode` de la tercera (`resultado_json`)
- `registrar_resultado_integridad` va **antes** de `evaluar_integridad` — así también queda
  registrada la corrida que detiene el proceso
- Agregar el sub-workflow `RegisterIntegrityResults` al final del archivo
  (`@.claude/data/standard/data-integrity.md` §6.4). Debe llevar su propio `try/except` que solo
  loguea `WARNING`: si la metadata API falla, el pipeline continúa
- Si `registro_resultados: false`, omitir el step y el sub-workflow — el resto del gate es igual

Si el archivo de workflow **no** tiene ya el sub-workflow `SyncBigQueryJobWithResults`
(porque `etapas.monitoring` no está activo) → copiarlo al final del archivo desde
`@.claude/data/standard/factory/monitoring.md` §8 (reutiliza el `BigQueryJobState` que ya
existe en todo workflow). Si `etapas.monitoring: true` ya lo agregó, no duplicarlo. Lo mismo
aplica a las variables `var_METADATA_API_URL`, `var_process_code`, `var_execution_id` y
`var_user` en `set_vars`: si MONITORING no las agregó, agregarlas solo esas cuatro.

> Si el workflow tiene múltiples fuentes con workflows separados (uno por fuente, según
> `@.claude/data/standard/factory/repositories.md`), insertar el gate solo en el workflow que
> consolida/carga la tabla final.

---

## Paso 7 — Actualizar `docs/TODO.md`

```markdown
### INTEGRIDAD
- [x] sp_integridad_{tabla_out}.sql generado (OUT o_flag_detener / o_motivo_detencion / o_resultado_json, sin tablas BQ)
- [x] Patrón de exclusión (QUALIFY + WHERE llave IS NOT NULL) aplicado en SP(s) de carga
- [x] Payloads de matrícula de reglas generados y registrados en monitoring_register
- [x] Steps de integridad insertados en el workflow (SyncBigQueryJobWithResults + RegisterIntegrityResults), antes de la carga principal
- [ ] Confirmar `dias_tolerancia` con Business Steward / Data Owner si difiere de 1 (D-1)
- [ ] Validar en dev que los resultados aparecen en GET /integrity-execution/status
```

---

## Reporte de etapa

```
## Etapa completada: INTEGRIDAD
SPEC: {id}  |  type: bq_pipeline  |  módulo: {id_modulo}

### Artefactos generados/modificados
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_integridad_{tabla_out}.sql (3 OUT: flag / motivo / resultado_json)
- ✅ SP(s) de carga actualizados con patrón de exclusión: {lista de fuentes}
- ✅ data/integrity/{dataset_out}/{tabla_out}/payloads/: {n} reglas matriculadas
- ✅ deploy/deploy_dev.json + deploy_prd.json: monitoring_register apunta al directorio de integridad
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml: steps de integridad + RegisterIntegrityResults (+ SyncBigQueryJobWithResults si no existía)
- ✅ docs/TODO.md: ítems INTEGRIDAD marcados

### Trazabilidad habilitada
- {n} reglas en ct_datapipeline_integrity_rule (proceso {process_code})
- Resultados por corrida en de_datapipeline_integrity_execution, consultables en
  GET /api/v1/pipeline-management/pipelines/{process_code}/integrity-execution/status

### Pendientes
- ⬜ Confirmar dias_tolerancia con {business_steward} si aplica

### Próxima etapa sugerida
fac-data-stage-monitoring {id_modulo}   (si etapas.monitoring: true)
fac-data-stage-data-quality {id_modulo} (si etapas.monitoring: false)
```

---

## Referencias

- Estándar de Integridad: `@.claude/data/standard/data-integrity.md` (§6 = registro histórico)
- Schema `fuentes` y `reglas_integridad`: `@.claude/data/standard/factory/spec-manifest.md`
- Framework de Control de Procesos (tablas, endpoints, matrícula) y patrón SP con `OUT` + `SyncBigQueryJobWithResults`: `@.claude/data/standard/factory/monitoring.md`
- Modelo y contratos de la API de integridad: `itcm-dp-dataops-api-metadata/docs/feature_spec/integrity_tracking/spec.md`
- Integración workflow (Regla 2b): `@.claude/data/standard/services/workflow.md`
