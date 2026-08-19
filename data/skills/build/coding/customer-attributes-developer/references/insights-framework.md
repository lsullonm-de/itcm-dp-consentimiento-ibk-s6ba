# Framework para Generación de Insights

> **De dato a decisión:** Un marco de trabajo estructurado para transformar información en conocimiento accionable.

---

## 1. ¿Qué es un Insight?

Un insight **no es un dato, ni una observación, ni una métrica**. Un insight es una verdad profunda y no obvia sobre el comportamiento, necesidad o motivación de un usuario o mercado, que tiene el poder de cambiar una decisión.

### Anatomía de un Insight

Un insight bien formulado tiene tres componentes:

```
OBSERVACIÓN   →   TENSIÓN   →   IMPLICACIÓN
(Qué pasa)        (Por qué importa)   (Qué hacemos)
```

**Fórmula de redacción:**

> *"[QUIÉN] hace/siente/piensa [QUÉ] porque [POR QUÉ], lo que significa que [IMPLICACIÓN PARA EL NEGOCIO]."*

**Ejemplo débil:** "El 60% de los usuarios abandona el carrito."
**Ejemplo fuerte:** "Los usuarios nuevos abandonan el carrito cuando ven costos de envío por primera vez, porque perciben un quiebre de confianza al sentir que el precio 'cambió'. Esto significa que mostrar costos estimados desde el inicio puede reducir abandono y aumentar percepción de transparencia."

---

## 2. Niveles de Profundidad

No todos los insights tienen el mismo valor estratégico. Clasifícalos según su profundidad:

| Nivel | Nombre | Descripción | Ejemplo | Valor |
|-------|--------|-------------|---------|-------|
| **L1** | Dato | Número o hecho sin contexto | "Tráfico cayó 15%" | Bajo |
| **L2** | Observación | Dato con contexto o patrón | "El tráfico cae los lunes después de feriados" | Medio-bajo |
| **L3** | Hallazgo | Patrón explicado con causa probable | "Los usuarios posponen compras post-feriado porque ya agotaron presupuesto" | Medio |
| **L4** | Insight | Verdad profunda con tensión y oportunidad | "Existe una ventana de 48h post-feriado donde los usuarios buscan ofertas de 'recuperación' — un momento no explotado" | Alto |
| **L5** | Insight Estratégico | Insight que redefine cómo pensamos el negocio | "El ciclo emocional de gasto de nuestros usuarios sigue un patrón predecible de 3 fases que podemos anticipar" | Muy alto |

**Regla de oro:** Si tu insight no genera al menos una pregunta de "¿y si...?", probablemente estás en L1-L2.

---

## 3. Proceso de Generación: Las 6 Fases

### FASE 0 — Encuadre Estratégico

**Objetivo:** Definir el punto de partida antes de tocar cualquier dato. Sin esta fase, corres el riesgo de generar insights brillantes pero irrelevantes.

Todo proceso de insights comienza respondiendo tres preguntas:

**Plantilla de Encuadre:**

```
─────────────────────────────────────────
ENCUADRE ESTRATÉGICO
─────────────────────────────────────────

PROBLEMÁTICA:
¿Qué está pasando? ¿Cuál es el dolor, fricción o desafío
que enfrenta el negocio hoy?

→ [Descripción del problema en términos concretos,
   con datos de contexto si los hay]

OBJETIVO:
¿Qué queremos lograr o resolver? ¿Qué decisión necesitamos
tomar con mejor información?

→ [Resultado esperado, medible si es posible]

OPORTUNIDAD:
¿Dónde creemos que hay espacio para actuar? ¿Qué territorio
queremos explorar?

→ [Hipótesis inicial de dónde buscar o qué palanca mover]

─────────────────────────────────────────
```

**Ejemplo aplicado:**

| Componente | Ejemplo |
|------------|---------|
| **Problemática** | La tasa de recompra cayó 18% en los últimos 3 meses, especialmente en el segmento de clientes adquiridos por campañas digitales. |
| **Objetivo** | Entender qué está rompiendo el ciclo de recompra para diseñar una estrategia de retención en Q3. |
| **Oportunidad** | Creemos que el gap está entre la primera y segunda compra — hay un momento post-compra donde perdemos la conexión con el cliente. |

**Reglas de esta fase:**

- Escríbelo antes de abrir cualquier dashboard o base de datos.
- Debe ser validado con el stakeholder que tomará la decisión.
- Si no puedes articular la problemática en 2 oraciones, necesitas más conversación con el negocio, no más datos.
- La oportunidad es una hipótesis, no una conclusión — está bien que cambie después.

