# DECLARACIÓN DE USO DE INTELIGENCIA ARTIFICIAL (DUIA) — TP Unidad 8

## 1. Información General

- **Trabajo Práctico:** Unidad 8 — Food Store en la feria: la base de la tablet y el cierre de la capa de datos
- **Alumno:** Saleme Ismael
- **Asignatura:** Base de Datos II (UTN - TUP a Distancia)
- **Herramientas de IA:** Kiro (especificación) y OpenCode (agente de codificación en terminal)
- **Motores:** PostgreSQL 17.10 (`Food_Store_Copia`) + SQLite 3.50.4 (`foodstore_movil.db`)
- **Fecha:** 2026-11-01

**Nota de alcance:** la IA no tuvo acceso a datos personales. Los usuarios de la
tablet son sintéticos (`caja-01`) y los clientes del catálogo son `Cliente N`.
No se enviaron nombres, mails, teléfonos ni la contraseña de la base.

---

## 2. Registro de Uso por Pieza (flujo obligatorio Kiro → OpenCode → verificación)

### Parte A — Base de la tablet (consigna 1)

#### A1. Esquema SQLite de cuatro tablas
- **Herramienta:** Kiro para el diseño, OpenCode para la generación
- **Prompt / Spec entregado (resumen):**
  > Modelar la base local de una tablet que vende sin señal: catálogo de sólo
  > lectura, borradores de pedido, renglones y una cola de salida hacia el
  > servidor. Regla: la tablet nunca confirma ventas. Dinero sin punto flotante.
- **Qué propuso la IA:** cuatro tablas (`producto_cache`, `pedido_borrador`,
  `item_borrador`, `cola_sync`) `STRICT`, dinero en `INTEGER` de centavos,
  `id_local` como UUID con `CHECK GLOB`, `disponible` y `eliminado` como
  booleanos `0/1`.
- **Qué se aceptó / modificó:**
  - Se aceptó el diseño general.
  - Se **rechazó** `UNIQUE` en `cola_sync.id_local`: el caso C2 exige dos
    solicitudes sobre el mismo borrador (la primera queda en `CONFLICTO` como
    registro histórico, la segunda da `SIMULADO_APROBADO`).
  - Se **agregó** `ON DELETE RESTRICT` en la FK de `item_borrador` a
    `producto_cache`, para que una recarga del catálogo no borre en silencio
    renglones de borradores ya armados.
- **Verificación:** 17/17 restricciones disparan como se espera (precio negativo,
  cantidad cero, `forma_pago` fuera del dominio, UUID mal formado, FK rota,
  estado fuera de los cuatro valores). Ejecutado en `movil/pruebas_sqlite.sql`.

#### A2. Pruebas de la base local
- **Herramienta:** OpenCode
- **Prompt:** "Escribí pruebas que demuestren que el esquema no deja entrar datos
  inválidos y que el catálogo se puede consultar sin señal."
- **Qué propuso la IA:** script con `COMMIT`/`ROLLBACK`, un caso de catálogo
  offline (C1) y un caso de errores esperados (C7).
- **Qué se aceptó / modificó:** se aceptó. Se **agregó** la advertencia de que el
  script borra las tablas al inicio, así que **debe correrse sobre una base
  aparte**, nunca contra `foodstore_movil.db` (el TP lo exige explícitamente).
- **Verificación:** `COMMIT` deja 1 pedido / 2 ítems / 1 solicitud; `ROLLBACK`
  vuelve a 1/2/1; C7 produce dos errores esperados sin dejar filas huérfanas.

---

### Parte B — Instantánea y semáforo (consigna 2)

#### B1. Vista de exportación
- **Herramienta:** Kiro (spec) → OpenCode
- **Spec entregado:** columnas `id, nombre, precio_centavos, stock_visto,
  disponible, eliminado, fecha_copia`; `disponible = activo AND stock > 0`;
  `eliminado = NOT activo`; la fecha la sella el servidor, no la tablet.
- **Qué propuso la IA:** la vista con `round(precio * 100)::integer` para el
  precio en centavos.
- **Qué se aceptó / modificado:** se aceptó. Se **agregó** `fecha_copia` con
  `to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SS')` para que la instantánea quede
  fechada **en origen**: si la fecha la pusiera la tablet, el dato más importante
  para juzgar si la copia envejeció sería el menos confiable.
- **Verificación:** 50.000 totales / 49.744 vendibles / 0 dados de baja /
  0 inconsistentes.

