# Validar Implementación de Caso de Uso

Audita que la implementación real del código cumpla lo que define el spec del UC indicado. Solo lectura — no modifica código. Reporta discrepancias entre spec y código con archivo, línea y corrección sugerida.

**Argumento (`$ARGUMENTS`):** acepta las mismas tres formas que `/spec-code`, más el flag `--fix`:
- `UC-AUTH-06` — ID exacto
- `auth` — módulo → lista UCs y pregunta cuál validar
- `auth switch` — módulo + palabras clave → busca y confirma
- Agregar `--fix` a cualquier forma para aplicar correcciones simples automáticamente

Ejemplos: `UC-AUTH-06`, `auth switch`, `org crear --fix`, `UC-RBAC-02 --fix`

---

## Paso 0 — Determinar tipo, resolver argumento y localizar spec e implementación

### 0a. Leer SPEC_TYPE y extraer flags

Leer `SPEC_TYPE` de `claude_workspace/.env`. Si no está definida → asumir `api`.

Si `$ARGUMENTS` contiene `--fix` → registrar `FIX_MODE = true` y removerlo antes de continuar.

```
Si argumento coincide con UC-{PREFIJO}-{NNN}  →  ID exacto: localizar spec directamente
Si argumento es una sola palabra de módulo    →  listar UCs del módulo y preguntar
Si argumento tiene varias palabras            →  buscar por palabras clave y confirmar
```

Resolver alias de módulo usando `## 📋 Module Registry` de `rules/architecture.md`.
Si no coincide → Glob `claude_workspace/architecture/feature_spec/**/spec.md` y buscar `### {UC-ID}`.

### 0b. Leer la sección del UC en el spec

Extraer de `### {UC-ID}:`:

- `HTTP_METHOD` + `HTTP_PATH`
- `PANTALLA` *(solo `SPEC_TYPE=frontend`)*: componente donde ocurre el UC
- `INPUT_FIELDS`: campos del request / props de entrada
- `OUTPUT_FIELDS`: campos del response / estado de salida
- `FLUJO_PRINCIPAL`: pasos numerados
- `FLUJOS_ALTERNATIVOS`: condiciones → HTTP status / feedback + excepción esperada
- `REGLAS_APLICADAS`: lista de `[RN-XXX-NNN]` del flujo
- `GUARDS`: autenticación/autorización requerida

### 0c. Leer la arquitectura del proyecto y localizar artefactos

Leer `rules/architecture.md`. Extraer:
- **Flujo de Implementación** — lista ordenada de artefactos y su responsabilidad
- **Path Registry** — paths por clave

Para cada artefacto del Flujo de Implementación, construir el Glob usando el Path Registry + nombre canónico del UC y verificar si existe. El nombre canónico es el título del UC en kebab-case (`UC-INV-03 — Listar Inventario` → `list-inventory`).

Si algún artefacto crítico no existe → reportar como `🔴 CRÍTICO` y detener esa dimensión de validación.

---

## Paso 1 — Verificación de artefactos (existencia)

Usando el resultado del Paso 0c, emitir la tabla de estado derivada del Flujo de Implementación del proyecto:

| Artefacto | Path | Estado |
|-----------|------|--------|
| {Artefacto 1 del Flujo de Implementación} | {path del Path Registry} | ✅ existe / ❌ falta |
| {Artefacto 2} | ... | ✅ / ❌ |
| ... | | |

Si falta algún artefacto crítico (use case / service, artefacto de entrada, artefacto de salida, entry point) → marcar como `🔴 CRÍTICO` y sugerir `/spec-code {UC-ID}`.

---

## Paso 2 — Verificación del artefacto de entrada (DTO / Props / Payload)

> Las convenciones de validación de inputs de este proyecto están en `rules/` (ya en contexto).
> Verificar que el código las cumple para cada campo del spec.

Leer el artefacto de entrada (DTO, Props, schema de validación, etc.). Comparar con los `INPUT_FIELDS` del spec.

Para cada campo del spec verificar en el código:

| Check | Criterio universal |
|-------|--------------------|
| Campo existe | La propiedad o parámetro está declarado |
| Tipo correcto | El tipo coincide con lo que describe el spec (string, UUID, boolean, number, etc.) |
| Obligatorio/opcional | Marcado como requerido u opcional según el spec |
| Validación de formato | Si el spec restringe el formato (email, longitud, enum), hay validación correspondiente |
| Documentación | Si el proyecto documenta inputs (Swagger, JSDoc, PropTypes), el campo está documentado |

