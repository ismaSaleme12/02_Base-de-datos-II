-- ================================

-- Primer update

-- ================================


begin;

update producto
set precio = precio + 100
where id = 5;

commit;

rollback;

-- ================================

-- Segundo update

-- ================================


begin;

update producto
set precio = precio + 100
where id = 5;

commit;

-- Prueba 

select id, nombre, precio
from producto
where id = 5;


