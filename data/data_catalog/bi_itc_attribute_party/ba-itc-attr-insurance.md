# Catálogo de Datos — `ba_itc_attr_insurance`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`

---

## Descripción

Seguros vigentes del cliente en el grupo Intercorp (Interseguro / Aviva). Registra qué tipos de seguro tiene activos, primas, frecuencia de pago, fechas de inicio/cancelación/término y siniestros reportados.

Permite identificar el portafolio de seguros por cliente, detectar oportunidades de cross-sell, anticipar renovaciones y analizar el comportamiento ante siniestros. Cubre 7 tipos de seguro: vida, masivos (grupal), SOAT, vehicular, renta vitalicia, renta privada y viaje.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~82M |
| Columnas | 125 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |
| `record_source` | `"RTDB"` |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `id` | STRING | Documento de identidad del cliente. Campo clustered |
| `creation_user` | STRING | SA que ejecutó la carga |
| `load_date` | DATETIME | Fecha y hora de carga |
| `record_source` | STRING | Origen del registro. Valor: `"RTDB"` |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

---

## 2. Flag general de vigencia

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_seguro_vigente` | INTEGER | `1` = tiene al menos un seguro vigente en cualquier tipo |

---

## 3. Flags de seguro por tipo — `flag_seguro_{tipo}`

`1` = tiene seguro activo de ese tipo.

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_seguro_vida` | INTEGER | Seguro de vida vigente |
| `flag_seguro_masivos` | INTEGER | Seguro masivo/grupal vigente |
| `flag_seguro_soat` | INTEGER | SOAT vigente |
| `flag_seguro_vehicular` | INTEGER | Seguro vehicular vigente |
| `flag_seguro_renta_vitalicia` | INTEGER | Renta vitalicia vigente |
| `flag_seguro_renta_privada` | INTEGER | Renta privada (AFP) registrada |
| `flag_seguro_viaje` | INTEGER | Seguro de viaje vigente |

---

## 4. Fechas de inicio de seguro — `fecha_seguro_{tipo}`

Fecha de inicio de la primera póliza vigente de ese tipo.

| Campo | Tipo | Descripción |
|---|---|---|
| `fecha_seguro_vida` | DATE | Fecha de inicio del seguro de vida |
| `fecha_seguro_masivos` | DATE | Fecha de inicio del seguro masivo |
| `fecha_seguro_soat` | DATE | Fecha de inicio del SOAT |
| `fecha_seguro_vehicular` | DATE | Fecha de inicio del seguro vehicular |
| `fecha_seguro_renta_vitalicia` | DATE | Fecha de inicio de renta vitalicia |
| `fecha_seguro_renta_privada` | DATE | Fecha de inicio de renta privada |
| `fecha_seguro_viaje` | DATE | Fecha de inicio del seguro de viaje |

---

## 5. Cantidad de pólizas vigentes — `cant_{tipo}_asegurado`

Número de pólizas activas por tipo de seguro.

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_vida_asegurado` | INTEGER | Cantidad de pólizas de vida vigentes |
| `cant_masivos_asegurado` | INTEGER | Cantidad de seguros masivos vigentes |
| `cant_soat_asegurado` | INTEGER | Cantidad de SOATs vigentes |
| `cant_vehiculo_asegurado` | INTEGER | Cantidad de seguros vehiculares vigentes |
| `cant_renta_vitalicia_asegurado` | INTEGER | Cantidad de rentas vitalicias vigentes |
| `cant_renta_privada_asegurado` | INTEGER | Cantidad de rentas privadas registradas |
| `cant_viaje_asegurado` | INTEGER | Cantidad de seguros de viaje vigentes |

---

## 6. Meses de antigüedad activa — `cant_meses_activo_seguro_{tipo}`

Meses de permanencia activa en el seguro.

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_meses_activo_seguro_vida` | INTEGER | Meses de antigüedad activa en seguro de vida |
| `cant_meses_activo_seguro_masivos` | INTEGER | Meses de antigüedad activa en seguro masivo |
| `cant_meses_activo_seguro_soat` | INTEGER | Meses de antigüedad activa en SOAT |
| `cant_meses_activo_seguro_vehicular` | INTEGER | Meses de antigüedad activa en seguro vehicular |
| `cant_meses_activo_seguro_renta_vitalicia` | INTEGER | Meses de antigüedad activa en renta vitalicia |
| `cant_meses_activo_seguro_renta_privada` | INTEGER | Meses de antigüedad activa en renta privada |
| `cant_meses_activo_seguro_viaje` | INTEGER | Meses de antigüedad activa en seguro de viaje |

---

## 7. Frecuencia de pago — `frec_pago_{tipo}`

