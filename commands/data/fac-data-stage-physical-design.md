# fac-data-stage-physical-design — Contrato de Datos

Única sub-etapa obligatoria de DESIGN. Define el **contrato de datos** del módulo: el schema
físico de las tablas, sus tipos, constraints, llaves e índices. Es lo que BUILD consume y lo
que resulta caro cambiar después.

**Bloque:** DESIGN
**Invocación:**
```
fac-data-stage-physical-design
fac-data-stage-physical-design {id_modulo}   ← módulo específico del project.manifest.yaml
```

> **Prerequisito:** spec en status `review` o `approved`. Si el `type` requiere DISCOVERY
> (`bq_pipeline`, `vertex_ml`), haberlo corrido antes — el DDL se diseña contra metadata real
> de las fuentes, no contra supuestos.

> **Qué NO hace esta etapa:** no genera skeletons de SPs, componentes KFP ni FastAPI. Esos
> archivos los crea CODING de una sola pasada. Un skeleton con `TODO` se reescribe entero en la
> etapa siguiente: cuesta tokens, ensucia el diff y deja el repo en un estado que no ejecuta.

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json
```
Si no existe → ejecutar `fac-data-init-project` automáticamente antes de continuar.

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` en $ARGUMENTS → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: PHYSICAL_DESIGN` en el manifest
3. Si hay ambigüedad → listar módulos activos y pedir al usuario que especifique

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.design: true` en el spec antes de continuar.

---

## Paso 1 — Cargar skill y leer contexto

**Skill a cargar según `type`:**

| `type` | Skill |
|---|---|
| `bq_pipeline` | `@.claude/data/skills/build/coding/bigquery-pipeline-developer/SKILL.md` |
| `vertex_ml` | `@.claude/data/skills/build/coding/mlops-framework-developer/SKILL.md` |
| `cloud_run_api` | `@apps/skills/api-dev-agent.md` |
| `cloud_function` | skill CF (futuro) |

> Para repos del dominio de atributos de cliente (`itcm-dp-vuci-customer`), usar
> `@.claude/data/skills/build/coding/customer-attributes-developer/SKILL.md`.

Leer en paralelo:
```
1. {ruta del spec.yaml}            → fuente de verdad
2. deploy/env_dev.json             → variables de despliegue disponibles (claves reales)
3. docs/feature_spec/*/spec.md     → diseño de campos por output
4. DDL existentes del repo         → convenciones vigentes y para no sobreescribir
```

---

## Paso 2 — Revisar fuentes (solo si hubo DISCOVERY)

- Confirmar que los proyectos/datasets/tablas existen y son accesibles
- Detectar campos relevantes para el output: llaves de join, métricas, dimensiones
- Documentar volumetría real si difiere del spec

---

## Paso 3 — DDL físico

El destino depende del `type`:

| `type` | Dónde | Motor |
|---|---|---|
| `bq_pipeline`, `vertex_ml` | `data/bigquery/{dataset_out}/{tabla_out}/ddl/{tabla_out}.sql` | BigQuery |
| `cloud_run_api` con `datasources.cloud_sql` | `data/postgresql/ddl/{tabla}.sql` — un archivo por tabla | PostgreSQL |
| `cloud_function` | según el destino que declare el spec | — |

### BigQuery

```sql
CREATE TABLE IF NOT EXISTS `${project_analytics}.${dataset_analytics}.{tabla}`
(
  -- Columnas de negocio (definidas desde docs/feature_spec/*/spec.md)
  {campo}  {TIPO}  OPTIONS (description = '...'),

  -- Auditoría obligatoria
  load_date       DATE,
  record_source   STRING,
  creation_user   STRING
)
PARTITION BY load_date
OPTIONS (
  description = '{contexto.nombre}',
  labels      = [("team", "data-platform")]
);
```

