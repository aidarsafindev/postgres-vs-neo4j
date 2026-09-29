#!/bin/bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROXY_URL="${PROXY_URL:-http://localhost:8080}"

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Демонстрация: Neo4j vs SQL            ${NC}"
echo -e "${CYAN}========================================${NC}"

echo -e "${YELLOW}1. Кратчайший путь: Москва → Новосибирск (Neo4j)${NC}"
curl -s -X POST "${PROXY_URL}/api/v1/graph/shortest-path" \
    -H "Content-Type: application/json" \
    -d '{"from": "Москва", "to": "Новосибирск"}' | python3 -m json.tool
echo ""

echo -e "${YELLOW}2. Тот же запрос на SQL${NC}"
curl -s -X POST "${PROXY_URL}/api/v1/benchmark/sql" \
    -H "Content-Type: application/json" \
    -d '{"from": "Москва", "to": "Новосибирск"}' | python3 -m json.tool
echo ""

echo -e "${YELLOW}3. Цепочка поставок: товар A001${NC}"
curl -s -X POST "${PROXY_URL}/api/v1/graph/supply-chain" \
    -H "Content-Type: application/json" \
    -d '{"product_code": "A001", "max_depth": 5}' | python3 -m json.tool
echo ""

echo -e "${YELLOW}4. Рекомендации: товар A001${NC}"
curl -s -X POST "${PROXY_URL}/api/v1/graph/recommendations" \
    -H "Content-Type: application/json" \
    -d '{"product_code": "A001", "limit": 5}' | python3 -m json.tool
echo ""

echo -e "${GREEN}Демонстрация завершена${NC}"
