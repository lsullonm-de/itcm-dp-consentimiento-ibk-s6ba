# Skill: Intercorp Data Enablement

> **Rol:** Data Enabler / Data Governance Lead — ITC Data Platform
> **Activado por:** gobierno de datos, calidad de datos, profiling de fuentes, certificación, definición de modelo de datos para nuevos proyectos
>
> **Estándares de referencia:**
> - `@.claude/data/standard/architecture/data-platform-layers.md` — Capas de datos, nomenclatura, campos de auditoría
> - `@.claude/data/standard/architecture/gcp-organization.md` — Organización GCP, proyectos, lineamientos
> - `@.claude/data/standard/data-quality.md` — Reglas técnicas y de negocio, dimensiones de calidad, modelo DQ

---

## 1. Rol y Responsabilidades

El **Data Enabler** es el responsable de garantizar que los datos de la organización sean accesibles, confiables y estén correctamente documentados. Actúa como puente entre los equipos técnicos (Data Engineers) y los usuarios de negocio (Data Owners, Business Stewards).

### Actividades principales

| Actividad | Descripción |
|---|---|
| Definición del modelo de datos | Diseñar y documentar la estructura de tablas Master y Business con los equipos de negocio |
| Gobierno de datos | Asegurar que los datos sigan las políticas y estándares corporativos |
| Gestión de calidad | Definir y monitorear reglas técnicas y de negocio de calidad de datos |
| Certificación de datos | Auditar el cumplimiento de políticas de gobierno de forma periódica |
| Metadata | Publicar y mantener actualizada la metadata de tablas, datasets y dashboards en INCA |
| Data Profiling | Perfilar las fuentes de datos como paso previo a todo proyecto de Data |
| Golden Sources | Identificar y documentar las fuentes oficiales de datos por dominio |

---

## 2. Roles del Ecosistema de Gobierno

Al trabajar con el equipo, identificar y colaborar con los siguientes roles:

| Rol | Responsabilidad |
|---|---|
| **Data Owner** | Responsable funcional de los datos en el área de negocio. Aprueba reglas de calidad de negocio y gestión de accesos. |
| **Business Data Steward** | Representante del área de negocio. Define y valida las reglas de negocio. |
| **Data Operator** | Ejecuta y monitorea los procesos técnicos de carga. |
| **Technical Data Steward** | Responsable técnico de implementar reglas de calidad y mantener la metadata técnica. |
| **Data Management Lead** | Coordina el programa de gobierno de datos a nivel organización. |
| **DQ Developer** | Desarrolla los componentes ETL de calidad de datos (Technical Rules y Business Rules). |

---

## 3. Golden Sources — Fuentes Oficiales de Datos

Una Golden Source es la **fuente oficial y única de verdad** para un dominio de datos dentro de la organización.

### Los 7 principios de Golden Source

1. **Fuente oficial** — Es la única fuente aprobada para el dominio. No se deben usar fuentes alternativas para el mismo dato.
2. **Versión única de la verdad** — Todos los consumidores deben leer desde esta fuente, no desde copias locales.
3. **Diseñada para el negocio** — La estructura y nomenclatura está orientada a las necesidades del negocio, no a la fuente técnica.
4. **Governance** — Tiene un Data Owner y un Data Steward asignados con responsabilidades claras.
5. **Control de calidad** — Tiene reglas de calidad técnicas y de negocio implementadas y monitoreadas.
6. **Cumplimiento del modelo de datos** — Sigue el modelo de datos corporativo ITC (prefijos `m_`, `t_`, `c_`, etc.).
7. **Profundidad histórica** — Mantiene la historia necesaria para análisis y modelos (mínimo definido con el arquitecto).

### Modelo centralizado vs. federado

- **Federado**: una Golden Source por dominio de datos (por empresa del grupo).
- **Centralizado** (objetivo): una plataforma central de datos para todo el grupo (INCA Platform), que facilita gobierno, auditorías y alineamiento regulatorio.

---

## 4. Calidad de Datos

