# INFORME TECNICO INTEGRADOR - PRIMER PARCIAL TPI
## Proyecto: Food Store — Base de Datos II (UTN TUP)
**Alumno:** Sabrina Gimenez, Ismael Saleme, Jeronimo Coronel y Joaquin Godoy 
**Motor de referencia:** PostgreSQL 16+  
**Estrategia de desarrollo:** Asistido por IA (OpenCode) bajo protocolo estricto de seguridad, transaccionalidad y validación empírica.

---

## 1. Introduccion y Alcance

El presente informe técnico documenta el diseño, desarrollo, pruebas, optimización y evolución del Trabajo Práctico Integrador (TPI) de la materia **Base de Datos II**, correspondiente a la primera entrega parcial. El proyecto modela el sistema de gestión transaccional y analítica para el comercio minorista **Food Store**, abarcando desde el modelado conceptual y lógico hasta la implementación de reglas de negocio avanzadas en PL/pgSQL, control de concurrencia con múltiples sesiones simultáneas, poblamiento masivo de datos y optimización de consultas complejas basadas en planes de ejecución reales.

Todo el desarrollo se estructuró bajo un flujo de trabajo:

1. **Modelado y Normalización:** Diseño relacional robusto sin redundancias ni anomalías de actualización.
2. **Seguridad y Aislamiento:** Creación de una copia de trabajo dedicada (`Food_Store_Copia`) para preservar intacta la base original (`Food_Store`), aplicando un protocolo estricto de tres pasos (copia, transacción con `BEGIN...ROLLBACK`, y respaldo con `pg_dump`).
3. **Programación en el Motor:** Implementación de restricciones declarativas y triggers avanzados para garantizar la integridad referencial y de negocio.
4. **Laboratorio de Concurrencia:** Reproducción de anomalías de aislamiento y estudio de bloqueos con dos sesiones concurrentes en PostgreSQL.
5. **Optimización Masiva y Analítica:** Generación de volúmenes de datos realistas (decenas de miles de registros) utilizando `generate_series`, medición de rendimiento mediante `EXPLAIN ANALYZE`, lectura crítica de planes de ejecución y verificación formal de equivalencia relacional utilizando el operador `EXCEPT`.

---

## 2. Acreditacion de los 9 Objetivos del TPI

### 1. Modelo ER (Entidades, Atributos, Claves y Cardinalidad)

El diseño conceptual del sistema Food Store se estructuró sobre cinco entidades fundamentales que cubren el dominio comercial:

- **categoria:** Almacena las divisiones de mercadería. Sus atributos son `id` (Clave Primaria), `nombre` (con restricción de unicidad para evitar duplicados) y `activo` (atributo booleano destinado al borrado lógico).

- **producto:** Representa los artículos físicos disponibles para la venta. Sus atributos principales son `id` (Clave Primaria), `nombre`, `precio` (validado mediante `CHECK` para impedir valores negativos), `stock` (unidades disponibles), `activo` (soft delete) y `categoria_id` (Clave Foránea hacia `categoria`).

- **cliente:** Contiene la información de los compradores. Sus atributos son `id` (Clave Primaria), `nombre`, `email` (con restricción `UNIQUE` para asegurar identificadores de contacto únicos) y `telefono`.

- **pedido:** Registra las transacciones comerciales de venta. Sus atributos son `id` (Clave Primaria), `fecha` (con valor por defecto `now()`), `forma_pago` (implementado mediante un tipo `ENUM` nativo de PostgreSQL con valores `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`) y `cliente_id` (Clave Foránea hacia `cliente`).

- **detalle_pedido:** Tabla asociativa que descompone la relación N:M entre `pedido` y `producto`. Sus atributos son `pedido_id` (Clave Foránea y parte de la PK compuesta), `producto_id` (Clave Foránea y parte de la PK compuesta), `cantidad` (unidades solicitadas, con `CHECK > 0`) y `precio_unitario` (precio congelado al momento de la compra).

**Cardinalidades y participación detallada:**
- Entre `categoria` y `producto`, la cardinalidad es **1:N** con participación total por parte del producto (un producto pertenece obligatoriamente a una categoría) y parcial por parte de la categoría (puede existir una categoría sin productos asociados temporalmente).
- Entre `cliente` y `pedido`, la cardinalidad es **1:N** con participación opcional por parte del cliente (un cliente registrado puede no haber realizado ningún pedido todavía).
- La relación entre `pedido` y `producto` es de **N:M**, la cual se materializó estructuralmente mediante la entidad intermedia `detalle_pedido`.

