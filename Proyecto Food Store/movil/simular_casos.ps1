# =============================================================================
#  TP 8 - Unidad 8 - Food Store en la feria
#  Consigna 2.c - Simulacion de los casos C2 a C6
# -----------------------------------------------------------------------------
#  Orquesta la secuencia que pide la catedra para cada caso:
#     preparar borrador -> cambiar el servidor -> nueva instantanea ->
#     recargar la cache -> correr el semaforo
#
#  Requiere:
#    - PGPASSWORD en el entorno (no se escribe en ningun archivo)
#    - sqlite3 en el PATH, o pasar -Sqlite3 <ruta>\sqlite3.exe
#
#  Uso:
#    $env:PGPASSWORD = "..."
#    .\simular_casos.ps1 -Sqlite3 "C:\ruta\sqlite3.exe"
# =============================================================================

param(
    [string]$Sqlite3 = "sqlite3",
    [string]$PgHost  = "localhost",
    [int]   $PgPort  = 5432,
    [string]$PgUser  = "postgres",
    [string]$PgDb    = "Food_Store_Copia"
)

$ErrorActionPreference = "Continue"
$env:PGCLIENTENCODING  = "UTF8"

$Movil = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root  = Split-Path -Parent $Movil
$Db    = Join-Path $Movil "foodstore_movil.db"
$Snaps = Join-Path $Movil "snapshots"
New-Item -ItemType Directory -Force $Snaps | Out-Null

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"

function Titulo($t) {
    Write-Output ""
    Write-Output ("=" * 78)
    Write-Output "  $t"
    Write-Output ("=" * 78)
}

function SQ {
    Push-Location $Movil
    & $Sqlite3 $Db @args 2>&1
    Pop-Location
}

function SQF($file) {
    Push-Location $Movil
    & $Sqlite3 $Db ".read $file" 2>&1
    Pop-Location
}

function PSQL($file) {
    & $Psql -U $PgUser -h $PgHost -p $PgPort -w -d $PgDb -f (Join-Path $Root $file) 2>&1
}

function ExportarSnapshot($destino) {
    $abs = (Join-Path $Movil $destino) -replace '\\', '/'
    "\copy (SELECT * FROM v_snapshot_movil) TO '$abs' CSV HEADER" |
        & $Psql -U $PgUser -h $PgHost -p $PgPort -w -d $PgDb 2>&1
}

function RecargarCache($csv) {
    $ruta = $csv -replace '\\', '/'
    Push-Location $Movil
    & $Sqlite3 $Db ".read schema_snapshot.sql"
    & $Sqlite3 $Db ".import --csv --skip 1 $ruta snapshot_servidor"
    & $Sqlite3 $Db ".read cargar_snapshot.sql"
    Pop-Location
}

function MostrarSolicitud($uuid) {
    SQ ".headers on" ".mode table" "SELECT c.solicitud_uuid, c.estado, c.motivo FROM cola_sync c WHERE c.solicitud_uuid = '$uuid';"
}

# -----------------------------------------------------------------------------
Titulo "ESTADO INICIAL"
SQ ".headers on" ".mode table" "SELECT count(*) AS productos, sum(disponible) AS vendibles, sum(eliminado) AS bajas FROM producto_cache;"

# -----------------------------------------------------------------------------
Titulo "CASO C5 - Borrador sin cambios (esperado: SIMULADO_APROBADO)"
SQF "casos\c5_borrador_sin_cambios.sql"
SQF "semaforo.sql"
MostrarSolicitud "50000000-0000-4000-8000-000000000005"

# -----------------------------------------------------------------------------
Titulo "CASO C3 - Mas unidades de las que quedan (esperado: RECHAZADO)"
SQF "casos\c3_stock_insuficiente.sql"
SQF "semaforo.sql"
MostrarSolicitud "30000000-0000-4000-8000-000000000003"

# -----------------------------------------------------------------------------
Titulo "CASO C2 (1/2) - El servidor sube el precio del producto 5"
SQF "casos\c2a_borrador_precio_viejo.sql"
PSQL "db\tp8_caso_c2_sube_precio.sql"
ExportarSnapshot "snapshots\snapshot_c2_precio.csv"
RecargarCache "snapshots\snapshot_c2_precio.csv"
SQF "semaforo.sql"
MostrarSolicitud "2a000000-0000-4000-8000-000000000002"

# -----------------------------------------------------------------------------
Titulo "CASO C2 (2/2) - El cliente acepta el precio nuevo (esperado: SIMULADO_APROBADO)"
SQF "casos\c2b_acepta_precio_nuevo.sql"
SQF "semaforo.sql"
MostrarSolicitud "2a000000-0000-4000-8000-000000000002"
MostrarSolicitud "2b000000-0000-4000-8000-000000000002"

# -----------------------------------------------------------------------------
Titulo "CASO C4 - Producto dado de baja (esperado: RECHAZADO)"
SQF "casos\c4_borrador_producto_vigente.sql"
PSQL "db\tp8_caso_c4_baja_logica.sql"
ExportarSnapshot "snapshots\snapshot_c4_baja.csv"
RecargarCache "snapshots\snapshot_c4_baja.csv"
SQF "semaforo.sql"
MostrarSolicitud "40000000-0000-4000-8000-000000000004"

Titulo "CASO C4 - El producto sale del catalogo pero la fila queda"
SQ ".headers on" ".mode table" "SELECT id, nombre, disponible, eliminado FROM producto_cache WHERE id = 6;"
SQ ".headers on" ".mode table" "SELECT count(*) AS productos_6_en_catalogo FROM producto_cache WHERE id = 6 AND disponible = 1 AND eliminado = 0;"

# -----------------------------------------------------------------------------
Titulo "CASO C6 - Reenvio con el mismo UUID (esperado: error de clave primaria)"
$antes = SQ "SELECT group_concat(solicitud_uuid || '=' || estado, '|') FROM (SELECT * FROM cola_sync ORDER BY solicitud_uuid);"
SQF "casos\c6_reenvio_mismo_uuid.sql"
SQF "semaforo.sql"
$despues = SQ "SELECT group_concat(solicitud_uuid || '=' || estado, '|') FROM (SELECT * FROM cola_sync ORDER BY solicitud_uuid);"
if ($antes -eq $despues) {
    Write-Output "IDEMPOTENTE: repetir la simulacion no reevaluo ninguna solicitud."
} else {
    Write-Output "ATENCION: el estado de las solicitudes cambio al repetir."
}

# -----------------------------------------------------------------------------
Titulo "ESTADO FINAL DE LA COLA"
SQ ".headers on" ".mode table" "SELECT solicitud_uuid, estado, motivo FROM cola_sync ORDER BY solicitud_uuid;"

# -----------------------------------------------------------------------------
Titulo "PRUEBA FINAL EN POSTGRESQL - pedidos y stock no cambiaron"
PSQL "db\tp8_verificacion_final.sql"
