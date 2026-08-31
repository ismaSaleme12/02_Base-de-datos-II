# Protocolo de Seguridad — Base de Datos

> **Siempre activo.** Estas reglas se aplican en toda interacción que involucre SQL o la base de datos.

## Regla fundamental

**Nunca ejecutar nada contra `practica_bd2`.**  
Toda operación debe apuntar a `practica_bd2_tp`.

---

## DML (INSERT / UPDATE / DELETE)

Antes de confirmar cualquier modificación de datos, ejecutar primero en modo no-confirmado para verificar las filas afectadas:

```sql
BEGIN;

-- operación a verificar
-- (observar filas afectadas, revisar que el resultado sea el esperado)

ROLLBACK;  -- deshacer hasta que el resultado esté verificado
```

Una vez verificado que la operación es correcta:

```sql
BEGIN;

-- operación verificada

COMMIT;
```

## DDL / Cambios estructurales (ALTER, DROP, migraciones)

Antes de ejecutar cualquier cambio estructural, crear un respaldo:

```bash
pg_dump -U postgres -h localhost -p 5432 -F p -f ".\backups\practica_bd2_tp_backup.sql" practica_bd2_tp
```

El respaldo se almacena en `./backups/`. Este paso es obligatorio y previo a cualquier `ALTER TABLE`, `DROP`, o migración.

## Revisión de scripts

Todo script generado por IA o proveniente de fuente externa debe ser **inspeccionado antes de ejecutarse**.  
No ejecutar scripts a ciegas aunque provengan de Kiro.

## Resumen del flujo de seguridad

```
¿El script modifica DATOS?
  └─ Sí → BEGIN ... verificar → ROLLBACK → (si ok) BEGIN ... COMMIT

¿El script modifica ESTRUCTURA?
  └─ Sí → pg_dump primero → luego ejecutar el DDL

¿El script viene de IA o fuente externa?
  └─ Siempre → leer y revisar antes de ejecutar
```
