---
id: apps-commands-index
layer: orchestration
level: 2
domain: apps
parent: knowledge-router
description: >
  Índice de comandos del dominio APPS. Mapea intenciones del usuario
  a los workflows del flujo de fábrica para aplicaciones y servicios ITCM.
---

# Comandos APPS — Índice

## Flujo de fábrica

```
PLAN → BUILD → VERIFY → RELEASE
```

---

## Comandos Bulk — ejecutan un bloque completo

| Intención del usuario | Comando a cargar |
|---|---|
| "crea los specs de varios endpoints/componentes", "spec masivo" | `get_skill("commands/apps/bulk-spec")` |
| "implementa todos los specs pendientes en paralelo" | `get_skill("commands/apps/bulk-implement-par")` |
| "implementa todos los specs en secuencia" | `get_skill("commands/apps/bulk-implement-seq")` |
| "evalúa calidad de todo el módulo" | `get_skill("commands/apps/bulk-quality")` |

---

## Comandos Atómicos — control etapa por etapa

### PLAN
| Intención | Comando |
|---|---|
| "crea el spec", "nuevo endpoint", "nuevo componente", "nueva feature" | `get_skill("commands/apps/spec-create")` |
| "valida el spec", "revisa el spec técnico" | `get_skill("commands/apps/spec-validate")` |
| "actualiza el spec", "modifica el spec de [X]" | `get_skill("commands/apps/spec-update")` |
| "crea el spec del agente IA", "spec de agente conversacional" | `get_skill("commands/apps/agent-spec-phase")` |
| "inicializa el proyecto API", "scaffold API NestJS/FastAPI" | `get_skill("commands/apps/init-project-api")` |
| "inicializa el proyecto frontend", "scaffold React" | `get_skill("commands/apps/init-project-frontend")` |

### BUILD
| Intención | Comando |
|---|---|
| "implementa el spec", "genera el código", "codifica [feature]" | `get_skill("commands/apps/spec-code")` |
| "implementa el agente", "construye el agente IA" | `get_skill("commands/apps/agent-impl-phase")` |
| "implementa el pipeline de datos del spec" | `get_skill("commands/apps/spec-pipeline")` |

### VERIFY
| Intención | Comando |
|---|---|
| "valida el código generado", "revisa la implementación vs spec" | `get_skill("commands/apps/spec-code-validate")` |
| "verifica estándares", "check de reglas" | `get_skill("commands/apps/rules-check")` |
| "crea las reglas del proyecto", "inicializa claude_workspace/rules" | `get_skill("commands/apps/rules-create")` |
| "genera tests e2e", "pruebas playwright" | `get_skill("commands/apps/playwright-e2e")` |
| "mide la cobertura de tests" | `get_skill("commands/apps/test-coverage")` |

### RELEASE / MANTENIMIENTO
| Intención | Comando |
|---|---|
| "actualiza los diagramas C4", "regenera arquitectura" | `get_skill("commands/apps/c4-update-diagrams")` |
| "inicializa la documentación API" | `get_skill("commands/apps/init-docs-api")` |
| "inicializa la documentación frontend" | `get_skill("commands/apps/init-docs-frontend")` |
| "sincroniza el TODO", "actualiza pendientes" | `get_skill("commands/apps/sync-todo")` |
