-- ============================================================
-- Script  : consultas_parte3_semana4.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-09-07
-- Desc    : Consultas con función de ventana (ranking) y subconsulta correlacionada,
--           con sus especificaciones precisas, alternativas y verificación con EXCEPT (Parte 3).
-- ============================================================

-- ============================================================
-- 1. RANKING CON FUNCIÓN DE VENTANA
-- ============================================================

/*
SPEC PRECISA (a):
«Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada cliente vigente, 
su ID, nombre, el monto total gastado en sus pedidos (suma de cantidad * precio_unitario en detalle_pedido) 
y su puesto en un ranking global de mayor a menor gasto utilizando la función de ventana DENSE_RANK(), 
desempatando por el ID del cliente de forma ascendente. No uses SELECT *.»
*/

-- Versión Principal (Con función de ventana DENSE_RANK)
SELECT 
    cl.id AS cliente_id,
    cl.nombre AS cliente_nombre,
    SUM(dp.cantidad * dp.precio_unitario) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC, cl.id ASC) AS puesto
FROM cliente cl
JOIN pedido p ON cl.id = p.cliente_id
JOIN detalle_pedido dp ON p.id = dp.pedido_id
GROUP BY cl.id, cl.nombre
ORDER BY total_gastado DESC, cliente_id ASC;


-- Versión Alternativa (Estructura distinta sin función de ventana, usando subconsulta correlacionada de conteo)
WITH gasto_clientes AS (
    SELECT 
        cl.id AS cliente_id,
        cl.nombre AS cliente_nombre,
        SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
    FROM cliente cl
    JOIN pedido p ON cl.id = p.cliente_id
    JOIN detalle_pedido dp ON p.id = dp.pedido_id
    GROUP BY cl.id, cl.nombre
)
SELECT 
    gc.cliente_id,
    gc.cliente_nombre,
    gc.total_gastado,
    (
        SELECT COUNT(DISTINCT gc2.total_gastado) + 1
        FROM gasto_clientes gc2
        WHERE gc2.total_gastado > gc.total_gastado
           OR (gc2.total_gastado = gc.total_gastado AND gc2.cliente_id < gc.cliente_id)
    ) AS puesto
FROM gasto_clientes gc
ORDER BY total_gastado DESC, cliente_id ASC;


-- Verificación de Equivalencia (Debe dar 0 filas en ambos sentidos)
(
    SELECT cl.id AS cliente_id, cl.nombre AS cliente_nombre, SUM(dp.cantidad * dp.precio_unitario) AS total_gastado, DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC, cl.id ASC) AS puesto
    FROM cliente cl
    JOIN pedido p ON cl.id = p.cliente_id
    JOIN detalle_pedido dp ON p.id = dp.pedido_id
    GROUP BY cl.id, cl.nombre
)
EXCEPT
(
    WITH gasto_clientes AS (
        SELECT cl.id AS cliente_id, cl.nombre AS cliente_nombre, SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
        FROM cliente cl
        JOIN pedido p ON cl.id = p.cliente_id
        JOIN detalle_pedido dp ON p.id = dp.pedido_id
        GROUP BY cl.id, cl.nombre
    )
    SELECT gc.cliente_id, gc.cliente_nombre, gc.total_gastado, (SELECT COUNT(DISTINCT gc2.total_gastado) + 1 FROM gasto_clientes gc2 WHERE gc2.total_gastado > gc.total_gastado OR (gc2.total_gastado = gc.total_gastado AND gc2.cliente_id < gc.cliente_id)) AS puesto
    FROM gasto_clientes gc
);

