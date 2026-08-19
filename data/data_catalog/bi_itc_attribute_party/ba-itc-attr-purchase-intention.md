# Catálogo de Datos — `ba_itc_attr_purchase_intention`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`

---

## Descripción

Intención de compra del cliente basada en navegación digital (product views, add to cart, view cart) en sitios de Promart y Oechsle. Registra si el cliente vio productos, los agregó al carrito o revisó el carrito por categoría de producto en 5 ventanas temporales cortas: 1 semana, 2 semanas, 3 semanas, 1 mes y 2 meses.

Complementa a `ba_itc_attr_purchase_card` (lo que ya compró) con lo que está **considerando comprar ahora**. Un cliente con `flag_tecnologia_product_view_1s = 1` vio productos de tecnología en la última semana — señal de alta intención de compra actual para activación inmediata.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~158M |
| Columnas | 708 |
| Última fecha de proceso | `2026-05-01` |
| Frecuencia | Mensual |

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | STRING | Documento de identidad del cliente |
| `process_date` | DATE | Campo de partición. Primer día del mes con toda la info del mes |

> Los campos de auditoría (`load_date`, `record_source`, `creation_user`) se encuentran incluidos en las 708 columnas totales.

---

## 2. Convención de naming de las columnas de intención

El patrón de las columnas de métricas es:

```
flag_{categoria}_{accion}_{ventana}
```

| Dimensión | Valores |
|---|---|
| `categoria` | 28 categorías (ver sección 3) |
| `accion` | `product_view`, `add_to_cart`, `view_cart` |
| `ventana` | `1s` (1 semana), `2s` (2 semanas), `3s` (3 semanas), `1m` (1 mes), `2m` (2 meses) |

Todos los campos son flags **INTEGER binarios**: `1` = el cliente realizó esa acción en al menos un producto de esa categoría en la ventana. `0` o `NULL` = no realizó la acción.

Combinación total: **28 × 3 × 5 = 420 campos de flags** (más campos de identificación y auditoría = 708 total).

---

## 3. Categorías de intención de compra (28)

| Categoría | Descripción |
|---|---|
| `tecnologia` | Electrónica, gadgets, computadoras, celulares |
| `aire_libre` | Artículos para actividades al aire libre, camping, jardín |
| `automotriz` | Accesorios y repuestos para vehículos |
| `belleza_accesorios` | Maquillaje, accesorios de moda y belleza |
| `calzado` | Zapatos y zapatillas |
| `construccion` | Materiales de construcción |
| `cursos_membresias` | Cursos online y membresías |
| `decohogar` | Decoración del hogar y artículos decorativos |
| `deportes` | Artículos deportivos y fitness |
| `dormitorio` | Muebles y ropa de cama para dormitorio |
| `electrohogar` | Línea blanca y electrodomésticos |
| `especiales` | Categorías especiales o temporadas (ej: Black Friday, Navidad) |
| `ferreteria` | Ferretería y materiales de trabajo |
| `herramientas` | Herramientas manuales y eléctricas |
| `infantil` | Productos para bebés y niños |
| `instrumentos_musicales` | Instrumentos musicales y accesorios |
| `juguetes_juegos` | Juguetes y juegos de mesa |
| `limpieza` | Productos de limpieza del hogar |
| `maletas` | Maletas, mochilas y accesorios de viaje |
| `mascotas` | Alimentos y accesorios para mascotas |
| `mejoramiento_hogar` | Mejoras del hogar, pintura, instalaciones |
| `moda` | Ropa en general (hombre y mujer) |
| `muebles` | Muebles para el hogar |
| `navidad` | Artículos de temporada navideña |
| `oficina_utiles` | Útiles de oficina y escolares |
| `salud_bienestar` | Productos de salud, vitaminas y bienestar |
| `servicios` | Servicios (instalación, mantenimiento, etc.) |
| `supermercado` | Productos de supermercado y alimentos |

---

## 4. Acciones registradas

| Acción | Descripción | Señal de intención |
|---|---|---|
| `product_view` | El cliente visualizó la página de un producto de esa categoría | Media — exploración |
| `add_to_cart` | El cliente agregó al menos un producto al carrito | Alta — decisión activa |
| `view_cart` | El cliente revisó su carrito (con productos de esa categoría) | Muy alta — a punto de comprar |

---

## 5. Ventanas temporales y fuerza de señal

| Ventana | Período | Interpretación de intención |
|---|---|---|
| `1s` | Última semana | MUY ALTA — navegación reciente, activar inmediatamente |
| `2s` | Últimas 2 semanas | ALTA — en ciclo de consideración activo |
| `3s` | Últimas 3 semanas | MEDIA-ALTA — aún relevante |
| `1m` | Último mes | MEDIA — puede estar comparando opciones |
| `2m` | Últimos 2 meses | BAJA-MEDIA — interés que puede haber pasado |

---

