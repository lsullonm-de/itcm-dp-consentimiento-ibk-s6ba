# Guia de Nomenclatura y Buenas Practicas - ba_itc_attr_retail

> Documentacion extraida de los stored procedures `sp_load_ba_itc_attr_retail` y `sp_load_tmp_ba_itc_attr_retail_{1-9} `. Los cuales contienen las lógicas para la carga de la tabla ba_itc_attr_retail que es una de las tablas principales.
> Proyecto BigQuery: `intercorp-data-storage-pv`

---

## 1. Estructura de Nombres de Stored Procedures

### Patron

```
sp_load_[tmp_]<dominio>_<organizacion>_<tipo>_<vertical>[_<secuencial>]
```

### Componentes

| Componente | Valor | Significado |
|---|---|---|
| `sp_` | Prefijo obligatorio | Stored Procedure |
| `load_` | Accion | Carga de datos |
| `tmp_` | Opcional | Indica que genera tablas temporales/intermedias |
| `ba_` | Dominio | Business Analytics |
| `itc_` | Organizacion | Intercorp |
| `attr_` | Tipo de dato | Atributos |
| `retail_` | Vertical de negocio | Retail |
| `_{N}` | Sufijo numerico | Particion secuencial de logica (1-9) |

### Ejemplos

| Stored Procedure | Proposito |
|---|---|
| `sp_load_ba_itc_attr_retail` | SP final que consolida e inserta en tabla definitiva |
| `sp_load_tmp_ba_itc_attr_retail_1` | SP intermedio #1 - Base transaccional limpia |
| `sp_load_tmp_ba_itc_attr_retail_2` | SP intermedio #2 - Variables por ventana temporal |
| `sp_load_tmp_ba_itc_attr_retail_3` | SP intermedio #3 - Tabla v1 consolidada |
| `sp_load_tmp_ba_itc_attr_retail_4` | SP intermedio #4 - Segmento tipo caja y montos |
| `sp_load_tmp_ba_itc_attr_retail_5` | SP intermedio #5 - Rankings de rubro |
| `sp_load_tmp_ba_itc_attr_retail_6` | SP intermedio #6 - Atributos IBK detalle |
| `sp_load_tmp_ba_itc_attr_retail_7` | SP intermedio #7 - Clasificacion por gamas |
| `sp_load_tmp_ba_itc_attr_retail_8` | SP intermedio #8 - Flags de producto |
| `sp_load_tmp_ba_itc_attr_retail_9` | SP intermedio #9 - Promedios por rubro/ticket |

### Configuracion global

Todos los SPs usan `OPTIONS(strict_mode=false)`.

---

## 2. Estructura de Nombres de Tablas

### 2.1 Prefijos de tablas

| Prefijo | Tipo | Significado | Ejemplos |
|---|---|---|---|
| `ba_` | Salida final | Business Analytics (tabla definitiva) | `ba_itc_attr_retail`, `ba_itc_attr_retail_v1`, `ba_itc_attr_retail_v2` |
| `tmp_` | Intermedia | Tabla temporal de calculo | `tmp_base_trx_cliente_retail`, `tmp_variables_1m` |
| `tmp_variables_` | Intermedia | Temporal de variables calculadas | `tmp_variables_ultimacompra`, `tmp_variables_3m` |
| `tmp_varibk_` | Intermedia | Temporal de variables Interbank | `tmp_varibk_farmas_x_rubro_riesgos` |
| `tmp_trx_retail_` | Intermedia | Temporal transaccional retail | `tmp_trx_retail_gamas_ibk`, `tmp_trx_retail_flags_ibk` |
| `prd_` | Productiva | Tabla productiva/procesada | `prd_attr_ba_retail_variables1`, `prd_attr_ba_retail_trx_ibk_frecuencia` |
| `t_` | Fuente | Tabla transaccional (hechos) | `t_retail_transaction`, `t_payment` |
| `m_` | Fuente | Tabla maestra (dimension) | `m_product`, `m_place` |
| `c_` | Fuente | Tabla catalogo/clasificacion | `c_bin_card`, `c_clasificacion_marcas_retail_ibk`, `c_flags_retail_ibk` |
| `tee_` | Fuente | Tabla ETL de extraccion | `tee_trn_retail_hpsa`, `tee_trn_retail_spsa`, `tee_trn_retail_tpsa` |
| `iden_` | Fuente | Tabla de identidad | `iden_itc_party` |
| `aux_` | Auxiliar | Tabla auxiliar de soporte | `aux_tarjetas_fape`, `aux_party_type_clasification` |

