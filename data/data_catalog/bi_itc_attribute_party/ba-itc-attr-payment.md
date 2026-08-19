# Catálogo de Datos — `ba_itc_attr_payment`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`

---

## Descripción

Atributos de **consumo con Tarjeta OH! y billetera Ágora** del cliente, agregados por mes. Registra transacciones realizadas con la tarjeta de fidelización OH! (Intercorp) en empresas del grupo y restaurantes afiliados, y operaciones de la billetera digital Ágora (recargas, P2P, consumo, pagos de servicios y educación).

**Tarjeta OH!:** tarjeta de compras Intercorp aceptada en SPSA, OE, Promart, Farmacias, Mass, Makro y restaurantes del ecosistema.
**Ágora:** billetera digital Intercorp para pagos presenciales, online, P2P, recargas y pagos de servicios.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~58M |
| Columnas | 2,405 |
| Última fecha de proceso | `2026-05-01` |
| Ventanas disponibles | `1m`, `3m`, `6m`, `9m`, `12m`, `24m` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp` |
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `record_source` | STRING | Origen del registro |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

---

## 2. Naming Convention

```
{cant/mto/max_mto/mto_prom}_{operacion}_{canal}_{empresa/comercio}_{ventana}
```

| Segmento | Valores |
|---|---|
| `cant` | Número de transacciones |
| `mto` | Monto total (S/) |
| `max_mto` | Monto máximo de una transacción |
| `mto_prom` | Monto promedio por transacción |
| `ventana` | `1m`, `3m`, `6m`, `9m`, `12m`, `24m` |
| `canal` | `online`, `presencial` |

---

## 3. Tarjeta OH! — Consumo Total

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_con_toh_{Nm}` | INTEGER | Transacciones totales con OH! en N meses |
| `mto_con_toh_{Nm}` | FLOAT | Monto total con OH! en N meses (S/) |
| `max_mto_con_toh_{Nm}` | FLOAT | Monto máximo de una transacción con OH! |
| `mto_prom_con_toh_{Nm}` | FLOAT | Ticket promedio con OH! en N meses |

---

## 4. Tarjeta OH! — Por Canal

### Online

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_con_online_toh_{Nm}` | INTEGER | Transacciones online con OH! |
| `mto_con_online_toh_{Nm}` | FLOAT | Monto online con OH! |
| `max_mto_con_online_toh_{Nm}` | FLOAT | Monto máximo online |
| `mto_prom_con_online_toh_{Nm}` | FLOAT | Ticket promedio online |

### Presencial

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_con_presencial_toh_{Nm}` | INTEGER | Transacciones presenciales con OH! |
| `mto_con_presencial_toh_{Nm}` | FLOAT | Monto presencial con OH! |
| `max_mto_con_presencial_toh_{Nm}` | FLOAT | Monto máximo presencial |
| `mto_prom_con_presencial_toh_{Nm}` | FLOAT | Ticket promedio presencial |

---

## 5. Tarjeta OH! — Por Empresa del Grupo

Los sufijos de empresa usados son: `vea` (Plaza Vea), `oe` (Oechsle), `pro` (Promart), `ink` (InkaFarma), `mif` (MiFarma), `mak` (Makro), `mass` (Mass), `cas` (Cassinelli), `iter` (Interbank).

Para cada empresa hay 4 campos en cada canal (`online`/`presencial`) y ventana:

```
cant_con_{canal}_toh_{empresa}_{Nm}
mto_con_{canal}_toh_{empresa}_{Nm}
max_mto_con_{canal}_toh_{empresa}_{Nm}
mto_prom_con_{canal}_toh_{empresa}_{Nm}
```

**Empresas disponibles:**

| Código | Empresa |
|---|---|
| `vea` | Plaza Vea |
| `oe` | Oechsle |
| `pro` | Promart |
| `ink` | InkaFarma |
| `mif` | MiFarma |
| `mak` | Makro Eco |
| `mass` | Mass |
| `cas` | Cassinelli |
| `iter` | Interbank (pagos con OH! en banco) |

---

## 6. Tarjeta OH! — Por Restaurante / Cadena de comida

Métricas de consumo OH! en restaurantes y cadenas afiliadas al programa. Patrón: `{cant/mto/max_mto/mto_prom}_con_toh_{restaurante}_{Nm}`

