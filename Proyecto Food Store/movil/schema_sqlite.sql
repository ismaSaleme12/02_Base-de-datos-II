-- ============================================================================
--  TP 8 · Unidad 8 · Food Store en la feria
--  Consigna 1.b — Esquema de la base de la tablet (SQLite 3.37+)
-- ----------------------------------------------------------------------------
--  Contexto: el food truck vende en una feria SIN SEÑAL. La tablet guarda un
--  subconjunto del catálogo y arma borradores de pedido. NO es la fuente de
--  verdad: precio, stock y ventas los decide PostgreSQL.
--
--  Regla de oro: el móvil propone, el servidor dispone.
--  Este esquema NO tiene tabla de ventas a propósito: un SIMULADO_APROBADO
--  es una propuesta de la tablet, nunca una venta confirmada.
--
--  Uso:
--    sqlite3 foodstore_movil.db < schema_sqlite.sql
--  (o abrir el archivo desde DB Browser for SQLite y ejecutarlo)
--
--  Nota: PRAGMA foreign_keys es POR CONEXIÓN y es NO-OP dentro de una
--  transacción. Por eso va como primera sentencia del script.
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
--  1) producto_cache
--     Copia de sólo lectura del subconjunto de `producto` que viaja a la
--     tablet. Se puebla desde la instantánea del servidor (consigna 2.a).
--
--     precio_centavos : entero, para no arrastrar punto flotante al dinero.
--     stock_visto     : stock tal como estaba en el momento de la copia.
--     disponible      : 0/1 — se puede vender ahora (activo y con stock).
--     eliminado       : 0/1 — baja lógica en el servidor. La fila NO se borra:
--                       si se borrara, los borradores históricos perderían su
--                       clave foránea y el caso C4 no se podría explicar.
--     fecha_copia     : ISO-8601 del momento en que se trajo la instantánea.
-- ----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id              INTEGER NOT NULL PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL
                    CONSTRAINT ck_producto_cache_precio_no_negativo
                    CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL
                    CONSTRAINT ck_producto_cache_stock_no_negativo
                    CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL
                    CONSTRAINT ck_producto_cache_disponible_booleano
                    CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL
                    CONSTRAINT ck_producto_cache_eliminado_booleano
                    CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT    NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
--  2) pedido_borrador
--     El pedido que el vendedor arma en la tablet. Vive sólo acá hasta que el
--     servidor lo confirme (y eso queda fuera del alcance de este TP).
--
--     id_local   : UUID generado por la tablet. Es la identidad del borrador
--                  mientras no existe id de servidor. Nunca se reutiliza.
--     usuario    : identificador SINTÉTICO del vendedor (ej. 'caja-01').
--                  Regla 2 del TP: nada de nombres, mails ni datos reales.
--     forma_pago : mismo dominio que el ENUM `forma_pago` de PostgreSQL.
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local   TEXT NOT NULL PRIMARY KEY
               CONSTRAINT ck_pedido_borrador_uuid_formato
               CHECK (id_local GLOB '????????-????-????-????-????????????'),
    usuario    TEXT NOT NULL
               CONSTRAINT ck_pedido_borrador_usuario_no_vacio
               CHECK (length(trim(usuario)) > 0),
    forma_pago TEXT NOT NULL
               CONSTRAINT ck_pedido_borrador_forma_pago
               CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha      TEXT NOT NULL
) STRICT;

-- ----------------------------------------------------------------------------
--  3) item_borrador
--     Renglones del borrador. `precio_centavos_visto` es el precio que el
--     cliente vio en la tablet: si el servidor lo cambió, esa diferencia es
--     exactamente lo que detecta el semáforo (amarillo / CONFLICTO).
--
--     PK compuesta (id_local, producto_id): un producto no se repite dentro
--     del mismo borrador, igual que en `detalle_pedido`.
-- ----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL,
    producto_id           INTEGER NOT NULL,
    cantidad              INTEGER NOT NULL
                          CONSTRAINT ck_item_borrador_cantidad_positiva
                          CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL
                          CONSTRAINT ck_item_borrador_precio_no_negativo
                          CHECK (precio_centavos_visto >= 0),

    CONSTRAINT pk_item_borrador
        PRIMARY KEY (id_local, producto_id),

    -- Si se descarta el borrador, sus renglones se van con él.
    CONSTRAINT fk_item_borrador_pedido
        FOREIGN KEY (id_local)
        REFERENCES pedido_borrador (id_local)
        ON DELETE CASCADE,

    -- RESTRICT y no CASCADE: borrar un producto de la cache no debe borrar
    -- en silencio el renglón de un borrador ya armado. La baja es lógica
    -- (eliminado = 1), nunca física.
    CONSTRAINT fk_item_borrador_producto
        FOREIGN KEY (producto_id)
        REFERENCES producto_cache (id)
        ON DELETE RESTRICT
) STRICT;

-- ----------------------------------------------------------------------------
--  4) cola_sync
--     Bandeja de salida hacia el servidor. Cada fila es UNA solicitud de
--     validación de UN borrador.
--
--     solicitud_uuid : PK. Esto es lo que da idempotencia (caso C6): reenviar
--                      el mismo UUID revienta por clave primaria duplicada en
--                      vez de duplicar el envío.
--     estado         : arranca en PENDIENTE; el semáforo lo resuelve.
--                      SIMULADO_APROBADO NO es una venta: es la simulación de
--                      que el servidor la habría aceptado.
--     motivo         : texto legible que explica el estado (lo llena el
--                      semáforo). NULL mientras está PENDIENTE.
--
--     Un mismo id_local puede tener varias solicitudes a lo largo del tiempo
--     (ej. C2: primero CONFLICTO, después de aceptar el precio, una nueva
--     solicitud da SIMULADO_APROBADO). Por eso id_local NO es UNIQUE acá.
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid TEXT NOT NULL PRIMARY KEY
                   CONSTRAINT ck_cola_sync_uuid_formato
                   CHECK (solicitud_uuid GLOB '????????-????-????-????-????????????'),
    id_local       TEXT NOT NULL,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                   CONSTRAINT ck_cola_sync_estado
                   CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO',
                                     'SIMULADO_APROBADO')),
    motivo         TEXT,

    CONSTRAINT fk_cola_sync_pedido
        FOREIGN KEY (id_local)
        REFERENCES pedido_borrador (id_local)
        ON DELETE CASCADE
) STRICT;

-- ----------------------------------------------------------------------------
--  Índices de apoyo
--  El semáforo filtra siempre por estado = 'PENDIENTE'; con muchos envíos
--  acumulados, sin este índice el barrido se vuelve secuencial.
-- ----------------------------------------------------------------------------
CREATE INDEX idx_cola_sync_estado ON cola_sync (estado);
CREATE INDEX idx_item_borrador_producto ON item_borrador (producto_id);
