# Catálogo de Datos — `ba_itc_attr_digital`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`

---

## Descripción

Atributos de **comportamiento digital** del cliente en los canales web y app de las empresas Intercorp. Registra si el cliente tiene actividad digital (compras online, sesiones, login), el dispositivo que usa, si está identificado (email/cuenta) y la recencia de su última transacción digital y en tienda. Cubre Plaza Vea, Vivanda, Makro, Oechsle, Promart, InkaFarma y MiFarma.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~974M |
| Columnas | 84 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes |
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp` |

---

## 2. Empresas y Códigos

| Código | Empresa |
|---|---|
| `vea` | Plaza Vea |
| `viv` | Vivanda |
| `mkr` | Makro Eco |
| `oec` | Oechsle |
| `pro` | Promart |
| `ink` | InkaFarma |
| `mif` | MiFarma |

---

## 3. Fecha Última Transacción — `fec_ult_trx_{canal}_{empresa}`

Fecha de la última transacción por canal y empresa.

| Campo | Tipo | Descripción |
|---|---|---|
| `fec_ult_trx_digital_vea` | DATE | Fecha última compra digital en Plaza Vea |
| `fec_ult_trx_digital_mkr` | DATE | Fecha última compra digital en Makro |
| `fec_ult_trx_digital_viv` | DATE | Fecha última compra digital en Vivanda |
| `fec_ult_trx_digital_oec` | DATE | Fecha última compra digital en Oechsle |
| `fec_ult_trx_digital_pro` | DATE | Fecha última compra digital en Promart |
| `fec_ult_trx_digital_ink` | DATE | Fecha última compra digital en InkaFarma |
| `fec_ult_trx_digital_mif` | DATE | Fecha última compra digital en MiFarma |
| `fec_ult_trx_tienda_vea` | DATE | Fecha última compra en tienda Plaza Vea |
| `fec_ult_trx_tienda_mkr` | DATE | Fecha última compra en tienda Makro |
| `fec_ult_trx_tienda_viv` | DATE | Fecha última compra en tienda Vivanda |
| `fec_ult_trx_tienda_oec` | DATE | Fecha última compra en tienda Oechsle |
| `fec_ult_trx_tienda_pro` | DATE | Fecha última compra en tienda Promart |
| `fec_ult_trx_tienda_ink` | DATE | Fecha última compra en tienda InkaFarma |
| `fec_ult_trx_tienda_mif` | DATE | Fecha última compra en tienda MiFarma |

---

## 4. Recencia — `recencia_{canal}_{empresa}`

Días desde la última transacción en ese canal y empresa (al momento del snapshot).

| Campo | Tipo | Descripción |
|---|---|---|
| `recencia_digital_vea` | INTEGER | Días desde última compra digital en Plaza Vea |
| `recencia_digital_mkr` | INTEGER | Días desde última compra digital en Makro |
| `recencia_digital_viv` | INTEGER | Días desde última compra digital en Vivanda |
| `recencia_digital_oec` | INTEGER | Días desde última compra digital en Oechsle |
| `recencia_digital_pro` | INTEGER | Días desde última compra digital en Promart |
| `recencia_digital_ink` | INTEGER | Días desde última compra digital en InkaFarma |
| `recencia_digital_mif` | INTEGER | Días desde última compra digital en MiFarma |
| `recencia_tienda_vea` | INTEGER | Días desde última compra en tienda Plaza Vea |
| `recencia_tienda_mkr` | INTEGER | Días desde última compra en tienda Makro |
| `recencia_tienda_viv` | INTEGER | Días desde última compra en tienda Vivanda |
| `recencia_tienda_oec` | INTEGER | Días desde última compra en tienda Oechsle |
| `recencia_tienda_pro` | INTEGER | Días desde última compra en tienda Promart |
| `recencia_tienda_ink` | INTEGER | Días desde última compra en tienda InkaFarma |
| `recencia_tienda_mif` | INTEGER | Días desde última compra en tienda MiFarma |

---

## 5. Flag Actividad — `flg_{canal}_{empresa}`

1 = el cliente tuvo actividad en ese canal/empresa en el mes de `process_date`.

| Campo | Tipo | Descripción |
|---|---|---|
| `flg_digital_vea` | INTEGER | 1 = compró online en Plaza Vea en el mes |
| `flg_digital_mkr` | INTEGER | 1 = compró online en Makro en el mes |
| `flg_digital_viv` | INTEGER | 1 = compró online en Vivanda en el mes |
| `flg_digital_oec` | INTEGER | 1 = compró online en Oechsle en el mes |
| `flg_digital_pro` | INTEGER | 1 = compró online en Promart en el mes |
| `flg_digital_ink` | INTEGER | 1 = compró online en InkaFarma en el mes |
| `flg_digital_mif` | INTEGER | 1 = compró online en MiFarma en el mes |
| `flg_tienda_vea` | INTEGER | 1 = compró en tienda Plaza Vea en el mes |
| `flg_tienda_mkr` | INTEGER | 1 = compró en tienda Makro en el mes |
| `flg_tienda_viv` | INTEGER | 1 = compró en tienda Vivanda en el mes |
| `flg_tienda_oec` | INTEGER | 1 = compró en tienda Oechsle en el mes |
| `flg_tienda_pro` | INTEGER | 1 = compró en tienda Promart en el mes |
| `flg_tienda_ink` | INTEGER | 1 = compró en tienda InkaFarma en el mes |
| `flg_tienda_mif` | INTEGER | 1 = compró en tienda MiFarma en el mes |

---

## 6. Dispositivo — `flg_device_{tipo}_{empresa}`

Dispositivo desde el que el cliente accedió al canal digital de cada empresa.

| Campo | Tipo | Descripción |
|---|---|---|
| `flg_device_desktop_vea` | INTEGER | 1 = accedió desde desktop (PC/Mac) a Plaza Vea |
| `flg_device_desktop_viv` | INTEGER | 1 = accedió desde desktop a Vivanda |
| `flg_device_desktop_oec` | INTEGER | 1 = accedió desde desktop a Oechsle |
| `flg_device_desktop_pro` | INTEGER | 1 = accedió desde desktop a Promart |
| `flg_device_desktop_ink` | INTEGER | 1 = accedió desde desktop a InkaFarma |
| `flg_device_desktop_mif` | INTEGER | 1 = accedió desde desktop a MiFarma |
| `flg_device_tablet_vea` | INTEGER | 1 = accedió desde tablet a Plaza Vea |
| `flg_device_tablet_viv` | INTEGER | 1 = accedió desde tablet a Vivanda |
| `flg_device_tablet_oec` | INTEGER | 1 = accedió desde tablet a Oechsle |
| `flg_device_tablet_pro` | INTEGER | 1 = accedió desde tablet a Promart |
| `flg_device_tablet_ink` | INTEGER | 1 = accedió desde tablet a InkaFarma |
| `flg_device_tablet_mif` | INTEGER | 1 = accedió desde tablet a MiFarma |
| `flg_device_mobile_vea` | INTEGER | 1 = accedió desde móvil/app a Plaza Vea |
| `flg_device_mobile_viv` | INTEGER | 1 = accedió desde móvil/app a Vivanda |
| `flg_device_mobile_oec` | INTEGER | 1 = accedió desde móvil/app a Oechsle |
| `flg_device_mobile_pro` | INTEGER | 1 = accedió desde móvil/app a Promart |
| `flg_device_mobile_ink` | INTEGER | 1 = accedió desde móvil/app a InkaFarma |
| `flg_device_mobile_mif` | INTEGER | 1 = accedió desde móvil/app a MiFarma |

> Makro (`mkr`) no tiene campos de dispositivo en esta tabla.

---

## 7. Identificación Digital — `flg_email_identified` y `flg_customer_identified`

| Campo | Tipo | Descripción |
|---|---|---|
| `flg_email_identified_vea` | INTEGER | 1 = el cliente fue identificado por email en Plaza Vea |
| `flg_email_identified_viv` | INTEGER | 1 = identificado por email en Vivanda |
| `flg_email_identified_oec` | INTEGER | 1 = identificado por email en Oechsle |
| `flg_email_identified_pro` | INTEGER | 1 = identificado por email en Promart |
| `flg_email_identified_ink` | INTEGER | 1 = identificado por email en InkaFarma |
| `flg_email_identified_mif` | INTEGER | 1 = identificado por email en MiFarma |
| `flg_customer_identified_vea` | INTEGER | 1 = el cliente fue identificado como usuario registrado en Plaza Vea |
| `flg_customer_identified_viv` | INTEGER | 1 = identificado como usuario registrado en Vivanda |
| `flg_customer_identified_oec` | INTEGER | 1 = identificado como usuario registrado en Oechsle |
| `flg_customer_identified_pro` | INTEGER | 1 = identificado como usuario registrado en Promart |
| `flg_customer_identified_ink` | INTEGER | 1 = identificado como usuario registrado en InkaFarma |
| `flg_customer_identified_mif` | INTEGER | 1 = identificado como usuario registrado en MiFarma |

---

## 8. Sesiones y Login — `flg_session` y `flg_login`

| Campo | Tipo | Descripción |
|---|---|---|
| `flg_session_vea` | INTEGER | 1 = tuvo al menos una sesión web/app en Plaza Vea en el mes |
| `flg_session_viv` | INTEGER | 1 = tuvo sesión en Vivanda |
| `flg_session_oec` | INTEGER | 1 = tuvo sesión en Oechsle |
| `flg_session_pro` | INTEGER | 1 = tuvo sesión en Promart |
| `flg_session_ink` | INTEGER | 1 = tuvo sesión en InkaFarma |
| `flg_session_mif` | INTEGER | 1 = tuvo sesión en MiFarma |
| `flg_login_vea` | INTEGER | 1 = inició sesión (login) en Plaza Vea en el mes |
| `flg_login_viv` | INTEGER | 1 = inició sesión en Vivanda |
| `flg_login_oec` | INTEGER | 1 = inició sesión en Oechsle |
| `flg_login_pro` | INTEGER | 1 = inició sesión en Promart |
| `flg_login_ink` | INTEGER | 1 = inició sesión en InkaFarma |
| `flg_login_mif` | INTEGER | 1 = inició sesión en MiFarma |

---

## 9. Queries de referencia

```sql
-- Clientes con compra digital en Plaza Vea mayo 2026
SELECT id, flg_digital_vea, recencia_digital_vea,
       fec_ult_trx_digital_vea, flg_device_mobile_vea
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`
WHERE process_date = '2026-05-01'
  AND flg_digital_vea = 1;

-- Clientes omnicanales (compra digital Y en tienda en el mismo mes)
SELECT id,
       flg_digital_vea, flg_tienda_vea,
       flg_digital_ink, flg_tienda_ink
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`
WHERE process_date = '2026-05-01'
  AND (flg_digital_vea = 1 AND flg_tienda_vea = 1);

