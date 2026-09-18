# Food Store — BD II U3 S5 — Índices, vistas y vistas materializadas

**Autor:** Saleme Ismael — TUP UTN  
**Motor:** PostgreSQL 16+ (probado en 18.6) — BD `Food_Store_Copia` (copia de `Food_Store`)

## Estructura del repositorio

```
Proyecto Food Store/
├── db/
│   ├── schema_tp1.sql                      # heredado, sin modificar (5 tablas)
│   ├── carga_masiva_datos - Tp3.sql        # heredado + ampliado (50k productos, 20k clientes, 200k pedidos)
│   ├── consultas_optimizacion - Tp3.sql    # carga de trabajo real a indexar
│   ├── reglas_integridad.sql               # triggers de integridad
│   └── ...
├── specs/                                  # especificaciones Kiro por pieza
│   ├── spec_indice_pedido_fecha_forma_pago.md
│   ├── spec_indice_producto_categoria_precio.md
│   ├── spec_indice_detalle_pedido_producto.md
│   ├── spec_indice_descartado_forma_pago.md
│   ├── spec_vista_productos_vigentes.md
│   ├── spec_vista_pedidos_con_cliente.md
│   ├── spec_vista_detalle_con_producto.md
│   └── spec_vista_materializada_facturacion.md
├── indices.sql                             # Parte A — 3 CREATE INDEX aceptados, comentados + descartado documentado
├── views.sql                               # Partes B y C — 3 vistas + 1 vista materializada + índice único
├── informe_mediciones.md                   # EXPLAIN ANALYZE antes/después, escritura, índice descartado
├── duia.md                                 # Bitácora Kiro/OpenCode (DUIA)
├── docs/
│   ├── DUIA_Tp4.md / DUIA_Tp3.md ...       # historial
│   └── informe_concurrencia.md             # modelo de informe seguido
├── Protocolo_Seguridad.md                  # trabajar sobre copia + BEGIN/ROLLBACK + pg_dump
└── README.md                               # este archivo
```

## Cómo reproducir las pruebas de esta entrega

### 0. Prerrequisitos

- PostgreSQL 16+ con bases `Food_Store` y `Food_Store_Copia` (ver `Protocolo_Seguridad.md`: `CREATE DATABASE Food_Store_Copia WITH TEMPLATE Food_Store;`)
- Usuario `postgres` con acceso a `Food_Store_Copia`
- Carga masiva ejecutada (si `SELECT count(*) FROM pedido;` no da 200000):

```powershell
psql -U postgres -h localhost -p 5432 -d Food_Store_Copia -f "db/carga_masiva_datos - Tp3.sql"
```

### 1. Medir planes ANTES de índices

```sql
-- Q1: pedidos por fecha + forma_pago (Seq Scan 33 ms)
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT id, fecha, forma_pago FROM pedido
WHERE fecha BETWEEN '2025-01-01' AND '2025-01-31' AND forma_pago='TARJETA' ORDER BY fecha DESC;

-- Q2: productos Bebidas con precio >2000
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT p.id, p.nombre, p.precio, c.nombre FROM producto p
JOIN categoria c ON p.categoria_id=c.id
WHERE c.nombre='Bebidas' AND p.precio>2000 ORDER BY p.precio DESC LIMIT 100;

-- Q3: recaudación por categoría
EXPLAIN (ANALYZE, BUFFERS, TIMING)
SELECT c.nombre, COUNT(dp.producto_id), SUM(dp.cantidad*dp.precio_unitario)
FROM categoria c JOIN producto p ON c.id=p.categoria_id JOIN detalle_pedido dp ON p.id=dp.producto_id
GROUP BY c.id, c.nombre ORDER BY SUM DESC;
```

### 2. Crear índices (midiendo después)

```powershell
psql -U postgres -h localhost -p 5432 -d Food_Store_Copia -f indices.sql
```

Repetir los EXPLAIN de arriba — deben mostrar `Index Scan` / `Bitmap Heap Scan` y tiempos del informe (Q1 0.03 ms, Q2 2.1 ms, Q3 filtrado <15 ms).

### 3. Medir costo de escritura

```sql
BEGIN;
EXPLAIN (ANALYZE, TIMING)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT 1, p.id, 1, p.precio FROM producto p WHERE p.id BETWEEN 40000 AND 40500;
ROLLBACK;
-- Antes: ~66 ms / Después: ~72 ms (+8%)
```

### 4. Crear vistas y materializada

```powershell
psql -U postgres -h localhost -p 5432 -d Food_Store_Copia -f views.sql
```

### 5. Verificar equivalencia de vistas

```sql
-- Cada par debe dar 0 filas
(SELECT * FROM v_productos_vigentes_con_categoria
 EXCEPT SELECT p.id,p.nombre,p.precio,p.stock,c.id,c.nombre FROM producto p JOIN categoria c ON p.categoria_id=c.id WHERE p.activo AND c.activo)
UNION ALL
(SELECT p.id,p.nombre,p.precio,p.stock,c.id,c.nombre FROM producto p JOIN categoria c ON p.categoria_id=c.id WHERE p.activo AND c.activo
 EXCEPT SELECT * FROM v_productos_vigentes_con_categoria);

-- Idem para v_pedidos_con_cliente y v_detalle_pedido_con_producto (ver informe_mediciones.md)

-- Seguridad: v_pedidos_con_cliente no expone email/telefono
\d v_pedidos_con_cliente
```

### 6. Medir vista materializada

```sql
-- Original costosa
EXPLAIN (ANALYZE, BUFFERS) SELECT c.nombre, to_char(p.fecha,'YYYY-MM') AS mes, SUM(dp.cantidad*dp.precio_unitario), COUNT(DISTINCT p.id)
FROM categoria c JOIN producto pr ON pr.categoria_id=c.id JOIN detalle_pedido dp ON dp.producto_id=pr.id JOIN pedido p ON p.id=dp.pedido_id
GROUP BY c.nombre, to_char(p.fecha,'YYYY-MM') ORDER BY mes DESC; -- ~523 ms

-- Materializada
EXPLAIN (ANALYZE, BUFFERS) SELECT * FROM vm_facturacion_categoria_mes ORDER BY mes DESC; -- ~0.8 ms

-- Refresco
REFRESH MATERIALIZED VIEW CONCURRENTLY vm_facturacion_categoria_mes;
```

### 7. Historial Git (parte de la entrega)

```powershell
git log --oneline --graph -20
git show HEAD --stat
```

## Defensa oral

Cada índice/vista debe poder explicarse sin IA: por qué se creó, qué plan cambió, qué costo tiene en escritura y por qué se descartó la sobreindexación. Ver `informe_mediciones.md` y `specs/spec_indice_descartado_forma_pago.md`.

## Notas sobre el esquema

El enunciado menciona tablas `usuario`/`pedido`/`detalle_pedido` con columnas `estado`/`eliminado`/`contraseña`. El esquema real del proyecto usa `cliente` (no `usuario`), sin columnas `estado`/`eliminado`/`contraseña`. Se adaptó: `usuario → cliente`, `contraseña → email/telefono` (dato sensible ocultado en `v_pedidos_con_cliente`), y filtros de vigencia sobre `activo`.

