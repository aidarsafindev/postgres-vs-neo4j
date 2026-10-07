# docs/CYPHER-GUIDE.md

# Cypher: подробное руководство с примерами

## Оглавление

1. [Что такое Cypher](#что-такое-cypher)
2. [Философия языка](#философия-языка)
3. [Базовые элементы](#базовые-элементы)
4. [Базовые команды](#базовые-команды)
5. [Примеры от простого к сложному](#примеры-от-простого-к-сложному)
6. [Сравнение с SQL](#сравнение-с-sql)
7. [Продвинутые возможности](#продвинутые-возможности)
8. [Оптимизация запросов](#оптимизация-запросов)
9. [Типичные ошибки](#типичные-ошибки)
10. [Шпаргалка](#шпаргалка)
11. [Ссылки](#ссылки)

## Что такое Cypher

**Cypher** — это декларативный язык запросов к графу в Neo4j. Аналог SQL для реляционных баз данных.

Название происходит от персонажа Кифера Сазерленда из фильма «Матрица» (Cypher в переводе — «шифр»). Также это игра слов с «cipher» — шифр, код.

**Основные характеристики:**

| Характеристика | Значение |
|---|---|
| Тип | Декларативный |
| Парадигма | Графовая |
| Появился | 2011 год |
| Стандарт | openCypher (открытый) |
| Аналоги | Gremlin, SPARQL, GQL |

**Ключевая идея:** Cypher описывает **что** мы хотим получить, а не **как** это сделать. Оптимизатор сам решает, как обойти граф.

## Философия языка

Cypher проектировался с тремя принципами:

**1. Читается как предложение**

```cypher
MATCH (c:City {name: 'Москва'})-[:ROAD]->(other)
RETURN other.name
```

Читается: «Найди город Москва, от него по дороге в другой город, верни имя другого города».

**2. Визуализирует граф**

```
(a:City)-[r:ROAD]->(b:City)
 │         │           │
 узел     ребро       узел
```

Запрос выглядит как рисунок графа. Это делает его интуитивно понятным.

**3. Декларативный, а не императивный**

Вы не пишете циклы и условия обхода. Вы описываете шаблон, который хотите найти. Neo4j сам решает, как его искать.

## Базовые элементы

### Узел: `()`

**Узел** обозначается круглыми скобками.

```cypher
()                    -- анонимный узел
(c)                   -- узел с переменной c
(c:City)              -- узел типа City
(c:City {name: 'Москва'})   -- узел с типом и свойством
```

**Что можно указать:**
- Переменную (`c`) — чтобы ссылаться на узел в других частях запроса
- Метку (`:City`) — тип узла
- Свойства (`{name: 'Москва'}`) — фильтр по свойствам

### Ребро: `[]`

**Ребро** обозначается квадратными скобками.

```cypher
-->                   -- анонимное ребро вправо
-[r]->                -- ребро с переменной r
-[:ROAD]->            -- ребро типа ROAD
-[r:ROAD {distance: 700}]->   -- ребро с типом и свойством
```

**Направление:**
- `-->` — вправо
- `<--` — влево
- `--` — без направления (в обе стороны)

### Направление: `->`

```cypher
(a)-[:ROAD]->(b)      -- от a к b
(a)<-[:ROAD]-(b)      -- от b к a
(a)-[:ROAD]-(b)       -- в обе стороны
```

**Совет:** по умолчанию указывайте направление. Это ускоряет запросы.

### Тип (метка): `:`

```cypher
(c:City)              -- узел типа City
-[r:ROAD]->           -- ребро типа ROAD
(c:City:Place)        -- узел с двумя типами (City и Place)
```

У одного узла может быть **несколько меток**. Это позволяет категоризировать данные.

### Свойства: `{}`

```cypher
(c:City {name: 'Москва'})
(c:City {name: 'Москва', population: 13000000})
-[r:ROAD {distance: 700, time_minutes: 240}]->
```

Свойства — это пары «ключ-значение». Могут быть у узлов и у рёбер.

### Параметры: `$`

```cypher
MATCH (c:City {name: $cityName})
RETURN c
```

**Параметры** — это переменные, которые передаются в запрос извне. Это безопаснее, чем подстановка значений напрямую, и позволяет Neo4j кэшировать план запроса.

**Из Python:**

```python
session.run("MATCH (c:City {name: $name}) RETURN c", name="Москва")
```

**Из 1С через прокси:**

```json
{
  "query": "MATCH (c:City {name: $name}) RETURN c",
  "params": {"name": "Москва"}
}
```

## Базовые команды

### MATCH — найти по шаблону

**MATCH** ищет узлы и рёбра, соответствующие шаблону.

```cypher
MATCH (c:City)
RETURN c
```

Аналог в SQL: `SELECT * FROM cities`.

```cypher
MATCH (c:City {name: 'Москва'})
RETURN c
```

Аналог в SQL: `SELECT * FROM cities WHERE name = 'Москва'`.

### WHERE — фильтр

**WHERE** добавляет условия к MATCH.

```cypher
MATCH (c:City)
WHERE c.population > 1000000
RETURN c.name, c.population
```

Аналог в SQL: `WHERE population > 1000000`.

**Операторы:**
- `=`, `<>`, `<`, `>`, `<=`, `>=`
- `AND`, `OR`, `NOT`
- `IN` — вхождение в список
- `STARTS WITH`, `ENDS WITH`, `CONTAINS` — для строк
- `IS NULL`, `IS NOT NULL`

### RETURN — вернуть результат

**RETURN** определяет, что вернуть.

```cypher
RETURN 1                          -- константа
RETURN c                          -- весь узел
RETURN c.name                     -- свойство
RETURN c.name AS cityName         -- с псевдонимом
RETURN DISTINCT c.name            -- уникальные
RETURN count(c)                   -- агрегат
```

**Агрегаты:**
- `count()`, `sum()`, `avg()`, `min()`, `max()`
- `collect()` — собрать в список
- `DISTINCT` — уникальные значения

### CREATE — создать

**CREATE** создаёт новый узел или ребро. **Всегда создаёт новый объект**, даже если такой уже есть.

```cypher
CREATE (c:City {name: 'Сочи', population: 400000})
RETURN c
```

```cypher
MATCH (a:City {name: 'Москва'}), (b:City {name: 'Сочи'})
CREATE (a)-[:ROAD {distance: 1600, time_minutes: 900}]->(b)
```

### MERGE — найти или создать

**MERGE** — это «найти или создать». Если объект есть — вернёт его. Если нет — создаст.

```cypher
MERGE (c:City {name: 'Москва'})
RETURN c
```

**Важно:** MERGE ищет по указанному шаблону. Если найден — ничего не делает. Если нет — создаёт.

**MERGE с SET:**

```cypher
MERGE (c:City {name: 'Москва'})
SET c.population = 13500000
RETURN c
```

Это «найди или создай, потом обнови свойство».

**MERGE для рёбер:**

```cypher
MATCH (a:City {name: 'Москва'}), (b:City {name: 'Казань'})
MERGE (a)-[r:ROAD]->(b)
SET r.distance = 800, r.time_minutes = 300
```

Это идемпотентно: повторный запуск не создаст дубль.

### SET — установить свойство

**SET** обновляет свойства узла или ребра.

```cypher
MATCH (c:City {name: 'Москва'})
SET c.population = 13500000
RETURN c
```

**Несколько свойств:**

```cypher
MATCH (c:City {name: 'Москва'})
SET c.population = 13500000,
    c.updated_at = datetime()
RETURN c
```

**Удалить свойство:**

```cypher
MATCH (c:City {name: 'Москва'})
SET c.population = NULL
```

### DELETE — удалить

**DELETE** удаляет узел или ребро.

```cypher
MATCH (c:City {name: 'Сочи'})
DELETE c
```

**Проблема:** если у узла есть рёбра, DELETE не сработает. Нужно сначала удалить рёбра.

**DETACH DELETE** — удалить узел и все его рёбра:

```cypher
MATCH (c:City {name: 'Сочи'})
DETACH DELETE c
```

### WITH — промежуточный шаг

**WITH** — это как pipe в Unix. Передаёт результат одного шага в следующий.

```cypher
MATCH (c:City)
WITH c, c.population AS pop
WHERE pop > 1000000
RETURN c.name
```

**Зачем нужен:**
- Разбить сложный запрос на шаги
- Агрегировать перед следующим шагом
- Ограничить результат перед продолжением

### UNWIND — развернуть список

**UNWIND** превращает список в строки.

```cypher
UNWIND [1, 2, 3] AS x
RETURN x
```

Результат:
```
x
1
2
3
```

**Применение:** массовая вставка данных.

```cypher
UNWIND $cities AS city
MERGE (c:City {name: city.name})
SET c.population = city.population
```

Это один запрос вместо тысячи.

### CALL — вызвать процедуру

**CALL** вызывает процедуру или функцию. Например, APOC или GDS.

```cypher
MATCH (from:City {name: 'Москва'}), (to:City {name: 'Новосибирск'})
CALL apoc.algo.dijkstra(from, to, 'ROAD>', 'time_minutes')
YIELD path, weight
RETURN path, weight
```

**YIELD** — получить результат процедуры.

## Примеры от простого к сложному

### 1. Найти все города

```cypher
MATCH (c:City)
RETURN c.name
```

**Что делает:** находит все узлы типа City и возвращает их имена.

### 2. Найти город по имени

```cypher
MATCH (c:City {name: 'Москва'})
RETURN c
```

**Что делает:** находит узел City с именем «Москва» и возвращает его целиком.

### 3. Найти дороги из Москвы

```cypher
MATCH (c:City {name: 'Москва'})-[r:ROAD]->(other:City)
RETURN other.name, r.distance, r.time_minutes
```

**Что делает:** находит все дороги, выходящие из Москвы, и возвращает имя города назначения, расстояние и время.

### 4. Найти путь через 3 города

```cypher
MATCH path = (a:City {name: 'Москва'})-[:ROAD*1..3]->(b:City)
RETURN [n IN nodes(path) | n.name] AS cities, length(path) AS hops
```

**Что делает:** находит все пути из Москвы длиной от 1 до 3 шагов.

**Разбор:**
- `path = ` — сохранить путь в переменную
- `*1..3` — от 1 до 3 шагов
- `[n IN nodes(path) | n.name]` — извлечь имена всех узлов пути
- `length(path)` — количество шагов

### 5. Создать новый город

```cypher
CREATE (c:City {name: 'Сочи', population: 400000})
RETURN c
```

**Что делает:** создаёт новый узел City с именем «Сочи».

### 6. Обновить свойство

```cypher
MATCH (c:City {name: 'Москва'})
SET c.population = 13500000
RETURN c
```

**Что делает:** находит Москву и обновляет население.

### 7. Удалить узел

```cypher
MATCH (c:City {name: 'Сочи'})
DETACH DELETE c
```

**Что делает:** удаляет узел «Сочи» и все его рёбра.

### 8. Найти кратчайший путь (с весами)

```cypher
MATCH (from:City {name: 'Москва'}), (to:City {name: 'Новосибирск'})
CALL apoc.algo.dijkstra(from, to, 'ROAD>', 'time_minutes')
YIELD path, weight
RETURN [n IN nodes(path) | n.name] AS cities, weight
```

**Что делает:** находит кратчайший путь по времени в пути.

**Важно:** `apoc.algo.dijkstra` учитывает веса. Стандартный `shortestPath` — нет.

### 9. Найти цепочку на 5 уровней

```cypher
MATCH path = (p:Product {code: 'A001'})<-[:STOCKS*1..5]-(w:Warehouse)
RETURN w.name, length(path) AS depth
ORDER BY depth
```

**Что делает:** находит все склады, которые поставляют товар A001, до 5-го уровня.

### 10. Найти рекомендации

```cypher
MATCH (p:Product {code: 'A001'})-[bw:BOUGHT_WITH]->(rec)
RETURN rec.code, rec.name, bw.frequency
ORDER BY bw.frequency DESC
LIMIT 5
```

**Что делает:** находит товары, которые покупают вместе с A001, сортирует по частоте.

### 11. Обновить остатки на складе

```cypher
MERGE (w:Warehouse {name: 'Склад Москва'})
MERGE (p:Product {code: 'A001'})
MERGE (w)-[s:STOCKS]->(p)
SET s.quantity = 150
```

**Что делает:** находит или создаёт склад и товар, находит или создаёт ребро, обновляет количество.

**Идемпотентно:** повторный запуск не создаст дубли.

### 12. Найти все города, доступные из Москвы за 2 шага

```cypher
MATCH (from:City {name: 'Москва'})-[:ROAD*2]->(to:City)
RETURN DISTINCT to.name
```

**Что делает:** находит все города, до которых ровно 2 шага от Москвы.

### 13. Найти топ-5 городов по количеству дорог

```cypher
MATCH (c:City)-[:ROAD]->()
RETURN c.name, count(*) AS roads_count
ORDER BY roads_count DESC
LIMIT 5
```

**Что делает:** считает, сколько дорог выходит из каждого города, и возвращает топ-5.

### 14. Найти путь через промежуточный город

```cypher
MATCH path = (a:City {name: 'Москва'})-[:ROAD]->(mid:City)-[:ROAD]->(b:City {name: 'Новосибирск'})
RETURN [n IN nodes(path) | n.name] AS cities
```

**Что делает:** находит путь Москва → X → Новосибирск, где X — любой промежуточный город.

### 15. Обновить много узлов батчем

```cypher
UNWIND $cities AS city
MATCH (c:City {name: city.name})
SET c.population = city.population
```

**Что делает:** обновляет население для списка городов за один запрос.

**Из Python:**

```python
cities = [
    {"name": "Москва", "population": 13500000},
    {"name": "Казань", "population": 1400000}
]
session.run("""
    UNWIND $cities AS city
    MATCH (c:City {name: city.name})
    SET c.population = city.population
""", cities=cities)
```

## Сравнение с SQL

| Задача | SQL | Cypher |
|---|---|---|
| Найти все | `SELECT * FROM cities` | `MATCH (c:City) RETURN c` |
| Фильтр | `WHERE name = 'Москва'` | `{name: 'Москва'}` или `WHERE` |
| Join | `JOIN roads ON ...` | `-[:ROAD]->` |
| Рекурсия | `WITH RECURSIVE` | `-[:ROAD*1..3]->` |
| Агрегат | `GROUP BY`, `COUNT(*)` | `count(*)`, `WITH` |
| Создать | `INSERT INTO` | `CREATE` |
| Обновить | `UPDATE SET` | `SET` |
| Удалить | `DELETE FROM` | `DELETE` |
| Upsert | `INSERT ... ON CONFLICT` | `MERGE` |

**Ключевые отличия:**

1. **Связи.** В SQL — JOIN. В Cypher — рёбра прямо в запросе.
2. **Рекурсия.** В SQL — `WITH RECURSIVE`. В Cypher — `*1..3`.
3. **Идемпотентность.** В SQL — `ON CONFLICT`. В Cypher — `MERGE`.
4. **Читаемость.** Cypher визуально ближе к графу.

## Продвинутые возможности

### Переменная длина пути

```cypher
MATCH path = (a)-[:ROAD*1..5]->(b)
RETURN path
```

- `*1..5` — от 1 до 5 шагов
- `*` — любая длина
- `*3` — ровно 3 шага
- `*1..` — от 1 до бесконечности

### Агрегация

```cypher
MATCH (c:City)-[:ROAD]->()
RETURN c.name, count(*) AS roads_count
ORDER BY roads_count DESC
```

**Агрегаты работают автоматически.** Если в RETURN есть агрегатная функция и неагрегатное поле, Neo4j группирует по неагрегатному полю.

### WITH для многошаговых запросов

```cypher
MATCH (c:City)
WHERE c.population > 1000000
WITH c ORDER BY c.population DESC LIMIT 10
MATCH (c)-[:ROAD]->(other)
RETURN c.name, count(other) AS connections
```

**WITH** разбивает запрос на шаги. Как временная таблица.

### OPTIONAL MATCH

```cypher
MATCH (c:City)
OPTIONAL MATCH (c)-[:ROAD]->(other)
RETURN c.name, count(other) AS roads
```

**OPTIONAL MATCH** — как LEFT JOIN. Если связей нет, узел всё равно вернётся.

### CASE

```cypher
MATCH (c:City)
RETURN c.name,
       CASE
           WHEN c.population > 1000000 THEN 'large'
           WHEN c.population > 500000 THEN 'medium'
           ELSE 'small'
       END AS size
```

### Списки и коллекции

```cypher
MATCH (c:City)
RETURN collect(c.name) AS all_cities
```

**collect()** собирает значения в список.

```cypher
MATCH path = (a)-[:ROAD*1..3]->(b)
RETURN [n IN nodes(path) | n.name] AS names
```

**List comprehension** — как map в Python.

### Функции

**Строковые:**
- `toLower()`, `toUpper()`
- `trim()`, `split()`
- `substring()`, `replace()`

**Числовые:**
- `abs()`, `round()`, `floor()`, `ceil()`
- `random()`

**Дата и время:**
- `datetime()`, `date()`, `time()`
- `duration()`

**Графовые:**
- `nodes(path)` — узлы пути
- `relationships(path)` — рёбра пути
- `length(path)` — длина пути
- `id(node)` — внутренний ID

### Агрегатные функции

```cypher
MATCH (c:City)-[r:ROAD]->()
RETURN count(r) AS roads_total,
       avg(r.distance) AS avg_distance,
       max(r.distance) AS max_distance,
       sum(r.distance) AS total_distance
```

## Оптимизация запросов

### PROFILE и EXPLAIN

**PROFILE** показывает, как Neo4j выполнил запрос.

```cypher
PROFILE MATCH (c:City {name: 'Москва'})-[:ROAD]->(other)
RETURN other.name
```

Результат — план выполнения с временем и количеством строк на каждом шаге.

**EXPLAIN** показывает план без выполнения.

```cypher
EXPLAIN MATCH (c:City {name: 'Москва'})-[:ROAD]->(other)
RETURN other.name
```

### Индексы

**Создать индекс:**

```cypher
CREATE INDEX FOR (c:City) ON (c.name)
```

**Составной индекс:**

```cypher
CREATE INDEX FOR (c:City) ON (c.name, c.population)
```

**Уникальный констрейнт:**

```cypher
CREATE CONSTRAINT FOR (c:City) REQUIRE c.name IS UNIQUE
```

**Проверить индексы:**

```cypher
SHOW INDEXES
```

### Правила оптимизации

**1. Указывайте направление рёбер**

```cypher
-- ✅ Хорошо
MATCH (a)-[:ROAD]->(b)

-- ❌ Плохо
MATCH (a)-[:ROAD]-(b)
```

**2. Используйте параметры**

```cypher
-- ✅ Хорошо: план кэшируется
MATCH (c:City {name: $name})

-- ❌ Плохо: план не кэшируется
MATCH (c:City {name: 'Москва'})
```

**3. Ограничивайте раньше**

```cypher
-- ✅ Хорошо
MATCH (c:City {name: 'Москва'})-[:ROAD]->(other)
RETURN other

-- ❌ Плохо
MATCH (c:City)-[:ROAD]->(other)
WHERE c.name = 'Москва'
RETURN other
```

**4. Используйте LIMIT**

```cypher
MATCH (c:City)
RETURN c.name
LIMIT 10
```

**5. Используйте PROFILE**

```cypher
PROFILE MATCH (c:City)-[:ROAD]->(other)
RETURN c.name, count(other)
```

Смотрите на план: где `AllNodesScan` — там нужен индекс.

## Типичные ошибки

### 1. MERGE со свойствами в ребре

```cypher
-- ❌ Плохо: создаст дубли при обновлении
MERGE (a)-[:ROAD {distance: 700}]->(b)

-- ✅ Хорошо
MERGE (a)-[r:ROAD]->(b)
SET r.distance = 700
```

### 2. shortestPath без весов

```cypher
-- ❌ Плохо: считает по числу шагов, а не по весам
MATCH path = shortestPath((a)-[:ROAD*]->(b))
RETURN path

-- ✅ Хорошо
MATCH (a:City {name: 'Москва'}), (b:City {name: 'Новосибирск'})
CALL apoc.algo.dijkstra(a, b, 'ROAD>', 'time_minutes')
YIELD path, weight
RETURN path, weight
```

### 3. Забыли path = в MATCH

```cypher
-- ❌ Плохо: length(path) не сработает
MATCH (a)-[:ROAD*1..5]->(b)
RETURN length(path)

-- ✅ Хорошо
MATCH path = (a)-[:ROAD*1..5]->(b)
RETURN length(path)
```

### 4. Несовпадение имён переменных

```cypher
-- ❌ Плохо: bw не определена
MATCH (p:Product)-[cw:BOUGHT_WITH]->(rec)
RETURN rec.code, bw.frequency

-- ✅ Хорошо
MATCH (p:Product)-[bw:BOUGHT_WITH]->(rec)
RETURN rec.code, bw.frequency
```

### 5. DELETE без DETACH

```cypher
-- ❌ Плохо: ошибка, если у узла есть рёбра
MATCH (c:City {name: 'Москва'})
DELETE c

-- ✅ Хорошо
MATCH (c:City {name: 'Москва'})
DETACH DELETE c
```

### 6. Не указали направление

```cypher
-- ⚠️ Работает, но медленнее
MATCH (a)-[:ROAD]-(b)

-- ✅ Быстрее
MATCH (a)-[:ROAD]->(b)
```

### 7. Не создали индекс

```cypher
-- ⚠️ Без индекса — полное сканирование
MATCH (c:City {name: 'Москва'})
RETURN c

-- ✅ Создайте индекс
CREATE INDEX FOR (c:City) ON (c.name)
```

## Шпаргалка

### Синтаксис

```
()                    узел
[]                    ребро
->                    направление
:Label                тип
{key: value}          свойство
$param                параметр
*1..5                 переменная длина
path = ...            сохранить путь
```

### Команды

```
MATCH ...             найти
WHERE ...             фильтр
RETURN ...            вернуть
CREATE ...            создать
MERGE ...             найти или создать
SET ...               обновить
DELETE ...            удалить
DETACH DELETE ...     удалить с рёбрами
WITH ...              промежуточный шаг
UNWIND ...            развернуть список
CALL ...              вызвать процедуру
OPTIONAL MATCH ...    как LEFT JOIN
```

### Агрегаты

```
count()               количество
sum()                 сумма
avg()                 среднее
min()                 минимум
max()                 максимум
collect()             собрать в список
```

### Полезные функции

```
nodes(path)           узлы пути
relationships(path)   рёбра пути
length(path)          длина пути
id(node)              внутренний ID
toLower(s)            нижний регистр
split(s, delim)       разбить строку
datetime()            текущее время
```

### Профилирование

```
PROFILE ...           выполнить с планом
EXPLAIN ...           план без выполнения
SHOW INDEXES          показать индексы
CREATE INDEX ...      создать индекс
```

## Ссылки

### Официальная документация

- [Cypher Manual](https://neo4j.com/docs/cypher-manual/current/)
- [Cypher Refcard](https://neo4j.com/docs/cypher-refcard/current/) — шпаргалка
- [openCypher](https://opencypher.org/) — открытый стандарт

### Обучение

- [Neo4j GraphAcademy](https://graphacademy.neo4j.com/) — бесплатные курсы
- [Cypher Tutorial](https://neo4j.com/developer/cypher/)
- [Neo4j Sandbox](https://sandbox.neo4j.com/) — облачная песочница

### Книги

- **«Graph Databases»** — Ian Robinson, Jim Webber, Emil Eifrem
- **«Neo4j in Action»** — Jonas Partner, Aleksa Vukotic
- **«Learning Neo4j»** — Rik Van Bruggen

### Инструменты

- [Neo4j Browser](https://neo4j.com/developer/neo4j-browser/) — UI для Cypher
- [Neo4j Bloom](https://neo4j.com/product/bloom/) — визуализация
- [APOC](https://neo4j.com/labs/apoc/) — библиотека процедур
- [GDS](https://neo4j.com/docs/graph-data-science/current/) — алгоритмы

## История изменений

| Версия | Дата | Изменения |
|---|---|---|
| 1.0 | 2024-06 | Первая версия: базовый синтаксис и примеры |
| 1.1 | 2024-06 | Добавлены продвинутые возможности |
| 1.2 | 2024-06 | Добавлены оптимизация и типичные ошибки |
| 1.3 | 2024-06 | Добавлена шпаргалка и ссылки |
