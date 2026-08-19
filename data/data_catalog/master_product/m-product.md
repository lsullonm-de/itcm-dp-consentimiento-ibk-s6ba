# Catálogo de Datos — `m_product`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_product`
**Tabla completa:** `intercorp-data-storage-pv.master_product.m_product`

---

## Descripción

Maestro de **productos** del Grupo Intercorp. Contiene el catálogo unificado de SKUs de las empresas retail del grupo: Tiendas Peruanas / Oechsle (011), Promart (024) y Farmacias Peruanas (074). Incluye jerarquía comercial del producto (hasta 8 niveles), datos de precio, fabricante, proveedor, atributos físicos y flags de comportamiento de venta.

Para Inkafarma (025) y Mifarma (048), el catálogo de medicamentos incluye información clínica: tipo de consumo (agudo/crónico), indicación (enfermedad, síntoma, grupo farmacológico) y documento de autorización (receta médica).

> Es la tabla de join clave para clasificar las compras en `t_retail_transaction` por categoría, tipo de producto, marca y jerarquía comercial.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DAY) |
| Clusterizado por | `itc_company_id`, `business_unit_id`, `product_item_sku` |
| Total de filas | ~3,723,028 |
| Tamaño lógico | ~3.33 GB |
| Snapshot más reciente | 2026-03-10 |
| Empresas cubiertas | 011 (Tiendas Peruanas), 024 (Promart), 074 (Farmacias Peruanas) |

---

## Perfil de datos (snapshot 2026-03-10)

| itc_company_id | itc_company_name | Productos | Tipos | Jerarquías jq1 | Jerarquías jq2 |
|---|---|---|---|---|---|
| 011 | TIENDAS PERUANAS | 3,007,391 | MODA / BASICO / SEMI MODA | 12 | 54 |
| 024 | PROMART | 106,368 | (sin tipo) | 7 | 22 |
| 074 | FARMACIAS PERUANAS S.A.C | 107 | (sin tipo) | 3 | 7 |

> Nota: SPSA (010), Inkafarma (025) y Mifarma (048) no aparecen en el snapshot actual — posiblemente tienen su propio catálogo de productos o aún no están integrados en esta tabla.

---

## Glosario de Campos

### 1. Identificadores y control

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `process_date` | DATE | **Campo de partición**. Fecha del snapshot | Filtrar siempre por este campo |
| `itc_company_id` | STRING | Código empresa Intercorp | `011`, `024`, `074` |
| `itc_company_name` | STRING | Nombre empresa | |
| `business_unit_id` | STRING | Código de la unidad de negocio | Parte del clustering |
| `business_unit` | STRING | Nombre de la unidad de negocio (tienda/formato) | |
| `flag_active` | BOOLEAN | Indica si el producto está activo | 100% activos en snapshot actual |
| `item_status` | STRING | Estado del ítem: ACTIVO, RETIRADO, BAJA | |
| `item_status_detail` | STRING | Estado del ítem en la empresa específica | |
| `effective_date` | STRING | Fecha de alta del producto | |
| `closed_date` | STRING | Fecha de baja del producto | |
| `available_for_sale_date` | STRING | Fecha desde la que está disponible para venta | |
| `dq_flag_ind` | BOOLEAN | Pasó controles de calidad de datos | |
| `dq_control_msg` | STRING | Detalle de errores de calidad | |
| `dq_config_id` | STRING | Modelo de calidad aplicado | |
| `hk_diff` | BYTES | Hash del registro para detectar cambios | |
| `start_date` | TIMESTAMP | Inicio de vigencia del registro | `end_date = 31/12/2099` cuando vigente |
| `end_date` | TIMESTAMP | Fin de vigencia del registro | |
| `record_source` | STRING | Sistema origen de los datos | |
| `load_date` | TIMESTAMP | Timestamp de inserción | |
| `creation_user` | STRING | Usuario que creó el registro | |

