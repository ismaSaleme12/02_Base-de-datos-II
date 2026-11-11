# BITACORA.md — Uso de IA en TP Unidad 8

**Food Store · Base de Datos II · 2026-11-01**
**TP:** Food Store en la feria — la base de la tablet y el cierre de la capa de datos

Registro de las interacciones con IA durante el TP 8. La regla que se sostuvo en
todo el trabajo: **la IA propone, la ejecución dispone**. Ninguna afirmación se
aceptó sin correrla contra la base real.

---

## Tabla de interacciones

| # | Prompt enviado a la IA | Respuesta relevante recibida (resumen) | Validación o corrección humana aplicada |
|---|---|---|---|
| 1 | "Leé el PDF del TP 8 y decime qué pide exactamente, consigna por consigna" | Resumen de las 4 consignas + detección de que el TP exige una base **aparte** para `pruebas_sqlite.sql` | Validado contra el PDF. Se detectó que `AGENTS.md` apuntaba a `practica_bd2_tp`, que **no existe**; la base real es `Food_Store_Copia` |
| 2 | "Diseñá el esquema SQLite de la tablet: catálogo, borradores y cola de sync" | 4 tablas `STRICT`, dinero en centavos `INTEGER`, `id_local` UUID con `CHECK GLOB` | Se aceptó el diseño base. Se **rechazó** poner `UNIQUE` en `cola_sync.id_local`: el caso C2 necesita dos solicitudes sobre el mismo borrador |
| 3 | "Escribí el semáforo: compará cada borrador contra la instantánea y decidí verde/amarillo/rojo" | `UPDATE … FROM` con CTE de dos niveles; cuatro motivos de rojo, un amarillo | Se aceptó la estructura. Se **corrigió** la precedencia: el orden de los `CASE` define qué motivo ve el vendedor, y el original reportaba "sin stock" para productos dados de baja |
| 4 | "¿Cómo exporto 50.000 filas de PostgreSQL a SQLite sin perder tipos?" | `\copy … CSV HEADER` + `.import --csv --skip 1` + tabla de aterrizaje no STRICT | Ejecutado. Aparecieron **dos bugs reales** (§1 y §2 abajo) que la IA no anticipó |
| 5 | "Armá los casos C2 a C6 con productos reales del catálogo" | Un archivo por caso + un driver PowerShell que orquesta la secuencia completa | Se aceptó. Se eligieron productos con stock real (95 con stock 3 para C3; 2, 4, 5, 6 con stock holgado para el resto) |
| 6 | "Revisá el código de las unidades anteriores y encontrá hallazgos reales" | Cuatro hallazgos candidatos: índice `forma_pago`, `REVOKE` por columna, `GRANT` dentro de `DO`, ausencia de regla de stock | Los cuatro se **verificaron ejecutando** (`tp8_code_review_verificaciones.sql`). Uno obligó a **corregir la justificación de U3** (§3) |
| 7 | "Escribí la spec de Kiro: requirements en EARS, design y tasks" | REQ-01…REQ-04 atados a C2/C3/C4/C6; design con precedencia, idempotencia y alternativas descartadas | Se aceptó. Se agregó explícitamente el alcance: la idempotencia de la tablet **no** es la protección real, y eso quedó documentado en `design.md §6` |

---

## Caso más significativo: `'t' = 1` es falso en SQLite

**El bug más peligroso del TP, porque era silencioso.**

`psql` exporta los booleanos de PostgreSQL como `t` y `f`. El semáforo comparaba:

```sql
WHEN s.eliminado = 1  THEN 'producto …: dado de baja'
WHEN s.disponible = 0 THEN 'producto …: no disponible (sin stock)'
```

En SQLite no hay conversión implícita de texto a número, y además **cualquier
texto es mayor que cualquier número**:

```sql
SELECT 't' = 1;   -- 0
SELECT 'f' = 0;   -- 0
```

Resultado: los motivos 2 y 3 del semáforo **nunca se disparaban**. Un producto
dado de baja podía salir `SIMULADO_APROBADO`. Y el error no daba excepción: el
chequeo de stock podía taparlo en algunos casos y en otros no.

**Cómo se detectó:** no leyendo el código, sino corriendo el caso C4 (producto 6
dado de baja) y viendo que el estado esperado era `RECHAZADO` y el obtenido no.

**Cómo se corrigió:** no parcheando el semáforo con `CAST`, sino **normalizando
una sola vez al aterrizar la instantánea** (`cargar_snapshot.sql §2`). Una sola
frontera de conversión, no N comparaciones frágiles repartidas por el código.
Además se agregó un control que verifica que ninguna fila quede fuera de `{0,1}`.

**Lección:** un `CHECK` de dominio en la tabla de destino no protege si el dato
entra por una bandeja de texto. La validación tiene que estar en la frontera.

---

## Segundo caso: `.import --skip 1` sobre una tabla inexistente

Se documentó el comando como:

