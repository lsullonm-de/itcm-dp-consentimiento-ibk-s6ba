#!/usr/bin/env python3
"""
Matillion Pipeline Mapper
Analiza exportaciones JSON de Matillion y genera 3 documentos Markdown:
1. logica-negocio-{stem}.md — Resumen de pipeline, tablas, variables, flujo
2. sql-statements-{stem}.md — SQLs organizados por tipo y empresa
3. orchestration-map-{stem}.md — Mapa de ejecución, fases, timeline, dependencias
"""

import json
import argparse
import re
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
from datetime import datetime


# ─── PREPROCESADOR MATILLION (STANDALONE) ────────────────────────────────

_COMPONENT_NOISE_KEYS = {
    "x", "y", "width", "height",
    "inputCardinality", "outputCardinality",
    "connectorHint", "executionHint",
    "inputConnectorIDs", "outputConnectorIDs",
    "outputSuccessConnectorIDs", "outputFailureConnectorIDs",
    "outputUnconditionalConnectorIDs", "outputTrueConnectorIDs",
    "outputFalseConnectorIDs", "outputIterationConnectorIDs",
    "inputIterationConnectorIDs",
    "exportMappings", "expectedFailure", "activationStatus",
}


def _extract_job_map(node: dict, result: dict | None = None) -> dict[int, dict]:
    """Recorre jobsTree recursivamente y construye mapa {job_id: {name, type}}."""
    if result is None:
        result = {}
    for job in node.get("jobs", []):
        result[job["id"]] = {
            "name": job["name"],
            "type": job["type"],
        }
    for child in node.get("children", []):
        _extract_job_map(child, result)
    return result


def _flatten_parameters(params: dict) -> dict[str, Any]:
    """Convierte parámetros anidados de Matillion a {name: value(s)}."""
    flat = {}
    for _slot_key, param in params.items():
        name = param.get("name", f"param_{_slot_key}")
        elements = param.get("elements", {})
        values = []
        for _elem_key, elem in elements.items():
            for _val_key, val_obj in elem.get("values", {}).items():
                values.append(val_obj.get("value"))
        if len(values) == 1:
            flat[name] = values[0]
        elif values:
            flat[name] = values
    return flat


def _clean_component(comp_id: str, comp: dict) -> dict:
    """Elimina campos de ruido de componente y aplana sus parámetros."""
    clean = {"component_id": comp_id}
    for key, value in comp.items():
        if key in _COMPONENT_NOISE_KEYS:
            continue
        if key == "parameters":
            clean["parameters"] = _flatten_parameters(value)
        else:
            clean[key] = value
    return clean


def preprocess_matillion_export(raw: dict) -> dict:
    """Preprocesa exportación Matillion: aplana parámetros, elimina ruido UI."""
    job_map = _extract_job_map(raw.get("jobsTree", {}))
    variables = raw.get("variables", [])

    orch_jobs = []
    for job in raw.get("orchestrationJobs", []):
        info = job_map.get(job["id"], {"name": f"orch_{job['id']}", "type": "ORCHESTRATION"})
        clean_comps = {cid: _clean_component(cid, c) for cid, c in job.get("components", {}).items()}
        orch_jobs.append({
            "job_id": job["id"],
            "job_name": info.get("name", f"orch_{job['id']}"),
            "components": clean_comps,
        })

    trans_jobs = []
    for job in raw.get("transformationJobs", []):
        info = job_map.get(job["id"], {"name": f"trans_{job['id']}", "type": "TRANSFORMATION"})
        clean_comps = {cid: _clean_component(cid, c) for cid, c in job.get("components", {}).items()}
        trans_jobs.append({
            "job_id": job["id"],
            "job_name": info.get("name", f"trans_{job['id']}"),
            "components": clean_comps,
        })

    return {
        "job_map": {str(k): v for k, v in job_map.items()},
        "variables": variables,
        "orchestration_jobs": orch_jobs,
        "transformation_jobs": trans_jobs,
    }


# ─── PERIODICIDAD DETECTION ─────────────────────────────────────────────

PERIODICITY_MAP = {
    "diario":      ("Diario",      "Todos los días"),
    "diaria":      ("Diario",      "Todos los días"),
    "semanal":     ("Semanal",     "Una vez por semana"),
    "quincenal":   ("Quincenal",   "Cada 15 días"),
    "mensual":     ("Mensual",     "Una vez por mes"),
    "bimestral":   ("Bimestral",   "Cada 2 meses"),
    "trimestral":  ("Trimestral",  "Cada 3 meses"),
    "semestral":   ("Semestral",   "Cada 6 meses"),
    "anual":       ("Anual",       "Una vez por año"),
    "semanal":     ("Semanal",     "Una vez por semana"),
    "oncemandato": ("On-demand",   "Ejecución manual / por evento"),
    "ondemand":    ("On-demand",   "Ejecución manual / por evento"),
}


def _detect_periodicity(stem: str) -> Tuple[str, str]:
    """Detecta periodicidad desde el nombre del archivo JSON.
    Retorna (label, descripción) o ('Mensual', ...) como default."""
    stem_lower = stem.lower().replace("-", "_")
    for keyword, (label, desc) in PERIODICITY_MAP.items():
        if keyword in stem_lower:
            return label, desc
    return "Mensual", "Una vez por mes (inferido por defecto)"


# ─── EMPRESA MAPPING ─────────────────────────────────────────────────────

COMPANY_MAP = {
    'foh': 'FOH', 'pmart': 'PMART', 'promart': 'PMART',
    'rpla': 'RPLA', 'indg': 'INDG', 'oe': 'OE', 'oec': 'OEC',
    'iter': 'ITER', 'iterar': 'ITER', 'spsa': 'SPSA',
    'fper': 'FPER', 'farmacias': 'FAR', 'cplt': 'CPLT', 'utp': 'UTP',
    'izipay': 'IZIPAY', 'vea': 'VEA', 'oechsle': 'OECHSLE',
}


def detect_company(sql: str) -> str:
    """Detecta empresa del SQL statement mediante 4 estrategias regex."""
    if not sql:
        return "UNKNOWN"

    sql_upper = sql.upper()

    # 1. Buscar en nombres de procesos
    process_match = re.search(r"process_name\s*=\s*['\"]jtrans_master_party_(\w+)_", sql_upper, re.IGNORECASE)
    if process_match:
        code = process_match.group(1).lower()
        return COMPANY_MAP.get(code, code.upper())

    # 2. Buscar en joins ($T{...._seed})
    join_match = re.search(r"\(\$T\{(\w+)_seed\}\)", sql, re.IGNORECASE)
    if join_match:
        code = join_match.group(1).lower()
        return COMPANY_MAP.get(code, code.upper())

    # 3. Buscar en tablas de entrada
    table_match = re.search(r"from\s+\(\$T\{(\w+)_", sql, re.IGNORECASE)
    if table_match:
        code = table_match.group(1).lower()
        return COMPANY_MAP.get(code, code.upper())

    # 4. Buscar en referencias de variables
    var_match = re.search(r"\$\{prm_.*?(\w+).*?\}", sql)
    if var_match:
        code = var_match.group(1).lower()
        if code in COMPANY_MAP:
            return COMPANY_MAP[code]

    return "UNKNOWN"


# ─── SQL EXTRACTION ─────────────────────────────────────────────────────

def _extract_sql(component: Dict) -> Optional[str]:
    """Extrae SQL completo de componente. Soporta formato plano y anidado."""
    params = component.get("parameters", {})

    # Formato plano (post-preprocesador)
    for param_key, param_value in params.items():
        if isinstance(param_value, str) and len(param_value) > 30:
            if any(kw in param_value.upper() for kw in ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "MERGE"]):
                return param_value

    # Formato anidado (raw JSON)
    for param_key, param_value in params.items():
        if isinstance(param_value, dict) and "elements" in param_value:
            for elem in param_value["elements"].values():
                if isinstance(elem, dict) and "values" in elem:
                    for val_obj in elem["values"].values():
                        if isinstance(val_obj, dict):
                            value = val_obj.get("value", "")
                            if isinstance(value, str) and len(value) > 30:
                                if any(kw in value.upper() for kw in ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "MERGE"]):
                                    return value

    return None


