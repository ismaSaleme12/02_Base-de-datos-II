-- ============================================================
-- Script  : queries_tp3.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-09-04
-- Desc    : Consultas lentas candidatas para EXPLAIN ANALYZE y optimización (Parte 2).
-- ============================================================

-- ============================================================
-- CONSULTA 1: Listado de productos filtrados por categoría y precio (sin índice en categoria_id o precio)
-- ============================================================

-- Busca productos de la categoria "Bebidas" con un precio mayor a 2000.

EXPLAIN ANALYZE
SELECT p.id, p.nombre, p.precio, c.nombre AS categoria
FROM producto p
JOIN categoria c ON p.categoria_id = c.id
WHERE c.nombre = 'Bebidas' AND p.precio > 2000
ORDER BY p.precio DESC;


-- ============================================================
-- CONSULTA 2: Historial de pedidos de un cliente específico con sus detalles y productos (sin índice en cliente_id)
-- ============================================================

-- Muestra las compras de un cliente atraves de su mail

EXPLAIN ANALYZE
SELECT p.id AS pedido_id, p.fecha, cl.nombre AS cliente, pr.nombre AS producto, dp.cantidad, dp.precio_unitario
FROM pedido p
JOIN cliente cl ON p.cliente_id = cl.id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
JOIN producto pr ON dp.producto_id = pr.id
WHERE cl.email = 'cliente1500@example.com'
ORDER BY p.fecha DESC;


-- ============================================================
-- CONSULTA 3: Resumen de recaudación y cantidad de ventas por categoría
-- ============================================================

-- Agrupa y suma la recaudación y unidades vendidas de todos los detalles de productos por cada categoría.

EXPLAIN ANALYZE
SELECT c.nombre AS categoria, COUNT(dp.producto_id) AS total_vendidos, SUM(dp.cantidad * dp.precio_unitario) AS recaudacion
FROM categoria c
JOIN producto p ON c.id = p.categoria_id
JOIN detalle_pedido dp ON p.id = dp.producto_id
GROUP BY c.id, c.nombre
ORDER BY recaudacion DESC;
