# Protocolo de Seguridad

===================================
## 1. Copia de la base de datos
===================================

Todas las operaciones de este trabajo práctico se realizan sobre una copia de trabajo y no sobre la base original.

La base original del proyecto es:

`Food_Store`

La copia utilizada para el trabajo práctico es:

`Food_Store_Copia`

La copia se creó desde PostgreSQL utilizando:


CREATE DATABASE `Food_Store_Copia`
WITH TEMPLATE `Food_Store`;


De esta manera, `Food_Store` se conserva como base original y las pruebas, modificaciones y experimentos del TP se realizan sobre `Food_Store_Copia`.

===================================
## 2. Transacción
===================================

Todo script que modifique datos de la base de trabajo se prueba inicialmente dentro de una transacción.

El procedimiento utilizado es:


BEGIN;

-- operación a probar

ROLLBACK;


Primero se ejecuta `BEGIN` para iniciar la transacción. Luego se ejecuta la operación propuesta y se observa el resultado.

Durante esta etapa se verifica qué filas fueron afectadas y si el resultado coincide con lo esperado.

Mientras se esté realizando la prueba, no se confirma el cambio.

Se utiliza `ROLLBACK` para deshacer la operación y dejar la base en el estado anterior.

Una vez comprobado que el script funciona correctamente, la operación podrá repetirse dentro de una transacción y confirmarse mediante:


BEGIN;

-- operación verificada

COMMIT;


===================================
## 3. Respaldo
===================================

Antes de realizar cambios estructurales sobre la base de trabajo, como `ALTER`, `DROP` o migraciones, se realizará un respaldo independiente mediante `pg_dump`.

El respaldo se realizará sobre la copia de trabajo:

`Food_Store_Copia`

El comando utilizado será:


pg_dump -U postgres -h localhost -p 5432 -F p -f ".\backups\practica_bd2_tp_backup.sql" practica_bd2_tp

El archivo de respaldo se almacenará dentro de la carpeta `backups` del proyecto.

El respaldo se realizará antes de cualquier modificación estructural para disponer de una copia independiente en caso de que una modificación no pueda revertirse mediante una transacción.

===================================
## Aplicación del protocolo
===================================

El procedimiento de seguridad utilizado durante el trabajo práctico será:

1. Trabajar sobre `Food_Store_Copia` y no sobre `Food_Store`.
2. Probar las operaciones que modifican datos dentro de `BEGIN ... ROLLBACK` antes de confirmarlas.
3. Realizar un `pg_dump` de la copia antes de cambios estructurales.
4. Leer y revisar cualquier script generado por IA antes de ejecutarlo.
