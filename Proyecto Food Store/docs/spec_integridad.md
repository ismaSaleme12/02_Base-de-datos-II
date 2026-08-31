\# Especificación de reglas de integridad



\## Regla 1 — Solo productos activos en los pedidos



Un registro de `detalle\_pedido` solo podrá referenciar un `producto` cuyo campo `producto.activo` sea `TRUE`. Si se intenta insertar un detalle asociado a un producto inactivo, la operación deberá ser rechazada por la base de datos.



\## Regla 2 — Todo pedido debe tener al menos un detalle



Todo registro de `pedido` deberá tener al menos un registro asociado en `detalle\_pedido`. La base de datos deberá impedir que un pedido quede registrado sin ningún producto asociado.