def _extract_tables_from_sql(sql: str) -> Tuple[set, set]:
    """Extrae tablas de lectura y escritura del SQL."""
    if not sql:
        return set(), set()

    read_tables = set()
    write_tables = set()

    # Lectura (FROM, JOIN)
    from_matches = re.findall(r'(?:FROM|JOIN)\s+(?:[`]([^`]+)[`]|([a-zA-Z0-9_.-]+))', sql, re.IGNORECASE)
    for backtick_match, normal_match in from_matches:
        t = backtick_match or normal_match
        if t and '$' not in t and '{' not in t:
            read_tables.add(t.split('.')[-1])

    # Escritura (INTO, UPDATE, CREATE TABLE)
    update_matches = re.findall(r'UPDATE\s+(?:[`]([^`]+)[`]|([a-zA-Z0-9_.-]+))', sql, re.IGNORECASE)
    for backtick_match, normal_match in update_matches:
        t = backtick_match or normal_match
        if t and '$' not in t and '{' not in t:
            write_tables.add(t.split('.')[-1])

    into_matches = re.findall(r'INTO\s+(?:[`]([^`]+)[`]|([a-zA-Z0-9_.-]+))', sql, re.IGNORECASE)
    for backtick_match, normal_match in into_matches:
        t = backtick_match or normal_match
        if t and '$' not in t and '{' not in t:
            write_tables.add(t.split('.')[-1])

    create_matches = re.findall(r'TABLE\s+(?:[`]([^`]+)[`]|([a-zA-Z0-9_.-]+))', sql, re.IGNORECASE)
    for backtick_match, normal_match in create_matches:
        t = backtick_match or normal_match
        if t and '$' not in t and '{' not in t:
            write_tables.add(t.split('.')[-1])

    return read_tables, write_tables


# ─── COMPONENT TYPE DETECTION ───────────────────────────────────────────────

