-- ============================================================
-- Script  : procedimientos.sql
-- Base    : Food_Store_Copia (PostgreSQL 16+)
-- Autor   : Saleme Ismael — BD II U1-U3 — Cierra Pt.6 rúbrica (PROCEDURE + CALL)
-- Desc    : Procedimientos PL/pgSQL invocables con CALL + función auxiliar
--           Respetan R1 (producto activo) y R2 (pedido ≥1 detalle) y soft delete
-- PRECOND : Ejecutar sobre Food_Store_Copia (no Food_Store). pg_dump previo.
--           Requiere db/schema_tp1.sql y db/reglas_integridad.sql ya aplicados.
-- ============================================================

-- ============================================================
-- FUNCIÓN AUXILIAR (opcional): calcula total de un pedido
-- Usada por vistas/procedimientos; demuestra función PL/pgSQL con RETURN
-- ============================================================
CREATE OR REPLACE FUNCTION fn_total_pedido(p_pedido_id BIGINT)
RETURNS NUMERIC(12,2)
LANGUAGE plpgsql
AS $$
DECLARE v_total NUMERIC(12,2);
BEGIN
    SELECT COALESCE(SUM(cantidad * precio_unitario), 0)
    INTO v_total
    FROM detalle_pedido
    WHERE pedido_id = p_pedido_id;
    RETURN v_total;
END;
$$;

COMMENT ON FUNCTION fn_total_pedido(BIGINT) IS 'Total histórico de un pedido (usa precio_unitario congelado).';

-- Ejemplo:
-- SELECT fn_total_pedido(1);


-- ============================================================
-- PROCEDIMIENTO 1: Crear pedido completo con detalles (transaccional)
-- Spec: pedido debe tener ≥1 detalle (R2 diferida) y solo productos activos (R1)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_crear_pedido(
    p_cliente_id  BIGINT,
    p_forma_pago  forma_pago,
    p_productos   BIGINT[],   -- array de producto_id
    p_cantidades  INTEGER[],   -- array paralelo de cantidades
    INOUT p_pedido_id BIGINT DEFAULT NULL  -- OUT: id generado
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_idx INTEGER;
    v_producto_id BIGINT;
    v_cantidad INTEGER;
    v_precio NUMERIC(10,2);
    v_activo BOOLEAN;
BEGIN
    -- Validaciones de entrada (reglas de negocio declarativas)
    IF p_productos IS NULL OR array_length(p_productos,1) IS NULL THEN
        RAISE EXCEPTION 'sp_crear_pedido: Debe especificar al menos un producto (R2).';
    END IF;
    IF array_length(p_productos,1) != array_length(p_cantidades,1) THEN
        RAISE EXCEPTION 'sp_crear_pedido: Arrays productos y cantidades deben tener misma longitud.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id = p_cliente_id) THEN
        RAISE EXCEPTION 'sp_crear_pedido: Cliente ID % no existe.', p_cliente_id;
    END IF;

    -- Crear cabecera (R2 se valida a COMMIT por trigger diferido, pero insertamos detalle antes de salir)
    INSERT INTO pedido(cliente_id, forma_pago, fecha)
    VALUES (p_cliente_id, p_forma_pago, now())
    RETURNING id INTO p_pedido_id;

    -- Insertar detalles validando R1 (producto activo) y CHECKs
    FOR v_idx IN 1..array_length(p_productos,1) LOOP
        v_producto_id := p_productos[v_idx];
        v_cantidad := p_cantidades[v_idx];

        IF v_cantidad IS NULL OR v_cantidad <= 0 THEN
            RAISE EXCEPTION 'sp_crear_pedido: Cantidad en posición % debe ser >0 (CHECK).', v_idx;
        END IF;

        SELECT precio, activo INTO v_precio, v_activo
        FROM producto
        WHERE id = v_producto_id;

        IF v_precio IS NULL THEN
            RAISE EXCEPTION 'sp_crear_pedido: Producto ID % no existe.', v_producto_id;
        END IF;
        IF v_activo = FALSE THEN
            RAISE EXCEPTION 'sp_crear_pedido: Producto ID % está inactivo (R1).', v_producto_id;
        END IF;

        INSERT INTO detalle_pedido(pedido_id, producto_id, cantidad, precio_unitario)
        VALUES (p_pedido_id, v_producto_id, v_cantidad, v_precio);
    END LOOP;

    -- Si llega aquí, COMMIT implícito del CALL disparará triggers diferidos R2 y validará
    RAISE NOTICE 'Pedido % creado con % items. Total: %', p_pedido_id, array_length(p_productos,1), fn_total_pedido(p_pedido_id);
END;
$$;

COMMENT ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, BIGINT[], INTEGER[], BIGINT) IS 'Crea pedido + detalles atómicamente. Respeta R1/R2. Invocar con CALL.';

