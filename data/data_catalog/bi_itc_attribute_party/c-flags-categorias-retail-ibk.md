# Catálogo de Datos — `c_flags_categorias_retail_ibk`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.c_flags_categorias_retail_ibk`

---

## Descripción

Catálogo de **clasificación de categorías de productos retail** para segmentación orientada a casos de uso Interbank (IBK). Clasifica combinaciones de jerarquía de producto (jq1–jq4) por empresa con flags binarios para identificar si pertenecen a: alimento saludable, alimento no saludable, implemento deportivo, o producto de bienestar.

Permite enriquecer transacciones de `t_retail_transaction` con el tipo de producto según su categoría retail, habilitando segmentos como "clientes de alimentación saludable", "deportistas", o "interesados en bienestar".

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | ~3,365 |
| Número de columnas | 9 |
| Tamaño | ~200 KB |

---

## Glosario de Campos

| Campo | Tipo | Descripción |
|---|---|---|
| `itc_company_name` | STRING | Nombre de la empresa retail (ej: `SPSA`, `OE`) |
| `jq1_value` | STRING | Nivel 1 de jerarquía de producto (departamento/sección) |
| `jq2_value` | STRING | Nivel 2 de jerarquía de producto (categoría) |
| `jq3_value` | STRING | Nivel 3 de jerarquía de producto (subcategoría) |
| `jq4_value` | STRING | Nivel 4 de jerarquía de producto (segmento) |
| `flag_alimento_saludable` | INTEGER | `1` = la categoría corresponde a alimentos saludables |
| `flag_alimento_no_saludable` | INTEGER | `1` = la categoría corresponde a alimentos no saludables (procesados, ultraprocesados) |
| `flag_implemento_deportivo` | INTEGER | `1` = la categoría corresponde a implementos deportivos |
| `flag_bienestar` | INTEGER | `1` = la categoría corresponde a productos de bienestar (vitaminas, suplementos, cuidado personal) |

---

## Ejemplos de clasificaciones

### Alimentos saludables
| jq1_value | jq2_value | jq3_value | flag |
|---|---|---|---|
| ALIMENTOS | FRUTAS Y VERDURAS | FRUTAS FRESCAS | `flag_alimento_saludable = 1` |
| ALIMENTOS | LÁCTEOS | YOGURT NATURAL | `flag_alimento_saludable = 1` |
| ALIMENTOS | CARNES | PESCADO FRESCO | `flag_alimento_saludable = 1` |

### Alimentos no saludables
| jq1_value | jq2_value | jq3_value | flag |
|---|---|---|---|
| ALIMENTOS | SNACKS | PAPAS FRITAS | `flag_alimento_no_saludable = 1` |
| BEBIDAS | GASEOSAS | BEBIDAS CARBONATADAS | `flag_alimento_no_saludable = 1` |
| ALIMENTOS | GOLOSINAS | CHOCOLATES | `flag_alimento_no_saludable = 1` |

### Implementos deportivos
| jq1_value | jq2_value | jq3_value | flag |
|---|---|---|---|
| DEPORTES | EQUIPAMIENTO | ROPA DEPORTIVA | `flag_implemento_deportivo = 1` |
| DEPORTES | CALZADO | ZAPATILLAS RUNNING | `flag_implemento_deportivo = 1` |

### Bienestar
| jq1_value | jq2_value | jq3_value | flag |
|---|---|---|---|
| CUIDADO PERSONAL | VITAMINAS | SUPLEMENTOS | `flag_bienestar = 1` |
| FARMACIA | SALUD | PRODUCTOS DE BIENESTAR | `flag_bienestar = 1` |

---

## Clave de join

Esta tabla se usa para etiquetar transacciones de `t_retail_transaction` con el flag de categoría:

```
t_retail_transaction.itc_company_id → itc_company_name (transformado)
t_retail_transaction.product_jq1 → jq1_value
t_retail_transaction.product_jq2 → jq2_value
t_retail_transaction.product_jq3 → jq3_value
t_retail_transaction.product_jq4 → jq4_value
```

