# Design — Esquema de roles y permisos Food Store (Unidad 5)
## Simulación de salida de Kiro — Parte A
**Referencia:** `requirements.md` · **Motor:** PostgreSQL 16+

## 1. Jerarquía

```text
rol_app_lectura ──┐
                  ├──► app_web (LOGIN)
rol_app_escritura ─┘

rol_soporte ──► admin_datos (LOGIN)

rol_reportes ──► (sin login propio en v1; se asigna a futuro usuario BI)
```

Grupo = `NOLOGIN`, login = `LOGIN INHERIT NOSUPERUSER`.

## 2. Objeto `usuario` (reconstrucción previa a Parte A)

El esquema TP1 no tenía `usuario` con credenciales (`cliente` era el análogo y
`tp_fnbc_control_lote.sql` creó un `usuario(id)` mínimo). Para Unidad 5 se
reconstruye de forma idempotente (ver `sql/roles.sql` §0):

```sql
CREATE TABLE IF NOT EXISTS usuario (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    rol           VARCHAR(30) NOT NULL DEFAULT 'cliente'
                  CHECK (rol IN ('cliente','admin','soporte','reportes')),
    fecha_alta    DATE NOT NULL DEFAULT CURRENT_DATE,
    activo        BOOLEAN NOT NULL DEFAULT TRUE
);
-- + ALTER TABLE ... ADD COLUMN IF NOT EXISTS ... (por si existía usuario(id) mínimo)
-- + fn_autenticar(p_email, p_clave) y fn_resetear_password(p_email, p_nuevo_hash)
```

## 3. Roles de grupo

### 3.1 `rol_app_lectura` (RF-01) — lectura por vistas + columna

```sql
CREATE ROLE rol_app_lectura NOLOGIN;
GRANT SELECT ON v_productos_vigentes_con_categoria TO rol_app_lectura;
GRANT SELECT ON v_pedidos_con_cliente TO rol_app_lectura;
GRANT SELECT ON v_detalle_pedido_con_producto TO rol_app_lectura;
-- Permiso a nivel de COLUMNA sobre usuario (sin PII):
GRANT SELECT (id, nombre, rol, fecha_alta) ON usuario TO rol_app_lectura;
```

Excluye: tablas base, `email`, `password_hash`, VM, procedimientos de admin.

### 3.2 `rol_app_escritura` (RF-02) — sólo EXECUTE

```sql
CREATE ROLE rol_app_escritura NOLOGIN;
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, BIGINT[], INTEGER[], BIGINT) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO rol_app_escritura;
```

Sin `INSERT` directo en `pedido/detalle_pedido` (eludiría R1/R2).

### 3.3 `rol_soporte` (RF-03) — SELECT base sin credenciales

```sql
CREATE ROLE rol_soporte NOLOGIN;
GRANT SELECT ON categoria, producto, cliente, pedido, detalle_pedido TO rol_soporte;
-- CORREGIDO 2026-10-05 (verificacion real): REVOKE SELECT(col) NO recorta un
-- GRANT de tabla. Se usa REVOKE ALL + GRANT por columnas sin password_hash:
REVOKE ALL ON usuario FROM rol_soporte;
GRANT SELECT (id, nombre, email, rol, fecha_alta, activo) ON usuario TO rol_soporte;
```

> CORREGIDO 2026-10-05: la redacción anterior afirmaba que
> `REVOKE SELECT (password_hash)` bastaba. La ejecución real demostró que no:
> `has_column_privilege('rol_soporte','usuario','password_hash','SELECT')`
> seguía en true. La única forma válida es no otorgar la tabla y conceder sólo
> las columnas no sensibles (ver sql/roles.sql §4.3).

### 3.4 `rol_reportes` (RF-04) — agregados sin PII

```sql
CREATE ROLE rol_reportes NOLOGIN;
GRANT SELECT ON vm_facturacion_categoria_mes TO rol_reportes;
GRANT EXECUTE ON PROCEDURE sp_refrescar_facturacion() TO rol_reportes;
-- Permiso a nivel de COLUMNA para agregación por rol/mes:
GRANT SELECT (rol, fecha_alta) ON usuario TO rol_reportes;
```

## 4. Roles de login

```sql
CREATE ROLE app_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT
  PASSWORD 'CAMBIAR_POR_VAULT';
GRANT rol_app_lectura, rol_app_escritura TO app_web;

CREATE ROLE admin_datos LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT
  PASSWORD 'CAMBIAR_POR_VAULT';
GRANT rol_soporte TO admin_datos;
GRANT EXECUTE ON PROCEDURE sp_soft_delete_producto(BIGINT) TO admin_datos;
GRANT EXECUTE ON PROCEDURE sp_restaurar_producto(BIGINT) TO admin_datos;
GRANT EXECUTE ON PROCEDURE sp_refrescar_facturacion() TO admin_datos;
GRANT EXECUTE ON FUNCTION fn_total_pedido(BIGINT) TO admin_datos;
GRANT EXECUTE ON FUNCTION fn_resetear_password(TEXT, TEXT) TO admin_datos;
GRANT SELECT ON v_productos_vigentes_con_categoria TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON v_pedidos_con_cliente TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON v_detalle_pedido_con_producto TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON vm_facturacion_categoria_mes TO admin_datos WITH GRANT OPTION;
```

## 5. Higiene y futuro

```sql
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE practica_bd2_tp FROM PUBLIC;
GRANT CONNECT ON DATABASE practica_bd2_tp TO app_web, admin_datos;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

-- Tablas futuras heredan la misma política:
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_soporte;
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
  GRANT SELECT ON TABLES TO rol_reportes; -- se refina a columnas en revisión posterior
```

## 6. Alternativas descartadas

| Decisión | Alternativa descartada | Motivo |
|----------|------------------------|--------|
| Vistas + columnas para app | `GRANT SELECT` directo en tablas | Expondría `email/password_hash` |
| `EXECUTE` sólo en `sp_crear_pedido` | `INSERT` directo | Elude R1/R2 |
| Soporte sin `password_hash` | `GRANT SELECT` pleno en `usuario` | Expone credenciales |
| `rol_reportes` sin login | crear `usuario_bi` ya | Superficie de ataque innecesaria |
| `admin_datos` sin `SUPERUSER` | `SUPERUSER` | Omite todo control de acceso |

## 7. Verificación

```sql
\du
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','app_web','admin_datos')
ORDER BY grantee, table_name, privilege_type;
```
La salida real se adjunta en `docs/verificacion_roles.txt` (la pega el operador
tras ejecutar en su entorno; no se inventa).