### 2.2 Sufijos de tablas

| Sufijo | Significado | Ejemplo |
|---|---|---|
| `_v1`, `_v2`, `_v3` | Versionado de tablas | `ba_itc_attr_retail_v1` |
| `_Nm` (1m, 3m, 6m, 9m, 12m) | Ventana temporal | `tmp_trx_retail_gamas_ibk_6m` |
| `_final` | Resultado final de un bloque | `retail_hpsa_final` |
| `_outliers` | Tabla de outliers | `tmp_ba_itc_attr_retail_outliers` |
| `_variables1`, `_variables2` | Segmentacion por grupo de variables | `prd_attr_ba_retail_variables1` |
| `_cliente` | Granularidad por cliente | `envio2_hpsa_final_retail_cliente` |

### 2.3 Patron de referencia completa

```
`{proyecto}.{dataset}.{tabla}`
```

En SQL dinamico:
```sql
`'''||v_proyecto_destino||'''.'''||v_master_stage||'''.nombre_tabla`
```

---

## 3. Estructura de Nombres de Datasets (Schemas)

### Patron: `<capa>_<dominio>`

| Capa | Patron | Datasets | Proposito |
|---|---|---|---|
| `master_` | Capa master / DWH | `master_stage`, `master_product`, `master_party`, `master_transaction`, `master_placement` | Datos maestros y staging |
| `bi_` | Capa Business Intelligence | `bi_attr`, `bi_vuc_insight` | Datos de BI y atributos |
| `sa_` | Staging Area | `sa_matillion` | Datos de ETL (Matillion) |

---

## 4. Convencion de Parametros y Variables

### 4.1 Parametros del Stored Procedure

| Prefijo | Uso | Ejemplos |
|---|---|---|
| `v_proyecto*` | Proyectos GCP | `v_proyecto`, `v_proyecto_foh`, `v_proyecto_destino`, `v_proyecto_publico` |
| `v_master_*` | Datasets maestros | `v_master_stage`, `v_master_product`, `v_master_party` |
| `v_table_*` | Nombres de tablas | `v_table_m_product`, `v_table_t_payment`, `v_table_c_bin_card` |
| `v_bi_*` | Datasets de BI | `v_bi_attr` |
| `v_sa_*` | Datasets de staging area | `v_sa_matillion` |
| `var_*` | Variables alternativas | `var_project_storage_sources`, `var_retail_transaction_dataset` |
| (sin prefijo) | Parametros de entrada principal | `start_date` |

#### Sub-patron de `v_table_*`

| Sub-prefijo | Tipo de tabla | Ejemplo |
|---|---|---|
| `v_table_m_*` | Tabla master/dimension | `v_table_m_product`, `v_table_m_place` |
| `v_table_t_*` | Tabla transaccional | `v_table_t_retail_transaction`, `v_table_t_payment` |
| `v_table_c_*` | Tabla catalogo/clasificacion | `v_table_c_bin_card`, `v_table_c_clasificacion_marcas_retail_ibk` |
| `v_table_tee_*` | Tabla ETL/extraccion | `v_table_tee_trn_retail_hpsa` |
| `v_table_iden_*` | Tabla de identidad | `v_table_iden_itc_party` |

### 4.2 Variables locales (DECLARE)

| Prefijo | Tipo de dato | Uso | Ejemplo |
|---|---|---|---|
| `v_input_*` | STRING | Ruta completa a tabla fuente (proyecto.dataset.tabla) | `v_input_t_retail_transaction` |
| `v_sql` | STRING | SQL dinamico para EXECUTE IMMEDIATE | `v_sql` |
| `v_start_date` | DATE | Fecha de inicio calculada | `v_start_date` |
| `v_end_date` | DATE | Fecha de fin calculada | `v_end_date` |
| `v_interval_date_{N}M_g` | DATE | Intervalo de N meses como DATE | `v_interval_date_6M_g` |
| `v_interval_date_{N}M` | INT64 | Intervalo de N meses como YYYYMMDD numerico | `v_interval_date_6M` |
| `v_tmp_*` | STRING | Referencia a tabla temporal | `v_tmp_ba_itc_attr_retail_outliers` |

