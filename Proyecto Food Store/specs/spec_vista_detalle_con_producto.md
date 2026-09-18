# spec: vista_detalle_pedido_con_producto

Objetivo: simplificar el reporte "detalle de un pedido con el nombre del producto" — evita repetir JOINs en cada consulta operativa.

Reporte: detalle por pedido, con cálculo de subtotal.

Columnas a exponer:
- pedido_id (detalle_pedido.pedido_id)
- producto_id (detalle_pedido.producto_id)
- producto_nombre (producto.nombre)
- categoria_nombre (categoria.nombre) — enriquecimiento útil
- cantidad (detalle_pedido.cantidad)
- precio_unitario (detalle_pedido.precio_unitario)
- subtotal (cantidad * precio_unitario) AS subtotal

Filtros: sin filtro de vigencia adicional (producto ya validado por trigger que impide detalle con producto inactivo). Opcional: WHERE producto.activo = TRUE para robustez.

Joins: detalle_pedido JOIN producto ON detalle_pedido.producto_id = producto.id JOIN categoria ON producto.categoria_id = categoria.id

Criterio de aceptación: equivalencia exacta contra consulta manual:
```sql
SELECT dp.pedido_id, dp.producto_id, pr.nombre AS producto_nombre, c.nombre AS categoria_nombre,
       dp.cantidad, dp.precio_unitario, (dp.cantidad * dp.precio_unitario) AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON dp.producto_id = pr.id
JOIN categoria c ON pr.categoria_id = c.id
ORDER BY dp.pedido_id, pr.nombre;
```
Verificación con EXCEPT ambos sentidos = 0 filas.

Generado con Kiro → OpenCode.
