# Catálogo de Datos — `c_bin_card`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_transaction`
**Tabla completa:** `intercorp-data-storage-pv.master_transaction.c_bin_card`

---

## Descripción

Catálogo de **BINs de tarjetas bancarias** (Bank Identification Number). El BIN son los primeros 6 u 8 dígitos del número de tarjeta e identifican el banco emisor, la marca (VISA, MASTERCARD) y el tipo de tarjeta. Esta tabla permite clasificar el instrumento de pago de un cliente a partir del BIN sin necesidad de conocer el número completo de tarjeta.

Se usa para enriquecer las transacciones de `t_retail_transaction` y `t_transaction` con el banco y tipo de tarjeta del cliente.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 22,329 |
| Tamaño | ~743 KB |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `bin` | STRING | **Clave primaria**. Primeros 6 dígitos del número de tarjeta | Join con `itc_number_card_mask_bin_6` o `bin_card_id` en las tablas de transacciones |
| `banco` | STRING | Nombre del banco emisor de la tarjeta | Puede tener variaciones de escritura para el mismo banco (ej: "BANCO DE CREDITO DEL PERU" vs "Banco De Credito Del Peru") |
| `marca` | STRING | Marca de la tarjeta | Valores: VISA, MASTERCARD, AMERICAN EXPRESS, etc. |
| `card_type` | STRING | Tipo de tarjeta: DÉBITO / CRÉDITO | **SIEMPRE NULL** en los registros observados |
| `card_level` | STRING | Nivel/gama de la tarjeta: CLASSIC, GOLD, PLATINUM, SIGNATURE, etc. | **SIEMPRE NULL** en los registros observados |

---

## Reglas de negocio

1. **BIN como clave de enriquecimiento**: Hacer join con `t_transaction.bin_card_id` o con `t_retail_transaction` a través de la tabla de pagos `t_payment`.

2. **Mismo banco, múltiples entradas**: El BCP aparece con varios nombres distintos ("BANK OF CREDIT (BCP)", "Banco De Credito Del Peru", "BANCO DE CREDITO DEL PERU"). Para agrupar correctamente usar `c_entidades_financieras` como tabla normalizadora.

3. **BIN de 6 dígitos**: Esta tabla usa BIN de 6 dígitos. En transacciones modernas el BIN puede tener 8 dígitos — para mayor precisión usar `bin_card_8_id` y la versión extendida si existiera.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| `card_type` siempre NULL | El tipo débito/crédito no está poblado en esta tabla. Usar `payment_card_type` en `t_transaction` en su lugar. |
| `card_level` siempre NULL | La gama de tarjeta no está poblada. Usar `c_gamas_tarjetas_noibk` para clasificar gama basado en banco+marca+nivel. |
| Inconsistencia en nombres de banco | El mismo banco aparece con diferentes grafías. Necesita normalización para análisis comparativo. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.t_transaction` | `bin_card_id` = `c_bin_card.bin` | Obtener banco y marca de la tarjeta usada |
| `bi_ibk_casos_uso.c_entidades_financieras` | `banco` → `payment_bank` | Normalizar nombre del banco |
| `bi_ibk_casos_uso.c_gamas_tarjetas_noibk` | `banco` + `marca` | Obtener gama de tarjeta |

---

## Query de referencia

```sql
-- Enriquecer transacciones Izipay con banco y marca desde BIN
SELECT t.id, t.transaction_date, b.banco, b.marca,
  t.product_item_gross_amount
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
LEFT JOIN `intercorp-data-storage-pv.master_transaction.c_bin_card` b
  ON t.bin_card_id = b.bin
WHERE t.itc_process_date = '2026-01-30'
  AND t.transaction_date = t.itc_process_date;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_transaction.c_bin_card`*
