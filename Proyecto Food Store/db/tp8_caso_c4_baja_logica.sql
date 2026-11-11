-- ============================================================================
--  CASO C4 — El servidor da de baja lógica el producto 6
-- ----------------------------------------------------------------------------
--  Corre en PostgreSQL (Food_Store_Copia).
--
--  BAJA LÓGICA: se pone activo = false. La fila NO se borra.
--  Motivos por los que acá no se puede hacer DELETE:
--    - `detalle_pedido` tiene FK a `producto` con ON DELETE RESTRICT, así que
--      el DELETE fallaría de todos modos por los pedidos históricos;
--    - y aunque se pudiera, borrar el producto dejaría huérfano el borrador
--      de la tablet, que no podría distinguir "dado de baja" de "no existe".
--
--  La columna se llama `activo`, no `eliminado`. La vista v_snapshot_movil
--  traduce activo = false  ->  eliminado = true para la tablet.
-- ============================================================================

\echo '=== C4: producto ANTES ==='
SELECT id, nombre, activo, stock, (round(precio * 100))::integer AS precio_centavos
FROM producto WHERE id = 6;

BEGIN;

UPDATE producto
   SET activo = false
 WHERE id = 6;

\echo '=== C4: producto DESPUES (dentro de la transaccion) ==='
SELECT id, nombre, activo, stock, (round(precio * 100))::integer AS precio_centavos
FROM producto WHERE id = 6;

COMMIT;

\echo '=== C4: confirmado — la fila sigue existiendo ==='
SELECT id, nombre, activo, stock FROM producto WHERE id = 6;
