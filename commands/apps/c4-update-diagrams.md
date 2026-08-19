# Actualizar Diagramas desde el Manifest

Regenera las secciones centineladas de los diagramas de arquitectura a partir de
`claude_workspace/project.manifest.yaml`. Solo sobreescribe el contenido entre marcadores
`<!-- generated:* -->` — el texto manual queda intacto.

**Argumento (opcional):** nombre del diagrama a actualizar.
- Sin argumento → actualiza **todos** los diagramas
- `context` → solo `architecture/context-diagram.md`
- `container` → solo `architecture/container-diagram.md`
- `component` → solo `architecture/component-diagram.md`
- `claude-md` → solo `CLAUDE.md` (stack, constraints, quick-start, never-do)
- `todo` → solo `claude_workspace/TODO.md`
- `all` → equivale a sin argumento

Ejemplos: `/c4-update-diagrams`, `/c4-update-diagrams container`, `/c4-update-diagrams component`

---

## Regla fundamental: centinelas de sección

Las secciones generadas están delimitadas por comentarios HTML:

```
<!-- generated:{KEY} — NO EDITAR, regenerado por /c4-update-diagrams -->
... contenido generado ...
<!-- /generated:{KEY} -->
```

**El skill SOLO modifica contenido entre estos marcadores.**
El texto fuera de los marcadores nunca se toca.

---

## Paso 0 — Leer el manifest

```
Leer: claude_workspace/project.manifest.yaml
```

Parsear y registrar mentalmente:
- `project.*`
- `stack[]`
- `actors[]`
- `external_systems[]`
- `infrastructure[]`
- `modules[]` (con sus `services[]`, `tables[]`, `entities[]`, `ports_out[]`)
- `constraints[]`
- `never_do[]`
- `quick_start.*`

Si el archivo no existe → detener y pedir al usuario que lo cree o ejecute `/init-project-api` o `/init-project-frontend`.

---

## Paso 1 — context-diagram.md

**Sección centinelada:** `<!-- generated:context-diagram -->`

**Qué regenerar:** el diagrama Mermaid C4 L1 completo basado en:
- `actors[]` → nodos de actores externos al sistema
- `external_systems[]` → sistemas externos (Firebase, etc.)
- `project.name` → nombre del sistema central
- `infrastructure[]` → NO aparece aquí (es L2); solo el sistema como caja negra

**Plantilla de salida:**

```mermaid
graph TB

    %% ── Actores ──────────────────────────────────────────────────
    {POR CADA actor}
    ACTOR_{id}(["{icon} {name}\n{description}\n<i>{client}</i>"])

    %% ── Sistema central ──────────────────────────────────────────
    subgraph system["{icon} {project.name}"]
        API["🚀 {project.name}\nAPI REST · NestJS\nPort {api_port}"]
    end

    %% ── Sistemas externos ─────────────────────────────────────────
    {POR CADA external_system}
    EXT_{id}["{icon} {name}\n{purpose}"]

    %% ── Conexiones ────────────────────────────────────────────────
    {POR CADA actor}
    ACTOR_{id} -->|"HTTPS REST + JWT\n{rutas de los módulos activos}"| system

    {POR CADA external_system}
    system -->|"{protocol}"| EXT_{id}
```

Si `external_systems` está vacío → omitir esa sección del diagrama.

---

## Paso 2 — container-diagram.md

**Secciones centineladas:**
- `<!-- generated:container-mermaid -->` — diagrama Mermaid principal
- `<!-- generated:containers-table -->` — tabla de contenedores
- `<!-- generated:tables-by-module -->` — tabla de tablas por módulo
- `<!-- generated:docker-compose -->` — snippet de docker-compose
- `<!-- generated:env-vars -->` — variables de entorno
- `<!-- generated:communication-table -->` — tabla de comunicación

**Qué regenerar por sección:**

### `container-mermaid`
Derivar de `actors[]` + `infrastructure[]` + `modules[]`:

```mermaid
graph TB

    %% ── Actores ──────────────────────────────────────────────────
    {POR CADA actor}
    {ACTOR_ID}(["{icon} {name}\n{description}\n<i>{client}</i>"])

    %% ── Sistema ──────────────────────────────────────────────────
    subgraph system["{project.name}  [Docker / Cloud]"]

        %% -- API
        subgraph api["{api.icon} {api.name}  :{api.port}"]
            direction TB
            {POR CADA módulo activo}
            MOD_{id}["{icon} {name}\n{lista de servicios implementados}"]
        end

        %% -- Datos
        subgraph store["🗄️ Almacenamiento"]
            {POR CADA infrastructure donde id != api}
            {INFRA_ID}[("{icon} {name}\n:{port}\n{tech}")]
        end

    end

    %% ── Conexiones ───────────────────────────────────────────────
    {actores → api con protocolo y rutas}
    {api → stores con protocolo}

    %% ── Estilos ──────────────────────────────────────────────────
    style api    fill:#dbeafe,stroke:#2563eb,stroke-width:2px
    style system fill:#f8fafc,stroke:#64748b
    style store  fill:#fffbeb,stroke:#b45309
```

