```markdown
# postgres-vs-neo4j

> 45 минут → 200 миллисекунд. Почему маршрутизация, рекомендации
> и анализ связей живут в Neo4j, а не в PostgreSQL.

Демонстрационный стенд для сравнения реляционной и графовой моделей
на задачах со связями. Включает обе базы данных с одинаковыми
тестовыми данными, HTTP-прокси для интеграции, генератор больших
графов и бенчмарк.

---

## 🎯 Что внутри

- **Neo4j** с демонстрационным графом: города, дороги, склады, товары
- **PostgreSQL** с той же реляционной моделью и теми же данными
- **HTTP-прокси** для интеграции с Neo4j (JSON входит → Cypher выполняется → JSON возвращается)
- **Генератор** больших графов до 100 000 узлов для честных бенчмарков
- **Бенчмарк** SQL vs Cypher на трёх сценариях
- **Пример кода** для вызова прокси из 1С

---

## 🚀 Быстрый старт

### Требования

- Docker 20+
- Docker Compose 1.29+
- 4+ GB свободной оперативной памяти

### Запуск

```bash
git clone https://github.com/yourname/postgres-vs-neo4j.git
cd postgres-vs-neo4j

# Запуск стенда (Neo4j + PostgreSQL + прокси)
docker-compose up -d

# Инициализация демонстрационного графа
bash scripts/init-graph.sh

# Демонстрация трёх сценариев
bash scripts/demo-routing.sh
```

### Генерация большого графа для бенчмарков

```bash
# 1 000 городов, 5 000 дорог, 50 складов (по умолчанию)
docker-compose --profile generator run --rm generator

# 10 000 городов, 50 000 дорог
NUM_CITIES=10000 NUM_ROADS=50000 docker-compose --profile generator run --rm generator
```

### Запуск бенчмарка

```bash
docker-compose --profile benchmark run --rm benchmark
```

---

## 📊 Три сценария сравнения

| Сценарий | SQL (PostgreSQL) | Cypher (Neo4j) |
|----------|------------------|----------------|
| **Кратчайший путь** | Рекурсивный CTE + обход таблицы рёбер | Нативный `shortestPath()` |
| **Цепочка поставок** | 5 JOIN + UNION | `MATCH ...-[*1..5]->` |
| **Рекомендации** | Корреляция через подзапросы | Обход соседних узлов |

---

## 🔧 API прокси

### Проверка работоспособности

```bash
curl http://localhost:8080/health
```

### Кратчайший путь между городами

```bash
curl -X POST http://localhost:8080/api/v1/graph/shortest-path \
  -H "Content-Type: application/json" \
  -d '{"from": "Москва", "to": "Новосибирск"}'
```

**Ответ:**

```json
{
  "path": ["Москва", "Новосибирск"],
  "total_weight": 1200,
  "hops": 1,
  "elapsed_ms": 2.3,
  "engine": "neo4j"
}
```

### Цепочка поставок: все поставщики товара до N-го уровня

```bash
curl -X POST http://localhost:8080/api/v1/graph/supply-chain \
  -H "Content-Type: application/json" \
  -d '{"product_code": "A001", "max_depth": 5}'
```

### Рекомендации: товары которые покупают вместе

```bash
curl -X POST http://localhost:8080/api/v1/graph/recommendations \
  -H "Content-Type: application/json" \
  -d '{"product_code": "A001", "limit": 5}'
```

### Тот же запрос на SQL для сравнения

```bash
curl -X POST http://localhost:8080/api/v1/benchmark/sql \
  -H "Content-Type: application/json" \
  -d '{"from": "Москва", "to": "Новосибирск"}'
```

---

## 📁 Структура

```
postgres-vs-neo4j/
├── docker-compose.yml              # Neo4j + PostgreSQL + прокси
├── .env                            # Переменные окружения
├── docker/
│   └── neo4j/
│       └── init.cypher             # Демонстрационный граф
├── sql/
│   └── postgres-schema.sql         # Реляционная модель + тестовые данные
├── src/
│   ├── proxy/
│   │   ├── app.py                  # HTTP-прокси: JSON → Cypher → JSON
│   │   ├── config.py               # Конфигурация
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── generator/
│   │   ├── generate_graph.py       # Генератор больших графов
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── benchmarks/
│       ├── run_benchmark.py        # Бенчмарк SQL vs Cypher
│       ├── Dockerfile
│       └── requirements.txt
├── scripts/
│   ├── init-graph.sh               # Инициализация демо-графа
│   ├── run-benchmark.sh            # Запуск бенчмарка
│   ├── demo-routing.sh             # Демонстрация трёх сценариев
│   └── init-db.sh                  # Создание базы PostgreSQL
└── examples/
    └── 1c-integration.example      # Пример вызова из 1С
```

---

## 🗄️ Демонстрационные данные

### Города и дороги

```
Москва ──700 км── Санкт-Петербург
   │                   
   ├──800 км── Казань ──900 км── Екатеринбург
   │                              │
   └────3300 км──── Новосибирск ──1500 км──┘
```

### Склады и остатки

| Склад | Город | Товар А | Товар B | Товар C |
|-------|-------|---------|---------|---------|
| Склад Москва | Москва | 100 | 50 | — |
| Склад СПб | Санкт-Петербург | 200 | — | 75 |
| Склад Казань | Казань | — | 150 | — |

### Совместные покупки

```
Товар А ──45──→ Товар B
Товар А ──30──→ Товар C
Товар B ──20──→ Товар C
```

---

## 🛠️ Конфигурация

Все параметры настраиваются через переменные окружения в файле `.env`:

```env
# Neo4j
NEO4J_USER=neo4j
NEO4J_PASSWORD=password

# PostgreSQL
POSTGRES_DB=testdb
POSTGRES_USER=demo
POSTGRES_PASSWORD=demo

# Генератор
NUM_CITIES=1000
NUM_ROADS=5000
NUM_WAREHOUSES=50

# Логирование
LOG_LEVEL=INFO
```

---

## 🧪 Как воспроизвести бенчмарк

1. Запустите стенд: `docker-compose up -d`
2. Инициализируйте демо-граф: `bash scripts/init-graph.sh`
3. Сгенерируйте большой граф: `docker-compose --profile generator run --rm generator`
4. Запустите бенчмарк: `docker-compose --profile benchmark run --rm benchmark`
5. Сравните результаты в консоли

---

## ❓ Когда Neo4j нужен, а когда нет

### Neo4j нужен если

- Данных больше 100 000 узлов
- Связи сложные: много типов рёбер, свойства на рёбрах
- Запросы — обход графа на глубину 3+
- Ответ нужен за миллисекунды

### PostgreSQL достаточно если

- Данных меньше 10 000 узлов
- Связи простые: один-два уровня, без циклов
- Запросы — обычные выборки и агрегации
- Нет требований к миллисекундному отклику

---

## 📄 Лицензия

MIT
```