(
    WITH gasto_clientes AS (
        SELECT cl.id AS cliente_id, cl.nombre AS cliente_nombre, SUM(dp.cantidad * dp.precio_unitario) AS total_gastado
        FROM cliente cl
        JOIN pedido p ON cl.id = p.cliente_id
        JOIN detalle_pedido dp ON p.id = dp.pedido_id
        GROUP BY cl.id, cl.nombre
    )
    SELECT gc.cliente_id, gc.cliente_nombre, gc.total_gastado, (SELECT COUNT(DISTINCT gc2.total_gastado) + 1 FROM gasto_clientes gc2 WHERE gc2.total_gastado > gc.total_gastado OR (gc2.total_gastado = gc.total_gastado AND gc2.cliente_id < gc.cliente_id)) AS puesto
    FROM gasto_clientes gc
)
EXCEPT
(
    SELECT cl.id AS cliente_id, cl.nombre AS cliente_nombre, SUM(dp.cantidad * dp.precio_unitario) AS total_gastado, DENSE_RANK() OVER (ORDER BY SUM(dp.cantidad * dp.precio_unitario) DESC, cl.id ASC) AS puesto
    FROM cliente cl
    JOIN pedido p ON cl.id = p.cliente_id
    JOIN detalle_pedido dp ON p.id = dp.pedido_id
    GROUP BY cl.id, cl.nombre
);


-- ============================================================
-- 2. SUBCONSULTA CORRELACIONADA
-- ============================================================

/*
SPEC PRECISA (b):
«Genera una consulta SQL sobre el esquema de Food Store que liste los productos activos (activo = TRUE) 
cuyo precio sea mayor que el precio promedio de los productos de su misma categoría (categoria_id). 
La consulta debe mostrar el ID del producto, su nombre, su precio y el ID de su categoría. 
Ordena el resultado por categoría de forma ascendente y luego por precio de forma descendente. No uses SELECT *.»
*/

-- Versión Principal (Subconsulta Correlacionada en el WHERE)
SELECT 
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    p.precio,
    p.categoria_id
FROM producto p
WHERE p.activo = TRUE
  AND p.precio > (
      SELECT AVG(p2.precio)
      FROM producto p2
      WHERE p2.categoria_id = p.categoria_id
        AND p2.activo = TRUE
  )
ORDER BY p.categoria_id ASC, p.precio DESC;


-- Versión Alternativa (Estructura distinta usando JOIN con una CTE agrupada por categoría)
WITH categorias_promedio AS (
    SELECT categoria_id, AVG(precio) AS avg_precio
    FROM producto
    WHERE activo = TRUE
    GROUP BY categoria_id
)
SELECT 
    p.id AS producto_id,
    p.nombre AS producto_nombre,
    p.precio,
    p.categoria_id
FROM producto p
JOIN categorias_promedio cp ON p.categoria_id = cp.categoria_id
WHERE p.activo = TRUE
  AND p.precio > cp.avg_precio
ORDER BY p.categoria_id ASC, p.precio DESC;


-- Verificación de Equivalencia (Debe dar 0 filas en ambos sentidos)
(
    SELECT p.id AS producto_id, p.nombre AS producto_nombre, p.precio, p.categoria_id
    FROM producto p
    WHERE p.activo = TRUE AND p.precio > (SELECT AVG(p2.precio) FROM producto p2 WHERE p2.categoria_id = p.categoria_id AND p2.activo = TRUE)
)
EXCEPT
(
    WITH categorias_promedio AS (
        SELECT categoria_id, AVG(precio) AS avg_precio FROM producto WHERE activo = TRUE GROUP BY categoria_id
    )
    SELECT p.id AS producto_id, p.nombre AS producto_nombre, p.precio, p.categoria_id
    FROM producto p
    JOIN categorias_promedio cp ON p.categoria_id = cp.categoria_id
    WHERE p.activo = TRUE AND p.precio > cp.avg_precio
);

(
    WITH categorias_promedio AS (
        SELECT categoria_id, AVG(precio) AS avg_precio FROM producto WHERE activo = TRUE GROUP BY categoria_id
    )
    SELECT p.id AS producto_id, p.nombre AS producto_nombre, p.precio, p.categoria_id
    FROM producto p
    JOIN categorias_promedio cp ON p.categoria_id = cp.categoria_id
    WHERE p.activo = TRUE AND p.precio > cp.avg_precio
)
EXCEPT
(
    SELECT p.id AS producto_id, p.nombre AS producto_nombre, p.precio, p.categoria_id
    FROM producto p
    WHERE p.activo = TRUE AND p.precio > (SELECT AVG(p2.precio) FROM producto p2 WHERE p2.categoria_id = p.categoria_id AND p2.activo = TRUE)
);
