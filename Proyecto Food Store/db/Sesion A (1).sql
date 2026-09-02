-- ================================

-- 		   READ COMMITED 

-- ================================

BEGIN;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

SELECT id, nombre, precio
FROM producto
ORDER BY id
LIMIT 1;

-- ------------------------------
-- Consulta para ver el cambio 
-- ------------------------------

select id, nombre, precio
from producto 
where id = 5;

rollback;

-- ================================

-- REPETABLE READ

-- ================================

begin;

set transaction isolation level  repeatable read;

select id, nombre, precio
from producto 
where id = 5;

commit;

-- ------------------------------
-- Consulta despues del commit
-- ------------------------------

select id, nombre, precio
from producto 
where id = 5;

