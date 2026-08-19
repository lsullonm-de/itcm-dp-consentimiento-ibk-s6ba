# Bulk Spec — Especificar Múltiples UCs

Crea y valida specs para varios casos de uso en secuencia.

**Formato de entrada** (separar por `;`):
```
UC-QUEST-02: Listar preguntas paginadas; UC-QUEST-03: Obtener pregunta por ID
```

UCs recibidos: **$ARGUMENTS**

---

## Instrucciones

1. **Parsea** los UCs del argumento. Cada elemento separado por `;` es un UC independiente.

2. **Para cada UC en orden**, ejecuta el ciclo completo de especificación:

   a. `/spec-create [UC-ID]: [descripción]`
      - Leer la fuente de verdad del schema del proyecto (definida en CLAUDE.md), `business-rules.md` y el spec del módulo antes de redactar
      - Respetar numeración de UC-IDs y RN-* existentes
      - Si el UC tiene diseño o mockup disponible (Figma, imagen, wireframe), incluirlo como contexto al redactar el spec — `/spec-create` lo documentará en la sección `**Mockup:**`

   b. `/spec-validate [UC-ID]`
      - Si hay bloqueantes → `/spec-validate [UC-ID] [sección]` y re-validar
      - Repetir hasta que no haya bloqueantes

   c. Mostrar confirmación: `✅ [UC-ID] spec aprobado` antes de pasar al siguiente

3. **No pases al siguiente UC** hasta que el anterior esté completamente validado.

---

## Reporte Final

Al terminar todos los UCs, presenta esta tabla:

| UC-ID | Nombre | Operación / Pantalla | Estado | Issues resueltos |
|-------|--------|---------------------|--------|-----------------|
| ...   | ...    | GET /ruta ó Dashboard/ProductList | ✅/❌  | N               |

Y confirma:
> 🏁 Todos los specs completados — el ingeniero debe revisar antes de `/bulk-implement-seq` o `/bulk-implement-par`
