# Estándar: Organización y Nomenclatura GCP — Data Platform ITC

> **Última actualización:** 2026-03-05
> **Plataforma:** `dp` (Data Platform) — Google Cloud Platform

---

## 1. Organización de Proyectos GCP

La plataforma de datos ITC sigue una jerarquía GCP de tres niveles: **Organization → Folder → Project**.

### Distribución de proyectos por ambiente

| Proyecto | Ambiente | Propósito |
|---|---|---|
| `dev-[company]-data-operation` | Desarrollo | Procesamiento: pipelines, Store Procedures, Workflows, Cloud Run, Cloud Functions, Cloud SQL. Incluye cuentas de servicio y buckets de código/logs. **Excluye** servicios MLOps (Vertex AI). |
| `dev-[company]-data-storage` | Desarrollo | Almacenamiento de las 3 capas (raw, master, business) en BigQuery y Cloud Storage. |
| `dev-[company]-data-control` | Desarrollo | APIs in-house, plataformas de audiencias publicitarias, controles y reglas de calidad de datos. Lo administra el equipo DevOps. |
| `dev-[company]-advanced-analytics` | Desarrollo | Ambiente exclusivo para Data Scientists y ML Engineers: Vertex AI, notebooks, modelos predictivos. Solo tablas temporales/logs de ejecución. |
| `prd-[company]-data-operation` | Producción | Procesamiento de pipelines productivos. Incluye servicios MLOps (Vertex AI). |
| `prd-[company]-data-storage-pv` | Producción | DataLake productivo: las 3 capas. Acceso para equipos de Data y usuarios finales mediante vistas. |
| `prd-[company]-data-sensitive` | Producción | Datos sensibles/PII encriptados y datos externos comprados que sean sensibles. Sin acceso directo — solo mediante vistas autorizadas desde `data-storage-pv`. |
| `prd-[company]-data-control` | Producción | APIs in-house productivas y controles de calidad de datos. |
| `prd-[company]-data-reporting` | Producción | Despliegue de reportes en Looker y Power BI. Se puede aplicar reserva de slots para reducir costos. |
| `cloud-[company]-monitoring` | Infraestructura | Monitoreo y auditoría de todos los proyectos GCP: logs, alertas, inventario de recursos. Solo acceso del administrador cloud, arquitecto y líderes. |
| `cloud-[company]-billing` | Infraestructura | Centralización del billing de todos los proyectos GCP. Solo acceso del administrador cloud, arquitecto y líderes. |
| `cloud-[company]-dataops` | Infraestructura | Gestión del framework DataOps: Cloud Build, CI/CD, pipelines de despliegue. |

> `[company]` = código corporativo asignado por Intercorp Data Office (ej: `itcm` para Intercorp Management).

---

## 2. Lineamientos Generales

| # | Lineamiento | Ámbito |
|---|---|---|
| 1 | Todos los servicios se crean en **minúsculas**, singular | Todos |
| 2 | Nombres compuestos con **guion** `-` en recursos GCP y **underscore** `_` en objetos BigQuery | Todos |
| 3 | Proyectos productivos: **multi-region** | Producción |
| 4 | Proyectos de desarrollo: **us-central1** | Desarrollo |
| 5 | Cuota de BigQuery: 5 TB/día en desarrollo, 10 TB/día en producción | BigQuery |
| 6 | La data final (raw, master, business) se almacena en proyectos `data-storage` | Todos |
| 7 | Todo el procesamiento (pipelines, SPs, CRs, CFs, Workflows) se crea en proyectos `data-operation` | Todos |
| 8 | Ningún proceso se ejecuta con cuenta de usuario; siempre con **cuentas de servicio** | Todos |
| 9 | Todas las llaves, credenciales, certificados SSL y datos sensibles en **Secret Manager** (proyecto `data-control`) | Todos |
| 10 | **Labels obligatorios** en todos los recursos GCP: `application`, `environment`, `owner`, `bi_technical_datasteward`, `service_type`, `data_zone` | Todos |
| 11 | Los SPs se crean en el proyecto `data-operation`, dataset `master_stage` | BigQuery |
| 12 | Datos sensibles encriptados desde capa RAW; compartidos solo mediante vistas autorizadas previa autorización | Data sensible |
| 13 | Almacenamiento Cloud Storage: últimos 12 meses en **Estándar**, historia restante en **Coldline** | Cloud Storage |
| 14 | No usar **Job Schedule de BigQuery** para automatizar procesos de carga en capas permanentes (solo uso temporal en capa experimental/business) | BigQuery |

---

## 3. Nomenclatura de Recursos GCP

### Cloud Run

```
[env]-[company]-[application/area/use_case]-[random]
```

Ejemplo: `dev-itc-asset-kn95`

### Cloud Functions

```
[env]-[company]-[application/area/use_case]-[random]
```

Ejemplo: `dev-itc-dynamics-crm-kn95`

### Cloud Workflows

| Tipo | Patrón | Ejemplo |
|---|---|---|
| Malla RAW por sistema | `[env]-raw-[application]-[random]` | `dev-raw-sap-kn95` |
| Malla Master por dominio | `[env]-master-[domain]-[random]` | `dev-master-party-kn95` |
| Malla Business/BI | `[env]-bi-[use_case]-[random]` | `dev-business-loyalty-kn95` |
| Sandbox | `[env]-sand-[area/use_case]-[random]` | `dev-sand-marketing-kn95` |
| Delivery de datos | `[env]-delivery-data-[use_case]-[random]` | `dev-delivery-propenciontc-kn95` |

### Cloud Scheduler

```
[env]-[company]-[application/area/use_case]-[random]
```

