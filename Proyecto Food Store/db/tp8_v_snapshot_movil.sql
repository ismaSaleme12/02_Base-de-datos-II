-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 2.a — La instantánea que viaja a la tablet
-- ----------------------------------------------------------------------------
--  Corre en PostgreSQL (base de PRUEBAS: Food_Store_Copia).
--  NO modifica nada: crea una vista de sólo lectura sobre `producto`.
--
--  Qué hace: traduce el modelo del servidor al contrato de la tablet.
--
--    servidor (PostgreSQL)            tablet (SQLite)
--    ------------------------------   -----------------------------------
--    producto.id                  ->  id
--    producto.nombre              ->  nombre
--    producto.precio NUMERIC(10,2)->  precio_centavos INTEGER  (x100)
--    producto.stock               ->  stock_visto
--    producto.activo              ->  disponible  /  eliminado
--
--  Decisiones de diseño (defendibles en la defensa):
--
--  1. El precio viaja en CENTAVOS y como entero. El dinero nunca se manda en
--     punto flotante: 0.1 + 0.2 no da 0.3 en binario, y en una caja eso es un
--     centavo perdido por venta.
--
--  2. `eliminado` NO filtra filas: los productos dados de baja siguen
--     apareciendo en la instantánea, marcados con eliminado = true. Si los
--     filtráramos, la tablet no podría distinguir "este producto ya no existe"
--     de "este producto fue dado de baja", y el caso C4 perdería sentido.
--
--  3. `disponible` = está activo Y tiene stock. Son dos condiciones distintas
--     de las cuatro que producen rojo en el semáforo:
--       - no existe            -> no está en la instantánea
--       - no disponible        -> disponible = false (activo pero sin stock)
--       - dado de baja         -> eliminado = true
--       - no alcanza el stock  -> cantidad > stock_visto
--
--  4. Los booleanos salen como booleanos y psql los exporta al CSV como
--     't'/'f'. SQLite en modo STRICT los rechaza en una columna INTEGER:
--     el cargador los normaliza a 1/0. Es un detalle real, no teórico.
--
--  5. `fecha_copia` viaja DENTRO de la instantánea y la sella el servidor.
--     Si la pusiera la tablet al importar, estaría registrando cuándo leyó el
--     archivo, no cuándo se tomó la foto. Una instantánea se fecha en origen.
-- ============================================================================

CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT
    p.id                             AS id,
    p.nombre                         AS nombre,
    (round(p.precio * 100))::integer AS precio_centavos,
    p.stock                          AS stock_visto,
    (p.activo AND p.stock > 0)       AS disponible,
    (NOT p.activo)                   AS eliminado,
    to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS') AS fecha_copia
FROM producto AS p;

COMMENT ON VIEW v_snapshot_movil IS
    'TP8 consigna 2.a: subconjunto de producto que viaja a la tablet. Solo lectura.';

-- ----------------------------------------------------------------------------
--  Control rápido: cuántas filas viajan y en qué estado quedan.
--  (Útil para el informe: deja constancia de que la vista no filtra bajas.)
-- ----------------------------------------------------------------------------
SELECT
    count(*)                                                   AS productos_totales,
    count(*) FILTER (WHERE disponible AND NOT eliminado)       AS vendibles_en_tablet,
    count(*) FILTER (WHERE eliminado)                          AS dados_de_baja,
    count(*) FILTER (WHERE disponible AND eliminado)           AS inconsistente
FROM v_snapshot_movil;
