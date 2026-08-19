# Schema de Spec: `type: cloud_function`

> Spec para módulos que implementan una **Cloud Function**: procesamiento event-driven
> disparado por Pub/Sub, Cloud Storage, HTTP o Cloud Scheduler.
> Skill correspondiente: pendiente de definir (skill CF futuro).
>
> **Ubicación del archivo:** `docs/specs/SPEC-[EMPRESA]-[YYYYMMDD]-[NNN].yaml`
> (todos los specs van en `docs/specs/` — ver `@.claude/data/standard/factory/project-manifest.md`)

---

## Bloques aplicables

| Bloque | ¿Aplica? | Descripción |
|---|---|---|
| Raíz (`id`, `version`, `status`, `type`, ...) | ✅ | Sin cambios |
| `contexto` | ✅ | `tipo_flujo: api` o según función |
| `etapas` | ✅ | Sin cambios |
| `trigger` | ✅ nuevo | Qué dispara la función |
| `fuentes` | ✅ | Tablas BQ o topics Pub/Sub que lee |
| `outputs` | ✅ adaptado | Tabla BQ, topic Pub/Sub o sin output |
| `componentes` | ✅ | Solo `cloud_function`, `pubsub` |
| `reglas_negocio` | ✅ | Lógica de la función |
| `data_quality` | — | No aplica |
| `seguridad` | ✅ | Sin cambios |
| `scheduling` | ✅ | Si es disparada por Scheduler |
| `restricciones` | ✅ | Sin cambios |

---

## Bloque `trigger`

Define cómo se activa la Cloud Function.

| Campo | Tipo | Req | Descripción |
|---|---|---|---|
| `tipo` | enum | ✅ | `pubsub` \| `gcs` \| `http` \| `scheduler` |
| `recurso` | string | ✅ | Topic, bucket, URL o expresión cron según tipo |
| `descripcion` | string | ✅ | Qué evento activa la función |
| `retry` | bool | — | `true` para reintentos automáticos en fallo. Default: `false` |
| `max_instances` | int | — | Máximo de instancias concurrentes. Default: `1` |
| `timeout_segundos` | int | — | Timeout de la función. Default: `60`. Max: `540` |

**Valores válidos `tipo`:**

| Tipo | `recurso` esperado | Cuándo usarlo |
|---|---|---|
| `pubsub` | Nombre del topic: `${pubsub_topic}` | Procesamiento event-driven de mensajes |
| `gcs` | Patrón del bucket: `${bucket_name}` | Procesamiento de archivos al subir |
| `http` | Path relativo: `/v1/webhook` | Webhook o callback de sistema externo |
| `scheduler` | Expresión cron: `"0 6 * * *"` | Job programado liviano (sin Workflow) |

---

## Bloque `componentes` para cloud_function

```yaml
componentes:
  - tipo: cloud_function
    archivo: service/cloud_function/{nombre}/
    descripcion: "Función Python event-driven"

  - tipo: pubsub       # si el trigger es pubsub o si publica mensajes
    archivo: ~
    descripcion: "Topic de entrada o salida"

  - tipo: cloud_scheduler   # solo si trigger es scheduler
    archivo: pipeline/workflow/cs-{nombre}.yaml
    descripcion: "Job programado"
```

---

## Reglas de desarrollo para este type

Al ejecutar `/check-rules` sobre un módulo `cloud_function`, Claude aplica adicionalmente:

1. **SA tipo `-app`** — Cloud Functions usan SA tipo `-app`, no `-job`
   (excepción: si el trigger es Scheduler y la CF hace procesamiento de datos, usar `-job`)
2. **Sin estado interno** — la función no debe mantener estado entre invocaciones
3. **Idempotencia** — el mismo mensaje Pub/Sub procesado dos veces debe producir el mismo resultado
4. **Timeout declarado** — `timeout_segundos` siempre explícito en el spec
5. **max_instances controlado** — para CFs que escriben a BQ, limitar concurrencia para evitar conflictos
6. **Secrets en Secret Manager** — nunca en variables de entorno en texto plano

