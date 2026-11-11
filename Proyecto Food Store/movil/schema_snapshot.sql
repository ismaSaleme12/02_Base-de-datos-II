-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 2.a — Tabla de aterrizaje del CSV
-- ----------------------------------------------------------------------------
--  `snapshot_servidor` NO es una tabla de dominio: es la bandeja donde cae el
--  CSV tal cual lo exportó psql.
--
--  ¿Por qué no es STRICT? Porque el CSV es texto y psql escribe los booleanos
--  como 't'/'f'. Una tabla STRICT con columnas INTEGER rechazaría la
--  importación en la primera fila ("cannot store TEXT value in INTEGER
--  column"). Esta bandeja los acepta y los normaliza en el paso siguiente.
--
--  Las afinidades sí están declaradas: así los números del CSV ('150000')
--  aterrizan como INTEGER y no como texto. Si quedaran como texto, la
--  comparación del semáforo sería lexicográfica — y en SQLite cualquier texto
--  es mayor que cualquier número, así que '9' > 150000 sería verdadero.
--
--  Se recrea en cada carga: la instantánea es completa, no incremental.
-- ============================================================================

DROP TABLE IF EXISTS snapshot_servidor;

CREATE TABLE snapshot_servidor (
    id              INTEGER,
    nombre          TEXT,
    precio_centavos INTEGER,
    stock_visto     INTEGER,
    disponible      INTEGER,   -- aterriza 't'/'f' (texto); se normaliza a 1/0
    eliminado       INTEGER,   -- idem
    fecha_copia     TEXT
);