#### Convencion de sufijo `_g`

- **Con `_g`**: Variable de tipo `DATE` (fecha calendario)
- **Sin `_g`**: Variable de tipo `INT64` (formato numerico `YYYYMMDD`)

```sql
-- Ejemplo:
declare v_interval_date_6M_g date;   -- DATE: 2024-07-01
declare v_interval_date_6M INT64;     -- INT64: 20240701
```

---

## 5. Convencion de Nombres de Columnas

### 5.1 Formula general

```
[prefijo_empresa_][metrica_][dimension_producto_][gama_nivel_][ventana_temporal]
```

### 5.2 Prefijos de empresa (Business Unit)

| Prefijo | itc_company_id | Empresa | Marcas incluidas |
|---|---|---|---|
| `spsa_` | `010` | Supermercados Peruanos S.A. | Plaza Vea, Vivanda, Mass, Makro |
| `pro_` / `promart_` | `024` | Promart | Promart |
| `oe_` | `011` | Oechsle / Tiendas Peruanas | Oechsle |
| `far_` / `farma_` / `farmas_` | `025`, `048` | Farmacias Peruanas | InkaFarma, MiFarma |
| (sin prefijo) | Todos | Intercorp Retail consolidado | Todas las empresas |

> **Nota**: `promart_` se usa en tablas intermedias y `pro_` en la tabla final de salida.
> `farmas_` se usa en tablas intermedias y `far_`/`farma_` en la tabla final.

### 5.3 Prefijos de metrica

| Prefijo | Significado | Funcion SQL | Tipo de dato |
|---|---|---|---|
| `mtoprom_` / `montoprom_` | Monto promedio | `SUM()/N` o `SAFE_DIVIDE()` | NUMERIC |
| `mtomax_` / `montomax_` | Monto maximo | `MAX()` | NUMERIC |
| `mtomin_` / `montomin_` | Monto minimo | `MIN()` | NUMERIC |
| `mto_` / `monto_` / `montototal_` | Monto total/acumulado | `SUM()` | NUMERIC |
| `numtrx_` / `numtrxtotal_` | Numero de transacciones | `COUNT(DISTINCT)` | INTEGER |
| `numdias_` | Numero de dias distintos | `COUNT(DISTINCT date)` | NUMERIC |
| `frecuencia_` | Frecuencia de compra | Calculada | NUMERIC |
| `recencia` | Recencia (dias desde ultima compra) | `DATE_DIFF()` | NUMERIC |
| `ticketprom_` | Ticket promedio | `SAFE_DIVIDE()` | NUMERIC |
| `porc_` | Porcentaje | `SAFE_DIVIDE()*100` | NUMERIC |
| `redencionoferta_` | Redencion de ofertas/descuentos | `COUNT()` | NUMERIC |
| `rubrofrec_` | Rubro mas frecuente | Ranking | STRING |
| `rubro_prom_` | Rubro promedio/principal | Ranking | STRING |
| `idestab_frec_` | ID establecimiento frecuente | Ranking | STRING |
| `descestab_frec_` | Descripcion establecimiento frecuente | Ranking | STRING |
| `businessunit_frec_` | Business unit mas frecuente | Ranking | STRING |
| `seg_canal_` | Segmento de canal | Clasificacion | STRING |
| `caja_rapida_` / `caja_normal_` | Tipo de caja | Conteo | INTEGER |
| `cant_total_trx_` | Cantidad total de transacciones | `SUM()` | INTEGER |
| `mto_total_` | Monto total por rubro | `SUM()` | NUMERIC |
| `trx_d_` | Transacciones distinct | `COUNT(DISTINCT)` | INTEGER |
| `prm_` | Promedio (en patron IBK) | `AVG()` o division | FLOAT64 |
| `max_` | Maximo (en patron IBK) | `MAX()` | FLOAT64 |
| `min_` | Minimo (en patron IBK) | `MIN()` | FLOAT64 |
| `frec_` | Frecuencia (en patron IBK) | `COUNT()` | INTEGER |

