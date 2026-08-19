# Implementar Caso de Uso

Implementa (o actualiza) todos los artefactos de código correspondientes al UC indicado. Detecta qué ya existe y aplica solo el delta necesario.

**Argumento (`$ARGUMENTS`):**
- `UC-INV-03` — ID exacto → implementa directamente
- `inventory` — módulo → lista UCs disponibles y pregunta cuál implementar
- `inventory list` — módulo + palabras clave → busca, confirma y procede

---

## Paso 0 — Determinar tipo y resolver el argumento

Leer `SPEC_TYPE` de `claude_workspace/.env`. Si no está definida → asumir `api`.

Este valor determina qué secciones del spec extraer (Paso 0c) y qué tipos de test aplican (Paso 5).

### 0a. Detectar tipo de argumento

```
Si $ARGUMENTS coincide con UC-{PREFIJO}-{NNN}  →  ID exacto: localizar spec directamente
Si $ARGUMENTS es una sola palabra              →  módulo: listar UCs y preguntar
Si $ARGUMENTS tiene varias palabras            →  módulo + búsqueda: buscar y confirmar
```

Resolver alias de módulo usando `## 📋 Module Registry` de `rules/architecture.md`.
Si es módulo → leer spec, extraer todos los `### UC-{ID}:` y presentar lista al usuario.
Si es módulo + palabras clave → buscar coincidencia en títulos, confirmar antes de proceder.

### 0b. Leer las reglas de arquitectura del proyecto

Leer `rules/architecture.md` del proyecto actual. Extraer y registrar:

- **Flujo de Implementación** — tabla ordenada de artefactos, su capa y responsabilidad
- **Path Registry** — paths absolutos o relativos de cada artefacto por clave
- **Module Registry** — alias de módulo → carpeta spec y sufijo de ruta

> Estas tablas son la **única fuente de verdad** para el inventario de artefactos (Paso 1) y el orden de implementación (Paso 3). No asumir rutas ni estructura de capas — leer del archivo.

### 0c. Leer la sección del UC en el spec

Buscar `### {UC-ID}:` en `claude_workspace/architecture/feature_spec/{módulo}/spec.md`. Extraer:

| Campo | Dónde encontrarlo |
|-------|------------------|
| `TITULO` | Nombre del UC |
| `HTTP_METHOD` + `HTTP_PATH` | Línea `**{MÉTODO}** \`/{ruta}\`` |
| `PANTALLA` | Línea `**Pantalla:**` *(solo si `SPEC_TYPE=frontend`)* |
| `INPUT_FIELDS` | Bloque Request del spec |
| `OUTPUT_FIELDS` | Bloque Response del spec |
| `FLUJO_PRINCIPAL` | Pasos numerados del flujo |
| `FLUJOS_ALTERNATIVOS` | Tabla de FAs |
| `REGLAS_APLICADAS` | `[RN-XXX-NNN]` mencionados en el flujo |
| `GUARDS_REQUERIDOS` | Auth requerida según el spec y `rules/security.md` o equivalente |

---

## Paso 1 — Inventario de artefactos existentes

Usando el **Flujo de Implementación** y el **Path Registry** de `rules/architecture.md` leídos en Paso 0b, construir la tabla de artefactos esperados para este UC.

El Flujo de Implementación define qué artefactos crear y en qué orden. El Path Registry define dónde crearlos. **No asumir artefactos que no estén en esas tablas.**

Para cada artefacto del Flujo de Implementación:

1. Construir el path usando el Path Registry + nombre canónico del UC
2. Hacer Glob para verificar si existe
3. Registrar: `CREAR` si no existe, `ACTUALIZAR` si existe, `SIN CAMBIOS` si existe y el UC no lo afecta

El nombre canónico se deriva del título del UC en kebab-case:
- `UC-INV-03 — Listar Inventario` → `list-inventory`
- `UC-ORG-11 — Archivar Organización` → `archive-organization`

**Si un archivo existe → leerlo antes de modificar. Nunca sobreescribir sin leer primero.**

---

## Paso 2 — Plan de implementación

Antes de escribir código, emitir el plan derivado del inventario:

```
## Plan de implementación: {UC-ID} — {Nombre}

### Estado actual
- ✅ {Artefacto}: ya existe (sin cambios)
- ✅ {Artefacto}: ya existe → ACTUALIZAR (delta: {descripción breve})
- ⬜ {Artefacto}: no existe → CREAR

### Orden de implementación (según Flujo de Implementación de rules/architecture.md)
1. {Artefacto 1}
2. {Artefacto 2}
...
```

Esperar confirmación implícita — si el usuario no objeta, proceder.

---

## Paso 3 — Implementar en orden de dependencias

> El orden canónico de artefactos está en el **Flujo de Implementación** de `rules/architecture.md`.
> Las convenciones de código (naming, patrones, DI, manejo de errores, decoradores, JSDoc) están en `rules/`.
> Los paths concretos están en el **Path Registry**.
> **No repetir ni asumir nada que ya esté en esas fuentes — leer de ellas.**

Para cada artefacto en el orden del Flujo de Implementación:

