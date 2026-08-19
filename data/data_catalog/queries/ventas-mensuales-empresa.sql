-- ============================================================
-- CAMPOS QUE NO EXISTEN (anti-patrones a evitar):
--   spsa_mto_retail_1m       pro_mto_retail_1m
--   oe_mto_retail_1m         far_mto_retail_1m
--   spsa_numtrx_retail_1m    pro_numtrx_retail_1m
--
-- CAMPOS CORRECTOS para monto total de ventas:
--   spsa: spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m
--   pro:  pro_mto_trx_presencial_1m  + pro_mto_trx_digital_1m
--   oe:   oe_mto_trx_presencial_1m   + oe_mto_trx_digital_1m
--   far:  far_mto_trx_presencial_1m  + far_mto_trx_digital_1m
-- ============================================================
-- CASO DE USO: Ventas totales mensuales por empresa
-- TABLA: ba_itc_attr_retail (nivel cliente → sumar para obtener totales empresa)
-- EMPRESAS: SPSA (spsa_), Promart (pro_), Oechsle (oe_)
-- ============================================================
--
-- NOTA IMPORTANTE:
-- ba_itc_attr_retail tiene UNA FILA POR CLIENTE por mes (process_date).
-- Para obtener el total de la empresa, hay que SUM de todos los clientes.
-- Los campos {empresa}_mto_trx_presencial_1m y {empresa}_mto_trx_digital_1m
-- contienen el monto acumulado del cliente en ese canal durante el mes.
-- Su suma = monto total de ventas de esa empresa en ese mes.
--
-- CAMPOS CLAVE:
--   {emp}_mto_trx_presencial_1m  → monto de ventas en tienda del cliente ese mes
--   {emp}_mto_trx_digital_1m     → monto de ventas online del cliente ese mes
--   {emp}_mtoprom_1m             → ticket promedio del cliente ese mes (NO sumar, usar AVG)
--   {emp}_frecuencia_1m          → número de transacciones del cliente ese mes
-- ============================================================

SELECT
    process_date,

    -- Promart: monto total = presencial + digital de todos los clientes
    SUM(pro_mto_trx_presencial_1m  + pro_mto_trx_digital_1m)  AS monto_total_venta_promart,

    -- SPSA (Plaza Vea, Vivanda, Mass, Makro): ídem
    SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m) AS monto_total_venta_spsa,

    -- Oechsle: ídem
    SUM(oe_mto_trx_presencial_1m   + oe_mto_trx_digital_1m)   AS monto_total_venta_oechsle,

    -- Ticket promedio: AVG del promedio individual de cada cliente activo en SPSA
    -- (no SUM — sería suma de promedios individuales, sin sentido de negocio)
    AVG(spsa_mtoprom_1m)                                       AS ticket_promedio_cliente_spsa

FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date >= '2026-01-01'
GROUP BY process_date
ORDER BY process_date;


-- ============================================================
-- VARIANTE: incluir número de clientes activos por empresa
-- ============================================================

SELECT
    process_date,

    -- SPSA
    SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m) AS monto_total_spsa,
    SUM(spsa_frecuencia_1m)                                    AS transacciones_spsa,
    COUNT(DISTINCT CASE WHEN spsa_frecuencia_1m > 0 THEN id_intercorp END) AS clientes_activos_spsa,
    SAFE_DIVIDE(
        SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m),
        SUM(spsa_frecuencia_1m)
    )                                                          AS ticket_real_spsa,

    -- Promart
    SUM(pro_mto_trx_presencial_1m + pro_mto_trx_digital_1m)   AS monto_total_promart,
    SUM(pro_frecuencia_1m)                                     AS transacciones_promart,
    COUNT(DISTINCT CASE WHEN pro_frecuencia_1m > 0 THEN id_intercorp END) AS clientes_activos_promart,

    -- Oechsle
    SUM(oe_mto_trx_presencial_1m + oe_mto_trx_digital_1m)     AS monto_total_oechsle,
    SUM(oe_frecuencia_1m)                                      AS transacciones_oechsle,
    COUNT(DISTINCT CASE WHEN oe_frecuencia_1m > 0 THEN id_intercorp END) AS clientes_activos_oechsle

FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date BETWEEN '2026-01-01' AND '2026-06-01'
GROUP BY process_date
ORDER BY process_date;


-- ============================================================
-- VARIANTE: canal presencial vs digital por empresa
-- ============================================================

SELECT
    process_date,

    -- SPSA por canal
    SUM(spsa_mto_trx_presencial_1m)                            AS monto_spsa_presencial,
    SUM(spsa_mto_trx_digital_1m)                               AS monto_spsa_digital,
    SAFE_DIVIDE(
        SUM(spsa_mto_trx_digital_1m),
        SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m)
    ) * 100                                                    AS pct_digital_spsa,

    -- Promart por canal
    SUM(pro_mto_trx_presencial_1m)                             AS monto_promart_presencial,
    SUM(pro_mto_trx_digital_1m)                                AS monto_promart_digital,

    -- Oechsle por canal
    SUM(oe_mto_trx_presencial_1m)                              AS monto_oechsle_presencial,
    SUM(oe_mto_trx_digital_1m)                                 AS monto_oechsle_digital

FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date >= '2026-01-01'
GROUP BY process_date
ORDER BY process_date;
