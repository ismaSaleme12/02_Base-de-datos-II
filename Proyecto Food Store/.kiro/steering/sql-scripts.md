---
inclusion: manual
---

# Guía de escritura de scripts SQL

> Usar este steering file cuando se trabaje activamente con scripts `.sql`.  
> Activar con `#sql-scripts` en el chat.

## Convenciones de estilo

- **Palabras clave SQL** en MAYÚSCULAS (`SELECT`, `INSERT`, `WHERE`, `JOIN`, etc.).
- **Identificadores** (tablas, columnas, schemas) en `snake_case` minúsculas.
- Indentación de 4 espacios. No usar tabulaciones.
- Una cláusula por línea para queries de más de una condición.
- Comentarios en español con `--` para explicar la intención del bloque.

## Encabezado obligatorio en cada archivo `.sql`

```sql
-- ============================================================
-- Script  : <nombre_descriptivo>.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : YYYY-MM-DD
-- Desc    : <descripción breve en español>
-- ============================================================
```

## Plantilla DML con transacción

```sql
-- ============================================================
-- Script  : <nombre>.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : YYYY-MM-DD
-- Desc    : <descripción>
-- ============================================================

BEGIN;

-- Verificación previa (conteo esperado)
-- SELECT COUNT(*) FROM <tabla> WHERE <condición>;

<INSERT | UPDATE | DELETE>
    ...;

-- Verificar filas afectadas antes de confirmar
-- ROLLBACK;   <-- descomentar para probar sin confirmar
-- COMMIT;     <-- descomentar solo cuando el resultado es correcto

ROLLBACK; -- cambiar a COMMIT una vez verificado
```

## Plantilla DDL con respaldo previo

```sql
-- ============================================================
-- Script  : <nombre>.sql
-- Base    : Food_Store_Copia
-- Autor   : Saleme Ismael
-- Fecha   : YYYY-MM-DD
-- Desc    : <descripción>
-- PRECONDICIÓN: ejecutar pg_dump antes de correr este script
-- ============================================================

-- pg_dump -U postgres -h localhost -p 5432 -F p
--   -f ".\db\backups\practica_bd2_tp_backup.sql" Food_Store_Copia

ALTER TABLE <tabla>
    ...;
```

## Queries de solo lectura (SELECT)

No requieren transacción ni respaldo, pero deben:
- Indicar claramente la tabla y el propósito en un comentario inicial.
- Usar aliases descriptivos en español cuando mejoren la legibilidad.

```sql
-- Consulta: listar <descripción>
SELECT
    col1        AS columna_uno,
    col2        AS columna_dos
FROM <tabla>
WHERE <condición>
ORDER BY col1;
```