### 5.4 Sufijos de ventana temporal

| Sufijo | Significado |
|---|---|
| `_1m` | Ultimo 1 mes |
| `_3m` | Ultimos 3 meses |
| `_6m` | Ultimos 6 meses |
| `_9m` | Ultimos 9 meses |
| `_12m` | Ultimos 12 meses |

#### Variantes

| Variante | Contexto | Ejemplo |
|---|---|---|
| `_Nm` | Estandar (tabla final) | `spsa_mtoprom_1m` |
| `_Nmes` | Tablas intermedias | `spsa_montototal_1mes` |
| `_uNm` | Variables IBK (Interbank) | `comportamiento_tarjeta_prm_trxtdefe_itc_u1m` |
| `_ult_Nm` | Promedios por rubro | `prm_spsa_rubro_frescos_ult_6m` |

### 5.5 Columnas sin sufijo temporal

Columnas que representan un punto en el tiempo (no una ventana):

| Columna | Tipo | Significado |
|---|---|---|
| `spsa_recencia` | NUMERIC | Dias desde la ultima compra en SPSA |
| `pro_recencia` | NUMERIC | Dias desde la ultima compra en Promart |
| `oe_recencia` | NUMERIC | Dias desde la ultima compra en Oechsle |
| `far_recencia` | NUMERIC | Dias desde la ultima compra en Farmacias |
| `spsa_fecha_ultimacompra` | DATE | Fecha de ultima compra en SPSA |

### 5.6 Columnas de control/metadata

| Columna | Tipo | Significado |
|---|---|---|
| `process_date` | DATE | Fecha de procesamiento del registro |
| `id_intercorp` | STRING | Identificador unico del cliente Intercorp |
| `record_source` | STRING | Fuente del registro (literal `'Retail'`) |
| `load_date` | DATETIME | Timestamp de carga (`CURRENT_DATETIME('America/Lima')`) |

### 5.7 Columnas de flags

| Patron | Tipo | Significado |
|---|---|---|
| `flag_persona_natural` | INTEGER (0/1) | Flag de persona natural |
| `flag_outlier_inkafarma` | INTEGER (0/1) | Flag de outlier por empresa |
| `flag_outlier_plazavea` | INTEGER (0/1) | Flag de outlier por empresa |
| `flag_compra_panal_bebe_1m_consecutivo` | INTEGER (0/1) | Flag de comportamiento |
| `flag_alimento_saludable` | INTEGER (0/1) | Flag de clasificacion de producto |

---

## 6. Patrones de Columnas Complejas

### 6.1 Patron de ranking de rubros

```
{empresa}_rubro_top{N}_{criterio}_{detalle}_{ventana}
```

| Componente | Valores | Ejemplo |
|---|---|---|
| `{empresa}` | `far_`, `farma_`, `spsa_`, `oe_`, `pro_` | `farma_` |
| `top{N}` | `top1`, `top2`, `top3` | `top1` |
| `{criterio}` | `frec` (frecuencia), `monto` | `frec` |
| `{detalle}` | `name` (nombre del rubro), (vacio = valor numerico) | `name` |
| `{ventana}` | `1m`, `3m`, `6m`, `9m`, `12m` | `1m` |

Ejemplo completo: `farma_rubro_top1_frec_name_1m` = Nombre del rubro top 1 por frecuencia en farmacias, ultimo mes

### 6.2 Patron de gamas

```
{empresa}_{metrica}_{tipo_producto}_gama_{nivel}_{ventana}
```

| Componente | Valores |
|---|---|
| `{tipo_producto}` | `electro`, `ropa`, `jugueteria`, `alimentos` |
| `gama_{nivel}` | `gama_alta`, `gama_media`, `gama_baja` |

Ejemplo: `spsa_mtomax_ropa_gama_alta_1m`

### 6.3 Patron de comportamiento IBK

```
comportamiento_{dimension}_{estadistico}_{tipo_transaccion}_itc_u{ventana}
```

