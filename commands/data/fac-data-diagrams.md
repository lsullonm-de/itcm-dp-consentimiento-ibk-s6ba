# fac-data-diagrams — Generar o Sincronizar Diagramas de Arquitectura

Genera los diagramas de `architecture/` que falten y regenera los que quedaron desfasados
respecto al `spec.yaml`, preservando las notas manuales del equipo.

**Bloque:** RELEASE — lo invoca `fac-data-stage-documentation`. También se puede correr suelto
como mantenimiento cuando el spec cambia.

> **Por qué al final y no en DESIGN:** los diagramas se derivan del spec, no lo alimentan.
> Generarlos antes de construir garantiza que queden mintiendo apenas la construcción se
> desvía del diseño. Al cierre reflejan lo que realmente se construyó.

**Invocación:**
```
fac-data-diagrams                  ← módulo del directorio actual, solo lo que falta o cambió
fac-data-diagrams {id_modulo}      ← módulo específico del project.manifest.yaml
fac-data-diagrams --all            ← regenera todo sin comparar
```

---

## Paso 0 — Cargar el estándar y los templates

```
@.claude/data/skills/design/architecture-diagrams/SKILL.md                        ← notación Mermaid, reglas de estilo
@.claude/data/skills/design/architecture-diagrams/references/itc-spec-templates.md ← los 6 templates + matriz por type
```

> Los templates viven **solo** ahí. Este comando no los duplica.

---

## Paso 1 — Leer estado actual

Leer en paralelo:
```
1. {ruta del spec.yaml}     → spec_id, version, type y todos los bloques
2. architecture/*.md        → cabecera «Generado desde: {spec_id} v{version}» de cada diagrama
3. project.manifest.yaml    → si existe
```

Determinar los diagramas aplicables con la matriz por `type` del archivo de templates.

---

## Paso 2 — Decidir qué se genera y qué se regenera

| Situación | Acción |
|---|---|
| Diagrama aplicable que no existe | **Generar** |
| Existe con `version` menor a la del spec | **Regenerar** solo si algún campo que lo alimenta cambió (tabla de impacto) |
| Existe sin cabecera de metadata | **Regenerar** completo |
| Existe y su versión coincide | Omitir |
| `--all` | Regenerar todos |

### Tabla de impacto — qué campo afecta a qué diagrama

| Campo del spec modificado | Diagramas afectados |
|---|---|
| `fuentes[]` / `datasources` — agregar, quitar, renombrar | context, data-flow, component, sequence |
| `fuentes[].volumetria` | context |
| `outputs[]` — tabla, tipo_carga, particion, capa | context, data-flow, component |
| `endpoints[]` — agregar o quitar | context, component, sequence |
| `componentes[]` — agregar o quitar | component, sequence, deployment |
| `pipelines.*.componentes_kfp` | pipeline, sequence |
| `pipelines.*.machine_type` / `frecuencia` | pipeline, component |
| `scheduling.frecuencia` | component, sequence, deployment |
| `scheduling.dependencias[]` | sequence |
| `scheduling.consumidores[]` | context, sequence |
| `modelo.*` | component, pipeline, deployment |
| `etapas.integridad` / `etapas.data_quality` / `etapas.monitoring` | component, sequence, data-flow |
| `contexto.*` | context |
| `version` del spec | todos — al menos actualizar la cabecera |

Mostrar el plan (qué se genera, qué se regenera, qué se omite y por qué) antes de escribir.

---

## Paso 3 — Escribir

Por cada diagrama a generar o regenerar:

1. Si el archivo existe, leerlo completo e identificar las **secciones manuales**: todo lo que
   esté fuera del bloque ` ```mermaid ``` ` y fuera de la cabecera de metadata — decisiones de
   diseño, notas del equipo, tablas de contexto
2. Aplicar el template correspondiente con los valores actuales del spec
3. **Reemplazar solo el bloque Mermaid** — las secciones manuales se conservan intactas
4. Actualizar la cabecera con `spec_id`, `version` y fecha de hoy

Ubicación: `architecture/` en la raíz del repo, o `docs/architecture/{id_modulo}/` si el repo
agrupa por módulo (respetar la convención que ya use el repo).

---

## Paso 4 — Verificación cruzada

| Verificación | Qué comparar |
|---|---|
| Fuentes consistentes | Las mismas fuentes en context, data-flow y sequence |
| Componentes completos | Todo `componentes[]` del spec aparece en component |
| Etapas coherentes | Si `integridad`/`data_quality`/`monitoring` están activas, sus pasos aparecen en component y sequence; si no, no aparecen |
| Pasos KFP alineados | pipeline-diagram coincide con el paso Vertex de sequence |
| Consumidores | `scheduling.consumidores` presentes en context y sequence |

Si algo no cuadra → corregir y reportarlo.

---

## Paso 5 — Actualizar `docs/TODO.md`

```markdown
- {YYYY-MM-DD}: Diagramas sincronizados — spec v{anterior} → v{actual}. {resumen}.
```

---

## Reporte

```
## fac-data-diagrams — {contexto.nombre}
Spec: {spec_id} v{version}  |  type: {type}

### Generados
- ✅ {archivo}   (no existía)

### Regenerados
- ✏️ {archivo}   (cambió: {campos})

### Sin cambios
- ⏭️ {archivo}

### Notas manuales preservadas
- {archivo}: sección "{título}" — sin tocar
```
