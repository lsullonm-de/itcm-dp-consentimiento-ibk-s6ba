# Skill: BigQuery MCP Validator

> **Rol:** Validador Dinámico de SPs y Tablas — ITC Data Platform
> **Activado por:** `/data:implement-stage TESTING` — después de compliance-reviewer (PASS o PASS con advertencias)
> **Output:** Reporte de testing con resultados de ejecución y veredicto (PASS / FAIL)
>
> **Estándares de referencia:**
> - `@.claude/data/rules/bigquery.md` — reglas de validación de DDL y SPs
> - `@.claude/data/rules/general.md` — idempotencia y campos de auditoría
> - `@.claude/data/standard/architecture/data-platform-layers.md` — campos de auditoría esperados
>
> **Herramienta:** MCP BigQuery — proyecto `dev-*` exclusivamente. **NUNCA ejecutar en `prd-*`.**

---

## 1. Rol y Responsabilidades

El **BigQuery MCP Validator** ejecuta validaciones dinámicas (en tiempo real) sobre los SPs y la estructura de tablas antes del despliegue a producción. Complementa el compliance-reviewer (que es estático) con pruebas que requieren acceso real a BigQuery en dev.

Usa el **MCP de BigQuery** para consultar metadatos de tablas, validar estructuras y ejecutar SPs en entorno `dev` con datos de prueba.

---

## Tipos de Tests

### T1 — Tests de Estructura (DDL)

Verifican que las tablas existen con el schema correcto después de aplicar el DDL.

```sql
-- T1.1: La tabla existe en el dataset correcto
SELECT table_name
FROM `${project_analytics}.${dataset_analytics}.INFORMATION_SCHEMA.TABLES`
WHERE table_name = 'ba_itc_attr_retail'

-- T1.2: Todos los campos del DDL están presentes
SELECT column_name, data_type
FROM `${project_analytics}.${dataset_analytics}.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'ba_itc_attr_retail'
ORDER BY ordinal_position

-- T1.3: La tabla tiene configuración de partición (para tablas t_*)
SELECT partition_column, clustering_columns
FROM `${project_analytics}.${dataset_analytics}.INFORMATION_SCHEMA.TABLE_PARTITIONS`
WHERE table_name = 't_retail_transaction'
LIMIT 1
```

**Veredicto T1:**
- ✅ PASS — tabla existe con todos los campos y partición correcta
- ❌ FAIL — tabla no existe, campos faltantes, o sin partición cuando se requiere

### T2 — Tests Unitarios de SPs

Validan la lógica del SP de forma aislada, con datos de entrada controlados y resultado esperado conocido. Ver estructura completa y casos obligatorios en `implement-stage.md → TESTING → Paso 3`.

Los scripts de test unitario viven en `data/bigquery/{dataset_out}/{tabla_out}/test/
test_sp_{tabla_out}_{emp}.sql` — **se crean en CODING y se ejecutan aquí**.

```bash
# Ejecutar via MCP BigQuery:
bq query --project={dev_project} --use_legacy_sql=false < data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_{tabla_out}_{emp}.sql
```

### T3 — Tests de Ejecución End-to-End (en dev)

Ejecutan cada SP en orden con datos reales de dev y fecha de prueba.

#### T3.1 — SP ejecuta sin error

```sql
CALL `dev-itc-customer-services.stored_procedures.sp_nombre`(
  'dev-itc-customer-services',
  'stage_tmp',
  'analytics',
  '${tabla_entrada_dev}',
  'tmp_mi_ejec',
  DATE '2025-03-01'
);
-- Esperado: ejecución sin error
```

#### T3.2 — Output no vacío

```sql
SELECT COUNT(*) AS total_rows
FROM `dev-itc-customer-services.stage_tmp.tmp_mi_ejec`
WHERE load_date = DATE '2025-03-01'
-- Esperado: total_rows > 0
```

#### T3.3 — Campos de auditoría poblados

```sql
SELECT
  COUNTIF(load_date IS NULL) AS null_load_date,
  COUNTIF(record_source IS NULL) AS null_record_source,
  COUNTIF(creation_user IS NULL) AS null_creation_user
FROM `${project_ba_itc_attr_retail}.${dataset_ba_itc_attr_retail}.${table_ba_itc_attr_retail}`
WHERE load_date = DATE '2025-03-01'
-- Esperado: todos en 0
```

#### T3.4 — Sin duplicados por PK

```sql
SELECT id_intercorp, load_date, COUNT(*) AS cnt
FROM `${project_ba_itc_attr_retail}.${dataset_ba_itc_attr_retail}.${table_ba_itc_attr_retail}`
WHERE load_date = DATE '2025-03-01'
GROUP BY id_intercorp, load_date
HAVING cnt > 1
-- Esperado: 0 filas
```

#### T3.5 — Idempotencia (re-ejecución no duplica)

```sql
-- Ejecutar el SP dos veces con la misma fecha — el COUNT debe ser idéntico
```

### T4 — Tests de Reglas de Negocio

Para cada RN-ITC-* del spec con regla verificable (mappings, rangos, nulos):

```sql
-- T4.1: Valores de estado_civil_encoded en rango esperado (RN-ITC-001)
SELECT DISTINCT estado_civil_encoded
FROM `dev-itc-customer-services.stage_tmp.tmp_mi_ejec_var`
WHERE estado_civil_encoded NOT BETWEEN 1 AND 6
-- Esperado: 0 filas

