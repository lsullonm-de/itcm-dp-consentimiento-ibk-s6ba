# fac-data-stage-data-quality — Calidad de Datos

Implementa las reglas DQ del spec como SP ejecutable y genera los registros de configuración
para el framework `itcm-dp-dataquality-core`.

**Bloque:** BUILD — después de ORCHESTRATION y MONITORING
**Condición:** aplica principalmente a `bq_pipeline`. Se activa con `etapas.data_quality: true`.

> Estándar: `@.claude/data/standard/data-quality.md`

**Invocación:**
```
fac-data-stage-data-quality
fac-data-stage-data-quality {id_modulo}
```

---

## Prerequisito — Verificar scaffold

Verificar que `fac-data-init-project` fue ejecutado:
```
docs/TODO.md · docs/specs/ · deploy/env_dev.json · data/bigquery/{dataset_out}/{tabla_out}/
```

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: DATA_QUALITY`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

Verificar que `etapas.data_quality: true` en el spec antes de continuar.

---

## Paso 1 — Leer contexto

Leer en paralelo:
```
1. {ruta del spec.yaml}                                            → reglas DQ del bloque data_quality.reglas
2. deploy/env_dev.json                                             → variables de despliegue
3. data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql → skeleton DQ existente (de init-project)
```

---

## Paso 2 — Completar SP DQ

Completar `data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql` (único, valida la
tabla final ya mergeada) con el patrón estándar:

```sql
CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_dq_{tabla_out}`()
BEGIN
  DECLARE v_config_id STRING;
  DECLARE v_invalid_count INT64;
  DECLARE v_total_count INT64;

  FOR rule IN (
    SELECT dq_config_id, sql_rule, umbral_max_pct_invalidos, is_critical
    FROM `${project_analytics}.${dataset_dq}.dq_config`
    WHERE tabla = '{tabla}'
      AND is_active = true
  )
  DO
    -- Ejecutar regla y registrar resultado
    -- Ver patrón completo: @.claude/data/standard/data-quality.md
  END FOR;
END;
```

Ver: `@.claude/data/standard/data-quality.md` — patrón completo con INSERT en `dq_control`.

---

## Paso 3 — Generar registros `dq_config`

Para cada regla DQ del spec, generar el INSERT correspondiente en
`data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_config_{tabla_out}.sql` (único — nunca un
INSERT suelto sin archivo destino):

```sql
-- DQ Config: {tabla_out}
-- Ejecutar en dev para registrar las reglas
INSERT INTO `${project_analytics}.${dataset_dq}.dq_config`
  (dq_config_id, tabla, dimension, tipo, campo, critica, umbral_max_pct_invalidos, sql_rule, is_active)
VALUES
  ('{DQ-ITC-TABLA-001}', '{tabla_out}', 'completitud', 'technical', '{campo}', true, 0,
   '{sql_rule del spec}', true),
  -- ... resto de reglas
```

Si el spec declara monitores (`dq_monitor_config`), generarlos en
`data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_monitor_config_{tabla_out}.sql` (único).

---

## Paso 4 — Actualizar docs/TODO.md

```
## Etapa completada: DATA_QUALITY
→ Próximo paso: fac-data-stage-lineage (si aplica) o fac-data-stage-dataops
```

---

## Reporte

```
## Etapa completada: DATA_QUALITY
SPEC: {id}  |  type: {type}  |  módulo: {id_modulo}

### Artefactos modificados
- ✅ data/bigquery/{dataset_out}/{tabla_out}/sp/sp_dq_{tabla_out}.sql    (SP DQ con lógica completa)
- ✅ data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_config_{tabla_out}.sql  (INSERTs de reglas)
- ✅ data/bigquery/{dataset_out}/{tabla_out}/dml/dml_dq_monitor_config_{tabla_out}.sql  (si aplica)
- ✅ docs/TODO.md: ítems de DATA QUALITY marcados

### Próxima etapa
fac-data-stage-lineage {id_modulo}   (si etapas.lineage: true)
fac-data-stage-dataops {id_modulo}   (si etapas.lineage: false)
```