Periodicidad de pago de la prima: `mensual`, `trimestral`, `anual`, etc.

| Campo | Tipo | Descripción |
|---|---|---|
| `frec_pago_vida` | STRING | Frecuencia de pago seguro de vida |
| `frec_pago_masivos` | STRING | Frecuencia de pago seguro masivo |
| `frec_pago_soat` | STRING | Frecuencia de pago SOAT |
| `frec_pago_vahicular` | STRING | Frecuencia de pago seguro vehicular. **Nota:** typo en nombre original (`vahicular`) |
| `frec_pago_renta_vitalicia` | STRING | Frecuencia de pago renta vitalicia |
| `frec_pago_renta_privada` | STRING | Frecuencia de pago renta privada |
| `frec_pago_viaje` | STRING | Frecuencia de pago seguro de viaje |

---

## 8. Prima neta — `prima_neta_{tipo}` (en S/)

Monto de la prima neta sin impuestos.

| Campo | Tipo | Descripción |
|---|---|---|
| `prima_neta_vida` | NUMERIC | Prima neta seguro de vida en S/ |
| `prima_neta_masivos` | NUMERIC | Prima neta seguro masivo en S/ |
| `prima_neta_soat` | NUMERIC | Prima neta SOAT en S/ |
| `prima_neta_vehicular` | NUMERIC | Prima neta seguro vehicular en S/ |
| `prima_neta_renta_vitalicia` | NUMERIC | Prima neta renta vitalicia en S/ |
| `prima_neta_renta_privada` | NUMERIC | Prima neta renta privada en S/ |
| `prima_neta_viaje` | NUMERIC | Prima neta seguro de viaje en S/ |

---

## 9. Prima total — `prima_total_{tipo}` (en S/)

Monto total de la prima incluyendo impuestos (neta + IGV u otros).

| Campo | Tipo | Descripción |
|---|---|---|
| `prima_total_vida` | NUMERIC | Prima total seguro de vida en S/ |
| `prima_total_masivos` | NUMERIC | Prima total seguro masivo en S/ |
| `prima_total_soat` | NUMERIC | Prima total SOAT en S/ |
| `prima_total_vehicular` | NUMERIC | Prima total seguro vehicular en S/ |
| `prima_total_renta_vitalicia` | NUMERIC | Prima total renta vitalicia en S/ |
| `prima_total_renta_privada` | NUMERIC | Prima total renta privada en S/ |
| `prima_total_viaje` | NUMERIC | Prima total seguro de viaje en S/ |

---

## 10. Seguros cancelados — `flag_cancelado_seguro_{tipo}` / `fecha_cancelado_seguro_{tipo}`

`1` = el seguro fue cancelado antes de su término natural.

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_cancelado_seguro_vida` | INTEGER | Seguro de vida cancelado anticipadamente |
| `flag_cancelado_seguro_masivos` | INTEGER | Seguro masivo cancelado anticipadamente |
| `flag_cancelado_seguro_soat` | INTEGER | SOAT cancelado anticipadamente |
| `flag_cancelado_seguro_vehicular` | INTEGER | Seguro vehicular cancelado anticipadamente |
| `flag_cancelado_seguro_renta_vitalicia` | INTEGER | Renta vitalicia cancelada anticipadamente |
| `flag_cancelado_seguro_renta_privada` | INTEGER | Renta privada cancelada anticipadamente |
| `flag_cancelado_seguro_viaje` | INTEGER | Seguro de viaje cancelado anticipadamente |
| `fecha_cancelado_seguro_vida` | DATE | Fecha de cancelación del seguro de vida |
| `fecha_cancelado_seguro_masivos` | DATE | Fecha de cancelación del seguro masivo |
| `fecha_cancelado_seguro_soat` | DATE | Fecha de cancelación del SOAT |
| `fecha_cancelado_seguro_vehicular` | DATE | Fecha de cancelación del seguro vehicular |
| `fecha_cancelado_seguro_renta_vitalicia` | DATE | Fecha de cancelación de la renta vitalicia |
| `fecha_cancelado_seguro_renta_privada` | DATE | Fecha de cancelación de la renta privada |
| `fecha_cancelado_seguro_viaje` | DATE | Fecha de cancelación del seguro de viaje |

---

## 11. Seguros terminados — `flag_terminado_seguro_{tipo}` / `fecha_terminado_seguro_{tipo}`

`1` = el seguro llegó a su término natural (no fue cancelado, simplemente venció).

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_terminado_seguro_vida` | INTEGER | Seguro de vida llegó a término natural |
| `flag_terminado_seguro_masivos` | INTEGER | Seguro masivo llegó a término natural |
| `flag_terminado_seguro_soat` | INTEGER | SOAT llegó a término natural |
| `flag_terminado_seguro_vehicular` | INTEGER | Seguro vehicular llegó a término natural |
| `flag_terminado_seguro_renta_vitalicia` | INTEGER | Renta vitalicia llegó a término natural |
| `flag_terminado_seguro_renta_privada` | INTEGER | Renta privada llegó a término natural |
| `flag_terminado_seguro_viaje` | INTEGER | Seguro de viaje llegó a término natural |
| `fecha_terminado_seguro_vida` | DATE | Fecha de término natural del seguro de vida |
| `fecha_terminado_seguro_masivos` | DATE | Fecha de término natural del seguro masivo |
| `fecha_terminado_seguro_soat` | DATE | Fecha de término natural del SOAT |
| `fecha_terminado_seguro_vehicular` | DATE | Fecha de término natural del seguro vehicular |
| `fecha_terminado_seguro_renta_vitalicia` | DATE | Fecha de término natural de la renta vitalicia |
| `fecha_terminado_seguro_renta_privada` | DATE | Fecha de término natural de la renta privada |
| `fecha_terminado_seguro_viaje` | DATE | Fecha de término natural del seguro de viaje |

