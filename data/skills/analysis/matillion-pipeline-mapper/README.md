# Matillion Pipeline Mapper

Herramienta 100% standalone que analiza exportaciones JSON de Matillion ETL y genera **3 documentos Markdown estructurados** para el análisis completo del pipeline.

## Uso Rápido

```bash
python mapper.py --input path/to/export.json
```

Genera 3 documentos en `temporal/{json-stem}/`:
1. `logica-negocio-{stem}.md` — Estadísticas, tablas, variables, jobs, flujo
2. `sql-statements-{stem}.md` — SQLs completos organizados por tipo y empresa
3. `orchestration-map-{stem}.md` — Mapa de ejecución, fases, timeline, dependencias

## Con Directorio Personalizado

```bash
python mapper.py --input export.json --output analysis/
```

Output: `analysis/{json-stem}/*.md`

## Requisitos

- Python 3.10+
- **Sin dependencias externas** (solo stdlib: json, argparse, re, pathlib, typing, collections)

## Output

### Documento 1: Lógica de Negocio
- Estadísticas (jobs, componentes, variables)
- Tablas input/output detectadas
- Variables clave
- Listado de jobs
- Patrones SQL
- Diagrama de flujo ASCII

### Documento 2: SQL Statements
- Índice de SQLs por tipo y empresa
- SQLs completos sin truncación (listos para copiar/pegar)
- Cabeceras `[EMPRESA]` en cada bloque
- Resumen por empresa
- Análisis de tablas

### Documento 3: Mapa de Orquestación
- Visión general del pipeline
- 4 fases de ejecución (Inicialización, Transformación, Orquestación, Finalización)
- Timeline estimado
- Matriz de ejecución dinámico
- Dependencias y sincronización
- Análisis de recursos

## Ejemplo

```bash
# Con el JSON principal
python mapper.py --input temporal/jorch_master_party_g01_daily_ba_contact.json

# Output: 3 documentos en temporal/jorch-master-party-g01-daily-ba-contact/
# - logica-negocio-jorch-master-party-g01-daily-ba-contact.md
# - sql-statements-jorch-master-party-g01-daily-ba-contact.md
# - orchestration-map-jorch-master-party-g01-daily-ba-contact.md
```

## Características

✅ **100% Standalone** — Sin dependencias, preprocesador integrado
✅ **Empresa Mapping Completo** — 17 códigos de empresas (FOH, PMART, SPSA, RPLA, INDG, OEC, ITER, FAR, CPLT, FPER, UTP, IZIPAY, VEA, OECHSLE, etc.)
✅ **SQL Extraction Dual-Mode** — Soporta formato plano y anidado del JSON Matillion
✅ **Dinámico** — No hardcodea IDs de jobs, analiza el JSON real
✅ **Rápido** — Archivos de ~50 MB en 10-30 segundos
✅ **Nombres en Minúsculas** — Todos los archivos de salida con guiones medios en lugar de guiones bajos

## Documentación Completa

Ver `SKILL.md` para:
- Instalación detallada
- Uso avanzado
- Estructura completa de documentos
- Integración con factory flow
- FAQ