1. **Verificar existencia** — resultado del Paso 1
2. **Leer antes de modificar** — si existe, leerlo completo
3. **Aplicar solo el delta** — agregar el método o campo nuevo; no reescribir lo que no cambia
4. **Seguir `rules/`** — estilo, patrones, inyección de dependencias, manejo de errores
5. **Comentar RN-*** — cada validación de negocio incluye `// [RN-XXX-NNN]` para trazabilidad

### Registro en el entry point de la aplicación

Si el módulo del UC es nuevo, verificar que esté registrado en el entry point centralizado del proyecto (ej: módulo raíz, router principal, container de DI). Si no → agregarlo.

> Sin este paso el módulo queda definido pero nunca se carga.

---

## Paso 4 — Verificar compilación

Ejecutar el comando de verificación de tipos del proyecto (definido en `rules/tooling.md` o `package.json`):

```bash
# Derivar el comando de rules/tooling.md — ejemplos típicos:
npx tsc --noEmit          # TypeScript
npx tsc --noEmit --strict
```

Si hay errores de tipos → corregirlos antes de continuar.

Errores comunes:
- Método en output port no implementado en repositorio → agregar implementación
- Tipo incompatible en mapper/transformer → ajustar tipos
- Import faltante → agregar import

---

## Paso 5 — Escribir tests

> Los tipos de tests del proyecto, sus paths y su setup están en:
> - `rules/testing.md` del proyecto — estrategia, templates, convenciones
> - **Path Registry** de `rules/architecture.md` — claves `test_unit`, `test_integration`, `test_e2e` (y equivalentes frontend)

Para cada tipo de test definido en el Path Registry:

### Test unitario (`test_unit`)

Crear o actualizar `{test_unit}/{módulo}/{nombre}.{sufijo}.spec.ts`.

Cobertura mínima:
- **Camino feliz** — flujo principal completo con inputs válidos
- **Un test por cada flujo alternativo** del spec
- **Un test por cada RN-*** crítico no cubierto por los anteriores

Reglas universales:
- Patrón **AAA**: `// Arrange` → `// Act` → `// Assert`
- Mockear todas las dependencias externas
- No hacer llamadas reales a BD, red ni servicios externos
- Resetear mocks en `beforeEach`

### Test de integración (`test_integration`) — *si la clave existe en el Path Registry*

Aplica cuando el proyecto tiene tests que verifican una capa de persistencia o adapter real (BD, API externa con servidor mock, etc.). Ver template en `rules/testing.md`.

- Si el archivo existe → leer y agregar solo los casos de los métodos nuevos del UC
- Si no existe → crear con setup + casos de todos los métodos del artefacto de persistencia

Qué testear: por cada método nuevo o modificado en el repositorio/adapter del UC, cubrir camino feliz + caso nulo/vacío + soft delete (si aplica en el proyecto).

### Test E2E (`test_e2e`) — *si la clave existe en el Path Registry*

Aplica cuando el proyecto tiene tests que ejercen el stack completo (HTTP endpoint o flujo completo de UI). Ver template en `rules/testing.md`.

- Si el archivo existe → leer y agregar casos del UC dentro del `describe` existente
- Si no existe → crear con setup + casos del UC

Casos obligatorios por UC:
- Camino feliz → status de éxito + campos clave del response/estado
- Input inválido → status de error de validación
- Un test por cada flujo alternativo del spec

Reglas universales para E2E:
- Un `describe` por endpoint o flujo, no por UC
- No mockear la capa de persistencia (BD real o servidor mock real según el tipo de proyecto)
- Aislar estado entre tests con seed o cleanup en `beforeEach`/`afterEach`

---

## Paso 6 — Correr tests y verificar

Derivar los comandos de `rules/tooling.md` o `package.json`. Ejemplos típicos:

```bash
# Unit
npm test -- --testPathPattern="{nombre}" --forceExit

# Integration (si aplica en el proyecto)
npm run test:integration -- --testPathPattern="{nombre}" --forceExit

# E2E (si aplica en el proyecto)
npm run test:e2e -- --testPathPattern="{módulo}" --forceExit
```

Si algún test falla → corregir antes de continuar. No reportar éxito con tests en rojo.

Si el entorno de integración o E2E no está disponible localmente (sin BD, sin servidor) → anotar como pendiente y continuar; corren en CI.

---

## Paso 7 — Actualizar TODO.md

Marcar como `✅` el ítem del UC en `claude_workspace/TODO.md`.
Si no estaba listado → agregar como nueva fila `✅`.

---

## Paso 8 — Reporte final

```
## Implementación completada: {UC-ID} — {Nombre}

### Artefactos creados
- ⬜ → ✅  {path}  ({descripción del delta})

### Artefactos actualizados
- ✅ → delta  {path}  ({descripción del delta})

### Sin cambios
- ✅  {path}

### Tests
- Unit:        {N} tests pasan — cobertura: {X}%
- Integration: {N} tests pasan  (o: no aplica en este proyecto)
- E2E:         {N} tests pasan  (o: no aplica en este proyecto)

### TODO.md
- ✅ {Nombre} ({UC-ID}) — marcado
```

---

## Cuándo NO usar este skill

| Situación | Skill correcto |
|-----------|---------------|
| El UC no existe en el spec | `/spec-create` primero |
| El spec tiene ambigüedades antes de implementar | `/spec-validate` primero |
| Solo verificar que el código cumple el spec | `/spec-code-validate` |
| Solo agregar tests de cobertura faltantes | `/test-coverage` |
