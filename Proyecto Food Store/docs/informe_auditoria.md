# Informe de auditoría — Parte B
**Food Store · PostgreSQL 16+ · Base `practica_bd2_tp` · 2026-10-05**

## 1. Parámetros modificados (teórico, a aplicar en el servidor de desarrollo)

| Parámetro | Valor requerido | Valor por defecto | Efecto |
|-----------|-----------------|-------------------|--------|
| `log_connections` | `on` | `off` | Registra cada intento de conexión (usuario, base, IP/puerto, PID) |
| `log_disconnections` | `on` | `off` | Registra cada desconexión con duración y PID para parear sesión |
| `log_statement` | `mod` | `none` | Registra INSERT/UPDATE/DELETE + DDL; no registra SELECT puros (usar `all` sólo en ventana de prueba) |
| `log_line_prefix` (recomendado) | `'%m [%p] %u@%d %h %a '` | variable | Antepone timestamp, PID, usuario, base, host, app para hacer el log legible y correlacionable |
| `logging_collector` | `on` | según distro | Necesario para capturar stderr en archivos; alternativamente `log_destination='csvlog'` |

Aplicación:

```ini
# postgresql.conf (desarrollo)
log_connections = on
log_disconnections = on
log_statement = 'mod'
log_line_prefix = '%m [%p] %u@%d %h %a '
logging_collector = on
```

```sql
SELECT pg_reload_conf();
SHOW log_connections; SHOW log_disconnections; SHOW log_statement;
```

## 2. Lectura del fragmento (`docs/log_auditoria_prueba.txt`)

Sobre el fragmento capturado tras `sql/auditoria_test.sql` es útil para auditoría:
**quién** (`%u` + rol de la sesión), **qué** (sentencia con `log_statement='mod'`),
**cuándo** (`%m` timestamp con ms), **desde dónde** (`%h` IP + puerto). El `PID [%p]`
permite parear `connection received → connection authorized → disconnection`.

Queda fuera del alcance del mecanismo nativo: el detalle **fila por fila**
(valores OLD/NEW, qué columnas cambiaron), el resultado de la sentencia
(¿cuántas filas afectó? ¿con qué parámetros enlazados si hay prepared statements?)
y la correlación con usuario de aplicación cuando hay pooler (todos llegan como
`app_web`). Para esa granularidad se necesitaría la extensión **pgaudit**
(a nivel de nociones: pgaudit registra clases de objetos y sentencias por rol,
incluyendo SELECT de tablas sensibles, con mucho más volumen y necesidad de
rotación/compresión del log).

## 3. ¿El log es un activo sensible? ¿Quién debe leerlo?

Sí. El propio archivo de log es un activo sensible porque contiene sentencias
con datos personales (emails en `WHERE`, hashes si se logran inserts en `usuario`),
patrones de acceso, IPs y horarios que permiten inferir comportamiento. Debe poder
leerlo sólo el rol administrador de la instancia / auditoría designada, con permiso
de lectura del SO restringido al usuario `postgres` (ej. `640 postgres:postgres`
o ACL equivalente) y sin `GRANT` general en el motor; los desarrolladores y soporte
acceden sólo a extractos anonimizados bajo solicitud. En producción se rota,
se retiene con plazo definido y se protege contra escritura.
