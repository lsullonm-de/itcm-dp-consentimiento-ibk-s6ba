# Test Coverage — Verificar y Completar Cobertura

Corre los tests del módulo indicado con `--coverage`, verifica el umbral del 85% definido en `testing.md`, identifica las líneas sin cobertura y genera los casos de test faltantes.

**Argumento (`$ARGUMENTS`):** nombre de módulo o servicio.
Ejemplos: `auth`, `organization`, `brand`, `rbac`, `menu`, `product`, `domain`, `token-exchange`, `create-org`

Sin argumento → reporte completo de todos los módulos.

---

## Paso 0 — Resolver paths del módulo

> Los paths están en la tabla `## 🗂️ Path Registry` de `rules/architecture.md` (ya en contexto).
> Usar las claves del registry para construir los paths — no hardcodear valores aquí.

Reglas de derivación para `$ARGUMENTS` usando el Path Registry:

- **Source path** → `{services}/{argumento}/**/*.ts`
- **Unit test path** → `{test_unit}/{argumento}`
- **Integration test path** → `{test_integration}` (buscar con Glob `**/*{argumento}*`)
- **E2E test path** → `{test_e2e}/{argumento}`

Si el argumento es un **nombre de servicio parcial** (ej: `token-exchange`) → buscar con Glob en `{services}/**/*{argumento}*` para encontrar el directorio exacto, luego derivar los demás paths.

Si el argumento es **vacío** → cobertura total:
- Source: `{services}/**/*.ts` (solo servicios — controllers/repos se verifican vía integration + E2E)
- Tests: sin filtro de path (correr todos)

Si algún directorio de test no existe → anotar como `⚠️ pendiente` en el reporte, no fallar.

---

## Paso 1 — Ejecutar los tres tipos de tests

### Si el argumento es un módulo conocido:

**1a. Unit tests con coverage:**
```bash
npm run test:cov -- \
  --testPathPattern="<UNIT_TEST_PATH>" \
  --collectCoverageFrom='["<SOURCE_GLOB>"]' \
  --forceExit 2>&1
```

**1b. Integration tests (repositorios TypeORM):**
```bash
npm run test:integration -- \
  --testPathPattern="<INTEGRATION_TEST_PATH>" \
  --forceExit 2>&1
```

**1c. E2E tests (endpoints HTTP):**
```bash
npm run test:e2e -- \
  --testPathPattern="<E2E_TEST_PATH>" \
  --forceExit 2>&1
```

Si el directorio integration o E2E del módulo no existe → anotar como `⚠️ pendiente` en el reporte, no fallar.

### Si el argumento es vacío (cobertura total):

**1a. Unit tests con coverage (solo servicios de aplicación):**
```bash
npm run test:cov -- \
  --collectCoverageFrom='["src/core/application/services/**/*.ts"]' \
  --forceExit 2>&1
```

**1b. Integration tests (todos):**
```bash
npm run test:integration -- --forceExit 2>&1
```

**1c. E2E tests (todos):**
```bash
npm run test:e2e -- --forceExit 2>&1
```

### Si Jest falla al compilar (error TS antes de correr tests):

```bash
npx tsc --noEmit 2>&1 | head -20
```

Resolver los errores TypeScript antes de continuar.

---

## Paso 2 — Parsear la tabla de coverage

La salida de Jest incluye una tabla de texto con este formato:

```
----------|---------|----------|---------|---------|-------------------
File      | % Stmts | % Branch | % Funcs | % Lines | Uncovered Line #s
----------|---------|----------|---------|---------|-------------------
 services |         |          |         |         |
  auth    |         |          |         |         |
   my.svc |   87.50 |    75.00 |  100.00 |   87.50 | 45,72-78
----------|---------|----------|---------|---------|-------------------
All files |   87.50 |    75.00 |  100.00 |   87.50 |
```

Para cada archivo del módulo registrar:
- `FILE`: ruta relativa
- `STMTS`: % Statements
- `BRANCH`: % Branch
- `FUNCS`: % Functions
- `LINES`: % Lines
- `UNCOVERED`: lista de líneas (columna última)

**Umbral del proyecto:** ≥ **85%** en Stmts, Branch, Funcs y Lines.

---

## Paso 3 — Emitir reporte de estado por archivo

Para cada archivo del módulo:

```
## 📄 src/core/application/services/auth/token-exchange.service.ts

| Métrica    | Valor  | Estado |
|------------|--------|--------|
| Statements | 92.30% | ✅     |
| Branches   | 75.00% | ❌     |
| Functions  | 100%   | ✅     |
| Lines      | 92.30% | ✅     |

Líneas sin cobertura: 45, 72-78
```

Al final del módulo:

```
### Resumen del módulo: auth
- Archivos analizados: N
- ✅ Cumplen umbral 85%: K archivos
- ❌ Bajo umbral: M archivos → requieren tests adicionales
- Cobertura global del módulo: XX.XX%
```

Si **todos los archivos cumplen** → emitir:
```
✅ Módulo [auth] cumple el umbral del 85% en todas las métricas.
```
Y detener aquí.

---

## Paso 4 — Identificar código sin cobertura

Para cada archivo con alguna métrica < 85%, o con líneas en `Uncovered Line #s`:

1. **Leer las líneas sin cobertura** usando Read con `offset` y `limit` para ir directamente a esos rangos.
2. Para cada rango de líneas, clasificar el tipo de código no cubierto:

| Tipo de código | Ejemplo | Test a generar |
|----------------|---------|----------------|
| Rama `if` no cubierta | `if (condition) { throw X }` | Test que cumple/no cumple `condition` |
| `throw XxxException` | `throw new NotFoundException(...)` | `rejects.toThrow(NotFoundException)` |
| Método sin ningún test | método completo | Camino feliz + al menos 1 error |
| Bloque `else` no cubierto | `else { return default }` | Test que llega al `else` |
| Guard de `null/undefined` | `if (!entity) throw` | Test con mock retornando `null` |
| Early return | `if (already) return existing` | Test donde la condición es verdadera |

