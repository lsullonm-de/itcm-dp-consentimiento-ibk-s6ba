-- =============================================================
-- PLANTILLA DE CABECERA PARA SCRIPTS SQL — ITC Data Platform
-- Pegar al inicio de cada archivo .sql antes del código.
-- =============================================================


-- ─────────────────────────────────────────────────────────────
-- TIPO 1: DDL  (alter_ba_itc_attr_[tabla]_[fecha].sql)
-- Usar cuando se agregan columnas nuevas a una tabla existente.
-- ─────────────────────────────────────────────────────────────
/*
== DDL: alter_[tabla]_[YYYYMMDD].sql ========================
   Tabla   : [proyecto].bi_itc_attribute_party.[tabla_destino]
   Atributo: [nombre descriptivo del grupo de columnas]
   Empresa : [far_ | spsa_ | oechsle_ | promart_ | ibk_ | ...]
   Métricas: [mto_ | numtrx_ | mtoprom_ | mtomax_ | mtomin_ | flag_]
   Ventanas: [1m | 3m | 6m | 9m | 12m]
   ──────────────────────────────────────────────────────────
   Lógica  : [Una oración con el filtro de negocio aplicado.
              Ej: "Compras en categoría MEDICAMENTO según
              tabla c_clasificacion_marcas_retail_ibk."]
   ──────────────────────────────────────────────────────────
   SP que lo calcula : sp_load_tmp_[tabla]_[N].sql
   Autor             : [nombre]
   Fecha             : [YYYY-MM-DD]
=============================================================*/


-- ─────────────────────────────────────────────────────────────
-- TIPO 2: SP temporal  (sp_load_tmp_ba_itc_attr_[tabla]_[N].sql)
-- Usar en cada stored procedure de carga parcial de atributos.
-- ─────────────────────────────────────────────────────────────
/*
== SP: sp_load_tmp_[tabla]_[N].sql ==========================
   Tabla destino : [proyecto].bi_itc_attribute_party.[tabla]
   Empresa       : [far_ | spsa_ | oechsle_ | ...]
   ──────────────────────────────────────────────────────────
   Atributos que calcula:
     [empresa]_[metrica]_[rubro]_1m  … _12m
     Ej: far_mto_medicamento_1m … far_mto_medicamento_12m
         far_numtrx_medicamento_1m … far_numtrx_medicamento_12m
   ──────────────────────────────────────────────────────────
   Fuentes:
     {v_input_t_retail_transaction}  -- transacciones retail
     {v_table_m_product}             -- catálogo de productos
     [agregar otras si aplican]
   ──────────────────────────────────────────────────────────
   Lógica de negocio:
     [Descripción del filtro/agrupación aplicado.
      Ej: "Filtra por empresa FAR (cod_empresa = 'FAR') y
      agrupa por categoría de producto de la tabla
      c_clasificacion_marcas_retail_ibk."]
   ──────────────────────────────────────────────────────────
   Dependencias:
     Requiere que tmp_[tabla]_[N-1] ya esté cargada.
     [Indicar si no tiene dependencia: "Ninguna."]
   ──────────────────────────────────────────────────────────
   Autor   : [nombre]
   Fecha   : [YYYY-MM-DD]
   Versión : [1.0]
=============================================================*/