| Componente | Valores |
|---|---|
| `{dimension}` | `tarjeta`, `efectivo`, `trx`, `cliente`, `compra` |
| `{estadistico}` | `prm` (promedio), `max`, `min`, `frec`, `flg` (flag), `prom` |
| `{tipo_transaccion}` | `trxtdefe` (tarjeta+debito+efectivo), `trxefe` (efectivo), `trxtd` (debito), `trxtc` (credito), `trxtotal`, `trxpres` (presencial), `trxonl` (online), `trxprom` (promocional) |

Ejemplo: `comportamiento_tarjeta_prm_trxtdefe_itc_u3m`

### 6.4 Patron de comportamiento de compra

```
comportamiento_compra_{dimension}_{criterio}_{ventana}
```

| Dimension | Ejemplo |
|---|---|
| `parte_dia_mas_frec` | Parte del dia mas frecuente |
| `nombre_dia_mas_frec` | Dia de la semana mas frecuente |
| `tipo_dia_mas_frec` | Tipo de dia mas frecuente (weekday/weekend) |
| `tipo_distrito_mas_frec` | Tipo de distrito mas frecuente |
| `entidad_banco_mas_frec` | Entidad bancaria mas frecuente |
| `patron_mas_frec` | Patron de consumo mas frecuente |

### 6.5 Patron de promedios por rubro

```
prm_{empresa}_rubro_{nombre_rubro}_ult_{ventana}
trx_{empresa}_rubro_{nombre_rubro}_ult_{ventana}
```

Ejemplo: `prm_spsa_rubro_frescos_ult_6m`, `trx_fa_rubro_marca_ult_6m`

---

## 7. Columnas de Tablas Fuente (Modelo Transaccional)

### 7.1 Tabla `t_retail_transaction`

| Columna | Tipo | Significado |
|---|---|---|
| `id` | STRING | ID unico del cliente |
| `itc_company_id` | STRING | Codigo de empresa Intercorp |
| `itc_company_name` | STRING | Nombre de empresa |
| `business_unit` | STRING | Unidad de negocio |
| `channel` | STRING | Canal de venta (ONLINE, PRESENCIAL) |
| `transaction_ticket` | STRING | Numero de ticket |
| `transaction_date` | DATE | Fecha de transaccion |
| `transaction_date_number` | INT64 | Fecha como YYYYMMDD |
| `transaction_type` | STRING | Tipo de transaccion (VENTAS, VENTA) |
| `transaction_id` | STRING | ID unico de transaccion |
| `transaction_hour` | STRING | Hora de la transaccion |
| `place_id` | STRING | ID del local/tienda |
| `place_description` | STRING | Descripcion del local |
| `product_item_id` | STRING | ID del producto |
| `product_item_sku` | STRING | SKU del producto |
| `product_item_seq` | INT | Secuencia del item |
| `product_item_quantity` | NUMERIC | Cantidad del item |
| `product_item_gross_amount` | NUMERIC | Monto bruto del item |
| `product_item_dsct_amount` | NUMERIC | Monto descuento del item |
| `product_item_itc_dsct_amount` | NUMERIC | Monto descuento ITC |
| `product_item_foh_dsct_amount` | NUMERIC | Monto descuento FOH |
| `product_category` | STRING | Categoria del producto |
| `process_date` | DATE | Fecha de procesamiento |
| `flag_outlier_vta_intercorp_retail` | INT64 | Flag de outlier |

### 7.2 Tabla `m_product`

| Columna | Significado |
|---|---|
| `product_item_id` | ID del producto (clave de join) |
| `itc_company_id` | ID empresa (filtro) |
| `brand_name` | Nombre de marca |
| `jq1_value` | Jerarquia nivel 1 (ej: MEDICAMENTO ETICO) |
| `jq2_value` | Jerarquia nivel 2 / Rubro (ej: BELLEZA, GENERICO) |
| `jq3_value` | Jerarquia nivel 3 (ej: FORMULA LACTEA) |
| `jq4_value` | Jerarquia nivel 4 (ej: PANAL DESECHABLE BEBE) |
| `jq7_value` | Jerarquia nivel 7 (filtro antibioticos) |

