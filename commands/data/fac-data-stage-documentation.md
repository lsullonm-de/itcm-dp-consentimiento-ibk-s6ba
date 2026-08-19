# fac-data-stage-documentation — Documentación

Genera el catálogo de datos del proceso, los diagramas de arquitectura, el glosario de campos y
el README del repo. Cierra el bloque RELEASE.

**Bloque:** RELEASE — último paso

**Invocación:**
```
fac-data-stage-documentation
fac-data-stage-documentation {id_modulo}
```

---

## Prerequisito

SECURITY completado. Todos los artefactos de código finales en su lugar.

---

## Paso 0 — Determinar módulo

**Si existe `project.manifest.yaml`:**
1. Si se pasó `{id_modulo}` → usar ese módulo
2. Si no → buscar módulo con `etapa_actual: DOCUMENTATION`
3. Si hay ambigüedad → listar módulos activos y pedir al usuario

**Si NO existe `project.manifest.yaml`:**
→ Usar `docs/specs/*.yaml` directamente.

---

## Paso 1 — Actualizar glosario

Crear o actualizar `data/standard/business-glossary/{tabla}.md` con todas las columnas del output.
Para cada campo: nombre, tipo BQ, descripción, fuente, regla de negocio, PII (sí/no).

---

## Paso 2 — Generar / actualizar catálogo de datos

Usando el skill `@.claude/data/skills/analysis/data-catalog-bq-generator/SKILL.md`,
generar o actualizar el catálogo en `data/data_catalog/{dataset}/{tabla-con-guiones}.md`.

Incluir:
- Metadata BigQuery (schema, particionado, clustering, volúmenes)
- Diccionario de campos
- Reglas de negocio aplicadas
- Observaciones de calidad detectadas en TESTING

---

## Paso 3 — Generar los diagramas de arquitectura

```
fac-data-diagrams {id_modulo}
```

Genera los diagramas aplicables al `type` y regenera los que quedaron desfasados. Es el momento
correcto para hacerlo: el código final ya existe, así que los diagramas describen lo construido
y no una intención de diseño que pudo cambiar durante BUILD.

Si el módulo ya tenía diagramas de una versión anterior, el comando preserva las secciones
manuales (decisiones de diseño, notas del equipo) y solo reemplaza los bloques Mermaid.

---

## Paso 4 — Actualizar README del repo

Agregar sección con:
- Descripción del proceso
- Tablas fuente y tabla output
- Frecuencia de ejecución
- SAs implicadas
- Etapas activas del spec

---

## Paso 5 — Actualizar docs/TODO.md

Marcar DOCUMENTATION como completado y el módulo como terminado.

```
## Etapa completada: DOCUMENTATION
✅ Módulo {id_modulo} completo — listo para merge/deploy trigger prd
```

Si hay `project.manifest.yaml`, actualizar:
```yaml
modules[{id_modulo}].status: done
modules[{id_modulo}].etapa_actual: DONE
```

---

## Reporte

```
## Etapa completada: DOCUMENTATION
SPEC: {id}  |  módulo: {id_modulo}

### Artefactos creados
- ✅ data/standard/business-glossary/{tabla}.md  (glosario de campos)
- ✅ data/data_catalog/{dataset}/{tabla}.md       (catálogo de datos)
- ✅ architecture/: {n} diagramas generados o sincronizados
- ✅ README.md: sección del proceso actualizada
- ✅ docs/TODO.md: módulo marcado como completo

### 🏁 Ciclo completo — listo para merge/deploy trigger prd
```
