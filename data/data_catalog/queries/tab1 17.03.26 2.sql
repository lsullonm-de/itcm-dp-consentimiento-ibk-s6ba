-- ══════════════════════════════════════════════════════════════
-- KPIs CLIENTES OEC — EJECUCIÓN DIRECTA BIGQUERY
-- ══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════
-- SECCIÓN 0: FILTROS (parámetros del procedure)
-- Usa NULL o [] para "Todos"
-- ══════════════════════════════════════════════════════════════
DECLARE p_genero       ARRAY<STRING> DEFAULT NULL;   -- Ej: ['M', 'F']
DECLARE p_generacion   ARRAY<STRING> DEFAULT NULL;   -- Ej: ['Millennials']
DECLARE p_departamento ARRAY<STRING> DEFAULT NULL;   -- Ej: ['LIMA']
DECLARE p_seg_valor    ARRAY<STRING> DEFAULT NULL;   -- Ej: ['ALTO', 'MEDIO']
DECLARE p_seg_interes  ARRAY<STRING> DEFAULT NULL;   -- Ej: ['MODA']
DECLARE p_rango_edad   ARRAY<STRING> DEFAULT NULL;   -- Ej: ['26 - 35 años']
DECLARE p_contactable  ARRAY<STRING> DEFAULT NULL;   -- Ej: ['Contactable']

-- ══════════════════════════════════════════════════════════════
-- QUERY #1: TOTALES — Tarjetas KPI
-- Dashboard: Pestaña 1 — 4 tarjetas superiores
-- ══════════════════════════════════════════════════════════════
SELECT
  COUNT(*)                                                                                                                                                        AS clientes_itc,
  SUM(oe_cant_clientes_activos)                                                                                                                                   AS clientes_oec_12m,
  SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m > 0 AND sum_oe_numtrx_presencial_12m > 0, 1, 0))                                              AS clientes_oec_omnicanal,
  SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m > 0 AND sum_oe_numtrx_presencial_12m = 0, 1, 0))                                              AS clientes_oec_digital,
  SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m = 0 AND sum_oe_numtrx_presencial_12m > 0, 1, 0))                                              AS clientes_oec_presencial,
  SAFE_DIVIDE(SUM(oe_cant_clientes_activos), COUNT(*))                                                                                                            AS clientes_oec_12m_porc,
  SAFE_DIVIDE(SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m > 0 AND sum_oe_numtrx_presencial_12m > 0, 1, 0)), SUM(oe_cant_clientes_activos))  AS clientes_oec_omnicanal_porc,
  SAFE_DIVIDE(SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m > 0 AND sum_oe_numtrx_presencial_12m = 0, 1, 0)), SUM(oe_cant_clientes_activos))  AS clientes_oec_digital_porc,
  SAFE_DIVIDE(SUM(IF(oe_cant_clientes_activos = 1 AND sum_oe_numtrx_digital_12m = 0 AND sum_oe_numtrx_presencial_12m > 0, 1, 0)), SUM(oe_cant_clientes_activos))  AS clientes_oec_presencial_porc
FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
  AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
  AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
  AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
  AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
  AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
  AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable));

-- ══════════════════════════════════════════════════════════════════════════════
-- QUERY #2: VARIACIONES - Tarjetas KPI
-- Dashboard: Pestaña 1 — Variaciones en las tarjetas KPI
-- Compara periodo actual vs periodo anterior para calcular % de variación
-- ══════════════════════════════════════════════════════════════════════════════
SELECT
  SAFE_DIVIDE(SUM(oe_cant_clientes_activos)            - SUM(oe_cant_clientes_activos_1m),            SUM(oe_cant_clientes_activos_1m))            AS clientes_oec_12m_var_1m,
  SAFE_DIVIDE(SUM(oe_cant_clientes_omnicanal_activos)  - SUM(oe_cant_clientes_omnicanal_activos_1m),  SUM(oe_cant_clientes_omnicanal_activos_1m))  AS clientes_oec_omnicanal_var_1m,
  SAFE_DIVIDE(SUM(oe_cant_clientes_digital_activos)    - SUM(oe_cant_clientes_digital_activos_1m),    SUM(oe_cant_clientes_digital_activos_1m))    AS clientes_oec_digital_var_1m,
  SAFE_DIVIDE(SUM(oe_cant_clientes_presencial_activos) - SUM(oe_cant_clientes_presencial_activos_1m), SUM(oe_cant_clientes_presencial_activos_1m)) AS clientes_oec_presencial_var_1m
FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
  AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
  AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
  AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
  AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
  AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
  AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable));

