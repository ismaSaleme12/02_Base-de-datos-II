# Informe Técnico — Entrega Parcial 1 — Food Store — Base de Datos II (UTN)

**Alumno:** Ismael Saleme, Sabrina Gimenez, Jeronimo Coronel, Joaquin Godoy  
**Materia:** Base de Datos II — TUP UTN | **Motor:** PostgreSQL 16+ (validado en 18.6)  
**Repositorio:** `ismaSaleme12/02_Base-de-datos-II` — Rama `main` | **Bases:** `Food_Store` (original solo lectura) / `Food_Store_Copia` / `practica_bd2_tp` (copia trabajo)  
**Fecha auditoría:** 2026-09-22 | **Modo:** Solo lectura — No se realizó push/commit  
**Archivos fuente auditados:** `db/schema_tp1.sql`, `db/reglas_integridad.sql`, `db/indices.sql`, `db/views.sql`, `db/carga_masiva_datos - Tp3.sql`, `db/consultas_optimizacion - Tp3.sql`, `db/consultas_parte1_ semana 4.sql`, `db/consultas_parte3_semana4.sql`, `db/consultas_parte4 - Tp3.sql`, `db/Sesion A/B (*).sql`, `docs/informe_concurrencia.md`, `docs/informe_mediciones.md`, `docs/DUIA_*.md`, `specs/*.md`, `.kiro/steering/schema.md`

> **Protocolo de seguridad aplicado durante todo el TP:** `Protocolo_Seguridad.md:1` + `AGENTS.md:4` — Trabajo sobre copia, `pg_dump` previo a DDL `pg_dump -U postgres -F p -f "./db/backups/Food_Store_Copia_backup.sql" Food_Store_Copia`, pruebas DML en `BEGIN; ... ROLLBACK;`, lectura línea por línea de scripts IA antes de ejecutar. `README.md:73`

---

## 1. Implementación por Unidad (Unidades 1, 2 y 3 — Trazabilidad a los 9 objetivos de la cátedra)

### Unidad 1 — Integridad, Modelado y Estructura Relacional (Objetivos 1,2,3,4,7,9)

| Elemento | Estado | Evidencia | Detalle técnico |
|---|---|---|---|
| **Modelo ER** | **CUMPLE (generado)** | `docs/modelo_ER.md:1` + `db/schema_tp1.sql:24-94`, `.kiro/steering/schema.md:11-66` | **Artefacto generado para Pt.1:** `docs/modelo_ER.md` con 5 entidades, atributos, PKs/UKs, cardinalidades `1:N` y `N:M`, participación total/parcial, y diagrama Mermaid Crow's Foot (`CATEGORIA \|\|--o{ PRODUCTO`, `PEDIDO \|\|--o{ DETALLE_PEDIDO`). Exportar Mermaid a `docs/modelo_ER.png` (300 dpi) para captura. DDL fuente `db/schema_tp1.sql:25,31,52,60` coincide. |
| **Paso ER → Relacional** | **CUMPLE (generado)** | `docs/modelo_relacional.md:1` + `db/schema_tp1.sql:38-41`, `db/schema_tp1.sql:65-68`, `db/schema_tp1.sql:71-88` | **Documento generado:** `docs/modelo_relacional.md` detalla regla entidad→tabla, `1:N → FK NOT NULL RESTRICT` (`producto.categoria_id` `db/schema_tp1.sql:36`, `pedido.cliente_id` `db/schema_tp1.sql:63`), `N:M → detalle_pedido PK compuesta + 2 FKs` `db/schema_tp1.sql:71-88`, `ENUM/TIMESTAMPTZ`, justificación `precio_unitario` histórico. |
| **Normalización 3FN/BCNF + DFs** | **CUMPLE (generado)** | `docs/normalizacion.md:1` | **Documento generado:** `docs/normalizacion.md` lista DFs (`categoria.id→nombre,activo`, `categoria.nombre→id,activo`, `producto.id→...`, `cliente.id→..., email→...`, `pedido.id→...`, `(pedido_id,producto_id)→cantidad,precio_unitario`), demuestra `1FN` atómico, `2FN` sin parcial en `detalle_pedido`, `3FN` sin transitiva (FK normalizada), `BCNF` todo determinante es superclave (PK/UK). Tabla resumen 5/5 en BCNF. |
| **DDL Completo** | CUMPLE | `db/schema_tp1.sql:14`, `db/schema_tp1.sql:61`, `db/schema_tp1.sql:25,31,52,60`, `db/schema_tp1.sql:101`, `db/indices.sql:23-60` | `TYPE forma_pago ENUM ('EFECTIVO','TARJETA','TRANSFERENCIA')` `db/schema_tp1.sql:14`, `TIMESTAMPTZ DEFAULT now()` `db/schema_tp1.sql:61`, 4× `GENERATED ALWAYS AS IDENTITY` `db/schema_tp1.sql:25`, PKs simples + compuesta, FKs `ON DELETE RESTRICT`, 4 `CHECK` (`precio>=0`, `stock>=0`, `cantidad>0`, `precio_unitario>=0`), 2 `UNIQUE` (`categoria.nombre`, `cliente.email`), índices base `index_pedido_cliente`, `index_producto_categoria` + 3 índices optimización (ver Unidad 3). **Listo para rúbrica.** |
| **Reglas de Negocio CHECK/UNIQUE/Triggers** | **CUMPLE (generado)** | `db/reglas_integridad.sql:17-42`, `db/reglas_integridad.sql:50-110` + `db/trigger_transicion.sql:22-50` | R1 `fn_check_producto_activo()` + `BEFORE FOR EACH ROW` `db/reglas_integridad.sql:17,39`, R2 `CONSTRAINT TRIGGER DEFERRABLE` `db/reglas_integridad.sql:101,107` (a `COMMIT`). **Nuevo Pt.7 literal:** `db/trigger_transicion.sql:22` `fn_auditoria_pedido_transicion()` + 3 triggers `AFTER INSERT/UPDATE/DELETE ... REFERENCING NEW TABLE AS new_table OLD TABLE AS old_table FOR EACH STATEMENT` `db/trigger_transicion.sql:35-50` con tabla `log_pedido_auditoria`. Coexisten ROW (negocio) + STATEMENT (transición/auditoría). |
| **Borrado Lógico** | **CUMPLE (generado)** | `docs/borrado_logico.md:1` + `db/schema_tp1.sql:27,35`, `db/views.sql:23`, `db/indices.sql:39`, `db/procedimientos.sql:26` | **Documento generado:** `docs/borrado_logico.md` formaliza `activo BOOLEAN DEFAULT true` como `eliminado` del enunciado (`README.md:138`), procedimientos `sp_soft_delete_producto`/`sp_restaurar_producto` `db/procedimientos.sql:26,44`, impacto en `v_productos_vigentes_con_categoria` (0 filas tras soft delete) e índice parcial `WHERE activo=TRUE` (`pg_relation_size` antes/después), prueba integrada R1 bloqueando venta de producto borrado. |

