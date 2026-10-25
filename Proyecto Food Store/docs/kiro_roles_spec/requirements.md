# Requirements — Esquema de roles y permisos Food Store (Unidad 5)
## Simulación de salida de Kiro — Parte A
**Proyecto:** Food Store · **Motor:** PostgreSQL 16+ · **Base:** `practica_bd2_tp`
**Fecha:** 2026-10-05 · **Autor:** Equipo TP Unidad 5

> Este documento simula la especificación generada con Kiro antes de escribir `sql/roles.sql`.
> Planificar antes de otorgar es aplicar el mínimo privilegio.

## 1. Contexto

Food Store gestiona `categoria`, `producto`, `cliente`, `pedido`, `detalle_pedido`,
más la tabla `usuario` (acceso a la aplicación) reconstruida para la Unidad 5 porque
el esquema TP1–TP4 usaba `cliente` como análogo y el artefacto `usuario(id)` mínimo
de `tp_fnbc_control_lote.sql` no cubre autenticación. Vistas: `v_productos_vigentes_con_categoria`,
`v_pedidos_con_cliente`, `v_detalle_pedido_con_producto`, materializada
`vm_facturacion_categoria_mes`. Rutinas: `sp_crear_pedido`, `sp_soft_delete_producto`,
`sp_restaurar_producto`, `sp_refrescar_facturacion`, `fn_total_pedido`,
`fn_autenticar`, `fn_resetear_password`.

## 2. Principio rector

Mínimo privilegio: cada rol recibe sólo el privilegio que habilita su operación
justificada. Sin DDL para roles de grupo. Sin `SUPERUSER`. Sin contraseñas en el repo.

## 3. Roles requeridos (justificación en una oración)

### 3.1 Grupo

- **RF-01 `rol_app_lectura`**: `SELECT` sobre las 3 vistas no materializadas + `SELECT(id,nombre,rol,fecha_alta)` sobre `usuario`, porque la app sólo necesita catálogo y pedidos sin PII (sin `email` ni `password_hash`).
- **RF-02 `rol_app_escritura`**: `EXECUTE` sobre `sp_crear_pedido` y `fn_autenticar`, porque crear pedidos y autenticar son los únicos puntos de escritura legítimos desde la web y encapsulan R1/R2.
- **RF-03 `rol_soporte`**: `SELECT` sobre las 5 tablas base + `usuario` (excepto columna `password_hash`), porque diagnosticar exige ver datos vigentes e inactivos pero nunca credenciales ni escrituras.
- **RF-04 `rol_reportes`**: `SELECT` sobre `vm_facturacion_categoria_mes` + `EXECUTE` sobre `sp_refrescar_facturacion` + `SELECT(rol,fecha_alta)` sobre `usuario`, porque BI sólo necesita agregados por rol/mes y refrescar el dashboard sin leer PII.

### 3.2 Login

- **RL-01 `app_web`**: hereda `rol_app_lectura` + `rol_app_escritura`, `LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE`, porque es la identidad de la aplicación web y concentra exactamente leer-catálogo + crear-pedido + autenticar.
- **RL-02 `admin_datos`**: hereda `rol_soporte` + `EXECUTE` sobre `sp_soft_delete_producto`, `sp_restaurar_producto`, `sp_refrescar_facturacion`, `fn_total_pedido`, `fn_resetear_password` y `SELECT WITH GRANT OPTION` sobre vistas, porque administra datos y delega lectura sin recibir `SUPERUSER` ni DDL.

## 4. Restricciones

- R1: ningún rol de grupo recibe `CREATE/ALTER/DROP`.
- R2: `rol_app_lectura` y `rol_reportes` acceden a `usuario` sólo a nivel de columna (nunca `password_hash` ni `email` completo).
- R3: ningún login es `SUPERUSER`.
- R4: passwords fuera del repo (vault / variable de entorno).
- R5: `REVOKE ALL ON SCHEMA public` de `CREATE` a `PUBLIC` como higiene inicial.

## 5. Criterios de aceptación

| ID | Criterio | Verificación esperada |
|----|----------|-----------------------|
| CA-01 | `app_web` lee catálogo | `SET ROLE app_web; SELECT * FROM v_productos_vigentes_con_categoria LIMIT 1;` → filas |
| CA-02 | `app_web` no lee `cliente` | `SELECT * FROM cliente LIMIT 1;` → `permission denied` |
| CA-03 | `app_web` no lee `password_hash` | `SELECT password_hash FROM usuario LIMIT 1;` → `permission denied` |
| CA-04 | `rol_soporte` lee inactivos | `SELECT * FROM producto WHERE activo=FALSE;` → filas (si existen) |
| CA-05 | `rol_soporte` no escribe | `UPDATE producto SET precio=0 WHERE id=1;` → `permission denied` |
| CA-06 | `rol_reportes` refresca VM | `CALL sp_refrescar_facturacion();` como miembro → ok |
| CA-07 | `rol_reportes` no lee `cliente` | `SELECT * FROM cliente LIMIT 1;` → `permission denied` |
| CA-08 | escalamiento falla | `GRANT admin_datos TO app_web;` como `app_web` → `permission denied` |