### 2. Identificación del producto

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `product_id` | STRING | Código del producto en el modelo corporativo | Nivel producto |
| `product_item_id` | STRING | Identificador del ítem en el sistema de origen | Nivel SKU |
| `product_item_sku` | STRING | **SKU del producto**. Clave de join con `t_retail_transaction.product_item_sku` | Parte del clustering |
| `product_item_itc_sku` | STRING | SKU corporativo ITC del producto | |
| `product_name` | STRING | Nombre del producto | |
| `product_business_name` | STRING | Nombre comercial del producto | |
| `product_description` | STRING | Descripción del producto | Ej: TARJETA DE CRÉDITO VISA NORMAL |
| `product_long_description` | STRING | Descripción extensa | |
| `product_item_name` | STRING | Nombre del ítem (nivel SKU) | |
| `product_item_description` | STRING | Descripción del ítem | |
| `product_item_itc_name` | STRING | Nombre corporativo del ítem | |

### 3. Tipo y clasificación comercial

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `product_type_id` | STRING | Código del tipo de producto | |
| `product_type` | STRING | Tipo de producto | Ej: TARJETA, SEGURO, CTS, MEDICAMENTO, COMESTIBLE, MODA, BASICO |
| `brand_id` | STRING | Código de la marca | |
| `brand_name` | STRING | Nombre de la marca | Ej: SAMSUNG, APPLE, DON VICTORIO, SFERA KIDS |
| `subbrand_id` | STRING | Código de la submarca | |
| `subbrand_name` | STRING | Nombre de la submarca | |
| `model_id` | STRING | Código del modelo | Ej: WA13J4750LV |
| `model_name` | STRING | Nombre del modelo | |
| `product_group_id` | STRING | Código del grupo de producto | |
| `product_group_name` | STRING | Nombre del grupo en jerarquía comercial | |

### 4. Jerarquía comercial (jq1 a jq8)

La jerarquía comercial clasifica los productos en niveles de agrupación propios de cada empresa. Cada nivel tiene id, nombre del nivel y valor asignado al producto.

| Campo | Descripción | Ejemplo (Tiendas Peruanas) |
|---|---|---|
| `jq1_id` / `jq1_name` / `jq1_value` | Nivel 1 (más alto) | Jerarquía 1 → MUJER / HOMBRE / INFANTIL / ELECTROHOGAR |
| `jq2_id` / `jq2_name` / `jq2_value` | Nivel 2 | Jerarquía 2 → JUVENIL / SEÑORA JOVEN / ELECTRONICA |
| `jq3_id` / `jq3_name` / `jq3_value` | Nivel 3 | Jerarquía 3 → Subcategoría específica |
| `jq4_id` / `jq4_name` / `jq4_value` | Nivel 4 | Subcategoría más fina |
| `jq5_id` / `jq5_name` / `jq5_value` | Nivel 5 | |
| `jq6_id` / `jq6_name` / `jq6_value` | Nivel 6 | |
| `jq7_id` / `jq7_name` / `jq7_value` | Nivel 7 | |
| `jq8_id` / `jq8_name` / `jq8_value` | Nivel 8 (más fino) | |

> No todas las empresas usan los 8 niveles. Tiendas Peruanas usa principalmente jq1-jq4. Promart usa jq1-jq2.

### 5. Canal de comercialización

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `channel_id` | STRING | Código del canal | |
| `channel_description` | STRING | Canal: PRESENCIAL, NO PRESENCIAL, OMNICANAL | |
| `subchannel_id` | STRING | Código del subcanal | |
| `subchannel_description` | STRING | Subcanal: FÍSICO, WEB, APP, CALL CENTER | |

### 6. Precios

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `price_list_id` | STRING | Código de la lista de precios | |
| `price_list_description` | STRING | Descripción del precio de lista | |
| `price_currency` | STRING | Moneda: SOLES, DÓLARES, PUNTOS | |
| `permanent_sale_unit_price_amount` | FLOAT | Precio unitario de venta permanente (con descuentos permanentes) | |
| `permanent_markdown_count_price` | FLOAT | Monto de los descuentos/rebajas permanentes | |
| `current_sale_unit_price_amount` | FLOAT | Precio actual de venta (base para POS) | Campo principal de precio |
| `digital_sale_unit_price_amount` | FLOAT | Precio en canal online | |
| `minimum_advertised_unit_price` | FLOAT | Precio mínimo de publicidad (MAP) | |
| `frequent_shopper_points_count` | FLOAT | Puntos de comprador frecuente por compra | |
| `unit_price_factor` | INTEGER | Unidades de medida por unidad de venta | |