**Hamburguesas y comida rápida:**
`bembos`, `burger_king`, `mcdonalds`, `fridays`, `juicy_lucy`, `papachos`, `vaca_negra`, `street_burger`, `johnny_rockets`, `bon_beef`, `popeyes`, `kfc`, `miami_chicken`, `chicken_what`, `conviction_chicken`, `pica_pollo`

**Pollerías:**
`casimiro`, `don_belisario`, `pardos_chicken`, `canastas`, `mediterraneo`, `villa_chicken`, `norkys`, `rockys`, `primos_chicken`, `don_tito`, `la_panka`, `las_tinajas`, `pikalo`, `el_pollon`, `pappas`, `kiriko`, `otto_grill`, `carbon_punto`, `caravana`, `pollos_pios`, `rasson`, `corralito`, `el_meson`, `lena_carbon`

**Chifas:**
`china_wok`, `fun_sen`, `mr_lee`, `madam_tusan`, `mr_shao`, `chifa_yiyi`, `chifa_palacio`, `san_joy_lao`

**Cafeterías:**
`dunkin_donuts`, `starbucks`

**Pizzerías:**
`dominos_pizza`, `mamma_tomato`, `dnnos_pizza`, `ragazzi_pizza`, `popolo_pizza`, `pizzarte`, `al_tavolo`, `jacks_urban_pizza`, `piccolina`, `la_linterna`, `antica_pizzeria`, `napoli`, `little_caesars`

---

## 7. Billetera Ágora — Operaciones

### Recargas de saldo

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_recarga_agora_{Nm}` | INTEGER | Recargas de saldo Ágora en N meses |
| `mto_recarga_agora_{Nm}` | FLOAT | Monto total recargado en N meses |
| `mto_prom_recarga_agora_{Nm}` | FLOAT | Monto promedio por recarga |
| `max_mto_recarga_agora_{Nm}` | FLOAT | Monto máximo de una recarga |
| `cant_recarga_saldo_tienda_agora_{Nm}` | INTEGER | Recargas en tienda |
| `mto_recarga_saldo_tienda_agora_{Nm}` | FLOAT | Monto recargado en tienda |
| `cant_recarga_saldo_td_agora_{Nm}` | INTEGER | Recargas desde tarjeta débito |
| `mto_recarga_saldo_td_agora_{Nm}` | FLOAT | Monto recargado desde débito |
| `cant_recarga_celular_agora_{Nm}` | INTEGER | Recargas de celular via Ágora |
| `mto_recarga_celular_agora_{Nm}` | FLOAT | Monto en recargas celular |

### Transferencias P2P

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_p2p_entrante_agora_{Nm}` | INTEGER | Transferencias recibidas de otros usuarios Ágora |
| `mto_p2p_entrante_agora_{Nm}` | FLOAT | Monto recibido via P2P |
| `mto_prom_p2p_entrante_agora_{Nm}` | FLOAT | Monto promedio recibido |
| `max_mto_p2p_entrante_agora_{Nm}` | FLOAT | Monto máximo recibido |
| `cant_p2p_saliente_agora_{Nm}` | INTEGER | Transferencias enviadas a otros usuarios |
| `mto_p2p_saliente_agora_{Nm}` | FLOAT | Monto enviado via P2P |
| `mto_prom_p2p_saliente_agora_{Nm}` | FLOAT | Monto promedio enviado |
| `max_mto_p2p_saliente_agora_{Nm}` | FLOAT | Monto máximo enviado |

### Retiros de efectivo

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_retiro_cash_agora_{Nm}` | INTEGER | Retiros de efectivo via Ágora |
| `mto_retiro_cash_agora_{Nm}` | FLOAT | Monto retirado |
| `mto_prom_retiro_cash_agora_{Nm}` | FLOAT | Monto promedio por retiro |
| `max_mto_retiro_cash_agora_{Nm}` | FLOAT | Monto máximo retirado |

### Consumo Ágora — Total

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_con_agora_{Nm}` | INTEGER | Transacciones de consumo totales con Ágora |
| `mto_con_agora_{Nm}` | FLOAT | Monto total consumido con Ágora |
| `mto_prom_con_agora_{Nm}` | FLOAT | Ticket promedio con Ágora |
| `max_mto_con_agora_{Nm}` | FLOAT | Monto máximo de una transacción |

### Consumo Ágora — Por Empresa

