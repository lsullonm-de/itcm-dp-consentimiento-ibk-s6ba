# Catálogo de Datos — Modelo de Clientes Intercorp

Documentación de las tablas del modelo de datos del Grupo Intercorp organizadas por **dataset BigQuery**.
Cada catálogo contiene: Catalog ID, descripción, metadata técnica, diccionario completo de campos, reglas de negocio, observaciones de calidad y queries de referencia.

**Convención de rutas:** `{dataset}/{tabla-con-hyphens}.md`
**Catalog ID:** `{dataset}.{tabla}` — identificador independiente del proyecto (dev o prd).
**Actualizado:** 2026-07-20

---

## Índice por Dataset

| Dataset | Descripción | Catálogos |
|---|---|---|
| [`ba_fape_agent`](#ba_fape_agent) | FAPE Agent — cupones y venta de mesón (Inkafarma / Mifarma) | 3 |
| [`bi_itcm_agent`](#bi_itcm_agent) | Tablas del Agente de Análisis de Datos (ventas propias + POS externo) | 2 |
| [`master_transaction`](#master_transaction) | Transacciones de venta, pagos, POS | 5 |
| [`master_party`](#master_party) | Identidad y catálogo de empresas | 2 |
| [`master_placement`](#master_placement) | Maestros de comercios y tiendas | 3 |
| [`master_product`](#master_product) | Catálogo de productos y SKUs | 2 |
| [`bi_itc_attribute_party`](#bi_itc_attribute_party) | Atributos calculados de cliente + catálogos de clasificación | 21 |
| [`bi_ibk_casos_uso`](#bi_ibk_casos_uso) | Catálogos específicos para casos de uso Interbank | 3 |
| [`bi_vuc_insight`](#bi_vuc_insight) | Ventas retail y RCC — dataset VUC Insight | 2 |
| [`bi_itcm_somos1`](#bi_itcm_somos1) | Clientes cross-retail programa Somos 1 | 2 |
| [`raw_itcm_sitc`](#raw_itcm_sitc) | Ventas no-retail / beneficios empleados | 1 |
| [`ba_prediction`](#ba_prediction) | Predicciones analíticas (EAV) | 1 |
| [`farmas_stage`](#farmas_stage) | Staging Farmacias Peruanas | 1 |
| [`aodarm`](#aodarm) | Tablas de usuario aodarm | 2 |
| [`gmaravi`](#gmaravi) | Tablas de usuario gmaravi | 1 |

---

## ba_fape_agent

Tablas analíticas del **FAPE Agent** (Farmacias — Inkafarma / Mifarma). Datos de cupones y venta de mesón para análisis de efectividad de campañas promocionales. Proyecto: `itc-data-governance-01`. Sin PII — el discriminador de empresa es `corporacion` (texto), no `itc_company_id`.

> Las 3 tablas se relacionan entre sí por `jq3 + categoria + periodo`.

| Catalog ID | Filas | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `ba_fape_agent.ventas_jq3_cupon` | 2,793 | Sin partición · filtrar por `periodo` (YYYYMM) | Venta de cupones agregada por JQ3, tipo de cupón (`DIGITAL`, `RULETA`, `FLASH`, `MASIVO`, `PERSONALIZADO`) y segmento cliente (`NUEVO`, `REENGANCHE`, `OTRO`) | [ver detalle](ba_fape_agent/ventas-jq3-cupon.md) |
| `ba_fape_agent.informacion_tipificaciones` | 18,110 | Sin partición · filtrar por `periodo` (YYYYMM) | Tipificación semántica de cupones por campaña (`llave` = clave única). Contiene jerarquías JQ1–JQ3, métricas económicas (venta, costo, margen, usos, emisiones) y tipificación (`EXACTO`/`FUZZY`). ⚠️ ~9.9% filas sin métricas (filtrar `venta_cup IS NOT NULL`) | [ver detalle](ba_fape_agent/informacion-tipificaciones.md) |
| `ba_fape_agent.ventas_zonas` | 317,371 | Sin partición · usar `tipo_periodo` | Venta de mesón por zona geográfica de Lima y jerarquía de categoría (hasta `jq5` y `marca`). `tipo_periodo` clasifica cada fila en `MES_ACTUAL` / `MES_ANTERIOR` / `MISMO_MES_AÑO_PASADO` para MoM y YoY directos | [ver detalle](ba_fape_agent/ventas-zonas.md) |

---

## bi_itcm_agent

Tablas del **Agente de Análisis de Datos** — ventas en tiendas propias Intercorp y gasto de clientes en comercios externos (POS). Fuentes primarias para análisis de share of wallet, comportamiento de gasto y evolución mensual de métricas de negocio. Proyecto: `itc-data-governance-01`.

| Catalog ID | Filas | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itcm_agent.dv_agente_analisis_datos` | 79,612 | `process_date` (18 meses) | Ventas retail propias Intercorp (Farmacias, Supermercados, Promart, Tiendas Peruanas) por empresa/marca/canal/depto/categoría | [ver detalle](bi_itcm_agent/dv-agente-analisis-datos.md) |
| `bi_itcm_agent.dv_agente_analisis_datos_pos` | 4,618 | `process_date` (18 meses) | Gasto de clientes Intercorp en POS externos (275 tipos de comercio MCC) — share of wallet externo | [ver detalle](bi_itcm_agent/dv-agente-analisis-datos-pos.md) |

---

## master_transaction

Transacciones de venta retail, POS y pagos con tarjeta.

| Catalog ID | Filas aprox. | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `master_transaction.t_retail_transaction` | ~4.7B | `transaction_date` | Ítems de ticket de venta retail (SPSA, OE, Promart, Farmacias) | [ver detalle](master_transaction/t-retail-transaction.md) |
| `master_transaction.t_payment` | ~2.83B | `payment_date` | Detalle de medios de pago vinculado a `t_retail_transaction` | [ver detalle](master_transaction/t-payment.md) |
| `master_transaction.t_transaction` | ~3.4B | `itc_process_date` | Transacciones POS/ecommerce Izipay (086) | [ver detalle](master_transaction/t-transaction.md) |
| `master_transaction.t_experience_transaction` | ~577M | `transaction_date` | Entretenimiento: entradas Cineplanet + restaurantes NGR | [ver detalle](master_transaction/t-experience-transaction.md) |
| `master_transaction.c_bin_card` | ~22K | Sin partición | Catálogo de BINs de tarjetas — banco emisor y marca | [ver detalle](master_transaction/c-bin-card.md) |

---

## master_party

Identidad y vinculación de clientes entre empresas del grupo.

| Catalog ID | Filas aprox. | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `master_party.iden_itc_party` | ~467M | Sin partición | Vincula `party_id` con documentos de identidad por empresa | [ver detalle](master_party/iden-itc-party.md) |
| `master_party.c_itc_company` | 83 | Sin partición | Catálogo de todas las empresas del Grupo Intercorp con `itc_company_id` | [ver detalle](master_party/c-itc-company.md) |

---

## master_placement

Maestros de tiendas propias y comercios de la red POS.

| Catalog ID | Filas aprox. | Descripción | Catálogo |
|---|---|---|---|
| `master_placement.m_place` | ~20K | Maestro de tiendas/sucursales propias (Inkafarma, Mifarma) | [ver detalle](master_placement/m-place.md) |
| `master_placement.m_commerce` | ~2.9M | Maestro de comercios afiliados a IZIPAY (segmento MCC, geodata) | [ver detalle](master_placement/m-commerce.md) |
| `master_placement.c_productos_escenciales_pos` | 253 | Clasificación MCC: esenciales vs. no esenciales (POS Izipay) | [ver detalle](master_placement/c-productos-escenciales-pos.md) |

---

## master_product

Catálogo de productos y clasificación de SKUs.

| Catalog ID | Filas aprox. | Descripción | Catálogo |
|---|---|---|---|
| `master_product.m_product` | ~3.7M | Catálogo de productos (OE, Promart, Farmacias) con jerarquía jq1–jq8 | [ver detalle](master_product/m-product.md) |
| `master_product.c_productos_escenciales_retail` | ~3.4K | SKUs retail clasificados como esenciales/no esenciales (OE, SPSA) | [ver detalle](master_product/c-productos-escenciales-retail.md) |

---

## bi_itc_attribute_party

Atributos calculados por cliente (`id` + `process_date`) y catálogos de clasificación para construirlos. Output principal del pipeline de atributos — alimenta modelos de marketing, segmentación y casos de uso Interbank.

> **Clave de todos los atributos:** `id` (documento de identidad) + `process_date`

### Atributos de consumo retail

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itc_attribute_party.ba_itc_attr_retail` | ~6.5B | 2,431 | Consumo retail por empresa (SPSA, OE, Promart, Farmacias), canal y ventana temporal | [ver detalle](bi_itc_attribute_party/ba-itc-attr-retail.md) |
| `bi_itc_attribute_party.ba_itc_attr_card_consumption` | ~364M | 74 | Consumo con tarjeta (retail + POS, por tipo, gama, canal, esencialidad) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-card-consumption.md) |
| `bi_itc_attribute_party.ba_itc_attr_payment_pos` | ~323M | 3,705 | Consumo POS/Izipay por rubro MCC, entidad financiera, ventanas 15d–12m | [ver detalle](bi_itc_attribute_party/ba-itc-attr-payment-pos.md) |
| `bi_itc_attribute_party.ba_itc_attr_payment` | ~58M | 2,405 | Consumo con tarjeta OH! y otras tarjetas por ventana temporal | [ver detalle](bi_itc_attribute_party/ba-itc-attr-payment.md) |
| `bi_itc_attribute_party.ba_itc_attr_purchase_card` | ~17M | 125 | Compras por categoría (salud, belleza, deportes, infantil, suplementos) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-purchase-card.md) |

### Atributos de perfil y comportamiento

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itc_attribute_party.ba_itc_attr_corporate` | ~2.76B | 52 | Flags de membresía activa por empresa + segmentaciones | [ver detalle](bi_itc_attribute_party/ba-itc-attr-corporate.md) |
| `bi_itc_attribute_party.ba_itc_attr_demographic` | ~40M | 52 | Demográficos: edad, género, NSE, generación, ubigeo, estado civil | [ver detalle](bi_itc_attribute_party/ba-itc-attr-demographic.md) |
| `bi_itc_attribute_party.ba_itc_attr_digital` | ~974M | 84+ | Comportamiento digital: sesiones, canal, dispositivo, login por empresa | [ver detalle](bi_itc_attribute_party/ba-itc-attr-digital.md) |
| `bi_itc_attribute_party.ba_itc_attr_entertainment` | ~60M | 62 | Entretenimiento Cineplanet: boletería, confitería, frecuencia, cine favorito | [ver detalle](bi_itc_attribute_party/ba-itc-attr-entertainment.md) |
| `bi_itc_attribute_party.ba_itc_attr_bienestar` | ~4.9M | 452 | Salud/bienestar clínico: atenciones médicas, partos, tipo de paciente | [ver detalle](bi_itc_attribute_party/ba-itc-attr-bienestar.md) |
| `bi_itc_attribute_party.ba_itc_attr_insurance` | ~82M | 125 | Seguros vigentes por tipo (vida, SOAT, vehicular, viaje, renta vitalicia) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-insurance.md) |

### Atributos de predicción e intención

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itc_attribute_party.ba_itc_attr_prediction` | ~554M | 21 | Predicciones demográficas y de comportamiento (delivery lover, Intercorp lover, embarazo) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-prediction.md) |
| `bi_itc_attribute_party.ba_itc_attr_purchase_intention` | ~158M | 708 | Intención de compra basada en navegación digital (product views por categoría y ventana) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-purchase-intention.md) |
| `bi_itc_attribute_party.ba_itc_attr_purchase_prediction` | — | — | Predicción de compra futura por categoría (scores de propensión) | [ver detalle](bi_itc_attribute_party/ba-itc-attr-purchase-prediction.md) |

### Atributos financieros / crediticios

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itc_attribute_party.ba_itc_attr_rcc` | ~731M | 6,476 | RCC (SBS): deudas por banco y tipo de crédito ⚠️ sensible | [ver detalle](bi_itc_attribute_party/ba-itc-attr-rcc.md) |

### Contacto y audiencias

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itc_attribute_party.ba_itc_audience_contact` | ~444M | 48 | Contacto: hash_email, nombre, dirección, teléfono por empresa ⚠️ PII | [ver detalle](bi_itc_attribute_party/ba-itc-audience-contact.md) |

### Catálogos de clasificación para atributos

| Catalog ID | Filas | Descripción | Catálogo |
|---|---|---|---|
| `bi_itc_attribute_party.c_attribute_metadata` | ~18K | Metadatos de todos los atributos: nombre, descripción, fórmula, tipo, empresa | [ver detalle](bi_itc_attribute_party/c-attribute-metadata.md) |
| `bi_itc_attribute_party.c_clasificacion_marcas_retail_ibk` | ~11K | Clasifica marcas/SKUs retail (OE, SPSA) por tipo/subtipo para atributos IBK | [ver detalle](bi_itc_attribute_party/c-clasificacion-marcas-retail-ibk.md) |
| `bi_itc_attribute_party.c_flags_categorias_retail_ibk` | ~3.4K | Flags de categorías retail: alimento saludable/no saludable, implemento deportivo | [ver detalle](bi_itc_attribute_party/c-flags-categorias-retail-ibk.md) |

---

## bi_ibk_casos_uso

Catálogos específicos para casos de uso Interbank.

| Catalog ID | Filas | Descripción | Catálogo |
|---|---|---|---|
| `bi_ibk_casos_uso.c_entidades_financieras` | 66 | Normalización de nombres de bancos (múltiples grafías → nombre canónico) | [ver detalle](bi_ibk_casos_uso/c-entidades-financieras.md) |
| `bi_ibk_casos_uso.c_gamas_tarjetas_noibk` | 25 | Clasificación de gamas de tarjetas no-IBK: CLÁSICA, ORO, PLATINUM, SIGNATURE | [ver detalle](bi_ibk_casos_uso/c-gamas-tarjetas-noibk.md) |
| `bi_ibk_casos_uso.c_empresas_cuenta_sueldo_ibk` | 112 | Empresas empleadoras que pagan sueldos vía Interbank | [ver detalle](bi_ibk_casos_uso/c-empresas-cuenta-sueldo-ibk.md) |

---

## bi_vuc_insight

Tablas de ventas agregadas e indicadores crediticios — dataset VUC Insight.

| Catalog ID | Filas aprox. | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_vuc_insight.dv_inretail_venta` | 1,195,515 | `load_date` | Ventas agregadas InRetail por empresa, marca, canal, punto de venta y período | [ver detalle](bi_vuc_insight/dv-inretail-venta.md) |
| `bi_vuc_insight.dv_rcc_montos_tc` | 2,361,084 | Sin partición | Montos RCC de tarjeta de crédito por entidad financiera y geografía ⚠️ `empresa` = banco, no retail | [ver detalle](bi_vuc_insight/dv-rcc-montos-tc.md) |

---

## bi_itcm_somos1

Tablas del programa Somos 1 — clientes cross-retail y tenencia de productos financieros.

| Catalog ID | Filas aprox. | Partición | Descripción | Catálogo |
|---|---|---|---|---|
| `bi_itcm_somos1.dv_clientes_empresa` | 24,526,662 | `DATE(load_date)` | Clientes cross-retail por empresa(s) donde transaccionan, demografía y período | [ver detalle](bi_itcm_somos1/dv-clientes-empresa.md) |
| `bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas` | 20,878 | `process_date` | Penetración YTD de TC IBK, TC OH! y Agora por empresa retail y departamento | [ver detalle](bi_itcm_somos1/dv-clientes-empresa-ytd-tarjetas.md) |

---

## raw_itcm_sitc

| Catalog ID | Filas aprox. | Descripción | Catálogo |
|---|---|---|---|
| `raw_itcm_sitc.t_ventas_noretail` | ~684K | Beneficios no-retail de empleados Intercorp: usos mensuales por empleado y empresa | [ver detalle](raw_itcm_sitc/t-ventas-noretail.md) |

---

## ba_prediction

| Catalog ID | Filas aprox. | Cols | Descripción | Catálogo |
|---|---|---|---|---|
| `ba_prediction.ba_customer_prediction` | ~264M | 14 | Predicciones analíticas en formato EAV (id + atributo + valor). Actualmente: INFANTES | [ver detalle](ba_prediction/ba-customer-prediction.md) |

---

## farmas_stage

| Catalog ID | Filas aprox. | Descripción | Catálogo |
|---|---|---|---|
| `farmas_stage.dv_productos` | — | Staging de productos de Farmacias Peruanas | [ver detalle](farmas_stage/dv-productos.md) |

---

## aodarm

Tablas de usuario del analista `aodarm`.

| Catalog ID | Descripción | Catálogo |
|---|---|---|
| `aodarm.m_itc_vinculos_cliente` | Vínculos de clientes Intercorp | [ver detalle](aodarm/user-aodarm-m-itc-vinculos-cliente.md) |
| `aodarm.tmp_transacciones_totales_cineplanet` | Transacciones totales Cineplanet (temporal) | [ver detalle](aodarm/user-aodarm-tmp-transacciones-totales-cineplanet.md) |

---

## gmaravi

Tablas de usuario del analista `gmaravi`.

| Catalog ID | Descripción | Catálogo |
|---|---|---|
| `gmaravi.ba_segmentacion_clientes_itc` | Segmentación de clientes ITC | [ver detalle](gmaravi/user-gmaravi-ba-segmentacion-clientes-itc.md) |

---

## Guía rápida — ¿Qué tabla usar?

| Necesidad | Tabla(s) recomendada(s) |
|---|---|
| Ventas retail por SKU/tienda | `master_transaction.t_retail_transaction` + `master_product.m_product` + `master_placement.m_place` |
| Pagos POS con tarjeta (todos los comercios) | `master_transaction.t_transaction` + `master_placement.m_commerce` |
| Identificar a qué empresa pertenece un ID | `master_party.iden_itc_party` + `master_party.c_itc_company` |
| Perfil demográfico del cliente | `bi_itc_attribute_party.ba_itc_attr_demographic` |
| Membresía activa del cliente en el grupo | `bi_itc_attribute_party.ba_itc_attr_corporate` |
| Consumo total retail por empresa y ventana | `bi_itc_attribute_party.ba_itc_attr_retail` |
| Consumo POS/Izipay por rubro de comercio | `bi_itc_attribute_party.ba_itc_attr_payment_pos` |
| Ventas propias Intercorp por empresa/marca/canal/categoría (agente analytics) | `bi_itcm_agent.dv_agente_analisis_datos` |
| Gasto externo de clientes Intercorp por tipo de comercio (share of wallet) | `bi_itcm_agent.dv_agente_analisis_datos_pos` |
| Ventas InRetail agregadas por punto de venta | `bi_vuc_insight.dv_inretail_venta` |
| Montos de TC en el sistema financiero (RCC) | `bi_vuc_insight.dv_rcc_montos_tc` |
| Clientes que compran en múltiples empresas | `bi_itcm_somos1.dv_clientes_empresa` |
| Penetración de TC IBK / OH! / Agora por empresa | `bi_itcm_somos1.dv_clientes_empresa_ytd_tarjetas` |
| Clientes con enfermedades crónicas | `master_product.m_product` + `master_transaction.t_retail_transaction` |
| Clientes de alimentación saludable | `bi_itc_attribute_party.c_flags_categorias_retail_ibk` + `master_transaction.t_retail_transaction` |
| Clientes con seguro activo | `bi_itc_attribute_party.ba_itc_attr_insurance` |
| Clientes con deuda/crédito activo | `bi_itc_attribute_party.ba_itc_attr_rcc` |
| Clasificar banco emisor de tarjeta | `master_transaction.c_bin_card` + `bi_ibk_casos_uso.c_entidades_financieras` |
| Gama de tarjeta (clásica/oro/platinum) | `bi_ibk_casos_uso.c_gamas_tarjetas_noibk` |
| Gasto en productos esenciales vs. discrecional | `master_product.c_productos_escenciales_retail` / `master_placement.c_productos_escenciales_pos` |
| Clientes cinéfilos | `bi_itc_attribute_party.ba_itc_attr_entertainment` |
| Clientes digitales / delivery lovers | `bi_itc_attribute_party.ba_itc_attr_digital` + `bi_itc_attribute_party.ba_itc_attr_prediction` |
| Clientes con intención de compra activa | `bi_itc_attribute_party.ba_itc_attr_purchase_intention` |
| Clientes con bebé/infante | `ba_prediction.ba_customer_prediction` (INFANTES) + `bi_itc_attribute_party.ba_itc_attr_prediction` |
| Datos de contacto para campaña (email/tel) | `bi_itc_attribute_party.ba_itc_audience_contact` |
| Consumo con tarjeta OH! | `bi_itc_attribute_party.ba_itc_attr_payment` |
| Consumo con tarjeta por tipo/gama/esencialidad | `bi_itc_attribute_party.ba_itc_attr_card_consumption` |
| Atributos de salud clínica del paciente | `bi_itc_attribute_party.ba_itc_attr_bienestar` |
| Descubrir qué atributos existen | `bi_itc_attribute_party.c_attribute_metadata` |

---

*Actualizado: 2026-07-20 | 49 catálogos en 15 datasets*
