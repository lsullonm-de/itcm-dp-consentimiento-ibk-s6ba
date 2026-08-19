-- DQ Config: ba_customer_consent_group
-- Spec: spec-ibk-20260819-001 | Ejecutar en dev para registrar las reglas (bigquery_dml — solo dev)
-- Ver notas de mapeo de vocabulario en dml_dq_config_t_consent_transaction.sql

INSERT INTO `${project_operation}.${dataset_dq}.dq_config`
  (dq_config_id, rule_name, rule_description, dq_dimension, rule_type, criticality,
   target_table, target_column, sql_rule, threshold_pct, alert_enabled, is_active,
   created_date, created_user)
VALUES
  ('DQ-IBK-BA_CUSTOMER_CONSENT_GROUP-001',
   'itc_company_id válido',
   'itc_company_id debe estar en (000, 1000) — cubre RN-IBK-006 (proxy: conset_id/consent_type no se persisten en este output)',
   'conformidad', 'business', 'critical',
   '${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.${table_ba_customer_consent_group}',
   'itc_company_id',
   'SELECT * FROM `${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.ba_customer_consent_group` WHERE itc_company_id NOT IN (\'000\',\'1000\')',
   100, true, true, CURRENT_DATE(), SESSION_USER()),

  ('DQ-IBK-BA_CUSTOMER_CONSENT_GROUP-002',
   'sin duplicados de id',
   'sin duplicados de id por itc_company_id + consent_date — cubre RN-IBK-007',
   'duplicidad', 'technical', 'critical',
   '${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.${table_ba_customer_consent_group}',
   'id',
   'SELECT itc_company_id, consent_date, id, COUNT(*) AS cnt FROM `${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.ba_customer_consent_group` GROUP BY itc_company_id, consent_date, id HAVING cnt > 1',
   100, true, true, CURRENT_DATE(), SESSION_USER());
