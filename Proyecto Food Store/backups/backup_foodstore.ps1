<#
.SYNOPSIS
    Script de respaldo automatizado para la base de datos Food Store en PostgreSQL 16+.
.DESCRIPTION
    Genera un respaldo en formato custom (-Fc), incluye fecha y hora en el nombre del archivo,
    registra el resultado en la carpeta 'logs/' y finaliza con error si pg_dump falla.
    No contiene contraseñas en texto plano.
#>

param(
    [string]$DbHost = "localhost",
    [string]$DbPort = "5432",
    [string]$DbUser = "postgres",
    [string]$DbName = "Food_Store_Copia" # O 'foodstore' según la instancia
)

# Directorios de salida
$BackupDir = Join-Path $PSScriptRoot "backups"
$LogDir = Join-Path $PSScriptRoot "logs"

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$DumpFile = Join-Path $BackupDir "foodstore_$Timestamp.dump"
$LogFile = Join-Path $LogDir "backup_$Timestamp.log"

Write-Output "[$Timestamp] Iniciando respaldo de la base de datos '$DbName'..." | Tee-Object -FilePath $LogFile -Append

# Ruta a pg_dump en PostgreSQL 17 / 16
$PgDumpPath = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"
if (-not (Test-Path $PgDumpPath)) {
    $PgDumpPath = "pg_dump" # Intentar usar PATH global
}

$Arguments = @(
    "-h", $DbHost,
    "-p", $DbPort,
    "-U", $DbUser,
    "-d", $DbName,
    "-Fc",
    "-f", $DumpFile
)

Write-Output "Ejecutando: $PgDumpPath $Arguments" | Tee-Object -FilePath $LogFile -Append

$StartTime = Get-Date
& $PgDumpPath $Arguments 2>&1 | Tee-Object -FilePath $LogFile -Append
$ExitCode = $LASTEXITCODE
$Duration = (Get-Date) - $StartTime

if ($ExitCode -eq 0) {
    $FileSize = (Get-Item $DumpFile).Length
    $Msg = "[$((Get-Date))] Respaldo completado exitosamente. Archivo: $DumpFile ($FileSize bytes). Duración: $($Duration.TotalSeconds) segundos."
    Write-Output $Msg | Tee-Object -FilePath $LogFile -Append
    exit 0
} else {
    $ErrorMsg = "[$((Get-Date))] ERROR: pg_dump falló con código de salida $ExitCode."
    Write-Error $ErrorMsg
    Write-Output $ErrorMsg | Tee-Object -FilePath $LogFile -Append
    exit 1
}
