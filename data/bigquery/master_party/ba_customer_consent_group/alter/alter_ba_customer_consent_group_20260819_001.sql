-- alter_ba_customer_consent_group_20260819_001.sql
-- Descripción: agrega los campos DQ obligatorios (etapas.data_quality: true, REGLA 4 de
-- fac-data-rules-check) — data/standard/architecture/data-platform-layers.md §5.
-- Ver nota sobre poblamiento (NULL por ahora) en alter_t_consent_transaction_20260819_001.sql.

ALTER TABLE `${project_ba_customer_consent_group}.${dataset_ba_customer_consent_group}.${table_ba_customer_consent_group}`
ADD COLUMN IF NOT EXISTS dq_flag_ind INT64 OPTIONS(description='0=válido, 1=con observaciones DQ — no poblado aún, ver nota en alter_t_consent_transaction_20260819_001.sql'),
ADD COLUMN IF NOT EXISTS dq_control_msg STRING OPTIONS(description='Mensaje de regla DQ incumplida — no poblado aún'),
ADD COLUMN IF NOT EXISTS dq_config_id STRING OPTIONS(description='FK a dq_config.dq_config_id — no poblado aún');
