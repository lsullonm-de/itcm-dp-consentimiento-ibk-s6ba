# Catálogo de Datos — `ba_itc_attr_retail`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`

---

## Descripción

Atributos de **consumo retail agregados por cliente y mes**. Una fila por cliente (`id_intercorp`) con sus métricas de compra para el mes de `process_date` y sus ventanas acumuladas. Cubre SPSA, Promart, Oechsle y Farmacias (InkaFarma + MiFarma).

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY — primer día del mes) |
| Clusterizado por | `id_intercorp` |
| Filas aprox. | ~6.5B |
| Columnas | ~2,431 |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id_intercorp` | STRING | Documento de identidad del cliente. Campo clustered. Clave de join. |
| `process_date` | DATE | **Campo de partición.** Primer día del mes. `'2026-01-01'` = enero 2026 |
| `record_source` | STRING | Origen del registro. Valor fijo: `"Retail"` |
| `load_date` | TIMESTAMP | Fecha y hora de carga del proceso |

---

## 2. Naming convention

```
{emp}_{metrica}_{ventana}                        ← global sin canal
{emp}_{metrica}_{canal}_{ventana}                ← por canal
{emp}_{metrica}_{categoria}_{ventana}            ← por categoría de producto
{emp}_{metrica}_{banner}_{ventana}               ← por banner (solo spsa_)
{emp}_{metrica}_{gama_producto}_{ventana}        ← por gama de producto
{emp}_porc_{medio_pago}_{ventana}                ← % medio de pago
{emp}_rubro_top{N}_{criterio}_{name/value}_{ventana}  ← ranking top-N
mto_trx_{canal}_{ventana}                        ← monto total grupo sin empresa
{emp}_mto_trx_{canal}_{ventana}                  ← monto total por empresa y canal
comportamiento_{dim}_{estadistico}_{tipo_trx}_itc_u{ventana}  ← estadísticos de compra
comportamiento_compra_{dimension}_{ventana}      ← patrones de comportamiento
comportamiento_cliente_{flag}_{ventana}          ← flags de tipo de cliente
```

**Ventanas:** `1m`, `3m`, `6m`, `9m`, `12m`
**Canales:** `presencial`, `digital`
**Empresas:** `spsa_`, `pro_`, `oe_`, `far_`

---

## 3. Empresas y prefijos

| Prefijo | Empresa | `itc_company_id` |
|---|---|---|
| `spsa_` | Supermercados Peruanos (Plaza Vea, Vivanda, Mass, Makro Eco) | `010` |
| `pro_` | Promart | `024` |
| `oe_` | Oechsle | `011` |
| `far_` | Farmacias (InkaFarma + MiFarma consolidadas) | `025`+`048` |

---

## 4. Métricas globales por empresa

| Campo | Tipo | Descripción |
|---|---|---|
| `{emp}_mtoprom_{Nm}` | FLOAT | Monto promedio por transacción en N meses |
| `{emp}_monto_{Nm}` | FLOAT | Monto total acumulado en N meses (`spsa_`, `oe_`, `far_`) |
| `{emp}_frecuencia_{Nm}` | INTEGER | Número total de transacciones en N meses |
| `{emp}_recencia` | INTEGER | Días desde la última transacción (sin sufijo de ventana) |
| `{emp}_redencionoferta_{Nm}` | INTEGER | Ofertas/cupones canjeados en N meses |
| `{emp}_rubrofrec_{Nm}` | STRING | Categoría de producto más frecuentada en N meses |
| `{emp}_rubro_prom_{Nm}` | STRING | Categoría con mayor monto promedio en N meses |
| `{emp}_idestab_frec_{Nm}` | STRING | Código del establecimiento más visitado en N meses |
| `{emp}_descestab_frec_{Nm}` | STRING | Nombre del establecimiento más visitado en N meses |
| `{emp}_seg_canal_{Nm}` | STRING | Canal predominante (`"tienda"` / `"digital"`) — solo `_1m` |

---

## 5. Métricas por canal

| Campo | Tipo | Descripción |
|---|---|---|
| `{emp}_mtoprom_presencial_{Nm}` | FLOAT | Monto promedio en tienda física en N meses |
| `{emp}_numtrx_presencial_{Nm}` | INTEGER | Transacciones en tienda física en N meses |
| `{emp}_mtoprom_digital_{Nm}` | FLOAT | Monto promedio en canal digital en N meses |
| `{emp}_numtrx_digital_{Nm}` | INTEGER | Transacciones en canal digital en N meses |

---

## 6. Monto total por canal (grupo e individual)

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_trx_presencial_{Nm}` | FLOAT | Monto total presencial del cliente en TODAS las empresas en N meses |
| `mto_trx_digital_{Nm}` | FLOAT | Monto total digital del cliente en TODAS las empresas en N meses |
| `{emp}_mto_trx_presencial_{Nm}` | FLOAT | Monto total presencial en esa empresa en N meses |
| `{emp}_mto_trx_digital_{Nm}` | FLOAT | Monto total digital en esa empresa en N meses |

