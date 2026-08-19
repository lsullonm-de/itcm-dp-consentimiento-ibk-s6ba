# Modificar Especificación de Desarrollo

Aplica un cambio quirúrgico a `docs/specs/*.yaml`. Lee el spec actual completo antes de modificar.
Edita solo la sección afectada — no reescribir bloques completos.
Si el cambio afecta outputs o fuentes, también actualiza `docs/feature_spec/*/spec.md`.

**Argumento (`$ARGUMENTS`):** `{bloque}: {descripción del cambio}`
```
/spec-update "contexto: agregar KPI de cobertura > 85%"
/spec-update "reglas_negocio: agregar RN-ITC-004 sobre filtro de clientes activos"
/spec-update "fuentes: agregar tabla iden_itc_party como nueva fuente"
/spec-update "data_quality: agregar regla DQ de unicidad para iden_party_hash"
/spec-update "scheduling: definir frecuencia mensual día 1 a las 3am"
/spec-update "status: cambiar a review"
/spec-update "fuentes: marcar rcc como rol principal, llave [tipo_doc, nro_doc]"
/spec-update "reglas_integridad: agregar validación de llave nula para fuente iden_party"
```

> **Regla de oro:** el mínimo cambio que satisface el requisito. No reescribir todo el bloque.

---

## Paso 0 — Leer el spec actual completo

Leer el spec en `docs/specs/`. Si no existe:
```
❌ No se encontró ningún spec en docs/specs/.
   Usa /spec-create "{descripción}" para crear uno.
```

Registrar mentalmente el estado actual de todos los bloques antes de editar.

Leer también `docs/feature_spec/*/spec.md` si existen — para evaluar impacto en ellos.

---

## Paso 1 — Clasificar el tipo de cambio

| Tipo | Descripción | Bloques afectados |
|---|---|---|
| **A — Campo de valor simple** | Cambiar un campo escalar (status, frecuencia, autor) | Solo el campo afectado |
| **B — Agregar item a lista** | Nueva fuente, output, RN, componente, regla DQ, permiso | El item nuevo al final de la lista |
| **C — Modificar item existente** | Cambiar un campo dentro de un item de lista | Solo el campo modificado del item |
| **D — Activar/desactivar etapa** | Marcar una etapa como true/false | Solo la etapa en el bloque `etapas` + verificar impacto en `componentes` |
| **E — Cambio de status** | `draft → review → approved` | Campo `status` + `aprobador` si pasa a `approved` |

---

## Paso 2 — Verificar consistencia antes de aplicar

Según el tipo de cambio, verificar que no rompe invariantes:

### Si el cambio es tipo B (nueva RN de criticidad `alta`):
→ Verificar que existe al menos 1 regla DQ que la cubra. Si no → proponer regla DQ complementaria.

### Si el cambio es activar `etapas.orquestacion`:
→ Verificar que hay componente `workflow` en `componentes`. Si no → proponer añadirlo.

### Si el cambio es activar `etapas.data_quality`:
→ Verificar que `data_quality.reglas` tiene al menos 1 regla con `critica: true`.

### Si el cambio es activar `etapas.integridad`:
→ Verificar que existe una fuente con `rol: principal` y `llave` definida. Si no →
proponer marcar una fuente como principal y completar su `llave` antes de activar la etapa.

### Si el cambio agrega/modifica una fuente con reglas de integridad activas:
→ Si se agrega `rol: principal` a una fuente → verificar que ninguna otra fuente ya tenga
ese rol (debe haber exactamente una). Si se agrega/edita `llave` → proponer las reglas
`duplicados` y `llave_nula` correspondientes en `reglas_integridad.reglas`.

### Si el cambio agrega una fuente con `pii: true`:
→ Verificar que `seguridad.campos_pii_fuente` no esté vacío.

### Si el cambio es `status: approved`:
→ Verificar que `aprobador` no sea `~`. Si lo es → bloquearlo:
```
❌ No se puede aprobar sin aprobador definido.
   Fix: definir aprobador antes de cambiar status a approved.
```

### Si el cambio modifica una regla DQ (`sql_rule`):
→ Verificar que la nueva SQL usa `${variables}` y no valores hardcodeados.

---

## Paso 3 — Aplicar el cambio en spec.yaml

Editar el spec con el cambio mínimo necesario.

**Convenciones al editar:**
- Agregar items a listas → al **final** de la lista (mantener el orden existente)
- RN nuevas → siguiente ID secuencial (`RN-ITC-NNN`)
- Reglas DQ nuevas → siguiente ID secuencial (`DQ-[EMPRESA]-[TABLA]-NNN`)
- No cambiar los IDs existentes de RN ni DQ (son referencias)
- No cambiar campos que no son parte del cambio pedido

