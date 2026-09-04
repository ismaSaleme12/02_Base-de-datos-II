-- ============================================================
-- Script  : carga_masiva.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-09-04
-- Desc    : Poblamiento masivo limpio con IDs desde 1 en adelante:
--           1. Vaciado de todas las tablas y reinicio de identidades (RESTART IDENTITY CASCADE).
--           2. Inserción de categorías base.
--           3. 20.000 clientes (IDs 1 a 20000).
--           4. 50.000 productos (IDs 1 a 50000, precios 500-5000, stock 0-200).
--           5. 200.000 pedidos (IDs 1 a 200000).
--           6. 200.000 detalles de pedido asociados.
-- PRECONDICIÓN: Seguir el Protocolo de Seguridad (respaldo con pg_dump previo).
-- ============================================================

BEGIN;

-- 0. Eliminar datos anteriores y reiniciar todas las identidades desde 1
TRUNCATE TABLE detalle_pedido, pedido, producto, cliente, categoria RESTART IDENTITY CASCADE;

-- 0.1. Insertar categorías base (IDs 1 a 10)
INSERT INTO categoria (nombre, activo)
VALUES 
    ('Bebidas', true), 
    ('Comidas', true), 
    ('Postres', true), 
    ('Snacks', true), 
    ('Lácteos', true),
    ('Panadería', true), 
    ('Verdulería', true), 
    ('Carnicería', true), 
    ('Limpieza', true), 
    ('Almacén', true);

-- 1. Inserción de 20.000 clientes (IDs 1 a 20000)
INSERT INTO cliente (nombre, email, telefono)
SELECT 
    'Cliente ' || i,
    'cliente' || i || '@example.com',
    '555-' || lpad(i::text, 6, '0')
FROM generate_series(1, 20000) AS i;

-- 2. Inserción de 50.000 productos distribuidos equitativamente entre las categorías (IDs 1 a 50000)
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
SELECT 
    'Producto ' || i,
    500 + (random() * 4500)::numeric(10,2),
    floor(random() * 201)::integer,
    true,
    ((i - 1) % 10) + 1 AS categoria_id
FROM generate_series(1, 50000) AS i;

-- Desactivar temporalmente el trigger de validación de pedidos
ALTER TABLE pedido DISABLE TRIGGER trg_verificar_pedido;
ALTER TABLE detalle_pedido DISABLE TRIGGER trg_verificar_detalle_pedido;


-- 3. Inserción de 200.000 pedidos (IDs 1 a 200000)
INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT 
    now() - (random() * interval '365 days'),
    (ARRAY['EFECTIVO'::forma_pago, 'TARJETA'::forma_pago, 'TRANSFERENCIA'::forma_pago])[floor(random() * 3 + 1)],
    floor(random() * 20000 + 1)::bigint
FROM generate_series(1, 200000) AS i;

-- 4. Inserción de detalles de pedido (exactamente 1 detalle por cada pedido, cumpliendo regla de negocio)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT 
    p.id AS pedido_id,
    ((p.id - 1) % 50000) + 1 AS producto_id,
    floor(random() * 5 + 1)::integer AS cantidad,
    (SELECT precio FROM producto WHERE id = ((p.id - 1) % 50000) + 1) AS precio_unitario
FROM pedido p;

-- 7. Reactivar los triggers de validación de integridad
ALTER TABLE pedido ENABLE TRIGGER trg_verificar_pedido;
ALTER TABLE detalle_pedido ENABLE TRIGGER trg_verificar_detalle_pedido;

-- Actualizar estadísticas del optimizador para planes de ejecución masivos
ANALYZE cliente;
ANALYZE producto;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- Confirmar transacción
COMMIT;
