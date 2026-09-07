
-- =====================================================================

-- == Consulta A (Facturación por categoría y mes cruzando 4 tablas): == 

-- =====================================================================
explain analyze
select 
	
	c.nombre as categoria,
	to_char(p.fecha, 'YYYY-MM')  as mes,
	SUM(dp.cantidad * dp.precio_unitario) as facturacion_total,
	COUNT(distinct p.id) as total_pedido
	
from categoria c
join producto pr on pr.id = c.id
join detalle_pedido dp on dp.producto_id = pr.id
join pedido p on p.id = dp.pedido_id 

group by c.id, c.nombre, to_char(p.fecha, 'YYYY-MM')
order by mes desc, facturacion_total desc;


-- =======================================================================

-- == Consulta B (Gasto total y pedidos por cliente cruzando 3 tablas): == 

-- =======================================================================

explain analyze
select 
	
	cl.id as cliente_id,
	cl.nombre as nombre_cliente,
	COUNT(distinct p.id) as cantidad_pedidos,
	SUM(dp.cantidad * dp.precio_unitario) as gasto_total
	
from cliente cl
join pedido p on p.id = cl.id
join detalle_pedido dp on dp.pedido_id = p.id 
group by cl.id, cl.nombre
order by cliente_id  asc;

