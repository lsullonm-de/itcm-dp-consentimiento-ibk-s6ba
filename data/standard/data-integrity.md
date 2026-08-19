# Estándar: Framework de Reglas de Integridad — ITC Data Platform

> **Última actualización:** 2026-08-19
> **Etapa en la fábrica:** INTEGRIDAD — se ejecuta en BUILD, después de ORCHESTRATION
> **Plataforma:** BigQuery + Cloud Workflows (GCP) + metadata API (Cloud Run / Cloud SQL)
>
> **Referencias de contexto (no duplicadas aquí):**
> - Estructura general de Cloud Workflows → `@.claude/data/standard/services/workflow.md`
> - Patrón de SP con parámetros `OUT` + subworkflow `SyncBigQueryJobWithResults` (origen del patrón, usado también por MONITORING) → `@.claude/data/standard/factory/monitoring.md` §7-9
> - Framework de Control de Procesos (tablas PostgreSQL, matrícula vía API, OIDC) → `@.claude/data/standard/factory/monitoring.md` §1, §3-4, §6
> - Schema del bloque `reglas_integridad` en el spec → `@.claude/data/standard/factory/spec-manifest.md`

---

## 1. Rol de la Etapa INTEGRIDAD en la Fábrica

INTEGRIDAD es un **gate de entrada**: valida las fuentes RAW declaradas en `fuentes` del spec
**antes** de la carga principal, y decide si el proceso puede ejecutarse.

| Aspecto | Definición |
|---|---|
| Qué valida | Las fuentes de entrada del módulo, nunca la tabla output |
| Cuándo corre | Entre la normalización de `process_date` y el bloque `try` de la carga principal |
| Si falla | Detiene el proceso (`o_flag_detener = 1`) y notifica con el motivo real |
| Dónde vive el resultado | `OUT` del SP (decisión) + histórico por regla en el **Framework de Control de Procesos** (`metadata_operational`, PostgreSQL, vía metadata API) — nunca en una tabla BigQuery |
| Acción sobre datos malos | Los excluye el propio SP de carga (patrón `QUALIFY`, Sección 4) |

```
ORCHESTRATION → INTEGRIDAD (gate, sin tablas BQ) → carga principal
                      │
                      └── resultado por regla → metadata API → metadata_operational (PostgreSQL)
```

**No se ejecuta la carga principal de un proceso si su fuente principal no tiene datos actualizados.**

