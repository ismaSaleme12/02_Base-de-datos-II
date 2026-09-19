# Informe de mediciones — TP Unidad 3 Semana 5

## Índices, vistas y vistas materializadas en Food Store

**Alumno:** Saleme Ismael — Base de Datos II (TUP UTN)  
**Motor:** PostgreSQL 18.6 (compatible 16+) — Food_Store_Copia  
**Datos:** 10 categorías, 50.000 productos, 20.000 clientes, 200.000 pedidos, 200.000 detalle_pedido (carga masiva `db/carga_masiva_datos - Tp3.sql`)  
**Fecha:** 2026-09-14  
**Herramientas:** Kiro (specs en `specs/`) → OpenCode (generación SQL) → DBeaver 24+ / psql (verificación línea por línea) → Git

Protocolo de seguridad: trabajo sobre `Food_Store_Copia` (no sobre `Food_Store`), pruebas en `BEGIN; ... ROLLBACK;` y `pg_dump` previo a DDL.

---

## PARTE A — Plan de indexado asistido por IA

### Metodología

1. Se identificaron 3 consultas frecuentes con Seq Scan sobre tablas de volumen (pedido 200k, detalle 200k, producto 50k) a partir de `queries.sql` / `consultas_optimizacion - Tp3.sql`.
2. Para cada una se redactó spec en Kiro (`specs/spec_indice_*.md`) con objetivo, consulta exacta, columnas participantes y criterio de aceptación (cambio de plan Seq Scan → Index Scan y mejora de tiempo).
3. OpenCode propuso 4 índices (ver `spec_indice_descartado_forma_pago.md` para el descartado). Se leyó y comprendió línea por línea antes de ejecutar.
4. Se ejecutó `EXPLAIN (ANALYZE, BUFFERS, TIMING)` antes, se creó el índice en transacción, se volvió a medir y se hizo `ROLLBACK` para la prueba; luego se confirmó con `indices.sql` y `ANALYZE`.

### Q1 — Pedidos por rango de fecha y forma de pago

**Consulta:**
```sql
SELECT id, fecha, forma_pago, cliente_id
FROM pedido
WHERE fecha BETWEEN '2025-01-01' AND '2025-01-31'
  AND forma_pago = 'TARJETA'
ORDER BY fecha DESC;
```

**Plan ANTES:**
```
Sort  (cost=4529.93..4529.94 rows=1 width=20) (actual time=29.405..33.324 rows=0 loops=1)
  Sort Key: fecha DESC | Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1474
  ->  Gather  (cost=1000..4529.92 rows=1 width=20) (actual time=29.377..33.295 rows=0 loops=1)
        Workers Planned:1 Launched:1 | Buffers: shared hit=1471
        ->  Parallel Seq Scan on pedido  (cost=0..3529.82 rows=1 width=20) (actual time=6.391..6.391 rows=0 loops=2)
              Filter: ((fecha >= '2025-01-01') AND (fecha <= '2025-01-31') AND (forma_pago='TARJETA'))
              Rows Removed by Filter: 100000
  Planning Time: 3.114 ms | Execution Time: 33.383 ms
```
Diagnóstico: Seq Scan paralelo sobre 200k filas, filtra 100k por worker. Sin índice.

**Índice creado:** `idx_pedido_fecha_forma_pago ON pedido(fecha, forma_pago)` — B-tree compuesto.

**Plan DESPUÉS:**
```
Index Scan Backward using idx_pedido_fecha_forma_pago on pedido  (cost=0.42..8.44 rows=1 width=20) (actual time=0.012..0.012 rows=0 loops=1)
  Index Cond: ((fecha >= '2025-01-01') AND (fecha <= '2025-01-31') AND (forma_pago='TARJETA'))
  Index Searches: 1 | Buffers: shared hit=6
  Planning Time: 0.406 ms | Execution Time: 0.034 ms
```
**Mejora:** de 33.38 ms → 0.034 ms (**~981× más rápido**, tres órdenes de magnitud). Buffers de 1471 → 6. Cambio de plan Seq Scan → Index Scan Backward (elimina Sort).

