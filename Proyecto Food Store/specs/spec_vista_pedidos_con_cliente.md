# spec: vista_pedidos_con_cliente (seguridad)

Objetivo: exponer pedidos enriquecidos con datos del cliente para reportes operativos, aplicando criterio de seguridad (sin exponer dato sensible).

Reportes: "Pedidos con datos del usuario/cliente" — usado en atención al cliente, logística y reportes de ventas.

Columnas a exponer:
- pedido_id (pedido.id)
- fecha (pedido.fecha)
- forma_pago (pedido.forma_pago)
- cliente_id (cliente.id)
- cliente_nombre (cliente.nombre)

Columna a ocultar por seguridad: cliente.email y cliente.telefono — datos personales sensibles. En el modelo original del enunciado es `usuario.contraseña`; en nuestro esquema real (cliente sin columna contraseña) el análogo sensible es email+telefono. La vista permite otorgar GRANT SELECT sobre la vista sin dar acceso a la tabla base cliente.

Filtro de vigencia: sin filtro de eliminado (el esquema actual no tiene columna pedido.eliminado ni producto.eliminado; se trabaja sobre Food_Store_Copia con datos vigentes). Si existiera `eliminado = FALSE` se incluiría.

Joins: pedido JOIN cliente ON pedido.cliente_id = cliente.id

Criterio de aceptación:
- Seguridad: `SELECT * FROM v_pedidos_con_cliente` NO expone email/telefono.
- Equivalencia: para validar, comparar contra consulta manual sin email/telefono:
```sql
SELECT p.id AS pedido_id, p.fecha, p.forma_pago, c.id AS cliente_id, c.nombre AS cliente_nombre
FROM pedido p JOIN cliente c ON p.cliente_id = c.id;
```
EXCEPT en ambos sentidos = 0 filas.

Nota de defensa oral: explicar por qué ocultar email/telefono es equivalente a ocultar contraseña en el modelo pedagógico, y cómo se otorga `GRANT SELECT ON v_pedidos_con_cliente TO rol_reportes;` sin grant sobre cliente.

Generado con Kiro → OpenCode.
