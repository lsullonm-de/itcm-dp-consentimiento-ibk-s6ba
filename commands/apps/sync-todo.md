# Sync TODO — Sincronizar Estado de Implementación

Lee el estado real de implementación (archivos existentes + resultado de tests) y actualiza `claude_workspace/TODO.md` reflejando el progreso actual. No asume nada: verifica cada ítem en el filesystem.

---

## Paso 1 — Obtener métricas del proyecto

Ejecuta los siguientes comandos y registra los resultados:

```bash
# 1a. Resultado de tests (unit + e2e)
npm test -- --silent 2>&1 | tail -8

# 1b. Errores TypeScript
npx tsc --noEmit 2>&1 | grep -c "error TS" || echo "0"

# 1c. Número de archivos .spec.ts existentes
find src test -name "*.spec.ts" 2>/dev/null | wc -l
```

Registra:
- `TEST_PASSED`: número de tests pasados
- `TEST_FAILED`: número de tests fallados
- `TEST_SUITES`: número de suites
- `TS_ERRORS`: número de errores TypeScript
- `FECHA_HOY`: fecha actual en formato YYYY-MM-DD

---

## Paso 2 — Escanear implementación por sección

> Los paths base están en la tabla `## 🗂️ Path Registry` de `rules/architecture.md` (ya en contexto).
> Las tablas siguientes usan las claves del registry como prefijo (`{services}`, `{typeorm_entities}`, etc.).
> Si la arquitectura cambia, actualizar el Path Registry es suficiente.
> Los patrones de nombre (`*list*`, `*create*`, etc.) son conocimiento de negocio y permanecen estables.

Para cada sección del TODO.md, usa Glob/Grep para verificar si los artefactos existen. Mapeo oficial:

---

### SECCIÓN: Infraestructura Base

| Ítem TODO | Verificación |
|-----------|-------------|
| Arquitectura hexagonal | `src/core/` y `src/infrastructure/` existen |
| Migración 001 — Schema inicial | `src/infrastructure/**/migrations/*InitialSchema*` |
| Migración 002 — RefactorSchemaV2 | `src/infrastructure/**/migrations/*RefactorSchemaV2*` |
| Migración 003 — MenuItemCode | `src/infrastructure/**/migrations/*MenuItemCode*` |
| Entidades de dominio | `src/core/domain/entities/*.entity.ts` (≥5 archivos) |
| Entidades TypeORM | `src/infrastructure/**/entities/*.typeorm-entity.ts` (≥5) |
| JWT payload actualizado | `src/infrastructure/**/interfaces/jwt-payload.interface.ts` contiene `permissions` |
| Output Ports | `src/core/application/ports/output/**/*.port.ts` (≥5) |
| JwtAuthGuard | `src/infrastructure/**/guards/jwt-auth.guard.ts` |
| `@CurrentUser()` decorator | `src/infrastructure/**/decorators/current-user.decorator.ts` |
| `@RequirePermissions()` decorator | `src/infrastructure/**/decorators/require-permissions.decorator.ts` |
| `@SuperAdminOnly()` decorator | `src/infrastructure/**/decorators/super-admin-only.decorator.ts` |
| Swagger configurado | `src/main.ts` contiene `SwaggerModule` |
| Docker — PostgreSQL | `docker-compose.yml` o `docker-compose.yaml` existe |
| PaginationQueryDto + PaginatedResponseDto | `src/core/application/dtos/shared/pagination*.dto.ts` |
| TenantGuard | `src/infrastructure/**/guards/tenant.guard.ts` |
| Redis Cache | `src/infrastructure/**/*redis*` o `*cache*` |
| CI/CD GitHub Actions | `.github/workflows/*.yml` |

---

### SECCIÓN: Módulo 0 — Products & Modules

