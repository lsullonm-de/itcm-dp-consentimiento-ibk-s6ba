CREATE OR REPLACE TABLE gnunurat.aux_segmentacion_valor_oe AS
WITH
-- 1. Filtramos la tabla base y calculamos el monto anual una sola vez
base_data AS (
  SELECT 
    ID_INTERCORP AS ID,
    oe_mtoprom_12m * 12 AS mto_anual
  FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
  WHERE process_date = '2026-02-01'
    AND oe_mtoprom_12m > 0
),

-- 2. Calculamos el límite TOP
tmp_top AS (
  SELECT AVG(mto_anual) AS LIMITE_TOP
  FROM base_data
  WHERE mto_anual < 10000
),

-- 3. Calculamos el límite VIP cruzando con el límite TOP
tmp_vip AS (
  SELECT AVG(b.mto_anual) AS LIMITE_VIP
  FROM base_data b
  CROSS JOIN tmp_top t
  WHERE b.mto_anual > t.LIMITE_TOP 
    AND b.mto_anual < 10000
)

-- 4. Asignamos los segmentos
SELECT
  CAST('2026-02-01' AS DATE) AS PROCESS_DATE,
  b.ID,
  CASE
    WHEN b.mto_anual >= v.LIMITE_VIP THEN 'CLIENTE VIP'
    WHEN b.mto_anual >= t.LIMITE_TOP THEN 'CLIENTE TOP'
    ELSE 'CLIENTE REGULAR'
  END AS oe_seg_valor
FROM base_data b
CROSS JOIN tmp_top t
CROSS JOIN tmp_vip v;



INSERT INTO gnunurat.aux_segmentacion_valor_oe (PROCESS_DATE, ID, oe_seg_valor)
WITH
base_data AS (
  SELECT 
    process_date,
    ID_INTERCORP AS ID,
    oe_mtoprom_12m * 12 AS mto_anual
  FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
  -- Reemplaza esto por tu rango de parámetros (ej. BETWEEN @fecha_inicio AND @fecha_fin)
  WHERE process_date BETWEEN '2024-01-01' AND '2026-01-31' 
    AND oe_mtoprom_12m > 0
),

tmp_top AS (
  SELECT 
    process_date, 
    AVG(mto_anual) AS LIMITE_TOP
  FROM base_data
  WHERE mto_anual < 10000
  GROUP BY process_date -- Calculamos el límite por cada día/mes
),

tmp_vip AS (
  SELECT 
    b.process_date, 
    AVG(b.mto_anual) AS LIMITE_VIP
  FROM base_data b
  JOIN tmp_top t ON b.process_date = t.process_date
  WHERE b.mto_anual > t.LIMITE_TOP 
    AND b.mto_anual < 10000
  GROUP BY b.process_date -- Calculamos el límite VIP por cada día/mes
)

SELECT
  b.process_date,
  b.ID,
  CASE
    WHEN b.mto_anual >= v.LIMITE_VIP THEN 'CLIENTE VIP'
    WHEN b.mto_anual >= t.LIMITE_TOP THEN 'CLIENTE TOP'
    ELSE 'CLIENTE REGULAR'
  END AS oe_seg_valor
FROM base_data b
JOIN tmp_top t ON b.process_date = t.process_date
JOIN tmp_vip v ON b.process_date = v.process_date;