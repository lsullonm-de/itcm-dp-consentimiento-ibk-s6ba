# Inicializar Proyecto — Scaffolding Estructural

Crea el esqueleto completo del proyecto frontend: archivos de proyecto base (package.json, vite.config.ts,
tsconfig.json, index.html) + estructura `src/` con infraestructura HTTP y configuración.
**No crea artefactos de negocio** (entidades, DTOs, mappers, use cases, repositorios de dominio, páginas).
Eso es responsabilidad de `/spec-code`.

> **Cuándo usar:** una sola vez, al iniciar un proyecto nuevo, después de ejecutar `/init-docs-frontend`.
> El resultado es un proyecto que compila y arranca con una página de bienvenida, listo para `/spec-code`.

**Argumento (`$ARGUMENTS`):**
- Sin argumento → scaffold completo
- `--check` → solo reporta qué archivos faltan, sin crear nada

---

## Paso 0 — Leer configuración del proyecto

Leer en paralelo (ignorar errores si no existen aún):

```
1. claude_workspace/CLAUDE.md                  → stack, framework, auth_strategy, dev_port
2. claude_workspace/project.manifest.yaml      → fuente de verdad completa
3. package.json                        → dependencias ya instaladas (puede no existir)
4. vite.config.ts                      → aliases y puerto (puede no existir)
5. tsconfig.json                       → path aliases (puede no existir)
6. .env.example                        → variables de entorno (puede no existir)
```

Extraer del manifest:

| Dato | Clave manifest | Uso |
|------|---------------|-----|
| Stack con versiones | `stack[]` | `package.json` dependencies |
| Puerto dev | `project.dev_port` | `vite.config.ts` + reporte |
| URL API | `project.api_base_url` | `.env.example` + `api-client.ts` |
| Auth strategy | `architecture.features.auth_strategy` | interceptors + hooks |
| Framework | `architecture.framework` | adaptar imports |
| State management | `architecture.features.state_management` | stores |
| External systems | `external_systems[]` | `.env.example` (Firebase, etc.) |

---

## Paso 1 — Detectar estado del proyecto

Verificar existencia de archivos clave:

```
package.json          → ¿proyecto base inicializado?
src/main.tsx          → ¿src/ ya scaffoldeada?
```