### 2. Paso de ER a Modelo Relacional

El proceso de traducción del modelo conceptual al esquema relacional se rigió estrictamente por las reglas formales de transformación:
- Las entidades independientes y fuertes (`categoria`, `cliente`) se convirtieron en tablas relacionales con sus respectivas claves primarias simples de tipo `BIGINT GENERATED ALWAYS AS IDENTITY`.

- Las relaciones de tipo **1:N** se resolvieron propagando la clave primaria de la entidad principal (lado '1') como columna de clave foránea en la entidad dependiente (lado 'N'). Esto se evidencia en la columna `categoria_id` dentro de la tabla `producto` y `cliente_id` dentro de la tabla `pedido`.

- La relación de tipo **N:M** se resolvió mediante la creación de la tabla relacional `detalle_pedido`, cuya clave primaria es una tupla compuesta por (`pedido_id`, `producto_id`). Ambas columnas actúan simultáneamente como claves foráneas hacia sus respectivas tablas de origen (`pedido` y `producto`), aplicando restricciones de integridad referencial con `ON DELETE RESTRICT` para evitar la eliminación de registros principales con dependencias activas.

### 3. Normalizacion hasta 3FN / BCNF

El esquema relacional fue sometido a un riguroso análisis de dependencias funcionales para garantizar la ausencia de anomalías de inserción, actualización y borrado:

- **Primera Forma Normal (1FN):** Se verificó que todos los atributos de cada tabla contengan únicamente valores atómicos y de dominio simple. No se utilizaron atributos multivaluados ni estructuras anidadas o arreglos informales.

- **Segunda Forma Normal (2FN):** Se cumplió la 1FN y se comprobó que todos los atributos que no forman parte de la clave primaria dependan funcionalmente de la totalidad de dicha clave. En particular, en la tabla intermedia `detalle_pedido` (con clave compuesta `pedido_id, producto_id`), los atributos descriptivos `cantidad` y `precio_unitario` dependen estrictamente de ambos identificadores combinados y no de uno solo de ellos, evitando dependencias parciales.

- **Tercera Forma Normal (3FN):** Se analizaron las dependencias funcionales para eliminar cualquier dependencia transitiva. Ningún atributo no clave depende de otro atributo no clave; todos dependen directa y exclusivamente de la clave primaria de su respectiva tabla. El diseño alcanza así un alto grado de cohesión y estabilidad estructural.

### 4. DDL Completo (Tipos, PK, FK, Restricciones e Indices)

La estructuración de la base de datos se codificó y versionó en el script `db/schema_tp1.sql`, haciendo uso intensivo de las características avanzadas de PostgreSQL 16+:

- **Tipos de datos y Autoincremento:** Se emplearon columnas `BIGINT GENERATED ALWAYS AS IDENTITY` para garantizar la generación segura y nativa de identificadores unívocos en todas las tablas.

- **Tipos Enumerados:** Se creó el dominio personalizado `forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')` para restringir los valores admitidos a nivel de motor.

- **Restricciones de Dominio (CHECK y UNIQUE):** Se incorporaron validaciones de integridad como `check_producto_precio (precio >= 0)`, `check_producto_stock (stock >= 0)`, `check_detalle_cantidad (cantidad > 0)` y restricciones `UNIQUE` en campos alfanuméricos clave (`categoria.nombre`, `cliente.email`).

- **Índices Estructurales (B-Tree):** Se definieron índices específicos para acelerar las operaciones de combinación en claves foráneas de alta frecuencia, tales como `index_pedido_cliente` sobre `pedido(cliente_id)` e `index_producto_categoria` sobre `producto(categoria_id)`.

### 5. DML y Consultas (JOIN, Agregacion, Subconsultas, HAVING y Ventana)

El proyecto incluye un amplio repertorio de consultas de manipulación (DML) y reportes analíticos complejos almacenados en los scripts del repositorio:
- **Combinaciones Múltiples (JOIN):** Uso intensivo de `INNER JOIN` para cruzar hasta cuatro y cinco tablas simultáneamente (`cliente`, `pedido`, `detalle_pedido`, `producto`, `categoria`), resolviendo reportes de facturación y transaccionalidad.

- **Agregación y Agrupamiento:** Implementación de funciones estadísticas como `COUNT()`, `SUM()` y `AVG()` combinadas con cláusulas `GROUP BY` y condiciones de filtrado sobre grupos mediante `HAVING`.

- **Subconsultas y Tablas Derivadas:** Empleo de subconsultas correlacionadas y expresiones de tabla común (`WITH` / CTEs) para resolver operaciones de comparación contra promedios generales y segmentados por categoría.

