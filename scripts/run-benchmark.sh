#!/bin/bash
set -euo pipefail

CYAN='\033[0;36m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Бенчмарк SQL vs Neo4j                 ${NC}"
echo -e "${CYAN}========================================${NC}"

mkdir -p output

docker-compose exec -T proxy python /app/benchmarks/run_benchmark.py | tee output/benchmark.txt
docker-compose exec -T proxy python /app/benchmarks/plot_results.py

echo -e "${GREEN}Результаты в output/${NC}"
