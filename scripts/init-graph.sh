#!/bin/bash
set -euo pipefail

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Инициализация графа в Neo4j           ${NC}"
echo -e "${CYAN}========================================${NC}"

echo -e "${YELLOW}Запуск Neo4j...${NC}"
docker-compose up -d neo4j

echo -e "${YELLOW}Ожидание готовности Neo4j...${NC}"
until curl -s http://localhost:7474 > /dev/null 2>&1; do
    sleep 2
done
echo -e "${GREEN}Neo4j готов${NC}"

echo -e "${YELLOW}Выполнение init.cypher...${NC}"
docker-compose exec -T neo4j cypher-shell \
    -u "${NEO4J_USER:-neo4j}" \
    -p "${NEO4J_PASSWORD:-password}" \
    -f /init.cypher

echo -e "${GREEN}Граф инициализирован${NC}"
