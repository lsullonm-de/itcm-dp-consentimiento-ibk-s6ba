# Catálogo de Datos — `iden_itc_party`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `master_party`
**Tabla completa:** `intercorp-data-storage-pv.master_party.iden_itc_party`

---

## Descripción

Tabla central del **modelo de identidad Intercorp**. Vincula el `party_id` (identificador único y universal de una persona en el ecosistema Intercorp) con los identificadores propios que cada empresa del grupo maneja para ese mismo cliente.

Cada empresa del grupo asigna su propio ID a sus clientes al momento del registro (Inkafarma tiene su ID, Promart el suyo, SPSA el suyo, etc.). Esta tabla resuelve el problema de fragmentación de identidad: dado el `id` (DNI/CE/RUC) de una persona, permite obtener su `party_id` para consultar atributos, segmentaciones y datos consolidados del ecosistema. O viceversa: dado un `party_id`, obtener los IDs que tiene en cada empresa.

> **Concepto clave:** `id` = documento de identidad del cliente (DNI, CE, RUC). `party_id` = identificador interno corporativo único del cliente en Intercorp. Son los dos identificadores que se usan para hacer joins entre las tablas de transacciones y las tablas de atributos.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | **NO** — sin campo de partición |
| Clusterizado | NO |
| Total de filas | ~467,725,992 |
| Tamaño | ~0 bytes activos (tabla vacía en snapshot bq show, pero tiene datos reales) |
| Última fecha de proceso | 2026-03-10 |
| Empresas cubiertas | 22 (`itc_company_id` distintos) |
| Tipos de party | 12 (`party_type_id` distintos) |

> **Atención:** La tabla NO tiene partición. Cualquier query sin filtro hace full scan de 467M registros. Siempre filtrar por `process_date` y/o `itc_company_id`.

---

## Perfil de datos

| Métrica | Valor |
|---|---|
| Total registros | 467,725,992 |
| `party_id` distintos | 354,383,439 |
| `id` distintos | 133,323,149 |
| Empresas (`itc_company_id`) | 22 |
| Tipos de party (`party_type_id`) | 12 |
| Última fecha de carga | 2026-03-10 |
| Frecuencia de carga | Diaria incremental (varía de 42K a 5.2M registros/día) |

### Distribución por empresa y tipo (top registros)

| itc_company_id | party_type_id | Registros | Empresa aproximada |
|---|---|---|---|
| 022 | -1 | 64,902,424 | (sin tipo definido) |
| 022 | 01 | 48,471,111 | |
| 012 | 01 | 47,789,516 | |
| 1000 | 01 | 26,885,261 | (código especial ITC) |
| 002 | 01 | 26,745,768 | |
| 010 | 01 | 25,641,262 | SPSA |
| 025 | 01 | 24,934,651 | Inkafarma |
| 048 | 01 | 24,932,534 | Mifarma |
| 074 | 01 | 24,930,634 | Farmacias Peruanas |
| 011 | 01 | 18,086,983 | Tiendas Peruanas |
| 024 | 01 | 15,290,390 | Promart |
| 000 | 01 | 5,411,030 | Interbank |
| 086 | 01 | 3,676,653 | Izipay |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `process_date` | DATE | Fecha del snapshot de carga | No es campo de partición — filtrar explícitamente. Usar `MAX(process_date)` para el estado actual |
| `itc_company_id` | STRING | Código de la empresa Intercorp que registra la identidad | Join con `c_itc_company.itc_company_id` |
| `party_id` | STRING | **Identificador único del cliente en el ecosistema Intercorp** | 354M distintos. Clave para joins con tablas de atributos (`ba_itc_attr_*`) |
| `id` | STRING | **Documento de identidad del cliente** (DNI, CE, RUC) | 133M distintos. Clave para joins con tablas de transacciones (`t_retail_transaction.id`, `t_transaction.id`) |
| `load_date` | DATETIME | Timestamp de carga del registro | |
| `party_type_id` | STRING | Tipo de party | `'01'` = persona natural, `'02'` = empresa/RUC, `'03'` = otros, `'-1'` = sin tipo (empresa 022) |

---

## Reglas de negocio

