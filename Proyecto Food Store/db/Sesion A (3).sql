begin;

select id, nombre, precio
from producto
where id = 5
for update;

commit;