-- ============================================================
-- Script  : trigger_transicion.sql
-- Base    : Food_Store_Copia (PostgreSQL 16+)
-- Autor   : Saleme Ismael — BD II U1 — Cierra Pt.7 rúbrica (tablas de transición)
-- Desc    : Trigger FOR EACH STATEMENT con REFERENCING NEW/OLD TABLE
--           Auditoría de cambios en pedido — demuestra tablas de transición
--           Complementa db/reglas_integridad.sql (que usa FOR EACH ROW)
-- PRECOND : Protocolo Seguridad: pg_dump previo + BEGIN; ROLLBACK; de prueba
--           No interfiere con R1/R2 (es AFTER STATEMENT de auditoría, no de validación)
-- ============================================================

-- 1. Tabla de auditoría (si no existe)
CREATE TABLE IF NOT EXISTS log_pedido_auditoria (
    log_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    operacion   CHAR(1) NOT NULL CHECK (operacion IN ('I','U','D')),
    pedido_id   BIGINT,
    cliente_id  BIGINT,
    forma_pago  forma_pago,
    fecha_old   TIMESTAMPTZ,
    fecha_new   TIMESTAMPTZ,
    fecha_log   TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario     TEXT NOT NULL DEFAULT current_user
);

COMMENT ON TABLE log_pedido_auditoria IS 'Auditoría STATEMENT-level de pedido usando tablas de transición (NEW TABLE / OLD TABLE). Pt.7 rúbrica.';

-- 2. Función de auditoría que recibe tablas de transición (statement-level)
CREATE OR REPLACE FUNCTION fn_auditoria_pedido_transicion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- TG_OP indica operación; las tablas old_table / new_table se referencian
    -- según el REFERENCING de cada trigger (ver abajo). Usamos TG_TABLE_NAME para distinguir.
    -- Para INSERT: solo new_table tiene filas
    -- Para DELETE: solo old_table
    -- Para UPDATE: ambas

    IF TG_OP = 'INSERT' THEN
        INSERT INTO log_pedido_auditoria(operacion, pedido_id, cliente_id, forma_pago, fecha_new)
        SELECT 'I', id, cliente_id, forma_pago, fecha FROM new_table;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO log_pedido_auditoria(operacion, pedido_id, cliente_id, forma_pago, fecha_old)
        SELECT 'D', id, cliente_id, forma_pago, fecha FROM old_table;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Logueamos viejo y nuevo en dos inserts separados para preservar ambas fechas
        -- Opcional: log solo cambios de forma_pago/cliente_id
        INSERT INTO log_pedido_auditoria(operacion, pedido_id, cliente_id, forma_pago, fecha_old, fecha_new)
        SELECT 'U', n.id, n.cliente_id, n.forma_pago, o.fecha, n.fecha
        FROM new_table n
        JOIN old_table o ON o.id = n.id;
    END IF;

    RETURN NULL; -- FOR EACH STATEMENT ignora RETURN
END;
$$;

COMMENT ON FUNCTION fn_auditoria_pedido_transicion() IS 'Función statement-level que lee transition tables (new_table/old_table).';

-- 3. Triggers STATEMENT con REFERENCING (uno por operación, cada uno expone su transition table)
--    PostgreSQL exige REFERENCING en cada CREATE TRIGGER si se usan transition tables

DROP TRIGGER IF EXISTS trg_pedido_audit_insert ON pedido;
CREATE TRIGGER trg_pedido_audit_insert
AFTER INSERT ON pedido
REFERENCING NEW TABLE AS new_table
FOR EACH STATEMENT
EXECUTE FUNCTION fn_auditoria_pedido_transicion();

DROP TRIGGER IF EXISTS trg_pedido_audit_delete ON pedido;
CREATE TRIGGER trg_pedido_audit_delete
AFTER DELETE ON pedido
REFERENCING OLD TABLE AS old_table
FOR EACH STATEMENT
EXECUTE FUNCTION fn_auditoria_pedido_transicion();

DROP TRIGGER IF EXISTS trg_pedido_audit_update ON pedido;
CREATE TRIGGER trg_pedido_audit_update
AFTER UPDATE ON pedido
REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
FOR EACH STATEMENT
EXECUTE FUNCTION fn_auditoria_pedido_transicion();

-- ============================================================
-- EJEMPLO DE USO (para defensa oral e informe)
-- ============================================================

-- Limpiar log:
-- TRUNCATE log_pedido_auditoria RESTART IDENTITY;

-- Prueba INSERT statement-level (multi-fila demuestra ventaja de transition vs ROW):
-- BEGIN;
-- INSERT INTO pedido(cliente_id, forma_pago) VALUES (1,'EFECTIVO'), (2,'TARJETA');
-- -- R2 diferido: falta detalle → el COMMIT fallará si no insertamos detalles; para probar auditoría sin R2, deshabilitar temporalmente:
-- -- ALTER TABLE pedido DISABLE TRIGGER trg_verificar_pedido;
-- -- INSERT ... ; SELECT * FROM log_pedido_auditoria; -- debe mostrar 2 filas 'I'
-- -- ROLLBACK;

-- Prueba UPDATE statement-level:
-- BEGIN;
-- UPDATE pedido SET forma_pago='TRANSFERENCIA' WHERE id IN (1,2);
-- SELECT operacion, pedido_id, forma_pago FROM log_pedido_auditoria ORDER BY log_id DESC LIMIT 5;
-- ROLLBACK;

-- Prueba con procedimiento (integra Pt.6):
-- BEGIN;
-- CALL sp_crear_pedido(1,'TARJETA',ARRAY[1],ARRAY[1],NULL);
-- SELECT * FROM log_pedido_auditoria ORDER BY log_id DESC LIMIT 2; -- 'I' del pedido creado
-- ROLLBACK;

-- Ver triggers:
-- SELECT trigger_name, action_statement FROM information_schema.triggers WHERE event_object_table='pedido';
-- \d log_pedido_auditoria

-- ============================================================
-- JUSTIFICACIÓN PARA EL INFORME (copiar a Pt.7)
-- ============================================================
-- Este trigger demuestra "tablas de transición" exigidas en rúbrica Pt.7:
--   - Usa REFERENCING NEW TABLE / OLD TABLE (sintaxis PostgreSQL 10+)
--   - Es FOR EACH STATEMENT (no ROW), procesa lote de filas en una sola invocación
--   - Es AFTER STATEMENT, ideal para auditoría sin penalizar cada fila
-- Se conserva junto a los triggers ROW de db/reglas_integridad.sql (R1/R2 de negocio) — ambos patrones coexisten y se explican en defensa.
-- Costo: statement-level es más eficiente para bulk INSERT/UPDATE que ROW-level.
