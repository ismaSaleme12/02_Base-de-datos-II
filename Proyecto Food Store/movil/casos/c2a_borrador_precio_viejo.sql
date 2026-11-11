-- ============================================================================
--  CASO C2 (parte 1) — Borrador con el precio viejo  ->  CONFLICTO
-- ----------------------------------------------------------------------------
--  El vendedor arma el pedido con el precio que el cliente está viendo AHORA
--  (111923 centavos por el producto 5).
--
--  Después de crear este borrador, en el servidor se sube ese precio.
--  Cuando el semáforo compare, el producto existe, está disponible y hay
--  stock — no hay rojo — pero el precio no coincide: AMARILLO.
--
--  Este caso es el que justifica que la tablet no confirme precios: el cliente
--  vio un precio, el servidor tiene otro, y alguien tiene que decidir.
-- ============================================================================

PRAGMA foreign_keys = ON;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c2000000-0000-4000-8000-000000000002',
        'caja-01', 'TRANSFERENCIA', '2026-11-01T19:42:00-03:00');

-- Producto 5: 3 unidades al precio vigente al momento de armar el borrador
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c2000000-0000-4000-8000-000000000002', 5, 3, 111923);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('2a000000-0000-4000-8000-000000000002',
        'c2000000-0000-4000-8000-000000000002');
