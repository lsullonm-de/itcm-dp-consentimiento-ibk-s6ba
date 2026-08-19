# Catálogo de Datos — `m_place`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_placement`
**Tabla completa:** `intercorp-data-storage-pv.master_placement.m_place`

---

## Descripción

Maestro de **lugares físicos** (tiendas, sucursales, puntos de venta) de las empresas Intercorp. Contiene la información geográfica, operativa y de jerarquía de cada punto de atención al cliente: tiendas Inkafarma (025) y Mifarma (048). Incluye dirección completa, coordenadas, datos del socio comercial, aforo, superficie de venta, horarios y jerarquía de agrupación de locales.

A diferencia de `m_commerce` (que cataloga comercios afiliados a la red Izipay), `m_place` cataloga **los propios puntos de venta** de las empresas del grupo.

> **Nota:** En el snapshot actual solo aparecen Inkafarma (025) y Mifarma (048). Promart, SPSA y otros pueden tener sus propias tablas maestras de tiendas o aún no integradas.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DAY) |
| Clusterizado por | `itc_company_id`, `place_id` |
| Total de filas | 20,492 |
| Tamaño | ~7.4 MB |
| Snapshot más reciente | 2026-03-10 |
| Empresas cubiertas | 025 (Inkafarma), 048 (Mifarma) |

---

## Perfil de datos (snapshot 2026-03-10)

| itc_company_id | itc_company_name | Lugares | place_status activo | Última fecha |
|---|---|---|---|---|
| 025 | INKAFARMA | 11 | 2 | 2026-03-10 |
| 048 | MIFARMA | 4 | 1 | 2026-03-10 |

> Solo 15 registros en el snapshot más reciente. La tabla puede tener mayor volumen en snapshots históricos o estar en proceso de carga.

---

## Glosario de Campos

### 1. Identificadores y control

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `process_date` | DATE | **Campo de partición**. Fecha del snapshot | |
| `itc_company_id` | STRING | Código empresa Intercorp | |
| `itc_company_name` | STRING | Nombre empresa | |
| `itc_employee_company_id` | STRING | Empresa del empleado responsable | |
| `itc_employee_company_name` | STRING | Nombre de la empresa del empleado | |
| `flag_active` | BOOLEAN | Indica si el lugar está activo | |
| `flg_external_place` | STRING | Indica si es un lugar externo (no propio) | |
| `place_status` | STRING | Estado del lugar: ACTIVO, CERRADO, EN CONSTRUCCIÓN | |
| `dq_flag_ind` | BOOLEAN | Pasó controles de calidad de datos | |
| `dq_control_msg` | STRING | Detalle de errores de calidad | |
| `dq_config_id` | STRING | Modelo de calidad aplicado | |
| `hk_diff` | BYTES | Hash del registro | |
| `start_date` | TIMESTAMP | Inicio de vigencia del registro | |
| `end_date` | TIMESTAMP | Fin de vigencia (`31/12/2099` cuando vigente) | |
| `record_source` | STRING | Sistema origen | |
| `load_date` | TIMESTAMP | Fecha de carga | |
| `creation_user` | STRING | Usuario | |

### 2. Identificación del lugar

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `place_id` | STRING | **Clave primaria**. Código del lugar | Join con `t_retail_transaction.place_id` |
| `place_alternative_id` | STRING | Identificador alternativo del lugar | |
| `place_name` | STRING | Nombre del lugar/tienda | Ej: INKAFARMA MIRAFLORES 1 |
| `place_description` | STRING | Descripción del lugar | |
| `business_unit_id` | STRING | Código de la unidad de negocio | |
| `business_unit` | STRING | Nombre del formato o unidad de negocio | |
| `corporation_id` | STRING | Código de la corporación | |
| `corporation_name` | STRING | Nombre de la corporación | |

### 3. Tipo y categoría del lugar

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `place_type_id` | STRING | Código del tipo de lugar | |
| `place_type_description` | STRING | Tipo: TIENDA, ALMACÉN, CENTRO DE DISTRIBUCIÓN, etc. | NULL en snapshot actual |
| `place_category_id` | STRING | Código de la categoría del lugar | |
| `place_category_name` | STRING | Nombre de la categoría | |
| `place_subcategory_id` | STRING | Código de subcategoría | |
| `place_subcategory_name` | STRING | Nombre de subcategoría | |

### 4. Canal

| Campo | Tipo | Descripción |
|---|---|---|
| `channel_id` | STRING | Código del canal de venta del lugar |
| `channel_description` | STRING | Canal: PRESENCIAL, NO PRESENCIAL |
| `subchannel_id` | STRING | Código del subcanal |
| `subchannel_description` | STRING | Subcanal: FÍSICO, WEB, APP |

### 5. Dirección y ubicación geográfica

