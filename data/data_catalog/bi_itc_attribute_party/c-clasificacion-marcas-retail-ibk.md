# Catálogo de Datos — `c_clasificacion_marcas_retail_ibk`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.c_clasificacion_marcas_retail_ibk`

---

## Descripción

Catálogo de **clasificación de marcas y productos retail** para uso en los atributos IBK. Mapea cada combinación empresa + jerarquía comercial (jq1 a jq4) a una clasificación de consumo y un indicador `grupo_ibk`. Se usa en el SP `sp_load_tmp_ba_itc_attr_retail_1.sql` para etiquetar las transacciones retail y calcular atributos de consumo segmentados para Interbank.

Cubre productos de Tiendas Peruanas/Oechsle (011) y Supermercados Peruanos/SPSA (010), clasificando marcas en categorías como Juguetería, Alimentos, Ropa, Electro, etc.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 11,063 |
| Tamaño | ~1.4 MB |

---

## Perfil de datos

| itc_company_id | itc_company_name | tipo | subtipo | SKUs | Marcas distintas | Clasificaciones |
|---|---|---|---|---|---|---|
| 10 | SUPERMERCADOS PERUANOS | Alimentos | Comestibles Especiales | 2,071 | 1,617 | 3 |
| 10 | SUPERMERCADOS PERUANOS | Alimentos | Bebidas Alcohólicas | 1,149 | 1,067 | 3 |
| 10 | SUPERMERCADOS PERUANOS | Juguetería | Juguetes | 986 | 986 | 3 |
| 11 | TIENDAS PERUANAS | Juguetería | Juguetes | 842 | 842 | 3 |
| 10 | SUPERMERCADOS PERUANOS | Alimentos | Fiambres y Quesos | 518 | 263 | 3 |
| 10 | SUPERMERCADOS PERUANOS | Alimentos | Comestibles Básicos | 459 | 378 | 3 |
| ... | | | | | | |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `itc_company_id` | INTEGER | Código de la empresa Intercorp | Nota: tipo INTEGER (no STRING como en otras tablas). Valores: 10 (SPSA), 11 (OE) |
| `itc_company_name` | STRING | Nombre de la empresa | SUPERMERCADOS PERUANOS, TIENDAS PERUANAS |
| `tipo` | STRING | Categoría de primer nivel | Ej: Alimentos, Ropa, Electro, Juguetería |
| `subtipo` | STRING | Subcategoría | Ej: Comestibles Especiales, Bebidas Alcohólicas, Ropa Mujer |
| `grupo_ibk` | INTEGER | Indicador de grupo IBK para segmentación | Valor numérico que agrupa marcas para reportes IBK |
| `jq1_value` | STRING | Valor del nivel 1 de jerarquía comercial | Join con `m_product.jq1_value` |
| `jq2_value` | STRING | Valor del nivel 2 de jerarquía comercial | Join con `m_product.jq2_value` |
| `jq3_value` | STRING | Valor del nivel 3 de jerarquía comercial | Join con `m_product.jq3_value` |
| `jq4_value` | STRING | Valor del nivel 4 de jerarquía comercial | Join con `m_product.jq4_value` |
| `brand_name` | STRING | Nombre de la marca del producto | Join con `m_product.brand_name` |
| `clasificacion` | STRING | **Clasificación asignada** para atributos IBK | Campo de salida principal |

---

## Categorías de `tipo` y `subtipo` observadas

| tipo | subtipos incluidos |
|---|---|
| Alimentos | Comestibles Especiales, Bebidas Alcohólicas, Fiambres y Quesos, Comestibles Básicos, Comidas Preparadas, Lácteos, Bebidas No Alcohólicas, Panadería y Pastelería, Carnes, Congelados, Frutas y Verduras |
| Ropa | Ropa Niños, Ropa Hombre, Ropa Mujer, Ropa Bebé |
| Electro | Cómputo, Electrónica Menor, Electrónica, Electrodomésticos |
| Juguetería | Juguetes |
| Belleza | Accesorios Belleza, Perfumería y Cosmético |
| Deportes | Tiempo Libre, Accesorios Deportes |

---

## Reglas de negocio

1. **`itc_company_id` es INTEGER**: A diferencia de otras tablas donde es STRING, aquí es INTEGER. El join debe usar CAST: `CAST(t.itc_company_id AS INTEGER) = c.itc_company_id`.

2. **Clave de join**: La combinación `itc_company_id + jq1_value + jq2_value + jq3_value + jq4_value + brand_name` identifica la clasificación de cada SKU.

3. **Cobertura parcial**: Solo cubre Tiendas Peruanas (011) y SPSA (010). No incluye Promart, Inkafarma ni Mifarma.

4. **Uso en SP**: El `sp_load_tmp_ba_itc_attr_retail_1.sql` hace join de `t_retail_transaction` + `m_product` + este catálogo para etiquetar cada transacción con su tipo/subtipo/clasificacion para el modelo de atributos de consumo retail de IBK.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| `itc_company_id` tipo INTEGER | Inconsistencia con el resto del modelo donde este campo es STRING |
| Join complejo | El join requiere 5 campos (company + 4 niveles jq). Si algún nivel es NULL en `m_product`, el join falla. |
| Sin versionado ni fechas | No hay campos de `process_date`, `effective_date` ni `end_date`. Es un catálogo estático sin histórico. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_product.m_product` | `itc_company_id` + `jq1_value` + ... + `brand_name` | Obtener la clasificación IBK del producto |
| `master_transaction.t_retail_transaction` | Vía `m_product.product_item_sku` | Clasificar transacciones retail |

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_itc_attribute_party.c_clasificacion_marcas_retail_ibk`*
