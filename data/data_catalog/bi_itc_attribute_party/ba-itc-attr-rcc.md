# Catálogo de Datos — `ba_itc_attr_rcc`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc`

---

## Descripción

Atributos del **Reporte Crediticio del Consumidor (RCC)** del cliente. Para cada cliente registra: deudas directas e indirectas por banco emisor y tipo de crédito (comercial, microempresa, consumo, hipotecaria), flags de mora, montos de deuda vigente y vencida, y scores de riesgo crediticio.

El RCC es el reporte oficial de deuda del sistema financiero peruano (SBS). Esta tabla es el input central para modelos de riesgo crediticio, segmentación por nivel de endeudamiento, y casos de uso de crédito del Grupo Intercorp.

> **⚠️ DATOS SENSIBLES**: Esta tabla contiene información crediticia regulada. Acceso restringido a equipos autorizados.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Tipo | TABLE |
| Particionado por | `process_date` (DAY) |
| Clusterizado por | `id` |
| Total de filas | ~731,000,000 (~731M) |
| Número de columnas | 6,476 |
| Tamaño lógico | ~1.8 TB |
| Última fecha de proceso | 2026-02-01 |
| Frecuencia | Mensual |
| Fuente | SBS (Superintendencia de Banca y Seguros del Perú) |

---

## Glosario de Campos

Por el volumen de columnas (6,476), la documentación se organiza por **familias de métricas** según el naming convention.

### 1. Identificadores

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | **Campo de partición**. Snapshot mensual |
| `id` | STRING | Documento de identidad del cliente. **Campo clustered** |

### 2. Naming convention de columnas

El patrón de naming es:

```
{tipo_deuda}_{banco}_{tipo_credito}_{metrica}
```

| Dimensión | Valores posibles |
|---|---|
| `tipo_deuda` | `flag_deuda_directa`, `flag_deuda_indirecta`, `mto_deuda_directa`, `mto_deuda_indirecta`, `flag_mora` |
| `banco` | `bcp`, `ibk`, `bbva`, `scotiabank`, `interamericano`, `mibanco`, `banbif`, `compartamos`, otros |
| `tipo_credito` | `comercial`, `microempresa`, `consumo`, `hipotecaria`, `gran_empresa`, `mediana_empresa`, `pequena_empresa` |
| `metrica` | `vigente`, `vencida`, `refinanciada`, `reestructurada`, `judicial` |

### 3. Flags de deuda directa e indirecta

#### Por banco y tipo de crédito

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_deuda_directa_{banco}_{tipo_credito}` | INTEGER | `1` = tiene deuda directa en ese banco y tipo de crédito |
| `flag_deuda_indirecta_{banco}_{tipo_credito}` | INTEGER | `1` = tiene deuda indirecta (avales, endosos) |
| `flag_mora_{banco}_{tipo_credito}` | INTEGER | `1` = tiene deuda vencida (en mora) en ese banco/tipo |

#### Flags globales (por tipo de crédito, todos los bancos)

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_deuda_directa_consumo` | INTEGER | `1` = tiene deuda de consumo en cualquier banco |
| `flag_deuda_directa_hipotecaria` | INTEGER | `1` = tiene crédito hipotecario en cualquier banco |
| `flag_deuda_directa_comercial` | INTEGER | `1` = tiene deuda comercial en cualquier banco |
| `flag_mora_consumo` | INTEGER | `1` = tiene mora en crédito de consumo |
| `flag_mora_hipotecaria` | INTEGER | `1` = tiene mora en crédito hipotecario |

### 4. Montos de deuda

| Campo | Tipo | Descripción |
|---|---|---|
| `mto_deuda_directa_{banco}_{tipo_credito}_vigente` | FLOAT | Saldo de deuda directa vigente (no vencida) |
| `mto_deuda_directa_{banco}_{tipo_credito}_vencida` | FLOAT | Saldo de deuda vencida (en mora) |
| `mto_deuda_directa_{banco}_{tipo_credito}_total` | FLOAT | Saldo total de deuda directa |
| `mto_deuda_hipotecaria_ibk_vigente` | FLOAT | Saldo hipotecario vigente en Interbank |

### 5. Bancos principales cubiertos

| Código | Banco |
|---|---|
| `bcp` | Banco de Crédito del Perú |
| `ibk` | Interbank |
| `bbva` | BBVA Perú |
| `scotiabank` | Scotiabank Perú |
| `interamericano` | Banco Interamericano de Finanzas (BanBIF) |
| `mibanco` | Mibanco |
| `compartamos` | Compartamos Financiera |
| `banbif` | BanBIF |
| `pichincha` | Banco Pichincha |

