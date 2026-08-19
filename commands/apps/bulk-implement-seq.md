# Bulk Implement — Secuencial

Implementa múltiples UCs uno a la vez, en orden estricto.

**Cuándo usar:** UCs del mismo módulo que comparten archivos
(controller, module.ts, repositorios comunes).

**Formato de entrada** (separar por `;`):
```
UC-QUEST-02; UC-QUEST-03; UC-QUEST-04
```

UCs recibidos: **$ARGUMENTS**

---

## Prerequisito

Verifica que cada UC-ID en `$ARGUMENTS` tenga un spec aprobado en
`claude_workspace/architecture/feature_spec/`. Si alguno no tiene spec, detente
e indica qué UCs faltan antes de implementar.

---

## Instrucciones

1. **Parsea** los UCs del argumento (separados por `;`).

2. **Para cada UC en orden**:

   a. `/spec-code [UC-ID]`
      - Implementar en orden: domain entity → output port → service →
        DTOs + mapper → TypeORM entity → repository → controller → module

   b. `/spec-code-validate [UC-ID]`
      - Si hay gaps → corrige solo la parte faltante → re-valida
      - Repetir hasta que no haya gaps

   c. Mostrar: `✅ [UC-ID] implementado y validado` antes de pasar al siguiente

3. **No pases al siguiente UC** hasta que el anterior esté completamente validado.

---

## Reporte Final

| UC-ID | Capas creadas | Validación | Estado |
|-------|--------------|------------|--------|
| ...   | 8/8          | ✅         | Listo  |

> 🏁 Implementación secuencial completa — pendiente code review del ingeniero (Gate 2)