---

## 7. Tipo de caja (spsa_, pro_, oe_ — solo `_1m`)

| Campo | Tipo | Descripción |
|---|---|---|
| `{emp}_caja_rapida_1m` | INTEGER | Transacciones pagadas en caja rápida en el mes |
| `{emp}_caja_normal_1m` | INTEGER | Transacciones pagadas en caja normal en el mes |

---

## 8. Medios de pago — `{emp}_porc_{medio}_{Nm}`

Porcentaje del monto total pagado con cada medio. **Disponible para `spsa_`, `pro_`, `oe_`. No disponible para `far_`.**

| Código | Medio |
|---|---|
| `efectivo` | Efectivo |
| `debito` | Tarjeta de débito (cualquier banco) |
| `credito` | Tarjeta de crédito (cualquier banco) |
| `toh` | Tarjeta OH! (Intercorp) |
| `ibk` | Interbank |
| `sco` | Scotiabank |
| `bbva` | BBVA |
| `csc` | Cencosud |
| `rip` | Ripley |
| `cmr` | CMR Falabella |
| `cen` | Cencosud (codificación alternativa) |

> Los valores suman ~100% entre todos los medios por empresa y ventana. NULL = medio no usado.

---

## 9. Banners SPSA — `spsa_numtrx_{banner}_{Nm}`

| Campo | Descripción |
|---|---|
| `spsa_numtrx_vea_{Nm}` | Transacciones en Plaza Vea en N meses |
| `spsa_numtrx_vivanda_{Nm}` | Transacciones en Vivanda en N meses |
| `spsa_numtrx_mass_{Nm}` | Transacciones en Mass en N meses |
| `spsa_numtrx_makroeco_{Nm}` | Transacciones en Makro Eco en N meses |
| `spsa_businessunit_frec_{Nm}` | Banner/sección más frecuentada (ej: `"PLAZA VEA"`) |

---

## 10. Rankings top-3 por empresa — `far_` y `spsa_`

| Campo | Tipo | Descripción |
|---|---|---|
| `{emp}_rubro_top{1/2/3}_frec_name_{Nm}` | STRING | Nombre categoría #N por frecuencia |
| `{emp}_rubro_top{1/2/3}_frec_{Nm}` | INTEGER | Número de transacciones de la categoría #N |
| `{emp}_rubro_top{1/2/3}_monto_name_{Nm}` | STRING | Nombre categoría #N por monto gastado |
| `{emp}_rubro_top{1/2/3}_monto_{Nm}` | FLOAT | Monto de la categoría #N |

> También existe `oe_rubro_top{1/2/3}_*` para Oechsle.

---

## 11. Métricas por categoría de producto

### SPSA — categorías disponibles (con `mtoprom`, `mtomax`, `mtomin`, `mto`, `numtrx`, `numdias`)

`bazar`, `bebidas`, `bebidas_alcoholicas`, `carnes`, `comestibles`, `comestibles_especiales`, `comidas_preparadas`, `cuidado_personal_limpieza`, `electro`, `fiambres_quesos`, `frutas_verduras`, `hogar`, `lacteos_congelados`, `miscelaneos`, `panaderia_pasteleria`, `pescados_mariscos`, `textil`, `otros`

