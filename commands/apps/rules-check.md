# Check Rules — Verificación de Reglas Críticas

Analiza el código y verifica el cumplimiento de las reglas del proyecto en dos fases:

- **Fase 1 — Reglas Estructurales:** hardcoded, requieren contexto y análisis semántico.
- **Fase 2 — Reglas Globales Dinámicas:** leídas de `business-rules.md` — se actualizan automáticamente al agregar reglas.

---

## Instrucciones de Ejecución

### 1. Determinar el scope de análisis

Si `$ARGUMENTS` está vacío → analizar todos los archivos `.ts` en `src/`.
Si `$ARGUMENTS` contiene `--staged` → usar `git diff --staged` y analizar solo archivos modificados.
Si `$ARGUMENTS` contiene un path (ej: `src/core/`) → limitar a ese path.
Si `$ARGUMENTS` contiene un ID de regla (ej: `RN-GLO-007`) → ejecutar solo esa regla.

Ignorar siempre: `.md`, `.sql`, `.json`, `.env*`, `test/e2e/**`.

---

## FASE 1 — Reglas Estructurales (hardcoded)

> Estas reglas requieren análisis semántico o contexto de múltiples líneas.
> No pueden reducirse a un patrón grep simple.

---

### REGLA 1 — No usar `any` en TypeScript

**Patrón de violación (buscar en líneas añadidas):**
```
: any
as any
<any>
any[]
Promise<any>
```

**Excepción:** `// eslint-disable` con justificación documentada.

**Corrección:** reemplazar por tipo concreto, `unknown` + type guard, o genérico `<T>`.

---

### REGLA 2 — Domain Layer no depende de Infrastructure

**Buscar en archivos dentro de `src/core/`:**
```typescript
import ... from '...infrastructure...'
import ... from '...typeorm...'
import ... from '@nestjs/typeorm'
import ... from 'typeorm'
```

**Violación:** cualquier import de infraestructura en `src/core/domain/` o `src/core/application/`.

**Corrección:** el domain solo importa de `src/core/`. Las dependencias externas se inyectan via port interfaces.

---

### REGLA 3 — No exponer TypeORM Entities en responses

**Buscar en archivos `*.controller.ts` y `*.mapper.ts`:**
```typescript
: XxxEntity     // como tipo de retorno o parámetro
return entity;  // retornando la TypeORM entity directamente
```

**Corrección:** pasar siempre por `XxxMapper.toResponse(domain)` antes de retornar.

---

### REGLA 4 — Auditoría: campos `*UserId` correctos

**En `create` de repositorios:**
```typescript
// ❌ Hardcodeado o ausente
createdUserId: 'system'
createdUserId: undefined

// ✅ Correcto
createdUserId: data.createdUserId ?? null
```

**En `softDelete` de repositorios:** los tres campos juntos obligatorios:
```typescript
isDeleted: true,
deletedAt: new Date(),
deletedUserId: userId,  // ← si falta alguno → violación
```

**Corrección:** `createdUserId`/`updatedUserId` vienen del `JWT.sub` pasado desde el controller.

---

### REGLA 5 — No hardcodear valores de configuración

**Patrón de violación:**
```typescript
secret: 'my-secret-key'
host: 'localhost'          // en archivos de módulo/config
port: 5432                 // como literal en código fuente
'postgres://user:pass@...'
```

**Excepción:** valores por defecto en DTOs (ej: `page = 1`) y constantes de dominio sin información sensible.

**Corrección:** usar `configService.get<string>('VAR_NAME')`.

---

### REGLA 6 — No lógica de negocio en Controllers

**Buscar en archivos `*.controller.ts`:**
```typescript
if (user.role === 'ADMIN') { ... }
const hash = await bcrypt.hash(...)
await this.repo.findOne(...)    // acceso directo a repo
data.filter(...)                // transformación de datos
```

**Corrección:** el controller solo extrae parámetros del request, delega al service y retorna:
```typescript
const result = await this.createXxxService.execute(dto, user.sub);
return result;
```

---

### REGLA 7 — Refresh tokens: solo el hash SHA-256

**Patrón de violación en services y repositorios:**
```typescript
token: refreshToken      // token en claro en la BD
tokenValue: token
rawToken: token
```

**Corrección:**
```typescript
tokenHash: crypto.createHash('sha256').update(token).digest('hex')
```

---

## FASE 2 — Reglas Globales Dinámicas

> El skill lee `claude_workspace/architecture/business-rules.md`, localiza la sección
> `## Patrones de Verificación Automática` y ejecuta cada fila de la tabla.

### Instrucciones para ejecutar la Fase 2

1. **Leer** `claude_workspace/architecture/business-rules.md`
2. **Localizar** la tabla bajo `## Patrones de Verificación Automática`
3. **Para cada fila** de la tabla:
   - Tomar el **Scope** (glob de archivos a analizar)
   - Tomar el **Tipo** (`forbidden` o `required`)
   - Tomar el **Patrón** (regex de grep)
   - Ejecutar la búsqueda:
     - `forbidden` → si el patrón **se encuentra** en algún archivo del scope → **VIOLACIÓN**
     - `required` → si el patrón **NO se encuentra** en ningún archivo del scope → **VIOLACIÓN**
4. **Reportar** con el formato estándar, identificando la regla por su ID (`RN-GLO-XXX`)

### Reglas con check manual (no automatizables por patrón simple)

Al finalizar la Fase 2, incluir una sección de revisión manual para las reglas que no tienen patrón en la tabla:

| ID | Descripción | Por qué no es automatizable |
|----|-------------|----------------------------|
| RN-GLO-001 | UUIDs via pgcrypto | La generación es en SQL (DDL), no en código TS |
| RN-GLO-002 | Timestamps automáticos TypeORM | Requiere verificar decoradores en contexto de clase |
| RN-GLO-003 | is_active=true, is_deleted=false por defecto | Requiere rastrear flujo de creación completo |
| RN-GLO-009 | created_user_id = JWT.sub | Requiere rastrear el valor de JWT.sub hasta el repo |
| RN-GLO-010 | updated_user_id = JWT.sub | Idem |

Marcar como: `⚪ RN-GLO-XXX — Requiere revisión manual`

---

## Formato del Reporte

```
## FASE 1 — Reglas Estructurales

### 📄 src/path/to/file.ts
✅ REGLA 1 — No any: OK
⚠️  REGLA 3 — TypeORM Entity en response: VIOLACIÓN
    Línea 23: `: CategoryEntity` como tipo de retorno
    Corrección: cambiar a `: CategoryResponseDto`, pasar por CategoryMapper.toResponse()

---

## FASE 2 — Reglas Globales (business-rules.md)

✅ RN-GLO-005 [required] APP_GUARD: encontrado en src/infrastructure/modules/shared.module.ts
⚠️  RN-GLO-011 [required] isDeleted filter: NO encontrado en src/infrastructure/adapters/secondary/
    Corrección: agregar `isDeleted: false` en el `where` de todas las queries de listado
✅ RN-GLO-013 [forbidden] .signAsync(): no encontrado en src/ — OK

⚪ RN-GLO-001 — Requiere revisión manual (pgcrypto en DDL)
⚪ RN-GLO-009 — Requiere revisión manual (rastrear JWT.sub)

---

## Resumen
- Fase 1 — Archivos analizados: N | Violaciones: M
- Fase 2 — Reglas verificadas: K | Violaciones: J | Revisión manual: P
- Total violaciones: M+J
```

Si no hay violaciones en ninguna fase:
```
✅ Todas las reglas se cumplen. (Fase 1: N archivos | Fase 2: K reglas globales)
```
