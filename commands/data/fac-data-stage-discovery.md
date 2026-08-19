# DISCOVERY — Entendimiento de Fuentes y Glosarios

Sub-etapa de DESIGN. Enriquece la sección `fuentes` del `spec.yaml` con metadata real de
BigQuery: campo de partición, volumetría, campos de join, empresas cubiertas y observaciones
de calidad. Para cada fuente busca el glosario existente; si no existe, ejecuta el flujo de
profiling para generarlo primero.

**Invocación:**
```
/data:implement-stage DISCOVERY
/data:implement-stage DISCOVERY docs/specs/spec-itc-20260330-001.yaml
/data:implement-stage DISCOVERY --only iden_itc_party,t_payment   ← solo fuentes indicadas
```

> **Cuándo usar:** primera sub-etapa de DESIGN, solo para módulos que declaran `fuentes[]`
> (`bq_pipeline`, `vertex_ml`). Un `cloud_run_api` no la ejecuta: sus datasources son tablas propias.
> El objetivo es que cuando comience PHYSICAL_DESIGN, cada fuente ya tenga documentado su
> campo de partición, volumetría y campos clave — no inventar nada durante el modelado.

---

## Paso 0 — Localizar y cargar el spec

```
1. Si $ARGUMENTS tiene ruta → leer ese archivo
2. Si no → buscar en este orden:
   a. docs/spec.yaml
   b. docs/specs/*.yaml  (si hay varios, listar y pedir al usuario que especifique)
3. Extraer lista de fuentes: spec.fuentes[]
4. Si --only → filtrar solo las fuentes indicadas
```

Leer en paralelo:
```
- deploy/env_dev.json   → para resolver variables ${...} en proyecto/dataset/tabla
- deploy/env_prd.json   → alternativa si env_dev.json no tiene la variable
```

---

## Paso 1 — Resolver tabla canónica de cada fuente

Para cada fuente en `spec.fuentes[]`:

### 1a. Resolver variables `${...}`

Si `proyecto`, `dataset` o `tabla` contienen variables `${project_xxx}`, resolverlas
usando `env_dev.json`. Si no están en env_dev, dejar la variable y marcar como
`tabla_canonica: pendiente_de_resolver`.

```yaml
# Ejemplo de resolución
proyecto: "${project_t_payment}"        → "intercorp-data-storage-pv"   (de env_dev.json)
dataset:  "${dataset_t_payment}"        → "master_transaction"
tabla:    "${table_t_payment}"          → "t_payment"
tabla_canonica: "intercorp-data-storage-pv.master_transaction.t_payment"
```

### 1b. Detectar patrón "Inside Project"

Si `proyecto` sigue el patrón `prd-[empresa]-data-storage-pv` Y `dataset` termina
en `_inside`, decodificar el nombre de la tabla para obtener la tabla canónica:

```
Tabla inside:  prd_itc_data_storage_pv_master_transaction_t_payment
Decodificado:  proyecto=prd-itc-data-storage-pv  dataset=master_transaction  tabla=t_payment
tabla_canonica: "prd-itc-data-storage-pv.master_transaction.t_payment"

Regla:  nombre_vista → reemplazar _ por - hasta tercer segmento (proyecto),
        luego _ por - para el dataset, luego el resto es el nombre de tabla.
        Verificar con INFORMATION_SCHEMA.VIEWS si hay ambigüedad.
```

Registrar en el spec:
```yaml
tabla_canonica:  "intercorp-data-storage-pv.master_transaction.t_payment"
tabla_profiling: "intercorp-data-storage-pv.master_transaction.t_payment"
# Si se hará profiling desde la vista inside o copia dev, cambiar tabla_profiling.
```

---

## Paso 2 — Buscar glosario existente

Para cada fuente con `tabla_canonica` resuelta, buscar en
`data/data_catalog/` del repositorio `itcm-dp-knowledge-base`:

```
Estrategia de búsqueda (en orden):
1. Nombre exacto con guiones:  t_payment → t-payment.md
2. Nombre con guiones bajos:   t_payment.md
3. Prefijo parcial:            archivos que contengan "payment" en el nombre
4. Para tablas inside:         usar el nombre de la tabla canónica resuelta
```

**Si el glosario se encuentra:**
→ Ir a Paso 3 (extraer metadata del glosario)

**Si el glosario NO se encuentra:**
→ Marcar `glosario_status: pendiente`
→ Ir a Paso 4 (generar glosario con profiling)

---

## Paso 3 — Extraer metadata del glosario existente

Leer el archivo de glosario y extraer los siguientes campos para poblar el spec:

```yaml
# Extraer de "## Metadata BigQuery":
particion: {campo_particion}           # ej: payment_date
volumetria: "{filas} · {tamaño} · {frecuencia}"

# Extraer de "## Glosario de Campos" — buscar campos marcados como "clave de join":
campos_join_clave: [lista]

# Extraer de "## Empresas cubiertas":
empresas_cubiertas: [lista de itc_company_id]

# Extraer de "## Reglas de negocio" + "## Observaciones de calidad":
observaciones: >
  {1-3 observaciones más relevantes para el proyecto actual}

# Registrar estado:
glosario_status: generado
glosario_path: "data/data_catalog/{archivo}.md"
tabla_profiling: "{tabla sobre la que se hizo el profiling — leer del encabezado del glosario}"
```

---

## Paso 4 — Generar glosario faltante

Si `glosario_status: pendiente`, ejecutar el flujo completo del skill
`@.claude/data/skills/analysis/data-catalog-bq-generator/SKILL.md` (Pasos 1 a 5) sobre
la `tabla_profiling` indicada:

```
Paso 1: Obtener metadata de la tabla (INFORMATION_SCHEMA)
Paso 2: Determinar estrategia de muestreo (transaccional vs catálogo)
Paso 3: Perfilar datos (volumetría, nulos, distribuciones, DQ flags)
Paso 4: Documentar relaciones con otras tablas
Paso 5: Generar archivo .md en data/data_catalog/
```

> Si no hay acceso a la tabla (`tabla_profiling` no resolvible o sin permisos):
> → marcar `glosario_status: sin_acceso`
> → documentar en `observaciones` qué se sabe de la tabla por el nombre/contexto del spec
> → continuar con las demás fuentes

Una vez generado el glosario, volver a Paso 3 para extraer su metadata al spec.

---

## Paso 5 — Escribir cambios en el spec

Actualizar `spec.fuentes[]` con los campos enriquecidos. Para cada fuente, agregar
los campos si no existen o actualizar si ya están con valor `~`:

```yaml
fuentes:
  - id: t_payment
    descripcion: "Detalle de medios de pago"
    proyecto: "${project_t_payment}"
    dataset: "${dataset_t_payment}"
    tabla: "${table_t_payment}"
    pii: false

    # ── Campos agregados por DISCOVERY ────────────────────────────
    tabla_canonica:  "intercorp-data-storage-pv.master_transaction.t_payment"
    tabla_profiling: "intercorp-data-storage-pv.master_transaction.t_payment"
    glosario_status: generado           # generado | pendiente | sin_acceso | no_aplica
    glosario_path:   "data/data_catalog/t-payment.md"
    particion:       payment_date
    volumetria:      "~2.83B filas · ~928 GB · diaria"
    empresas_cubiertas: [010, 025, 048, 024, 011]
    campos_join_clave:  [payment_date, transaction_id, id, bin_card_id]
    observaciones: >
      payment_type y payment_bank siempre NULL — no usar para segmentación.
      Rezago ETL ~13 días entre payment_date y disponibilidad en BQ.
      Usar bin_card_id → c_bin_card para identificar banco emisor.
```

---

## Paso 6 — Reportar resumen al usuario

Al finalizar, mostrar tabla resumen:

```
┌─────────────────────────────┬───────────────────────────────────────────────┬──────────────────┐
│ Fuente                      │ Tabla canónica                                │ Glosario         │
├─────────────────────────────┼───────────────────────────────────────────────┼──────────────────┤
│ tee_trn_retail_spsa         │ prd-spsa-data-storage-pv.spsa_inside.tee_...  │ ✅ generado       │
│ iden_itc_party              │ intercorp-data-storage-pv.master_party.iden.. │ ✅ existía        │
│ attr_demographic            │ intercorp-data-storage-pv.bi_itc_attr...      │ ✅ existía        │
│ attr_insurance              │ intercorp-data-storage-pv.bi_itc_attr...      │ ⚠️ sin_acceso    │
│ attr_payment_pos            │ pendiente_de_resolver (${project_...} vacío)  │ ⏳ pendiente      │
└─────────────────────────────┴───────────────────────────────────────────────┴──────────────────┘

Spec actualizado: docs/specs/spec-itc-20260330-001.yaml
Glosarios generados: 1 nuevo  |  2 existentes reutilizados  |  1 sin acceso  |  1 pendiente

⚠️  Fuentes pendientes o sin acceso — revisar antes de /data:implement-stage PHYSICAL_DESIGN:
  - attr_insurance: solicitar acceso a intercorp-data-storage-pv.bi_itc_attribute_party
  - attr_payment_pos: completar variable ${project_ba_itc_attr_payment_pos} en env_dev.json
```

---

## Notas

- **No sobreescribir** campos del spec que ya tengan valor distinto de `~` sin confirmación
- **Si `--only`** fue especificado, reportar solo las fuentes procesadas
- **Tablas sin `itc_company_id`** (fuentes externas, Google Ads, etc.): marcar
  `glosario_status: no_aplica` y documentar brevemente en `observaciones`
- **Para tablas de usuario** (dataset `[usuario]_inside`): registrar tanto la vista
  como la tabla canónica — el profiling se hace sobre la que tenga acceso