- **Funciones de Ventana (Window Functions):** Aplicación de la función analítica `DENSE_RANK() OVER (...)` para la construcción de rankings de clientes según su volumen de gasto histórico, preservando el detalle fila por fila sin colapsar el conjunto de resultados.

### 6. Vistas, Funciones y Procedimientos en PL/pgSQL

Se diseñaron e integraron funciones ejecutables en lenguaje procedural `PL/pgSQL` directamente dentro del motor de base de datos. Estas funciones actúan como el núcleo lógico para las validaciones dinámicas y los disparadores de integridad referencial diferida, garantizando que la lógica comercial resida de forma segura en el servidor de base de datos.

### 7. Reglas de Negocio Implementadas (CHECK, UNIQUE y Triggers)

Para garantizar reglas de negocio complejas que no pueden resolverse únicamente con restricciones estáticas, se programaron triggers y funciones disparadoras en `db/reglas_integridad.sql`:

1. **Regla de Producto Activo en Pedidos:** Se programó la función `fn_check_producto_activo()` y el trigger `trg_check_producto_activo` de tipo `BEFORE INSERT OR UPDATE` sobre la tabla `detalle_pedido`. Si se intenta asociar un producto cuyo campo `activo` se encuentre en `FALSE`, el motor intercepta la operación y emite un rechazo inmediato (`RAISE EXCEPTION`).

2. **Regla de Pedido con Detalle Obligatorio:** Se implementó una validación de consistencia comercial que estipula que ningún pedido puede registrarse sin al menos un producto asociado. Para permitir que la inserción del cabezal (`pedido`) y sus ítems (`detalle_pedido`) ocurra de forma fluida dentro de una misma transacción, se configuró un **Trigger de Restricción Diferido** (`CONSTRAINT TRIGGER ... DEFERRABLE INITIALLY DEFERRED`), el cual pospone la verificación de la aserción hasta el momento exacto del `COMMIT`.

### 8. Transacciones: Atomicidad, COMMIT, ROLLBACK, Niveles de Aislamiento y Concurrencia

Se aplicó rigurosamente el protocolo de seguridad de la cátedra sobre la base de pruebas `Food_Store_Copia`:
- **Atomicidad Transaccional:** Cada modificación masiva o estructura de prueba se ejecutó envolviéndola en bloques `BEGIN; ... ROLLBACK;` para inspeccionar el impacto en las filas afectadas antes de confirmar definitivamente los cambios con `COMMIT;`.

- **Laboratorio de Concurrencia:** Utilizando dos sesiones concurrentes independientes sobre el motor PostgreSQL, se reprodujeron y documentaron tres anomalías teóricas de la unidad:

  - *Lectura No Repetible:* Evidenciada bajo el nivel de aislamiento `READ COMMITTED`, demostrando cómo una segunda consulta dentro de una transacción observa modificaciones confirmadas por otra sesión, y cómo se evita utilizando `REPEATABLE READ`.

  - *Lectura Fantasma:* Demostrada mediante consultas de agregación (`COUNT`) repetidas mientras otra sesión insertaba un registro nuevo dentro del rango de búsqueda.

  - *Espera por Bloqueo:* Ejecutada mediante operaciones concurrentes con `SELECT ... FOR UPDATE` sobre un mismo registro, comprobando cómo la segunda sesión queda a la espera de la liberación del recurso.

### 9. Borrado Logico (Soft Delete) y su Impacto

Las entidades principales del dominio (`categoria`, `producto`) incorporan el atributo booleano `activo` en lugar de aplicar borrados físicos (`DELETE`). 
- **Impacto en Consultas:** Todas las consultas operativas y analíticas desarrolladas en el proyecto incorporan de forma explícita filtros del tipo `WHERE activo = TRUE`, garantizando que la baja lógica de un producto o categoría sea transparente para los clientes pero preserve la integridad histórica de los pedidos ya realizados.

---

## 4. Informe Tecnico 

### 1. ¿Que elementos implementaron en cada unidad?

- **Unidad 1 (Diseño, Modelado y DDL):** Se implementó el esquema relacional completo (`schema_tp1.sql`), abarcando la creación de tablas con restricciones de dominio (`CHECK`, `UNIQUE`, `NOT NULL`), claves primarias autoincrementales, claves foráneas con políticas de restricción ante borrados (`ON DELETE RESTRICT`), tipos de datos enumerados (`ENUM`) y la estructuración de índices B-Tree iniciales.