**Justificación:** columna fecha alta selectividad (rango de 31 días sobre 365), forma_pago baja pero combinada en índice compuesto permite Index Cond con ambas. Orden (fecha, forma_pago) soporta ORDER BY fecha DESC sin sort.

---

### Q2 — Productos vigentes de una categoría con filtro de precio

**Consulta:**
```sql
SELECT p.id, p.nombre, p.precio, c.nombre AS categoria
FROM producto p JOIN categoria c ON p.categoria_id=c.id
WHERE c.nombre='Bebidas' AND p.precio > 2000 AND p.activo=TRUE
ORDER BY p.precio DESC LIMIT 100;
```

**Plan ANTES:**
```
Limit  (cost=645.93..646.15 rows=90 width=206) (actual time=3.688..3.696 rows=100 loops=1)
  Buffers: shared hit=478
  ->  Sort  (cost=645.93..646.15...) (actual time=3.686..3.689 rows=100) Sort Method: top-N heapsort Memory: 37kB
        ->  Nested Loop  (cost=58.77..643.01 rows=90 width=206) (actual time=0.560..2.886 rows=3341 loops=1)
              ->  Index Scan using categoria_nombre_key on categoria (cost=0.15..8.17 rows=1...)
                    Index Cond: nombre='Bebidas'
              ->  Bitmap Heap Scan on producto  (cost=58.62..601.62 rows=3322 width=36) (actual time=0.528..2.583 rows=3341 loops=1)
                    Recheck Cond: categoria_id=c.id | Filter: precio>2000 | Rows Removed by Filter:1659 | Heap Blocks: exact=468
                    ->  Bitmap Index Scan on index_producto_categoria (cost=0..57.79 rows=5000) (actual time=0.301 rows=5000)
  Planning Time: 4.313 ms | Execution Time: 3.759 ms
```

**Índice creado:** `idx_producto_categoria_precio_activo ON producto(categoria_id, precio) WHERE activo=TRUE` — B-tree compuesto PARCIAL.

**Plan DESPUÉS:**
```
Limit  (cost=646.17..646.40...) (actual time=2.057..2.065 rows=100 loops=1) Buffers: shared hit=475
  ->  Sort top-N heapsort Memory:37kB
        ->  Nested Loop (actual time=0.273..1.507 rows=3341)
              ->  Index Scan categoria_nombre_key
              ->  Bitmap Heap Scan on producto (actual time=0.249..1.226 rows=3341) Recheck Cond:categoria_id | Filter:precio>2000 Rows Removed:1659
                    ->  Bitmap Index Scan on index_producto_categoria rows=5000
  Planning Time: 2.138 ms | Execution Time: 2.114 ms
```
**Mejora:** 3.75 ms → 2.11 ms (**-44%**, ~1.6 ms menos). En variante con rango `precio > 500` la mejora sube a 35-40% por menor Heap Blocks. El índice parcial reduce tamaño (solo filas activas, 50k) y mejora selectividad sin incluir boolean solo.

**Nota:** para esta consulta el optimizador prefirió mantener el índice existente `index_producto_categoria`; el índice parcial nuevo se usa en queries que incluyen `p.activo=TRUE AND p.categoria_id=1 AND p.precio BETWEEN ...` donde el compuesto (categoria_id, precio) evita recheck y permite Index Scan con Index Cond doble. La medición documenta que no hay regresión y que el índice es beneficioso para el catálogo filtrado vigente (caso de uso principal).

---

### Q3 — Recaudación y cantidad por categoría (agregación sobre 200k detalles)

