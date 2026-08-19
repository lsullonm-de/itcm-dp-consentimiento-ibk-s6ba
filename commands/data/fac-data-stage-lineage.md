# fac-data-stage-lineage — Registro de Linaje

Registra el grafo de linaje del pipeline — nodos (assets), aristas (relaciones entre assets
vía SPs) y trazabilidad columnar opcional — vía API REST durante el despliegue con Cloud Build.

**Bloque:** BUILD — después de DATA_QUALITY, antes de DATAOPS
**Condición:** solo ejecutar cuando `etapas.lineage: true` en `spec.yaml`. Si es `false`, saltar.

> Cargar skill: `@.claude/data/skills/build/lineage/lineage-configurator/SKILL.md`
> Estándar: `@.claude/data/standard/factory/lineage.md`

**Invocación:**
```
fac-data-stage-lineage
fac-data-stage-lineage {id_modulo}
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
2. Si no → buscar módulo con `etapa_actual: LINEAGE`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.lineage: true`. Si es `false`:
```
⏭️ LINEAGE no aplica para este módulo (etapas.lineage: false)
   Continuando con fac-data-stage-dataops
```

---

## Paso 1 — Verificar prerequisito

Verificar `etapas.lineage: true` en el spec. Si el bloque `lineage:` no existe aún,
derivarlo de `spec.fuentes[]` y `spec.outputs[]` antes de generar los artefactos.

Leer en paralelo:
```
1. {ruta del spec.yaml}         → fuentes, outputs, componentes
2. deploy/env_dev.json          → variables de despliegue
3. deploy/deploy_dev.json       → para agregar entradas de lineage
```

---

## Paso 2 — Ejecutar skill

Seguir el skill `@.claude/data/skills/build/lineage/lineage-configurator/SKILL.md` completo
(Pasos 2 al 5): derivar grafo, payloads JSON, actualizar deploy JSON. No se generan scripts
`.sh` en el repositorio del módulo — el registro es 100% vía payloads JSON + API
(`metadata_register.sh` vive en el framework compartido, fuera de este repo).

Naming de artefactos de linaje:
- `node_id`: `NODE-{PROYECTO}-{DATASET}-{TABLA}`
- `edge_id`: `EDGE-{NODE_SOURCE}-{NODE_TARGET}`
- `col_lineage_id`: `COLLINEAGE-{EDGE}-{CAMPO}`
- **Nombre de archivo** (distinto del `node_id`/`edge_id` interno): siempre derivado de
  `{tabla_out}` (prefijo) y `{emp}` (sufijo, si aplica) — `data/lineage/{dataset_out}/
  {tabla_out}/payloads/node_{tabla_out}[_{emp}].json` / `edge_sp_{tabla_out}_{emp}.json`.
  Nunca un slug libre — ver `@.claude/data/standard/factory/lineage.md` §6.

---

## Paso 3 — Actualizar docs/TODO.md

```
## Etapa completada: LINEAGE
→ Próximo paso: fac-data-stage-dataops
```

---

## Reporte

```
## Etapa completada: LINEAGE
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos creados
- ✅ data/lineage/{dataset_out}/{tabla_out}/payloads/node_{tabla_out}[_{emp}].json, edge_sp_{tabla_out}_{emp}.json
- ✅ deploy/deploy_dev.json          (actualizado con entradas lineage_register)
- ✅ docs/TODO.md: ítems de LINEAGE marcados

### Próxima etapa
fac-data-stage-dataops {id_modulo}
```
