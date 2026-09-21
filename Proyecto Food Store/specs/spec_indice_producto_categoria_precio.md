# spec: indice_producto_categoria_precio_activo

Objetivo: acelerar búsquedas de catálogo "productos vigentes de una categoría con filtro de precio" y rankings por precio dentro de categoría.

Consulta afectada:
```sql
SELECT p.id, p.nombre, p.precio, c.nombre AS categoria
FROM producto p
JOIN categoria c ON p.categoria_id = c.id
WHERE c.nombre = 'Bebidas'
  AND p.activo = TRUE
  AND p.precio > 2000
ORDER BY p.precio DESC;
```

Frecuencia: alta — navegación de catálogo y filtros de e-commerce (cientos de consultas por hora).

Columnas candidatas: categoria_id (media selectividad, 10 categorías), precio (alta selectividad, rango), activo (baja cardinalidad boolean).

Tipo propuesto: índice B-tree compuesto PARCIAL (categoria_id, precio) WHERE activo = TRUE. Parcial porque solo los productos activos participan del catálogo visible; reduce tamaño del índice y mejora selectividad. Orden: categoria_id ASC, precio DESC para cubrir ORDER BY sin sort adicional cuando se filtra por categoría.

Criterio de aceptación: de Bitmap Heap Scan + Filter a Bitmap Index Scan más selectivo o Index Scan con menor Rows Removed by Filter. Buffers hit debe bajar y Sort Method pasar de external a quicksort/top-N con menor memoria.

Nota: no se indexa solo `activo` porque boolean sin condición parcial es de baja cardinalidad y el optimizador preferirá Seq Scan.

Generado con Kiro — validado con EXPLAIN ANALYZE antes y después.