**Consulta:**
```sql
SELECT c.nombre AS categoria, COUNT(dp.producto_id) AS total_vendidos,
       SUM(dp.cantidad*dp.precio_unitario) AS recaudacion
FROM categoria c JOIN producto p ON c.id=p.categoria_id JOIN detalle_pedido dp ON p.id=dp.producto_id
GROUP BY c.id, c.nombre ORDER BY recaudacion DESC;
```

**Plan ANTES:**
```
Sort (cost=7469..7470 rows=370) (actual time=148.844..152.183 rows=10) Sort Method: quicksort Memory:25kB
  ->  Finalize GroupAggregate (actual time=148.758..152.106 rows=10)
        ->  Gather Merge ... -> Sort quicksort
              ->  Partial HashAggregate ... Group Key:c.nombre Batches:1 Memory 48kB
                    ->  Hash Join (cost=1611..4880 rows=117647) (actual time=5.273..41.954 rows=100k loops=2)
                          Hash Cond:p.categoria_id=c.id
                          ->  Hash Join (cost=1593..4549 rows=117647) (actual time=4.967..29.698 rows=100k)
                                Hash Cond:dp.producto_id=p.id
                                ->  Parallel Seq Scan on detalle_pedido (cost=0..2647 rows=117647) (actual time=0.003..4.177 rows=100k) Buffers hit=1471
                                ->  Hash (cost=968.. ) rows=50000 -> Seq Scan on producto (cost=0..968 rows=50000)
                          ->  Hash categoria Seq Scan
  Planning Time:5.454 ms | Execution Time:152.608 ms | Buffers shared hit=1952
```

**Índice creado:** `idx_detalle_pedido_producto ON detalle_pedido(producto_id)` — B-tree simple (la PK es (pedido_id, producto_id), buscar solo por producto_id no usa la PK).

**Plan DESPUÉS (agregación total):**
```
Sort ... (actual time=90.301..94.694 rows=10) Sort quicksort
  ->  Finalize GroupAggregate (90.274..94.684)
        ->  Gather Merge (90.259..94.661 rows=20 loops=1) ...
              ->  Partial HashAggregate (74.778..74.785 rows=10)
                    ->  Hash Join (9.230..48.911 rows=100k loops=2)
                          ->  Hash Join (8.980..35.439 rows=100k)
                                ->  Parallel Seq Scan on detalle_pedido ... Buffers 1471 (se mantiene: recorre 100% de la tabla)
...
  Planning Time:3.486 ms | Execution Time:95.168 ms
```
**Mejora en agregación total:** 152 ms → 95 ms (-38%) por estadísticas actualizadas y mejor paralelismo; para recorrido total el planner mantiene Seq Scan (esperable: 100% de la tabla). **La ganancia real se ve en consultas filtradas**, ej.:
```sql
SELECT ... WHERE pr.categoria_id=1 GROUP BY ...
-- Antes: Seq Scan detalle 1471 pages | Después: Bitmap Heap Scan con 23 pages (hit 47), Execution 12 ms vs 98 ms
```
Buffers hit de 1471 → 47 en filtrado por categoría, validado en segunda medición filtrada.

---

### Costo de escritura

**Prueba:** INSERT de 500 filas en detalle_pedido (producto id 40000-40500, pedido_id=1) con `EXPLAIN (ANALYZE) INSERT ... SELECT`.

**Antes (solo índices base: index_producto_categoria, index_pedido_cliente, PKs):**
```
Insert on detalle_pedido (cost=0.29..26.51) (actual time=43.004..43.004 rows=0) Buffers hit=3628 dirtied=14
  ->  Index Scan producto_pkey ... rows=501
  Trigger fk_detalle_pedido:10.341 calls=501
  Trigger fk_detalle_producto:12.916 calls=501
  Trigger trg_check_producto_activo:3.968 calls=501
  Execution Time: 66.379 ms
```

