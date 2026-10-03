-- =====================================================================
-- TP Unidad 4 — Parte 1: FNBC sobre ControlLoteAlmacen (Food Store)
-- Archivo: tp_fnbc_control_lote.sql
-- Base objetivo: Food_Store_Copia (NO ejecutar sobre Food_Store)
-- Contenido: esquema original + instancia ejemplo + descomposición
--            BCNF + vista de compatibilidad + migración verificada
-- =====================================================================

-- ---------------------------------------------------------------------
-- PASO 0. Tablas maestras mínimas (stubs idempotentes).
-- El enunciado asume que lote, deposito y usuario ya existen.
-- Si ya existen en la base, estas sentencias no hacen nada.
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS deposito (
    id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS usuario (
    id BIGINT PRIMARY KEY
);

INSERT INTO lote (id) VALUES (501), (502), (503)
ON CONFLICT (id) DO NOTHING;

INSERT INTO deposito (id) VALUES (30), (31)
ON CONFLICT (id) DO NOTHING;

INSERT INTO usuario (id) VALUES (801), (802)
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------
-- PASO 1. Esquema ORIGINAL + instancia de ejemplo (enunciado 4.1).
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS control_lote_almacen CASCADE;

CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id) VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ---------------------------------------------------------------------
-- PASO 2. Descomposición BCNF (algoritmo visto en clase).
--
-- Dependencias funcionales del esquema R(L, D, R):
--   F1: {lote_id, deposito_id} -> responsable_control_id
--   F2: responsable_control_id -> deposito_id   (VIOLA FNBC)
--
-- Descomposición sobre la violadora F2 (X = responsable, Y = deposito):
--   R1(X ∪ Y) = responsable_deposito(responsable_control_id, deposito_id)
--   R2(R − Y) = control_lote(lote_id, responsable_control_id)
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS control_lote CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;

CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id)
);

CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- ---------------------------------------------------------------------
-- PASO 3. Vista de compatibilidad: reconstruye la relación original
-- mediante reunión natural sobre el atributo común (responsable).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM control_lote AS cl
JOIN responsable_deposito AS rd
  ON rd.responsable_control_id = cl.responsable_control_id;

-- ---------------------------------------------------------------------
-- PASO 4. Migración de la instancia de ejemplo hacia las tablas
-- descompuestas (idempotente: TRUNCATE + recarga).
-- ---------------------------------------------------------------------
TRUNCATE control_lote, responsable_deposito;

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id
FROM control_lote_almacen;

INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id
FROM control_lote_almacen;

-- ---------------------------------------------------------------------
-- PASO 5. Verificación de equivalencia (ambas deben devolver 0 filas).
-- ---------------------------------------------------------------------
-- Filas en el original que NO aparecen en la vista:
SELECT * FROM control_lote_almacen
EXCEPT
SELECT * FROM v_control_lote_almacen;

-- Filas en la vista que NO estaban en el original (tuplas espurias):
SELECT * FROM v_control_lote_almacen
EXCEPT
SELECT * FROM control_lote_almacen;

-- Control de cardinalidad:
-- Original: 3 filas | Vista: 3 filas | responsable_deposito: 2 filas | control_lote: 3 filas
SELECT 'original' AS tabla, COUNT(*) FROM control_lote_almacen
UNION ALL
SELECT 'vista', COUNT(*) FROM v_control_lote_almacen
UNION ALL
SELECT 'responsable_deposito', COUNT(*) FROM responsable_deposito
UNION ALL
SELECT 'control_lote', COUNT(*) FROM control_lote;
