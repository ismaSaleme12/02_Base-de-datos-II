-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 2.b — El semáforo de sincronización
-- ----------------------------------------------------------------------------
--  Qué hace: compara cada solicitud PENDIENTE de cola_sync contra la
--  instantánea del servidor (snapshot_servidor) y le escribe el estado y el
--  motivo. NO toca PostgreSQL ni modifica producto_cache.
--
--  Regla de oro: el móvil propone, el servidor dispone.
--  Este script LEE una copia. No confirma ventas, no descuenta stock y no
--  cambia precios: sólo decide si la propuesta de la tablet habría pasado.
--
--  Semáforo:
--    ROJO     -> RECHAZADO          algún ítem tiene un problema de fondo
--    AMARILLO -> CONFLICTO          no hay rojo, pero cambió algún precio
--    VERDE    -> SIMULADO_APROBADO  todo coincide con el servidor
--
--  Los cuatro motivos de rojo son excluyentes y se evalúan en este orden:
--    1. el producto no existe en la instantánea
--    2. el producto fue dado de baja (eliminado = 1)
--    3. el producto no está disponible (activo pero sin stock)
--    4. no alcanza el stock para la cantidad pedida
--
--  IDEMPOTENCIA: el WHERE final filtra estado = 'PENDIENTE'. Una solicitud ya
--  resuelta no se vuelve a evaluar, así que correr el script dos veces seguidas
--  no cambia nada (ni "aprueba" dos veces lo mismo).
-- ============================================================================

PRAGMA foreign_keys = ON;

WITH item_evaluado AS (
    SELECT
        c.solicitud_uuid,
        i.producto_id,
        i.cantidad,
        i.precio_centavos_visto,
        s.id             AS id_servidor,
        s.stock_visto,
        s.precio_centavos,
        CASE
            WHEN i.producto_id IS NULL
                THEN 'borrador sin ítems'
            WHEN s.id IS NULL
                THEN 'producto ' || i.producto_id || ': no existe en el servidor'
            WHEN s.eliminado = 1
                THEN 'producto ' || i.producto_id || ': dado de baja'
            WHEN s.disponible = 0
                THEN 'producto ' || i.producto_id || ': no disponible (sin stock)'
            WHEN i.cantidad > s.stock_visto
                THEN 'producto ' || i.producto_id || ': no alcanza el stock (pide '
                     || i.cantidad || ', hay ' || s.stock_visto || ')'
            ELSE NULL
        END AS motivo_rojo,
        CASE
            WHEN s.id IS NOT NULL
             AND i.precio_centavos_visto <> s.precio_centavos
                THEN 'producto ' || i.producto_id || ': precio cambió de '
                     || i.precio_centavos_visto || ' a ' || s.precio_centavos || ' centavos'
            ELSE NULL
        END AS motivo_amarillo
    FROM cola_sync AS c
    LEFT JOIN item_borrador AS i
           ON i.id_local = c.id_local
    LEFT JOIN snapshot_servidor AS s
           ON s.id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
),
resumen AS (
    SELECT
        solicitud_uuid,
        count(*)                                AS items,
        sum(motivo_rojo IS NOT NULL)            AS items_rojos,
        sum(motivo_amarillo IS NOT NULL)        AS items_amarillos,
        group_concat(motivo_rojo, '; ')         AS detalle_rojo,
        group_concat(motivo_amarillo, '; ')     AS detalle_amarillo
    FROM item_evaluado
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
   SET estado = CASE
                    WHEN r.items_rojos > 0     THEN 'RECHAZADO'
                    WHEN r.items_amarillos > 0 THEN 'CONFLICTO'
                    ELSE 'SIMULADO_APROBADO'
                END,
       motivo = CASE
                    WHEN r.items_rojos > 0
                        THEN 'RECHAZADO: ' || r.detalle_rojo
                    WHEN r.items_amarillos > 0
                        THEN 'CONFLICTO: ' || r.detalle_amarillo
                    ELSE 'SIMULADO_APROBADO: todo coincide (simulación, no es una venta)'
                END
  FROM resumen AS r
 WHERE cola_sync.solicitud_uuid = r.solicitud_uuid
   AND cola_sync.estado = 'PENDIENTE';


-- ----------------------------------------------------------------------------
--  Evidencia: resultado del semáforo.
-- ----------------------------------------------------------------------------
.headers on
.mode table

SELECT
    c.solicitud_uuid,
    c.estado,
    c.motivo,
    p.usuario,
    p.forma_pago
FROM cola_sync AS c
JOIN pedido_borrador AS p ON p.id_local = c.id_local
ORDER BY c.estado, c.solicitud_uuid;

SELECT estado, count(*) AS solicitudes
FROM cola_sync
GROUP BY estado
ORDER BY estado;