-- T4.2: Sin nulos en campos críticos de features
SELECT COUNTIF(nse_encoded IS NULL) AS null_nse
FROM `dev-itc-customer-services.stage_tmp.tmp_mi_ejec_var`
-- Esperado: 0
```

### T5 — Tests de Cobertura de Datos

Si el spec define KPIs de cobertura:

```sql
-- T5.1: Cobertura de iden_itc_party > 90% clientes activos (RN-ITC-006)
WITH total AS (SELECT COUNT(DISTINCT id_sandbox) AS total FROM ...),
con_party AS (SELECT COUNT(DISTINCT id_sandbox) AS con FROM ... WHERE iden_itc_party IS NOT NULL)
SELECT ROUND(con / total * 100, 2) AS cobertura_pct FROM total, con_party
-- Esperado: cobertura_pct >= 90
```

### T6 — Verificar Catálogo de Datos

```
Para cada tabla en outputs del spec:
  - Verificar que existe data/glossary/[nombre_tabla].md
  - Si falta: WARNING (no blocker, crear en DOCUMENTATION)
```

---

## Flujo de Ejecución

### Paso 0 — Verificar prerequisito de despliegue (BLOQUEANTE)

Antes de ejecutar cualquier test, verificar vía MCP BigQuery que el trigger Dataops dev ya corrió.

Para cada tabla en `outputs` del spec, ejecutar:

```sql
SELECT COUNT(*) AS existe
FROM `${project_analytics}.${dataset_analytics}.INFORMATION_SCHEMA.TABLES`
WHERE table_name = '{nombre_tabla_output}'
```

**Si alguna tabla no existe → BLOCKED:**
```
❌ TESTING BLOCKED — Prerequisito de despliegue no cumplido

Tabla '{nombre_tabla}' no encontrada en:
  ${project_analytics}.${dataset_analytics}

Acciones requeridas antes de continuar:
  1. Ejecutar trigger InfraOps en dev (crea SAs e IAM)
  2. Ejecutar trigger Dataops en dev (despliega DDL, SPs, servicios)
  3. Verificar que ambos triggers finalizaron con estado SUCCESS
  4. Activar testing: true en el spec
  5. Re-ejecutar /data:implement-stage TESTING
```

**Si todas las tablas existen → continuar con Paso 1.**

### Paso 1 — Leer spec del proceso

Obtener: tablas DDL, SPs con parámetros, RN-ITC-* verificables, KPIs de cobertura, tablas output.

### Paso 2 — Confirmar datos de prueba en dev

- Tablas output existen (ya verificado en Paso 0)
- Tablas fuente tienen datos para la fecha de prueba elegida

### Paso 3 — Ejecutar T1: Tests de estructura

Consultar `INFORMATION_SCHEMA` via MCP BigQuery para cada tabla DDL.

### Paso 4 — Ejecutar T2: Tests unitarios de SPs

Ejecutar cada `data/bigquery/{dataset_out}/{tabla_out}/test/test_sp_{tabla_out}_{emp}.sql` via MCP.

### Paso 5 — Ejecutar T3: Tests end-to-end

Ejecutar SPs en orden (respetando dependencias del spec).

**Fecha de prueba recomendada:** último día hábil del mes anterior.

### Paso 6 — Ejecutar T4: Tests de reglas de negocio

Para cada RN-ITC-* con regla verificable en los datos.

### Paso 7 — Ejecutar T5: Tests de cobertura

Si el spec define KPIs.

### Paso 8 — Verificar T6: Catálogo de Datos

Verificar existencia de `data/glossary/[nombre_tabla].md` para cada output.

### Paso 9 — Generar Reporte

```markdown
## Reporte de Testing — [nombre-proceso] — [fecha]

### Configuración de prueba
- Ambiente: dev
- Fecha de prueba: 2025-03-01
- MCP BigQuery: conectado

### Resultados por tipo

| Tipo | Tests | PASS | FAIL | SKIP |
|---|---|---|---|---|
| T1 — Estructura DDL      | 3 | 3 | 0 | 0 |
| T2 — Tests unitarios SPs | 4 | 4 | 0 | 0 |
| T3 — Ejecución e2e       | 5 | 4 | 1 | 0 |
| T4 — Reglas de negocio   | 3 | 3 | 0 | 0 |
| T5 — Cobertura datos     | 1 | 1 | 0 | 0 |
| T6 — Catálogo de Datos   | 1 | 0 | 0 | 1 |

**Veredicto: ⚠️ PASS con advertencias**

### Fallos
#### T3.2 FAIL — SP sp_prc_retail → tmp_mi_ejec vacío
- SP ejecutado sin error pero la tabla temporal tiene 0 filas para 2025-03-01
- Causa posible: tablas fuente SPSA no tienen datos para esa fecha en dev
- Acción: probar con fecha que tenga datos

### Advertencias
#### T6.1 WARNING — Glosario faltante
- No existe data/glossary/modelo_ingreso_vii_prediccion.md
- Crear antes de pasar a RELEASE (requisito de DOCUMENTATION)
```

### Criterio de paso

| Resultado | Condición |
|---|---|
| ✅ PASS | Todos los T1–T5 pasan |
| ⚠️ PASS con advertencias | T1–T5 pasan, pero hay T6 WARNING (glosario faltante) |
| ❌ FAIL | Al menos 1 fallo en T1, T2, T3, T4 o T5 |

---

## Consideraciones para Vertex ML

Para procesos `vertex_ml`, T3 (ejecución e2e) se reemplaza por **T3-lite**: compilar el pipeline KFP sin ejecutar.

```python
# T3-lite para Vertex ML — compilar sin ejecutar
from kfp import compiler
compiler.Compiler().compile(
    pipeline_func=pipeline_inference,
    package_path="compiled_test.json"
)
# Esperado: sin error de compilación
```

La ejecución real se valida en el primer run de integración en dev post-RELEASE.
