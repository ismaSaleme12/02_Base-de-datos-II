# Especificación del Plan de Mantenimiento, Respaldo y Recuperación — Food Store (Unidad 6)

**Proyecto:** Food Store  
**Motor:** PostgreSQL 16+  
**Base Principal:** `foodstore` (copia de trabajo: `Food_Store_Copia`)  
**Base de Restauración (Simulacro):** `foodstore_restore_test`  

---

## 1. Objetivo y Alcance
Establecer los procedimientos automatizados y periódicos para garantizar la disponibilidad, integridad, salud y recuperabilidad de la base de datos de Food Store ante posibles fallos o incidentes, definiendo los objetivos de RPO (Recovery Point Objective) y RTO (Recovery Time Objective).

---

## 2. Plan de Mantenimiento y Operaciones

| Tarea Mínima | Frecuencia Propuesta | Evidencia / Salida | Condición de Éxito / Terminación |
| :--- | :--- | :--- | :--- |
| **Respaldo de foodstore** | Diaria | Archivo `.dump` (formato custom `-Fc`) y archivo de log en `logs/`. | Ejecución exitosa de `pg_dump` con código de salida 0 y archivo generado > 0 bytes. |
| **Chequeo de salud** | Diaria | Salida de `health_check.sql` (tamaño, conexiones, tuplas muertas, consultas activas). | Identificación de métricas operativas normales y ausencia de bloqueos prolongados. |
| **Revisión de mantenimiento** | Semanal | Estado de tuplas muertas, estadísticas de `autovacuum` / `autoanalyze` (`maintenance.sql`). | Optimización de estadísticas y limpieza efectiva de tuplas muertas sin uso de `VACUUM FULL` periódico. |
| **Restauración de prueba** | Semanal | Base `foodstore_restore_test` validada mediante script de validación mínima. | Restauración completa sin errores y conteos de filas / validaciones lógicas correctas. |

---

## 3. Reglas de Seguridad y Normas Operativas
1. **Credenciales:** No se deben escribir contraseñas en texto plano dentro de los scripts (`backup_foodstore.ps1`, `restore_test.ps1`). Se utiliza la variable de entorno `$env:PGPASSWORD` o autenticación externa segura.
2. **Entornos Descartables:** La base de producción/principal (`foodstore` / `Food_Store_Copia`) nunca se elimina ni se sobrescribe durante los simulacros de desastre. Todas las pruebas de restauración se ejecutan exclusivamente en `foodstore_restore_test`.
3. **Formato de Respaldo:** Los respaldos se realizan en formato custom (`-Fc`) para permitir el uso selectivo y flexible de `pg_restore`.
4. **Validación Humana:** Todo script generado o asistido por herramientas de IA (OpenCode) debe ser inspeccionado y probado manualmente antes de considerarse apto para programación o producción.
