# Desarrollar Especificación de Caso de Uso

> **Paths de artefactos:** los paths canónicos están definidos en `rules/architecture.md` (ya en contexto) — usar esa referencia para todas las rutas de artefactos.

Desarrolla la especificación completa del caso de uso **"$ARGUMENTS"** siguiendo el formato canónico del proyecto.

El argumento tiene el formato: `{módulo} {UC-ID}: {nombre descriptivo}`
Ejemplos:
- `01-auth UC-AUTH-09: Desactivar Usuario`
- `03-inventory UC-INV-05: Ajuste Manual de Stock`
- `organizations UC-ORG-11: Archivar Organización`

---

## Paso 0 — Determinar tipo de especificación

Leer `SPEC_TYPE` de `claude_workspace/.env`. Si no está definida → asumir `api`.

| Valor | Significado |
|-------|-------------|
| `api` | UC de backend REST (NestJS). Fuente de verdad: DDL. |
| `frontend` | UC de interfaz de usuario. Fuente de verdad: contrato API. |

Este valor afecta únicamente la **fuente de verdad a leer** (Paso 0b) y el **formato de los ejemplos de datos** (Paso 6). El resto del skill es idéntico para ambos tipos.

---

## Paso 0b — Preparación (leer antes de escribir)

Leer en paralelo:

1. **Spec del módulo** → `claude_workspace/architecture/feature_spec/{módulo}/spec.md`
   - Último UC-ID usado para determinar el número siguiente
   - Reglas de negocio existentes (RN-XXX) para referenciarlas
   - Formato y estilo de los UCs ya documentados

2. **Fuente de verdad del schema:**
   - `SPEC_TYPE=api` → `claude_workspace/architecture/ddl.sql` — nombres exactos de tablas y columnas
   - `SPEC_TYPE=frontend` → `claude_workspace/architecture/api_contracts/` (si existe) — endpoint, request body, response shape y status codes; si no existe, leer el spec del módulo API equivalente

3. **business-rules.md** → `claude_workspace/architecture/business-rules.md`
   - Reglas globales (RN-GLO-*) aplicables al UC

4. **Resumen de endpoints** al final del spec.md del módulo
   - Para determinar el próximo UC-ID libre

---

## Paso 1 — Identificar el UC

Determina y confirma:

| Campo | Valor |
|-------|-------|
| **Módulo** | (ej: Inventory, Organizations…) |
| **UC-ID** | (ej: UC-INV-05) — el siguiente disponible en el módulo |
| **Nombre** | (ej: Ajuste Manual de Stock) |
| **Endpoint** | Método HTTP + ruta — `GET /inventory`, `POST /organizations/:id/archive` |
| **Actor** | Quién invoca el UC (ej: Administrador, Sistema de Monitoreo, Usuario autenticado) |
| **Pantalla** | *(solo frontend)* Componente donde ocurre (ej: `InventoryListPage`, `OrganizationDialog`) |

Si hay ambigüedad en el UC-ID o el endpoint, infiere la respuesta más lógica según los UCs existentes y continúa.

---

## Paso 2 — Definir Reglas de Negocio

Si el UC introduce lógica nueva no cubierta por ningún RN-XXX existente, propón reglas nuevas:

```
| **RN-{MÓDULO}-{NRO}** | Descripción clara de la restricción o comportamiento | Capa de Validación | Implementación sugerida |
```

**Numeración:** busca el último número usado en el bloque `RN-{MÓDULO}-*` del spec.md y continúa desde ahí.

**Capas de validación** (según lo que aplique al tipo de proyecto):

| Capa | api | frontend |
|------|-----|----------|
| `DTO` | Validación de entrada con class-validator | — |
| `Domain` | Lógica de negocio pura | — |
| `Servicio` | Orquestación del caso de uso | — |
| `Repo` | Query-level constraints | — |
| `Guard` | Auth / permisos | — |
| `DB` | Constraints de base de datos | — |
| `Zod` | — | Validación client-side del formulario |
| `RHF` | — | Errores inline por campo (`setError`) |
| `UseCase` | — | Lógica de negocio en capa Application frontend |
| `Presentation` | — | Estado de UI, visibilidad condicional |
| `HTTP` | — | Manejo de respuesta del servidor (status codes, retry) |