> Nota: `itc_company_name` en esta tabla corresponde al nombre de la empresa, no al `itc_company_id` numérico. Requiere mapeo previo.

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `t_retail_transaction` | `product_jq1-jq4` + `itc_company_id` | Etiquetar transacciones con flags de categoría |
| `m_product` | `jq1_value-jq4_value` | Etiquetar SKUs del catálogo de productos |
| `c_clasificacion_marcas_retail_ibk` | `itc_company_name` + jerarquías | Complementa con clasificación por marca |

---

## Reglas de negocio

1. **Sin partición** — catálogo estático. 3,365 combinaciones de jerarquía empresa+jq1-jq4.

2. **Los flags NO son mutuamente excluyentes**: Un producto puede ser simultáneamente `flag_alimento_saludable = 0` y `flag_alimento_no_saludable = 1`.

3. **`flag_alimento_saludable` para segmentación de salud**: Clientes con alta proporción de compras en `flag_alimento_saludable = 1` tienen perfil de alimentación consciente.

4. **`flag_alimento_no_saludable`**: No implica calidad nutricional baja necesariamente — es una clasificación de marketing para identificar categorías de productos procesados/snacks.

5. **Cobertura**: Solo cubre SPSA y OE (las dos empresas con jerarquía de producto jq1-jq4 completa). Promart y farmacias tienen cobertura limitada.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Solo SPSA y OE | Cobertura limitada a las empresas con jerarquía jq1-jq4 completa |
| `itc_company_name` ≠ `itc_company_id` | Usar mapeo `c_itc_company` para convertir entre nombre y ID |
| 3,365 filas | Catálogo pequeño y estático — escanear completo sin problema |
| Flags no actualizados frecuentemente | Si se agregan nuevas categorías de producto, el catálogo puede no cubrirlas automáticamente |

---

## Queries de referencia

```sql
-- Clientes con alta proporción de alimentos saludables en SPSA
SELECT t.id,
  COUNT(CASE WHEN f.flag_alimento_saludable = 1 THEN 1 END) AS trx_saludable,
  COUNT(CASE WHEN f.flag_alimento_no_saludable = 1 THEN 1 END) AS trx_no_saludable,
  COUNT(*) AS total_trx,
  ROUND(COUNT(CASE WHEN f.flag_alimento_saludable = 1 THEN 1 END) * 100.0 / COUNT(*), 2) AS pct_saludable
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.c_flags_categorias_retail_ibk` f
  ON t.itc_company_id = '010'  -- SPSA
  AND UPPER(t.product_jq1) = UPPER(f.jq1_value)
  AND UPPER(t.product_jq2) = UPPER(f.jq2_value)
  AND f.itc_company_name = 'SPSA'
WHERE t.transaction_date >= '2026-01-01'
  AND t.itc_company_id = '010'
GROUP BY 1
HAVING pct_saludable >= 60  -- clientes que >60% de sus compras son saludables
ORDER BY pct_saludable DESC;

-- Clientes deportistas (compran implementos deportivos en OE)
SELECT DISTINCT t.id
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.c_flags_categorias_retail_ibk` f
  ON UPPER(t.product_jq1) = UPPER(f.jq1_value)
  AND UPPER(t.product_jq2) = UPPER(f.jq2_value)
  AND f.itc_company_name = 'OE'
  AND f.flag_implemento_deportivo = 1
WHERE t.itc_company_id = '011'
  AND t.transaction_date >= '2026-01-01';

-- Distribución de categorías saludables vs no-saludables
SELECT f.flag_alimento_saludable, f.flag_alimento_no_saludable,
  COUNT(*) AS combinaciones
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.c_flags_categorias_retail_ibk` f
GROUP BY 1, 2;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_itc_attribute_party.c_flags_categorias_retail_ibk`*
