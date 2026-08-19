# fac-data-stage-orchestration — Orquestación

Implementa el Cloud Workflow y Cloud Scheduler que orquestan el proceso completo.

**Bloque:** BUILD — después de CODING
**Condición:** aplica cuando `etapas.orchestration: true` en el spec.

> Cargar skill: `@.claude/data/skills/build/orchestration/workflow-orchestration/SKILL.md`
> Estándar sintáctico: `@.claude/data/standard/services/workflow.md`

**Invocación:**
```
fac-data-stage-orchestration
fac-data-stage-orchestration {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json · pipeline/workflow/{dataset_out}/{tabla_out}/
```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: ORCHESTRATION`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.orchestration: true` en el spec antes de continuar.

---

## Paso 1 — Leer contexto

Leer en paralelo:
```
1. {ruta del spec.yaml}                                          → fuente de verdad (componentes, scheduling, fuentes[])
2. deploy/env_dev.json                                           → variables de despliegue
3. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml         → skeleton(s) de workflow existente(s) (de init-project)
4. data/bigquery/{dataset_out}/{tabla_out}/sp/*.sql              → SPs a invocar (para nombres exactos)
```

---

## Paso 2 — Diseñar la secuencia de orquestación

Leer los componentes del spec y decidir:
- Qué pasos van en paralelo vs secuencial (ver criterios en workflow-orchestration)
- Qué tipo de invocación requiere cada componente (SP / Vertex / API / sub-workflow)

---

## Paso 3 — Implementar Workflow

> **Regla de cardinalidad por fuente:** si `fuentes[]` tiene más de un origen para la misma
> tabla output, crear **un workflow independiente por fuente** — nunca un solo workflow con N
> pasos de SP. Ver `@.claude/data/skills/build/orchestration/workflow-orchestration/SKILL.md` Paso 0.5.

Por cada fuente `{emp}`, crear `pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-
{emp}.yaml` con la estructura completa.
Ver patrones por tipo de componente en `@.claude/data/skills/build/orchestration/workflow-orchestration/SKILL.md`.

Aplicar patrones obligatorios:
- `set_vars` al inicio con todas las variables
- `try/except` en cada step con manejo de errores
- `SyncBigQueryJob` para invocación de SPs
- `verificar_email_body` para notificación por mail al final

**Regla crítica:** strings en expresiones `${}` sin `": "` — ver `@.claude/data/standard/services/workflow.md`.

---

## Paso 4 — Implementar Cloud Scheduler

Por cada workflow del Paso 3, crear su `pipeline/scheduler/{dataset_out}/{tabla_out}/
cs-{tabla_out_kebab}-{emp}.yaml` correspondiente:
- `schedule`: frecuencia del spec (`scheduling.frecuencia`)
- `timeZone`: `scheduling.zona_horaria` (default `America/Lima`)
- SA tipo `-job` (vía variable `${service_account_job}`)

---

## Paso 5 — Actualizar docs/TODO.md

```
## Etapa completada: ORCHESTRATION
→ Próximo paso: fac-data-stage-monitoring (si aplica) o fac-data-stage-data-quality
```

---

## Reporte

```
## Etapa completada: ORCHESTRATION
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos creados
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml      (uno por fuente)
- ✅ pipeline/scheduler/{dataset_out}/{tabla_out}/cs-{tabla_out_kebab}-{emp}.yaml     (uno por fuente)
- ✅ docs/TODO.md: ítems de ORCHESTRATION marcados

### Próxima etapa
fac-data-stage-monitoring {id_modulo}   (si etapas.monitoring: true)
fac-data-stage-data-quality {id_modulo} (si etapas.monitoring: false)
```
