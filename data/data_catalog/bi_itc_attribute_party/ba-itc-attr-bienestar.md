# Catálogo de Datos — `ba_itc_attr_bienestar`

**Proyecto:** `intercorp-data-storage-pv`
**Dataset:** `bi_itc_attribute_party`
**Tabla completa:** `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar`

---

## Descripción

Atributos de **salud y bienestar clínico** del cliente, agregados por mes. Registra la actividad en clínicas del grupo Aviva (Intercorp): atenciones por tipo de servicio (consulta externa, emergencia, hospitalización), 40 especialidades médicas, tipo de pago (particular, EPS, seguro) y condiciones de salud específicas.

---

## Metadata BigQuery

| Atributo | Valor |
|---|---|
| Particionado por | `process_date` (DAY) — primer día del mes, contiene toda la información del mes |
| Clusterizado por | `id` |
| Filas aprox. | ~4.9M |
| Columnas | 452 |
| Bytes por partición | ~650 MB |
| Frecuencia | Mensual |

> `process_date = '2026-01-01'` contiene toda la data de enero 2026.

---

## 1. Identificadores y auditoría

| Campo | Tipo | Descripción |
|---|---|---|
| `process_date` | DATE | Campo de partición. Primer día del mes |
| `id` | STRING | Documento de identidad del cliente. Campo clustered. ⚠️ Usa `id`, no `id_intercorp` |
| `fecha_registro` | DATE | Fecha de primer registro del paciente |
| `creation_user` | STRING | SA o usuario que creó el registro |
| `load_date` | DATETIME | Fecha y hora de carga |
| `record_source` | STRING | Origen del registro |
| `dq_flag_ind` | BOOLEAN | Flag de control de calidad |
| `dq_control_msg` | STRING | Mensaje de control de calidad |
| `dq_config_id` | STRING | ID de configuración DQ |

> ⚠️ Para cruzar con `ba_itc_attr_retail` u otras tablas `ba_*`: `bienestar.id = retail.id_intercorp`

---

## 2. Perfil del paciente

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_cliente_fisico` | INTEGER | 1 = asiste a clínica física |
| `flag_cliente_online` | INTEGER | 1 = usa telemedicina / atención online |
| `flag_cliente_omnicanal` | INTEGER | 1 = usa canal físico y online |
| `antiguedad_paciente_meses` | INTEGER | Meses desde la primera atención registrada |
| `flag_cliente_nuevo` | INTEGER | 1 = primer registro en el mes de `process_date` |
| `grupo_edad` | STRING | Grupo etario del paciente |
| `flag_meses_edad` | INTEGER | Indicador derivado de la edad en meses |
| `genero` | STRING | Género del paciente |

---

## 3. Atenciones totales

| Campo | Tipo | Descripción |
|---|---|---|
| `cant_atenciones_1m` | INTEGER | Total atenciones médicas (todos los tipos) en el mes |
| `cant_atenciones_3m` | INTEGER | Total atenciones en últimos 3 meses |
| `cant_atenciones_6m` | INTEGER | Total atenciones en últimos 6 meses |
| `cant_atenciones_9m` | INTEGER | Total atenciones en últimos 9 meses |
| `cant_atenciones_12m` | INTEGER | Total atenciones en últimos 12 meses |

---

## 4. Tipo de pago (flag por ventana `_1m` a `_12m`)

| Campo | Descripción |
|---|---|
| `flag_pago_particular_{Nm}` | 1 = atención pagada de forma particular |
| `flag_pago_eps_{Nm}` | 1 = atención cubierta por alguna EPS |
| `flag_pago_eps_rimac_{Nm}` | 1 = cubierta por EPS Rímac |
| `flag_pago_eps_pacifico_{Nm}` | 1 = cubierta por EPS Pacífico |
| `flag_pago_eps_mapfre_{Nm}` | 1 = cubierta por EPS Mapfre |
| `flag_pago_seguro_aviva_{Nm}` | 1 = cubierta por seguro Aviva |
| `flag_pago_seguro_otros_{Nm}` | 1 = cubierta por otro seguro |
| `flag_pago_otros_{Nm}` | 1 = otro tipo de pago |

---

## 5. Consulta Externa (flag + cantidad + monto por ventana)

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_consulta_externa_{Nm}` | INTEGER | 1 = tuvo consulta externa en N meses |
| `num_consulta_externa_{Nm}` | INTEGER | Número de consultas externas en N meses |
| `monto_consulta_externa_{Nm}` | NUMERIC | Monto total en consultas externas (S/) |
| `flag_atencion_consulta_{Nm}` | INTEGER | 1 = atención de consulta médica |
| `flag_atencion_farmacia_{Nm}` | INTEGER | 1 = atención de farmacia |
| `flag_atencion_laboratorio_{Nm}` | INTEGER | 1 = atención de laboratorio |
| `flag_atencion_otros_{Nm}` | INTEGER | 1 = otro tipo de atención |

