# Catálogo de Datos — `c_productos_escenciales_pos`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_placement`
**Tabla completa:** `intercorp-data-storage-pv.master_placement.c_productos_escenciales_pos`

---

## Descripción

Catálogo de **segmentos de comercios esenciales en el canal POS** (Izipay). Clasifica los segmentos MCC (Merchant Category Code) de `m_commerce` con un indicador binario (`clasificacion_escencial = 1/0`) para determinar si el giro del comercio cubre una necesidad básica del consumidor.

Complementa a `c_productos_escenciales_retail` (que clasifica por SKU en retail) aplicando la misma lógica de esencialidad pero sobre los comercios donde el cliente paga con Izipay.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 253 |
| Tamaño | ~8 KB |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `segmento` | STRING | **Clave de join**. Descripción del segmento MCC tal como aparece en `m_commerce.segment` | Join con `m_commerce.segment` |
| `clasificacion_escencial` | INTEGER | **1 = segmento esencial / 0 = no esencial** | Campo de salida principal |

---

## Ejemplos de segmentos clasificados

| Esenciales (clasificacion_escencial = 1) | No Esenciales (= 0) |
|---|---|
| BODEGAS, MINIMERCADOS | CASINOS, LOTERIAS, APUESTAS |
| RESTAURANTES | JOYERIA, RELOJERIA |
| FARMACIAS, BOTICAS | BARES, DISCOTECAS, KARAOKE |
| HOSPITALES, CLINICAS | AGENCIAS DE VIAJE |
| DOCTORES EN GENERAL | HOTELES, HOSTALES, MOTELES |
| SUPERMERCADOS | ROPA PARA HOMBRES |
| COLEGIOS Y NIDOS | SALAS DE JUEGO, VIDEO PUB |
| TRANSPORTES EN BUS | TIMESHARES |
| LUZ, AGUA, GAS | ALQUILER DE VEHICULOS |
| FERRETERIA | CLUBES Y EVENTOS DEPORTIVOS |
| PANADERIAS, PASTELERIAS, CAFET. | PARQUE DE DIVERSIONES |
| LABORATORIOS MEDICOS | NOVOTEL HOTELS |
| ESTACIONES DE SERVICIO, GRIFOS | LIBRERIAS |
| CARNICERIAS, AVICOLAS | INSTRUMENTOS MUSICALES |
| MUNICIPALIDADES, TRIBUTOS | MASCOTAS Y ACCESORIOS |

---

## Reglas de negocio

1. **Join con m_commerce**: `segmento` (esta tabla) ↔ `m_commerce.segment`. Con este join se puede etiquetar cada transacción Izipay como esencial o no esencial según el tipo de comercio.

2. **Perfil de clientes según gasto en esenciales**:
   - **Clientes de alta necesidad básica**: Alto % de transacciones en segmentos esenciales (alimentación, salud, transporte, educación)
   - **Clientes de consumo discrecional**: Más gasto en entretenimiento, viajes, lujo
   - **Clientes con enfermedades crónicas potenciales**: Frecuencia alta en FARMACIAS + HOSPITALES + LABORATORIOS

3. **253 segmentos MCC clasificados** de los 324 distintos en `m_commerce`. Los 71 no mapeados no tendrán clasificación.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Sin fechas de carga | Catálogo estático sin `load_date` ni `process_date` |
| Cobertura incompleta | 253 de 324 segmentos mapeados. ~71 segmentos de `m_commerce` sin clasificación |
| Categoría RESTAURANTES = esencial | La clasificación de restaurantes como esencial puede sobreestimar el consumo básico en clientes que comen fuera frecuentemente |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_placement.m_commerce` | `segmento` = `m_commerce.segment` | Obtener clasificación de esencialidad del comercio |
| `master_transaction.t_transaction` | Vía `m_commerce.commerce_id` | Clasificar pagos POS por esencialidad del comercio |

---

```sql
-- Perfil de gasto esencial vs. no esencial por cliente en POS Izipay
SELECT t.id,
  SUM(CASE WHEN pe.clasificacion_escencial = 1 THEN t.product_item_gross_amount ELSE 0 END) AS gasto_esencial,
  SUM(CASE WHEN pe.clasificacion_escencial = 0 THEN t.product_item_gross_amount ELSE 0 END) AS gasto_no_esencial,
  COUNT(CASE WHEN pe.clasificacion_escencial = 1 THEN 1 END) AS trx_esenciales,
  COUNT(CASE WHEN pe.clasificacion_escencial = 0 THEN 1 END) AS trx_no_esenciales
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
JOIN `intercorp-data-storage-pv.master_placement.m_commerce` mc
  ON t.commerce_id = mc.commerce_id
  AND mc.process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_placement.m_commerce`)
LEFT JOIN `intercorp-data-storage-pv.master_placement.c_productos_escenciales_pos` pe
  ON mc.segment = pe.segmento
WHERE t.itc_process_date = '2026-01-30'
  AND t.transaction_date = t.itc_process_date
GROUP BY 1;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_placement.c_productos_escenciales_pos`*
