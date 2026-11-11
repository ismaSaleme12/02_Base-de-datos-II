-- ============================================================================
--  TP 8 · Consigna 2.c — Prueba final: PostgreSQL no cambió
-- ----------------------------------------------------------------------------
--  Compara el estado actual contra la línea de base tomada ANTES de empezar.
--
--  Lo que tiene que dar SIN CAMBIOS: pedidos, detalles, stock (total y huella).
--  Lo que SÍ tiene que haber cambiado: la huella de precios (caso C2) y el
--  estado del producto 6 (caso C4). Mostrar las dos cosas juntas es la prueba
--  de que el semáforo leyó y no escribió.
--
--  Por qué la huella md5 y no sólo la suma de stock: dos cambios opuestos
--  (uno sube 3, otro baja 3) dejan la suma igual. El md5 del vector completo
--  (id:stock) ordenado detecta cualquier cambio en cualquier fila.
-- ============================================================================

WITH ahora AS (
    SELECT
        (SELECT count(*) FROM pedido)         AS pedidos,
        (SELECT count(*) FROM detalle_pedido) AS detalles,
        (SELECT sum(stock) FROM producto)     AS stock_total,
        (SELECT md5(string_agg(id::text || ':' || stock::text, ',' ORDER BY id))
           FROM producto)                     AS stock_huella,
        (SELECT md5(string_agg(id::text || ':' || precio::text, ',' ORDER BY id))
           FROM producto)                     AS precio_huella
)
SELECT 'pedidos'      AS invariante,
       b.pedidos::text AS antes,
       a.pedidos::text AS ahora,
       CASE WHEN b.pedidos = a.pedidos THEN 'SIN CAMBIOS' ELSE 'CAMBIÓ' END AS veredicto
FROM tp8_linea_base b, ahora a
UNION ALL
SELECT 'detalle_pedido',
       b.detalles::text, a.detalles::text,
       CASE WHEN b.detalles = a.detalles THEN 'SIN CAMBIOS' ELSE 'CAMBIÓ' END
FROM tp8_linea_base b, ahora a
UNION ALL
SELECT 'stock_total',
       b.stock_total::text, a.stock_total::text,
       CASE WHEN b.stock_total = a.stock_total THEN 'SIN CAMBIOS' ELSE 'CAMBIÓ' END
FROM tp8_linea_base b, ahora a
UNION ALL
SELECT 'stock_huella (md5)',
       b.stock_huella, a.stock_huella,
       CASE WHEN b.stock_huella = a.stock_huella THEN 'SIN CAMBIOS' ELSE 'CAMBIÓ' END
FROM tp8_linea_base b, ahora a
UNION ALL
SELECT 'precio_huella (md5)',
       b.precio_huella, a.precio_huella,
       CASE WHEN b.precio_huella = a.precio_huella
            THEN 'SIN CAMBIOS'
            ELSE 'CAMBIÓ (esperado: caso C2)' END
FROM tp8_linea_base b, ahora a;

\echo ''
\echo '=== Producto 5 (C2: precio subido a proposito) ==='
SELECT id, nombre, precio, activo FROM producto WHERE id = 5;

\echo '=== Producto 6 (C4: baja logica a proposito) ==='
SELECT id, nombre, precio, activo FROM producto WHERE id = 6;