---

## 6. Emergencia

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_emergencia_{Nm}` | INTEGER | 1 = tuvo atención de emergencia |
| `num_atencion_emergencia_{Nm}` | INTEGER | Número de atenciones de emergencia |
| `monto_emergencia_{Nm}` | NUMERIC | Monto total en emergencias (S/) |
| `flag_emergencia_consulta_{Nm}` | INTEGER | 1 = emergencia incluyó consulta médica |
| `flag_emergencia_farmacia_{Nm}` | INTEGER | 1 = emergencia incluyó farmacia |
| `flag_emergencia_laboratorio_{Nm}` | INTEGER | 1 = emergencia incluyó laboratorio |
| `flag_emergencia_otros_{Nm}` | INTEGER | 1 = emergencia incluyó otro servicio |

---

## 7. Hospitalización

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_hospitalizacion_{Nm}` | INTEGER | 1 = tuvo hospitalización |
| `num_atencion_hospitalaria_{Nm}` | INTEGER | Número de atenciones hospitalarias |
| `monto_hospitalizacion_{Nm}` | NUMERIC | Monto total en hospitalización (S/) |
| `flag_hospitalizacion_consulta_{Nm}` | INTEGER | 1 = hospitalización incluyó consulta |
| `flag_hospitalizacion_farmacia_{Nm}` | INTEGER | 1 = hospitalización incluyó farmacia |
| `flag_hospitalizacion_laboratorio_{Nm}` | INTEGER | 1 = hospitalización incluyó laboratorio |
| `flag_hospitalizacion_otros_{Nm}` | INTEGER | 1 = hospitalización incluyó otro servicio |

---