### `containers-table`
```markdown
| Contenedor | Tecnología | Puerto | Responsabilidad |
|-----------|------------|--------|----------------|
{POR CADA infrastructure}
| **{name}** | {tech} | {port} | {purpose} |
```

### `tables-by-module`
```markdown
| Módulo | Tablas |
|--------|--------|
{POR CADA módulo con status != deprecated}
| {name} | {tables unidas con backticks y comas} |
```

### `docker-compose`
Generar snippet para el primer `infrastructure` con `id != api` (la BD):
```yaml
services:
  {infra.id}:
    image: postgres:{version_major}
    ports: ["{infra.port}:{infra.port}"]
    environment:
      POSTGRES_{key}: {value}
```

### `env-vars`
Variables derivadas de `infrastructure[]` + `architecture.features`:
```bash
# Base de Datos
DB_HOST=localhost
DB_PORT={postgres.port}
DB_NAME={postgres.db_name}
DB_USERNAME={postgres.db_user}
DB_PASSWORD=

# Auth (si architecture.features.auth = true)
JWT_SECRET=
JWT_EXPIRES_IN=15m
```

### `communication-table`
```markdown
| Origen | Destino | Protocolo | Puerto | Autenticación |
|--------|---------|-----------|--------|---------------|
{POR CADA actor}
| {actor.name} | {project.name} API | HTTPS REST | {api.port} | Bearer JWT |
{POR CADA infrastructure donde id != api}
| {project.name} API | {infra.name} | PG Protocol | {infra.port} | User / Password |
```

---

## Paso 3 — component-diagram.md

**Secciones centineladas:**
- `<!-- generated:component-mermaid -->` — diagrama Mermaid de servicios y puertos
- `<!-- generated:modules-mermaid -->` — diagrama de módulos NestJS
- `<!-- generated:module-detail:{module_id} -->` — tabla de componentes por módulo
- `<!-- generated:di-binding:{module_id} -->` — ejemplo de DI del módulo

### `component-mermaid`

```mermaid
graph TB
    subgraph "Infrastructure — Primary Adapters"
        {POR CADA módulo activo}
        {MOD_ID}_CTRL[{controller}]
        GUARDS[Guards\nJwtAuthGuard]
    end

    subgraph "Application Layer"
        {POR CADA módulo activo}
        {MOD_ID}_SVC[{name} Services\n{lista de services.name separados por \\n}]
        {MOD_ID}_PORTS[{name} Ports\n{lista de ports_out.name separados por \\n}]
    end

    subgraph "Domain Layer"
        {POR CADA módulo activo, POR CADA entity}
        DOM_{entity.name}[{entity.name} Entity]
    end

    subgraph "Infrastructure — Secondary Adapters"
        {POR CADA módulo activo, POR CADA ports_out}
        REPO_{id}[{ports_out.impl}]
        DB[(PostgreSQL)]
    end

    {conexiones ctrl → guards → svc → ports → repos → db}
    {ports -.impl.-> repos}
```

### `modules-mermaid`

```mermaid
graph TD
    APP[AppModule]

    {POR CADA módulo}
    APP --> {MOD_ID}_MOD[{nest_module}]
    APP --> DB_MOD[DatabaseModule]
    APP --> CONFIG_MOD[ConfigModule]

    {POR CADA módulo}
    {MOD_ID}_MOD --> DB_MOD

    {POR CADA módulo}
    subgraph {nest_module}
        {MOD_ID}_C[{controller}]
        {POR CADA service}
        {SVC_ID}[{service.name}]
    end
```

### `module-detail:{module_id}`

Para cada módulo, tabla de 4 secciones (Primary Adapter / Application Layer / Domain / Secondary Adapters):