| Campo patrón | Descripción |
|---|---|
| `spsa_mtoprom_{cat}_{Nm}` | Monto promedio en esa categoría en N meses |
| `spsa_mtomax_{cat}_{Nm}` | Monto máximo de una transacción en esa categoría en N meses |
| `spsa_mtomin_{cat}_{Nm}` | Monto mínimo de una transacción en esa categoría en N meses |
| `spsa_mto_{cat}_{Nm}` | Monto total acumulado en esa categoría en N meses |
| `spsa_numtrx_{cat}_{Nm}` | Número de transacciones en esa categoría en N meses |
| `spsa_numdias_{cat}_{Nm}` | Número de días distintos con compra en esa categoría en N meses |

### Promart — categorías

`acabados`, `ferreteria`, `hogar_deco`, `jardin_temp`, `obra_gruesa`, `otros`

Métricas disponibles: `mtoprom`, `mtomax` por categoría.

### Oechsle — categorías

`mujer`, `hombre`, `infantil`, `belleza`, `deportes`, `calzado`, `electrohogar`, `decohogar`, `marcas_boutique`, `autoliquidables`, `otros`

Métricas disponibles: `mtoprom`, `mtomax`, `mtomin`, `mto` por categoría.

### Farmacias — categorías

`marca`, `generico`, `wellnes`, `bienestar`, `belleza`, `cuidado_personal`, `cuidado_infantil`, `dermacosmetica`, `bebes_ninos`, `bazar`, `mimarket`, `nutricion_adultos`, `nutricion_deportiva_control`, `dispositivo_medico`, `adulto`, `medicamento`, `medicamento_popular_marca`, `medicamento_popular_generico`, `antibiotico`, `formula_estandar`, `forma_farmaceutica`, `producto_fmagistral`, `liquidos`, `insumo_material_fm`, `insumos_excipientes`, `otros`, `otros_nutricion`, `sin_clasificacion_historica`, `muestra_biologica`, `heces`, `orina`, `sangre`, `secrecion`, `administrativo`

| Campo patrón | Descripción |
|---|---|
| `far_mtoprom_{cat}_{Nm}` | Monto promedio en esa categoría en N meses |
| `far_mtomax_{cat}_{Nm}` | Monto máximo en esa categoría en N meses |
| `far_mtomin_{cat}_{Nm}` | Monto mínimo en esa categoría en N meses |
| `far_mto_{cat}_{Nm}` | Monto total acumulado en esa categoría en N meses |
| `far_numtrx_{cat}_{Nm}` | Número de transacciones en esa categoría (`medicamento`, `antibiotico`, `formula_lactea`, `panales`) |

---

## 12. Métricas por gama de producto

Aplica a `spsa_` y `oe_` para las categorías: `ropa`, `electro`, `jugueteria`, `alimentos` (solo spsa_).
Gamas: `alta`, `media`, `baja`.

| Campo patrón | Descripción |
|---|---|
| `{emp}_mtomax_{producto}_gama_{gama}_{Nm}` | Monto máximo de una transacción en esa gama en N meses |
| `{emp}_mtomin_{producto}_gama_{gama}_{Nm}` | Monto mínimo de una transacción en esa gama en N meses |
| `{emp}_mto_{producto}_gama_{gama}_{Nm}` | Monto total en esa gama en N meses |
| `{emp}_mtoprom_{producto}_gama_{gama}_{Nm}` | Monto promedio en esa gama en N meses |

**Ejemplos:**
```
spsa_mto_electro_gama_alta_1m     → monto total en electro gama alta SPSA en enero
oe_mtoprom_ropa_gama_media_6m     → ticket promedio ropa gama media OE en 6 meses
spsa_mto_alimentos_gama_baja_3m   → monto total alimentos gama baja SPSA en 3 meses
```

---

## 13. Métricas de alimentos saludable / no saludable (solo `spsa_`)

