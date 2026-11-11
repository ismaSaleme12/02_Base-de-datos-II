-- ============================================================================
--  CASO C2 (parte 2) — El cliente acepta el precio nuevo  ->  SIMULADO_APROBADO
-- ----------------------------------------------------------------------------
--  Después del CONFLICTO, alguien decide: el cliente acepta pagar el precio
--  actual del servidor (126923 centavos, $1.269,23).
--
--  La tablet actualiza el precio visto del renglón y encola una SOLICITUD
--  NUEVA, con UUID nuevo, sobre el MISMO borrador.
--
--  La solicitud vieja queda en CONFLICTO como registro histórico: no se
--  reescribe. El semáforo sólo evalúa PENDIENTE, así que la nueva pasa sola.
--
--  Dos solicitudes, un borrador: por eso cola_sync.id_local NO es UNIQUE.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- El cliente acepta: el borrador se alinea con el precio del servidor.
UPDATE item_borrador
   SET precio_centavos_visto = 126923
 WHERE id_local    = 'c2000000-0000-4000-8000-000000000002'
   AND producto_id = 5;

-- Solicitud NUEVA (UUID distinto) para el mismo borrador.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('2b000000-0000-4000-8000-000000000002',
        'c2000000-0000-4000-8000-000000000002');
