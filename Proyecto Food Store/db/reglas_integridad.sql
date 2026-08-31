-- ============================================================
-- Script  : reglas_integridad.sql
-- Base    : Food_store_copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-08-28
-- Desc    : Implementación de Reglas de Integridad 1 y 2
--           Regla 1: Solo productos activos en detalle_pedido.
--           Regla 2: Todo pedido debe tener al menos un detalle.
-- PRECONDICIÓN: Ejecutar pg_dump antes de correr este script
-- ============================================================

-- ============================================================
-- REGLA 1: Solo productos activos en detalle_pedido
-- ============================================================

-- Función para verificar que el producto referenciado esté activo
CREATE OR REPLACE FUNCTION fn_check_producto_activo()
RETURNS TRIGGER AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo INTO v_activo
    FROM producto
    WHERE id = NEW.producto_id;

    IF v_activo IS NULL THEN
        RAISE EXCEPTION 'Operación rechazada: El producto ID % no existe.', NEW.producto_id;
    ELSIF v_activo = FALSE THEN
        RAISE EXCEPTION 'Operación rechazada: El producto ID % se encuentra inactivo y no se puede agregar al detalle del pedido.', NEW.producto_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger BEFORE en detalle_pedido para rechazo inmediato
DROP TRIGGER IF EXISTS trg_check_producto_activo ON detalle_pedido;

CREATE TRIGGER trg_check_producto_activo
BEFORE INSERT OR UPDATE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_check_producto_activo();


-- ============================================================
-- REGLA 2: Todo pedido debe tener al menos un detalle_pedido
-- ============================================================

-- Función auxiliar de aserción: verifica que un pedido tenga al menos un detalle
CREATE OR REPLACE FUNCTION fn_assert_pedido_tiene_detalle(p_pedido_id BIGINT)
RETURNS VOID AS $$
DECLARE
    v_cant_detalles INTEGER;
BEGIN
    -- Solo verificar si el pedido existe (por si fue eliminado en la misma transacción)
    IF EXISTS (SELECT 1 FROM pedido WHERE id = p_pedido_id) THEN
        SELECT COUNT(*) INTO v_cant_detalles
        FROM detalle_pedido
        WHERE pedido_id = p_pedido_id;

        IF v_cant_detalles = 0 THEN
            RAISE EXCEPTION 'Operación rechazada: El pedido ID % debe tener al menos un registro asociado en detalle_pedido.', p_pedido_id;
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función disparadora principal para la validación diferida al COMMIT
CREATE OR REPLACE FUNCTION fn_verificar_pedido_tiene_detalle()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'pedido' THEN
        IF TG_OP IN ('INSERT', 'UPDATE') THEN
            PERFORM fn_assert_pedido_tiene_detalle(NEW.id);
        END IF;
        IF TG_OP = 'UPDATE' AND OLD.id IS DISTINCT FROM NEW.id THEN
            PERFORM fn_assert_pedido_tiene_detalle(OLD.id);
        END IF;

    ELSIF TG_TABLE_NAME = 'detalle_pedido' THEN
        IF TG_OP = 'DELETE' THEN
            PERFORM fn_assert_pedido_tiene_detalle(OLD.pedido_id);
        ELSIF TG_OP = 'INSERT' THEN
            PERFORM fn_assert_pedido_tiene_detalle(NEW.pedido_id);
        ELSIF TG_OP = 'UPDATE' THEN
            PERFORM fn_assert_pedido_tiene_detalle(OLD.pedido_id);
            IF NEW.pedido_id IS DISTINCT FROM OLD.pedido_id THEN
                PERFORM fn_assert_pedido_tiene_detalle(NEW.pedido_id);
            END IF;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggers de restricción diferidos (DEFERRABLE INITIALLY DEFERRED)
DROP TRIGGER IF EXISTS trg_verificar_pedido ON pedido;
DROP TRIGGER IF EXISTS trg_verificar_detalle_pedido ON detalle_pedido;

CREATE CONSTRAINT TRIGGER trg_verificar_pedido
AFTER INSERT OR UPDATE ON pedido
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_verificar_pedido_tiene_detalle();

CREATE CONSTRAINT TRIGGER trg_verificar_detalle_pedido
AFTER INSERT OR UPDATE OR DELETE ON detalle_pedido
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION fn_verificar_pedido_tiene_detalle();