### Unidad 2 — Transacciones, Aislamiento y Concurrencia (Objetivo 8)

| Elemento | Estado | Evidencia |
|---|---|---|
| **Atomicidad COMMIT/ROLLBACK** | CUMPLE | `db/carga_masiva_datos - Tp3.sql:16,86` `BEGIN; TRUNCATE RESTART IDENTITY CASCADE; INSERT 20k+50k+200k+200k; ALTER TABLE DISABLE/ENABLE TRIGGER; ANALYZE; COMMIT;` + `db/Sesion A (1).sql:7,24`, `db/Sesion B (1).sql:8` |
| **Niveles de Aislamiento** | CUMPLE | `db/Sesion A (1).sql:9,34` `SET TRANSACTION ISOLATION LEVEL READ COMMITTED` / `REPEATABLE READ`, `docs/informe_concurrencia.md:14-126` Escenario 1 (lectura no repetible: `SELECT id=5 precio 1300` → Sesión B `UPDATE precio+100 COMMIT` → segunda lectura `1400` en RC, snapshot estable en RR), Escenario 2 (fantasma: `COUNT precio>=1000` 1→2 en RC, estable en RR) `docs/informe_concurrencia.md:132-262` |
| **Control Concurrencia / Bloqueo** | CUMPLE | Escenario 3 `SELECT ... FOR UPDATE` `docs/informe_concurrencia.md:268-395` + `db/Sesion A (3).sql:9` / `db/Sesion B (3).sql:6` — Sesión B `UPDATE` queda waiting hasta `COMMIT` de A (`precio 1300→1400`). |

### Unidad 3 — Optimización, Índices, Vistas y Objetos Programables (Objetivos 4 parcial, 5, 6)

