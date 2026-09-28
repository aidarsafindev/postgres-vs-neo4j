// ============================================================================
// Сверка данных Neo4j с PostgreSQL
// Сравните результат с sql/verify.sql
// ============================================================================

MATCH (c:City)      WITH count(c) AS cities
MATCH ()-[r:ROAD]->() WITH cities, count(r) AS roads
MATCH (w:Warehouse) WITH cities, roads, count(w) AS warehouses
MATCH (p:Product)   WITH cities, roads, warehouses, count(p) AS products
MATCH ()-[s:STOCKS]->() WITH cities, roads, warehouses, products, count(s) AS stock
MATCH ()-[b:BOUGHT_WITH]->() WITH cities, roads, warehouses, products, stock, count(b) AS bought_with
RETURN cities, roads, warehouses, products, stock, bought_with;
