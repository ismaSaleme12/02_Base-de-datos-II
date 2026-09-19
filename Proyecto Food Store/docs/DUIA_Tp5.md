# DECLARACIÓN DE USO DE INTELIGENCIA ARTIFICIAL (DUIA) — TP Unidad 3 Semana 5

## 1. Información General

- **Trabajo Práctico:** Unidad 3 — Semana 5 — Índices, vistas y vistas materializadas en Food Store
- **Alumno:** Saleme Ismael
- **Asignatura:** Base de Datos II (UTN - TUP a Distancia)
- **Herramientas de IA:** Kiro (especificación) y OpenCode (agente de codificación en terminal / Muse Spark)
- **Motor:** PostgreSQL 18.6 (Food_Store_Copia) — DBeaver 24 + psql
- **Fecha:** 2026-09-14

---

## 2. Registro de Uso por Pieza (flujo obligatorio Kiro → OpenCode → verificación)

### Parte A — Plan de indexado

#### A1. Índice pedido(fecha, forma_pago)
- **Herramienta:** Kiro para spec, OpenCode para generación
- **Prompt / Spec entregado (tal cual):**
  > `# spec: indice_pedido_fecha_forma_pago` — Objetivo: acelerar reporte "pedidos confirmados de un mes". Consulta: `SELECT id, fecha, total FROM pedido WHERE fecha BETWEEN :desde AND :hasta AND estado='CONFIRMADO' AND eliminado=FALSE;` Adaptado a esquema real: `WHERE fecha BETWEEN :desde AND :hasta AND forma_pago='TARJETA'`. Columnas: fecha (alta selectividad), forma_pago (baja). Criterio: plan pasa de Seq Scan a Index/Bitmap Scan y tiempo baja al menos 10×.
- **Qué propuso la IA:** `CREATE INDEX idx_pedido_fecha_forma_pago ON pedido(fecha, forma_pago);` y variante `CREATE INDEX idx_pedido_fecha ON pedido(fecha);`
- **Qué se aceptó / modificó:** Se aceptó el compuesto (fecha, forma_pago) por cubrir filtro combinado + ORDER BY fecha DESC. Se descartó el de una sola columna por ser menos selectivo.
- **Verificación:** EXPLAIN antes: Parallel Seq Scan 33.38 ms → después: Index Scan Backward 0.034 ms. Se ejecutó en `BEGIN; CREATE INDEX; EXPLAIN; ROLLBACK;` y luego confirmado en `indices.sql`.

#### A2. Índice producto(categoria_id, precio) WHERE activo
- **Herramienta:** Kiro → OpenCode
- **Spec entregado:** spec_indice_producto_categoria_precio.md — acelerar "productos vigentes de Bebidas con precio > 2000", columnas categoria_id, precio, activo (boolean). Se pidió índice parcial.
- **Qué propuso la IA:** `CREATE INDEX idx_producto_categoria_precio ON producto(categoria_id, precio);` y `CREATE INDEX idx_producto_activo ON producto(activo);`
- **Qué se aceptó / modificó:** Se aceptó el compuesto parcial `WHERE activo=TRUE` y se **descartó** `idx_producto_activo` por sobreindexación (boolean baja cardinalidad, ver Parte A6). Se ajustó orden a (categoria_id, precio) para cubrir `WHERE categoria_id=? AND precio > ?`.
- **Verificación:** 3.75 ms → 2.11 ms (-44%). Verificado con `EXPLAIN (ANALYZE, BUFFERS)`. Sin regresión en otros planes.

#### A3. Índice detalle_pedido(producto_id)
- **Herramienta:** Kiro → OpenCode
- **Spec entregado:** spec_indice_detalle_pedido_producto.md — acelerar joins detalle→producto para reportes de recaudación.
- **Qué propuso la IA:** `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(producto_id);` y `CREATE INDEX idx_detalle_pedido_pedido_producto ON detalle_pedido(pedido_id, producto_id);` (este último redundante con PK)
- **Qué se aceptó / modificó:** Se aceptó el simple sobre producto_id; se descartó el compuesto (pedido_id, producto_id) por ser redundante con la PK existente `detalle_pedido_pkey (pedido_id, producto_id)`.
- **Verificación:** Agregación total 152 ms → 95 ms (-38%) por estadísticas; en filtrado por categoría pasa de Seq Scan 1471 pages a Bitmap Heap 47 pages. Medido con 5 repeticiones.

