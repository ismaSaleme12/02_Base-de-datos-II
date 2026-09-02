begin;

-- Primer consulta

select count(*) as cantidad
from producto
where precio >= 1000

-- Segunda consulta

select count(*) as cantidad
from producto
where precio >= 1000;

-- Tercer Consulta

rollback;

begin;

set transaction isolation level repeatable read;

select count(*) as cantidad
from producto
where precio >= 1000;

commit;