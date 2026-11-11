# tasks.md — Food Store: sincronización de la tablet en la feria

**Proyecto:** Food Store · Base de Datos II · TP 8 (Unidad 8)
**Change:** `tp8-sincronizacion-tablet`
**Base de trabajo:** PostgreSQL `Food_Store_Copia` + SQLite `foodstore_movil.db`

Cada tarea es ejecutable de punta a punta y deja una verificación concreta. El
orden importa: ninguna tarea arranca si la anterior no dio verde.

Leyenda: `[x]` hecho y verificado · `[ ]` pendiente

---

## Fase 0 — Preparación (protocolo de seguridad)

- [x] **T0.1 · Respaldo previo de PostgreSQL**
      `pg_dump -F p` de `Food_Store_Copia` a `db/backups/`.
      *Verificación:* archivo de 17 MB con `CREATE TABLE` de las 13 tablas.
      *Resultado:* `db/backups/Food_Store_Copia_tp8_20261101_193127.sql`

- [x] **T0.2 · Línea de base de invariantes**
      `db/tp8_linea_base.sql` → tabla `tp8_linea_base` con `pedidos`,
      `detalles`, `stock_total`, `stock_huella` (md5) y `precio_huella` (md5).
      *Verificación:* `200000 / 200000 / 4999032 / 95b86fa0… / 1816a7c5…`
      *Por qué la huella y no sólo la suma:* dos cambios opuestos dejan la misma
      suma; el md5 del vector `(id:stock)` ordenado detecta cualquier cambio.

- [x] **T0.3 · Confirmar el entorno**
      PostgreSQL 17.10 en `localhost:5432`; SQLite 3.50.4; `psql` en
      `C:\Program Files\PostgreSQL\17\bin\`.
      *Verificación:* `select version()` responde y `sqlite3 --version` responde.

---

## Fase 1 — Esquema de la tablet (consigna 1)

- [x] **T1.1 · Las cuatro tablas en SQLite**
      `movil/schema_sqlite.sql`: `producto_cache`, `pedido_borrador`,
      `item_borrador`, `cola_sync`, todas `STRICT`.
      *Verificación:* 17/17 restricciones disparan como se espera.
      *Decisión clave:* `id_local` en `cola_sync` **no** es UNIQUE (C2 necesita
      dos solicitudes sobre el mismo borrador).

- [x] **T1.2 · Pruebas de la base local**
      `movil/pruebas_sqlite.sql`, **sobre una base aparte** (borra las tablas al
      inicio; no se corre contra `foodstore_movil.db`).
      *Verificación:* COMMIT deja 1/2/1; ROLLBACK vuelve a 1/2/1; C1 (catálogo
      offline) anda; C7 (dos errores esperados) no deja filas.

- [x] **T1.3 · Generar la base real**
      `movil/foodstore_movil.db` desde `schema_sqlite.sql`.
      *Verificación:* las 4 tablas existen y `PRAGMA foreign_keys` está en ON.

---

## Fase 2 — Instantánea y semáforo (consigna 2)

- [x] **T2.1 · Vista de exportación en PostgreSQL**
      `db/tp8_v_snapshot_movil.sql`: precio en centavos, `disponible =
      activo AND stock > 0`, `eliminado = NOT activo`, `fecha_copia` sellada con
      `to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS')`.
      *Verificación:* 50.000 totales / 49.744 vendibles / 0 dados de baja /
      0 inconsistentes.

- [x] **T2.2 · Exportar el CSV**
      `\copy (SELECT * FROM v_snapshot_movil) TO '…/servidor_snapshot.csv' CSV HEADER`
      *Verificación:* `COPY 50000`; 50.001 líneas con encabezado; 2,7 MB;
      booleanos como `t`/`f`.

- [x] **T2.3 · Tabla de aterrizaje**
      `movil/schema_snapshot.sql`: `snapshot_servidor`, **no** STRICT, con
      afinidades declaradas.
      *Verificación:* el `.import` de 50.000 filas entra sin error.

- [x] **T2.4 · Normalizar y poblar la cache**
      `movil/cargar_snapshot.sql`: `'t'/'true'/'1' → 1`, UPSERT con
      `WHERE true ON CONFLICT (id) DO UPDATE`.
      *Verificación:* 50.000 en cache, 49.744 vendibles, 0 inconsistentes,
      una sola `fecha_copia`.

- [x] **T2.5 · El semáforo**
      `movil/semaforo.sql`: cuatro motivos de rojo en orden de precedencia, un
      motivo amarillo, `WHERE estado = 'PENDIENTE'` en CTE y UPDATE.
      *Verificación:* correrlo dos veces no cambia ningún estado.

- [x] **T2.6 · Los casos C2 a C6**
      `movil/casos/*.sql` + `movil/simular_casos.ps1`.
      *Verificación (evidencia en `movil/evidencias_casos.txt`, 348 líneas):*

      | Caso | Escenario | Resultado real |
      |---|---|---|
      | C5 | borrador sin cambios | `SIMULADO_APROBADO` |
      | C3 | producto 95, stock 3, pide 10 | `RECHAZADO: … no alcanza el stock (pide 10, hay 3)` |
      | C2a | servidor sube precio 111923 → 126923 | `CONFLICTO: producto 5: precio cambió de 111923 a 126923 centavos` |
      | C2b | cliente acepta el precio nuevo | `SIMULADO_APROBADO` (UUID nuevo, mismo borrador) |
      | C4 | producto 6 dado de baja | `RECHAZADO: producto 6: dado de baja` |
      | C6 | reenvío del mismo UUID | `UNIQUE constraint failed: cola_sync.solicitud_uuid` |

