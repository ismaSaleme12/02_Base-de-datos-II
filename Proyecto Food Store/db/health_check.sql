-- ============================================================================
-- health_check.sql — Controles de Salud y Monitoreo (Unidad 6 - Food Store)
-- Motor: PostgreSQL 16+
-- ============================================================================

\echo '=== 1. TAMAÑO DE LA BASE DE DATOS ==='
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_actual_db;

\echo '=== 2. ACTIVIDAD DE CONEXIONES Y TRANSACCIONES ==='
SELECT 
    datname AS base_datos,
    numbackends AS conexiones_activas, 
    xact_commit AS transacciones_commit, 
    xact_rollback AS transacciones_rollback,
    blks_read AS bloques_leidos_disco,
    blks_hit AS bloques_en_cache,
    ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS ratio_cache_hit_pct
FROM pg_stat_database
WHERE datname = current_database();

\echo '=== 3. ESTADO DE TABLAS Y TUPLAS MUERTAS (AUTOVACUUM) ==='
SELECT 
    schemaname,
    relname AS tabla, 
    n_live_tup AS tuplas_vivas, 
    n_dead_tup AS tuplas_muertas,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS porcentaje_muertas,
    last_vacuum,
    last_autovacuum, 
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;

\echo '=== 4. CONSULTAS ACTIVAS (EXCLUYENDO IDLE) ==='
SELECT 
    pid, 
    usename AS usuario,
    state, 
    now() - query_start AS duracion, 
    query 
FROM pg_stat_activity 
WHERE datname = current_database() 
  AND state <> 'idle'
  AND pid <> pg_backend_pid();