-- Distribución de dispositivos en farmacias digitales
SELECT
  SUM(flg_device_mobile_ink)  AS mobile_inkf,
  SUM(flg_device_desktop_ink) AS desktop_inkf,
  SUM(flg_device_tablet_ink)  AS tablet_inkf
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`
WHERE process_date = '2026-05-01'
  AND flg_digital_ink = 1;

-- Clientes con sesión pero sin login (visitantes anónimos)
SELECT id, flg_session_vea, flg_login_vea,
       flg_email_identified_vea, flg_customer_identified_vea
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`
WHERE process_date = '2026-05-01'
  AND flg_session_vea = 1
  AND flg_login_vea = 0;
```

---

## 10. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Clave: `id`** — para cruzar con otras `ba_*`: `digital.id = retail.id_intercorp`.
3. **Sin ventanas temporales** — snapshot del mes actual de `process_date`.
4. **Makro (`mkr`) no tiene campos de dispositivo** (`flg_device_*_mkr`).
5. **`flg_session`** captura cualquier visita al sitio/app, **`flg_login`** solo las sesiones autenticadas.
6. **`flg_digital`** = compra completada online; **`flg_session`** = visita (puede ser sin compra).
7. NULL = sin actividad registrada (no es 0 — el 0 sí indica sin actividad).

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_digital`*
