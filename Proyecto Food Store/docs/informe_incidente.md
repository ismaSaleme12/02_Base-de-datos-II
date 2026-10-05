# Informe de incidente — Parte C (simulacro controlado)
**Food Store · entorno propio `practica_bd2_tp` · 2026-10-05**

## 1. Hipótesis del ataque (basada en el log anonimizado)

Secuencia reconstruida: 3 llamadas a `fn_autenticar` con resultado `FALSE`
(fuerza bruta de baja intensidad o credential stuffing manual), seguida de una
llamada con resultado `TRUE`, seguida de `SELECT` masivo sobre `usuario`,
seguida de `GRANT admin_datos TO app_web` que el motor rechaza con
`permission denied / insufficient_privilege`. El `log_line_prefix` con PID
permite atribuir las 5 acciones a la misma sesión/origen, y el `FATAL` no aparece
porque `fn_autenticar` retorna booleano en lugar de abrir sesión nueva.

Hipótesis: compromiso de credencial de un usuario `cliente` (quizá por reuso de
clave) y posterior intento oportunista de escalamiento horizontal→vertical. No hay
evidencia en el log de exfiltración fuera del motor ni de persistencia; afirmar
un origen externo concreto o un malware sería ir más allá de lo que el log sustenta.

## 2. Respuesta de la IA vs. lo realmente ejecutado (lectura crítica)

Se entregó a la IA **sólo** el log anonimizado, sin contexto adicional. Respuesta
recibida (resumen): identificó correctamente fuerza bruta + éxito + lectura masiva
+ escalamiento fallido y propuso bloquear IP, rotar claves y revisar grants.

- **Acertó:** orden de la secuencia, naturaleza del escalamiento como el evento
  más grave, y que el `permission denied` demuestra que el diseño Parte A contuvo.
- **Omitió:** que `fn_autenticar` devuelve booleano (no genera `FATAL`), por lo que
  el conteo de fallidos debe hacerse sobre resultados, no sobre conexiones; y que
  la lectura masiva como `postgres` no prueba qué vería `app_web` (faltó `SET ROLE`).
- **Afirmación no sustentada:** la IA infirió fecha/hora como "madrugada sospechosa"
  y sugirió que el atacante vino de fuera; el log anonimizado no conserva zona
  horaria ni reputación de IP, por lo que esa inferencia es inválida y se descarta.

## 3. Decisión final de contención (del equipo, no automática)

1. **Bloqueo temporal del origen** a nivel `pg_hba` / firewall sólo si se confirma
   reincidencia desde la misma IP real (el dato sintético no bloquea nada).
2. **Rotación inmediata** de la clave de `victima.simulacro@foodstore.test` vía
   `fn_resetear_password` y de `app_web`/`admin_datos` por precaución
   (`ALTER ROLE ... PASSWORD`), con vault.
3. **Revertir/verificar roles:** `SELECT * FROM pg_auth_members` para confirmar que
   `app_web` no es miembro de `admin_datos`; `REVOKE` si hubiera éxito (hallazgo).
4. **Endurecer:** `log_statement='mod'` permanente, alerta ante >5 `FALSE` de
   `fn_autenticar` por minuto, y `ALTER TABLE usuario` para auditar intentos
   (tabla de intentos o pgaudit en fase 2).
5. **No ejecutar** automáticamente nada de lo sugerido por la IA sin validar en
   `BEGIN; ... ROLLBACK;` y con `pg_dump` previo.

**Constancia de escalamiento:** `SET ROLE app_web; GRANT admin_datos TO app_web;`
**falla** en ejecución real del 2026-10-05 (`ERROR: se ha denegado el permiso...`,
ver `log_simulacro_anonimizado.txt`), lo que confirma que la Parte A es correcta.

## 4. Hallazgo metodológico (constancia obligatoria)

La primera versión del script probaba el escalamiento con un bloque
`DO ... EXECUTE 'GRANT admin_datos TO app_web'`. Al ejecutarse como `postgres`
(superuser) el GRANT **tuvo éxito** y dejó a `app_web` como miembro de
`admin_datos` (verificado en `pg_auth_members`), falseando la prueba. Se
revocó de inmediato (`REVOKE admin_datos FROM app_web`) y se reescribió el
script con `SET ROLE app_web` —única forma válida de probar un escalamiento—,
tras lo cual el GRANT falló como se esperaba. Lección: las pruebas de
permisos deben correrse con el rol atacado, nunca como superuser.