-- ══════════════════════════════════════════════════════════════
-- QUERY #3: SEGMENTO VALOR OEC
-- Dashboard: Pestaña 1 — Barras "Segmento de Valor OEC"
-- ══════════════════════════════════════════════════════════════
WITH base_filtrada AS (
  SELECT oe_cant_clientes_activos, oe_seg_valor
FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
  AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
  AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
  AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
  AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
  AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
  AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
),
conteo AS (SELECT UPPER(oe_seg_valor) AS description, SUM(oe_cant_clientes_activos) AS value FROM base_filtrada GROUP BY 1)
SELECT description, value, SAFE_DIVIDE(value, SUM(value) OVER()) AS percentage
FROM conteo 
WHERE description is not null
ORDER BY value DESC;

-- ══════════════════════════════════════════════════════════════
-- QUERY #4: SEGMENTACIÓN INTERÉS OEC
-- Dashboard: Pestaña 1 — Segmentación Interés OE
-- ══════════════════════════════════════════════════════════════
WITH base_filtrada AS (
  SELECT oe_cant_clientes_activos, oe_seg_interes
  FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
  WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
),
conteo AS (
  SELECT
    CASE WHEN oe_seg_interes IS NULL OR oe_seg_interes = '' THEN 'NO DEFINIDO' ELSE UPPER(oe_seg_interes) END AS description,
    SUM(oe_cant_clientes_activos) AS value
  FROM base_filtrada GROUP BY 1
),
con_otros AS (
  SELECT
    CASE WHEN SAFE_DIVIDE(value, SUM(value) OVER()) < 0.01 THEN 'OTROS' ELSE description END AS description,
    value
  FROM conteo
),
agrupado AS (SELECT description, SUM(value) AS value FROM con_otros GROUP BY description)
SELECT description, value, SAFE_DIVIDE(value, SUM(value) OVER()) AS percentage
FROM agrupado ORDER BY value DESC;

-- ══════════════════════════════════════════════════════════════
-- QUERY #5: RANGO DE EDAD
-- Dashboard: Pestaña 1 — Barras "Rango de Edad"
-- ══════════════════════════════════════════════════════════════
WITH base_filtrada AS (
  SELECT oe_cant_clientes_activos, rango_edad
  FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
  WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
),
conteo AS (SELECT COALESCE(rango_edad, 'NO DEFINIDO') AS description, SUM(oe_cant_clientes_activos) AS value FROM base_filtrada GROUP BY 1)
SELECT description, value, SAFE_DIVIDE(value, SUM(value) OVER()) AS percentage
FROM conteo ORDER BY description;

-- ══════════════════════════════════════════════════════════════
-- QUERY #6: GENERACIÓN
-- Dashboard: Pestaña 1 — Barras "Generación"
-- ══════════════════════════════════════════════════════════════
WITH base_filtrada AS (
  SELECT oe_cant_clientes_activos, generacion
  FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
  WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
),
conteo AS (SELECT COALESCE(generacion, 'NO DEFINIDO') AS description, SUM(oe_cant_clientes_activos) AS value FROM base_filtrada GROUP BY 1)
SELECT description, value, SAFE_DIVIDE(value, SUM(value) OVER()) AS percentage
FROM conteo ORDER BY value DESC;

-- ══════════════════════════════════════════════════════════════════════════════
-- QUERY #7: GÉNERO
-- Dashboard: Pestaña 1 — Tarjetas Femenino / Masculino + porcentajes
-- ══════════════════════════════════════════════════════════════════════════════
SELECT
  SUM(oe_cant_clientes_activos)                                                   AS clientes_oec_12m,
  SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'M', 1, 0))                    AS clientes_oec_masculino,
  SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'F', 1, 0))                    AS clientes_oec_femenino,
  SAFE_DIVIDE(SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'M', 1, 0)),
              SUM(oe_cant_clientes_activos))                                      AS clientes_oec_masculino_porc,
  SAFE_DIVIDE(SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'F', 1, 0)),
              SUM(oe_cant_clientes_activos))                                      AS clientes_oec_femenino_porc,

  -- Variación género (periodo previo)
  SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'M', 1, 0))                 AS clientes_oec_masculino_1m,
  SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'F', 1, 0))                 AS clientes_oec_femenino_1m,
  SAFE_DIVIDE(
    SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'M', 1, 0))
    - SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'M', 1, 0)),
    NULLIF(SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'M', 1, 0)), 0))   AS clientes_oec_masculino_var_1m,
  SAFE_DIVIDE(
    SUM(IF(oe_cant_clientes_activos = 1 AND genero = 'F', 1, 0))
    - SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'F', 1, 0)),
    NULLIF(SUM(IF(oe_cant_clientes_activos_1m = 1 AND genero = 'F', 1, 0)), 0))   AS clientes_oec_femenino_var_1m
FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
  AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
  AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
  AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
  AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
  AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
  AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable));

-- ══════════════════════════════════════════════════════════════
-- QUERY #8: TOP DEPARTAMENTOS
-- Dashboard: Pestaña 1 — Barras Departamentos
-- ══════════════════════════════════════════════════════════════
WITH base_filtrada AS (
  SELECT oe_cant_clientes_activos, departamento
  FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
  WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero          IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion      IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento    IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor    IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes  IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
),
conteo AS (SELECT COALESCE(UPPER(departamento), 'NO DEFINIDO') AS description, SUM(oe_cant_clientes_activos) AS value FROM base_filtrada GROUP BY 1),
con_otros AS (
  SELECT CASE WHEN SAFE_DIVIDE(value, SUM(value) OVER()) < 0.01 THEN 'OTROS' ELSE description END AS description, value FROM conteo
),
agrupado AS (SELECT description, SUM(value) AS value FROM con_otros GROUP BY description)
SELECT description, value, SAFE_DIVIDE(value, SUM(value) OVER()) AS percentage
FROM agrupado ORDER BY value DESC;

-- ══════════════════════════════════════════════════════════════
-- QUERY #9: EVOLUTIVO
-- Dashboard: Pestaña 1 — Barras Evolutivo
-- ══════════════════════════════════════════════════════════════