## 6. Ejemplos de campos

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_tecnologia_product_view_1s` | INTEGER | Vio productos de tecnología en la última semana |
| `flag_tecnologia_add_to_cart_1s` | INTEGER | Agregó tecnología al carrito en la última semana |
| `flag_tecnologia_view_cart_1s` | INTEGER | Revisó carrito con tecnología en la última semana |
| `flag_electrohogar_product_view_3s` | INTEGER | Vio electrodomésticos en las últimas 3 semanas |
| `flag_moda_product_view_1m` | INTEGER | Vio moda en el último mes |
| `flag_infantil_add_to_cart_2s` | INTEGER | Agregó productos infantiles al carrito en 2 semanas |
| `flag_deportes_product_view_2m` | INTEGER | Vio artículos deportivos en los últimos 2 meses |
| `flag_supermercado_view_cart_1s` | INTEGER | Revisó carrito con supermercado en la última semana |
| `flag_mejoramiento_hogar_product_view_1m` | INTEGER | Vio mejoramiento del hogar en el último mes |
| `flag_mascotas_add_to_cart_1m` | INTEGER | Agregó productos de mascotas al carrito en el mes |

---

## 7. Queries de referencia

```sql
-- Alta intención de compra en tecnología (product view última semana)
SELECT id,
  flag_tecnologia_product_view_1s,
  flag_tecnologia_add_to_cart_1s,
  flag_tecnologia_view_cart_1s
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`
WHERE process_date = '2026-05-01'
  AND flag_tecnologia_product_view_1s = 1;

-- Clientes con carrito activo en electrohogar (señal más fuerte — view_cart)
SELECT id
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`
WHERE process_date = '2026-05-01'
  AND flag_electrohogar_view_cart_1s = 1;

-- Clientes con intención en múltiples categorías (comprador activo en 1m)
SELECT id,
  (COALESCE(flag_tecnologia_product_view_1m, 0) +
   COALESCE(flag_electrohogar_product_view_1m, 0) +
   COALESCE(flag_moda_product_view_1m, 0) +
   COALESCE(flag_deportes_product_view_1m, 0) +
   COALESCE(flag_decohogar_product_view_1m, 0) +
   COALESCE(flag_muebles_product_view_1m, 0)) AS categorias_activas
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`
WHERE process_date = '2026-05-01'
HAVING categorias_activas >= 3;

-- Segmento maternidad: intención infantil + predicción embarazo
SELECT pi.id,
  pi.flag_infantil_product_view_1s,
  pi.flag_infantil_add_to_cart_1s,
  pred.mes_bebe
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention` pi
LEFT JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_prediction` pred
  ON pi.id = pred.id AND pi.process_date = pred.process_date AND pred.flag_active = true
WHERE pi.process_date = '2026-05-01'
  AND pi.flag_infantil_product_view_1s = 1;

-- Tasa de intención por categoría (% de clientes con product view en 1 semana)
SELECT
  ROUND(SUM(COALESCE(flag_tecnologia_product_view_1s, 0)) * 100.0 / COUNT(*), 2)  AS pct_tecnologia,
  ROUND(SUM(COALESCE(flag_moda_product_view_1s, 0)) * 100.0 / COUNT(*), 2)        AS pct_moda,
  ROUND(SUM(COALESCE(flag_infantil_product_view_1s, 0)) * 100.0 / COUNT(*), 2)    AS pct_infantil,
  ROUND(SUM(COALESCE(flag_electrohogar_product_view_1s, 0)) * 100.0 / COUNT(*), 2) AS pct_electrohogar,
  ROUND(SUM(COALESCE(flag_deportes_product_view_1s, 0)) * 100.0 / COUNT(*), 2)    AS pct_deportes,
  COUNT(*) AS total_clientes
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`
WHERE process_date = '2026-05-01';
```

---

## 8. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes.
2. **Señal más fuerte**: `view_cart` > `add_to_cart` > `product_view`. Para retargeting inmediato priorizar `view_cart_1s`.
3. **NULL vs 0**: `NULL` puede significar "sin dato de navegación" mientras `0` es "navegó pero no realizó la acción". Tratar ambos como "sin intención" con `COALESCE(campo, 0)`.
4. **`flag_{cat}_product_view_1s = 1` + `add_to_cart_1s = 0`**: El cliente vio pero no agregó al carrito — candidato para campaña de empuje (descuento, urgencia).
5. **`product_view_1m = 1` + `product_view_1s = 0`**: Interés previo sin navegación reciente — candidato a reactivación.
6. **Fuente**: Solo cubre navegación en plataformas digitales de Promart y Oechsle. No incluye comportamiento en otras webs/apps del grupo.
7. **158M registros**: Solo clientes con actividad de navegación digital registrada — no todo el universo de clientes Intercorp.
8. **Retargeting cross-empresa**: Una intención en `electrohogar` puede activar campaña tanto en Oechsle como en Promart, sin importar en cuál plataforma navegó el cliente.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_purchase_intention`*
