-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 1.c — Pruebas del esquema de la tablet
-- ----------------------------------------------------------------------------
--  Se corre sobre una base creada desde cero con schema_sqlite.sql:
--
--      sqlite3 foodstore_movil.db < schema_sqlite.sql
--      sqlite3 foodstore_movil.db < pruebas_sqlite.sql
--
--  Los errores de los casos C7 son ESPERADOS: `.bail off` hace que sqlite3
--  siga ejecutando después de un error, para poder mostrar que la fila no
--  quedó y que el resto de la base sigue sano.
-- ============================================================================

.bail off
.headers on
.mode table

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
--  Limpieza: permite re-ejecutar el script sin chocar con claves duplicadas.
--  El orden respeta las claves foráneas (hijos antes que padres).
-- ----------------------------------------------------------------------------
DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;
DELETE FROM producto_cache;

-- ----------------------------------------------------------------------------
--  Semilla de catálogo (DATOS INVENTADOS)
--  En la consigna 2 esta tabla la llena la instantánea del servidor.
--  Acá alcanza con tres filas para probar el esquema.
--
--    id 1: disponible y con stock   -> vendible
--    id 2: disponible, stock bajo   -> vendible (sirve para C3 más adelante)
--    id 3: activo pero stock 0      -> NO disponible, no aparece en el catálogo
-- ----------------------------------------------------------------------------
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
VALUES
    (1, 'Pancho completo',     150000, 20, 1, 0, '2026-11-01T09:00:00-03:00'),
    (2, 'Hamburguesa doble',   320000,  4, 1, 0, '2026-11-01T09:00:00-03:00'),
    (3, 'Gaseosa 500 ml',      120000,  0, 0, 0, '2026-11-01T09:00:00-03:00');

SELECT 'SEMILLA' AS paso, COUNT(*) AS productos_en_cache FROM producto_cache;


-- ============================================================================
--  1) BORRADOR COMPLETO GUARDADO CON BEGIN ... COMMIT
--     Se guardan las tres piezas juntas: cabecera + ítems + solicitud.
--     Si cualquiera falla, no debería quedar nada (atomicidad).
-- ============================================================================
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a1b2c3d4-1111-4111-8111-000000000001',
        'caja-01',
        'EFECTIVO',
        '2026-11-01T10:05:00-03:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('a1b2c3d4-1111-4111-8111-000000000001', 1, 2, 150000),
       ('a1b2c3d4-1111-4111-8111-000000000001', 2, 1, 320000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b0000000-1111-4111-8111-000000000001',
        'a1b2c3d4-1111-4111-8111-000000000001',
        'PENDIENTE',
        NULL);

COMMIT;

SELECT '1) COMMIT' AS paso,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;


-- ============================================================================
--  1 bis) OPERACIÓN DESHECHA CON ROLLBACK
--     Mismo armado, pero el vendedor se arrepiente antes de encolar.
--     El ROLLBACK tiene que dejar la base exactamente como estaba.
-- ============================================================================
SELECT '1bis) ANTES del rollback' AS paso,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;

BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('a1b2c3d4-1111-4111-8111-000000000002',
        'caja-01',
        'TARJETA',
        '2026-11-01T10:07:00-03:00');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('a1b2c3d4-1111-4111-8111-000000000002', 1, 5, 150000);

INSERT INTO cola_sync (solicitud_uuid, id_local, estado, motivo)
VALUES ('b0000000-1111-4111-8111-000000000002',
        'a1b2c3d4-1111-4111-8111-000000000002',
        'PENDIENTE',
        NULL);

-- Dentro de la transacción las filas existen...
SELECT '1bis) DENTRO de la transacción' AS paso,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;

ROLLBACK;

-- ...y después del ROLLBACK no queda ninguna.
SELECT '1bis) DESPUÉS del rollback' AS paso,
       (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;


-- ============================================================================
--  2) CASO C1 — EL CATÁLOGO DISPONIBLE FUNCIONA SIN SERVIDOR
--     Esta consulta es la única que la tablet necesita para vender en la feria:
--     no toca la red, sale entera de producto_cache.
--     El producto 3 (stock 0) NO aparece: no se puede ofrecer lo que no hay.
-- ============================================================================
SELECT '2) CATÁLOGO OFFLINE (C1)' AS paso;
SELECT id, nombre, precio_centavos, stock_visto, fecha_copia
FROM producto_cache
WHERE disponible = 1
  AND eliminado = 0
ORDER BY nombre;


-- ============================================================================
--  3) CASO C7 — DATOS INVÁLIDOS: ERROR Y CERO FILAS NUEVAS
--     Las dos sentencias de abajo DEBEN fallar. Los mensajes de error son la
--     evidencia esperada, no un problema del script.
-- ============================================================================
SELECT '3) ANTES de las pruebas inválidas' AS paso,
       (SELECT COUNT(*) FROM item_borrador) AS items;

-- 3.a) Cantidad 0 -> viola CHECK (cantidad > 0)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('a1b2c3d4-1111-4111-8111-000000000001', 1, 0, 150000);

-- 3.b) Producto inexistente (99999) -> viola la clave foránea a producto_cache
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('a1b2c3d4-1111-4111-8111-000000000001', 99999, 1, 150000);

-- 3.c) Ninguna de las dos dejó fila
SELECT '3) DESPUÉS de las pruebas inválidas' AS paso,
       (SELECT COUNT(*) FROM item_borrador) AS items;

-- Detalle: el borrador 1 sigue teniendo exactamente sus 2 ítems originales.
SELECT id_local, producto_id, cantidad, precio_centavos_visto
FROM item_borrador
ORDER BY producto_id;


-- ============================================================================
--  CIERRE — estado final de la base de prueba
-- ============================================================================
SELECT 'CIERRE' AS paso,
       (SELECT COUNT(*) FROM producto_cache)  AS producto_cache,
       (SELECT COUNT(*) FROM pedido_borrador) AS pedido_borrador,
       (SELECT COUNT(*) FROM item_borrador)   AS item_borrador,
       (SELECT COUNT(*) FROM cola_sync)       AS cola_sync;
