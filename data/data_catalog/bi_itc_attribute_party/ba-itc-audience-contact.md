# Catálogo de Datos — `ba_itc_audience_contact`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`

> **⚠️ TABLA SENSIBLE — DATOS PERSONALES (PII)**: Contiene información de identificación personal (nombre, dirección, fecha de nacimiento, dispositivo móvil). Campos de contacto (email, teléfono, celular) se almacenan como **hashes BYTES** — no en texto claro. Requiere autorización explícita para acceder.

---

## Descripción

Datos de contacto del cliente consolidados por empresa del Grupo Intercorp. Contiene información personal como nombre, dirección, email hasheado, teléfono hasheado, dispositivo móvil y flags de autorización de comunicación. Cada fila representa el perfil de contacto de un cliente en una empresa específica (`itc_company_id`), por lo que un cliente puede tener múltiples filas.

Es la tabla de referencia para activación en canales digitales: construcción de audiencias (email hash para Google Ads / Meta Ads), validación de opt-in y perfilado de contactabilidad.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~444M |
| Columnas | 48 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y partición

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |
| `id` | STRING | Documento de identidad del cliente. Campo clustered. ⚠️ PII |
| `itc_company_id` | STRING | ID de la empresa Intercorp que registró el contacto |
| `itc_company_name` | STRING | Nombre de la empresa Intercorp |

> Un cliente puede tener **múltiples filas** (una por cada `itc_company_id` con datos de contacto registrados).

---

## 2. Datos de contacto — email y teléfono hasheados ⚠️ PII hasheada

| Campo | Tipo | Descripción |
|---|---|---|
| `hash_email` | BYTES | Email del cliente hasheado (SHA256 u otro). No contiene email en claro. ⚠️ PII hasheada |
| `telephone` | BYTES | Teléfono (fijo) hasheado. ⚠️ PII hasheada |
| `cell_phone` | BYTES | Celular hasheado. ⚠️ PII hasheada |
| `contact_email_date` | DATETIME | Fecha de registro del email |
| `contact_cell_phone_date` | DATETIME | Fecha de registro del celular |
| `contact_email_update_date` | DATETIME | Fecha de última actualización del email |
| `contact_cell_phone_update_date` | DATETIME | Fecha de última actualización del celular |

---

## 3. Datos de nombre ⚠️ PII

| Campo | Tipo | Descripción |
|---|---|---|
| `first_name` | STRING | Primer nombre del cliente. ⚠️ PII |
| `midle_name` | STRING | Segundo nombre del cliente. ⚠️ PII. Nota: typo en nombre original (`midle`) |
| `name` | STRING | Nombre(s) del cliente. ⚠️ PII |
| `first_surname` | STRING | Primer apellido. ⚠️ PII |
| `second_surname` | STRING | Segundo apellido. ⚠️ PII |
| `last_name` | STRING | Apellidos del cliente. ⚠️ PII |
| `full_name` | STRING | Nombre completo concatenado. ⚠️ PII |
| `name_initials` | STRING | Iniciales del nombre |

---

## 4. Datos demográficos básicos ⚠️ PII

| Campo | Tipo | Descripción |
|---|---|---|
| `birth_date` | STRING | Fecha de nacimiento (almacenada como STRING). ⚠️ PII |
| `birth_year` | STRING | Año de nacimiento |
| `birth_month` | STRING | Mes de nacimiento |
| `age` | STRING | Edad calculada |
| `gender` | STRING | Género (`M`, `F`) |

---

## 5. Datos de ubicación ⚠️ PII

| Campo | Tipo | Descripción |
|---|---|---|
| `address` | STRING | Dirección de residencia registrada. ⚠️ PII |
| `country_id` | STRING | Código de país (ej: `PE`) |
| `city` | STRING | Ciudad |
| `zip_id` | STRING | Código postal |

---

## 6. Dispositivo móvil

| Campo | Tipo | Descripción |
|---|---|---|
| `mobile_device_brand` | STRING | Marca del dispositivo móvil (ej: `Samsung`, `Apple`) |
| `mobile_device_system` | STRING | Sistema operativo del dispositivo (ej: `Android`, `iOS`) |
| `mobile_device_ad` | STRING | ID de publicidad del dispositivo (GAID / IDFA) |
| `mobile_device_model` | STRING | Modelo del dispositivo |

---

## 7. Fechas de ciclo de vida del cliente

| Campo | Tipo | Descripción |
|---|---|---|
| `party_effective_date` | DATETIME | Fecha de alta del cliente en la empresa |
| `party_closed_date` | STRING | Fecha de baja del cliente (almacenada como STRING) |
| `flag_customer_identified` | BOOLEAN | `true` = cliente identificado con documento de identidad válido |

---

