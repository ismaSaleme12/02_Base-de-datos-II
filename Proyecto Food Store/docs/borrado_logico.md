# Borrado Lógico (Soft Delete) — Food Store — Impacto en Consultas e Índices

**Esquema DDL:** `db/schema_tp1.sql:27,35` | **Vistas:** `db/views.sql:14,36,57` | **Índices:** `db/indices.sql:39` | **Procedimientos:** `db/procedimientos.sql:sp_soft_delete_producto` | **Rúbrica Pt.9**

## 1. Definición y Mapeo al Enunciado

| Enunciado (rúbrica) | Implementación real | Justificación |
|---|---|---|
| `usuario.eliminado BOOLEAN` / `pedido.estado` / `producto.eliminado` | `categoria.activo BOOLEAN DEFAULT true` `db/schema_tp1.sql:27` + `producto.activo BOOLEAN DEFAULT true` `db/schema_tp1.sql:35` | Adaptación documentada `Proyecto Food Store/README.md:138`: `usuario → cliente`, `eliminado/estado → activo`. Semántica idéntica: `activo=TRUE` = vigente, `activo=FALSE` = borrado lógico. No se usa `deleted_at TIMESTAMPTZ` para simplicidad y porque `BOOLEAN` permite índice parcial eficiente. |

**Invariante:** Nunca se hace `DELETE FROM producto/categoria` físico; se hace `UPDATE producto SET activo=FALSE` (`db/procedimientos.sql:sp_soft_delete_producto` / `db/trigger_transicion.sql` no interfiere).

## 2. Operaciones de Borrado Lógico

```sql
-- Soft delete (borrado lógico):
CALL sp_soft_delete_producto(10);  -- db/procedimientos.sql:26
-- Equivale a: UPDATE producto SET activo=FALSE WHERE id=10 AND activo=TRUE;

-- Verificación en tabla base (sigue existiendo, pero marcado):
SELECT id, nombre, activo FROM producto WHERE id=10;
-- id | nombre      | activo
-- 10 | Producto 10 | f

-- Restaurar (undo):
CALL sp_restaurar_producto(10); -- UPDATE activo=TRUE

-- Listar borrados (para auditoría):
SELECT id, nombre, precio FROM producto WHERE activo=FALSE ORDER BY id;

-- Borrado físico bloqueado por FK RESTRICT + R1:
DELETE FROM producto WHERE id=10; -- ERROR si tiene detalle_pedido (RESTRICT) o si se intenta borrar categoría con productos
```

## 3. Impacto Correcto sobre Consultas

**Principio:** Toda consulta de catálogo/reportes **debe filtrar `activo=TRUE`**; consultas de auditoría/contabilidad pueden omitir filtro para ver históricos.

| Consulta | Sin filtro (incorrecto) | Con soft delete (correcto) | Evidencia |
|---|---|---|---|
| **Catálogo vigente** | `SELECT * FROM producto;` — devuelve 50k incluyendo borrados | `SELECT * FROM v_productos_vigentes_con_categoria;` `db/views.sql:14` — `WHERE p.activo=TRUE AND c.activo=TRUE` → solo vigentes | `docs/informe_mediciones.md:196` |
| **Pedidos con cliente** | Expone `email/telefono` sin filtrar | `v_pedidos_con_cliente` `db/views.sql:36` oculta sensibles; pedidos de clientes vigentes (no hay soft delete en cliente en este esquema) | `specs/spec_vista_pedidos_con_cliente.md` |
| **Detalle con producto** | `JOIN producto` sin filtro trae productos borrados | `v_detalle_pedido_con_producto` `db/views.sql:57` hace `JOIN producto pr ON dp.producto_id=pr.id` — si se quiere excluir borrados, añadir `WHERE pr.activo=TRUE` en consulta consumidora | Adaptable |
| **Agregación precio promedio** | `AVG(p.precio)` incluye borrados (sesga) | `WHERE c.activo=TRUE AND p.activo=TRUE GROUP BY ... HAVING AVG>1000` `db/consultas_parte4 - Tp3.sql:29` — promedio solo vigentes | Correcto Pt.9 |
| **Ranking ventana** | `SUM` incluye productos borrados si se hace historic | `FROM producto p WHERE p.activo=TRUE AND p.precio > (SELECT AVG...)` `db/consultas_parte3_semana4.sql:114` — filtra borrados | Correcto |

