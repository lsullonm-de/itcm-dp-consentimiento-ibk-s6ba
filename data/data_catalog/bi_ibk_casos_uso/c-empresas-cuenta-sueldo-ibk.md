# Catálogo de Datos — `c_empresas_cuenta_sueldo_ibk`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_ibk_casos_uso`
**Tabla completa:** `intercorp-data-storage-pv.bi_ibk_casos_uso.c_empresas_cuenta_sueldo_ibk`

---

## Descripción

Catálogo de **empresas que depositan sueldos a través de Interbank (IBK)**. Se usa en el SP `sp_load_ibk_cuenta_sueldo_adobe.sql` para identificar clientes que reciben su sueldo en una cuenta Interbank, cruzando el nombre del comercio donde el cliente realiza transacciones con esta lista de empresas empleadoras.

Un cliente que tiene transacciones en comercios cuyo nombre (`business_description` en `t_transaction`) coincide con una empresa de esta lista es candidato a recibir oferta de cuenta sueldo IBK.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado | NO |
| Clusterizado | NO |
| Total de filas | 112 |
| Tamaño | ~6 KB |

---

## Glosario de Campos

| Campo | Tipo | Descripción | Observaciones |
|---|---|---|---|
| `nombre_comercial` | STRING | **Clave de búsqueda**. Nombre comercial de la empresa | Join aproximado con `t_transaction.business_description` o `m_commerce.business_commercial_name` |
| `razon_social` | STRING | Razón social / RUC de la empresa empleadora | Algunos registros tienen NULL en razón social |
| `rubro` | STRING | Tipo de negocio / rubro de la empresa | Ej: Bar, Café y Postres, Ceviche, Restaurante, etc. |

---

## Ejemplos de empresas incluidas

| nombre_comercial | razon_social | rubro |
|---|---|---|
| Fulana Garden Bar | INSIGNIA CORP S.A.C. | Bar |
| Chef Karaoke | INVERSIONES TURISTICAS AQP S.A.C. | Bar |
| 900 Café Bar | CHICLAYO CAFE S.A.C. | Café y Postres |
| La Mora | LAUGEN S.A.C. | Café y Postres |
| Big Ben California | NEGOCIOS DE PLAYA S.A.C. | Ceviche |
| Manta | DECALSA S.A.C | Ceviche |
| MAP Café | NULL | Café y Postres |

---

## Reglas de negocio

1. **Lógica de matching no exacta**: El join entre el nombre comercial de esta tabla y `business_description` en `t_transaction` generalmente requiere `LIKE` o coincidencia aproximada, ya que los nombres pueden tener variaciones de escritura.

2. **Uso en caso de uso IBK**: Este catálogo es específico del SP de cuenta sueldo IBK (`sp_load_ibk_cuenta_sueldo_adobe.sql`). Su propósito es identificar prospectos para productos financieros, no para análisis de consumo general.

3. **Catálogo manual y limitado**: 112 registros. Cubre principalmente el sector de gastronomía/entretenimiento como empleadores que pagan via IBK.

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| `razon_social` con NULL | Algunos registros no tienen la razón social registrada |
| Nombres duplicados | "Fulana Garden Bar" aparece con dos razones sociales distintas (INSIGNIA CORP S.A.C. vs INSIGNIA CORP SAC) |
| "La Mora" con 3 razones sociales | El mismo nombre comercial puede tener múltiples entidades legales |
| Sin fechas de carga | No hay trazabilidad temporal del catálogo |
| Cobertura limitada | 112 empresas es una muestra muy pequeña del universo de empresas que pagan via IBK |

---

## Relaciones con otras tablas

| Tabla | Campo de join | Propósito |
|---|---|---|
| `master_transaction.t_transaction` | `nombre_comercial` ~ `business_description` | Identificar clientes de empresas que pagan sueldo via IBK |
| `master_placement.m_commerce` | `nombre_comercial` ~ `business_commercial_name` | Buscar el comercio en el maestro |

---

```sql
-- Identificar clientes que trabajan en empresas del catálogo (via transacciones Izipay)
SELECT DISTINCT t.id, c.nombre_comercial, c.rubro
FROM `intercorp-data-storage-pv.master_transaction.t_transaction` t
JOIN `intercorp-data-storage-pv.bi_ibk_casos_uso.c_empresas_cuenta_sueldo_ibk` c
  ON UPPER(t.business_description) LIKE CONCAT('%', UPPER(c.nombre_comercial), '%')
WHERE t.itc_process_date = '2026-01-30'
  AND t.transaction_date = t.itc_process_date;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_ibk_casos_uso.c_empresas_cuenta_sueldo_ibk`*
