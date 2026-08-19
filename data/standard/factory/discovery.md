# Estándar: Etapa DISCOVERY — Mapeo e Integración de Fuentes

> **Etapa:** DISCOVERY — validación de fuentes de datos y enriquecimiento de spec después de aprobación
>
> La etapa **DISCOVERY** ocurre una sola vez en el ciclo de vida del proyecto: después que el `spec.yaml`
> es aprobado (`status: approved`), y **antes** de iniciar el diseño arquitectónico (`design: true`).
> Su propósito es validar que todas las fuentes de datos existen, son accesibles, y enriquecer el spec
> con metadata real de BigQuery.

---

## Posición en el flujo de fábrica

```
┌────────────────────────────────────────────────────────────────┐
│ 1. PRE-PLAN: Brief Funcional (negocio describe necesidad)    │
├────────────────────────────────────────────────────────────────┤
│ 2. PLAN: /spec-create (ingeniero traduce a spec.yaml draft)  │
├────────────────────────────────────────────────────────────────┤
│ 3. PLAN APPROVAL: Stakeholders validan spec (status: approved)│
├────────────────────────────────────────────────────────────────┤
│ ⭐ 4. DISCOVERY: Mapear tablas, validar, enriquecer spec     │
│     (NUEVO — ocurre aquí, una sola vez)                      │
├────────────────────────────────────────────────────────────────┤
│ 5. /init-project: Crear scaffold (carpetas, archivos base)   │
├────────────────────────────────────────────────────────────────┤
│ 6. DESIGN: Arquitectura, lineamientos, nombrado              │
│ 7. BUILD: Codificación (DDL, SP, transformaciones)           │
│ 8. VERIFY: Validación, testing                               │
│ 9. RELEASE: Despliegue, documentación                        │
└────────────────────────────────────────────────────────────────┘
```

---

## Propósito

La etapa DISCOVERY asegura que:

1. **Todas las fuentes declaradas en `spec.fuentes` existen** en BigQuery y son accesibles
2. **Se extrae metadata real** de cada tabla (estructura, tamaño, partición, clustering, PII)
3. **El spec se enriquece** con información descubierta (volumetría real, campos sensibles, referencias precisas)
4. **Se generan catálogos** en `data/data_catalog/` para cada fuente
5. **Se crea un reporte** (`discovery-report.md`) documentando qué se validó y alertas encontradas
6. **Se valida consistencia** entre el brief y la realidad de los datos

---

## Cuándo ejecutar `/data:implement-stage DISCOVERY`

Ejecutar `/data:implement-stage DISCOVERY` **solo si:**

- ✅ El spec está en estado `status: approved`
- ✅ El spec **tiene sección `fuentes`** (al menos una tabla de entrada)
- ✅ El proyecto GCP es **conocido y accesible** (no puede ser variable desconocida)
- ✅ Las tablas **ya existen en BigQuery** (proyecto destino confirmado)
- ✅ El usuario tiene **acceso IAM** a las tablas fuente

**NO ejecutar discovery si:**

- ❌ Las tablas se crearán como parte del desarrollo (fuentes nuevas)
- ❌ Las fuentes vienen de sistemas externos (Matillion, S3, APIs de terceros) no integrados en BQ
- ❌ El acceso está pendiente de gestión IAM
- ❌ El spec no tiene `fuentes[]` declaradas (proyecto sin fuentes externas)

---

## Actividades en DISCOVERY

### 1. Preparación — Validar spec.yaml

Antes de ejecutar el comando, verificar que el spec está en buen estado:

```yaml
# Checklist antes de /data:implement-stage DISCOVERY
status: approved              # ✅ Spec debe estar aprobado
fuentes:                      # ✅ Al menos una fuente declarada
  - id: rcc               
    descripcion: "..."    
    proyecto: dev-itc-customer-services  # ✅ Proyecto accesible
    dataset: analytics    
    tabla: m_rcc         # ✅ Tabla existe en el proyecto
    # Estos campos se completarán en discovery:
    # volumetria, particion, pii, campos_sensibles
```

Si falta algo, actualizar el spec primero con `/spec-update`.

---

### 2. Ejecución del Comando

Ejecutar en la raíz del repositorio:

```bash
/data:implement-stage DISCOVERY
```

El comando automáticamente:
- Lee `spec.yaml` y resuelve todas las fuentes
- Invoca `data-catalog-bq-generator` para cada fuente (si no existe catálogo)
- Enriquece spec.yaml con metadata real
- Genera `discovery-report.md`

---

### 3. Mapeo — Detalles de lo que hace el comando internamente

Para cada tabla en `spec.fuentes`, usar el skill `data-catalog-bq-generator`:

```bash
# Plantilla de comando
python tools/fun-data-profiler-bq/client.py \
  --table-ref "${proyecto}.${dataset}.${tabla}"
```

**Outputs esperados:**
- `data/data_catalog/{dataset}-{tabla}.md` — catálogo detallado
- Metadata JSON (opcional, almacenado internamente por la herramienta)

**Ejemplo práctico:**