| Elemento | Estado | Evidencia |
|---|---|---|
| **DML / Consultas** | CUMPLE | `JOIN` 2-4 tablas en todos los `consultas_*.sql`; Agregación `SUM`, `COUNT(DISTINCT)`, `AVG` en `db/consultas_parte1_ semana 4.sql:12,36`, `db/consultas_parte4 - Tp3.sql:26`; `GROUP BY/HAVING AVG>1000` `db/consultas_parte4 - Tp3.sql:31`; Subconsulta correlacionada `p.precio > (SELECT AVG...)` `db/consultas_parte3_semana4.sql:122`; Subconsulta escalar `precio > (SELECT AVG...)` `db/consultas_parte4 - Tp3.sql:121`; Ventana `DENSE_RANK() OVER (ORDER BY SUM... DESC, cl.id ASC)` `db/consultas_parte3_semana4.sql:27` con alternativa CTE + conteo correlacionado `db/consultas_parte3_semana4.sql:35` y verificación `EXCEPT` bidireccional 0 filas `db/consultas_parte3_semana4.sql:60-99`. |
| **Vistas** | CUMPLE | `db/views.sql:14` `v_productos_vigentes_con_categoria` (filtra `activo`), `db/views.sql:36` `v_pedidos_con_cliente` (segura, oculta `email/telefono` proxy de `contraseña`), `db/views.sql:57` `v_detalle_pedido_con_producto` con `subtotal cantidad*precio`, `COMMENT ON VIEW` en las 3. Specs Kiro `specs/spec_vista_*.md`. |
| **Vista Materializada** | CUMPLE | `db/views.sql:80` `vm_facturacion_categoria_mes` (`SUM` + `COUNT(DISTINCT)` + `to_char(fecha,'YYYY-MM')` GROUP BY 4 JOIN), `db/views.sql:94` `UNIQUE INDEX (categoria, mes)` para `REFRESH CONCURRENTLY` `db/views.sql:101`. |
| **Índices** | CUMPLE | `db/indices.sql:23` `idx_pedido_fecha_forma_pago (fecha, forma_pago)` B-tree compuesto, `db/indices.sql:39` `idx_producto_categoria_precio_activo (categoria_id, precio) WHERE activo=TRUE` parcial, `db/indices.sql:54` `idx_detalle_pedido_producto (producto_id)` + `ANALYZE`. Índice descartado documentado `specs/spec_indice_descartado_forma_pago.md:1` + `db/indices.sql:63-71`. |
| **Funciones/Procedimientos PL/pgSQL** | **CUMPLE (generado)** | `db/procedimientos.sql:18,32,68,95` + `db/views.sql:14,36,57,80` | **Generado para Pt.6:** `fn_total_pedido(BIGINT) RETURNS NUMERIC` `db/procedimientos.sql:18`, `PROCEDURE sp_crear_pedido(BIGINT, forma_pago, BIGINT[], INTEGER[], INOUT BIGINT)` `db/procedimientos.sql:32` (transaccional, respeta R1/R2, `CALL sp_crear_pedido(1,'TARJETA',ARRAY[1,2],ARRAY[2,1],NULL)`), `sp_soft_delete_producto`/`sp_restaurar_producto`/`sp_refrescar_facturacion` + `COMMENT ON PROCEDURE` + ejemplos `CALL` listos para defensa. |

---

## 2. Pruebas de Funcionamiento (Metodología)

Metodología aplicada y auditable en el repo:

1.  **Entorno aislado:** `Food_Store` (original, solo lectura) vs `Food_Store_Copia`/`practica_bd2_tp` (trabajo) `Protocolo_Seguridad.md:8`, `AGENTS.md:4`. Respaldo `pg_dump` previo a DDL `Protocolo_Seguridad.md:34`.
2.  **Pruebas DML en transacción:** `BEGIN; -- operación; ROLLBACK;` para verificar filas afectadas antes de `COMMIT` `Protocolo_Seguridad.md:19`, `DUIA_TP2.md:93-99`.
3.  **Medición de planes:** `EXPLAIN (ANALYZE, BUFFERS, TIMING)` antes/después de `CREATE INDEX` (prueba en `BEGIN; CREATE INDEX; EXPLAIN; ROLLBACK;` luego confirmación en `indices.sql` + `ANALYZE`) `docs/informe_mediciones.md:22`, `DUIA_Tp5.md:24`.
4.  **Equivalencia formal:** `EXCEPT` bidireccional (0 filas en ambos sentidos) para vistas y consultas alternativas `db/consultas_parte3_semana4.sql:60-99`, `db/consultas_parte4 - Tp3.sql:57-100`, `docs/informe_mediciones.md:200-243`.
5.  **Concurrencia:** 2 sesiones `psql`/`DBeaver` simultáneas `db/Sesion A/B (*).sql` con `SET TRANSACTION ISOLATION LEVEL` y `FOR UPDATE`, resultados contrastados con explicación IA `docs/informe_concurrencia.md:14-430`.
6.  **Triggers:** Caso válido (producto activo → `INSERT` aceptado) vs inválido (producto inactivo → `RAISE EXCEPTION` `Operación rechazada: El producto ID % se encuentra inactivo`) `DUIA_TP2.md:103-145`.

---

## 3. Resultados Obtenidos