| Ítem TODO | Verificación |
|-----------|-------------|
| Listar productos | `src/core/application/services/product/*list*.service.ts` |
| Crear producto | `src/core/application/services/product/*create*.service.ts` |
| Obtener producto por ID | `src/core/application/services/product/*get*.service.ts` |
| Actualizar producto | `src/core/application/services/product/*update*.service.ts` |
| Soft delete producto | `src/core/application/services/product/*delete*.service.ts` |
| Listar módulos de producto | `src/core/application/services/module/*list*.service.ts` |
| Crear módulo | `src/core/application/services/module/*create*.service.ts` |
| Actualizar módulo | `src/core/application/services/module/*update*.service.ts` |
| Productos contratados por org | `src/core/application/services/organization-product/*list*.service.ts` o similar |
| Contratar producto | `src/core/application/services/organization-product/*create*.service.ts` o similar |
| Dar de baja producto | `src/core/application/services/organization-product/*delete*.service.ts` o similar |
| Módulos activados | `src/core/application/services/organization-product/*module*.service.ts` o similar |
| Activar/desactivar módulos | (mismo que anterior, puede ser mismo archivo) |
| Migración seed 002 | `src/infrastructure/**/migrations/*SeedProduct*` o `*Seed*002*` |
| Migración seed 003 | `src/infrastructure/**/migrations/*SeedPermission*` o `*Seed*003*` |

---

### SECCIÓN: Módulo 1 — Auth & Identity

| Ítem TODO | Verificación |
|-----------|-------------|
| FirebaseAuthAdapter | `src/infrastructure/**/firebase/firebase-auth.adapter.ts` |
| Token Exchange (login) | `src/core/application/services/auth/token-exchange.service.ts` |
| Auto-asignación por dominio | Grep `organization_domains` en `token-exchange.service.ts` |
| Renovar sesión (refresh) | `src/core/application/services/auth/*refresh*.service.ts` |
| Cerrar sesión (logout) | `src/core/application/services/auth/*logout*.service.ts` |
| Sincronizar perfil | `src/core/application/services/auth/*sync*.service.ts` o `*profile*` |
| JWKS | `src/core/application/services/auth/*jwks*.service.ts` o `*well-known*` |
| Obtener perfil (me) | `src/core/application/services/auth/*me*.service.ts` o `*profile*` |
| Switch de contexto | `src/core/application/services/auth/*switch*.service.ts` |

---

### SECCIÓN: Módulo 2 — Organizations & Brands

| Ítem TODO | Verificación |
|-----------|-------------|
| Crear organización | `src/core/application/services/organization/*create*.service.ts` |
| Listar organizaciones | `src/core/application/services/organization/*list*.service.ts` |
| Árbol corporativo | `src/core/application/services/organization/*tree*.service.ts` |
| Obtener org por ID | `src/core/application/services/organization/*get*.service.ts` |
| Actualizar org | `src/core/application/services/organization/*update*.service.ts` |
| Soft delete org | `src/core/application/services/organization/*delete*.service.ts` |
| Config de tenant | `src/core/application/services/organization/*config*.service.ts` |
| Listar dominios | `src/core/application/services/organization/*domain*.service.ts` |
| Agregar dominio | (mismo archivo que listar, o `*add-domain*`) |
| Desactivar dominio | (mismo archivo que listar) |
| Crear marca | `src/core/application/services/brand/*create*.service.ts` |
| Listar marcas | `src/core/application/services/brand/*list*.service.ts` |
| Obtener marca | `src/core/application/services/brand/*get*.service.ts` |
| Actualizar marca | `src/core/application/services/brand/*update*.service.ts` |
| Soft delete marca | `src/core/application/services/brand/*delete*.service.ts` |

---

### SECCIÓN: Módulo 3 — RBAC

| Ítem TODO | Verificación |
|-----------|-------------|
| Asignar usuario a org | `src/core/application/services/membership/*create*.service.ts` |
| Listar membresías | `src/core/application/services/membership/*list*.service.ts` |
| Agregar rol a membresía | `src/core/application/services/membership/*role*.service.ts` o `*add-role*` |
| Eliminar membresía | `src/core/application/services/membership/*delete*.service.ts` |
| Remover rol de membresía | (mismo que agregar, o `*remove-role*`) |
| Crear rol personalizado | `src/core/application/services/role/*create*.service.ts` |
| Listar roles | `src/core/application/services/role/*list*.service.ts` |
| Actualizar rol | `src/core/application/services/role/*update*.service.ts` |
| Soft delete rol | `src/core/application/services/role/*delete*.service.ts` |
| Clonar rol | `src/core/application/services/role/*clone*.service.ts` |
| Catálogo permisos | `src/core/application/services/permission/*list*.service.ts` |
| Auditar permiso | `src/core/application/services/permission/*audit*.service.ts` |

---

### SECCIÓN: Módulo 4 — Menu

