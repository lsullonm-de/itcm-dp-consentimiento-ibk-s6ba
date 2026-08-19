# Init Docs — Generar Documentación desde el Manifest (API / Backend)

Genera toda la estructura `claude_workspace/` a partir de `project.manifest.yaml`
para proyectos **backend/API** (NestJS, Express, FastAPI, etc.).
Paso previo y obligatorio antes de `/init-project-api`.

> **Cuándo usar:** una sola vez, al iniciar un proyecto API nuevo, después de llenar
> `project.manifest.yaml`. Si los docs ya existen, usar `/c4-update-diagrams` en su lugar.
>
> Para proyectos **frontend** (React / Vue / Next.js) usar `/init-docs-frontend` en su lugar.

```
project.manifest.yaml  ──►  /init-docs  ──►  claude_workspace/ completo
                                               ↓
                                          /init-project-api  (código)
```

---

## Paso 0 — Leer y validar el manifest

```
Leer: claude_workspace/project.manifest.yaml
```

Verificar que las secciones mínimas requeridas existen:

| Sección | Requerida | Qué extraer |
|---------|-----------|-------------|
| `project` | ✅ | `name`, `slug`, `tagline`, `api_port`, `db_schema` |
| `stack[]` | ✅ | lista con al menos `tech` y `version` |
| `actors[]` | ✅ | al menos un actor |
| `infrastructure[]` | ✅ | al menos API + BD |
| `architecture` | ✅ | `pattern`, `features.*`, `coverage_threshold` |
| `modules[]` | ⚠️ opcional | puede estar vacío al inicio |
| `constraints[]` | ⚠️ opcional | si vacío → usar los RN-GLO-* estándar |

Si falta alguna sección requerida → listar qué falta y detener sin crear archivos.

---

## Paso 1 — Detectar estado

Verificar si existe `claude_workspace/CLAUDE.md`:

| Estado | Acción |
|--------|--------|
| No existe | Crear todo (pasos 2–8) |
| Existe | Confirmar con el usuario antes de continuar. Si confirma → regenerar solo secciones centineladas via `/c4-update-diagrams`; no tocar archivos manuales |

---

## Paso 2 — Plan

Mostrar al usuario el plan antes de crear archivos:

```
## Plan /init-docs — {project.name}

### Archivos a crear
.claude/
├── CLAUDE.md                              (desde manifest)
claude_workspace/
├── TODO.md                                (desde manifest.modules)
├── project.manifest.yaml                  (ya existe — no se toca)
│
├── architecture/
│   ├── context-diagram.md                 (desde manifest.actors + external_systems)
│   ├── container-diagram.md               (desde manifest.infrastructure + modules)
│   ├── component-diagram.md               (desde manifest.modules + services)
│   ├── business-rules.md                  (RN-GLO-* estándar + índice de módulos)
│   ├── ddl.sql                            (scaffold vacío con schema declarado)
│   ├── migrations.sql                     (scaffold vacío)
│   └── feature_spec/
│       {por cada módulo en modules[]}
│       └── {spec_path}/spec.md            (scaffold mínimo — sin UCs aún)
│
├── rules/
│   ├── README.md, architecture.md, conventions.md, typescript.md
│   ├── documentation.md, solid.md, patterns.md, testing.md
│   ├── logging.md, error-handling.md, configuration.md, security.md
│   ├── performance.md, tooling.md, git-cicd.md, general.md
│   └── (parametrizados con el stack del manifest)
│
└── guides/
    ├── development.md                     (variables de entorno del manifest)
    ├── testing.md                         (estrategia estándar)
    └── deployment-{platform}.md           (según manifest.deployment.platform)


¿Procedo? (s/n)
```

Solo continuar si el usuario confirma.

---

## Paso 3 — CLAUDE.md

Generar `CLAUDE.md` con la siguiente estructura. Las secciones marcadas con
`<!-- generated:* -->` derivan del manifest; las demás son texto fijo estándar.