Disponible para: `retail` (todas), `spsa`, `oe`, `mif`, `mass`, `mak`, `ink`, `pro`

```
cant_con_agora_{empresa}_{Nm}
mto_con_agora_{empresa}_{Nm}
mto_prom_con_agora_{empresa}_{Nm}
max_mto_con_agora_{empresa}_{Nm}
```

### Consumo Ágora — Por Empresa y Canal (presencial/online)

```
cant_con_agora_{presencial/online}_{empresa}_{Nm}
mto_con_agora_{presencial/online}_{empresa}_{Nm}
mto_prom_con_agora_{presencial/online}_{empresa}_{Nm}
max_mto_con_agora_{presencial/online}_{empresa}_{Nm}
```

---

## 8. Ágora — Pagos de Servicios y Educación

### Pagos de servicios generales

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_pago_servicios_agora_{Nm}` | INTEGER | Pagos de servicios (luz, agua, etc.) via Ágora |
| `mto_pago_servicios_agora_{Nm}` | FLOAT | Monto pagado en servicios |
| `mto_prom_pago_servicios_agora_{Nm}` | FLOAT | Monto promedio por pago |
| `max_mto_pago_servicios_agora_{Nm}` | FLOAT | Monto máximo pagado |

### Pagos educativos via Ágora

Patrón: `{cant/mto/mto_prom/max_mto}_pago_{institucion}_agora_{Nm}`

| Institución | Campo `{institucion}` |
|---|---|
| UTP | `utp` |
| IDAT | `idat` |
| IPAE | `ipae` |
| Innova Schools | `innova_schools` |
| Otras universidades | `otras_univ` |
| Otros colegios | `otros_colegios` |

---

## 9. Ventanas temporales

| Sufijo | Contenido | Sumable entre particiones |
|---|---|---|
| `_1m` | Solo el mes de `process_date` | ✅ Sí |
| `_3m` / `_6m` / `_9m` / `_12m` | Acumulado | ❌ No |
| `_24m` | Acumulado 24 meses (2 años) | ❌ No |

> Esta tabla incluye ventana de **24 meses** — exclusiva de esta tabla en el ecosistema.

---

## 10. Queries de referencia

```sql
-- Clientes activos con OH! en mayo 2026
SELECT id, cant_con_toh_1m, mto_con_toh_1m, mto_prom_con_toh_1m,
       cant_con_online_toh_1m, cant_con_presencial_toh_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`
WHERE process_date = '2026-05-01'
  AND cant_con_toh_1m > 0;

-- Usuarios de Ágora activos (consumo + recargas)
SELECT id, cant_con_agora_1m, mto_con_agora_1m,
       cant_recarga_agora_1m, mto_recarga_agora_1m,
       cant_p2p_entrante_agora_1m, cant_p2p_saliente_agora_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`
WHERE process_date = '2026-05-01'
  AND (cant_con_agora_1m > 0 OR cant_recarga_agora_1m > 0);

-- Consumo OH! en restaurantes burguers y pollos
SELECT id, mto_con_toh_burger_king_1m, mto_con_toh_mcdonalds_1m,
       mto_con_toh_pardos_chicken_1m, mto_con_toh_norkys_1m,
       mto_con_toh_kfc_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`
WHERE process_date = '2026-05-01'
  AND (mto_con_toh_burger_king_1m > 0 OR mto_con_toh_pardos_chicken_1m > 0);

-- Clientes que pagan educación con Ágora (tendencia 12m)
SELECT id, cant_pago_utp_agora_12m, cant_pago_idat_agora_12m,
       cant_pago_ipae_agora_12m, cant_pago_innova_schools_agora_12m,
       mto_pago_utp_agora_12m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`
WHERE process_date = '2026-05-01'
  AND (cant_pago_utp_agora_12m > 0 OR cant_pago_idat_agora_12m > 0
    OR cant_pago_ipae_agora_12m > 0 OR cant_pago_innova_schools_agora_12m > 0);
```

---

## 11. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Clave: `id`** — para cruzar con otras tablas `ba_*`: `payment.id = retail.id_intercorp`.
3. **Ventana exclusiva `_24m`** — solo en esta tabla; para lealtad de largo plazo.
4. **`_1m` es sumable** entre particiones. `_3m` a `_24m` son acumulados.
5. **Tarjeta OH!** y **Ágora** son productos distintos — un cliente puede usar ambos independientemente.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_payment`*
