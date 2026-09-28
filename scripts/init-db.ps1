# ============================================================================
# Создание базы данных PostgreSQL
# ============================================================================
# .\scripts\init-db.ps1
# $env:PG_ADMIN_PASSWORD = "secret"; .\scripts\init-db.ps1

$ErrorActionPreference = "Stop"
$env:PGCLIENTENCODING = "UTF8"

if (-not (Get-Command psql -ErrorAction SilentlyContinue)) {
    Write-Host "ОШИБКА: psql не найден в PATH" -ForegroundColor Red
    Write-Host "Установите PostgreSQL client или добавьте в PATH" -ForegroundColor Yellow
    exit 1
}

$PG_HOST          = if ($env:PG_HOST)          { $env:PG_HOST }          else { "localhost" }
$PG_PORT          = if ($env:PG_PORT)          { $env:PG_PORT }          else { "5432" }
$PG_ADMIN_USER    = if ($env:PG_ADMIN_USER)    { $env:PG_ADMIN_USER }    else { "postgres" }
$PG_ADMIN_PASSWORD= if ($env:PG_ADMIN_PASSWORD){ $env:PG_ADMIN_PASSWORD}else { "postgres" }
$DB_NAME          = if ($env:POSTGRES_DB)      { $env:POSTGRES_DB }      else { "testdb" }
$DB_USER          = if ($env:POSTGRES_USER)    { $env:POSTGRES_USER }    else { "demo" }
$DB_PASSWORD      = if ($env:POSTGRES_PASSWORD){ $env:POSTGRES_PASSWORD}else { "demo" }

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$SchemaFile = Join-Path $ScriptDir "..\sql\postgres-schema.sql"
$SchemaFile = (Resolve-Path $SchemaFile).Path

if (-not (Test-Path $SchemaFile)) {
    Write-Host "ОШИБКА: не найден $SchemaFile" -ForegroundColor Red
    exit 1
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Создание базы данных PostgreSQL       " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "База:   $DB_NAME"
Write-Host "Польз.: $DB_USER"
Write-Host "Схема:  $SchemaFile"
Write-Host ""

$env:PGPASSWORD = $PG_ADMIN_PASSWORD

Write-Host "[1/6] Проверка подключения..." -ForegroundColor Yellow
$versionRaw = psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -tAc "SHOW server_version_num;" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА: не удалось подключиться" -ForegroundColor Red
    Write-Host $versionRaw
    exit 1
}
$versionNum = [int]($versionRaw.Trim())
if ($versionNum -lt 120000) {
    Write-Host "ПРЕДУПРЕЖДЕНИЕ: PostgreSQL < 12" -ForegroundColor Yellow
}
Write-Host "Подключение успешно (PostgreSQL $versionNum)" -ForegroundColor Green
Write-Host ""

Write-Host "[2/6] Пользователь $DB_USER..." -ForegroundColor Yellow
$userExists = psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER';"
if ($userExists -match "1") {
    Write-Host "Уже существует"
} else {
    psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" | Out-Null
    Write-Host "Создан" -ForegroundColor Green
}
Write-Host ""

Write-Host "[3/6] База $DB_NAME..." -ForegroundColor Yellow
$dbExists = psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME';"
if ($dbExists -match "1") {
    Write-Host "Уже существует"
} else {
    psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" | Out-Null
    Write-Host "Создана" -ForegroundColor Green
}
Write-Host ""

Write-Host "[4/6] Привилегии..." -ForegroundColor Yellow
psql -h $PG_HOST -p $PG_PORT -U $PG_ADMIN_USER -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;" | Out-Null
Write-Host "Выданы" -ForegroundColor Green
Write-Host ""

Write-Host "[5/6] Применение схемы..." -ForegroundColor Yellow
$env:PGPASSWORD = $DB_PASSWORD
psql -h $PG_HOST -p $PG_PORT -U $DB_USER -d $DB_NAME -v ON_ERROR_STOP=1 -f $SchemaFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "ОШИБКА при применении схемы" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "[6/6] ANALYZE..." -ForegroundColor Yellow
psql -h $PG_HOST -p $PG_PORT -U $DB_USER -d $DB_NAME -c "ANALYZE;" | Out-Null
Write-Host "Статистика обновлена" -ForegroundColor Green
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "  База данных готова!                   " -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
