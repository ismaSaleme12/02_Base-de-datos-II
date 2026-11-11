-- ============================================================================
--  CASO C4 — Borrador con un producto que después se da de baja  ->  RECHAZADO
-- ----------------------------------------------------------------------------
--  El vendedor arma el pedido con el producto 6, que en ese momento está
--  activo. Después, en el servidor, ese producto se da de baja LÓGICA
--  (activo = false). No se borra la fila: en Food Store las bajas son lógicas.
--
--  El semáforo tiene que decir "dado de baja", no "no existe". La diferencia
--  importa: son dos incidentes distintos para quien atiende el conflicto.
--
--  Y cuando la tablet recargue el catálogo, el producto desaparece de la lista
--  de venta pero la fila sigue en producto_cache con eliminado = 1, para que
--  este borrador no pierda su clave foránea.
-- ============================================================================

PRAGMA foreign_keys = ON;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago, fecha)
VALUES ('c4000000-0000-4000-8000-000000000004',
        'caja-01', 'EFECTIVO', '2026-11-01T19:43:00-03:00');

-- Producto 6: 2 unidades a 248569 centavos (vigente al armar el borrador)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('c4000000-0000-4000-8000-000000000004', 6, 2, 248569);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('40000000-0000-4000-8000-000000000004',
        'c4000000-0000-4000-8000-000000000004');
