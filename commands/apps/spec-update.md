# Modificar Especificación de Caso de Uso Existente

Aplica un cambio quirúrgico al caso de uso **"$ARGUMENTS"** en el spec del módulo correspondiente.

El argumento tiene el formato: `{módulo} {UC-ID}: {descripción breve del cambio}`
Ejemplos:
- `01-auth UC-AUTH-01: agregar campo device_id al refresh token request`
- `02-organizations UC-ORG-03: cambiar validación de code a no editable post-creación`
- `03-rbac UC-RBAC-02: agregar flujo alternativo cuando usuario ya tiene el rol`
- `04-menu UC-MENU-01: incluir moduleCode en el response de cada ítem`

---

## Paso 0 — Leer el UC actual completo

Leer `SPEC_TYPE` de `claude_workspace/.env`. Si no está definida → asumir `api`.

Antes de modificar nada, lee:

1. **El UC a modificar** en `claude_workspace/architecture/feature_spec/{módulo}/spec.md`
   - Flujo principal, flujos alternativos, reglas aplicadas y ejemplo de datos actual
   - RN-* que ya citan este UC

2. **Fuente de verdad del schema:**
   - `SPEC_TYPE=api` → `claude_workspace/architecture/ddl.sql` — solo las tablas involucradas
   - `SPEC_TYPE=frontend` → `claude_workspace/architecture/api_contracts/` (si existe), o spec del módulo API equivalente — endpoint, campos en camelCase, status codes

3. **Archivos de código afectados** (si ya están implementados):
   - Identificar cuáles tocar según el Path Registry de `rules/architecture.md`

> **Regla de oro:** el mínimo cambio que satisface el requisito. No reescribir todo el UC; editar solo las secciones que cambian.

---

## Paso 1 — Clasificar el tipo de cambio

Determina en qué categoría cae el cambio pedido (puede ser más de una):

| Tipo | Descripción | Secciones del UC afectadas |
|------|-------------|---------------------------|
| **A — Nuevo campo en request** | Se agrega un parámetro al body o query | Flujo Principal, Request JSON, tal vez RN nueva |
| **B — Nuevo campo en response** | Se agrega un campo al DTO de respuesta | Flujo Principal (paso de retorno), Response JSON |
| **C — Nueva condición / validación** | Se cambia o agrega una regla de negocio | Flujo Principal (paso afectado), Flujos Alternativos, RN-* |
| **D — Nuevo flujo alternativo** | Se añade un camino de error no documentado | Flujos Alternativos, tal vez Flujo Principal |
| **E — Cambio de regla existente** | Se modifica el comportamiento de una RN-* ya citada | Flujo Principal, RN-* (tabla de reglas del módulo) |
| **F — Campo nuevo en schema** | `api`: requiere columna nueva en `ddl.sql`. `frontend`: requiere campo nuevo en el contrato API — si aún no existe en el contrato, el cambio es fuera del scope del frontend spec (es un cambio de backend primero) | `api`: Paso 2b de `/spec-create` antes de continuar. `frontend`: verificar que el campo ya existe en el contrato antes de documentarlo |

---

## Paso 2 — Si el tipo es F: actualizar schema primero

**`SPEC_TYPE=api`** — si el cambio requiere una columna nueva en la base de datos, aplica el **Paso 2b del skill `/spec-create`** antes de continuar:

1. Agregar columna en `ddl.sql` (en el `CREATE TABLE` correspondiente)
2. Documentar nueva `MIGRACIÓN 00X` en `migrations.sql` (UP + DOWN)
3. Crear archivo TypeScript de migración
4. Actualizar TypeORM entity con `@Column()`
5. Propagar hacia domain entity → port → DTO → mapper → repository

**`SPEC_TYPE=frontend`** — si el campo nuevo aún no existe en el contrato API → el cambio está bloqueado hasta que el backend lo implemente. Documentar la dependencia en el spec con una nota:
```
> ⏳ Pendiente de backend: campo `{campo}` no disponible en el contrato API hasta {UC-API-ID}.
```
Si el campo ya existe en el contrato → no aplica Tipo F; tratarlo como Tipo A o B y continuar.

Una vez resuelto, continúa con Paso 3.

---

## Paso 3 — Modificar el UC en el spec.md

Edita **solo las secciones que cambian**. Guía por tipo:

### Tipo A — Nuevo campo en request / props de entrada

- **Flujo Principal:** agrega el campo en el bloque del body de ejemplo y en el paso de validación correspondiente (ej: "2. Validar que `device_id` sea UUID válido [RN-AUTH-0XX]")
- **Ejemplo de datos:**
  - `api` → Request JSON: agrega el campo con valor de ejemplo realista
  - `frontend` → Shape TypeScript: agrega el campo con su tipo en camelCase; si tiene validación Zod, documentar la capa `Zod` en la RN nueva
- **RN nueva** (si aplica): agrégala en la tabla de Reglas de Negocio del módulo

### Tipo B — Nuevo campo en response / estado de salida

- **Flujo Principal:** actualiza el paso de retorno para reflejar el nuevo campo (ej: "5. Retornar 200 + `AuthResponseDto` (incluye `deviceId`)")
- **Ejemplo de datos:**
  - `api` → Response JSON: agrega el campo con valor de ejemplo realista
  - `frontend` → Shape TypeScript: agrega el campo con su tipo en camelCase
- No exponer: `isDeleted`, `deletedAt`, `deletedUserId`, hashes, tokens en claro

### Tipo C — Nueva condición / validación

