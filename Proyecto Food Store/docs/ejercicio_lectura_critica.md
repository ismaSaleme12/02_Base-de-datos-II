============================================================
PARTE 3 - LECTURA CRITICA
============================================================


============================================================
PRIMER LECTURA CRITICA - SCRIPT 1
============================================================

En este script tenemos: 

-----------------------
UPDATE funcion
SET activa = FALSE;
-----------------------

La intencion de este es:

 - "Dar de baja las funciones de las peliculas que fueron retiradas de cartel".

El problema de este script es que no tiene un WHERE, asi que desactiva todas las funciones, incluso las de las peliculas que aun estan en el cartel.

Suponiendo que las tablas son asi:

-------------------
pelicula
---------
id
titulo
retirada
-------------------

-------------------
funcion
---------
id
pelicula_id
fecha
activa
-------------------

Una correcion posible seria: 

-----------------------
UPDATE funcion f
SET activa = FALSE
FROM pelicula p 
WHERE f.pelicula_id = p.id
  AND p.retirada = TRUE;
-----------------------

Ahora si:

 - Busca la pelicula asociada a cada funcion.
 - Comprueba si esta retirada.
 - Solamente desactiva esas funciones.


============================================================
PRIMER LECTURA CRITICA - SCRIPT 2
============================================================

En este script tenemos:

-----------------------
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
-----------------------

La intencion de este es:

    - "Eliminar las categorias que no tienen ningun producto asociado."

El problema de esto es que surgen inconvenientes en NOT IN con el valor NULL. Si en la lista de valores que devuelve la subconsulta,hay un valor NULL, puede producir UNKNOW y el DELETE no se comportara como se pretende.

Suponiendo que las tablas son asi:

-----------------
categoria
---------
id
nombre
-----------------

-----------------
producto
---------
id
nombre
categoria_id
-----------------

Una correcion posible y mas segura seria: 

-----------------------
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1
    FROM producto p
    WHERE p.categoria_id = c.id
);
-----------------------

Aca cambia completamente la forma de plantear la pregunta.

Ya no se interpreta como:

 - "Elimina las categorias cuyo ID no este dentro de una lista."

Se interpreta como:

 - "Elimina la categoria para la cual NO EXISTE ningun producto asociado."

Y evita tambien el problema logico de NULL que presenta el NOT IN.