3. Anotar por archivo:
   ```
   Archivo: token-exchange.service.ts
   Líneas 72-78: bloque catch — usuario desactivado (isActive = false)
   Líneas 45:    rama else — sin membresía default → ForbiddenException
   ```

---

## Paso 5 — Generar los casos de test faltantes

Para cada caso identificado en el Paso 4, generar el test siguiendo las convenciones del proyecto:

### Convenciones obligatorias

- **Patrón AAA:** `// Arrange` → `// Act` → `// Assert`
- **Nombres descriptivos:** `should throw XxxException when {condición}`
- **Alias de imports:** `@core/` y `@infra/` — nunca rutas relativas
- **Dependencias:** mockear con `jest.fn()` en `beforeEach`, resetear automáticamente
- **Firebase:** siempre mockeado — nunca llamadas reales
- **Un assert principal por test** cuando sea posible

### Plantilla para un caso faltante

```typescript
it('should throw NotFoundException when entity does not exist', async () => {
  // Arrange
  mockRepo.findById.mockResolvedValue(null);

  // Act & Assert
  await expect(service.execute({ id: 'non-existent-id' }))
    .rejects.toThrow(NotFoundException);
});
```

### Plantilla para rama `else` / early return

```typescript
it('should return existing record when already assigned', async () => {
  // Arrange
  mockRepo.findExisting.mockResolvedValue(mockRecord); // condición verdadera → early return

  // Act
  const result = await service.execute(validDto);

  // Assert
  expect(result).toEqual(expectedResponseDto);
  expect(mockRepo.save).not.toHaveBeenCalled(); // confirmar que no creó duplicado
});
```

### Plantilla para branch no cubierto en guards

```typescript
it('should throw ForbiddenException when user has no active membership', async () => {
  // Arrange
  mockMembershipRepo.findDefault.mockResolvedValue(null);

  // Act & Assert
  await expect(service.execute(dto)).rejects.toThrow(ForbiddenException);
});
```

---

## Paso 6 — Escribir los tests en el spec file

1. **Localizar el archivo spec** correspondiente:
   - Pattern: `test/unit/core/application/services/{módulo}/{service-name}.service.spec.ts`
   - Si no existe: crearlo siguiendo el template de `testing.md`

2. **Leer el spec file actual** para entender los mocks ya definidos en `beforeEach` y evitar duplicar `describe` blocks.

3. **Insertar los nuevos tests** dentro del `describe` block correcto:
   - Si el test es sobre un método ya testeado → agregar dentro del `describe` del método
   - Si es un método sin tests → crear nuevo `describe('methodName', () => { ... })`

4. **Verificar que los nuevos mocks** estén declarados en el `beforeEach` o como variables del `describe` externo.

5. **Ejecutar los tests nuevamente** para confirmar que los tests generados pasan:

```bash
npm run test:cov -- \
  --testPathPattern="<TEST_PATH>" \
  --collectCoverageFrom='["<SOURCE_GLOB>"]' \
  --forceExit 2>&1
```

Si algún test generado falla → corregirlo antes de reportar éxito.

---

## Paso 7 — Reporte final

Emitir un resumen comparativo antes/después:

```
## Resultado de /test-coverage [módulo]

### Unit Tests — Cobertura de servicios
#### Antes
| Archivo | Stmts | Branch | Funcs | Lines |
|---------|-------|--------|-------|-------|
| token-exchange.service.ts | 87.50% | 66.67% ❌ | 100% | 87.50% |

#### Tests generados (N nuevos casos)
- token-exchange.service.ts:
  - ✅ `should throw UnauthorizedException when user is deactivated`
  - ✅ `should throw ForbiddenException when no default membership exists`

#### Después
| Archivo | Stmts | Branch | Funcs | Lines |
|---------|-------|--------|-------|-------|
| token-exchange.service.ts | 95.83% | 91.67% ✅ | 100% | 95.83% |

### Integration Tests — Repositorios TypeORM
| Suite | Tests | Estado |
|-------|-------|--------|
| typeorm-inventory.repository.integration-spec.ts | N passed | ✅ / ⚠️ pendiente |

### E2E Tests — Endpoints HTTP
| Suite | Tests | Estado |
|-------|-------|--------|
| auth.e2e-spec.ts | 5 passed | ✅ |
| (módulo).e2e-spec.ts | N passed | ✅ / ⚠️ pendiente |

### Estado final
✅ Módulo [auth] cumple el umbral del 85% en unit tests.
✅ Integration: N tests pasando.
✅ E2E: N tests pasando.
```

Si hay módulos implementados **sin integration file o sin E2E file**: listar como deuda técnica:
```
⚠️ Tests pendientes:
  - test/integration/.../typeorm-categories.repository.integration-spec.ts — no existe
  - test/e2e/categories/categories.e2e-spec.ts — no existe
```

---

## Notas

- **No modificar código fuente** para aumentar coverage artificialmente (ej: eliminar ramas). Solo agregar tests.
- **No testear implementation details:** testear comportamiento observable (excepciones, valores retornados, métodos llamados).
- **Branches difíciles de cubrir** (ej: manejo de errores de BD inesperados): anotar como `⚪ Rama omitida intencionalmente` con justificación, y no contar como deuda.
- Si el spec file no existe para un servicio implementado, crearlo completo siguiendo el template de `testing.md` antes de agregar los casos faltantes.
- Si `npm run test:cov` tarda demasiado al correr todos los módulos, limitar siempre con `--testPathPattern`.