- [x] **T2.7 · Prueba de que PostgreSQL no cambió**
      `db/tp8_verificacion_final.sql`.
      *Verificación:* pedidos `200000 → 200000`, detalles `200000 → 200000`,
      stock `4999032 → 4999032`, `stock_huella` idéntica; `precio_huella`
      **cambió** (esperado, C2).
      *Esto es la prueba de la regla de oro:* el precio cambió, el stock no.

- [x] **T2.8 · C4: la fila queda en la cache**
      *Verificación:* `producto_cache` id 6 → `disponible = 0`, `eliminado = 1`,
      y `productos_6_en_catalogo = 0`.

---

## Fase 3 — Revisión de código (consigna 3)

- [x] **T3.1 · Mapa de los tres motores** → `docs/informe.pdf §3.a`
      PostgreSQL (relacional), SQLite (copia local), MongoDB (documental, U7).
      Para cada uno: qué guarda, qué garantiza, qué no.

- [x] **T3.2 · Plan de mantenimiento** → `docs/informe.pdf §3.b`
      Respaldo, `VACUUM`/`ANALYZE`, reindexado, retención, rotación de la cache
      de la tablet, verificación de integridad.

- [x] **T3.3 · Cuatro hallazgos verificados, no leídos**
      `db/tp8_code_review_verificaciones.sql` →
      `docs/evidencias_code_review.txt`.

      | # | Unidad | Hallazgo | Estado |
      |---|---|---|---|
      | H1 | U3 | índice `pedido(forma_pago)` descartado | **justificación corregida**: el planner SÍ lo usa, pero lee las 1471 páginas igual |
      | H2 | U5 | `REVOKE SELECT (precio)` no recorta un `GRANT SELECT` de tabla | **corregido**: `REVOKE ALL` + `GRANT` por columnas |
      | H3 | U5 | `GRANT` dentro de un `DO` se ejecuta como el invocador | **corregido** |
      | H4 | U1–U3 | no existe ninguna regla de stock en la base | **verificado**: 999 unidades de un producto con stock 3 entran sin error |

      *Verificación final:* 0 índices `tp8`, 0 roles `tp8`, 200.000 pedidos —
      nada quedó modificado.

---

## Fase 4 — Documentación (consigna 4)

- [x] **T4.1 · `docs/kiro/requirements.md`**
      REQ-01 … REQ-04 en EARS, cada uno atado a su caso (C2, C3, C4, C6).

- [x] **T4.2 · `docs/kiro/design.md`**
      Arquitectura, modelo de datos, precedencia del semáforo, idempotencia
      server-side, alternativas descartadas, riesgos.

- [x] **T4.3 · `docs/kiro/tasks.md`** ← este archivo
      Lista ejecutable en el orden real de construcción.

- [x] **T4.4 · `docs/bitacora_ia.md`**
      Mínimo 3 entradas. Cada una: qué pedí, qué devolvió la IA, qué estaba mal,
      cómo lo detecté, qué corregí.
      *Material real disponible:* `'t' = 1` falso en SQLite (dos motivos de rojo
      muertos); `.import --skip 1` sobre tabla inexistente pierde una fila;
      `INSERT … SELECT … ON CONFLICT` ambiguo sin `WHERE true`; la justificación
      de U3 sobre el índice `forma_pago` era incorrecta.

- [x] **T4.5 · `docs/DUIA.md`**
      Declaración de uso de IA, siguiendo el formato de `docs/DUIA_Tp5.md`.

- [x] **T4.6 · `README.md`**
      Orden exacto de creación desde cero, con los comandos reales y la
      precondición de cada paso.

- [x] **T4.7 · `docs/informe.pdf` (≤ 6 páginas)**
      Cubre 1.a, 2.c, 3.a, 3.b, 3.c. Redactado en `docs/informe.md` (fuente
      única) y convertido con `docs/generar_informe.py`. **4 páginas.**

---

## Fase 5 — Cierre

- [x] **T5.1 · Verificar el árbol de entrega**
      Los 12 archivos de la estructura exigida existen y la evidencia
      corresponde a la corrida final (348 líneas, 5 estados distintos).

- [x] **T5.2 · Revisar que no haya datos personales reales**
      En SQLite, en el CSV y en lo que se le pidió a la IA. Usuarios sintéticos
      (`caja-01`), clientes `Cliente 453`. Sin mails, passwords ni credenciales
      en los archivos del TP.

- [x] **T5.3 · Comprobar que la base quedó en estado conocido**
      Producto 5 con precio 1269.23 y producto 6 con `activo = false` son
      cambios **intencionales** de C2 y C4, ya reflejados en la evidencia.
      El resto, idéntico a la línea de base. 200.000 pedidos.

---

## Definición de terminado

El TP está terminado cuando se cumplen las cuatro cosas juntas:

1. **Los cinco casos dan lo esperado** con evidencia de una corrida completa
   (no editada a mano).
2. **PostgreSQL no se movió**: pedidos y stock idénticos a la línea de base.
3. **Los cuatro hallazgos del review están verificados ejecutando**, no citando
   el script.
4. **El informe entra en 6 páginas** y cada afirmación tiene su archivo de
   respaldo.
