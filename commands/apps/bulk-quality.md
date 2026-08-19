# Bulk Quality — Fase de Calidad para Múltiples UCs

Ejecuta la fase de calidad completa para un conjunto de UCs implementados.

**Formato de entrada** (separar por `;`):
```
UC-QUEST-02; UC-QUEST-03; UC-QUEST-04
```

UCs recibidos: **$ARGUMENTS**

---

## Paso 1 — Check Rules (pasada global)

Invoca `/rules-check`.

Verifica para **todo el código modificado**:
- ❌ No `any` en TypeScript
- ❌ Domain no importa Infrastructure
- ❌ No hard delete — solo soft delete
- ❌ Toda query filtra `WHERE is_deleted = false`
- ❌ Auditoría: `created_user_id` / `updated_user_id` = `JWT.sub`
- ❌ Lógica de negocio en services, no en controllers

Si hay violaciones → corrígelas todas antes de continuar al Paso 2.

---

## Paso 2 — Test Coverage (por UC)

Para **cada UC-ID** en `$ARGUMENTS`, en orden:

1. `/test-coverage [UC-ID]`
   - Unit tests del service: cobertura > 85% en branches, functions, lines
   - E2E: casos felices + casos de error del spec
   - Si coverage < 85% → agrega tests faltantes → re-ejecuta

2. Confirma `✅ [UC-ID] coverage OK` antes de pasar al siguiente UC.

---

## Paso 3 — Sync TODO (pasada global al final)

Una vez que todos los UCs tengan coverage aprobado:

Invoca `/sync-todo`.

Marca cada UC de `$ARGUMENTS` como `✅ completado` en `claude_workspace/TODO.md`.
Actualiza contadores y fecha de última actualización.

---

## Reporte Final

| UC-ID | rules-check | Coverage | Tests E2E | TODO | Estado |
|-------|-------------|----------|-----------|------|--------|
| ...   | ✅          | XX%      | ✅        | ✅   | Listo  |

> 🏁 Fase de calidad completa — UCs listos para PR
