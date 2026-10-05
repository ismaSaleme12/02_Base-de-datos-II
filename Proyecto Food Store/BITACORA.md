# BITACORA.md — Uso de IA en TP Unidad 5
**Food Store · Base de Datos II · 2026-10-05**

| Prompt enviado a la IA | Respuesta relevante recibida (resumen) | Validación o corrección humana aplicada |
|---|---|---|
| Parte A: "Diseñá roles rol_app_lectura/escritura/soporte/reportes + app_web/admin_datos con mínimo privilegio sobre Food Store + usuario" | Propuso esquema por vistas/procedimientos + `GRANT ALL ON ALL TABLES` a `rol_soporte` y `app_web` "para simplificar" | **Rechazado el `GRANT ALL`**: se reemplazó por `GRANT SELECT` puntual + `REVOKE` explícito + columna `(id,nombre,rol,fecha_alta)`; el ALL violaba mínimo privilegio y exponía `password_hash`. Registrado como caso testigo |
| Parte A: "Auditá roles.sql y proponé mejoras" | Sugirió `SUPERUSER` a `admin_datos` y `CREATEDB` "para mantenimiento" | Rechazado: `admin_datos` queda `NOSUPERUSER NOCREATEDB`; el mantenimiento se hace como `postgres`. Se aceptó en cambio agregar `ALTER DEFAULT PRIVILEGES` |
| Parte A: "¿Falta reconstruir usuario/fn_autenticar?" | Confirmó que `cliente` era el análogo y que `usuario(id)` mínimo no servía | Validado contra `schema_tp1.sql:51` y `tp_fnbc_control_lote.sql:22`; se reconstruyó `usuario` idempotente + `fn_autenticar/fn_resetear_password` en `roles.sql §0` |
| Parte B: "¿Qué parámetros auditan conexiones y DML?" | `log_connections=on, log_disconnections=on, log_statement='mod'` + `log_line_prefix` | Verificado en docs PG16; se documentó en `informe_auditoria.md` y se advirtió que `mod` no registra SELECT (control negativo de la prueba) |
| Parte B: "Generá secuencia lectura/inserción/actualización/login fallido" | Script con `SELECT/INSERT/UPDATE` + `psql user=inexistente` para el `FATAL` | Ejecutado real 2026-10-05 en `practica_bd2_tp`: INSERT/UPDATE auditados, FATAL `no existe el rol` capturado en `log_auditoria_prueba.txt`; `log_statement` quedó en `mod` final |
| Parte C: [sólo log anonimizado] "Reconstruí qué ocurrió y proponé contención" | Hipótesis: fuerza bruta → éxito → exfiltración → escalamiento fallido; propuso bloquear IP, rotar claves | Contraste en `informe_incidente.md`: acertó secuencia, omitió naturaleza booleana de `fn_autenticar` y afirmó hora/IP sospechosa sin evidencia → se descartó esa inferencia; decisión final la tomó el equipo |
| Parte C: "Anonimizá este log antes de darlo a la IA" | Mapa `email→usuario.N@sintetico.test, IP→10.99.0.7, hash→[REDACTED]` | Aplicado y guardado en `log_simulacro_anonimizado.txt`; mapa inverso fuera del repo |
| Parte D: "Dame agregación por rol/mes sobre usuario_anon y su equivalente en usuario" | `GROUP BY rol, mes_alta` vs `GROUP BY rol, to_char(fecha_alta,'YYYY-MM')` + chequeo `EXCEPT` cruzado | Ejecutado real: 7 grupos idénticos, `EXCEPT` 0 filas, 9 vs 9 usuarios en `verificacion_equivalencia.md` |
| Ejecución real Parte A (sin IA): verificación de `REVOKE SELECT(col)` | Se asumía que `REVOKE SELECT(password_hash)` recortaba el `GRANT` de tabla | **Falso**: `has_column_privilege` siguió true; se corrigió a `REVOKE ALL + GRANT por columnas` en `roles.sql §4.3` |
| Ejecución real Parte C (sin IA): prueba de escalamiento con `DO+EXECUTE` | El bloque parecía una prueba segura sin cambio de sesión | **Falso**: como superuser el GRANT tuvo éxito y dejó a `app_web` en `admin_datos`; se revocó y se reescribió con `SET ROLE app_web` (falla como debe) |

## Caso más significativo de error detectado (con ejecución real)

El más significativo pasó de ser un `GRANT ALL` hipotético a **dos defectos
reales encontrados al ejecutar**: (1) el `REVOKE SELECT (password_hash)` no
recorta un `GRANT SELECT` de tabla —`password_hash` seguía legible para
`rol_soporte` y hubo que cambiar a `REVOKE ALL + GRANT por columnas`— y (2) el
bloque `DO+EXECUTE 'GRANT admin_datos'` corrido como superuser otorgó de verdad
el rol a `app_web` y falseó la prueba de escalamiento (se revocó y se reescribió
con `SET ROLE`). Ambos se detectaron sólo porque se ejecutó y se verificó con
`has_column_privilege` y `pg_auth_members`, no por revisión teórica. El `GRANT ALL`
propuesto por la IA se rechazó en el diseño por el mismo criterio y quedó como
antecedente.

## Historial Git

```text
feat(seguridad): diseño e implementacion de roles y permisos (Parte A)
feat(auditoria): configuracion y scripts de prueba de auditoria (Parte B)
feat(incidente): simulacro de brecha y reconstruccion forense (Parte C)
feat(anonimizacion): scripts de datos sinteticos y agregacion (Parte D)
docs(bitacora): consolidacion de interacciones con IA y cierre (Parte E)
test(evidencia): ejecucion real en practica_bd2_tp y correcciones validadas (A-D)
```
(Ver `git log --oneline` para los hashes vigentes.)

Un commit por parte, mensajes legibles. Si el historial quedara desordenado, la
próxima vez se trabajaría en rama `tp-u5` con PR por parte en lugar de commits
directos a `main`.