- **Unidad 2 (Integridad, Transacciones y Concurrencia):** Se programaron las reglas de negocio avanzadas mediante funciones PL/pgSQL y triggers de validación inmediata y diferida (`reglas_integridad.sql`). Asimismo, se ejecutó el laboratorio de concurrencia de dos sesiones simultáneas, documentando niveles de aislamiento y bloqueos explícitos (`FOR UPDATE`).

- **Unidad 3 y 4 (Optimización, Poblamiento Masivo y Analítica):** Se desarrolló el script de carga masiva (`carga_masiva.sql`) utilizando `generate_series` para poblar la base con 50.000 productos, 20.000 clientes, 200.000 pedidos y sus detalles con IDs estructurados desde 1. Se realizaron mediciones de rendimiento con `EXPLAIN ANALYZE`, creación de índices compuestos, lectura crítica de planes de ejecución, formulación de especificaciones precisas (specs), consultas con funciones de ventana, subconsultas correlacionadas y pruebas formales de equivalencia relacional utilizando el operador `EXCEPT`.

### 2. ¿Cómo probaron su funcionamiento?

- **Pruebas transaccionales controladas:** Ejecución de scripts en DBeaver sobre la base de prueba `Food_Store_Copia`, utilizando bloques `BEGIN ... ROLLBACK` para validar casos de prueba válidos e inválidos sin alterar el estado persistente hasta su confirmación.

- **Validación de restricciones empíricas:** Intentos deliberados de insertar productos inactivos o pedidos vacíos para comprobar el correcto rechazo por parte de los triggers del motor.

- **Análisis de rendimiento y planes (EXPLAIN ANALYZE):** Medición de costos estimados y tiempos reales de ejecución antes y después de aplicar estrategias de indexación en escenarios de alta volumetría.

- **Verificación de equivalencia relacional:** Ejecución de pruebas cruzadas con el operador relacional `EXCEPT` entre consultas principales y sus variantes alternativas (como CTEs y tablas derivadas), asegurando que ambas direcciones retornen estrictamente 0 filas de discrepancia.

### 3. Qué resultados obtuvieron?

- **Robustez Estructural:** Se consolidó una base de datos con blindaje en el motor, capaz de rechazar automáticamente cualquier intento de vulnerar las reglas de integridad comercial.

- **Escalabilidad y Comportamiento Masivo:** Se comprobó empíricamente el comportamiento de PostgreSQL ante volúmenes masivos de cientos de miles de filas, entendiendo las diferencias de rendimiento entre recorridos secuenciales (`Sequential Scan`) y búsquedas indexadas (`Index Scan` / `Bitmap Index Scan`).

- **Criterio Profesional de Optimización:** Se corroboró que la agregación de índices no siempre reduce el tiempo de ejecución en consultas analíticas masivas, documentando de forma científica cuándo el optimizador prefiere un escaneo completo debido a la alta cardinalidad de los datos.

### 4. Qué consultas optimizaron y qué diferencias encontraron antes y después?

Se analizaron y optimizaron consultas representativas sobre la base masiva:

- **Consulta de filtrado de productos por categoría y precio:** 
  * *Antes:* Requería un escaneo sobre la tabla de productos y un ordenamiento posterior en memoria (`Sort`).
  * *Después (con índice compuesto `(categoria_id, precio DESC)`):* Optimizó el acceso a los registros y redujo el tiempo de ejecución real de forma perceptible.

- **Consultas analíticas de múltiples JOINs y agregación:**
  * Se estudió el comportamiento de algoritmos complejos como `Nested Loop`, `Hash Join` y `Merge Join`, documentando cómo el motor combina los datos y cómo las estadísticas actualizadas mediante `ANALYZE` resultan vitales para la elección del plan óptimo por parte del optimizador.

### 5. Uso de IA (OpenCode / Kiro), decisiones adoptadas y descartadas

La inteligencia artificial se integró como motor primario de codificación y asistencia técnica bajo un marco de supervisión humana estricta:

- **Decisiones adoptadas:** Se aceptaron los scripts de carga masiva generados con `generate_series`, las propuestas iniciales de índices compuestos para filtrados por categoría y las estructuras de consultas analíticas y de ventana, tras comprobar su validez sintáctica y lógica.

- **Decisiones descartadas:** Se rechazaron o ajustaron aquellas sugerencias teóricas de índices que el motor desestimaba en la práctica (demostrado mediante `EXPLAIN ANALYZE`), priorizando siempre la evidencia empírica de PostgreSQL por encima de las recomendaciones genéricas de la IA, cumpliendo así con el criterio fundamental de la cátedra.

