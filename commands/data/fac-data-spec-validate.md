# Validar Especificación de Desarrollo

Audita `docs/specs/*.yaml` contra el estándar `@.claude/data/standard/factory/spec-manifest.md`. Solo lectura — no
modifica archivos. Reporta campos faltantes, inconsistencias y reglas violadas con corrección sugerida.
Si existen archivos `docs/feature_spec/*/spec.md`, también verifica su coherencia con el YAML.

> **Cuándo usar:** después de `/spec-create`, después de `/spec-update`, y obligatoriamente antes de
> pasar a la etapa DESIGN. Un spec con issues críticos **no debe avanzar**.

**Argumento (`$ARGUMENTS`):**
- Sin argumento → valida el spec activo en `docs/specs/` del repo actual
- `--strict` → trata warnings como errores (bloqueante para pasar a DESIGN)

---

## Paso 0 — Localizar y parsear el spec

Leer el spec en `docs/specs/`. Si hay más de un archivo → tomar el más reciente (por fecha en el ID).
Si no existe ninguno:
```
❌ No se encontró ningún spec en docs/specs/.
   Usa /spec-create "{descripción}" para crear uno.
```

Leer también:
- `@.claude/data/standard/factory/spec-manifest.md` — schema de referencia
- `@.claude/data/standard/data-quality.md` — convenciones de IDs DQ
- `docs/feature_spec/*/spec.md` — si existen, verificar coherencia

---

## Paso 1 — Verificación de campos obligatorios (raíz)

| Campo | Req | Verificación |
|---|---|---|
| `id` | ✅ | Formato `spec-[a-z]+-\d{8}-[a-z0-9][a-z0-9\-]*` — ej: `spec-itc-20260501-atributo-educacion` |
| `version` | ✅ | String no vacío |
| `status` | ✅ | Uno de: `draft`, `review`, `approved`, `deprecated` |
| `empresa` | ✅ | No vacío, no `~` |
| `equipo` | ✅ | No vacío, no `~` |
| `fecha` | ✅ | Formato `YYYY-MM-DD` |
| `autor` | ✅ | No `~` |
| `aprobador` | — | Si `status: approved` → debe ser distinto de `~` |

```
❌ Campo obligatorio vacío: autor = ~
   Fix: completar con el usuario responsable técnico
```

---

## Paso 2 — Verificación del bloque `contexto`

| Campo | Req | Verificación |
|---|---|---|
| `nombre` | ✅ | No vacío, no `~` |
| `tipo_flujo` | ✅ | Valor válido del enum (ver standard) |
| `descripcion` | ✅ | No vacío, no `~`, max ~3 oraciones |
| `objetivo_negocio` | ✅ | No vacío, no `~` |
| `data_owner` | ✅ | No `~` |
| `business_steward` | ✅ | No `~` |
| `kpis` | — | Recomendado para flujos tipo `etl`, `atributos`, `productivizacion-modelo` |

```
⚠️ contexto.kpis vacío para tipo_flujo=atributos
   Recomendado: definir al menos 1 KPI de cobertura (ej: "> 80% de iden_itc_party activos")
```

---

## Paso 3 — Verificación del bloque `etapas`

| Verificación | Criterio |
|---|---|
| Al menos 3 etapas activas | Además de `plan: true` obligatorio |
| `orquestacion: true` requiere componente `workflow` | Si `orquestacion=true` → debe existir en `componentes` |
| `data_quality: true` requiere bloque `data_quality` con reglas | Si `data_quality=true` → `data_quality.reglas` no vacío |
| `integridad: true` requiere bloque `reglas_integridad` completo | Si `integridad=true` → `reglas_integridad.fuente_principal` definido y `reglas` no vacío (ver Paso 4b) |
| `seguridad: true` requiere `seguridad.campos_pii_fuente` definido | No puede ser `~` |
| `dataops: true` requiere componentes definidos | `componentes` no vacío |

```
❌ etapas.orquestacion = true pero no hay componente tipo 'workflow' en la lista
   Fix: agregar componente workflow en el bloque componentes
```

---

## Paso 4 — Verificación del bloque `fuentes`

Para cada fuente:

| Campo | Verificación |
|---|---|
| `id` | No `~`, no vacío, único entre todas las fuentes |
| `proyecto` | Debe ser una variable `${...}` o un literal GCP válido (`xxx-itc-yyy`) |
| `dataset` | Debe ser variable `${...}` o literal |
| `tabla` | Debe ser variable `${...}` o literal |
| `pii` | Si es `true` → verificar que `seguridad.campos_pii_fuente` no esté vacío |

```
⚠️ fuente 'rcc': tabla = ~ (no definida)
   Fix: definir como ${table_ba_itc_attr_rcc} o valor literal
```

```
❌ fuente 'iden_party': pii=true pero seguridad.campos_pii_fuente = []
   Fix: listar los campos PII que se usan de esta fuente en el bloque seguridad
```

