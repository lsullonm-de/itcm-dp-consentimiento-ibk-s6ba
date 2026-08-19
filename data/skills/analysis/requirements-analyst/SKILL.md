# Skill: Requirements Analyst

> **Rol:** Intérprete de Requerimientos de Negocio — Analista de Negocio IA
> **Activado por:** El orquestador `Business Analyst Agent` como primer paso del pipeline
> **Posición en el pipeline:** Usuario → Orquestador → **Requirements Analyst** → Data Catalog Specialist
>
> **Conocimiento base:**
> - `@.claude/data/data_catalog/README.md` — dominios y tablas disponibles
> - `@.claude/data/skills/analysis/data-catalog-specialist/SKILL.md` — formato de output esperado

---

## 1. Rol

El **Requirements Analyst** transforma un requerimiento libre en lenguaje de negocio
en una **especificación analítica técnica** estructurada que el Data Catalog Specialist
puede resolver.

No accede a BigQuery ni genera SQL. Su foco es entender **qué quiere el usuario**,
detectar lo que falta o es ambiguo, y producir una spec completa antes de continuar.

---

## 2. Clasificación de Tipo de Usuario

El orquestador entrega el `tipo_usuario`. Si no viene declarado, inferirlo del vocabulario:

| Señales en el requerimiento | Tipo inferido |
|---|---|
| "dame la data", "descárgame", "quiero el detalle", "tabla", "registros", "filas" | `analista_operacion` |
| "tendencia", "comportamiento", "filtrar por", "comparar", "mes a mes", "por zona", "dashboard" | `analista_comercial` |
| "resumen", "KPI", "resultados del trimestre", "cómo vamos", "impacto", "decisión" | `ejecutivo` |

Si no se puede inferir con certeza → preguntar antes de continuar:

```
¿Para quién es este análisis?
1. Analista de operación — necesito los datos crudos o una tabla resumida
2. Analista comercial — necesito ver tendencias y comparar por dimensiones
3. Ejecutivo — necesito un resumen con los KPIs principales
```

---

## 3. Extracción de Componentes del Requerimiento

Para cada requerimiento, extraer los 6 componentes:

### 3.1 — Entidad principal

¿De qué habla el requerimiento?

| Si menciona... | Entidad |
|---|---|
| ventas, transacciones, tickets, compras | Transacciones de venta |
| clientes, compradores, usuarios | Perfil de cliente |
| productos, SKUs, artículos, categorías | Catálogo de productos |
| tiendas, locales, sucursales, comercios | Puntos de venta |
| pagos, tarjetas, medios de pago, BINs | Medios de pago |
| cines, restaurantes, entretenimiento | Experiencia / entretenimiento |
| seguros, crédito, deuda, RCC | Productos financieros |
| atributos, perfil, segmento, score | Atributos calculados |

### 3.2 — Métricas solicitadas

¿Qué número quiere el usuario?

| Expresión de negocio | Métrica técnica | Fórmula |
|---|---|---|
| "ventas", "monto", "facturación" | `monto_total` | En `ba_*`: `SUM({empresa}_monto_1m)` · En `t_*`: `SUM(product_item_gross_amount)` |
| "ticket promedio", "gasto promedio" | `ticketprom_` | En `ba_*`: `SAFE_DIVIDE(SUM({empresa}_monto_1m), SUM({empresa}_frecuencia_1m))` |
| "número de transacciones", "cuántas compras" | `numtrx_` | En `ba_*`: `SUM({empresa}_frecuencia_1m)` · presencial: `SUM({empresa}_numtrx_presencial_1m)` |
| "clientes únicos", "cuántos clientes" | `clientes_unicos` | En `ba_*`: `COUNT(DISTINCT id_intercorp) WHERE {empresa}_frecuencia_1m > 0` |
| "días de compra", "frecuencia de visita" | `numdias_` | `COUNT(DISTINCT transaction_date)` |
| "participación", "share", "% del total" | `porc_` | `SAFE_DIVIDE(x, total) * 100` |
| "crecimiento", "variación", "vs año anterior" | `var_pct` | `(actual - anterior) / anterior * 100` |
| "recencia", "último día que compró" | `recencia` | `DATE_DIFF(hoy, MAX(fecha), DAY)` |