WITH base AS (
  SELECT
    SUM(oe_cant_clientes_evol_total_1)  AS total_1,
    SUM(oe_cant_clientes_evol_total_2)  AS total_2,
    SUM(oe_cant_clientes_evol_total_3)  AS total_3,
    SUM(oe_cant_clientes_evol_total_4)  AS total_4,
    SUM(oe_cant_clientes_evol_total_5)  AS total_5,
    SUM(oe_cant_clientes_evol_total_6)  AS total_6,
    SUM(oe_cant_clientes_evol_total_7)  AS total_7,
    SUM(oe_cant_clientes_evol_total_8)  AS total_8,
    SUM(oe_cant_clientes_evol_total_9)  AS total_9,
    SUM(oe_cant_clientes_evol_total_10) AS total_10,
    SUM(oe_cant_clientes_evol_total_11) AS total_11,
    SUM(oe_cant_clientes_evol_total_12) AS total_12,
    SUM(oe_cant_clientes_evol_total_13) AS total_13,

    SUM(oe_cant_clientes_evol_omni_1)   AS omni_1,
    SUM(oe_cant_clientes_evol_omni_2)   AS omni_2,
    SUM(oe_cant_clientes_evol_omni_3)   AS omni_3,
    SUM(oe_cant_clientes_evol_omni_4)   AS omni_4,
    SUM(oe_cant_clientes_evol_omni_5)   AS omni_5,
    SUM(oe_cant_clientes_evol_omni_6)   AS omni_6,
    SUM(oe_cant_clientes_evol_omni_7)   AS omni_7,
    SUM(oe_cant_clientes_evol_omni_8)   AS omni_8,
    SUM(oe_cant_clientes_evol_omni_9)   AS omni_9,
    SUM(oe_cant_clientes_evol_omni_10)  AS omni_10,
    SUM(oe_cant_clientes_evol_omni_11)  AS omni_11,
    SUM(oe_cant_clientes_evol_omni_12)  AS omni_12,
    SUM(oe_cant_clientes_evol_omni_13)  AS omni_13,

    SUM(oe_cant_clientes_evol_digi_1)   AS digi_1,
    SUM(oe_cant_clientes_evol_digi_2)   AS digi_2,
    SUM(oe_cant_clientes_evol_digi_3)   AS digi_3,
    SUM(oe_cant_clientes_evol_digi_4)   AS digi_4,
    SUM(oe_cant_clientes_evol_digi_5)   AS digi_5,
    SUM(oe_cant_clientes_evol_digi_6)   AS digi_6,
    SUM(oe_cant_clientes_evol_digi_7)   AS digi_7,
    SUM(oe_cant_clientes_evol_digi_8)   AS digi_8,
    SUM(oe_cant_clientes_evol_digi_9)   AS digi_9,
    SUM(oe_cant_clientes_evol_digi_10)  AS digi_10,
    SUM(oe_cant_clientes_evol_digi_11)  AS digi_11,
    SUM(oe_cant_clientes_evol_digi_12)  AS digi_12,
    SUM(oe_cant_clientes_evol_digi_13)  AS digi_13,

    SUM(oe_cant_clientes_evol_pres_1)   AS pres_1,
    SUM(oe_cant_clientes_evol_pres_2)   AS pres_2,
    SUM(oe_cant_clientes_evol_pres_3)   AS pres_3,
    SUM(oe_cant_clientes_evol_pres_4)   AS pres_4,
    SUM(oe_cant_clientes_evol_pres_5)   AS pres_5,
    SUM(oe_cant_clientes_evol_pres_6)   AS pres_6,
    SUM(oe_cant_clientes_evol_pres_7)   AS pres_7,
    SUM(oe_cant_clientes_evol_pres_8)   AS pres_8,
    SUM(oe_cant_clientes_evol_pres_9)   AS pres_9,
    SUM(oe_cant_clientes_evol_pres_10)  AS pres_10,
    SUM(oe_cant_clientes_evol_pres_11)  AS pres_11,
    SUM(oe_cant_clientes_evol_pres_12)  AS pres_12,
    SUM(oe_cant_clientes_evol_pres_13)  AS pres_13

FROM `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
WHERE (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR genero        IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR generacion    IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR departamento  IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR oe_seg_valor  IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR oe_seg_interes IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR rango_edad      IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR flag_dato_contacto  IN UNNEST(p_contactable))
)

SELECT
  t.orden,
  t.month,
  t.value,
  t.type_evolutivo
FROM base,
UNNEST([
  -- ── DIGITAL ───────────────────────────────────────────────
  STRUCT(1  AS orden, 'Ene25'   AS month, digi_1  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(2  AS orden, 'Feb25'   AS month, digi_2  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(3  AS orden, 'Mar25'   AS month, digi_3  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(4  AS orden, 'Abr25'   AS month, digi_4  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(5  AS orden, 'May25'   AS month, digi_5  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(6  AS orden, 'Jun25'   AS month, digi_6  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(7  AS orden, 'Jul25'   AS month, digi_7  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(8  AS orden, 'Ago25'   AS month, digi_8  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(9  AS orden, 'Sep25'   AS month, digi_9  AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(10 AS orden, 'Oct25'   AS month, digi_10 AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(11 AS orden, 'Nov25'   AS month, digi_11 AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(12 AS orden, 'Dic25'   AS month, digi_12 AS value, 'DIGITAL' AS type_evolutivo),
  STRUCT(13 AS orden, 'Ene26' AS month, digi_13 AS value, 'DIGITAL' AS type_evolutivo),
  -- ── OMNICANAL ─────────────────────────────────────────────
  STRUCT(1  AS orden, 'Ene25'   AS month, omni_1  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(2  AS orden, 'Feb25'   AS month, omni_2  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(3  AS orden, 'Mar25'   AS month, omni_3  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(4  AS orden, 'Abr25'   AS month, omni_4  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(5  AS orden, 'May25'   AS month, omni_5  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(6  AS orden, 'Jun25'   AS month, omni_6  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(7  AS orden, 'Jul25'   AS month, omni_7  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(8  AS orden, 'Ago25'   AS month, omni_8  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(9  AS orden, 'Sep25'   AS month, omni_9  AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(10 AS orden, 'Oct25'   AS month, omni_10 AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(11 AS orden, 'Nov25'   AS month, omni_11 AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(12 AS orden, 'Dic25'   AS month, omni_12 AS value, 'OMNICANAL' AS type_evolutivo),
  STRUCT(13 AS orden, 'Ene26' AS month, omni_13 AS value, 'OMNICANAL' AS type_evolutivo),
  -- ── PRESENCIAL ────────────────────────────────────────────
  STRUCT(1  AS orden, 'Ene25'   AS month, pres_1  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(2  AS orden, 'Feb25'   AS month, pres_2  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(3  AS orden, 'Mar25'   AS month, pres_3  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(4  AS orden, 'Abr25'   AS month, pres_4  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(5  AS orden, 'May25'   AS month, pres_5  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(6  AS orden, 'Jun25'   AS month, pres_6  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(7  AS orden, 'Jul25'   AS month, pres_7  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(8  AS orden, 'Ago25'   AS month, pres_8  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(9  AS orden, 'Sep25'   AS month, pres_9  AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(10 AS orden, 'Oct25'   AS month, pres_10 AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(11 AS orden, 'Nov25'   AS month, pres_11 AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(12 AS orden, 'Dic25'   AS month, pres_12 AS value, 'PRESENCIAL' AS type_evolutivo),
  STRUCT(13 AS orden, 'Ene26' AS month, pres_13 AS value, 'PRESENCIAL' AS type_evolutivo),
  -- ── TOTAL ─────────────────────────────────────────────────
  STRUCT(1  AS orden, 'Ene25'   AS month, total_1  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(2  AS orden, 'Feb25'   AS month, total_2  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(3  AS orden, 'Mar25'   AS month, total_3  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(4  AS orden, 'Abr25'   AS month, total_4  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(5  AS orden, 'May25'   AS month, total_5  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(6  AS orden, 'Jun25'   AS month, total_6  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(7  AS orden, 'Jul25'   AS month, total_7  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(8  AS orden, 'Ago25'   AS month, total_8  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(9  AS orden, 'Sep25'   AS month, total_9  AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(10 AS orden, 'Oct25'   AS month, total_10 AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(11 AS orden, 'Nov25'   AS month, total_11 AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(12 AS orden, 'Dic25'   AS month, total_12 AS value, 'TOTAL' AS type_evolutivo),
  STRUCT(13 AS orden, 'Ene26' AS month, total_13 AS value, 'TOTAL' AS type_evolutivo)
]) AS t

ORDER BY t.type_evolutivo, t.orden;

-- ══════════════════════════════════════════════════════════════
-- QUERY: CONSUMO POR CATEGORÍAS (Gráfico de Barras con Tabs)
-- Desempaqueta el ARRAY y aplica los filtros demográficos
-- ══════════════════════════════════════════════════════════════

WITH base_filtrada AS (
  SELECT
    c.id,
    cat.division_producto,
    cat.departamento_producto,
    cat.linea_producto,
    cat.mto_venta
  FROM `itc-data-governance-01.gnunurat.dv_inretail_cliente_oec` c,
  UNNEST(c.detalle_consumo_categorias) AS cat
  WHERE oe_cant_clientes_activos = 1
    AND (p_genero IS NULL       OR ARRAY_LENGTH(p_genero) = 0       OR 'Todos' IN UNNEST(p_genero)       OR c.genero             IN UNNEST(p_genero))
    AND (p_generacion IS NULL   OR ARRAY_LENGTH(p_generacion) = 0   OR 'Todos' IN UNNEST(p_generacion)   OR c.generacion         IN UNNEST(p_generacion))
    AND (p_departamento IS NULL OR ARRAY_LENGTH(p_departamento) = 0 OR 'Todos' IN UNNEST(p_departamento) OR c.departamento       IN UNNEST(p_departamento))
    AND (p_seg_valor IS NULL    OR ARRAY_LENGTH(p_seg_valor) = 0    OR 'Todos' IN UNNEST(p_seg_valor)    OR c.oe_seg_valor       IN UNNEST(p_seg_valor))
    AND (p_seg_interes IS NULL  OR ARRAY_LENGTH(p_seg_interes) = 0  OR 'Todos' IN UNNEST(p_seg_interes)  OR c.oe_seg_interes     IN UNNEST(p_seg_interes))
    AND (p_rango_edad IS NULL   OR ARRAY_LENGTH(p_rango_edad) = 0   OR 'Todos' IN UNNEST(p_rango_edad)   OR c.rango_edad         IN UNNEST(p_rango_edad))
    AND (p_contactable IS NULL  OR ARRAY_LENGTH(p_contactable) = 0  OR 'Todos' IN UNNEST(p_contactable)  OR c.flag_dato_contacto IN UNNEST(p_contactable))
),

niveles_producto AS (
    -- NIVEL 1: División
    SELECT
        'División' AS nivel,
        division_producto AS etiqueta_producto,
        SUM(mto_venta) AS venta_neta,
        count(distinct(id)) clientes_compradores,
    FROM base_filtrada
    WHERE division_producto IS NOT NULL
    GROUP BY 1, 2

    UNION ALL

    -- NIVEL 2: Departamento
    SELECT
        'Departamento' AS nivel,
        departamento_producto AS etiqueta_producto,
        SUM(mto_venta) AS venta_neta,
        count(distinct(id)) clientes_compradores,
    FROM base_filtrada
    WHERE departamento_producto IS NOT NULL
    GROUP BY 1, 2

    UNION ALL

    -- NIVEL 3: Línea
    SELECT
        'Línea' AS nivel,
        linea_producto AS etiqueta_producto,
        SUM(mto_venta) AS venta_neta,
        count(distinct(id)) clientes_compradores,
    FROM base_filtrada
    WHERE linea_producto IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    nivel AS tipo_filtro,           
    etiqueta_producto AS nombre,    
    SAFE_DIVIDE(venta_neta, clientes_compradores) AS valor            
FROM niveles_producto
ORDER BY
    CASE nivel WHEN 'División' THEN 1 WHEN 'Departamento' THEN 2 ELSE 3 END,
    valor DESC;
