# spec: indice_detalle_pedido_producto

Objetivo: acelerar agregaciones y reportes que cruzan detalle_pedido → producto → categoria (recaudación por categoría, facturación por mes).

Consulta afectada:
```sql
SELECT c.nombre AS categoria,
       COUNT(dp.producto_id) AS total_vendidos,
       SUM(dp.cantidad * dp.precio_unitario) AS recaudacion
FROM categoria c
JOIN producto p ON c.id = p.categoria_id
JOIN detalle_pedido dp ON p.id = dp.producto_id
GROUP BY c.id, c.nombre
ORDER BY recaudacion DESC;

-- y variantes con filtro de fecha:
SELECT to_char(p.fecha,'YYYY-MM') AS mes, SUM(...) ...
FROM detalle_pedido dp JOIN pedido p ON dp.pedido_id = p.id ...
```

Frecuencia: media-alta — reportes analíticos diarios y dashboard de ventas (5-10 ejecuciones por día, sobre 200k filas en detalle_pedido).

Columnas candidatas: detalle_pedido(producto_id) — FK inversa. La PK es (pedido_id, producto_id), por lo que una búsqueda por producto_id solo no usa la PK eficientemente; requiere Seq Scan o segundo índice.

Tipo propuesto: índice B-tree simple sobre detalle_pedido(producto_id). Tipo B-tree estándar; no parcial porque todas las filas participan de las agregaciones.

Criterio de aceptación: el plan de JOIN Hash/Seq Scan debe poder evaluar Index Scan o Bitmap Heap Scan cuando el reporte filtra por producto/categoría. Para agregación total (sin filtro) es esperable que el optimizador mantenga Seq Scan; la mejora se valida sobre consultas filtradas por categoría o por producto específico. No debe degradar INSERT en detalle_pedido más de 15%.

Generado con Kiro — medido con EXPLAIN ANALYZE y prueba de escritura de 500 INSERT.
