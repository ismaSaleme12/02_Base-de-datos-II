-- ============================================================
-- Script  : verificacion_parcial.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : 2026-09-07
-- Desc    : Script integral de pruebas y verificacion para capturas de evidencias
--           requeridas en el informe del Primer Parcial TPI.
-- ============================================================


-- ============================================================
-- 1. OBJETO: R1 - PRODUCTO ACTIVO (Trigger R1)
-- ============================================================

-- A. Caso Inválido: Intentar agregar un detalle con un producto inactivo (activo = FALSE)
BEGIN;

-- Crear un producto inactivo de prueba
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Inactivo Test', 1500.00, 10, FALSE, 1)
RETURNING id;

-- Supongamos que el ID generado es el último producto. Intentamos insertarlo en detalle_pedido:
-- (Reemplazar X por el id devuelto o usar un subselect)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, (SELECT MAX(id) FROM producto WHERE activo = FALSE), 2, 1500.00);

ROLLBACK; -- Debe fallar con el error de producto inactivo


-- B. Caso Válido: Insertar un detalle con un producto activo (activo = TRUE)
BEGIN;

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, (SELECT id FROM producto WHERE activo = TRUE LIMIT 1), 2, 1500.00);

ROLLBACK; -- Aceptado correctamente (INSERT 0 1)


-- ============================================================
-- 2. OBJETO: R2 - PEDIDO SIN DETALLE (Trigger Diferido)
-- ============================================================

-- A. Caso Rechazado en COMMIT (Pedido sin detalle)
BEGIN;

INSERT INTO pedido (forma_pago, cliente_id)
VALUES ('EFECTIVO', (SELECT MIN(id) FROM cliente));

COMMIT; -- Debe fallar al hacer commit por el trigger diferido


-- B. Caso Exitoso con Detalle en la misma Transacción
BEGIN;

INSERT INTO pedido (forma_pago, cliente_id)
VALUES ('EFECTIVO', (SELECT MIN(id) FROM cliente))
RETURNING id;

-- Insertar el detalle asociado al nuevo pedido (ejemplo usando currval o max)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES ((SELECT MAX(id) FROM pedido), (SELECT MIN(id) FROM producto), 1, 1000.00);

COMMIT; -- OK


-- C. Caso de Borrado de Detalle que deja un pedido vacío (Falla en COMMIT)
BEGIN;

-- Tomar un pedido existente y borrar su detalle
DELETE FROM detalle_pedido 
WHERE pedido_id = (SELECT MIN(pedido_id) FROM detalle_pedido);

COMMIT; -- Debe fallar en el commit por quedar sin detalle


-- ============================================================
-- 3. OBJETO: VISTAS Y EQUIVALENCIA (EXCEPT)
-- ============================================================

-- (Si posees vistas como v_productos_vigentes_con_categoria, v_pedidos_con_cliente, etc.)
-- Ejemplo de prueba EXCEPT bidireccional (debe dar 0 filas):

/*
(SELECT * FROM v_productos_vigentes_con_categoria)
EXCEPT
(SELECT p.id, p.nombre, p.precio, c.nombre FROM producto p JOIN categoria c ON p.categoria_id = c.id WHERE p.activo = TRUE AND c.activo = TRUE);

(SELECT p.id, p.nombre, p.precio, c.nombre FROM producto p JOIN categoria c ON p.categoria_id = c.id WHERE p.activo = TRUE AND c.activo = TRUE)
EXCEPT
(SELECT * FROM v_productos_vigentes_con_categoria);
*/


-- ============================================================
-- 4. OBJETO: CARGA MASIVA - CONTEO POR TABLA
-- ============================================================

SELECT 'categoria' AS tabla, COUNT(*) FROM categoria
UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL
SELECT 'producto', COUNT(*) FROM producto
UNION ALL
SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL
SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;


-- ============================================================
-- 5. OBJETO: DDL - VALIDACIÓN DE RESTRICCIONES (CHECK, UNIQUE, FK)
-- ============================================================

-- A. Intentar insertar un producto con precio negativo (violando CHECK check_producto_precio)
BEGIN;

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto Precio Negativo', -500.00, 10, TRUE, 1);

ROLLBACK; -- Debe retornar: ERROR: new row for relation "producto" violates check constraint "check_producto_precio"


-- B. Intentar insertar un cliente con email duplicado (violando UNIQUE)
BEGIN;

INSERT INTO cliente (nombre, email, telefono)
VALUES ('Cliente Duplicado', (SELECT email FROM cliente LIMIT 1), '555-9999');

ROLLBACK; -- Debe retornar error de llave duplicada viola restricción UNIQUE
