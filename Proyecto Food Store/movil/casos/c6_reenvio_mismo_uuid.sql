-- ============================================================================
--  CASO C6 — Reenviar la misma solicitud (mismo UUID)  ->  NO se duplica
-- ----------------------------------------------------------------------------
--  La tablet perdió la respuesta y reintenta. Manda otra vez la solicitud
--  '50000000-0000-4000-8000-000000000005', que ya existe.
--
--  Resultado esperado: error de clave primaria. La fila NO se duplica.
--  Y como el semáforo sólo evalúa estado = 'PENDIENTE', correrlo de nuevo no
--  reevalúa nada: el estado ya resuelto queda congelado.
--
--  ---------------------------------------------------------------------------
--  ¿Dónde va la protección REAL en un sistema de verdad? (parada 8)
--  ---------------------------------------------------------------------------
--  La clave primaria acá funciona porque el UUID lo genera la tablet y viaja
--  en el request: es idempotencia del lado del cliente.
--
--  En producción eso NO alcanza, por dos motivos:
--   1. Un reintento puede llegar con OTRO UUID (la tablet se reinició y
--      regeneró el identificador). La PK no lo detecta.
--   2. La PK protege la tabla local, no el efecto de negocio: si el servidor
--      ya creó el pedido, un UUID nuevo crearía un pedido duplicado.
--
--  La protección real va en el SERVIDOR, en la misma transacción que crea el
--  pedido:
--   - una tabla de idempotencia (solicitud_uuid UNIQUE) consultada dentro de
--     la transacción, con la respuesta guardada para devolver la misma;
--   - o una clave de idempotencia estable por pedido (cliente + tablet +
--     secuencia local), no un UUID al azar;
--   - y el efecto de negocio (descontar stock, crear pedido) en una sola
--     transacción con INSERT ... ON CONFLICT DO NOTHING.
--  La tablet sola nunca puede garantizar que no haya duplicados.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- Esto DEBE fallar: UNIQUE constraint failed: cola_sync.solicitud_uuid
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('50000000-0000-4000-8000-000000000005',
        'c5000000-0000-4000-8000-000000000005');
