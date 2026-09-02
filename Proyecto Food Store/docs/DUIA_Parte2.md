============================================================
DUIA - TP2
DECLARACIÓN DE USO DE INTELIGENCIA ARTIFICIAL
PARTE 2 - LABORATORIO DE CONCURRENCIA
============================================================


1. HERRAMIENTA UTILIZADA
============================================================

Herramienta:
OpenCode / ChatGPT

La IA fue utilizada como asistente durante el desarrollo de los
experimentos de concurrencia de la Parte 2.

La IA no ejecutó directamente las operaciones sobre la base de datos.
Las consultas fueron revisadas por el alumno y ejecutadas manualmente
en las sesiones de PostgreSQL.


============================================================
2. ESCENARIO 1 - LECTURA NO REPETIBLE
============================================================

------------------------------
PROMPT / CONSIGNA UTILIZADA
------------------------------

Se solicitó a la IA ayuda para reproducir una lectura no repetible
utilizando dos sesiones concurrentes sobre la base de datos del
proyecto.

Se trabajó primero con READ COMMITTED y posteriormente con
REPEATABLE READ, con el objetivo de comprobar el comportamiento de
ambos niveles de aislamiento.


------------------------------
QUÉ GENERÓ LA IA
------------------------------

La IA propuso los comandos SQL necesarios para iniciar las
transacciones, consultar el producto, modificarlo desde la segunda
sesión y volver a realizar la consulta desde la primera sesión.

También explicó la diferencia entre READ COMMITTED y
REPEATABLE READ y anticipó qué resultado debería observarse.


------------------------------
QUÉ SE ACEPTÓ
------------------------------

Se aceptaron las consultas SQL propuestas por la IA después de
revisarlas y comprender su funcionamiento.

Los comandos fueron ejecutados manualmente sobre la base de datos
de trabajo utilizando dos sesiones concurrentes.


------------------------------
QUÉ SE MODIFICÓ
------------------------------

No se realizaron modificaciones estructurales sobre la base de datos
para este escenario.

Los comandos fueron adaptados al producto utilizado en el proyecto
y ejecutados de acuerdo con el estado real de la base de datos.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

La IA explicó que una lectura no repetible ocurre cuando una
transacción realiza dos veces la misma consulta y obtiene resultados
diferentes porque otra transacción modificó y confirmó los datos
entre ambas consultas.

También explicó que READ COMMITTED permite que cada sentencia vea
los datos confirmados disponibles al momento de ejecutar esa
sentencia.

En cambio, REPEATABLE READ mantiene una visión consistente de los
datos durante la transacción, evitando que una segunda lectura del
mismo registro muestre un valor diferente.


------------------------------
VERIFICACIÓN
------------------------------

La explicación fue verificada ejecutando el experimento directamente
en PostgreSQL.

Con READ COMMITTED se observó que la segunda consulta pudo ver el
cambio confirmado por la Sesión B.

Con REPEATABLE READ se comprobó que la Sesión A mantuvo la visión
correspondiente al snapshot de su transacción.


------------------------------
RESULTADO
------------------------------

La explicación de la IA fue confirmada mediante el comportamiento
real observado en PostgreSQL.


============================================================
3. ESCENARIO 2 - LECTURA FANTASMA
============================================================

------------------------------
PROMPT / CONSIGNA UTILIZADA
------------------------------

Se solicitó a la IA ayuda para reproducir una lectura fantasma
utilizando dos sesiones concurrentes y una consulta COUNT sobre
los productos cuyo precio fuera mayor o igual a 1000.

También se solicitó comprobar el comportamiento utilizando
REPEATABLE READ.


------------------------------
QUÉ GENERÓ LA IA
------------------------------

La IA propuso utilizar una consulta COUNT(*) en la Sesión A y
realizar un INSERT desde la Sesión B sobre un producto que cumpliera
la condición de la consulta.

También indicó que con READ COMMITTED la segunda consulta podía
observar la nueva fila, mientras que con REPEATABLE READ la
transacción mantendría su snapshot.


------------------------------
QUÉ SE ACEPTÓ
------------------------------

Se aceptaron las consultas SQL propuestas por la IA luego de
revisarlas.

Los comandos fueron ejecutados manualmente utilizando dos sesiones
concurrentes.


------------------------------
QUÉ SE MODIFICÓ
------------------------------

No se modificó la estructura de la base de datos.

Se utilizó un producto de prueba generado específicamente para
reproducir el escenario de concurrencia.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

La IA explicó que una lectura fantasma ocurre cuando una transacción
repite una consulta sobre un conjunto de filas y, entre ambas
consultas, otra transacción inserta o elimina filas que cumplen
la condición de búsqueda.

La diferencia con una lectura no repetible es que en la lectura
fantasma cambia el conjunto de filas que cumple una condición,
mientras que en la lectura no repetible cambia el valor de una fila
ya existente.

