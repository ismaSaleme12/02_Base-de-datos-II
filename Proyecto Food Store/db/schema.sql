
-- ========================================

-- TP 1 - Semana 1 - Base de datos II -- 

-- Alumno: Ismael Saleme -- 

-- Parte 4 -- DDl en postgreSQL --

-- ========================================

-- Creación de enum para forma de pago -- 

create type forma_pago as enum (
	'EFECTIVO',
	'TARJETA',
	'TRANSFERENCIA'
);

-- ================== --
-- Creación de tablas --
-- ================== --

create table categoria (
	id 		BIGINT 		generated always as identity primary key,
	nombre	VARCHAR(80)	not null unique,
	activo 	BOOlEAN		not null default true
);

create table producto (
	id 		BIGINT 		  generated always as identity primary key,
	nombre	VARCHAR	(100) not null,
	precio 	NUMERIC(10,2) not null,
	stock	INTEGER		  not null,
	activo  BOOLEAN 	  not null default true,
	categoria_id BIGINT   not null,
	
	constraint fk_producto_categoria
		foreign key (categoria_id)
		references categoria(id)
		on delete restrict,

	constraint check_producto_precio
		check (precio >= 0),
		
	constraint check_producto_stock
		check (stock >= 0)
);


create table cliente (
	id 	   BIGINT 		generated always as identity primary key,
	nombre VARCHAR(100) not null,
	email  VARCHAR(150) not null unique,
	telefono VARCHAR(30)
);


create table pedido (
	id    BIGINT 		  generated always as identity primary key,
	fecha TIMESTAMPTZ 	  not null default now(),
	forma_pago forma_pago not null,
	cliente_id BIGINT 		  not null,

	constraint fk_pedido_cliente
		foreign key (cliente_id)
		references   cliente(id)
		on delete restrict
);

create table detalle_pedido (
	pedido_id BIGINT not null,
	producto_id BIGINT not null,
	cantidad INTEGER not null,
	precio_unitario NUMERIC(10,2) not null,
	
	primary key (pedido_id, producto_id),
	
	constraint fk_detalle_pedido
		foreign key (pedido_id)
		references pedido(id)
		on delete restrict,
		
	constraint fk_detalle_producto
		foreign key (producto_id)
		references producto(id)
		on delete restrict,
		
	constraint check_detalle_cantidad
		check (cantidad > 0),
		
	constraint check_detalle_precio
		check (precio_unitario >= 0)
);

-- =================== --
-- Creación de indices --
-- =================== --

-- Indice 1: Acelera la busqueda de pedido que pertenecen a un cliente.
create index index_pedido_cliente
on pedido(cliente_id);

-- Indice 2: Acelera la busqueda de productos que pertenecen a una categoria.
create index index_producto_categoria
on producto(categoria_id);



