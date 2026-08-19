# Validar Especificación de Caso de Uso

Audita que la **documentación del spec** de un UC sea completa, coherente y alineada con las fuentes de verdad del proyecto. Solo lectura — no modifica archivos. Reporta omisiones, inconsistencias y referencias rotas con corrección sugerida.

> **Diferencia con `/spec-code-validate`:** este skill valida el *spec escrito*, no el código implementado.

**Argumento (`$ARGUMENTS`):**
- `UC-INV-03` — ID exacto
- `inventory` — módulo → lista UCs y pregunta cuál validar
- `inventory list` — módulo + palabras clave → busca y confirma

---

## Paso 0 — Determinar tipo y localizar el spec

### 0a. Leer SPEC_TYPE

Leer `SPEC_TYPE` de `claude_workspace/.env`. Si no está definida → asumir `api`.

Este valor determina:
- Qué fuente de verdad leer para verificar entidades y campos (Paso 3)
- Qué secciones estructurales son obligatorias (Paso 1)
- Qué tabla de resumen verificar (Paso 6)

### 0b. Resolver argumento y localizar el spec

```
Si argumento coincide con UC-{PREFIJO}-{NNN}  →  localizar spec directamente
Si argumento es una sola palabra de módulo    →  listar UCs del módulo y preguntar
Si argumento tiene varias palabras            →  buscar por palabras clave y confirmar
```

Resolver alias de módulo usando `## 📋 Module Registry` de `rules/architecture.md`.
Si no coincide → Glob `claude_workspace/architecture/feature_spec/**/{argumento}/spec.md`.

### 0c. Leer en paralelo

1. **Spec del módulo** → `claude_workspace/architecture/feature_spec/{módulo}/spec.md` — extraer la sección `### {UC-ID}:`
2. **Fuente de verdad del schema:**
   - `SPEC_TYPE=api` → `claude_workspace/architecture/ddl.sql` — tablas y columnas exactas
   - `SPEC_TYPE=frontend` → `claude_workspace/architecture/api_contracts/` (si existe); si no, leer el spec del módulo API equivalente — endpoint, campos en camelCase, status codes
3. **Reglas de negocio** → tabla `## Reglas de Negocio` del spec.md + `business-rules.md` (RN-GLO-*)
4. **Resumen** → sección al final del spec.md

---

## Paso 1 — Verificación de Estructura (secciones obligatorias)

| Sección | Qué buscar | api | frontend |
|---------|-----------|-----|----------|
| **Actor** | Línea `**Actor:**` con un valor | ✅ | ✅ |
| **Pantalla** | Línea `**Pantalla:**` con componente `.tsx` | — | ✅ |
| **Estado** | Línea `**Estado:**` con `🔲 Pendiente` (o equivalente) | — | ✅ |
| **Precondiciones** | Bloque `**Precondiciones:**` con al menos un ítem | ✅ | ✅ |
| **Método HTTP + Path** | `**{MÉTODO}** \`/{ruta}\`` | ✅ | ✅ |
| **Flujo Principal** | Bloque numerado dentro de ` ``` ` con al menos 3 pasos | ✅ | ✅ |
| **Diagrama de Secuencia** | Bloque ` ```mermaid ` con `sequenceDiagram` | ✅ | ✅ |
| **Flujos Alternativos** | Tabla `\| Condición \| Respuesta \| Regla \|` | ✅ | ✅ |
| **Reglas aplicadas** | Línea `**Reglas aplicadas:**` al final | ✅ | ✅ |
| **Separador `---`** | Al final del UC | ✅ | ✅ |
| **Ejemplo de datos** | Bloque JSON (api) o TypeScript (frontend) del response/estado exitoso | ✅ | ✅ |
| **Mockup** | Wireframe ASCII con el componente o pantalla | ⚠️ si tiene UI | ✅ |

Discrepancia típica:
```
❌ Sección faltante: Diagrama de Secuencia
   UC-INV-03 no contiene bloque ```mermaid sequenceDiagram```
   Fix: agregar el diagrama coherente con el flujo numerado
```

---

## Paso 2 — Verificación de Referencias a Reglas de Negocio (RN-*)

Para cada `[RN-XXX-NNN]` en el **Flujo Principal** o **Flujos Alternativos**:

### 2a. Verificar que la RN existe

Buscar en:
- Tabla `## Reglas de Negocio` del spec.md del módulo
- Reglas globales en `business-rules.md` (RN-GLO-*)

