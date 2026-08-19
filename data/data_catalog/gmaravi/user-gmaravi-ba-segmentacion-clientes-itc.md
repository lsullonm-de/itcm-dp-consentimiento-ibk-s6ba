# Catálogo de Datos — `ba_segmentacion_clientes_itc`

**Proyecto:** `int-advanced-analytics-01`
**Dataset:** `gmaravi`
**Tabla completa:** `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
**Prefijo de archivo:** `user_gmaravi_` (tabla en esquema de usuario)

---

## Descripción

**Maestro de segmentación de clientes Intercorp** — la tabla de perfil más completa y consolidada del repositorio. Con 373 columnas y 21.7 millones de clientes, consolida en una sola vista por cliente (`id` = DNI):

- **Consumo retail** en cada empresa Intercorp (SPSA, OE, Promart, Farmacias, Mass, Vivanda)
- **Perfil demográfico** (edad, género, departamento, NSE implícito)
- **Situación financiera** (bancarización, tarjetas, deuda, mora, RCC)
- **Comportamiento de entretenimiento** (Cineplanet, NGR/restaurantes, streamings, delivery)
- **Presencia en malls** (mall favorito, intensidad de visita)
- **Segmento de interés** (categoría de producto más consumida)
- **Flags de lifecycle** (hijo infante, colegial, propietario, empleado ITC, digital, fidelizado)
- **Vínculos** (tiene vínculo familiar, padre en Innova)

Es el punto de partida ideal para cualquier análisis de perfilamiento o segmentación multidimensional de clientes Intercorp.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | **NO** (snapshot único) |
| Clusterizado | NO |
| Total de filas | 21,704,930 (~21.7M) |
| Número de columnas | 373 |
| Tamaño lógico | ~64.9 GB |
| Tamaño físico | ~1.9 GB (alta compresión) |
| Granularidad | **1 fila por cliente** (`id` = DNI) — sin duplicados |
| Actualización | Carga estática (snapshot puntual) |
| Proyecto | `int-advanced-analytics-01` (esquema analítico de usuario) |

---

## Glosario de Campos

Por el volumen (373 columnas), los campos se organizan por **familia temática**.

### 1. Identificadores

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `id` | STRING | **DNI / CE / RUC del cliente**. Clave primaria — 0% NULL, sin duplicados. | 0% NULL |
| `tipo_persona_juridica` | STRING | `"NATURAL"` (95.3%) o `"JURÍDICA"` (4.7%) | 0% NULL |

### 2. Consumo retail Intercorp

| Campo | Tipo | Descripción |
|---|---|---|
| `monto_venta_bruto_itc` | FLOAT64 | **Monto total acumulado** en todas las empresas Intercorp (retail). Promedio: S/. 957; Mediana: S/. 200 |
| `q_trx_itc` | INT64 | Número total de transacciones retail Intercorp |
| `cantidad_empresas` | INT64 | Número de empresas Intercorp distintas donde compró |
| `monto_venta_bruto_supermercados_peruanos_itc` | FLOAT64 | Monto en SPSA (PV/Mass/Vivanda). Promedio: S/. 469 |
| `monto_venta_bruto_tiendas_peruanas_itc` | FLOAT64 | Monto en OE/Tiendas Peruanas. Promedio: S/. 71 |
| `monto_venta_bruto_promart_itc` | FLOAT64 | Monto en Promart. Promedio: S/. 102 |
| `monto_venta_bruto_inkafarma_itc` | FLOAT64 | Monto en Inkafarma. Promedio: S/. 175 |
| `monto_venta_bruto_mifarma_itc` | FLOAT64 | Monto en Mifarma. Promedio: S/. 140 |
| `monto_venta_bruto_plaza_vea_itc` | FLOAT64 | Monto en Plaza Vea. Promedio: S/. 269 |
| `monto_venta_bruto_mass_itc` | FLOAT64 | Monto en Mass/Makro. Promedio: S/. 20 |
| `monto_venta_bruto_vivanda_itc` | FLOAT64 | Monto en Vivanda. Promedio: S/. 11 |
| `monto_venta_bruto_farmacias_peruanas_itc` | FLOAT64 | Monto consolidado en todas las farmacias. Promedio: S/. 315 |
| `q_trx_supermercados_peruanos_itc` | INT64 | N° transacciones SPSA |
| `q_trx_tiendas_peruanas_itc` | INT64 | N° transacciones OE |
| `q_trx_promart_itc` | INT64 | N° transacciones Promart |
| `q_trx_inkafarma_itc` | INT64 | N° transacciones Inkafarma |
| `q_trx_mifarma_itc` | INT64 | N° transacciones Mifarma |
| `cant_meses_consumo_retail` | INT64 | Meses activos en retail Intercorp |
| `rango_meses_consumo_retail` | STRING | Rango: `"1-4 MESES"`, `"5-8 MESES"`, `"9-12 MESES"`, `"INTERBANK + FINANCIERA OH"` |

### 3. Consumo total (retail + no-retail)

| Campo | Tipo | Descripción |
|---|---|---|
| `consumo_total` | FLOAT64 | Gasto total estimado del cliente (retail ITC + otros canales). Promedio: S/. 2,493; Mediana: S/. 285 |
| `cant_meses_consumo_total` | INT64 | Meses activos en cualquier canal. Promedio: 5.78 meses |
| `cant_tiendas_consumo` | INT64 | Número de tiendas distintas visitadas. Promedio: 4.36 |
| `cant_departamentos_consumo` | INT64 | Número de departamentos donde compró. Promedio: 1.27 |
| `trx_itc_total_izipay` | INT64 | Transacciones en comercios Intercorp vía Izipay |
| `monto_bruto_itc_total_izipay` | FLOAT64 | Monto en comercios Intercorp vía Izipay |
| `trx_no_itc_total_izipay` | INT64 | Transacciones en comercios externos vía Izipay |
| `monto_bruto_no_itc_total_izipay` | FLOAT64 | Monto en comercios externos vía Izipay |

### 4. Flags de validez (outliers)

| Campo | Tipo | Descripción | Clientes válidos |
|---|---|---|---|
| `flag_valido_no_outlier_supermercados` | INT64 | `1` = cliente válido para análisis SPSA (no outlier) | 12,213,741 |
| `flag_valido_no_outlier_farmacias` | INT64 | `1` = cliente válido para análisis de farmacias | 15,942,125 |
| `flag_valido_no_outlier_tiendas` | INT64 | `1` = cliente válido para análisis OE | 3,369,958 |
| `flag_valido_no_outlier_promart` | INT64 | `1` = cliente válido para análisis Promart | 3,371,498 |

### 5. Segmentación y rangos de comportamiento

| Campo | Tipo | Descripción | Valores principales |
|---|---|---|---|
| `segmento_interes` | STRING | **Categoría de producto de mayor interés** inferida del comportamiento de compra | Ver tabla abajo (4.4% NULL) |
| `rango_transacciones_cliente` | STRING | Frecuencia de compra | `1 VEZ`, `2 a 3 VECES`, `4 a 8 VECES`, `9 a 12 VECES`, `MÁS DE 12 VECES`, `INTERBANK + FINANCIERA OH` |
| `rango_cantidad_empresas` | STRING | N° de empresas Intercorp donde compra | `1-2`, `3-4`, NULL |
| `rango_edad` | STRING | Grupo etario | `<18`, `18 a 24`, `25 a 34`, `35 a 44`, `45 a 54`, `55 a 64`, `>64` (15.3% NULL) |

### 6. Segmentos de interés principales

| `segmento_interes` | Clientes | % |
|---|---|---|
| `SIN HISTORIA` | 6,878,275 | 31.7% |
| `BEBIDAS CON ALCOHOL + FRESCOS + CONGELADOS` | 6,529,758 | 30.1% |
| `CINE + ACABADOS GENERALES` | 1,750,458 | 8.1% |
| `NUTRICION ADULTOS + WELLNESS` | 780,057 | 3.6% |
| `MEDICAMENTOS + NUTRICION` | 504,270 | 2.3% |
| `WELLNESS + BELLEZA` | 495,111 | 2.3% |
| `MULTICATEGORIA (BEBIDAS, FRESCOS, LACTEOS, DECOHOGAR)` | 422,802 | 1.9% |
| `DISPOSITIVOS MEDICOS DE USO GENERAL + MEDICAMENTOS + NUTRICION ADULTOS` | 379,487 | 1.7% |
| `NUTRICION INFANTIL + CALZADO + INFANTIL` | 349,946 | 1.6% |
| `INFANTIL + NUTRICION INFANTIL` | 315,041 | 1.5% |
| `MEDICAMENTOS` | 311,263 | 1.4% |
| `INDUMENTARIA` | 274,990 | 1.3% |
| `DEPORTES + ROPA HOMBRE` | 206,930 | 1.0% |
| *~20 segmentos adicionales* | — | — |
| NULL | 953,021 | 4.4% |

### 7. Datos demográficos

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `edad` | INT64 | Edad del cliente. Promedio: 45.65 años; Min: 7; Max: 141 (error) | — |
| `rango_edad` | STRING | Grupo etario agrupado | 15.3% NULL |
| `genero` | STRING | `"F"` (43%), `"M"` (40%) | 17.8% NULL |
| `categoria_hijo_menor` | STRING | `"SIN HIJO"` (82.8%), `"COLEGIO"` (13%), `"BEBE"` (4.1%) | — |

### 8. Geografía

| Campo | Tipo | Descripción | Calidad |
|---|---|---|---|
| `departamento` | STRING | Departamento de residencia. Top: LIMA (7.3M), LA LIBERTAD (1.1M) | 20.7% NULL |
| `departamento_lima_callao` | STRING | `"LIMA + CALLAO"` agrupados, o departamento para provincias | — |
| `region_somos_uno` | STRING | Región comercial Intercorp. Ej: `"LIMA MODERNA"`, `"LIMA NORTE"`, `"AREQUIPA"` | 20.7% NULL |
| `provincia` | STRING | Provincia de residencia | — |
| `distrito` | STRING | Distrito de residencia | — |
| `flag_residencia_lima_callao` | INT64 | `1` = reside en Lima o Callao (7.2M clientes) | — |
| `flag_residencia_otros_depart` | INT64 | `1` = reside en provincias distintas a Lima Provincias (9.5M) | — |
| `flag_residencia_lima_provincias` | INT64 | `1` = Lima Provincias (491K) | — |

### 9. Flags de lifecycle y perfil

| Campo | Tipo | Descripción | Clientes |
|---|---|---|---|
| `flag_cliente_ibk_itc` | INT64 | `1` = cliente activo de Interbank | 5,904,859 (27%) |
| `flag_cliente_foh_itc` | INT64 | `1` = cliente Financiera OH! | 3,465,319 (16%) |
| `flag_activo_solo_ibk_foh` | INT64 | `1` = solo tiene actividad en IBK/FOH, sin retail | 953,021 (4.4%) |
| `flag_bancarizado` | INT64 | `1` = tiene relación con sistema financiero formal | 12,637,423 (58%) |
| `flag_contactable` | INT64 | `1` = tiene al menos un dato de contacto válido (email o cel) | 13,367,023 (62%) |
| `flag_fidelidad` | INT64 | `1` = cliente fidelizado según programa Intercorp | 3,345,007 (15%) |
| `flag_cliente_digital` | INT64 | `1` = cliente con comportamiento digital activo | 132,516 (0.6%) |
| `flag_empleado_itc` | INT64 | `1` = es empleado del Grupo Intercorp | 335,514 (1.5%) |
| `flag_tiene_vinculo` | INT64 | `1` = tiene al menos un vínculo familiar detectado | 4,225,838 (19.5%) |
| `flag_hijo_infante` | INT64 | `1` = tiene hijo en edad de bebé/infante | 992,328 |
| `flag_propietario_vivienda` | INT64 | `1` = propietario de vivienda | 3,232,365 |
| `flag_propietario_vehiculo` | INT64 | `1` = propietario de vehículo | 1,244,646 |
| `flag_vinculo_innova` | INT64 | `1` = tiene hijo en Innova Schools | 62,139 |
| `flag_padre_innova` | INT64 | `1` = es padre de alumno en Innova Schools | 54,580 |
| `flag_vinculo_colegio` | INT64 | `1` = tiene hijo en edad escolar | 113,475 |
| `flag_cliente_top_1000` | INT64 | `1` = cliente de mayor valor (top 1,000 percentil) | 4,534,925 |
| `flag_cliente_top_3500` | INT64 | `1` = cliente de valor muy alto | 1,287,262 |

### 10. Mall y Real Plaza

| Campo | Tipo | Descripción | Clientes |
|---|---|---|---|
| `flag_mall` | INT64 | `1` = consume en algún mall | 11,057,920 |
| `flag_rp` | INT64 | `1` = consume en Real Plaza | 6,947,365 |
| `mall_preferido` | STRING | Nombre del mall más visitado. Top: Real Plaza Huancayo (474K), Real Plaza Piura (458K) | 47.4% NULL |
| `intensidad_mall_preferido` | STRING | `"PREFERENCIA ALTA"` (9.4M) o `"PREFERENCIA MEDIA"` (2M) | — |
| `intensidad_visitas_malls` | STRING | `"ESPORÁDICO"` (8M), `"OCASIONAL"` (1.5M), `"FRECUENTE"` (1.9M) | — |

### 11. Ubicación de consumo

| Campo | Tipo | Descripción |
|---|---|---|
| `ubicacion_top_consumo_retail` | STRING | Dept-Prov-Dist donde más compra en retail. Formato: `"LIMA_LIMA_ATE"`. 8.4M NULL. |
| `ubicacion_top_consumo_cine` | STRING | Dept-Prov-Dist donde más va al cine. Mayormente Lima. |
| `ubicacion_top_consumo_retail_cine` | STRING | Ubicación combinada retail + cine. |
| `flag_consume_mall_distrito_residencia` | INT64 | `1` = consume principalmente en el mall de su distrito | 3,794,377 |
| `flag_traslado` | INT64 | `1` = consume en un mall fuera de su distrito (se traslada) | 6,698,854 |
| `flag_movilidad` | INT64 | `1` = alto nivel de movilidad geográfica de consumo | 5,713,821 |

### 12. Situación financiera (RCC — última foto)

| Campo | Tipo | Descripción |
|---|---|---|
| `tramo_de_mora_ult_foto` | STRING | Tramo de mora: `"0"` (93.99%), `">120"`, `"1 - 30"`, etc. |
| `max_dias_atraso_deuda_directa_ult_foto` | INT64 | Días máximos de atraso en deuda directa |
| `saldo_promedio_deudor_ult_foto` | NUMERIC | Saldo promedio adeudado. Promedio: S/. 2,511 |
| `mto_linea_tc_consumo_ult_foto` | NUMERIC | Línea de crédito de tarjeta disponible. Promedio: S/. 8,022 |
| `flag_tiene_tc_ult_foto` | INT64 | `1` = tiene tarjeta de crédito activa (4.4M clientes) | — |
| `flag_deuda_hipotecaria_ult_foto` | INT64 | `1` = tiene deuda hipotecaria (297K clientes) | — |
| `flag_deuda_prestamo_personal_consumo_ult_foto` | INT64 | `1` = tiene préstamo personal (4.1M clientes) | — |
| `flag_cliente_ibk_rcc_ult_foto` | INT64 | `1` = aparece en RCC de Interbank | — |
| `flag_cliente_bcp_rcc_ult_foto` | INT64 | `1` = aparece en RCC de BCP (3.3M) | — |
| `flag_tc_bcp_ult_foto` | INT64 | `1` = tiene TC BCP activa (1.2M) | — |
| `flag_tc_falabella_ult_foto` | INT64 | `1` = tiene TC Falabella (1.3M) | — |

### 13. IBK — Relación con Interbank

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_trx_ibk` | INT64 | N° de transacciones con tarjeta IBK. Promedio: 7.81 |
| `monto_bruto_ibk` | FLOAT64 | Monto total pagado con IBK. Promedio: S/. 881 |

