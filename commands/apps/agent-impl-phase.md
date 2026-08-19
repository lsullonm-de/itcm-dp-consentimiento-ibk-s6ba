# Monday Impl Agent — Agente 2: Implementación tras aprobación

Agente que el usuario dispara manualmente después de revisar el plan generado
por `/agent-spec-phase`. Lee el estado persistido, pide confirmación final
y ejecuta implementación + calidad + PR + sync Monday.

**Disparado por el usuario** luego de recibir la notificación de Windows.

**Argumentos opcionales:** `$ARGUMENTS`
- Sin argumentos → leer `claude_workspace/pending-plans/latest.txt` para obtener el plan más reciente
- Con ruta de plan → usar ese archivo específico (ej: `plan-2026-04-01-103045.json`)

---

## ━━━ PASO 1 — Cargar Plan Persistido ━━━

1. Determinar ruta del plan:
   - Si `$ARGUMENTS` tiene valor → `claude_workspace/pending-plans/[ARGUMENTS]`
   - Si no → leer `claude_workspace/pending-plans/latest.txt` y usar la ruta indicada

2. Si el archivo no existe o `status != "pending_approval"`:
   ```
   ⚠️  No hay ningún plan pendiente de aprobación.
       Ejecuta /agent-spec-phase primero para generar uno.
   ```
   **TERMINAR**