| Campo | Tipo | Descripción |
|---|---|---|
| `address` | STRING | Dirección completa |
| `address_street_type` | STRING | Tipo de vía (AV., JR., CALLE) |
| `address_street_name` | STRING | Nombre de la vía |
| `address_street_number` | STRING | Número |
| `address_reference` | STRING | Referencia de la dirección |
| `address_zone_type` | STRING | Tipo de zona (URBANIZACIÓN, PUEBLO JOVEN, etc.) |
| `address_zone_name` | STRING | Nombre de la zona |
| `address_access_type` | STRING | Tipo de acceso |
| `location_access_number` | STRING | Número de acceso |
| `city` | STRING | Ciudad |
| `location_type` | STRING | Tipo de localización |
| `ubigeo` | STRING | Código UBIGEO |
| `district_id` / `district_name` | STRING | Distrito |
| `province_id` / `province_name` | STRING | Provincia |
| `department_id` / `department_name` | STRING | Departamento |
| `region_id` / `region_name` | STRING | Región |
| `country_id` / `country_name` | STRING | País |
| `longitude` | STRING | Longitud geográfica (formato STRING) |
| `latitude` | STRING | Latitud geográfica (formato STRING) |
| `geographic_point` | STRING | Punto geográfico combinado |
| `geographic_polygon` | STRING | Polígono de área del lugar |
| `utm_e` / `utm_n` / `utm_zone` | STRING | Coordenadas UTM |

### 6. Dimensiones y capacidad

| Campo | Tipo | Descripción |
|---|---|---|
| `size_unit_of_measure` | STRING | Unidad de medida de tamaño |
| `size` | STRING | Tamaño total del local |
| `selling_area_size` | STRING | Superficie de venta (m²) |
| `aforo` | STRING | Capacidad máxima de personas |
| `transaction_wokstation_quantity` | STRING | Cantidad de cajas/workstations |
| `transaction_workstation` | STRING | Descripción de workstations |
| `last_remodel_date` | STRING | Fecha de última remodelación |
| `location_store` | STRING | Código de ubicación en tienda |
| `security_level` | STRING | Nivel de seguridad del lugar |

### 7. Jerarquía de agrupación (jq1 a jq5)

Jerarquía propia de cada empresa para agrupar tiendas (por zona, distrito, región, etc.).

| Campo | Descripción |
|---|---|
| `jq1_id` / `jq1_name` / `jq1_value` | Nivel 1 — agrupación máxima (ej: Región) |
| `jq2_id` / `jq2_name` / `jq2_value` | Nivel 2 |
| `jq3_id` / `jq3_name` / `jq3_value` | Nivel 3 |
| `jq4_id` / `jq4_name` / `jq4_value` | Nivel 4 |
| `jq5_id` / `jq5_name` / `jq5_value` | Nivel 5 — agrupación más fina |

### 8. Fechas de operación

| Campo | Tipo | Descripción |
|---|---|---|
| `open_date` | STRING | Fecha de apertura de la tienda |
| `closing_date` | STRING | Fecha de cierre (si aplica) |
| `effective_date` | STRING | Fecha de inicio de vigencia en el sistema |
| `closed_date` | STRING | Fecha de baja en el sistema |

### 9. Socio comercial / operador

| Campo | Tipo | Descripción |
|---|---|---|
| `business_partner_id` | STRING | Código del socio comercial operador |
| `business_partner_identification` | STRING | RUC del socio |
| `business_partner_name` / `business_partner_commercial_name` | STRING | Nombre del socio |
| `business_partner_type` | STRING | Tipo de socio |
| `business_partner_sector_id` / `business_partner_sector` | STRING | Sector del socio |

### 10. Contacto

| Campo | Tipo | Descripción |
|---|---|---|
| `telephone_country_code` / `telephone_area_code` / `telephone` / `telephone_extension` / `telephone_complete_number` | STRING | Teléfonos del lugar |
| `email` | STRING | Correo de contacto |
| `website` | STRING | URL del sitio web |

### 11. Jerarquía de lugar padre

| Campo | Tipo | Descripción |
|---|---|---|
| `place_parent_id` | STRING | ID del lugar padre (ej: centro comercial que contiene la tienda) |
| `place_parent_name` | STRING | Nombre del lugar padre |

---

## Reglas de negocio

1. **Snapshot diario**: Usar `WHERE process_date = (SELECT MAX(process_date) FROM ...)` para el estado actual.

2. **Join con t_retail_transaction**: El campo de join es `place_id`. Para farmacias, este join enriquece con la dirección exacta de la farmacia donde se realizó la compra.

3. **Coordenadas en STRING**: Los campos `latitude` y `longitude` son tipo STRING. Convertir a FLOAT64 antes de calcular distancias: `SAFE_CAST(latitude AS FLOAT64)`.

4. **Tabla con pocos registros**: El maestro de lugares actual tiene muy pocos registros (15 en snapshot reciente). Puede indicar que la integración aún está en curso.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Muy pocos registros | Solo 15 lugares en el snapshot más reciente (11 INKF + 4 MFARM). Considerar versiones históricas. |
| `place_type_description` NULL | En snapshot actual todos los registros tienen NULL en este campo |
| Coordenadas como STRING | `latitude` y `longitude` son STRING, no FLOAT — requieren conversión |
| Empresas ausentes | SPSA, Promart, OE, Cineplanet, Real Plaza no aparecen |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.t_retail_transaction` | `place_id` | Enriquecer transacciones con datos de la tienda |
| `master_party.c_itc_company` | `itc_company_id` | Decodificar empresa |

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_placement.m_place`*
