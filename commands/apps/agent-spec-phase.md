# Monday Spec Agent — Agente 1: Especificación Automática

Agente autónomo que consulta Monday.com, procesa tareas nuevas o modificadas,
genera/actualiza specs, valida, construye el plan de implementación y notifica
al usuario de Windows cuando el plan está listo para revisión.

**Diseñado para correr desatendido** (scheduled o manual).
No espera input del usuario — persiste el estado y notifica al terminar.

**Argumentos opcionales:** `$ARGUMENTS`
- Sin argumentos → lee `MONDAY_BOARD_ID` del `claude_workspace/.env`
- Con argumento → usa ese board ID

---

## ━━━ PASO 0 — Verificar rama base ━━━

Leer la variable de entorno `ACTIVE_PULL_REQUEST` (valores válidos: `true` / `1`; cualquier otro valor o ausencia se trata como `false`).

**Si `ACTIVE_PULL_REQUEST=true`:**

Asegurarse de estar en `master` y con el working tree limpio antes de generar specs:

```bash
git checkout master
git pull origin master
```

Si hay cambios sin commitear en el working tree:
```
⚠️  Hay cambios sin commitear en la rama actual.
    No es posible continuar para evitar mezclar trabajo en curso con los specs nuevos.
    Commiteá o stasheá los cambios y volvé a ejecutar /agent-spec-phase.
```
**TERMINAR**

**Si `ACTIVE_PULL_REQUEST=false` (o no está definida):**

No realizar checkout ni pull. Verificar únicamente que el working tree esté limpio (sin cambios sin commitear):

```bash
git status --short
```

- Si hay cambios sin commitear y **Si `CONTINUE_WORKING=false` (o no está definida)** → mostrar la advertencia anterior y **TERMINAR**
- Si está limpio o **`CONTINUE_WORKING=true`** → continuar desde la rama actual sin modificarla

Registrar la rama actual para usarla en pasos posteriores:

```bash
git branch --show-current
```

---

## ━━━ PASO 1 — Leer Board Monday ━━━

1. Determinar `BOARD_ID`:
   - Si `$ARGUMENTS` tiene valor → usar ese
   - Si no → leer variable `MONDAY_BOARD_ID` del archivo `.env` del proyecto

2. Via MCP Monday, obtener ítems con status `"To Do"` o `"Backlog"` o `"En Proceso"`:
   ```
   mcp_monday_get_items(boardId, statusFilter: ["To Do", "Backlog", "En Proceso"])
   ```

3. Si no hay ítems nuevos:
   - Escribir en `claude_workspace/pending-plans/last-check.txt` la fecha/hora actual
   - Ejecutar notificación: `Sin tareas nuevas en Monday` (nivel: info silencioso)
   - **TERMINAR** — no hay trabajo que hacer

4. Para cada ítem, extraer:
   | Campo Monday       | Variable local    |
   |--------------------|-------------------|
   | `item.id`          | `monday_item_id`  |
   | columna `UC-ID`    | `uc_id`           |
   | columna `Descripción`    | `description`           |
   | columna `Módulo`   | `module`          |
   | `item.name`        | `uc_name`         |
   | columna `Status`   | `status`          |
   | `item.updated_at`  | `updated_at`      |

---

## ━━━ PASO 2 — Clasificar cada ítem ━━━

Para cada ítem obtenido, determinar la acción requerida:

**¿Es spec nuevo o actualización?**
- Identificar el caso de uso con Grep el `descripcion` dentro de `claude_workspace/architecture/feature_spec/`
- Si **NO existe** → acción: `CREATE_SPEC`
- Si **existe** → comparar `item.updated_at` con fecha de última modificación del spec
  - Si Monday es más reciente → acción: `UPDATE_SPEC`
  - Si spec es más reciente → acción: `SKIP` (ya procesado)

Construir tabla de clasificación:

| UC-ID | Nombre | Módulo | Acción | Motivo |
|-------|--------|--------|--------|--------|
| ...   | ...    | ...    | CREATE_SPEC / UPDATE_SPEC / SKIP | ... |

Ignorar los ítems con acción `SKIP`.

**Crear/cambiar a rama feature** a partir de los ítems con acción `CREATE_SPEC` o `UPDATE_SPEC`:

- Módulo único → `feat/[modulo]-[uc-ids separados por -]`
  - ej: `feat/sales-UC-SALES-01-UC-SALES-02`
- Múltiples módulos → `feat/[uc-ids separados por -]`
  - ej: `feat/UC-SALES-01-UC-INV-02`

**Si `ACTIVE_PULL_REQUEST=true`:**

Crear o cambiar a la rama feature:

```bash
# Si la rama no existe
git checkout -b [nombre-de-rama]

# Si la rama ya existe (agente re-ejecutado sobre los mismos ítems)
git checkout [nombre-de-rama]
```

**Si `ACTIVE_PULL_REQUEST=false` (o no está definida):**

No cambiar de rama. Continuar trabajando en la rama actual detectada en el PASO 0.
El nombre de rama que se registrará en el plan JSON será la rama actual.

Registrar el nombre de rama en el estado interno para incluirlo luego en el plan JSON (`"branch"`).

---