### 7.3 Tablas TEE (Fuentes legadas)

Columnas con prefijos de tipo de dato (notacion hungara):

| Prefijo | Tipo | Significado | Ejemplo |
|---|---|---|---|
| `d_` | DATETIME/DATE | Fecha | `d_fec_trn` |
| `b_` | BOOLEAN | Flag | `b_flg_cliente` |
| `n_` / `N_` | NUMERIC/FLOAT64 | Numerico | `n_imp_tot`, `N_IMP_OT_BBVA` |
| `s_` | STRING | Cadena texto | `s_id_doc_pago`, `s_cod_tipo_trn` |

#### Detalle de columnas de importe (`n_imp_*`)

| Columna | Significado |
|---|---|
| `n_imp_tot` | Importe total |
| `n_imp_toh` | Importe Tarjeta OH |
| `n_imp_omp` | Importe Oh Mastercard/Payments |
| `n_imp_efe` | Importe efectivo |
| `n_imp_ot_cre` | Importe otros credito |
| `n_imp_ot_deb` | Importe otros debito |
| `N_IMP_OT_BBVA` | Importe Otros BBVA |
| `N_IMP_OT_IBK` | Importe Otros Interbank |
| `N_IMP_OT_SCO` | Importe Otros Scotiabank |
| `N_IMP_OT_CSC` | Importe Otros Cencosud |
| `N_IMP_OT_RIP` | Importe Otros Ripley |
| `N_IMP_OT_CMR` | Importe Otros CMR Falabella |
| `N_IMP_OT_CEN` | Importe Otros Cencosud (alt) |
| `N_IMP_OT_PROV` | Importe Otros Proveedores |

---

## 8. Codigos de Empresa Intercorp

| itc_company_id | Empresa | Prefijo largo (intermedia) | Prefijo corto (final) |
|---|---|---|---|
| `010` | Supermercados Peruanos S.A. | `spsa_` | `spsa_` |
| `011` | Oechsle / Tiendas Peruanas | `oe_` | `oe_` |
| `024` | Promart | `promart_` | `pro_` |
| `025` | InkaFarma | `farmas_` (agrupado con 048) | `far_` / `farma_` |
| `048` | MiFarma | `farmas_` (agrupado con 025) | `far_` / `farma_` |
| `074` | (Catalogo productos farmacia) | -- | -- |
| `012` | (Excluido de metricas digitales) | -- | -- |
| `015` | (Excluido de metricas digitales) | -- | -- |

---

## 9. Categorias de Producto por Unidad de Negocio

### SPSA (Supermercados Peruanos)

bazar, bebidas, carnes, comestibles, comestibles_especiales, comidas_preparadas, cuidado_personal_limpieza, electro, fiambres_quesos, frutas_verduras, hogar, lacteos_congelados, miscelaneos, panaderia_pasteleria, pescados_mariscos, textil, otros, bebidas_alcoholicas, alimentos, ropa_nino, alimento_saludable, alimento_no_saludable, frescos, carnes_pescados

### Promart

acabados, jardin_temp, hogar_deco, otros, obra_gruesa, ferreteria

### Oechsle

mujer, infantil, hombre, belleza, deportes, calzado, electrohogar, decohogar, marcas_boutique, autoliquidables, otros, ropa, ropa_nino, implemento_deportivo

### Farmacias (InkaFarma + MiFarma)

administrativo, adulto, bazar, bebes_ninos, belleza, cuidado_infantil, cuidado_personal, dermacosmetica, dispositivo_medico, forma_farmaceutica, formula_estandar, generico, insumo_material_fm, liquidos, marca, medicamento, medicamento_popular_marca, medicamento_popular_generico, mimarket, nutricion_adultos, nutricion_deportiva_control, otros, otros_nutricion, producto_fmagistral, sin_clasificacion_historica, wellnes, antibiotico, bienestar

---

## 10. Abreviaturas de Medios de Pago