### 14. Entretenimiento — Cineplanet

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_entretenimiento` | INT64 | `1` = tiene algún consumo en entretenimiento | 3,852,347 |
| `flag_cineplanet` | INT64 | `1` = consume en Cineplanet | 1,587,628 |
| `cant_visitas_cineplanet` | FLOAT64 | N° visitas a Cineplanet |
| `monto_bruto_cineplanet` | FLOAT64 | Monto en Cineplanet |
| `genero_top_peliculas_cp` | STRING | Género de película favorita (99.97% NULL — campo muy incompleto) |
| `cant_trx_cinemark_*` / `monto_bruto_cinemark_*` | FLOAT64 | Consumo en Cinemark (competencia) |

### 15. NGR / Restaurantes

| Campo | Tipo | Descripción | Clientes |
|---|---|---|---|
| `flag_ngr` | INT64 | `1` = consume en restaurantes NGR | 3,119,738 |
| `canal_pref_ngr` | STRING | Canal preferido: `"PRESENCIAL"` (894K), `"OMNICANAL"` (302K), `"DIGITAL"` (58K) | — |
| `tipo_consumo_pref_ngr` | STRING | `"INDIVIDUAL"` (372K) o `"GRUPAL"` (293K) | — |
| `dia_semana_preferido_ngr` | STRING | Día de visita preferido: SÁBADO, DOMINGO, VIERNES, etc. | — |
| `horario_consumo_ngr` | STRING | Horario: `"17-23"` (cena, 358K) o `"11-16"` (almuerzo, 181K) | — |

Por cada marca del grupo NGR (Bembos, Dunkin, Papa Johns, Don Belisario, Popeyes, ChinaWok) hay campos similares.

### 16. Delivery / Agregadores

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_agreg_pickup_{marca}` | INT64 | `1` = usa delivery/pickup de esa marca vía agregador |
| `cant_trx_agreg_pickup_{marca}` | INT64 | N° pedidos vía delivery de esa marca |
| `monto_bruto_agreg_pickup_{marca}` | FLOAT64 | Monto en delivery de esa marca |