## ━━━ PASO 3 — Procesar Specs ━━━

Para cada ítem con acción `CREATE_SPEC` o `UPDATE_SPEC` (secuencial):

### Si CREATE_SPEC:
1. `/spec-create [uc_id]: [uc_name]`
2. `/spec-validate [uc_id]`
   - Si bloqueantes → `/spec-validate [uc_id]` corregir y re-validar
   - Máximo 3 iteraciones; si persisten bloqueantes → marcar `spec_status: NEEDS_REVIEW`
3. Marcar `spec_status: APPROVED` si pasa sin bloqueantes

### Si UPDATE_SPEC:
1. Leer el ítem Monday para identificar qué cambió (descripción, criterios de aceptación, RN)
2. `/spec-validate [uc_id] [sección afectada]`
3. `/spec-validate [uc_id]`
   - Si bloqueantes → corregir y re-validar (máximo 3 iteraciones)
4. Marcar `spec_status: APPROVED` o `NEEDS_REVIEW`

---

## ━━━ PASO 4 — Generar Plan de Implementación ━━━

Solo para ítems con `spec_status: APPROVED`:

Para cada UC, generar:
```json
{
  "uc_id": "UC-SALES-01",
  "monday_item_id": "...",
  "uc_name": "...",
  "module": "sales",
  "spec_path": "claude_workspace/architecture/feature_spec/02-sales/spec.md",
  "artefacts": [
    "core/domain/entities/sale.entity.ts",
    "core/application/ports/out/sales/sale-repository.port.ts",
    "core/application/ports/in/sales/create-sale.port.ts",
    "core/application/services/sales/create-sale.service.ts",
    "core/application/dtos/sales/create-sale-request.dto.ts",
    "core/application/dtos/sales/sale-response.dto.ts",
    "core/application/mappers/sales/sale.mapper.ts",
    "infrastructure/adapters/secondary/persistence/repositories/typeorm-sale.repository.ts",
    "infrastructure/adapters/primary/rest/sales/sales.controller.ts",
    "infrastructure/modules/sales.module.ts",
    "test/unit/sales/create-sale.service.spec.ts"
  ],
  "strategy": "sequential | parallel",
  "dependencies": []
}
```

Determinar estrategia global:
- Todos del mismo módulo → `sequential`
- Módulos distintos → `parallel` (subagentes por módulo)

---

## ━━━ PASO 5 — Persistir Estado ━━━

Generar timestamp: `YYYY-MM-DD-HHmmss`

Escribir archivo `claude_workspace/pending-plans/plan-[timestamp].json`:
```json
{
  "created_at": "[ISO timestamp]",
  "status": "pending_approval",
  "board_id": "[BOARD_ID]",
  "summary": {
    "total_items": 0,
    "approved_specs": 0,
    "needs_review": 0,
    "skipped": 0
  },
  "uc_items": [...],
  "implementation_plan": {
    "strategy": "sequential | parallel",
    "execution_order": ["UC-ID-1", "UC-ID-2"],
    "estimated_artefacts": 0
  },
  "needs_review_items": []
}
```

También actualizar `claude_workspace/pending-plans/latest.txt` con la ruta al archivo recién creado.

---

## ━━━ PASO 6 — Notificar al Usuario de Windows ━━━

Construir el mensaje de notificación con los UCs aprobados.

Ejecutar via Bash — estrategia en cascada (intentar cada método hasta que uno funcione):

**Método 1 — BurntToast (preferido, nativo y confiable):**
```bash
powershell -ExecutionPolicy Bypass -Command "
if (Get-Module -ListAvailable -Name BurntToast) {
  Import-Module BurntToast;
  New-BurntToastNotification -Text 'Claude Code — Plan listo', 'Specs generados: [N] UCs. Ejecuta /agent-impl-phase para implementar.'
} else { exit 1 }
"
```

**Método 2 — Toast con AppId de PowerShell (si BurntToast no está instalado):**
```bash
powershell -Command "
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
\$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>Claude Code — Plan listo</text><text>Specs generados: [N] UCs. Ejecuta /agent-impl-phase</text></binding></visual></toast>');
\$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml;
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}/WindowsPowerShell/v1.0/powershell.exe').Show(\$toast)
"
```

**Método 3 — MessageBox (fallback universal):**
```bash
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('Specs generados: [N] UCs. Ejecuta /agent-impl-phase para implementar.', 'Claude Code — Plan listo', 'OK', 'Information')"
```

Intentar los métodos en orden. Si el Método 1 falla (BurntToast no instalado), probar Método 2. Si también falla, usar Método 3 que siempre funciona.

---

## ━━━ PASO 7 — Reporte Final del Agente ━━━

Imprimir resumen en consola (para logs del scheduler):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Monday Spec Agent — [timestamp]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Board ID    : [BOARD_ID]
  Items found : [N]
  Approved    : [N] specs listos para implementar
  Needs review: [N] requieren intervención manual
  Skipped     : [N] ya procesados

  Plan guardado en:
  claude_workspace/pending-plans/plan-[timestamp].json

  ✅ Notificación enviada al usuario
  👉 Siguiente paso: /agent-impl-phase
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**TERMINAR** — el agente no espera respuesta del usuario.