```markdown
### Primary Adapter
| Componente | Archivo | Responsabilidad |
|------------|---------|-----------------|
| `{controller}` | `{module_id}/{module_id}.controller.ts` | Routes: {métodos HTTP de los services} |

### Application Layer
| Componente | Archivo | Responsabilidad |
|------------|---------|-----------------|
{POR CADA service implementado}
| `{service.name}` | `{module_id}/services/{service_file}.service.ts` | {service.uc} |
{POR CADA port_out}
| `{port.name}` | `{module_id}/ports/output/{port_token_lower}.port.ts` | Interface repo {entity} |
{DTOs y mappers derivados de los services}
| `{Module}RequestDto` | `{module_id}/dtos/...` | Payload de entrada |
| `{Module}ResponseDto` | `{module_id}/dtos/...` | Respuesta mapeada |

### Domain Layer
| Componente | Archivo | Responsabilidad |
|------------|---------|-----------------|
{POR CADA entity}
| `{entity.name}` | `domain/entities/{entity_file}.ts` | Entidad {entity.name} |

### Secondary Adapters
| Componente | Archivo | Responsabilidad |
|------------|---------|-----------------|
{POR CADA port_out}
| `{port.impl}` | `persistence/repositories/typeorm-{entity}.repository.ts` | CRUD {entity} |
| `{Module}Entity` | `persistence/entities/{entity}.typeorm-entity.ts` | TypeORM entity |
```

### `di-binding:{module_id}`

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([{entity}Entity{, ...}])],
  controllers: [{controller}],
  providers: [
    {POR CADA service implementado}
    {service.name},
    {POR CADA port_out}
    { provide: '{port.token}', useClass: {port.impl} },
  ],
})
export class {nest_module} {}
```

---

## Paso 4 — CLAUDE.md

**Secciones centineladas:**
- `<!-- generated:stack-table -->` — tabla de stack
- `<!-- generated:constraints-table -->` — tabla de constraints
- `<!-- generated:never-do -->` — lista de "qué nunca hacer"
- `<!-- generated:spec-links -->` — links a specs de módulos
- `<!-- generated:quick-start -->` — comandos de quick start

### `stack-table`
```markdown
| Tecnología | Versión | Propósito |
|------------|---------|-----------|
{POR CADA stack[]}
| {tech} | {version} | {purpose} |
```

### `constraints-table`
```markdown
| Constraint | Detalle |
|-----------|---------|
{POR CADA constraints[]}
| **{name}** | {detail} |
```

### `never-do`
```markdown
{POR CADA never_do[]}
- ❌ {item}
```

### `spec-links`
```markdown
{POR CADA módulo activo}
- [{icon} {name}](./claude_workspace/architecture/{spec_path})
```

### `quick-start`
```bash
{POR CADA quick_start.commands[]}
{si tiene comment}: {cmd}          # {comment}
{si no tiene comment}: {cmd}
# API: {quick_start.urls.api}  |  Swagger: {quick_start.urls.docs}
```

---

## Paso 5 — TODO.md

**Sección centinelada:** `<!-- generated:todo-table:{module_id} -->`

Para cada módulo, tabla de UCs:
```markdown
| UC-ID | Nombre | Spec | Impl | Tests | Estado |
|-------|--------|------|------|-------|--------|
{POR CADA service del módulo}
| {module.uc_prefix}-{NNN} | {service.name sin "Service"} | {estado} | {estado} | {estado} | {estado} |
```

El estado de Spec/Impl/Tests se determina leyendo el TODO.md existente si ya hay filas,
o se inicializa en `⏳` para los `status: planned` y `✅` para los `status: implemented`.

---

## Paso 6 — Aplicar los cambios

Para cada archivo y cada sección centinelada:

1. Leer el archivo actual completo
2. Localizar el bloque `<!-- generated:{KEY} -->` ... `<!-- /generated:{KEY} -->`
3. Si el bloque **existe** → reemplazar el contenido interno (conservar los marcadores)
4. Si el bloque **no existe** → agregar el bloque completo al final de la sección correspondiente
5. Escribir el archivo modificado

---

## Paso 7 — Reporte final

```
## /c4-update-diagrams — Resultado

| Archivo | Secciones | Acción |
|---------|-----------|--------|
| context-diagram.md | 1 | ✅ regenerado |
| container-diagram.md | 6 | ✅ regenerado |
| component-diagram.md | 4 | ✅ regenerado |
| CLAUDE.md | 5 | ✅ regenerado |
| TODO.md | 1 | ✅ regenerado |

Módulos procesados: {lista}
Manifest versión: {version} · Fecha: {last_updated}

Tip: si agregaste un módulo nuevo al manifest, ejecuta también /sync-todo
para actualizar el estado de implementación.
```

---

## Cuándo usar este skill

| Evento | Acción |
|--------|--------|
| Se agrega un módulo a `modules[]` | `/c4-update-diagrams` |
| Se agrega un sistema externo a `external_systems[]` | `/c4-update-diagrams context` y `/c4-update-diagrams container` |
| Se agrega un nuevo servicio a un módulo existente | `/c4-update-diagrams component` |
| Cambia la tecnología del stack | `/c4-update-diagrams claude-md` |
| Se agrega un constraint nuevo | `/c4-update-diagrams claude-md` |
| Primera vez en un proyecto nuevo | `/init-project-api` or `/init-project-frontend` (incluye este skill) |