| Check | Resultado |
|-------|-----------|
| RN existe en tabla del módulo | ✅ |
| RN existe como regla global | ✅ |
| RN no encontrada en ninguna fuente | ❌ referencia rota |

### 2b. Verificar coherencia RN ↔ flujo

Para cada RN referenciada, leer su descripción y confirmar que el paso del flujo es consistente con ella.

```
⚠️ RN-INV-003 — Descripción no coincide con el uso en el flujo
   RN-INV-003 dice: "stock negativo → rechazar movimiento"
   Flujo paso 3 dice: "Si stock insuficiente → 409 Conflict"
   Fix: alinear el mensaje del flujo con el comportamiento descrito en la RN
```

### 2c. Verificar coherencia "Reglas aplicadas" ↔ RN del flujo

- RN en el flujo pero ausente del pie → ⚠️ omisión
- RN en el pie pero no referenciada en el flujo → ⚠️ referencia huérfana

---

## Paso 3 — Verificación contra la Fuente de Verdad del Schema

### 3a. Verificar entidades/endpoints mencionados en el flujo

**`SPEC_TYPE=api`** — para cada tabla/repositorio mencionado en el flujo:
- Buscar `CREATE TABLE` en `ddl.sql` con ese nombre exacto
- Reportar si no existe:
  ```
  ❌ Tabla no existe en DDL: 'product_stocks'
     El flujo menciona ProductStockRepository pero la tabla en ddl.sql es 'inventory'
     Fix: corregir el nombre en el flujo del UC
  ```

**`SPEC_TYPE=frontend`** — para cada endpoint mencionado en el flujo:
- Verificar que el método + ruta existe en el contrato API (o spec del módulo API equivalente)
- Reportar si no existe:
  ```
  ❌ Endpoint no existe en el contrato: PATCH /inventory/:id/adjust
     El contrato solo tiene POST /inventory/movements
     Fix: corregir el método y ruta en el flujo del UC
  ```

### 3b. Verificar que los campos del ejemplo de datos existen en la fuente de verdad

**`SPEC_TYPE=api`** — campos del JSON de request/response → deben tener columna en `ddl.sql` o ser derivados documentados.

**`SPEC_TYPE=frontend`** — campos del shape TypeScript → deben tener correspondencia en el response del contrato API (camelCase).

```
❌ Campo inexistente: 'warehouseId' en el request
   El contrato API no tiene ese campo en el body del endpoint
   Fix: usar el nombre correcto según la fuente de verdad
```

### 3c. Verificar que campos internos/sensibles NO aparecen en el ejemplo de datos

Verificar contra `business-rules.md`. Campos típicamente prohibidos: `isDeleted`, `deletedAt`, `deletedUserId`, hashes, tokens.

```
⚠️ Campo sensible en response: "isDeleted": false
   Fix: eliminar del ejemplo — RN-GLO-006
```

---

## Paso 4 — Coherencia Flujo Principal ↔ Flujos Alternativos

### 4a. Cada condición de error del flujo tiene su FA

Para cada rama `→ {4xx}` o `→ excepción` en el flujo principal, verificar que existe fila en la tabla de FAs.

```
⚠️ FA faltante para paso 2a
   Flujo: "2a. Si producto no encontrado → 404"
   Tabla FA: no tiene fila para este caso
   Fix: agregar | Producto no encontrado | 404 Not Found | — |
```

### 4b. Status codes consistentes entre flujo y FA

```
⚠️ Status inconsistente
   Flujo paso 3: "→ 403 Forbidden"
   FA tabla: "401 Unauthorized" para la misma condición
   Fix: unificar — revisar qué status dicta la RN referenciada
```

### 4c. FA implícito de autenticación

Si el UC requiere autenticación (no marcado con `@Public()` o equivalente):

**`SPEC_TYPE=api`** — verificar que la tabla de FAs incluye la fila de JWT inválido/expirado → 401.

**`SPEC_TYPE=frontend`** — verificar que los FAs documentan la sesión expirada (401) y su manejo (interceptor refresh → retry, o redirección a login). Si el mecanismo es transparente al UC y está documentado globalmente → ✅ aceptable si el spec lo indica.

```
⚠️ FA implícito faltante: sesión expirada
   El UC requiere auth pero los FAs no documentan el caso 401
   Fix: agregar | Sesión expirada (401) | Interceptor refresh → retry | RN-GLO-005 |
```

