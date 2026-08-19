# Inicializar Proyecto — Scaffolding Completo

Crea toda la estructura base del proyecto la primera vez: configuración, arranque NestJS, infraestructura compartida, entidades de dominio, ports, entidades TypeORM y módulos shell — **sin implementar lógica de negocio** (services, repositories, controllers, mappers).

> **Cuándo usar:** una sola vez, antes de cualquier `/spec-code`. El resultado es un proyecto que compila y arranca, listo para recibir UCs.

---

## Paso 0 — Leer fuentes de verdad

Leer en paralelo:

```
1. CLAUDE.md                          → stack, convenciones
2. claude_workspace/guides/development.md      → variables de entorno, JWT payload, tokens DI
3. claude_workspace/architecture/ddl.sql       → tablas, columnas, tipos, PKs, FKs, schema name
4. claude_workspace/architecture/feature_spec/ → módulos de negocio (para module shells)
5. claude_workspace/rules/architecture.md      → Path Registry
```

Verificar que `rules/architecture.md` tiene la sección `## 🗂️ Path Registry`.
Si no existe → crearla antes de continuar (paths derivados de la estructura del proyecto).

---

## Paso 1 — Detectar estado

| Estado | Acción |
|--------|--------|
| `src/main.ts` no existe | Crear todo (pasos 2–12) |
| `src/main.ts` existe | Reportar y salir sin modificar nada |

---

## Paso 2 — Plan

Derivar del DDL y los specs la lista de artefactos y presentarla al usuario:

```
## Plan de Scaffold — {project.name}

Config raíz:        package.json · tsconfig.json · tsconfig.build.json
                    nest-cli.json · .eslintrc.js · .prettierrc · .env.example
                    jest.config.js · test/jest-e2e.json

Arranque NestJS:    src/main.ts · src/app.module.ts · src/data-source.ts

Shared infra:       jwt-payload.interface.ts
                    decorators: @Public() · @CurrentUser() · @RequirePermissions() · @SuperAdminOnly()
                    guards: JwtAuthGuard (global) · PermissionsGuard · SuperAdminGuard
                    filters/all-exceptions.filter.ts

DTOs comunes:       pagination-query.dto.ts · paginated-response.dto.ts

DatabaseModule:     infrastructure/modules/database.module.ts

Domain entities:    {N} archivos — una clase pura por tabla del DDL
Output ports:       {N} interfaces — una por agregado
TypeORM entities:   {N} clases decoradas — una por tabla del DDL
Module shells:      {M} módulos vacíos — uno por área de negocio del spec

¿Procedo? (s/n)
```

Solo continuar si el usuario confirma.

---

## Paso 3 — Archivos de configuración raíz

| Archivo | Fuente / Regla |
|---------|---------------|
| `package.json` | Stack de CLAUDE.md · scripts según `rules/tooling.md` "package.json Scripts" |
| `tsconfig.json` | Strict mode según `rules/typescript.md` · agregar path aliases `@core/*` y `@infrastructure/*` |
| `tsconfig.build.json` | Extender `tsconfig.json` · excluir `node_modules`, `test/`, `dist/` |
| `nest-cli.json` | `sourceRoot: "src"` · `compilerOptions.deleteOutDir: true` |
| `.eslintrc.js` | Según `rules/tooling.md` "ESLint" |
| `.prettierrc` | Según `rules/tooling.md` "Prettier" |
| `.env.example` | Variables de `guides/development.md` "Variables de Entorno" · sin valores reales |
| `jest.config.js` | Según `rules/testing.md` "Configuración de Coverage" · umbral del manifest · `moduleNameMapper` para path aliases |
| `test/jest-e2e.json` | Config separada para E2E · mismo umbral |

---

## Paso 4 — Arranque NestJS

**`src/main.ts`** — según `rules/security.md` "Setup en main.ts", más:
- `app.setGlobalPrefix('api')` (prefijo del manifest)
- Swagger solo si `NODE_ENV !== 'production'`
- Puerto desde `process.env.PORT ?? 3000`

**`src/app.module.ts`** — solo `ConfigModule.forRoot` + `DatabaseModule` + un import comentado por cada módulo de negocio detectado en los specs:

```typescript
@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    DatabaseModule,
    // AuthModule,      // habilitar con /spec-code UC-AUTH-01
    // ProductsModule,  // habilitar con /spec-code UC-PROD-01
  ],
})
export class AppModule {}
```

**`src/data-source.ts`** — variables `DB_*` desde `process.env`, `synchronize: false`, globs de entities y migrations a los paths del Path Registry. Soporte Unix sockets si `DB_HOST` empieza con `/`.

---

## Paso 5 — Infraestructura compartida

Directorio: `src/infrastructure/adapters/primary/rest/shared/`

| Artefacto | Fuente / Regla |
|-----------|---------------|
| `interfaces/jwt-payload.interface.ts` | Campos de `guides/development.md` "JWT Payload" |
| `decorators/` (4 archivos) | Según `guides/development.md` "Decoradores disponibles" |
| `guards/` (3 archivos) | Según `rules/security.md` "JWT Authentication" + `guides/development.md` "Guards" |
| `filters/all-exceptions.filter.ts` | Según `rules/error-handling.md` "All Exceptions Filter" · agregar mapeo PG → HTTP (23505→409, etc.) |

---

## Paso 6 — DTOs compartidos + DatabaseModule