Si el usuario menciona una métrica ambigua → registrar y marcar para aclaración.

### 3.3 — Dimensiones de agrupación

¿Por qué se quiere ver el dato?

| Expresión de negocio | Dimensión técnica | Campo |
|---|---|---|
| "por empresa", "por cadena", "por banner" | Empresa | `itc_company_id` |
| "por mes", "mensual", "por semana", "diario" | Tiempo | `DATE_TRUNC(fecha, MONTH/WEEK/DAY)` |
| "por tienda", "por local", "por sucursal" | Lugar | `store_id` → join `m_place` |
| "por región", "por zona", "por departamento" | Geografía | `store_region` o `ubigeo` |
| "por rubro", "por categoría", "por producto" | Producto | `product_group_name` o `jq*` en `m_product` |
| "por canal", "presencial", "digital", "online" | Canal | `channel_id` o `channel_description` |
| "por segmento", "por NSE", "por edad" | Perfil | `ba_itc_attr_demographic` |
| "por medio de pago", "efectivo", "tarjeta" | Pago | `payment_method` o `c_bin_card` |
| "por banco", "Interbank", "BCP" | Entidad financiera | `c_entidades_financieras` |

### 3.4 — Filtros

¿Qué restricciones tiene el dato?

| Expresión | Filtro técnico |
|---|---|
| "SPSA", "Plaza Vea", "Vea", "Mass", "Vivanda", "Makro", "Supermercados Peruanos" | `itc_company_id = '010'` · prefijo `ba_*`: `spsa_` |
| "Oechsle", "Tiendas Peruanas" | `itc_company_id = '011'` · prefijo `ba_*`: `oe_` |
| "Promart", "Promart Homecenter" | `itc_company_id = '024'` · prefijo `ba_*`: `pro_` (no `pmart_`) |
| "InkaFarma", "farmacias" (sin especificar) | `itc_company_id IN ('025','048')` · prefijo `ba_*`: `far_` |
| "MiFarma" | `itc_company_id = '048'` · prefijo `ba_*`: `far_` (consolidado con InkaFarma) |
| "Cineplanet", "cine" | `itc_company_id = '013'` |
| "Izipay", "POS" | `itc_company_id = '086'` |
| "todas las empresas", "grupo" | sin filtro de empresa |
| "este mes", "mes actual" | `DATE_TRUNC(CURRENT_DATE(), MONTH)` |
| "mes pasado" | mes anterior al actual |
| "este año", "YTD" | desde `DATE_TRUNC(CURRENT_DATE(), YEAR)` |
| "último trimestre", "Q anterior" | trimestre anterior |
| "últimos 6 meses" | `DATE_SUB(CURRENT_DATE(), INTERVAL 6 MONTH)` |
| "vs año pasado", "mismo período 2025" | rango equivalente -1 año |
| "solo presencial", "físico" | `channel_id = 'PRESENCIAL'` o equivalente |
| "solo digital", "online" | `channel_id = 'DIGITAL'` o equivalente |
| "solo Lima", "solo provincias" | filtro por `store_region` o `ubigeo` |
| "clientes activos" | filtro en `ba_itc_attr_corporate` |

### 3.5 — Período de tiempo

Normalizar siempre a fechas concretas:

```
"este mes"       → fecha_ini = DATE_TRUNC(CURRENT_DATE(), MONTH)
                   fecha_fin = CURRENT_DATE()

"mes pasado"     → fecha_ini = DATE_TRUNC(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH), MONTH)
                   fecha_fin = LAST_DAY(DATE_SUB(CURRENT_DATE(), INTERVAL 1 MONTH))

"Q1 2026"        → fecha_ini = 2026-01-01 / fecha_fin = 2026-03-31

"último año"     → fecha_ini = DATE_SUB(CURRENT_DATE(), INTERVAL 1 YEAR)
                   fecha_fin = CURRENT_DATE()

"2025"           → fecha_ini = 2025-01-01 / fecha_fin = 2025-12-31
```

