# fac-data-stage-monitoring — Control de Procesos

Instrumenta el pipeline para control de procesos — genera los scripts de matrícula
(proceso + tareas vía API), modifica el workflow con sub-workflows de tracking y actualiza
la firma de los SPs con parámetros OUT de métricas.

**Bloque:** BUILD — entre ORCHESTRATION y DATA_QUALITY
**Condición:** solo ejecutar cuando `etapas.monitoring: true` en `spec.yaml`. Si es `false`, saltar.

> Cargar skill: `@.claude/data/skills/build/monitoring/process-monitor/SKILL.md`
> Estándar: `@.claude/data/standard/factory/monitoring.md`

**Invocación:**
```
fac-data-stage-monitoring
fac-data-stage-monitoring {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json · data/bigquery/{dataset_out}/{tabla_out}/
```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: MONITORING`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Verificar prerequisito

Verificar que `etapas.monitoring: true` en el spec y que el bloque `monitoring:` existe con:
- `METADATA_API_URL`
- `process.code`
- Al menos 1 tarea en `tasks[]`

Si falta el bloque `monitoring:` → pedir al usuario que lo complete antes de continuar.

Si `etapas.monitoring: false`:
```
⏭️ MONITORING no aplica para este módulo (etapas.monitoring: false)
   Usar fac-data-spec-update "etapas: activar monitoring" para habilitarlo.
   Continuando con fac-data-stage-data-quality
```

---

## Paso 2 — Ejecutar skill

Leer en paralelo:
```
1. {ruta del spec.yaml}                                              → fuente de verdad
2. deploy/env_dev.json                                               → variables de despliegue
3. pipeline/workflow/{dataset_out}/{tabla_out}/wf-*.yaml             → workflow(s) existente(s) (para modificar)
4. data/bigquery/{dataset_out}/{tabla_out}/sp/sp_*.sql               → SPs existentes (para agregar parámetros OUT)
```

Cargar y seguir el skill `@.claude/data/skills/build/monitoring/process-monitor/SKILL.md` completo
(Pasos 2 al 6): scripts de matrícula, deploy JSON, env JSON, workflow, SPs.

---

## Paso 3 — Actualizar docs/TODO.md

```
## Etapa completada: MONITORING
→ Próximo paso: fac-data-stage-data-quality
```

---

## Reporte

```
## Etapa completada: MONITORING
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos modificados
- ✅ data/monitoring/{dataset_out}/{tabla_out}/payloads/process_{tabla_out}_{emp}.json y task_sp_{tabla_out}_{emp}.json  (payloads de matrícula — no scripts .sh, ver monitoring.md)
- ✅ pipeline/workflow/{dataset_out}/{tabla_out}/wf-{tabla_out_kebab}-{emp}.yaml    (sub-workflows de tracking agregados)
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_{tabla_out}_{emp}.sql     (parámetros OUT agregados)
- ✅ docs/TODO.md: ítems de MONITORING marcados

### Próxima etapa
fac-data-stage-data-quality {id_modulo}
```