**Discrepancia típica:**
```
⚠️ Input — Campo faltante
   Spec indica: campo `organizationId` (requerido, UUID)
   Código: campo no encontrado en el artefacto de entrada
   Fix: agregar el campo con validación de tipo UUID y marcado como requerido
```

---

## Paso 3 — Verificación del artefacto de salida (Response DTO / Props / Estado)

> Los campos prohibidos en responses están definidos en `business-rules.md` del proyecto
> (ya en contexto o en `claude_workspace/architecture/`). Verificar según esas reglas.

Leer el artefacto de salida y el mapper/transformer. Comparar con `OUTPUT_FIELDS` del spec.

| Check | Criterio universal |
|-------|--------------------|
| Campos presentes | Todos los campos del output del spec están en el artefacto de respuesta |
| Sin campos internos expuestos | Campos marcados como internos/sensibles en `business-rules.md` NO aparecen en el output |
| Transformación completa | El mapper/transformer cubre todos los campos del output |
| Sin entidad de persistencia expuesta | El tipo de retorno es el artefacto de output del UC, no la entidad de persistencia cruda |

**Discrepancia típica:**
```
⚠️ Output — Campo sensible expuesto
   Archivo: user-response.dto.ts:18
   Código expone un campo marcado como interno en business-rules.md
   Fix: eliminar el campo del artefacto de output
```

---

## Paso 4 — Verificación de Reglas de Negocio

Para cada `[RN-XXX-NNN]` referenciado en el spec del UC, verificar que el service/use case lo implementa.

> Las reglas de negocio del proyecto están en `business-rules.md` y en el spec del módulo.
> Las convenciones de implementación de cada tipo de regla están en `rules/` (ya en contexto).

### Metodología de verificación por tipo de regla

Leer el service/use case completo. Para cada RN del spec:

**1. Reglas que producen errores** (spec dice "→ error / status 4xx"):

Verificar que el código lanza el error/excepción correspondiente al status del spec, usando el mecanismo de error del proyecto (definido en `rules/error-handling.md`).
- La condición del error coincide con lo que describe la RN
- El tipo de error/excepción produce el HTTP status (u equivalente) indicado en el spec

**2. Reglas de eliminación lógica** (si el proyecto usa soft delete según `business-rules.md`):

Verificar que no hay eliminación física donde el spec requiere soft delete. El mecanismo exacto está en `rules/` y `business-rules.md`.

**3. Reglas de auditoría** (si el proyecto registra autoría según `business-rules.md`):

En operaciones create/update/delete, verificar que los campos de auditoría (autoría del cambio) reciben el ID del usuario autenticado, no null ni valores hardcodeados.

**4. Reglas de filtro** (si el proyecto filtra registros eliminados según `business-rules.md`):

Verificar que las queries del repositorio aplicar el filtro de exclusión de registros eliminados.

**5. Reglas específicas del proyecto** (RN del módulo en el spec):

Verificar cada RN-* del spec según su descripción. Si la RN describe una condición de negocio → buscar esa condición en el código.

**Formato de reporte por RN:**

```
✅ RN-XXX-003 — [descripción breve]
   Verificado: archivo.ts:34

⚠️ RN-XXX-010 — [descripción breve]
   Código: archivo.ts:67 lanza error tipo A
   Spec indica: error tipo B
   Fix: cambiar el tipo de error para que coincida con el spec

⚪ RN-XXX-014 — [descripción breve]
   Requiere revisión manual (regla de infraestructura/ops)
```

---

## Paso 5 — Verificación del Entry Point

> El artefacto de entrada primaria del proyecto (Controller, Route Handler, Page Component, etc.)
> está definido en el Flujo de Implementación de `rules/architecture.md`.
> Las convenciones (decoradores, guards, documentación, delegación) están en `rules/`.

Leer el entry point del módulo según el Flujo de Implementación. Buscar el método/handler que corresponde al UC.

| Check | Criterio universal |
|-------|--------------------|
| Verbo / método correcto | El verbo HTTP (u operación equivalente) coincide con el spec |
| Path / ruta correcta | La ruta del handler coincide con el path del spec |
| Status de respuesta | El status de éxito coincide con el spec |
| Autenticación/autorización | Guards o middlewares de auth presentes si el spec los requiere; ausentes si el UC es público |
| Documentación | Si el proyecto documenta endpoints (Swagger, OpenAPI, JSDoc), el UC está documentado |
| Solo delega | El handler no contiene lógica de negocio — solo delega al service/use case |
| Parámetros correctos | Los parámetros (body, path, query, usuario autenticado) coinciden con el spec |

