# Catálogo de Datos — `ba_itc_attr_corporate`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`

---

## Descripción

Atributos de **membresía corporativa** del cliente en el ecosistema Intercorp. Registra en qué empresas y productos del grupo tiene presencia activa, sus segmentaciones por empresa (interés, tendencia, valor, RFM) y si tiene datos de contacto disponibles. Es la tabla de referencia para saber a qué empresas del grupo pertenece un cliente.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~2.76B |
| Columnas | 52 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |
| `record_source` | `"MASTER_PARTY"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp` |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `record_source` | STRING | Origen del registro. Valor: `"MASTER_PARTY"` |
| `creation_user` | STRING | SA que ejecutó la carga |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

---

## 2. Flags de Membresía por Empresa — `flag_cliente_{empresa}`

1 = el cliente tiene presencia activa en esa empresa/producto del grupo en el mes.

| Campo | Empresa / Producto | Descripción |
|---|---|---|
| `flag_cliente_spsa` | SPSA | Cliente activo en Supermercados Peruanos (Plaza Vea, Mass, Vivanda, Makro) |
| `flag_cliente_oe` | Oechsle | Cliente activo en Oechsle / Tiendas Peruanas |
| `flag_cliente_pro` | Promart | Cliente activo en Promart |
| `flag_cliente_inkf` | InkaFarma | Cliente activo en InkaFarma |
| `flag_cliente_mfarm` | MiFarma | Cliente activo en MiFarma |
| `flag_cliente_cplt` | Cineplanet | Cliente activo en Cineplanet |
| `flag_cliente_ngr` | NGRestaurant | Cliente activo en restaurantes NGR (Madam Tusan, Chifa Chifa Express, etc.) |
| `flag_cliente_iter` | Interbank | Cliente activo en Interbank (banking) |
| `flag_cliente_ibk` | Interbank (IBK) | Cliente con producto Interbank activo |
| `flag_cliente_aviva` | Aviva | Cliente activo en clínicas Aviva (Intercorp Health) |
| `flag_cliente_foh` | Tarjeta OH! | Tiene tarjeta OH! activa (tarjeta de fidelización Intercorp) |
| `flag_cliente_rp` | Real Plaza | Cliente activo en centros comerciales Real Plaza |
| `flag_cliente_indg` | Indiggo | Cliente en el programa de lealtad Indiggo |
| `flag_cliente_agora_pay` | Ágora Pay | Usuario activo de la billetera Ágora Pay |
| `flag_cliente_agora_club` | Ágora Club | Suscrito al programa Ágora Club |
| `flag_cliente_agora_shop` | Ágora Shop | Usuario de Ágora Shop |
| `flag_cliente_agora_savings` | Ágora Savings | Usuario de Ágora Savings (ahorro) |
| `flag_cliente_ucic` | UCIC | Cliente identificado en el universo corporativo Intercorp |
| `flag_fidelidad` | Fidelidad | Flag general de fidelización activa en cualquier empresa |

---

## 3. Flags Negativos

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_no_cliente_ibk` | INTEGER | 1 = NO es cliente Interbank (complemento de `flag_cliente_ibk`) |
| `flag_no_cliente_foh` | INTEGER | 1 = NO tiene Tarjeta OH! activa (complemento de `flag_cliente_foh`) |

---

## 4. Datos de Contacto

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_dato_contacto` | INTEGER | 1 = tiene al menos un dato de contacto disponible (email o celular) |
| `flag_dato_correo` | INTEGER | 1 = tiene email registrado |
| `flag_dato_celular` | INTEGER | 1 = tiene número de celular registrado |
| `flag_dato_contacto_retail` | INTEGER | 1 = tiene dato de contacto proveniente de canal retail |
| `flag_dato_contacto_noretail` | INTEGER | 1 = tiene dato de contacto proveniente de canal no-retail |

---

## 5. Segmentaciones por Empresa

### Indiggo (programa de lealtad)

| Campo | Tipo | Descripción |
|---|---|---|
| `indg_seg_interes` | STRING | Segmento de interés del cliente en Indiggo |
| `indg_seg_rfm_frecuencia` | STRING | Segmento RFM de frecuencia en Indiggo |
| `indg_seg_rfm_monto` | STRING | Segmento RFM de monto en Indiggo |
| `indg_seg_rfm_recencia` | STRING | Segmento RFM de recencia en Indiggo |

