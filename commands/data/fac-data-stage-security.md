# fac-data-stage-security — Auditoría de Seguridad

Audita que los permisos creados en INFRAOPS siguen least-privilege, verifica el tratamiento
de PII en outputs y valida que no hay accesos excesivos cross-project.

**Bloque:** RELEASE — después de INFRAOPS

**Invocación:**
```
fac-data-stage-security
fac-data-stage-security {id_modulo}
```

---

## Prerequisito

INFRAOPS completado — `infra/service_accounts/`, `infra/iam/` y `deploy/infra_*.json` existentes.

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: SECURITY`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Verificar permisos del spec

Para cada entrada en `seguridad.permisos`, confirmar que la SA tiene el rol indicado sobre el recurso.

Ver permisos mínimos por tipo de SA en `@.claude/data/standard/services/service-accounts.md`.

---

## Paso 2 — Verificar outputs sin PII

Si `seguridad.campos_pii_output = []`, verificar que el DDL y el SP no incluyen campos
de identificación personal (`tipo_doc`, `nro_doc`, `nombre`, `email`, `telefono`, `celular`).

---

## Paso 3 — Verificar hash iden_party (si aplica)

Si `seguridad.hash_iden_party = true`, verificar que el SP usa:
```sql
TO_HEX(SHA256(CONCAT(tipo_doc, nro_doc)))
```
y no persiste los campos originales en el output.

---

## Paso 4 — Verificar SA tipo correcto por componente

| Componente | SA esperada |
|---|---|
| `cloud_run`, `cloud_function` | SA tipo `-app` |
| `workflow`, `vertex_pipeline`, `cloud_scheduler` | SA tipo `-job` |

---

## Paso 5 — Actualizar docs/TODO.md

```
## Etapa completada: SECURITY
→ Próximo paso: fac-data-stage-documentation
```

---

## Reporte

```
## Etapa completada: SECURITY
SPEC: {id}  |  módulo: {id_modulo}

### Resultado: ✅ PASS | ⚠️ Advertencias | ❌ Issues críticos

| Verificación | Estado |
|---|---|
| Permisos least-privilege | ✅/⚠️/❌ |
| Sin PII en outputs | ✅/⚠️/❌ |
| Hash iden_party correcto | ✅/N/A |
| SA tipo correcto por componente | ✅/❌ |

### Próxima etapa
fac-data-stage-documentation {id_modulo}
```