## 8. Flags de autorización (opt-in)

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_security_police_authorized` | BOOLEAN | `true` = el cliente autorizó la política de seguridad de datos |
| `flag_information_authorized` | BOOLEAN | `true` = el cliente autorizó el uso de su información personal |
| `flag_intercorp_authorized` | BOOLEAN | `true` = el cliente autorizó comunicaciones del grupo Intercorp |

> Para campañas de email o SMS: usar solo registros con `flag_intercorp_authorized = true`. Requerimiento de la Ley de Protección de Datos Personales (LPDP) del Perú.

---

## 9. Control de calidad y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_type` | STRING | Tipo de control DQ aplicado |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_priority_order` | STRING | Prioridad del control DQ |
| `dq_config_id` | STRING | ID de configuración DQ |
| `hk_diff` | BYTES | Hash diferencial del registro (detecta cambios entre cargas) |
| `record_source` | STRING | Sistema origen del dato de contacto |
| `update_date` | DATETIME | Fecha de última actualización del registro |
| `load_date` | DATETIME | Fecha y hora de carga |
| `creation_user` | STRING | SA que ejecutó la carga |

---

## 10. Queries de referencia

```sql
-- Audiencia con hash_email para activación en plataformas digitales
SELECT DISTINCT id, hash_email, itc_company_id
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`
WHERE process_date = '2026-05-01'
  AND hash_email IS NOT NULL
  AND flag_intercorp_authorized = true
  AND flag_information_authorized = true;

-- Contacto único por cliente (deduplica — toma la empresa con mayor prioridad)
SELECT id, hash_email, full_name, cell_phone, gender
FROM (
  SELECT id, hash_email, full_name, cell_phone, gender, itc_company_id,
    ROW_NUMBER() OVER (PARTITION BY id ORDER BY
      CASE itc_company_id WHEN '010' THEN 1 WHEN '025' THEN 2 ELSE 3 END,
      contact_email_update_date DESC) AS rn
  FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`
  WHERE process_date = '2026-05-01'
    AND hash_email IS NOT NULL
    AND flag_intercorp_authorized = true
) WHERE rn = 1;

-- Distribución de clientes con datos de contacto por empresa
SELECT itc_company_id, itc_company_name,
  COUNT(DISTINCT id)                                                         AS clientes_total,
  COUNTIF(hash_email IS NOT NULL)                                            AS con_email,
  COUNTIF(cell_phone IS NOT NULL)                                            AS con_celular,
  COUNTIF(flag_intercorp_authorized = true)                                  AS con_autorizacion,
  ROUND(COUNTIF(hash_email IS NOT NULL) * 100.0 / COUNT(DISTINCT id), 1)    AS pct_email
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`
WHERE process_date = '2026-05-01'
GROUP BY 1, 2
ORDER BY 3 DESC;

-- Clientes con dispositivo móvil para campañas in-app (GAID/IDFA disponible)
SELECT id, mobile_device_brand, mobile_device_system, mobile_device_ad
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`
WHERE process_date = '2026-05-01'
  AND mobile_device_ad IS NOT NULL
  AND flag_intercorp_authorized = true;

-- Cobertura de datos de contacto
SELECT
  COUNT(DISTINCT CASE WHEN hash_email IS NOT NULL THEN id END)      AS clientes_con_email,
  COUNT(DISTINCT CASE WHEN cell_phone IS NOT NULL THEN id END)      AS clientes_con_celular,
  COUNT(DISTINCT CASE WHEN mobile_device_ad IS NOT NULL THEN id END) AS clientes_con_dispositivo,
  COUNT(DISTINCT id)                                                 AS total_clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`
WHERE process_date = '2026-05-01';
```

---

## 11. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Un cliente puede tener múltiples filas**: Una por cada `itc_company_id`. Para universo único, usar `COUNT(DISTINCT id)` o deduplicar con `ROW_NUMBER()`.
3. **`flag_intercorp_authorized = true`**: Requerido para cualquier uso de datos de contacto en comunicaciones al cliente. Obligatorio por LPDP.
4. **`hash_email` es BYTES, no reversible**: No se puede obtener el email original. Usar directamente para matching en Google Ads / Meta Ads (aceptan hashed email en BYTES o STRING hex).
5. **Typo en campo `midle_name`**: El campo se llama `midle_name` (sin segunda `d`). Usar este nombre exacto en queries.
6. **`birth_date` y `party_closed_date` son STRING**: No son DATE/DATETIME — convertir con `PARSE_DATE` o `SAFE.PARSE_DATE` si se necesita operar con fechas.
7. **`mobile_device_ad`**: Contiene GAID (Android) o IDFA (iOS). Verificar que no sean IDs de privacidad (zeros o valores por defecto) antes de usar en campañas.
8. **Cruce con `ba_itc_attr_corporate`**: El campo `flag_dato_correo = 1` en `ba_itc_attr_corporate` indica disponibilidad de email — confirmar con esta tabla para obtener el `hash_email`.
9. **Datos de nombre con variaciones**: `first_name`, `last_name`, etc. pueden tener diferente capitalización o tildes según la empresa fuente. Normalizar antes de comparar.
10. **⚠️ Enmascarar en entornos no-productivos**: En dev/QA, reemplazar campos PII con valores sintéticos o truncados.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_audience_contact`*
