# Playwright E2E — Implementar Tests para Casos de Uso

Implementa tests E2E con Playwright para los casos de uso del proyecto, usando
la infraestructura de **Mock Repositories** existente para eliminar dependencias
externas (backend, SSO, APIs) durante las pruebas.

**Argumento (`$ARGUMENTS`):** `{UC-ID}` o lista separada por comas.
Sin argumentos → ejecutar diagnóstico y sugerir UCs sin tests.

```
# Un caso de uso
/apps:playwright-e2e UC-ORG-01

# Varios a la vez
/apps:playwright-e2e "UC-ORG-01, UC-RBAC-02, UC-PROD-01"

# Sin argumentos: diagnóstico
/apps:playwright-e2e
```

> **Prerequisito:** El proyecto debe tener `@playwright/test` instalado y browsers configurados.
> Si no existe la carpeta `tests/e2e/`, el comando la crea con la estructura base.

---

## Paso 0 — Diagnóstico y descubrimiento de UCs

### 0a. Sin argumentos: escanear el proyecto

1. Leer `claude_workspace/architecture/feature_spec.md` — contiene el índice de todos los
   casos de uso con sus códigos (`UC-ORG-01`, `UC-RBAC-02`, etc.) y las pantallas asociadas.

2. Verificar qué UCs ya tienen tests E2E:
   ```bash
   find tests/e2e -name "*.spec.ts" 2>/dev/null
   ```

3. Mostrar tabla de cobertura:

   | UC | Pantalla | Tiene test E2E |
   |----|----------|---------------|
   | UC-ORG-01 | OrganizationsListPage | ❌ |
   | UC-RBAC-02 | RolesListPage | ❌ |
   | ... | ... | ... |

4. Sugerir UCs prioritarias (las que tienen pantalla implementada y no tienen test).

### 0b. Con argumentos: leer specs de los UCs

Para cada UC-ID solicitado:

1. Ubicar el archivo de spec: buscar en `claude_workspace/architecture/feature_spec/**/*.md`
   el UC-ID. Si no se encuentra, preguntar al usuario.

2. Leer la spec para extraer:
   - **Pantalla:** componente React y ruta (ej: `OrganizationsListPage.tsx — /console/organizations`)
   - **Actor:** quién ejecuta el UC
   - **Endpoint:** `GET/POST/PUT/DELETE /api/...`
   - **Precondiciones:** qué necesita estar presente
   - **Flujo principal:** pasos del happy path
   - **Flujos alternativos:** errores, validaciones, edge cases

3. Si la pantalla no está implementada (spec en estado `🔲 Pendiente`), advertir y preguntar
   si continuar de todos modos.

### 0c. Verificar infraestructura de mocks

Antes de escribir tests, confirmar que la app puede correr sin backend:

1. Revisar `.env` o `src/config/env.ts` — buscar `VITE_ENABLE_MOCKS` o equivalente.
2. Verificar existencia de `Mock*Repository` en `src/infrastructure/repositories/`.
3. Si no hay mocks, evaluar alternativas:
   - Usar `page.route()` de Playwright para interceptar llamadas HTTP.
   - Usar MSW (`msw`) si está disponible en el proyecto.
   - Documentar dependencia de backend real.

---

## Paso 1 — Configurar Playwright (si no existe)

### 1a. Estructura de archivos esperada

```
[raíz del proyecto]/
├── playwright.config.ts          ← config de Playwright (nivel raíz)
├── tests/                        ← carpeta de tests (nivel raíz, junto a src/)
│   └── e2e/
│       └── use-cases/
│           ├── organizations/    ← un subdirectorio por módulo/dominio
│           │   ├── list-orgs.spec.ts
│           │   └── create-org.spec.ts
│           ├── roles/
│           │   └── list-roles.spec.ts
│           └── ...
├── src/                          ← código fuente de la app
└── claude_workspace/
    └── architecture/
        └── feature_spec/         ← specs de casos de uso (UC-ORG-01, etc.)
```

> **Regla:** `tests/e2e/` se crea al mismo nivel que `src/`. Si el proyecto tiene
> `src/` en la raíz, `tests/e2e/` también va en la raíz. No se crea dentro de `src/`
> ni dentro de `pocs/`.

Si la carpeta `tests/e2e/` no existe, el comando la crea junto con `use-cases/`.

### 1b. playwright.config.ts

Crear en la raíz del proyecto:

> **Convención de outputs:** Los artefactos de Playwright (screenshots, videos, reportes, traces)
> se generan localmente en el proyecto. Luego de cada ejecución, el comando copia una selección
> de artefactos relevantes (fallos, reporte HTML) a `commands/test/playwright/` del repositorio
> de knowledge para referencia futura y debugging.

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './tests/e2e',
  outputDir: './test-results',
  fullyParallel: true,
  retries: process.env.CI ? 2 : 1,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],
  use: {
    baseURL: process.env.CI
      ? process.env.PLAYWRIGHT_BASE_URL ?? 'http://localhost:5100'
      : 'http://localhost:5100',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
  webServer: process.env.CI ? undefined : {
    command: 'npx vite',
    url: 'http://localhost:5100',
    reuseExistingServer: true,
  },
});
```

### 1c. Scripts en package.json

```json
{
  "test:e2e": "playwright test",
  "test:e2e:headed": "playwright test --headed",
  "test:e2e:ui": "playwright test --ui",
  "test:e2e:report": "playwright show-report"
}
```

---

## Paso 2 — Estrategia de autenticación

Determinar cómo la app maneja autenticación y elegir la estrategia adecuada:

| Escenario | Estrategia recomendada |
|-----------|----------------------|
| App con `VITE_ENABLE_MOCKS=true` y Mock Repositories | Activar mocks + mockear stores de auth vía aliases de Vite |
| App con SSO (Google, Azure AD) sin mocks | **storageState** — loguearse una vez manual y guardar sesión |
| App con backend real disponible | **storageState** o token inyectado vía `localStorage.setItem()` |
| App con Module Federation + mfe-auth | Mockear los stores remotos vía `resolve.alias` en vite.config.ts |

### 2a. Estrategia A — Mocks internos + alias (recomendado cuando existen Mock Repos)

1. Activar `VITE_ENABLE_MOCKS=true` en `.env`.
2. Crear mocks para los stores de autenticación que la app necesite
   (manifest-store, session-store, o equivalentes de Zustand/Redux/Context).
3. Apuntar los aliases de Vite a los mocks en `vite.config.ts` o crear un
   `vite.config.e2e.ts` dedicado.
4. Crear un entry point alternativo que renderice la app sin el wrapper de
   autenticación (AuthGuard, ProtectedRoute, etc.).

### 2b. Estrategia B — storageState (cuando hay backend real)

```bash
# Guardar sesión autenticada
npx playwright open --save-storage=auth.json http://localhost:5100
```

```typescript
// playwright.config.ts
use: {
  storageState: 'auth.json',
}
```

### 2c. Estrategia C — Token inyectado (API tokens)

```typescript
test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await page.evaluate((token) => {
    localStorage.setItem('access_token', token);
  }, process.env.TEST_TOKEN);
});
```

---

## Paso 3 — Estructura de tests

Organizar los tests reflejando la estructura de specs del proyecto:

```
tests/e2e/
└── use-cases/
    ├── organizations/
    │   ├── list-orgs.spec.ts          # UC-ORG-01
    │   ├── create-org.spec.ts         # UC-ORG-02
    │   └── org-detail.spec.ts         # UC-ORG-03, UC-ORG-04, UC-ORG-05
    ├── roles/
    │   ├── list-roles.spec.ts         # UC-RBAC-02
    │   ├── create-role.spec.ts        # UC-RBAC-01
    │   └── edit-permissions.spec.ts   # UC-RBAC-03
    ├── memberships/
    │   ├── list-users.spec.ts         # UC-RBAC-09
    │   └── invite-user.spec.ts        # UC-RBAC-08
    ├── products/
    │   └── list-products.spec.ts      # UC-PROD-01
    └── ...
```

**Reglas:**
- Un archivo por UC o grupo de UCs relacionadas.
- Nombre del test: `UC-XX-YY: Descripción del caso de uso`.
- Cada test debe poder ejecutarse de forma independiente.

---

## Paso 4 — Escribir tests por UC

Para cada caso de uso, implementar los siguientes escenarios como mínimo:

### 4a. Happy Path

Flujo completo de éxito. Carga la pantalla, interactúa con los componentes,
verifica el resultado esperado.

```typescript
test('UC-ORG-01: Listar organizaciones', async ({ page }) => {
  await page.goto('/console/organizations');

  // Esperar que los datos mock carguen (puede haber delay simulado)
  await expect(page.getByRole('table')).toBeVisible({ timeout: 8000 });

  // Verificar datos esperados del Mock Repository
  await expect(page.getByText('Inca Kola Corp')).toBeVisible();
});
```

### 4b. Validaciones y errores

Campos requeridos, formatos inválidos, errores de API (si se usa `page.route()`).

```typescript
test('UC-ORG-02: Validación — campos requeridos', async ({ page }) => {
  await page.goto('/console/organizations');
  await page.getByRole('button', { name: /crear/i }).click();
  await page.getByRole('button', { name: /guardar/i }).click();

  // Verificar mensajes de error
  await expect(page.getByText(/obligatorio/i)).toBeVisible();
});
```

### 4c. Edge Cases

- Valores límite (strings vacíos, números máximos).
- Estados de carga (loading skeleton, empty state, error state).
- Comportamiento con datos vacíos.

### 4d. Responsive (opcional)

Si la pantalla es crítica, probar en 3 viewports:

```typescript
const viewports = [
  { name: 'mobile', width: 375, height: 667 },
  { name: 'tablet', width: 768, height: 1024 },
  { name: 'desktop', width: 1280, height: 720 },
];

