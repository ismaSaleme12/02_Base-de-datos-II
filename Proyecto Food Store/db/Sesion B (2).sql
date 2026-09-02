begin;

insert into producto(nombre, precio, stock, categoria_id)
values ('Producto Fantasma', 1500, 10, 5);

commit;

begin;

insert into producto(nombre, precio, stock, categoria_id)
values ('Prodcuto fantasma 1', 2000, 10, 5);

commit;

rollback;