```markdown
# {project.name}

> **Context:** {project.tagline}

---

## 📋 Documentación

### Arquitectura
- [🗂️ DDL Canónico](./claude_workspace/architecture/ddl.sql) — fuente de verdad del schema
- [📦 Contenedores](./claude_workspace/architecture/container-diagram.md) — C4 L2
- [🏗️ Componentes](./claude_workspace/architecture/component-diagram.md) — C4 L3
- [⚖️ Reglas de Negocio](./claude_workspace/architecture/business-rules.md) — RN-GLO-* y RN-AUD-*
- [🗄️ Migraciones](./claude_workspace/architecture/migrations.sql) — historial SQL (UP/DOWN)

### Especificaciones por Módulo
<!-- generated:spec-links — NO EDITAR, regenerado por /c4-update-diagrams -->
{por cada módulo en modules[] con status != deprecated}
- [{icon} {name}](./claude_workspace/architecture/{spec_path})
<!-- /generated:spec-links -->

### Guías
- [👨‍💻 Desarrollo](./claude_workspace/guides/development.md)
- [🧪 Testing](./claude_workspace/guides/testing.md)
{si deployment.platform = gcp}
- [☁️ Despliegue GCP](./claude_workspace/guides/deployment-gcp.md)

### Reglas de Desarrollo (NestJS + TypeScript)
- [📋 Índice](./claude_workspace/rules/README.md) · [🏗️ Arquitectura](./claude_workspace/rules/architecture.md) · ...
(línea estándar con todos los links a rules/)

### Progreso
- [✅ TODO](./claude_workspace/TODO.md) — estado de implementación por módulo

---

## 🚀 Quick Start

<!-- generated:quick-start — NO EDITAR, regenerado por /c4-update-diagrams -->
{comandos de manifest.quick_start.commands}
<!-- /generated:quick-start -->

---

## 📦 Stack

<!-- generated:stack-table — NO EDITAR, regenerado por /c4-update-diagrams -->
| Tecnología | Versión | Propósito |
|------------|---------|-----------|
{por cada stack[]}
| {tech} | {version} | {purpose} |
<!-- /generated:stack-table -->

---

## 🔑 Reglas Críticas para Claude

> Reglas de negocio → business-rules.md y feature_spec/.
> Reglas técnicas → rules/.

### Constraints que NUNCA se pueden violar

<!-- generated:constraints-table — NO EDITAR, regenerado por /c4-update-diagrams -->
| Constraint | Detalle |
|-----------|---------|
{por cada constraints[]}
| **{name}** | {detail} |
<!-- /generated:constraints-table -->

### ❌ Qué nunca hacer

<!-- generated:never-do — NO EDITAR, regenerado por /c4-update-diagrams -->
{por cada never_do[]}
- ❌ {item}
<!-- /generated:never-do -->

---

### Informativo — Workflow de Skills

{diagramas Mermaid del flujo Spec→Impl→Quality — texto fijo estándar}

**Última actualización:** {fecha} · **Versión:** 1.0
```

---

## Paso 4 — Diagramas de arquitectura

Ejecutar la lógica de `/c4-update-diagrams all` para generar los tres diagramas
con sus centinelas. Ver ese skill para el detalle de cada sección.

Archivos generados:
- `architecture/context-diagram.md` — C4 L1 con actores y sistemas externos
- `architecture/container-diagram.md` — C4 L2 con infraestructura y módulos
- `architecture/component-diagram.md` — C4 L3 con servicios, ports, repos por módulo

---

## Paso 5 — business-rules.md

Generar con la estructura estándar:

```markdown
# Reglas de Negocio — Globales y Transversales

> Este archivo contiene únicamente las reglas globales y de auditoría.
> Las reglas específicas de cada módulo están en sus specs.

> | Módulo | Prefijo | Especificación |
> |--------|---------|----------------|
> {por cada módulo en modules[]}
> | {name} | {rn_prefix} | [{spec_path}](./feature_spec/{spec_path}/spec.md) |

---

## Convención de Nomenclatura
RN-{MÓDULO}-{NRO}
Módulos: {lista de rn_prefix del manifest} · GLO · AUD

---

## GLO — Reglas Globales

| ID | Descripción | Aplica a |
|----|-------------|----------|
| RN-GLO-001 | Todos los IDs son UUID v4 ... | Todas las entidades |
| RN-GLO-002 | created_at y updated_at gestionados por TypeORM ... | Todas las entidades |
| RN-GLO-003 | Nuevos registros con is_active = true e is_deleted = false | Todas las entidades |
{si architecture.features.pagination}
| RN-GLO-004 | Paginación: page (default 1) y limit (default 20, máx 100) | Endpoints de listado |
| RN-GLO-005 | Todos los endpoints requieren JWT válido (excepto @Public()) | Toda la API |
| RN-GLO-006 | No exponer datos sensibles en logs o responses | Toda la API |
{si architecture.features.soft_delete}
| RN-GLO-007 | Soft delete: is_deleted=true + deleted_at + deleted_user_id. Nunca DELETE físico | Todas las entidades |
| RN-GLO-008 | is_active vs is_deleted son independientes semánticamente | Entidades con is_active |
{si architecture.features.audit_fields}
| RN-GLO-009 | created_user_id = JWT.sub en creación. Seeds/migrations → NULL | Todas las entidades |
| RN-GLO-010 | updated_user_id = JWT.sub en cada UPDATE | Todas las entidades |
| RN-GLO-011 | Filtro is_deleted=false en todas las queries de listado/búsqueda | Todas las entidades |

---

## AUD — Auditoría [FUT]
{sección estándar con RN-AUD-001 y RN-AUD-002}

---

## Estado de Implementación — Reglas Globales
| Regla | Descripción corta | Estado |
|-------|-------------------|--------|
{tabla con todas las RN-GLO generadas, estado inicial: ⏳ Pendiente}
```

---

## Paso 6 — ddl.sql y migrations.sql

### `architecture/ddl.sql`

```sql
-- =============================================================================
-- DDL Canónico — {project.name}
-- Schema: {project.db_schema}
-- Fuente de verdad del schema de base de datos.
-- NUNCA modificar las tablas directamente — usar migrations.sql + migración TypeScript.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Tablas a definir según el dominio del proyecto.
-- Convención de auditoría obligatoria en cada tabla:
--
-- created_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
-- created_user_id UUID NULL,
-- updated_at      TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
-- updated_user_id UUID NULL,
-- is_deleted      BOOLEAN NOT NULL DEFAULT false,
-- deleted_at      TIMESTAMP WITH TIME ZONE NULL,
-- deleted_user_id UUID NULL
```

### `architecture/migrations.sql`

```sql
-- =============================================================================
-- Historial de Migraciones — {project.name}
-- =============================================================================
-- Formato por migración:
--
-- -- MIGRACIÓN 00N — Descripción breve
-- -- Fecha: YYYY-MM-DD
-- -- UC: UC-XXX-NN (caso de uso que motivó el cambio)
-- --
-- -- UP
-- ALTER TABLE ...;
-- --
-- -- DOWN
-- ALTER TABLE ...;
-- =============================================================================

-- (sin migraciones aún)
```

---

## Paso 7 — feature_spec/ scaffolds

Por cada módulo en `modules[]` con `status != deprecated`:

Crear `architecture/feature_spec/{spec_path}/spec.md` con:

```markdown
# {module.name}

> **Módulo:** {descripción breve derivada del tagline + nombre del módulo}
> **Schema DB:** `{project.db_schema}`
> **Prefijo reglas:** `{module.rn_prefix}`

---

## Reglas de Negocio

| ID | Descripción | Capa de Validación | Implementación |
|----|-------------|-------------------|----------------|
| **{rn_prefix}-001** | (pendiente de especificar) | — | — |

---

## Resumen de Endpoints

| UC-ID | Ruta | Método | Status codes | Reglas clave |
|-------|------|--------|--------------|-------------|
{por cada service en module.services[]}
| {uc} | `{path}` | {method} | — | — |

---

{los UCs se agregan con /spec-create}
```

---

## Paso 8 — TODO.md

```markdown
# TODO — Estado de Implementación

> **Última actualización:** {fecha}

---

{por cada módulo en modules[]}
## Módulo: {name} (`{spec_path}`)

| UC-ID | Nombre | Spec | Impl | Tests | Estado |
|-------|--------|------|------|-------|--------|
{por cada service en module.services[]}
| {uc} | {nombre derivado del service.id} | ⏳ | ⏳ | ⏳ | 📐 Pendiente spec |

---

## Leyenda

| Símbolo | Significado |
|---------|-------------|
| ✅ | Completado |
| ⏳ | Pendiente |
| 🚧 | En progreso |
| ❌ | Bloqueado |
| 📐 | Solo spec |
```