| Campo | Tipo | Descripción |
|---|---|---|
| `spsa_mto_alimentos_{Nm}` | FLOAT | Monto total en alimentos (todas las gamas) en N meses |
| `spsa_mto_alimento_saludable_{Nm}` | FLOAT | Monto total en alimentos saludables en N meses |
| `spsa_mto_alimento_no_saludable_{Nm}` | FLOAT | Monto total en alimentos no saludables en N meses |
| `spsa_mtomax_alimentos_{Nm}` | FLOAT | Monto máximo en alimentos en N meses |
| `spsa_mtomin_alimentos_{Nm}` | FLOAT | Monto mínimo en alimentos en N meses |
| `spsa_mtoprom_alimentos_{Nm}` | FLOAT | Monto promedio en alimentos en N meses |
| `spsa_mtoprom_alimento_saludable_{Nm}` | FLOAT | Monto promedio en alimentos saludables en N meses |
| `spsa_mtoprom_alimento_no_saludable_{Nm}` | FLOAT | Monto promedio en alimentos no saludables en N meses |

---

## 14. Métricas de bebé / infante

| Campo | Tipo | Descripción |
|---|---|---|
| `spsa_numtrx_formula_lactea_{Nm}` | INTEGER | Transacciones de fórmula láctea en SPSA en N meses |
| `spsa_numtrx_panales_{Nm}` | INTEGER | Transacciones de pañales en SPSA en N meses |
| `far_numtrx_formula_lactea_{Nm}` | INTEGER | Transacciones de fórmula láctea en farmacias en N meses |
| `far_numtrx_panales_{Nm}` | INTEGER | Transacciones de pañales en farmacias en N meses |
| `flag_compra_formula_bebe_{Nm}_consecutivo` | INTEGER | Flag: compró fórmula de bebé en meses consecutivos |
| `flag_compra_panal_bebe_{Nm}_consecutivo` | INTEGER | Flag: compró pañal en meses consecutivos |

---

## 15. Métricas específicas Oechsle

| Campo | Tipo | Descripción |
|---|---|---|
| `oe_mto_implemento_deportivo_{Nm}` | FLOAT | Monto total en implementos deportivos en N meses |
| `oe_mtomax_implemento_deportivo_{Nm}` | FLOAT | Monto máximo en implementos deportivos en N meses |
| `oe_mtomin_implemento_deportivo_{Nm}` | FLOAT | Monto mínimo en implementos deportivos en N meses |
| `oe_mtoprom_implemento_deportivo_{Nm}` | FLOAT | Monto promedio en implementos deportivos en N meses |
| `oe_numtrx_implemento_deportivo_{Nm}` | INTEGER | Transacciones en implementos deportivos en N meses |
| `oe_mto_ropa_{Nm}` | FLOAT | Monto total en ropa en N meses |
| `oe_mto_ropa_nino_{Nm}` | FLOAT | Monto total en ropa de niño en N meses |

---

## 16. Comportamiento de tarjeta y efectivo

### `comportamiento_tarjeta_{estadistico}_{tipo_trx}_itc_u{Nm}`

Estadísticos del comportamiento de pago con tarjeta por tipo de transacción.

**Tipos de transacción:**
| Código | Descripción |
|---|---|
| `trxtdefe` | Transacciones con tarjeta de débito en establecimientos físicos |
| `trxtd` | Transacciones con tarjeta de débito (total) |
| `trxtc` | Transacciones con tarjeta de crédito |

**Estadísticos disponibles:**
| Código | Descripción |
|---|---|
| `prm` | Monto promedio por transacción |
| `max` | Monto máximo de una transacción |
| `min` | Monto mínimo de una transacción |
| `frec` | Número de transacciones |
| `prom_cant_prod` | Promedio de productos por transacción |
| `max_cant_prod` | Máximo de productos en una transacción |
| `min_cant_prod` | Mínimo de productos en una transacción |

