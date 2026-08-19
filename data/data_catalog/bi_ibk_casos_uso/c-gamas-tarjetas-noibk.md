# Catálogo de Datos — `c_gamas_tarjetas_noibk`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_ibk_casos_uso`
**Tabla completa:** `intercorp-data-storage-pv.bi_ibk_casos_uso.c_gamas_tarjetas_noibk`

---

## Descripción

Catálogo de **clasificación de gamas de tarjetas de bancos distintos a Interbank (IBK)**. Permite asignar una gama comercial (CLÁSICA, ORO, PLATINUM, SIGNATURE/BLACK, INFINITE) a cada combinación de banco + marca + nivel de tarjeta. Se usa para comparar el perfil socioeconómico de los clientes basado en el tipo de tarjeta con que pagan en las tiendas del grupo.

El campo `monto` en este catálogo refleja el volumen acumulado de consumo observado para esa combinación banco+marca+nivel en la fuente de referencia.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 25 |
| Tamaño | ~2.6 KB |
| Fuente | MANUAL - IBK |

---

## Contenido completo

| banco | marca | card_level | monto | gama_tarjeta |
|---|---|---|---|---|
| BANCO DE CREDITO DEL PERU | VISA | GOLD | 36,386,216 | ORO |
| SCOTIABANK PERU | VISA | GOLD | 6,563,843 | ORO |
| BANCO CONTINENTAL | VISA | GOLD | 120,483 | ORO |
| SCOTIABANK PERU | MASTERCARD | GOLD | 57,162 | ORO |
| BANCO DE CREDITO DEL PERU | VISA | CLASSIC | 14,938,994 | CLASICA |
| BANCO FALABELLA PERU | VISA | TRADITIONAL | 46,949,295 | CLASICA |
| BANCO CONTINENTAL | VISA | TRADITIONAL | 22,860,222 | CLASICA |
| BANCO DE CREDITO DEL PERU | VISA | TRADITIONAL | 16,812,610 | CLASICA |
| SCOTIABANK PERU | VISA | TRADITIONAL | 8,427,858 | CLASICA |
| BANCO RIPLEY | MASTERCARD | STANDARD | 25,908,662 | CLASICA |
| Caja Rural De Ahorro Y Credito Cat Peru | MASTERCARD | STANDARD | 10,640,892 | CLASICA |
| BANCO CONTINENTAL | MASTERCARD | STANDARD | 1,559,215 | CLASICA |
| BANCO DE CREDITO DEL PERU | AMERICAN EXPRES | AMERICAN EXPRESS | 8,435,467 | CLASICA |
| Cencosud | VISA | CLASSIC | 6,034,096 | CLASICA |
| BANCO CONTINENTAL | VISA | INFINITE | 33,906,498 | INFINITE |
| BANCO DE CREDITO DEL PERU | VISA | INFINITE | 21,664,377 | INFINITE |
| BANCO CONTINENTAL | VISA | PLATINUM | 18,633,250 | PLATINUM |
| SCOTIABANK PERU | VISA | PLATINUM | 17,297,709 | PLATINUM |
| BANCO DE CREDITO DEL PERU | VISA | PLATINUM | 218,754 | PLATINUM |
| BANCO CONTINENTAL | MASTERCARD | PLATINIUM | 1,896,163 | PLATINUM |
| BANCO CONTINENTAL | VISA | SIGNATURE | 55,038,789 | SIGNATURE |
| BANCO DE CREDITO DEL PERU | VISA | SIGNATURE | 49,780,396 | SIGNATURE |
| SCOTIABANK PERU | VISA | SIGNATURE | 12,594,675 | SIGNATURE |
| SCOTIABANK PERU | MASTERCARD | BLACK | 3,429,728 | SIGNATURE |
| BANCO CONTINENTAL | MASTERCARD | BLACK | 10,291,573 | SIGNATURE |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `banco` | STRING | Nombre del banco emisor | Join con `c_bin_card.banco` o `t_transaction.payment_bank` |
| `marca` | STRING | Marca de la tarjeta: VISA, MASTERCARD, AMERICAN EXPRESS | |
| `card_level` | STRING | Nivel del BIN/tarjeta: CLASSIC, TRADITIONAL, GOLD, PLATINUM, INFINITE, SIGNATURE, BLACK, STANDARD | Viene de `c_bin_card.card_level` (actualmente NULL) o de otra fuente |
| `monto` | INTEGER | Monto acumulado de consumo observado para esa combinación | Usado como referencia para el catálogo, no para análisis directo |
| `gama_tarjeta` | STRING | **Gama asignada**: CLASICA, ORO, PLATINUM, INFINITE, SIGNATURE | Campo de salida para segmentación socioeconómica |
| `load_date` | TIMESTAMP | Fecha de carga | 2025-01-30 |
| `creation_user` | STRING | Usuario | lmorales@inside.com.pe |
| `record_source` | STRING | Origen | MANUAL - IBK |

---

## Jerarquía de gamas (de menor a mayor)

| Gama | Niveles de tarjeta incluidos | Perfil aproximado |
|---|---|---|
| CLASICA | CLASSIC, TRADITIONAL, STANDARD, AMERICAN EXPRESS | Tarjeta básica, acceso masivo |
| ORO | GOLD | Segmento medio |
| PLATINUM | PLATINUM, PLATINIUM | Segmento medio-alto |
| INFINITE | INFINITE | Segmento alto (BBVA/BCP) |
| SIGNATURE | SIGNATURE, BLACK | Segmento premium |

---

## Reglas de negocio

1. **Solo bancos no-IBK**: El catálogo cubre BCP, BBVA, Scotiabank, Falabella, Ripley y otras entidades. Las tarjetas Interbank se clasifican por una lógica separada en los SPs de IBK.

2. **Combinación única banco+marca+card_level**: La clave del catálogo es la tripleta. No hay `card_level` solo porque el mismo nivel puede tener distinta gama según el banco.

3. **Carga manual**: Solo 25 registros. Cobertura limitada — combinaciones no mapeadas no tendrán `gama_tarjeta`.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Solo 25 registros | Cobertura muy limitada. Muchos bancos y niveles no están mapeados. |
| Error tipográfico | "PLATINIUM" (con i) vs "PLATINUM" — ambos valores existen en distintos registros, mapeados a PLATINUM |
| `card_level` en `c_bin_card` es NULL | La fuente esperada de `card_level` (c_bin_card) no tiene este campo poblado. El join puede estar roto en la práctica. |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.c_bin_card` | `banco`, `marca`, `card_level` | Obtener gama desde el BIN |
| `master_transaction.t_transaction` | `payment_bank` + `payment_card_brand` + `payment_card_type` | Asignar gama a transacciones Izipay |

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_ibk_casos_uso.c_gamas_tarjetas_noibk`*
