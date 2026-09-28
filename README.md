# postgres-vs-neo4j

> **SQL считает связи. Neo4j их хранит.**

Демонстрационный репозиторий к докладу **«Реляционная база — это таблица. А мир — это граф. Почему маршрутизация, рекомендации и анализ связей живут в Neo4j, а не в PostgreSQL»**.

Айдар Сафин · Главный разработчик Центра экспертизы 1С, Магнит · safin_ak@magnit.ru

---

## О чём это

Задача: построить оптимальный маршрут доставки для 500 заказов через 50 складов с учётом пробок, времени загрузки и совместимости товаров.

- **PostgreSQL**: запрос с 20 JOIN, recursive CTE, временные таблицы. **45 минут.**
- **Neo4j**: 5 строк Cypher. **200 миллисекунд.**

Разрыв — **13 500×**. Этот репозиторий — воспроизводимый стенд, который позволяет проверить цифры на своих данных.

---

## Что внутри

| Компонент | Назначение |
|---|---|
| **Neo4j 5** | Граф дорог, складов, товаров, рекомендаций |
| **PostgreSQL 16** | Реляционная модель тех же данных |
| **HTTP-прокси** | Интеграция 1С ↔ Neo4j через REST |
| **Генератор графов** | До 100 000 городов / 500 000 дорог |
| **Бенчмарки** | SQL vs Cypher на одних данных |
| **Три сценария** | Маршрутизация, цепочка поставок, рекомендации |
| **Дашборд Grafana** | График «время vs объём» |

---

## Быстрый старт

### Требования

- Docker 20.10+
- Docker Compose 2.0+
- 4 ГБ RAM (для 100k графа — 8 ГБ)

### Запуск

```bash
git clone https://github.com/yourname/postgres-vs-neo4j.git
cd postgres-vs-neo4j

cp .env.example .env

docker-compose up -d

# Инициализация демо-графа
bash scripts/init-graph.sh

# Инициализация PostgreSQL
bash scripts/init-db.sh

# Демонстрация
bash scripts/demo-routing.sh
```

Через 30 секунд:
- Neo4j Browser: http://localhost:7474 (neo4j / password)
- Grafana: http://localhost:3000 (admin / admin)
- HTTP-прокси: http://localhost:8080

---

## API прокси

### Кратчайший путь

```bash
curl -X POST http://localhost:8080/api/v1/graph/shortest-path \
  -H "Content-Type: application/json" \
  -d '{"from": "Москва", "to": "Новосибирск"}'
```

Ответ:
```json
{
  "path": ["Москва", "Казань", "Екатеринбург", "Новосибирск"],
  "total_weight": 1260,
  "hops": 3,
  "elapsed_ms": 2.3,
  "engine": "neo4j",
  "algorithm": "apoc.algo.dijkstra"
}
```

### Тот же запрос на SQL

```bash
curl -X POST http://localhost:8080/api/v1/benchmark/sql \
  -H "Content-Type: application/json" \
  -d '{"from": "Москва", "to": "Новосибирск"}'
```

### Цепочка поставок

```bash
curl -X POST http://localhost:8080/api/v1/graph/supply-chain \
  -H "Content-Type: application/json" \
  -d '{"product_code": "A001", "max_depth": 5}'
```

### Рекомендации

```bash
curl -X POST http://localhost:8080/api/v1/graph/recommendations \
  -H "Content-Type: application/json" \
  -d '{"product_code": "A001", "limit": 5}'
```

### Обновление графа (эмуляция 1С)

```bash
curl -X POST http://localhost:8080/api/v1/graph/update \
  -H "Content-Type: application/json" \
  -d '{
    "action": "update_stock",
    "entity": {
      "warehouse": "Склад Москва",
      "product": "A001",
      "quantity": 150
    }
  }'
```

---

## Генерация большого графа

### 1 000 городов / 5 000 дорог (по умолчанию)

```bash
docker-compose --profile generator run --rm generator
```

### 100 000 городов / 500 000 дорог

```bash
NUM_CITIES=100000 NUM_ROADS=500000 \
  docker-compose --profile generator run --rm generator
```

Генератор использует **одинаковый seed (42)** для Neo4j и PostgreSQL — данные идентичны, сравнение честное.

---

## Бенчмарк

```bash
bash scripts/run-benchmark.sh
```

Результат — таблица и график в `output/`:

| Объём | Наивный CTE | + pruning | pgRouting | Neo4j |
|---|---|---|---|---|
| 100 городов | 2 с | 50 мс | 5 мс | 1 мс |
| 1 000 | 15 с | 500 мс | 20 мс | 2 мс |
| 10 000 | 3 мин | 5 с | 200 мс | 3 мс |
| 100 000 | 45 мин | 3 мин | 800 мс | 5 мс |

*Реальные цифры зависят от железа. Запустите бенчмарк на своём.*

---

## Когда Neo4j НУЖЕН

✅ Обход связей на глубину 3+  
✅ Больше 100 000 объектов со связями  
✅ Запросы с 5+ JOIN или recursive CTE  
✅ Нужен ответ за миллисекунды  
✅ Связи — это данные, а не метаданные

## Когда Neo4j НЕ нужен

❌ Меньше 10 000 объектов — PostgreSQL справится  
❌ Задача не про связи (агрегаты, отчёты)  
❌ Нет ресурсов на вторую СУБД  
❌ Команда не готова изучать Cypher  
❌ Связи простые, 1–2 уровня

**Правило трёх «НЕ»:**
1. НЕ внедряйте Neo4j, если PostgreSQL справляется
2. НЕ дублируйте все данные в граф — только связи
3. НЕ пытайтесь заменить реляционный учёт графом

**PostgreSQL + Neo4j — это «и», а не «или».**

---

## Документация

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — архитектура стенда
- [BENCHMARKS.md](docs/BENCHMARKS.md) — методология бенчмарка
- [INTEGRATION_1C.md](docs/INTEGRATION_1C.md) — интеграция с 1С
- [ECONOMY.md](docs/ECONOMY.md) — расчёт экономии
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) — типовые проблемы
- [handout.md](docs/handout.md) — раздатка на 1 стр.

---

## Лицензия

MIT. Используйте свободно.

## Контакты

Айдар Сафин · safin_ak@magnit.ru