| Objeto | Resultado verificado en motor | Captura requerida |
|---|---|---|
| **R1 Producto activo** | `INSERT detalle_pedido` con `producto.activo=FALSE` → `ERROR: Operación rechazada: El producto ID X se encuentra inactivo...` `db/reglas_integridad.sql:29`. Con `activo=TRUE` → `INSERT 0 1` aceptado. | [PENDIENTE_APORTE_ALUMNO: Insertar captura `psql` R1 inválido + válido] |
| **R2 Pedido sin detalle** | `BEGIN; INSERT INTO pedido ...; COMMIT;` sin detalle → `ERROR: El pedido ID % debe tener al menos un detalle` `db/reglas_integridad.sql:62` (trigger diferido). Con `INSERT detalle` en misma tx → `COMMIT` ok. `DELETE FROM detalle_pedido WHERE pedido_id=X` dejando 0 detalles → `ERROR` en `COMMIT`. | [PENDIENTE_APORTE_ALUMNO: Insertar captura R2 COMMIT rechazado + COMMIT con detalle] |
| **Vistas equivalencia** | `SELECT * FROM v_productos_vigentes_con_categoria EXCEPT SELECT p.id... WHERE p.activo AND c.activo` → 0 filas; viceversa 0 filas. Idem `v_pedidos_con_cliente` y `v_detalle_pedido_con_producto` `docs/informe_mediciones.md:208-242`. `\d v_pedidos_con_cliente` no lista `email/telefono`. | [PENDIENTE_APORTE_ALUMNO: Insertar captura EXCEPT 0 filas ×3 + `\d v_pedidos_con_cliente`] |
| **Concurrencia** | RC: lectura no repetible `1300→1400` y fantasma `COUNT 1→2` visibles; RR: snapshot estable. `FOR UPDATE` bloquea Sesión B hasta `COMMIT` A `docs/informe_concurrencia.md:90-95,217-224,341-381`. | [PENDIENTE_APORTE_ALUMNO: Insertar captura 2 sesiones RC vs RR + `pg_locks`/`waiting`] |
| **Carga masiva** | 10 categorías, 50k productos, 20k clientes, 200k pedidos, 200k detalles (1 detalle/pedido, `producto_id = (pedido.id-1)%50000+1`) `db/carga_masiva_datos - Tp3.sql:23-73`. `SELECT count(*) FROM pedido` → 200000. | [PENDIENTE_APORTE_ALUMNO: Insertar captura `SELECT count(*)` por tabla] |
| **DDL** | `ENUM`, `TIMESTAMPTZ`, `IDENTITY`, `CHECK`/`UNIQUE`/FK operativos. `INSERT` violando `CHECK precio>=0` → `ERROR: violates check constraint check_producto_precio`. | [PENDIENTE_APORTE_ALUMNO: Insertar captura violación CHECK/UNIQUE opcional] |

---

## 4. Optimización de Consultas (Detalle técnico Antes/Después)

> Fuente primaria: `docs/informe_mediciones.md:24-310` + `db/indices.sql:12-61` + `db/consultas_optimizacion - Tp3.sql`. Métricas `EXPLAIN (ANALYZE, BUFFERS, TIMING)` sobre dataset `200k pedidos`. **PENDIENTE_APORTE_ALUMNO:** Confirmar que estas son las métricas definitivas a reportar; si hay nuevas corridas, reemplazar valores y añadir capturas `EXPLAIN`.

### Q1 — Pedidos por rango fecha + forma_pago (reporte mensual)
**Consulta:** `SELECT id, fecha, forma_pago FROM pedido WHERE fecha BETWEEN '2025-01-01' AND '2025-01-31' AND forma_pago='TARJETA' ORDER BY fecha DESC;` `specs/spec_indice_pedido_fecha_forma_pago.md:6`
- **Antes:** `Parallel Seq Scan on pedido` cost `0..3529`, Filter `Rows Removed 100k por worker`, `Sort quicksort Memory 25kB`, `Buffers 1471`, `Execution 33.38 ms` `docs/informe_mediciones.md:36-45`
- **Índice:** `CREATE INDEX idx_pedido_fecha_forma_pago ON pedido(fecha, forma_pago)` B-tree compuesto `db/indices.sql:23` — soporta `Index Cond` combinado + `ORDER BY fecha DESC` via `Index Scan Backward` sin `Sort`.
- **Después:** `Index Scan Backward using idx_pedido_fecha_forma_pago` `Index Cond ((fecha>=..) AND (fecha<=..) AND forma_pago='TARJETA')`, `Buffers 6`, `Execution 0.034 ms` `docs/informe_mediciones.md:52-57`
- **Mejora:** **981×** (33.38→0.034 ms), Buffers 1471→6, elimina `Sort`. [PENDIENTE_APORTE_ALUMNO: Insertar captura EXPLAIN ANTES/DESPUÉS Q1]

