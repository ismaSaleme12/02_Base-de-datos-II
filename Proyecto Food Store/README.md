# Food Store — Base de Datos II

**Autor:** Saleme Ismael — TUP UTN<br>
**Motor:** PostgreSQL 17 (probado en 17.10) — BD `Food_Store_Copia` (copia de `Food_Store`)

| Unidad | Tema | Dónde |
|---|---|---|
| U3 S5 | índices, vistas y vistas materializadas | §«Cómo reproducir las pruebas de esta entrega» (más abajo) |
| **U8** | **la base de la tablet y el cierre de la capa de datos** | **§TP 8 (acá abajo)** |

---

# TP 8 — Food Store en la feria

**Enunciado:** el food truck vende en una feria **sin señal**. La tablet guarda
una copia del catálogo en SQLite y arma borradores de pedido. Cuando recupera
conexión, el servidor decide si la venta se acepta.

> **Regla de oro:** el móvil propone, el servidor dispone.
> La tablet **nunca** escribe en PostgreSQL. `SIMULADO_APROBADO` **no es una venta.**

## Orden de creación desde cero

Cada paso depende del anterior. Si uno falla, no se sigue: el siguiente leería
datos que no existen o que están mal.

### Paso 0 — Prerrequisitos

```powershell
# PostgreSQL 17 con la base cargada
$env:PGPASSWORD = "<password>"          # sólo en el entorno, nunca en un archivo
$psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"

& $psql -U postgres -h localhost -p 5432 -w -d Food_Store_Copia `
        -tAc "select count(*) from producto;"     # debe dar 50000

# SQLite 3.37+ (hace falta por las tablas STRICT)
sqlite3 --version
```

Si `producto` no tiene 50.000 filas, primero hay que correr la carga masiva
(`db/carga_masiva_datos - Tp3.sql`).

### Paso 1 — Respaldo (protocolo del proyecto)

```powershell
& "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" -U postgres -h localhost -p 5432 -w `
   -F p -f "db\backups\Food_Store_Copia_tp8_$(Get-Date -Format yyyyMMdd_HHmmss).sql" Food_Store_Copia
```

No se toca nada sin respaldo. Es la primera regla de `Protocolo_Seguridad.md`.

### Paso 2 — Línea de base de los invariantes

```powershell
& $psql -U postgres -h localhost -p 5432 -w -d Food_Store_Copia -f "db\tp8_linea_base.sql"
```

Crea `tp8_linea_base` con `pedidos`, `detalles`, `stock_total`, `stock_huella`
(md5 del vector `id:stock`) y `precio_huella`. **Es contra esto que se prueba, al
final, que PostgreSQL no se movió.**

### Paso 3 — Vista de exportación

```powershell
& $psql -U postgres -h localhost -p 5432 -w -d Food_Store_Copia -f "db\tp8_v_snapshot_movil.sql"
```

Crea `v_snapshot_movil`: precio en centavos, `disponible = activo AND stock > 0`,
`eliminado = NOT activo`, `fecha_copia` sellada por el servidor.

### Paso 4 — Exportar la instantánea

```powershell
$csv = (Resolve-Path "movil").Path.Replace('\','/') + "/servidor_snapshot.csv"
"\copy (SELECT * FROM v_snapshot_movil) TO '$csv' CSV HEADER" |
    & $psql -U postgres -h localhost -p 5432 -w -d Food_Store_Copia
```

Tiene que responder `COPY 50000`. El CSV trae los booleanos como `t`/`f` — eso
es lo que hay que normalizar en el paso 7.

### Paso 5 — Esquema de la tablet

```powershell
sqlite3 movil\foodstore_movil.db ".read movil\schema_sqlite.sql"
```

Crea las cuatro tablas `STRICT`: `producto_cache`, `pedido_borrador`,
`item_borrador`, `cola_sync`.

### Paso 6 — Tabla de aterrizaje

```powershell
sqlite3 movil\foodstore_movil.db ".read movil\schema_snapshot.sql"
```

**Este paso va antes del `.import`, no después.** Si `snapshot_servidor` no
existe, `sqlite3` la crea usando la primera fila de datos como nombres de columna
y se pierde un producto del catálogo.

### Paso 7 — Importar y normalizar

```powershell
sqlite3 movil\foodstore_movil.db ".import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor"
sqlite3 movil\foodstore_movil.db ".read movil\cargar_snapshot.sql"
```

`cargar_snapshot.sql` hace tres cosas: controla qué llegó, normaliza `'t'/'f'`
a `1/0` (sin esto, los motivos "dado de baja" y "no disponible" del semáforo
nunca se disparan) y hace el UPSERT contra `producto_cache`.