**Test rápido:** Si al terminar el proceso tus insights no responden a la problemática ni se conectan con el objetivo, algo se desvió. Vuelve aquí.

**Conexión con BigQuery:** El encuadre estratégico define qué tablas necesitas consultar. Documenta las tablas input desde el inicio:

```
─────────────────────────────────────────
REGISTRO DE INPUTS (BigQuery)
─────────────────────────────────────────

Proyecto:  itc-data-governance-01
Dataset:   aodarm

Tablas input identificadas:

| # | Tabla                          | Descripción                        | Pregunta que responde                    |
|---|--------------------------------|------------------------------------|------------------------------------------|
| 1 | tmp_transacciones_totales_ngr  | Transacciones base con canal       | ¿Cuánto y dónde compra cada cliente?     |
| 2 | tmp_cliente_canal_12m          | Tipo cliente por canal (12m)       | ¿Cuál es su preferencia de canal?        |
| 3 | tmp_cliente_canal_sin_definir  | Detalle de clientes <3 trx         | ¿Qué sabemos de clientes con poca data? |
| … | [agregar conforme se sumen]    |                                    |                                          |

─────────────────────────────────────────
```

---

### FASE 1 — Recolección

**Objetivo:** Reunir señales desde múltiples fuentes, con BigQuery como backbone de datos cuantitativos.

**Fuentes cuantitativas (BigQuery):**

Toda data cuantitativa se consulta y almacena en BigQuery bajo `itc-data-governance-01.aodarm`. Cada query de recolección debe seguir el estándar:

- Usar CTEs encadenados (nunca subconsultas anidadas ni tablas temporales fuera de `CREATE OR REPLACE TABLE`)
- Rutas completas con backticks: `` `itc-data-governance-01.aodarm.nombre_tabla` ``
- Prefijo `tmp_` para tablas intermedias
- Incluir bloque de validación al final de cada query (conteos, distribuciones, duplicados, nulls)
- Documentar en el header del SQL: tabla input, tabla output, y pregunta de negocio que responde

**Ejemplo de tabla input ya estandarizada:**

| Tabla | Input | Output | Pregunta |
|-------|-------|--------|----------|
| Clasificación de cliente por canal | `tmp_transacciones_totales_ngr` | `tmp_cliente_canal_12m` | ¿Cuál es el tipo de cliente según su preferencia de canal? |
| Detalle clientes sin definir | `tmp_cliente_canal_12m` | `tmp_cliente_canal_sin_definir` | ¿Qué perfil tienen los clientes con <3 transacciones? |

**Fuentes cualitativas (complementarias):**
- Entrevistas a usuarios (mínimo 8-15 para patrones)
- Sesiones de usabilidad (5-8 por diseño)
- Verbatims de soporte y reclamos
- Social listening y reviews
- Observación etnográfica / contextual

**Principio clave:** Triangulación — un insight robusto requiere evidencia de al menos 2 fuentes diferentes (cuantitativa + cualitativa). BigQuery provee la base cuantitativa; las fuentes cualitativas dan el "por qué".

**Bloque de validación obligatorio por cada tabla generada:**

Cada query que genere una tabla nueva en BigQuery debe incluir al final un bloque de control con:

```sql
-- VALIDACIÓN
-- 1. Conteo total de registros y clientes únicos
-- 2. Distribución de la variable de clasificación (% por categoría)
-- 3. Verificación de duplicados (debe retornar 0)
-- 4. Verificación de NULLs en campos clave
-- 5. Consistencia cruzada entre tablas relacionadas
```

---

### FASE 3 — Codificación

**Objetivo:** Etiquetar y organizar los datos crudos en categorías manejables.

**Sistema de etiquetas recomendado:**

| Etiqueta | Uso | Ejemplo |
|----------|-----|---------|
| `[COMPORTAMIENTO]` | Lo que hace el usuario | "Compara 3+ opciones antes de decidir" |
| `[MOTIVACIÓN]` | Por qué lo hace | "Busca validación de que eligió bien" |
| `[FRUSTRACIÓN]` | Qué lo detiene o molesta | "No encuentra reviews de usuarios reales" |
| `[CONTEXTO]` | Cuándo/dónde ocurre | "Investiga en móvil, compra en desktop" |
| `[NECESIDAD]` | Qué necesita (dicho o no dicho) | "Necesita sentir control sobre el proceso" |
| `[CITA]` | Palabras textuales del usuario | "Siento que me están ocultando algo" |
| `[SORPRESA]` | Algo inesperado o contradictorio | "Usuarios premium usan menos features" |

**Tip:** Las etiquetas `[SORPRESA]` suelen ser la semilla de los insights más valiosos.

---

### FASE 4 — Síntesis

