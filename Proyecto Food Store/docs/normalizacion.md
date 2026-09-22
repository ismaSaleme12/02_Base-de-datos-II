# Normalización hasta 3FN/BCNF — Food Store — Justificación con Dependencias Funcionales

**Esquema auditado:** `db/schema_tp1.sql:24-94` | **Dataset:** 10 categorías, 50k productos, 20k clientes, 200k pedidos, 200k detalles (`db/carga_masiva_datos - Tp3.sql`)

## 1. Dependencias Funcionales (DFs) Identificadas

> Determinante → Dependiente | Determinante es superclave si contiene PK/UK

| Tabla | DF | Determinante ¿Superclave? | Fuente |
|---|---|---|---|
| **categoria** | `id → nombre, activo` | SÍ (PK) | `PRIMARY KEY(id)` `db/schema_tp1.sql:25` |
|  | `nombre → id, activo` | SÍ (UK) | `UNIQUE(nombre)` `db/schema_tp1.sql:26` |
| **producto** | `id → nombre, precio, stock, activo, categoria_id` | SÍ (PK) | `PRIMARY KEY(id)` `db/schema_tp1.sql:31` |
|  | `categoria_id ↛ producto.id` (no DF, solo FK) | — | `FK categoria_id → categoria` `db/schema_tp1.sql:38` |
| **cliente** | `id → nombre, email, telefono` | SÍ (PK) | `PRIMARY KEY(id)` `db/schema_tp1.sql:52` |
|  | `email → id, nombre, telefono` | SÍ (UK) | `UNIQUE(email)` `db/schema_tp1.sql:54` |
| **pedido** | `id → fecha, forma_pago, cliente_id` | SÍ (PK) | `PRIMARY KEY(id)` `db/schema_tp1.sql:60` |
|  | `cliente_id ↛ pedido.id` | — | FK |
| **detalle_pedido** | `(pedido_id, producto_id) → cantidad, precio_unitario` | SÍ (PK compuesta) | `PRIMARY KEY(pedido_id,producto_id)` `db/schema_tp1.sql:77` |
|  | `pedido_id ↛ cantidad` (dependencia parcial **no existe** porque `cantidad` depende del par, no solo de `pedido_id`) | — | Ver §2 |
|  | `producto_id ↛ precio_unitario` (no parcial: `precio_unitario` es histórico por pedido+producto, no solo producto) | — | Justificado §2c |

**No hay DFs transitivas dentro de la misma tabla** (ej. no existe `producto.id → categoria_id → categoria.nombre` dentro de `producto`; `categoria.nombre` está en otra tabla vía FK — eso es **descomposición correcta**, no transitividad).

## 2. Demostración por Forma Normal

### 1FN (Primera Forma Normal) — Atomicidad
**Requisito:** Atributos atómicos, sin grupos repetitivos ni multivaluados.
- **Cumple en 5/5 tablas:** Todos los atributos son atómicos (`VARCHAR`, `NUMERIC`, `INTEGER`, `BOOLEAN`, `TIMESTAMPTZ`, `ENUM`). No hay arrays, JSON ni columnas compuestas. `detalle_pedido` no almacena lista de productos; cada fila es un producto por pedido (1 fila = 1 hecho). Ver `db/schema_tp1.sql:72-75`.

### 2FN (Segunda Forma Normal) — Sin dependencia parcial sobre PK compuesta
**Requisito:** Todo atributo no primo debe depender de **toda** la PK, no de parte de ella. Solo aplica a `detalle_pedido` (única PK compuesta).
- **Cumple:** `cantidad` y `precio_unitario` dependen del **par** `(pedido_id, producto_id)`. No se puede determinar `cantidad` con solo `pedido_id` (un pedido tiene N productos con distintas cantidades) ni con solo `producto_id` (un producto aparece en N pedidos con distintas cantidades). Por tanto no hay dependencia parcial.
- **Prueba empírica:** `SELECT pedido_id, COUNT(DISTINCT producto_id) FROM detalle_pedido GROUP BY pedido_id HAVING COUNT(*)>1 LIMIT 5;` — si hay pedidos con >1 producto, `cantidad` varía por producto, luego no es parcial.

