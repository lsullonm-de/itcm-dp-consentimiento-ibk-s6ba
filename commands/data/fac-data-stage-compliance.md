# fac-data-stage-compliance — Auditoría de Código

Audita estáticamente el código antes de pasar a RELEASE — verifica que cumple todas las
reglas del dominio (naming, PII, auditoría, despliegue).

**Bloque:** VERIFY — primer paso después de DATAOPS

> Cargar skill: `@.claude/data/skills/verify/compliance-reviewer/SKILL.md`
> Reglas: `@.claude/data/rules/bigquery.md` · `@.claude/data/rules/security.md` ·
>         `@.claude/data/rules/workflow.md` · `@.claude/data/rules/dataops.md` ·
>         `@.claude/data/rules/general.md`

**Invocación:**
```
fac-data-stage-compliance
fac-data-stage-compliance {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado y que DATAOPS está completado
(`deploy/deploy_dev.json` y `deploy/env_dev.json` existen con valores reales).

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: COMPLIANCE`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Identificar archivos del proceso

Listar todos los archivos en:
```
data/bigquery/{dataset_out}/{tabla_out}/ddl/    → DDLs
data/bigquery/{dataset_out}/{tabla_out}/sp/     → SPs
pipeline/workflow/{dataset_out}/{tabla_out}/    → Workflows
pipeline/scheduler/{dataset_out}/{tabla_out}/   → Schedulers
service/*/{dataset_out}/{tabla_out}/            → Cloud Run / CF / Vertex
deploy/                                          → deploy configs y variables
```

---

## Paso 2 — Ejecutar auditoría por dominio

Aplicar las reglas de cada archivo de `data/rules/` sobre los archivos identificados:
1. `@.claude/data/rules/bigquery.md` → DDL y SPs
2. `@.claude/data/rules/security.md` → operaciones destructivas, PII, SAs
3. `@.claude/data/rules/workflow.md` → YAML de workflow y scheduler
4. `@.claude/data/rules/dataops.md` → deploy configs y variables
5. `@.claude/data/rules/general.md` → principios generales

---

## Paso 3 — Generar reporte de conformidad

Seguir el formato del compliance-reviewer: lista de violaciones por severidad y veredicto.

**Criterio de paso:**
- ✅ PASS: 0 CRÍTICAS y 0 ALTAS
- ⚠️ PASS con advertencias: solo MEDIAS y BAJAS
- ❌ FAIL: al menos 1 CRÍTICA o ALTA → volver a BUILD para corrección

---

## Paso 4 — Guardar reporte en `docs/reports/`

```
docs/reports/compliance-{YYYY-MM-DD}.md
```

```markdown
# Reporte COMPLIANCE — {YYYY-MM-DD}
> **Repo:** `{nombre-repo}` · **SPEC:** {spec_id} · **Ejecutado por:** {autor}
> **Resultado:** ✅ PASS | ⚠️ PASS con advertencias | ❌ FAIL

{contenido completo del reporte por dominio}

---
> 📁 Generado por `fac-data-stage-compliance` · {fecha}
> Próximo paso: {fac-data-stage-testing si PASS | corregir violaciones si FAIL}
```

---

## Paso 5 — Actualizar docs/TODO.md

---

## Reporte

```
## Etapa completada: COMPLIANCE
SPEC: {id}  |  módulo: {id_modulo}

### Resultado: ✅ PASS | ⚠️ PASS con advertencias | ❌ FAIL

| Severidad | Violaciones |
|---|---|
| 🔴 CRÍTICA | N |
| 🟠 ALTA | N |
| 🟡 MEDIA | N |
| 🟢 BAJA | N |

### Reporte guardado
docs/reports/compliance-{YYYY-MM-DD}.md

### Próxima etapa
fac-data-stage-testing {id_modulo}   (si PASS)
Corregir violaciones → volver a BUILD  (si FAIL)
```