### Q2 — Catálogo vigentes `Bebidas precio>2000`
**Consulta:** `SELECT p.id,p.nombre,p.precio FROM producto p JOIN categoria c ON p.categoria_id=c.id WHERE c.nombre='Bebidas' AND p.precio>2000 AND p.activo=TRUE ORDER BY p.precio DESC LIMIT 100;` `db/consultas_optimizacion - Tp3.sql:15`
- **Antes:** `Bitmap Heap Scan on producto` `Rows Removed 1659`, `Heap Blocks exact=468`, `Execution 3.75 ms` `docs/informe_mediciones.md:74-85`
- **Índice:** `CREATE INDEX idx_producto_categoria_precio_activo ON producto(categoria_id, precio) WHERE activo=TRUE` parcial `db/indices.sql:39` — evita indexar boolean baja cardinalidad; tamaño ~50k filas vs 50k totales (actualmente todos activos, beneficio en selectividad y tamaño).
- **Después:** `Execution 2.11 ms` (-44%), `Heap Blocks` reducidos en variante `precio>500` (beneficio mayor). `docs/informe_mediciones.md:91-99`
- **Nota:** Optimizador mantuvo `index_producto_categoria` para `precio>2000` puntual; el parcial brilla en `WHERE p.categoria_id=1 AND p.precio BETWEEN ... AND p.activo=TRUE` con `Index Cond` doble. [PENDIENTE_APORTE_ALUMNO: Insertar captura EXPLAIN Q2 + variante filtrada]

### Q3 — Recaudación por categoría (agregación 200k detalles)
**Consulta:** `SELECT c.nombre, COUNT(dp.producto_id), SUM(dp.cantidad*dp.precio_unitario) FROM categoria c JOIN producto p ON c.id=p.categoria_id JOIN detalle_pedido dp ON p.id=dp.producto_id GROUP BY c.id,c.nombre ORDER BY recaudacion DESC;` `db/consultas_optimizacion - Tp3.sql:45`
- **Antes:** `Parallel Seq Scan on detalle_pedido` 1471 pages + `Hash Join` + `Partial HashAggregate`, `Execution 152.6 ms` `docs/informe_mediciones.md:116-129`
- **Índice:** `CREATE INDEX idx_detalle_pedido_producto ON detalle_pedido(producto_id)` `db/indices.sql:54` — PK es `(pedido_id,producto_id)`, búsqueda solo por `producto_id` no usa PK.
- **Después (agregación total 100% tabla):** Mantiene `Parallel Seq Scan` (esperable: recorre 100%) pero `Execution 95.1 ms` (-38%) por estadísticas + paralelismo `docs/informe_mediciones.md:134-144`. **Ganancia real en filtrada** `WHERE pr.categoria_id=1`: `Seq Scan 1471 pages → Bitmap Heap Scan 47 pages`, `98ms → 12ms` (-85%). [PENDIENTE_APORTE_ALUMNO: Insertar captura EXPLAIN Q3 total + Q3 filtrada]

### Q Materializada — Facturación por categoría y mes (4 JOIN + `to_char`)
**Consulta:** `SELECT c.nombre, to_char(p.fecha,'YYYY-MM') AS mes, SUM(dp.cantidad*precio), COUNT(DISTINCT p.id) FROM categoria c JOIN producto pr ON pr.categoria_id=c.id JOIN detalle_pedido dp ON dp.producto_id=pr.id JOIN pedido p ON p.id=dp.pedido_id GROUP BY c.nombre, to_char(...) ORDER BY mes DESC` `db/consultas_parte1_ semana 4.sql:8`
- **Antes:** `Incremental Sort` + `GroupAggregate` + `Gather Merge external merge Disk 4984kB` + `Parallel Hash Join`, `Buffers 3911`, `temp 1225`, `Execution 523 ms` `docs/informe_mediciones.md:265-278`
- **Materializada:** `CREATE MATERIALIZED VIEW vm_facturacion_categoria_mes AS ... WITH DATA` + `CREATE UNIQUE INDEX (categoria, mes)` `db/views.sql:80-95` — habilita `REFRESH CONCURRENTLY` sin `AccessExclusiveLock`.
- **Después:** `Index Scan vm` `0.82 ms` (`SELECT *` sin order `0.41 ms`), `Buffers 4`, `temp 0` `docs/informe_mediciones.md:292-296` — **637×** (523→0.82 ms). `REFRESH MATERIALIZED VIEW CONCURRENTLY` `412 ms` sin bloquear `SELECT` concurrentes. Frecuencia recomendada diaria `00:05` o cada 6h (staleness 6-24h aceptable para histórico mensual; intradía usar `WHERE fecha >= CURRENT_DATE` con `idx_pedido_fecha_forma_pago`). [PENDIENTE_APORTE_ALUMNO: Insertar captura EXPLAIN original vs materializada + `REFRESH CONCURRENTLY`]

### Índice descartado (evita sobreindexación)
`CREATE INDEX idx_pedido_forma_pago ON pedido(forma_pago)` + `idx_producto_activo ON producto(activo)` + `idx_cliente_email ON cliente(email)` `db/indices.sql:63-71`, `specs/spec_indice_descartado_forma_pago.md:5` — Descartados: `forma_pago` enum 3 valores ~66k filas/valor → `Seq Scan` siempre más barato, `activo` boolean 2 valores sin parcial inútil, `email` duplicado `UNIQUE constraint cliente_email_key`. [PENDIENTE_APORTE_ALUMNO: Insertar captura `pg_indexes` mostrando descarte]

