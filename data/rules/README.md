# Reglas de Desarrollo — Dominio Data

> Reglas técnicas para el desarrollo de pipelines de datos en BigQuery / GCP.
> Desacopladas por dominio para que el `compliance-reviewer` las cargue selectivamente.
> Aplican a todos los módulos del flujo de fábrica.

| Archivo | Contenido |
|---|---|
| [bigquery.md](./bigquery.md) | DDL, SP, naming, particiones, clustering, variables |
| [security.md](./security.md) | Operaciones destructivas (`DROP TABLE`, `DELETE` sin `WHERE`), PII, SAs, secrets, autenticación |
| [workflow.md](./workflow.md) | Cloud Workflows: `set_vars`, `SyncBigQueryJob`, logging, estructura del archivo |
| [dataops.md](./dataops.md) | Variables de despliegue, deploy configs, scheduler, ambientes |
| [general.md](./general.md) | Idempotencia, naming, capas de datos, documentación del código |

---

## Cómo se usan estas reglas

El comando `/check-rules` y el skill `@.claude/data/skills/verify/compliance-reviewer/SKILL.md`
cargan estos archivos para auditar el código antes de pasar a RELEASE.

```
/check-rules          ← audita todas las reglas
/check-rules bigquery ← audita solo las reglas BigQuery
```
