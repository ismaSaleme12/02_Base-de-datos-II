# design.md — Food Store: sincronización de la tablet en la feria

**Proyecto:** Food Store · Base de Datos II · TP 8 (Unidad 8)
**Change:** `tp8-sincronizacion-tablet`
**Deriva de:** `requirements.md` (REQ-01 … REQ-04)

---

## 1. Principio que ordena todo el diseño

> **El móvil propone, el servidor dispone.**

La tablet puede **leer** una copia del catálogo y **armar** borradores. No puede
confirmar precios, no puede descontar stock y no puede crear pedidos. Todo lo
que la tablet decide es, en el mejor de los casos, una **simulación** de lo que
el servidor *habría* aceptado.

De ahí sale una regla de diseño que atraviesa el esquema: **en SQLite no hay
tabla de ventas**. Si existiera, alguien la podría llenar y creería que vendió.
Lo único que hay es una cola de solicitudes con cuatro estados, y el mejor de
ellos se llama `SIMULADO_APROBADO` — no `APROBADO`, no `CONFIRMADO`, no `VENTA`.

| Motor | Rol | Puede escribir |
|---|---|---|
| PostgreSQL | fuente de verdad | pedidos, stock, precios |
| SQLite (tablet) | copia + borradores + cola | sólo su propia base local |
| Snapshot (CSV) | mensajero de una sola dirección | nada: es un archivo |

**La tablet nunca escribe en PostgreSQL.** No hay conexión, no hay credenciales,
no hay driver. El único canal es un CSV exportado por el servidor.

---

## 2. Arquitectura en tres capas

```
┌──────────────────────────────────────────────────────────────────────┐
│  POSTGRESQL  ·  Food_Store_Copia                                     │
│                                                                      │
│   producto ──► v_snapshot_movil ──► \copy ... TO CSV                 │
│   (50.000 filas, precio en numeric, activo boolean)                  │
└───────────────────────────┬──────────────────────────────────────────┘
                            │  servidor_snapshot.csv  (una dirección)
                            │  50.000 filas · 2,7 MB · fecha_copia sellada
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│  SQLITE  ·  foodstore_movil.db                                       │
│                                                                      │
│   1. snapshot_servidor   bandeja de aterrizaje (no STRICT, texto)    │
│           │  normaliza 't'/'f' → 1/0                                 │
│           ▼                                                          │
│   2. producto_cache      catálogo de sólo lectura (STRICT)           │
│           ▲                                                          │
│           │ FK RESTRICT                                              │
│   3. pedido_borrador ──► item_borrador                               │
│           ▲                                                          │
│           │ FK CASCADE                                               │
│   4. cola_sync           una fila = una solicitud de validación      │
│           │                                                          │
│           ▼  semaforo.sql (lee la bandeja, escribe el estado)        │
│      PENDIENTE ──► SIMULADO_APROBADO | CONFLICTO | RECHAZADO         │
└──────────────────────────────────────────────────────────────────────┘
                            │
                            ▼  (fuera de alcance del TP)
                   el servidor decide y confirma
```

### 2.1 Por qué una tabla de aterrizaje y no importar directo

`snapshot_servidor` **no es una tabla de dominio**. Es una bandeja: recibe el CSV
tal cual viene, sin juzgarlo, y se descarta en la próxima carga.

Hay dos motivos concretos, los dos verificados en este TP:

1. **`psql` exporta booleanos como `'t'`/`'f'`.** Una tabla `STRICT` con columnas
   `INTEGER` rechaza la importación en la primera fila. La bandeja los acepta
   como texto y los normaliza en un `UPDATE` explícito.
2. **Si el CSV viene mal, el error se ve acá.** Un `id` no numérico, una fila
   vacía o un `stock` negativo quedan visibles en la bandeja antes de tocar la
   cache. Importar directo contra `producto_cache` mezclaría el problema de
   transporte con el de dominio.

Las afinidades sí están declaradas (`INTEGER`, `TEXT`): si los números
aterrizaran como texto, la comparación del semáforo sería **lexicográfica** y en
SQLite cualquier texto es mayor que cualquier número — `'9' > 150000` sería
verdadero. Ese bug no da error, da veredictos equivocados.

---

## 3. Modelo de datos de la tablet

### 3.1 Las cuatro tablas

