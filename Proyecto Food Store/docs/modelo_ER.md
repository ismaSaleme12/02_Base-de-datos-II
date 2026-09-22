# Modelo Entidad-Relación — Food Store — BD II

**Motor:** PostgreSQL 16+ | **Esquema DDL fuente:** `db/schema_tp1.sql:24-94` | **Vista lógica:** `.kiro/steering/schema.md`

## 1. Entidades y Atributos

| Entidad | Atributos (PK subrayada) | Dominio / Restricción DDL | Observación |
|---|---|---|---|
| **CATEGORIA** | **id** BIGINT, nombre VARCHAR(80), activo BOOLEAN | `id GENERATED ALWAYS AS IDENTITY PRIMARY KEY` `db/schema_tp1.sql:25`, `nombre NOT NULL UNIQUE` `db/schema_tp1.sql:26`, `activo NOT NULL DEFAULT true` `db/schema_tp1.sql:27` | Catálogo maestro. `nombre` candidato alternativo (UQ). |
| **PRODUCTO** | **id** BIGINT, nombre VARCHAR(100), precio NUMERIC(10,2), stock INTEGER, activo BOOLEAN, categoria_id BIGINT (FK) | `precio CHECK >=0` `db/schema_tp1.sql:44`, `stock CHECK >=0` `db/schema_tp1.sql:47`, `activo DEFAULT true` `db/schema_tp1.sql:35`, `FK categoria_id → categoria(id) RESTRICT` `db/schema_tp1.sql:38` | Débil respecto a CATEGORIA (dependencia existencia). |
| **CLIENTE** | **id** BIGINT, nombre VARCHAR(100), email VARCHAR(150), telefono VARCHAR(30) | `email NOT NULL UNIQUE` `db/schema_tp1.sql:54`, `id IDENTITY PK` `db/schema_tp1.sql:52` | `email` clave candidata. Sin `contraseña` (adaptación ver `README.md:138`). |
| **PEDIDO** | **id** BIGINT, fecha TIMESTAMPTZ, forma_pago forma_pago, cliente_id BIGINT (FK) | `fecha NOT NULL DEFAULT now()` `db/schema_tp1.sql:61`, `forma_pago ENUM('EFECTIVO','TARJETA','TRANSFERENCIA')` `db/schema_tp1.sql:14`, `FK cliente_id → cliente(id) RESTRICT` `db/schema_tp1.sql:65` | Entidad transaccional. |
| **DETALLE_PEDIDO** | **pedido_id** BIGINT (FK, PK comp.), **producto_id** BIGINT (FK, PK comp.), cantidad INTEGER, precio_unitario NUMERIC(10,2) | `PK(pedido_id,producto_id)` `db/schema_tp1.sql:77`, `FK pedido_id → pedido(id) RESTRICT` `db/schema_tp1.sql:79`, `FK producto_id → producto(id) RESTRICT` `db/schema_tp1.sql:84`, `cantidad CHECK >0` `db/schema_tp1.sql:90`, `precio_unitario CHECK >=0` `db/schema_tp1.sql:93` | Tabla asociativa que resuelve N:M. `precio_unitario` copia histórica de `producto.precio`. |

> **Nota tipo:** `ENUM forma_pago` y `TIMESTAMPTZ` son tipos nativos PostgreSQL 16+ exigidos por rúbrica Pt.4 — ver `db/schema_tp1.sql:14,61`.

## 2. Relaciones, Cardinalidad y Participación

| Relación | Entidades | Cardinalidad | Participación | Implementación Relacional | Regla de Negocio |
|---|---|---|---|---|---|
| **CLASIFICA** | CATEGORIA — PRODUCTO | `1:N` (1 categoría tiene N productos; 1 producto pertenece a 1 categoría) | CATEGORIA `(0,N)` opcional (puede existir sin productos) — PRODUCTO `(1,1)` total (todo producto debe tener categoría) | FK `producto.categoria_id NOT NULL` `db/schema_tp1.sql:36` + `INDEX` `db/schema_tp1.sql:105` | `ON DELETE RESTRICT`: no se puede borrar categoría con productos. |
| **REALIZA** | CLIENTE — PEDIDO | `1:N` (1 cliente N pedidos; 1 pedido de 1 cliente) | CLIENTE `(0,N)` opcional — PEDIDO `(1,1)` total | FK `pedido.cliente_id NOT NULL` `db/schema_tp1.sql:63` + `INDEX` `db/schema_tp1.sql:101` | `RESTRICT` + trigger R2 garantiza que todo pedido tenga detalle `db/reglas_integridad.sql:101` |
| **CONTIENE** | PEDIDO — PRODUCTO | `N:M` resuelta vía **DETALLE_PEDIDO** | PEDIDO `(1,N)` total (≥1 detalle, R2 `db/reglas_integridad.sql:62`) — PRODUCTO `(0,N)` opcional (producto puede no haberse pedido) | Tabla intermedia `detalle_pedido` PK compuesta + 2 FKs `db/schema_tp1.sql:71-88` | R1: solo `producto.activo=TRUE` `db/reglas_integridad.sql:39`; R2: pedido no puede quedar vacío (deferred) |