**Reglas globales de referencia frecuente:**
- `RN-GLO-001` — `id` UUID autogenerado
- `RN-GLO-003` — `created_at` / `updated_at` automáticos
- `RN-GLO-005` — JWT válido en header `Authorization: Bearer`
- `RN-GLO-007/008` — Soft delete: `is_deleted = true` + `deleted_at` + `deleted_user_id`
- `RN-GLO-009/010` — Auditoría: `created_user_id` / `updated_user_id` = `JWT.sub`
- `RN-GLO-011` — Todos los queries filtran `WHERE is_deleted = false`

---

## Paso 2b — Actualizar Schema *(solo si `SPEC_TYPE=api` y el UC requiere un campo nuevo)*

> Si todos los campos del flujo ya existen en `ddl.sql` → saltar este paso.

1. Agregar la columna en el `CREATE TABLE` correspondiente de `ddl.sql`
2. Documentar la migración UP/DOWN en `migrations.sql`
3. Crear el archivo de migración TypeORM
4. Propagar en orden (Path Registry de `rules/architecture.md`):
   - TypeORM entity → Domain entity → Output port → DTO → Mapper → Repository

---

## Paso 3 — Flujo Principal

Escribe el flujo **numerado** dentro de un bloque de código. El flujo describe el camino feliz de la interacción, con sub-ramas para condiciones alternativas.

```
{MÉTODO} /{ruta}  [{ body_example }]
  Header: Authorization: Bearer <JWT>   ← omitir si el UC es público (@Public())
  1. Descripción del paso  [RN-XXX]
  2. {Entidad}Repository.método(params)  ← api: TypeORM repo | frontend: UseCase → HttpRepo → API
     2a. Condición alternativa → resultado  [RN-XXX]
     2b. Otra condición → resultado
  3. Validación de negocio  [RN-XXX, RN-YYY]
  4. Operación principal
  5. Retornar {status} + {ResponseDto}
```

**Convenciones:**
- Repositorios api: `{Entidad}Repository.{método}(params)`
- Repositorios frontend: `{Nombre}UseCase.execute(dto)` → `Http{Entidad}Repository.método(params)`
- Soft delete (api): `{Entidad}Repository.softDelete(id, userId)` — nunca DELETE físico
- Feedback frontend: `toast.success(...)`, `setError(campo, msg)`, `invalidateQuery([...])`
- Siempre referenciar `[RN-XXX]` en cada paso donde aplica una regla

---

## Paso 4 — Diagrama de Secuencia Mermaid

Genera el diagrama usando `sequenceDiagram`.

Participantes según tipo:

| Tipo | Participantes |
|------|--------------|
| `api` | Cliente/MFE · Controller · Service · Repository · PostgreSQL (· Firebase si aplica) |
| `frontend` | Usuario · Página/Componente · UseCase · HttpRepository · API Backend (· QueryClient si invalida caché) |

Reglas comunes:
- `->>` llamada síncrona, `-->>` respuesta, `-x` error
- `alt ... else ... end` para la bifurcación de error principal
- Solo participantes realmente involucrados en el flujo
- Conciso: pasos principales y bifurcación de error más importante

---

## Paso 5 — Flujos Alternativos

Tabla con todos los caminos de error y edge cases:

| Condición | Respuesta / Feedback | Regla |
|-----------|---------------------|-------|
| JWT inválido o expirado | 401 Unauthorized · (frontend: interceptor refresh → retry) | RN-GLO-005 |
| Recurso no encontrado | 404 Not Found · (frontend: toast warn "No encontrado") | — |
| Conflicto / duplicado | 409 Conflict · (frontend: error inline en campo) | RN-XXX |
| Permiso insuficiente | 403 Forbidden | RN-XXX |
| Validación client-side *(frontend)* | Error inline RHF en el campo | RN-XXX |
| Estado vacío *(frontend)* | Mensaje "No hay elementos" + CTA | — |

