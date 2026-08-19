# Agregar Nueva Regla de Negocio

Agrega la regla de negocio **"$ARGUMENTS"** al spec del módulo correspondiente y, si es global, también a `business-rules.md`.

El argumento tiene el formato: `RN-{MÓDULO}-{NNN}` o `RN-{MÓDULO}-{NNN}: {descripción breve}`
Ejemplos:
- `RN-AUTH-022`
- `RN-ORG-016: validar unicidad de tax_id entre organizaciones activas`
- `RN-GLO-013: rate limiting por IP en endpoints públicos`
- `RN-RBAC-014: un usuario no puede asignarse roles a sí mismo`

---

## Paso 0 — Preparar contexto

Antes de escribir nada, lee:

1. **Spec del módulo** → `claude_workspace/architecture/feature_spec/{módulo}/spec.md`
   - Lee la tabla `## Reglas de Negocio` completa para entender el contexto y evitar duplicados
   - Identifica el **último número** usado en el bloque `RN-{MÓDULO}-*` — el nuevo número debe ser el siguiente disponible
   - Si el argumento ya incluye número, verificar que no esté ocupado; si lo está, asignar el siguiente libre

2. **`business-rules.md`** → `claude_workspace/architecture/business-rules.md`
   - Solo necesario si el prefijo es `RN-GLO-*` o `RN-AUD-*`

---

## Paso 1 — Determinar el módulo destino

Mapeo de prefijo → archivo de spec:

| Prefijo | Módulo | Archivo |
|---------|--------|---------|
| `RN-PROD` | Products & Modules | `claude_workspace/architecture/feature_spec/00-products-modules/spec.md` |
| `RN-AUTH` | Auth & Identity | `claude_workspace/architecture/feature_spec/01-auth/spec.md` |
| `RN-ORG`, `RN-BRN`, `RN-TNT` | Organizations & Brands | `claude_workspace/architecture/feature_spec/02-organizations/spec.md` |
| `RN-RBAC` | RBAC — Roles & Permissions | `claude_workspace/architecture/feature_spec/03-rbac/spec.md` |
| `RN-MENU` | Menu Orchestration | `claude_workspace/architecture/feature_spec/04-menu/spec.md` |
| `RN-GLO`, `RN-AUD` | Global | `claude_workspace/architecture/business-rules.md` **Y** el spec más relevante si aplica |

---

## Paso 2 — Completar los campos de la regla

Si el argumento solo da el ID (sin descripción), inferir el contenido a partir del nombre del ID y el contexto del módulo. De lo contrario, usar la descripción proporcionada como punto de partida.

Rellena los **4 campos** de la tabla:

### Campo 1: ID
```
**RN-{MÓDULO}-{NNN}**
```
Agregar marcador si corresponde:
- `[OPC]` — comportamiento opcional, activado por configuración
- `[FUT]` — requiere tabla o estructura de BD aún no implementada

### Campo 2: Descripción
- Una o dos oraciones. Responde a: **¿qué está prohibido o permitido, y bajo qué condición?**
- Incluir el comportamiento esperado cuando la regla se viola (ej: `→ 409 Conflict`, `→ 403 Forbidden`)
- Referenciar otras RN-* si la regla depende de ellas (ej: `[RN-AUTH-015]`)
- Evitar lenguaje técnico de implementación en este campo

### Campo 3: Capa de Validación
Elegir la capa más temprana donde se puede validar:

| Capa | Cuándo usarla |
|------|---------------|
| `DTO` | Validación de formato/tipo antes de llegar al service |
| `Domain` | Invariante del dominio (ej: estado inválido de la entidad) |
| `Servicio` | Lógica de negocio que requiere consultar otros datos |
| `Repo` | Constraint de unicidad o integridad que solo el repo conoce |
| `Guard` | Acceso/permisos (JWT, roles, organización) |
| `DB` | Constraint a nivel de base de datos (UNIQUE, FK, CHECK) |
| `Adapter` | Validación en adapter externo (Firebase, API tercero) |
| `Configuración / Ops` | Regla de infraestructura o entorno, no de código |