### Oechsle

| Campo | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `oe_seg_interes` | STRING | Segmento de interés del cliente en OE | `"Hombre-Mujer"` |
| `oe_seg_tendencia` | STRING | Tendencia de compra en OE | `"T_Negativa_V+C"` |
| `oe_seg_valor` | STRING | Segmento de valor del cliente en OE | `"Medio Valor"` |

### Promart

| Campo | Tipo | Descripción |
|---|---|---|
| `pro_seg_interes` | STRING | Segmento de interés del cliente en Promart |
| `pro_seg_tendencia` | STRING | Tendencia de compra en Promart |
| `pro_seg_valor` | STRING | Segmento de valor del cliente en Promart |

### Farmacias (InkaFarma + MiFarma)

| Campo | Tipo | Descripción |
|---|---|---|
| `far_seg_interes` | STRING | Segmento de interés del cliente en farmacias |
| `far_seg_tendencia_frecuencia` | STRING | Tendencia en frecuencia de visita a farmacias |
| `far_seg_tendencia_margen` | STRING | Tendencia en margen generado en farmacias |
| `far_seg_tendencia_monto` | STRING | Tendencia en monto gastado en farmacias |

### SPSA (Supermercados Peruanos)

| Campo | Tipo | Descripción |
|---|---|---|
| `spsa_seg_rentabilidad` | STRING | Segmento de rentabilidad del cliente en SPSA |

### Plaza Vea

| Campo | Tipo | Descripción |
|---|---|---|
| `vea_seg_interes` | STRING | Segmento de interés del cliente en Plaza Vea |

---

## 6. Ventanas temporales

Esta tabla **no tiene ventanas temporales** (`_1m`, `_3m`, etc.). Cada partición `process_date` es un snapshot del estado actual del cliente en ese mes.

---

## 7. Queries de referencia

```sql
-- Clientes activos en múltiples empresas del grupo (mayo 2026)
SELECT id,
       flag_cliente_spsa, flag_cliente_oe, flag_cliente_pro,
       flag_cliente_inkf + flag_cliente_mfarm AS flag_farmacias,
       flag_cliente_cplt, flag_cliente_iter, flag_cliente_foh
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`
WHERE process_date = '2026-05-01'
  AND flag_fidelidad = 1;

-- Clientes con Tarjeta OH! y con dato de contacto
SELECT id, flag_cliente_foh, flag_dato_correo, flag_dato_celular,
       oe_seg_valor, spsa_seg_rentabilidad
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`
WHERE process_date = '2026-05-01'
  AND flag_cliente_foh = 1
  AND flag_dato_contacto = 1;

-- Segmentación de clientes SPSA por rentabilidad
SELECT spsa_seg_rentabilidad, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`
WHERE process_date = '2026-05-01'
  AND flag_cliente_spsa = 1
  AND spsa_seg_rentabilidad IS NOT NULL
GROUP BY 1 ORDER BY 2 DESC;

-- Clientes multi-empresa (activos en 3+ empresas)
SELECT id,
  (flag_cliente_spsa + flag_cliente_oe + flag_cliente_pro +
   flag_cliente_inkf + flag_cliente_mfarm + flag_cliente_cplt +
   flag_cliente_iter) AS num_empresas
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`
WHERE process_date = '2026-05-01'
HAVING num_empresas >= 3;
```

---

## 8. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Clave: `id`** — para cruzar con `ba_itc_attr_retail`: `corp.id = retail.id_intercorp`.
3. **Sin ventanas temporales** — cada partición es el estado del cliente en ese mes.
4. **`flag_fidelidad = 1`** = tiene membresía activa en al menos una empresa del grupo.
5. **`flag_cliente_inkf` y `flag_cliente_mfarm` son independientes** — un cliente puede estar en ambas farmacias simultáneamente.
6. **Segmentaciones pueden ser NULL** si el cliente no tiene historial suficiente para esa empresa.
7. **NULL = dato no disponible**; 0 = sin membresía activa.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate`*