| Estado | Criterio | Acción |
|--------|---------|--------|
| **Proyecto vacío** | `package.json` no existe | Paso 1.5 (bootstrapping) + Pasos 2–10 |
| **Base sin src/** | `package.json` existe, `src/main.tsx` no existe | Solo Pasos 2–10 |
| **Proyecto completo** | `src/main.tsx` existe | Reportar estado y salir sin modificar |

Si `--check`: mostrar tabla de estado de cada archivo clave y salir sin crear nada.

---

## Paso 1.5 — Bootstrapping del proyecto base (solo si Proyecto vacío)

> Código canónico en `guides/scaffold.md` → sección **Proyecto Base**.

### 1.5a — Leer design system (si existe)

Antes de crear `tailwind.config.js`, verificar si existe `rules/design.md`:

- **Existe** → leerlo completo. Extraer: paleta de colores (§ 2), escala tipográfica (§ 3),
  border-radius (§ 5), spacing (§ 5) y shadow system (§ 6).
  Usar la versión con tokens de `guides/scaffold.md` (sección `tailwind.config.js`).
- **No existe** → usar `theme: { extend: {} }` vacío.

> Esto garantiza que todos los componentes implementados por `/spec-code` usen clases semánticas
> (`bg-parchment`, `text-olive-gray`, `shadow-ring`) en lugar de los valores genéricos de Tailwind.

### 1.5b — Crear archivos de proyecto base

| Archivo | Contenido |
|---------|-----------|
| `package.json` | Dependencias del manifest (React, Vite, Inversify, TanStack Query, Firebase, Zod, Tailwind, Vitest, Playwright…) |
| `vite.config.ts` | Plugin React, path aliases (`@core`, `@infrastructure`, `@presentation`, `@shared`, `@config`, `@mfe`), puerto del manifest, proxy `/api → api_base_url` |
| `tsconfig.json` | Referencia a `tsconfig.app.json` y `tsconfig.node.json` |
| `tsconfig.app.json` | `strict: true`, `experimentalDecorators`, `emitDecoratorMetadata`, paths alineados con vite |
| `tsconfig.node.json` | Para Vite config (bundler, node env) |
| `index.html` | Punto de entrada Vite estándar con `<div id="root">` |
| `.env.example` | Variables `VITE_*` derivadas del manifest (API URL, Firebase keys) |
| `.env` | Copia de `.env.example` con valores de desarrollo del manifest |
| `.gitignore` | `node_modules`, `dist`, `.env`, `.env.local`, coverage |
| `tailwind.config.js` | Tokens del design system si existe `rules/design.md` — ver Paso 1.5a |
| `postcss.config.js` | `tailwindcss` + `autoprefixer` |

---

## Paso 2 — Plan y confirmación

Mostrar al usuario el plan completo (adaptando secciones según el estado detectado en Paso 1):

```
## Plan de Scaffold — init-project-frontend

### [Solo si Proyecto vacío] Archivos de proyecto base
  → package.json                (dependencias del manifest)
  → vite.config.ts              (aliases, puerto {dev_port}, proxy)
  → tsconfig.json + tsconfig.app.json + tsconfig.node.json
  → index.html
  → .env.example + .env
  → .gitignore
  → tailwind.config.js + postcss.config.js

### Archivos de arranque
  → src/main.tsx                (React + QueryClient + interceptors)
  → src/App.tsx                 (BrowserRouter + AppRoutes)

### Configuración de la app
  → src/config/env.ts           (variables VITE_* validadas con Zod)
  → src/config/routes.tsx       (placeholder ruta /)
  → src/config/di-container.ts  (contenedor Inversify vacío)

### Infraestructura HTTP
  → src/infrastructure/http/api-client.ts
  → src/infrastructure/http/interceptors/auth.interceptor.ts
  → src/infrastructure/http/interceptors/error.interceptor.ts

### Errores base de dominio
  → src/core/domain/errors/domain.error.ts

### Utilidades compartidas
  → src/shared/utils/logger.ts
  → src/shared/utils/api-error.utils.ts

### Hooks de presentación
  → src/presentation/hooks/useDI.ts
  → src/presentation/hooks/use{Auth}.ts    (según auth_strategy del manifest)

### Carpetas vacías (con .gitkeep)
  → src/core/domain/entities/
  → src/core/domain/repositories/
  → src/core/application/use-cases/
  → src/core/application/dtos/
  → src/core/application/mappers/
  → src/infrastructure/repositories/
  → src/presentation/pages/
  → src/presentation/components/shared/
  → src/presentation/components/features/

Total: {N} archivos de proyecto base + 12 archivos src/ + 9 carpetas vacías

¿Procedo con la creación? (s/n)
```

Solo proceder si el usuario confirma.

---

## Paso 3 — Crear archivos de proyecto base (solo si Paso 1.5 aplica)

> Código canónico en `guides/scaffold.md` → sección **Proyecto Base**.

### `package.json`
Construir a partir de `stack[]` del manifest con estas reglas:

- `dependencies`: React, ReactDOM, react-router-dom, axios, zustand, zod, inversify, reflect-metadata, @tanstack/react-query, firebase (si auth_strategy incluye firebase)
- `devDependencies`: TypeScript, Vite, @vitejs/plugin-react, tailwindcss, autoprefixer, postcss, vitest, @vitest/coverage-v8, @testing-library/react, @testing-library/jest-dom, jsdom, @playwright/test, eslint, prettier, @typescript-eslint/\*
- `scripts` estándar: `dev`, `build`, `preview`, `type-check`, `lint`, `lint:fix`, `format`, `test`, `test:coverage`, `test:e2e`

### `vite.config.ts`
```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  server: {
    port: {dev_port},
    proxy: {
      '/api': {
        target: '{api_base_url_sin_path}',
        changeOrigin: true,
      },
    },
  },
  resolve: {
    alias: {
      '@core':           path.resolve(__dirname, 'src/core'),
      '@infrastructure': path.resolve(__dirname, 'src/infrastructure'),
      '@presentation':   path.resolve(__dirname, 'src/presentation'),
      '@shared':         path.resolve(__dirname, 'src/shared'),
      '@config':         path.resolve(__dirname, 'src/config'),
      '@mfe':            path.resolve(__dirname, 'src/mfe'),
    },
  },
});
```

### `tsconfig.app.json`
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": true,
    "skipLibCheck": true,
    "paths": {
      "@core/*":           ["./src/core/*"],
      "@infrastructure/*": ["./src/infrastructure/*"],
      "@presentation/*":   ["./src/presentation/*"],
      "@shared/*":         ["./src/shared/*"],
      "@config/*":         ["./src/config/*"],
      "@mfe/*":            ["./src/mfe/*"]
    }
  },
  "include": ["src"]
}
```

### `.env.example`
Derivar del manifest: una variable por cada `external_system` + `project.api_base_url`:

```bash
# Backend API
VITE_API_BASE_URL=http://localhost:3000/api

# Firebase Auth (si external_system firebase_auth existe)
VITE_FIREBASE_API_KEY=your-firebase-api-key
VITE_FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
VITE_FIREBASE_PROJECT_ID=your-project-id
VITE_FIREBASE_APP_ID=your-app-id
```

---

## Paso 4 — Archivos de arranque

> Código canónico en `guides/scaffold.md` → sección **Arranque**.

- `src/main.tsx` — bootstrap: `reflect-metadata`, `QueryClientProvider`, `React.StrictMode`, imports de interceptors
- `src/App.tsx` — `BrowserRouter` + `AppRoutes`

---

## Paso 5 — Configuración de la app

> Código canónico en `guides/scaffold.md` → sección **Configuración**.

- `src/config/env.ts` — schema Zod validando las variables de `.env.example`; exporta `env` tipado
- `src/config/routes.tsx` — placeholder con ruta `/`; sin rutas de dominio
- `src/config/di-container.ts` — contenedor Inversify vacío con `TOKENS = {}` comentado

---

## Paso 6 — Infraestructura HTTP

> Código canónico en `guides/scaffold.md` → sección **Infraestructura HTTP**.

Adaptar según `auth_strategy` del manifest:

| auth_strategy | auth.interceptor.ts | error.interceptor.ts |
|---------------|--------------------|--------------------|
| `jwt-cookie` + Firebase | Firebase `getIdToken()` como Bearer | `getIdToken(true)` para refresh |
| `jwt-localStorage` | Lee token de store Zustand | Refresh vía endpoint `/auth/refresh` |
| `session` | Sin Bearer header | 401 → redirect `/login` |
| `mfe-auth` | Lee `mfe-auth/session-store` | Refresh vía `useSessionStore.refresh()` + cola |

---

## Paso 7 — Errores base de dominio

> Código canónico en `rules/error-handling.md` → sección **Jerarquía de Errores de Dominio**.

Crear `src/core/domain/errors/domain.error.ts` con:
- `DomainError` (abstract base)
- `NotFoundError`, `DuplicateError`, `ValidationError`, `UnauthorizedError`, `ExternalServiceError`

---

## Paso 8 — Utilidades y hooks compartidos

> Logger → `rules/logging.md` · Utils de error → `rules/error-handling.md` · Hooks → `guides/scaffold.md`.

- `src/shared/utils/logger.ts` — código canónico de `rules/logging.md`
- `src/shared/utils/api-error.utils.ts` — `getApiErrorMessage()` + `getApiFieldErrors()`
- `src/presentation/hooks/useDI.ts` — wrapper `container.get<T>(token)`
- Hook de auth según `auth_strategy`:
  - Firebase → `src/presentation/hooks/useAuth.ts` con `onAuthStateChanged`
  - mfe-auth → `src/presentation/hooks/useManifest.ts` con selector Zustand
  - jwt-localStorage → `src/presentation/hooks/useSession.ts` con store

---

## Paso 9 — Carpetas vacías

> Lista canónica en `rules/architecture.md` → **Estructura de Proyecto**.

```
src/core/domain/entities/.gitkeep
src/core/domain/repositories/.gitkeep
src/core/application/use-cases/.gitkeep
src/core/application/dtos/.gitkeep
src/core/application/mappers/.gitkeep
src/infrastructure/repositories/.gitkeep
src/presentation/pages/.gitkeep
src/presentation/components/shared/.gitkeep
src/presentation/components/features/.gitkeep
```

---

## Paso 10 — Verificar compilación

Solo si `package.json` y `node_modules` existen:

```bash
npx tsc --noEmit 2>&1 | head -30
```

Si `node_modules` no existe → indicar al usuario que ejecute `npm install` primero.

Errores comunes:

| Error | Causa | Fix |
|-------|-------|-----|
| `Cannot find module '@core/...'` | Path alias no alineado | Verificar `paths` en `tsconfig.app.json` vs `alias` en `vite.config.ts` |
| `reflect-metadata not found` | No instalado | `npm install reflect-metadata` |
| `experimentalDecorators` error | Flag faltante | Habilitar en `tsconfig.app.json` |
| `Cannot find module 'firebase/auth'` | Firebase no instalado | `npm install firebase` |

---

## Paso 11 — Reporte final

```
## Scaffold completado — {project.name}

### [Si bootstrapping] Proyecto base: {N} archivos creados
  package.json · vite.config.ts · tsconfig*.json · index.html
  .env.example · .env · .gitignore · tailwind.config.js · postcss.config.js

### Estructura src/: 12 archivos + 9 carpetas vacías

| Categoría | Archivos |
|-----------|---------|
| Arranque | src/main.tsx, src/App.tsx |
| Config | config/env.ts, config/routes.tsx, config/di-container.ts |
| HTTP | infrastructure/http/api-client.ts, auth.interceptor.ts, error.interceptor.ts |
| Errores base | core/domain/errors/domain.error.ts |
| Utils | shared/utils/logger.ts, api-error.utils.ts |
| Hooks | presentation/hooks/useDI.ts, use{Auth}.ts |

### Compilación: ✅ sin errores  /  ❌ N errores  /  ⏳ pendiente npm install

### Próximos pasos
{Si bootstrapping:}
1. npm install           → instalar dependencias
2. cp .env.example .env  → ya creado, revisar valores
{Siempre:}
3. npm run dev           → verificar arranque en http://localhost:{dev_port}
4. /spec-create UC-{PREFIJO}-01  → especificar primera pantalla
5. /spec-code UC-{PREFIJO}-01    → implementar primera pantalla
```

---

## Qué NO hace este skill

| Responsabilidad | Skill correcta |
|----------------|---------------|
| Especificar un Use Case | `/spec-create` |
| Implementar entidades, DTOs, use cases, repositorios, páginas | `/spec-code` |
| Bindings en di-container | `/spec-code` |
| Rutas de dominio en routes.tsx | `/spec-code` |
| Tests unitarios o E2E | `/spec-code` o `/test-coverage` |
| Actualizar diagramas C4 | `/c4-update-diagrams` |
