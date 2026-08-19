# Catálogo de Datos: dev-itc-customer-services.farmas_stage.dv_productos

**Generado:** 2026-05-08

## 📊 Overview

| Propiedad | Valor |
|-----------|-------|
| **Tabla Completa** | `dev-itc-customer-services.farmas_stage.dv_productos` |
| **Tipo** | TABLE |
| **Descripción** | Tabla maestra de productos Farmacias |
| **Filas** | 69.55K |
| **Tamaño** | 46.55 MB |
| **Columnas** | 101 |
| **Creada** | 2025-09-19T23:27:13.522000+00:00 |
| **Modificada** | 2025-09-19T23:27:13.523000+00:00 |

## 📋 Diccionario de Campos

### Identificador

| Campo | Tipo | Modo | Riesgo PII | Observaciones |
|-------|------|------|-----------|---------------|
| `id` | `INT64` | NULLABLE | LOW | - |
| `co_producto` | `STRING` | NULLABLE | LOW | - |
| `co_producto_sap` | `STRING` | NULLABLE | LOW | - |
| `co_producto_mifarma` | `STRING` | NULLABLE | LOW | - |
| `cod_digemid` | `STRING` | NULLABLE | LOW | - |
| `keyproducto` | `STRING` | NULLABLE | LOW | - |
| `keyproductocupones` | `STRING` | NULLABLE | LOW | - |
| `keyjq3` | `STRING` | NULLABLE | LOW | - |
| `keyforecastjq5` | `STRING` | NULLABLE | LOW | - |
| `cantidad_fraccion` | `FLOAT64` | NULLABLE | LOW | - |
| `unidad_concentracion` | `STRING` | NULLABLE | LOW | - |
| `unidad_medida` | `STRING` | NULLABLE | LOW | - |
| `unidad_medida_mifarma` | `STRING` | NULLABLE | LOW | - |
| `unidad_producto_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `valor_medida` | `FLOAT64` | NULLABLE | LOW | - |
| `prod_sin_vta_perdida` | `STRING` | NULLABLE | LOW | - |

### Texto

| Campo | Tipo | Modo | Riesgo PII | Observaciones |
|-------|------|------|-----------|---------------|
| `de_producto` | `STRING` | NULLABLE | LOW | Descripción del producto |
| `marca` | `STRING` | NULLABLE | LOW | - |
| `laboratorio_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `laboratorio_mifarma` | `STRING` | NULLABLE | LOW | - |
| `proveedor_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `proveedor_mifarma` | `STRING` | NULLABLE | LOW | - |
| `division` | `STRING` | NULLABLE | LOW | - |
| `linea` | `STRING` | NULLABLE | LOW | - |
| `categoria` | `STRING` | NULLABLE | LOW | - |
| `segmento` | `STRING` | NULLABLE | LOW | - |
| `subsegmento` | `STRING` | NULLABLE | LOW | - |
| `subcategoria` | `STRING` | NULLABLE | LOW | - |
| `jq1` | `STRING` | NULLABLE | LOW | Jerarquía de clasificación nivel 1 |
| `jq2` | `STRING` | NULLABLE | LOW | Jerarquía de clasificación nivel 2 |
| `jq3` | `STRING` | NULLABLE | LOW | - |
| `jq4` | `STRING` | NULLABLE | LOW | - |
| `jq5` | `STRING` | NULLABLE | LOW | - |
| `jq6` | `STRING` | NULLABLE | LOW | - |
| `jq7` | `STRING` | NULLABLE | LOW | - |
| `jq_1` | `STRING` | NULLABLE | LOW | - |
| `jq_gg` | `STRING` | NULLABLE | LOW | - |
| `co_jq1` | `STRING` | NULLABLE | LOW | Código jerarquía nivel 1 |
| `co_jq2` | `STRING` | NULLABLE | LOW | Código jerarquía nivel 2 |
| `co_jq3` | `STRING` | NULLABLE | LOW | - |
| `co_jq4` | `STRING` | NULLABLE | LOW | - |
| `co_jq5` | `STRING` | NULLABLE | LOW | - |
| `co_linea` | `STRING` | NULLABLE | LOW | - |
| `co_categoria` | `STRING` | NULLABLE | LOW | - |
| `co_segmento` | `STRING` | NULLABLE | LOW | - |
| `co_subsegmento` | `STRING` | NULLABLE | LOW | - |
| `co_subcategoria` | `STRING` | NULLABLE | LOW | - |
| `co_division` | `STRING` | NULLABLE | LOW | - |
| `co_presentacion` | `STRING` | NULLABLE | LOW | - |
| `de_presentacion` | `STRING` | NULLABLE | LOW | - |
| `concentracion` | `STRING` | NULLABLE | LOW | - |
| `via_administracion` | `STRING` | NULLABLE | LOW | - |
| `cod_marca` | `STRING` | NULLABLE | LOW | - |
| `cod_laboratorio_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `cod_laboratorio_mifarma` | `STRING` | NULLABLE | LOW | - |
| `cod_proveedor_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `cod_proveedor_mifarma` | `STRING` | NULLABLE | LOW | - |
| `principio_act1` | `STRING` | NULLABLE | LOW | Principio activo 1 |
| `principio_act2` | `STRING` | NULLABLE | LOW | Principio activo 2 |
| `principio_act3` | `STRING` | NULLABLE | LOW | Principio activo 3 |
| `principio_act4` | `STRING` | NULLABLE | LOW | Principio activo 4 |
| `principio_act5` | `STRING` | NULLABLE | LOW | Principio activo 5 |
| `flag_coronavirus` | `STRING` | NULLABLE | LOW | - |
| `afecto_igv_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `afecto_igv_mifarma` | `STRING` | NULLABLE | LOW | - |
| `ean_inka` | `STRING` | NULLABLE | LOW | - |
| `ean_mifa` | `STRING` | NULLABLE | LOW | - |
| `estado_b2b` | `STRING` | NULLABLE | LOW | - |
| `estado_producto_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `estado_producto_mifarma` | `STRING` | NULLABLE | LOW | - |
| `grupo_externo` | `STRING` | NULLABLE | LOW | - |
| `in_prod_fraccionable_ink` | `STRING` | NULLABLE | LOW | - |
| `in_prod_fraccionable_mfa` | `STRING` | NULLABLE | LOW | - |
| `ind_marca_propia` | `STRING` | NULLABLE | LOW | - |
| `ind_zan_inkafarma` | `STRING` | NULLABLE | LOW | - |
| `ind_zan_mifarma` | `STRING` | NULLABLE | LOW | - |
| `origen` | `STRING` | NULLABLE | LOW | - |
| `pais` | `STRING` | NULLABLE | LOW | - |
| `corporacion_producto` | `STRING` | NULLABLE | LOW | - |
| `reg_sanitario` | `STRING` | NULLABLE | LOW | - |

### Financiero

| Campo | Tipo | Modo | Riesgo PII | Observaciones |
|-------|------|------|-----------|---------------|
| `precio_compra_inkafarma` | `FLOAT64` | NULLABLE | LOW | - |
| `costo_promedio_inkafarma` | `FLOAT64` | NULLABLE | LOW | - |

### Estructura

| Campo | Tipo | Modo | Riesgo PII | Observaciones |
|-------|------|------|-----------|---------------|
| `bono_inkafarma` | `INT64` | NULLABLE | LOW | - |
| `peso_bruto` | `FLOAT64` | NULLABLE | LOW | - |
| `presentacion` | `FLOAT64` | NULLABLE | LOW | - |
| `volumen` | `FLOAT64` | NULLABLE | LOW | - |
| `porc_incentivo_inkafarma` | `FLOAT64` | NULLABLE | LOW | - |
| `porc_incentivo_mifarma` | `FLOAT64` | NULLABLE | LOW | - |
| `val_frac_vta_sug_ink` | `FLOAT64` | NULLABLE | LOW | - |
| `val_frac_vta_sug_mfa` | `FLOAT64` | NULLABLE | LOW | - |
| `fecha_creacion_inkafarma` | `DATE` | NULLABLE | LOW | - |
| `fecha_creacion_mifarma` | `DATE` | NULLABLE | LOW | - |
| `fecha_proceso` | `TIMESTAMP` | NULLABLE | LOW | - |

### Identidad/PII

| Campo | Tipo | Modo | Riesgo PII | Observaciones |
|-------|------|------|-----------|---------------|
| `ruc_proveedor_mifarma` | `STRING` | NULLABLE | HIGH | ⚠️ DATO SENSIBLE |

## 🔐 Análisis de Seguridad

### Campos de Alto Riesgo

- 🔴 `ruc_proveedor_mifarma` — RUC (identificador fiscal) de proveedor

### Campos de Riesgo Medio

- Ninguno

### Campos Encriptados/Hash

- Ninguno

## 📈 Estadísticas Detalladas

```json
{
  "num_rows": 69553,
  "num_rows_formatted": "69.55K",
  "num_bytes": 48813609,
  "size_gb": 0.05,
  "size_formatted": "46.55 MB",
  "created": "2025-09-19T23:27:13.522000+00:00",
  "modified": "2025-09-19T23:27:13.523000+00:00",
  "expires": null
}
```

## 📦 Muestras de Datos

| id | co_producto | de_producto | jq1 | laboratorio_inkafarma |
|----|-------------|-------------|-----|----------------------|
| 35552 | 002784 | CULTIVO DE SECRECION VAGINAL | ANALISIS CLINICOS | ANALISIS CLINICOS |
| 48604 | 000054 | CAPSULAS | FORMULARIO MAGISTRAL (RECETARIO) | (null) |
| 13882 | 004358 | INACTIVO | SIN CLASIFICACION HISTORICA | SIN LABORATORIO |
| 56098 | 000075 | GEL BASE DE CARBOPOL 1% KG | FORMULARIO MAGISTRAL (RECETARIO) | FORMULARIO MAGISTRAL |
| 28518 | 002781 | PSA LIBRE Y TOTAL | ANALISIS CLINICOS | ANALISIS CLINICOS |

## 📝 Lineamientos

### Reglas de Negocio

- Tabla de referencia para productos de Farmacias (Inkafarma y Mi Farma)
- Mantiene sincronización entre códigos SAP e internos
- Soporta clasificaciones jerárquicas multinivel (JQ1-JQ7)
- Campos duplicados para dos cadenas de farmacia (Inkafarma/Mifarma)

### Observaciones de Calidad de Datos

- ⚠️ **Alto uso de NULLs:** muchos campos tienen valores nulos (análisis a profundidad recomendado)
- ⚠️ **Datos heredados:** algunos registros tienen estado "INACTIVO" (verificar políticas de retención)
- ✅ **Integridad de IDs:** campo `id` es PK identificador único

### Consideraciones Técnicas

- Tabla NO particionada (69.55K registros, tamaño moderado)
- NO está clustered (considerar clustering por `jq1`, `jq2` para queries analíticas)
- **PII Detectado:** Campo `ruc_proveedor_mifarma` contiene números de identificación fiscal
- Recomendación: Aplicar encriptación AEAD a `ruc_proveedor_mifarma` en capas sensibles

## 👥 Contacto

- **Data Owner:** _Pendiente_
- **Área:** Farmacias / Supply Chain
- **Repositorio:** `dev-itc-customer-services`
- **Última revisión:** 2026-05-08

---

**Generado con:** BigQuery Data Profiler (Cloud Function + Python)