---

## Paso 4 — Propagar a `feature_spec/*/spec.md` (si aplica)

Si el cambio afecta bloques que tienen reflejo en los spec.md, actualizarlos en consecuencia:

| Cambio en spec.yaml | Actualización en feature_spec/ |
|---|---|
| Nueva fuente (tipo B) | Agregar fila en tabla "Fuentes de Entrada" del spec.md correspondiente |
| Modificar tabla output (tipo C) | Actualizar header y sección Output del spec.md |
| Nueva RN (tipo B) | Agregar fila en tabla "Reglas de Negocio" del spec.md |
| Nueva regla DQ (tipo B) | Agregar fila en tabla "Reglas de Calidad" del spec.md |
| Cambio de partición/tipo_carga (tipo C) | Actualizar sección Output del spec.md |
| Nueva etapa activada (tipo D) | No afecta spec.md directamente |
| Cambio de status/autor/frecuencia (tipo A/E) | No afecta spec.md |

Editar **solo las filas/campos afectados** — no reescribir todo el spec.md.

---

## Paso 5 — Impacto en otros artefactos

Evaluar si el cambio requiere actualizar otros archivos:

| Tipo de cambio | Posible impacto en otros artefactos |
|---|---|
| Nueva fuente | `deploy/env_dev.json` y `env_prd.json` → agregar variables `project_X`, `dataset_X`, `table_X`; nuevo SP/test/workflow/scheduler por fuente en `{dataset_out}/{tabla_out}/` |
| Nuevo output | DDL en `data/bigquery/{dataset_out}/{tabla_out}/ddl/` si aún no existe + nuevo `docs/feature_spec/{feature}/spec.md` |
| Nueva regla DQ | `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql` si DQ ya está implementado |
| Nueva regla de integridad / cambio de `rol`\|`llave` en fuentes | `sp/sp_integridad_{tabla_out}.sql` (bloque `IF` nuevo si la regla es `accion: detener_proceso`) si INTEGRIDAD ya está implementada — sin DML ni tabla de catálogo; SP de carga de la fuente afectada (patrón de exclusión, Sección 4 de `@.claude/data/standard/data-integrity.md`) si es `accion: excluir_registros`; step de integridad en el workflow si ya existe |
| Nuevo componente workflow | `pipeline/workflow/{dataset_out}/{tabla_out}/` si workflow ya existe → revisar si el paso aplica (uno por fuente) |
| Nuevo componente cloud_scheduler | `pipeline/scheduler/{dataset_out}/{tabla_out}/cs-*.yaml` |
| Status → `approved` | `docs/brief.md` y `docs/TODO.md` pueden regenerarse con `/data:implement-stage PLAN` |

Reportar el impacto pero **no modificar** esos archivos — el dev decide cuándo aplicarlo.

---

## Paso 6 — Reporte del cambio

```
## Cambio aplicado: /spec-update

### Modificación
- Bloque: {bloque}
- Tipo: {A/B/C/D/E}
- Campo(s) modificado(s): {lista}

### Antes
{valor anterior}

### Después
{valor nuevo}

### Propagación a feature_spec/
✅ Sin impacto en feature_spec/
  — o —
📋 Actualizado docs/feature_spec/{feature}/spec.md:
   - Fila agregada en "Reglas de Negocio": RN-ITC-004

### Consistencia
✅ Sin impacto en invariantes
  — o —
⚠️ Impacto detectado:
   - Nueva RN-ITC-003 (alta) → no tiene regla DQ asociada aún
     Fix: usar /spec-update "data_quality: agregar regla para RN-ITC-003"

### Impacto en otros archivos (no modificados)
- deploy/env_dev.json → agregar variables de nueva fuente 'iden_party'
- deploy/env_prd.json → ídem

### Próximos pasos
- Ejecutar /spec-validate para verificar que el spec sigue siendo coherente
{si el cambio afecta fuentes, outputs, componentes, scheduling o etapas:}
- Ejecutar /data:implement-stage DISCOVERY para re-enriquecer fuentes con metadata BQ
```

---

## Tipos de cambio que NO entran en este command

| Situación | Command correcto |
|---|---|
| El spec no existe | `/spec-create` |
| Cambiar la estructura completa del spec | Crear nuevo spec con `/spec-create` |
| Modificar variables en `env_dev.json` | Editar directamente o usar `/data:implement-stage DATAOPS` |
| Ejecutar una etapa del desarrollo | `/data:implement-stage {ETAPA}` |