Debe cerrar con **50.000 en cache / 49.744 vendibles / 0 inconsistentes**.

### Paso 8 — Semáforo

```powershell
sqlite3 movil\foodstore_movil.db ".read movil\semaforo.sql"
```

Resuelve cada solicitud `PENDIENTE` a `SIMULADO_APROBADO`, `CONFLICTO` o
`RECHAZADO`. Correrlo dos veces no cambia nada (filtra por `PENDIENTE`).

### Paso 9 — Los casos C2 a C6

```powershell
$env:PGPASSWORD = "<password>"
.\movil\simular_casos.ps1 -Sqlite3 "C:\ruta\a\sqlite3.exe"
```

Orquesta la secuencia completa (borrador → cambio en el servidor → nueva
instantánea → recarga → semáforo) y deja la evidencia en
`movil/evidencias_casos.txt`. Los resultados esperados están en
`docs/kiro/tasks.md §T2.6`.

> Ojo: este script **modifica a propósito** el precio del producto 5 (C2) y el
> estado del producto 6 (C4). Son los dos cambios intencionales del TP.

### Paso 10 — Prueba de que PostgreSQL no cambió

```powershell
& $psql -U postgres -h localhost -p 5432 -w -d Food_Store_Copia -f "db\tp8_verificacion_final.sql"
```

Pedidos, detalles y stock tienen que dar **SIN CAMBIOS**. `precio_huella` tiene
que dar **CAMBIÓ** — es el caso C2, y es la prueba de que el semáforo leyó y no
escribió.

### Paso 11 — Pruebas del esquema, sobre una base aparte

```powershell
sqlite3 movil\pruebas_aparte.db ".read movil\pruebas_sqlite.sql"
```

`pruebas_sqlite.sql` **borra las tablas al inicio**. Por eso se corre sobre una
base descartable y nunca contra `foodstore_movil.db`.

## Mapa de archivos del TP 8

```
Proyecto Food Store/
├── db/
│   ├── tp8_linea_base.sql                 # invariantes ANTES de empezar
│   ├── tp8_v_snapshot_movil.sql           # la vista que exporta el catálogo
│   ├── tp8_caso_c2_sube_precio.sql        # cambio deliberado de precio
│   ├── tp8_caso_c4_baja_logica.sql        # baja lógica deliberada
│   ├── tp8_verificacion_final.sql         # prueba de que nada se movió
│   ├── tp8_code_review_verificaciones.sql # los 4 hallazgos, verificados
│   └── backups/                           # pg_dump previo
├── movil/
│   ├── schema_sqlite.sql                  # las 4 tablas STRICT
│   ├── pruebas_sqlite.sql                 # 1.c (base aparte)
│   ├── schema_snapshot.sql                # bandeja de aterrizaje (no STRICT)
│   ├── cargar_snapshot.sql                # normaliza t/f → 1/0 + UPSERT
│   ├── semaforo.sql                       # 2.b
│   ├── casos/                             # C2a, C2b, C3, C4, C5, C6
│   ├── simular_casos.ps1                  # driver de la simulación
│   ├── servidor_snapshot.csv              # instantánea real (50.000 filas)
│   ├── snapshots/                         # instantáneas intermedias
│   └── evidencias_casos.txt               # evidencia de la corrida final
├── docs/
│   ├── kiro/requirements.md               # 4.a — EARS
│   ├── kiro/design.md                     # 4.a — diseño y decisiones
│   ├── kiro/tasks.md                      # 4.a — lista ejecutable
│   ├── bitacora_ia.md                     # 4.b
│   ├── DUIA.md                            # 4.b
│   ├── evidencias_code_review.txt         # 3.c — salida real
│   └── informe.pdf                        # 1.a, 2.c, 3.a, 3.b, 3.c
└── README.md                              # este archivo
```

## Lo que este TP demuestra

1. **La tablet no puede confirmar nada.** No tiene conexión, credenciales ni
   driver. El único canal es un CSV de una sola dirección.
2. **El semáforo distingue cuatro rojos y un amarillo**, en orden de precedencia,
   y el amarillo sólo aparece si no hay ningún rojo.
3. **PostgreSQL no se movió**: pedidos y stock idénticos a la línea de base, con
   huella md5. El precio sí cambió, y eso es lo que prueba que se leyó sin
   escribir.
4. **La idempotencia de la tablet no es la protección real.** La PK de
   `cola_sync` protege la tabla local; la protección de negocio vive en el
   servidor, dentro de la transacción (`docs/kiro/design.md §6`).
5. **La base que dice ser la fuente de verdad no impide vender sin stock.**
   Verificado: 999 unidades de un producto con stock 3 entran sin error (H4).

---

# U3 S5 — Índices, vistas y vistas materializadas

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

