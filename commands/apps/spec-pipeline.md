# UC Pipeline — Ciclo Completo (Spec + Impl + Quality)

Orquesta las tres fases del ciclo de desarrollo para uno o varios UCs,
con pausas obligatorias para revisión del ingeniero entre fases.

**Formato de entrada** (separar por `;`):
```
UC-QUEST-02: Listar preguntas; UC-QUEST-03: Obtener pregunta por ID
```
O solo los IDs si los specs ya existen:
```
UC-QUEST-02; UC-QUEST-03
```

UCs recibidos: **$ARGUMENTS**

---

## ━━━ FASE 1 — ESPECIFICACIÓN (secuencial) ━━━

Para cada UC en `$ARGUMENTS`:

1. Si el spec NO existe → `/spec-create [UC-ID]: [descripción]`
2. `/spec-validate [UC-ID]`
   - Si hay bloqueantes → `/spec-validate [UC-ID] [sección]` y re-validar
   - Repetir hasta aprobar
3. Confirmar `✅ [UC-ID] spec aprobado`

**Al terminar todos los specs, DETENTE.**

Muestra esta tabla de resumen:

| UC-ID | Endpoint | Actor | RN aplicadas | Estado |
|-------|----------|-------|--------------|--------|
| ...   | ...      | ...   | ...          | ✅     |

```
⏸️  GATE 1 — Esperando aprobación del ingeniero.
    Responde "ok" para implementar, o indica correcciones.
```

---

## ━━━ FASE 2 — IMPLEMENTACIÓN ━━━

*(Solo continúa si el ingeniero aprobó Gate 1)*

Evalúa si los UCs son del mismo módulo o de módulos distintos:
- **Mismo módulo** → usa la estrategia secuencial
- **Módulos distintos** → lanza subagentes simultáneos (uno por UC)

Para cada UC:
1. `/spec-code [UC-ID]` — las 8 capas
2. `/spec-code-validate [UC-ID]` — hasta que no haya gaps

**Al terminar todos, DETENTE.**

Muestra resumen de archivos creados por UC.

```
⏸️  GATE 2 — Esperando code review del ingeniero.
    Responde "ok" para ejecutar calidad, o indica correcciones.
```

---

## ━━━ FASE 3 — CALIDAD ━━━

*(Solo continúa si el ingeniero aprobó Gate 2)*

1. `/rules-check` — pasada global, corregir violaciones antes de continuar
2. Para cada UC → `/test-coverage [UC-ID]` hasta coverage > 85%
3. `/sync-todo` — marcar UCs como ✅ en TODO.md

---

## Reporte Final

| UC-ID | Spec | Impl | Tests | TODO | Estado |
|-------|------|------|-------|------|--------|
| ...   | ✅   | ✅   | ✅    | ✅   | 🚀 PR  |

> 🏁 Pipeline completo — UCs listos para Pull Request
