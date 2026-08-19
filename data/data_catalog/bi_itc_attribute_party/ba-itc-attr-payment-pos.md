# Catálogo de Datos — `ba_itc_attr_payment_pos`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment_pos`

---

## Descripción

Atributos de **consumo POS/Izipay con tarjeta** del cliente, agregados por mes. Registra montos y transacciones realizadas en comercios afiliados a la red Izipay (POS), segmentados por entidad financiera, tipo/marca de tarjeta, rubro MCC, comercio específico y canal (presencial/virtual). Incluye 100+ comercios de competencia ITC trackeados individualmente.

**Diferencia con `ba_itc_attr_retail`:** esta tabla cubre consumo externo (Izipay/POS en comercios no-ITC y ITC), mientras que retail cubre las ventas propias del grupo.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~323M |
| Columnas | 3,705 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp` |
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `record_source` | STRING | Origen del registro |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |

---

## 2. Naming Convention

```
{metrica}_{dimension}_{contexto}_ult_{ventana}
```

| Dimensión | Valores |
|---|---|
| `metrica` | `mto_venta` (monto S/), `cant_trx` (transacciones), `mto_max_venta`, `mto_min_venta`, `mto_prom_venta`, `cant_dias` |
| `ventana` | `ult_15d`, `ult_1m`, `ult_3m`, `ult_6m`, `ult_12m` |
| `contexto` | `pos` (todas las transacciones POS) |

> Los campos **sin sufijo `ult_`** no tienen ventana temporal — son del mes actual (equivalen a `_ult_1m`).

---

## 3. Métricas Totales POS

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_venta_pos_ult_{v}` | FLOAT | Monto total de ventas POS en la ventana |
| `cant_trx_pos_ult_{v}` | INTEGER | Número de transacciones POS en la ventana |
| `mto_trx_presencial_pos_ult_{v}` | FLOAT | Monto en transacciones presenciales (chip/contactless) |
| `mto_trx_virtual_pos_ult_{v}` | FLOAT | Monto en transacciones virtuales/online |
| `cant_trx_presencial_pos_ult_{v}` | INTEGER | Transacciones presenciales |
| `cant_trx_virtual_pos_ult_{v}` | INTEGER | Transacciones virtuales |
| `cant_trx_con_cuotas_pos_ult_{v}` | INTEGER | Transacciones pagadas en cuotas |
| `cant_trx_sin_cuotas_pos_ult_{v}` | INTEGER | Transacciones sin cuotas (contado) |
| `mto_venta_con_tarjeta_credito_pos_ult_{v}` | FLOAT | Monto con tarjeta crédito |
| `cant_trx_con_tarjeta_credito_pos_ult_{v}` | INTEGER | Transacciones con tarjeta crédito |
| `mto_venta_con_tarjeta_debito_pos_ult_{v}` | FLOAT | Monto con tarjeta débito |
| `cant_trx_con_tarjeta_debito_pos_ult_{v}` | INTEGER | Transacciones con tarjeta débito |
| `mto_venta_dia_semana_pos_ult_{v}` | FLOAT | Monto en días de semana (lunes-viernes) |
| `cant_trx_dia_semana_pos_ult_{v}` | INTEGER | Transacciones en días de semana |
| `mto_venta_fin_de_semana_pos_ult_{v}` | FLOAT | Monto en fin de semana |
| `cant_trx_fin_de_semana_pos_ult_{v}` | INTEGER | Transacciones en fin de semana |
| `cant_rubros_unicos_venta_pos_ult_{v}` | INTEGER | Cantidad de rubros MCC distintos donde compró |
| `cant_tarjetas_unicas_usadas_pos_ult_{v}` | INTEGER | Cantidad de tarjetas distintas utilizadas |
| `cant_commerce_pos_ult_{v}` | FLOAT | Cantidad de comercios distintos visitados |

---