```bash
# Descubrir tabla de RCC
python tools/fun-data-profiler-bq/client.py \
  --table-ref "dev-itc-customer-services.analytics.m_rcc"

# Descubrir tabla de atributos
python tools/fun-data-profiler-bq/client.py \
  --table-ref "dev-itc-customer-services.analytics.ba_customer_attributes"

# Descubrir tabla de transacciones
python tools/fun-data-profiler-bq/client.py \
  --table-ref "dev-itc-customer-services.analytics.t_transactions"
```

---

### 3. Validación — Checklist de accesibilidad

Para cada tabla descubierta:

| Validación | Descripción | Si falla |
|---|---|---|
| ✅ Existe | La tabla está en el dataset especificado | Alertar y documentar |
| ✅ Accesible | La SA tiene permiso `bigquery.tables.get` | Escalada IAM requerida |
| ✅ Estructura válida | Tiene al menos 1 columna | Investigar si tabla vacía |
| ✅ Registros | Tiene rowcount > 0 | Alertar: tabla sin datos |
| ✅ Partición | Campo de partición existe (si se declara) | Actualizar `particion: ~` |
| ✅ Clustering | Validar campos clustering (si aplica) | Documentar en catálogo |

---

### 4. Enriquecimiento del spec.yaml

Después de invocar data-catalog-bq-generator, actualizar cada fuente con metadata descubierta:

**Antes (spec draft):**
```yaml
fuentes:
  - id: rcc
    descripcion: "Rating de Crédito Corporativo"
    proyecto: dev-itc-customer-services
    dataset: analytics
    tabla: m_rcc
    volumetria: ~
    particion: ~
    pii: ~
```

**Después (spec enriquecido):**
```yaml
fuentes:
  - id: rcc
    descripcion: "Rating de Crédito Corporativo"
    proyecto: dev-itc-customer-services
    dataset: analytics
    tabla: m_rcc
    volumetria: "~245K registros (2026-05-08)"
    particion: "Sin partición (tabla estática)"
    pii: false
    campos_sensibles: []
    metadata_url: "data/data_catalog/analytics-m_rcc.md"
```

**Campos a actualizar:**
- `volumetria` — Filas reales: `~{N}K/M registros`
- `particion` — Campo partición o `"Sin partición"`
- `pii` — `true` si data-catalog-bq-generator encuentra campos HIGH/MEDIUM risk
- `campos_sensibles` (nuevo) — Lista de campos con riesgo HIGH/MEDIUM
- `metadata_url` (nuevo) — Referencia al catálogo generado
- `ultima_fecha_disponible` (nuevo, si `particion` es temporal) — Última partición cargada
- `primera_fecha_disponible` (nuevo, si es table de eventos) — Rango temporal

---

### 5. Generación de Reporte

Crear `docs/discovery-report.md` con:

```markdown
# Discovery Report — {spec.id}

**Fecha:** {fecha}
**Spec:** {spec.id} v{version}
**Status:** ✅ COMPLETADO / ⚠️ CON ALERTAS / ❌ FALLIDO

## Resumen

- Tablas descubiertas: {N}/{N} (100% exitosas)
- Catálogos generados: {N}
- Alertas encontradas: {N}

## Detalles por Fuente

### {id_fuente}: {descripcion}

| Atributo | Valor | Status |
|---|---|---|
| Tabla | `{proyecto}.{dataset}.{tabla}` | ✅ |
| Filas | ~{N}K | ✅ |
| Tamaño | {N} GB | ✅ |
| Partición | {campo} (DAY) | ✅ |
| PII detectado | {campos} | ⚠️ ALTO RIESGO |
| Catálogo | [Link](../../standard/data_catalog/...) | ✅ |

**Hallazgos:**
- Tabla parece estar vacía desde {fecha} — validar si es esperado
- Campo X tiene 95% NULLs — considerar exclusión
- PII detectado en campos: {lista} — requiere encriptación en capas sensibles

---

## Alertas

### ⚠️ ALTO RIESGO

- Tabla `ba_customer_attributes` contiene RUC de clientes (campo `ruc_customer`)
  **Acción requerida:** Aplicar encriptación AEAD en pipeline o restringir acceso

### ⚠️ ADVERTENCIA

- Tabla `t_transactions` no está particionada (69.55K registros, 46.55 MB)
  **Recomendación:** Considerar clustering por `transaction_date` y `itc_company_id`

## Cambios al spec.yaml

✅ Actualizado:
- `fuentes[0].volumetria` ← de `~` a `~245K registros`
- `fuentes[0].pii` ← de `~` a `true`
- `fuentes[1].particion` ← de `~` a `transaction_date (DAY)`

## Siguiente paso

1. Revisar alertas y validar con Data Owner
2. Actualizar spec.yaml si se encuentran discrepancias
3. Marcar `status: approved` si todo está OK
4. Proceder a `/init-project` y DESIGN
```

---

## Cómo Invocar DISCOVERY

**Comando:** `/data:implement-stage DISCOVERY`

Ejecutar en la raíz del repositorio de trabajo después que el spec sea aprobado:

```bash
# Invocar discovery para todas las fuentes
/data:implement-stage DISCOVERY

# Invocar discovery solo para fuentes específicas
/data:implement-stage DISCOVERY --only tabla1,tabla2,tabla3
```

**Qué hace:**
1. Lee `spec.yaml` (todas las fuentes en `fuentes[]`)
2. Resuelve variables `${...}` desde `deploy/env_dev.json`
3. Busca glosarios existentes en `data/data_catalog/`
4. Para glosarios faltantes: invoca `data-catalog-bq-generator` (skill de análisis)
5. Enriquece `spec.yaml` con volumetría, partición, PII, campos sensibles
6. Genera reporte `discovery-report.md` con alertas
7. Retorna mensaje de éxito o alertas encontradas

**Herramientas utilizadas:**
- **data-catalog-bq-generator** (skill `@data/skills/analysis/data-catalog-bq-generator/SKILL.md`): extrae metadata real de BigQuery INFORMATION_SCHEMA
- **Cloud Function** (opcional): si usa herramienta `tools/fun-data-profiler-bq/` para profiling remoto

---

## Checklist de DISCOVERY

| # | Actividad | Responsable | Status |
|---|-----------|-------------|--------|
| 1 | ✅ spec.yaml en estado `approved` | Equipo técnico | |
| 2 | ✅ Preparar fuentes (validar proyecto/dataset/tabla) | Data Engineer | |
| 3 | ✅ Invocar `discovery-assistant` skill | Data Engineer | |
| 4 | ✅ Revisar alertas en discovery-report.md | Data Owner | |
| 5 | ✅ Actualizar spec.yaml si hay discrepancias | Data Engineer | |
| 6 | ✅ Validar catálogos en `data_catalog/` | Reviewer técnico | |
| 7 | ✅ Obtener sign-off de Data Owner | Data Owner | |
| 8 | ✅ Proceder a `/init-project` | Data Engineer | |

---

## Casos de uso

### Caso 1: Proyecto simple, 1 fuente

```yaml
# spec.yaml
fuentes:
  - id: rcc
    descripcion: "Rating de Crédito"
    proyecto: dev-itc-customer-services
    dataset: analytics
    tabla: m_rcc
```

Discovery ejecuta:
1. Validar que `dev-itc-customer-services.analytics.m_rcc` existe
2. Generar `data_catalog/analytics-m_rcc.md`
3. Actualizar spec con volumetría y PII
4. Crear `discovery-report.md`

---

### Caso 2: Proyecto con múltiples fuentes y join

```yaml
# spec.yaml
fuentes:
  - id: clientes
    tabla: m_customer
  - id: transacciones
    tabla: t_transactions
  - id: iden
    tabla: iden_itc_party
```

Discovery ejecuta:
1. Validar las 3 tablas en paralelo
2. Generar 3 catálogos
3. Analizar campos de join (ej: `customer_id` en ambas)
4. Alertar si campos clave no existen en alguna fuente
5. Documentar lineage

---

### Caso 3: Proyecto con datos sensibles

```yaml
# spec.yaml
fuentes:
  - id: empleados
    tabla: m_employee
    descripcion: "Datos maestros de empleados"
    pii: ~  # ← Será llenado en discovery
```

Discovery detecta PII y actualiza:
```yaml
  - id: empleados
    pii: true
    campos_sensibles:
      - nombre (HIGH)
      - email (HIGH)
      - ssn (HIGH)
      - phone (MEDIUM)
```

Esto informa decisiones posteriores en DESIGN (encriptación, acceso restringido).

---

## FAQ

**P: ¿Qué pasa si una tabla no existe?**
R: Discovery lo reporta en `discovery-report.md` con status ❌ FALLIDO. Detiene el flujo hasta que la tabla sea creada o referencia sea corregida.

**P: ¿Puedo hacer discovery con tablas que se crearán en este proyecto?**
R: No. Las tablas de OUTPUT se crean en CODING (fase BUILD), no existen en discovery. Discovery solo valida FUENTES.

**P: ¿Qué pasa si la tabla tiene millones de registros?**
R: El profiling toma más tiempo (típicamente < 5 min para 100M registros). Pero solo se hace UNA VEZ, y el resultado enriquece el spec permanentemente.

**P: ¿Puedo saltarme discovery?**
R: Solo si `discovery: false` en spec.yaml. Pero se recomienda siempre que haya fuentes BigQuery existentes (es un check crítico).

**P: ¿Se puede re-ejecutar discovery después de DESIGN?**
R: Técnicamente sí, pero no es recomendado. Discovery está diseñado para ocurrir una sola vez, después de spec approval. Si luego descubres cambios en las fuentes, actualiza el spec y procede.

---

## Integración con otros estándares

Referencia a estándares relacionados:
- `@data/standard/factory/spec-manifest.md` — Schema del spec.yaml
- `@data/standard/factory/functional-brief.md` — Brief previo a discovery
- `@data/standard/architecture/data-platform-layers.md` — Capas, nomenclatura
- `@data/skills/analysis/data-catalog-bq-generator/SKILL.md` — Herramienta de profiling