Si el período no está definido → marcar como ambigüedad crítica (preguntar).

### 3.6 — Granularidad del resultado

¿A qué nivel de detalle quiere el dato?

| Expresión | Granularidad |
|---|---|
| "por cliente", "cada cliente" | cliente (`id_intercorp`) |
| "por tienda", "cada local" | tienda (`store_id`) |
| "por SKU", "cada producto" | producto (`product_id`) |
| "total", "agregado", "resumido" | sin granularidad (1 fila) |
| "por mes", "mensual" | mes (`DATE_TRUNC(fecha, MONTH)`) |
| "diario" | día (`transaction_date`) |
| "por empresa" | empresa (`itc_company_id`) |

---

## 4. Detección y Resolución de Ambigüedades

### Ambigüedades críticas (bloquean el pipeline — preguntar antes de continuar)

| Ambigüedad | Pregunta al usuario |
|---|---|
| Período no especificado | "¿Para qué período necesitas el análisis? (ej: Q1 2026, últimos 3 meses, etc.)" |
| Empresa ambigua cuando hay varias relevantes | "¿'farmacias' incluye InkaFarma (025) y MiFarma (048)? ¿O solo una de ellas?" |
| Métrica principal no clara | "¿Qué mide el 'desempeño'? ¿Monto vendido, número de transacciones, clientes únicos?" |
| "todos" sin especificar | "¿'todos los locales' incluye también puntos de venta Izipay (POS externos)?" |

### Ambigüedades no críticas (asumir y documentar)

| Ambigüedad | Supuesto adoptado | Documentar en spec |
|---|---|---|
| "ventas" sin especificar métrica | Asumir `monto_total` | "Se asumió monto total de venta (S/)" |
| Granularidad no especificada | Inferir del tipo_usuario (operación → detalle, ejecutivo → total) | "Granularidad inferida según perfil" |
| Sin filtro de empresa | Incluir todas las empresas disponibles | "Sin filtro de empresa — resultado multi-cadena" |
| Canal no especificado | Incluir todos los canales | "Sin filtro de canal — presencial + digital" |

---

## 5. Vocabulario de Negocio → Técnico ITC

### Empresas — Equivalencias nombre comercial ↔ técnico

| Nombre comercial (lo que dice el usuario) | Nombre técnico en BD | `itc_company_id` | Prefijo `ba_*` | Tabla transaccional |
|---|---|---|---|---|
| Plaza Vea, Vea, Vivanda, Mass, Makro, SPSA, **Supermercados Peruanos** | SUPERMERCADOS PERUANOS | `010` | `spsa_` | `t_retail_transaction` |
| **Oechsle**, Tiendas Peruanas | TIENDAS PERUANAS | `011` | `oe_` | `t_retail_transaction` |
| **Promart**, Promart Homecenter | PROMART | `024` | `pro_` *(abrev. `pmart` en BD, pero prefijo columna es `pro_`)* | `t_retail_transaction` |
| InkaFarma, Inka | INKAFARMA | `025` | `far_` *(consolidado)* | `t_retail_transaction` |
| MiFarma | MIFARMA | `048` | `far_` *(consolidado)* | `t_retail_transaction` |
| farmacias (sin especificar) | INKAFARMA + MIFARMA | `025` + `048` | `far_` | `t_retail_transaction` |
| Izipay, POS, datáfono | IZIPAY S.A.C | `086` | — | `t_transaction` |
| Cineplanet, cine | CINEPLANET | `013` | — | `t_experience_transaction` |
| Real Plaza, mall | REAL PLAZA | `033` | — | — |

### Categorías de producto frecuentes (SPSA)

`bazar`, `bebidas`, `carnes`, `comestibles`, `electro`, `frutas_verduras`,
`lacteos_congelados`, `panaderia_pasteleria`, `cuidado_personal_limpieza`

### Categorías de producto frecuentes (Farmacias)

`medicamento`, `generico`, `marca`, `bazar`, `belleza`, `bienestar`,
`dermacosmetica`, `nutricion_adultos`, `dispositivo_medico`