| Ítem TODO | Verificación |
|-----------|-------------|
| Configurar ítem de menú | `src/core/application/services/menu/*create*.service.ts` |
| Actualizar ítem de menú | `src/core/application/services/menu/*update*.service.ts` |
| Desactivar ítem de menú | `src/core/application/services/menu/*delete*.service.ts` |
| Menú dinámico | `src/core/application/services/menu/*get*.service.ts` o `*user-menu*` |
| Favoritos — obtener | `src/core/application/services/menu/*favorite*.service.ts` |
| Favoritos — guardar | (mismo archivo que obtener) |
| Listar ítems por producto | `src/core/application/services/menu/*product*.service.ts` o similar |
| Upsert masivo | (mismo archivo que listar por producto, o `*upsert*`) |

---

## Paso 3 — Lógica de decisión de estado

Para cada ítem del TODO.md aplica esta lógica:

```
archivo_existe = resultado del Glob del Paso 2

if archivo_existe AND estado_actual == "⬜":
    → cambiar a "✅"   (implementado, no estaba marcado)

if NOT archivo_existe AND estado_actual == "✅":
    → cambiar a "🚧"   (marcado como hecho pero archivo no encontrado — posible renombre)
    → anotar en la sección de "Discrepancias encontradas"

if archivo_existe AND estado_actual == "🚧":
    → cambiar a "✅"

if NOT archivo_existe AND estado_actual == "⬜":
    → mantener "⬜"    (sin cambios)

if NOT archivo_existe AND estado_actual == "🚧":
    → mantener "🚧"   (en progreso)
```

**Caso especial — ítems sin archivo verificable** (ej: Redis Cache, CI/CD, TenantGuard):
- Si el Glob no encuentra nada → mantener el estado actual
- No degradar de ✅ a 🚧 salvo que el archivo claramente ya no exista

---

## Paso 4 — Actualizar TODO.md

### 4a. Actualizar el header

Reemplaza las líneas de métricas con los valores actuales:

```markdown
> **Última actualización:** {FECHA_HOY}
> **Tests:** {TEST_PASSED} passed, {TEST_FAILED} failed ({TEST_SUITES} suites)
> **TypeScript:** {TS_ERRORS} errores
```

### 4b. Aplicar los cambios de estado

Para cada ítem cuyo estado cambió (Paso 3), edita la fila correspondiente en la tabla. Mantener el resto sin cambios.

### 4c. Actualizar la tabla de Resumen

Recalcula los totales de la tabla `## Resumen` contando los ✅, 🚧 y ⬜ actualizados.

### 4d. Agregar ítems nuevos (si los hay)

Si el Glob encontró archivos de service/controller que **no están listados** en el TODO.md (módulos o UCs nuevos implementados), agrégalos como nuevas filas con estado ✅ en la sección correspondiente.

Patrón para detectar ítems nuevos:
```bash
# Services existentes no en TODO
ls src/core/application/services/**/*.service.ts
```
Compara con los endpoints ya listados. Si aparece un service nuevo, agrégalo como nueva fila.

---

## Paso 5 — Reporte de cambios

Al finalizar, emite un resumen de lo que cambió:

```
## Cambios aplicados al TODO.md

### Ítems actualizados
- ⬜ → ✅  [Módulo X] nombre del ítem
- 🚧 → ✅  [Módulo Y] nombre del ítem

### Ítems nuevos detectados
- ✅ [Módulo Z] nombre del servicio nuevo

### Discrepancias encontradas (requieren revisión)
- ✅ → 🚧  [Módulo X] nombre (archivo no encontrado en path esperado)
  Ruta buscada: src/core/application/services/xxx/*.service.ts

### Sin cambios
- N ítems ya estaban en el estado correcto

### Métricas actualizadas
- Tests: antes {X} passed → ahora {TEST_PASSED} passed
- TS errors: antes {Y} → ahora {TS_ERRORS}
- Fecha: {FECHA_HOY}
```

---

## Notas

- **No borrar ítems**: si un ítem ✅ no tiene archivo verificable (ej: "Migración seed 002"), asumir que sigue ✅ y no degradar.
- **No agregar ítems futuros** (Redis, CI/CD) como ✅ a menos que el Glob los encuentre explícitamente.
- **Prioridad de confianza**: resultado de `npm test` > existencia de archivo > estado previo del TODO.
- Si `npm test` falla completamente (no corre), registrar `TEST_FAILED = DESCONOCIDO` y no actualizar el contador de tests.
