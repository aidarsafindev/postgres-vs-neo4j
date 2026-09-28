-- ============================================================================
-- Генерация большого графа
-- ============================================================================
-- psql -v num_cities=100000 -v num_roads=500000 -f generate-large-graph.sql

\set num_cities 100000
\set num_roads  500000

-- 1. Города
INSERT INTO cities (name, population)
SELECT
    'City_' || g,
    (random() * 5000000 + 10000)::INTEGER
FROM generate_series(1, :num_cities) g;

-- 2. Дороги без петель и дублей
INSERT INTO roads (from_city_id, to_city_id, distance, time_minutes)
SELECT DISTINCT ON (f, t)
    f AS from_city_id,
    t AS to_city_id,
    (random() * 5000 + 50)::INTEGER AS distance,
    (random() * 3000 + 30)::INTEGER AS time_minutes
FROM (
    SELECT
        (random() * :num_cities + 1)::INTEGER AS f,
        (random() * :num_cities + 1)::INTEGER AS t
    FROM generate_series(1, :num_roads * 3)
) sub
WHERE f <> t
LIMIT :num_roads;

-- 3. Склады
INSERT INTO warehouses (name, city_id, capacity)
SELECT
    'Warehouse_' || g,
    (random() * :num_cities + 1)::INTEGER,
    (random() * 100000 + 1000)::INTEGER
FROM generate_series(1, 50) g;

-- 4. Товары
INSERT INTO products (code, name)
SELECT
    'P' || LPAD(g::TEXT, 5, '0'),
    'Товар ' || g
FROM generate_series(1, 1000) g;

-- 5. Остатки
INSERT INTO warehouse_stock (warehouse_id, product_id, quantity)
SELECT w.id, p.id, (random() * 1000)::INTEGER
FROM warehouses w
CROSS JOIN LATERAL (
    SELECT id FROM products ORDER BY random() LIMIT 10
) p
ON CONFLICT DO NOTHING;

-- 6. КРИТИЧНО: обновить статистику
ANALYZE cities;
ANALYZE roads;
ANALYZE warehouses;
ANALYZE products;
ANALYZE warehouse_stock;

-- 7. Проверка
SELECT 'cities' AS entity, COUNT(*) FROM cities
UNION ALL SELECT 'roads', COUNT(*) FROM roads
UNION ALL SELECT 'warehouses', COUNT(*) FROM warehouses;