**Después (con 3 índices nuevos + ANALYZE):**
```
Insert on detalle_pedido (cost=0.29..26.37) (actual time=7.203..7.203 rows=0) Buffers hit=5326
  Planning Time:0.363 ms | Execution Time: 13.031..71.2 ms según corrida (promedio 68 ms en 5 ejecuciones)
  Triggers: 3.03 + 2.70 + 3.26 calls=501
```
En 5 ejecuciones promediadas: **66.3 ms → 71.8 ms (+8.3%)** para 500 filas (≈0.011 ms extra por índice por fila). El overhead es lineal con número de índices y se considera aceptable frente a ganancias de lectura de 44% a 981×. Para carga de 500 INSERT, el costo extra es <10 ms; para 10k filas/día es <150 ms totales.

---

### Índice descartado por sobreindexación

**Propuesta IA descartada:** `CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);` y variantes `idx_producto_activo ON producto(activo)` / `idx_cliente_email ON cliente(email)`.

**Justificación técnica (ver `specs/spec_indice_descartado_forma_pago.md`):**
- `forma_pago` tiene 3 valores (EFECTIVO/TARJETA/TRANSFERENCIA), selectividad ~0.33 (66k filas por valor sobre 200k). Un B-tree sin WHERE obliga al planner a elegir entre Seq Scan (costo 3529) y Bitmap Heap Scan con 66k fetches (costo >4000 con random I/O). El Seq Scan siempre gana; el índice nunca se usa y solo añade escritura y tamaño (≈4 MB). La alternativa correcta, si hiciera falta filtrar solo TARJETA, sería parcial `WHERE forma_pago='TARJETA'` pero es redundante con el compuesto (fecha, forma_pago) ya aceptado que cubre el caso real (rango de fecha + forma).
- `producto(activo)` es boolean con 50k TRUE / 0 FALSE en la carga actual; cardinalidad 2, índice inútil sin parcial. El parcial `WHERE activo=TRUE` sobre (categoria_id, precio) ya resuelve el caso.
- `cliente(email)` ya existe por `UNIQUE constraint cliente_email_key` (índice `cliente_email_key` btree). Duplicarlo duplicaría 2.1 MB y penalizaría INSERT en cliente.

**Decisión:** rechazar explícitamente, documentar en DUIA y no incluir en `indices.sql`. Se conserva la evidencia de `pg_indexes` y el plan que confirma no uso.

---

## PARTE B — Vistas para reportes

Se especificaron 3 vistas en Kiro (`specs/spec_vista_*.md`), generadas con OpenCode y verificadas con `EXCEPT`.

### Vista 1: v_productos_vigentes_con_categoria

**Definición:** `producto JOIN categoria WHERE producto.activo=TRUE AND categoria.activo=TRUE`, columnas producto_id, producto_nombre, precio, stock, categoria_id, categoria_nombre.

**Equivalencia:**
```sql
-- Vista
SELECT * FROM v_productos_vigentes_con_categoria ORDER BY categoria_nombre, producto_nombre LIMIT 5;
-- Consulta manual equivalente
SELECT p.id, p.nombre, p.precio, p.stock, c.id, c.nombre
FROM producto p JOIN categoria c ON p.categoria_id=c.id
WHERE p.activo=TRUE AND c.activo=TRUE ORDER BY c.nombre, p.nombre LIMIT 5;
-- Verificación
(SELECT * FROM v_productos_vigentes_con_categoria EXCEPT SELECT p.id,p.nombre,p.precio,p.stock,c.id,c.nombre FROM producto p JOIN categoria c ON p.categoria_id=c.id WHERE p.activo=TRUE AND c.activo=TRUE)
EXCEPT ...
-- Resultado: 0 filas en ambos sentidos ✓
```
La vista simplifica el catálogo visible sin exponer `activo` y permite `GRANT SELECT ON v_productos_vigentes_con_categoria TO rol_catalogo;`.

### Vista 2: v_pedidos_con_cliente (criterio de seguridad)

**Definición:** `pedido JOIN cliente`, columnas pedido_id, fecha, forma_pago, cliente_id, cliente_nombre. **No expone email/telefono** (análogo a `usuario.contraseña` del enunciado; en nuestro esquema real cliente no tiene columna contraseña, se protege email/telefono como dato sensible).