Ejemplo: `dev-audience-load-g-kn95`

### Cloud SQL

```
[env]-[application]-[tipo_servicio]-[random]
```

| Tipo | Ejemplo |
|---|---|
| MySQL | `dev-sap-msql-kn95` |
| PostgreSQL | `dev-sap-psql-kn95` |

El servidor de la instancia sigue el patrón: `[env]-[company]-dops-sql-usct1-[random]`

### Secret Manager

```
[env]-[application/area/use_case]-[random]
```

Ejemplo: `dev-sharing-kn95`

### Compute Engine

```
[env]-[application]-[random]
```

Ejemplo: `dev-mtln-eng-kn95`

### Cloud Repository

```
[application]/[company]-[application]-[caso_de_uso]
```

Ejemplo: `vuci/itcm-dp-vuci-employee`, `inca/itcm-inca-campaign`

---

## 4. Cuentas de Servicio (Service Accounts)

### Cuentas estándar de plataforma

| SA | Propósito |
|---|---|
| `[env]-storage-ingestion` | Ingesta hacia capa RAW |
| `[env]-operation-processing` | Procesamiento raw → master |
| `[env]-analytics-processing` | Procesamiento capa analítica |
| `[env]-dataops-app` | Despliegues del framework DataOps |

### Cuentas por proyecto/caso de uso

```
[env]-[project]-[application/area/use_case]
```

Ejemplo: `dev-data-operation-dynamic`

> Para las convenciones de SA específicas del framework DataOps (tipos `-app`, `-job`, `-deployer`), ver `@.claude/data/standard/services/service-accounts.md`.

---

## 5. Roles IAM

### Patrón de roles personalizados

| Alcance | Patrón | Ejemplo |
|---|---|---|
| Por proyecto | `[company]_[project]_[cod_rol]_role` | `itcm_data_operation_deng_role` |
| Por servicio (BQ, Storage) | `[company]_[servicio]_role` | `itcm_bq_role`, `itcm_stg_role` |
| Plataforma general | `[company]_[cod_rol]_role` | `itcm_adm_role`, `itcm_sec_role` |

### Roles técnicos

| Rol | Código | Alcance |
|---|---|---|
| Data Engineer | `deng` | Por proyecto |
| Data Scientist | `dsci` | Por proyecto |
| Machine Learning Engineer | `mlen` | Por proyecto |
| Software Engineer | `seng` | Por proyecto |
| Security Analyst | `seca` | Por área |
| System Operator | `sope` | Por área |
| Administrator | `admn` | Por organización |

---

## 6. Variables de Nomenclatura

| Variable | Descripción | Valores |
|---|---|---|
| `env` | Código de entorno | `dev`, `test`, `prd` |
| `company` | Código corporativo | `itcm` |
| `team` | Código de equipo | `bi` |
| `project` | Código de proyecto/caso de uso | `stg`, `loy` |
| `application` | Código de aplicación | `app`, `dpy`, `fico`, `sap` |
| `region` | Ubicación geográfica | Regional: `usea1`, Global: `g` |
| `random` | Secuencia alfanumérica aleatoria | `kn95`, `ia24`, `dt01` |
| `domain` | Dominio de datos del modelo corporativo | `party`, `transaction` |
| `use_case` | Caso de negocio | `loyalty`, `priorizacion_lead` |
| `area` | Área de negocio | `marketing`, `riesgo` |

---

## 7. Monitoreo y Billing

### Proyectos dedicados

- **`cloud-[company]-billing`**: Centraliza el billing de todos los proyectos. Configurar exportación del billing a BigQuery dataset `bi_monitoring`. Crear alertas por organización, cuenta de facturación y proyecto en 25%, 50%, 75%, 100% del presupuesto.
- **`cloud-[company]-monitoring`**: Centraliza logs de auditoría (Cloud Logging), inventario de activos, accesos por recurso y usuario. Dashboards de seguimiento en Looker Studio.

### Tipos de alertas obligatorias

| Tipo | Descripción |
|---|---|
| Billing/Presupuesto | Límites de costos por nivel; alertas por % de avance |
| Jobs BigQuery | Alertas configurables por proyecto, tipo de recurso |
| Auditoría Compute Engine | Acciones sobre VMs en ventana de tiempo |
| Filtración de credenciales | Detección de secrets en repositorios públicos |

### Criterios de optimización de costos

1. **Depurar activos inactivos** > 3 meses (tablas, buckets, reportes no consultados ni actualizados).
2. **Comprimir tablas BigQuery**: cambiar almacenamiento lógico por físico donde sea conveniente.
3. **Particionado y clusterización**: usar la API de recomendación de Google para identificar tablas candidatas.
4. **Optimizar queries pesados**: centralizar logs de Cloud Logging para detectar consultas sin uso de particiones.

---

## 8. Seguridad y CI/CD

### Consideraciones obligatorias

- **Versionamiento de código**: todo avance técnico en repositorio GitLab/Cloud Repository.
- **Pases a producción**: minimizar procesos manuales — automatizar despliegues con scripts.
- **Cuentas de servicio**: ningún proceso se ejecuta con cuenta de usuario.
- **Despliegue de recursos**: activar y etiquetar (labels) todos los recursos desplegados automáticamente.
- **INCA Platform**: integrar proyectos de data a INCA para gobierno de metadata, linaje y gestión de accesos.

### Encriptación de comunicación

- Comunicación entre servicios GCP mediante **TLS 1.2**.
- Opción de encriptación: **Google-managed Encryption Key (GMEK)** para evitar costos operativos de gestión de llaves.
- Para datos de negocio sensibles: **AEAD.ENCRYPT** en BigQuery con llaves del catálogo de datos sensibles.
