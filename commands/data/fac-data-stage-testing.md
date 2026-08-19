# fac-data-stage-testing — Validación Dinámica en Dev

Ejecuta validaciones dinámicas en dev sobre la estructura DDL, ejecución de SPs y reglas
de negocio antes de RELEASE. Usa MCP BigQuery para ejecutar queries directamente.

**Bloque:** VERIFY — después de COMPLIANCE y después de confirmar despliegue en dev
**Prerequisito:** triggers Cloud Build (InfraOps + Dataops dev) ejecutados con SUCCESS

> Cargar skill: `@.claude/data/skills/verify/bigquery-mcp-validator/SKILL.md`
> Usa MCP BigQuery para ejecutar queries en el entorno dev.
> **NUNCA ejecutar en proyectos `prd-*`.**

**Invocación:**
```
fac-data-stage-testing
fac-data-stage-testing {id_modulo}
```

> **`testing: false` por defecto en el spec.** Activar manualmente con
> `fac-data-spec-update "etapas: activar testing"` solo después de confirmar
> que el trigger Dataops dev finalizó con éxito y las tablas/servicios están desplegados.

---

## Prerequisito — Verificar pre-condiciones

Antes de iniciar:
1. Verificar vía MCP BigQuery que las tablas del spec existen en dev.
   Si no existen → reportar **BLOCKED**:
   ```
   ⛔ TESTING BLOCKED — tablas DDL no encontradas en dev.
      Ejecutar primero:
      1. Trigger InfraOps → crear SAs y permisos IAM
      2. Trigger Dataops (dev) → desplegar DDL, SPs, Workflows
      Confirmar SUCCESS en ambos triggers antes de re-ejecutar.
   ```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: TESTING`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Leer spec y prerequisitos

Leer el spec para obtener: tablas DDL, SPs, RNs verificables, KPIs y tablas output.

---

## Paso 2 — T1: Tests de estructura DDL

Via MCP BigQuery, consultar `INFORMATION_SCHEMA` para cada tabla output:
- Tabla existe
- Todos los campos del DDL están presentes
- Tablas `t_*` o `tipo_carga: incremental` tienen partición configurada

---

## Paso 3 — T2: Tests unitarios de SPs

Ejecutar los archivos `data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_{tabla_out}_{emp}.sql`
creados en CODING (uno por fuente).

```bash
bq query --project={dev_project} --use_legacy_sql=false < data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_{tabla_out}_{emp}.sql
```

Ver estructura de tests en `fac-data-stage-coding`.

---

## Paso 4 — T3: Tests de ejecución end-to-end

Ejecutar cada SP en orden (respetando secuencia del spec) con datos reales de dev:
- SP ejecuta sin error
- Tabla output tiene filas (`COUNT(*) > 0`)
- Campos de auditoría poblados
- Sin duplicados por PK

Para `vertex_ml`: compilar pipeline KFP sin ejecutar (T3-lite).

---

## Paso 5 — T4: Tests de reglas de negocio

Para cada RN-ITC-* con regla verificable: ejecutar query de validación sobre tablas intermedias o output.

---

## Paso 6 — T5: Tests de cobertura

Si el spec define KPIs de cobertura (ej. > 90% clientes con iden_itc_party), ejecutar la query correspondiente.

---

## Paso 7 — T6: Verificar catálogo de datos

Para cada tabla en `outputs` del spec, verificar que existe `data/glossary/{nombre_tabla}.md`.
Si falta → marcar como WARNING (debe crearse en DOCUMENTATION).

---

## Paso 8 — Guardar reporte en `docs/reports/`

```
docs/reports/testing-{YYYY-MM-DD}.md
```

```markdown
# Reporte TESTING — {YYYY-MM-DD}
> **Repo:** `{nombre-repo}` · **SPEC:** {spec_id}
> **Resultado:** ✅ PASS | ⚠️ PASS con advertencias | ❌ FAIL

## T1 — Estructura DDL
## T2 — Tests unitarios de SPs
## T3 — Ejecución end-to-end
## T4 — Reglas de negocio
## T5 — Cobertura
## T6 — Catálogo de datos

---
> 📁 Generado por `fac-data-stage-testing` · {fecha}
> Próximo paso: fac-data-stage-infraops
```

---

## Reporte

```
## Etapa completada: TESTING
SPEC: {id}  |  módulo: {id_modulo}

### Resultado: ✅ PASS | ❌ FAIL

| Test | Resultado |
|---|---|
| T1 — DDL estructura | ✅/❌ |
| T2 — Tests unitarios SP | ✅/❌ |
| T3 — Ejecución end-to-end | ✅/❌ |
| T4 — Reglas de negocio | ✅/❌ |
| T5 — Cobertura | ✅/❌/N/A |
| T6 — Catálogo de datos | ✅/⚠️ |

### Reporte guardado
docs/reports/testing-{YYYY-MM-DD}.md

### Próxima etapa
fac-data-stage-infraops {id_modulo}
```
