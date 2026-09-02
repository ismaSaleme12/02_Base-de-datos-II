============================================================
PARTE 2 - LABORATORIO DE CONCURRENCIA
============================================================


ESCENARIO 1 - LECTURA NO REPETIBLE
============================================================

OBJETIVO:

Demostrar una lectura no repetible utilizando dos sesiones concurrentes
y comparar el comportamiento de READ COMMITTED con REPEATABLE READ.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

La lectura no repetible ocurre cuando una transacción realiza dos veces
la misma consulta y obtiene resultados diferentes porque otra transacción
modificó y confirmó los datos entre ambas consultas.

En PostgreSQL, READ COMMITTED utiliza un snapshot diferente para cada
sentencia. Por eso, si otra transacción modifica un registro y realiza
COMMIT entre la primera y la segunda consulta, la segunda consulta puede
ver el nuevo valor.

REPEATABLE READ funciona de manera diferente: la transacción mantiene un
mismo snapshot durante toda su ejecución. Por lo tanto, aunque otra
transacción modifique y confirme los datos, las consultas posteriores
dentro de la primera transacción continúan viendo la versión correspondiente
al snapshot inicial.

Por este motivo, REPEATABLE READ evita las lecturas no repetibles.


------------------------------
REPRODUCCIÓN
------------------------------

SESIÓN A:

Se inició una transacción y se consultó el producto con id = 5.

Comandos:

begin;

select id, nombre, precio
from producto
where id = 5;

Resultado inicial:

id = 5
nombre = Producto Activo Prueba TP
precio = 1300


SESIÓN B:

Se modificó el precio del mismo producto y se confirmó la transacción.

Comandos:

begin;

update producto
set precio = precio + 100
where id = 5;

commit;


SESIÓN A:

Se volvió a ejecutar la misma consulta.

Resultado:

id = 5
nombre = Producto Activo Prueba TP
precio = 1400


------------------------------
RESULTADO
------------------------------

La primera consulta devolvió precio = 1300.

La segunda consulta devolvió precio = 1400.

Por lo tanto, con READ COMMITTED se produjo una lectura no repetible.


------------------------------
VERIFICACIÓN CON REPEATABLE READ
------------------------------

Se repitió el experimento utilizando:

begin;

set transaction isolation level repeatable read;

select id, nombre, precio
from producto
where id = 5;

Luego otra sesión modificó el registro y realizó COMMIT.

Al repetir la consulta desde la Sesión A, esta mantuvo la visión de los
datos correspondiente al snapshot tomado al comienzo de la transacción.


------------------------------
CONCLUSIÓN
------------------------------

La explicación de la IA fue confirmada por el motor PostgreSQL.

READ COMMITTED permitió observar el cambio confirmado por la otra sesión,
mientras que REPEATABLE READ mantiene el snapshot de la transacción y
evita que una misma consulta observe esos cambios posteriores.


============================================================


ESCENARIO 2 - LECTURA FANTASMA
============================================================

OBJETIVO:

Demostrar una lectura fantasma mediante una consulta COUNT repetida
dentro de una misma transacción mientras otra sesión inserta una nueva
fila que cumple la condición del WHERE.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

Una lectura fantasma ocurre cuando una transacción repite una consulta
sobre un conjunto de filas y, entre ambas consultas, otra transacción
inserta o elimina filas que cumplen la condición de búsqueda.

A diferencia de una lectura no repetible, donde cambia el valor de una
fila existente, en una lectura fantasma cambia el conjunto de filas que
cumple una determinada condición.

En este caso, un COUNT permite observar claramente el fenómeno.

Con READ COMMITTED, cada sentencia obtiene un snapshot nuevo. Por eso,
si otra sesión inserta una fila que cumple la condición y realiza COMMIT,
una consulta posterior puede incluir esa nueva fila.

Con REPEATABLE READ, la transacción mantiene el mismo snapshot durante
toda su ejecución, por lo que la nueva fila confirmada por otra
transacción no aparece en la consulta repetida.


------------------------------
REPRODUCCIÓN
------------------------------

SESIÓN A:

Se inició una transacción y se contó la cantidad de productos cuyo precio
es mayor o igual a 1000.

Comandos:

begin;

select count(*) as cantidad
from producto
where precio >= 1000;

Resultado inicial:

cantidad = 1


SESIÓN B:

Se insertó un nuevo producto cuyo precio cumple la condición.

Comandos:

begin;

insert into producto(nombre, precio, stock, categoria_id)
values ('Producto Fantasma', 1500, 10, 5);

commit;


SESIÓN A:

Se repitió exactamente la misma consulta:

select count(*) as cantidad
from producto
where precio >= 1000;

Resultado:

cantidad = 2


------------------------------
RESULTADO
------------------------------

La primera consulta devolvió:

cantidad = 1

La segunda consulta devolvió:

cantidad = 2

La nueva fila insertada por la Sesión B pasó a formar parte del resultado
de la segunda consulta.