Top marcas por clientes con delivery: Papa Johns (116K), Popeyes (69K), Bembos (67K).

### 17. Streaming

| Campo | Tipo | Descripción |
|---|---|---|
| `monto_bruto_streamming_cp_netflix` | FLOAT64 | Gasto en Netflix (cobrado via IBK/FOH) |
| `monto_bruto_streamming_cp_disney_plus` | FLOAT64 | Gasto en Disney+ |
| `monto_bruto_streamming_cp_spotify` | FLOAT64 | Gasto en Spotify |
| `monto_bruto_streamming_cp_amazon_prime` | FLOAT64 | Gasto en Amazon Prime |
| `monto_bruto_streamming_cp_paramount_plus` | FLOAT64 | Gasto en Paramount+ |

### 18. Viaje y movilidad

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_viaje` | INT64 | `1` = tiene consumo en servicios de viaje (5.2M) |
| `flag_movilidad` | INT64 | `1` = alto nivel de desplazamiento geográfico (5.7M) |

---

## Reglas de negocio

1. **1 fila por cliente** — no hay duplicados. El `id` es clave única.

2. **Sin partición — snapshot estático**: La tabla no tiene `process_date`. Representa un estado puntual del modelo. Para filtros de tiempo, usar las ventanas de los atributos fuente.

3. **`segmento_interes = 'SIN HISTORIA'` (31.7%)**: Clientes con historial insuficiente para inferir interés. Tratar como segmento de baja madurez de datos.

4. **`rango_transacciones_cliente = 'INTERBANK + FINANCIERA OH'` (4.4%)**: Clientes que solo tienen relación financiera (IBK/FOH) sin historial de compra retail. Sus `monto_venta_bruto_*` son 0.

5. **`flag_valido_no_outlier_*`**: SIEMPRE filtrar por el flag correspondiente al hacer análisis de una empresa específica. Evita distorsión por clientes con patrones anómalos (empleados, cuentas especiales).

6. **`edad >= 100` (outlier)**: Hay clientes con `edad = 141` y similares — errores de datos origen. Filtrar `WHERE edad BETWEEN 18 AND 99` para análisis demográficos.

7. **`tramo_de_mora_ult_foto = '0'`**: 94% de clientes sin mora — perfil de riesgo bajo del universo activo. Segmento con mora (`> 30 días`) representa ~6% y debe excluirse de campañas de crédito.

8. **`flag_contactable = 1`**: Solo el 62% de clientes tiene dato de contacto válido. Las campañas de comunicación deben filtrar por este flag.

9. **`tipo_persona_juridica = 'JURÍDICA'` (4.7%)**: Son empresas/RUCs, no personas naturales. Excluir en análisis de comportamiento de consumidor individual.

---

## Observaciones de calidad de datos

| Campo | % NULL | Observación |
|---|---|---|
| `departamento` | 20.7% | 4.5M clientes sin ubicación geográfica conocida |
| `rango_edad` / `genero` | 15-18% | Datos demográficos incompletos en una porción relevante |
| `segmento_interes` | 4.4% | Corresponde al segmento IBK/FOH sin retail |
| `mall_preferido` | 47.4% | Solo para clientes con consumo en mall identificado |
| `genero_top_peliculas_cp` | 99.97% | Campo prácticamente vacío — no usar |
| `edad` outliers | — | Valores hasta 141 años — filtrar con `BETWEEN 18 AND 99` |
| **Sin `process_date`** | — | No hay control temporal. Snapshot único, sin versión histórica. |
| 373 columnas | — | Nunca usar `SELECT *`. Siempre especificar columnas. |

---

## Queries de referencia

```sql
-- Perfil de segmento de interés en Lima por género
SELECT segmento_interes, genero, COUNT(*) as clientes,
  ROUND(AVG(monto_venta_bruto_itc), 2) as monto_prom
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE departamento = 'LIMA'
  AND tipo_persona_juridica = 'NATURAL'
  AND flag_valido_no_outlier_supermercados = 1
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Clientes con hijo infante + compras en farmacias (segmento madre/padre con bebé)
SELECT id, monto_venta_bruto_inkafarma_itc + monto_venta_bruto_mifarma_itc AS monto_farmacias,
  genero, rango_edad, departamento, flag_contactable
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE flag_hijo_infante = 1
  AND (monto_venta_bruto_inkafarma_itc > 0 OR monto_venta_bruto_mifarma_itc > 0)
  AND tipo_persona_juridica = 'NATURAL'
