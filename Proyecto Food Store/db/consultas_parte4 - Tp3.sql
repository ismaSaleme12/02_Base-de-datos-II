-- ============================================================
-- Script  : consultas_parte4.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-09-04
-- Desc    : Consultas resumen y subconsultas bajo especificación precisa,
--           alternativas y verificación de equivalencia con EXCEPT (Parte 4).
-- ============================================================

-- ============================================================
-- PARTE A: CONSULTA DE RESUMEN (AGREGACIÓN)
-- ============================================================

/*
SPEC PRECISA:
«Genera una consulta SQL sobre el esquema de Food Store que devuelva, para cada categoría activa (activo = TRUE), 
el nombre de la categoría y el precio promedio de sus productos activos (activo = TRUE), incluyendo únicamente 
aquellas categorías cuyo precio promedio supere los 1000. Ordena el resultado de mayor a menor precio promedio. 
No uses SELECT *.»
*/

-- Versión Principal (Agregación con GROUP BY y HAVING)

SELECT 
    c.nombre AS categoria,
    AVG(p.precio) AS precio_promedio
FROM categoria c
JOIN producto p ON c.id = p.categoria_id
WHERE c.activo = TRUE 
  AND p.activo = TRUE
GROUP BY c.id, c.nombre
HAVING AVG(p.precio) > 1000
ORDER BY precio_promedio DESC;


-- Versión Alternativa (Usando CTE / WITH para separar la agregación)

WITH promedio_categorias AS (
    SELECT 
        c.id AS categoria_id,
        c.nombre AS categoria,
        AVG(p.precio) AS precio_promedio
    FROM categoria c
    JOIN producto p ON c.id = p.categoria_id
    WHERE c.activo = TRUE 
      AND p.activo = TRUE
    GROUP BY c.id, c.nombre
)
SELECT 
    categoria,
    precio_promedio
FROM promedio_categorias
WHERE precio_promedio > 1000
ORDER BY precio_promedio DESC;


-- Verificación de Equivalencia (Debe retornar 0 filas en ambas direcciones)
(
    SELECT c.nombre AS categoria, AVG(p.precio) AS precio_promedio
    FROM categoria c
    JOIN producto p ON c.id = p.categoria_id
    WHERE c.activo = TRUE AND p.activo = TRUE
    GROUP BY c.id, c.nombre
    HAVING AVG(p.precio) > 1000
)
EXCEPT
(
    WITH promedio_categorias AS (
        SELECT c.nombre AS categoria, AVG(p.precio) AS precio_promedio
        FROM categoria c
        JOIN producto p ON c.id = p.categoria_id
        WHERE c.activo = TRUE AND p.activo = TRUE
        GROUP BY c.id, c.nombre
    )
    SELECT categoria, precio_promedio
    FROM promedio_categorias
    WHERE precio_promedio > 1000
);

(
    WITH promedio_categorias AS (
        SELECT c.nombre AS categoria, AVG(p.precio) AS precio_promedio
        FROM categoria c
        JOIN producto p ON c.id = p.categoria_id
        WHERE c.activo = TRUE AND p.activo = TRUE
        GROUP BY c.id, c.nombre
    )
    SELECT categoria, precio_promedio
    FROM promedio_categorias
    WHERE precio_promedio > 1000
)
EXCEPT
(
    SELECT c.nombre AS categoria, AVG(p.precio) AS precio_promedio
    FROM categoria c
    JOIN producto p ON c.id = p.categoria_id
    WHERE c.activo = TRUE AND p.activo = TRUE
    GROUP BY c.id, c.nombre
    HAVING AVG(p.precio) > 1000
);


-- ============================================================
-- PARTE B: CONSULTA CON SUBCONSULTA
-- ============================================================

/*
SPEC PRECISA:
«Genera una consulta SQL sobre el esquema de Food Store que liste el ID, el nombre y el precio de aquellos 
productos activos (activo = TRUE) cuyo precio sea superior al precio promedio general de todos los productos 
activos de la base de datos. Ordena el resultado por precio de forma ascendente. No uses SELECT *.»
*/

-- Versión Principal (Subconsulta escalar en el WHERE)
SELECT 
    id,
    nombre,
    precio
FROM producto
WHERE activo = TRUE
  AND precio > (
      SELECT AVG(precio)
      FROM producto
      WHERE activo = TRUE
  )
ORDER BY precio ASC;


-- Versión Alternativa (Usando JOIN con tabla derivada para el promedio)
SELECT 
    p.id,
    p.nombre,
    p.precio
FROM producto p
JOIN (
    SELECT AVG(precio) AS avg_precio 
    FROM producto 
    WHERE activo = TRUE
) prom ON p.precio > prom.avg_precio
WHERE p.activo = TRUE
ORDER BY p.precio ASC;


-- Verificación de Equivalencia (Debe retornar 0 filas en ambas direcciones)
(
    SELECT id, nombre, precio
    FROM producto
    WHERE activo = TRUE AND precio > (SELECT AVG(precio) FROM producto WHERE activo = TRUE)
)
EXCEPT
(
    SELECT p.id, p.nombre, p.precio
    FROM producto p
    JOIN (SELECT AVG(precio) AS avg_precio FROM producto WHERE activo = TRUE) prom ON p.precio > prom.avg_precio
    WHERE p.activo = TRUE
);

(
    SELECT p.id, p.nombre, p.precio
    FROM producto p
    JOIN (SELECT AVG(precio) AS avg_precio FROM producto WHERE activo = TRUE) prom ON p.precio > prom.avg_precio
    WHERE p.activo = TRUE
)
EXCEPT
(
    SELECT id, nombre, precio
    FROM producto
    WHERE activo = TRUE AND precio > (SELECT AVG(precio) FROM producto WHERE activo = TRUE)
);
