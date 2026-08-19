-- ══════════════════════════════════════════════════════════════════════════════
-- ARCHIVO: 01_crear_tabla_input_optimizado.sql
-- TABLA:   itc-data-governance-01.gnunurat.dv_inretail_cliente_oec
-- OPTIMIZACIÓN v3: 
--  1. Tabla Seg2 como Driver Principal (Elimina scan de demographic S1).
--  2. Reemplazo de +15 variables Corporate y RCC directo desde Seg2.
--  3. Fusión de CTEs para evitar doble proyección.
--  4. Transaccional anidado con ARRAY_AGG para evitar Fan-Out.
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE `itc-data-governance-01.gnunurat.dv_inretail_cliente_oec`
CLUSTER BY genero, generacion, departamento, oe_seg_interes
AS
WITH 

cliente_segmentacion as
(
  select avg(oe_mtoprom_12m*12) prom_12m
  from `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
  where process_date = "2026-02-01"
    and oe_mtoprom_12m*12 > 0
    and oe_mtoprom_12m*12 < 10000
),

cliente_top_top as
(
  select avg(a.oe_mtoprom_12m*12) prom_12m_top_top
  from `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` a
  CROSS JOIN cliente_segmentacion b
  where a.process_date = "2026-02-01"
    and a.oe_mtoprom_12m*12 > b.prom_12m
    and a.oe_mtoprom_12m*12 < 10000
),

clientes_base AS (
  SELECT
    -- ── IDENTIFICADOR ─────────────────────────────────────
    seg2.id,

    -- ── SOCIODEMOGRÁFICOS (Directo desde Seg2) ────────────
    CASE 
      WHEN seg2.genero IS NULL OR TRIM(seg2.genero) IN ('', '-') THEN 'NO DEFINIDO'
      ELSE UPPER(TRIM(seg2.genero)) 
    END AS genero,

    CASE
      WHEN seg2.edad IS NULL THEN 'OTRA GENERACION'
      WHEN (2026 - seg2.edad) BETWEEN 1997 AND 2012 THEN 'MILLENNIALS'
      WHEN (2026 - seg2.edad) BETWEEN 1981 AND 1996 THEN 'GENERACION X'
      WHEN (2026 - seg2.edad) BETWEEN 1965 AND 1980 THEN 'BABY BOOMERS'
      WHEN (2026 - seg2.edad) BETWEEN 1946 AND 1964 THEN 'SILENT GENERATION'
      WHEN (2026 - seg2.edad) >= 2013               THEN 'GENERACION Z'
      ELSE 'OTRA GENERACION'
    END AS generacion,

    COALESCE(seg2.rango_edad, 'NO DEFINIDO') AS rango_edad,
    COALESCE(seg2.departamento, 'NO DEFINIDO') AS departamento,
    IF(seg2.flag_contactable = 1, 'Contactable', 'No Contactable') AS flag_dato_contacto,

    -- ── SEGMENTOS ─────────────────────────────────────────
    IFNULL(s2.segmento_itc, 'NO DEFINIDO') AS segmento_itc, /* Cambiar por el de Aron */
    UPPER(IFNULL(corp.oe_seg_interes, 'NO DEFINIDO')) AS oe_seg_interes,
    
    CASE
      WHEN rt.oe_mtoprom_12m*12 >= top.prom_12m_top_top THEN "CLIENTE VIP"
      WHEN rt.oe_mtoprom_12m*12 >= seg.prom_12m THEN "CLIENTE TOP"
      WHEN rt.oe_mtoprom_12m*12 < seg.prom_12m THEN "CLIENTE REGULAR"
    END AS oe_seg_valor,

    COALESCE(seg2.flag_identificado_itc, 0) AS cant_clientes_itc, /* Cambiar por activo ITC */

    -- ── FLAGS OEC (El CASE ya devuelve 0, no necesita COALESCE extra)
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 THEN 1 ELSE 0 END AS oe_cant_clientes_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m > 0 AND rt.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_omnicanal_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m > 0 AND rt.oe_numtrx_presencial_12m = 0 THEN 1 ELSE 0 END AS oe_cant_clientes_digital_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m = 0 AND rt.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_presencial_activos,

    /* Cambiar cuando se tenga procesado un mes anterior */
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m > 0 AND rt_pa.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_omnicanal_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m > 0 AND rt_pa.oe_numtrx_presencial_12m = 0 THEN 1 ELSE 0 END AS oe_cant_clientes_digital_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m = 0 AND rt_pa.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_presencial_activos_1m,

    COALESCE(rt.oe_numtrx_digital_12m, 0) AS sum_oe_numtrx_digital_12m,
    COALESCE(rt.oe_numtrx_presencial_12m, 0) AS sum_oe_numtrx_presencial_12m,

    -- ── PARTICIPACIÓN GRUPO CORPORATE (Directo de Seg2) ───
    CASE WHEN seg2.flag_activo_supermercados_peruanos_itc = 1 AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_spsa,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1       AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 THEN 1 ELSE 0 END AS cant_clientes_oe,
    CASE WHEN seg2.flag_cliente_foh_rcc_ult_foto = 1          AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_foh,
    CASE WHEN seg2.flag_rp = 1                                AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_rp,
    CASE WHEN seg2.flag_activo_promart_itc = 1                AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_pro,
    CASE WHEN seg2.flag_activo_farmacias_peruanas_itc = 1     AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_inkf, /* No hay solo inka*/
    CASE WHEN seg2.flag_activo_farmacias_peruanas_itc = 1     AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_mfarm,/* No hay solo mifa*/
    CASE WHEN seg2.flag_cliente_ibk_rcc_ult_foto = 1          AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_ibk,
    CASE WHEN seg2.flag_fidelidad = 1                         AND seg2.flag_identificado_itc = 1                                                          THEN 1 ELSE 0 END AS cant_clientes_fidelidad,
    
    COALESCE(seg2.flag_activo_retail,0) AS cant_clientes_retail,

    /* Cambiar cuando se tenga procesado un mes anterior */
    IF(rt_pa.oe_mtoprom_12m>0, 1, 0) AS cant_clientes_oe_1m,
    GREATEST(
      IF(rt_pa.spsa_mtoprom_12m > 0, 1, 0), IF(rt_pa.oe_mtoprom_12m > 0, 1, 0),
      IF(rt_pa.far_mtoprom_12m > 0, 1, 0), IF(rt_pa.pro_mtoprom_12m > 0, 1, 0)
    ) AS cant_clientes_retail_1m,

    -- ── CROSS-SELL ────────────────────────────────────────
    cli_perfil.nro_empresas_retail_estandar,
    cli_perfil.empresa_cross_retail,

    -- ── RCC ENDEUDAMIENTO Y PRODUCTOS (Fusión r + Seg2) ───
    COALESCE(r.mto_deuda_total, 0) AS sum_mto_deuda_total,
    COALESCE(r_pa.mto_deuda_total, 0) AS sum_mto_deuda_total_1m,
    
    COALESCE(seg2.flag_deuda_hipotecaria_ult_foto, 0) AS clientes_deuda_hipotecaria,
    COALESCE(seg2.flag_deuda_prestamo_personal_vehicular, 0) AS clientes_deuda_prestamo_vehicular,
    
    COALESCE(seg2.flag_tiene_tc_ult_foto, 0) AS clientes_tiene_tc,
    COALESCE(r_pa.Flag_tiene_tc, 0) AS clientes_tiene_tc_1m,
    
    COALESCE(r.mto_deuda_directa_tc_consumo, 0) AS sum_mto_deuda_tc,
    COALESCE(r_pa.mto_deuda_directa_tc_consumo, 0) AS sum_mto_deuda_tc_1m,

    IF(seg2.mto_deuda_directa_toh_ult_foto > 0, 1, 0) AS clientes_deuda_consumo_toh,
    COALESCE(r_pa.Flag_deuda_directa_consumo_toh, 0) AS clientes_deuda_consumo_toh_1m,
    
    COALESCE(seg2.mto_deuda_directa_toh_ult_foto, 0) AS sum_mto_deuda_tc_toh,
    COALESCE(r_pa.mto_deuda_directa_tc_consumo_toh, 0) AS sum_mto_deuda_tc_toh_1m,
    
    IF(rt.oe_mtoprom_12m > 0 AND seg2.mto_deuda_directa_toh_ult_foto > 0, 1, 0) AS cant_clientes_oe_toh,
    IF(rt_pa.oe_mtoprom_12m > 0 AND r_pa.mto_deuda_directa_tc_consumo_toh > 0, 1, 0) AS cant_clientes_oe_toh_1m,

    COALESCE(seg2.flag_cliente_foh_rcc_ult_foto, 0) AS cant_clientes_tarjeta_foh,
    COALESCE(seg2.flag_cliente_ibk_rcc_ult_foto, 0) AS clientes_tarjeta_ibk,

    COALESCE(seg2.mto_deuda_directa_falabella_ult_foto, 0) AS sum_mto_deuda_directa_falabella,
    COALESCE(r_pa.mto_deuda_directa_falabella, 0) AS sum_mto_deuda_directa_falabella_1m,
    COALESCE(seg2.mto_deuda_directa_falabella_ult_foto, 0) AS sum_mto_deuda_tc_falabella,
    COALESCE(seg2.mto_deuda_directa_ripley_ult_foto, 0) AS sum_mto_deuda_tc_ripley,
    COALESCE(seg2.mto_deuda_directa_cencosud_ult_foto, 0) AS sum_mto_deuda_tc_cencosud,

    -- ── EVOLUCIÓN HISTÓRICA (COALESCE directo del PIVOT) ──
    COALESCE(rt_hist.oe_cant_clientes_evol_total_13, 0) AS oe_cant_clientes_evol_total_13, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_12, 0) AS oe_cant_clientes_evol_total_12, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_11, 0) AS oe_cant_clientes_evol_total_11, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_10, 0) AS oe_cant_clientes_evol_total_10, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_9, 0)  AS oe_cant_clientes_evol_total_9,  
    COALESCE(rt_hist.oe_cant_clientes_evol_total_8, 0)  AS oe_cant_clientes_evol_total_8, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_7, 0)  AS oe_cant_clientes_evol_total_7,  
    COALESCE(rt_hist.oe_cant_clientes_evol_total_6, 0)  AS oe_cant_clientes_evol_total_6,  
    COALESCE(rt_hist.oe_cant_clientes_evol_total_5, 0)  AS oe_cant_clientes_evol_total_5, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_4, 0)  AS oe_cant_clientes_evol_total_4,  
    COALESCE(rt_hist.oe_cant_clientes_evol_total_3, 0)  AS oe_cant_clientes_evol_total_3,  
    COALESCE(rt_hist.oe_cant_clientes_evol_total_2, 0)  AS oe_cant_clientes_evol_total_2, 
    COALESCE(rt_hist.oe_cant_clientes_evol_total_1, 0)  AS oe_cant_clientes_evol_total_1,
    
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_13, 0) AS oe_cant_clientes_evol_omni_13, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_12, 0) AS oe_cant_clientes_evol_omni_12, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_11, 0) AS oe_cant_clientes_evol_omni_11, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_10, 0) AS oe_cant_clientes_evol_omni_10, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_9, 0)  AS oe_cant_clientes_evol_omni_9,  
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_8, 0)  AS oe_cant_clientes_evol_omni_8, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_7, 0)  AS oe_cant_clientes_evol_omni_7,  
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_6, 0)  AS oe_cant_clientes_evol_omni_6,  
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_5, 0)  AS oe_cant_clientes_evol_omni_5, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_4, 0)  AS oe_cant_clientes_evol_omni_4,  
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_3, 0)  AS oe_cant_clientes_evol_omni_3,  
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_2, 0)  AS oe_cant_clientes_evol_omni_2, 
    COALESCE(rt_hist.oe_cant_clientes_evol_omni_1, 0)  AS oe_cant_clientes_evol_omni_1,

    COALESCE(rt_hist.oe_cant_clientes_evol_digi_13, 0) AS oe_cant_clientes_evol_digi_13, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_12, 0) AS oe_cant_clientes_evol_digi_12, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_11, 0) AS oe_cant_clientes_evol_digi_11, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_10, 0) AS oe_cant_clientes_evol_digi_10, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_9, 0)  AS oe_cant_clientes_evol_digi_9,  
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_8, 0)  AS oe_cant_clientes_evol_digi_8, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_7, 0)  AS oe_cant_clientes_evol_digi_7,  
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_6, 0)  AS oe_cant_clientes_evol_digi_6,  
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_5, 0)  AS oe_cant_clientes_evol_digi_5, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_4, 0)  AS oe_cant_clientes_evol_digi_4,  
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_3, 0)  AS oe_cant_clientes_evol_digi_3,  
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_2, 0)  AS oe_cant_clientes_evol_digi_2, 
    COALESCE(rt_hist.oe_cant_clientes_evol_digi_1, 0)  AS oe_cant_clientes_evol_digi_1,

    COALESCE(rt_hist.oe_cant_clientes_evol_pres_13, 0) AS oe_cant_clientes_evol_pres_13, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_12, 0) AS oe_cant_clientes_evol_pres_12, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_11, 0) AS oe_cant_clientes_evol_pres_11, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_10, 0) AS oe_cant_clientes_evol_pres_10, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_9, 0)  AS oe_cant_clientes_evol_pres_9,  
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_8, 0)  AS oe_cant_clientes_evol_pres_8, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_7, 0)  AS oe_cant_clientes_evol_pres_7,  
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_6, 0)  AS oe_cant_clientes_evol_pres_6,  
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_5, 0)  AS oe_cant_clientes_evol_pres_5, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_4, 0)  AS oe_cant_clientes_evol_pres_4,  
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_3, 0)  AS oe_cant_clientes_evol_pres_3,  
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_2, 0)  AS oe_cant_clientes_evol_pres_2, 
    COALESCE(rt_hist.oe_cant_clientes_evol_pres_1, 0)  AS oe_cant_clientes_evol_pres_1

  -- 🟢 LA MAGIA: SEG2 ES AHORA LA TABLA PRINCIPAL (DRIVER)
  FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc` seg2
  
  -- ✅ Filtro para mantener la base limpia con los 30 Millones
  JOIN `intercorp-data-storage-pv.bi_vuc_insight.ba_itc_valid_customer` a
     ON seg2.id = a.id

  -- 🟡 Mantenemos solo la data de Corporate y RCC que Seg2 NO tiene
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate` corp
    ON seg2.id = corp.id AND corp.process_date = '2026-02-01'

  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc` r
    ON seg2.id = r.id AND r.process_date = '2026-01-01'
    
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc` r_pa
    ON seg2.id = r_pa.id AND r_pa.process_date = '2025-01-01'

  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` rt
    ON seg2.id = rt.id_intercorp AND rt.process_date = '2026-02-01'
    
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` rt_pa
    ON seg2.id = rt_pa.id_intercorp AND rt_pa.process_date = '2026-01-01'

  LEFT JOIN `prd-itc-customer-services.ba_itc_customer_analytics.ba_segmentacion_itc_clientes_cluster_interes` s2
    ON seg2.id = s2.id 

  LEFT JOIN `intercorp-data-storage-pv.bi_vuc_insight.insight_cliente_perfil` cli_perfil
    ON seg2.id = cli_perfil.id

  LEFT JOIN cliente_segmentacion seg ON 1 = 1  
  LEFT JOIN cliente_top_top top ON 1 = 1

  -- 🔵 PIVOT HISTÓRICO RETAIL
  LEFT JOIN (
    SELECT
      id_intercorp,
      MAX(IF(process_date = '2026-02-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_13,
      MAX(IF(process_date = '2026-01-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_12,
      MAX(IF(process_date = '2025-12-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_11,
      MAX(IF(process_date = '2025-11-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_10,
      MAX(IF(process_date = '2025-10-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_9,
      MAX(IF(process_date = '2025-09-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_8,
      MAX(IF(process_date = '2025-08-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_7,
      MAX(IF(process_date = '2025-07-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_6,
      MAX(IF(process_date = '2025-06-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_5,
      MAX(IF(process_date = '2025-05-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_4,
      MAX(IF(process_date = '2025-04-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_3,
      MAX(IF(process_date = '2025-03-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_2,
      MAX(IF(process_date = '2025-02-01', IF(oe_mtoprom_12m*12 > 0, 1, 0), 0)) AS oe_cant_clientes_evol_total_1,
      MAX(IF(process_date = '2026-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_13,
      MAX(IF(process_date = '2026-01-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_12,
      MAX(IF(process_date = '2025-12-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_11,
      MAX(IF(process_date = '2025-11-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_10,
      MAX(IF(process_date = '2025-10-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_9,
      MAX(IF(process_date = '2025-09-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_8,
      MAX(IF(process_date = '2025-08-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_7,
      MAX(IF(process_date = '2025-07-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_6,
      MAX(IF(process_date = '2025-06-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_5,
      MAX(IF(process_date = '2025-05-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_4,
      MAX(IF(process_date = '2025-04-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_3,
      MAX(IF(process_date = '2025-03-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_2,
      MAX(IF(process_date = '2025-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_omni_1,
      MAX(IF(process_date = '2026-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_13,
      MAX(IF(process_date = '2026-01-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_12,
      MAX(IF(process_date = '2025-12-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_11,
      MAX(IF(process_date = '2025-11-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_10,
      MAX(IF(process_date = '2025-10-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_9,
      MAX(IF(process_date = '2025-09-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_8,
      MAX(IF(process_date = '2025-08-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_7,
      MAX(IF(process_date = '2025-07-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_6,
      MAX(IF(process_date = '2025-06-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_5,
      MAX(IF(process_date = '2025-05-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_4,
      MAX(IF(process_date = '2025-04-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_3,
      MAX(IF(process_date = '2025-03-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_2,
      MAX(IF(process_date = '2025-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m > 0 AND oe_numtrx_presencial_12m = 0, 1, 0), 0)) AS oe_cant_clientes_evol_digi_1,
      MAX(IF(process_date = '2026-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_13,
      MAX(IF(process_date = '2026-01-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_12,
      MAX(IF(process_date = '2025-12-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_11,
      MAX(IF(process_date = '2025-11-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_10,
      MAX(IF(process_date = '2025-10-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_9,
      MAX(IF(process_date = '2025-09-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_8,
      MAX(IF(process_date = '2025-08-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_7,
      MAX(IF(process_date = '2025-07-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_6,
      MAX(IF(process_date = '2025-06-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_5,
      MAX(IF(process_date = '2025-05-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_4,
      MAX(IF(process_date = '2025-04-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_3,
      MAX(IF(process_date = '2025-03-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_2,
      MAX(IF(process_date = '2025-02-01', IF(oe_mtoprom_12m*12 > 0 AND oe_numtrx_digital_12m = 0 AND oe_numtrx_presencial_12m > 0, 1, 0), 0)) AS oe_cant_clientes_evol_pres_1
    FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
    WHERE process_date BETWEEN '2025-02-01' AND '2026-02-01'
    GROUP BY id_intercorp
  ) rt_hist ON seg2.id = rt_hist.id_intercorp

  -- Filtramos Seg2 al periodo de interés (ajusta este valor si en tu base tiene un formato tipo '2026-02-01')
  -- WHERE seg2.periodo_datos = '202602'
),

-- ============================================================
-- CTE: tmp_transaccional con empaquetado de Arreglos
-- ============================================================
tmp_transaccional AS (
  SELECT 
    id,
    ARRAY_AGG(
      STRUCT(
        division_producto,
        departamento_producto,
        linea_producto,
        mto_venta
      )
    ) AS detalle_consumo_categorias
  FROM (
    SELECT
      a.id,
      prod.jq1_value AS division_producto,
      prod.jq2_value AS departamento_producto,
      prod.jq3_value AS linea_producto,
      SUM(CAST(a.product_item_gross_amount AS FLOAT64)) AS mto_venta
    FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` a
    LEFT JOIN `intercorp-data-storage-pv.master_product.m_product` prod
      ON a.product_item_id = prod.product_item_id AND a.itc_company_id = prod.itc_company_id
    WHERE a.transaction_date >= '2025-03-01'
      AND a.transaction_date < '2026-03-01'
      AND a.itc_company_id = '011'
    GROUP BY a.id, division_producto, departamento_producto, linea_producto
  )
  GROUP BY id
)

-- ============================================================
-- SELECT FINAL
-- ============================================================
SELECT 
  a.*,
  b.detalle_consumo_categorias
FROM clientes_base a
LEFT JOIN tmp_transaccional b
  ON a.id = b.id;