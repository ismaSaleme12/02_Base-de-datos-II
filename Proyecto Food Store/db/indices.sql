-- ============================================================
-- Script  : indices.sql
-- Base    : Food_Store_Copia (PostgreSQL 16+)
-- Autor   : Saleme Ismael — BD II U3 S5
-- Desc    : Plan de indexado justificado con EXPLAIN ANALYZE
--           3 índices aceptados + 1 descartado documentado
--           Todos los CREATE leídos línea por línea antes de ejecutar.
-- PRECOND : Protocolo de Seguridad: pg_dump previo + BEGIN; ROLLBACK; de prueba
--           Analizar estadísticas después de crear: ANALYZE tabla;
-- ============================================================

-- ============================================================
-- ÍNDICE 1: idx_pedido_fecha_forma_pago
-- Justifica: Consulta Q1 con Seq Scan sobre 200k filas
--   SELECT id, fecha, forma_pago FROM pedido
--   WHERE fecha BETWEEN :desde AND :hasta AND forma_pago = 'TARJETA'
-- Medición antes: Parallel Seq Scan, Filter Rows Removed 100k por worker, Execution Time ~33.38 ms
-- Medición después: Index Scan Backward using idx_pedido_fecha_forma_pago, Execution Time ~0.034 ms
-- Mejora: ~981x (de 33 ms a 0.03 ms), Buffers shared hit de 1471 a 6, pasa de Seq Scan a Index Scan
-- Tipo: B-tree compuesto (fecha, forma_pago) — orden soporta rango de fecha + igualdad en forma_pago
--           y ORDER BY fecha DESC via Index Scan Backward sin Sort.
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_pedido_fecha_forma_pago
ON pedido(fecha, forma_pago);

-- ============================================================
-- ÍNDICE 2: idx_producto_categoria_precio_activo (PARCIAL)
-- Justifica: Q2 catálogo "productos vigentes de Bebidas con precio > 2000"
--   SELECT p.id, p.nombre, p.precio FROM producto p JOIN categoria c ON ...
--   WHERE c.nombre='Bebidas' AND p.precio > 2000 AND p.activo=TRUE
-- Medición antes: Bitmap Heap Scan con 3341 rows, Rows Removed by Filter 1659, Execution Time ~3.75 ms
-- Medición después: plan se mantiene selectivo pero reduce Filter y Sort Method; con filtro activo=TRUE
--   el índice parcial reduce tamaño y mejora selectividad. Execution Time ~2.06 ms (-45%)
--   En variante con rango amplio (precio > 500) la mejora es mayor al evitar heap fetch de inactivos.
-- Tipo: B-tree compuesto PARCIAL WHERE activo = TRUE sobre (categoria_id, precio)
--   Parcial porque solo productos activos participan del catálogo visible.
--   Evita indexar boolean solo (baja cardinalidad) sin condición parcial.
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_producto_categoria_precio_activo
ON producto(categoria_id, precio)
WHERE activo = TRUE;

-- ============================================================
-- ÍNDICE 3: idx_detalle_pedido_producto
-- Justifica: Q3 agregación "recaudación por categoría" y joins detalle→producto
--   SELECT c.nombre, SUM(dp.cantidad*precio) FROM categoria c JOIN producto p ON ... JOIN detalle_pedido dp ON p.id=dp.producto_id GROUP BY c.nombre
--   La PK es (pedido_id, producto_id) — buscar por producto_id solo no usa la PK.
-- Medición antes: Parallel Seq Scan on detalle_pedido (1471 pages), Execution Time ~152.6 ms (Q3) y ~95 ms en variante
-- Medición después: Para agregación total sin filtro el optimizador aún prefiere Seq Scan (esperable: recorre 100% de la tabla).
--   La ganancia se observa en consultas filtradas por producto/categoría (ej. WHERE p.categoria_id=1): pasa de Seq Scan a Bitmap Heap Scan con Buffers hit de 1471 a <50.
-- Tipo: B-tree simple sobre detalle_pedido(producto_id)
-- Costo escritura: +5-10% en INSERT masivo (medido: 66 ms → 71 ms en 500 filas, dentro del umbral aceptable).
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_detalle_pedido_producto
ON detalle_pedido(producto_id);

-- Actualizar estadísticas del optimizador tras crear índices
ANALYZE pedido;
ANALYZE producto;
ANALYZE detalle_pedido;

-- ============================================================
-- ÍNDICE DESCARTADO (documentado, NO creado)
-- Propuesta IA: CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);
-- Motivo descarte: columna enum de 3 valores, baja cardinalidad ~33% por valor (~66k filas),
--   el planner hará Seq Scan igualmente; índice sin condición parcial solo añade costo de mantenimiento
--   y se solapa con el compuesto idx_pedido_fecha_forma_pago ya aceptado.
-- Alternativa correcta si hiciera falta: índice parcial WHERE forma_pago='TARJETA' pero se descartó por redundancia.
-- También descartado: idx_producto_activo ON producto(activo) — boolean sin parcial es inútil.
-- Y descartado: idx_cliente_email ON cliente(email) — redundante con UNIQUE constraint cliente_email_key que ya crea índice.
-- Ver informe_mediciones.md sección "Índice descartado por sobreindexación" y specs/spec_indice_descartado_forma_pago.md
-- ============================================================
