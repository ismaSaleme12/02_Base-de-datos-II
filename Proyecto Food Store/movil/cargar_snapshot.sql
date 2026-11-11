-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 2.a — De la instantánea del servidor a la cache de la tablet
-- ----------------------------------------------------------------------------
--  Precondición: `snapshot_servidor` ya existe y tiene las filas del CSV
--  exportado desde v_snapshot_movil. Secuencia completa:
--
--      .read schema_snapshot.sql
--      .import --csv --skip 1 servidor_snapshot.csv snapshot_servidor
--      .read cargar_snapshot.sql
--
--  Ojo con el `--skip 1`: sólo tiene sentido si la tabla YA existe. Si sqlite3
--  tiene que crearla, usa la primera fila que ve como nombres de columna; con
--  --skip 1 esa "primera fila" es el primer producto y se pierde una fila.
--
--  ---------------------------------------------------------------------------
--  EL DETALLE QUE ROMPE TODO (y que costó un bug real en este TP)
--  ---------------------------------------------------------------------------
--  psql exporta los booleanos como 't' y 'f'. En SQLite, 't' = 1 es FALSO y
--  'f' = 0 también es FALSO: no hay conversión implícita de texto a número en
--  una comparación, y además cualquier texto es mayor que cualquier número.
--
--  Consecuencia si no se normaliza: el semáforo nunca detecta "dado de baja"
--  ni "no disponible", y esas solicitudes caen en verde. El error es silencioso
--  porque el chequeo de stock puede taparlo en algunos casos.
--
--  Por eso se normaliza UNA sola vez, acá, al aterrizar la instantánea.
-- ============================================================================

PRAGMA foreign_keys = ON;

.headers on
.mode table

-- ----------------------------------------------------------------------------
--  1) Control de entrada: qué trajo el CSV
-- ----------------------------------------------------------------------------
SELECT 'INSTANTÁNEA RECIBIDA' AS paso,
       count(*)                                AS filas,
       min(fecha_copia)                        AS fecha_copia,
       sum(lower(CAST(disponible AS TEXT)) = 't') AS disponibles_t,
       sum(lower(CAST(eliminado  AS TEXT)) = 't') AS dados_de_baja_t
FROM snapshot_servidor;

-- ----------------------------------------------------------------------------
--  2) Normalización: 't'/'true'/'1' -> 1, todo lo demás -> 0
--     Después de este UPDATE las dos columnas son INTEGER de verdad.
-- ----------------------------------------------------------------------------
UPDATE snapshot_servidor
   SET disponible = CASE
                        WHEN lower(CAST(disponible AS TEXT)) IN ('t', 'true', '1') THEN 1
                        ELSE 0
                    END,
       eliminado  = CASE
                        WHEN lower(CAST(eliminado  AS TEXT)) IN ('t', 'true', '1') THEN 1
                        ELSE 0
                    END;

-- Verificación: ninguna fila puede quedar fuera de {0,1}.
SELECT 'NORMALIZACIÓN' AS paso,
       count(*)                                          AS filas,
       sum(disponible NOT IN (0, 1))                     AS disponible_invalido,
       sum(eliminado  NOT IN (0, 1))                     AS eliminado_invalido,
       sum(disponible = 1 AND eliminado = 1)             AS inconsistente
FROM snapshot_servidor;

-- ----------------------------------------------------------------------------
--  3) Poblado de la cache
--     ON CONFLICT: recargar el catálogo actualiza, no duplica. La fila de un
--     producto dado de baja NO se borra: queda con eliminado = 1 para que los
--     borradores históricos conserven su clave foránea (caso C4).
-- ----------------------------------------------------------------------------
INSERT INTO producto_cache
    (id, nombre, precio_centavos, stock_visto, disponible, eliminado, fecha_copia)
SELECT
    CAST(s.id              AS INTEGER),
    s.nombre,
    CAST(s.precio_centavos AS INTEGER),
    CAST(s.stock_visto     AS INTEGER),
    s.disponible,
    s.eliminado,
    s.fecha_copia
FROM snapshot_servidor AS s
-- El `WHERE true` NO es decorativo: en SQLite, un UPSERT después de un
-- INSERT ... SELECT es ambiguo y el parser falla con "near DO: syntax error".
-- El WHERE fuerza a cerrar el SELECT antes del ON CONFLICT.
WHERE true
ON CONFLICT (id) DO UPDATE SET
    nombre          = excluded.nombre,
    precio_centavos = excluded.precio_centavos,
    stock_visto     = excluded.stock_visto,
    disponible      = excluded.disponible,
    eliminado       = excluded.eliminado,
    fecha_copia     = excluded.fecha_copia;

-- ----------------------------------------------------------------------------
--  4) Control de salida: la cache quedó consistente con la instantánea
-- ----------------------------------------------------------------------------
SELECT 'CACHE ACTUALIZADA' AS paso,
       count(*)                                                 AS filas_en_cache,
       sum(disponible)                                          AS vendibles,
       sum(eliminado)                                           AS dados_de_baja,
       count(*) FILTER (WHERE disponible = 1 AND eliminado = 1) AS inconsistentes
FROM producto_cache;

-- Catálogo que ve el vendedor: sólo lo que se puede vender hoy.
-- (Se muestran 10: son ~49.700 filas, no tiene sentido volcarlas a pantalla.)
SELECT id, nombre, precio_centavos, stock_visto
FROM producto_cache
WHERE disponible = 1
  AND eliminado  = 0
ORDER BY id
LIMIT 10;