| Abreviatura | Significado |
|---|---|
| `efectivo` / `efe` | Efectivo |
| `debito` / `deb` | Tarjeta de debito |
| `credito` / `cre` | Tarjeta de credito |
| `toh` | Tarjeta OH |
| `omp` | Oh Mastercard/Payments |
| `bbva` | BBVA |
| `ibk` | Interbank |
| `sco` | Scotiabank |
| `csc` | Cencosud (Tarjeta) |
| `rip` | Ripley (Tarjeta) |
| `cmr` | CMR Falabella |
| `cen` | Cencosud (alternativo) |
| `prov` | Proveedores |

---

## 11. Patrones de SQL Dinamico

### Patron de ejecucion

```sql
set v_sql = '''
  <SQL statement>
''';
execute immediate v_sql;
```

### Patron de referencia a tablas

```sql
-- Tabla con proyecto/dataset como variable y nombre fijo:
`'''||v_proyecto_destino||'''.'''||v_master_stage||'''.nombre_tabla_fijo`

-- Tabla completamente parametrizada:
`'''||v_proyecto||'''.'''||v_master_product||'''.'''||v_table_m_product||'''`
```

### Patron de fechas en filtros

```sql
where process_date = "'''||v_fecha||'''"
where transaction_date >= "'''||v_interval_date_6M_g||'''"
where codmes = "'''||v_interval_date_1M_g||'''"
where transaction_date_number >= '''||v_interval_date_6M||'''
```

---

## 12. Patrones de Calculo

### 12.1 Montos por empresa (SUM + CASE WHEN)

```sql
sum(case when itc_company_id='010'
    then product_item_gross_amount else 0 end) as spsa_montototal_1mes
```

### 12.2 Monto promedio (SAFE_DIVIDE)

```sql
SAFE_DIVIDE(
  sum(case when ... then amount else 0 end),
  count(distinct case when ... then ticket else null end)
) as spsa_mtoprom_1m
```

### 12.3 Promedio mensual (division por N)

```sql
sum(case when ... then amount else 0 end) / 6 as spsa_mtoprom_6m
```

### 12.4 Porcentaje (SAFE_DIVIDE * 100)

```sql
SAFE_DIVIDE(
  if(a.promart_montoprom_1m > 0, b.pro_mtoprom_efectivo_1m, 0),
  b.pro_mtoprom_tot_1m
) * 100 as pro_porc_efectivo_1m
```

### 12.5 Deduplicacion (ROW_NUMBER)

```sql
ROW_NUMBER() OVER (
  PARTITION BY process_date, id
  ORDER BY process_date DESC
) rn
...
WHERE rn = 1
```

### 12.6 Ranking de rubros (FIRST_VALUE / ROW_NUMBER)

```sql
FIRST_VALUE(rubro) OVER (
  PARTITION BY id
  ORDER BY frecuencia DESC
  ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
) as farma_rubro_top1_frec_name_1m
```

### 12.7 Flags (CASE WHEN + COALESCE)

```sql
COALESCE(flag_outlier_vta_inkafarma, 0) AS flag_outlier_inkafarma

case when tipo_persona = 'natural' then 1 else 0 end as flag_persona_natural
```

### 12.8 CAST en la tabla de salida final

```sql
CAST(pro_porc_efectivo_1m as NUMERIC)
CAST(spsa_seg_canal_1m as STRING)
CAST(spsa_caja_rapida_1m as INTEGER)
```

---

## 13. Aliases de Tablas

| Convencion | Ejemplo | Contexto |
|---|---|---|
| Letras simples secuenciales | `a`, `b`, `c`, `d`, `e`, `f` | JOINs multiples |
| Abreviaturas descriptivas | `trx`, `mp`, `cm`, `fp`, `ip`, `pro` | Tablas fuente |
| `mN` (m1, m3, m6, m9, m12) | Tablas temporales por ventana temporal | Consolidacion final |
| `TMP{N}` (mayusculas) | CTEs numerados | Sub-queries complejas |
| `s{N}` (s1, s3) | Sub-queries secuenciales | Secciones IBK |
| `USING (id)` sin alias | JOINs masivos | Tabla final con muchos LEFT JOINs |

---

## 14. Tipos de Dato por Prefijo