---

## Ejemplo completo

```yaml
id: SPEC-ITC-20260701-001
version: "1.0"
status: draft
type: cloud_function
empresa: itc
equipo: data-analytics
fecha: "2026-07-01"
autor: amoreno
aprobador: ~

contexto:
  nombre: "Notificador de Carga de Atributos"
  tipo_flujo: api
  descripcion: >
    Cloud Function que se activa al recibir un mensaje Pub/Sub cuando un pipeline
    de atributos completa su carga, y envía notificación por correo al equipo.
  objetivo_negocio: >
    Notificar al equipo de negocio automáticamente cuando los atributos del cliente
    están disponibles para consumo.
  data_owner: "Área de Analítica de Clientes"
  business_steward: "lmorales"
  kpis:
    - "Notificación enviada en menos de 60s tras el evento"
    - "0% de mensajes perdidos"

etapas:
  plan: true
  design: true
  coding: true
  data_quality: false
  compliance: true
  orchestration: false
  testing: true
  dataops: true
  calidad: false
  security: true
  documentation: true
  monitoreo: false

trigger:
  tipo: pubsub
  recurso: "${pubsub_topic_attr_complete}"
  descripcion: >
    Se activa cuando un pipeline de atributos publica un mensaje en el topic
    indicando que la carga fue exitosa.
  retry: true
  max_instances: 5
  timeout_segundos: 60

fuentes:
  - id: pubsub_mensaje
    descripcion: "Mensaje Pub/Sub con metadata de la carga completada"
    proyecto: "${project_pubsub}"
    dataset: ~
    tabla: ~
    volumetria: "~1 mensaje por ejecución de pipeline"
    particion: ~
    pii: false

outputs:
  - tabla: ~
    proyecto: ~
    dataset: ~
    descripcion: "Sin output a BQ — solo envío de correo vía Pub/Sub mail"
    capa: ~
    tipo_carga: ~
    campos_auditoria: []
    pii: false

componentes:
  - tipo: cloud_function
    archivo: service/cloud_function/attr-notifier/
    descripcion: "Función Python que parsea mensaje y publica en topic de mail"

  - tipo: pubsub
    archivo: ~
    descripcion: "Topic de entrada: ${pubsub_topic_attr_complete} | Topic mail: ${mail_pubsub_topic}"

reglas_negocio:
  - id: RN-ITC-001
    descripcion: >
      Si el mensaje indica error en la carga → enviar correo con asunto 'ERROR'
      y detalle del fallo. Si es éxito → enviar correo con resumen de filas cargadas.
    criticidad: alta
    campo_afectado: status
    validado_por: lmorales

  - id: RN-ITC-002
    descripcion: >
      El mensaje de correo debe incluir: nombre del proceso, ambiente (dev/prd),
      fecha de ejecución y conteo de filas. Sin datos PII.
    criticidad: media
    campo_afectado: ~
    validado_por: lmorales

seguridad:
  campos_pii_fuente: []
  campos_pii_output: []
  encriptacion_requerida: false
  hash_iden_party: false
  permisos:
    - sa: "${env}-itc-notifier-app@${env}-itc-customer-services.iam.gserviceaccount.com"
      recurso: "${project_pubsub}.${mail_pubsub_topic}"
      permiso: roles/pubsub.publisher
  nota: >
    SA tipo -app — es un servicio en ejecución event-driven, no un job de datos.

restricciones:
  - La función no debe leer ni escribir datos de clientes — solo metadata del proceso
  - Idempotente — si el mismo mensaje se procesa dos veces, no debe duplicar el correo
    (usar message_id de Pub/Sub para deduplicación si es necesario)
  - timeout_segundos máximo 60 — si excede, la lógica debe simplificarse
```