-- ============================================================
-- PROCEDIMIENTO 2: Soft delete de producto (borrado lógico Pt.9)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_soft_delete_producto(p_producto_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE v_filas INTEGER;
BEGIN
    UPDATE producto SET activo = FALSE WHERE id = p_producto_id AND activo = TRUE;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    IF v_filas = 0 THEN
        RAISE EXCEPTION 'sp_soft_delete_producto: Producto ID % no existe o ya está inactivo.', p_producto_id;
    END IF;
    RAISE NOTICE 'Producto % desactivado (soft delete). Ya no aparece en v_productos_vigentes_con_categoria.', p_producto_id;
END;
$$;

COMMENT ON PROCEDURE sp_soft_delete_producto(BIGINT) IS 'Borrado lógico: activo=FALSE. Impacto en vistas/índices ver docs/borrado_logico.md';

-- ============================================================
-- PROCEDIMIENTO 3: Restaurar producto (undo soft delete)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_restaurar_producto(p_producto_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE producto SET activo = TRUE WHERE id = p_producto_id AND activo = FALSE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'sp_restaurar_producto: Producto ID % no existe o ya está activo.', p_producto_id;
    END IF;
    RAISE NOTICE 'Producto % restaurado.', p_producto_id;
END;
$$;

-- ============================================================
-- PROCEDIMIENTO 4: Refrescar materializada (para dashboards)
-- ============================================================
CREATE OR REPLACE PROCEDURE sp_refrescar_facturacion()
LANGUAGE plpgsql
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;
    RAISE NOTICE 'vm_facturacion_categoria_mes refrescada CONCURRENTLY (~412ms).';
END;
$$;

COMMENT ON PROCEDURE sp_refrescar_facturacion IS 'Refresco no bloqueante de la vista materializada. Ver docs/informe_mediciones.md Parte C.';

-- ============================================================
-- EJEMPLOS DE INVOCACIÓN (para defensa oral y README)
-- ============================================================

-- 1. Crear pedido válido (transacción atómica):
-- BEGIN;
-- CALL sp_crear_pedido(1, 'TARJETA', ARRAY[1,2], ARRAY[2,1], NULL); -- cliente 1, 2 productos
-- -- Verificar:
-- SELECT * FROM v_detalle_pedido_con_producto WHERE pedido_id = currval('pedido_id_seq');
-- SELECT fn_total_pedido(currval('pedido_id_seq'));
-- COMMIT;
-- -- Si un producto está inactivo, el CALL hace ROLLBACK implícito por excepción R1.

-- 2. Intentar crear pedido con producto inactivo (debe fallar por R1):
-- -- Primero soft delete:
-- CALL sp_soft_delete_producto(5);
-- -- Luego intentar usarlo:
-- CALL sp_crear_pedido(1, 'EFECTIVO', ARRAY[5], ARRAY[1], NULL); -- ERROR: Producto ID 5 está inactivo
-- -- Restaurar:
-- CALL sp_restaurar_producto(5);

-- 3. Intentar crear pedido sin productos (debe fallar por R2):
-- CALL sp_crear_pedido(1, 'EFECTIVO', ARRAY[]::BIGINT[], ARRAY[]::INTEGER[], NULL); -- ERROR: Debe especificar al menos un producto

-- 4. Refrescar reporte:
-- CALL sp_refrescar_facturacion();
-- SELECT * FROM vm_facturacion_categoria_mes ORDER BY mes DESC LIMIT 5;

-- 5. Verificar soft delete impacta vistas e índices:
-- CALL sp_soft_delete_producto(10);
-- SELECT * FROM v_productos_vigentes_con_categoria WHERE producto_id=10; -- 0 filas
-- SELECT * FROM producto WHERE id=10; -- activo=FALSE aún visible en tabla base
-- EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM v_productos_vigentes_con_categoria WHERE categoria_id=1 AND precio>2000; -- usa idx parcial WHERE activo

-- ============================================================
-- VERIFICACIÓN DE IRREVOCABILIDAD (para informe)
-- ============================================================
-- \df fn_total_pedido
-- \sf sp_crear_pedido
-- SELECT proname, prokind FROM pg_proc WHERE proname LIKE 'sp_%'; -- prokind='p' = procedure
-- CALL sp_crear_pedido(1,'TRANSFERENCIA',ARRAY[1],ARRAY[1],NULL); -- prueba mínima
-- SELECT * FROM pedido ORDER BY id DESC LIMIT 1;
-- ROLLBACK; -- si se envolvió en BEGIN
