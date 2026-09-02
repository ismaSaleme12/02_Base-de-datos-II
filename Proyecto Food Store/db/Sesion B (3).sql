begin;

update producto
set precio = precio + 100
where id = 5;

commit;

select id, nombre, precio
from producto
where id = 5;