# fac-data-stage-dataops — Configuración Dataops

Parametriza todos los artefactos y genera los archivos de despliegue completos.
Cierra el bloque BUILD. Sin esta etapa, COMPLIANCE no puede auditar las configs
y TESTING no tiene variables de entorno para ejecutar.

**Bloque:** BUILD — cierra BUILD, prerequisito para VERIFY

> Cargar skill: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

**Invocación:**
```
fac-data-stage-dataops
fac-data-stage-dataops {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json · deploy/deploy_dev.json
```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: DATAOPS`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.dataops: true` en el spec antes de continuar.

---

## Paso 1 — Backup versionado de deploy JSONs (ANTES de modificar)

**Obligatorio — ejecutar PRIMERO, antes de tocar cualquier archivo:**

```bash
mkdir -p deploy/backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
cp deploy/deploy_dev.json deploy/backup/deploy_dev_${TIMESTAMP}.json
cp deploy/deploy_prd.json deploy/backup/deploy_prd_${TIMESTAMP}.json
cp deploy/env_dev.json    deploy/backup/env_dev_${TIMESTAMP}.json
cp deploy/env_prd.json    deploy/backup/env_prd_${TIMESTAMP}.json
```

> `deploy/backup/` no es leído por el framework — es historial de auditoría.
> El backup cubre también `env_*.json` para que el estado completo sea recuperable.

---

## Paso 2 — Reemplazar `deploy/deploy_dev.json` y `deploy/deploy_prd.json`

> **REGLA:** los archivos `deploy_[env].json` se **limpian y reescriben** en cada ejecución
> DATAOPS — no se acumulan ni se mezclan con ejecuciones anteriores.
> Solo quedan los componentes declarados en el módulo actual del `project.manifest.yaml`.

Generar desde cero con los componentes del spec en el orden obligatorio:
```
bigquery_ddl → bigquery_sp → bigquery_dml → cloudsql_ddl → image → cloud_run →
vertex_pipeline → cloud_function → pubsub → workflow → cloud_scheduler →
monitoring_register → lineage_register
```

Incluir solo las claves con al menos un elemento. Omitir las claves vacías.

---

## Paso 3 — Completar `deploy/env_dev.json`

Revisar todos los archivos del repo (DDL, SP, Workflow) y extraer **todas** las variables `${...}` usadas.
Asegurarse que `env_dev.json` las contiene todas, con valores reales de dev.

Orden obligatorio: variables por tabla (project → dataset → table agrupados), luego generales.
Variable `env` excluida — es global del framework.

---

## Paso 4 — Completar `deploy/env_prd.json`

Misma estructura que `env_dev.json`, con valores de producción.

---

## Paso 5 — Validar cobertura de variables

Verificar que no quede ninguna variable `${...}` en los archivos SQL/YAML sin su correspondiente
entrada en `env_dev.json`:

```bash
grep -r '\${' data/ pipeline/ service/ | grep -v env_dev | grep -v env_prd
```

Si hay variables no cubiertas → agregarlas en env_dev.json y reportar.

---

## Paso 6 — Actualizar docs/TODO.md

```
## Etapa completada: DATAOPS
→ Próximo paso: fac-data-rules-check y luego fac-data-stage-compliance
```

---

## Reporte

```
## Etapa completada: DATAOPS
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos modificados
- ✅ deploy/backup/deploy_dev_{TIMESTAMP}.json  (backup previo)
- ✅ deploy/backup/deploy_prd_{TIMESTAMP}.json  (backup previo)
- ✅ deploy/backup/env_dev_{TIMESTAMP}.json     (backup previo)
- ✅ deploy/backup/env_prd_{TIMESTAMP}.json     (backup previo)
- ✅ deploy/deploy_dev.json   (reemplazado — {N} componentes del módulo {id_modulo})
- ✅ deploy/deploy_prd.json   (ídem)
- ✅ deploy/env_dev.json      (variables completas para dev)
- ✅ deploy/env_prd.json      (variables completas para prd)
- ✅ docs/TODO.md: ítems de DATAOPS marcados

### Variables pendientes (si las hay)
- {variable}: {descripción}

### Próxima etapa
fac-data-rules-check → fac-data-stage-compliance {id_modulo}
```
