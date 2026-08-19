---
id: data-commands-index
layer: orchestration
level: 2
domain: data
parent: knowledge-router
description: >
  Índice de comandos del dominio DATA. Mapea intenciones del usuario
  a los workflows del flujo de fábrica para la plataforma de datos ITCM.
---

# Comandos DATA — Índice

## Flujo de fábrica

```
PLAN → DESIGN → BUILD → VERIFY → RELEASE
```

DESIGN es **condicional**: depende del `type` del módulo y de si el cambio es un módulo nuevo o
una extensión de uno ya construido. Ver `fac-data-phase-design` — Paso 0.

---

## Comandos Phase — ejecutan un bloque completo

Úsalos cuando quieres avanzar una fase entera sin decidir etapa por etapa.

| Intención del usuario | Comando a cargar |
|---|---|
| "avanza el diseño", "ejecuta la fase DESIGN" | `get_skill("commands/data/fac-data-phase-design")` |
| "construye todo", "ejecuta toda la fase BUILD", "completa BUILD + VERIFY + RELEASE" | `get_skill("commands/data/fac-data-phase-build")` |

---

## Comandos Atómicos — control etapa por etapa

Úsalos cuando el usuario quiere ejecutar una etapa específica.

### PLAN
| Intención | Comando |
|---|---|
| "crea el spec", "nuevo módulo", "nuevo desarrollo" | `get_skill("commands/data/fac-data-spec-create")` |
| "valida el spec", "revisa el spec" | `get_skill("commands/data/fac-data-spec-validate")` |
| "actualiza el spec", "cambia [campo] del spec" | `get_skill("commands/data/fac-data-spec-update")` |
| "inicializa el proyecto", "crea la estructura del repo" | `get_skill("commands/data/fac-data-init-project")` |

### DESIGN
> Condicional. DISCOVERY solo aplica a módulos con `fuentes[]` (`bq_pipeline`, `vertex_ml`).
> PHYSICAL_DESIGN aplica siempre que el cambio toque el modelo de datos.
> Los diagramas ya **no** son parte de DESIGN — se generan en DOCUMENTATION.

| Intención | Comando |
|---|---|
| "mapea las fuentes", "identifica las tablas de origen", "discovery" | `get_skill("commands/data/fac-data-stage-discovery")` |
| "diseña las tablas", "genera el DDL", "physical design", "contrato de datos" | `get_skill("commands/data/fac-data-stage-physical-design")` |

### BUILD
| Intención | Comando |
|---|---|
| "verifica que el spec calce con el repo", "reality check", "revisa antes de construir" | `get_skill("commands/data/fac-data-stage-reality-check")` |
| "implementa CODING", "escribe el SP", "implementa la API" | `get_skill("commands/data/fac-data-stage-coding")` |
| "implementa ORCHESTRATION", "genera el workflow" | `get_skill("commands/data/fac-data-stage-orchestration")` |
| "implementa INTEGRIDAD", "valida integridad de fuentes", "reglas de integridad", "actualidad de la fuente principal" | `get_skill("commands/data/fac-data-stage-integrity")` |
| "implementa MONITORING", "registra el proceso en metadata API" | `get_skill("commands/data/fac-data-stage-monitoring")` |
| "implementa DATA_QUALITY", "agrega reglas DQ" | `get_skill("commands/data/fac-data-stage-data-quality")` |
| "implementa LINEAGE", "registra el linaje de datos" | `get_skill("commands/data/fac-data-stage-lineage")` |
| "implementa DATAOPS", "genera el deploy.json" | `get_skill("commands/data/fac-data-stage-dataops")` |

### VERIFY
| Intención | Comando |
|---|---|
| "verifica cumplimiento", "revisa estándares", "check reglas" | `get_skill("commands/data/fac-data-rules-check")` |
| "implementa COMPLIANCE", "auditoría del código" | `get_skill("commands/data/fac-data-stage-compliance")` |
| "implementa TESTING", "valida en dev" | `get_skill("commands/data/fac-data-stage-testing")` |

### RELEASE
| Intención | Comando |
|---|---|
| "implementa INFRAOPS", "crea las SAs y permisos IAM" | `get_skill("commands/data/fac-data-stage-infraops")` |
| "implementa SECURITY", "revisa seguridad" | `get_skill("commands/data/fac-data-stage-security")` |
| "implementa DOCUMENTATION", "genera la documentación", "cierra el módulo" | `get_skill("commands/data/fac-data-stage-documentation")` |

### MANTENIMIENTO
| Intención | Comando |
|---|---|
| "sincroniza el TODO", "actualiza pendientes" | `get_skill("commands/data/fac-data-sync-todo")` |
| "genera los diagramas", "actualiza los diagramas", "architecture" | `get_skill("commands/data/fac-data-diagrams")` |
