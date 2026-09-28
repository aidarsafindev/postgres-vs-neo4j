// ============================================================================
// Инициализация демо-графа Neo4j
// ============================================================================
// Соответствует sql/postgres-schema.sql: те же города, дороги, склады, товары.

// --- Индексы и констрейнты ---
CREATE INDEX IF NOT EXISTS FOR (c:City)      ON (c.name);
CREATE INDEX IF NOT EXISTS FOR (w:Warehouse) ON (w.name);
CREATE INDEX IF NOT EXISTS FOR (p:Product)   ON (p.code);

CREATE CONSTRAINT IF NOT EXISTS FOR (c:City)      REQUIRE c.name IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (w:Warehouse) REQUIRE w.name IS UNIQUE;
CREATE CONSTRAINT IF NOT EXISTS FOR (p:Product)   REQUIRE p.code IS UNIQUE;

// --- Города ---
MERGE (msk:City {name: 'Москва',          population: 13000000})
MERGE (spb:City {name: 'Санкт-Петербург', population: 5400000})
MERGE (kzn:City {name: 'Казань',          population: 1300000})
MERGE (nsk:City {name: 'Новосибирск',     population: 1600000})
MERGE (ekb:City {name: 'Екатеринбург',    population: 1500000});

// --- Дороги ---
// ВАЖНО: MERGE (a)-[r:ROAD]->(b) SET r += $props
// НЕ MERGE (a)-[:ROAD {props}]->(b) — иначе дубли при обновлении
MATCH (msk:City {name: 'Москва'}), (spb:City {name: 'Санкт-Петербург'})
MERGE (msk)-[r:ROAD]->(spb) SET r.distance = 700, r.time_minutes = 240;
MATCH (spb:City {name: 'Санкт-Петербург'}), (msk:City {name: 'Москва'})
MERGE (spb)-[r:ROAD]->(msk) SET r.distance = 700, r.time_minutes = 240;

MATCH (msk:City {name: 'Москва'}), (kzn:City {name: 'Казань'})
MERGE (msk)-[r:ROAD]->(kzn) SET r.distance = 800, r.time_minutes = 300;
MATCH (kzn:City {name: 'Казань'}), (msk:City {name: 'Москва'})
MERGE (kzn)-[r:ROAD]->(msk) SET r.distance = 800, r.time_minutes = 300;

MATCH (msk:City {name: 'Москва'}), (nsk:City {name: 'Новосибирск'})
MERGE (msk)-[r:ROAD]->(nsk) SET r.distance = 3300, r.time_minutes = 1200;
MATCH (nsk:City {name: 'Новосибирск'}), (msk:City {name: 'Москва'})
MERGE (nsk)-[r:ROAD]->(msk) SET r.distance = 3300, r.time_minutes = 1200;

MATCH (kzn:City {name: 'Казань'}), (ekb:City {name: 'Екатеринбург'})
MERGE (kzn)-[r:ROAD]->(ekb) SET r.distance = 900, r.time_minutes = 360;
MATCH (ekb:City {name: 'Екатеринбург'}), (kzn:City {name: 'Казань'})
MERGE (ekb)-[r:ROAD]->(kzn) SET r.distance = 900, r.time_minutes = 360;

MATCH (ekb:City {name: 'Екатеринбург'}), (nsk:City {name: 'Новосибирск'})
MERGE (ekb)-[r:ROAD]->(nsk) SET r.distance = 1500, r.time_minutes = 600;
MATCH (nsk:City {name: 'Новосибирск'}), (ekb:City {name: 'Екатеринбург'})
MERGE (nsk)-[r:ROAD]->(ekb) SET r.distance = 1500, r.time_minutes = 600;

// --- Склады ---
MERGE (wh_msk:Warehouse {name: 'Склад Москва', capacity: 10000})
MERGE (wh_spb:Warehouse {name: 'Склад СПб',    capacity: 5000})
MERGE (wh_kzn:Warehouse {name: 'Склад Казань', capacity: 3000});

MATCH (w:Warehouse {name: 'Склад Москва'}), (c:City {name: 'Москва'})
MERGE (w)-[:LOCATED_IN]->(c);
MATCH (w:Warehouse {name: 'Склад СПб'}), (c:City {name: 'Санкт-Петербург'})
MERGE (w)-[:LOCATED_IN]->(c);
MATCH (w:Warehouse {name: 'Склад Казань'}), (c:City {name: 'Казань'})
MERGE (w)-[:LOCATED_IN]->(c);

// --- Товары ---
MERGE (prod_a:Product {code: 'A001', name: 'Товар А'})
MERGE (prod_b:Product {code: 'B002', name: 'Товар B'})
MERGE (prod_c:Product {code: 'C003', name: 'Товар C'});

// --- Остатки ---
MATCH (w:Warehouse {name: 'Склад Москва'}), (p:Product {code: 'A001'})
MERGE (w)-[s:STOCKS]->(p) SET s.quantity = 100;
MATCH (w:Warehouse {name: 'Склад Москва'}), (p:Product {code: 'B002'})
MERGE (w)-[s:STOCKS]->(p) SET s.quantity = 50;
MATCH (w:Warehouse {name: 'Склад СПб'}), (p:Product {code: 'A001'})
MERGE (w)-[s:STOCKS]->(p) SET s.quantity = 200;
MATCH (w:Warehouse {name: 'Склад СПб'}), (p:Product {code: 'C003'})
MERGE (w)-[s:STOCKS]->(p) SET s.quantity = 75;
MATCH (w:Warehouse {name: 'Склад Казань'}), (p:Product {code: 'B002'})
MERGE (w)-[s:STOCKS]->(p) SET s.quantity = 150;

// --- Совместные покупки ---
// Семантика: frequency — условная вероятность P(B|A) × 100
MATCH (a:Product {code: 'A001'}), (b:Product {code: 'B002'})
MERGE (a)-[r:BOUGHT_WITH]->(b) SET r.frequency = 45;
MATCH (a:Product {code: 'A001'}), (c:Product {code: 'C003'})
MERGE (a)-[r:BOUGHT_WITH]->(c) SET r.frequency = 30;
MATCH (b:Product {code: 'B002'}), (c:Product {code: 'C003'})
MERGE (b)-[r:BOUGHT_WITH]->(c) SET r.frequency = 20;

RETURN 'Graph initialized' AS status;
