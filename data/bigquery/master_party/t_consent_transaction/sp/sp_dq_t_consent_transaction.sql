-- SP DQ: valida las reglas de calidad de t_consent_transaction (etapas.data_quality: true)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk
-- Generado por: fac-data-stage-data-quality
--
-- Itera las reglas activas para esta tabla en dq_config y registra el resultado en dq_control.
-- NOTA 1: dq_config/dq_control se referencian con ${project_operation}.${dataset_dq} — variables
-- de despliegue, resueltas en tiempo de deploy (no pueden ser parámetros IN STRING: BigQuery
-- exige que el nombre de tabla del FROM de un FOR loop sea estático en tiempo de compilación).
-- NOTA 2: a diferencia de la plantilla genérica del estándar, sql_rule aquí NO usa un
-- placeholder {process_date} — las reglas DQ-IBK-T_CONSENT_TRANSACTION-* validan invariantes
-- sobre TODA la tabla (ej. "nunca debe haber id NULL"), no solo el batch del día. Por eso
-- v_total también cuenta la tabla completa, sin filtrar por v_process_date. v_process_date solo
-- se usa para dejar trazabilidad de en qué corrida se ejecutó el chequeo (dq_control.process_date).

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_dq_t_consent_transaction`(
  v_project_analytics  STRING,   -- proyecto de la tabla evaluada
  v_dataset_analytics  STRING,
  v_table_destino      STRING,
  v_process_date       DATE
)
BEGIN

  DECLARE v_target_table STRING;
  DECLARE v_total         INT64;
  DECLARE v_invalidos     INT64;
  DECLARE v_pct           FLOAT64;
  DECLARE v_status        STRING;

  SET v_target_table = CONCAT(v_project_analytics, '.', v_dataset_analytics, '.', v_table_destino);

  FOR rule IN (
    SELECT dq_config_id, sql_rule, threshold_pct, criticality
    FROM `${project_operation}.${dataset_dq}.dq_config`
    WHERE target_table = v_target_table
      AND is_active = TRUE
  )
  DO

    -- Filas inválidas — sql_rule ya viene con la referencia completa a la tabla (resuelta por
    -- Dataops al desplegar dml_dq_config_t_consent_transaction.sql)
    EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*) FROM (', rule.sql_rule, ')') INTO v_invalidos;

    -- Total de filas de la tabla completa (sin filtro de fecha — ver NOTA 2)
    EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*) FROM `', v_target_table, '`') INTO v_total;

    SET v_pct = IF(v_total = 0, 100.0, ROUND((v_total - v_invalidos) / v_total * 100, 2));

    SET v_status = CASE
      WHEN v_pct >= rule.threshold_pct THEN 'pass'
      WHEN v_pct >= rule.threshold_pct - 5 THEN 'warn'
      ELSE 'fail'
    END;

    INSERT INTO `${project_operation}.${dataset_dq}.dq_control`
      (dq_control_id, dq_config_id, execution_date, process_date,
       total_records, valid_records, invalid_records, pct_compliance, dq_status)
    VALUES
      (GENERATE_UUID(), rule.dq_config_id, CURRENT_DATE(), v_process_date,
       v_total, v_total - v_invalidos, v_invalidos, v_pct, v_status);

  END FOR;

END;