**Ejemplos:**
```
comportamiento_tarjeta_prm_trxtdefe_itc_u1m   → ticket promedio con débito físico en 1 mes
comportamiento_tarjeta_frec_trxtd_itc_u6m     → número de transacciones con débito en 6 meses
comportamiento_tarjeta_max_cant_prod_trxtc_itc_u3m → máx. productos por ticket con crédito en 3 meses
```

### `comportamiento_efectivo_{estadistico}_trxefe_itc_u{Nm}`

Mismo patrón de estadísticos pero para transacciones en efectivo (`trxefe`).

---

## 17. Comportamiento de transacciones totales

### `comportamiento_trx_{estadistico}_{tipo_trx}_itc_u{Nm}`

Estadísticos globales por tipo de canal de compra.

**Tipos:**
| Código | Descripción |
|---|---|
| `trxtotal` | Todas las transacciones |
| `trxpres` | Transacciones presenciales (físico) |
| `trxonl` | Transacciones online (digital) |
| `trxprom` | Transacciones en canal de oferta/promoción |

**Estadísticos:** `prm`, `max`, `min`, `frec`, `prom_cant_prod`, `max_cant_prod`, `min_cant_prod`

**Ejemplos:**
```
comportamiento_trx_prm_trxtotal_itc_u1m    → ticket promedio total en 1 mes
comportamiento_trx_frec_trxpres_itc_u6m   → número de transacciones presenciales en 6 meses
comportamiento_trx_frec_trxonl_itc_u12m   → número de transacciones online en 12 meses
```

---

## 18. Flags de tipo de cliente

| Campo | Tipo | Descripción |
|---|---|---|
| `comportamiento_cliente_flg_cliente_habitual_u{Nm}` | INTEGER | 1 = cliente habitual (compra frecuente regular) en N meses |
| `comportamiento_cliente_flg_cliente_oneshot_u{Nm}` | INTEGER | 1 = cliente oneshot (compró solo una vez) en N meses |
| `comportamiento_cliente_flg_cliente_diario_u{Nm}` | INTEGER | 1 = cliente con patrón de compra diaria en N meses |

Ventanas disponibles: `u1m`, `u3m`, `u6m`, `u9m`, `u12m`.

---

## 19. Patrones de comportamiento de compra

### Parte del día más frecuente

| Campo | Tipo | Valores | Descripción |
|---|---|---|---|
| `comportamiento_compra_parte_dia_mas_frec` | STRING | `mañana`, `tarde`, `noche` | Parte del día con más transacciones (histórico total) |
| `comportamiento_compra_parte_dia_mas_frec_{Nm}` | STRING | idem | Parte del día con más transacciones en N meses |
| `comportamiento_compra_parte_dia_mas_mto` | STRING | idem | Parte del día con mayor monto (histórico) |
| `comportamiento_compra_parte_dia_mas_mto_{Nm}` | STRING | idem | Parte del día con mayor monto en N meses |

### Día de la semana más frecuente

| Campo | Tipo | Valores | Descripción |
|---|---|---|---|
| `comportamiento_compra_nombre_dia_mas_frec` | STRING | `Lunes`...`Domingo` | Día con más transacciones (histórico) |
| `comportamiento_compra_nombre_dia_mas_frec_{Nm}` | STRING | idem | Día con más transacciones en N meses |
| `comportamiento_compra_tipo_dia_mas_frec` | STRING | `weekday`, `weekend` | Tipo de día más frecuente (histórico) |
| `comportamiento_compra_tipo_dia_mas_frec_{Nm}` | STRING | idem | Tipo de día más frecuente en N meses |
| `comportamiento_compra_nombre_dia_mas_mto` | STRING | idem | Día con mayor monto (histórico) |
| `comportamiento_compra_nombre_dia_mas_mto_{Nm}` | STRING | idem | Día con mayor monto en N meses |
| `comportamiento_compra_tipo_dia_mas_mto` | STRING | idem | Tipo de día con mayor monto en N meses |

### Tipo de distrito