### 7. Atributos clínicos / farmacéuticos (Farmacias)

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `product_consumption_type` | STRING | Tipo de consumo: AGUDO, CRÓNICO, NO APLICA | Clave para identificar clientes con enfermedades crónicas |
| `product_usage` | STRING | Uso del producto: SÍNTOMA, ENFERMEDAD, GRUPO FARMACOLÓGICO, DISPOSITIVO MÉDICO | |
| `product_usage_detail` | STRING | Detalle de enfermedad/síntoma/grupo farmacológico | Ej: DIABETES, HIPERTENSIÓN, ANTIBIÓTICO |
| `authorization_document` | STRING | Documento requerido para venta | Ej: Receta Médica |

### 8. Atributos físicos y logística

| Campo | Tipo | Descripción |
|---|---|---|
| `color` | STRING | Color del producto |
| `size` | STRING | Talla/tamaño |
| `size_description` / `size_category` / `size_type` / `size_proportion` / `size_family_name` | STRING | Dimensiones detalladas de talla |
| `gender` | STRING | Género: HOMBRE, MUJER, NIÑO, UNISEX |
| `material` | STRING | Material de fabricación |
| `number_of_pieces` | STRING | Número de piezas en el producto |
| `season` | STRING | Temporada: OTOÑO-INVIERNO 2021, etc. |
| `presentation_type` | STRING | Presentación: CAJA, SUELTO, etc. |
| `exposition_type` | STRING | Tipo de exposición: COLGADO, VITRINA |
| `barcode` | STRING | Código de barras |
| `environment_type` | STRING | Requisitos de almacenamiento (temperatura, humedad) |
| `weather_type` / `weather_temperature` / `weather_condition_type_id` | STRING | Condiciones climáticas del ambiente de venta |
| `security_required_type` | STRING | Nivel de seguridad para venta (joyas, medicamentos controlados) |
| `customer_pickup_type` | STRING | Forma de recojo: tienda, almacén, delivery |
| `validity` | STRING | Periodo de validez |
| `product_guarantee_description` | STRING | Tiempo de garantía: "1 año", "12 meses" |
| `product_technology` | STRING | Tecnología del producto |

### 9. Fabricante y proveedor

| Campo | Tipo | Descripción |
|---|---|---|
| `manufacturer_id` | STRING | Código del fabricante |
| `manufacturer_identification_number` | STRING | RUC del fabricante |
| `manufacturer_identification_name` / `manufacturer_identification_description` | STRING | Nombre comercial / razón social del fabricante |
| `manufacturer_country` | STRING | País de fabricación |
| `manufacturer_type` | STRING | NACIONAL o EXTRANJERO |
| `provider_id` | STRING | Código del proveedor |
| `provider_identification_number` | STRING | RUC del proveedor |
| `provider_identification_name` / `provider_identification_description` | STRING | Nombre del proveedor |
| `provider_country` | STRING | País del proveedor |
| `provider_type` | STRING | NACIONAL o EXTRANJERO |

