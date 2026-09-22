# Paso ER → Modelo Relacional — Food Store

**Fuente ER:** `docs/modelo_ER.md` | **DDL destino:** `db/schema_tp1.sql:24-108` | **Reglas aplicadas:** Heurísticas de Elmasri/Navathe para transformación ER→Relacional

## 1. Reglas de Transformación Aplicadas

| Caso ER | Regla | Aplicación en Food Store | DDL |
|---|---|---|---|
| **Entidad fuerte** | Tabla con PK subrogada `IDENTITY` + atributos atómicos | 4 entidades fuertes: `categoria`, `producto`, `cliente`, `pedido` | `categoria(id IDENTITY PK)` `db/schema_tp1.sql:25`, `producto(id)` `db/schema_tp1.sql:31`, `cliente(id)` `db/schema_tp1.sql:52`, `pedido(id)` `db/schema_tp1.sql:60` |
| **Relación 1:N con participación total en N** | Lado N recibe FK `NOT NULL` + `FOREIGN KEY … RESTRICT` + índice | `categoria 1:N producto`: `producto.categoria_id BIGINT NOT NULL FK → categoria(id)` `db/schema_tp1.sql:36-41` + `INDEX index_producto_categoria` `db/schema_tp1.sql:105`. `cliente 1:N pedido`: `pedido.cliente_id` `db/schema_tp1.sql:63` + `INDEX index_pedido_cliente` `db/schema_tp1.sql:101`. | Ver DDL arriba |
| **Relación N:M** | Tabla intermedia con PK compuesta (FK1,FK2) + FKs + atributos de relación | `pedido N:M producto` → `detalle_pedido(pedido_id FK, producto_id FK, cantidad, precio_unitario)` PK `(pedido_id, producto_id)` `db/schema_tp1.sql:71-88` | `PRIMARY KEY(pedido_id,producto_id)` `db/schema_tp1.sql:77`, `FK pedido_id → pedido` `db/schema_tp1.sql:79`, `FK producto_id → producto` `db/schema_tp1.sql:84` |
| **Atributo multivaluado** | Tabla aparte (no aplica) | No hay atributos multivaluados en ER Food Store | — |
| **Enumerado** | `TYPE ENUM` | `forma_pago` `db/schema_tp1.sql:14` | `CREATE TYPE forma_pago AS ENUM ('EFECTIVO','TARJETA','TRANSFERENCIA')` |
| **Temporal con zona** | `TIMESTAMPTZ` | `pedido.fecha` `db/schema_tp1.sql:61` | `TIMESTAMPTZ NOT NULL DEFAULT now()` |

## 2. Esquema Relacional Resultante (notación textual)

```
categoria( id PK, nombre UK NOT NULL, activo NOT NULL DEFAULT true )
producto( id PK, nombre NOT NULL, precio NOT NULL CHECK>=0, stock NOT NULL CHECK>=0, activo NOT NULL DEFAULT true, categoria_id FK NOT NULL → categoria.id ON DELETE RESTRICT )
cliente( id PK, nombre NOT NULL, email UK NOT NULL, telefono )
pedido( id PK, fecha TIMESTAMPTZ NOT NULL DEFAULT now(), forma_pago ENUM NOT NULL, cliente_id FK NOT NULL → cliente.id ON DELETE RESTRICT )
detalle_pedido( pedido_id PK,FK → pedido.id RESTRICT, producto_id PK,FK → producto.id RESTRICT, cantidad NOT NULL CHECK>0, precio_unitario NOT NULL CHECK>=0, PRIMARY KEY(pedido_id, producto_id) )

Índices: index_pedido_cliente(pedido.cliente_id), index_producto_categoria(producto.categoria_id),
         idx_pedido_fecha_forma_pago(fecha,forma_pago), idx_producto_categoria_precio_activo(categoria_id,precio) WHERE activo,
         idx_detalle_pedido_producto(producto_id)  — ver db/indices.sql
```

## 3. Justificación de Decisiones Clave

**a) ¿Por qué `detalle_pedido` no tiene `id` subrogado?**
PK compuesta garantiza unicidad natural (no duplicar mismo producto en mismo pedido) y es más eficiente para `JOIN producto_id` cuando se agrega `idx_detalle_pedido_producto` `db/indices.sql:54`. Un `id` subrogado exigiría `UNIQUE(pedido_id,producto_id)` adicional — redundante.

**b) ¿Por qué `ON DELETE RESTRICT` y no `CASCADE`?**
Preserva integridad histórica: no se puede borrar `categoria` con productos, ni `cliente` con pedidos, ni `producto`/`pedido` con detalles. El borrado es lógico (`activo=FALSE` — ver `docs/borrado_logico.md`), no físico.

**c) ¿Por qué `precio_unitario` en `detalle_pedido` duplicado de `producto.precio`?**
Historización: `producto.precio` es mutable; `detalle_pedido.precio_unitario` congela precio al momento de la venta. Sin esto, un `UPDATE producto SET precio` alteraría facturación pasada — viola 3FN si se derivara, pero aquí es copia histórica justificada (no dependencia transitiva).

**d) ¿Por qué `IDENTITY` vs `SERIAL`?**
`GENERATED ALWAYS AS IDENTITY` `db/schema_tp1.sql:25` es estándar SQL:2003, PostgreSQL 10+, evita `SEQUENCE` manual y permite `RESTART IDENTITY` en `db/carga_masiva_datos - Tp3.sql:19` (`TRUNCATE ... RESTART IDENTITY CASCADE`).

## 4. Correspondencia ER → Tablas (trazabilidad para defensa)

| Entidad/Relación ER | Tabla(s) Relacional | Clave | Atributos de relación |
|---|---|---|---|
| CATEGORIA | `categoria` | `id` PK, `nombre` UK | `activo` |
| PRODUCTO | `producto` | `id` PK | `categoria_id` FK materializa `CLASIFICA` |
| CLIENTE | `cliente` | `id` PK, `email` UK | — |
| PEDIDO | `pedido` | `id` PK | `cliente_id` FK materializa `REALIZA`, `fecha`, `forma_pago` |
| DETALLE (N:M) | `detalle_pedido` | `(pedido_id,producto_id)` PK | `cantidad`, `precio_unitario` |

**Verificación:** `SELECT conname, contype FROM pg_constraint WHERE conrelid='detalle_pedido'::regclass;` debe mostrar 2 FKs + 1 PK compuesta. `[Insertar captura \d detalle_pedido aquí — muestra PK compuesta y FKs]`

---
*Generado para cerrar Pt.2 rúbrica — Coherente con DDL real — Ver también `docs/normalizacion.md`*
