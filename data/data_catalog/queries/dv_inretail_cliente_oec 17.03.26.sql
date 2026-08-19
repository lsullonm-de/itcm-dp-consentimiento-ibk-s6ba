-- ══════════════════════════════════════════════════════════════════════════════
-- ARCHIVO: 01_crear_tabla_input_optimizado.sql
-- TABLA:   itc-data-governance-01.gnunurat.dv_inretail_cliente_oec
-- OPTIMIZACIÓN: rt_hist pivoteado con GROUP BY antes del JOIN
--               Transaccional anidado con ARRAY_AGG para evitar Fan-Out
-- ══════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE TABLE `itc-data-governance-01.caldana.dv_inretail_cliente_oec`
CLUSTER BY genero, generacion, departamento, oe_seg_interes
AS
WITH 

cliente_segmentacion as
(
  select
    avg(oe_mtoprom_12m*12) prom_12m
  from `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
  where process_date = "2026-02-01"
    and oe_mtoprom_12m*12 > 0
    and oe_mtoprom_12m*12 < 10000
),

cliente_top_top as
(
  select
    avg(a.oe_mtoprom_12m*12) prom_12m_top_top
  from `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` a
  LEFT join cliente_segmentacion b
    ON 1 = 1
  where a.process_date = "2026-02-01"
    and a.oe_mtoprom_12m*12 > b.prom_12m
    and a.oe_mtoprom_12m*12 < 10000
),

clientes_base AS (
  SELECT
    -- ── IDENTIFICADOR ─────────────────────────────────────
    S1.id,

    -- ── SOCIODEMOGRÁFICOS ─────────────────────────────────
    IFNULL(S1.genero, 'NO DEFINIDO') AS genero,

    COALESCE(
      S1.generacion,
      CASE
        WHEN (2026 - S1.edad) BETWEEN 1997 AND 2012 THEN 'MILLENNIALS'
        WHEN (2026 - S1.edad) BETWEEN 1981 AND 1996 THEN 'GENERACION X'
        WHEN (2026 - S1.edad) BETWEEN 1965 AND 1980 THEN 'BABY BOOMERS'
        WHEN (2026 - S1.edad) BETWEEN 1946 AND 1964 THEN 'SILENT GENERATION'
        WHEN (2026 - S1.edad) >= 2013               THEN 'GENERACION Z'
        ELSE 'OTRA GENERACION'
      END
    ) AS generacion,

    CASE
      WHEN S1.edad IS NULL OR S1.edad < 18 OR S1.edad > 80 THEN 'NO DEFINIDO'
      WHEN S1.edad <= 25 THEN '18-25 años'
      WHEN S1.edad <= 35 THEN '26-35 años'
      WHEN S1.edad <= 45 THEN '36-45 años'
      WHEN S1.edad <= 55 THEN '46-55 años'
      WHEN S1.edad <= 65 THEN '56-65 años'
      ELSE '65+ años'
    END AS rango_edad,

    S1.estado_civil,
    IF(S1.cantidad_hijos = 0, 'No Tiene Hijos', 'Si Tiene Hijos') AS flag_tiene_hijos,
    IFNULL(S1.departamento, 'NO DEFINIDO') AS departamento,

    -- ── SEGMENTO INTERÉS ITC ───────────────────────────────
    IFNULL(s2.segmento_itc, 'NO DEFINIDO') AS segmento_itc,

    -- ── CALIFICACIÓN CREDITICIA SBS ───────────────────────
    r.calificacion_crediticia,

    -- ── SEGMENTACIÓN OEC ──────────────────────────────────
    UPPER(IFNULL(corp.oe_seg_interes,   'NO DEFINIDO')) AS oe_seg_interes,
    UPPER(IFNULL(corp.oe_seg_tendencia, 'NO DEFINIDO')) AS oe_seg_tendencia,

    CASE
      WHEN rt.oe_mtoprom_12m*12 >= top.prom_12m_top_top THEN "CLIENTE VIP"
      WHEN rt.oe_mtoprom_12m*12 >= seg.prom_12m THEN "CLIENTE TOP"
      WHEN rt.oe_mtoprom_12m*12 < seg.prom_12m THEN "CLIENTE REGULAR"
    END AS oe_seg_valor,

    -- ── SEGMENTACIÓN INDIGO (RFM) ─────────────────────────
    corp.indg_seg_interes,
    corp.indg_seg_rfm_frecuencia,
    corp.indg_seg_rfm_monto,
    corp.indg_seg_rfm_recencia,

    -- ── FLAGS OEC PERIODO ACTUAL ──────────────────────────
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 THEN 1 ELSE 0 END AS oe_cant_clientes_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m > 0 AND rt.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_omnicanal_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m > 0 AND rt.oe_numtrx_presencial_12m = 0 THEN 1 ELSE 0 END AS oe_cant_clientes_digital_activos,
    CASE WHEN seg2.flag_activo_tiendas_peruanas_itc = 1 AND seg2.flag_identificado_itc = 1 AND seg2.flag_valido_no_outlier_tiendas_peruanas_itc = 1 AND rt.oe_numtrx_digital_12m = 0 AND rt.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_presencial_activos,

    -- ── FLAGS OEC PERIODO ANTERIOR ────────────────────────
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0                                                                          THEN 1 ELSE 0 END AS oe_cant_clientes_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m > 0 AND rt_pa.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_omnicanal_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m > 0 AND rt_pa.oe_numtrx_presencial_12m = 0 THEN 1 ELSE 0 END AS oe_cant_clientes_digital_activos_1m,
    CASE WHEN rt_pa.oe_mtoprom_12m*12 > 0 AND rt_pa.oe_numtrx_digital_12m = 0 AND rt_pa.oe_numtrx_presencial_12m > 0 THEN 1 ELSE 0 END AS oe_cant_clientes_presencial_activos_1m,

    -- ══════════════════════════════════════════════════════
    -- EVOLUCIÓN HISTÓRICA — PIVOT (1 fila por cliente)
    -- ══════════════════════════════════════════════════════

    rt_hist.oe_cant_clientes_evol_total_13, rt_hist.oe_cant_clientes_evol_total_12, rt_hist.oe_cant_clientes_evol_total_11,
    rt_hist.oe_cant_clientes_evol_total_10, rt_hist.oe_cant_clientes_evol_total_9,  rt_hist.oe_cant_clientes_evol_total_8,
    rt_hist.oe_cant_clientes_evol_total_7,  rt_hist.oe_cant_clientes_evol_total_6,  rt_hist.oe_cant_clientes_evol_total_5,
    rt_hist.oe_cant_clientes_evol_total_4,  rt_hist.oe_cant_clientes_evol_total_3,  rt_hist.oe_cant_clientes_evol_total_2,
    rt_hist.oe_cant_clientes_evol_total_1,

    rt_hist.oe_cant_clientes_evol_omni_13, rt_hist.oe_cant_clientes_evol_omni_12, rt_hist.oe_cant_clientes_evol_omni_11,
    rt_hist.oe_cant_clientes_evol_omni_10, rt_hist.oe_cant_clientes_evol_omni_9,  rt_hist.oe_cant_clientes_evol_omni_8,
    rt_hist.oe_cant_clientes_evol_omni_7,  rt_hist.oe_cant_clientes_evol_omni_6,  rt_hist.oe_cant_clientes_evol_omni_5,
    rt_hist.oe_cant_clientes_evol_omni_4,  rt_hist.oe_cant_clientes_evol_omni_3,  rt_hist.oe_cant_clientes_evol_omni_2,
    rt_hist.oe_cant_clientes_evol_omni_1,

    rt_hist.oe_cant_clientes_evol_digi_13, rt_hist.oe_cant_clientes_evol_digi_12, rt_hist.oe_cant_clientes_evol_digi_11,
    rt_hist.oe_cant_clientes_evol_digi_10, rt_hist.oe_cant_clientes_evol_digi_9,  rt_hist.oe_cant_clientes_evol_digi_8,
    rt_hist.oe_cant_clientes_evol_digi_7,  rt_hist.oe_cant_clientes_evol_digi_6,  rt_hist.oe_cant_clientes_evol_digi_5,
    rt_hist.oe_cant_clientes_evol_digi_4,  rt_hist.oe_cant_clientes_evol_digi_3,  rt_hist.oe_cant_clientes_evol_digi_2,
    rt_hist.oe_cant_clientes_evol_digi_1,

    rt_hist.oe_cant_clientes_evol_pres_13, rt_hist.oe_cant_clientes_evol_pres_12, rt_hist.oe_cant_clientes_evol_pres_11,
    rt_hist.oe_cant_clientes_evol_pres_10, rt_hist.oe_cant_clientes_evol_pres_9,  rt_hist.oe_cant_clientes_evol_pres_8,
    rt_hist.oe_cant_clientes_evol_pres_7,  rt_hist.oe_cant_clientes_evol_pres_6,  rt_hist.oe_cant_clientes_evol_pres_5,
    rt_hist.oe_cant_clientes_evol_pres_4,  rt_hist.oe_cant_clientes_evol_pres_3,  rt_hist.oe_cant_clientes_evol_pres_2,
    rt_hist.oe_cant_clientes_evol_pres_1,

    -- ── CONSUMO OEC GLOBALES ──────────────────────────────
    rt.oe_monto_1m,              rt.oe_monto_12m,
    rt.oe_frecuencia_1m,         rt.oe_frecuencia_12m,
    rt.oe_mtoprom_1m,            rt.oe_mtoprom_12m,
    rt.oe_mto_trx_digital_1m,    rt.oe_mto_trx_digital_12m,
    rt.oe_mto_trx_presencial_1m, rt.oe_mto_trx_presencial_12m,
    rt.oe_numtrx_digital_1m,     rt.oe_numtrx_digital_12m,
    rt.oe_numtrx_presencial_1m,  rt.oe_numtrx_presencial_12m,
    rt.oe_recencia,

    -- ── OEC TICKET PROMEDIO POR LÍNEA ─────────────────────
    rt.oe_mtoprom_electrohogar_1m,       rt.oe_mtoprom_electrohogar_12m,
    rt.oe_mtoprom_mujer_1m,              rt.oe_mtoprom_mujer_12m,
    rt.oe_mtoprom_hombre_1m,             rt.oe_mtoprom_hombre_12m,
    rt.oe_mtoprom_infantil_1m,           rt.oe_mtoprom_infantil_12m,
    rt.oe_mtoprom_calzado_1m,            rt.oe_mtoprom_calzado_12m,
    rt.oe_mtoprom_deportes_1m,           rt.oe_mtoprom_deportes_12m,
    rt.oe_mtoprom_decohogar_1m,          rt.oe_mtoprom_decohogar_12m,
    rt.oe_mtoprom_belleza_1m,            rt.oe_mtoprom_belleza_12m,
    rt.oe_mtoprom_marcas_boutique_1m,    rt.oe_mtoprom_marcas_boutique_12m,

    -- ── OEC TICKET PROMEDIO POR DIVISIÓN ──────────────────
    rt.oe_mtoprom_electro_gama_alta_1m,     rt.oe_mtoprom_electro_gama_alta_12m,
    rt.oe_mtoprom_electro_gama_media_1m,    rt.oe_mtoprom_electro_gama_media_12m,
    rt.oe_mtoprom_electro_gama_baja_1m,     rt.oe_mtoprom_electro_gama_baja_12m,
    rt.oe_mtoprom_ropa_1m,                  rt.oe_mtoprom_ropa_12m,
    rt.oe_mtoprom_ropa_gama_alta_1m,        rt.oe_mtoprom_ropa_gama_alta_12m,
    rt.oe_mtoprom_ropa_gama_media_1m,       rt.oe_mtoprom_ropa_gama_media_12m,
    rt.oe_mtoprom_ropa_gama_baja_1m,        rt.oe_mtoprom_ropa_gama_baja_12m,
    rt.oe_mtoprom_ropa_nino_1m,             rt.oe_mtoprom_ropa_nino_12m,
    rt.oe_mtoprom_jugueteria_gama_alta_1m,  rt.oe_mtoprom_jugueteria_gama_alta_12m,
    rt.oe_mtoprom_jugueteria_gama_media_1m, rt.oe_mtoprom_jugueteria_gama_media_12m,
    rt.oe_mtoprom_jugueteria_gama_baja_1m,  rt.oe_mtoprom_jugueteria_gama_baja_12m,
    rt.oe_mtoprom_implemento_deportivo_1m,  rt.oe_mtoprom_implemento_deportivo_12m,

    -- ── OEC MONTO POR CATEGORÍA ───────────────────────────
    rt.oe_mto_electro_gama_alta_1m,     rt.oe_mto_electro_gama_alta_12m,
    rt.oe_mto_electro_gama_media_1m,    rt.oe_mto_electro_gama_media_12m,
    rt.oe_mto_electro_gama_baja_1m,     rt.oe_mto_electro_gama_baja_12m,
    rt.oe_mto_ropa_1m,                  rt.oe_mto_ropa_12m,
    rt.oe_mto_ropa_gama_alta_1m,        rt.oe_mto_ropa_gama_alta_12m,
    rt.oe_mto_ropa_gama_media_1m,       rt.oe_mto_ropa_gama_media_12m,
    rt.oe_mto_ropa_gama_baja_1m,        rt.oe_mto_ropa_gama_baja_12m,
    rt.oe_mto_ropa_nino_1m,             rt.oe_mto_ropa_nino_12m,
    rt.oe_mto_implemento_deportivo_1m,  rt.oe_mto_implemento_deportivo_12m,
    rt.oe_mto_jugueteria_gama_alta_1m,  rt.oe_mto_jugueteria_gama_alta_12m,
    rt.oe_mto_jugueteria_gama_media_1m, rt.oe_mto_jugueteria_gama_media_12m,
    rt.oe_mto_jugueteria_gama_baja_1m,  rt.oe_mto_jugueteria_gama_baja_12m,

    -- ── FLAGS EMPRESA CORPORATE ───────────────────────────
    corp.flag_dato_contacto AS flag_dato_contacto,
    corp.flag_cliente_spsa  AS corp_flag_cliente_spsa,
    IF(rt.oe_mtoprom_12m>0,1,0)    AS corp_flag_cliente_oe,
    corp.flag_cliente_foh   AS corp_flag_cliente_foh,
    corp.flag_cliente_rp    AS corp_flag_cliente_rp,
    corp.flag_cliente_pro   AS corp_flag_cliente_pro,
    corp.flag_cliente_inkf  AS corp_flag_cliente_inkf,
    corp.flag_cliente_mfarm AS corp_flag_cliente_mfarm,
    corp.flag_cliente_indg  AS corp_flag_cliente_indg,
    corp.flag_cliente_ibk   AS corp_flag_cliente_ibk,
    corp.flag_fidelidad     AS corp_flag_fidelidad,
    GREATEST(
      IF(rt.spsa_mtoprom_12m > 0, 1,  0),
      IF(rt.oe_mtoprom_12m > 0, 1,  0),
      IF(rt.far_mtoprom_12m > 0, 1,  0),
      IF(rt.pro_mtoprom_12m > 0, 1,  0)
    ) AS corp_flag_cliente_retail,

    corp_pa.flag_cliente_spsa  AS corp_flag_cliente_spsa_1m,
    IF(rt_pa.oe_mtoprom_12m>0,1,0)    AS corp_flag_cliente_oe_1m,
    corp_pa.flag_cliente_foh   AS corp_flag_cliente_foh_1m,
    corp_pa.flag_cliente_rp    AS corp_flag_cliente_rp_1m,
    corp_pa.flag_cliente_pro   AS corp_flag_cliente_pro_1m,
    corp_pa.flag_cliente_inkf  AS corp_flag_cliente_inkf_1m,
    corp_pa.flag_cliente_mfarm AS corp_flag_cliente_mfarm_1m,
    corp_pa.flag_cliente_indg  AS corp_flag_cliente_indg_1m,
    corp_pa.flag_cliente_ibk   AS corp_flag_cliente_ibk_1m,
    corp_pa.flag_fidelidad     AS corp_flag_fidelidad_1m,
    GREATEST(
      IF(rt_pa.spsa_mtoprom_12m > 0, 1,  0),
      IF(rt_pa.oe_mtoprom_12m > 0, 1,  0),
      IF(rt_pa.far_mtoprom_12m > 0, 1,  0),
      IF(rt_pa.pro_mtoprom_12m > 0, 1,  0)
    ) AS corp_flag_cliente_retail_1m,

    -- ── CROSS-SELL ────────────────────────────────────────
    cli_perfil.nro_empresas_intercorp,
    cli_perfil.nro_empresas_retail_estandar,
    cli_perfil.empresa_cross_intercorp,
    cli_perfil.empresa_cross_retail,
    cli_perfil.flag_cliente_retail_fisico,
    cli_perfil.flag_cliente_retail_online,
    cli_perfil.cant_transacciones_retail,
    cli_perfil.mto_venta_bruta_retail,

    -- ── RCC ENDEUDAMIENTO ─────────────────────────────────
    r.mto_deuda_total,
    r_pa.mto_deuda_total                    AS mto_deuda_total_1m,
    r.mto_deuda_directa,
    r.mto_deuda_directa_vigente,
    r.mto_deuda_directa_vencida,
    r.mto_deuda_directa_judicial,
    r.mto_deuda_directa_mas_castigos,
    r.max_dias_atraso_deuda_directa,
    r.max_dias_atraso_total,
    r.peor_calificacion_total,
    r.cant_entidades_total,
    r.cant_entidades_deuda_directa,

    -- ── RCC TIPOS DE CRÉDITO ──────────────────────────────
    r.Flag_deuda_directa_comercial,
    r.mto_deuda_directa_comercial,
    r.Flag_deuda_Hipotecaria,
    r.mto_deuda_directa_hipotecaria,
    r.Flag_deuda_prestamo_personal_vehicular,
    r.mto_deuda_directa_prestamo_vehicular,
    r.mto_deuda_directa_libre_disponibilidad,

    -- ── RCC TARJETA DE CRÉDITO ────────────────────────────
    r.Flag_tiene_tc,
    r_pa.Flag_tiene_tc                      AS Flag_tiene_tc_1m,
    r.cant_entidades_tc_Consumo,
    r.mto_deuda_directa_tc_compras,
    r.mto_deuda_directa_tc_compras_revolvente,
    r.mto_linea_tc_consumo,
    r.mto_deuda_directa_tc_consumo as mto_deuda_tc,
    r_pa.mto_deuda_directa_tc_consumo as mto_deuda_tc_1m,

    -- ── RCC TARJETA OH (TOH) ──────────────────────────────
    r.Flag_deuda_directa_consumo_toh,
    r_pa.Flag_deuda_directa_consumo_toh     AS Flag_deuda_directa_consumo_toh_1m,
    r.mto_deuda_directa_tc_compras_toh,
    r.mto_linea_tc_consumo_toh,
    r.Ratio_utilizacion_tc_consumo_toh,
    r.peor_calificacion_deuda_directa_toh,
    r.mto_deuda_directa_tc_consumo_toh as mto_deuda_tc_toh,
    r_pa.mto_deuda_directa_tc_consumo_toh as mto_deuda_tc_toh_1m,
    IF(rt.oe_mtoprom_12m >0 and r.mto_deuda_directa_tc_consumo_toh>0,1,0) cant_clientes_oe_toh,
    IF(rt_pa.oe_mtoprom_12m >0 and r_pa.mto_deuda_directa_tc_consumo_toh>0,1,0) cant_clientes_oe_toh_1m,

    -- ── RCC FINANCIERA OH (FOH) ───────────────────────────
    r.Flag_clientes_foh,
    r.sow_foh,
    r.sow_compras_foh,
    r.cant_entidades_TC_sin_FOH,
    r.prom_sow_compras_foh_3um,
    r.prom_sow_compras_foh_6um,
    r.prom_sow_compras_foh_12um,
    r.prom_sow_foh_3um,
    r.prom_sow_foh_12um,

    -- ── RCC INTERBANK ─────────────────────────────────────
    r.Flag_clientes_ibk,

    -- ── RCC FALABELLA ─────────────────────────────────────
    r.mto_deuda_directa_falabella, 
    r_pa.mto_deuda_directa_falabella        AS mto_deuda_directa_falabella_1m,
    r.mto_linea_tc_consumo_falabella,
    r.sow_falabella,
    r.sow_compras_falabella,
    r.mto_deuda_directa_tc_consumo_falabella,

    -- ── RCC RIPLEY ────────────────────────────────────────
    r.Flag_clientes_ripley,
    r.Flag_deuda_directa_consumo_ripley,
    r.mto_deuda_directa_ripley,
    r.mto_deuda_directa_tc_compras_ripley,
    r.sow_ripley,
    r.sow_compras_ripley,
    r.mto_deuda_directa_tc_consumo_ripley,

    -- ── RCC CENCOSUD ─────────────────────────────────────
    r.Flag_TC_cencosud,
    r.Flag_clientes_cencosud,
    r.mto_deuda_directa_tc_compras_cencosud,
    r.sow_cencosud,
    r.sow_compras_cencosud,
    r.mto_deuda_directa_tc_consumo_cencosud,

    -- ── RCC SOW COMPARATIVO ───────────────────────────────
    r.sow_total,
    r.sow_compras_total,
    r.sow_bcp,
    r.sow_bbva,
    r.sow_scotiabank,
    r.sow_compras_bcp

  FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic` S1
  JOIN `intercorp-data-storage-pv.bi_vuc_insight.ba_itc_valid_customer` a
     ON S1.id = a.id
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc` r
    ON S1.id = r.id AND r.process_date = '2026-01-01'
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc` r_pa
    ON S1.id = r_pa.id AND r_pa.process_date = '2025-01-01'
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` rt
    ON S1.id = rt.id_intercorp AND rt.process_date = '2026-02-01'
  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` rt_pa
    ON S1.id = rt_pa.id_intercorp AND rt_pa.process_date = '2026-01-01'
  -- ✅ PIVOT: 13 meses colapsados en 1 fila por cliente
  LEFT JOIN (
    SELECT
      id_intercorp,

      -- TOTAL ACTIVOS
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

      -- OMNICANAL
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

      -- SOLO DIGITAL
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

      -- SOLO PRESENCIAL
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
  ) rt_hist ON S1.id = rt_hist.id_intercorp

  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate` corp
    ON S1.id = corp.id AND corp.process_date = '2026-02-01'

  LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate` corp_pa
    ON S1.id = corp_pa.id AND corp_pa.process_date = '2026-01-01'

  LEFT JOIN `intercorp-data-storage-pv.bi_vuc_insight.insight_cliente_perfil` cli_perfil
    ON S1.id = cli_perfil.id

  LEFT JOIN `prd-itc-customer-services.ba_itc_customer_analytics.ba_segmentacion_itc_clientes_cluster_interes` s2
    ON S1.id = s2.id

  LEFT JOIN cliente_segmentacion seg
    ON 1 = 1  

  LEFT JOIN cliente_top_top top
    ON 1 = 1

  LEFT JOIN `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc` Seg2
    ON S1.id = Seg2.id

  -- Filtro de fecha agregado para evitar duplicados en esta tabla
  LEFT JOIN `int-advanced-analytics-01.aodarm.ba_segmentacion_itc_clientes_cluster_interes` Seg3
    ON S1.id = Seg3.id and seg3.process_date = "2026-03-16"

),

