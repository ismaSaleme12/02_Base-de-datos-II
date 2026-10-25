-- ============================================================================
-- maintenance.sql — Revisión y Mantenimiento Justificado (Unidad 6 - Food Store)
-- Motor: PostgreSQL 16+
-- ============================================================================

\echo '============================================================================'
\echo 'PASO 1: Diagnóstico previo del estado de tablas, tuplas muertas y estadísticas'
\echo '============================================================================'

SELECT 
    schemaname,
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '============================================================================'
\echo 'PASO 2: Acción de mantenimiento segura y justificada'
\echo '============================================================================'
\echo 'JUSTIFICACIÓN:'
\echo 'Tras la inserción masiva de datos (200k pedidos, 50k productos) y operaciones'
\echo 'frecuentes de actualización/borrado, las tablas principales (pedido, detalle_pedido)'
\echo 'acumulan tuplas muertas y estadísticas obsoletas en el optimizador de consultas.'
\echo 'Se ejecuta ANALYZE y VACUUM estándar (sin FULL) para actualizar estadísticas'
\echo 'y liberar espacio reutilizable en páginas sin bloquear lecturas ni escrituras,'
\echo 'evitando estrictamente VACUUM FULL por su bloqueo exclusivo y reasignación de disco.'
\echo '============================================================================'

-- Mantenimiento seguro sobre tablas críticas de Food Store
ANALYZE VERBOSE categoria;
ANALYZE VERBOSE cliente;
ANALYZE VERBOSE producto;
ANALYZE VERBOSE pedido;
ANALYZE VERBOSE detalle_pedido;

-- VACUUM estándar no bloqueante sobre tablas con mayor actividad de tuplas muertas
VACUUM VERBOSE ANALYZE pedido;
VACUUM VERBOSE ANALYZE detalle_pedido;

\echo '============================================================================'
\echo 'PASO 3: Verificación posterior del mantenimiento'
\echo '============================================================================'

SELECT 
    schemaname,
    relname AS tabla,
    n_live_tup AS tuplas_vivas,
    n_dead_tup AS tuplas_muertas,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY relname;