| Prefijo de columna | Tipo BigQuery | Contexto |
|---|---|---|
| `d_` | DATETIME / DATE | Fechas (tablas TEE) |
| `b_` | BOOLEAN | Flags (tablas TEE) |
| `n_` / `N_` | FLOAT64 / NUMERIC | Importes (tablas TEE) |
| `s_` | STRING | Cadenas (tablas TEE) |
| `id` / `id_` | STRING | Identificadores |
| `flag_` | INTEGER (0/1) | Flags binarios |
| `mto*_` / `montototal_` | NUMERIC | Montos calculados |
| `numtrx_` / `q_` | INTEGER | Conteos |
| `porc_` | NUMERIC | Porcentajes |
| `rubrofrec_` / `rubro_prom_` | STRING | Categorias textuales |
| `fecha_` | DATE | Fechas calculadas |
| `process_date` | DATE | Fecha de proceso |
| `load_date` | DATETIME | Timestamp de carga |
| `codmes` | STRING/DATE | Codigo de mes (YYYYMM) |

---

## 15. Flujo de Ejecucion del Pipeline

```
SP_1: Base transaccional limpia (tmp_base_trx_cliente_retail)
  |
SP_2: Variables por ventana temporal (tmp_variables_1m a _12m)
  |     + Ultima compra, establecimiento, frecuencia BU
  |     + Variables farmas por rubro/riesgos
  |
SP_3: Consolidacion v1 (ba_itc_attr_retail_v1)
  |
SP_4: Segmento tipo caja, montos, medios de pago
  |     (tmp_variables_envio3_*, envio2_*_final_retail_cliente)
  |
SP_5: Rankings de rubro top1-top3 por frecuencia y monto
  |
SP_6: Atributos IBK detalle (prd_attr_ba_retail_trx_ibk_*)
  |     + Comportamiento compra, patron consumo
  |
SP_7: Clasificacion por gamas (tmp_trx_retail_gamas_ibk)
  |
SP_8: Flags de producto (tmp_trx_retail_flags_ibk)
  |
SP_9: Promedios por rubro/ticket (tmp_varibk_*_prom_ticket)
  |
SP_FINAL: Consolidacion final (ba_itc_attr_retail)
           DELETE + INSERT con JOINs de todas las tablas intermedias
```

---

## 16. Opciones de Tabla

| Patron | Uso |
|---|---|
| `CREATE OR REPLACE TABLE` | Tablas intermedias (idempotente) |
| `DELETE FROM ... WHERE process_date = ...` + `INSERT INTO` | Tablas finales (incremental por fecha) |
| `PARTITION BY transaction_date` | Tablas de detalle transaccional |
| `PARTITION BY codmes` | Tablas finales por mes |
| `CLUSTER BY itc_company_id` | Tablas transaccionales |
| `CLUSTER BY transaction_date` | Tablas agrupadas |

---

## 17. Comentarios y Separadores

### Separadores de seccion

```sql
--------------------------jorch_nombre_seccion--------------------------
```

Donde `jorch_` es un identificador del desarrollador/creador de la seccion.

### Comentarios inline en SET

```sql
set v_input = proyecto||'.'||dataset||'.'||tabla; /*nombre_tabla*/
```

### Comentarios de bloque

```sql
---- Tabla temporal de outliers
--DIGITAL
--PRESENCIAL
---atributos ibk
```

---

## 18. Inconsistencias Documentadas

| Inconsistencia | Detalle |
|---|---|
| Prefijo de parametros | Mezcla de `v_` y `var_` sin criterio claro |
| Case en tipos | `string` (minuscula) vs `STRING` (mayuscula) en parametros |
| `start_date` sin prefijo | Unico parametro sin `v_` o `var_` |
| Sufijo temporal | `_Nmes` (intermedias) vs `_Nm` (final) vs `_uNm` (IBK) vs `_ult_Nm` (rubros) |
| Prefijo empresa largo/corto | `promart_` vs `pro_`, `farmas_` vs `far_` / `farma_` |
| Case en CTEs internas | `TMP1`, `TMP2`, `RUBRO`, `SOLES_1M` (UPPER) vs tablas/columnas finales (lower) |
| `oe_decohogar_6m` | Falta `mtoprom_` que tienen los demas periodos |
| Naming de rubros | `far_` en INSERT list vs `farma_` en SELECT para rankings |
