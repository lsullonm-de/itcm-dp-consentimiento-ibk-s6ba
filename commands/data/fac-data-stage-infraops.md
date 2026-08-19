# fac-data-stage-infraops — Configuración InfraOps

Genera la configuración declarativa del framework InfraOps — `infra_dev.json`, `infra_prd.json`
y los YAMLs de `infra/service_accounts/` e `infra/iam/` — que el framework `itcm-dp-infraops-build`
ejecuta vía Cloud Build para crear SAs y asignar roles IAM.

**Bloque:** RELEASE — primer paso. Prerequisito para que el framework Dataops pueda desplegar.

> Cargar skill: `@.claude/data/skills/release/infraops-configurator/SKILL.md`
> Estándares: `@.claude/data/standard/services/service-accounts.md` ·
>             `@.claude/data/standard/architecture/gcp-organization.md`

**Invocación:**
```
fac-data-stage-infraops
fac-data-stage-infraops {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado y que DATAOPS está completado.

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: INFRAOPS`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Leer fuentes de verdad

Leer `docs/specs/*.yaml` (bloque `seguridad.permisos` + `componentes`) y los `deploy/env_*.json` existentes.
Identificar SAs requeridas (tipo `-job` o `-app`) y los permisos por recurso.

---

## Paso 2 — Generar YAMLs en `infra/`

Siguiendo el skill `@.claude/data/skills/release/infraops-configurator/SKILL.md`:

- Crear `infra/service_accounts/[empresa]-[caso]-[tipo].yaml` por cada SA
- Crear `infra/iam/[empresa]-[caso]-[tipo]-bindings.yaml` por cada SA
- Usar variables `${env}`, `${project_id}`, `${project_*}`, `${dataset_*}`, `${bucket_*}` — nunca hardcodear

**Regla de SA por componente:**

| Componente | Tipo SA | Sufijo |
|---|---|---|
| `cloud_run`, `cloud_function` | Servicios en ejecución | `-app` |
| `workflow`, `vertex_pipeline`, `cloud_scheduler` | Procesamiento / orquestación | `-job` |
| Cloud Build | Despliegue | `-deployer` (gestión centralizada) |

---

## Paso 3 — Generar manifests InfraOps

Generar `deploy/infra_dev.json` y `deploy/infra_prd.json` apuntando a los YAMLs creados.
Ambos archivos pueden apuntar a los mismos YAMLs (las variables `${env}` se resuelven por ambiente).

---

## Paso 4 — Backup versionado de infra JSONs

```bash
mkdir -p deploy/backup
TIMESTAMP=$(date +%Y%m%d%H%M%S)
cp deploy/infra_dev.json deploy/backup/infra_dev_${TIMESTAMP}.json
cp deploy/infra_prd.json deploy/backup/infra_prd_${TIMESTAMP}.json
```

---

## Paso 5 — Actualizar env JSON

Agregar a `deploy/env_dev.json` y `deploy/env_prd.json` las variables nuevas referenciadas en `infra/`.
Mantener el orden de agrupación estándar.

---

## Paso 6 — Actualizar `docs/TODO.md`

```
## Etapa completada: INFRAOPS
→ Próximo paso: fac-data-stage-security
```

---

## Reporte

```
## Etapa completada: INFRAOPS
SPEC: {id}  |  módulo: {id_modulo}

### Artefactos creados
- ✅ infra/service_accounts/       (YAMLs por SA)
- ✅ infra/iam/                    (YAMLs de bindings)
- ✅ deploy/infra_dev.json         (manifest InfraOps dev)
- ✅ deploy/infra_prd.json         (manifest InfraOps prd)
- ✅ deploy/backup/infra_*_{TIMESTAMP}.json  (backups)
- ✅ docs/TODO.md: ítems de INFRAOPS marcados

### Próxima etapa
fac-data-stage-security {id_modulo}
```
