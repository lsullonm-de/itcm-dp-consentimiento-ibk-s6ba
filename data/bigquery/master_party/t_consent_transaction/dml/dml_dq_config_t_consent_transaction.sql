-- DQ Config: t_consent_transaction
-- Spec: spec-ibk-20260819-001 | Ejecutar en dev para registrar las reglas (bigquery_dml — solo dev)
--
-- Mapeo de vocabulario: el spec (spec-manifest.md) usa dimension: completitud|unicidad|validez;
-- el framework central (data-quality.md) usa dq_dimension: completitud|conformidad|consistencia|
-- precision|duplicidad|integridad. Mapeo aplicado aquí: unicidad->duplicidad, validez->conformidad.
-- criticidad: alta (spec) -> criticality: critical. umbral_max_pct_invalidos: 0 -> threshold_pct: 100.

INSERT INTO `${project_operation}.${dataset_dq}.dq_config`
  (dq_config_id, rule_name, rule_description, dq_dimension, rule_type, criticality,
   target_table, target_column, sql_rule, threshold_pct, alert_enabled, is_active,
   created_date, created_user)
VALUES
  ('DQ-IBK-T_CONSENT_TRANSACTION-001',
   'id no nulo',
   'id no debe ser nulo (registros sin match en iden_itc_party_prd) — cubre RN-IBK-003',
   'completitud', 'technical', 'critical',
   '${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}',
   'id',
   'SELECT * FROM `${project_t_consent_transaction}.${dataset_t_consent_transaction}.t_consent_transaction` WHERE id IS NULL',
   100, true, true, CURRENT_DATE(), SESSION_USER()),

  ('DQ-IBK-T_CONSENT_TRANSACTION-002',
   'consent_date no nulo',
   'consent_date debe venir siempre del contenido real del archivo — cubre RN-IBK-004',
   'completitud', 'technical', 'critical',
   '${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}',
   'consent_date',
   'SELECT * FROM `${project_t_consent_transaction}.${dataset_t_consent_transaction}.t_consent_transaction` WHERE consent_date IS NULL',
   100, true, true, CURRENT_DATE(), SESSION_USER()),

  ('DQ-IBK-T_CONSENT_TRANSACTION-003',
   'sin duplicados de conset_transaction_id',
   'sin duplicados de conset_transaction_id por itc_company_id + consent_date — cubre RN-IBK-005',
   'duplicidad', 'technical', 'critical',
   '${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}',
   'conset_transaction_id',
   'SELECT itc_company_id, consent_date, conset_transaction_id, COUNT(*) AS cnt FROM `${project_t_consent_transaction}.${dataset_t_consent_transaction}.t_consent_transaction` GROUP BY itc_company_id, consent_date, conset_transaction_id HAVING cnt > 1',
   100, true, true, CURRENT_DATE(), SESSION_USER());
