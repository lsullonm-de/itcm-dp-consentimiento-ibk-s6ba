# fac-data-phase-build — Construcción, Verificación y Release

Ejecuta los bloques BUILD → VERIFY → RELEASE completos en secuencia.
Cada etapa se ejecuta solo si está marcada como `true` en `docs/specs/*.yaml`.

---

## Prerequisito

Verificar antes de comenzar:
- Existe `docs/specs/spec-*.yaml` validado, en status `review` o `approved`
- El scaffold del repo está completo (`fac-data-init-project` ejecutado)
- El contrato de datos existe: `fac-data-stage-physical-design` ejecutado (más DISCOVERY si el
  `type` lo exigía — ver la matriz de `fac-data-phase-design`)

> Los diagramas de arquitectura **no** son prerequisito: se generan al cierre, en DOCUMENTATION.

Leer `etapas` del spec para determinar qué etapas correr:

```yaml
etapas:
  coding:        true/false   # BUILD
  orchestration: true/false   # BUILD
  integridad:    true/false   # BUILD — opcional, gate antes de la carga principal
  monitoring:    true/false   # BUILD — opcional
  data_quality:  true/false   # BUILD
  lineage:       true/false   # BUILD — opcional
  dataops:       true/false   # BUILD — cierra BUILD
  compliance:    true/false   # VERIFY
  testing:       true/false   # VERIFY — activar solo post-despliegue dev
  infraops:      true/false   # RELEASE
  security:      true/false   # RELEASE
  documentation: true/false   # RELEASE
```

Omitir silenciosamente las etapas marcadas `false` o `N/A`.

---

## ── BLOQUE BUILD ─────────────────────────────────────────────────

### Paso 0 — Reality check (siempre)

```
fac-data-stage-reality-check
```

Contrasta el spec contra los artefactos reales del repo y del framework Dataops: variables de
entorno definidas, claves de deploy, YAML de imagen, IAM y soporte de los scripts. Barato de
correr y es donde aparecen los errores que no rompen la validación del spec pero sí el build.

Si devuelve bloqueantes → corregirlos antes de escribir código. No tiene sentido construir
sobre una configuración que no va a desplegar.

### Paso 1 — CODING (si `coding: true`)

```
fac-data-stage-coding
```

- SP con lógica de negocio completa (el DDL ya viene de PHYSICAL_DESIGN)
- Para `vertex_ml`: componentes KFP completos + preprocessing + notebook
- Para `cloud_run_api`: FastAPI (model → router → function → repository) y registro en `main.py`
- Tests unitarios de SPs en `data/bigquery/{dataset_out}/{tabla_out}/test/`
- Fuente: `@.claude/data/skills/build/coding/[tipo]/SKILL.md`

### Paso 2 — ORCHESTRATION (si `orchestration: true`)

```
fac-data-stage-orchestration
```

- Cloud Workflow en `pipeline/workflow/{dataset_out}/{tabla_out}/` (uno por fuente)
- Cloud Scheduler en `pipeline/scheduler/{dataset_out}/{tabla_out}/` (uno por fuente)
- Patrones obligatorios: `set_vars`, `try/except`, `SyncBigQueryJob`, notificación mail
- Fuente: `@.claude/data/skills/build/orchestration/workflow-orchestration/SKILL.md`

### Paso 3 — INTEGRIDAD (si `integridad: true`)

```
fac-data-stage-integrity
```

- Gate de actualidad D-1 sobre la fuente principal (detiene el proceso si no hay datos, sin tablas BigQuery de por medio)
- SP de integridad con `OUT o_flag_detener`/`o_motivo_detencion`/`o_resultado_json`, consumido por el workflow vía `SyncBigQueryJobWithResults`
- Histórico por regla registrado en el Framework de Control de Procesos vía metadata API (`registro_resultados: true`)
- Exclusión de duplicados y llaves nulas (todas las fuentes) vía patrón `QUALIFY` en los SPs de carga
- Fuente: `@.claude/data/skills/build/integrity/integrity-rules-assistant/SKILL.md`

### Paso 4 — MONITORING (si `monitoring: true`)

```
fac-data-stage-monitoring
```

- Scripts de matrícula proceso+tareas vía API
- Sub-workflows de tracking en el workflow
- Parámetros OUT en SPs para métricas
- Fuente: `@.claude/data/skills/build/monitoring/process-monitor/SKILL.md`

### Paso 5 — DATA_QUALITY (si `data_quality: true`)

```
fac-data-stage-data-quality
```

- SP DQ con lógica completa
- Registros `dq_config` para el framework

### Paso 6 — LINEAGE (si `lineage: true`)