---

## Paso 4b — Verificación del bloque `reglas_integridad` (si `etapas.integridad: true`)

| Verificación | Criterio |
|---|---|
| Exactamente 1 fuente `rol: principal` | Ninguna o más de una → error crítico |
| Toda fuente tiene `llave` no vacía | Requerido para los checks de duplicados y llave nula |
| `tipo_fuente` y `campo_fecha` coherentes | Si `tipo_fuente: archivo` → debe existir convención de fecha en nombre de archivo o `campo_fecha` con el campo `load_date` del archivo |
| `reglas_integridad.fuente_principal` coincide con la fuente `rol: principal` | Deben ser el mismo `id` |
| Fuente principal tiene regla `tipo_check: actualidad` | Con `accion: detener_proceso` — obligatoria |
| `tipo_check: actualidad` solo en la fuente principal | Ninguna fuente secundaria puede declarar este check |
| Toda fuente con `llave` tiene reglas `duplicados` y `llave_nula` | `accion: excluir_registros` por default. `accion: detener_proceso` también es válido **si** `restricciones[]` documenta la razón de negocio — si no, marcar como error |
| `id` de regla único y con formato `RI-[EMPRESA]-[TABLA]-NNN` | Es el `code` con el que la regla se matricula en `ct_datapipeline_integrity_rule` — un duplicado rompe el histórico |
| `registro_resultados` (default `true`) con `METADATA_API_URL` disponible | Si es `true`, `env_dev.json`/`env_prd.json` deben tener la variable. Si es `false`, `restricciones[]` debe justificarlo |

```
❌ reglas_integridad: no hay ninguna fuente con rol: principal (o hay más de una)
   Fix: en fuentes[], marcar exactamente una fuente con rol: principal

❌ fuente 'iden_party': llave = [] (vacía) pero etapas.integridad = true
   Fix: definir las columnas de la llave de negocio de esta fuente

❌ reglas_integridad.registro_resultados = true pero METADATA_API_URL no está en env_[env].json
   Fix: agregar la variable (ver @.claude/data/standard/factory/monitoring.md §10)
        o poner registro_resultados: false y justificarlo en restricciones[]

⚠️ reglas_integridad.registro_resultados = false sin justificación en restricciones[]
   Fix: documentar por qué este módulo no registra el histórico del gate de integridad

⚠️ fuente 'rcc': tipo_fuente = archivo pero campo_fecha = ~ y no hay convención de fecha en el nombre
   Fix: definir campo_fecha (load_date dentro del archivo) o documentar el patrón de fecha en el nombre
```

---

## Paso 5 — Verificación del bloque `outputs`

Para cada output:

| Campo | Verificación |
|---|---|
| `tabla` | No `~`, sigue convención de nomenclatura (`ba_`, `m_`, `t_`, etc.) |
| `proyecto` | Variable `${project_analytics}` o literal válido |
| `dataset` | Variable `${dataset_analytics}` o literal |
| `capa` | Uno de: `raw`, `master`, `business` |
| `tipo_carga` | Uno de: `reemplazo`, `incremental`, `acumulativo` |
| `campos_auditoria` | Incluye al menos `load_date` y `record_source` |
| `pii` | Si `true` → `seguridad.encriptacion_requerida` debe ser `true` o `seguridad.nota` justifica |

```
❌ output 'ba_itc_attr_education': capa = ~ (no definida)
   Fix: una de: raw | master | business

⚠️ output: campos_auditoria no incluye 'record_source'
   Fix: agregar 'record_source' — obligatorio según data-platform-layers.md
```

---

## Paso 6 — Verificación del bloque `reglas_negocio`

| Verificación | Criterio |
|---|---|
| Al menos 1 regla | Para flujos `etl`, `atributos` — mínimo 1 RN |
| Formato de ID | `RN-[EMPRESA]-\d{3}` — secuencial sin huecos |
| `criticidad` | Uno de: `alta`, `media`, `baja` |
| `descripcion` no `~` | Toda regla debe estar descrita |
| RN de criticidad `alta` → regla DQ | Verificar que existe al menos 1 regla en `data_quality.reglas` que las cubra |

```
❌ RN-ITC-001 criticidad=alta pero no hay ninguna regla DQ asociada
   Fix: agregar al menos 1 regla en data_quality.reglas que valide esta RN
   Ver: @.claude/data/standard/data-quality.md
```

---

## Paso 7 — Verificación del bloque `componentes`

