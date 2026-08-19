# Catálogo de Datos — `ba_itc_attr_demographic`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic`

---

## Descripción

Atributos **demográficos y socioeconómicos** del cliente Intercorp. Contiene información personal (edad, género, estado civil, hijos), geográfica (ubigeo, distrito, departamento, coordenadas), laboral (empresa, condición, salario estimado), NSE (nivel socioeconómico), generación y pertenencia al ecosistema Intercorp como colaborador.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la info del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~40M |
| Columnas | 45 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes |
| `id` | STRING | Documento de identidad del cliente. ⚠️ Usa `id`, no `id_intercorp` |
| `version` | STRING | Versión del registro demográfico |
| `flag_inferido` | INTEGER | 1 = datos inferidos estadísticamente (no declarados directamente) |
| `record_source` | STRING | Origen del registro |
| `load_date` | TIMESTAMP | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |
| `dq_flag_ind` | INTEGER | Flag de control de calidad |
| `dq_control_msg` | INTEGER | Mensaje de control de calidad |
| `dq_config_id` | INTEGER | ID de configuración DQ |

---

## 2. Datos Personales

| Campo | Tipo | Descripción |
|---|---|---|
| `fecha_nacimiento` | DATE | Fecha de nacimiento del cliente |
| `edad` | INTEGER | Edad en años al momento del snapshot |
| `genero` | STRING | Género (`"M"` = Masculino, `"F"` = Femenino) |
| `estado_civil` | STRING | Estado civil (`"Soltero"`, `"Casado"`, `"Divorciado"`, `"Viudo"`) |
| `nacionalidad` | STRING | Nacionalidad del cliente |
| `pais_procedencia` | STRING | País de procedencia |
| `generacion` | STRING | Generación según año de nacimiento (`"Millennials"`, `"Gen Z"`, `"Baby Boomers"`, `"Gen X"`, `"Silenciosa"`) |

---

## 3. Hijos y Familia

| Campo | Tipo | Descripción |
|---|---|---|
| `cantidad_hijos` | INTEGER | Número de hijos registrados |
| `flag_tiene_hijo` | INTEGER | 1 = tiene al menos un hijo |
| `flag_tiene_hijo_pequeno` | INTEGER | 1 = tiene al menos un hijo pequeño (bebé / infante) |
| `id_conyuge` | STRING | Documento de identidad del cónyuge (si está en el grupo) |
| `flag_conyuge_cliente` | BOOLEAN | `true` = el cónyuge también es cliente Intercorp |

---

## 4. Nivel Socioeconómico (NSE)

| Campo | Tipo | Descripción |
|---|---|---|
| `nse` | STRING | NSE agregado: `"A"`, `"B"`, `"C"`, `"D"`, `"E"` |
| `nse_desagregado` | STRING | NSE granular: `"A1"`, `"A2"`, `"B1"`, `"B2"`, `"C1"`, `"C2"`, etc. |
| `id_manzana` | STRING | ID de manzana catastral — unidad geográfica base para asignar NSE |

> El NSE se asigna a nivel de manzana catastral (`id_manzana`), no es declarado individualmente por el cliente.

---

## 5. Geolocalización

| Campo | Tipo | Descripción |
|---|---|---|
| `ubigeo` | STRING | Código INEI 6 dígitos (2=depto + 2=provincia + 2=distrito) |
| `departamento` | STRING | Nombre del departamento |
| `provincia` | STRING | Nombre de la provincia |
| `distrito` | STRING | Nombre del distrito |
| `latitud_distrito` | FLOAT | Latitud del centroide del distrito |
| `longitud_distrito` | FLOAT | Longitud del centroide del distrito |
| `macroregion_inei` | STRING | Macroregión INEI (ej: `"Lima"`, `"Sierra Sur"`, `"Costa Norte"`, `"Selva"`) |

---

## 6. Datos Laborales

| Campo | Tipo | Descripción |
|---|---|---|
| `condicion_laboral` | STRING | Condición laboral (`"Dependiente"`, `"Independiente"`, `"Sin actividad"`) |
| `nombre_empresa_labora` | STRING | Empresa donde trabaja el cliente |
| `cantidad_empresas_planillas` | INTEGER | Número de empresas en cuya planilla ha figurado el cliente |
| `salario_afp` | STRING | Rango de salario estimado según AFP (por tramos) |
| `salario_itc` | STRING | Rango de salario estimado según Intercorp (por tramos) |
| `nivel_educativo` | STRING | Nivel educativo máximo alcanzado |
| `profesion` | STRING | Profesión u ocupación |

---

## 7. Relación con Intercorp como Colaborador

| Campo | Tipo | Descripción |
|---|---|---|
| `fecha_ingreso_intercorp` | DATE | Fecha de ingreso al grupo como colaborador |
| `flag_colaborador_intercorp` | BOOLEAN | `true` = colaborador activo del grupo Intercorp |
| `flag_ex_colaborador_intercorp` | BOOLEAN | `true` = ex colaborador del grupo |
| `periodo_baja_ex_colaborador_intercorp` | STRING | Período en que dejó de ser colaborador |
| `ult_empresa_ex_colaborador_intercorp` | STRING | Última empresa Intercorp en la que trabajó |
| `flag_colaborador_ifs` | BOOLEAN | `true` = colaborador de Intercorp Financial Services |

---

## 8. Queries de referencia

```sql
-- Perfil demográfico clientes mayo 2026
SELECT genero, generacion, nse, departamento, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic`
WHERE process_date = '2026-05-01'
GROUP BY 1, 2, 3, 4 ORDER BY clientes DESC;

-- Clientes con hijos pequeños en Lima (campañas bebés)
SELECT id, edad, genero, nse, distrito
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic`
WHERE process_date = '2026-05-01'
  AND flag_tiene_hijo_pequeno = 1
  AND departamento = 'Lima';

-- Distribución NSE por macroregión
SELECT macroregion_inei, nse, COUNT(DISTINCT id) AS clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic`
WHERE process_date = '2026-05-01'
GROUP BY 1, 2 ORDER BY clientes DESC;

-- Cruce demográfico + corporate: millennials con OH!
SELECT d.id, d.generacion, d.nse, d.distrito,
       c.flag_cliente_foh, c.flag_cliente_spsa
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic` d
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_corporate` c
  ON d.id = c.id AND d.process_date = c.process_date
WHERE d.process_date = '2026-05-01'
  AND d.generacion = 'Millennials'
  AND c.flag_cliente_foh = 1;
```

---

## 9. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Clave: `id`** — para cruzar con otras `ba_*`: `demog.id = retail.id_intercorp`.
3. **Sin ventanas temporales** — snapshot mensual del estado demográfico actual.
4. **`flag_inferido = 1`** = datos estimados estadísticamente, no declarados por el cliente.
5. **`nse`** se asigna a nivel de manzana catastral, no a nivel individual.
6. **`ubigeo`** código INEI 6 dígitos. Primeros 2 = departamento.
7. NULL en campos laborales = dato no disponible.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Última partición: `2026-05-01` | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_demographic`*
