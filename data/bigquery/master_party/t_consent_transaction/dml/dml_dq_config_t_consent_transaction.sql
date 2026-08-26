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
   'sin duplicados de id',
   'no debe haber más de 1 fila por id — cubre RN-IBK-011 (2026-08-26): t_consent_transaction guarda solo el último evento por cliente, nunca dos filas para el mismo id. Reemplaza el chequeo anterior por customer_id+itc_company_id+consent_date (2026-08-21, sobre conset_transaction_id antes de eso, ambos ya obsoletos con este cambio de diseño)',
   'duplicidad', 'technical', 'critical',
   '${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}',
   'id',
   'SELECT id, COUNT(*) AS cnt FROM `${project_t_consent_transaction}.${dataset_t_consent_transaction}.t_consent_transaction` GROUP BY id HAVING cnt > 1',
   100, true, true, CURRENT_DATE(), SESSION_USER());
