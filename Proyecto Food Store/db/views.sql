-- ============================================================
-- Script  : views.sql
-- Base    : Food_Store_Copia (PostgreSQL 16+)
-- Autor   : Saleme Ismael — BD II U3 S5 (Parte B y C)
-- Desc    : Vistas para reportes + vista materializada con índice único
--           Verificación de equivalencia con EXCEPT documentada en informe.
-- ============================================================

-- ============================================================
-- VISTA 1: Productos vigentes con su categoría
-- Spec: specs/spec_vista_productos_vigentes.md
-- Seguridad: no expone dato sensible; filtra vigentes.
-- ============================================================
CREATE OR REPLACE VIEW v_productos_vigentes_con_categoria AS
SELECT
    p.id   AS producto_id,
    p.nombre AS producto_nombre,
    p.precio,
    p.stock,
    c.id   AS categoria_id,
    c.nombre AS categoria_nombre
FROM producto p
JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE
  AND c.activo = TRUE;

COMMENT ON VIEW v_productos_vigentes_con_categoria IS 'Catálogo visible: productos activos con categoría activa. Equivale a consulta manual con mismo WHERE.';


-- ============================================================
-- VISTA 2: Pedidos con datos del cliente (SEGURA)
-- Spec: specs/spec_vista_pedidos_con_cliente.md
-- Seguridad: expone cliente sin email/telefono (análogo a ocultar contraseña en modelo pedagógico usuario).
-- Permite GRANT SELECT sobre la vista sin conceder SELECT sobre tabla cliente.
-- ============================================================
CREATE OR REPLACE VIEW v_pedidos_con_cliente AS
SELECT
    p.id         AS pedido_id,
    p.fecha,
    p.forma_pago,
    c.id         AS cliente_id,
    c.nombre     AS cliente_nombre
    -- intencionalmente NO se expone c.email ni c.telefono
FROM pedido p
JOIN cliente c ON p.cliente_id = c.id;

COMMENT ON VIEW v_pedidos_con_cliente IS 'Pedidos enriquecidos sin dato sensible. Oculta email/telefono análogo a contraseña.';

-- Vista alternativa segura explícita para defensa oral (alias, misma definición):
-- CREATE OR REPLACE VIEW v_pedidos_con_cliente_seguro AS SELECT ... (igual que arriba)


-- ============================================================
-- VISTA 3: Detalle de pedido con nombre del producto y categoría
-- Spec: specs/spec_vista_detalle_con_producto.md
-- ============================================================
CREATE OR REPLACE VIEW v_detalle_pedido_con_producto AS
SELECT
    dp.pedido_id,
    dp.producto_id,
    pr.nombre AS producto_nombre,
    cat.nombre AS categoria_nombre,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON dp.producto_id = pr.id
JOIN categoria cat ON pr.categoria_id = cat.id;

COMMENT ON VIEW v_detalle_pedido_con_producto IS 'Detalle por pedido con nombre de producto y subtotal calculado.';


-- ============================================================
-- PARTE C: Vista materializada facturación por categoría y mes
-- Spec: specs/spec_vista_materializada_facturacion.md
-- Reporte costoso: ~523 ms, temp files 1.2MB, external merge sort
-- ============================================================
DROP MATERIALIZED VIEW IF EXISTS vm_facturacion_categoria_mes;

CREATE MATERIALIZED VIEW vm_facturacion_categoria_mes AS
SELECT
    c.nombre AS categoria,
    to_char(p.fecha, 'YYYY-MM') AS mes,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total,
    COUNT(DISTINCT p.id) AS total_pedidos
FROM categoria c
JOIN producto pr ON pr.categoria_id = c.id
JOIN detalle_pedido dp ON dp.producto_id = pr.id
JOIN pedido p ON p.id = dp.pedido_id
GROUP BY c.nombre, to_char(p.fecha, 'YYYY-MM')
WITH DATA;

-- Índice único obligatorio para REFRESH CONCURRENTLY (sin bloqueo de lectura)
CREATE UNIQUE INDEX IF NOT EXISTS idx_vm_facturacion_categoria_mes_unique
ON vm_facturacion_categoria_mes(categoria, mes);

COMMENT ON MATERIALIZED VIEW vm_facturacion_categoria_mes IS 'Reporte agregado facturación por categoría y mes. REFRESH CONCURRENTLY diario 00:05. Consulta <2ms vs 523ms original.';

-- Uso:
-- SELECT * FROM vm_facturacion_categoria_mes ORDER BY mes DESC, facturacion_total DESC;
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;
