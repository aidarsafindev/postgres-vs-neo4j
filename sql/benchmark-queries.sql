-- ============================================================================
-- Три варианта SQL для одной задачи: кратчайший путь
-- ============================================================================
-- \timing on

-- ----------------------------------------------------------------------------
-- Вариант 1: наивный recursive CTE (без pruning)
-- Именно это даёт «45 минут» на больших графах
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH RECURSIVE paths AS (
    SELECT
        r.to_city_id,
        ARRAY[r.from_city_id, r.to_city_id] AS path,
        r.time_minutes AS total_weight,
        1 AS hops
    FROM roads r
    WHERE r.from_city_id = 1
    UNION ALL
    SELECT
        r.to_city_id,
        p.path || r.to_city_id,
        p.total_weight + r.time_minutes,
        p.hops + 1
    FROM paths p
    JOIN roads r ON p.to_city_id = r.from_city_id
    WHERE NOT r.to_city_id = ANY(p.path)
      AND p.hops < 10
)
SELECT path, total_weight, hops
FROM paths
WHERE to_city_id = 4
ORDER BY total_weight ASC
LIMIT 1;

-- ----------------------------------------------------------------------------
-- Вариант 2: с pruning по upper bound (честная оптимизация)
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT * FROM shortest_path_sql(1, 4, 10, 10000);

-- ----------------------------------------------------------------------------
-- Вариант 3: pgRouting (если установлено)
-- CREATE EXTENSION IF NOT EXISTS pgrouting;
--
-- EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
-- SELECT * FROM pgr_dijkstra(
--     'SELECT id, from_city_id AS source, to_city_id AS target,
--             time_minutes AS cost FROM roads',
--     1, 4, directed := false
-- );