---

## 12. Pensión y renta

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_tipo_pension` | INTEGER | `1` = tiene producto de pensión |
| `tipo_pension` | STRING | Tipo de pensión (ej: `SPP`, `SNP`) |
| `flag_tipo_renta` | INTEGER | `1` = tiene producto de renta |
| `tipo_renta` | STRING | Tipo de renta |

---

## 13. Siniestros — histórico total

`flag_siniestro_{tipo}` = `1` si reportó al menos un siniestro alguna vez.

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_siniestro_vida` | INTEGER | Tiene siniestro reportado en vida alguna vez |
| `flag_siniestro_masivos` | INTEGER | Tiene siniestro reportado en masivos alguna vez |
| `flag_siniestro_soat` | INTEGER | Tiene siniestro reportado en SOAT alguna vez |
| `flag_siniestro_vehicular` | INTEGER | Tiene siniestro reportado en vehicular alguna vez |
| `flag_siniestro_renta` | INTEGER | Tiene siniestro reportado en renta alguna vez |
| `cant_siniestro_vida` | INTEGER | Cantidad total de siniestros reportados en vida |
| `cant_siniestro_masivos` | INTEGER | Cantidad total de siniestros reportados en masivos |
| `cant_siniestro_soat` | INTEGER | Cantidad total de siniestros reportados en SOAT |
| `cant_siniestro_vehicular` | INTEGER | Cantidad total de siniestros reportados en vehicular |
| `cant_siniestro_renta` | INTEGER | Cantidad total de siniestros reportados en renta |
| `fecha_ultimo_siniestro_vida` | DATE | Fecha del último siniestro en vida |
| `fecha_ultimo_siniestro_masivos` | DATE | Fecha del último siniestro en masivos |
| `fecha_ultimo_siniestro_soat` | DATE | Fecha del último siniestro en SOAT |
| `fecha_ultimo_siniestro_vehicular` | DATE | Fecha del último siniestro en vehicular |
| `fecha_ultimo_siniestro_renta` | DATE | Fecha del último siniestro en renta |

---

## 14. Siniestros — ventana 6 meses (`_6m`)

`1` = siniestro ocurrido en los últimos 6 meses.

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_siniestro_vida_6m` | INTEGER | Siniestro en vida en los últimos 6 meses |
| `flag_siniestro_masivos_6m` | INTEGER | Siniestro en masivos en los últimos 6 meses |
| `flag_siniestro_soat_6m` | INTEGER | Siniestro en SOAT en los últimos 6 meses |
| `flag_siniestro_vehicular_6m` | INTEGER | Siniestro en vehicular en los últimos 6 meses |
| `flag_siniestro_renta_6m` | INTEGER | Siniestro en renta en los últimos 6 meses |
| `cant_siniestro_vida_6m` | INTEGER | Cantidad de siniestros en vida en los últimos 6 meses |
| `cant_siniestro_masivos_6m` | INTEGER | Cantidad de siniestros en masivos en los últimos 6 meses |
| `cant_siniestro_soat_6m` | INTEGER | Cantidad de siniestros en SOAT en los últimos 6 meses |
| `cant_siniestro_vehicular_6m` | INTEGER | Cantidad de siniestros en vehicular en los últimos 6 meses |
| `cant_siniestro_renta_6m` | INTEGER | Cantidad de siniestros en renta en los últimos 6 meses |

---

## 15. Siniestros — ventana 12 meses (`_12m`)

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_siniestro_vida_12m` | INTEGER | Siniestro en vida en los últimos 12 meses |
| `flag_siniestro_masivos_12m` | INTEGER | Siniestro en masivos en los últimos 12 meses |
| `flag_siniestro_soat_12m` | INTEGER | Siniestro en SOAT en los últimos 12 meses |
| `flag_siniestro_vehicular_12m` | INTEGER | Siniestro en vehicular en los últimos 12 meses |
| `flag_siniestro_renta_12m` | INTEGER | Siniestro en renta en los últimos 12 meses |
| `cant_siniestro_vida_12m` | INTEGER | Cantidad de siniestros en vida en los últimos 12 meses |
| `cant_siniestro_masivos_12m` | INTEGER | Cantidad de siniestros en masivos en los últimos 12 meses |
| `cant_siniestro_soat_12m` | INTEGER | Cantidad de siniestros en SOAT en los últimos 12 meses |
| `cant_siniestro_vehicular_12m` | INTEGER | Cantidad de siniestros en vehicular en los últimos 12 meses |
| `cant_siniestro_renta_12m` | INTEGER | Cantidad de siniestros en renta en los últimos 12 meses |