| Campo | Tipo | Valores | Descripción |
|---|---|---|---|
| `comportamiento_compra_tipo_distrito_mas_frec` | STRING | `lima`, `lima_prov`, `callao`, `provincia` | Tipo de zona donde compra más frecuentemente (histórico) |
| `comportamiento_compra_tipo_distrito_mas_frec_{Nm}` | STRING | idem | Tipo de zona más frecuente en N meses |
| `comportamiento_compra_tipo_distrito_mas_mto` | STRING | idem | Tipo de zona con mayor monto (histórico) |
| `comportamiento_compra_tipo_distrito_mas_mto_{Nm}` | STRING | idem | Tipo de zona con mayor monto en N meses |

### Entidad bancaria más frecuente

| Campo | Tipo | Descripción |
|---|---|---|
| `comportamiento_compra_entidad_banco_mas_frec` | STRING | Banco con más transacciones (histórico). Ej: `"nulo"`, `"scotia"`, `"bbva"` |
| `comportamiento_compra_entidad_banco_mas_frec_{Nm}` | STRING | Banco con más transacciones en N meses |
| `comportamiento_compra_entidad_banco_mas_mto` | STRING | Banco con mayor monto gastado (histórico) |
| `comportamiento_compra_entidad_banco_mas_mto_{Nm}` | STRING | Banco con mayor monto en N meses |

### Patrón de compra combinado (día + parte del día)

| Campo | Tipo | Descripción |
|---|---|---|
| `comportamiento_compra_patron_mas_frec` | STRING | Patrón más frecuente histórico. Ej: `"Martes-noche"` |
| `comportamiento_compra_patron_mas_frec_{Nm}` | STRING | Patrón más frecuente en N meses |
| `comportamiento_compra_valor_patron_mas_frec` | INTEGER | Número de veces que ocurrió ese patrón (histórico) |
| `comportamiento_compra_valor_patron_mas_frec_{Nm}` | INTEGER | Número de veces en N meses |

---

## 20. Métricas con naming alternativo `ult_`

Algunos campos usan `ult_{N}m` en lugar de `_{Nm}`. Aplica a rubros específicos.

| Campo | Tipo | Descripción |
|---|---|---|
| `prm_spsa_rubro_{rubro}_ult_{Nm}` | FLOAT | Monto promedio en ese rubro SPSA en últimos N meses |
| `trx_spsa_rubro_{rubro}_ult_{Nm}` | INTEGER | Número de transacciones en ese rubro SPSA en últimos N meses |
| `prm_fa_rubro_{rubro}_ult_{Nm}` | FLOAT | Monto promedio en ese rubro farmacias en últimos N meses |
| `trx_fa_rubro_{rubro}_ult_{Nm}` | INTEGER | Transacciones en ese rubro farmacias en últimos N meses |

**Rubros documentados:** `frescos`, `bebidas_alcoholicas`, `alimentos_saludables`, `alimentos_no_saludables`, `carnes_pescados`, `marca` (farmacias)

---

## 21. Otras métricas globales

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_business_unit_ult_12m` | INTEGER | Número de unidades de negocio distintas visitadas en los últimos 12 meses |
| `far_ticketprom_{Nm}` | FLOAT | Ticket promedio en farmacias en N meses |
| `far_mto_medicamento_popular_de_marca_{Nm}` | FLOAT | Monto total medicamento popular de marca en N meses |

---

## 22. Flags de outlier y segmentación

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_outlier_plazavea` | INTEGER | 1 = cliente con comportamiento atípico en Plaza Vea |
| `flag_outlier_vivanda` | INTEGER | 1 = cliente con comportamiento atípico en Vivanda |
| `flag_outlier_mass` | INTEGER | 1 = cliente con comportamiento atípico en Mass |
| `flag_outlier_makro` | INTEGER | 1 = cliente con comportamiento atípico en Makro |
| `flag_outlier_supermercados_peruanos` | INTEGER | 1 = outlier SPSA consolidado |
| `flag_outlier_promart` | INTEGER | 1 = cliente con comportamiento atípico en Promart |
| `flag_outlier_oechsle` | INTEGER | 1 = cliente con comportamiento atípico en Oechsle |
| `flag_outlier_inkafarma` | INTEGER | 1 = cliente con comportamiento atípico en InkaFarma |
| `flag_outlier_mifarma` | INTEGER | 1 = cliente con comportamiento atípico en MiFarma |
| `flag_outlier_farmacias_peruanas` | INTEGER | 1 = outlier farmacias consolidado |
| `flag_outlier_intercorp_retail` | INTEGER | 1 = outlier Intercorp Retail consolidado |
| `flag_outlier_jokr` | INTEGER | 1 = cliente con comportamiento atípico en Jokr |
| `flag_persona_natural` | INTEGER | 1 = persona natural (vs empresa). Puede ser NULL |