-- ============================================================
-- CTE 2: tmp_formato_final 
-- ============================================================
tmp_formato_final AS (
  SELECT
    S1.id,
    S1.genero,
    S1.generacion,
    S1.rango_edad,
    S1.estado_civil,
    S1.flag_tiene_hijos,
    S1.departamento,
    S1.segmento_itc,
    S1.calificacion_crediticia,
    S1.oe_seg_interes,
    S1.oe_seg_tendencia,
    S1.oe_seg_valor,
    S1.indg_seg_interes,
    S1.indg_seg_rfm_frecuencia,
    S1.indg_seg_rfm_monto,
    S1.indg_seg_rfm_recencia,

    1 AS cant_clientes_itc,

    COALESCE(S1.oe_cant_clientes_activos,            0) AS oe_cant_clientes_activos,
    COALESCE(S1.oe_cant_clientes_omnicanal_activos,  0) AS oe_cant_clientes_omnicanal_activos,
    COALESCE(S1.oe_cant_clientes_digital_activos,    0) AS oe_cant_clientes_digital_activos,
    COALESCE(S1.oe_cant_clientes_presencial_activos, 0) AS oe_cant_clientes_presencial_activos,

    COALESCE(S1.oe_cant_clientes_activos_1m,             0) AS oe_cant_clientes_activos_1m,
    COALESCE(S1.oe_cant_clientes_omnicanal_activos_1m,   0) AS oe_cant_clientes_omnicanal_activos_1m,
    COALESCE(S1.oe_cant_clientes_digital_activos_1m,     0) AS oe_cant_clientes_digital_activos_1m,
    COALESCE(S1.oe_cant_clientes_presencial_activos_1m,  0) AS oe_cant_clientes_presencial_activos_1m,

    COALESCE(oe_monto_1m,               0) AS sum_oe_monto_1m,
    COALESCE(oe_mtoprom_12m*12,         0) AS sum_oe_monto_12m,
    COALESCE(oe_frecuencia_1m,          0) AS avg_oe_frecuencia_1m,
    COALESCE(oe_frecuencia_12m,         0) AS avg_oe_frecuencia_12m,
    COALESCE(oe_mtoprom_1m,             0) AS avg_oe_mtoprom_1m,
    COALESCE(oe_mtoprom_12m,            0) AS avg_oe_mtoprom_12m,
    COALESCE(oe_mto_trx_digital_1m,    0) AS sum_oe_mto_trx_digital_1m,
    COALESCE(oe_mto_trx_digital_12m,   0) AS sum_oe_mto_trx_digital_12m,
    COALESCE(oe_mto_trx_presencial_1m, 0) AS sum_oe_mto_trx_presencial_1m,
    COALESCE(oe_mto_trx_presencial_12m,0) AS sum_oe_mto_trx_presencial_12m,
    COALESCE(oe_numtrx_digital_1m,     0) AS sum_oe_numtrx_digital_1m,
    COALESCE(oe_numtrx_digital_12m,    0) AS sum_oe_numtrx_digital_12m,
    COALESCE(oe_numtrx_presencial_1m,  0) AS sum_oe_numtrx_presencial_1m,
    COALESCE(oe_numtrx_presencial_12m, 0) AS sum_oe_numtrx_presencial_12m,
    COALESCE(oe_recencia,              0) AS avg_oe_recencia,

    COALESCE(oe_mtoprom_electrohogar_1m,     0) AS avg_oe_mtoprom_electrohogar_1m,
    COALESCE(oe_mtoprom_electrohogar_12m,    0) AS avg_oe_mtoprom_electrohogar_12m,
    COALESCE(oe_mtoprom_mujer_1m,            0) AS avg_oe_mtoprom_mujer_1m,
    COALESCE(oe_mtoprom_mujer_12m,           0) AS avg_oe_mtoprom_mujer_12m,
    COALESCE(oe_mtoprom_hombre_1m,           0) AS avg_oe_mtoprom_hombre_1m,
    COALESCE(oe_mtoprom_hombre_12m,          0) AS avg_oe_mtoprom_hombre_12m,
    COALESCE(oe_mtoprom_infantil_1m,         0) AS avg_oe_mtoprom_infantil_1m,
    COALESCE(oe_mtoprom_infantil_12m,        0) AS avg_oe_mtoprom_infantil_12m,
    COALESCE(oe_mtoprom_calzado_1m,          0) AS avg_oe_mtoprom_calzado_1m,
    COALESCE(oe_mtoprom_calzado_12m,         0) AS avg_oe_mtoprom_calzado_12m,
    COALESCE(oe_mtoprom_deportes_1m,         0) AS avg_oe_mtoprom_deportes_1m,
    COALESCE(oe_mtoprom_deportes_12m,        0) AS avg_oe_mtoprom_deportes_12m,
    COALESCE(oe_mtoprom_decohogar_1m,        0) AS avg_oe_mtoprom_decohogar_1m,
    COALESCE(oe_mtoprom_decohogar_12m,       0) AS avg_oe_mtoprom_decohogar_12m,
    COALESCE(oe_mtoprom_belleza_1m,          0) AS avg_oe_mtoprom_belleza_1m,
    COALESCE(oe_mtoprom_belleza_12m,         0) AS avg_oe_mtoprom_belleza_12m,
    COALESCE(oe_mtoprom_marcas_boutique_1m,  0) AS avg_oe_mtoprom_marcas_boutique_1m,
    COALESCE(oe_mtoprom_marcas_boutique_12m, 0) AS avg_oe_mtoprom_marcas_boutique_12m,

    COALESCE(oe_mtoprom_electro_gama_alta_1m,     0) AS avg_oe_mtoprom_electro_gama_alta_1m,
    COALESCE(oe_mtoprom_electro_gama_alta_12m,    0) AS avg_oe_mtoprom_electro_gama_alta_12m,
    COALESCE(oe_mtoprom_electro_gama_media_1m,    0) AS avg_oe_mtoprom_electro_gama_media_1m,
    COALESCE(oe_mtoprom_electro_gama_media_12m,   0) AS avg_oe_mtoprom_electro_gama_media_12m,
    COALESCE(oe_mtoprom_electro_gama_baja_1m,     0) AS avg_oe_mtoprom_electro_gama_baja_1m,
    COALESCE(oe_mtoprom_electro_gama_baja_12m,    0) AS avg_oe_mtoprom_electro_gama_baja_12m,
    COALESCE(oe_mtoprom_ropa_1m,                  0) AS avg_oe_mtoprom_ropa_1m,
    COALESCE(oe_mtoprom_ropa_12m,                 0) AS avg_oe_mtoprom_ropa_12m,
    COALESCE(oe_mtoprom_ropa_gama_alta_1m,        0) AS avg_oe_mtoprom_ropa_gama_alta_1m,
    COALESCE(oe_mtoprom_ropa_gama_alta_12m,       0) AS avg_oe_mtoprom_ropa_gama_alta_12m,
    COALESCE(oe_mtoprom_ropa_gama_media_1m,       0) AS avg_oe_mtoprom_ropa_gama_media_1m,
    COALESCE(oe_mtoprom_ropa_gama_media_12m,      0) AS avg_oe_mtoprom_ropa_gama_media_12m,
    COALESCE(oe_mtoprom_ropa_gama_baja_1m,        0) AS avg_oe_mtoprom_ropa_gama_baja_1m,
    COALESCE(oe_mtoprom_ropa_gama_baja_12m,       0) AS avg_oe_mtoprom_ropa_gama_baja_12m,
    COALESCE(oe_mtoprom_ropa_nino_1m,             0) AS avg_oe_mtoprom_ropa_nino_1m,
    COALESCE(oe_mtoprom_ropa_nino_12m,            0) AS avg_oe_mtoprom_ropa_nino_12m,
    COALESCE(oe_mtoprom_jugueteria_gama_alta_1m,  0) AS avg_oe_mtoprom_jugueteria_gama_alta_1m,
    COALESCE(oe_mtoprom_jugueteria_gama_alta_12m, 0) AS avg_oe_mtoprom_jugueteria_gama_alta_12m,
    COALESCE(oe_mtoprom_jugueteria_gama_media_1m, 0) AS avg_oe_mtoprom_jugueteria_gama_media_1m,
    COALESCE(oe_mtoprom_jugueteria_gama_media_12m,0) AS avg_oe_mtoprom_jugueteria_gama_media_12m,
    COALESCE(oe_mtoprom_jugueteria_gama_baja_1m,  0) AS avg_oe_mtoprom_jugueteria_gama_baja_1m,
    COALESCE(oe_mtoprom_jugueteria_gama_baja_12m, 0) AS avg_oe_mtoprom_jugueteria_gama_baja_12m,
    COALESCE(oe_mtoprom_implemento_deportivo_1m,  0) AS avg_oe_mtoprom_implemento_deportivo_1m,
    COALESCE(oe_mtoprom_implemento_deportivo_12m, 0) AS avg_oe_mtoprom_implemento_deportivo_12m,

    COALESCE(oe_mto_electro_gama_alta_1m,     0) AS sum_oe_mto_electro_gama_alta_1m,
    COALESCE(oe_mto_electro_gama_alta_12m,    0) AS sum_oe_mto_electro_gama_alta_12m,
    COALESCE(oe_mto_electro_gama_media_1m,    0) AS sum_oe_mto_electro_gama_media_1m,
    COALESCE(oe_mto_electro_gama_media_12m,   0) AS sum_oe_mto_electro_gama_media_12m,
    COALESCE(oe_mto_electro_gama_baja_1m,     0) AS sum_oe_mto_electro_gama_baja_1m,
    COALESCE(oe_mto_electro_gama_baja_12m,    0) AS sum_oe_mto_electro_gama_baja_12m,
    COALESCE(oe_mto_ropa_1m,                  0) AS sum_oe_mto_ropa_1m,
    COALESCE(oe_mto_ropa_12m,                 0) AS sum_oe_mto_ropa_12m,
    COALESCE(oe_mto_ropa_gama_alta_1m,        0) AS sum_oe_mto_ropa_gama_alta_1m,
    COALESCE(oe_mto_ropa_gama_alta_12m,       0) AS sum_oe_mto_ropa_gama_alta_12m,
    COALESCE(oe_mto_ropa_gama_media_1m,       0) AS sum_oe_mto_ropa_gama_media_1m,
    COALESCE(oe_mto_ropa_gama_media_12m,      0) AS sum_oe_mto_ropa_gama_media_12m,
    COALESCE(oe_mto_ropa_gama_baja_1m,        0) AS sum_oe_mto_ropa_gama_baja_1m,
    COALESCE(oe_mto_ropa_gama_baja_12m,       0) AS sum_oe_mto_ropa_gama_baja_12m,
    COALESCE(oe_mto_ropa_nino_1m,             0) AS sum_oe_mto_ropa_nino_1m,
    COALESCE(oe_mto_ropa_nino_12m,            0) AS sum_oe_mto_ropa_nino_12m,
    COALESCE(oe_mto_implemento_deportivo_1m,  0) AS sum_oe_mto_implemento_deportivo_1m,
    COALESCE(oe_mto_implemento_deportivo_12m, 0) AS sum_oe_mto_implemento_deportivo_12m,
    COALESCE(oe_mto_jugueteria_gama_alta_1m,  0) AS sum_oe_mto_jugueteria_gama_alta_1m,
    COALESCE(oe_mto_jugueteria_gama_alta_12m, 0) AS sum_oe_mto_jugueteria_gama_alta_12m,
    COALESCE(oe_mto_jugueteria_gama_media_1m, 0) AS sum_oe_mto_jugueteria_gama_media_1m,
    COALESCE(oe_mto_jugueteria_gama_media_12m,0) AS sum_oe_mto_jugueteria_gama_media_12m,
    COALESCE(oe_mto_jugueteria_gama_baja_1m,  0) AS sum_oe_mto_jugueteria_gama_baja_1m,
    COALESCE(oe_mto_jugueteria_gama_baja_12m, 0) AS sum_oe_mto_jugueteria_gama_baja_12m,

    IF(flag_dato_contacto = 1, "Contactable","No Contactable") AS flag_dato_contacto,
    COALESCE(corp_flag_cliente_spsa,   0) AS cant_clientes_spsa,
    COALESCE(corp_flag_cliente_oe,     0) AS cant_clientes_oe,
    COALESCE(corp_flag_cliente_foh,    0) AS cant_clientes_foh,
    COALESCE(corp_flag_cliente_rp,     0) AS cant_clientes_rp,
    COALESCE(corp_flag_cliente_pro,    0) AS cant_clientes_pro,
    COALESCE(corp_flag_cliente_inkf,   0) AS cant_clientes_inkf,
    COALESCE(corp_flag_cliente_mfarm,  0) AS cant_clientes_mfarm,
    COALESCE(corp_flag_cliente_indg,   0) AS cant_clientes_indg,
    COALESCE(corp_flag_cliente_ibk,    0) AS cant_clientes_ibk,
    COALESCE(corp_flag_fidelidad,      0) AS cant_clientes_fidelidad,

    COALESCE(corp_flag_cliente_retail, 0) AS cant_clientes_retail,

    COALESCE(corp_flag_cliente_spsa_1m,   0) AS cant_clientes_spsa_1m,
    COALESCE(corp_flag_cliente_oe_1m,     0) AS cant_clientes_oe_1m,
    COALESCE(corp_flag_cliente_foh_1m,    0) AS cant_clientes_foh_1m,
    COALESCE(corp_flag_cliente_rp_1m,     0) AS cant_clientes_rp_1m,
    COALESCE(corp_flag_cliente_pro_1m,    0) AS cant_clientes_pro_1m,
    COALESCE(corp_flag_cliente_inkf_1m,   0) AS cant_clientes_inkf_1m,
    COALESCE(corp_flag_cliente_mfarm_1m,  0) AS cant_clientes_mfarm_1m,
    COALESCE(corp_flag_cliente_indg_1m,   0) AS cant_clientes_indg_1m,
    COALESCE(corp_flag_cliente_ibk_1m,    0) AS cant_clientes_ibk_1m,
    COALESCE(corp_flag_fidelidad_1m,      0) AS cant_clientes_fidelidad_1m,
    COALESCE(corp_flag_cliente_retail_1m, 0) AS cant_clientes_retail_1m,

    nro_empresas_intercorp,
    nro_empresas_retail_estandar,
    empresa_cross_intercorp,
    empresa_cross_retail,
    flag_cliente_retail_fisico,
    flag_cliente_retail_online,
    cant_transacciones_retail,
    mto_venta_bruta_retail,

    COALESCE(mto_deuda_total,                  0) AS sum_mto_deuda_total,
    COALESCE(mto_deuda_total_1m,               0) AS sum_mto_deuda_total_1m,
    COALESCE(mto_deuda_directa,                0) AS sum_mto_deuda_directa,
    COALESCE(mto_deuda_directa_vigente,        0) AS sum_mto_deuda_directa_vigente,
    COALESCE(mto_deuda_directa_vencida,        0) AS sum_mto_deuda_directa_vencida,
    COALESCE(mto_deuda_directa_judicial,       0) AS sum_mto_deuda_directa_judicial,
    COALESCE(mto_deuda_directa_mas_castigos,   0) AS sum_mto_deuda_directa_mas_castigos,
    COALESCE(max_dias_atraso_deuda_directa,    0) AS avg_max_dias_atraso_deuda_directa,
    COALESCE(max_dias_atraso_total,            0) AS avg_max_dias_atraso_total,
    COALESCE(cant_entidades_total,             0) AS avg_cant_entidades_total,
    COALESCE(cant_entidades_deuda_directa,     0) AS avg_cant_entidades_deuda_directa,

    COALESCE(Flag_deuda_directa_comercial,          0) AS clientes_deuda_directa_comercial,
    COALESCE(mto_deuda_directa_comercial,           0) AS sum_mto_deuda_directa_comercial,
    COALESCE(Flag_deuda_Hipotecaria,                0) AS clientes_deuda_hipotecaria,
    COALESCE(mto_deuda_directa_hipotecaria,         0) AS sum_mto_deuda_directa_hipotecaria,
    COALESCE(Flag_deuda_prestamo_personal_vehicular, 0) AS clientes_deuda_prestamo_vehicular,
    COALESCE(mto_deuda_directa_prestamo_vehicular,  0) AS sum_mto_deuda_directa_prestamo_vehicular,
    COALESCE(mto_deuda_directa_libre_disponibilidad, 0) AS sum_mto_deuda_directa_libre_disponibilidad,

    COALESCE(Flag_tiene_tc,                           0) AS clientes_tiene_tc,
    COALESCE(Flag_tiene_tc_1m,                        0) AS clientes_tiene_tc_1m,
    COALESCE(cant_entidades_tc_Consumo,               0) AS avg_cant_entidades_tc_consumo,
    COALESCE(mto_deuda_directa_tc_compras,            0) AS sum_mto_deuda_directa_tc_compras,
    COALESCE(mto_deuda_directa_tc_compras_revolvente, 0) AS sum_mto_deuda_directa_tc_compras_revolvente,
    COALESCE(mto_linea_tc_consumo,                    0) AS sum_mto_linea_tc_consumo,
    COALESCE(mto_deuda_tc,                            0) AS sum_mto_deuda_tc,
    COALESCE(mto_deuda_tc_1m,                         0) AS sum_mto_deuda_tc_1m,

    COALESCE(Flag_deuda_directa_consumo_toh,    0) AS clientes_deuda_consumo_toh,
    COALESCE(Flag_deuda_directa_consumo_toh_1m, 0) AS clientes_deuda_consumo_toh_1m,
    COALESCE(mto_deuda_directa_tc_compras_toh,  0) AS sum_mto_deuda_directa_tc_compras_toh,
    COALESCE(mto_linea_tc_consumo_toh,          0) AS sum_mto_linea_tc_consumo_toh,
    COALESCE(Ratio_utilizacion_tc_consumo_toh,  0) AS avg_ratio_utilizacion_tc_consumo_toh,
    COALESCE(mto_deuda_tc_toh,                  0) AS sum_mto_deuda_tc_toh,
    COALESCE(mto_deuda_tc_toh_1m,               0) AS sum_mto_deuda_tc_toh_1m,
    COALESCE(cant_clientes_oe_toh,                    0) AS cant_clientes_oe_toh,
    COALESCE(cant_clientes_oe_toh_1m,                 0) AS cant_clientes_oe_toh_1m,

    COALESCE(Flag_clientes_foh,           0) AS cant_clientes_tarjeta_foh,
    COALESCE(cant_entidades_TC_sin_FOH,   0) AS avg_cant_entidades_tc_sin_foh,
    COALESCE(sow_foh,                     0) AS avg_sow_foh,
    COALESCE(sow_compras_foh,             0) AS avg_sow_compras_foh,
    COALESCE(prom_sow_compras_foh_3um,    0) AS avg_prom_sow_compras_foh_3um,
    COALESCE(prom_sow_compras_foh_6um,    0) AS avg_prom_sow_compras_foh_6um,
    COALESCE(prom_sow_compras_foh_12um,   0) AS avg_prom_sow_compras_foh_12um,
    COALESCE(prom_sow_foh_3um,            0) AS avg_prom_sow_foh_3um,
    COALESCE(prom_sow_foh_12um,           0) AS avg_prom_sow_foh_12um,

    COALESCE(Flag_clientes_ibk, 0) AS clientes_tarjeta_ibk,

    COALESCE(mto_deuda_directa_falabella,    0) AS sum_mto_deuda_directa_falabella,
    COALESCE(mto_deuda_directa_falabella_1m, 0) AS sum_mto_deuda_directa_falabella_1m,
    COALESCE(mto_linea_tc_consumo_falabella, 0) AS sum_mto_linea_tc_consumo_falabella,
    COALESCE(sow_falabella,                  0) AS avg_sow_falabella,
    COALESCE(sow_compras_falabella,          0) AS avg_sow_compras_falabella,
    COALESCE(mto_deuda_directa_tc_consumo_falabella,0) AS sum_mto_deuda_tc_falabella,

    COALESCE(Flag_clientes_ripley,               0) AS clientes_ripley,
    COALESCE(Flag_deuda_directa_consumo_ripley,  0) AS clientes_deuda_consumo_ripley,
    COALESCE(mto_deuda_directa_ripley,           0) AS sum_mto_deuda_directa_ripley,
    COALESCE(mto_deuda_directa_tc_compras_ripley,0) AS sum_mto_deuda_directa_tc_compras_ripley,
    COALESCE(sow_ripley,                         0) AS avg_sow_ripley,
    COALESCE(sow_compras_ripley,                 0) AS avg_sow_compras_ripley,
    COALESCE(mto_deuda_directa_tc_consumo_ripley,0) AS sum_mto_deuda_tc_ripley,

    COALESCE(Flag_TC_cencosud,                      0) AS clientes_tc_cencosud,
    COALESCE(Flag_clientes_cencosud,                0) AS clientes_cencosud,
    COALESCE(mto_deuda_directa_tc_compras_cencosud, 0) AS sum_mto_deuda_directa_tc_compras_cencosud,
    COALESCE(sow_cencosud,                          0) AS avg_sow_cencosud,
    COALESCE(sow_compras_cencosud,                  0) AS avg_sow_compras_cencosud,
    COALESCE(mto_deuda_directa_tc_consumo_cencosud, 0) AS sum_mto_deuda_tc_cencosud,

    COALESCE(sow_total,         0) AS avg_sow_total,
    COALESCE(sow_compras_total, 0) AS avg_sow_compras_total,
    COALESCE(sow_bcp,           0) AS avg_sow_bcp,
    COALESCE(sow_bbva,          0) AS avg_sow_bbva,
    COALESCE(sow_scotiabank,    0) AS avg_sow_scotiabank,
    COALESCE(sow_compras_bcp,   0) AS avg_sow_compras_bcp,

    -- ── EVOLUCIÓN HISTÓRICA (ya pivoteadas desde rt_hist) ─
    COALESCE(oe_cant_clientes_evol_total_13, 0) AS oe_cant_clientes_evol_total_13,
    COALESCE(oe_cant_clientes_evol_total_12, 0) AS oe_cant_clientes_evol_total_12,
    COALESCE(oe_cant_clientes_evol_total_11, 0) AS oe_cant_clientes_evol_total_11,
    COALESCE(oe_cant_clientes_evol_total_10, 0) AS oe_cant_clientes_evol_total_10,
    COALESCE(oe_cant_clientes_evol_total_9,  0) AS oe_cant_clientes_evol_total_9,
    COALESCE(oe_cant_clientes_evol_total_8,  0) AS oe_cant_clientes_evol_total_8,
    COALESCE(oe_cant_clientes_evol_total_7,  0) AS oe_cant_clientes_evol_total_7,
    COALESCE(oe_cant_clientes_evol_total_6,  0) AS oe_cant_clientes_evol_total_6,
    COALESCE(oe_cant_clientes_evol_total_5,  0) AS oe_cant_clientes_evol_total_5,
    COALESCE(oe_cant_clientes_evol_total_4,  0) AS oe_cant_clientes_evol_total_4,
    COALESCE(oe_cant_clientes_evol_total_3,  0) AS oe_cant_clientes_evol_total_3,
    COALESCE(oe_cant_clientes_evol_total_2,  0) AS oe_cant_clientes_evol_total_2,
    COALESCE(oe_cant_clientes_evol_total_1,  0) AS oe_cant_clientes_evol_total_1,

    COALESCE(oe_cant_clientes_evol_omni_13, 0) AS oe_cant_clientes_evol_omni_13,
    COALESCE(oe_cant_clientes_evol_omni_12, 0) AS oe_cant_clientes_evol_omni_12,
    COALESCE(oe_cant_clientes_evol_omni_11, 0) AS oe_cant_clientes_evol_omni_11,
    COALESCE(oe_cant_clientes_evol_omni_10, 0) AS oe_cant_clientes_evol_omni_10,
    COALESCE(oe_cant_clientes_evol_omni_9,  0) AS oe_cant_clientes_evol_omni_9,
    COALESCE(oe_cant_clientes_evol_omni_8,  0) AS oe_cant_clientes_evol_omni_8,
    COALESCE(oe_cant_clientes_evol_omni_7,  0) AS oe_cant_clientes_evol_omni_7,
    COALESCE(oe_cant_clientes_evol_omni_6,  0) AS oe_cant_clientes_evol_omni_6,
    COALESCE(oe_cant_clientes_evol_omni_5,  0) AS oe_cant_clientes_evol_omni_5,
    COALESCE(oe_cant_clientes_evol_omni_4,  0) AS oe_cant_clientes_evol_omni_4,
    COALESCE(oe_cant_clientes_evol_omni_3,  0) AS oe_cant_clientes_evol_omni_3,
    COALESCE(oe_cant_clientes_evol_omni_2,  0) AS oe_cant_clientes_evol_omni_2,
    COALESCE(oe_cant_clientes_evol_omni_1,  0) AS oe_cant_clientes_evol_omni_1,

    COALESCE(oe_cant_clientes_evol_digi_13, 0) AS oe_cant_clientes_evol_digi_13,
    COALESCE(oe_cant_clientes_evol_digi_12, 0) AS oe_cant_clientes_evol_digi_12,
    COALESCE(oe_cant_clientes_evol_digi_11, 0) AS oe_cant_clientes_evol_digi_11,
    COALESCE(oe_cant_clientes_evol_digi_10, 0) AS oe_cant_clientes_evol_digi_10,
    COALESCE(oe_cant_clientes_evol_digi_9,  0) AS oe_cant_clientes_evol_digi_9,
    COALESCE(oe_cant_clientes_evol_digi_8,  0) AS oe_cant_clientes_evol_digi_8,
    COALESCE(oe_cant_clientes_evol_digi_7,  0) AS oe_cant_clientes_evol_digi_7,
    COALESCE(oe_cant_clientes_evol_digi_6,  0) AS oe_cant_clientes_evol_digi_6,
    COALESCE(oe_cant_clientes_evol_digi_5,  0) AS oe_cant_clientes_evol_digi_5,
    COALESCE(oe_cant_clientes_evol_digi_4,  0) AS oe_cant_clientes_evol_digi_4,
    COALESCE(oe_cant_clientes_evol_digi_3,  0) AS oe_cant_clientes_evol_digi_3,
    COALESCE(oe_cant_clientes_evol_digi_2,  0) AS oe_cant_clientes_evol_digi_2,
    COALESCE(oe_cant_clientes_evol_digi_1,  0) AS oe_cant_clientes_evol_digi_1,

    COALESCE(oe_cant_clientes_evol_pres_13, 0) AS oe_cant_clientes_evol_pres_13,
    COALESCE(oe_cant_clientes_evol_pres_12, 0) AS oe_cant_clientes_evol_pres_12,
    COALESCE(oe_cant_clientes_evol_pres_11, 0) AS oe_cant_clientes_evol_pres_11,
    COALESCE(oe_cant_clientes_evol_pres_10, 0) AS oe_cant_clientes_evol_pres_10,
    COALESCE(oe_cant_clientes_evol_pres_9,  0) AS oe_cant_clientes_evol_pres_9,
    COALESCE(oe_cant_clientes_evol_pres_8,  0) AS oe_cant_clientes_evol_pres_8,
    COALESCE(oe_cant_clientes_evol_pres_7,  0) AS oe_cant_clientes_evol_pres_7,
    COALESCE(oe_cant_clientes_evol_pres_6,  0) AS oe_cant_clientes_evol_pres_6,
    COALESCE(oe_cant_clientes_evol_pres_5,  0) AS oe_cant_clientes_evol_pres_5,
    COALESCE(oe_cant_clientes_evol_pres_4,  0) AS oe_cant_clientes_evol_pres_4,
    COALESCE(oe_cant_clientes_evol_pres_3,  0) AS oe_cant_clientes_evol_pres_3,
    COALESCE(oe_cant_clientes_evol_pres_2,  0) AS oe_cant_clientes_evol_pres_2,
    COALESCE(oe_cant_clientes_evol_pres_1,  0) AS oe_cant_clientes_evol_pres_1

  FROM clientes_base S1
),

-- ============================================================
-- CTE 3: tmp_transaccional con empaquetado de Arreglos
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
FROM tmp_formato_final a
LEFT JOIN tmp_transaccional b
  ON a.id = b.id;