## 4. Consumo en empresas ITC vs no-ITC

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_venta_empresas_itc_pos_ult_{v}` | FLOAT | Monto en empresas del grupo ITC |
| `cant_trx_empresas_itc_pos_ult_{v}` | INTEGER | Transacciones en ITC |
| `mto_venta_empresas_itc_retail_pos_ult_{v}` | FLOAT | Monto en ITC retail (SPSA, OE, Promart, Farmacias) |
| `cant_trx_empresas_itc_retail_pos_ult_{v}` | INTEGER | Transacciones en ITC retail |
| `mto_venta_empresas_itc_no_retail_pos_ult_{v}` | FLOAT | Monto en ITC no-retail |
| `cant_trx_empresas_itc_no_retail_pos_ult_{v}` | INTEGER | Transacciones en ITC no-retail |
| `mto_venta_empresas_no_itc_pos_ult_{v}` | FLOAT | Monto en comercios NO pertenecientes a ITC |
| `cant_trx_empresas_no_itc_pos_ult_{v}` | INTEGER | Transacciones en no-ITC |

---

## 5. Rankings Top-3

### Por entidad financiera

| Campo | Descripción |
|---|---|
| `entidad_financiera_top_{1/2/3}_trx_ult_{v}` | Banco emisor con más transacciones (#1, #2, #3) |
| `entidad_financiera_top_{1/2/3}_mto_venta_ult_{v}` | Banco emisor con mayor monto (#1, #2, #3) |

### Por tipo de tarjeta

| Campo | Descripción |
|---|---|
| `tipo_tarjeta_top_{1/2/3}_trx_ult_{v}` | Tipo de tarjeta con más transacciones (débito/crédito) |
| `tipo_tarjeta_top_{1/2/3}_mto_venta_ult_{v}` | Tipo de tarjeta con mayor monto |

### Por marca de tarjeta

| Campo | Descripción |
|---|---|
| `marca_tarjeta_top_{1/2/3}_trx_ult_{v}` | Marca (Visa/Mastercard/Amex) con más transacciones |
| `marca_tarjeta_top_{1/2/3}_mto_venta_ult_{v}` | Marca con mayor monto |

### Por rubro MCC

| Campo | Descripción |
|---|---|
| `rubro_top_{1/2/3}_trx_ult_{v}` | Rubro MCC con más transacciones |
| `rubro_top_{1/2/3}_mto_venta_ult_{v}` | Rubro MCC con mayor monto |

### Por comercio y negocio (en rubros clave)

`comercio_{rubro}_top_{1/2/3}_{trx/mto_venta}_ult_{v}` — nombre del comercio físico top
`negocio_{rubro}_top_{1/2/3}_{trx/mto_venta}_ult_{v}` — nombre del negocio/cadena top

**Rubros con ranking de comercio y negocio:**
`accesorios_mascotas`, `aerolineas`, `agencias_viaje`, `apps_delivery_comida`, `apps_streaming`, `apps_taxi`, `apuestas_electronicas`, `bares_discotecas_karaoke`, `chifas_no_itc`, `cines_no_itc`, `colegios_y_nidos_no_itc`, `comida_rapida`, `gastos_carro`, `gimnasios`, `hamburgueserias_no_itc`, `hospital_clinica_no_itc`, `hoteles_hostales`, `institutos_superiores_universidades_no_itc`, `no_itc`, `pagos_estado`, `panaderia_pasteleria_cafeteria`, `pizzerias_no_itc`, `pollerias_no_itc`, `restaurantes`, `seguros_reaseguros_no_itc`, `teatros`, `ticketeras`, `tienda_deportista`, `venta_carro_camion`, `venta_moto`, `veterinarias`

**Ranking global:**
`comercio_top_{1/2/3}_{trx/mto_venta}_ult_{v}` — comercio con más transacciones/monto global
`negocio_top_{1/2/3}_{trx/mto_venta}_ult_{v}` — negocio con más transacciones/monto global

---

## 6. Métricas por Rubro MCC — `mto_venta_rubro_{mcc}_pos` / `cant_trx_rubro_{mcc}_pos`

| Rubro (campo `{mcc}`) | Descripción |
|---|---|
| `agencias_de_viaje` | Agencias de viaje |
| `apps_delivery_comida` | Apps de delivery de comida |
| `apps_streaming` | Servicios de streaming (Netflix, HBO, etc.) |
| `apps_taxi` | Apps de taxi/movilidad |
| `apuestas_electronicas` | Casinos y apuestas online |
| `bares_discotecas_karaoke` | Entretenimiento nocturno |
| `chifa_competencia_itc` | Chifas fuera del grupo ITC |
| `cines_competencia_itc` | Cines fuera del grupo ITC |
| `colegios_nidos_competencia_itc` | Colegios y nidos no-ITC |
| `colegios_nidos` | Colegios y nidos (total) |
| `comida_rapida` | Comida rápida / fast food |
| `comida_rapida_hamburguesas_competencia_itc` | Hamburguesas no-ITC |
| `deportista` | Tiendas deportivas |
| `eventos` | Eventos y espectáculos |
| `gastos_carro` | Gastos relacionados al automóvil |
| `gimnasio` | Gimnasios |
| `grifos` | Grifos y gasolineras |
| `hospitales_clinicas` | Hospitales y clínicas (total) |
| `hospitales_clinicas_competencia_itc` | Clínicas no-ITC |
| `hoteles_hostales_moteles` | Hospedaje |
| `institutos_superiores_universidades_competencia_itc` | Educación superior no-ITC |
| `pagos_al_estado` | Pagos a entidades del Estado |
| `panaderias_cafeterias_pastelerias` | Panaderías y cafeterías |
| `pizzeria_competencia_itc` | Pizzerías no-ITC |
| `polleria_competencia_itc` | Pollerías no-ITC |
| `realiza_viajes` | Viajes (combinado) |
| `restaurantes` | Restaurantes |
| `seguros_competencia_itc` | Seguros no-ITC |
| `ticketera` | Ticketeras y eventos |
| `tiene_mascota` | Comercios para mascotas |
| `venta_de_auto_camion` | Venta de vehículos |
| `venta_de_moto` | Venta de motos |

**Campos adicionales para rubros seleccionados:**
`mto_max_venta_rubro_{mcc}_pos`, `mto_min_venta_rubro_{mcc}_pos`, `mto_prom_venta_rubro_{mcc}_pos`, `cant_dias_rubro_{mcc}_pos`

---

## 7. Métricas por Rubro MCC Gama Alta

Para rubros de gastronomía premium y servicios, métricas específicas de gama alta:

**Rubros con gama alta:** `criollo`, `polleria`, `pizzeria`, `chifa`, `hamburguesas_sandwich`, `cafe_restaurante`, `pasteleria`, `carnes_y_parrillas`, `restobar`, `mascota`, `deportes`, `clinicas`, `hoteles`, `spa_salon_belleza`, `universidades`

| Campo patrón | Descripción |
|---|---|
| `mto_venta_rubro_{rubro}_gama_alta_pos_ult_{v}` | Monto en establecimientos de gama alta |
| `mto_max_rubro_{rubro}_gama_alta_pos_ult_{v}` | Ticket máximo en gama alta |
| `cant_trx_rubro_{rubro}_gama_alta_pos_ult_{v}` | Transacciones en gama alta |
| `prm_rubro_{rubro}_gama_alta_pos_ult_{v}` | Ticket promedio en gama alta |

**Métricas adicionales de comportamiento:**

| Campo | Descripción |
|---|---|
| `prm_rubro_restaurantes_pos_ult_{v}` | Ticket promedio en restaurantes |
| `prm_rubro_entretenimiento_pos_ult_{v}` | Ticket promedio en entretenimiento |
| `prm_rubro_hoteles_hostales_moteles_pos_ult_{v}` | Ticket promedio en hospedaje |
| `share_DEBITO_pos_ult_{v}` | Participación de débito sobre total POS |
| `cant_conquotas_pos_ult_{v}` | Cantidad de compras en cuotas |
| `ticket_prom_fastfood_pos_ult_{v}` | Ticket promedio en fast food |

---

## 8. Métricas por Comercio Específico — `mto_venta_{comercio}_pos` / `cant_trx_{comercio}_pos`

| Comercio | Descripción |
|---|---|
| `adidas` | Adidas |
| `aerolineas_argentinas` | Aerolíneas Argentinas |
| `air_europa` | Air Europa |
| `amazon_prime_video` | Amazon Prime Video |
| `american_airlines` | American Airlines |
| `aruma` | Aruma (cosméticos) |
| `atsa_airlines` | ATSA Airlines |
| `boticas_24_horas` | Boticas 24 Horas |
| `boticas_felicidad` | Boticas Felicidad |
| `boticas_peru` | Boticas Perú |
| `boticas_y_salud` | Boticas y Salud |
| `burger_king` | Burger King |
| `cabify` | Cabify |
| `casa_ideas` | Casa Ideas |
| `cassinelli` | Cassinelli |
| `chifa_chifa_express` | Chifa Chifa Express |
| `chifa_madam_tusan` | Chifa Madam Tusan |
| `cinemark` | Cinemark |
| `cinestar` | Cinestar |
| `cinnabon` | Cinnabon |
| `corporacion_montalvo` | Corporación Montalvo |
| `crunchyroll` | Crunchyroll |
| `curacao` | Curacao |
| `derma_shop` | Derma Shop |
| `didi_food` | DiDi Food |
| `didi` | DiDi (taxi) |
| `drogueria_montalvo` | Droguería Montalvo |
| `gap` | GAP |
| `gym_mega_force` | Gym Mega Force |
| `hbo_max` | HBO Max |
| `hiraoka` | Hiraoka |
| `indrive` | InDrive |
| `instituto_certus` | Instituto Certus |
| `joinnus` | Joinnus |
| `juan_valdez` | Juan Valdez |
| `juntoz` | Juntoz |
| `kayser` | Kayser |
| `kfc` | KFC |
| `la_casa_del_alfajor` | La Casa del Alfajor |
| `lab_nutrition` | Lab Nutrition |
| `latam_airlines` | LATAM Airlines |
| `marathon` | Marathon Sports |
| `mayorsa` | Mayorsa |
| `mc_donalds` | McDonald's |
| `montalvo_spa` | Montalvo Spa |
| `movie_time` | Movie Time |
| `municipalidades` | Municipalidades |
| `natura_cosmeticos` | Natura Cosméticos |
| `netflix` | Netflix |
| `new_athletic` | New Athletic |
| `nike` | Nike |
| `pedidos_ya` | Pedidos Ya |
| `perfumerias_unidas` | Perfumerías Unidas |
| `pizza_hut` | Pizza Hut |
| `pizzas_dominos` | Domino's Pizza |
| `pizzas_little_caesars` | Little Caesars |
| `pizzas_raul` | Pizzas Raúl |
| `platanitos` | Platanitos |
| `polleria_norkys` | Norkys |
| `polleria_pardos` | Pardo's Chicken |
| `polleria_primos` | Primos Chicken |
| `polleria_rokys` | Rokys |
| `polleria_villa_chicken` | Villa Chicken |
| `premium_fit` | Premium Fit |
| `puma` | Puma |
| `q_churros` | Q Churros |
| `rappi` | Rappi |
| `reebok` | Reebok |
| `revo_sport` | Revo Sport |
| `sat` | SAT (pagos al estado) |
| `shopstar` | Shopstar |
| `sky_airline` | Sky Airline |
| `smart_fit` | Smart Fit |
| `star_peru` | Star Perú |
| `starbucks` | Starbucks |
| `taxi_365` | Taxi 365 |
| `taxi_directo` | Taxi Directo |
| `taxi_satelital` | Taxi Satelital |
| `teatros` | Teatros varios |
| `teleticket` | Teleticket |
| `tiendas_efe` | Tiendas EFE |
| `tiendas_tambo` | Tambo+ |
| `tommy_hilfiger` | Tommy Hilfiger |
| `topitop` | Topitop |
| `triathlon` | Triathlon |
| `uber_eats` | Uber Eats |
| `uber` | Uber |
| `vaope` | Vaope |
| `vega` | Vega |
| `veterinaria` | Veterinarias |
| `viva_airlines` | Viva Airlines |
| `walon` | Walon |
| `xfly_peru` | Xfly Perú |
| `zapatillas_tigre` | Zapatillas Tigre |
| `zara` | Zara |

---

## 9. Flags

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_outlier_intercorp_pos_ult_{v}` | INTEGER | 1 = comportamiento atípico en POS ITC |
| `flag_outlier_pos_gastos_carro_ult_{v}` | INTEGER | 1 = comportamiento atípico en gastos de auto |
| `flag_outlier_pos_grifos_ult_{v}` | INTEGER | 1 = comportamiento atípico en grifos |
| `flag_persona_natural_ult_{v}` | INTEGER | 1 = persona natural (vs empresa) |