- **Flujo Principal:** agrega o modifica el paso donde se evalúa la condición, referenciando la RN-*:
  ```
  3. Verificar que {condición}  [RN-XXX-NEW]
     3a. Si no cumple → lanzar {XxxException}
  ```
- **Flujos Alternativos:** agrega la nueva fila en la tabla
- **RN nueva:** agrégala en la tabla de Reglas de Negocio del módulo si es una regla nueva

### Tipo D — Nuevo flujo alternativo

- **Flujos Alternativos:** agrega la fila con `Condición | HTTP Status | RN`
- **Flujo Principal:** si la condición se evalúa en un paso específico, agrega el sub-paso `Xa.`

### Tipo E — Cambio de regla existente

- **Tabla de Reglas de Negocio del módulo:** modifica la descripción de la RN-* afectada
- **Flujo Principal:** actualiza el paso que cita esa RN-*
- **Flujos Alternativos:** actualiza la fila si cambia el status o la condición

---

## Paso 4 — Actualizar el diagrama de secuencia (si aplica)

Actualiza el bloque `sequenceDiagram` **solo si cambia la interacción entre participantes**:

- **Actualizar:** si hay un nuevo actor, un nuevo paso de validación que genera un flujo alternativo visible, o una nueva llamada a un repositorio/adapter
- **No actualizar:** si el cambio es solo de datos (nuevo campo en request/response sin cambiar el flujo de control)

---

## Paso 5 — Trazar el impacto en código

Por cada tipo de cambio, identifica qué artefactos de implementación hay que modificar.
**No modifica el código aquí** — solo documenta el impacto para que `/spec-code` lo ejecute.

> Los artefactos del proyecto y sus responsabilidades están en el **Flujo de Implementación**
> de `rules/architecture.md` (ya en contexto). Usar esa tabla para determinar qué artefacto
> corresponde a cada tipo de cambio.

| Tipo de cambio | Artefactos típicamente impactados (según Flujo de Implementación) |
|----------------|------------------------------------------------------------------|
| Nuevo campo en input | Artefacto de entrada (DTO/Props/Schema) + use case/service + mapper si va al dominio |
| Nuevo campo en output | Artefacto de salida (ResponseDTO/State) + mapper/transformer |
| Nueva validación/condición | Use case/service + test del use case |
| Nueva regla en persistencia | Repositorio + método afectado |
| Campo nuevo en schema (tipo F) | Entidad de persistencia + entidad de dominio + port + artefactos input/output + repo (ya hecho en Paso 2) |

Escribe al final del UC una nota temporal con los artefactos a modificar; eliminarla una vez implementado.

---

## Paso 6 — Evaluar impacto en diagramas de arquitectura (si aplica)

Aplica el mismo criterio que el Paso 9 del skill `/spec-create`:

- **`component-diagram.md`:** solo si hay un nuevo Service, Port, Adapter o Controller
- **`container-diagram.md`:** solo si hay un nuevo sistema externo, actor o tecnología de almacenamiento

En la mayoría de cambios de tipo A-E **no se requiere actualizar los diagramas**. Justifica brevemente si no aplica.

---

## Paso 7 — Actualizar el pie del UC y los registros del módulo

Después de las ediciones:

1. **"Reglas aplicadas"** al pie del UC → agrega las nuevas RN-* usadas (o elimina las que ya no aplican)
2. **Tabla de Reglas de Negocio del módulo** → agrega o modifica la RN-* correspondiente, en orden numérico
3. **Registro del UC:**
   - `SPEC_TYPE=api` → Tabla de Resumen de Endpoints: actualizar si cambió method, ruta o status codes
   - `SPEC_TYPE=frontend` → `claude_workspace/TODO.md`: actualizar el estado de la fila si cambió

---

## Checklist de Calidad

Antes de confirmar los cambios:

- [ ] Leí el UC completo y la fuente de verdad antes de editarlo (Paso 0)
- [ ] Cambié **solo** las secciones afectadas — sin reescribir secciones que no cambian
- [ ] Si Tipo F (`api`): `ddl.sql` + `migrations.sql` + `.ts` + capas propagadas
- [ ] Si Tipo F (`frontend`): campo existe en el contrato API antes de documentarlo (o bloqueado con nota)
- [ ] El flujo principal sigue siendo coherente (numeración, referencias a RN-*)
- [ ] El diagrama de secuencia fue actualizado (o justificado que no aplica)
- [ ] Los flujos alternativos cubren la nueva condición (si hubo cambio tipo C o D)
- [ ] El ejemplo de datos no expone campos sensibles
- [ ] "Reglas aplicadas" al pie del UC está actualizado
- [ ] La tabla de Reglas de Negocio del módulo fue actualizada (si hay RN nueva o modificada)
- [ ] `api`: Tabla de Resumen de Endpoints actualizada si cambió method, ruta o status
- [ ] `frontend`: TODO.md actualizado si cambió el estado del UC
- [ ] Se evaluó impacto en `component-diagram.md` — actualizado o justificado
- [ ] Se evaluó impacto en `container-diagram.md` — actualizado o justificado
- [ ] Los archivos de código impactados fueron identificados (Paso 5) para implementación posterior

---

## Tipos de cambio que NO entran en este skill

| Situación | Skill correcto |
|-----------|----------------|
| Crear un UC nuevo de cero | `/spec-create` |
| Implementar el código de un UC ya especificado | `/new-module` |
| Agregar una tabla completa nueva | `/spec-create` + Paso 2b |
| Cambiar el nombre/ruta de un endpoint (breaking change) | Analizar impacto con el usuario antes de proceder |