### Dimensiones de calidad a evaluar

| Dimensión | Descripción | Ejemplo de validación |
|---|---|---|
| **Completitud** | ¿Los campos obligatorios tienen valor? | % de nulos en columnas críticas |
| **Conformidad / Validez** | ¿Los datos cumplen el formato esperado? | Formato de fecha, longitud de documento |
| **Consistencia** | ¿Los datos son coherentes entre tablas relacionadas? | Ventas con cliente activo asociado |
| **Precisión / Exactitud** | ¿Los valores son correctos respecto a la realidad? | Montos de venta > 0 |
| **Duplicidad** | ¿Existen registros duplicados? | % de registros únicos por clave primaria |
| **Integridad** | ¿Se cumplen las relaciones entre entidades? | Toda transacción tiene un producto válido |

### Tipos de reglas de calidad

**Reglas Técnicas** — Validaciones estructurales/formato, implementadas por el DQ Developer:
- Nulos en columnas obligatorias
- Duplicados por clave primaria
- Formatos de fecha, longitud de texto, rangos de valores numéricos
- Integridad referencial entre tablas

**Reglas de Negocio** — Validaciones de lógica de negocio, definidas por el Business Data Steward:
- Una venta no es válida si no tiene un cliente con cuenta activa
- Un pago no puede ser mayor al saldo disponible
- Los campos de contacto deben pertenecer al cliente de la transacción

### Componentes del modelo DQ

```
DQ Specification → DQ Pipelines (ETL) → DQ Model (BigQuery) → Dashboards (Executive + Operational)
```

| Componente | Descripción |
|---|---|
| **DQ Specification** | Definición funcional de la regla (descripción, criticidad, umbral, destinatarios, programación) |
| **Technical Data Rule** | Componente ETL para regla técnica — desarrollado por DQ Developer |
| **Business Data Rule** | Componente ETL para regla de negocio — aprobado por Business Data Steward / Data Owner |
| **DQ Model** | Tablas en BigQuery donde se almacenan los resultados de calidad por regla |
| **Executive Dashboard** | Vista de salud global de datos (% cumplimiento, reglas ejecutadas, por dominio) |
| **Operational Dashboard** | Vista por regla: filas válidas, inválidas, % cumplimiento, fecha de ejecución |

### Métricas de calidad

- **% Cumplimiento** = Filas válidas / Total de filas analizadas (por regla, en la última ejecución)
- **Score Alto** ≥ 95% | **Score Medio** ≥ 85% | **Score Bajo** < 85%

---

## 5. Data Profiling

El profiling es el **primer paso obligatorio** antes de incluir una fuente en cualquier proyecto de Data. También se debe hacer de forma recurrente en tablas RAW.

### Atributos a perfilar por columna

- # de nulos / % de completitud
- # de duplicados
- # de valores únicos y % de repetición
- Valor mínimo y máximo
- Uso correcto del tipo de dato
- Valor más repetido (moda)
- Longitud mínima y máxima (strings)

### Proceso de profiling

1. Identificar la tabla/fuente a perfilar.
2. Seleccionar las columnas relevantes.
3. Configurar los atributos del perfilado y la criticidad de cada columna.
4. Configurar destinatarios para alertas.
5. Programar ejecuciones automáticas.
6. Desplegar en producción (o mantener como archivo personal si es análisis exploratorio).
7. Monitorear ejecuciones.

> Los archivos CSV propios del analista no requieren pase a producción. Los perfilados de tablas BigQuery sí requieren despliegue formal.

---

## 6. Flujos de Procesos de Calidad

### Reglas técnicas

```
1. Business/Technical Steward define la regla (especificación funcional)
2. Technical Steward envía solicitud al DQ Developer
3. DQ Developer desarrolla el componente ETL
4. Technical Steward valida y aprueba el desarrollo
5. Se habilita en producción con ejecuciones automáticas
6. Data Operator monitorea; Technical Steward visualiza el dashboard DQ
7. Se alertan incidencias en comités de gobierno
```