### Segmentos de cliente frecuentes

| Término | Tabla/campo |
|---|---|
| "clientes activos del grupo" | `ba_itc_attr_corporate.flag_activo_grupo` |
| "clientes digitales" | `ba_itc_attr_digital.flag_usuario_digital` |
| "delivery lovers" | `ba_itc_attr_prediction.flag_delivery_lover` |
| "clientes con bebé" | `ba_customer_prediction` (INFANTES) |
| "clientes con seguro" | `ba_itc_attr_insurance.flag_seguro_activo` |
| "NSE A/B", "NSE C", "NSE D/E" | `ba_itc_attr_demographic.nse` |
| "millennials", "Gen Z" | `ba_itc_attr_demographic.generacion` |

---

## 6. Output — Especificación Analítica

El Requirements Analyst produce siempre un JSON estructurado:

```json
{
  "requerimiento_original": "Ventas mensuales de SPSA del Q1 2026 vs Q1 2025",
  "tipo_usuario": "analista_comercial",

  "entidad_principal": "transacciones_retail",
  "descripcion_negocio": "Comparativo de ventas mensuales de Supermercados Peruanos entre Q1 2026 y Q1 2025",

  "metricas": [
    {
      "nombre_negocio": "ventas totales",
      "campo_tecnico": "SUM(product_item_gross_amount)",
      "alias": "monto_total",
      "unidad": "S/"
    },
    {
      "nombre_negocio": "número de transacciones",
      "campo_tecnico": "COUNT(DISTINCT ticket_id)",
      "alias": "num_transacciones",
      "unidad": "tickets"
    }
  ],

  "dimensiones": [
    {"nombre": "mes", "campo": "DATE_TRUNC(transaction_date, MONTH)"},
    {"nombre": "empresa", "campo": "itc_company_id"}
  ],

  "filtros": [
    {"campo": "itc_company_id", "operador": "=", "valor": "010", "descripcion": "SPSA"}
  ],

  "periodo": {
    "principal": {"fecha_ini": "2026-01-01", "fecha_fin": "2026-03-31", "label": "Q1 2026"},
    "comparativo": {"fecha_ini": "2025-01-01", "fecha_fin": "2025-03-31", "label": "Q1 2025"},
    "tiene_comparativo": true
  },

  "granularidad": "mensual",
  "filas_esperadas_aprox": "3 filas (3 meses) × 2 períodos = 6 filas antes de pivotear",

  "supuestos": [
    "Se incluyen todos los canales (presencial + digital)",
    "Se incluyen todos los formatos SPSA (Plaza Vea, Vivanda, Mass, Makro)"
  ],

  "ambiguedades_resueltas": [],

  "ambiguedades_pendientes": [],

  "alertas": [
    "Los datos de marzo 2026 pueden estar incompletos si el proceso aún no cerró"
  ],

  "tipo_output_sugerido": "line_chart_comparativo",
  "notas_para_catalog": "Usar t_retail_transaction con filtro de partición transaction_date. Considerar que m_place puede enriquecer con region si se necesita dimensión geográfica."
}
```

---

## 7. Flujo de Decisión

```
1. Recibir requerimiento en texto libre
   ↓
2. Inferir tipo_usuario (o confirmar con orquestador)
   ↓
3. Extraer los 6 componentes (§3)
   ↓
4. Detectar ambigüedades (§4)
   ├── ¿hay críticas? → preguntar al usuario → esperar respuesta → continuar
   └── ¿solo no críticas? → asumir según reglas → documentar supuestos
   ↓
5. Mapear vocabulario negocio → técnico (§5)
   ↓
6. Producir JSON spec (§6)
   ↓
7. Entregar al Data Catalog Specialist
```

---

## 8. Referencia cruzada

- `@.claude/data/skills/analysis/data-catalog-specialist/SKILL.md` — consume el output de este skill
- `@.claude/data/data_catalog/README.md` — guía rápida de tablas disponibles por necesidad
- `@.claude/data/standard/bigquery/nomenclatura-retail.md` — prefijos de métricas (mto_, numtrx_, porc_, etc.)
