# spec: vista_materializada_facturacion_categoria_mes

Objetivo: materializar el reporte agregado costoso "facturación por categoría y mes" para consulta instantánea en dashboard.

Consulta original costosa (cruzando 4 tablas, 200k pedidos + 200k detalles + 50k productos):
```sql
SELECT c.nombre AS categoria,
       to_char(p.fecha,'YYYY-MM') AS mes,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total,
       COUNT(DISTINCT p.id) AS total_pedidos
FROM categoria c
JOIN producto pr ON pr.categoria_id = c.id
JOIN detalle_pedido dp ON dp.producto_id = pr.id
JOIN pedido p ON p.id = dp.pedido_id
GROUP BY c.nombre, to_char(p.fecha,'YYYY-MM')
ORDER BY mes DESC, facturacion_total DESC;
-- Costo observado: ~523 ms, temp files 1.2MB, external merge sort
```

Vista materializada: `vm_facturacion_categoria_mes` con WITH DATA.

Columnas: categoria, mes (text YYYY-MM), facturacion_total (numeric), total_pedidos (bigint)

Índice único requerido para REFRESH CONCURRENTLY: UNIQUE (categoria, mes) — permite refresco sin bloquear lecturas.

Criterio de aceptación:
- SELECT * FROM vm_facturacion_categoria_mes < 5 ms (vs 500+ ms original)
- Índice único existe y permite `REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;` sin AccessExclusiveLock.
- Datos coinciden con consulta original antes de refrescar (validado con EXCEPT).

Frecuencia de REFRESH: diaria (00:05 AM) o cada 6 horas según uso del dashboard. Justificación: reporte histórico por mes no necesita tiempo real; staleness de hasta 24h es aceptable para decisiones tácticas. Para operativa intradía se usa consulta directa filtrada por hoy con índice fecha. Implica que usuarios ven datos con retraso hasta el próximo REFRESH; no afecta transacciones OLTP.

Generado con Kiro → OpenCode.
