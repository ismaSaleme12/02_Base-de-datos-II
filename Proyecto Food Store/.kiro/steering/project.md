# Proyecto: Saleme_Ismael_Tp2 — Base de Datos II

## Contexto académico

Trabajo práctico de la materia **Base de Datos II** (ISMA).  
El objetivo es practicar operaciones SQL (DML, DDL, consultas, transacciones) sobre una base PostgreSQL de trabajo.

## Estructura del repositorio

```
Saleme_Ismael_Tp2/
├── db/backups/         # Respaldos pg_dump antes de cambios estructurales
├── .kiro/
│   └── steering/         # Archivos de contexto e instrucciones para Kiro
├── AGENTS.md             # Reglas de seguridad del repositorio (fuente de verdad)
└── Protocolo_Seguridad.md  # Protocolo detallado en español
```

## Convenciones generales

- El idioma de trabajo es **español** (comentarios, documentación, nombres de objetos).
- Todos los scripts SQL se escriben para **PostgreSQL** (versión compatible con `pg_dump`).
- Los archivos de respaldo se guardan en `./db/backups/` con el nombre `Food_Store_Copia_backup.sql`.
- No se crean archivos README ni documentación adicional salvo solicitud explícita.

## Base de datos

| Nombre              | Rol                                      |
|---------------------|------------------------------------------|
| `Food_Store`        | Base **original** — solo lectura, no tocar |
| `Food_Store_Copia`  | Copia de trabajo — todas las operaciones |

## Herramienta de respaldo

```bash
pg_dump -U postgres -h localhost -p 5432 -F p -f ".\db\backups\Food_Store_Copia_backup.sql" Food_Store_Copia
```
