-- DDL: dq_control — resultados de ejecución de reglas DQ para este módulo
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk | etapas.data_quality: true
-- Generado por: fac-data-stage-dataops (fix post-COMPLIANCE, 2026-08-20)
--
-- ${dataset_dq} es compartido entre módulos (ver env_dev.json) — CREATE TABLE IF NOT EXISTS
-- la hace segura de desplegar aunque otro módulo ya la haya creado antes.
-- Esquema tomado de data/standard/data-quality.md Sección "Tablas del modelo DQ".

CREATE TABLE IF NOT EXISTS `${project_operation}.${dataset_dq}.dq_control`
(
  dq_control_id       STRING NOT NULL  OPTIONS(description='UUID de la ejecución'),
  dq_config_id        STRING NOT NULL  OPTIONS(description='FK → dq_config.dq_config_id'),
  execution_date      DATE NOT NULL    OPTIONS(description='Fecha de ejecución (partición)'),
  process_date        DATE             OPTIONS(description='Fecha del proceso evaluado'),
  total_records       INT64            OPTIONS(description='Total de registros analizados'),
  valid_records       INT64            OPTIONS(description='Registros que cumplen la regla'),
  invalid_records     INT64            OPTIONS(description='Registros que NO cumplen la regla'),
  pct_compliance      FLOAT64          OPTIONS(description='valid_records / total_records * 100'),
  dq_status           STRING           OPTIONS(description='pass | warn | fail'),
  execution_seconds   INT64,
  error_message       STRING           OPTIONS(description='Si el SP falló al ejecutar')
)
PARTITION BY execution_date
OPTIONS(
  description = 'Resultados de ejecución de reglas de Data Quality — tabla compartida entre módulos del dataset_dq',
  labels = [('capa', 'control'), ('modulo', 'compartido')]
);
