# spec: indice_pedido_fecha_forma_pago

Objetivo: acelerar el reporte "pedidos por mes y forma de pago" y filtros por rango de fecha + forma de pago.

Consulta afectada:
```sql
SELECT id, fecha, forma_pago, cliente_id
FROM pedido
WHERE fecha BETWEEN :desde AND :hasta
  AND forma_pago = 'TARJETA'
ORDER BY fecha DESC;
```

Frecuencia: alta — reporte mensual y listado operativo diario (decenas de ejecuciones por día).

Columnas candidatas: fecha (alta selectividad, rango), forma_pago (baja selectividad, 3 valores).

Tipo propuesto: índice B-tree compuesto (fecha, forma_pago). Orden: fecha ASC, forma_pago ASC; permite Index Scan con Index Cond sobre ambas columnas y sort backward para ORDER BY fecha DESC.

Criterio de aceptación: el plan pasa de Parallel Seq Scan a Index Scan / Index Scan Backward y el tiempo baja al menos un orden de magnitud. EXPLAIN ANALYZE debe mostrar Buffers shared hit < 20 y Execution Time < 1 ms.

Decisión: si la medición no muestra mejora, se descarta por sobreindexación.

Generado con Kiro — revisado línea por línea antes de ejecutar en Food_Store_Copia con BEGIN; ROLLBACK; previo.