```
fac-data-stage-lineage
```

- Scripts de registro nodos/aristas/columnas vía API
- Actualizar deploy JSON con `lineage_register`
- Fuente: `@.claude/data/skills/build/lineage/lineage-configurator/SKILL.md`

### Paso 7 — DATAOPS (si `dataops: true`) — cierra BUILD

```
fac-data-stage-dataops
```

- `deploy/env_dev.json` y `env_prd.json` completos con todas las variables
- `deploy/deploy_dev.json` y `deploy_prd.json` con componentes en orden correcto
- Backup versionado en `deploy/backup/`
- Fuente: `@.claude/data/skills/build/dataops/dataops-configurator/SKILL.md`

### Paso 8 — Rules Check (al cerrar BUILD)

```
fac-data-rules-check
```

Verificar todo el código generado en BUILD. Si hay violaciones → corregir antes de continuar a VERIFY.

---

## ── BLOQUE VERIFY ────────────────────────────────────────────────

### Paso 9 — COMPLIANCE (si `compliance: true`)

```
fac-data-stage-compliance
```

- Auditoría estática del código contra todos los estándares
- Reporte en `docs/reports/compliance-{YYYY-MM-DD}.md`
- Fuente: `@.claude/data/skills/verify/compliance-reviewer/SKILL.md`

### Paso 10 — Sync TODO (al cerrar VERIFY)

```
fac-data-sync-todo
```

---

## ── BLOQUE RELEASE ───────────────────────────────────────────────

### Paso 11 — INFRAOPS (si `infraops: true`)

```
fac-data-stage-infraops
```

- YAMLs de SAs en `infra/service_accounts/`
- YAMLs de IAM en `infra/iam/`
- `deploy/infra_dev.json` y `infra_prd.json`
- Fuente: `@.claude/data/skills/release/infraops-configurator/SKILL.md`

### Paso 12 — SECURITY (si `security: true`)

```
fac-data-stage-security
```

- Auditar permisos (least-privilege)
- Verificar tratamiento de PII en outputs
- Verificar hash `iden_party` si aplica

### Paso 13 — DOCUMENTATION (si `documentation: true`)

```
fac-data-stage-documentation
```

- Catálogo de datos en `data/data_catalog/`
- Glosario en `data/standard/business-glossary/`
- README del repo actualizado
- **Diagramas de arquitectura** (`fac-data-diagrams`) — generados acá, contra lo que realmente
  se construyó, no contra el diseño previo

### Paso 14 — Sync TODO (al cerrar RELEASE)

```
fac-data-sync-todo
```

---

## ── BLOQUE TESTING (post-despliegue) ────────────────────────────

> **⏸️ Pausa requerida antes de continuar:**
> Ejecutar los triggers Cloud Build en este orden:
> 1. **Trigger InfraOps** — crea SAs y asigna roles IAM en GCP
> 2. **Trigger Dataops (dev)** — despliega DDL, SPs, CFs, Workflows usando las SAs ya creadas
>
> Confirmar que ambos triggers finalizaron con estado SUCCESS antes del Paso 15.
> Luego activar `testing: true` en el spec con `fac-data-spec-update`.

### Paso 15 — TESTING (si `testing: true`)

```
fac-data-stage-testing
```

- Validación dinámica en dev vía MCP BigQuery
- Reporte en `docs/reports/testing-{YYYY-MM-DD}.md`
- Fuente: `@.claude/data/skills/verify/bigquery-mcp-validator/SKILL.md`

> **`testing: false` por defecto.** Activar manualmente solo tras confirmar despliegue exitoso en dev.

---

## Reporte Final

| Bloque | Etapa | Estado |
|--------|-------|--------|
| BUILD | reality-check | ✅/❌ |
| BUILD | CODING | ✅/❌/N/A |
| BUILD | ORCHESTRATION | ✅/❌/N/A |
| BUILD | INTEGRIDAD | ✅/❌/N/A |
| BUILD | MONITORING | ✅/❌/N/A |
| BUILD | DATA_QUALITY | ✅/❌/N/A |
| BUILD | LINEAGE | ✅/❌/N/A |
| BUILD | DATAOPS | ✅/❌/N/A |
| VERIFY | rules-check | ✅/❌ |
| VERIFY | COMPLIANCE | ✅/❌/N/A |
| RELEASE | INFRAOPS | ✅/❌/N/A |
| RELEASE | SECURITY | ✅/❌/N/A |
| RELEASE | DOCUMENTATION | ✅/❌/N/A |
| TESTING | TESTING | ✅/❌/N/A |

> 🏁 Ciclo completo — listo para merge/deploy trigger prd.