---

## Paso 6 — Ejemplos de Request / Response

### Request (si aplica)

`SPEC_TYPE=api` → bloque JSON con valores realistas:
```json
{ "campo": "valor de ejemplo" }
```

`SPEC_TYPE=frontend` → shape TypeScript con tipos (camelCase):
```typescript
{ campo: tipo; campoOpcional?: tipo; }
```

### Response exitosa

`SPEC_TYPE=api` → bloque JSON completo con todos los campos del ResponseDto:
```json
{ "id": "uuid", "campo": "valor", "createdAt": "2026-04-06T00:00:00Z" }
```
- Nunca incluir campos sensibles (`isDeleted`, `deletedAt`, tokens, hashes)

`SPEC_TYPE=frontend` → shape TypeScript del DTO que el UseCase retorna:
```typescript
{ id: string; campo: tipo; createdAt: string; }
```
- Incluir los status codes que el UC maneja: `201`, `200`, `204`, `400`, `409`, `404`

### Mockup *(frontend: incluir siempre; api: solo si el UC tiene representación visual)*

Wireframe ASCII del componente o pantalla:

```
┌── {Título del Dialog / Sección} ─────────────────────────┐
│  Campo A *                    Campo B *                   │
│  [valor de ejemplo           ] [VALOR_EJEMPLO           ] │
│                                                           │
│  (condicional: qué aparece y cuándo)                      │
│                                                           │
│                              [Cancelar]  [Guardar]        │
└───────────────────────────────────────────────────────────┘
```

Para acciones destructivas:
```
┌── Confirmar eliminación ─────┐
│  ¿Eliminar "{nombre}"?       │
│                              │
│         [Cancelar] [Eliminar]│
└──────────────────────────────┘
```

---

## Paso 7 — Pie del UC

```markdown
**Reglas aplicadas:** RN-XXX-001, RN-XXX-002, RN-GLO-005, ...

---
```

Lista solo las reglas efectivamente usadas en el flujo.

---

## Paso 8 — Actualizar Resumen de Endpoints *(solo si `SPEC_TYPE=api`)*

Agrega una fila a la tabla **"Resumen de Endpoints"** al final del spec.md:

```markdown
| {UC-ID} | `/{ruta}` | {MÉTODO} | {status codes} | {RN clave 1}, {RN clave 2} |
```

---

## Paso 9 — Evaluar impacto en diagramas de arquitectura

Hazlo **solo si aplica**; no tocar diagramas que no cambian.

### 9a — Diagrama de Componentes (`claude_workspace/architecture/component-diagram.md`)

Actualizar si el UC introduce un nuevo Service, Port, Adapter secundario o Controller no listado aún.

### 9b — Diagrama de Contenedores (`claude_workspace/architecture/container-diagram.md`)

Actualizar si el UC introduce un nuevo sistema externo, unidad desplegable, tecnología de almacenamiento o actor.

### 9c — Resumen

Indicar brevemente qué diagramas se actualizaron y por qué, o por qué no fue necesario.

---

## Paso 10 — Escribir en el archivo

**`SPEC_TYPE=api`:** insertar en `claude_workspace/architecture/feature_spec/{módulo}/spec.md`
- Antes de `## Resumen de Endpoints`, después del último UC existente
- Insertar nuevas RN-* en la tabla del módulo respetando el orden numérico
- Actualizar la tabla de Resumen de Endpoints
- Aplicar cambios de diagramas del Paso 9

**`SPEC_TYPE=frontend`:** el destino depende del dominio
- Si es el primero del dominio → crear `claude_workspace/architecture/feature_spec/{módulo}/{slug}.md`
  (`{slug}` refleja el concepto: `create_organization.md`, `organizations_list.md`)
