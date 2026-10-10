# docs/SYNC-1C-NEO4J.md

# Синхронизация данных из 1С в Neo4j

Этот документ — расширенная версия слайда 29 доклада. Здесь объясняется, **какие данные**, **как часто**, **в каких случаях** и **с помощью каких инструментов** обновляются из 1С в Neo4j.

## Оглавление

1. [Главный принцип](#главный-принцип)
2. [Что синхронизируется](#что-синхронизируется)
3. [Что НЕ синхронизируется](#что-не-синхронизируется)
4. [Когда обновляется](#когда-обновляется)
5. [Способы синхронизации](#способы-синхронизации)
6. [Инструменты](#инструменты)
7. [Архитектура синхронизации](#архитектура-синхронизации)
8. [Примеры кода](#примеры-кода)
9. [Обработка ошибок](#обработка-ошибок)
10. [Reconciliation](#reconciliation)
11. [Мониторинг](#мониторинг)
12. [Типичные ошибки](#типичные-ошибки)
13. [Шпаргалка](#шпаргалка)

## Главный принцип

**1С — источник истины. Neo4j — кэш связей.**

Это значит:

- Все данные живут в 1С / PostgreSQL
- В Neo4j попадает **только то, что нужно для обхода графа**
- Neo4j можно **потерять и восстановить** из учётной системы
- Данные синхронизируются **из 1С в Neo4j**, не наоборот

**Правило:** если граф потеряется — его можно восстановить за час из 1С. Если потеряется 1С — граф не поможет.

## Что синхронизируется

### 1. Узлы (Nodes)

| Узел | Источник в 1С | Свойства | Приоритет |
|---|---|---|---|
| `:City` | `Справочник.Города` | name, population | Высокий |
| `:Warehouse` | `Справочник.Склады` | name, capacity | Высокий |
| `:Product` | `Справочник.Номенклатура` | code, name | Высокий |
| `:Counterparty` | `Справочник.Контрагенты` | inn, name | Средний |
| `:Order` | `Документ.ЗаказКлиента` | number, date | Низкий |

### 2. Рёбра (Relationships)

| Ребро | Источник в 1С | Свойства | Приоритет |
|---|---|---|---|
| `:ROAD` | `РегистрСведений.Дороги` | distance, time_minutes | Высокий |
| `:LOCATED_IN` | `Справочник.Склады.Город` | — | Высокий |
| `:STOCKS` | `РегистрНакопления.ОстаткиТоваров` | quantity | Высокий |
| `:BOUGHT_WITH` | `РегистрНакопления.Продажи` (агрегат) | frequency | Средний |
| `:SUPPLIES` | `Документ.ПоступлениеТоваров` | date, amount | Средний |
| `:WORKS_AT` | `РегистрСведений.КонтактныеЛица` | position | Низкий |

### 3. Что определяет приоритет

- **Высокий** — участвует в маршрутизации и основных запросах. Синхронизируется при каждом изменении.
- **Средний** — участвует в аналитике и рекомендациях. Синхронизируется батчами.
- **Низкий** — справочная информация. Синхронизируется раз в сутки.

## Что НЕ синхронизируется

**Не попадает в Neo4j:**

- Документы (кроме тех, что нужны для связей)
- Проводки
- Бухгалтерские регистры
- Отчёты
- Настройки
- Пользователи и права (кроме графа доступов — если используется)

**Правило:** если объект не участвует в обходе связей — он не нужен в Neo4j.

## Когда обновляется

### 1. По событию (реальное время)

**Когда:** при проведении документа, изменении справочника.

**Что синхронизируется:**
- Изменение склада → обновление узла `:Warehouse`
- Изменение товара → обновление узла `:Product`
- Проведение документа поступления → обновление ребра `:STOCKS`
- Изменение дороги → обновление ребра `:ROAD`

**Задержка:** секунды.

**Плюсы:**
- Актуальные данные
- Простая логика

**Минусы:**
- Нагрузка на Neo4j при массовых операциях
- Возможны ошибки синхронизации

### 2. По расписанию (батчами)

**Когда:** раз в час, раз в сутки.

**Что синхронизируется:**
- Рекомендации (`:BOUGHT_WITH`) — пересчёт раз в сутки
- Агрегаты — раз в час
- Справочники — раз в сутки
- Полная пересинхронизация — раз в неделю

**Задержка:** минуты-часы.

**Плюсы:**
- Меньше нагрузки
- Можно пересчитать всё

**Минусы:**
- Данные не всегда актуальны
- Нужны reconciliation-процессы

### 3. По требованию

**Когда:** администратор запускает вручную.

**Что синхронизируется:**
- Полная пересинхронизация
- Восстановление после сбоя
- Миграция

**Инструменты:** скрипт `scripts/init-graph.sh`, `scripts/generate-large.sh`.

## Способы синхронизации

### 1. Прямой HTTP-вызов

**Как работает:**

1. Событие происходит в 1С
2. 1С отправляет HTTP-запрос к прокси
3. Прокси обновляет Neo4j

**Когда использовать:**
- Мало событий (десятки в час)
- Не критична задержка

**Плюсы:**
- Простая реализация
- Не нужны дополнительные компоненты

**Минусы:**
- 1С блокируется на время запроса
- Нет буферизации при сбое

**Схема:**

```
1С → HTTP → Прокси → Neo4j
```

### 2. Через очередь (RabbitMQ, Kafka)

**Как работает:**

1. Событие происходит в 1С
2. 1С публикует сообщение в очередь
3. Обработчик читает сообщение
4. Обработчик обновляет Neo4j

**Когда использовать:**
- Много событий (сотни-тысячи в час)
- Критична надёжность

**Плюсы:**
- 1С не блокируется
- Буферизация при сбое
- Можно масштабировать обработчики
- Гарантированная доставка

**Минусы:**
- Нужна инфраструктура (RabbitMQ, Kafka)
- Дополнительные компоненты
- Сложнее отладка

**Схема:**

```
1С → RabbitMQ → Обработчик → HTTP → Прокси → Neo4j
```

### 3. Через ETL (Airbyte, Kafka Connect)

**Как работает:**

1. ETL-инструмент читает данные из PostgreSQL
2. Преобразует в формат для Neo4j
3. Записывает в Neo4j

**Когда использовать:**
- Массовая загрузка
- Периодическая синхронизация
- Нет событий в 1С

**Плюсы:**
- Не требует изменений в 1С
- Работает с готовыми инструментами
- Легко настроить

**Минусы:**
- Задержка (обычно минуты)
- Нужно писать трансформации

**Схема:**

```
PostgreSQL → ETL → Neo4j
```

### 4. Через CDC (Debezium)

**Как работает:**

1. CDC-инструмент читает WAL PostgreSQL
2. Преобразует изменения в события
3. Отправляет в Neo4j

**Когда использовать:**
- Нельзя менять 1С
- Нужна реальная актуальность
- Большие объёмы

**Плюсы:**
- Не требует изменений в 1С
- Задержка — секунды
- Не влияет на производительность 1С

**Минусы:**
- Сложная настройка
- Нужен Debezium + Kafka
- Сложнее отладка

**Схема:**

```
PostgreSQL (WAL) → Debezium → Kafka → Обработчик → Neo4j
```

## Инструменты

### 1. HTTP-прокси (Python / Flask)

**Что делает:** принимает HTTP-запросы от 1С, транслирует в Cypher, выполняет в Neo4j.

**Код:** `src/proxy/app.py`.

**Когда использовать:** базовый случай.

**Пример вызова:**

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

### 2. RabbitMQ

**Что делает:** очередь для событий от 1С.

**Когда использовать:** много событий, нужна надёжность.

**Схема работы:**

```
1С (publish) → RabbitMQ → Обработчик (consume) → Прокси → Neo4j
```

### 3. Kafka

**Что делает:** распределённый лог для событий.

**Когда использовать:** очень много событий, несколько потребителей.

**Отличие от RabbitMQ:**
- Kafka — это лог, сообщения хранятся долго
- RabbitMQ — это очередь, сообщение удаляется после обработки

### 4. Debezium

**Что делает:** читает изменения из PostgreSQL через WAL.

**Когда использовать:** нельзя менять 1С.

**Схема:**

```
PostgreSQL (WAL) → Debezium → Kafka → Обработчик → Neo4j
```

### 5. Airbyte

**Что делает:** ETL-платформа для переливки данных.

**Когда использовать:** массовая синхронизация.

**Схема:**

```
PostgreSQL → Airbyte → Neo4j
```

### 6. APOC

**Что делает:** библиотека процедур для Neo4j. Содержит `apoc.periodic.iterate` для батчевой загрузки.

**Когда использовать:** массовая загрузка через Cypher.

**Пример:**

```cypher
CALL apoc.periodic.iterate(
  'UNWIND $cities AS city RETURN city',
  'MERGE (c:City {name: city.name}) SET c.population = city.population',
  {batchSize: 1000, params: {cities: $cities}}
)
```

## Архитектура синхронизации

### Базовая (HTTP-прокси)

```
┌──────────┐     ┌────────────────┐     ┌──────────┐
│    1С    │────→│  HTTP-прокси   │────→│   Neo4j  │
│          │     │  (Python/Flask)│     │  Bolt    │
└────┬─────┘     └────────────────┘     └──────────┘
     │
     ▼
┌──────────┐
│PostgreSQL│
│  (учёт)  │
└──────────┘
```

**Плюсы:** просто.
**Минусы:** 1С блокируется.

### С очередью (RabbitMQ)

```
┌──────────┐     ┌──────────┐     ┌────────────┐     ┌──────────┐
│    1С    │────→│ RabbitMQ │────→│ Обработчик │────→│  Neo4j   │
│          │     │  (queue) │     │  (worker)  │     │  Bolt    │
└────┬─────┘     └──────────┘     └────────────┘     └──────────┘
     │
     ▼
┌──────────┐
│PostgreSQL│
└──────────┘
```

**Плюсы:** 1С не блокируется, надёжность.
**Минусы:** нужна инфраструктура.

### С CDC (Debezium)

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌────────────┐     ┌──────────┐
│    1С    │────→│PostgreSQL│────→│ Debezium │────→│   Kafka    │────→│  Neo4j   │
│          │     │  (WAL)   │     │          │     │  (log)     │     │  Bolt    │
└──────────┘     └──────────┘     └──────────┘     └────────────┘     └──────────┘
```

**Плюсы:** 1С не меняется, реальное время.
**Минусы:** сложная настройка.

## Примеры кода

### 1С: публикация события при проведении документа

```bsl
Процедура ОбработкаПроведения(Отказ, Режим)
    // Стандартная проводка в PostgreSQL
    // ...
    
    // Публикация события в RabbitMQ
    Событие = Новый Структура;
    Событие.Вставить("action", "update_stock");
    Событие.Вставить("entity", Новый Структура);
    Событие.entity.Вставить("warehouse", Склад);
    Событие.entity.Вставить("product", Товар);
    Событие.entity.Вставить("quantity", Количество);
    
    ОпубликоватьВОчередь("graph.updates", Событие);
КонецПроцедуры
```

### Обработчик RabbitMQ (Python)

```python
import json
import pika
import requests

def handle_message(ch, method, properties, body):
    event = json.loads(body)
    
    try:
        response = requests.post(
            "http://proxy:8080/api/v1/graph/update",
            json=event,
            timeout=5
        )
        response.raise_for_status()
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        print(f"Error: {e}")
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

connection = pika.BlockingConnection(pika.ConnectionParameters('rabbitmq'))
channel = connection.channel()
channel.queue_declare(queue='graph.updates', durable=True)
channel.basic_qos(prefetch_count=10)
channel.basic_consume(queue='graph.updates', on_message_callback=handle_message)
channel.start_consuming()
```

### Прокси: обновление графа

```python
@app.route("/api/v1/graph/update", methods=["POST"])
def update_graph():
    data = request.get_json(force=True)
    action = data.get("action")
    entity = data.get("entity", {})

    if action == "new_road":
        query = """
            MERGE (a:City {name: $from})
            MERGE (b:City {name: $to})
            MERGE (a)-[r:ROAD]->(b)
            SET r.distance = $distance,
                r.time_minutes = $time
        """
        with neo4j_driver.session() as session:
            session.run(query, **{
                "from": entity["from"],
                "to": entity["to"],
                "distance": entity["distance"],
                "time": entity["time_minutes"],
            })
        return jsonify({"status": "updated", "entity": "road"})

    if action == "update_stock":
        query = """
            MERGE (w:Warehouse {name: $warehouse})
            MERGE (p:Product {code: $product})
            MERGE (w)-[s:STOCKS]->(p)
            SET s.quantity = $quantity
        """
        with neo4j_driver.session() as session:
            session.run(query, **entity)
        return jsonify({"status": "updated", "entity": "stock"})

    return jsonify({"error": "Unknown action"}), 400
```

### ETL: массовая загрузка через APOC

```cypher
CALL apoc.periodic.iterate(
  'UNWIND $cities AS city RETURN city',
  'MERGE (c:City {name: city.name}) SET c.population = city.population',
  {batchSize: 1000, params: {cities: $cities}}
)
```

## Обработка ошибок

### 1. Идемпотентность

Все операции `update` должны быть **идемпотентными** — повторная отправка того же события не должна ломать граф.

**Пример:**

```cypher
MERGE (w:Warehouse {name: $warehouse})
MERGE (p:Product {code: $product})
MERGE (w)-[s:STOCKS]->(p)
SET s.quantity = $quantity
```

`MERGE` + `SET` — идемпотентно. Повторный запуск обновит значение, а не создаст дубль.

### 2. Retry-политика

Если прокси недоступен — повторить попытку.

```python
import time
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

session = requests.Session()
retries = Retry(
    total=5,
    backoff_factor=1,
    status_forcelist=[500, 502, 503, 504]
)
session.mount('http://', HTTPAdapter(max_retries=retries))
```

### 3. Dead Letter Queue

Если событие не удалось обработать после N попыток — отправить в DLQ.

```python
channel.queue_declare(queue='graph.updates.dlq', durable=True)

def handle_message(ch, method, properties, body):
    try:
        process(body)
        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        if method.redelivered:
            # Уже была попытка — отправляем в DLQ
            channel.basic_publish(
                exchange='',
                routing_key='graph.updates.dlq',
                body=body
            )
            ch.basic_ack(delivery_tag=method.delivery_tag)
        else:
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)
```

### 4. Мониторинг ошибок

Логировать все ошибки в структурированном виде:

```python
logger.error("Failed to update graph", extra={
    "action": action,
    "entity": entity,
    "error": str(e),
    "retry_count": retry_count
})
```

## Reconciliation

### Зачем нужен

Между PostgreSQL и Neo4j может возникнуть **рассинхрон**:

- Событие потерялось
- Обработчик упал
- Neo4j был недоступен
- Ошибка в логике

**Reconciliation** — это процесс сверки данных между двумя источниками.

### Как работает

**1. Сверка количества**

```sql
-- PostgreSQL
SELECT 'cities' AS entity, COUNT(*) FROM cities
UNION ALL SELECT 'roads', COUNT(*) FROM roads;
```

```cypher
// Neo4j
MATCH (c:City) WITH count(c) AS cities
MATCH ()-[r:ROAD]->() RETURN cities, count(r) AS roads;
```

Если числа не совпадают — есть проблема.

**2. Сверка контрольных сумм**

Для критичных полей (например, `quantity` остатков) считается контрольная сумма:

```sql
-- PostgreSQL
SELECT SUM(quantity) FROM warehouse_stock;
```

```cypher
// Neo4j
MATCH ()-[s:STOCKS]->() RETURN sum(s.quantity);
```

**3. Полная пересинхронизация**

Если расхождение критичное — полная пересинхронизация:

```bash
bash scripts/init-graph.sh
docker-compose --profile generator run --rm generator
```

### Как часто запускать

| Что сверять | Частота |
|---|---|
| Количество узлов и рёбер | Раз в час |
| Контрольные суммы | Раз в сутки |
| Полная пересинхронизация | Раз в неделю |

## Мониторинг

### Что логировать

| Метрика | Что показывает |
|---|---|
| Количество событий в секунду | Нагрузка на очередь |
| Время обработки события | Производительность прокси |
| Количество ошибок | Проблемы с синхронизацией |
| Размер очереди | Задержка обработки |
| Рассинхрон | Критичные расхождения |

### Grafana-дашборд

**Панели:**

1. **Events/sec** — сколько событий в секунду
2. **Processing time (p50, p95, p99)** — время обработки
3. **Error rate** — процент ошибок
4. **Queue size** — размер очереди
5. **Reconciliation diff** — расхождения

### Алерты

- Error rate > 1% за 5 минут → warning
- Queue size > 1000 → warning
- Reconciliation diff > 0 → critical
- Обработчик не отвечает > 1 минуты → critical

## Типичные ошибки

### 1. MERGE со свойствами в ребре

```cypher
-- ❌ Плохо: создаст дубли при обновлении
MERGE (a)-[:ROAD {distance: 700}]->(b)

-- ✅ Хорошо
MERGE (a)-[r:ROAD]->(b)
SET r.distance = 700
```

### 2. Отсутствие идемпотентности

```python
# ❌ Плохо: повторный вызов создаст дубль
session.run("CREATE (c:City {name: 'Москва'})")

# ✅ Хорошо
session.run("MERGE (c:City {name: 'Москва'})")
```

### 3. Синхронный вызов из 1С

```bsl
// ❌ Плохо: 1С блокируется на время HTTP-запроса
Результат = HTTPСоединение.ВызватьHTTPМетод(Запрос);

// ✅ Хорошо: публикация в очередь
ОпубликоватьВОчередь("graph.updates", Событие);
```

### 4. Нет retry-политики

```python
# ❌ Плохо: при сбое событие теряется
requests.post(url, json=event)

# ✅ Хорошо: 5 попыток с backoff
session.post(url, json=event)
```

### 5. Нет reconciliation

Без сверки рассинхрон может накапливаться. Через месяц граф станет бесполезным.

## Шпаргалка

### Что синхронизируется

| Категория | Приоритет | Частота |
|---|---|---|
| Узлы городов, складов, товаров | Высокий | При изменении |
| Рёбра дорог, остатков | Высокий | При проведении |
| Рёбра рекомендаций | Средний | Раз в сутки |
| Справочники | Низкий | Раз в сутки |

### Способы

| Способ | Когда | Плюсы | Минусы |
|---|---|---|---|
| HTTP-прокси | Мало событий | Просто | Блокирует 1С |
| RabbitMQ | Много событий | Надёжно | Инфраструктура |
| Kafka | Очень много | Масштабируемо | Сложно |
| Debezium | Нельзя менять 1С | Реальное время | Сложно |
| Airbyte | Массово | Готовое | Задержка |

### Инструменты

| Инструмент | Роль |
|---|---|
| `src/proxy/app.py` | HTTP-прокси |
| RabbitMQ | Очередь событий |
| Kafka | Лог событий |
| Debezium | CDC из PostgreSQL |
| Airbyte | ETL |
| APOC | Батчевая загрузка в Neo4j |

### Частота

| Что | Когда |
|---|---|
| Изменение справочника | Секунды |
| Проведение документа | Секунды |
| Агрегаты рекомендаций | Раз в час |
| Полная синхронизация | Раз в неделю |
| Reconciliation | Раз в час |

### Мониторинг

- Events/sec
- Processing time
- Error rate
- Queue size
- Reconciliation diff

## Ссылки

### Документация

- [Neo4j Data Import](https://neo4j.com/docs/operations-manual/current/tools/import/)
- [APOC Periodic Iterate](https://neo4j.com/labs/apoc/4.4/overview/apoc.periodic/apoc.periodic.iterate/)
- [RabbitMQ Tutorials](https://www.rabbitmq.com/tutorials)
- [Debezium Documentation](https://debezium.io/documentation/)
- [Airbyte Neo4j Destination](https://docs.airbyte.com/integrations/destinations/neo4j)

### Статьи

- [Neo4j ETL Best Practices](https://neo4j.com/blog/etl-best-practices/)
- [Eventual Consistency with Neo4j](https://neo4j.com/blog/eventual-consistency-neo4j/)
- [Reconciliation Patterns](https://martinfowler.com/articles/patterns-of-distributed-systems/)

### Инструменты

- [Neo4j ETL Tool](https://neo4j.com/labs/etl-tool/) — визуальный ETL
- [neo4j-admin import](https://neo4j.com/docs/operations-manual/current/tools/import/) — массовая загрузка
- [APOC](https://neo4j.com/labs/apoc/) — библиотека процедур

## История изменений

| Версия | Дата | Изменения |
|---|---|---|
| 1.0 | 2024-06 | Первая версия: что, когда, как синхронизируется |
| 1.1 | 2024-06 | Добавлены примеры кода и инструменты |
| 1.2 | 2024-06 | Добавлены reconciliation и мониторинг |
