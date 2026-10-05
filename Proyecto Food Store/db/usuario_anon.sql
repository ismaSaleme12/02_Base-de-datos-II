-- ============================================================
-- Food Store — Unidad 5 — Parte D: tabla anonimizada determinista
-- Crea usuario_anon con datos sintéticos que preservan agregados
-- (rol y mes de alta) sin exponer PII. SQL puro, idempotente.
-- ============================================================

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id_sintetico INTEGER PRIMARY KEY,
    nombre_sint   VARCHAR(100) NOT NULL,
    email_sint    VARCHAR(150) NOT NULL UNIQUE,
    rol           VARCHAR(30) NOT NULL CHECK (rol IN ('cliente','admin','soporte','reportes')),
    mes_alta      CHAR(7) NOT NULL,          -- 'YYYY-MM' derivado de fecha_alta
    activo        BOOLEAN NOT NULL DEFAULT TRUE
);

-- Poblamiento determinista: conserva id, rol, mes y activo; sintetiza PII.
-- Determinista = misma entrada siempre produce mismo seudónimo (auditable).
INSERT INTO usuario_anon (id_sintetico, nombre_sint, email_sint, rol, mes_alta, activo)
SELECT
    u.id AS id_sintetico,
    'USUARIO_SINT_' || lpad(u.id::TEXT, 5, '0') AS nombre_sint,
    'usuario.' || lpad(u.id::TEXT, 5, '0') || '@sintetico.test' AS email_sint,
    u.rol,
    to_char(u.fecha_alta, 'YYYY-MM') AS mes_alta,
    u.activo
FROM usuario u
ORDER BY u.id;

-- Permisos: reportes y soporte leen anon; nadie escribe desde app:
GRANT SELECT ON usuario_anon TO rol_reportes, rol_soporte, admin_datos;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON usuario_anon FROM rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

COMMENT ON TABLE usuario_anon IS 'Copia anonimizada determinista de usuario: conserva rol/mes/activo, sintetiza nombre/email, omite password_hash.';

-- Conteo de control (debe coincidir con SELECT COUNT(*) FROM usuario):
-- SELECT (SELECT COUNT(*) FROM usuario) AS real, (SELECT COUNT(*) FROM usuario_anon) AS anon;
