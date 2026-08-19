# Queries de Referencia — Data Lakehouse ITC

Colección de queries SQL listos para ejecutar sobre las tablas del datalake.
Organizados por caso de uso de negocio. Todos apuntan al proyecto `intercorp-data-storage-pv`.

**Propósito:** servir como conocimiento base para el skill `bq-sql-translator` y el agente `Business Analyst`.

---

## Índice

| Archivo | Caso de uso | Tablas |
|---|---|---|
| [ventas-mensuales-empresa.sql](ventas-mensuales-empresa.sql) | Ventas totales y ticket promedio por empresa y mes | `ba_itc_attr_retail` |

---

## Principio clave — tabla cliente como fuente de totales de empresa

Las tablas `ba_itc_attr_*` están **a nivel de cliente** (`id_intercorp`).
Sumando los campos `_1m` de todos los clientes en una misma partición (`process_date`)
se obtienen los totales mensuales de la empresa:

```
SUM({empresa}_mto_trx_presencial_1m + {empresa}_mto_trx_digital_1m)
  → monto total de ventas de esa empresa en ese mes
```

Este es el patrón estándar para consultas de negocio sobre volumen de ventas.

---

*Actualizado: 2026-06-06 | Proyecto: `intercorp-data-storage-pv`*