```text
sqlite3 foodstore_movil.db ".import --csv --skip 1 servidor_snapshot.csv snapshot_servidor"
```

Si `snapshot_servidor` **no existe**, `sqlite3` la crea usando la primera fila que
ve como nombres de columna. Con `--skip 1`, esa "primera fila" es el **primer
producto**, no el encabezado: la tabla se crea con columnas llamadas `1`,
`Producto 1`, `186853`… y se pierde una fila del catálogo.

**Cómo se detectó:** el control de entrada de `cargar_snapshot.sql` reportó
`filas = 49999` cuando el CSV tenía 50.001 líneas.

**Cómo se corrigió:** `schema_snapshot.sql` crea la tabla **antes** del `.import`.
El `--skip 1` sólo tiene sentido si la tabla ya existe, y así quedó documentado
en el encabezado de `cargar_snapshot.sql`.

---

## Tercer caso: `INSERT … SELECT … ON CONFLICT` es ambiguo

El UPSERT de `producto_cache`:

```sql
INSERT INTO producto_cache (...)
SELECT ... FROM snapshot_servidor AS s
ON CONFLICT (id) DO UPDATE SET ...
```

SQLite falla con `near "DO": syntax error`. El parser no puede decidir si el
`ON` pertenece al `INSERT` o al `SELECT` — es ambiguo.

**Corrección:** agregar `WHERE true` antes del `ON CONFLICT`, que fuerza a cerrar
el `SELECT`. No es decorativo: sin esa línea el script no corre.

---

## Cuarto caso: la justificación de U3 estaba mal

En la Unidad 3 se descartó el índice `pedido(forma_pago)` argumentando que
*"el optimizador hará Seq Scan igualmente"*.

**Verificado en este TP: es falso.** El planner **sí** usa el índice
(`Bitmap Index Scan on idx_tp8_prueba_forma_pago`). El motivo real para
descartarlo es más fuerte: lee **las 1471 páginas igual**, porque el 33% de las
filas está en casi todas las páginas de la tabla. No ahorra I/O; sólo agrega
costo de escritura y 4 MB.

**Consecuencia:** se corrigió la justificación en el informe del TP 8 sin tocar
la decisión (el índice sigue descartado, ahora por el motivo correcto). Una
decisión acertada con un argumento equivocado es una decisión que no se puede
defender.

---

## Quinto caso: la herramienta de orquestación también se equivoca

El driver `simular_casos.ps1` tenía dos defectos propios, encontrados al correrlo:

1. **`Select-Object -First 120` sobre el pipeline mató el script a mitad de
   camino.** En PowerShell, `Select-Object -First N` cierra el pipeline y el
   proceso que escribe recibe un error de pipe roto. La simulación se cortó
   después de C2 y faltaron C4 y C6. Se corrigió redirigiendo con `*>` a un
   archivo y leyéndolo después.
2. **La función `SQ` sólo tomaba el primer argumento.** `SQ ".headers on" "SELECT …"`
   ejecutaba `.headers on` y descartaba la consulta: dos secciones de la evidencia
   salieron vacías. Se corrigió con `@args`.

Ninguno de los dos era un error de SQL: los dos eran errores de la herramienta que
corre el SQL. **Una evidencia incompleta puede parecer una evidencia correcta** —
por eso la corrida final se hizo desde cero y se verificó el conteo de líneas
(348) y cada uno de los cinco estados.

---

## Lo que la IA propuso y se rechazó

| Propuesta de la IA | Por qué se rechazó |
|---|---|
| `UNIQUE` en `cola_sync.id_local` | Impide modelar C2: dos solicitudes sobre el mismo borrador |
| Tabla `venta` en SQLite | Convertiría un `SIMULADO_APROBADO` en una venta confirmada |
| Un solo booleano `activo` en `producto_cache` | Colapsa los motivos 3 y 4 del semáforo |
| `REAL` para los precios | Error de redondeo en la conciliación de caja |
| Resolver el conflicto de precio automáticamente | Alguien tiene que decidir si el cliente acepta pagar más |
| Confiar en la PK de la tablet como idempotencia suficiente | Falla si el UUID cambia (reinicio de la tablet); la protección real va en el servidor |

---

## Historial Git

```text
feat(movil): esquema SQLite de la tablet (4 tablas STRICT) + pruebas
feat(snapshot): vista v_snapshot_movil + exportacion CSV + carga normalizada
feat(semaforo): precedencia de cuatro motivos de rojo + idempotencia
test(casos): C2, C3, C4, C5, C6 con evidencia real de ejecucion
test(invariantes): pedidos y stock identicos a la linea de base
docs(review): cuatro hallazgos verificados + correccion de justificacion U3
docs(kiro): requirements, design y tasks del change tp8-sincronizacion-tablet
docs(bitacora): interacciones con IA y errores reales detectados
```

(Ver `git log --oneline` para los hashes vigentes.)