- Naming por capa (`ba_`, `m_`, `t_`) — ver `@.claude/data/standard/bigquery/nomenclatura-retail.md`
- Tipos BQ: `STRING`, `INT64`, `FLOAT64`, `BOOL`, `DATE`, `TIMESTAMP`, `BYTES`
- Si hay PII en el output → `AEAD.ENCRYPT`, ver `@.claude/data/standard/architecture/data-platform-layers.md`

### PostgreSQL (Cloud SQL)

```sql
-- Schema: ${schema_pg_x} | Table: {tabla}
-- {descripción corta}
-- Spec: {spec_id} v{version} | Módulo: {id_modulo}
-- Generado por: fac-data-stage-physical-design

CREATE SCHEMA IF NOT EXISTS ${schema_pg_x};

CREATE TABLE IF NOT EXISTS ${schema_pg_x}.{tabla} (
  id            UUID NOT NULL,
  ...
  creation_user TEXT NOT NULL,
  creation_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT pk_{tabla}     PRIMARY KEY (id),
  CONSTRAINT uq_{tabla}_{x} UNIQUE (...),
  CONSTRAINT fk_{tabla}_{x} FOREIGN KEY (...) REFERENCES ${schema_pg_x}.{tabla_padre}(...),
  CONSTRAINT chk_{tabla}_{campo} CHECK ({campo} IN (...))
);

CREATE INDEX IF NOT EXISTS idx_{tabla}_{col} ON ${schema_pg_x}.{tabla}({col});

COMMENT ON TABLE  ${schema_pg_x}.{tabla} IS '...';
COMMENT ON COLUMN ${schema_pg_x}.{tabla}.{col} IS '...';
```

- **El placeholder de schema debe ser una clave que exista en `env_[env].json`.** `cloudsql_pg.sh`
  sustituye con un `sed` por cada clave del env; un `${schema_pg}` que nadie define queda literal
  en el SQL y el deploy crea un schema con nombre inválido. Verificarlo contra el env antes de escribir
- `CREATE TABLE IF NOT EXISTS` siempre, `DROP` nunca
- Constraints con nombre: `pk_`, `uq_`, `fk_`, `chk_` — un `CHECK` por cada enum
- Índices en FKs, flags de actividad y columnas de búsqueda
- `COMMENT ON` en tabla y en toda columna no obvia, referenciando la RN cuando aplique
- Auditoría: `creation_user`, `creation_date` y, si la tabla se actualiza, `update_user`, `update_date`

### Coherencia con el código

Los `CHECK` de enums son el contrato que después replican los `Literal` de Pydantic o los
`ENUM` del modelo. Definirlos acá y no en el código evita que diverjan.

---

## Paso 4 — Declarar el DDL en el spec

Cada archivo creado debe quedar declarado en `componentes[]` del spec:

| `type` | Componente |
|---|---|
| BigQuery | `tipo: ddl` |
| PostgreSQL | `tipo: ddl_pg` → mapea a la clave `cloudsql_ddl` de `deploy_[env].json` en DATAOPS |

Si el spec no los tiene, agregarlos con `fac-data-spec-update` — no editar el spec a mano.

> El **orden** en que se listan importa: DATAOPS lo respeta al desplegar y las FK exigen que la
> tabla padre exista primero.

---

## Paso 5 — Actualizar docs/TODO.md

Marcar PHYSICAL_DESIGN como completado y documentar los pendientes detectados.

```
## Etapa completada: PHYSICAL_DESIGN
→ Próximo paso: fac-data-stage-reality-check y luego fac-data-stage-coding
```

---

## Reporte

```
## Etapa completada: PHYSICAL_DESIGN
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Contrato de datos definido
- ✅ {ruta del DDL}   ({n} columnas, {n} constraints, {n} índices)

### Decisiones tomadas en el DDL
- {constraint o llave} — {qué ambigüedad del spec resuelve}

### Pendientes (si los hay)
- ⬜ {archivo}: {razón}

### Próxima etapa
fac-data-stage-reality-check {id_modulo}      (contrastar spec contra artefactos reales)
fac-data-stage-coding {id_modulo}
```