**Notación:** Crow's Foot — `||` = 1, `|o` = 0..1, `}o` = 0..N, `}|` = 1..N. Participación total = barra `|` (obligatorio); parcial = círculo `o`.

## 3. Diagrama ER (Mermaid — compatible con GitHub / draw.io import)

```mermaid
erDiagram
    CATEGORIA ||--o{ PRODUCTO : "clasifica"
    CLIENTE ||--o{ PEDIDO : "realiza"
    PEDIDO ||--o{ DETALLE_PEDIDO : "contiene"
    PRODUCTO ||--o{ DETALLE_PEDIDO : "es_contenido_en"

    CATEGORIA {
        BIGINT id PK "IDENTITY"
        VARCHAR nombre UK "NOT NULL"
        BOOLEAN activo "DEFAULT true"
    }
    PRODUCTO {
        BIGINT id PK "IDENTITY"
        VARCHAR nombre "NOT NULL"
        NUMERIC precio "CHECK >=0"
        INTEGER stock "CHECK >=0"
        BOOLEAN activo "DEFAULT true"
        BIGINT categoria_id FK "NOT NULL → CATEGORIA"
    }
    CLIENTE {
        BIGINT id PK "IDENTITY"
        VARCHAR nombre "NOT NULL"
        VARCHAR email UK "NOT NULL"
        VARCHAR telefono
    }
    PEDIDO {
        BIGINT id PK "IDENTITY"
        TIMESTAMPTZ fecha "DEFAULT now()"
        ENUM forma_pago "EFECTIVO|TARJETA|TRANSFERENCIA"
        BIGINT cliente_id FK "NOT NULL → CLIENTE"
    }
    DETALLE_PEDIDO {
        BIGINT pedido_id PK_FK "→ PEDIDO"
        BIGINT producto_id PK_FK "→ PRODUCTO"
        INTEGER cantidad "CHECK >0"
        NUMERIC precio_unitario "CHECK >=0"
    }
```

**Instrucción para captura:** Pegar este Mermaid en https://mermaid.live o en draw.io (Arrange → Insert → Advanced → Mermaid) y exportar `docs/modelo_ER.png` (300 dpi). Alternativa textual válida para defensa si no hay imagen: este bloque + tabla de cardinalidades arriba.

## 4. Claves Candidatas y Alternativas

- `categoria.nombre UNIQUE` `db/schema_tp1.sql:26` → clave candidata (no PK por ser mutable).
- `cliente.email UNIQUE` `db/schema_tp1.sql:54` → clave candidata; justifica descarte de `idx_cliente_email` `specs/spec_indice_descartado_forma_pago.md:18`.
- `detalle_pedido` no tiene clave subrogada; PK natural compuesta garantiza unicidad de (pedido,producto) y evita duplicado de producto en mismo pedido.

## 5. Adaptación al Enunciado

Enunciado menciona `usuario`/`contraseña`/`estado`/`eliminado` (`README.md:138`). Mapeo real: `usuario → cliente`, `contraseña → email/telefono` (dato sensible oculto en `v_pedidos_con_cliente` `db/views.sql:36`), `eliminado/estado → activo BOOLEAN` (soft delete — ver `docs/borrado_logico.md`). Participación y cardinalidad idénticas.

---
*Generado para cerrar Pt.1 rúbrica — Fuente única de verdad DDL `db/schema_tp1.sql` — Ver también `docs/modelo_relacional.md` y `docs/normalizacion.md`*