------------------------------
VERIFICACIÓN CON REPEATABLE READ
------------------------------

Se repitió el experimento utilizando:

begin;

set transaction isolation level repeatable read;

select count(*) as cantidad
from producto
where precio >= 1000;

Luego la Sesión B insertó una nueva fila que cumplía la condición y
realizó COMMIT.

Al ejecutar nuevamente el COUNT desde la Sesión A, la nueva fila no fue
incorporada al resultado porque la transacción continuaba utilizando el
snapshot inicial.


------------------------------
CONCLUSIÓN
------------------------------

La explicación de la IA fue confirmada por el comportamiento observado
en PostgreSQL.

Con READ COMMITTED, la segunda consulta pudo observar la nueva fila
confirmada por la otra sesión.

Con REPEATABLE READ, la transacción mantuvo su snapshot y no incorporó
la nueva fila a la segunda consulta.


============================================================


ESCENARIO 3 - ESPERA POR BLOQUEO
============================================================

OBJETIVO:

Demostrar cómo funciona el bloqueo de una fila cuando dos sesiones
intentan acceder/modificar concurrentemente el mismo registro utilizando
FOR UPDATE.


------------------------------
EXPLICACIÓN DE LA IA
------------------------------

FOR UPDATE solicita un bloqueo de las filas seleccionadas para impedir
que otras transacciones las modifiquen o bloqueen de manera incompatible
mientras la transacción actual permanece abierta.

Si una segunda sesión intenta modificar esa misma fila mientras la
primera transacción mantiene el bloqueo, la segunda operación queda
esperando.

La espera termina cuando la primera transacción libera el bloqueo,
normalmente mediante COMMIT o ROLLBACK.

Por lo tanto, el mecanismo que explica este escenario es el bloqueo
de fila generado por FOR UPDATE, y no depende exclusivamente de cambiar
el nivel de aislamiento.


------------------------------
REPRODUCCIÓN
------------------------------

SESIÓN A:

Se inició una transacción y se seleccionó el producto con id = 5
utilizando FOR UPDATE.

Comandos:

begin;

select id, nombre, precio
from producto
where id = 5
for update;

Resultado:

id = 5
nombre = Producto Activo Prueba TP
precio = 1300

La fila quedó bloqueada por la Sesión A.


SESIÓN B:

Se inició otra transacción y se intentó modificar el mismo producto.

Comandos:

begin;

update producto
set precio = precio + 100
where id = 5;


------------------------------
RESULTADO
------------------------------

La operación de la Sesión B quedó esperando.

Esto ocurrió porque la Sesión A todavía mantenía el bloqueo sobre la fila
del producto con id = 5.


SESIÓN A:

Se liberó el bloqueo mediante:

commit;


SESIÓN B:

Después del COMMIT de la Sesión A, la operación que estaba esperando
pudo continuar.

Posteriormente se confirmó la transacción mediante:

commit;


------------------------------
VERIFICACIÓN
------------------------------

Se consultó nuevamente el producto:

select id, nombre, precio
from producto
where id = 5;


Resultado observado:

id = 5
nombre = Producto Activo Prueba TP
precio = 1400


------------------------------
CONCLUSIÓN
------------------------------

La explicación de la IA fue confirmada mediante el comportamiento
observado en PostgreSQL.

FOR UPDATE bloqueó la fila seleccionada en la Sesión A.

La Sesión B tuvo que esperar para poder modificar esa misma fila.

Cuando la Sesión A realizó COMMIT, el bloqueo se liberó y la Sesión B
pudo continuar con su operación.


============================================================
CONCLUSIÓN GENERAL DE LA PARTE 2
============================================================

Se reprodujeron tres escenarios de concurrencia utilizando dos sesiones
simultáneas sobre la base de datos del proyecto:

1. Lectura no repetible.
2. Lectura fantasma.
3. Espera por bloqueo.

En cada escenario primero se reprodujo el fenómeno utilizando dos
sesiones, luego se solicitó a la IA una explicación y finalmente se
verificó dicha explicación mediante pruebas realizadas directamente
sobre PostgreSQL.

Los resultados obtenidos permitieron confirmar que:

- READ COMMITTED puede permitir lecturas no repetibles porque cada
  sentencia utiliza un snapshot nuevo.

- REPEATABLE READ mantiene el snapshot de la transacción y evita que
  cambios posteriores confirmados por otras transacciones sean visibles
  dentro de ella.

- Las lecturas fantasma pueden observarse con READ COMMITTED cuando una
  segunda consulta incorpora filas nuevas que cumplen la condición.

- FOR UPDATE genera un bloqueo sobre las filas seleccionadas y una
  segunda transacción que intenta modificarlas debe esperar hasta que
  el bloqueo sea liberado mediante COMMIT o ROLLBACK.

En los tres escenarios, la explicación de la IA fue contrastada con el
motor real, siguiendo el procedimiento indicado en la consigna.