#!/bin/bash
set -euo pipefail

PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_ADMIN_USER="${PG_ADMIN_USER:-postgres}"
PG_ADMIN_PASSWORD="${PG_ADMIN_PASSWORD:-postgres}"
DB_NAME="${POSTGRES_DB:-testdb}"
DB_USER="${POSTGRES_USER:-demo}"
DB_PASSWORD="${POSTGRES_PASSWORD:-demo}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEMA_FILE="${SCRIPT_DIR}/../sql/postgres-schema.sql"

if [ ! -f "$SCHEMA_FILE" ]; then
    echo "ОШИБКА: не найден $SCHEMA_FILE"
    exit 1
fi

export PGPASSWORD="$PG_ADMIN_PASSWORD"

echo "========================================"
echo "  Создание базы данных PostgreSQL"
echo "========================================"

echo "[1/4] Проверка подключения..."
psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -c "SELECT 1;" > /dev/null
echo "OK"

echo "[2/4] Пользователь $DB_USER..."
if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    echo "Уже существует"
else
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres \
        -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';" > /dev/null
    echo "Создан"
fi

echo "[3/4] База $DB_NAME..."
if psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1; then
    echo "Уже существует"
else
    psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_ADMIN_USER" -d postgres \
        -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;" > /dev/null
    echo "Создана"
fi

echo "[4/4] Применение схемы..."
export PGPASSWORD="$DB_PASSWORD"
psql -h "$PG_HOST" -p "$PG_PORT" -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$SCHEMA_FILE"

echo ""
echo "========================================"
echo "  База данных готова!"
echo "========================================"