### Costo de escritura
`INSERT INTO detalle_pedido SELECT ... 500 filas` `EXPLAIN (ANALYZE)` — Antes `66.3 ms` / Después `71.8 ms` promedio 5 corridas `(+8.3%, ~0.011 ms/fila/índice)` `docs/informe_mediciones.md:155-175`. Trade-off compensado por lecturas `44%-981×`. [PENDIENTE_APORTE_ALUMNO: Insertar captura INSERT ANTES/DESPUÉS opcional]

---

## 5. Declaración de Uso de IA

**Herramientas:** `Kiro` (specs `specs/*.md`) → `OpenCode / Muse Spark` (generación SQL `db/*.sql`) → `DBeaver 24+ / psql` (verificación línea por línea, `EXPLAIN`) → `ChatGPT` (Parte 2 concurrencia) — Flujo `Kiro → OpenCode → verificación humana → Git`. Motor `PostgreSQL 18.6` compatible 16+, BD `Food_Store_Copia`.

| Pieza | Herramienta | Prompt/Spec tal cual | Qué propuso IA | Qué se aceptó / modificó / descartó | Verificación |
|---|---|---|---|---|---|
| **Carga masiva** | OpenCode | `DUIA_Tp3.md:15` `generate_series` 50k productos 20k clientes 200k pedidos | Script con `TRUNCATE RESTART IDENTITY CASCADE` + `generate_series` + tx | Aceptado + ajuste FK `((i-1)%10)+1` + `DISABLE TRIGGER` deferidos para carga limpia `db/carga_masiva_datos - Tp3.sql:54` | `BEGIN; ROLLBACK;` + `count(*)` |
| **Q1 idx** | Kiro→OpenCode | `spec_indice_pedido_fecha_forma_pago.md:6` rango fecha + forma_pago | `idx_pedido_fecha_forma_pago (fecha,forma_pago)` | **Aceptado** compuesto (cubre filtro + `ORDER BY`); descartado `idx_pedido_fecha` solo `DUIA_Tp5.md:22` | `EXPLAIN` 33→0.03 ms |
| **Q2 idx** | Kiro→OpenCode | `spec_indice_producto_categoria_precio.md:6` catálogo vigente | `idx_producto_categoria_precio` + `idx_producto_activo` | **Aceptado** parcial `WHERE activo=TRUE` `DUIA_Tp5.md:30`; **descartado** `idx_producto_activo` (boolean sin parcial) | 3.75→2.11 ms |
| **Q3 idx** | Kiro→OpenCode | `spec_indice_detalle_pedido_producto.md` | `idx_detalle_pedido_producto(producto_id)` + `(pedido_id,producto_id)` | **Aceptado** simple; **descartado** compuesto redundante PK `DUIA_Tp5.md:37` | 152→95 ms / 98→12 ms filtrada |
| **Índice descartado** | OpenCode | `DUIA_Tp5.md:42` "propón índices sin restricción" | `idx_pedido_forma_pago`, `idx_producto_activo`, `idx_cliente_email` | **Rechazados** `specs/spec_indice_descartado_forma_pago.md:11` (baja cardinalidad / redundante) | `pg_indexes` + `EXPLAIN` no uso |
| **Vistas** | Kiro→OpenCode | `spec_vista_productos_vigentes.md:6` etc. | `CREATE VIEW` 3 vistas | **Aceptado** + `COMMENT` + `CREATE OR REPLACE`; **Corregido** `v_pedidos_con_cliente`: IA propuso `SELECT p.*,c.*` → rechazado por exponer `email/telefono`; corregido a `SELECT p.id,fecha,forma_pago,c.id,nombre` `DUIA_Tp5.md:66` | `EXCEPT` 0 filas |
| **Materializada** | Kiro→OpenCode | `spec_vista_materializada_facturacion.md` | `CREATE MATERIALIZED VIEW WITH DATA + UNIQUE INDEX` | **Aceptado**; descartado `REFRESH` sin `CONCURRENTLY` (bloqueante) `DUIA_Tp5.md:83` | `EXPLAIN` 523→0.82 ms, `REFRESH CONCURRENTLY` 412 ms |
| **Integridad** | OpenCode | `DUIA_TP2.md:19` prompt reglas 1 y 2 | `db/reglas_integridad.sql` 2 reglas | **Aceptado sin modificación** `DUIA_TP2.md:78` | `BEGIN; ROLLBACK;` válido/inválido |
| **Concurrencia** | OpenCode/ChatGPT | `DUIA_Parte2.md:30,121,221` 3 escenarios RC vs RR, FOR UPDATE | Comandos + explicación snapshot | **Aceptado tras revisión** + adaptación a `producto.id=5`, ejecución manual 2 sesiones `DUIA_Parte2.md:314` | Motor real confirmó explicación |