| Verificación | Criterio |
|---|---|
| Al menos 1 componente | Para cualquier flujo no trivial |
| Tipos válidos | `ddl`, `sp`, `image`, `cloud_run`, `cloud_function`, `workflow`, `cloud_scheduler`, `vertex_pipeline`, `pubsub` |
| `archivo` no `~` | Toda ruta debe estar definida |
| Rutas consistentes con estructura de repo | `data/bigquery/{dataset_out}/{tabla_out}/ddl/` para DDL, `pipeline/workflow/{dataset_out}/{tabla_out}/` para workflows, etc. — ver `@.claude/data/standard/factory/repositories.md` |
| Si hay `vertex_pipeline` → debe existir `workflow` | Los pipelines Vertex se orquestan vía Workflow |

---

## Paso 8 — Verificación del bloque `data_quality`

| Verificación | Criterio |
|---|---|
| `dataset_dq` | Debe ser `${dataset_dq}` — nunca hardcodeado |
| Al menos 1 regla | Si `etapas.data_quality = true` |
| Formato `id` | `DQ-[EMPRESA]-[TABLA]-\d{3}` |
| `dimension` | Uno de: `completitud`, `unicidad`, `validez`, `precision`, `consistencia`, `oportunidad` |
| `tipo` | Uno de: `technical`, `business` |
| `umbral_max_pct_invalidos` | Entero 0–100 |
| `sql_rule` | No `~`, debe contener `SELECT *` que retorne filas inválidas, debe usar `${variables}` |
| Al menos 1 regla `critica: true` | Mínimo 1 regla crítica por tabla output |

---

## Paso 9 — Verificación del bloque `seguridad`

| Verificación | Criterio |
|---|---|
| `encriptacion_requerida` | Si `campos_pii_output` no vacío → debe ser `true` |
| `hash_iden_party` | Si las fuentes incluyen `tipo_doc`/`nro_doc` → verificar que sea `true` |
| `permisos` | Si `etapas.seguridad = true` → al menos 1 permiso definido |
| SA en permisos | Debe seguir patrón `${env}-[empresa]-[caso]-[tipo]@${env}-...` (sin hardcodeo del ambiente) |

---

## Paso 10 — Verificación del bloque `scheduling`

| Verificación | Criterio |
|---|---|
| `frecuencia` | No `~`. Expresión cron válida o `on-demand` |
| `zona_horaria` | `America/Lima` por defecto |
| `tiempo_max_ejecucion` | Recomendado para flujos con cloud_scheduler |

---

## Paso 11 — Verificación de `feature_spec/*/spec.md` (si existen)

Para cada archivo `docs/feature_spec/{feature}/spec.md` presente:

| Verificación | Criterio |
|---|---|
| El spec-ID del header coincide con el spec.yaml | Primera línea referencia el mismo ID |
| Las fuentes listadas coinciden con las del spec.yaml | Mismos IDs y tablas |
| Los outputs listados coinciden con el spec.yaml | Misma tabla, capa y partición |
| Las RN listadas coinciden con `reglas_negocio` del YAML | Mismos IDs |
| Las reglas DQ coinciden | Mismos IDs |

```
⚠️ feature_spec/ba_itc_attr_digital/spec.md — Output inconsistente
   spec.md dice tabla: 'ba_itc_attr_digital_v2'
   spec.yaml dice tabla: 'ba_itc_attr_digital'
   Fix: usar /spec-update para corregir o actualizar el spec.md manualmente
```

---

## Paso 12 — Resumen del reporte

```
## Resultado /spec-validate — {ID}
status actual: draft

### Issues encontrados: N

| Severidad | Bloque | Descripción |
|---|---|---|
| 🔴 CRÍTICO | data_quality | sql_rule con proyecto hardcodeado en regla DQ-ITC-001 |
| 🔴 CRÍTICO | reglas_negocio | RN-ITC-001 (alta) sin regla DQ asociada |
| 🔴 CRÍTICO | reglas_integridad | Fuente 'rcc' sin llave definida pese a etapas.integridad = true |
| 🟡 MEDIO | contexto | objetivo_negocio = ~ |
| 🟡 MEDIO | seguridad | permisos vacío con etapas.seguridad = true |
| 🟢 MENOR | contexto | kpis vacío |

### Verificaciones OK: N
✅ Bloque raíz: todos los campos obligatorios presentes
✅ tipo_flujo: valor válido (atributos)
✅ etapas: coherentes con tipo_flujo
✅ fuentes: todas las tablas con ${variables}
✅ outputs: nomenclatura correcta (ba_ prefix, capa=business)
✅ componentes: rutas consistentes con estructura de repo
✅ scheduling: frecuencia definida
✅ feature_spec/: coherentes con spec.yaml (si existen)

### Veredicto
❌ NO apto para pasar a DESIGN — hay 2 issues críticos
   Usar /spec-update para corregir antes de avanzar.
```

**Veredicto posible:**
- `✅ APTO para pasar a etapa DESIGN` — sin críticos ni medios (o `--strict` sin ningún issue)
- `⚠️ APTO con advertencias` — solo issues menores
- `❌ NO apto` — hay al menos 1 issue crítico o medio