### Campo 4: Implementación
Describe **cómo** se implementa, con referencias a clases/métodos reales del proyecto:
```
NombreService: método() → XxxRepository.findBy...() → si condición → throw XxxException
```
- Usar nombres de clases y métodos en el estilo del proyecto (camelCase)
- Si requiere un método nuevo que no existe aún, indicarlo con `→ (nuevo)`
- Si es `[FUT]`, indicar la tabla futura requerida

---

## Paso 3 — Insertar en spec.md del módulo

Ubica la sección `## Reglas de Negocio` → subtabla del módulo correspondiente (ej: `### AUTH — Auth & Identity`).

Inserta la nueva fila **en orden numérico** dentro del bloque. Si el número ya tiene una posición natural (ej: RN-AUTH-022 va después de RN-AUTH-021), insertar ahí. Si hay saltos de numeración, insertar al final del bloque del módulo.

Formato de la fila:
```markdown
| **RN-{MÓDULO}-{NNN}** | {Descripción} | {Capa} | {Implementación} |
```

Si la descripción es larga (>120 caracteres), es válido usar la fila de todas formas — el Markdown la renderiza correctamente.

---

## Paso 4 — Insertar en `business-rules.md` (solo para RN-GLO-* y RN-AUD-*)

Si el prefijo es `RN-GLO-*`:
- Localiza la sección `## GLO — Reglas Globales`
- Inserta la fila en orden numérico dentro de la tabla `| ID | Descripción | Aplica a |`
- **Nota:** las reglas GLO tienen 3 columnas (`ID`, `Descripción`, `Aplica a`), no 4

Si el prefijo es `RN-AUD-*`:
- Localiza la sección `## AUD — Auditoría`
- Inserta la fila en orden numérico dentro de la tabla de 4 columnas

Para cualquier otro prefijo: **no modificar `business-rules.md`**. Las reglas de módulo viven únicamente en su spec.md.

---

## Paso 5 — Actualizar la tabla de estado en `business-rules.md` (solo RN-GLO-*)

Al final de `business-rules.md` hay una tabla `## Estado de Implementación — Reglas Globales`. Si se agregó una `RN-GLO-*`, añadir la fila:

```markdown
| RN-GLO-{NNN} | {descripción corta} | ⏳ Pendiente |
```

---

## Paso 6 — Verificar si la regla requiere un UC nuevo o actualización

Evalúa si la nueva regla:

1. **Solo documenta algo ya implementado** → no requiere cambios de código
2. **Define un comportamiento no implementado** → indicar qué UC / service lo implementará (referencia para futura tarea)
3. **Cambia un UC existente** → sugerir usar `/spec-validate {módulo} {UC-ID}: aplicar {RN-ID}`

---

## Checklist de Calidad

Antes de confirmar:

- [ ] El ID de la regla es el siguiente número disponible en el bloque del módulo (sin duplicar)
- [ ] Los 4 campos están completos (ID, Descripción, Capa, Implementación)
- [ ] La descripción responde "¿qué restricción impone esta regla?" en lenguaje de negocio
- [ ] La capa de validación es la más temprana posible
- [ ] La implementación referencia clases/métodos reales del proyecto (o indica `→ (nuevo)`)
- [ ] Fila insertada en orden numérico correcto dentro del bloque
- [ ] Si es RN-GLO-* o RN-AUD-*: también insertada en `business-rules.md`
- [ ] Si es RN-GLO-*: fila agregada a la tabla de estado de implementación
- [ ] Si la regla implica un cambio de comportamiento en un UC existente: se sugirió `/spec-validate`

---

## Referencia rápida de prefijos y archivos

```
RN-GLO-*  → business-rules.md  (sección GLO)
RN-AUD-*  → business-rules.md  (sección AUD)
RN-PROD-* → feature_spec/00-products-modules/spec.md
RN-AUTH-* → feature_spec/01-auth/spec.md
RN-ORG-*  → feature_spec/02-organizations/spec.md
RN-BRN-*  → feature_spec/02-organizations/spec.md
RN-TNT-*  → feature_spec/02-organizations/spec.md
RN-RBAC-* → feature_spec/03-rbac/spec.md
RN-MENU-* → feature_spec/04-menu/spec.md
```
