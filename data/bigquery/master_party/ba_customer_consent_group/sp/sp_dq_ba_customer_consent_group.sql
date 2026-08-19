-- SP DQ: valida las reglas de calidad de ba_customer_consent_group (etapas.data_quality: true)
-- Spec: spec-ibk-20260819-001 | Módulo: consentimiento-ibk
-- Generado por: fac-data-stage-data-quality
-- Ver notas de diseño en sp_dq_t_consent_transaction.sql (misma estructura, mismo dataset dq).

CREATE OR REPLACE PROCEDURE `${project_operation}.${dataset_sp}.sp_dq_ba_customer_consent_group`(
  v_project_analytics  STRING,
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

    EXECUTE IMMEDIATE CONCAT('SELECT COUNT(*) FROM (', rule.sql_rule, ')') INTO v_invalidos;

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
