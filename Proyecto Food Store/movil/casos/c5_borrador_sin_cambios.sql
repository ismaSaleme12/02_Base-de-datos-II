-- ============================================================================
--  CASO C5 — Borrador sin cambios  ->  SIMULADO_APROBADO
-- ----------------------------------------------------------------------------
--  El caso más simple y el que hay que entender primero: la tablet armó un
--  pedido con los precios y el stock que vio, y el servidor no cambió nada.
--  El semáforo da verde.
--
--  OJO: verde NO significa "venta". Significa "si esto se enviara ahora, el
--  servidor lo habría aceptado". No se descuenta stock ni se crea pedido.
-- ============================================================================

PRAGMA foreign_keys = ON;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c5000000-0000-4000-8000-000000000005',
        'caja-01', 'EFECTIVO', '2026-11-01T19:40:00-03:00');

-- Producto 2: 2 unidades a 484734 centavos (precio y stock vigentes)
-- Producto 4: 1 unidad  a 153634 centavos
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c5000000-0000-4000-8000-000000000005', 2, 2, 484734),
       ('c5000000-0000-4000-8000-000000000005', 4, 1, 153634);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('50000000-0000-4000-8000-000000000005',
        'c5000000-0000-4000-8000-000000000005');