def _detect_component_type(component: Dict) -> str:
    """Detecta el tipo de componente por implementationID y estructura de parámetros."""
    impl_id = component.get("implementationID")

    # Mapping explícito de implementationID (basado en Matillion estándar)
    if impl_id == -1266674941:
        return "SQL_QUERY"
    elif impl_id == 1716658327:
        return "CALCULATOR"
    elif impl_id == -1760161015:
        return "FILTER"
    elif impl_id == -629958239:
        return "JOIN"
    elif impl_id == 211954775:
        return "TABLE_OUTPUT"
    elif impl_id == -1099429750:
        return "SORT_RERANK"

    # Fallback: detectar por contenido de parámetros
    params = component.get("parameters", {})

    # Buscar SQL_QUERY (keywords en algún parámetro de texto)
    for param_key, param_value in params.items():
        if isinstance(param_value, str) and len(param_value) > 30:
            if any(kw in param_value.upper() for kw in ["SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "MERGE"]):
                return "SQL_QUERY"

    # Si nada coincide, desconocido
    return "UNKNOWN"


def _extract_calculator_logic(component: Dict) -> Optional[List[Dict]]:
    """Extrae expresiones BigQuery del componente CALCULATOR."""
    params = component.get("parameters", {})
    expressions = []

    # Buscar param[3] que contiene {elem_N: {values: {1: {value: expr}, 2: {value: col_destino}}}}
    param_3 = params.get("3", {})
    if not isinstance(param_3, dict):
        return None

    elements = param_3.get("elements", {})
    if not isinstance(elements, dict):
        return None

    for elem_key, elem_val in elements.items():
        if not isinstance(elem_val, dict):
            continue

        values = elem_val.get("values", {})
        if not isinstance(values, dict):
            continue

        # Extraer val_1 (expresión) y val_2 (columna destino)
        expr = None
        col_destino = None

        for val_key, val_obj in values.items():
            if isinstance(val_obj, dict):
                val = val_obj.get("value")
                if val:
                    # val_1 es la expresión, val_2 es el nombre de columna
                    if val_key == "1":
                        expr = val
                    elif val_key == "2":
                        col_destino = val

        if expr and col_destino:
            expressions.append({
                "expression": expr,
                "column": col_destino
            })

    return expressions if expressions else None


def _extract_filter_logic(component: Dict) -> Optional[Dict]:
    """Extrae condiciones WHERE del componente FILTER."""
    params = component.get("parameters", {})

    # param[2] = "Filter Conditions": {elem_N: {values: {1: {value: col}, 2: {value: op}, 3: {...}, 4: {value: val}}}}
    # param[3] = "Combine Conditions": {elem_1: {values: {1: {value: "AND"/"OR"}}}}

    param_2 = params.get("2", {})
    param_3 = params.get("3", {})

    elements_2 = param_2.get("elements", {}) if isinstance(param_2, dict) else {}
    elements_3 = param_3.get("elements", {}) if isinstance(param_3, dict) else {}

    if not isinstance(elements_2, dict):
        return None

    conditions = []
    logical_operator = "AND"

    # Extraer operador lógico de param[3]
    for elem in elements_3.values():
        if isinstance(elem, dict):
            values = elem.get("values", {})
            for val_obj in values.values():
                if isinstance(val_obj, dict):
                    val = val_obj.get("value")
                    if isinstance(val, str) and val.upper() in ["AND", "OR"]:
                        logical_operator = val.upper()
                        break

    # Extraer condiciones de param[2]
    for elem_key, elem_val in elements_2.items():
        if not isinstance(elem_val, dict):
            continue

        values = elem_val.get("values", {})
        if not isinstance(values, dict):
            continue

        col = None
        op = None
        val = None

        for val_key, val_obj in values.items():
            if isinstance(val_obj, dict):
                v = val_obj.get("value")
                if val_key == "1":
                    col = v
                elif val_key == "2":
                    op = v
                elif val_key == "4":
                    val = v

        if col and op:
            conditions.append({
                "column": col,
                "operator": op,
                "value": val
            })

    if conditions:
        return {
            "operator": logical_operator,
            "conditions": conditions
        }

    return None


def _extract_join_logic(component: Dict) -> Optional[Dict]:
    """Extrae lógica de JOIN (tipo, inputs, condición, columnas)."""
    params = component.get("parameters", {})

    # param[1] = "Left Input Name"
    # param[2] = "Left Input Alias"
    # param[4] = "Right Input": {elem_N: {values: {1: {value: nombre_input_derecho}, 3: {value: "Left"/"Inner"/"Right"}, 2: {value: alias}}}}
    # param[5] = "Join Condition": {elem_N: {values: {1: {value: condición_join_SQL}, ...}}}
    # param[6] = "Output Field Map": {elem_N: {values: {1: {value: "col_origen"}, 2: {value: "col_destino"}}}}

    # Extraer inputs izquierdos
    param_1 = params.get("1", {})
    param_2 = params.get("2", {})
    left_input = None
    left_alias = None

    if isinstance(param_1, dict):
        elements = param_1.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                for val_obj in values.values():
                    if isinstance(val_obj, dict):
                        left_input = val_obj.get("value")
                        break

    if isinstance(param_2, dict):
        elements = param_2.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                for val_obj in values.values():
                    if isinstance(val_obj, dict):
                        left_alias = val_obj.get("value")
                        break

    param_4 = params.get("4", {})
    param_5 = params.get("5", {})
    param_6 = params.get("6", {})

    if not (left_input and left_alias and param_4):
        return None

    # Extraer input derecho y tipo de join
    right_input = None
    right_alias = None
    join_type = "Inner"

    elements_4 = param_4.get("elements", {}) if isinstance(param_4, dict) else {}
    for elem in elements_4.values():
        if isinstance(elem, dict):
            values = elem.get("values", {})
            for val_key, val_obj in values.items():
                if isinstance(val_obj, dict):
                    v = val_obj.get("value")
                    if val_key == "1":
                        right_input = v
                    elif val_key == "2":
                        right_alias = v
                    elif val_key == "3":
                        if v in ["Left", "Inner", "Right", "Full"]:
                            join_type = v

    if not right_input:
        return None

    # Extraer condición de join
    join_condition = None
    elements_5 = param_5.get("elements", {}) if isinstance(param_5, dict) else {}
    for elem in elements_5.values():
        if isinstance(elem, dict):
            values = elem.get("values", {})
            for val_obj in values.values():
                if isinstance(val_obj, dict):
                    v = val_obj.get("value")
                    if isinstance(v, str):
                        join_condition = v
                        break
            if join_condition:
                break

    # Extraer column mapping
    column_mapping = []
    elements_6 = param_6.get("elements", {}) if isinstance(param_6, dict) else {}
    for elem in elements_6.values():
        if isinstance(elem, dict):
            values = elem.get("values", {})
            src = None
            dst = None
            for val_key, val_obj in values.items():
                if isinstance(val_obj, dict):
                    v = val_obj.get("value")
                    if val_key == "1":
                        src = v
                    elif val_key == "2":
                        dst = v
            if src and dst:
                column_mapping.append((src, dst))

    return {
        "left_input": left_input,
        "left_alias": left_alias,
        "right_input": right_input,
        "right_alias": right_alias,
        "join_type": join_type,
        "join_condition": join_condition,
        "column_mapping": column_mapping
    }


def _extract_table_output_logic(component: Dict) -> Optional[Dict]:
    """Extrae lógica de TABLE_OUTPUT (tabla destino, mapping, tipo carga)."""
    params = component.get("parameters", {})

    # param[2] = "Table Name": {elem: {values: {1: {value: tabla_destino}}}}
    # param[4] = "Output Field Map": {elem_N: {values: {1: {value: "col_origen"}, 2: {value: "col_destino"}}}}
    # param[5] = "Table Load Type": {elem: {values: {1: {value: tipo_carga}}}}
    # param[100] = "Project": {elem: {values: {1: {value: project}}}}

    target_table = None
    load_type = "Insert"
    project = None

    # Extraer tabla destino
    param_2 = params.get("2", {})
    if isinstance(param_2, dict):
        elements = param_2.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                for val_obj in values.values():
                    if isinstance(val_obj, dict):
                        target_table = val_obj.get("value")
                        break

    # Extraer tipo de carga
    param_5 = params.get("5", {})
    if isinstance(param_5, dict):
        elements = param_5.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                for val_obj in values.values():
                    if isinstance(val_obj, dict):
                        v = val_obj.get("value")
                        if v:
                            load_type = v
                        break

    # Extraer proyecto
    param_100 = params.get("100", {})
    if isinstance(param_100, dict):
        elements = param_100.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                for val_obj in values.values():
                    if isinstance(val_obj, dict):
                        project = val_obj.get("value")
                        break

    if not target_table:
        return None

    # Extraer column mapping
    column_mapping = []
    param_4 = params.get("4", {})
    if isinstance(param_4, dict):
        elements = param_4.get("elements", {})
        for elem in elements.values():
            if isinstance(elem, dict):
                values = elem.get("values", {})
                src = None
                dst = None
                for val_key, val_obj in values.items():
                    if isinstance(val_obj, dict):
                        v = val_obj.get("value")
                        if val_key == "1":
                            src = v
                        elif val_key == "2":
                            dst = v
                if src and dst:
                    column_mapping.append((src, dst))

    return {
        "target_table": target_table,
        "project": project,
        "load_type": load_type,
        "column_mapping": column_mapping
    }


# ─── ANÁLISIS ───────────────────────────────────────────────────────────

def analyze_pipeline(raw: dict) -> dict:
    """Analiza pipeline completo y retorna diccionario con estadísticas."""
    preprocessed = preprocess_matillion_export(raw)

    # Estadísticas básicas
    num_orch_jobs = len(preprocessed.get("orchestration_jobs", []))
    num_trans_jobs = len(preprocessed.get("transformation_jobs", []))
    num_variables = len(preprocessed.get("variables", []))

    # Contar componentes
    total_comps = 0
    for job in preprocessed["orchestration_jobs"] + preprocessed["transformation_jobs"]:
        total_comps += len(job.get("components", {}))

    # Extraer todos los componentes (SQL, CALCULATOR, FILTER, JOIN, TABLE_OUTPUT)
    # Necesitamos acceder a los componentes RAW para mantener la estructura de parámetros
    all_sqls = []

    # Mapear raw jobs a preprocessed jobs
    raw_trans_jobs = raw.get("transformationJobs", [])
    raw_orch_jobs = raw.get("orchestrationJobs", [])

    for job_type_str, raw_jobs, prep_jobs in [
        ("transformation", raw_trans_jobs, preprocessed.get("transformation_jobs", [])),
        ("orchestration", raw_orch_jobs, preprocessed.get("orchestration_jobs", []))
    ]:
        for raw_job, prep_job in zip(raw_jobs, prep_jobs):
            raw_comps = raw_job.get("components", {})
            for comp_id, raw_comp in raw_comps.items():
                comp_type = _detect_component_type(raw_comp)

                comp_name = _get_component_name(raw_comp)

                if comp_type == "SQL_QUERY":
                    sql = _extract_sql(raw_comp)
                    if sql:
                        company = detect_company(sql)
                        # Detectar tipo SQL
                        sql_type = "UNKNOWN"
                        for kw in ['CREATE', 'INSERT', 'UPDATE', 'DELETE', 'MERGE', 'SELECT']:
                            if kw in sql.upper():
                                sql_type = kw
                                break
                        if 'def ' in sql or 'import ' in sql:
                            sql_type = "PYTHON"

                        read_tables, write_tables = _extract_tables_from_sql(sql)
                        all_sqls.append({
                            "job_id": prep_job["job_id"],
                            "job_name": prep_job["job_name"],
                            "job_type": job_type_str,
                            "comp_id": comp_id,
                            "comp_name": comp_name,
                            "component_type": "SQL_QUERY",
                            "sql_type": sql_type,
                            "company": company,
                            "content": sql,
                            "read_tables": read_tables,
                            "write_tables": write_tables,
                        })

                elif comp_type == "CALCULATOR":
                    expressions = _extract_calculator_logic(raw_comp)
                    if expressions:
                        all_sqls.append({
                            "job_id": prep_job["job_id"],
                            "job_name": prep_job["job_name"],
                            "job_type": job_type_str,
                            "comp_id": comp_id,
                            "comp_name": comp_name,
                            "component_type": "CALCULATOR",
                            "company": "UNKNOWN",
                            "calc_expressions": expressions,
                        })

                elif comp_type == "FILTER":
                    filter_logic = _extract_filter_logic(raw_comp)
                    if filter_logic:
                        all_sqls.append({
                            "job_id": prep_job["job_id"],
                            "job_name": prep_job["job_name"],
                            "job_type": job_type_str,
                            "comp_id": comp_id,
                            "comp_name": comp_name,
                            "component_type": "FILTER",
                            "company": "UNKNOWN",
                            "filter_conditions": filter_logic,
                        })

                elif comp_type == "JOIN":
                    join_logic = _extract_join_logic(raw_comp)
                    if join_logic:
                        all_sqls.append({
                            "job_id": prep_job["job_id"],
                            "job_name": prep_job["job_name"],
                            "job_type": job_type_str,
                            "comp_id": comp_id,
                            "comp_name": comp_name,
                            "component_type": "JOIN",
                            "company": "UNKNOWN",
                            "join_logic": join_logic,
                        })

                elif comp_type == "TABLE_OUTPUT":
                    table_output = _extract_table_output_logic(raw_comp)
                    if table_output:
                        all_sqls.append({
                            "job_id": prep_job["job_id"],
                            "job_name": prep_job["job_name"],
                            "job_type": job_type_str,
                            "comp_id": comp_id,
                            "comp_name": comp_name,
                            "component_type": "TABLE_OUTPUT",
                            "company": "UNKNOWN",
                            "table_output": table_output,
                        })

    # Variables declaradas en el JSON de Matillion
    key_variables = []
    for var in preprocessed.get("variables", []):
        var_name = var.get("name", "")
        if any(pfx in var_name.lower() for pfx in ["project_", "dataset_", "table_", "evar_", "date_"]):
            key_variables.append(var_name)

    # Variables de configuración embebidas en SQLs (${prm_*}, ${evar_*}, etc.)
    sql_variables: set = set()
    for entry in all_sqls:
        sql_text = entry.get("content", "")
        if sql_text:
            sql_variables.update(re.findall(r'\$\{([^}]+)\}', sql_text))

    # Fuentes reales: nombres de componentes SQL_QUERY (Matillion usa $T{} — regex no funciona)
    source_components = [
        {"comp_name": e["comp_name"], "job_name": e["job_name"]}
        for e in all_sqls if e["component_type"] == "SQL_QUERY"
    ]

    # Tabla(s) destino: extraídas de TABLE_OUTPUT
    target_tables = []
    for e in all_sqls:
        if e["component_type"] == "TABLE_OUTPUT":
            to = e.get("table_output", {})
            target_tables.append({
                "table": to.get("target_table"),
                "project": to.get("project"),
                "load_type": to.get("load_type"),
                "job_name": e["job_name"],
            })

    # Sort/merge keys desde SORT_RERANK (param[6] o similar — usar comp_name como referencia)
    sort_keys = []
    for entry in all_sqls:
        if entry["component_type"] == "SORT_RERANK":
            sort_keys.append(entry["comp_name"])

    return {
        "num_orch_jobs": num_orch_jobs,
        "num_trans_jobs": num_trans_jobs,
        "num_variables": num_variables,
        "total_components": total_comps,
        "jobs": preprocessed["orchestration_jobs"] + preprocessed["transformation_jobs"],
        "all_sqls": all_sqls,
        "key_variables": key_variables[:20],
        "sql_variables": sorted(sql_variables),
        "source_components": source_components,
        "target_tables": target_tables,
        "sort_keys": sort_keys,
        "preprocessed": preprocessed,
        "raw_trans_jobs": raw_trans_jobs,
        "raw_orch_jobs": raw_orch_jobs,
    }


# ─── GRAPH EXTRACTION ───────────────────────────────────────────────────

def _get_component_name(raw_comp: Dict) -> str:
    """Extrae el nombre legible del componente desde param[1]."""
    params = raw_comp.get("parameters", {})
    param_1 = params.get("1", {})
    if isinstance(param_1, dict):
        for elem in param_1.get("elements", {}).values():
            if isinstance(elem, dict):
                for val_obj in elem.get("values", {}).values():
                    if isinstance(val_obj, dict):
                        name = val_obj.get("value")
                        if isinstance(name, str) and name:
                            return name
    impl_id = raw_comp.get("implementationID", "?")
    return f"comp_{impl_id}"


def _extract_component_graph(raw_job: Dict) -> Dict:
    """Extrae grafo de componentes de un job raw: nodos + aristas."""
    components = raw_job.get("components", {})
    connectors = raw_job.get("connectors", {})

    nodes: Dict[str, Dict] = {}
    for comp_id, comp in components.items():
        nodes[str(comp_id)] = {
            "name": _get_component_name(comp),
            "type": _detect_component_type(comp),
        }

    edges: List[Tuple[str, str]] = []
    for conn in connectors.values():
        src_id = str(conn.get("sourceID", ""))
        tgt_id = str(conn.get("targetID", ""))
        if src_id in nodes and tgt_id in nodes:
            edges.append((src_id, tgt_id))

    return {"nodes": nodes, "edges": edges}


def _generate_mermaid_flowchart(graph: Dict, job_name: str) -> str:
    """Genera bloque Mermaid flowchart LR a partir del grafo de un job."""
    nodes = graph["nodes"]
    edges = graph["edges"]

    # Asignar IDs cortos para Mermaid
    node_id_map: Dict[str, str] = {}
    for i, comp_id in enumerate(nodes):
        node_id_map[comp_id] = f"n{i}"

    lines = ["```mermaid", "flowchart LR"]

    # Definiciones de nodos con formas por tipo
    SHAPE = {
        "SQL_QUERY":    ('([', '])'),
        "CALCULATOR":   ('[/', '/]'),
        "FILTER":       ('{', '}'),
        "JOIN":         ('[', ']'),
        "TABLE_OUTPUT": ('[(', ')]'),
        "SORT_RERANK":  ('[[', ']]'),
        "UNKNOWN":      ('[', ']'),
    }
    for comp_id, node_info in nodes.items():
        mid = node_id_map[comp_id]
        name = node_info["name"].replace('"', "'")
        open_s, close_s = SHAPE.get(node_info["type"], ('[', ']'))
        lines.append(f'    {mid}{open_s}"{name}"{close_s}')

    lines.append("")

    # Aristas
    for src_id, tgt_id in edges:
        src_mid = node_id_map.get(src_id)
        tgt_mid = node_id_map.get(tgt_id)
        if src_mid and tgt_mid:
            lines.append(f"    {src_mid} --> {tgt_mid}")

    lines.append("")

    # classDefs y asignación
    CLASS_DEF = {
        "SQL_QUERY":    "sql",
        "CALCULATOR":   "calc",
        "FILTER":       "filter",
        "JOIN":         "join",
        "TABLE_OUTPUT": "output",
        "SORT_RERANK":  "sort",
        "UNKNOWN":      "unknown",
    }
    COLORS = {
        "sql":     "fill:#4a90d9,stroke:#2c5f8a,color:#fff",
        "calc":    "fill:#7cb87e,stroke:#4a7a4c,color:#fff",
        "filter":  "fill:#f0a500,stroke:#b87800,color:#fff",
        "join":    "fill:#9b59b6,stroke:#6c3483,color:#fff",
        "output":  "fill:#e74c3c,stroke:#a93226,color:#fff",
        "sort":    "fill:#1abc9c,stroke:#148a72,color:#fff",
        "unknown": "fill:#aaa,stroke:#666,color:#fff",
    }

    # Agrupar por clase
    class_groups: Dict[str, List[str]] = defaultdict(list)
    for comp_id, node_info in nodes.items():
        cls = CLASS_DEF.get(node_info["type"], "unknown")
        class_groups[cls].append(node_id_map[comp_id])

    for cls, color in COLORS.items():
        if cls in class_groups:
            lines.append(f"    classDef {cls} {color}")

    for cls, mids in class_groups.items():
        lines.append(f"    class {','.join(mids)} {cls}")

    lines.append("```")
    return "\n".join(lines)


# ─── GENERADORES DE MARKDOWN ────────────────────────────────────────────

def generate_logica_negocio(analysis: dict, json_stem: str) -> str:
    """Genera documento 1: logica-negocio-{stem}.md"""
    output = []
    output.append(f"# Lógica de Negocio - {json_stem}")
    output.append("")
    output.append("**Pipeline de transformación y orquestación de datos**")
    output.append("")
    output.append("---")
    output.append("")

    # Resumen ejecutivo
    output.append("## 1. Resumen Ejecutivo")
    output.append("")
    output.append(f"- **Jobs de Orquestación:** {analysis['num_orch_jobs']}")
    output.append(f"- **Jobs de Transformación:** {analysis['num_trans_jobs']}")
    output.append(f"- **Componentes Totales:** {analysis['total_components']}")
    output.append(f"- **Variables Globales:** {analysis['num_variables']}")
    output.append(f"- **Statements SQL/Code:** {len(analysis['all_sqls'])}")
    output.append("")

    output.append("## 2. Tablas Input/Output")
    output.append("")

    # Fuentes: componentes SQL_QUERY (nombres reales del pipeline)
    source_components = analysis.get("source_components", [])
    if source_components:
        output.append("### Fuentes de Entrada (SQL_QUERY)")
        output.append("")
        output.append("| Componente | Job |")
        output.append("|---|---|")
        for src in source_components:
            output.append(f"| `{src['comp_name']}` | {src['job_name']} |")
        output.append("")

    # Destino: TABLE_OUTPUT
    target_tables = analysis.get("target_tables", [])
    if target_tables:
        output.append("### Tablas Destino (TABLE_OUTPUT)")
        output.append("")
        output.append("| Tabla | Proyecto | Tipo de Carga | Job |")
        output.append("|---|---|---|---|")
        for tgt in target_tables:
            project = tgt.get("project") or "_(variable)_"
            output.append(f"| `{tgt['table']}` | `{project}` | {tgt['load_type']} | {tgt['job_name']} |")
        output.append("")

    # Si no hay ni fuentes ni destino detectados, fallback a regex
    if not source_components and not target_tables:
        all_read = set()
        all_write = set()
        for e in analysis['all_sqls']:
            all_read.update(e.get('read_tables', set()))
            all_write.update(e.get('write_tables', set()))
        if all_read:
            output.append("### Tablas Leídas")
            output.append("")
            for t in sorted(all_read):
                output.append(f"- `{t}`")
            output.append("")
        if all_write:
            output.append("### Tablas Modificadas")
            output.append("")
            for t in sorted(all_write):
                output.append(f"- `{t}`")
            output.append("")

    # Variables clave
    output.append("## 3. Variables Clave")
    output.append("")

    key_variables = analysis.get("key_variables", [])
    sql_variables = analysis.get("sql_variables", [])

    if key_variables:
        output.append("### Variables declaradas en Matillion")
        output.append("")
        for var in key_variables:
            output.append(f"- `{var}`")
        output.append("")

    if sql_variables:
        output.append("### Variables de configuración embebidas en SQL")
        output.append("")
        for var in sql_variables:
            output.append(f"- `${{{var}}}`")
        output.append("")

    if not key_variables and not sql_variables:
        output.append("_Sin variables detectadas._")
        output.append("")

    # Jobs
    output.append("## 4. Jobs del Pipeline")
    output.append("")

    orch_count = 0
    trans_count = 0
    for job in analysis['jobs']:
        num_comps = len(job.get("components", {}))
        if "orch" in job["job_name"].lower():
            orch_count += 1
            output.append(f"- **[ORCH #{orch_count}]** {job['job_name']} (ID: {job['job_id']}, {num_comps} componentes)")
        else:
            trans_count += 1
            output.append(f"- **[TRANS #{trans_count}]** {job['job_name']} (ID: {job['job_id']}, {num_comps} componentes)")
    output.append("")

    # Patrones detectados
    output.append("## 5. Patrones SQL Detectados")
    output.append("")

    sql_type_counts = defaultdict(int)
    company_counts = defaultdict(int)
    for sql_entry in analysis['all_sqls']:
        sql_type_counts[sql_entry.get('component_type', 'UNKNOWN')] += 1
        if sql_entry.get('company', 'UNKNOWN') != "UNKNOWN":
            company_counts[sql_entry.get('company', 'UNKNOWN')] += 1

    output.append("### Por Tipo de Operación")
    output.append("")
    for sql_type in sorted(sql_type_counts.keys()):
        output.append(f"- `{sql_type}`: {sql_type_counts[sql_type]} statements")
    output.append("")

    if company_counts:
        output.append("### Empresas Detectadas")
        output.append("")
        for company in sorted(company_counts.keys()):
            output.append(f"- `{company}`: {company_counts[company]} statements")
        output.append("")

    # Diagrama de flujo simple
    output.append("## 6. Flujo del Pipeline")
    output.append("")
    output.append("```")
    output.append("┌─────────────────────────────────┐")
    output.append("│ Lectura de Configuración        │")
    output.append("└─────────────┬───────────────────┘")
    output.append("              ↓")
    output.append(f"┌─────────────────────────────────┐")
    output.append(f"│ {analysis['num_trans_jobs']} Transformation Jobs (PARALELO)    │")
    output.append(f"│ - SELECT / ENCRYPT / HASH / DQ  │")
    output.append(f"└─────────────┬───────────────────┘")
    output.append("              ↓")
    output.append(f"┌─────────────────────────────────┐")
    output.append(f"│ {analysis['num_orch_jobs']} Orchestration Jobs (PARALELO)   │")
    output.append(f"│ - DELETE / INSERT / UPDATE      │")
    output.append(f"└─────────────┬───────────────────┘")
    output.append("              ↓")
    output.append("┌─────────────────────────────────┐")
    output.append("│ Registrar Ejecución & Auditoría │")
    output.append("└─────────────────────────────────┘")
    output.append("```")
    output.append("")

    return "\n".join(output)


def generate_sql_statements(analysis: dict, json_stem: str) -> str:
    """Genera documento 2: sql-statements-{stem}.md"""
    output = []
    output.append(f"# SQL Statements - {json_stem}")
    output.append("")
    output.append("**Lógica de Negocio implementada en SQL/Python - Organizado por Empresa y Tipo**")
    output.append("")
    output.append("---")
    output.append("")

    # Agrupar por tipo de componente
    comp_by_type = defaultdict(list)
    for sql_entry in analysis['all_sqls']:
        comp_type = sql_entry.get('component_type', 'SQL_QUERY')
        comp_by_type[comp_type].append(sql_entry)

    # También agrupar por sql_type para SQL_QUERY
    sql_by_type = defaultdict(list)
    for sql_entry in analysis['all_sqls']:
        if sql_entry.get('component_type') == 'SQL_QUERY':
            sql_by_type[sql_entry.get('sql_type', 'UNKNOWN')].append(sql_entry)

    # Índice
    output.append("## Índice de Componentes por Tipo y Empresa")
    output.append("")
    output.append("| Tipo de Componente | Cantidad | Empresas Detectadas |")
    output.append("|---|---|---|")

    # Mostrar índice de componentes (no solo SQL)
    for comp_type in sorted(comp_by_type.keys()):
        items = comp_by_type[comp_type]
        if comp_type == "SQL_QUERY":
            companies = set(item.get('company', 'UNKNOWN') for item in items)
            companies_str = ", ".join(sorted(companies)) if companies else "UNKNOWN"
        else:
            companies_str = "-"
        output.append(f"| {comp_type} | {len(items)} | {companies_str} |")
    output.append("")

    # Secciones por tipo de componente

    # ═══ SQL_QUERY SECTION ═══
    if "SQL_QUERY" in comp_by_type:
        output.append("## SQL_QUERY (SQL Statements)")
        output.append("")

        items = comp_by_type["SQL_QUERY"]
        sql_by_type_local = defaultdict(list)
        for item in items:
            sql_by_type_local[item.get('sql_type', 'UNKNOWN')].append(item)

        output.append("### Índice SQL por Tipo")
        output.append("")
        output.append("| Tipo SQL | Cantidad | Empresas |")
        output.append("|---|---|---|")
        for sql_type in sorted(sql_by_type_local.keys()):
            items_sql = sql_by_type_local[sql_type]
            companies = set(item.get('company', 'UNKNOWN') for item in items_sql)
            companies_str = ", ".join(sorted(companies)) if companies else "UNKNOWN"
            output.append(f"| {sql_type} | {len(items_sql)} | {companies_str} |")
        output.append("")

        for sql_type in sorted(sql_by_type_local.keys()):
            items_sql = sql_by_type_local[sql_type]
            output.append(f"#### {sql_type} ({len(items_sql)})")
            output.append("")

            for i, item in enumerate(items_sql, 1):
                company_tag = f"[{item.get('company', 'UNKNOWN')}]"
                output.append(f"##### {sql_type} #{i} {company_tag}")
                output.append(f"**Job:** {item['job_type'].upper()} (ID: {item['job_id']}) - {item['job_name']}")
                output.append(f"**Company:** {item.get('company', 'UNKNOWN')}")
                output.append(f"**Component:** {item['comp_id']}")
                output.append("")

                lang = "python" if sql_type == "PYTHON" else "sql"
                output.append(f"```{lang}")
                output.append(item.get('content', ''))
                output.append("```")
                output.append("")

    # ═══ CALCULATOR SECTION ═══
    if "CALCULATOR" in comp_by_type:
        output.append("## CALCULATOR (Calculated Expressions)")
        output.append("")

        items = comp_by_type["CALCULATOR"]
        for i, item in enumerate(items, 1):
            output.append(f"### CALCULATOR #{i}")
            output.append(f"**Job:** {item['job_type'].upper()} (ID: {item['job_id']}) - {item['job_name']}")
            output.append(f"**Component:** {item['comp_id']}")
            output.append("")

            expressions = item.get('calc_expressions', [])
            output.append("| Columna Destino | Expresión |")
            output.append("|---|---|")
            for expr_item in expressions:
                col = expr_item.get('column', '')
                expr = expr_item.get('expression', '')
                output.append(f"| `{col}` | `{expr}` |")
            output.append("")

    # ═══ FILTER SECTION ═══
    if "FILTER" in comp_by_type:
        output.append("## FILTER (Filter Conditions)")
        output.append("")

        items = comp_by_type["FILTER"]
        for i, item in enumerate(items, 1):
            output.append(f"### FILTER #{i}")
            output.append(f"**Job:** {item['job_type'].upper()} (ID: {item['job_id']}) - {item['job_name']}")
            output.append(f"**Component:** {item['comp_id']}")
            output.append("")

            filter_logic = item.get('filter_conditions', {})
            operator = filter_logic.get('operator', 'AND')
            conditions = filter_logic.get('conditions', [])

            output.append(f"**Lógica:** {operator}")
            output.append("")
            output.append("| Columna | Operador | Valor |")
            output.append("|---|---|---|")
            for cond in conditions:
                col = cond.get('column', '')
                op = cond.get('operator', '')
                val = cond.get('value', '')
                output.append(f"| `{col}` | `{op}` | `{val}` |")
            output.append("")

    # ═══ JOIN SECTION ═══
    if "JOIN" in comp_by_type:
        output.append("## JOIN (Join Operations)")
        output.append("")

        items = comp_by_type["JOIN"]
        for i, item in enumerate(items, 1):
            output.append(f"### JOIN #{i}")
            output.append(f"**Job:** {item['job_type'].upper()} (ID: {item['job_id']}) - {item['job_name']}")
            output.append(f"**Component:** {item['comp_id']}")
            output.append("")

            join_logic = item.get('join_logic', {})
            output.append(f"**Tipo de Join:** {join_logic.get('join_type', 'Inner')}")
            output.append("")
            output.append(f"**Input Izquierdo:** `{join_logic.get('left_input')}` (alias: `{join_logic.get('left_alias')}`)")
            output.append(f"**Input Derecho:** `{join_logic.get('right_input')}` (alias: `{join_logic.get('right_alias')}`)")
            output.append("")

            if join_logic.get('join_condition'):
                output.append("**Condición de Join:**")
                output.append("")
                output.append("```sql")
                output.append(join_logic.get('join_condition'))
                output.append("```")
                output.append("")

            col_mapping = join_logic.get('column_mapping', [])
            if col_mapping:
                output.append("**Columnas Seleccionadas:**")
                output.append("")
                output.append("| Origen | Destino |")
                output.append("|---|---|")
                for src, dst in col_mapping:
                    output.append(f"| `{src}` | `{dst}` |")
                output.append("")

    # ═══ TABLE_OUTPUT SECTION ═══
    if "TABLE_OUTPUT" in comp_by_type:
        output.append("## TABLE_OUTPUT (Table Loading)")
        output.append("")

        items = comp_by_type["TABLE_OUTPUT"]
        for i, item in enumerate(items, 1):
            output.append(f"### TABLE_OUTPUT #{i}")
            output.append(f"**Job:** {item['job_type'].upper()} (ID: {item['job_id']}) - {item['job_name']}")
            output.append(f"**Component:** {item['comp_id']}")
            output.append("")

            table_info = item.get('table_output', {})
            output.append(f"**Tabla Destino:** `{table_info.get('target_table')}`")
            if table_info.get('project'):
                output.append(f"**Proyecto:** `{table_info.get('project')}`")
            output.append(f"**Tipo de Carga:** `{table_info.get('load_type')}`")
            output.append("")

            col_mapping = table_info.get('column_mapping', [])
            if col_mapping:
                output.append("**Mapeo de Columnas:**")
                output.append("")
                output.append("| Origen | Destino |")
                output.append("|---|---|")
                for src, dst in col_mapping:
                    output.append(f"| `{src}` | `{dst}` |")
                output.append("")

    # Resumen por componente y empresa
    output.append("## Resumen por Tipo de Componente")
    output.append("")

    output.append("| Componente | SQL | CALC | FILTER | JOIN | T_OUT |")
    output.append("|---|---|---|---|---|---|")

    comp_stats = defaultdict(lambda: defaultdict(int))
    for sql_entry in analysis['all_sqls']:
        comp_type = sql_entry.get('component_type', 'UNKNOWN')
        if comp_type == 'SQL_QUERY':
            sql_type = sql_entry.get('sql_type', 'UNKNOWN')
            comp_stats['SQL_QUERY'][sql_type] += 1
        else:
            comp_stats[comp_type][comp_type] += 1

    # Renderizar resumen simplificado
    for comp_type in sorted(comp_by_type.keys()):
        counts = {
            'SQL': 0,
            'CALC': 0,
            'FILTER': 0,
            'JOIN': 0,
            'T_OUT': 0
        }

        if comp_type == 'SQL_QUERY':
            counts['SQL'] = len(comp_by_type[comp_type])
        elif comp_type == 'CALCULATOR':
            counts['CALC'] = len(comp_by_type[comp_type])
        elif comp_type == 'FILTER':
            counts['FILTER'] = len(comp_by_type[comp_type])
        elif comp_type == 'JOIN':
            counts['JOIN'] = len(comp_by_type[comp_type])
        elif comp_type == 'TABLE_OUTPUT':
            counts['T_OUT'] = len(comp_by_type[comp_type])

        row = f"| {comp_type} | {counts['SQL']} | {counts['CALC']} | {counts['FILTER']} | {counts['JOIN']} | {counts['T_OUT']} |"
        output.append(row)

    output.append("")
    output.append("**Leyenda:** SQL=SQL Statements, CALC=Calculator Expressions, FILTER=Filter Conditions, JOIN=Join Operations, T_OUT=Table Output")
    output.append("")

    return "\n".join(output)


def generate_orchestration_map(analysis: dict, json_stem: str) -> str:
    """Genera documento 3: orchestration-map-{stem}.md con diagramas Mermaid reales."""
    output = []
    output.append(f"# Mapa de Orquestación - {json_stem}")
    output.append("")
    output.append("**Grafos reales de componentes extraídos del pipeline Matillion**")
    output.append("")
    output.append("---")
    output.append("")

    # Leyenda de formas
    output.append("## Leyenda")
    output.append("")
    output.append("| Forma | Tipo de Componente | Descripción |")
    output.append("|---|---|---|")
    output.append("| `([nombre])` | SQL_QUERY | Consulta SQL (SELECT / INSERT / MERGE) |")
    output.append("| `[/nombre/]` | CALCULATOR | Expresiones BigQuery calculadas |")
    output.append("| `{nombre}` | FILTER | Condiciones WHERE / filtro de filas |")
    output.append("| `[nombre]` | JOIN | Operación de JOIN entre datasets |")
    output.append("| `[(nombre)]` | TABLE_OUTPUT | Carga final a tabla BigQuery |")
    output.append("| `[[nombre]]` | SORT_RERANK | Ordenamiento / re-ranking |")
    output.append("")

    raw_trans_jobs = analysis.get("raw_trans_jobs", [])
    raw_orch_jobs = analysis.get("raw_orch_jobs", [])
    preprocessed = analysis.get("preprocessed", {})
    prep_trans = preprocessed.get("transformation_jobs", [])
    prep_orch = preprocessed.get("orchestration_jobs", [])

    # ─── TRANSFORMATION JOBS ─────────────────────────────────────────────
    if raw_trans_jobs:
        output.append(f"## Transformation Jobs ({len(raw_trans_jobs)})")
        output.append("")

        for raw_job, prep_job in zip(raw_trans_jobs, prep_trans):
            job_name = prep_job.get("job_name", f"trans_{raw_job.get('id', '?')}")
            job_id = prep_job.get("job_id", raw_job.get("id", "?"))
            num_comps = len(raw_job.get("components", {}))
            num_conns = len(raw_job.get("connectors", {}))

            output.append(f"### {job_name} (ID: {job_id})")
            output.append("")
            output.append(f"- **Componentes:** {num_comps}")
            output.append(f"- **Conexiones:** {num_conns}")
            output.append("")

            graph = _extract_component_graph(raw_job)

            if graph["edges"]:
                output.append(_generate_mermaid_flowchart(graph, job_name))
            else:
                # Sin conectores — listar nodos sin grafo
                output.append("_Sin conexiones entre componentes (ejecución lineal o job de 1 nodo)_")
                output.append("")
                output.append("| Componente | Tipo |")
                output.append("|---|---|")
                for comp_id, node_info in graph["nodes"].items():
                    output.append(f"| {node_info['name']} | {node_info['type']} |")
            output.append("")

    # ─── ORCHESTRATION JOBS ──────────────────────────────────────────────
    if raw_orch_jobs:
        output.append(f"## Orchestration Jobs ({len(raw_orch_jobs)})")
        output.append("")

        for raw_job, prep_job in zip(raw_orch_jobs, prep_orch):
            job_name = prep_job.get("job_name", f"orch_{raw_job.get('id', '?')}")
            job_id = prep_job.get("job_id", raw_job.get("id", "?"))
            num_comps = len(raw_job.get("components", {}))
            num_conns = len(raw_job.get("connectors", {}))

            output.append(f"### {job_name} (ID: {job_id})")
            output.append("")
            output.append(f"- **Componentes:** {num_comps}")
            output.append(f"- **Conexiones:** {num_conns}")
            output.append("")

            graph = _extract_component_graph(raw_job)

            if graph["edges"]:
                output.append(_generate_mermaid_flowchart(graph, job_name))
            else:
                output.append("_Sin conexiones entre componentes_")
                output.append("")
                output.append("| Componente | Tipo |")
                output.append("|---|---|")
                for comp_id, node_info in graph["nodes"].items():
                    output.append(f"| {node_info['name']} | {node_info['type']} |")
            output.append("")

    # ─── RESUMEN DE TIPOS ────────────────────────────────────────────────
    output.append("## Resumen de Componentes por Tipo")
    output.append("")
    output.append("| Tipo | Count | Jobs |")
    output.append("|---|---|---|")

    type_job_map: Dict[str, List[str]] = defaultdict(list)

    for raw_job, prep_job in zip(raw_trans_jobs, prep_trans):
        job_name = prep_job.get("job_name", "?")
        for comp in raw_job.get("components", {}).values():
            ctype = _detect_component_type(comp)
            if job_name not in type_job_map[ctype]:
                type_job_map[ctype].append(job_name)

    for raw_job, prep_job in zip(raw_orch_jobs, prep_orch):
        job_name = prep_job.get("job_name", "?")
        for comp in raw_job.get("components", {}).values():
            ctype = _detect_component_type(comp)
            if job_name not in type_job_map[ctype]:
                type_job_map[ctype].append(job_name)

    # Contar totales
    type_counts: Dict[str, int] = defaultdict(int)
    for raw_job in raw_trans_jobs + raw_orch_jobs:
        for comp in raw_job.get("components", {}).values():
            type_counts[_detect_component_type(comp)] += 1

    for ctype in sorted(type_counts.keys()):
        jobs_str = ", ".join(type_job_map[ctype][:3])
        if len(type_job_map[ctype]) > 3:
            jobs_str += f" (+{len(type_job_map[ctype]) - 3} más)"
        output.append(f"| {ctype} | {type_counts[ctype]} | {jobs_str} |")
    output.append("")

    return "\n".join(output)


# ─── FUNCTIONAL BRIEF ───────────────────────────────────────────────────

def generate_functional_brief(analysis: dict, json_stem: str, original_stem: str) -> str:
    """Genera documento 4: functional-brief-{stem}.md siguiendo el estándar factory."""
    periodicity_label, periodicity_desc = _detect_periodicity(original_stem)
    today = datetime.now().strftime("%Y-%m-%d")

    # Extraer datos clave del análisis
    all_sqls = analysis["all_sqls"]
    comp_by_type = defaultdict(list)
    for e in all_sqls:
        comp_by_type[e["component_type"]].append(e)

    # Detectar empresa del pipeline (desde SQL_QUERY o nombre del job)
    company = "UNKNOWN"
    for e in comp_by_type.get("SQL_QUERY", []):
        if e.get("company", "UNKNOWN") != "UNKNOWN":
            company = e["company"]
            break
    if company == "UNKNOWN":
        # intentar desde el stem
        for code, label in COMPANY_MAP.items():
            if code in original_stem.lower():
                company = label
                break

    # Extraer tabla destino desde TABLE_OUTPUT
    table_output_entry = comp_by_type.get("TABLE_OUTPUT", [])
    table_sort_entry = comp_by_type.get("SORT_RERANK", [])
    target_table = None
    target_project = None
    load_type = "Append"
    column_mapping = []

    if table_output_entry:
        to = table_output_entry[0].get("table_output", {})
        target_table = to.get("target_table")
        target_project = to.get("project")
        load_type = to.get("load_type", "Append")
        column_mapping = to.get("column_mapping", [])

    # Fuentes de datos desde SQL_QUERY
    sql_sources = comp_by_type.get("SQL_QUERY", [])

    # Reglas de negocio desde CALCULATOR, FILTER, JOIN
    calc_entries = comp_by_type.get("CALCULATOR", [])
    filter_entries = comp_by_type.get("FILTER", [])
    join_entries = comp_by_type.get("JOIN", [])

    # Job principal
    jobs = analysis.get("jobs", [])
    main_job_name = jobs[0]["job_name"] if jobs else json_stem

    # Nombre legible del proyecto
    project_name = main_job_name.replace("_", " ").title()

    brief_id = f"BRIEF-{company}-{today.replace('-', '')}-001"

    output = []
    output.append(f"# Brief Funcional — Migración {project_name}")
    output.append("")
    output.append(f"**ID:** {brief_id}")
    output.append(f"**Fecha:** {today}")
    output.append(f"**Solicitante:** _(completar — área solicitante)_")
    output.append(f"**Data Owner:** _(completar — email responsable del dato)_")
    output.append(f"**Prioridad:** Alta")
    output.append(f"**Fecha objetivo:** _(completar)_")
    output.append("")
    output.append("> ⚠️ Brief generado automáticamente desde análisis del pipeline Matillion.")
    output.append("> Los campos marcados con _(completar)_ requieren información del solicitante.")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 1: Objetivo
    output.append("## 1. Problema / Objetivo de Negocio")
    output.append("")
    output.append("**Situación actual:**")
    output.append(f"El proceso `{main_job_name}` se ejecuta actualmente en Matillion ETL.")
    output.append(f"Gestiona la transformación y carga de datos hacia la tabla `{target_table or '_(completar)_'}`.")
    output.append(f"El proceso requiere migración al stack GCP nativo (BigQuery SPs + Cloud Workflows).")
    output.append("")
    output.append("**Resultado esperado:**")
    output.append(f"Pipeline ejecutándose automáticamente en GCP con frecuencia **{periodicity_label}**,")
    output.append("sin dependencia de Matillion, con trazabilidad, alertas y calidad de datos integradas.")
    output.append("")
    output.append("**Impacto estimado:**")
    output.append("- Eliminación de dependencia Matillion en este proceso")
    output.append("- Trazabilidad completa: logs BigQuery, alertas Pub/Sub, DQ flags")
    output.append("- Capacidad de escalar y versionar en el flujo de fábrica")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 2: Actores
    output.append("## 2. Actores y Stakeholders")
    output.append("")
    output.append("| Rol | Nombre / Área | Responsabilidad |")
    output.append("|---|---|---|")
    output.append("| Solicitante | _(completar)_ | Define requerimientos funcionales |")
    output.append("| Data Owner | _(completar email)_ | Aprueba definición del dato y accesos |")
    output.append(f"| Consumidor del Output | _(completar — área que usa `{target_table or 'tabla destino'}`)_ | Lee el output del proceso |")
    output.append("| Revisor Técnico | Tech Lead Data Platform | Valida diseño y estándares |")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 3: Casos de Uso
    output.append("## 3. Casos de Uso")
    output.append("")
    output.append("### UC-DATA-001: Transformación y carga de datos")
    output.append("")
    output.append(f"**Descripción:** Migración del job Matillion `{main_job_name}` a BigQuery SP + Cloud Workflow.")
    output.append("")
    output.append(f"**Trigger:** Cloud Scheduler — frecuencia {periodicity_label} _(confirmar día/hora)_")
    output.append("")
    output.append("**Flujo esperado:**")
    step = 1
    for src in sql_sources:
        output.append(f"{step}. Leer datos desde `{src.get('comp_name', src['comp_id'])}` (SQL input)")
        step += 1
    if join_entries:
        for j in join_entries:
            jl = j.get("join_logic", {})
            output.append(f"{step}. Aplicar {jl.get('join_type', 'Left')} JOIN entre `{jl.get('left_input')}` y `{jl.get('right_input')}`")
            step += 1
    if filter_entries:
        output.append(f"{step}. Filtrar registros según condiciones de negocio ({len(filter_entries)} filtros)")
        step += 1
    if calc_entries:
        output.append(f"{step}. Calcular campos derivados ({sum(len(e.get('calc_expressions', [])) for e in calc_entries)} expresiones)")
        step += 1
    output.append(f"{step}. Cargar resultado en tabla destino `{target_table or '_(completar)_'}` (tipo: {load_type})")
    output.append("")
    output.append(f"**Resultado:** Tabla `{target_table or '_(completar)_'}` actualizada con datos del período.")
    output.append("")
    output.append("**Flujos alternativos:**")
    output.append("- Si una fuente no está disponible: notificar por Pub/Sub mail y abortar")
    output.append("- Si DQ flags detectan anomalías: registrar en log y notificar")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 5: Diagrama de Flujo
    output.append("## 5. Diagrama de Flujo del Pipeline")
    output.append("")

    raw_trans_jobs = analysis.get("raw_trans_jobs", [])
    raw_orch_jobs = analysis.get("raw_orch_jobs", [])
    preprocessed = analysis.get("preprocessed", {})
    prep_trans = preprocessed.get("transformation_jobs", [])
    prep_orch = preprocessed.get("orchestration_jobs", [])

    diagrams_generated = 0
    for raw_job, prep_job in zip(raw_trans_jobs, prep_trans):
        job_name = prep_job.get("job_name", f"trans_{raw_job.get('id', '?')}")
        graph = _extract_component_graph(raw_job)
        if graph["edges"]:
            output.append(f"**{job_name}**")
            output.append("")
            output.append(_generate_mermaid_flowchart(graph, job_name))
            output.append("")
            diagrams_generated += 1

    for raw_job, prep_job in zip(raw_orch_jobs, prep_orch):
        job_name = prep_job.get("job_name", f"orch_{raw_job.get('id', '?')}")
        graph = _extract_component_graph(raw_job)
        if graph["edges"]:
            output.append(f"**{job_name}**")
            output.append("")
            output.append(_generate_mermaid_flowchart(graph, job_name))
            output.append("")
            diagrams_generated += 1

    if diagrams_generated == 0:
        output.append("_Sin conexiones detectadas entre componentes — ver orchestration-map para detalle._")
        output.append("")

    output.append("---")
    output.append("")

    # ─── SECCIÓN 6: Fuentes de Datos
    output.append("## 6. Fuentes de Datos")
    output.append("")
    output.append("| # | Componente Matillion | Descripción | Disponibilidad |")
    output.append("|---|---|---|---|")
    for i, src in enumerate(sql_sources, 1):
        name = src.get("comp_name", src["comp_id"])
        output.append(f"| {i} | `{name}` | _(completar — qué contiene este input)_ | {periodicity_label} |")
    if not sql_sources:
        output.append("| 1 | _(completar)_ | _(qué contiene)_ | _(cuándo está disponible)_ |")
    output.append("")
    output.append("**Restricciones de acceso conocidas:**")
    output.append("- _(completar — accesos cross-project, PII, IAM pendientes)_")
    output.append("")

    # SQLs completos de cada fuente (para que el ingeniero pueda escribir el SP sin abrir otro archivo)
    if sql_sources:
        output.append("### SQL de entrada (extraídos del pipeline Matillion)")
        output.append("")
        for src in sql_sources:
            name = src.get("comp_name", src["comp_id"])
            sql_content = src.get("content", "")
            output.append(f"#### `{name}`")
            output.append("")
            output.append("```sql")
            output.append(sql_content)
            output.append("```")
            output.append("")

    output.append("---")
    output.append("")

    # ─── SECCIÓN 5: Output Esperado
    output.append("## 7. Output Esperado")
    output.append("")
    output.append("**Tipo de output:** Tabla BigQuery")
    output.append("")

    if column_mapping:
        output.append("| Campo destino | Campo origen | Tipo de dato | Descripción |")
        output.append("|---|---|---|---|")
        for src_col, dst_col in column_mapping:
            output.append(f"| `{dst_col}` | `{src_col}` | _(completar)_ | _(completar)_ |")
    else:
        output.append("| Campo | Descripción | Tipo de dato | Ejemplo |")
        output.append("|---|---|---|---|")
        output.append("| _(completar desde DDL)_ | | | |")
    output.append("")

    output.append("**Granularidad:** _(completar — un registro por X)_")
    output.append("**Partición:** _(completar — load_date / process_date / sin partición)_")
    output.append(f"**Tipo de carga:** {load_type}")
    if target_table and target_project:
        output.append(f"**Destino:** `{target_project}.$(dataset).{target_table}`")
    elif target_table:
        output.append(f"**Destino:** `$(project).$(dataset).{target_table}`")
    else:
        output.append("**Destino:** `_(completar)_`")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 6: Reglas de Negocio
    output.append("## 8. Reglas de Negocio")
    output.append("")
    output.append("| ID | Descripción | Componente Matillion | Criticidad |")
    output.append("|---|---|---|---|")

    rn_idx = 1
    for j_entry in join_entries:
        jl = j_entry.get("join_logic", {})
        cond = jl.get("join_condition", "")
        cond_short = cond[:80].replace("\n", " ") + ("..." if len(cond) > 80 else "") if cond else "_(ver sql-statements)_"
        output.append(f"| RN-{company}-{rn_idx:03d} | {jl.get('join_type', 'Left')} JOIN: `{cond_short}` | {j_entry.get('comp_name', 'JOIN')} | Alta |")
        rn_idx += 1

    for f_entry in filter_entries:
        fl = f_entry.get("filter_conditions", {})
        conds = fl.get("conditions", [])
        op = fl.get("operator", "AND")
        cond_desc = f" {op} ".join(
            f"`{c['column']}` {c['operator']}" + (f" {c['value']}" if c.get('value') else "")
            for c in conds[:3]
        )
        if len(conds) > 3:
            cond_desc += f" (+{len(conds)-3} más)"
        output.append(f"| RN-{company}-{rn_idx:03d} | Filtro: {cond_desc} | {f_entry.get('comp_name', 'FILTER')} | Alta |")
        rn_idx += 1

    for c_entry in calc_entries:
        exprs = c_entry.get("calc_expressions", [])
        for expr in exprs[:5]:
            col = expr.get("column", "")
            expression = expr.get("expression", "")[:60]
            output.append(f"| RN-{company}-{rn_idx:03d} | `{col}` = `{expression}` | {c_entry.get('comp_name', 'CALCULATOR')} | Alta |")
            rn_idx += 1
        if len(exprs) > 5:
            output.append(f"| RN-{company}-{rn_idx:03d} | _(+{len(exprs)-5} expresiones adicionales — ver sql-statements)_ | {c_entry.get('comp_name', 'CALCULATOR')} | Alta |")
            rn_idx += 1

    if rn_idx == 1:
        output.append(f"| RN-{company}-001 | _(completar desde sql-statements.md)_ | | Alta |")

    output.append("")
    output.append("> Ver detalle completo en `sql-statements-{stem}.md`")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 7: Frecuencia y Volumen
    output.append("## 9. Frecuencia y Volumen")
    output.append("")
    output.append("| Atributo | Valor |")
    output.append("|---|---|")
    output.append(f"| Frecuencia de ejecución | {periodicity_label} — {periodicity_desc} |")
    output.append("| Día/hora de ejecución | _(completar — ej: día 3 de cada mes a las 2:00am Lima)_ |")
    output.append("| Volumen de input estimado | _(completar — filas aprox. por ejecución)_ |")
    output.append("| Volumen de output estimado | _(completar — registros en tabla destino)_ |")
    output.append("| SLA de disponibilidad | _(completar — ej: disponible antes del día 5)_ |")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 8: Criterios de Aceptación
    output.append("## 10. Criterios de Aceptación")
    output.append("")
    output.append("| # | Criterio | Métrica | Umbral |")
    output.append("|---|---|---|---|")
    output.append("| CA-001 | Disponibilidad puntual | Pipeline completado dentro del SLA | ✅ Siempre |")
    if column_mapping:
        output.append(f"| CA-002 | Completitud del output | % registros con campos clave no nulos | 100% |")
    output.append("| CA-003 | Unicidad de registros | Duplicados en clave primaria | 0 |")
    output.append("| CA-004 | Resultado igual al origen Matillion | Comparación de counts y sumas | Δ < 0.01% |")
    output.append("| CA-005 | Sin errores en producción | Ejecuciones fallidas en primeros 3 meses | 0 errores |")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 9: Fuera de Alcance
    output.append("## 11. Fuera de Alcance")
    output.append("")
    output.append("- Modificación de la lógica de negocio respecto al proceso Matillion original")
    output.append("- Rediseño del modelo de datos de la tabla destino")
    output.append("- Migración de otros jobs Matillion no incluidos en este brief")
    output.append("- _(completar — qué más queda fuera)_")
    output.append("")
    output.append("---")
    output.append("")

    # ─── SECCIÓN 10: Adjuntos
    output.append("## 12. Adjuntos / Referencias")
    output.append("")
    output.append("| Tipo | Descripción | Ruta |")
    output.append("|---|---|---|")
    output.append(f"| JSON Matillion | Export original del pipeline | `{original_stem}.json` |")
    output.append(f"| Análisis técnico | Lógica de negocio extraída | `logica-negocio-{json_stem}.md` |")
    output.append(f"| SQL completos | Todos los statements por tipo | `sql-statements-{json_stem}.md` |")
    output.append(f"| Mapa de orquestación | Grafo Mermaid del pipeline | `orchestration-map-{json_stem}.md` |")
    output.append("| DDL tabla destino | _(pendiente — extraer de BigQuery o definir)_ | _(ruta)_ |")
    output.append("")

    return "\n".join(output)


# ─── MAIN ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Matillion Pipeline Mapper: Analiza JSON exports y genera 3 documentos"
    )
    parser.add_argument("--input", required=True, help="Path al JSON Matillion export")
    parser.add_argument("--output", default="temporal", help="Directorio base de salida (default: temporal/)")

    args = parser.parse_args()

    # Validar entrada
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[ERROR] Archivo no existe: {input_path}")
        return

    output_dir = Path(args.output)
    output_dir.mkdir(exist_ok=True, parents=True)

    # Cargar JSON
    print(f"[...] Cargando {input_path.name}...")
    with open(input_path, 'r', encoding='utf-8') as f:
        raw = json.load(f)

    # Analizar
    print(f"[...] Analizando pipeline...")
    analysis = analyze_pipeline(raw)

    # Crear carpeta de output
    original_stem = input_path.stem
    json_stem = original_stem.replace('_', '-').lower()
    output_subdir = output_dir / json_stem
    output_subdir.mkdir(exist_ok=True, parents=True)

    # Detectar periodicidad
    periodicity_label, _ = _detect_periodicity(original_stem)
    print(f"[...] Periodicidad detectada: {periodicity_label}")

    # Generar documentos
    print(f"[...] Generando documentos...")

    docs = {
        f"logica-negocio-{json_stem}.md": generate_logica_negocio(analysis, json_stem),
        f"sql-statements-{json_stem}.md": generate_sql_statements(analysis, json_stem),
        f"orchestration-map-{json_stem}.md": generate_orchestration_map(analysis, json_stem),
        f"functional-brief-{json_stem}.md": generate_functional_brief(analysis, json_stem, original_stem),
    }

    for filename, content in docs.items():
        filepath = output_subdir / filename
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(content)
        lines = len(content.split('\n'))
        size = len(content.encode('utf-8'))
        print(f"[OK] {filename} ({lines} líneas, {size} bytes)")

    print("")
    print(f"[OK] Análisis completado en: {output_subdir}/")
    print(f"     Documentos generados: 4")
    print(f"     - Lógica de negocio: {analysis['num_orch_jobs']} orch jobs, {analysis['num_trans_jobs']} trans jobs")
    print(f"     - SQL statements: {len(analysis['all_sqls'])} componentes extraídos")
    print(f"     - Orchestration map: {analysis['total_components']} componentes totales")
    print(f"     - Functional brief: periodicidad={periodicity_label}")


if __name__ == "__main__":
    main()