---

## 23. Ventanas temporales

| Sufijo | Contenido | Sumable entre particiones |
|---|---|---|
| `_1m` | Solo el mes de `process_date` | ✅ Sí |
| `_3m` | Acumulado 3 meses hasta `process_date` | ❌ No |
| `_6m` | Acumulado 6 meses hasta `process_date` | ❌ No |
| `_9m` | Acumulado 9 meses hasta `process_date` | ❌ No |
| `_12m` | Acumulado 12 meses hasta `process_date` | ❌ No |

---

## 24. Campos correctos para monto total de ventas — REGLA CRÍTICA

**Los siguientes campos NO existen en esta tabla:**

| Campo inventado (NO USAR) | Campo correcto |
|---|---|
| `spsa_mto_retail_1m` | `spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m` |
| `pro_mto_retail_1m` | `pro_mto_trx_presencial_1m + pro_mto_trx_digital_1m` |
| `oe_mto_retail_1m` | `oe_mto_trx_presencial_1m + oe_mto_trx_digital_1m` |
| `far_mto_retail_1m` | `far_mto_trx_presencial_1m + far_mto_trx_digital_1m` |
| `spsa_numtrx_retail_1m` | `spsa_frecuencia_1m` (total) o `spsa_numtrx_presencial_1m + spsa_numtrx_digital_1m` |
| `pro_numtrx_retail_1m` | `pro_frecuencia_1m` o `pro_numtrx_presencial_1m + pro_numtrx_digital_1m` |
| `oe_numtrx_retail_1m` | `oe_frecuencia_1m` o `oe_numtrx_presencial_1m + oe_numtrx_digital_1m` |
| `far_numtrx_retail_1m` | `far_frecuencia_1m` o `far_numtrx_presencial_1m + far_numtrx_digital_1m` |

**El monto total de ventas de una empresa = suma de dos canales:**
```sql
-- ✅ CORRECTO
SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m) AS monto_total_spsa
SUM(pro_mto_trx_presencial_1m  + pro_mto_trx_digital_1m)  AS monto_total_promart
SUM(oe_mto_trx_presencial_1m   + oe_mto_trx_digital_1m)   AS monto_total_oechsle
SUM(far_mto_trx_presencial_1m  + far_mto_trx_digital_1m)  AS monto_total_farmacias

-- ❌ INCORRECTO — estos campos no existen en la tabla
SUM(spsa_mto_retail_1m)    -- no existe
SUM(pro_mto_retail_1m)     -- no existe
SUM(spsa_numtrx_retail_1m) -- no existe
```

---

## 24b. Principio clave — tabla cliente que da totales de empresa

**`ba_itc_attr_retail` está a nivel de cliente (`id_intercorp`)**, pero al sumar los campos `_1m`
de todos los clientes en una misma partición (`process_date`) se obtienen los totales mensuales
de la empresa. Este es el patrón canónico para consultas de negocio.

```
SUM({empresa}_mto_trx_presencial_1m + {empresa}_mto_trx_digital_1m)
  → monto total de ventas de esa empresa en el mes
```

**Campos para monto total de ventas por empresa:**
- `{empresa}_mto_trx_presencial_1m` — monto acumulado en transacciones presenciales del mes
- `{empresa}_mto_trx_digital_1m` — monto acumulado en transacciones digitales del mes
- La suma de ambos = monto total de ventas (presencial + digital)

**Campo para ticket promedio por cliente:**
- `AVG({empresa}_mtoprom_1m)` — promedio del ticket promedio de cada cliente activo en el mes

