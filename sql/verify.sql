-- ============================================================================
-- Сверка консистентности: PostgreSQL и Neo4j должны иметь одинаковые данные
-- Сравните с docker/neo4j/verify.cypher
-- ============================================================================

SELECT 'cities'     AS entity, COUNT(*) AS cnt FROM cities
UNION ALL SELECT 'roads',       COUNT(*) FROM roads
UNION ALL SELECT 'warehouses',  COUNT(*) FROM warehouses
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'stock',       COUNT(*) FROM warehouse_stock
UNION ALL SELECT 'bought_with', COUNT(*) FROM bought_with;
