# postgres-vs-neo4j

> 45 минут → 200 миллисекунд. Почему маршрутизация, рекомендации
> и анализ связей живут в Neo4j, а не в PostgreSQL.

Демонстрационный репозиторий к докладу «Когда SQL сдаётся. Графовые
базы данных рядом с 1С: как Neo4j решает задачу маршрутизации
в тысячи раз быстрее».

---

## 🎯 Что внутри

- **Neo4j** с демонстрационным графом: города, дороги, склады, товары
- **PostgreSQL** с той же реляционной моделью и теми же данными
- **HTTP-прокси** для интеграции 1С с Neo4j (JSON входит → Cypher выполняется → JSON возвращается)
- **Генератор** больших графов до 100 000 узлов для честных бенчмарков
- **Бенчмарк** SQL vs Cypher на трёх сценариях

---

## 🚀 Быстрый старт

```bash
git clone https://github.com/yourname/postgres-vs-neo4j.git
cd postgres-vs-neo4j

# Запуск стенда
docker-compose up -d

# Инициализация демонстрационного графа
bash scripts/init-graph.sh

# Демонстрация трёх сценариев
bash scripts/demo-routing.sh

# Генерация большого графа для бенчмарков
docker-compose --profile generator run --rm generator

# Запуск бенчмарка
docker-compose --profile benchmark run --rm benchmark
