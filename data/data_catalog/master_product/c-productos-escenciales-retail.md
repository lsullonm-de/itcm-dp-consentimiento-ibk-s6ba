# Catálogo de Datos — `c_productos_escenciales_retail`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_product`
**Tabla completa:** `intercorp-data-storage-pv.master_product.c_productos_escenciales_retail`

---

## Descripción

Catálogo de **productos esenciales en el canal retail**. Clasifica SKUs de Tiendas Peruanas/Oechsle (011) y Supermercados Peruanos/SPSA (010) con un indicador binario (`clasificacion_escencial = 1/0`) que determina si el producto cubre una **necesidad básica**. Se usa en los SPs de atributos de consumo retail para distinguir el gasto en productos de primera necesidad del gasto discrecional.

Un cliente que concentra sus compras en `clasificacion_escencial = 1` tiene un perfil de consumo orientado a la canasta básica.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 3,361 |
| Tamaño | ~300 KB |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `itc_company_id` | STRING | Código empresa Intercorp | `010` (SPSA), `011` (OE) |
| `itc_company_name` | STRING | Nombre empresa | |
| `jq1_value` | STRING | Jerarquía nivel 1 del producto | Join con `m_product.jq1_value` |
| `jq2_value` | STRING | Jerarquía nivel 2 del producto | |
| `jq3_value` | STRING | Jerarquía nivel 3 del producto | |
| `jq4_value` | STRING | Jerarquía nivel 4 del producto | |
| `clasificacion_escencial` | INTEGER | **1 = producto esencial / 0 = no esencial** | Campo de salida principal |

---

## Distribución por empresa y tipo

**SPSA (010) — Alimentos esenciales:** Comestibles Básicos, Lácteos, Carnes, Frutas y Verduras, Panadería, Congelados, Fiambres, Bebidas No Alcohólicas, Comidas Preparadas

**SPSA (010) — No esenciales:** Ropa (parcialmente), algunos Electro

**Tiendas Peruanas (011) — Esenciales:** Textil Infantil (ropa de bebés/niños), algunas categorías básicas

**Tiendas Peruanas (011) — No esenciales:** Electrónica, Videojuegos, Belleza, Perfumería, Marcas Boutique, Juguetería

---

## Reglas de negocio

1. **Clave de join**: Usar `itc_company_id + jq1_value + jq2_value + jq3_value + jq4_value` para clasificar cada SKU de `t_retail_transaction` vía `m_product`.

2. **Segmentos de clientes con esta tabla**:
   - **Clientes canasta básica**: `clasificacion_escencial = 1` con alta frecuencia y bajo ticket
   - **Clientes discrecionales**: `clasificacion_escencial = 0` con compras en ropa, electro, entretenimiento
   - **Clientes mixtos**: Combinación de ambos tipos

3. **Cobertura parcial**: Solo cubre empresas 010 y 011. Para Promart, Inkafarma y Mifarma no hay clasificación de esenciales en esta tabla.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Sin fechas de carga | No hay `load_date` ni `process_date`. Catálogo estático sin trazabilidad temporal. |
| Cobertura limitada | Solo 3,361 SKUs catalogados entre dos empresas. Puede haber SKUs en `t_retail_transaction` sin clasificación. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_product.m_product` | `itc_company_id` + `jq1_value` + `jq2_value` + `jq3_value` + `jq4_value` | Marcar productos como esenciales/no esenciales |
| `master_transaction.t_retail_transaction` | Vía `m_product.product_item_sku` | Clasificar el tipo de compra retail del cliente |

---

```sql
-- Gasto en productos esenciales vs. no esenciales por cliente (SPSA)
SELECT t.id,
  SUM(CASE WHEN pe.clasificacion_escencial = 1 THEN SAFE_CAST(t.product_item_amount AS FLOAT64) END) AS gasto_esencial,
  SUM(CASE WHEN pe.clasificacion_escencial = 0 THEN SAFE_CAST(t.product_item_amount AS FLOAT64) END) AS gasto_no_esencial
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
JOIN `intercorp-data-storage-pv.master_product.m_product` mp
  ON t.product_item_sku = mp.product_item_sku AND t.itc_company_id = mp.itc_company_id
  AND mp.process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_product.m_product`)
LEFT JOIN `intercorp-data-storage-pv.master_product.c_productos_escenciales_retail` pe
  ON mp.itc_company_id = pe.itc_company_id
  AND mp.jq1_value = pe.jq1_value AND mp.jq2_value = pe.jq2_value
  AND mp.jq3_value = pe.jq3_value AND mp.jq4_value = pe.jq4_value
WHERE t.transaction_date BETWEEN '2025-01-01' AND '2026-01-01'
  AND t.itc_company_id = '010'
GROUP BY 1;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_product.c_productos_escenciales_retail`*
