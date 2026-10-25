-- ============================================================
-- Food Store — Unidad 5 — Parte B: prueba de auditoría
-- Base: practica_bd2_tp · Requiere: log_statement='mod' (o 'all')
-- Una lectura, una inserción, una actualización, un login fallido.
-- Ejecutar con psql y capturar el log del servidor (csvlog o stderr).
-- ============================================================

-- B1. LECTURA (no queda en log_statement='mod', sí en 'all'; sirve de control negativo)
SELECT * FROM v_productos_vigentes_con_categoria LIMIT 5;

-- B2. INSERCIÓN (debe quedar registrada con log_statement='mod')
INSERT INTO categoria (nombre, activo)
VALUES ('AUDIT_TEST_CAT_' || to_char(now(),'HH24MISS'), TRUE)
RETURNING id, nombre;

-- B3. ACTUALIZACIÓN (debe quedar registrada)
-- Usa la fila recién creada para no tocar datos reales:
UPDATE categoria
SET nombre = nombre || '_MOD'
WHERE nombre LIKE 'AUDIT\_TEST\_CAT\_%'
RETURNING id, nombre;

-- Limpieza de la fila de prueba (también queda auditada; demuestra DELETE):
-- DELETE FROM categoria WHERE nombre LIKE 'AUDIT\_TEST\_CAT\_%';

-- B4. INTENTO DE LOGIN FALLIDO (debe quedar en log_connections / auth)
-- Opción A (recomendada): intentar conectar como usuario inexistente desde shell:
--   psql "host=localhost dbname=practica_bd2_tp user=usuario_inexistente password=wrong" -c "SELECT 1;"
-- Opción B (dentro de sesión): forzar un error de permisos que simule autenticación fallida:
SELECT fn_autenticar('no_existe@foodstore.test', 'clave_erronea');
-- El operador debe ejecutar la Opción A en terminal y adjuntar el fragmento
--   FATAL: password authentication failed for user "usuario_inexistente"

-- Verificación posterior en el servidor:
-- SHOW log_connections; SHOW log_disconnections; SHOW log_statement;
