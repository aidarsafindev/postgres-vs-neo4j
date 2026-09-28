-- ============================================================================
-- Реляционная модель данных
-- ============================================================================
-- Используем INTEGER-ключи вместо VARCHAR-имён: честное сравнение с Neo4j.

DROP TABLE IF EXISTS bought_with CASCADE;
DROP TABLE IF EXISTS warehouse_stock CASCADE;
DROP TABLE IF EXISTS warehouses CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS roads CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP FUNCTION IF EXISTS shortest_path_sql(INTEGER, INTEGER, INTEGER, INTEGER);

-- --- Таблицы ---

CREATE TABLE cities (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) UNIQUE NOT NULL,
    population  INTEGER
);

CREATE TABLE roads (
    id            SERIAL PRIMARY KEY,
    from_city_id  INTEGER NOT NULL REFERENCES cities(id),
    to_city_id    INTEGER NOT NULL REFERENCES cities(id),
    distance      INTEGER,
    time_minutes  INTEGER,
    CONSTRAINT no_self_loop CHECK (from_city_id <> to_city_id)
);

CREATE TABLE warehouses (
    id        SERIAL PRIMARY KEY,
    name      VARCHAR(100) UNIQUE NOT NULL,
    city_id   INTEGER REFERENCES cities(id),
    capacity  INTEGER
);

CREATE TABLE products (
    id    SERIAL PRIMARY KEY,
    code  VARCHAR(50) UNIQUE NOT NULL,
    name  VARCHAR(255)
);

CREATE TABLE warehouse_stock (
    warehouse_id INTEGER REFERENCES warehouses(id),
    product_id   INTEGER REFERENCES products(id),
    quantity     INTEGER,
    PRIMARY KEY (warehouse_id, product_id)
);

CREATE TABLE bought_with (
    product_id      INTEGER REFERENCES products(id),
    recommended_id  INTEGER REFERENCES products(id),
    frequency       INTEGER,
    PRIMARY KEY (product_id, recommended_id),
    CONSTRAINT no_self_recommend CHECK (product_id <> recommended_id)
);

-- --- Индексы ---

CREATE INDEX idx_roads_from      ON roads(from_city_id);
CREATE INDEX idx_roads_to        ON roads(to_city_id);
CREATE INDEX idx_roads_from_time ON roads(from_city_id, time_minutes);
CREATE INDEX idx_roads_to_time   ON roads(to_city_id, time_minutes);

CREATE INDEX idx_warehouses_city ON warehouses(city_id);
CREATE INDEX idx_stock_product   ON warehouse_stock(product_id);
CREATE INDEX idx_stock_warehouse ON warehouse_stock(warehouse_id);
CREATE INDEX idx_bought_with_prod ON bought_with(product_id);

-- --- Демо-данные ---

INSERT INTO cities (name, population) VALUES
    ('Москва', 13000000),
    ('Санкт-Петербург', 5400000),
    ('Казань', 1300000),
    ('Новосибирск', 1600000),
    ('Екатеринбург', 1500000);

INSERT INTO roads (from_city_id, to_city_id, distance, time_minutes) VALUES
    (1, 2, 700, 240), (2, 1, 700, 240),
    (1, 3, 800, 300), (3, 1, 800, 300),
    (1, 4, 3300, 1200), (4, 1, 3300, 1200),
    (3, 5, 900, 360), (5, 3, 900, 360),
    (5, 4, 1500, 600), (4, 5, 1500, 600);

INSERT INTO warehouses (name, city_id, capacity) VALUES
    ('Склад Москва', 1, 10000),
    ('Склад СПб', 2, 5000),
    ('Склад Казань', 3, 3000);

INSERT INTO products (code, name) VALUES
    ('A001', 'Товар А'),
    ('B002', 'Товар B'),
    ('C003', 'Товар C');

INSERT INTO warehouse_stock (warehouse_id, product_id, quantity) VALUES
    (1, 1, 100), (1, 2, 50),
    (2, 1, 200), (2, 3, 75),
    (3, 2, 150);

INSERT INTO bought_with (product_id, recommended_id, frequency) VALUES
    (1, 2, 45), (1, 3, 30), (2, 3, 20);

-- --- Функция кратчайшего пути с pruning ---
-- Наивная версия (без pruning) — в benchmark-queries.sql как «вариант 1».

CREATE OR REPLACE FUNCTION shortest_path_sql(
    p_from_id     INTEGER,
    p_to_id       INTEGER,
    p_max_depth   INTEGER DEFAULT 10,
    p_upper_bound INTEGER DEFAULT 2147483647
)
RETURNS TABLE(
    path          INTEGER[],
    total_weight  INTEGER,
    hops          INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE paths AS (
        SELECT
            r.to_city_id,
            ARRAY[r.from_city_id, r.to_city_id] AS path,
            r.time_minutes AS total_weight,
            1 AS hops
        FROM roads r
        WHERE r.from_city_id = p_from_id
          AND r.time_minutes < p_upper_bound

        UNION ALL

        SELECT
            r.to_city_id,
            p.path || r.to_city_id,
            p.total_weight + r.time_minutes,
            p.hops + 1
        FROM paths p
        JOIN roads r ON p.to_city_id = r.from_city_id
        WHERE NOT r.to_city_id = ANY(p.path)
          AND p.hops < p_max_depth
          AND p.total_weight + r.time_minutes < p_upper_bound
    )
    SELECT p.path, p.total_weight, p.hops
    FROM paths p
    WHERE p.to_city_id = p_to_id
    ORDER BY p.total_weight ASC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- --- Обновление статистики ---
ANALYZE cities;
ANALYZE roads;
ANALYZE warehouses;
ANALYZE products;
ANALYZE warehouse_stock;
ANALYZE bought_with;

-- --- Статистика ---
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'База создана:';
    RAISE NOTICE '  Города: %', (SELECT COUNT(*) FROM cities);
    RAISE NOTICE '  Дороги: %', (SELECT COUNT(*) FROM roads);
    RAISE NOTICE '  Склады: %', (SELECT COUNT(*) FROM warehouses);
    RAISE NOTICE '  Товары: %', (SELECT COUNT(*) FROM products);
    RAISE NOTICE '========================================';
END $$;