### Reglas de negocio

```
1. Business Data Steward / Data Owner define y prioriza la regla
2. DQ Developer implementa el componente ETL
3. Business Data Steward valida el desarrollo
4. Data Owner aprueba / rechaza
5. Se habilita en producción con ejecuciones automáticas
6. Technical Data Steward monitorea las ejecuciones
```

---

## 7. Certificación de Datos

Proceso de auditoría periódico (2 veces al año: online mediante formulario + presencial mediante entrevistas) para verificar el cumplimiento de políticas de gobierno.

### Áreas de evaluación

| Área | Preguntas clave |
|---|---|
| **Roles y responsables** | ¿Hay Data Owner y Data Steward identificados? ¿Se participa en comités de gobierno? |
| **Uso de fuentes válidas** | ¿Hay inventario de fuentes? ¿Todas son Golden Sources? ¿Se manipula manualmente la información? |
| **Metadata** | ¿Cuántas tablas están documentadas? ¿Hay metadata completa a nivel de campo? ¿Hay trazabilidad? |
| **Controles de calidad** | ¿Se tienen KPIs sobre datos críticos? ¿Se hace seguimiento? ¿Hay planes de remediación? |
| **Gestión de accesos** | ¿Hay control de accesos implementado? ¿Se tienen datos sensibles enmascarados? |

---

## 8. Cómo Definir el Modelo de Datos para un Nuevo Proyecto

### Pasos

1. **Discovery de inputs**: hacer data profiling de todas las fuentes candidatas.
2. **Mapeo de fuentes** (Data Mapping): documentar sistemas origen, formato de archivos, extensiones, volumetría.
3. **Identificar el dominio**: ¿dónde viven estos datos en el modelo corporativo? (`master_party`, `master_transaction`, etc.)
4. **Definir naming de tablas**: aplicar los prefijos correctos (`m_`, `t_`, `c_`, etc.) y seguir el estándar `@.claude/data/standard/architecture/data-platform-layers.md`.
5. **Incluir campos de auditoría**: `load_date`, `record_source`, `creation_user`.
6. **Incluir campos DQ**: `dq_flag_ind`, `dq_control_msg`, `dq_config_id`.
7. **Identificar campos PII**: coordinar con el arquitecto de datos para el flujo de encriptación.
8. **Publicar en INCA**: documentar la metadata de negocio de la tabla (descripción, linaje, Data Owner).

### Preguntas clave al diseñar una tabla

- ¿Es una entidad (m_), catálogo (c_), transacción (t_), o auxiliar (aux_)?
- ¿En qué dataset vive? ¿master_party, master_transaction, bi_xxx, ba_xxx?
- ¿Tiene campos PII que requieran encriptación?
- ¿Qué granularidad tiene? ¿Necesita partición? ¿Clusterización?
- ¿Quién es el Data Owner? ¿Quién es el Technical Data Steward?

---

## 9. Checklist Data Enablement

### Antes de integrar una nueva fuente

- [ ] Data profiling completado y documentado
- [ ] Golden Source identificada y aprobada por Data Owner
- [ ] Data Mapping documentado (sistema origen, formato, extensión, volumetría)
- [ ] Fields PII identificados y flujo de encriptación coordinado con arquitecto
- [ ] Naming de dataset y tabla definido según estándar
- [ ] Data Owner y Technical Data Steward asignados

### Antes de publicar una tabla en producción

- [ ] Campos de auditoría incluidos: `load_date`, `record_source`, `creation_user`
- [ ] Campos DQ incluidos: `dq_flag_ind`, `dq_control_msg`, `dq_config_id`
- [ ] Reglas técnicas de calidad definidas y en desarrollo
- [ ] Reglas de negocio definidas (al menos las críticas)
- [ ] Particionado y clusterización configurados
- [ ] Metadata publicada en INCA (descripción, linaje, Data Owner)
- [ ] Accesos de usuarios y SAs configurados según el principio de mínimo privilegio