### 10. Flags de comportamiento de venta

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_discount` | STRING | ¿Se puede descontar? |
| `flag_only_cash` | STRING | ¿Solo se vende por efectivo? |
| `flag_include_sale_tax` | STRING | ¿El precio incluye IGV? |
| `flag_prohibit_return` | STRING | ¿No se puede devolver? (ej: congelados) |
| `flag_own_product_brand` | STRING | ¿Es marca propia de la empresa? |
| `flag_core_product` | STRING | ¿Es producto core? |
| `flag_kit_set` | STRING | ¿Se vende como parte de un kit? |
| `flag_composite_product` | STRING | ¿Está compuesto por varios ítems vendibles por separado? |
| `flag_coupon_restricted` | STRING | ¿Restringido para uso con cupones? |
| `flag_authorized_for_sale` | STRING | ¿Autorizado para venta al público? |
| `flag_delivery_type` | STRING | ¿Se entrega en tienda o a domicilio? |
| `flag_foh_credit_card` | STRING | ¿Pagado con tarjeta OH? |
| `flag_price_audit` | STRING | ¿Precio auditado? |
| `flag_quantity_pricing` | STRING | ¿Precio por cantidad? Ej: 3 x S/1.00 |
| `flag_allow_food_stamp` | STRING | ¿Acepta cupones de alimentos? |
| `flag_allow_coupon_multiple` | STRING | ¿Acepta cupones múltiples/dobles? |
| `flag_frequent_shopper_points_eligibility` | STRING | ¿Elegible para puntos de comprador frecuente? |
| `flag_serialized_unity_validation` | STRING | ¿Requiere validación post-pago para serializado? |
| `flag_substitute_identified` | STRING | ¿Tiene sustituto disponible en tienda? |
| `flag_electronic_coupon` | STRING | ¿Tiene cupón electrónico disponible? |
| `flag_employee_discount_allowed` | STRING | ¿Tiene descuento para empleados? |

---

## Reglas de negocio

1. **Snapshot diario**: Usar `process_date = (SELECT MAX(...))` para obtener el catálogo vigente.

2. **Join con t_retail_transaction**: El campo de join es `product_item_sku` (clustering). Filtrar también por `itc_company_id` para eficiencia.

3. **Jerarquía comercial varía por empresa**: Los valores de `jq1_value` a `jq8_value` son específicos de cada empresa. No comparar entre empresas sin normalización previa.

4. **Identificación de clientes con enfermedades crónicas**: Cruzar `product_consumption_type = 'CRÓNICO'` y `product_usage_detail` con las compras en `t_retail_transaction` de farmacias.

5. **Solo 3 empresas en la tabla**: SPSA, Inkafarma y Mifarma no están representadas en el snapshot actual. Sus productos se identifican en `t_retail_transaction` a través del `product_item_sku` pero sin enriquecimiento de jerarquía desde esta tabla.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Empresas ausentes | SPSA (010), Inkafarma (025), Mifarma (048) no están en el snapshot actual |
| jq names genéricos | En Tiendas Peruanas, `jq1_name = 'Jerarquía 1'` — el nombre del nivel no es descriptivo; el valor real está en `jq1_value` |
| product_item_sku vs product_item_id | Ambos campos pueden representar el SKU. Verificar cual aplica por empresa antes de hacer join |
| Muchos campos de precio | Hay 8+ campos de precio distintos. Confirmar cuál es el precio de referencia para cada empresa |

---

## Queries de referencia

```sql
-- Catálogo vigente de Tiendas Peruanas por categoría jq1
SELECT jq1_value AS departamento, jq2_value AS subdepartamento,
  COUNT(*) AS sku_count,
  COUNTIF(flag_active = true) AS activos
FROM `intercorp-data-storage-pv.master_product.m_product`
WHERE process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_product.m_product`)
  AND itc_company_id = '011'
GROUP BY 1,2 ORDER BY sku_count DESC;

-- Identificar compras de medicamentos crónicos (segmento clínico)
SELECT t.id, p.product_usage_detail,
  COUNT(*) AS compras,
  SUM(SAFE_CAST(t.product_item_amount AS FLOAT64)) AS gasto_total
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
JOIN `intercorp-data-storage-pv.master_product.m_product` p
  ON t.product_item_sku = p.product_item_sku
  AND t.itc_company_id = p.itc_company_id
  AND p.process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_product.m_product`)
WHERE t.transaction_date BETWEEN '2025-01-01' AND '2026-01-01'
  AND p.product_consumption_type = 'CRÓNICO'
GROUP BY 1,2;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_product.m_product`*