## 8. Eventos de salud específicos

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_parto_{Nm}` | INTEGER | 1 = registro de parto (gestante / puérpera) |
| `flag_cirugias_{Nm}` | INTEGER | 1 = tuvo alguna cirugía |

---

## 9. Programas de salud Aviva

| Campo | Tipo | Descripción |
|---|---|---|
| `flag_aviva_cuida_{Nm}` | INTEGER | 1 = inscrito en programa Aviva Cuida |
| `flag_aviva_cura_{Nm}` | INTEGER | 1 = inscrito en programa Aviva Cura |

---

## 10. Condiciones de cuidado por área de salud

| Campo | Área |
|---|---|
| `flag_cuidado_mujer_{Nm}` | Salud femenina / ginecología |
| `flag_cuidado_hombre_{Nm}` | Salud masculina |
| `flag_cuidado_infantil_{Nm}` | Pediatría / salud infantil |
| `flag_cuidado_piel_{Nm}` | Dermatología |
| `flag_cuidado_respiratorio_{Nm}` | Sistema respiratorio |
| `flag_cuidado_corazon_{Nm}` | Cardiología |
| `flag_cuidado_vista_{Nm}` | Oftalmología |
| `flag_cuidado_adulto_mayor_{Nm}` | Geriatría / adulto mayor |
| `flag_cuidado_digestivo_{Nm}` | Gastroenterología |
| `flag_cuidado_emocional_{Nm}` | Salud mental (psicología / psiquiatría) |
| `flag_cuidado_dental_{Nm}` | Odontología |
| `flag_cuidado_oseo_muscular_{Nm}` | Traumatología / fisiatría / reumatología |

---

## 11. Especialidades médicas consultadas (flag `_1m` a `_12m`)

1 = al menos una atención con ese especialista en N meses.

| Campo | Especialidad |
|---|---|
| `flag_anestesiologia_{Nm}` | Anestesiología |
| `flag_biologo_{Nm}` | Biólogo (laboratorio clínico) |
| `flag_cardiologia_{Nm}` | Cardiología |
| `flag_cirugia_cabeza_cuello_{Nm}` | Cirugía de cabeza y cuello |
| `flag_cirugia_general_{Nm}` | Cirugía general |
| `flag_cirugia_infantil_{Nm}` | Cirugía infantil |
| `flag_cirugia_oncologica_{Nm}` | Cirugía oncológica |
| `flag_cirugia_plastica_facial_{Nm}` | Cirugía plástica facial |
| `flag_cirugia_toracica_{Nm}` | Cirugía torácica |
| `flag_dermatologia_{Nm}` | Dermatología |
| `flag_emergenciologo_{Nm}` | Emergenciología |
| `flag_endocrinologia_{Nm}` | Endocrinología |
| `flag_endocrinologo_infantil_{Nm}` | Endocrinología infantil |
| `flag_externo_{Nm}` | Médico externo (fuera de red Aviva) |
| `flag_fisiatria_{Nm}` | Fisiatría / rehabilitación |
| `flag_fisioterapeuta_uroginecologico_{Nm}` | Fisioterapia uroginecológica |
| `flag_gastroenterologia_{Nm}` | Gastroenterología |
| `flag_geriatria_{Nm}` | Geriatría |
| `flag_ginecologia_{Nm}` | Ginecología |
| `flag_hematologia_{Nm}` | Hematología |
| `flag_infectologia_{Nm}` | Infectología |
| `flag_medicina_adolescente_{Nm}` | Medicina del adolescente |
| `flag_medicina_general_familiar_{Nm}` | Medicina general / familiar |
| `flag_medicina_interna_{Nm}` | Medicina interna |
| `flag_nefrologia_{Nm}` | Nefrología |
| `flag_neumologia_{Nm}` | Neumología |
| `flag_neurocirugia_{Nm}` | Neurocirugía |
| `flag_neurologia_{Nm}` | Neurología |
| `flag_nutricion_{Nm}` | Nutrición |
| `flag_obstetricia_{Nm}` | Obstetricia |
| `flag_odontologia_{Nm}` | Odontología |
| `flag_oftalmologia_{Nm}` | Oftalmología |
| `flag_otorrinolaringologia_{Nm}` | Otorrinolaringología (ORL) |
| `flag_pediatria_{Nm}` | Pediatría |
| `flag_psicologia_{Nm}` | Psicología |
| `flag_psiquiatria_{Nm}` | Psiquiatría |
| `flag_radiologia_oncologica_{Nm}` | Radioterapia oncológica |
| `flag_reumatologia_{Nm}` | Reumatología |
| `flag_terapia_intensiva_infantil_{Nm}` | Terapia intensiva infantil (UCI pediátrica) |
| `flag_traumatologia_{Nm}` | Traumatología y ortopedia |
| `flag_urologia_{Nm}` | Urología |

---

## 12. Ventanas temporales

| Sufijo | Contenido | Sumable entre particiones |
|---|---|---|
| `_1m` | Solo el mes de `process_date` | Si |
| `_3m` / `_6m` / `_9m` / `_12m` | Acumulado hasta `process_date` | No |

---

## 13. Queries de referencia

```sql
-- Pacientes con atención clínica enero 2026
SELECT id, cant_atenciones_1m,
       flag_consulta_externa_1m, flag_emergencia_1m, flag_hospitalizacion_1m,
       flag_pago_eps_1m, flag_pago_particular_1m, monto_consulta_externa_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar`
WHERE process_date = '2026-01-01'
  AND cant_atenciones_1m > 0;

-- Gestantes / puérperas
SELECT id, flag_parto_6m, flag_ginecologia_6m, flag_obstetricia_6m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar`
WHERE process_date = '2026-01-01'
  AND flag_parto_6m = 1;

-- Adultos mayores con enfermedades crónicas (cardio + endocrinología)
SELECT id, flag_cardiologia_12m, flag_endocrinologia_12m,
       cant_atenciones_12m, monto_consulta_externa_12m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar`
WHERE process_date = '2026-01-01'
  AND flag_cuidado_adulto_mayor_12m = 1
  AND (flag_cardiologia_12m = 1 OR flag_endocrinologia_12m = 1);

-- Cruce bienestar + retail (farmacias)
-- ⚠️ bienestar.id = retail.id_intercorp
SELECT b.id, b.cant_atenciones_1m, b.flag_ginecologia_1m,
       r.far_frecuencia_1m, r.far_mtoprom_medicamento_1m
FROM `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar` b
JOIN `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_retail` r
  ON b.id = r.id_intercorp AND b.process_date = r.process_date
WHERE b.process_date = '2026-01-01'
  AND b.cant_atenciones_1m > 0;
```

---

## 14. Reglas de negocio

1. **Filtrar siempre por `process_date`** — primer día del mes que contiene toda la info del mes.
2. **Clave: `id`** — no `id_intercorp`. Para cruzar con otras tablas `ba_*`: `b.id = r.id_intercorp`.
3. **Fuente: clínicas Aviva** — solo captura atenciones dentro de la red Aviva. No incluye EsSalud ni otras clínicas privadas.
4. **`monto_*`** en soles (S/).
5. **Todos los flags son 0/1/NULL** — NULL = dato no disponible; 0 = sin actividad en ese período.

---

*Actualizado: 2026-06-06 | Fuente: schema real via MCP BigQuery | Tabla: `intercorp-data-storage-pv.bi_itc_attribute_party.ba_itc_attr_bienestar`*
