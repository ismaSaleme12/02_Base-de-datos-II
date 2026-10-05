-- ============================================================
-- Food Store — Unidad 5 — Parte C: simulacro de incidente
-- Ejecutar EXCLUSIVAMENTE contra practica_bd2_tp (entorno propio).
-- Secuencia: fallidos fn_autenticar → éxito → lectura masiva usuario
--            → intento fallido de escalamiento a admin_datos.
-- Con log_statement='all' temporalmente para capturar también SELECTs.
-- ============================================================

-- Preparación: asegurar un usuario víctima de prueba (no toca reales):
INSERT INTO usuario (nombre, email, password_hash, rol)
VALUES ('Victima Simulacro', 'victima.simulacro@foodstore.test', md5('ClaveCorrecta123'), 'cliente')
ON CONFLICT (email) DO NOTHING;

-- C1. Varios intentos FALLIDOS contra fn_autenticar (fuerza bruta simulada):
SELECT fn_autenticar('victima.simulacro@foodstore.test', 'wrong1') AS intento1;
SELECT fn_autenticar('victima.simulacro@foodstore.test', 'wrong2') AS intento2;
SELECT fn_autenticar('victima.simulacro@foodstore.test', 'wrong3') AS intento3;

-- C2. Inicio de sesión EXITOSO:
SELECT fn_autenticar('victima.simulacro@foodstore.test', 'ClaveCorrecta123') AS login_ok;
-- Resultado esperado: login_ok = TRUE (las 3 anteriores = FALSE).

-- C3. Lectura MASIVA de usuario (exfiltración simulada):
-- Con rol de bajo privilegio debería ver sólo columnas no sensibles;
-- si se ejecuta como postgres/admin se documenta como "qué vería un atacante
-- que ya obtuvo sesión válida".
SELECT id, nombre, email, rol, fecha_alta FROM usuario ORDER BY id;

-- C4. Intento de ESCALAMIENTO: otorgar membresía en admin_datos a rol bajo.
-- Debe FALLAR si el diseño Parte A es correcto (sólo superuser / createrole puede).
-- Ejecutar como app_web (o rol sin CREATEROLE) para verificar:
--   SET ROLE app_web;
--   GRANT admin_datos TO app_web;
--   RESET ROLE;
-- C4 CORRECTO: el escalamiento debe probarse como rol de bajo privilegio.
-- Si este script se corre como superuser (postgres), el GRANT tendría éxito
-- y falsearía la prueba (hallazgo metodológico del 2026-10-05: el DO+EXECUTE
-- como superuser otorgó admin_datos a app_web y hubo que revocarlo).
-- Por eso se usa SET ROLE:
SET ROLE app_web;
-- Debe fallar con: permission denied (sólo roles con ADMIN OPTION pueden otorgar):
GRANT admin_datos TO app_web;
RESET ROLE;

-- Constancia: si el GRANT tuviera éxito, es HALLAZGO CRÍTICO (defecto Parte A)
-- y debe corregirse (REVOKE + revisar CREATEROLE) antes de continuar.