#### B2. Carga de la instantánea en SQLite
- **Herramienta:** OpenCode
- **Prompt:** "Exportá la vista a CSV y cargala en la tablet sin perder tipos."
- **Qué propuso la IA:** `\copy … CSV HEADER` + `.import --csv --skip 1` directo
  contra `producto_cache`.
- **Qué se aceptó / modificado:** se **rechazó** la importación directa. Se
  agregó una tabla de aterrizaje (`snapshot_servidor`, no `STRICT`) y un paso de
  normalización explícito `'t'/'true'/'1' → 1`. Motivo: `psql` exporta booleanos
  como `t`/`f`, y en SQLite `'t' = 1` es **falso** — con la comparación directa,
  los motivos "dado de baja" y "no disponible" del semáforo quedaban muertos.
- **Verificación:** 50.000 filas en cache, 49.744 vendibles, 0 inconsistentes,
  una sola `fecha_copia`. Controles de entrada y salida en cada carga.

#### B3. El semáforo
- **Herramienta:** Kiro (spec) → OpenCode
- **Spec entregado:** para cada solicitud `PENDIENTE`, decidir
  `SIMULADO_APROBADO` / `CONFLICTO` / `RECHAZADO` comparando contra la
  instantánea. Cuatro motivos de rojo distinguibles. No escribir en PostgreSQL.
- **Qué propuso la IA:** `UPDATE … FROM` con un CTE de dos niveles
  (`item_evaluado` → `resumen`), `group_concat` de motivos.
- **Qué se aceptó / modificado:** se aceptó la estructura. Se **corrigió la
  precedencia**: el orden de los `CASE` decide qué motivo ve el vendedor, y el
  original reportaba *"sin stock"* para productos dados de baja. Se fijó el orden
  no existe → dado de baja → no disponible → no alcanza el stock, y el amarillo
  sólo aparece si no hay ningún rojo.
- **Verificación:** los cinco casos C2–C6 dan exactamente lo esperado
  (`movil/evidencias_casos.txt`, 348 líneas). Correrlo dos veces no cambia
  ningún estado (idempotencia por `WHERE estado = 'PENDIENTE'`).

#### B4. Prueba de que PostgreSQL no cambió
- **Herramienta:** OpenCode
- **Prompt:** "¿Cómo pruebo que el semáforo leyó y no escribió?"
- **Qué propuso la IA:** comparar `count(*)` de `pedido` y `detalle_pedido` antes
  y después.
- **Qué se aceptó / modificado:** se aceptó y se **reforzó**. El conteo solo no
  alcanza: se agregó una huella `md5` del vector `(id:stock)` de los 50.000
  productos, porque dos cambios opuestos dejan la misma suma. Se agregó también
  `precio_huella`, que **sí debe cambiar** (caso C2) — mostrar el precio cambiado
  y el stock intacto es la prueba de la regla de oro.
- **Verificación:** pedidos `200000 → 200000`, detalles `200000 → 200000`,
  stock `4999032 → 4999032`, `stock_huella` idéntica (`95b86fa0…`);
  `precio_huella` cambió (`1816a7c5… → c47b59be…`).

---

### Parte C — Casos de simulación

#### C1. Casos C2 a C6
- **Herramienta:** OpenCode
- **Prompt:** "Armá un caso por cada situación del enunciado, con productos reales
  del catálogo y un driver que orqueste la secuencia completa."
- **Qué propuso la IA:** seis archivos SQL + un driver PowerShell que hace:
  preparar borrador → cambiar el servidor → nueva instantánea → recargar cache →
  correr semáforo.
- **Qué se aceptó / modificado:** se aceptó. Se eligieron productos reales:
  producto 95 (stock 3) para C3, productos 2/4/5/6 (stock holgado) para el resto.
  Se **corrigieron dos defectos del driver** encontrados al ejecutarlo
  (`Select-Object -First` cortaba el pipeline; `SQ` tomaba un solo argumento).
- **Verificación (resultados reales):**

  | Caso | Resultado |
  |---|---|
  | C5 borrador sin cambios | `SIMULADO_APROBADO` |
  | C3 pide 10, hay 3 | `RECHAZADO: … no alcanza el stock (pide 10, hay 3)` |
  | C2a servidor sube el precio | `CONFLICTO: … precio cambió de 111923 a 126923 centavos` |
  | C2b cliente acepta | `SIMULADO_APROBADO` (UUID nuevo, mismo borrador) |
  | C4 producto dado de baja | `RECHAZADO: producto 6: dado de baja` |
  | C6 reenvío del mismo UUID | `UNIQUE constraint failed: cola_sync.solicitud_uuid` |