---

## 16. Queries de referencia

```sql
-- Clientes con SOAT sin seguro vehicular (oportunidad cross-sell)
SELECT id, cant_soat_asegurado, prima_neta_soat, cant_meses_activo_seguro_soat
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`
WHERE process_date = '2026-05-01'
  AND flag_seguro_soat = 1
  AND flag_seguro_vehicular = 0;

-- Clientes con múltiples tipos de seguro (alta protección financiera)
SELECT id,
  (flag_seguro_vida + flag_seguro_masivos + flag_seguro_soat +
   flag_seguro_vehicular + flag_seguro_renta_vitalicia +
   flag_seguro_renta_privada + flag_seguro_viaje) AS tipos_seguros,
  prima_total_vida + prima_total_vehicular AS prima_estimada
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`
WHERE process_date = '2026-05-01'
HAVING tipos_seguros >= 3
ORDER BY tipos_seguros DESC;

-- Distribución de tipos de seguro vigentes
SELECT
  SUM(flag_seguro_vida)          AS clientes_vida,
  SUM(flag_seguro_masivos)       AS clientes_masivos,
  SUM(flag_seguro_soat)          AS clientes_soat,
  SUM(flag_seguro_vehicular)     AS clientes_vehicular,
  SUM(flag_seguro_renta_vitalicia) AS clientes_renta_vitalicia,
  SUM(flag_seguro_renta_privada) AS clientes_renta_privada,
  SUM(flag_seguro_viaje)         AS clientes_viaje,
  COUNT(*)                       AS total_asegurados
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`
WHERE process_date = '2026-05-01';

-- Clientes con siniestro reciente en SOAT o vehicular (6 meses)
SELECT id, flag_siniestro_soat_6m, cant_siniestro_soat_6m,
       flag_siniestro_vehicular_6m, cant_siniestro_vehicular_6m,
       fecha_ultimo_siniestro_soat, fecha_ultimo_siniestro_vehicular
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`
WHERE process_date = '2026-05-01'
  AND (flag_siniestro_soat_6m = 1 OR flag_siniestro_vehicular_6m = 1);

-- Prima promedio por tipo de seguro
SELECT
  AVG(prima_total_vida)          AS avg_prima_vida,
  AVG(prima_total_soat)          AS avg_prima_soat,
  AVG(prima_total_vehicular)     AS avg_prima_vehicular,
  AVG(prima_total_viaje)         AS avg_prima_viaje
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`
WHERE process_date = '2026-05-01'
  AND flag_seguro_vigente = 1;
```

---

## 17. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **`flag_seguro_vigente = 1`** es el filtro de entrada para cualquier análisis de asegurados activos.
3. **`flag_cancelado` vs `flag_terminado`**: cancelado = rescisión anticipada (potencial churn); terminado = vencimiento natural (oportunidad de renovación).
4. **Typo en campo original**: el campo de frecuencia de pago vehicular es `frec_pago_vahicular` (con `h`), no `frec_pago_vehicular`. Usar el nombre original al consultar.
5. **Solo cubre seguros Intercorp**: Interseguro / Aviva. Seguros contratados en otras compañías no aparecen.
6. **Siniestros acumulados**: `cant_siniestro_{tipo}` es el histórico total — no está limitado a ventana. Para análisis reciente usar `_6m` o `_12m`.
7. **`flag_tipo_pension` / `flag_tipo_renta`**: Presencia en productos de pensión y renta — pueden estar activos aunque `flag_seguro_vigente = 0` si no tienen otros seguros.
8. **NULL en primas**: Indica que el campo no está disponible para esa póliza, no que la prima sea cero.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_insurance`*