**Objetivo:** Detectar patrones, tensiones y conexiones entre los datos codificados.

**Técnica 1: Clustering por Afinidad**

Agrupa las etiquetas en temas. Si tienes 50 data points, deberías obtener 5-8 clusters temáticos.

```
Cluster: "Parálisis de elección"
├── [COMPORTAMIENTO] Abre 12 tabs para comparar
├── [FRUSTRACIÓN] "Hay demasiadas opciones"
├── [MOTIVACIÓN] Miedo a elegir mal
├── [CONTEXTO] Peor en categorías con poca experiencia
└── [CITA] "Ojalá alguien me dijera cuál es la mejor"
```

**Técnica 2: Matriz de Tensiones**

Busca contradicciones — ahí viven los insights más potentes.

| Lo que dicen | Lo que hacen | Tensión |
|-------------|-------------|---------|
| "Quiero variedad" | Compran lo mismo siempre | Seguridad disfrazada de exploración |
| "No me importa el precio" | Comparan obsesivamente | El precio importa, pero admitirlo no |
| "Prefiero autoservicio" | Llaman a soporte constantemente | Quieren autonomía pero necesitan guía |

**Técnica 3: Los 5 Porqués**

Para cada hallazgo, pregunta "¿por qué?" cinco veces hasta llegar a la raíz.

```
Observación: Los usuarios no completan el onboarding.
¿Por qué? → No ven valor inmediato.
¿Por qué? → El tutorial muestra features, no beneficios.
¿Por qué? → Fue diseñado desde la perspectiva del producto, no del usuario.
¿Por qué? → No se investigó qué problema quieren resolver primero.
¿Por qué? → El equipo asumió que todos llegan con el mismo objetivo.

→ INSIGHT: Los usuarios llegan con un problema específico urgente, pero el onboarding los trata como estudiantes de un curso genérico. Personalizar el primer minuto según el caso de uso puede transformar la activación.
```

---

### FASE 5 — Formulación

**Objetivo:** Escribir insights claros, accionables y compartibles.

**Plantilla de Insight Card:**

```
─────────────────────────────────────────
INSIGHT #[número]
Título: [Nombre memorable y conciso]
─────────────────────────────────────────

OBSERVACIÓN:
[Qué vimos / qué pasa]

TENSIÓN:
[Por qué es relevante / qué contradicción revela]

IMPLICACIÓN:
[Qué significa para el negocio / producto]

OPORTUNIDAD:
[Qué podríamos hacer con esto]

EVIDENCIA:
- Cuantitativa: [dato + fuente]
- Cualitativa: [cita + contexto]
- Frecuencia: [X de Y participantes / % de usuarios]

CONFIANZA: [Alta / Media / Baja]
─────────────────────────────────────────
```

**Test de calidad — Un buen insight debe pasar estas 5 pruebas:**

1. **Test de "¿Y qué?"** — Si alguien pregunta "¿y qué?", ¿puedes responder con una acción concreta?
2. **Test de novedad** — ¿Dice algo que el equipo no sabía o no había articulado?
3. **Test de especificidad** — ¿Es específico de tu usuario/contexto, o es una verdad genérica?
4. **Test de tensión** — ¿Revela una contradicción, barrera o necesidad oculta?
5. **Test de accionabilidad** — ¿Sugiere al menos una cosa que podrías hacer diferente?

---

### FASE 6 — Priorización

**Objetivo:** Decidir sobre cuáles insights actuar primero.

**Matriz de Priorización:**

Evalúa cada insight en dos ejes (1-5 cada uno):

**Eje Y — Impacto potencial:**
- Alcance: ¿A cuántos usuarios/clientes afecta?
- Magnitud: ¿Qué tan significativo es el efecto?
- Alineación: ¿Qué tan conectado está con objetivos del negocio?

**Eje X — Facilidad de acción:**
- Viabilidad: ¿Podemos hacer algo con los recursos actuales?
- Velocidad: ¿Qué tan rápido podemos actuar?
- Riesgo: ¿Qué tan bajo es el riesgo de actuar?

| Cuadrante | Impacto | Facilidad | Acción |
|-----------|---------|-----------|--------|
| **Quick Wins** | Alto | Alta | Ejecutar ya |
| **Apuestas Estratégicas** | Alto | Baja | Planificar y priorizar |
| **Optimizaciones** | Bajo | Alta | Delegar o automatizar |
| **Descarte Informado** | Bajo | Baja | Documentar y archivar |

---

## 4. Salida del Framework (BigQuery)

El output de este framework **no es un reporte** (eso se construirá después). La salida es un conjunto de tablas estructuradas en BigQuery que contienen los insights priorizados y listos para ser consumidos.

