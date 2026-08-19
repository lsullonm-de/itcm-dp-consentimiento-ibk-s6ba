# Sync TODO — Sincronizar Estado de Implementación

Lee el estado real de los archivos del repo y actualiza `docs/TODO.md` reflejando el progreso
actual. No asume nada — verifica cada ítem en el filesystem.

**Argumento (`$ARGUMENTS`):**
- Sin argumento → sincroniza `docs/TODO.md` del repo actual
- `--report` → solo reporta diferencias sin modificar el archivo

---

## Paso 0 — Verificar que existe docs/TODO.md

Si no existe:
```
❌ docs/TODO.md no encontrado.
   Usa /init-project para generarlo desde docs/spec.yaml.
```

Leer también `docs/spec.yaml` para obtener las etapas activas y nombres de componentes.

---

## Paso 1 — Escanear estado real por sección

Verificar cada ítem del TODO contra el filesystem:

### Sección DESIGN
| Ítem | Verificación |
|---|---|
| DDL con columnas definidas | `data/bigquery/{dataset_out}/{tabla_out}/ddl/*.sql` tiene columnas (más de 5 líneas, no solo skeleton) |
| Nombrado aprobado | Grep de nombre de tabla output en `data/bigquery/{dataset_out}/{tabla_out}/ddl/` coincide con spec |

### Sección CODING
| Ítem | Verificación |
|---|---|
| DDL completado | `data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql` existe y tiene `CREATE TABLE` con campos de negocio |
| SP principal | `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql` existe (uno por fuente) y tiene `INSERT` o `MERGE` (no solo skeleton) |
| SP DQ | `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql` existe (si `etapas.data_quality=true` en spec) |

### Sección DATA QUALITY
| Ítem | Verificación |
|---|---|
| SP DQ implementado | `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql` tiene `FOR rule IN (...)` — no solo skeleton |
| DQ config generado | Grep de `dq_config_id` en sp_dq — o archivo de seed DQ existe |

### Sección ORCHESTRATION
| Ítem | Verificación |
|---|---|
| Workflow implementado | `pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml` existe con más de 5 steps (no skeleton), uno por fuente |
| Cloud Scheduler | `pipeline/scheduler/{dataset_out}/{tabla_out}/cs-*.yaml` existe con `schedule` definido (no `~`), uno por fuente |

### Sección DATAOPS
| Ítem | Verificación |
|---|---|
| env_dev.json sin `pendiente_definir` | Grep de `pendiente_definir` en `deploy/env_dev.json` → 0 resultados |
| env_prd.json sin `pendiente_definir` | Grep de `pendiente_definir` en `deploy/env_prd.json` → 0 resultados |
| deploy_dev.json completo | `deploy/deploy_dev.json` existe con al menos 1 componente |
| deploy_prd.json completo | `deploy/deploy_prd.json` existe con al menos 1 componente |

### Sección SECURITY
| Ítem | Verificación |
|---|---|
| Permisos SA solicitados | Sin verificación automática — mantener estado actual |
| Sin PII en outputs | Grep de campos PII (`tipo_doc`, `nro_doc`, `nombre`, `email`, `telefono`) en DDL output |

### Sección DOCUMENTATION
| Ítem | Verificación |
|---|---|
| Glosario actualizado | `data/standard/business-glossary/{tabla}.md` existe |
| README actualizado | `README.md` contiene nombre del proceso (del spec) |

---

## Paso 2 — Lógica de actualización de estado

```
archivo_existe_y_completo = resultado de verificación del Paso 1

si archivo_existe_y_completo Y estado_actual == "⬜":
    → cambiar a "✅"

si NO archivo_existe_y_completo Y estado_actual == "✅":
    → cambiar a "🚧"   (regresión — posible renombre o eliminación)
    → anotar en Discrepancias

si archivo_existe_y_completo Y estado_actual == "🚧":
    → cambiar a "✅"

si NO archivo_existe_y_completo Y estado_actual == "⬜":
    → mantener "⬜"

si NO archivo_existe_y_completo Y estado_actual == "🚧":
    → mantener "🚧"
```

**Caso especial:** ítems de SECURITY (permisos SA) y revisiones manuales → no degradar de ✅ a 🚧
sin archivo verificable.

---

## Paso 3 — Detectar ítems nuevos

Si existen archivos en el repo que no están listados en el TODO:

```bash
# SP nuevos
ls data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql

# Workflows nuevos
ls pipeline/workflow/{dataset_out}/{tabla_out}/*.yaml
```

Comparar con los ítems listados en TODO.md. Si hay archivos sin ítem correspondiente → agregarlos
como `✅` en la sección correcta.

---

## Paso 4 — Actualizar docs/TODO.md

### 4a. Actualizar header

```markdown
> **Última actualización:** {fecha actual YYYY-MM-DD}
> **SPEC:** {id del spec}
> **Status:** {status del spec}
```

### 4b. Actualizar estados

Aplicar los cambios del Paso 2 y 3. Mantener sin cambios los ítems en estado correcto.

### 4c. Actualizar resumen de progreso

Si el TODO tiene una sección de resumen:
```markdown
## Progreso

| Etapa | Estado |
|---|---|
| DESIGN | ✅ Completado |
| CODING | 🚧 En progreso (2/3 ítems) |
| DATA QUALITY | ⬜ Pendiente |
| ... |
```

---

## Paso 5 — Reporte de cambios

```
## Cambios aplicados — sync-todo
{fecha}

### Ítems actualizados
- ⬜ → ✅  [CODING] DDL ba_itc_attr_education completado
- ⬜ → ✅  [CODING] SP sp_ba_itc_attr_education completado
- ✅ → 🚧  [ORCHESTRATION] Workflow — archivo no encontrado en ruta esperada

### Ítems nuevos detectados
- ✅ [CODING] SP DQ sp_dq_ba_itc_attr_education (no estaba en TODO)

### Discrepancias (requieren revisión)
- ✅ → 🚧  pipeline/workflow/analytics/ba_itc_attr_education/wf-ba-itc-attr-education-rcc.yaml
  Buscado en: pipeline/workflow/analytics/ba_itc_attr_education/wf-ba-itc-attr-education-rcc.yaml
  Posible renombre — verificar si el archivo existe con otro nombre

### Sin cambios
- N ítems ya estaban en el estado correcto

### Progreso actual
- DESIGN: ✅
- CODING: 2/3 ✅
- DATA QUALITY: ⬜
- ORCHESTRATION: 🚧
- DATAOPS: ⬜
- DOCUMENTATION: ⬜
```

---

## Notas

- No borrar ítems del TODO aunque no tengan archivo verificable (ej: "Permisos SA solicitados")
- No marcar ítems de revisión manual como ✅ automáticamente
- Si `docs/spec.yaml` no existe → sincronizar igual, pero advertir que no hay spec de referencia
- Si el repo no tiene commits → usar Glob en lugar de `git diff` para detectar archivos


