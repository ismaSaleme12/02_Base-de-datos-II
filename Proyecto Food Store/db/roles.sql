-- ============================================================
-- Food Store — Unidad 5 — Parte A: roles y permisos
-- Motor: PostgreSQL 16+ · Base: practica_bd2_tp
-- Principio: mínimo privilegio. SQL puro, sin ORM.
-- Orden: §0 reconstrucción idempotente → §1 grupos → §2 logins
--        → §3 grants/revokes → §4 default privileges → §5 verificación
-- PRECOND: pg_dump previo según AGENTS.md. Passwords por vault.
-- ============================================================

-- ================= §0. RECONSTRUCCIÓN IDEMPOTENTE DE usuario ================
-- El esquema TP1–TP4 no tenía usuario con credenciales (cliente era el análogo;
-- tp_fnbc_control_lote.sql dejó un usuario(id) mínimo). Se reconstruye sin romper.

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

-- Si existía el usuario(id) mínimo, agregar columnas faltantes:
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS nombre VARCHAR(100);
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS email VARCHAR(150);
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS rol VARCHAR(30) DEFAULT 'cliente';
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS fecha_alta DATE DEFAULT CURRENT_DATE;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS activo BOOLEAN DEFAULT TRUE;

-- NOT NULL donde sea seguro (si la tabla estaba vacía o ya poblada con defaults):
-- Se dejan como comprobación manual para no romper datos legacy:
-- ALTER TABLE usuario ALTER COLUMN nombre SET NOT NULL;
-- ALTER TABLE usuario ALTER COLUMN email SET NOT NULL;
-- ALTER TABLE usuario ALTER COLUMN password_hash SET NOT NULL;

