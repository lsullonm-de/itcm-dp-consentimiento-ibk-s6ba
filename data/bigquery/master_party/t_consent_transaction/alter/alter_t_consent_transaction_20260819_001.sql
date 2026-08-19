-- alter_t_consent_transaction_20260819_001.sql
-- Descripción: agrega los campos DQ obligatorios (etapas.data_quality: true, REGLA 4 de
-- fac-data-rules-check) — data/standard/architecture/data-platform-layers.md §5.
--
-- NOTA: el modelo DQ actual de este módulo (sp_dq_t_consent_transaction.sql) valida a nivel de
-- TABLA (cuenta filas inválidas globalmente y registra en dq_control), no a nivel de FILA — por
-- eso estas 3 columnas quedan sin poblar (NULL) por ahora. Se agregan igual porque el estándar
-- las exige cuando data_quality está activo; si se decide implementar marcado por fila más
-- adelante, este es el lugar donde ya existen las columnas.

ALTER TABLE `${project_t_consent_transaction}.${dataset_t_consent_transaction}.${table_t_consent_transaction}`
ADD COLUMN IF NOT EXISTS dq_flag_ind INT64 OPTIONS(description='0=válido, 1=con observaciones DQ — no poblado aún, ver nota de este script'),
ADD COLUMN IF NOT EXISTS dq_control_msg STRING OPTIONS(description='Mensaje de regla DQ incumplida — no poblado aún, ver nota de este script'),
ADD COLUMN IF NOT EXISTS dq_config_id STRING OPTIONS(description='FK a dq_config.dq_config_id — no poblado aún, ver nota de este script');