#### A4. Índice descartado por sobreindexación (bitácora mínima obligatoria)
- **Herramienta:** OpenCode
- **Prompt / Spec:** se pidió a la IA "propón índices adicionales para optimizar todas las queries de queries.sql sin restricción"
- **Qué propuso la IA:** `CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago);` + `idx_producto_activo ON producto(activo);` + `idx_cliente_email ON cliente(email);`
- **Qué se descartó y por qué:**
  - `idx_pedido_forma_pago`: enum 3 valores, 66k filas por valor → Seq Scan siempre más barato, índice nunca usado, solo costo de escritura y 4 MB. Se solapa con el compuesto ya aceptado.
  - `idx_producto_activo`: boolean 2 valores, todos TRUE → inútil sin parcial.
  - `idx_cliente_email`: redundante con `UNIQUE constraint cliente_email_key` que ya crea índice btree.
- **Justificación técnica:** cardinalidad < 4 valores → índice B-tree no selectivo sin WHERE parcial; no duplicar índices de constraints. Documentado en `specs/spec_indice_descartado_forma_pago.md` e `informe_mediciones.md`. Decisión humana, no delegada.

#### A5. Costo de escritura
- **Herramienta:** OpenCode sugirió "medir INSERT masivo antes y después con EXPLAIN ANALYZE"
- **Qué se hizo:** se ejecutó `INSERT INTO detalle_pedido SELECT ... 500 filas` antes (66.3 ms) y después (71.8 ms promedio). La IA estimó +5-10% y la medición confirmó +8.3%, aceptable frente a ganancias de lectura 44%–981×.

### Parte B — Vistas

#### B1. v_productos_vigentes_con_categoria
- **Herramienta:** Kiro (spec_vista_productos_vigentes.md) → OpenCode
- **Spec entregado:** columnas producto_id, producto_nombre, precio, stock, categoria_id, categoria_nombre; filtro producto.activo=TRUE AND categoria.activo=TRUE; sin columna sensible a ocultar.
- **Qué propuso la IA:** `CREATE VIEW v_productos_vigentes_con_categoria AS SELECT p.id, p.nombre, p.precio ... FROM producto p JOIN categoria c ON ... WHERE p.activo AND c.activo;`
- **Qué se aceptó / modificó:** Se aceptó tal cual; se agregó `COMMENT ON VIEW` y `CREATE OR REPLACE VIEW` para idempotencia.
- **Verificación de equivalencia (mínimo obligatorio):** `SELECT * FROM vista EXCEPT SELECT manual` y viceversa = 0 filas. Ejecutado en DBeaver, capturas en informe.

#### B2. v_pedidos_con_cliente (segura)
- **Herramienta:** Kiro → OpenCode
- **Spec entregado:** exponer pedido_id, fecha, forma_pago, cliente_id, cliente_nombre; ocultar por seguridad columna contraseña (enunciado) → en esquema real sin columna contraseña se oculta email/telefono como dato sensible.
- **Qué propuso la IA:** primero propuso exponer todo `SELECT p.*, c.*` (se rechazó por exponer email/telefono).
- **Qué se aceptó / modificó:** Se corrigió manualmente para exponer solo columnas no sensibles (`CREATE VIEW v_pedidos_con_cliente AS SELECT p.id, p.fecha, p.forma_pago, c.id, c.nombre FROM pedido p JOIN cliente c ...`).
- **Verificación:** equivalencia con consulta manual sin email/telefono = 0 filas en ambos sentidos. Se documenta que `GRANT SELECT ON vista` permite acceso sin `GRANT` sobre `cliente` base.

