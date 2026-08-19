# fac-data-stage-reality-check — Contraste Spec ↔ Realidad

Verifica que lo que el spec **declara** coincide con lo que el repo y el framework Dataops
**tienen**. Solo lectura — no modifica archivos. Reporta cada desalineación con su corrección.

**Bloque:** entre DESIGN y BUILD. También vale correrlo antes de un deploy a prd.

> **Por qué existe:** `fac-data-spec-validate` audita el YAML contra el estándar — es coherencia
> interna. Este comando audita el YAML contra la realidad desplegada: variables de entorno que
> nadie define, claves de deploy vacías, imágenes sin nombre, permisos que faltan, scripts del
> framework que no soportan lo que el spec asume. Son los errores que no rompen la validación
> pero sí el build.

**Argumento (`$ARGUMENTS`):** `[{id_modulo}] [--strict]`

```
fac-data-stage-reality-check
fac-data-stage-reality-check metadata-procesos
fac-data-stage-reality-check --strict     ← warnings cuentan como bloqueantes
```

---

## Paso 0 — Determinar módulo

Igual que el resto de comandos de etapa: `{id_modulo}` de `$ARGUMENTS`, o el módulo con
`etapa_actual` correspondiente en `project.manifest.yaml`, o el spec único de `docs/specs/`.

---

## Paso 1 — Leer en paralelo

```
1. {ruta del spec.yaml}                       → lo declarado
2. deploy/env_dev.json · env_prd.json         → variables realmente definidas
3. deploy/deploy_dev.json · deploy_prd.json   → componentes realmente desplegados
4. image/**/*.yaml                            → definición de imágenes
5. service/cloud_run/*/deploy_config.yaml     → env_vars y config del servicio
6. infra/service_accounts/ · infra/iam/       → SAs y permisos existentes
7. Código del servicio                        → rutas, modelos y variables realmente usadas
```

---

## Paso 2 — Verificaciones

### 2.1 Variables de entorno

| Verificación | Cómo |
|---|---|
| Toda `${var}` usada en DDL, `deploy_config.yaml`, workflows y schedulers existe como clave en `env_dev.json` **y** `env_prd.json` | Extraer los `${...}` de cada archivo y cruzarlos contra las claves del env. Una variable sin definir no falla el deploy: queda literal en el artefacto |
| Toda clave del env se usa en algún artefacto | Claves huérfanas = restos de módulos retirados |
| Las `env_vars` de `deploy_config.yaml` apuntan a claves existentes | Mismo cruce, en ambos ambientes |
| Ninguna variable duplica a otra con el mismo valor | Dos claves para lo mismo terminan divergiendo |

### 2.2 Componentes del spec vs deploy

| Verificación | Cómo |
|---|---|
| Todo `componentes[]` del spec tiene su entrada en `deploy_[env].json` | `ddl` → `bigquery_ddl`, `sp` → `bigquery_sp`, `ddl_pg` → **`cloudsql_ddl`**, `image` → `image`, `cloud_run` → `cloud_run`, `workflow` → `workflow`, `cloud_scheduler` → `cloud_scheduler` |
| Toda ruta listada en el deploy JSON existe en el repo | Un path que no existe aborta el build |
| El orden respeta las dependencias | FK en DDL, `image` antes de `cloud_run`, `monitoring_register` después de `cloud_scheduler` |
| `deploy_dev.json` y `deploy_prd.json` están alineados | Un componente en dev y no en prd es deuda silenciosa |

### 2.3 Imagen y Cloud Run (`cloud_run_api`, `cloud_function`)

| Verificación | Cómo |
|---|---|
| El YAML de imagen tiene los 6 campos (`dockerfile`, `name`, `repo`, `region`, `project`, `description`) | Sin `name`, `image.sh` no puede construir `{env}-{name}` |
| El `image:` de `deploy_config.yaml` coincide con `{env}-{name}` del YAML de imagen | Si no coinciden, el Cloud Run apunta a una imagen que nadie construyó |
| El `dockerfile` referenciado existe | — |
| `allow_unauthenticated` coincide con lo que declara `seguridad.autenticacion_api` | — |

### 2.4 Endpoints y rutas (`cloud_run_api`)

| Verificación | Cómo |
|---|---|
| Todo `endpoints[].path` del spec existe en el código | Cruzar contra los decoradores `@router.*` más el `prefix` del `APIRouter` |
| Toda ruta del código está declarada en el spec | Endpoints no documentados = deriva; los contratos legacy deben quedar marcados como tales |
| Los `datasources` que declara cada endpoint existen en el bloque `datasources` | — |

### 2.5 IAM y permisos

| Verificación | Cómo |
|---|---|
| Todo `seguridad.permisos[]` del spec tiene binding en `infra/iam/*-bindings.yaml` | — |
| Todo servicio GCP que el código invoca tiene su rol | Ej.: llamar a Workflow Executions API exige `roles/workflows.invoker`; leer un secreto, `secretmanager.secretAccessor` |
| Las SAs referenciadas existen en `infra/service_accounts/` | — |
| No hay bindings de módulos retirados | — |

### 2.6 Soporte del framework Dataops

| Verificación | Cómo |
|---|---|
| Las claves usadas en `deploy_[env].json` están soportadas por los scripts | Contrastar contra `itcm-dp-dataops-build/build/bash/` |
| Si el módulo matricula payloads vía API, `metadata_register.sh` sabe clasificarlos | Su `classify()` decide por contenido; un payload nuevo que no calce en ninguna rama se postea al endpoint equivocado |
| Los scripts sustituyen los placeholders que usan los artefactos | `cloudsql_pg.sh` y equivalentes reemplazan clave por clave del env |

> Esta verificación es la que más veces detecta trabajo que "quedaba pendiente en otro repo".
> Si el framework no soporta lo que el spec asume, el módulo no se puede desplegar aunque su
> código esté perfecto.

### 2.7 Restos de módulos retirados

Variables, bindings, DDL, código muerto o rutas de deploy que referencian módulos que ya no
existen. Se acumulan callados y rompen deploys mucho después.

---

## Paso 3 — Reporte

```
## Resultado fac-data-stage-reality-check — {spec_id}
módulo: {id_modulo}  |  type: {type}

### Desalineaciones: N

| Severidad | Área | Descripción | Corrección |
|---|---|---|---|
| 🔴 BLOQUEANTE | {área} | {qué está desalineado} | {qué archivo tocar} |
| 🟡 MEDIO | ... | ... | ... |
| 🟢 MENOR | ... | ... | ... |

### Verificado OK
✅ Variables: {n}/{n} definidas en dev y prd
✅ Componentes: {n}/{n} con entrada en deploy y ruta existente
✅ Endpoints: {n} del spec presentes en el código
✅ IAM: {n} permisos con binding
✅ Framework: claves de deploy soportadas

### Veredicto
✅ APTO para BUILD — o — ❌ NO apto: {n} bloqueantes
```

**Severidades:**
- 🔴 **BLOQUEANTE** — el build o el deploy fallan, o el servicio queda mal configurado en runtime
- 🟡 **MEDIO** — no rompe el deploy pero deja deriva entre spec, código e infraestructura
- 🟢 **MENOR** — restos, duplicaciones y documentación desalineada

---

## Qué NO cubre este comando

| Situación | Comando correcto |
|---|---|
| Coherencia interna del spec contra el estándar | `fac-data-spec-validate` |
| Cumplimiento de reglas de código (naming, PII, hardcoding) | `fac-data-rules-check` |
| Auditoría estática completa con reporte | `fac-data-stage-compliance` |
| Validación dinámica contra dev con datos reales | `fac-data-stage-testing` |