| Tabla | Qué representa | Restricciones que importan |
|---|---|---|
| `producto_cache` | el catálogo que el vendedor puede ver | `STRICT`, precios y stock `>= 0`, booleanos en `{0,1}` |
| `pedido_borrador` | un pedido armado sin señal | `id_local` UUID con `CHECK GLOB`, `forma_pago` con el dominio del ENUM |
| `item_borrador` | los renglones del borrador | PK `(id_local, producto_id)`, `cantidad > 0`, FK a producto `RESTRICT` |
| `cola_sync` | la bandeja de salida | `solicitud_uuid` PK, `estado` en 4 valores, `id_local` **sin** UNIQUE |

### 3.2 Decisiones que no son obvias

**`STRICT` en las cuatro tablas de dominio.** SQLite acepta cualquier cosa en
cualquier columna por defecto. En una base que va a vivir en una tablet, sin
administrador, sin backups y sin logs, eso es una bomba: un `INSERT` con
`'diez'` en `cantidad` se guarda sin chistar y explota tres días después.
`STRICT` convierte ese problema en un error inmediato y localizable.

**Dinero en centavos, `INTEGER`, nunca `REAL`.** `0.1 + 0.2 != 0.3` en punto
flotante. Un total de pedido calculado con `REAL` puede diferir un centavo del
que calcula PostgreSQL con `numeric`. En una conciliación de caja eso es un
descuadre. Se guarda `186853`, no `1868.53`.

**`item_borrador.producto_id` con `ON DELETE RESTRICT`.** Si fuera `CASCADE`,
borrar un producto de la cache borraría en silencio el renglón de un borrador
ya armado. El vendedor vería el pedido desaparecer. La baja es **lógica**
(`eliminado = 1`), nunca física.

**`cola_sync.id_local` no es UNIQUE.** Un mismo borrador puede generar varias
solicitudes a lo largo del tiempo. El caso C2 lo exige: primero una solicitud
que termina en `CONFLICTO` (precio viejo), después de que el cliente acepta el
precio nuevo, una **solicitud nueva con UUID nuevo** sobre el mismo borrador. La
solicitud vieja se conserva como registro histórico: no se reescribe. Si
`id_local` fuera UNIQUE, el caso C2 no se podría modelar.

**`producto_cache.eliminado` existe en vez de borrar la fila.** Si el producto 6
se diera de baja borrando la fila, el borrador histórico perdería su clave
foránea y no se podría distinguir *"dado de baja"* de *"nunca existió"*. Son dos
incidentes distintos para quien atiende el conflicto, y el vendedor merece saber
cuál de los dos le pasó.

### 3.3 Los dos booleanos no son lo mismo

| Columna | Significado | Se calcula como |
|---|---|---|
| `disponible` | se puede vender **ahora** | `activo AND stock > 0` |
| `eliminado` | el producto **ya no existe** comercialmente | `NOT activo` |

Podrían parecer redundantes. No lo son: si `disponible` fuera sólo `activo`, el
motivo *"no disponible (sin stock)"* nunca se dispararía — todo producto activo
sería "disponible" y el rojo por stock se confundiría con el rojo por cantidad.
Separarlos mantiene **cuatro motivos de rojo distinguibles** (§4.2).

---

## 4. El semáforo (`semaforo.sql`)

### 4.1 Qué hace exactamente

Para cada solicitud en `PENDIENTE`, recorre sus ítems, los cruza con la
instantánea del servidor y escribe **un** estado y **un** motivo.

**No modifica `producto_cache`. No toca PostgreSQL. No descuenta stock.**

### 4.2 Precedencia: rojo gana siempre

Los cuatro motivos de rojo se evalúan **en orden** y el primero que aplica gana:

| # | Condición | Motivo |
|---|---|---|
| 1 | el producto no está en la instantánea | `no existe en el servidor` |
| 2 | `eliminado = 1` | `dado de baja` |
| 3 | `disponible = 0` | `no disponible (sin stock)` |
| 4 | `cantidad > stock_visto` | `no alcanza el stock (pide N, hay M)` |

El orden importa porque los casos se solapan. Un producto dado de baja también
tiene `disponible = 0`. Si se evaluara al revés, el motivo que vería el vendedor
sería *"sin stock"* cuando la verdad es *"lo sacaron del catálogo"* — y el
vendedor perdería diez minutos buscando stock de algo que ya no se vende.