---

## Paso 9 — rules/

Copiar los archivos de la biblioteca de reglas estándar sin modificaciones.
Son templates agnósticos que solo usan el stack como referencia contextual;
no se parametrizan en el texto — el stack es implícito vía CLAUDE.md.

Archivos a crear:
`general.md`, `architecture.md`, `conventions.md`, `typescript.md`,
`documentation.md`, `solid.md`, `patterns.md`, `testing.md`,
`logging.md`, `error-handling.md`, `configuration.md`, `security.md`,
`performance.md`, `tooling.md`, `git-cicd.md`, `README.md`

> Si en el repo de templates no están disponibles → generar cada uno
> siguiendo las definiciones de las reglas técnicas del proyecto base.

---

## Paso 10 — guides/

### `guides/development.md`

Generar con:
- **Setup inicial:** comandos de `manifest.quick_start.commands`
- **Variables de entorno:** derivadas de `manifest.infrastructure[]` y `architecture.features`
- **Estructura de directorios:** estándar hexagonal según `architecture.pattern`
- **Troubleshooting:** sección vacía con marcador `<!-- agregar según surjan issues -->`

### `guides/testing.md`

Template estándar: pirámide (Unit 70% / Integration 20% / E2E 10%),
umbral `{architecture.coverage_threshold}%`, ejemplos Jest con el patrón AAA.

### `guides/deployment-{platform}.md` (si `deployment.platform` != null)

Template básico para la plataforma indicada:
- `gcp` → sección Cloud Run + Secret Manager + env vars
- `aws` → sección ECS/Lambda + Secrets Manager
- `azure` → sección Container Apps + Key Vault
- otro → template genérico Docker

---

## Paso 11 — commands/

Copiar todos los skills existentes del proyecto base al directorio `commands/`.
Estos son los archivos `.md` de cada skill del workflow:

`init-docs.md` (este), `init-project-api.md`, `spec-code.md`, `spec-code-validate.md`,
`spec-create.md`, `spec-validate.md`, `spec-validate.md`, `rules-create.md`,
`test-coverage.md`, `rules-check.md`, `sync-todo.md`, `c4-update-diagrams.md`,
`spec-pipeline.md`, `bulk-spec.md`, `bulk-implement-seq.md`,
`bulk-implement-par.md`, `bulk-quality.md`

---

## Paso 12 — Reporte final

```
## /init-docs completado — {project.name}

### Archivos generados

| Sección | Archivos | Estado |
|---------|----------|--------|
| CLAUDE.md | 1 | ✅ |
| Diagramas C4 | 3 (context, container, component) | ✅ |
| business-rules.md | 1 | ✅ |
| ddl.sql + migrations.sql | 2 | ✅ (scaffolds vacíos) |
| feature_spec/ | N specs (uno por módulo) | ✅ |
| TODO.md | 1 | ✅ |
| rules/ | 16 archivos | ✅ |
| guides/ | 2-3 archivos | ✅ |
| commands/ | 18 archivos | ✅ |

### Módulos registrados en el manifest: {N}
{lista con nombre y uc_prefix de cada módulo}

### Próximos pasos
1. Revisar y completar `architecture/ddl.sql` con las tablas del dominio
2. `/init-project-api`  →  scaffolding de código NestJS
3. `/spec-create UC-XXX-01`  →  especificar el primer caso de uso
```

---

## Qué NO hace este skill

| Responsabilidad | Skill correcto |
|----------------|---------------|
| Crear `src/` o cualquier archivo TypeScript | `/init-project-api` |
| Especificar UCs con flujos y reglas | `/spec-create` |
| Generar el DDL de las tablas | Manual (el arquitecto define el schema) |
| Actualizar docs cuando el manifest cambia | `/c4-update-diagrams` |
| Crear migraciones TypeScript | Manual + `npm run migration:generate` |
