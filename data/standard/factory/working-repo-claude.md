# CLAUDE.md — Template para Repositorio de Trabajo

> **Uso:** Este archivo es el template de `CLAUDE.md` para cualquier repositorio que use
> el flujo de fábrica ITC. El `install.sh` lo genera (o fusiona) en la raíz del repo de trabajo.
> Reemplazar `{REPO_NAME}` y `{REPO_DESCRIPTION}` con los valores del repo.

---

## Contenido a incluir en el CLAUDE.md del repo de trabajo

```markdown
# CLAUDE.md — {REPO_NAME}

{REPO_DESCRIPTION}

---

## Base de Conocimiento — Estructura

El flujo de fábrica ITC está instalado en `.claude/`. Estructura:

| Carpeta | Contenido |
|---|---|
| `.claude/commands/data/` | Comandos del flujo de fábrica (`fac-data-phase-build`, `fac-data-stage-coding`, etc.) |
| `.claude/data/skills/` | Skills especializados por etapa |
| `.claude/data/standard/` | Estándares técnicos (BigQuery, GCP, arquitectura, factory) |
| `.claude/data/rules/` | Reglas de validación (SQL, YAML, Python, seguridad) |

Todos los archivos referenciados en los comandos como `@.claude/data/...` se leen desde
`.claude/data/` en este repositorio.

---

## Convenciones del Repo

- **Proyecto GCP:** `${env}-itc-customer-services`
- **Framework deploy:** `itcm-dp-dataops-build`
- **Framework infra:** `itcm-dp-infraops-build`
- **Spec activo:** `docs/specs/*.yaml`

## Restricciones

- No hacer commits automáticos. Solo el usuario decide cuándo commitear.
- No hardcodear valores de proyecto, dataset o SA en SQL/YAML — usar variables `${...}`.
- No ejecutar comandos InfraOps o Dataops en producción (`prd-*`) directamente.
```

---

## Notas para el `install.sh`

Cuando el `install.sh` despliega el flujo de fábrica en un nuevo repo de trabajo:

1. Copiar `.claude/commands/` desde el KB al repo de trabajo
2. Copiar `.claude/data/` (skills, standard, rules) desde el KB al repo de trabajo
3. Generar o fusionar `CLAUDE.md` en la raíz del repo usando este template
4. Asegurarse de que el `CLAUDE.md` generado incluye la sección **Base de Conocimiento — Estructura**
   para que Claude sepa dónde encontrar skills y estándares
5. Las referencias `@.claude/data/...` en los comandos resolverán correctamente a
   `{workspace_root}/.claude/data/...` en cualquier repo de trabajo

> **Por qué es necesario:** Claude Code resuelve las referencias `@path/...` relativas a la
> raíz del workspace. Los comandos en `.claude/commands/data/` referencian `@.claude/data/skills/...`
> para que resuelvan correctamente a la base de conocimiento instalada en `.claude/data/`,
> y no a la carpeta `data/` del repo (que contiene BigQuery DDL/SPs, no la KB).