### 6. Tipos de crédito del RCC

| Tipo | Descripción |
|---|---|
| `consumo` | Créditos de consumo personal (tarjetas, préstamos personales) |
| `hipotecaria` | Créditos hipotecarios (vivienda) |
| `comercial` | Créditos comerciales empresariales |
| `microempresa` | Créditos para microempresas (MES) |
| `pequena_empresa` | Créditos para pequeñas empresas |
| `mediana_empresa` | Créditos para medianas empresas |
| `gran_empresa` | Créditos para grandes empresas |

---

## Reglas de negocio

1. **Snapshot mensual** — una fila por cliente con historial crediticio por mes.

2. **`flag_mora_consumo = 1`**: Cliente en mora en crédito de consumo → excluir de campañas de oferta de crédito.

3. **`flag_deuda_directa_hipotecaria = 1` + `flag_mora_hipotecaria = 0`**: Cliente con hipoteca vigente sin mora — buen perfil de riesgo crediticio.

4. **`mto_deuda_directa_consumo_ibk_vigente > 0`**: Cliente con saldo de consumo activo en Interbank — candidato a cross-sell de productos de consolidación de deuda.

5. **`flag_deuda_directa_consumo = 1` + `flag_deuda_directa_ibk_consumo = 0`**: Cliente con deuda de consumo pero NO en Interbank → oportunidad de captación de crédito IBK.

6. **Deuda indirecta**: Avales y endosos. Indica compromiso financiero como garante — aumenta el riesgo real del cliente aunque no sea deuda propia directa.

7. **Clasificación de riesgo**:
   - Sin mora, sin deuda vencida: `flag_mora_* = 0` en todos los bancos → Riesgo bajo
   - Mora en 1 banco: Riesgo medio
   - Mora en múltiples bancos: Riesgo alto / excluir de productos de crédito

---

## Observaciones de calidad de datos

| Observación | Detalle |
|---|---|
| 6,476 columnas | La tabla más ancha del repositorio. Nunca usar `SELECT *`. |
| **⚠️ Datos SBS regulados** | Acceso restringido. Solo equipos con autorización de riesgo crediticio. |
| 731M registros | Filtrar siempre por `process_date` específico |
| NULL = sin deuda en esa combinación | No indica error — cliente sin crédito en ese banco/tipo |
| Rezago de ~30 días | El RCC de la SBS tiene un rezago de ~1 mes. Los datos de `process_date = '2026-02-01'` corresponden aproximadamente a la situación crediticia de enero 2026. |
| `mto_deuda` en soles (PEN) | Todos los montos están expresados en soles peruanos |

---

## Queries de referencia

```sql
-- Clientes con deuda hipotecaria vigente sin mora (prospectos de seguros de desgravamen)
SELECT id, mto_deuda_directa_ibk_hipotecaria_vigente,
  mto_deuda_directa_bcp_hipotecaria_vigente
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc`
WHERE process_date = '2026-02-01'
  AND flag_deuda_directa_hipotecaria = 1
  AND flag_mora_hipotecaria = 0;

-- Clientes con deuda de consumo fuera de IBK (oportunidad captación)
SELECT id, flag_deuda_directa_consumo,
  flag_deuda_directa_ibk_consumo,
  mto_deuda_directa_bcp_consumo_vigente + mto_deuda_directa_bbva_consumo_vigente AS deuda_competencia
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc`
WHERE process_date = '2026-02-01'
  AND flag_deuda_directa_consumo = 1
  AND COALESCE(flag_deuda_directa_ibk_consumo, 0) = 0
ORDER BY deuda_competencia DESC;

-- Perfil de endeudamiento general
SELECT
  SUM(flag_deuda_directa_consumo) AS con_consumo,
  SUM(flag_deuda_directa_hipotecaria) AS con_hipoteca,
  SUM(flag_mora_consumo) AS en_mora_consumo,
  SUM(flag_mora_hipotecaria) AS en_mora_hipoteca,
  COUNT(*) AS total
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc`
WHERE process_date = '2026-02-01';

-- Clientes sin deuda en ningún banco (sin historial crediticio)
SELECT COUNT(DISTINCT id) AS sin_historial_crediticio
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc`
WHERE process_date = '2026-02-01'
  AND flag_deuda_directa_consumo = 0
  AND flag_deuda_directa_hipotecaria = 0
  AND flag_deuda_directa_comercial = 0;
```

---

*Generado: 2026-03-10 | Fuente: BigQuery `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_rcc` — Datos SBS regulados*