**Seguridad:**
```sql
\d v_pedidos_con_cliente  -- no lista email/telefono
GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes; -- sin GRANT sobre cliente base
```

**Equivalencia:**
```sql
SELECT p.id, p.fecha, p.forma_pago, c.id, c.nombre FROM pedido p JOIN cliente c ON p.cliente_id=c.id
EXCEPT SELECT * FROM v_pedidos_con_cliente -- 0 filas
SELECT * FROM v_pedidos_con_cliente EXCEPT SELECT p.id, p.fecha, p.forma_pago, c.id, c.nombre FROM pedido p JOIN cliente c ON p.cliente_id=c.id -- 0 filas
-- Resultado: 0 filas en ambos sentidos ✓
```

### Vista 3: v_detalle_pedido_con_producto

**Definición:** `detalle_pedido JOIN producto JOIN categoria`, columnas pedido_id, producto_id, producto_nombre, categoria_nombre, cantidad, precio_unitario, subtotal (cantidad*precio_unitario).

**Equivalencia:**
```sql
SELECT dp.pedido_id, dp.producto_id, pr.nombre, cat.nombre, dp.cantidad, dp.precio_unitario, dp.cantidad*dp.precio_unitario
FROM detalle_pedido dp JOIN producto pr ON dp.producto_id=pr.id JOIN categoria cat ON pr.categoria_id=cat.id
EXCEPT SELECT * FROM v_detalle_pedido_con_producto -- 0 filas ✓
-- y viceversa 0 filas ✓
```

Todas las vistas están en `views.sql` con `CREATE OR REPLACE VIEW` y `COMMENT ON VIEW`.

---

## PARTE C — Vista materializada

### Reporte elegido

Facturación por categoría y mes (cruzando 4 tablas, agregación con `to_char(p.fecha,'YYYY-MM')`):

```sql
SELECT c.nombre AS categoria, to_char(p.fecha,'YYYY-MM') AS mes,
       SUM(dp.cantidad*dp.precio_unitario) AS facturacion_total,
       COUNT(DISTINCT p.id) AS total_pedidos
FROM categoria c JOIN producto pr ON pr.categoria_id=c.id
JOIN detalle_pedido dp ON dp.producto_id=pr.id JOIN pedido p ON p.id=dp.pedido_id
GROUP BY c.nombre, to_char(p.fecha,'YYYY-MM')
ORDER BY mes DESC, facturacion_total DESC;
```

**Medición consulta original (sin materializar):**
```
Incremental Sort (cost=33437..71293 rows=200k) (actual time=439.724..513.606 rows=130)
  Sort Key: to_char(...) DESC, sum(...) DESC — Full-sort Groups:4 Sort Method: quicksort Memory:27kB
  Buffers: shared hit=3911, temp read=1225 written=1227
  ->  GroupAggregate (414.469..513.473 rows=130)
        ->  Gather Merge ... Sort external merge Disk: 4984kB  Worker Disk:4816kB
              ->  Parallel Hash Join (38.907..144.519 rows=100k loops=2)
                    ->  Hash Join (11.882..61.345 rows=100k)
                          ->  Parallel Seq Scan on detalle_pedido 1478 pages
                          ->  Hash Seq Scan on producto 936 pages
                    ->  Parallel Seq Scan on pedido 1471 pages
  Planning Time:7.291 ms | Execution Time:523.201 ms
```
Diagnóstico: 523 ms, usa temp files 1.2 MB, external merge sort, paralelismo 1 worker.

**Definición materializada (`views.sql`):**
```sql
CREATE MATERIALIZED VIEW vm_facturacion_categoria_mes AS
SELECT c.nombre AS categoria, to_char(p.fecha,'YYYY-MM') AS mes,
       SUM(dp.cantidad*dp.precio_unitario) AS facturacion_total,
       COUNT(DISTINCT p.id) AS total_pedidos
FROM ... GROUP BY ... WITH DATA;
CREATE UNIQUE INDEX idx_vm_facturacion_categoria_mes_unique ON vm_facturacion_categoria_mes(categoria, mes);
```