**Tabla de salida esperada:** `itc-data-governance-01.aodarm.tmp_insights_priorizados`

```sql
-- Estructura esperada de la tabla de insights
CREATE OR REPLACE TABLE `itc-data-governance-01.aodarm.tmp_insights_priorizados`
(
  insight_id            STRING,     -- Identificador único (INS-001, INS-002...)
  titulo                STRING,     -- Nombre memorable del insight
  nivel                 STRING,     -- L1 a L5
  observacion           STRING,     -- Qué vimos
  tension               STRING,     -- Por qué importa
  implicacion           STRING,     -- Qué significa para el negocio
  oportunidad           STRING,     -- Qué podríamos hacer
  evidencia_cuanti      STRING,     -- Dato + fuente (tabla BQ de origen)
  evidencia_cuali       STRING,     -- Cita + contexto
  tabla_origen          STRING,     -- Tabla BQ que sustenta el insight
  confianza             STRING,     -- Alta / Media / Baja
  score_impacto         INT64,      -- 1-5
  score_facilidad       INT64,      -- 1-5
  cuadrante             STRING,     -- Quick Win / Apuesta / Optimización / Descarte
  estado                STRING,     -- Nuevo / Validado / En acción / Archivado
  fecha_creacion        DATE,       -- Fecha de generación
  responsable           STRING      -- Quién lo trabaja
);
```

**Pipeline completo en BigQuery:**

```
FASE 0 (Encuadre)
    │
    ▼
FASE 1 (Recolección) ─── tmp_transacciones_totales_ngr
    │                     tmp_cliente_canal_12m
    │                     tmp_cliente_canal_sin_definir
    │                     [+ tablas futuras]
    ▼
FASE 3-5 (Codificación → Síntesis → Formulación)
    │
    ▼
FASE 6 (Priorización) ── tmp_insights_priorizados
    │
    ▼
[REPORTE — se construirá después]
```

---

## 5. Anti-Patrones: Errores Comunes

| Anti-patrón | Ejemplo | Corrección |
|-------------|---------|------------|
| **Dato disfrazado de insight** | "El 40% usa móvil" | Pregunta "¿por qué?" y "¿y qué?" |
| **Insight genérico** | "Los usuarios quieren experiencias personalizadas" | Especifica qué tipo de personalización y cuándo |
| **Insight sin evidencia** | "Creemos que los usuarios prefieren X" | Respalda con datos concretos y citas |
| **Insight sin tensión** | "Los usuarios quieren que sea fácil" | Encuentra la contradicción oculta |
| **Insight sin acción** | "Los millennials son digitales" | Conecta siempre con un "por lo tanto..." |
| **Sesgo de confirmación** | Solo seleccionas datos que validan tu hipótesis | Busca activamente evidencia contradictoria |

---

## 6. Checklist de Calidad

Antes de presentar un insight, verifica:

- [ ] Está respaldado por al menos 2 fuentes (cuanti + cuali)
- [ ] Tiene los 3 componentes: observación, tensión, implicación
- [ ] Pasa los 5 tests de calidad
- [ ] Tiene nivel de confianza declarado
- [ ] Sugiere al menos 1 acción concreta
- [ ] Está formulado en lenguaje que la audiencia entiende
- [ ] No es una verdad obvia ni un dato sin contexto
- [ ] Tiene un título memorable de máximo 8 palabras

---

## 7. Plantillas Rápidas

### Plantilla: Insight Card (versión corta)

```
💡 [TÍTULO]
📊 Evidencia: [dato clave]
💬 Voz del usuario: "[cita]"
⚡ Oportunidad: [qué hacer]
🎯 Confianza: [Alta/Media/Baja]
```

### Plantilla: De Dato a Insight (escalera)

```
DATO:       [Número o hecho]
    ↓
PATRÓN:     [Tendencia o recurrencia]
    ↓
CAUSA:      [Por qué ocurre]
    ↓
TENSIÓN:    [Contradicción o barrera]
    ↓
INSIGHT:    [Verdad profunda + oportunidad]
    ↓
ACCIÓN:     [Qué hacer con esto]
```

### Plantilla: Insight Narrativo (para presentaciones)

```
Siempre pensamos que [CREENCIA ACTUAL].
Pero cuando [EVIDENCIA], descubrimos que [REALIDAD].
Esto importa porque [IMPACTO EN NEGOCIO].
La oportunidad es [ACCIÓN PROPUESTA].
```

---

*Framework diseñado con BigQuery como backbone de datos. Cada fase genera tablas validadas que alimentan la siguiente. El reporte final se construirá como capa de visualización sobre estos outputs.*