> **No confundir:** `SUM(spsa_mtoprom_1m)` no tiene sentido (suma de promedios individuales).
> Para ticket promedio real de la empresa: `SAFE_DIVIDE(SUM(spsa_mto_trx_presencial_1m + spsa_mto_trx_digital_1m), SUM(spsa_frecuencia_1m))`

---

## 25. Patrones de Query

```sql
-- Perfil de pago SPSA enero 2026 (medios de pago + comportamiento)
SELECT id_intercorp,
       spsa_frecuencia_1m, spsa_monto_1m,
       spsa_porc_efectivo_1m, spsa_porc_debito_1m, spsa_porc_credito_1m,
       spsa_porc_ibk_1m, spsa_porc_bbva_1m, spsa_porc_sco_1m,
       comportamiento_compra_parte_dia_mas_frec_1m,
       comportamiento_compra_nombre_dia_mas_frec_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND spsa_frecuencia_1m > 0;

-- Comportamiento de compra con tarjeta grupo enero 2026
SELECT id_intercorp,
       comportamiento_tarjeta_frec_trxtdefe_itc_u1m  AS trx_debito_fisico,
       comportamiento_tarjeta_prm_trxtdefe_itc_u1m   AS ticket_prom_debito,
       comportamiento_tarjeta_frec_trxtc_itc_u1m     AS trx_credito,
       comportamiento_efectivo_frec_trxefe_itc_u1m   AS trx_efectivo
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01';

-- Clientes con bebé activo (fórmula + pañales en farmacias)
SELECT id_intercorp,
       far_numtrx_formula_lactea_3m, far_numtrx_panales_3m,
       flag_compra_formula_bebe_3m_consecutivo,
       flag_compra_panal_bebe_3m_consecutivo
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND (far_numtrx_formula_lactea_3m > 0 OR far_numtrx_panales_3m > 0);

-- Clientes SPSA alimentos saludables vs no saludables enero 2026
SELECT id_intercorp,
       spsa_mto_alimento_saludable_1m,
       spsa_mto_alimento_no_saludable_1m,
       SAFE_DIVIDE(spsa_mto_alimento_saludable_1m,
         spsa_mto_alimentos_1m) * 100 AS pct_saludable
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND spsa_mto_alimentos_1m > 0;

-- Mix de gama electro OE enero 2026
SELECT id_intercorp,
       oe_mto_electro_gama_alta_1m,
       oe_mto_electro_gama_media_1m,
       oe_mto_electro_gama_baja_1m,
       oe_frecuencia_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND oe_frecuencia_1m > 0;

-- Patrón de compra: clientes nocturnos de fin de semana SPSA
SELECT id_intercorp, spsa_monto_1m, spsa_frecuencia_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`
WHERE process_date = '2026-01-01'
  AND spsa_frecuencia_1m > 0
  AND comportamiento_compra_parte_dia_mas_frec_1m = 'noche'
  AND comportamiento_compra_tipo_dia_mas_frec_1m = 'weekend';
```

---

## 25. Reglas de negocio

1. **Filtrar siempre por `process_date`** — sin filtro se escanean ~2TB.
2. **`_1m` = solo ese mes, sumable.** `_3m`..`_12m` son acumulados, no sumar entre particiones.
3. **`far_` consolida InkaFarma + MiFarma.** No existen `inkf_` ni `mfarm_`.
4. **`far_` no tiene `porc_` de medios de pago.** Solo `spsa_`, `pro_`, `oe_`.
5. **`recencia` sin sufijo de ventana** — días desde última compra.
6. **NULL vs 0:** en campos de categoría y gama, NULL = dato no disponible; 0 = sin compra.
7. **`flag_outlier_*`** marca clientes con comportamiento estadísticamente atípico — excluir en análisis de perfil promedio.
8. **`comportamiento_*`** sin sufijo `_{Nm}` = histórico completo disponible.

---

*Actualizado: 2026-06-06 | Fuente: muestra real `ba_atr_retail_10registros.txt` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail`*
