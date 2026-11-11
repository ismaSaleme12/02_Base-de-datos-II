-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 2.c — Línea de base para probar que PostgreSQL no cambió
-- ----------------------------------------------------------------------------
--  Corre en PostgreSQL (base de PRUEBAS: Food_Store_Copia), ANTES de tocar
--  nada. Guarda una foto de los invariantes que la tablet NO debe mover:
--
--    pedidos      : cantidad de filas en pedido
--    detalles     : cantidad de filas en detalle_pedido
--    stock_total  : suma de stock de todo el catálogo
--    stock_huella : md5 de la lista ordenada (id:stock) de los 50.000 productos
--
--  La huella es la parte importante: la suma sola no alcanza, porque dos
--  cambios opuestos (uno sube 3, otro baja 3) dejan la misma suma. El md5 del
--  vector completo detecta cualquier cambio, en cualquier fila.
--
--  También se guarda precio_huella, que SÍ va a cambiar (los casos C2 suben
--  precios a propósito). Mostrar que el precio cambió y el stock no, es
--  exactamente la prueba que pide la consigna.
-- ============================================================================

DROP TABLE IF EXISTS tp8_linea_base;

CREATE TABLE tp8_linea_base AS
SELECT
    now() AS capturado_en,
    (SELECT count(*) FROM pedido)         AS pedidos,
    (SELECT count(*) FROM detalle_pedido) AS detalles,
    (SELECT sum(stock) FROM producto)     AS stock_total,
    (SELECT md5(string_agg(id::text || ':' || stock::text, ',' ORDER BY id))
       FROM producto)                     AS stock_huella,
    (SELECT md5(string_agg(id::text || ':' || precio::text, ',' ORDER BY id))
       FROM producto)                     AS precio_huella;

COMMENT ON TABLE tp8_linea_base IS
    'TP8: invariantes de Food_Store_Copia antes de la simulación de sincronización.';

SELECT * FROM tp8_linea_base;
