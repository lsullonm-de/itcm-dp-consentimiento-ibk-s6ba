# fac-data-phase-design — Diseño

Ejecuta las sub-etapas de DESIGN **que apliquen al módulo**. No es un bloque fijo: DISCOVERY
depende del `type` y la fase entera se puede saltar cuando el cambio es una extensión de un
módulo ya construido.

**Prerequisito:** spec validado (`fac-data-spec-validate`) en status `review` o `approved`, y
scaffold listo (`fac-data-init-project`).

---

## Paso 0 — Decidir si esta fase aplica

### Por naturaleza del cambio

| Situación | DESIGN |
|---|---|
| Módulo **nuevo** | Aplica — ver matriz por `type` |
| **Extensión** de un módulo ya construido (tabla o endpoint nuevo sobre una arquitectura vigente) | Solo `fac-data-stage-physical-design` para el contrato de datos nuevo. Ir directo a BUILD después |
| Cambio que no toca el modelo de datos (lógica, umbrales, scheduling) | No aplica — ir a BUILD |

### Por `type`

| Sub-etapa | `bq_pipeline` | `vertex_ml` | `cloud_run_api` | `cloud_function` |
|---|---|---|---|---|
| DISCOVERY | ✅ obligatoria | ✅ obligatoria | ⊘ N/A — no hay `fuentes[]`, los datasources son propios | ⊘ N/A salvo que lea tablas existentes |
| PHYSICAL_DESIGN | ✅ | ✅ | ✅ (DDL PostgreSQL) | ✅ si escribe tablas |

> Los **diagramas de arquitectura ya no son parte de DESIGN.** Se generan al cierre, en
> DOCUMENTATION, con `fac-data-diagrams`. Un diagrama hecho antes de construir queda
> desactualizado apenas la construcción se desvía del diseño; hecho al final refleja lo que
> realmente se construyó. Si necesitas un boceto para discutir con el equipo, corre
> `fac-data-diagrams` suelto — pero no como puerta de entrada a BUILD.

Reportar explícitamente qué sub-etapas se omiten y por qué antes de ejecutar.

---

## ── BLOQUE DESIGN ─────────────────────────────────────────────────

### Paso 1 — DISCOVERY (si aplica según la matriz)

```
fac-data-stage-discovery
```

- Resolver tablas canónicas de cada fuente en `spec.fuentes[]`
- Buscar glosarios existentes en `data/data_catalog/`
- Si no existe glosario → ejecutar profiling con `data-catalog-bq-generator`
- Enriquecer `spec.fuentes[]` con: `tabla_canonica`, `particion`, `volumetria`,
  `empresas_cubiertas`, `campos_join_clave`
- Fuente: `@.claude/commands/data/fac-data-stage-discovery.md`

> Es la sub-etapa que evita diseñar contra supuestos falsos. Si el módulo tiene fuentes, no se salta.

### Paso 2 — PHYSICAL_DESIGN

```
fac-data-stage-physical-design
```

- Contrato de datos: DDL físico con columnas, tipos, constraints, llaves e índices
- BigQuery (`bq_pipeline`, `vertex_ml`) o PostgreSQL (`cloud_run_api`)
- Declarar los DDL en `componentes[]` del spec
- **No** genera skeletons de código — eso lo crea CODING
- Fuente: `@.claude/commands/data/fac-data-stage-physical-design.md`

### Paso 3 — Sync TODO

```
fac-data-sync-todo
```

Marcar las sub-etapas ejecutadas y dejar registradas las omitidas con su motivo.

---

## Reporte Final

| Sub-etapa | Estado | Observaciones |
|-----------|--------|---------------|
| DISCOVERY | ✅/⊘ N/A | Fuentes procesadas: N — o el motivo de la omisión |
| PHYSICAL_DESIGN | ✅ | DDL creados: N |

> Próximo paso: `fac-data-stage-reality-check` y luego `fac-data-phase-build`