-- fn_autenticar: compara hash (demo con md5; en producción usar pgcrypto crypt).
-- Retorna TRUE si email+clave coinciden y el usuario está activo.
CREATE OR REPLACE FUNCTION fn_autenticar(p_email TEXT, p_clave TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE v_hash TEXT; v_activo BOOLEAN;
BEGIN
    SELECT password_hash, activo INTO v_hash, v_activo
    FROM usuario WHERE email = p_email;
    IF NOT FOUND OR v_activo IS DISTINCT FROM TRUE THEN
        RETURN FALSE;
    END IF;
    -- Demo: md5(clave). Producción: crypt(p_clave, v_hash) = v_hash con pgcrypto.
    RETURN v_hash = md5(p_clave);
END;
$$;

COMMENT ON FUNCTION fn_autenticar(TEXT, TEXT) IS 'Autentica usuario por email+clave. Demo md5; prod pgcrypto. SECURITY DEFINER con search_path fijo.';

-- fn_resetear_password: sólo admin_datos (EXECUTE restringido abajo).
CREATE OR REPLACE FUNCTION fn_resetear_password(p_email TEXT, p_nuevo_hash TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE usuario SET password_hash = p_nuevo_hash WHERE email = p_email;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'fn_resetear_password: email % no existe.', p_email;
    END IF;
END;
$$;

COMMENT ON FUNCTION fn_resetear_password(TEXT, TEXT) IS 'Resetea hash de clave. Reservado a admin_datos vía GRANT EXECUTE.';

-- ================= §1. ROLES DE GRUPO (NOLOGIN) ==============================
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_app_lectura') THEN
        CREATE ROLE rol_app_lectura NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_app_escritura') THEN
        CREATE ROLE rol_app_escritura NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_soporte') THEN
        CREATE ROLE rol_soporte NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END $$;

-- ================= §2. ROLES DE LOGIN ========================================
-- Passwords de ejemplo: REEMPLAZAR por vault antes de producción.
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_web') THEN
        CREATE ROLE app_web LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT
            PASSWORD 'CAMBIAR_app_web_POR_VAULT';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='admin_datos') THEN
        CREATE ROLE admin_datos LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE INHERIT
            PASSWORD 'CAMBIAR_admin_datos_POR_VAULT';
    END IF;
END $$;

-- ================= §3. HIGIENE: revocar por defecto ==========================
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE practica_bd2_tp TO app_web, admin_datos;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

-- Quitar a PUBLIC cualquier resto sobre tablas del esquema (defensa en profundidad):
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- ================= §4. GRANTS POR ROL ========================================

-- ---- 4.1 rol_app_lectura: vistas + COLUMNAS no sensibles de usuario ---------
GRANT SELECT ON v_productos_vigentes_con_categoria TO rol_app_lectura;
GRANT SELECT ON v_pedidos_con_cliente TO rol_app_lectura;
GRANT SELECT ON v_detalle_pedido_con_producto TO rol_app_lectura;
-- Permiso a nivel de COLUMNA (exigido por consigna): sin email ni password_hash
GRANT SELECT (id, nombre, rol, fecha_alta) ON usuario TO rol_app_lectura;
-- Explícito: nada de escritura ni DDL
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM rol_app_lectura;

-- ---- 4.2 rol_app_escritura: sólo EXECUTE ------------------------------------
GRANT EXECUTE ON PROCEDURE sp_crear_pedido(BIGINT, forma_pago, BIGINT[], INTEGER[], BIGINT) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO rol_app_escritura;
-- Sin acceso a tablas base:
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM rol_app_escritura;
-- Re-otorgar sólo lo necesario ya fue hecho arriba (EXECUTE no es de tabla).

-- ---- 4.3 rol_soporte: SELECT diagnóstico sin credenciales -------------------
-- CORRECCIÓN validada por ejecución (2026-10-05): REVOKE SELECT(columna) NO
-- revoca nada si existe GRANT SELECT a nivel tabla. La forma correcta es
-- REVOKE ALL + GRANT por columnas excluyendo password_hash.
GRANT SELECT ON categoria TO rol_soporte;
GRANT SELECT ON producto TO rol_soporte;
GRANT SELECT ON cliente TO rol_soporte;
GRANT SELECT ON pedido TO rol_soporte;
GRANT SELECT ON detalle_pedido TO rol_soporte;
REVOKE ALL ON usuario FROM rol_soporte;
-- Columnas no sensibles (sin password_hash):
GRANT SELECT (id, nombre, email, rol, fecha_alta, activo) ON usuario TO rol_soporte;
-- Sin escritura ni DDL:
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM rol_soporte;

-- ---- 4.4 rol_reportes: VM + COLUMNAS agregables -----------------------------
GRANT SELECT ON vm_facturacion_categoria_mes TO rol_reportes;
GRANT EXECUTE ON PROCEDURE sp_refrescar_facturacion() TO rol_reportes;
-- Permiso a nivel de COLUMNA para agregación por rol/mes (sin PII):
GRANT SELECT (rol, fecha_alta) ON usuario TO rol_reportes;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM rol_reportes;

-- ---- 4.5 Membresías ----------------------------------------------------------
GRANT rol_app_lectura TO app_web;
GRANT rol_app_escritura TO app_web;
GRANT rol_soporte TO admin_datos;

-- Privilegios directos exclusivos de admin_datos:
GRANT EXECUTE ON PROCEDURE sp_soft_delete_producto(BIGINT) TO admin_datos;
GRANT EXECUTE ON PROCEDURE sp_restaurar_producto(BIGINT) TO admin_datos;
GRANT EXECUTE ON PROCEDURE sp_refrescar_facturacion() TO admin_datos;
GRANT EXECUTE ON FUNCTION fn_total_pedido(BIGINT) TO admin_datos;
GRANT EXECUTE ON FUNCTION fn_resetear_password(TEXT, TEXT) TO admin_datos;
GRANT SELECT ON v_productos_vigentes_con_categoria TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON v_pedidos_con_cliente TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON v_detalle_pedido_con_producto TO admin_datos WITH GRANT OPTION;
GRANT SELECT ON vm_facturacion_categoria_mes TO admin_datos WITH GRANT OPTION;

-- admin_datos NO recibe SUPERUSER/CREATEDB/CREATEROLE (ver creación §2).

-- ================= §5. DEFAULT PRIVILEGES (tablas futuras) ====================
-- Las tablas que cree admin_datos heredan la misma política:
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_soporte;

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_reportes;

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM rol_app_lectura;
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM rol_soporte;
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM rol_reportes;

-- ================= §6. VERIFICACIÓN (pegar salida en docs/verificacion_roles.txt)
-- \du
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes','app_web','admin_datos')
-- ORDER BY grantee, table_name, privilege_type;
-- -- Columnas:
-- -- SELECT grantee, table_name, column_name, privilege_type
-- -- FROM information_schema.role_column_grants
-- -- WHERE grantee IN ('rol_app_lectura','rol_reportes','rol_soporte')
-- -- ORDER BY grantee, table_name, column_name;