> **Decisión de diseño (actualizada 2026-08-19):** este framework **no crea tablas de
> catálogo/control en BigQuery**. El SP de integridad no escribe una sola fila: todo su
> resultado viaja en parámetros `OUT`.
>
> Lo que sí cambia respecto de la versión anterior de este estándar: el resultado **ya no muere
> con la ejecución del workflow**. El gate es un evento de *ejecución*, no de *dato*, así que su
> histórico se registra donde ya vive el control de procesos — las tablas
> `metadata_operational` de Cloud SQL — mediante la misma metadata API, el mismo `execution_id`
> y el mismo mecanismo OIDC que usa MONITORING. Así se obtiene trazabilidad histórica
> consultable ("¿cuántas veces se detuvo este proceso por falta de datos en la fuente
> principal?") y un ítem del reporte de ejecución y control de la plataforma, sin crear un
> framework paralelo ni acoplar el SP a ninguna tabla.
>
> Ver Sección 6 — Registro histórico de resultados.

### Qué se entrega en esta etapa

| Artefacto | Descripción |
|---|---|
| SP de integridad | `sp_integridad_{tabla_out}.sql` — evalúa las reglas con `accion: detener_proceso` y devuelve `OUT o_flag_detener` + `OUT o_motivo_detencion` + `OUT o_resultado_json` |
| Payloads de matrícula | `data/integrity/{dataset_out}/{tabla_out}/payloads/integrity_rule_{tabla_out}_{emp}.json` — una regla por archivo, registradas en deploy vía API (Sección 6.3) |
| Step(s) en el Workflow | `build_sql_integridad` → `ejecutar_validacion_integridad` (`SyncBigQueryJobWithResults`) → `extraer_resultado_integridad` → `registrar_resultado_integridad` → `evaluar_integridad` → `error_sin_datos_principal`, insertados **antes** del bloque `try` de carga principal |
| Sub-workflows | `SyncBigQueryJobWithResults` (copiado si no lo agregó MONITORING, ver `@.claude/data/standard/factory/monitoring.md` §8) y `RegisterIntegrityResults` (Sección 6.4) |
| Patrón de filtrado en el SP de carga | `QUALIFY ROW_NUMBER()` + `WHERE llave IS NOT NULL` en la query de staging de cada fuente (Sección 5) — así se materializa `accion: excluir_registros` |

---

## 2. Conceptos: Fuente Principal (Universo) vs Fuentes Secundarias

Todo módulo con `etapas.integridad: true` debe declarar en `fuentes` (spec.yaml) exactamente
**una** fuente con `rol: principal` — el universo del proceso — y cero o más con
`rol: secundaria`.

| Rol | Checks obligatorios |
|---|---|
| `principal` (universo) | Actualidad (datos a la fecha de ayer, D-1, por defecto) — si no hay datos, **detener el proceso**. Duplicados y llave nula se excluyen en el SP de carga (Sección 4), sin gatear el proceso por default |
| `secundaria` | Duplicados y llave nula se excluyen en el SP de carga (Sección 4), sin gatear el proceso por default |

> Una fuente (principal o secundaria) puede escalar su check de `duplicados` o `llave_nula` a
> `accion: detener_proceso` si el equipo documenta la razón de negocio en `restricciones[]` del
> spec (ver Sección 7). En ese caso, ese check también se implementa en el SP de integridad,
> igual que la actualidad de la fuente principal.

### Identificación de actualidad según `tipo_fuente`

| `tipo_fuente` | Cómo se identifica la fecha |
|---|---|
| `tabla` | Por **partición** (`fuentes[].particion`) o por columna **`load_date`** — lo que declare `fuentes[].campo_fecha` |
| `archivo` | Por la **fecha en el nombre del archivo** (ej. `ventas_20260802.csv` → `REGEXP_EXTRACT` sobre `_FILE_NAME` si es tabla externa GCS) **o** por un campo **`load_date`** dentro del archivo, si existe — lo que declare `fuentes[].campo_fecha` |

> Si `tipo_fuente: archivo` y no hay ni fecha en el nombre ni campo `load_date` → el spec no puede
> declarar `tipo_check: actualidad` para esa fuente; `/spec-validate` debe marcarlo como error.

---

## 3. SP de Integridad — Estructura

Un SP por módulo (tabla output): `sp_integridad_{tabla_out}.sql`. Recibe la fecha de proceso y
devuelve **tres parámetros `OUT`** — nada se escribe en ninguna tabla:

| Parámetro `OUT` | Tipo | Para qué |
|---|---|---|
| `o_flag_detener` | INT64 | Punto de corte del workflow: `1` = detener, `0` = continuar |
| `o_motivo_detencion` | STRING | Detalle legible para el correo — motivos concatenados con ` \| ` |
| `o_resultado_json` | STRING | Detalle **por regla** que el workflow envía a la metadata API (Sección 6) |

```sql
CREATE OR REPLACE PROCEDURE `${project_analytics}.${dataset_sp}.sp_integridad_ba_itc_attr_education` (
  IN  p_process_date     DATE,
  OUT o_flag_detener     INT64,   -- 1 = detener el proceso, 0 = continuar con la carga
  OUT o_motivo_detencion STRING,  -- detalle legible de qué falló (una o más reglas concatenadas)
  OUT o_resultado_json   STRING   -- array JSON: un objeto por regla evaluada (trazabilidad histórica)
)
BEGIN

  DECLARE v_motivos     ARRAY<STRING> DEFAULT [];
  DECLARE v_resultados  ARRAY<STRING> DEFAULT [];
  DECLARE v_tiene_datos BOOL;
  DECLARE v_registros   INT64;
  DECLARE v_motivo_regla STRING;

  SET o_flag_detener     = 0;
  SET o_motivo_detencion = '';
  SET o_resultado_json   = '[]';

  -- Regla RI-ITC-BA_ITC_ATTR_EDUCATION-001 (tipo_check: actualidad, fuente: rcc, accion: detener_proceso)
  SET v_registros = (
    SELECT COUNT(*)
    FROM `${project_ba_itc_attr_rcc}.${dataset_ba_itc_attr_rcc}.${table_ba_itc_attr_rcc}`
    WHERE load_date >= DATE_SUB(p_process_date, INTERVAL 1 DAY)
  );
  SET v_tiene_datos  = v_registros > 0;
  SET v_motivo_regla = IF(v_tiene_datos, '',
    'Sin datos en fuente principal (rcc) para ' || CAST(p_process_date AS STRING));

  IF NOT v_tiene_datos THEN
    SET v_motivos = ARRAY_CONCAT(v_motivos, [v_motivo_regla]);
  END IF;

  SET v_resultados = ARRAY_CONCAT(v_resultados, [TO_JSON_STRING(STRUCT(
    'RI-ITC-BA_ITC_ATTR_EDUCATION-001'          AS rule_code,
    'rcc'                                       AS source_id,
    'actualidad'                                AS check_type,
    'detener_proceso'                           AS check_action,
    IF(v_tiene_datos, 'PASSED', 'FAILED')       AS integrity_status_code,
    IF(v_tiene_datos, '0', '1')                 AS flag_stop_process,
    v_registros                                 AS records_evaluated,
    0                                           AS records_affected,
    v_motivo_regla                              AS stop_reason
  ))]);

  -- Repetir el par de bloques anterior (evaluación + append a v_resultados) por cada regla
  -- adicional con accion: detener_proceso (ej. una regla de duplicados escalada — ver Sección 7).
  -- Las reglas con accion: excluir_registros NO se evalúan aquí — se resuelven en el
  -- SP de carga con el patrón de la Sección 4.

  IF ARRAY_LENGTH(v_motivos) > 0 THEN
    SET o_flag_detener     = 1;
    SET o_motivo_detencion = ARRAY_TO_STRING(v_motivos, ' | ');
  END IF;

  SET o_resultado_json = '[' || ARRAY_TO_STRING(v_resultados, ',') || ']';

END;
```

> **Por qué no hay más DECLARE/SET de los estrictamente necesarios:** el SP solo implementa
> las reglas cuya `accion` sea `detener_proceso`. Por default eso es únicamente la actualidad
> de la fuente principal — el SP de un módulo típico tiene un solo bloque `IF`.
>
> **`o_resultado_json` se llena siempre**, tanto para las reglas que pasan como para las que
> fallan: es la fuente del histórico. Un `[]` significa "el gate no evaluó ninguna regla" y
> `fac-data-rules-check` lo marca como error.
>
> **`records_evaluated`** se toma del mismo `COUNT(*)` que decide la regla — no se agrega una
> query extra solo para medir. Para `duplicados`/`llave_nula` escaladas, `records_affected`
> lleva la cantidad de filas que incumplen.
>
> **Orden crítico:** todos los `DECLARE` van antes de cualquier `SET`, igual que en cualquier
> SP del repo — ver `data/rules/bigquery.md`.

---

## 4. Patrón obligatorio de exclusión en el SP de carga

Toda fuente declarada en `reglas_integridad` con `accion: excluir_registros` (duplicados y/o
llave nula — el default) debe leerse en el SP de carga con este patrón en la query de
staging — **nunca** leer la fuente cruda sin filtrar:

```sql
-- Patrón obligatorio: excluir duplicados (quedarse con el más reciente) y llaves nulas
SELECT * EXCEPT(rn)
FROM (
  SELECT
    t.*,
    ROW_NUMBER() OVER (PARTITION BY {llave} ORDER BY {campo_fecha} DESC) AS rn
  FROM `{asset_fuente}` t
  WHERE {llave_col_1} IS NOT NULL
    -- AND {llave_col_n} IS NOT NULL  (una condición por cada columna de la llave compuesta)
)
WHERE rn = 1
```

- `{llave}` puede ser compuesta (ej. `tipo_doc, nro_doc`) — el `PARTITION BY` y el `WHERE ... IS NOT NULL` deben cubrir **todas** las columnas de la llave.
- `{campo_fecha}` es el mismo campo usado para el check de actualidad (`load_date` o partición).
- Este patrón reemplaza el `SELECT * FROM {asset_fuente}` plano en cualquier SP que consuma una fuente con reglas de integridad activas.
- Este es el **único** lugar donde se materializa la exclusión de duplicados/llaves nulas — el SP de integridad (Sección 3) no las toca cuando `accion: excluir_registros`.

---

## 5. Integración en el Workflow

Los steps de integridad se insertan **entre la normalización de `process_date` y el bloque
`try` de carga principal** — antes de cualquier lógica de negocio. Se usa el mismo patrón de
SP-con-`OUT`-parameters que MONITORING (`@.claude/data/standard/factory/monitoring.md` §7-9):
un script `DECLARE + CALL + SELECT` ejecutado con `SyncBigQueryJobWithResults` (no
`SyncBigQueryJob`, que no retorna filas).

```yaml
# Fragmento del workflow YAML — va después de log_fecha, antes de "ejecutar" (try/except)

- build_sql_integridad:
    assign:
      - sql_integridad_p1: ${"DECLARE v_flag_detener INT64 DEFAULT 0; "
          + "DECLARE v_motivo_detencion STRING DEFAULT ''; "
          + "DECLARE v_resultado_json STRING DEFAULT '[]'; "
          + "CALL `" + var_sp_integridad + "`("}
      - sql_integridad_p2: ${"DATE '" + var_process_date + "'"
          + ", v_flag_detener, v_motivo_detencion, v_resultado_json); "}
      - sql_integridad_p3: ${"SELECT v_flag_detener AS flag_detener"
          + ", v_motivo_detencion AS motivo_detencion"
          + ", v_resultado_json AS resultado_json"}

- concatenar_sql_integridad:
    assign:
      - query_integridad: ${sql_integridad_p1 + sql_integridad_p2 + sql_integridad_p3}

- log_query_integridad:
    call: sys.log
    args:
      text: ${"[BUILD] query_integridad = " + query_integridad}
      severity: INFO

- ejecutar_validacion_integridad:
    call: SyncBigQueryJobWithResults
    args:
      query: ${query_integridad}
      project_id: ${v_billing_project}
    result: resultado_integridad

- extraer_resultado_integridad:
    assign:
      - integridad_flag_detener: ${int(resultado_integridad.rows[0].f[0].v)}
      - integridad_motivo: ${resultado_integridad.rows[0].f[1].v}
      - integridad_resultados: ${json.decode(resultado_integridad.rows[0].f[2].v)}

# Registro histórico — corre SIEMPRE, antes del punto de corte (Sección 6)
- registrar_resultado_integridad:
    call: RegisterIntegrityResults
    args:
      api_url: ${var_METADATA_API_URL}
      process_code: ${var_process_code}
      execution_id: ${var_execution_id}
      task_code: ${var_sp_integridad}
      process_date: ${var_process_date}
      flag_detener: ${integridad_flag_detener}
      motivo_detencion: ${integridad_motivo}
      resultados: ${integridad_resultados}
      user: ${var_user}
    result: integridad_registro_response

- evaluar_integridad:
    switch:
      - condition: ${integridad_flag_detener == 1}
        next: error_sin_datos_principal
      - condition: ${true}
        next: ejecutar   # step del try/except con la carga principal

- error_sin_datos_principal:
    assign:
      - email_body:
          subject: "[INTEGRIDAD] Proceso detenido - ba_itc_attr_education"
          content: ${"<p>" + integridad_motivo + "</p>"}
          toAddress:
            - "responsable1@empresa.com"
    next: enviar_mail
```

**Reglas del gate de integridad:**
- Se inserta **siempre** antes del `try` de la carga principal — nunca después
- `registrar_resultado_integridad` va **entre** `extraer_resultado_integridad` y
  `evaluar_integridad`: el histórico debe quedar registrado también cuando el proceso se detiene
- `evaluar_integridad` es el único punto de corte: si `o_flag_detener = 1`, el workflow termina
  en `error_sin_datos_principal` → `enviar_mail`, con el **detalle real del error**
  (`integridad_motivo`, tomado directo del `OUT` del SP) en el cuerpo del correo — nunca un
  mensaje genérico
- El SP `sp_integridad_[tabla_out]` no escribe en ninguna tabla — todo el resultado vive en sus
  `OUT`, se lee en el mismo job que lo invocó y lo persiste el workflow vía metadata API
- Si el workflow no tiene ya el sub-workflow `SyncBigQueryJobWithResults` (porque
  `etapas.monitoring` también está activo y ya lo agregó), copiarlo desde
  `@.claude/data/standard/factory/monitoring.md` §8 — usa el mismo `BigQueryJobState` que ya
  existe en todo workflow (Regla 5 de `@.claude/data/standard/services/workflow.md`)
- No requiere ningún dataset BigQuery adicional. La única variable de despliegue es
  `METADATA_API_URL` (Sección 6.5) — la misma que ya usa MONITORING

---

## 6. Registro Histórico de Resultados

El gate deja trazabilidad en el **Framework de Control de Procesos**
(`@.claude/data/standard/factory/monitoring.md` §1): mismas tablas PostgreSQL, misma metadata
API, mismo `execution_id` del workflow. El SP sigue sin tocar ninguna tabla.

### 6.1 — Tablas (schema `metadata_operational`, Cloud SQL)

| Tabla | Cuándo se escribe | Contenido |
|---|---|---|
| `ct_datapipeline_integrity_rule` | Deploy (matrícula, idempotente) | Catálogo de reglas del proceso: `code` (= `id` de la regla en el spec), `process_code`, `task_code`, `source_id`, `source_role`, `source_asset`, `check_type`, `check_action`, `tolerance_days`, `key_columns`, `date_field`, `flag_active`, `last_status_code` |
| `de_datapipeline_integrity_execution` | Runtime, una vez por corrida del gate | Un registro **por regla evaluada**: `execution_id`, `process_code`, `task_code`, `rule_code`, `execution_date`, `process_date`, `integrity_status_code` (`PASSED`/`FAILED`), `flag_stop_process`, `records_evaluated`, `records_affected`, `stop_reason` |

`de_datapipeline_integrity_execution` es **append-only** y comparte `execution_id` con
`de_datapipeline_execution`: eso permite que el reporte de ejecución y control muestre el gate
en la misma línea de tiempo que las tareas del proceso.

> Modelo completo y contratos de request/response:
> `itcm-dp-dataops-api-metadata/docs/feature_spec/integrity_tracking/spec.md`

### 6.2 — Endpoints de la metadata API

Base URL: `${METADATA_API_URL}` · prefijo `/api/v1/pipeline-management`

| Operación | Método | Path |
|---|---|---|
| Matricular regla | POST | `/pipelines/{process_code}/integrity-rules` |
| Listar reglas | GET | `/pipelines/{process_code}/integrity-rules` |
| Actualizar regla | PUT | `/pipelines/{process_code}/integrity-rules/{rule_code}/update` |
| Registrar resultados de una corrida (bulk) | POST | `/pipelines/{process_code}/integrity-execution/creation` |
| Último resultado por regla | GET | `/pipelines/{process_code}/integrity-execution/status` |
| Consolidado por rango (reporte) | GET | `/pipelines/{process_code}/integrity-execution/summary` |

### 6.3 — Matrícula de reglas (deploy time)

Un archivo por regla, generado desde `reglas_integridad` del spec:

```
data/integrity/{dataset_out}/{tabla_out}/payloads/
└── integrity_rule_{tabla_out}_{emp}_{nnn}.json
```

```json
{
  "code": "RI-ITC-BA_ITC_ATTR_EDUCATION-001",
  "process_code": "{workflow_name}",
  "task_code": "{project}.{dataset_sp}.sp_integridad_{tabla_out}",
  "company_id": "074",
  "company_code": "ITC",
  "source_id": "rcc",
  "source_role": "principal",
  "source_asset": "{project_fuente}.{dataset_fuente}.{tabla_fuente}",
  "check_type": "actualidad",
  "check_action": "detener_proceso",
  "tolerance_days": 1,
  "key_columns": ["tipo_doc", "nro_doc"],
  "date_field": "load_date",
  "business_name": "Actualidad D-1 de la fuente principal (rcc)",
  "technical_name": "RI-ITC-BA_ITC_ATTR_EDUCATION-001",
  "flag_active": "1",
  "last_status_code": null,
  "creation_user": "dataops-deploy"
}
```

Se registran con la misma clave `monitoring_register` de `deploy_[env].json` que usa MONITORING
— el framework Dataops clasifica el payload por su contenido (`check_type` presente = regla de
integridad):

```json
"monitoring_register": [
  "/data/monitoring/{dataset_out}/{tabla_out}/payloads",
  "/data/integrity/{dataset_out}/{tabla_out}/payloads"
]
```

> El proceso debe estar matriculado antes que sus reglas (FK sobre `process_code`). Como
> `monitoring_register` procesa procesos → tareas → reglas en ese orden, basta con listar el
> directorio de integridad **después** del de monitoring.
>
> Si el módulo tiene `etapas.monitoring: false`, el directorio de payloads de integridad debe
> incluir también `process_{tabla_out}_{emp}.json` (plantilla en
> `@.claude/data/standard/factory/monitoring.md` §6) — sin proceso matriculado no hay dónde
> colgar las reglas.

### 6.4 — Sub-workflow `RegisterIntegrityResults`

Agregarlo al final del archivo de workflow, junto a los demás sub-workflows:

```yaml
RegisterIntegrityResults:
  params:
    - api_url
    - process_code
    - execution_id
    - task_code
    - process_date
    - flag_detener
    - motivo_detencion
    - resultados
    - user
  steps:
    - call_api:
        try:
          call: http.post
          args:
            url: ${api_url + "/api/v1/pipeline-management/pipelines/" + process_code + "/integrity-execution/creation"}
            auth:
              type: OIDC
              audience: ${api_url}
            body:
              execution_id: ${execution_id}
              task_code: ${task_code}
              process_date: ${process_date}
              flag_detener: ${flag_detener}
              motivo_detencion: ${motivo_detencion}
              resultados: ${resultados}
              creation_user: ${user}
          result: api_response
        except:
          as: e
          steps:
            - log_registro_fallido:
                call: sys.log
                args:
                  text: ${"[INTEGRIDAD] No se pudo registrar el resultado - " + json.encode_to_string(e)}
                  severity: WARNING
            - return_error:
                return: null

    - return_response:
        return: ${api_response.body}
```

> **El registro nunca rompe el pipeline.** Si la metadata API no responde, se loguea `WARNING`
> y el workflow continúa hacia `evaluar_integridad`: la decisión de detener o seguir depende
> solo del `OUT` del SP, jamás de la disponibilidad de la API. Es la diferencia con
> `TrackedBigQueryJobWithResults`, donde el error sí se propaga.

### 6.5 — Prerequisitos

- `METADATA_API_URL` en `env_[env].json` (misma variable de MONITORING —
  `@.claude/data/standard/factory/monitoring.md` §10)
- `var_METADATA_API_URL`, `var_process_code`, `var_execution_id`, `var_user` en `set_vars`
  (bloque `# --- MONITORING ---`, §7.1 del estándar de monitoring). Si `etapas.monitoring: false`,
  agregar solo esas 4 variables
- SA de Cloud Build con `roles/run.invoker` sobre la metadata API (para la matrícula) y SA del
  workflow con `roles/run.invoker` (para el registro en runtime)

---

## 7. Definición de Reglas — Origen desde `spec.yaml`

Las reglas de integridad no se redactan a mano en SQL — se **derivan automáticamente** del
bloque `fuentes` y `reglas_integridad` del spec, y solo las reglas con
`accion: detener_proceso` generan código en el SP de integridad (Sección 3):

| Campo en `fuentes[]` / `reglas_integridad[]` | Efecto |
|---|---|
| `rol: principal` | 1 regla `tipo_check: actualidad`, `accion: detener_proceso` **(obligatoria, siempre en el SP)** |
| `llave` (cualquier rol), `accion: excluir_registros` (default) | Se resuelve en el SP de carga (Sección 4) — **no** genera código en el SP de integridad |
| `llave` (cualquier rol), `accion: detener_proceso` (excepción documentada) | Genera un bloque `IF` adicional en el SP de integridad, igual que la regla de actualidad |
| `reglas_integridad.registro_resultados: true` (default) | Genera los payloads de matrícula (Sección 6.3), el step `registrar_resultado_integridad` y el sub-workflow `RegisterIntegrityResults` |
| `reglas_integridad.registro_resultados: false` | Solo gate en memoria: el SP igual devuelve `o_resultado_json`, pero el workflow no lo envía a la API. Reservado para módulos sin acceso a la metadata API — debe justificarse en `restricciones[]` |

> **Toda regla del spec se matricula**, incluidas las de `accion: excluir_registros`: el
> catálogo describe qué se controla en el módulo. Solo las de `detener_proceso` producen
> registros de ejecución (son las únicas que el SP evalúa).

> Escalar `duplicados` o `llave_nula` a `accion: detener_proceso` es válido cuando el equipo
> documenta la razón de negocio en `restricciones[]` del spec (ej. "un duplicado en la fuente
> principal es señal de un problema de calidad de origen, no un registro descartable en
> silencio"). Por default, ambos checks quedan en `excluir_registros`.

Ver schema completo del bloque `reglas_integridad`: `@.claude/data/standard/factory/spec-manifest.md`

---

## 8. Estructura de Archivos en el Repositorio

```
[repo]/
├── data/bigquery/{dataset_out}/{tabla_out}/sp/
│   ├── sp_integridad_{tabla_out}.sql        ← SP de validación de integridad (3 OUT params)
│   └── sp_{tabla_out}_{fuente}.sql          ← SP de carga, aplica patrón de exclusión (Sección 4)
│
├── data/integrity/{dataset_out}/{tabla_out}/
│   └── payloads/
│       └── integrity_rule_{tabla_out}_{emp}_{nnn}.json   ← matrícula de reglas (Sección 6.3)
│
└── pipeline/workflow/{dataset_out}/{tabla_out}/
    └── wf-{tabla_out_kebab}-{emp}.yaml      ← incluye steps de integridad antes del try principal
                                                + sub-workflows SyncBigQueryJobWithResults
                                                y RegisterIntegrityResults
```

---

## 9. Checklist de la Etapa INTEGRIDAD

### Validación y SP
- [ ] `fuentes` en el spec tiene exactamente 1 fuente con `rol: principal`
- [ ] Toda fuente tiene `llave` definida (no vacía)
- [ ] Toda fuente tiene `tipo_fuente` (`archivo` | `tabla`) y `campo_fecha` coherente
- [ ] `sp_integridad_{tabla_out}.sql` creado, con firma `(IN p_process_date DATE, OUT o_flag_detener INT64, OUT o_motivo_detencion STRING, OUT o_resultado_json STRING)`
- [ ] El SP solo implementa reglas con `accion: detener_proceso` (por default, solo actualidad de la fuente principal)
- [ ] `o_motivo_detencion` se arma con `ARRAY_CONCAT`/`ARRAY_TO_STRING` — nunca un mensaje genérico sin el detalle real
- [ ] `o_resultado_json` incluye un objeto por regla evaluada (`rule_code`, `integrity_status_code`, `records_evaluated`, `stop_reason`), tanto para las que pasan como para las que fallan
- [ ] SP(s) de carga aplican el patrón `QUALIFY ROW_NUMBER()` + `WHERE llave IS NOT NULL` (Sección 4) para **cada** fuente con `accion: excluir_registros`

### Workflow
- [ ] Steps `build_sql_integridad` → `ejecutar_validacion_integridad` (`SyncBigQueryJobWithResults`) → `extraer_resultado_integridad` → `registrar_resultado_integridad` → `evaluar_integridad` insertados **antes** del `try` de carga principal
- [ ] `registrar_resultado_integridad` va antes de `evaluar_integridad` (se registra también la corrida que detiene el proceso)
- [ ] `RegisterIntegrityResults` atrapa su propio error y loguea `WARNING` — el registro nunca rompe el pipeline
- [ ] Step `error_sin_datos_principal` notifica con el `integridad_motivo` real y detiene el proceso sin ejecutar la carga
- [ ] Sub-workflows `SyncBigQueryJobWithResults` y `RegisterIntegrityResults` presentes en el archivo
- [ ] `var_METADATA_API_URL`, `var_process_code`, `var_execution_id`, `var_user` disponibles en `set_vars`

### Registro histórico (si `registro_resultados: true`, el default)
- [ ] Un payload `integrity_rule_*.json` por cada regla de `reglas_integridad.reglas[]`
- [ ] Directorio de payloads agregado a `monitoring_register` en `deploy_[env].json`, después del de monitoring
- [ ] `METADATA_API_URL` presente en `env_dev.json` / `env_prd.json`
- [ ] No se generó ninguna tabla, DDL ni DML **en BigQuery** para esta etapa — la persistencia es en `metadata_operational` vía API