1. **Un `id` puede tener múltiples `party_id`?** En teoría no — el `party_id` es único por persona. Sin embargo, en la práctica puede haber duplicados por empresa si el mismo DNI fue registrado en distintas compañías en distintos momentos. Verificar con `GROUP BY id HAVING COUNT(DISTINCT party_id) > 1`.

2. **Un `party_id` tiene múltiples registros**: Una fila por cada `itc_company_id` donde la persona tiene registro. Un cliente que compra en SPSA, Inkafarma y usa Izipay tendrá 3+ filas con el mismo `party_id`.

3. **`id` es el puente entre transacciones y atributos**: Las tablas de transacciones (`t_retail_transaction`, `t_transaction`) usan `id` (documento). Las tablas de atributos (`ba_itc_attr_*`) también usan `id`. Esta tabla permite además obtener el `party_id` para cruzar con sistemas de identidad avanzados.

4. **Sin partición — full scan**: No hay campo de partición. Siempre incluir `WHERE process_date = (SELECT MAX(process_date) FROM ...)` y/o `WHERE itc_company_id = 'XXX'` para reducir costo.

5. **Carga incremental diaria**: El volumen de carga varía (42K–5.2M registros/día). El proceso actualiza registros de todas las empresas en ciclos distintos.

6. **`party_type_id = '-1'`**: La empresa 022 tiene 64.9M registros con tipo `-1` (sin tipo definido). Puede indicar un tipo especial o registros migrados de un sistema anterior.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| Sin partición | Full table scan en queries sin filtro. Costo alto en análisis ad-hoc |
| IDs con múltiples party_id | Posibles duplicados si el mismo DNI fue registrado en distintas empresas con diferentes party_id |
| party_type_id = '-1' | 64.9M registros de empresa 022 con tipo inválido/indefinido |
| Volumen diario variable | La carga incremental varía significativamente — no todos los días se cargan todas las empresas |
| `id` NULL potencial | No verificado si hay registros sin `id` — validar antes de joins |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Dirección | Propósito |
|---|---|---|---|
| `master_transaction.t_retail_transaction` | `id` | iden_itc_party.id = t_retail_transaction.id | Obtener `party_id` para un comprador retail |
| `master_transaction.t_transaction` | `id` | iden_itc_party.id = t_transaction.id | Obtener `party_id` para un pagador Izipay |
| `bi_itc_attribute_party.ba_itc_attr_*` | `id` | Join directo por `id` | Combinar transacciones con atributos del cliente |
| `master_party.c_itc_company` | `itc_company_id` | Decodificar empresa | |

---

## Queries de referencia

```sql
-- Obtener party_id de un cliente dado su DNI, para todas sus empresas
SELECT itc_company_id, party_id, party_type_id
FROM `intercorp-data-storage-pv.master_party.iden_itc_party`
WHERE id = '12345678'
  AND process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_party.iden_itc_party`);

-- Verificar si un cliente está en múltiples empresas del grupo
SELECT id, COUNT(DISTINCT itc_company_id) AS empresas,
  STRING_AGG(DISTINCT itc_company_id ORDER BY itc_company_id) AS lista_empresas
FROM `intercorp-data-storage-pv.master_party.iden_itc_party`
WHERE process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_party.iden_itc_party`)
  AND itc_company_id IN ('010','011','024','025','048','086')
GROUP BY 1
HAVING COUNT(DISTINCT itc_company_id) >= 3
ORDER BY empresas DESC;

-- Clientes de Inkafarma con sus transacciones retail SPSA
SELECT t.id, t.transaction_date, t.itc_company_id,
  SAFE_CAST(t.product_item_amount AS FLOAT64) AS monto
FROM `intercorp-data-storage-pv.master_transaction.t_retail_transaction` t
WHERE t.transaction_date = '2026-01-30'
  AND t.itc_company_id = '010'  -- SPSA
  AND t.id IN (
    SELECT id FROM `intercorp-data-storage-pv.master_party.iden_itc_party`
    WHERE itc_company_id = '025'  -- Inkafarma
      AND process_date = (SELECT MAX(process_date) FROM `intercorp-data-storage-pv.master_party.iden_itc_party`)
  );
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.master_party.iden_itc_party`*