---

## Paso 5 — Coherencia Diagrama de Secuencia ↔ Flujo Principal

| Check | Qué verificar |
|-------|--------------|
| Participantes correctos | Todos los actores del flujo tienen su `participant` — api: Controller/Service/Repo/DB; frontend: Page/UseCase/HttpRepo/API |
| Sin participantes de capa incorrecta | api: no debe haber User/Page; frontend: no debe haber Controller/TypeORM/PostgreSQL |
| Orden de llamadas | El orden de `->>` coincide con los pasos numerados del flujo |
| Bloques `alt` para FAs | Los flujos alternativos principales tienen su `alt...else...end` |
| Respuesta final | Flecha `-->>` de retorno al cliente con el status/feedback correcto |
| Sin participantes fantasma | No hay `participant` declarado que nunca se use en las flechas |

```
⚠️ Participante de capa incorrecta (frontend)
   El diagrama incluye `participant DB as PostgreSQL`
   Un spec frontend no debe tener participantes de infraestructura backend
   Fix: eliminar el participante y ajustar las flechas al participante API
```

---

## Paso 6 — Verificación del Resumen / Registro del UC

**`SPEC_TYPE=api`** — verificar presencia en tabla `## Resumen de Endpoints` al final del spec.md:

| Check | Qué verificar |
|-------|--------------|
| UC-ID existe en la tabla | La fila `{UC-ID}` está presente |
| Endpoint coincide | Método + ruta del flujo iguales a los de la tabla |
| Status codes representativos | Al menos el status de éxito está listado |
| RN clave referenciada | Al menos 1 RN importante está en la columna |

```
❌ UC-INV-03 no está en la tabla de Resumen de Endpoints
   Fix: agregar | INV-03 | `/inventory` | GET | 200, 401 | RN-INV-001 |
```

**`SPEC_TYPE=frontend`** — verificar presencia en `claude_workspace/TODO.md`:

```
❌ UC-ORG-11 no está registrado en TODO.md
   Fix: agregar | UC-ORG-11 | Archivar Organización | 🔲 | — |
```

---

## Paso 7 — Verificación de UC-ID (unicidad y secuencia)

| Check | Criterio |
|-------|---------|
| UC-ID no duplicado | No hay dos secciones `### {UC-ID}:` con el mismo ID en el spec.md |
| Numeración sin huecos grandes | Números relativamente consecutivos (huecos pequeños son aceptables) |
| Prefijo correcto | `UC-INV-*` en módulo inventory, `UC-CAT-*` en categories, etc. |

---

## Paso 8 — Resumen del Reporte

```
## Resultado de /spec-validate {UC-ID} — {Nombre}

### Discrepancias encontradas: N

| Severidad | Dimensión | Descripción |
|-----------|-----------|-------------|
| 🔴 CRÍTICO | Referencias RN | [RN-INV-099] no existe en ninguna tabla de reglas |
| 🔴 CRÍTICO | Schema | Tabla/endpoint 'xxx' no existe en la fuente de verdad |
| 🟡 MEDIO | Flujos Alternativos | FA de autenticación fallida ausente |
| 🟡 MEDIO | Reglas aplicadas | RN-GLO-001 listada al pie pero no referenciada en el flujo |
| 🟢 MENOR | Diagrama | Participante faltante o de capa incorrecta |
| 🟢 MENOR | Datos | Campo sensible en el ejemplo de response |

### Verificaciones OK: N

✅ Estructura completa ({n}/{total} secciones presentes)
✅ Referencias RN-XXX existen y son coherentes con el flujo
✅ Entidades/endpoints del flujo existen en la fuente de verdad
✅ Coherencia flujo ↔ FA para caminos de error explícitos
✅ Diagrama coherente con el flujo (participantes, orden, bloques alt)
✅ UC-ID registrado en {Resumen de Endpoints / TODO.md}
✅ UC-ID único en el módulo con prefijo correcto

### Acciones sugeridas (ordenadas por severidad)
1. ...
2. ...
```

---

## Cuándo usar este skill

| Momento | Uso |
|---------|-----|
| Después de `/spec-create` | Verificar que el spec generado está completo y bien formado |
| Antes de `/spec-code` | Asegurar que el spec es implementable sin ambigüedades |
| En revisión de documentación | Auditoría de calidad antes de un PR |
| Al detectar bug en producción | Verificar si el spec anticipaba el caso como FA no documentado |