for (const vp of viewports) {
  test(`viewport ${vp.name}`, async ({ page }) => {
    await page.setViewportSize({ width: vp.width, height: vp.height });
    // ...
  });
}
```

---

## Paso 5 — Reglas de selectores

### 5a. Preferir `getByRole` sobre selectores CSS

```typescript
// ✅ Bien
await page.getByRole('button', { name: 'Crear' }).click();
await page.getByRole('textbox', { name: 'Nombre' }).fill('Texto');
await page.getByRole('combobox').selectOption('1');

// ❌ Mal
await page.locator('button').first().click();
await page.locator('input').first().fill('Texto');
```

### 5b. `{ exact: true }` cuando hay nombres similares

Cuando un texto es substring de otro (ej: "Satisfecho" dentro de "Muy satisfecho"),
Playwright matchea ambos. Usar `exact: true`:

```typescript
await page.getByRole('radio', { name: 'Satisfecho', exact: true }).click();
```

### 5c. Leer el source code antes de escribir selectores

No asumir la estructura del DOM. Leer el componente para verificar:
- Si usa `<table>`, lista de `<div>`, o cards.
- El texto exacto de botones y labels (ej: "Crear rol" vs "Nuevo rol").
- Clases CSS usadas para estados (`.is-selected`, `.is-on`).

### 5d. Inputs de búsqueda con onSubmit

Si el componente de búsqueda usa un callback `onSubmit`, escribir el texto no basta.
Presionar Enter para disparar el filtro:

```typescript
await searchInput.fill('Kola');
await searchInput.press('Enter');
```

### 5e. Dependencias entre componentes

Si una página requiere seleccionar una organización antes de mostrar datos
(ej: Marcas), seleccionarla explícitamente:

```typescript
await page.getByRole('combobox').selectOption('1');
await expect(page.locator('.brand-grid')).toBeVisible();
```

### 5f. Componentes custom con radios/checkboxes ocultos

Si un componente usa `<input type="radio" hidden>` con un `<label>` o `<span>` visible,
clickear el elemento visible, no el input oculto:

```typescript
// ❌ Click en input oculto
await page.getByRole('radio').click();

// ✅ Click en el label visible
await page.locator('label').filter({ hasText: 'Opción' }).click();
```

---

## Paso 6 — Verificación y resultados

### 6a. Ejecutar en chromium primero

```bash
npx playwright test --project=chromium
```

### 6b. Si hay fallos

1. Ejecutar con `--headed` para ver la UI en vivo.
2. Usar `--ui` para modo interactivo con time-travel y picker de locators.
3. Revisar screenshots y videos en `test-results/`.
4. Abrir traces con `npx playwright show-trace test-results/<trace>.zip`.

### 6c. Antes de commit

```bash
npx playwright test                    # Los 3 navegadores
npx playwright show-report             # Revisar reporte HTML
```

### 6d. Copiar resultados al repositorio de knowledge

Después de una ejecución completa (especialmente si hay fallos), copiar artefactos
relevantes a `commands/test/playwright/` del knowledge repo:

```bash
# Copiar reporte HTML
cp -r playwright-report/* $KNOWLEDGE_REPO/commands/test/playwright/report/

# Copiar screenshots/videos de fallos
cp -r test-results/* $KNOWLEDGE_REPO/commands/test/playwright/artifacts/
```

### 6e. CI/CD

```yaml
# Ejemplo GitHub Actions
- name: Playwright E2E
  run: npx playwright test --project=chromium
  env:
    CI: true
    PLAYWRIGHT_BASE_URL: ${{ vars.STAGING_URL }}
```

### 6f. Resultados persistentes

Los artefactos de cada ejecución quedan en `commands/test/playwright/`:

```
commands/test/playwright/
├── artifacts/          ← screenshots (*.png), videos (*.webm), traces (*.zip)
├── report/             ← reporte HTML (playwright-report)
└── last-run.json       ← resultado de la última ejecución
```

> Esta carpeta vive en el repositorio de knowledge. Los artefactos de tests fallidos
> sirven como evidencia para debugging y auditoría. No se commitean archivos binarios
> grandes — solo se conserva la última ejecución local.

---

## Checklist pre-commit

- [ ] Tests pasan en chromium (modo headless).
- [ ] Cada UC-ID del spec está mapeado a un archivo de test o documentado como pendiente.
- [ ] Selectores usan `getByRole` cuando es posible (no CSS genéricos).
- [ ] Nombres de variables/funciones en inglés, datos de prueba en español (consistente con la UI).
- [ ] Sin `test.only` ni `test.skip` sin comentario.
- [ ] Sin secretos ni tokens reales en el código.
- [ ] `playwright.config.ts` configurado con `webServer` para CI/CD.
- [ ] Scripts `test:e2e*` agregados a `package.json`.
- [ ] Outputs (`outputDir`, `report`) configurados con paths locales (`test-results/`, `playwright-report/`).
- [ ] `.gitignore` del proyecto incluye `test-results/` y `playwright-report/` para no commitear binarios.