3. Leer el plan y mostrar resumen al usuario:

   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     Plan generado: [created_at]
     Board: [board_id]
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   ```

   | # | UC-ID | Nombre | Módulo | Artefactos | Spec |
   |---|-------|--------|--------|------------|------|
   | 1 | ...   | ...    | ...    | N          | ✅   |

   Estrategia de implementación: `sequential` | `parallel`
   Artefactos totales estimados: N

   Si hay ítems con `spec_status: NEEDS_REVIEW`:

   Notificar al usuario antes de pedir confirmación:
   ```bash
   powershell -ExecutionPolicy Bypass -Command "
   if (Get-Module -ListAvailable -Name BurntToast) {
     Import-Module BurntToast;
     New-BurntToastNotification -Text 'Claude Code — Revisión requerida', 'Algunos specs necesitan revisión manual. Respondé en Claude Code.'
   } else { exit 1 }
   " 2>/dev/null || powershell -Command "
   [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
   [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;
   \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
   \$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>Claude Code — Revisión requerida</text><text>Algunos specs necesitan revisión manual. Respondé en Claude Code.</text></binding></visual></toast>');
   \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml;
   [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}/WindowsPowerShell/v1.0/powershell.exe').Show(\$toast)
   "
   ```

   ```
   ⚠️  Los siguientes UCs requieren revisión manual del spec antes de implementar:
   [lista]
   ¿Continuar solo con los aprobados? Responde "ok" para continuar o "cancelar".
   ```

4. Notificar al usuario antes de pedir confirmación final:
   ```bash
   powershell -ExecutionPolicy Bypass -Command "
   if (Get-Module -ListAvailable -Name BurntToast) {
     Import-Module BurntToast;
     New-BurntToastNotification -Text 'Claude Code — Confirmación requerida', 'Plan listo para implementar. Respondé en Claude Code para continuar.'
   } else { exit 1 }
   " 2>/dev/null || powershell -Command "
   [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
   [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;
   \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
   \$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>Claude Code — Confirmación requerida</text><text>Plan listo para implementar. Respondé en Claude Code para continuar.</text></binding></visual></toast>');
   \$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml;
   [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}/WindowsPowerShell/v1.0/powershell.exe').Show(\$toast)
   "
   ```

   Pedir confirmación final:
   ```
   ⏸️  ¿Confirmás la implementación de los UCs listados?
       Responde "ok" para implementar, "cancelar" para abortar,
       o lista los UC-IDs a excluir (ej: "ok sin UC-SALES-03").
   ```

5. Actualizar `status` del plan a `"in_progress"` en el JSON.

6. Resolver la rama de trabajo según `ACTIVE_PULL_REQUEST`:

   **Si `ACTIVE_PULL_REQUEST=true`:**

   Leer el campo `"branch"` del plan JSON y hacer checkout:
   ```bash
   git checkout [branch del plan]
   ```
   > La rama ya existe y contiene los specs generados por `/agent-spec-phase`.
   > Toda la implementación se realizará sobre esta rama.

   **Si `ACTIVE_PULL_REQUEST=false` (o no está definida):**

   No cambiar de rama. Continuar en la rama actual. Registrar internamente la rama actual como la rama de trabajo para los pasos posteriores.

---

## ━━━ PASO 2 — Implementación ━━━

Ejecutar según la estrategia del plan:

### Estrategia `sequential` (mismo módulo):
Para cada UC en `execution_order`:
1. `/spec-code [uc_id]`
2. `/spec-code-validate [uc_id]`
   - Si hay gaps → corregir y re-validar hasta cero gaps

### Estrategia `parallel` (módulos distintos):
Agrupar UCs por módulo y lanzar subagentes simultáneos.
Cada subagente ejecuta la estrategia `sequential` para su grupo.

Al terminar todos los UCs, mostrar:

| UC-ID | Artefactos creados | Gaps en validación | Estado |
|-------|--------------------|--------------------|--------|
| ...   | N                  | 0                  | ✅     |

Notificar al usuario antes del gate de code review:
```bash
powershell -ExecutionPolicy Bypass -Command "
if (Get-Module -ListAvailable -Name BurntToast) {
  Import-Module BurntToast;
  New-BurntToastNotification -Text 'Claude Code — Code Review requerido', 'Implementación lista. Revisá los archivos y respondé en Claude Code.'
} else { exit 1 }
" 2>/dev/null || powershell -Command "
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
\$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>Claude Code — Code Review requerido</text><text>Implementación lista. Revisá los archivos y respondé en Claude Code.</text></binding></visual></toast>');
\$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml;
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}/WindowsPowerShell/v1.0/powershell.exe').Show(\$toast)
"
```

```
⏸️  GATE — Code Review.
    Revisa los archivos creados antes de ejecutar la fase de calidad.
    Responde "ok" para continuar o indica correcciones.
```

---

## ━━━ PASO 3 — Fase de Calidad ━━━

*(Solo continúa si el ingeniero aprobó el Gate)*

1. `/rules-check` — validar constraints globales del proyecto
   - Si hay violaciones críticas → corregir antes de avanzar
2. Para cada UC implementado → `/test-coverage [uc_id]`
   - Iterar hasta coverage ≥ 85%
3. `/sync-todo` — actualizar `claude_workspace/TODO.md` con los UCs completados

---

## ━━━ PASO 4 — Pull Request ━━━

Construir el PR agrupando todos los UCs del plan:

**Orden obligatorio: primero cerrar el plan, luego commitear todo, luego PR.**

### 4a — Cerrar el plan antes del commit

Antes de hacer `git add`, actualizar el plan JSON con estado final y moverlo a archive:

```bash
# 1. Actualizar el JSON con status=completed, pr_url y completed_at
#    (editar claude_workspace/pending-plans/[plan-file].json con los valores finales)

# 2. Mover a archive
PLAN_FILE=$(cat claude_workspace/pending-plans/latest.txt)
mkdir -p claude_workspace/pending-plans/archive
mv "$PLAN_FILE" claude_workspace/pending-plans/archive/

# 3. Limpiar latest.txt (quedará vacío — está en .gitignore, no se commitea)
> claude_workspace/pending-plans/latest.txt
```

### 4b — Staging: artefactos + archive del plan

```bash
# Artefactos de implementación + specs
git add \
  [artefactos listados en el plan] \
  [spec_path de cada UC] \
  claude_workspace/TODO.md

# Archive del plan (audit trail del pipeline)
git add claude_workspace/pending-plans/archive/

# latest.txt está en .gitignore → no se stagea
```

### 4c — Commit

```bash
git commit -m "feat([módulo]): implement [UC-IDs]

[uc_id]: [uc_name]

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

### 4d — Push y PR

**Si `ACTIVE_PULL_REQUEST=true`:**

```bash
git push "https://[user]:${GITHUB_TOKEN}@github.com/[owner]/[repo].git" [branch]

gh pr create \
  --title "feat: [UC-IDs joined] — [primer uc_name]" \
  --base master \
  --head [branch] \
  --body "$(cat <<'EOF'
## UCs implementados

| UC-ID | Endpoint | Método | Tests |
|-------|----------|--------|-------|
[tabla generada del plan]

## Checklist
- [x] Specs validados por /agent-spec-phase
- [x] Implementación validada por /spec-code-validate
- [x] /rules-check sin violaciones críticas
- [x] Coverage ≥ 85% por UC
- [x] TODO.md actualizado

🤖 Generated with [Claude Code](https://claude.ai/code) via /agent-impl-phase
EOF
)"
```

Guardar la URL del PR en el plan JSON (ya en archive) campo `pr_url`.

**Si `ACTIVE_PULL_REQUEST=false` (o no está definida):**

No hacer push ni crear PR. El commit queda solo en local. Registrar `pr_url: null` en el plan JSON.

---

## ━━━ PASO 5 — Sync Monday (API GraphQL) ━━━

Usa la variable de entorno `$MONDAY_API_KEY` (token personal configurado en Windows).
Endpoint: `https://api.monday.com/v2`

### 5a — Descubrir columnas del board (solo si no se conocen los column IDs)

```bash
curl -sf -X POST https://api.monday.com/v2 \
  -H "Content-Type: application/json" \
  -H "Authorization: $MONDAY_API_KEY" \
  -H "API-Version: 2024-01" \
  -d '{
    "query": "{ boards(ids: [BOARD_ID]) { columns { id title type } } }"
  }' | python3 -c "import sys,json; cols=json.load(sys.stdin)['data']['boards'][0]['columns']; [print(c['id'], c['title'], c['type']) for c in cols]"
```

Registrar el resultado para identificar:
- La columna `status` (tipo `color`) → anotar su `id` (ej: `"status"`)
- La columna para URL del PR (tipo `link` o `text`) → anotar su `id`

### 5b — Descubrir los labels disponibles del status column

Antes de actualizar, verificar qué labels tiene el board (varían por board):

```bash
curl -sf -X POST https://api.monday.com/v2 \
  -H "Content-Type: application/json" \
  -H "Authorization: $MONDAY_API_KEY" \
  -H "API-Version: 2024-01" \
  -d "{\"query\": \"{ boards(ids: [BOARD_ID]) { columns { id title settings_str } } }\"}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for col in data['data']['boards'][0]['columns']:
    if col['id'] == 'status':
        settings = json.loads(col['settings_str'])
        labels = settings.get('labels', {})
        print('Status labels:', labels)
"
```

Usar el label correcto según el resultado (ej: `\"Listo\"`, `\"Done\"`, `\"Completado\"`, etc.)

### 5c — Actualizar cada UC implementado al status "completado"

Siempre usar archivo temporal para evitar problemas de escaping en bash:

```bash
cat > /tmp/monday_update.json <<EOF
{
  "query": "mutation { change_column_value(board_id: BOARD_ID, item_id: MONDAY_ITEM_ID, column_id: \"status\", value: \"{\\\"label\\\":\\\"LABEL_COMPLETADO\\\"}\") { id name } }"
}
EOF

curl -sf -X POST https://api.monday.com/v2 \
  -H "Content-Type: application/json" \
  -H "Authorization: $MONDAY_API_KEY" \
  -H "API-Version: 2024-01" \
  -d @/tmp/monday_update.json
```

Verificar que la respuesta contenga `"data"` y no `"errors"`. Si hay `"errors"` con `missingLabel` → releer los labels disponibles del paso 5b y usar el correcto.

> **Para este board (18398000674):** el label de completado es `"Listo"`.

### 5d — Actualizar ítems con NEEDS_REVIEW (si los hay)

```bash
cat > /tmp/monday_review.json <<EOF
{
  "query": "mutation { change_column_value(board_id: BOARD_ID, item_id: MONDAY_ITEM_ID, column_id: \"status\", value: \"{\\\"label\\\":\\\"Estancado\\\"}\") { id name } }"
}
EOF

curl -sf -X POST https://api.monday.com/v2 \
  -H "Content-Type: application/json" \
  -H "Authorization: $MONDAY_API_KEY" \
  -H "API-Version: 2024-01" \
  -d @/tmp/monday_review.json
```

> **Para este board:** usar `"Estancado"` como equivalente a "Needs Review".

---

## ━━━ PASO 6 — Notificar ━━━

> El cierre del plan (status, archive, latest.txt) ya se hizo en PASO 4a — antes del commit.

Enviar notificación de Windows:
```bash
powershell -ExecutionPolicy Bypass -Command "
if (Get-Module -ListAvailable -Name BurntToast) {
  Import-Module BurntToast;
  New-BurntToastNotification -Text 'Claude Code — Implementación completa', '[N] UCs implementados. PR creado. Monday actualizado.'
} else { exit 1 }
" 2>/dev/null || powershell -Command "
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null;
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType=WindowsRuntime] | Out-Null;
\$xml = New-Object Windows.Data.Xml.Dom.XmlDocument;
\$xml.LoadXml('<toast><visual><binding template=\"ToastGeneric\"><text>Claude Code — Implementación completa</text><text>[N] UCs implementados. PR creado. Monday actualizado.</text></binding></visual></toast>');
\$toast = New-Object Windows.UI.Notifications.ToastNotification \$xml;
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}/WindowsPowerShell/v1.0/powershell.exe').Show(\$toast)
"
```

---

## Reporte Final

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Monday Impl Agent — Completado
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

| UC-ID | Spec | Impl | Tests | TODO | PR | Monday |
|-------|------|------|-------|------|----|--------|
| ...   | ✅   | ✅   | ✅    | ✅   | ✅ | ✅ Done|

> 🏁 Pipeline Monday completo
> PR: [URL]
