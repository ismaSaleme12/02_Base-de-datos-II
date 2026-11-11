-- ============================================================================
--  CASO C3 — Borrador por más unidades de las que quedan  ->  RECHAZADO
-- ----------------------------------------------------------------------------
--  El producto 95 tiene stock 3. El vendedor carga 10 unidades.
--  El producto EXISTE y está disponible: el problema no es el catálogo, es que
--  no alcanza. Por eso el motivo es "no alcanza el stock", no "no existe".
--
--  Esto es exactamente lo que la tablet NO puede resolver sola: sin señal, no
--  sabe si el stock que vio sigue siendo el real.
-- ============================================================================

PRAGMA foreign_keys = ON;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c3000000-0000-4000-8000-000000000003',
        'caja-01', 'TARJETA', '2026-11-01T19:41:00-03:00');

-- Producto 95: stock_visto = 3, se piden 10
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c3000000-0000-4000-8000-000000000003', 95, 10, 432420);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('30000000-0000-4000-8000-000000000003',
        'c3000000-0000-4000-8000-000000000003');
