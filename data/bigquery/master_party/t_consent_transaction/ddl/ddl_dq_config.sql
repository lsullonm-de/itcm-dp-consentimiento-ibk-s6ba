-- DDL: dq_config — registro de reglas DQ definidas para este módulo
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | etapas.data_quality: true
-- Generado por: fac-data-stage-dataops (fix post-COMPLIANCE, 2026-08-20)
--
-- ${dataset_dq} es compartido entre módulos (ver env_dev.json) — CREATE TABLE IF NOT EXISTS
-- la hace segura de desplegar aunque otro módulo ya la haya creado antes.
-- Esquema tomado de data/standard/data-quality.md Sección "Tablas del modelo DQ".

CREATE TABLE IF NOT EXISTS `${project_operation}.${dataset_dq}.dq_config`
(
  dq_config_id        STRING NOT NULL   OPTIONS(description='ID único: DQ-[EMPRESA]-[TABLA]-[NNN]'),
  rule_name           STRING NOT NULL   OPTIONS(description='Nombre corto de la regla'),
  rule_description    STRING            OPTIONS(description='Descripción funcional'),
  dq_dimension        STRING NOT NULL   OPTIONS(description='completitud | conformidad | consistencia | precision | duplicidad | integridad'),
  rule_type           STRING NOT NULL   OPTIONS(description='technical | business'),
  criticality         STRING NOT NULL   OPTIONS(description='critical | high | medium | low'),
  target_table        STRING NOT NULL   OPTIONS(description='proyecto.dataset.tabla evaluada'),
  target_column       STRING            OPTIONS(description='Columna específica (null si es a nivel tabla)'),
  sql_rule            STRING NOT NULL   OPTIONS(description='Query que retorna las filas INVÁLIDAS'),
  threshold_pct       FLOAT64 NOT NULL  OPTIONS(description='Umbral mínimo de cumplimiento (0-100)'),
  alert_enabled       BOOL DEFAULT TRUE OPTIONS(description='Activar alerta Pub/Sub si se incumple'),
  is_active           BOOL DEFAULT TRUE,
  created_date        DATE,
  created_user        STRING
)
PARTITION BY created_date
OPTIONS(
  description = 'Configuración de reglas de Data Quality — tabla compartida entre módulos del dataset_dq',
  labels = [('capa', 'control'), ('modulo', 'compartido')]
);