ORDER BY monto_farmacias DESC;

-- Clientes con mora que también son cliente Interbank (riesgo interno)
SELECT tramo_de_mora_ult_foto, COUNT(*) as clientes,
  ROUND(AVG(monto_venta_bruto_itc), 2) as monto_prom_retail
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE flag_cliente_ibk_itc = 1
  AND tramo_de_mora_ult_foto != '0'
GROUP BY 1
ORDER BY 2 DESC;

-- Segmento: amantes del cine + alto consumo en retail (potencial campaña cross-sell)
SELECT id, segmento_interes, flag_cineplanet, monto_venta_bruto_itc,
  mall_preferido, intensidad_mall_preferido, rango_edad, genero
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE flag_cineplanet = 1
  AND monto_venta_bruto_itc >= 1000
  AND rango_transacciones_cliente = 'MÁS DE 12 VECES'
  AND flag_contactable = 1
ORDER BY monto_venta_bruto_itc DESC;

-- Top malls por volumen de clientes frecuentes
SELECT mall_preferido, intensidad_visitas_malls,
  COUNT(*) as clientes, ROUND(AVG(consumo_total), 2) as consumo_prom
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE mall_preferido IS NOT NULL
  AND intensidad_visitas_malls = 'FRECUENTE'
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;

-- Clientes de farmacias con posible cronicidad (medicamentos + alta frecuencia)
SELECT id, q_trx_inkafarma_itc + q_trx_mifarma_itc AS trx_farmacias,
  monto_venta_bruto_farmacias_peruanas_itc, segmento_interes,
  rango_edad, departamento
FROM `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc`
WHERE segmento_interes IN ('MEDICAMENTOS', 'MEDICAMENTOS + NUTRICION',
  'DISPOSITIVOS MEDICOS DE USO GENERAL + MEDICAMENTOS + NUTRICION ADULTOS')
  AND flag_valido_no_outlier_farmacias = 1
  AND (q_trx_inkafarma_itc + q_trx_mifarma_itc) >= 12
ORDER BY q_trx_inkafarma_itc + q_trx_mifarma_itc DESC;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `int-advanced-analytics-01.gmaravi.ba_segmentacion_clientes_itc` — Tabla de usuario (esquema `gmaravi`) — Snapshot estático sin `process_date`*
