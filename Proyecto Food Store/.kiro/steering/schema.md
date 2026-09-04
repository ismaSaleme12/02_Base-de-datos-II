# Esquema de la base de datos — Food Store

> **Siempre activo.** Usar como referencia del modelo de datos al escribir cualquier consulta o script SQL.

## Tipos personalizados

```sql
TYPE forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')
```

## Tablas

### `categoria`
| Columna | Tipo          | Restricciones                        |
|---------|---------------|--------------------------------------|
| id      | BIGINT        | PK, generado automáticamente (IDENTITY) |
| nombre  | VARCHAR(80)   | NOT NULL, UNIQUE                     |
| activo  | BOOLEAN       | NOT NULL, DEFAULT true               |

---

### `producto`
| Columna      | Tipo           | Restricciones                        |
|--------------|----------------|--------------------------------------|
| id           | BIGINT         | PK, generado automáticamente (IDENTITY) |
| nombre       | VARCHAR(100)   | NOT NULL                             |
| precio       | NUMERIC(10,2)  | NOT NULL, CHECK >= 0                 |
| stock        | INTEGER        | NOT NULL, CHECK >= 0                 |
| activo       | BOOLEAN        | NOT NULL, DEFAULT true               |
| categoria_id | BIGINT         | NOT NULL, FK → categoria(id) ON DELETE RESTRICT |

Índice: `index_producto_categoria` sobre `(categoria_id)`.

---

### `cliente`
| Columna  | Tipo          | Restricciones                        |
|----------|---------------|--------------------------------------|
| id       | BIGINT        | PK, generado automáticamente (IDENTITY) |
| nombre   | VARCHAR(100)  | NOT NULL                             |
| email    | VARCHAR(150)  | NOT NULL, UNIQUE                     |
| telefono | VARCHAR(30)   | —                                    |

---

### `pedido`
| Columna    | Tipo          | Restricciones                                   |
|------------|---------------|-------------------------------------------------|
| id         | BIGINT        | PK, generado automáticamente (IDENTITY)         |
| fecha      | TIMESTAMPTZ   | NOT NULL, DEFAULT now()                         |
| forma_pago | forma_pago    | NOT NULL                                        |
| cliente_id | BIGINT        | NOT NULL, FK → cliente(id) ON DELETE RESTRICT   |

Índice: `index_pedido_cliente` sobre `(cliente_id)`.

---

### `detalle_pedido`
| Columna         | Tipo           | Restricciones                                       |
|-----------------|----------------|-----------------------------------------------------|
| pedido_id       | BIGINT         | PK compuesta, FK → pedido(id) ON DELETE RESTRICT    |
| producto_id     | BIGINT         | PK compuesta, FK → producto(id) ON DELETE RESTRICT  |
| cantidad        | INTEGER        | NOT NULL, CHECK > 0                                 |
| precio_unitario | NUMERIC(10,2)  | NOT NULL, CHECK >= 0                                |

---

## Reglas de integridad (triggers — `db/reglas_integridad.sql`)

| Regla | Objeto           | Descripción                                                                 |
|-------|------------------|-----------------------------------------------------------------------------|
| 1     | `detalle_pedido` | Solo se pueden referenciar productos con `activo = TRUE`. Trigger BEFORE INSERT/UPDATE. |
| 2     | `pedido`         | Todo pedido debe tener al menos un `detalle_pedido`. Triggers DEFERRABLE INITIALLY DEFERRED. |

## Relaciones resumidas

```
categoria  ←──  producto  ←──  detalle_pedido  ──→  pedido  ──→  cliente
```