**El amarillo sólo aparece si no hay ningún rojo.** Un pedido con un precio
cambiado *y* un producto inexistente es `RECHAZADO`, no `CONFLICTO`. Reportar el
conflicto de precio cuando el pedido igual no puede pasar sería ruido.

### 4.3 La trampa que costó un bug real

`psql` escribe `t`/`f`. En SQLite:

```sql
SELECT 't' = 1;   -- 0  (falso)
SELECT 'f' = 0;   -- 0  (falso)
```

No hay conversión implícita, y **cualquier texto es mayor que cualquier número**.
Con la comparación `s.eliminado = 1` contra un `'t'` en texto, los motivos 2 y 3
quedaban **muertos**: nunca se disparaban y esas solicitudes caían en verde. El
error era silencioso porque el chequeo de stock podía taparlo en algunos casos.

La corrección no fue parchear el semáforo, sino **normalizar una sola vez, al
aterrizar la instantánea** (`cargar_snapshot.sql §2`). Una sola frontera de
conversión, no N comparaciones frágiles repartidas por el código.

### 4.4 Idempotencia del semáforo

El `WHERE c.estado = 'PENDIENTE'` está **dos veces**: en el CTE y en el `UPDATE`.
Una solicitud ya resuelta no se vuelve a evaluar. Correr el script dos veces
seguidas no cambia nada, ni "aprueba" dos veces lo mismo.

Esto se probó (caso C6): el `group_concat` de `uuid=estado` antes y después de
una segunda corrida es idéntico.

---

## 5. Secuencia de una sincronización

```
TABLET                          SERVIDOR (PostgreSQL)
  │                                   │
  │  1. arma el borrador              │
  │     pedido_borrador + items       │
  │     (precio_centavos_visto)       │
  │                                   │
  │  2. encola la solicitud           │
  │     cola_sync (PENDIENTE)         │
  │                                   │
  │  3. recupera señal                │
  │     ─────────────────────────────►│  \copy v_snapshot_movil → CSV
  │                                   │  (fecha_copia sellada en origen)
  │◄───────────────────────────────── │
  │                                   │
  │  4. aterriza el CSV               │
  │     snapshot_servidor             │
  │     normaliza t/f → 1/0           │
  │     UPSERT → producto_cache       │
  │                                   │
  │  5. corre el semáforo             │
  │     PENDIENTE → estado            │
  │                                   │
  │  6. si hay CONFLICTO:             │
  │     alguien decide                │
  │     ── el cliente acepta ──       │
  │     actualiza precio visto        │
  │     encola solicitud NUEVA        │
  │     (UUID nuevo, mismo id_local)  │
  │                                   │
  │  7. si hay SIMULADO_APROBADO:     │
  │     se envía al servidor          │
  │     ─────────────────────────────►│  ← acá recién se decide de verdad
  │                                   │     (fuera del alcance del TP)
```

El paso 7 es el que el TP **no** implementa, y es deliberado. Implementarlo
convertiría `SIMULADO_APROBADO` en una venta, y ahí se cae toda la consigna.

---

## 6. Idempotencia: dónde está la protección de verdad

### 6.1 Lo que hay en la tablet

`solicitud_uuid` es `PRIMARY KEY`. Reenviar el mismo UUID revienta con
`UNIQUE constraint failed: cola_sync.solicitud_uuid` (caso C6). La fila no se
duplica y el semáforo no reevalúa lo ya resuelto.

### 6.2 Por qué eso no alcanza

Es **idempotencia del lado del cliente**, y falla en dos escenarios reales:

1. **El UUID cambia.** La tablet se reinició, se reinstaló la app o el vendedor
   tocó "reenviar" y se generó un identificador nuevo. La PK no ve nada: son dos
   solicitudes distintas con el mismo contenido.
2. **La PK protege la tabla, no el efecto de negocio.** Si el servidor ya creó
   el pedido y descuenta stock, un UUID nuevo crea un pedido duplicado. La
   tablet no tiene forma de saberlo: no ve el estado del servidor.

### 6.3 Dónde va la protección real

En el **servidor**, en la misma transacción que crea el pedido:

```
BEGIN;
  -- 1. ¿ya procesé esta solicitud?
  INSERT INTO solicitud_procesada (solicitud_uuid, respuesta)
  VALUES ($1, NULL)
  ON CONFLICT (solicitud_uuid) DO NOTHING
  RETURNING solicitud_uuid;

  -- si no insertó nada → ya estaba: devolver la respuesta guardada
  -- (misma respuesta, sin volver a descontar stock)

  -- 2. crear pedido + detalle + descontar stock, todo junto
  -- 3. guardar la respuesta en solicitud_procesada
COMMIT;
```

Tres piezas, ninguna opcional:

- **tabla de idempotencia** con `solicitud_uuid UNIQUE`, consultada *dentro* de
  la transacción;
- **respuesta guardada**, para devolver la misma y no un error distinto en el
  reintento;
- **clave estable por pedido** (cliente + tablet + secuencia local), no un UUID
  al azar — así un reintento después de un reinicio sigue siendo reconocible.

La tablet sola nunca puede garantizar que no haya duplicados. Puede reducir la
probabilidad; garantizarlo es trabajo del que tiene la transacción.

---

## 7. Alternativas descartadas

| Alternativa | Por qué no |
|---|---|
| La tablet escribe directo en PostgreSQL | Necesita credenciales y conexión en la feria; y contradice la regla de oro. Un `UPDATE` desde la tablet puede pisar stock vendido por otra caja. |
| Importar el CSV directo a `producto_cache` | Los `'t'`/`'f'` rompen una tabla `STRICT`; y se pierde la frontera donde diagnosticar un CSV mal formado. |
| Tabla de ventas en SQLite | Convierte una simulación en una venta. Es exactamente el error que el TP pide no cometer. |
| Borrar el producto de la cache al darlo de baja | Rompe la FK del borrador histórico y borra la diferencia entre "no existe" y "dado de baja". |
| Un solo booleano `activo` en la cache | Colapsa los motivos 3 y 4 del semáforo y hace que el rojo por stock se confunda con el rojo por cantidad. |
| Resolver el conflicto de precio automáticamente | Alguien tiene que decidir si el cliente acepta pagar más. El sistema informa; no negocia. |
| `id_local UNIQUE` en `cola_sync` | Impide modelar C2 (dos solicitudes, un borrador). |
| `REAL` para el dinero | Error de redondeo en la conciliación de caja. |

---

## 8. Riesgos y límites conocidos

| Riesgo | Impacto | Mitigación en este TP |
|---|---|---|
| La instantánea envejece | el semáforo dice verde con datos de hace horas | `fecha_copia` sellada por el servidor; el verde es una simulación, no una venta |
| Un CSV corrupto pasa desapercibido | cache con datos falsos | controles de entrada/salida en `cargar_snapshot.sql` (filas, fechas, booleanos inválidos) |
| Reintento con UUID nuevo | pedido duplicado | se documenta la protección server-side (§6.3); la tablet no puede resolverlo sola |
| Sin límite de tamaño en `motivo` | texto crece con muchos ítems | aceptable para el TP; en producción se separaría en una tabla de incidentes |
| No hay regla de stock en PostgreSQL | se puede vender más de lo que hay | **hallazgo H4 del code review** (§3.c): verificado insertando 999 unidades de un producto con stock 3 |

Ese último punto es el más importante del diseño: **el semáforo de la tablet
detecta el stock insuficiente, pero la base que dice ser la fuente de verdad no
lo impide.** La tablet tapa el síntoma; el problema sigue en PostgreSQL.

---

## 9. Trazabilidad requisito → implementación → prueba

| Requisito | Implementación | Prueba |
|---|---|---|
| REQ-01 conflicto de precio | `semaforo.sql` motivo amarillo | caso C2: 111923 → 126923 |
| REQ-02 stock insuficiente | `semaforo.sql` motivo rojo #4 | caso C3: pide 10, hay 3 |
| REQ-03 baja lógica | `disponible`/`eliminado`, FK `RESTRICT` | caso C4: producto 6 |
| REQ-04 idempotencia | `cola_sync.solicitud_uuid` PK + `WHERE PENDIENTE` | caso C6: UNIQUE constraint |
| No escribir en PostgreSQL | no hay conexión ni credenciales | `tp8_verificacion_final.sql`: pedidos y stock idénticos |
