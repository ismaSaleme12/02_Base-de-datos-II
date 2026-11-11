-- ============================================================================
--  TP 8 · Consigna 3.c — Verificación en la base de los hallazgos del review
-- ----------------------------------------------------------------------------
--  Corre en PostgreSQL (Food_Store_Copia). NO deja cambios:
--    - el índice de prueba se crea dentro de una transacción y se revierte;
--    - los roles de prueba se crean y se eliminan al final;
--    - el pedido de prueba se revierte con ROLLBACK.
--
--  Cada hallazgo se comprueba EJECUTANDO, no leyendo el script.
-- ============================================================================

\echo ''
\echo '############################################################'
\echo '# H1 (U3) - Indice sobre forma_pago: DESCARTADO'
\echo '############################################################'

\echo '--- Cardinalidad real de la columna ---'
SELECT forma_pago, count(*) AS filas,
       round(100.0 * count(*) / (SELECT count(*) FROM pedido), 2) AS porcentaje
FROM pedido
GROUP BY forma_pago
ORDER BY filas DESC;

\echo '--- Plan SIN el indice propuesto ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT id, fecha, forma_pago FROM pedido WHERE forma_pago = 'TARJETA';

BEGIN;
CREATE INDEX idx_tp8_prueba_forma_pago ON pedido (forma_pago);
ANALYZE pedido;

\echo '--- Plan CON el indice propuesto (dentro de la transaccion) ---'
EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY ON)
SELECT id, fecha, forma_pago FROM pedido WHERE forma_pago = 'TARJETA';

ROLLBACK;

\echo '--- El indice NO quedo creado ---'
SELECT count(*) AS indices_con_ese_nombre
FROM pg_indexes WHERE indexname = 'idx_tp8_prueba_forma_pago';


\echo ''
\echo '############################################################'
\echo '# H2 (U5) - REVOKE SELECT (columna) no recorta un GRANT de tabla'
\echo '############################################################'

CREATE ROLE tp8_rol_prueba NOLOGIN;

GRANT SELECT ON producto TO tp8_rol_prueba;

\echo '--- Antes del REVOKE por columna ---'
SELECT has_column_privilege('tp8_rol_prueba', 'producto', 'precio', 'SELECT') AS puede_leer_precio;

REVOKE SELECT (precio) ON producto FROM tp8_rol_prueba;

\echo '--- Después de REVOKE SELECT (precio): deberia ser false, y NO lo es ---'
SELECT has_column_privilege('tp8_rol_prueba', 'producto', 'precio', 'SELECT') AS puede_leer_precio;

\echo '--- La forma que SI funciona: REVOKE ALL + GRANT por columnas ---'
REVOKE ALL ON producto FROM tp8_rol_prueba;
GRANT SELECT (id, nombre, stock, activo, categoria_id) ON producto TO tp8_rol_prueba;
SELECT has_column_privilege('tp8_rol_prueba', 'producto', 'precio', 'SELECT') AS puede_leer_precio;

\echo '--- Limpieza ---'
REVOKE ALL ON producto FROM tp8_rol_prueba;
DROP ROLE tp8_rol_prueba;


\echo ''
\echo '############################################################'
\echo '# H3 (U5) - Un GRANT dentro de un DO se ejecuta como el invocador'
\echo '############################################################'

CREATE ROLE tp8_rol_a NOLOGIN;
CREATE ROLE tp8_rol_b NOLOGIN;

\echo '--- Un bloque DO "inocente" ---'
DO $$
BEGIN
    EXECUTE 'GRANT tp8_rol_a TO tp8_rol_b';
END
$$;

\echo '--- Pero el GRANT se aplico de verdad: deberia ser false, y NO lo es ---'
SELECT pg_has_role('tp8_rol_b', 'tp8_rol_a', 'MEMBER') AS tp8_rol_b_obtuvo_el_rol;

\echo '--- Limpieza ---'
REVOKE tp8_rol_a FROM tp8_rol_b;
DROP ROLE tp8_rol_b;
DROP ROLE tp8_rol_a;


\echo ''
\echo '############################################################'
\echo '# H4 (U1-U3) - No existe ninguna regla de stock suficiente'
\echo '############################################################'

\echo '--- Producto 95: stock real ---'
SELECT id, nombre, stock, activo FROM producto WHERE id = 95;

BEGIN;

INSERT INTO pedido (cliente_id, forma_pago)
VALUES (1, 'EFECTIVO')
RETURNING id AS pedido_de_prueba \gset

\echo '--- Se piden 999 unidades de un producto con stock 3 ---'
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (:pedido_de_prueba, 95, 999, 4324.20);

\echo '--- La fila entro sin error: no hay CHECK, ni trigger, ni procedure que lo impida ---'
SELECT pedido_id, producto_id, cantidad,
       (SELECT stock FROM producto WHERE id = 95) AS stock_disponible
FROM detalle_pedido
WHERE pedido_id = :pedido_de_prueba;

\echo '--- Se revierte: la prueba no deja datos ---'
ROLLBACK;

\echo '--- El stock sigue intacto ---'
SELECT id, stock FROM producto WHERE id = 95;


\echo ''
\echo '############################################################'
\echo '# ESTADO FINAL - nada quedo modificado'
\echo '############################################################'
SELECT
    (SELECT count(*) FROM pg_indexes WHERE indexname LIKE 'idx_tp8%') AS indices_tp8,
    (SELECT count(*) FROM pg_roles   WHERE rolname    LIKE 'tp8%')   AS roles_tp8,
    (SELECT count(*) FROM pedido)                                    AS pedidos;
