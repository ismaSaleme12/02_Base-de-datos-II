# DUIA — Parte 1: Integridad versionada

## Herramienta
OpenCode.

## Spec o prompt utilizado

Se utilizó la especificación previamente definida en `docs/spec_integridad.md`, con las siguientes reglas:

### Regla 1 — Solo productos activos en los pedidos

Un registro de `detalle_pedido` solo podrá referenciar un producto cuyo campo `producto.activo` sea `TRUE`. Si se intenta insertar un detalle asociado a un producto inactivo, la operación deberá ser rechazada por la base de datos.

### Regla 2 — Todo pedido debe tener al menos un detalle

Todo registro de `pedido` deberá tener al menos un registro asociado en `detalle_pedido`. La base de datos deberá impedir que un pedido quede registrado sin ningún producto asociado.

## Qué generó

OpenCode generó el archivo `db/reglas_integridad.sql`, que implementa las dos reglas mediante funciones y triggers de PostgreSQL.

Para la Regla 1 se generó:

- La función `fn_check_producto_activo()`.
- El trigger `trg_check_producto_activo` sobre `detalle_pedido`.
- La validación se ejecuta antes de insertar o modificar un detalle.

Para la Regla 2 se generó:

- La función `fn_assert_pedido_tiene_detalle()`.
- La función `fn_verificar_pedido_tiene_detalle()`.
- Triggers diferidos (`DEFERRABLE INITIALLY DEFERRED`) para validar la existencia de detalles al finalizar la transacción.

## Qué se aceptó

Se aceptó la implementación generada para las dos reglas:

1. Impedir que `detalle_pedido` utilice productos cuyo campo `producto.activo` sea `FALSE`.
2. Garantizar que los pedidos tengan al menos un detalle asociado.

La implementación se mantuvo en `db/reglas_integridad.sql`.

## Qué se modificó o descartó, y por qué

Se decidió trabajar únicamente con dos reglas de negocio en la Parte 1, descartando la incorporación de una tercera regla.

No se realizaron modificaciones manuales adicionales al archivo `db/reglas_integridad.sql` respecto de la implementación utilizada para las dos reglas seleccionadas.

## Verificación realizada

### Regla 1

Se realizó una prueba intentando agregar un `detalle_pedido` asociado a un producto inactivo.

Resultado: la operación fue rechazada por la función `fn_check_producto_activo()`, mostrando el mensaje de error correspondiente.

También se verificó que un producto activo pudiera ser utilizado correctamente en un `detalle_pedido`.

Resultado: la inserción del detalle para el producto activo fue aceptada.

### Regla 2

Se verificó la validación de pedidos sin detalles mediante los triggers diferidos implementados en `db/reglas_integridad.sql`.

La validación se realiza al finalizar la transacción, permitiendo construir el pedido y sus detalles dentro de la misma transacción, pero rechazando el `COMMIT` si el pedido queda sin ningún detalle asociado.

### Resultado general

Las dos reglas seleccionadas quedaron implementadas y verificadas sobre la copia de trabajo de la base de datos.
