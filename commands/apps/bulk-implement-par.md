# Bulk Implement — Paralelo

Implementa múltiples UCs simultáneamente usando subagentes independientes.

**Cuándo usar:** UCs de módulos distintos que NO comparten archivos.
Si los UCs tocan el mismo controller o module.ts, usa `/bulk-implement-seq`.

**Formato de entrada** (separar por `;`):
```
UC-QUEST-02; UC-ANSWERS-01; UC-AUTH-05
```

UCs recibidos: **$ARGUMENTS**

---

## Prerequisito

Verifica que:
1. Cada UC-ID tiene spec aprobado en `claude_workspace/architecture/feature_spec/`
2. Los UCs pertenecen a módulos distintos (no comparten archivos de infraestructura)

Si algún UC falta spec o hay conflicto de módulo, detente y reporta antes de continuar.

---

## Instrucciones

1. **Parsea** los UCs del argumento (separados por `;`).

2. **Lanza un subagente independiente por cada UC** de forma simultánea.

   Cada subagente debe:
   a. `/spec-code [UC-ID]`
      - Todas las capas: entity → port → service → DTOs → TypeORM entity → repo → controller → module
   b. `/spec-code-validate [UC-ID]`
      - Si hay gaps → corregir → re-validar
   c. Reportar resultado: `✅ [UC-ID] completo` o `❌ [UC-ID] error: [detalle]`

3. **Espera** a que todos los subagentes terminen antes de consolidar.

4. Si algún subagente falló, corrígelo de forma individual antes de reportar éxito global.

---

## Reporte Final

| UC-ID | Módulo | Capas | Validación | Estado |
|-------|--------|-------|------------|--------|
| ...   | ...    | 8/8   | ✅         | Listo  |

> 🏁 Implementación paralela completa — pendiente code review del ingeniero (Gate 2)

> ⚠️ Nota: si el proyecto no está inicializado como repositorio git (`git init`),
> los subagentes trabajan sobre los mismos archivos. Asegúrate de que los UCs
> sean verdaderamente independientes (no comparten archivos) antes de usar este comando.
