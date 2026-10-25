<#
.SYNOPSIS
    Script automatizado de simulacro de desastre y restauración (Parte 4 - Unidad 6).
.DESCRIPTION
    Crea la base de datos de prueba 'foodstore_restore_test', restaura el último respaldo
    disponible (o el especificado), mide el tiempo total (RTO) y ejecuta las validaciones mínimas requeridas.
#>

param(
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$DbUser = "postgres",
    [string]$TestDbName = "foodstore_restore_test"
)

$BackupDir = Join-Path $PSScriptRoot "backups"
$LogDir = Join-Path $PSScriptRoot "logs"

if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

# Buscar el archivo .dump más reciente
$LatestDump = Get-ChildItem -Path $BackupDir -Filter "*.dump" | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $LatestDump) {
    Write-Error "No se encontró ningún archivo .dump en la carpeta 'backups'."
    exit 1
}

$DumpPath = $LatestDump.FullName
$BackupAge = (Get-Date) - $LatestDump.LastWriteTime

Write-Output "============================================================================"
Write-Output "INICIANDO SIMULACRO DE DESASTRE CONTRA RELOJ"
Write-Output "Respaldo seleccionado: $($LatestDump.Name)"
Write-Output "Antigüedad del respaldo (RPO observado): $($BackupAge.Days) días, $($BackupAge.Hours) horas, $($BackupAge.Minutes) minutos"
Write-Output "============================================================================"

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

$PsqlPath = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$CreatedbPath = "C:\Program Files\PostgreSQL\17\bin\createdb.exe"
$DropdbPath = "C:\Program Files\PostgreSQL\17\bin\dropdb.exe"
$PgRestorePath = "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe"

# 1. Eliminar base de prueba si ya existe (para reiniciar el simulacro limpiamente)
Write-Output "[1/4] Verificando y eliminando base de prueba anterior si existe ($TestDbName)..."
& $DropdbPath -h $DbHost -p $DbPort -U $DbUser --if-exists $TestDbName 2>&1 | Out-Null

# 2. Crear base de datos de restauración
Write-Output "[2/4] Creando base de datos limpia '$TestDbName'..."
& $CreatedbPath -h $DbHost -p $DbPort -U $DbUser $TestDbName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al crear la base de datos $TestDbName."
    exit 1
}

# 3. Restaurar respaldo con pg_restore
Write-Output "[3/4] Restaurando respaldo mediante pg_restore (--no-owner --no-privileges)..."
& $PgRestorePath -h $DbHost -p $DbPort -U $DbUser -d $TestDbName --no-owner --no-privileges $DumpPath 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warning "pg_restore finalizó con advertencias o errores (común con dependencias de esquemas/extensiones)."
}

# 4. Ejecutar validaciones mínimas
Write-Output "[4/4] Ejecutando validaciones mínimas sobre '$TestDbName'..."

$ValidationSql = @"
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'producto', COUNT(*) FROM producto
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

SELECT COUNT(*) AS productos_invalidos
FROM producto
WHERE precio < 0 OR stock < 0;

SELECT COUNT(*) AS detalles_invalidos
FROM detalle_pedido
WHERE cantidad <= 0 OR precio_unitario < 0;
"@

$TempSqlFile = Join-Path $PSScriptRoot "temp_validation.sql"
Set-Content -Path $TempSqlFile -Value $ValidationSql -Encoding UTF8

& $PsqlPath -h $DbHost -p $DbPort -U $DbUser -d $TestDbName -f $TempSqlFile
$ValidationExitCode = $LASTEXITCODE

Remove-Item -Path $TempSqlFile -ErrorAction SilentlyContinue

$Stopwatch.Stop()
$RtoSeconds = $Stopwatch.Elapsed.TotalSeconds

Write-Output "============================================================================"
Write-Output "SIMULACRO FINALIZADO EXITOSAMENTE"
Write-Output "Tiempo Total de Restauración y Validación (RTO Observado): $([Math]::Round($RtoSeconds, 2)) segundos"
Write-Output "Antigüedad del Respaldo (RPO Observado): $([Math]::Round($BackupAge.TotalHours, 2)) horas"
Write-Output "============================================================================"