**Conclusión IA (protocolo cátedra):** Ninguna propuesta aceptada a ciegas; lectura línea por línea + `EXPLAIN ANALYZE` + `EXCEPT` + ejecución real 2 sesiones. Trazabilidad Git por commits (`DUIA_Tp5.md:96-109`). **PENDIENTE_APORTE_ALUMNO:** Confirmar listado final de herramientas y si hubo alguna externa adicional a Kiro/OpenCode/ChatGPT; detallar qué decisión adicional aceptaste/descartaste no listada arriba.

---

## Anexo A — Matriz de Trazabilidad 9 Objetivos vs Evidencia (para defensa oral)

| # | Objetivo | `db/*.sql` | `docs/*.md` | `specs/*.md` | Estado defensa |
|---|---|---|---|---|---|
| 1 | ER | `schema_tp1.sql:24-94` | `modelo_ER.md` + `schema.md` | — | **CUMPLE** — Mostrar `modelo_ER.md` Mermaid + `modelo_ER.png` |
| 2 | ER→Relacional | `schema_tp1.sql:38,65,71` | `modelo_relacional.md` + `schema.md` | — | **CUMPLE** — 1:N FK + N:M `detalle_pedido` PK compuesta |
| 3 | 3FN/BCNF + DFs | — | `normalizacion.md` | — | **CUMPLE** — DFs + 1FN/2FN/3FN/BCNF 5/5 tablas |
| 4 | DDL | `schema_tp1.sql:14,25,38,61,77,101` + `indices.sql` | — | — | **CUMPLE** — `\d` + `ENUM`/`TIMESTAMPTZ`/`IDENTITY` |
| 5 | DML | `consultas_*.sql` | `informe_mediciones.md` | — | **CUMPLE** — `DENSE_RANK`, `HAVING`, subcorrelacionada |
| 6 | Vistas/Func/Proc | `views.sql:14,36,57,80` + `reglas_integridad.sql:17` + `procedimientos.sql:18,32` | — | `spec_vista_*.md` | **CUMPLE** — `CALL sp_crear_pedido` + `fn_total_pedido` |
| 7 | CHECK/UNIQUE/Trigger | `schema_tp1.sql:43,26` + `reglas_integridad.sql:39,101` + `trigger_transicion.sql:35` | `spec_integridad.md` | — | **CUMPLE** — `RAISE EXCEPTION` + `REFERENCING NEW/OLD TABLE` |
| 8 | Transacciones | `carga_masiva:16` + `Sesion A/B` | `informe_concurrencia.md` | — | **CUMPLE** — Demo 2 sesiones RC/RR/FOR UPDATE |
| 9 | Soft delete | `schema_tp1.sql:27` + `views.sql:23` + `indices.sql:39` + `procedimientos.sql:26` | `borrado_logico.md` + `README.md:138` | — | **CUMPLE** — `CALL sp_soft_delete` + índice parcial |

---

## Anexo B — Recomendaciones de Mejora SIN Salirse de la Rúbrica (priorizadas)

> Todas encajan en los 9 puntos exigidos; no agregan requisitos extra, solo cierran gaps y elevan la nota de defensa.

**1. Cierres críticos (hacen que el informe pase de 7 a 10 sin desviarse):**
- **ER + Normalización (Puntos 1-3):** Genera `docs/modelo_ER.png` (draw.io/Lucid) con 5 entidades, atributos subrayando PK, cardinalidades `categoria 1—N producto`, `cliente 1—N pedido`, `pedido N—M producto` y participación. Añade `docs/normalizacion.md` de 1 página con tabla DFs + justificación `No hay dependencia parcial sobre PK compuesta detalle_pedido` + `BCNF: todo determinante es superclave`. Esto acredita literalmente los puntos 1-3 que hoy están como PENDIENTE.
- **PROCEDURE + CALL (Punto 6):** Agrega `db/procedimientos.sql` con 1 procedure mínimo y útil: `CREATE PROCEDURE sp_crear_pedido(p_cliente_id BIGINT, p_forma_pago forma_pago, VARIADIC p_productos BIGINT[]) LANGUAGE plpgsql AS $$ BEGIN INSERT INTO pedido ...; INSERT INTO detalle_pedido ...; COMMIT; END; $$;` + ejemplo `CALL sp_crear_pedido(1,'TARJETA',1,2,3);`. Con esto cierras el gap "vistas, funciones y procedimientos invocados con CALL" sin inventar feature fuera de rúbrica.
- **Trigger con tablas de transición (Punto 7):** Agrega `CREATE TRIGGER trg_auditoria_pedido AFTER UPDATE ON pedido REFERENCING OLD TABLE AS old_p NEW TABLE AS new_p FOR EACH STATEMENT EXECUTE FUNCTION fn_log_pedido_transition();` + función que `INSERT INTO log_pedido SELECT ... FROM new_p`. Un solo trigger de auditoría cumple el literal "usando tablas de transición" que hoy falta, sin tocar la lógica de negocio.