**Discrepancia típica:**
```
⚠️ Entry point — Status de respuesta incorrecto
   Archivo: module.controller.ts:145
   Código retorna status X por default
   Spec indica: status Y
   Fix: configurar el status correcto según las convenciones del proyecto

⚠️ Entry point — Guard de autorización faltante
   Spec requiere permiso/rol específico
   Código: no aplica el guard correspondiente
   Fix: agregar el guard/middleware de autorización según reglas del proyecto
```

---

## Paso 6 — Verificación de Flujos Alternativos

Comparar la lista de `FLUJOS_ALTERNATIVOS` del spec con los throws del service.

Para cada flujo alternativo del spec:
```
FA-1: Token Firebase inválido → 401
FA-2: Usuario desactivado → 401
FA-3: Sin membresía en org destino → 403
```

Verificar que cada uno tiene su rama en el service. Si falta alguno → `⚠️ Flujo alternativo no implementado`.

**Flujo alternativo no implementado:**
```
⚠️ Flujo Alternativo FA-3 no implementado
   Spec: "Si el usuario no tiene membresía en la org destino → 403 Forbidden"
   Código: switch-context.service.ts no verifica membresía en org destino antes de emitir JWT
   Fix: agregar verificación de membresía con ForbiddenException antes del jwtService.sign()
```

---

## Paso 7 — Verificación de Tests

> Los tipos de test del proyecto y sus paths están en el **Path Registry** de `rules/architecture.md`
> (claves `test_unit`, `test_integration`, `test_e2e` y equivalentes si existen).
> Las convenciones de cada tipo de test están en `rules/testing.md`.

Para cada tipo de test definido en el Path Registry, leer el archivo correspondiente al UC y verificar:

| Check | Criterio universal |
|-------|--------------------|
| Archivo existe | Path derivado del Path Registry + nombre canónico del UC |
| Camino feliz cubierto | Al menos 1 test positivo del flujo principal |
| Cada FA cubierto | Un test por cada flujo alternativo del spec |
| Dependencias aisladas | Las dependencias externas son mocks/stubs — no instancias reales ni llamadas a BD/red |
| Cleanup entre tests | Los mocks o estado se resetean entre tests |

Si un tipo de test no está definido en el Path Registry del proyecto → omitir esa fila sin reportar discrepancia.

```
⚠️ Tests — Flujo alternativo FA-3 no tiene test
   Spec FA-3: [condición] → [error esperado]
   Test faltante: `should [error] when [condición]`
   Sugerencia: usar /test-coverage {UC-ID} para generar el caso
```

---

## Paso 8 — Resumen del reporte

```
## Resultado de /spec-code-validate UC-AUTH-06 — Switch de Contexto

### Discrepancias encontradas: 3

| Severidad | Dimensión | Descripción |
|-----------|-----------|-------------|
| 🔴 CRÍTICO | Regla de negocio | RN-AUTH-010: lanza NotFoundException en vez de ForbiddenException |
| 🟡 MEDIO | Controller | @HttpCode faltante → retorna 200 en vez de 201 |
| 🟡 MEDIO | Tests | FA-3 no tiene test unitario |

### Verificaciones OK: 14

✅ Artefactos (5/5 existen)
✅ Request DTO (3 campos, tipos correctos)
✅ Response DTO (sin campos sensibles)
✅ RN-AUTH-003, RN-AUTH-006, RN-AUTH-008, RN-AUTH-011, RN-AUTH-017 (5 reglas OK)
✅ Soft delete no usado en este UC
✅ Auditoría: userId propagado correctamente
✅ Controller: path, método HTTP y guard correctos
✅ Flujos FA-1, FA-2 cubiertos en tests

### Acciones sugeridas
1. Corregir RN-AUTH-010: `throw new ForbiddenException(...)` en switch-context.service.ts:67
2. Agregar `@HttpCode(HttpStatus.OK)` en auth.controller.ts (o verificar si 200 es correcto para switch)
3. Ejecutar `/test-coverage auth` para generar test del FA-3
```

Si `--fix` fue pasado en los argumentos → aplicar automáticamente las correcciones de severidad 🟡 MEDIO que sean cambios de 1 línea (excepciones, decoradores HTTP). Las de 🔴 CRÍTICO siempre requieren confirmación del usuario.

---

## Cuándo usar este skill

| Momento | Uso |
|---------|-----|
| Después de `/spec-code` | Verificar que la implementación quedó alineada con el spec |
| Después de `/spec-validate` | Verificar qué partes del código quedaron desactualizadas |
| Antes de un PR | Auditoría final de un UC antes de merge |
| Al encontrar un bug | Verificar si el spec lo anticipaba como flujo alternativo no implementado |
| Review de código | Revisión objetiva sin depender del criterio del revisor |
