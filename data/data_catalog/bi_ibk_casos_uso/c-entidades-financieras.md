# Catálogo de Datos — `c_entidades_financieras`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_ibk_casos_uso`
**Tabla completa:** `intercorp-data-storage-pv.bi_ibk_casos_uso.c_entidades_financieras`

---

## Descripción

Catálogo de **normalización de entidades financieras**. Mapea las múltiples variantes del nombre de un mismo banco (tal como aparecen en la fuente de datos Izipay) hacia un nombre canónico normalizado. Resuelve el problema de inconsistencia en el campo `payment_bank` de `t_transaction` y `t_retail_transaction`, donde el mismo banco puede aparecer con diferentes grafías.

Fue cargado manualmente por el equipo de IBK el 2025-01-30.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 66 |
| Tamaño | ~6 KB |
| Fuente | MANUAL - IBK (carga manual) |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `payment_bank` | STRING | **Clave de búsqueda**. Nombre del banco tal como aparece en `t_transaction.payment_bank` | Puede tener variaciones de mayúsculas/minúsculas |
| `entidad_financiera` | STRING | **Nombre normalizado** del banco | Forma canónica para agrupar en análisis |
| `load_date` | TIMESTAMP | Fecha de carga | 2025-01-30 |
| `creation_user` | STRING | Usuario que cargó | lmorales@inside.com.pe |
| `record_source` | STRING | Origen | MANUAL - IBK |

---

## Contenido — Mapeos principales

| payment_bank (fuente) | entidad_financiera (normalizado) |
|---|---|
| BCP / BANK OF CREDIT (BCP) / Banco De Credito Del Peru | BANCO DE CREDITO DEL PERU |
| BBVA / BBVA BANCO CONTINENTAL / Bbva Banco Continental / BANCO CONTINENTAL | BANCO CONTINENTAL |
| INTERBANK / INTERBANK - BANCO INTERNACIONAL DEL PERU | BANCO INTERNACIONAL DEL PERU |
| SCOTIABANK PERU S.A.A. / Scotiabank Peru | SCOTIABANK PERU |
| BANCO FALABELLA PERU S.A. / Banco Falabella Peru | BANCO FALABELLA PERU |
| CREDISCOTIA FINANCIERA S.A. | CREDISCOTIA FINANCIERA |
| MIBANCO BANCO DE LA MICROEMPRESA S.A. / Mibanco | MIBANCO |
| CITIBANK / CITIBANK DEL PERU S.A. | CITIBANK DEL PERU |
| BANCO RIPLEY S.A. / Banco Ripley | BANCO RIPLEY |
| BANCO INTERAMERICANO DE FINANZAS S.A.E.M.A. | BANCO INTERAMERICANO DE FINANZAS S.A.E.M.A. |
| Tarjeta Oh | TARJETA OH |
| DINNERS | DINNERS |
| Cencosud | Cencosud |

---

## Reglas de negocio

1. **Catálogo manual**: Esta tabla fue creada y mantenida manualmente. Si aparecen nuevos bancos en `t_transaction`, el mapeo puede estar incompleto.

2. **Case-sensitive**: El join con `payment_bank` de `t_transaction` debe considerar que hay variantes en mayúsculas/minúsculas. Usar `UPPER()` o `LOWER()` para join robusto.

3. **Bancos sin mapeo**: Si `payment_bank` de una transacción no aparece en esta tabla, la transacción no tendrá `entidad_financiera`. Usar `LEFT JOIN` y manejar NULLs.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Carga manual única | Solo una carga (2025-01-30). No hay proceso automático de actualización. |
| Bancos no cubiertos | Pueden existir bancos en `t_transaction` no mapeados aquí (Visa Local, Sodexo, Edenred, etc.) |
| Duplicados por grafía | Hay registros como "Banco De Credtio Del Peru" (con error tipográfico) → BANCO DE CREDITO DEL PERU |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.t_transaction` | `payment_bank` | Normalizar nombre del banco emisor |
| `master_transaction.t_retail_transaction` | (via `t_payment.payment_bank`) | Normalizar banco en pagos retail |

---

```sql
-- Normalizar banco en transacciones Izipay
SELECT t.id, t.transaction_date,
  COALESCE(e.entidad_financiera, t.payment_bank) AS banco_normalizado,
  COUNT(*) AS transacciones
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
LEFT JOIN `intercorp-data-storage-pv.bi_ibk_casos_uso.c_entidades_financieras` e
  ON t.payment_bank = e.payment_bank
WHERE t.itc_process_date = '2026-01-30' AND t.transaction_date = t.itc_process_date
GROUP BY 1,2,3;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_ibk_casos_uso.c_entidades_financieras`*