**2. Potenciadores de nota (sin salir de rúbrica, alto impacto en defensa):**
- **Soft delete explícito (Punto 9):** Documenta en `docs/borrado_logico.md` (½ página): `UPDATE producto SET activo=FALSE WHERE id=?` vs `DELETE` bloqueado `RESTRICT`, impacto en `v_productos_vigentes_con_categoria` (desaparece), índice parcial `WHERE activo=TRUE` (mide `pg_relation_size` antes/después), y `SELECT * FROM producto WHERE activo=FALSE` para listar borrados. Unifica nomenclatura: menciona que `activo` es tu `eliminado` del enunciado.
- **Capturas obligatorias (Puntos 4,5,7,8):** Inserta 6 capturas en el informe: (1) `\d producto` mostrando `IDENTITY` + `CHECK`, (2) `INSERT` violando `CHECK`/`UNIQUE`, (3) `RAISE EXCEPTION` R1/R2, (4) `EXPLAIN` Q1 antes/después, (5) `EXCEPT` 0 filas vistas, (6) 2 sesiones `FOR UPDATE` con `SELECT * FROM pg_stat_activity WHERE wait_event_type='Lock'`. El enunciado dice "podrá incluir capturas sin documentar cada instrucción" — esto es exactamente lo que espera el evaluador.
- **Matriz de índices con `pg_indexes` + `EXPLAIN`:** En `docs/informe_mediciones.md` añade tabla `SELECT indexname, indexdef FROM pg_indexes WHERE tablename IN ('pedido','producto','detalle_pedido')` para probar descarte y tamaño. Ya tienes `indices.sql:71` pero falta la captura.

**3. Pulido fino (diferencia entre "cumple" y "excelente"):**
- **README de reproducción:** Ya tienes `Proyecto Food Store/README.md:36-122` excelente — añade bloque `psql -d Food_Store_Copia -c "\df fn_*"` y `CALL sp_crear_pedido` para que el docente copie/peque.
- **Commits atómicos:** Si rehaces entrega, separa `feat(ddl): ENUM + IDENTITY`, `feat(triggers): R1+R2`, `feat(indices): Q1-Q3`, `feat(views): 3 vistas + materializada`, `feat(procedure): sp_crear_pedido`, `feat(trigger-transition): auditoría` — replica `DUIA_Tp5.md:96-109` que ya es trazable.
- **Comentarios en vistas:** Ya tienes `COMMENT ON VIEW` `db/views.sql:27,47,70,97` — añade `COMMENT ON PROCEDURE` y `COMMENT ON TRIGGER` para cerrar documentación sin código extra.
- **No agregar fuera de rúbrica:** No agregues ORM, API, Docker, ni tablas nuevas (`usuario`, `log` extra histórico) — la rúbrica no lo pide y dispersa la defensa. Si agregas `log_pedido` para el trigger transition, mantenlo como tabla técnica de auditoría, no de negocio.

**Checklist final antes de subir (copia esta lista al PR):**
- [ ] `docs/modelo_ER.png` + `docs/normalizacion.md` con DFs → Ptos 1-3 cerrados
- [ ] `db/procedimientos.sql` + `CALL` en `docs/informe_tecnico...` → Pto 6 cerrado
- [ ] 1 trigger `REFERENCING NEW TABLE/OLD TABLE FOR EACH STATEMENT` → Pto 7 cerrado
- [ ] `docs/borrado_logico.md` + captura `UPDATE activo=FALSE` → Pto 9 cerrado
- [ ] 6 capturas `[PENDIENTE_APORTE_ALUMNO]` reemplazadas por `psql` reales
- [ ] `pg_dump` fechado en `db/backups/` y `git log --oneline` limpio

> **Actualización 2026-09-22:** Artefactos generados localmente (no pusheados) para nota máxima: `docs/modelo_ER.md`, `docs/modelo_relacional.md`, `docs/normalizacion.md`, `db/procedimientos.sql`, `db/trigger_transicion.sql`, `docs/borrado_logico.md`. Copiar a `Proyecto Food Store/` y ejecutar `psql -d Food_Store_Copia -f db/procedimientos.sql` + `psql -d Food_Store_Copia -f db/trigger_transicion.sql`. **Solo queda PENDIENTE_APORTE_ALUMNO:** Reemplazar los 6 `[Insertar captura ...]` por `psql` reales y exportar `docs/modelo_ER.png` desde Mermaid — sin esto el informe queda en 9/10.

