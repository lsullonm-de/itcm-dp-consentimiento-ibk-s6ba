# Estándar: Capas de Datos — Data Platform ITC

> **Última actualización:** 2026-03-05
> **Plataforma:** `dp` (Data Platform) — BigQuery + Cloud Storage (GCP)

---

## 1. Arquitectura de Zonas de Datos

La plataforma de datos corporativa de ITC está organizada en tres zonas. Cada zona tiene un propósito, proyecto GCP y convenciones de naming propios.

```
Sources → RAW → Master → Business / Explotación → Consumo
```

| Zona | Proyecto GCP | Propósito |
|---|---|---|
| RAW | `[env]-[company]-data-storage` | Ingesta sin transformación desde sistemas origen |
| Master | `[env]-[company]-data-storage` | Estandarización y homologación de entidades de negocio |
| Business | `[env]-[company]-data-storage` | Explotación, modelos analíticos y dashboards |
| Datos sensibles | `prd-[company]-data-sensitive` | Tablas con PII/datos críticos encriptados |

---

## 2. Zona RAW

### Lineamientos de carga

1. Todo proceso de carga RAW considera la ingesta desde la fuente a Cloud Storage y luego a una tabla BigQuery. La historia se mantiene en Storage y solo se conservan 3 a 6 meses en BigQuery (definir con el arquitecto según volumetría).
2. Los archivos en Cloud Storage se cargan **tal cual** el formato origen (CSV, TXT, etc.). No se transforman.
3. Los **nombres de tablas y columnas** se respetan tal como vienen del sistema origen — el estándar de nomenclatura ITC **no aplica en capa RAW**. Solo aplica desde Master en adelante.
4. Los datos se carguen siempre en tipo **STRING**, excepto `load_date` y `process_date` (tipo fecha).
5. Todas las tablas RAW deben **particionarse** por `process_date` o campo de fecha mandatorio.
6. Los campos PII (datos sensibles: DNI, teléfono, correo, nombre, sueldo, etc.) se almacenan **encriptados** usando `AEAD.ENCRYPT` con la llave del catálogo `config_protected_data`. Ver [sección de encriptación](#5-encriptación-de-datos-sensibles).

### Naming de datasets RAW

```
raw_<application>[_<domain>]
```

| Variable | Descripción | Ejemplo |
|---|---|---|
| `application` | Nombre del sistema/aplicación origen — minúsculas, abreviaturas permitidas | `sap`, `dynamics_crm`, `as400`, `peoplesoft` |
| `domain` | (Opcional) Dominio si el sistema tiene demasiadas tablas | `ventas`, `persona` |

**Ejemplos:** `raw_sap_persona`, `raw_salesforce_venta`, `raw_dynamics_crm`, `raw_peoplesoft`, `raw_as400`

### Datasets auxiliares RAW

| Dataset | Propósito |
|---|---|
| `raw_stage` | Tablas temporales y procedimientos almacenados de apoyo a la carga RAW. Evita re-cálculos. |

---

## 3. Zona Master

### Lineamientos de carga

- Los datos se estandarizan y homologan al modelo corporativo de entidades de negocio (cliente, producto, transacción, lugar).
- Los procedimientos almacenados (SP) se crean en el proyecto `data-operation` en el dataset `master_stage`.
- Se aplican las reglas de nomenclatura ITC (prefijos de tabla, columnas en minúsculas, sin abreviaturas en nombres de tabla finales).

### Naming de datasets Master

```
master_<domain>
```

| Domain | Descripción |
|---|---|
| `master_party` | Personas (individuales, organizaciones, empleados) |
| `master_customer` | Clientes y cuentas |
| `master_product` | Productos, catálogos, precios, promociones |
| `master_transaction` | Transacciones, pagos, ventas |
| `master_place` | Lugares y locales |
| `master_stage` | Tablas temporales y SPs — no contiene datos finales del modelo |

### Prefijos de tablas en zona Master

| Prefijo | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `m_` | Tabla maestra | Entidades clave del negocio (dimensiones) | `m_customer`, `m_product`, `m_place` |
| `c_` | Catálogo | Listas de valores/dominios (código + descripción) | `c_identification_document_type`, `c_campaign` |
| `t_` | Transacción | Eventos/interacciones de la persona con la empresa | `t_transaction`, `t_payment`, `t_sale` |
| `h_` | Hash/equivalencia | Códigos de origen mapeados a identificadores del modelo | `h_party` |
| `s_` | Snapshot | Fotos periódicas (daily/monthly) de entidades | `s_customer_monthly`, `s_account_daily` |
| `iden_` | Identificador compartido | Identificadores compartidos a nivel de Grupo Intercorp | `iden_party`, `iden_party_digital` |
| `aux_` | Auxiliar | Tablas de apoyo con datos precalculados (persisten) | `aux_customer_account` |
| `tmp_` | Temporal | Tablas de trabajo de ámbito del proceso o malla | `tmp_ecai_solicitud` |
| `v_` | Vista | Vistas de consumo para usuarios finales | `v_party_individual` |

---

## 4. Zona Business / Explotación

### Lineamientos de carga

- Cada área consumidora define sus propias reglas de negocio.
- No se realizan transformaciones en tiempo de ejecución — los datos deben estar listos para consumo.
- Los modelos analíticos (ML) usan `ba_`; los dashboards/reportes usan `bi_` o `dv_`.

### Naming de datasets Business

```
[prefijo_zona]_<use_case>
```

| Dataset | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `bi_<use_case>` | Visualización/Explotación | Tablas para reportes y dashboards | `bi_priorizacion_lead`, `bi_venta` |
| `ba_<use_case>` | Analítica avanzada | Tablas input/output de modelos analíticos | `ba_perfil_cliente`, `ba_priorizacion_lead` |
| `dq_<use_case>` | Calidad de datos | Controles y reglas de calidad sobre un caso de uso | `dq_cliente_unico` |

### Prefijos de tablas en zona Business

| Prefijo | Tipo | Descripción | Ejemplo |
|---|---|---|---|
| `bm_` | Datamart | Explotación interna de áreas de negocio | `bm_campaign`, `bm_riesgo` |
| `ba_` | Analítica | Inputs/outputs de modelos analíticos e IA | `ba_customer_loyalty`, `ba_itc_attr_purchase_prediction` |
| `dv_` | Visualización | Tablas para dashboards, reportes y usuarios finales | `dv_loyalty_segmentacion`, `dv_profiling_employee` |
| `vm_` | Vista materializada | Agrupaciones precalculadas para dashboards | `vm_venta_producto` |
| `v_` | Vista | Vistas de consumo | `v_loyalty_summary` |

---

## 5. Campos de Auditoría y Calidad

Todas las tablas finales del modelo de datos (Master y Business) deben incluir los siguientes campos:

### Campos de auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `load_date` | TIMESTAMP | Fecha/hora de inserción del registro en la BD |
| `record_source` | STRING | Aplicativo/sistema origen de los datos |
| `creation_user` | STRING | Usuario/SA del proceso de carga que creó el registro |

### Campos de calidad de datos (DQ)

| Campo | Tipo | Descripción |
|---|---|---|
| `dq_flag_ind` | BOOLEAN | `true` = registro válido, `false` = incumple reglas de calidad |
| `dq_control_msg` | STRING | Detalle de columnas/reglas que no cumplieron las validaciones |
| `dq_config_id` | STRING | ID de metadatos del proceso de calidad asociado al registro |

---

## 6. Cloud Storage — Nomenclatura y Estructura

### Naming de buckets

| Tipo de bucket | Patrón | Ejemplo |
|---|---|---|
| RAW (por sistema origen) | `[env]-raw-[source_system]-[random]` | `dev-raw-as400-kn95` |
| Master | `[env]-master-[random]` | `dev-master-kn95` |
| Business BI | `[env]-bi-[use_case]-[random]` | `dev-bi-loyalty-kn95` |
| Output modelo analítico | `[env]-ba-[use_case]-[random]` | `dev-ba-priorizacionlead-kn95` |
| Staging MLOps | `[env]-stg-mlops-[use_case]-[random]` | `dev-stg-mlops-priorizacionlead-kn95` |
| Sandbox | `[env]-sand-[use_case]-[random]` | `dev-sand-segmentacion-kn95` |

Nota: `random` es una secuencia alfanumérica que diferencia buckets por empresa/instancia (ej: `kn95`, `ia24`).

### Estructura de directorios en bucket RAW

```
gs://[env]-raw-[source]-[random]/
├── data/
│   ├── input/
│   │   └── [table_name]/
│   │       └── [yyyymmdd]/           ← período de datos
│   │           └── [yyyymmddHHMMSS]_[application]_[table_name].[ext]
│   └── procesado/
│       └── [table_name]/
│           └── [yyyymmdd]/
├── code/                             ← scripts SQL o de aplicación
├── reject/                           ← registros rechazados en carga
├── archive/                          ← backups operativos
└── logs/                             ← logs de ejecución de pipelines
```

**Ejemplo de archivo:** `gs://dev-pe-iter-samp-ia24/data/input/202310/20231025/20231025040004_samp_cuenta.csv`

**Convención de nombre de archivo:** `[YYYYMMDDHHMMSS]_[application]_[table_name].[ext]`

### Lineamientos Cloud Storage

- Los archivos de la capa RAW se cargan en formato **CSV o TXT** con separador `|` y datos entre comillas.
- Mantener los **últimos 12 meses en almacenamiento Estándar**; el resto de historia en **Coldline**.
- Inhabilitar el **acceso público** en todos los buckets.
- Un bucket por cada **sistema origen** (RAW); un solo bucket para todo el modelo Master.

---

## 7. Encriptación de Datos Sensibles

### Lineamientos

1. Los campos PII y críticos (DNI, correo, teléfono, nombre, sueldo, cuenta, tarjeta, entre otros) se encriptan desde la capa RAW.
2. Las tablas con información sensible en su totalidad se crean en el proyecto `prd-[company]-data-sensitive`.
3. Se utiliza el catálogo `process_ctr_protected_data` para mapear las llaves de encriptación por tipo de variable.
4. Una sola llave de encriptación por **tipo de campo** (ej: una para `CORREO`, una para `DNI`). Generación con `KEYS.NEW_KEYSET('AEAD_AES_GCM_256')`.
5. Funciones: `AEAD.ENCRYPT` (encriptar) y `AEAD.DECRYPT_STRING` (desencriptar — solo previa autorización del jefe/director).
6. Las tablas en `data-sensitive` **no se exponen directamente en INCA**. Se crean vistas autorizadas remapeadas al proyecto `data-storage`.
7. Los campos encriptados deben marcarse como `sensitive` en los metadatos de INCA.

### Hash de persona (iden_party)

Para estandarizar la identidad de personas a nivel de Grupo Intercorp:

```
[codigo_tipo_documento (2 dig)] + [nro_documento (15 dig, zero-padded)] → sha256 → base64 → mayúsculas
```

| Paso | Descripción | Ejemplo |
|---|---|---|
| 1 | Estandarizar tipo doc (código 2 dígitos) + documento (15 dígitos) | `01000000047648778` |
| 2 | Aplicar hash SHA-256 | `nb1vyJbDt...` |
| 3 | Convertir a string hexadecimal en mayúsculas | `9DBD6FC896...` |

Tabla de tipos de documento:

| Código | Tipo |
|---|---|
| `01` | DNI |
| `02` | Carnet de Extranjería |
| `03` | RUC |
| `04` | Pasaporte |
| `07` | Permiso de Permanencia |

---

## 8. Modelo de Datos Corporativo — Entidades Clave

El modelo de datos corporativo ITC organiza las entidades en dominios. Referencia de las principales:

| Entidad | Dataset | Prefijo | Descripción |
|---|---|---|---|
| `iden_party` | `master_party` | `iden_` | Identificador único del cliente a nivel de grupo |
| `m_party_individual` | `master_party` | `m_` | Datos personales del cliente individual |
| `m_party_organization` | `master_party` | `m_` | Datos de organizaciones/empresas |
| `m_party_pii` | `master_pii` (data-sensitive) | `m_` | Datos PII encriptados |
| `m_customer` | `master_customer` | `m_` | Relación cliente-empresa |
| `m_account` | `master_customer` | `m_` | Cuentas del cliente |
| `m_product` | `master_product` | `m_` | Catálogo de productos |
| `t_transaction` | `master_transaction` | `t_` | Transacciones centralizadas |
| `t_payment` | `master_transaction` | `t_` | Pagos |
| `m_place` | `master_place` | `m_` | Locales y puntos de venta |

---

## 9. Lineamientos Generales de Nomenclatura

1. Todos los servicios y objetos en **minúsculas**, singular.
2. Nombres compuestos separados por **underscore** `_` (objetos BigQuery) o **guion** `-` (recursos GCP).
3. No se permiten abreviaturas en nombres de tablas finales (Master/Business); sí se permiten en datasets y buckets.
4. Los procedimientos almacenados (SP) siguen el patrón `sp_[company]_[accion]_[tabla]` — ej: `sp_oe_load_m_customer`.
5. Cada miembro del equipo tiene un bucket y dataset personal de desarrollo nombrado como `[inicial_nombre][apellido]` — ej: `cquispe`.
