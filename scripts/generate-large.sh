#!/bin/bash
set -euo pipefail

NUM_CITIES="${NUM_CITIES:-100000}"
NUM_ROADS="${NUM_ROADS:-500000}"

echo "Генерация ${NUM_CITIES} городов / ${NUM_ROADS} дорог..."

NUM_CITIES="${NUM_CITIES}" NUM_ROADS="${NUM_ROADS}" \
    docker-compose --profile generator run --rm generator

echo "Проверка консистентности..."
docker-compose exec -T postgres psql -U demo -d testdb -f /sql/verify.sql