**Anomalía si no se filtra:** Reporte `vm_facturacion_categoria_mes` `db/views.sql:80` incluye **histórico** (todos los `detalle_pedido` ya vendidos, aunque luego el producto se desactive) — es **correcto** no filtrar `activo` allí: facturación pasada no se reescribe por soft delete posterior. Para catálogo futuro sí se filtra.

## 4. Impacto sobre Índices

| Índice | Definición | Impacto soft delete |
|---|---|---|
| `idx_producto_categoria_precio_activo` | `CREATE INDEX ... ON producto(categoria_id, precio) WHERE activo=TRUE` `db/indices.sql:39` | **Índice parcial:** solo indexa filas vigentes. Tras soft delete (`activo=FALSE`), la fila se **elimina del índice** automáticamente (no ocupa espacio, no se escanea). Mide: `SELECT pg_size_pretty(pg_relation_size('idx_producto_categoria_precio_activo'))` antes/después de `CALL sp_soft_delete_producto(10)` — tamaño se mantiene o baja. Sin `WHERE`, un índice sobre `activo` boolean (2 valores) sería inútil — ver descarte `specs/spec_indice_descartado_forma_pago.md:15`. |
| `index_producto_categoria` | `ON producto(categoria_id)` `db/schema_tp1.sql:105` | Indexa todos (vigentes + borrados); no distingue. Se mantiene por FK pero el parcial es preferido para catálogo. |
| `idx_pedido_fecha_forma_pago` | `ON pedido(fecha, forma_pago)` | Pedido no tiene `activo`; no aplica soft delete (pedido es histórico, no se borra lógico). Si se agregara `pedido.eliminado`, se crearía parcial `WHERE NOT eliminado`. |

**Medición sugerida para informe:**

```sql
-- Tamaño índice parcial antes:
SELECT pg_size_pretty(pg_relation_size('idx_producto_categoria_precio_activo')); -- ej. 1360 kB
-- Soft delete 1000 productos:
UPDATE producto SET activo=FALSE WHERE id BETWEEN 1 AND 1000;
-- Tamaño después (debe bajar o mantenerse, no subir):
SELECT pg_size_pretty(pg_relation_size('idx_producto_categoria_precio_activo')); -- ej. 1328 kB
-- Plan usa índice parcial:
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM v_productos_vigentes_con_categoria WHERE categoria_id=1 AND precio>2000;
-- Buffers hit mucho menor que Seq Scan
-- Restaurar:
UPDATE producto SET activo=TRUE WHERE id BETWEEN 1 AND 1000;
```

`[Insertar captura pg_relation_size ANTES/DESPUÉS + EXPLAIN usando índice parcial aquí]`

## 5. Integridad con Triggers

- **R1** `trg_check_producto_activo` `db/reglas_integridad.sql:39` impide `INSERT detalle_pedido` con `producto.activo=FALSE` — coherente con soft delete: no se puede vender producto borrado.
- **R2** no aplica a soft delete de producto (solo a pedido sin detalle).

**Prueba integrada para informe:**

```sql
BEGIN;
CALL sp_soft_delete_producto(5); -- borra lógico
-- Intentar vender producto borrado:
INSERT INTO detalle_pedido(pedido_id, producto_id, cantidad, precio_unitario) VALUES (1, 5, 1, 1000);
-- ERROR: Operación rechazada: El producto ID 5 se encuentra inactivo (R1)
ROLLBACK;

-- Ver que catálogo ya no lo lista:
CALL sp_soft_delete_producto(5);
SELECT * FROM v_productos_vigentes_con_categoria WHERE producto_id=5; -- 0 filas
SELECT * FROM producto WHERE id=5; -- activo=f, sigue en base (soft)
ROLLBACK; -- o CALL sp_restaurar_producto(5) para deshacer
```

`[Insertar captura R1 bloqueando venta de producto con soft delete aquí]`

---
*Esta documentación cierra Pt.9 rúbrica — Coherente con DDL `activo` y demuestra impacto en vistas e índices parciales — Ver también `db/procedimientos.sql`*