**DTOs** en `src/core/application/dtos/common/` según `rules/performance.md` "Paginación":
- `pagination-query.dto.ts` — `page` (default 1), `limit` (default 20, max 100)
- `paginated-response.dto.ts` — `PaginatedResponseDto<T>` con `data[]` y `meta`

**DatabaseModule** en `src/infrastructure/modules/database.module.ts`:
`TypeOrmModule.forRootAsync` con `ConfigService`, schema del DDL, globs de entities/migrations del Path Registry, `synchronize: false`, connection pool según `rules/performance.md` "Connection Pooling".

---

## Paso 7 — Domain entities

Directorio: Path Registry `domain_entities`. **Una clase TypeScript pura por tabla del DDL.**
Template en `guides/development.md` "Domain Entity".

Reglas de traducción DDL → domain:

| DDL | Propiedad en la entity |
|-----|----------------------|
| `snake_case` column | `camelCase` |
| FK `xxx_id UUID NOT NULL` | `xxxId: string` |
| FK `xxx_id UUID NULL` | `xxxId: string \| null` |
| `tipo NOT NULL` | `tipo` |
| `tipo NULL` | `tipo \| null` |
| `created_at`, `updated_at`, `is_deleted`, `deleted_at`, `*_user_id` | Incluir siempre — ver template en `guides/development.md` |

Sin decoradores NestJS ni TypeORM. Sin lógica de negocio.

---

## Paso 8 — Output ports

Directorio: Path Registry `ports_output/{módulo}/`. **Una interfaz por agregado principal.**
Template en `guides/development.md` "Output Port".

- Sin imports de infraestructura ni framework
- Exportar token DI junto a la interfaz
- Métodos base: `findById`, `create`, `update`, `softDelete` + los que anticipen los specs

---

## Paso 9 — TypeORM entities

Directorio: Path Registry `typeorm_entities`. **Una clase decorada por tabla del DDL.**
Template completo con columnas de auditoría en `guides/development.md` "TypeORM Entity".

| DDL tipo | Decorator TypeORM |
|----------|------------------|
| PK UUID | `@PrimaryGeneratedColumn('uuid')` |
| `VARCHAR(N)` | `@Column({ type: 'varchar', length: N })` |
| `TEXT` | `@Column({ type: 'text' })` |
| `NUMERIC(p,s)` | `@Column({ type: 'numeric', precision: p, scale: s })` |
| `INTEGER` | `@Column({ type: 'int' })` |
| `BOOLEAN DEFAULT false` | `@Column({ type: 'boolean', default: false })` |
| FK `UUID NULL` | `@Column({ type: 'uuid', nullable: true })` |
| `created_at` | `@CreateDateColumn({ name: 'created_at', type: 'timestamptz' })` |
| `updated_at` | `@UpdateDateColumn({ name: 'updated_at', type: 'timestamptz' })` |
| Columna nullable | agregar `nullable: true` |

`@Entity({ name: '{tabla}', schema: '{schema}' })`. Sin `@ManyToOne`/`@OneToMany` — solo `@Column` para FKs. Indexar columnas `UNIQUE` o de filtro frecuente (según `rules/performance.md` "Indexing").

---

## Paso 10 — Module shells

Directorio: Path Registry `modules`. **Un módulo vacío por área de negocio** de los specs.
Providers y controllers comentados como guía para `/spec-code`:

```typescript
@Module({
  imports: [TypeOrmModule.forFeature([/* Entities — agregar con /spec-code */])],
  controllers: [/* {Nombre}Controller — agregar con /spec-code */],
  providers: [
    // { provide: {NOMBRE}_REPOSITORY_PORT, useClass: TypeOrm{Nombre}Repository },
  ],
  exports: [],
})
export class {Nombre}Module {}
```

---

## Paso 11 — Verificar compilación

```bash
npm install && npx tsc --noEmit 2>&1 | grep "error TS" | head -20
```

| Error frecuente | Fix |
|-----------------|-----|
| `Cannot find module '@core/...'` | Agregar `moduleNameMapper` en `jest.config.js` + `paths` en `tsconfig.json` |
| `Module not found` | Verificar `package.json` |
| Import circular | `src/core/` no debe importar de `src/infrastructure/` |
| `Property X does not exist` | Domain entity no refleja el DDL — corregir la propiedad |

---

## Paso 12 — Reporte final

```
## Scaffold completado — {project.name}

| Capa | Archivos |
|------|---------|
| Config raíz | package.json, tsconfig*, nest-cli.json, .eslintrc.js, .prettierrc, .env.example, jest* |
| Arranque | main.ts, app.module.ts, data-source.ts |
| Shared infra | 4 decorators, 3 guards, 1 filter, 1 interface |
| DTOs comunes | pagination-query.dto.ts, paginated-response.dto.ts |
| DatabaseModule | database.module.ts |
| Domain entities | {N} |
| Output ports | {N} |
| TypeORM entities | {N} |
| Module shells | {M} |

Compilación: ✅ sin errores / ❌ {N} errores (ver arriba)

Próximos pasos → guides/development.md "Setup Inicial"
```

---

## Qué NO hace este skill

| Responsabilidad | Skill correcto |
|----------------|---------------|
| Services, repositories, controllers, DTOs, mappers | `/spec-code` |
| Adapters externos (Firebase, etc.) | `/spec-code` |
| Migraciones SQL | Manual — documentar en `architecture/migrations.sql` |