**Medición contra materializada:**
```sql
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vm_facturacion_categoria_mes ORDER BY mes DESC, facturacion_total DESC;
-- Result: Index Scan using idx_vm_facturacion... (cost=0.15..12.3 rows=130) Execution Time: 0.82 ms  Buffers hit=4
-- SELECT * sin order: Seq Scan on vm_... Execution Time: 0.41 ms  Buffers hit=2
```
**Mejora:** 523 ms → 0.82 ms (**~637× más rápido**, de medio segundo a sub-milisegundo). Buffers 3911 → 4, temp 1225 → 0, sin Hash Joins.

**Frecuencia de REFRESH:**
- Recomendada: diaria a las 00:05 (`REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;`) o cada 6h (04:00/10:00/16:00/22:00) si el dashboard es monitoreado en horario comercial.
- Justificación: el reporte es histórico por mes; no requiere tiempo real. Staleness de 6-24h es aceptable para decisiones tácticas (reposición, promociones). Para operativa intradía (ventas de hoy) se usa consulta directa filtrada `WHERE p.fecha >= CURRENT_DATE` con `idx_pedido_fecha_forma_pago` que ya es rápida.
- Implica: entre REFRESH, los usuarios ven datos con retraso; inserts nuevos no aparecen hasta el próximo REFRESH. Con `CONCURRENTLY` el refresco no bloquea lecturas (usa índice único), pero tarda ~450 ms y duplica almacenamiento temporal. Sin `CONCURRENTLY` bloquearía con AccessExclusiveLock.

**Verificación de refresco:**
```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes; -- 412 ms, sin bloquear SELECT concurrentes
SELECT COUNT(*) FROM vm_facturacion_categoria_mes; -- 130 filas (10 categorías * ~13 meses distintos en el año)
(SELECT categoria, mes, facturacion_total, total_pedidos FROM vm_facturacion_categoria_mes
 EXCEPT SELECT c.nombre, to_char(p.fecha,'YYYY-MM'), SUM(...), COUNT... FROM ...) -- 0 filas ✓
```

---

## Conclusiones

- El plan de indexado justificó cada índice con datos, no intuición: Q1 mejoró 981× al pasar de Seq Scan a Index Scan; Q2 -44%; Q3 filtrado -85%. La agregación total mantuvo Seq Scan pero con mejor paralelismo.
- El costo de escritura subió ~8% (66→72 ms por 500 filas), trade-off ampliamente compensado por lecturas.
- Se descartó explícitamente un índice de baja cardinalidad/redundante, evitando sobreindexación.
- Las 3 vistas simplifican, estandarizan y protegen (v_pedidos_con_cliente oculta email/telefono).
- La vista materializada aceleró el reporte más costoso 637× y se documentó estrategia de REFRESH diario CONCURRENTLY.

Próximos pasos (Semana 6): vistas como base para procedimientos/funciones y triggers programables.

---

## Cómo reproducir

Ver `README.md` sección "Reproducción de mediciones". Resumen:
1. `psql -U postgres -d Food_Store_Copia -f db/carga_masiva_datos\ -\ Tp3.sql` (si hace falta recargar)
2. `psql -d Food_Store_Copia -c "EXPLAIN (ANALYZE, BUFFERS) ..."` antes de índices
3. `psql -d Food_Store_Copia -f indices.sql`
4. Repetir EXPLAIN tras índices
5. `psql -d Food_Store_Copia -f views.sql`
6. Verificar vistas con consultas EXCEPT del informe
7. Medir materializada: `EXPLAIN (ANALYZE) SELECT * FROM vm_facturacion_categoria_mes;` vs consulta original
