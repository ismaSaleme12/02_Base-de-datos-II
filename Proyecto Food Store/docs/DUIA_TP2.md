# DUIA_TP2 – Parte 1: Integridad versionada

## Herramienta

OpenCode.

Se utilizó OpenCode como herramienta de inteligencia artificial para analizar el esquema de la base de datos Food_Store, proponer una implementación para las reglas de integridad seleccionadas y generar el script correspondiente.

La implementación fue revisada manualmente antes de ejecutarse sobre la copia de trabajo de la base de datos.

---

## Spec o prompt utilizado

Se utilizó OpenCode para implementar las reglas de integridad especificadas en `spec_integridad.md`.

El primer prompt utilizado fue el siguiente:

" Quiero implementar las reglas de integridad especificada en spec_integridad.md. Regla 1: un Registro de detalle_pedido solo puede referenciar un producto cuyo producto.activo = true. Si se intenta insertar un detalle asociado a un producto inactivo, la operacion debe ser rechazada por la base de datos. Regla 2: Todo pedido debe tener al menos un registro asociado a detalle_pedido. la base de datos debe impedir que un pedido quede registrado sin ningun producto. Trabaja primero en modo plan. Analiza el esquema existente ubicado en la carpeta db y poropone una solucion utilizando las restricciones declarativas o triggers segun corresponda. No modifiques ni cree nignun archivo todavía "

## Qué generó

OpenCode generó el archivo:

`db/reglas_integridad.sql`

El script implementó las dos reglas seleccionadas mediante funciones y triggers de PostgreSQL.

### Para la Regla 1

Se generó:

- La función `fn_check_producto_activo()`.
- El trigger `trg_check_producto_activo` sobre `detalle_pedido`.
- La validación se ejecuta antes de insertar o modificar un detalle.

La función verifica que el producto referenciado exista y que su campo `producto.activo` sea `TRUE`.

### Para la Regla 2

Se generaron:

- La función `fn_assert_pedido_tiene_detalle()`.
- La función `fn_verificar_pedido_tiene_detalle()`.
- Triggers diferidos (`DEFERRABLE INITIALLY DEFERRED`) para verificar la existencia de al menos un detalle al finalizar la transacción.

Esto permite crear primero el pedido y luego sus detalles dentro de la misma transacción, pero impide confirmar la transacción si el pedido queda sin detalles.

---

## Qué se aceptó

Se aceptó la implementación generada para las dos reglas seleccionadas.

### Regla 1

Se aceptó:

- `fn_check_producto_activo()`.
- `trg_check_producto_activo`.
- La validación antes de insertar o modificar registros de `detalle_pedido`.

La regla garantiza que un `detalle_pedido` no pueda utilizar un producto cuyo campo `producto.activo` sea `FALSE`.

### Regla 2

Se aceptó:

- `fn_assert_pedido_tiene_detalle()`.
- `fn_verificar_pedido_tiene_detalle()`.
- Los triggers diferidos utilizados para realizar la validación al finalizar la transacción.

La regla garantiza que un pedido no pueda confirmarse sin tener al menos un detalle asociado.

---

## Qué se modificó o descartó, y por qué

No se realizaron modificaciones manuales sobre la implementación de las dos reglas seleccionadas.

Durante el desarrollo se decidió trabajar únicamente con dos reglas de negocio para la Parte 1, descartando la incorporación de una tercera regla.

La implementación utilizada para las dos reglas seleccionadas se mantuvo en:

`db/reglas_integridad.sql`

---

## Verificación realizada

Las pruebas se realizaron sobre la copia de trabajo de la base de datos `Food_Store_Copia`, siguiendo el protocolo de seguridad definido para el TP.

Antes de aplicar los cambios se utilizó una transacción con:

`BEGIN;`

y durante las pruebas se utilizó:

`ROLLBACK;`

para comprobar el comportamiento sin confirmar los cambios de prueba.

### Regla 1 – Producto inactivo

Se creó un producto de prueba con:

- Nombre: `Producto Inactivo Prueba TP`
- Precio: `1000`
- Stock: `10`
- Activo: `FALSE`

Luego se intentó agregar dicho producto a un `detalle_pedido`.

Resultado:

La operación fue rechazada por la función `fn_check_producto_activo()`, indicando que el producto se encontraba inactivo y no podía agregarse al detalle del pedido.

Esto confirmó que la Regla 1 funciona correctamente.

### Regla 1 – Producto activo

También se verificó el comportamiento con un producto activo.

Resultado:

La inserción del detalle asociado al producto activo fue aceptada correctamente.

Esto confirmó que la regla no bloquea productos válidos.

### Regla 2 – Pedido sin detalle

Se verificó el comportamiento de un pedido que no posee ningún registro asociado en `detalle_pedido`.

La validación se realizó mediante los triggers diferidos implementados en `db/reglas_integridad.sql`.

Resultado:

La validación se realiza al finalizar la transacción. Un pedido puede construirse inicialmente sin detalle dentro de la misma transacción, pero el `COMMIT` es rechazado si el pedido continúa sin ningún detalle asociado.

También se verificó el caso válido, agregando un detalle al pedido antes de finalizar la transacción.

Resultado:

La transacción puede confirmarse cuando el pedido posee al menos un detalle.

Esto confirmó que la Regla 2 funciona correctamente.

---

## Resultado general

Las dos reglas de negocio seleccionadas para la Parte 1 quedaron implementadas y verificadas sobre la copia de trabajo de la base de datos.

La implementación quedó versionada en Git junto con la documentación correspondiente.

El proceso seguido fue:

1. Definición de las reglas mediante una spec.
2. Generación mediante OpenCode.
3. Revisión del código generado.
4. Revisión del `git diff`.
5. Aplicación sobre la copia de trabajo.
6. Pruebas con casos válidos e inválidos.
7. Uso de transacciones para verificar los cambios.
8. Confirmación de los cambios.
9. Commit y publicación en el repositorio.