---

## 10. Ventanas temporales

| Sufijo | Contenido |
|---|---|
| `ult_15d` | Últimos 15 días |
| `ult_1m` | Último mes (primer día del mes = `process_date`) |
| `ult_3m` | Últimos 3 meses acumulados |
| `ult_6m` | Últimos 6 meses acumulados |
| `ult_12m` | Últimos 12 meses acumulados |

> `ult_1m` es sumable entre particiones. `ult_3m` a `ult_12m` son acumulados — no sumar.

---

## 11. Queries de referencia

```sql
-- Consumo POS total y por canal mayo 2026
SELECT id, mto_venta_pos_ult_1m, cant_trx_pos_ult_1m,
       mto_trx_presencial_pos_ult_1m, mto_trx_virtual_pos_ult_1m,
       cant_rubros_unicos_venta_pos_ult_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment_pos`
WHERE process_date = '2026-05-01'
  AND mto_venta_pos_ult_1m > 0;

-- Clientes gastrónomos de gama alta
SELECT id, mto_venta_rubro_restaurantes_pos_ult_3m,
       mto_venta_rubro_criollo_gama_alta_pos_ult_3m,
       mto_venta_rubro_polleria_gama_alta_pos_ult_3m,
       prm_rubro_restaurantes_pos_ult_3m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment_pos`
WHERE process_date = '2026-05-01'
  AND mto_venta_rubro_restaurantes_pos_ult_3m > 0;

-- Viajeros frecuentes
SELECT id, mto_venta_rubro_agencias_de_viaje_pos_ult_12m,
       mto_venta_rubro_realiza_viajes_pos_ult_12m,
       mto_venta_latam_airlines_pos_ult_12m,
       mto_venta_american_airlines_pos_ult_12m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment_pos`
WHERE process_date = '2026-05-01'
  AND mto_venta_rubro_realiza_viajes_pos_ult_12m > 0;
```

---

## 12. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Clave: `id`** — para cruzar con `ba_itc_attr_retail`: `pos.id = retail.id_intercorp`.
3. **Ventana `ult_15d`** es única en esta tabla — los últimos 15 días del mes.
4. **`ult_1m`** es sumable entre particiones; `ult_3m` a `ult_12m` son acumulados.
5. **NULL = sin actividad** en ese comercio/rubro en la ventana.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment_pos`*