#### B3. v_detalle_pedido_con_producto
- **Herramienta:** Kiro → OpenCode
- **Spec entregado:** pedido_id, producto_id, producto_nombre, categoria_nombre, cantidad, precio_unitario, subtotal (cantidad*precio).
- **Qué propuso la IA:** `CREATE VIEW v_detalle_pedido_con_producto AS SELECT dp.pedido_id, dp.producto_id, pr.nombre, cat.nombre, dp.cantidad, dp.precio_unitario, dp.cantidad*dp.precio_unitario AS subtotal FROM detalle_pedido dp JOIN producto pr ... JOIN categoria cat ...`
- **Qué se aceptó:** se aceptó; se verificó equivalencia con `EXCEPT` 0 filas.

### Parte C — Vista materializada

#### C1. vm_facturacion_categoria_mes
- **Herramienta:** Kiro → OpenCode
- **Spec entregado:** spec_vista_materializada_facturacion.md — reporte costoso facturación por categoría y mes (`SUM(cantidad*precio) GROUP BY c.nombre, to_char(fecha)`), 523 ms, temp files. Pedir `WITH DATA` + índice único para `REFRESH CONCURRENTLY`.
- **Qué propuso la IA:** `CREATE MATERIALIZED VIEW vm_facturacion_categoria_mes AS ... WITH DATA; CREATE UNIQUE INDEX ON (categoria, mes);`
- **Qué se aceptó / modificó:** Se aceptó; se ajustó `to_char(p.fecha,'YYYY-MM')` como mes y se agregó `COUNT(DISTINCT p.id)`. Se creó índice único `(categoria, mes)` exactamente como propuso la IA.
- **Qué se descartó:** propuesta inicial de `REFRESH` sin `CONCURRENTLY` (bloqueante) se documentó pero se prefirió `CONCURRENTLY` para no bloquear dashboard.
- **Verificación:** `EXPLAIN (ANALYZE) SELECT * FROM vm` 0.82 ms vs 523 ms original (637×). `REFRESH MATERIALIZED VIEW CONCURRENTLY` 412 ms sin bloquear SELECT concurrentes. Equivalencia con `EXCEPT` 0 filas. Frecuencia de refresco documentada: diaria 00:05 o cada 6h; implica staleness 6-24h aceptable para histórico mensual.

---

## 3. Conclusión sobre el uso de la IA

Kiro y OpenCode actuaron como motor primario para redactar specs y generar SQL, pero **la decisión nunca se delegó**: cada índice, vista y materializada fue leído línea por línea, probado en `BEGIN;...ROLLBACK;` sobre `Food_Store_Copia` y medido con `EXPLAIN ANALYZE` antes de aceptarlo. Se descartó explícitamente la sobreindexación propuesta por la IA y se corrigió la vista que exponía datos sensibles. Las equivalencias con `EXCEPT` y las mediciones de tiempo son la evidencia que sostiene la defensa oral.

## 4. Trazabilidad Git

Flujo Git exigido: cada pieza en commits separados y descriptivos.

Commits realizados (ver `git log --oneline`):
- `spec: indice pedido(fecha, forma_pago) — Kiro spec`
- `feat(indices): idx_pedido_fecha_forma_pago — Seq Scan 33ms→Index Scan 0.03ms`
- `feat(indices): idx_producto_categoria_precio parcial — catálogo vigente`
- `feat(indices): idx_detalle_pedido_producto — optimiza joins de recaudación`
- `docs: índice descartado forma_pago — justifica sobreindexación`
- `feat(views): v_productos_vigentes_con_categoria + verificación EXCEPT`
- `feat(views): v_pedidos_con_cliente segura sin email/telefono`
- `feat(views): v_detalle_pedido_con_producto`
- `feat(materialized): vm_facturacion_categoria_mes + índice único + REFRESH CONCURRENTLY`
- `docs: informe_mediciones con EXPLAIN antes/después y costo escritura`
- `docs: duia bitácora Kiro/OpenCode`

Cada commit es mostrable con `git show` en la defensa oral.