- Si es variante de un spec existente → añadir al archivo existente
- Actualizar `claude_workspace/TODO.md` con la nueva fila: `| {UC-ID} | {Nombre} | 🔲 | — |`

---

## Paso 11 — Sincronizar project.manifest.yaml

Leer `claude_workspace/project.manifest.yaml`. Localizar el módulo por `uc_prefix` o `id`.

**Si el servicio YA existe** en `modules[x].services[]` → actualizar `method` y `path` si cambiaron.

**Si el servicio NO existe** → agregar:

```yaml
- id: {snake_case del nombre del UC}   # UC-ORG-11: Archivar → archive_organization
  name: "{NombreService}"
  uc: "{UC-ID}"
  method: "{HTTP_METHOD}"
  path: "{ruta}"
  status: planned
```

Después de actualizar el manifest → ejecutar `/c4-update-diagrams component`.

---

## Formato Completo del UC (template de salida)

```markdown
### {UC-ID}: {Nombre del Caso de Uso}

**Actor:** {Actor}
**Pantalla:** `{Componente}.tsx`   ← omitir si SPEC_TYPE=api

**Precondiciones:**
- {Precondición 1}
- {Precondición 2 si aplica}

**{MÉTODO}** `/{ruta}`

**Flujo Principal:**

\`\`\`
{MÉTODO} /{ruta}  { body }
  Header: Authorization: Bearer <JWT>
  1. Paso 1  [RN-XXX]
  2. {Entidad}Repository.método(params)
     2a. Condición → resultado  [RN-XXX]
     2b. Condición → resultado
  3. Retornar {status} + {ResponseDto}
\`\`\`

**Diagrama de Secuencia:**

\`\`\`mermaid
sequenceDiagram
    ...
\`\`\`

**Request:**
\`\`\`json  ← api  /  \`\`\`typescript  ← frontend
{ ... }
\`\`\`

**Response {status}:**
\`\`\`json  ← api  /  \`\`\`typescript  ← frontend
{ ... }
\`\`\`

**Mockup:**   ← omitir si SPEC_TYPE=api y no hay UI
\`\`\`
{wireframe ASCII}
\`\`\`

**Flujos Alternativos:**

| Condición | Respuesta / Feedback | Regla |
|-----------|---------------------|-------|
| ... | ... | ... |

**Reglas aplicadas:** RN-XXX-001, RN-GLO-005, ...

---
```

---

## Checklist de Calidad

- [ ] UC-ID es el siguiente disponible y no duplica ningún existente
- [ ] Fuente de verdad leída: DDL (`api`) o contrato API / spec equivalente (`frontend`)
- [ ] Cada campo del flujo existe en la fuente de verdad (no inventar tablas/endpoints)
- [ ] Si el UC requiere campo nuevo (`api`): ddl.sql + migración + capas propagadas (Paso 2b)
- [ ] Cada paso del flujo referencia la RN-* correspondiente
- [ ] Flujo es trazable de extremo a extremo (entrada → lógica → respuesta/feedback)
- [ ] Diagrama mermaid coherente con el flujo numerado
- [ ] Flujos alternativos cubren todos los caminos de error del flujo principal
- [ ] Ejemplos de request/response usan el formato correcto (JSON para api, TypeScript para frontend)
- [ ] Mockup incluido si el UC tiene representación visual
- [ ] Response no expone campos sensibles (`isDeleted`, `deletedAt`, tokens)
- [ ] Las nuevas RN-* fueron agregadas a la tabla de Reglas de Negocio del módulo
- [ ] Resumen de Endpoints actualizado (`api`)
- [ ] TODO.md actualizado (`frontend`)
- [ ] Se evaluó impacto en component-diagram.md y container-diagram.md (Paso 9)
- [ ] `project.manifest.yaml` actualizado (Paso 11)
- [ ] `/c4-update-diagrams component` ejecutado si se agregó un servicio nuevo
