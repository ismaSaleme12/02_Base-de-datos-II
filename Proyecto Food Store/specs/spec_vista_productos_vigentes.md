# spec: vista_productos_vigentes_con_categoria

Objetivo: simplificar y estandarizar el acceso al catálogo visible de Food Store.

Reporte: "Productos vigentes con su categoría" — usado en listado público, buscador y validación de detalle_pedido (solo productos activos).

Columnas a exponer:
- producto_id (producto.id)
- producto_nombre (producto.nombre)
- precio (producto.precio)
- stock (producto.stock)
- categoria_id (categoria.id)
- categoria_nombre (categoria.nombre)

Filtro de vigencia: producto.activo = TRUE AND categoria.activo = TRUE

Columnas a ocultar: ninguna sensible en esta vista (producto no tiene contraseña/dato sensible). Se aplica principio de menor exposición: no se expone producto.activo booleano porque la vista ya filtra vigentes.

Joins: producto JOIN categoria ON producto.categoria_id = categoria.id

Orden: categoria_nombre ASC, producto_nombre ASC

Criterio de aceptación: SELECT * FROM v_productos_vigentes_con_categoria devuelve exactamente las mismas filas y columnas que la consulta manual:
```sql
SELECT p.id, p.nombre, p.precio, p.stock, c.id AS categoria_id, c.nombre AS categoria_nombre
FROM producto p JOIN categoria c ON p.categoria_id = c.id
WHERE p.activo = TRUE AND c.activo = TRUE;
```
Verificación con EXCEPT en ambos sentidos debe dar 0 filas.

Generado con Kiro → OpenCode.