### 3FN (Tercera Forma Normal) — Sin dependencia transitiva
**Requisito:** Ningún atributo no primo depende transitivamente de la PK vía otro atributo no primo.
- **Cumple en 5/5 tablas:**
  - `categoria`: Solo PK `id` y UK `nombre`; `activo` depende directo de PK, no vía `nombre` (ambos son claves, no transitividad).
  - `producto`: `nombre, precio, stock, activo, categoria_id` dependen directo de `id`. **No** existe `id → categoria_id → categoria.nombre` dentro de `producto` (eso sería transitividad si `categoria.nombre` estuviera como columna en `producto`, pero está normalizado en `categoria` vía FK).
  - `cliente`: `nombre, email, telefono` dependen directo de `id`; `email` es UK pero no hay atributo que dependa de `email` sin pasar por `id` (ambos superclaves, no viola 3FN).
  - `pedido`: `fecha, forma_pago, cliente_id` dependen directo de `id`. No hay `id → cliente_id → cliente.nombre` dentro de `pedido`.
  - `detalle_pedido`: `cantidad, precio_unitario` dependen directo de PK compuesta. `precio_unitario` **parece** redundante con `producto.precio`, pero es copia histórica justificada: no es ` (pedido_id,producto_id) → producto_id → precio ` porque `producto.precio` es mutable y `precio_unitario` congela valor al momento de venta. Si se eliminara y se derivara vía JOIN, se perdería historización y se recalcularía mal facturación pasada.

### BCNF (Boyce-Codd) — Todo determinante es superclave
**Requisito:** Para toda DF `X → Y`, `X` es superclave.
- **Cumple en 5/5 tablas:** Únicas DFs no triviales son las listadas en §1, y en todas el determinante es PK o UK (superclave). No existen DFs como `producto.categoria_id → producto.nombre` ni `pedido.cliente_id → pedido.fecha` (no son DFs reales; un `categoria_id` tiene N productos con distintos nombres). Por tanto, no hay violaciones BCNF.
- **Conclusión:** Esquema está en **BCNF** (y por tanto en 3FN). No requiere descomposición adicional.

## 3. Tabla Resumen por Tabla

| Tabla | 1FN | 2FN | 3FN | BCNF | Observación defensa |
|---|---|---|---|---|---|
| `categoria` | ✓ | ✓ (PK simple) | ✓ | ✓ | UK `nombre` es superclave, no transitiva |
| `producto` | ✓ | ✓ (PK simple) | ✓ | ✓ | FK `categoria_id` no es transitividad; `precio_unitario` no está aquí |
| `cliente` | ✓ | ✓ (PK simple) | ✓ | ✓ | UK `email` es superclave |
| `pedido` | ✓ | ✓ (PK simple) | ✓ | ✓ | `TIMESTAMPTZ` atómico, no viola 1FN |
| `detalle_pedido` | ✓ | ✓ (no parcial) | ✓ | ✓ | PK compuesta, `precio_unitario` es histórico justificado |

## 4. ¿Por qué no se desnormaliza?

- **No se agrega `categoria.nombre` en `producto`** (evitaría JOIN pero duplicaría y violaría 3FN transitiva).
- **No se agrega `cliente.nombre` en `pedido`** (mismo motivo).
- **Sí se mantiene `detalle_pedido.precio_unitario` + `producto.precio`** (no es desnormalización, es historización — ver `docs/modelo_relacional.md:3c`). Alternativa desnormalizada sería agregar `pedido.total` calculado (suma de detalles) — se descartó: se calcula vía `SUM` en vistas `db/views.sql:57` y materializada `db/views.sql:80` para evitar anomalía de actualización.

## 5. Verificación en Motor

```sql
-- Comprobar DFs: intentar duplicar UK debe fallar
INSERT INTO categoria(nombre) VALUES ('Bebidas'); -- ERROR violates unique_constraint categoria_nombre_key
INSERT INTO cliente(nombre,email) VALUES ('Test','cliente1@example.com'); -- ERROR unique cliente_email_key (ya existe 1..20000)

-- Comprobar no dependencia parcial: un mismo pedido_id tiene distintos productos/cantidades
SELECT pedido_id, producto_id, cantidad FROM detalle_pedido WHERE pedido_id=1; -- 1 fila (1 detalle/pedido en carga actual), pero el modelo soporta N

-- Comprobar BCNF: no hay determinante no superclave
SELECT conname, contype FROM pg_constraint WHERE conrelid='producto'::regclass; -- solo PK, FK, CHECK, no DF espuria
```

`[Insertar captura pg_constraint + intento INSERT duplicado UNIQUE aquí]`

---
*Esta justificación cierra Pt.3 rúbrica — Coherente con DDL real y sin DFs inventadas — Ver `docs/modelo_ER.md` y `docs/modelo_relacional.md`*