También explicó que READ COMMITTED puede permitir que una segunda
consulta observe nuevas filas confirmadas por otra transacción,
mientras que REPEATABLE READ mantiene el snapshot de la transacción.


------------------------------
VERIFICACIÓN
------------------------------

La explicación fue verificada en PostgreSQL.

En READ COMMITTED, la primera consulta devolvió:

cantidad = 1

Después de que la Sesión B insertó y confirmó un nuevo producto,
la segunda consulta devolvió:

cantidad = 2

Luego se repitió el experimento utilizando REPEATABLE READ y la
segunda consulta mantuvo el mismo resultado observado al comienzo
de la transacción.


------------------------------
RESULTADO
------------------------------

La explicación de la IA fue confirmada mediante el comportamiento
observado directamente en PostgreSQL.


============================================================
4. ESCENARIO 3 - ESPERA POR BLOQUEO
============================================================

------------------------------
PROMPT / CONSIGNA UTILIZADA
------------------------------

Se solicitó a la IA ayuda para reproducir una espera por bloqueo
utilizando SELECT ... FOR UPDATE sobre una misma fila desde dos
sesiones concurrentes.

El objetivo fue comprobar qué ocurre cuando una sesión mantiene
bloqueada una fila y otra intenta modificarla.


------------------------------
QUÉ GENERÓ LA IA
------------------------------

La IA propuso que la Sesión A utilizara SELECT ... FOR UPDATE
sobre el producto con id = 5 y mantuviera abierta la transacción.

Luego propuso que la Sesión B intentara modificar la misma fila
mediante UPDATE.

También indicó que la Sesión B debería quedar esperando hasta que
la Sesión A liberara el bloqueo mediante COMMIT o ROLLBACK.


------------------------------
QUÉ SE ACEPTÓ
------------------------------

Se aceptaron los comandos propuestos por la IA después de
revisarlos y comprender su funcionamiento.

Los comandos fueron ejecutados manualmente en dos sesiones de
PostgreSQL.


------------------------------
QUÉ SE MODIFICÓ
------------------------------

No se modificó la estructura de la base de datos.

Se utilizó el producto con id = 5 para reproducir el bloqueo.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

La IA explicó que SELECT ... FOR UPDATE solicita un bloqueo sobre
las filas seleccionadas.

Mientras la transacción que posee el bloqueo permanezca abierta,
otra transacción que intente modificar esa misma fila debe esperar.

La espera termina cuando la primera transacción libera el bloqueo
mediante COMMIT o ROLLBACK.

Por lo tanto, el mecanismo involucrado en este escenario es el
bloqueo explícito de la fila generado por FOR UPDATE.


------------------------------
VERIFICACIÓN
------------------------------

La explicación fue verificada directamente en PostgreSQL.

La Sesión A ejecutó SELECT ... FOR UPDATE sobre el producto con
id = 5 y mantuvo abierta la transacción.

La Sesión B intentó modificar la misma fila mediante UPDATE y
quedó esperando.

Luego la Sesión A ejecutó COMMIT y liberó el bloqueo.

La Sesión B pudo continuar con su UPDATE y posteriormente realizó
COMMIT.

Finalmente se consultó nuevamente el producto y se comprobó que
el precio había pasado de 1300 a 1400.


------------------------------
RESULTADO
------------------------------

La explicación de la IA fue confirmada mediante el comportamiento
observado directamente en PostgreSQL.


============================================================
5. PARTICIPACIÓN Y RESPONSABILIDAD DEL ALUMNO
============================================================

La IA fue utilizada como herramienta de asistencia para comprender
los escenarios de concurrencia, proponer comandos SQL y explicar
los resultados esperados.

Revisé los comandos antes de ejecutarlos y realizé
manualmente las pruebas en PostgreSQL utilizando dos sesiones
concurrentes.

Los resultados no fueron aceptados únicamente por la explicación
de la IA. Cada comportamiento fue comprobado mediante la ejecución
real de las consultas en el motor PostgreSQL.

Las decisiones sobre qué comandos ejecutar, cuándo ejecutar cada
sesión y cómo interpretar los resultados fueron realizadas y
verificadas durante el desarrollo del trabajo.


============================================================
6. CONCLUSIÓN DEL USO DE IA
============================================================

La IA fue utilizada como motor de asistencia durante los tres
escenarios de concurrencia.

Sus explicaciones y propuestas fueron contrastadas con el
comportamiento real del motor PostgreSQL.

Los tres escenarios experimentados fueron:

1. Lectura no repetible.
2. Lectura fantasma.
3. Espera por bloqueo.

Las pruebas permitieron verificar en la práctica las explicaciones
proporcionadas por la IA y relacionarlas con los niveles de
aislamiento y los mecanismos de bloqueo utilizados por PostgreSQL.

La IA funcionó como herramienta de apoyo para la elaboración y
comprensión de los experimentos, mientras que la validación final
se realizó mediante pruebas reales sobre la base de datos.