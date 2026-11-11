-- ============================================================================
--  CASO C2 — El servidor sube el precio del producto 5
-- ----------------------------------------------------------------------------
--  Corre en PostgreSQL (Food_Store_Copia). Es el único cambio de precio de
--  todo el TP, y es deliberado: sin un cambio real del servidor no hay
--  CONFLICTO que mostrar.
--
--  Protocolo del proyecto: la verificación va DENTRO de la transacción, antes
--  del COMMIT, para poder revertir si el valor no es el esperado.
--
--  Precio anterior: 1119.23  ->  111923 centavos (lo que vio el cliente)
--  Precio nuevo:    1269.23  ->  126923 centavos
-- ============================================================================

\echo '=== C2: precio ANTES ==='
SELECT id, nombre, precio, (round(precio * 100))::integer AS precio_centavos
FROM producto WHERE id = 5;

BEGIN;

UPDATE producto
   SET precio = 1269.23
 WHERE id = 5;

\echo '=== C2: precio DESPUES (dentro de la transaccion) ==='
SELECT id, nombre, precio, (round(precio * 100))::integer AS precio_centavos
FROM producto WHERE id = 5;

-- Si el valor no es 1269.23, reemplazar COMMIT por ROLLBACK.
COMMIT;

\echo '=== C2: confirmado ==='
SELECT id, nombre, precio, (round(precio * 100))::integer AS precio_centavos
FROM producto WHERE id = 5;
