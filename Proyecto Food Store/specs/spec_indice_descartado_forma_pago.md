# spec: indice_descartado — sobreindexación

Propuesta IA descartada:

```sql
CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);
-- o también propuesto: CREATE INDEX idx_producto_activo ON producto(activo);
-- o: CREATE INDEX idx_cliente_email ON cliente(email);
```

Motivo de descarte (decisión humana, NO delegada):

1. `pedido(forma_pago)`: columna enum de 3 valores (EFECTIVO, TARJETA, TRANSFERENCIA) — cardinalidad bajísima. Selectividad ~33% por valor. El optimizador hará Seq Scan igualmente porque filtrar por un valor devuelve ~66k filas de 200k; un índice B-tree sin condición parcial no mejora el plan y solo añade costo de mantenimiento. Si se necesitara, debería ser parcial `WHERE forma_pago = 'TARJETA'` pero aun así el beneficio es marginal y se solapa con el índice compuesto (fecha, forma_pago) ya aceptado.

2. `producto(activo)`: boolean con 2 valores, todos TRUE en la carga masiva (50k filas activas). Índice sobre boolean sin WHERE es inútil: Seq Scan es más barato. La alternativa correcta ya aceptada es el índice parcial `WHERE activo = TRUE` sobre (categoria_id, precio).

3. `cliente(email)`: redundante. Ya existe UNIQUE constraint `cliente_email_key` que crea un índice B-tree único sobre email. Crear otro índice idéntico duplicaría almacenamiento y costo de escritura sin beneficio.

Criterio aplicado: no indexar columnas de baja cardinalidad sin condición parcial, y no duplicar índices que ya existen por constraints. La decisión se documenta en informe_mediciones.md y en DUIA.

Propuesta recibida de OpenCode el 2026-09-14, rechazada tras lectura línea por línea y verificación de `pg_indexes` y `EXPLAIN`.