---

### Parte D — Revisión de código (consigna 3.c)

#### D1. Cuatro hallazgos verificados
- **Herramienta:** OpenCode para localizar candidatos; **verificación humana
  ejecutando**
- **Prompt:** "Revisá los scripts de las unidades anteriores y encontrá hallazgos
  reales, no teóricos."
- **Qué propuso la IA:** cuatro candidatos.
- **Qué se aceptó / modificó:** los cuatro se **verificaron ejecutando**
  (`db/tp8_code_review_verificaciones.sql`). Uno obligó a corregir la
  documentación de U3:

  | # | Hallazgo | Resultado de la verificación |
  |---|---|---|
  | H1 | índice `pedido(forma_pago)` descartado en U3 | el planner **sí** lo usa (`Bitmap Index Scan`), pero lee las 1471 páginas igual → **la justificación era incorrecta**; se corrigió |
  | H2 | `REVOKE SELECT (precio)` no recorta un `GRANT SELECT` de tabla | confirmado: `has_column_privilege` siguió `true`; se corrigió a `REVOKE ALL + GRANT` por columnas |
  | H3 | `GRANT` dentro de un `DO` se ejecuta como el invocador | confirmado: el rol se otorgó de verdad |
  | H4 | no existe ninguna regla de stock en la base | confirmado: 999 unidades de un producto con stock 3 entran sin error |

- **Verificación final:** 0 índices `tp8`, 0 roles `tp8`, 200.000 pedidos —
  la revisión no dejó cambios.

---

### Parte E — Documentación (consigna 4)

#### E1. Spec de Kiro
- **Herramienta:** Kiro
- **Prompt:** "Escribí requirements en EARS, design y tasks para el change
  `tp8-sincronizacion-tablet`, atados a los casos reales."
- **Qué propuso la IA:** REQ-01…REQ-04 en EARS, design con arquitectura y
  precedencia, tasks en el orden de construcción.
- **Qué se aceptó / modificado:** se aceptó. Se **agregó** una sección explícita
  (§6 del design) sobre dónde vive la protección real de idempotencia: la PK de
  la tablet no alcanza si el UUID cambia, y eso tiene que quedar escrito, no
  supuesto.
- **Verificación:** cada REQ apunta a su caso y a su archivo de evidencia.

---

## 3. Conclusión sobre el uso de la IA

La IA se usó como motor de generación y como revisor, pero **la decisión nunca se
delegó**. Cada script se leyó línea por línea y se ejecutó contra la base real
antes de aceptarlo. Los cinco defectos más importantes del TP —`'t' = 1` falso en
SQLite, `.import --skip 1` perdiendo una fila, `INSERT … SELECT … ON CONFLICT`
ambiguo, la justificación errónea del índice de U3 y la ausencia de regla de stock
en PostgreSQL— **no se detectaron leyendo, se detectaron corriendo**. Eso es
exactamente el punto: una respuesta de IA que *parece* razonable puede ser falsa
de una forma que sólo la ejecución revela.

Se rechazaron explícitamente seis propuestas: `UNIQUE` en `id_local`, tabla de
ventas en SQLite, un solo booleano `activo`, `REAL` para dinero, resolución
automática de conflictos de precio y confiar en la PK de la tablet como
idempotencia suficiente.

---

## 4. Trazabilidad Git

Flujo exigido: cada pieza en commits separados y descriptivos.

Commits realizados (ver `git log --oneline`):
- `feat(movil): esquema SQLite de la tablet (4 tablas STRICT) + pruebas`
- `feat(snapshot): vista v_snapshot_movil + exportacion CSV`
- `feat(snapshot): carga normalizada t/f -> 1/0 + UPSERT de la cache`
- `feat(semaforo): precedencia de cuatro motivos de rojo + idempotencia`
- `test(casos): C2, C3, C4, C5, C6 con evidencia real`
- `test(invariantes): pedidos y stock identicos a la linea de base`
- `docs(review): cuatro hallazgos verificados + correccion de justificacion U3`
- `docs(kiro): requirements, design y tasks`
- `docs(bitacora): interacciones con IA y errores reales detectados`
- `docs(entrega): informe de la segunda entrega, README del TP 8 y orden del repositorio`
- `docs(duia): declaracion de uso de IA`

Cada commit es mostrable con `git show` en la defensa oral.
