"""
Генератор тестового графа: города, дороги, склады.
Заполняет Neo4j и PostgreSQL ОДИНАКОВЫМИ данными для честного сравнения.

Ключевые решения:
- Батчи UNWIND вместо N+1 (иначе 100k городов = часы)
- MERGE (a)-[r:ROAD]->(b) SET r += $props (не создаёт дубли)
- Одинаковый seed для random в Neo4j и PostgreSQL
"""

import logging
import os
import random

import psycopg2
from psycopg2.extras import execute_values
from neo4j import GraphDatabase

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] GENERATOR: %(message)s",
)
logger = logging.getLogger("generator")

NEO4J_URI      = os.getenv("NEO4J_URI", "bolt://neo4j:7687")
NEO4J_USER     = os.getenv("NEO4J_USER", "neo4j")
NEO4J_PASSWORD = os.getenv("NEO4J_PASSWORD", "password")

POSTGRES_HOST     = os.getenv("POSTGRES_HOST", "postgres")
POSTGRES_PORT     = int(os.getenv("POSTGRES_PORT", "5432"))
POSTGRES_DB       = os.getenv("POSTGRES_DB", "testdb")
POSTGRES_USER     = os.getenv("POSTGRES_USER", "demo")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "demo")

NUM_CITIES     = int(os.getenv("NUM_CITIES", "1000"))
NUM_ROADS      = int(os.getenv("NUM_ROADS", "5000"))
NUM_WAREHOUSES = int(os.getenv("NUM_WAREHOUSES", "50"))
SEED           = int(os.getenv("SEED", "42"))

BATCH_SIZE = 1000


def batched(iterable, size):
    batch = []
    for item in iterable:
        batch.append(item)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch


def generate_neo4j(driver):
    logger.info("Neo4j: %d cities, %d roads, %d warehouses",
                NUM_CITIES, NUM_ROADS, NUM_WAREHOUSES)

    rng = random.Random(SEED)

    with driver.session() as session:
        session.run("CREATE INDEX IF NOT EXISTS FOR (c:City) ON (c.name)")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (c:City) REQUIRE c.name IS UNIQUE")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (w:Warehouse) REQUIRE w.name IS UNIQUE")
        session.run("CREATE CONSTRAINT IF NOT EXISTS FOR (p:Product) REQUIRE p.code IS UNIQUE")

        # --- Города ---
        logger.info("Neo4j: creating cities...")
        cities = [
            {"name": f"City_{i}", "population": rng.randint(10000, 5000000)}
            for i in range(NUM_CITIES)
        ]
        for batch in batched(cities, BATCH_SIZE):
            session.run("""
                UNWIND $batch AS row
                MERGE (:City {name: row.name})
                SET .population = row.population
            """, batch=batch)

        # --- Дороги ---
        logger.info("Neo4j: creating roads...")
        seen = set()
        roads = []
        while len(roads) < NUM_ROADS:
            f = rng.randint(0, NUM_CITIES - 1)
            t = rng.randint(0, NUM_CITIES - 1)
            if f == t:
                continue
            if (f, t) in seen:
                continue
            seen.add((f, t))
            roads.append({
                "from": f"City_{f}",
                "to":   f"City_{t}",
                "distance": rng.randint(50, 5000),
                "time":     rng.randint(30, 3000),
            })

        for batch in batched(roads, BATCH_SIZE):
            session.run("""
                UNWIND $batch AS row
                MATCH (a:City {name: row.from})
                MATCH (b:City {name: row.to})
                MERGE (a)-[r:ROAD]->(b)
                SET r.distance = row.distance,
                    r.time_minutes = row.time
            """, batch=batch)

        # --- Склады ---
        logger.info("Neo4j: creating warehouses...")
        warehouses = []
        for i in range(NUM_WAREHOUSES):
            c = rng.randint(0, NUM_CITIES - 1)
            warehouses.append({
                "name": f"Warehouse_{i}",
                "city": f"City_{c}",
                "capacity": rng.randint(1000, 100000),
            })
        for batch in batched(warehouses, BATCH_SIZE):
            session.run("""
                UNWIND $batch AS row
                MATCH (c:City {name: row.city})
                MERGE (w:Warehouse {name: row.name})
                SET w.capacity = row.capacity,
                    w.city     = row.city
                MERGE (w)-[:LOCATED_IN]->(c)
            """, batch=batch)

    logger.info("Neo4j: done")


def generate_postgres():
    logger.info("PostgreSQL: generating identical data...")
    rng = random.Random(SEED)

    conn = psycopg2.connect(
        host=POSTGRES_HOST, port=POSTGRES_PORT,
        dbname=POSTGRES_DB, user=POSTGRES_USER, password=POSTGRES_PASSWORD,
    )

    with conn.cursor() as cur:
        cur.execute("""
            TRUNCATE roads, warehouse_stock, warehouses, products, cities
            RESTART IDENTITY CASCADE;
        """)

        # Города
        cities = [(f"City_{i}", rng.randint(10000, 5000000)) for i in range(NUM_CITIES)]
        execute_values(cur,
            "INSERT INTO cities (name, population) VALUES %s",
            cities)

        # Дороги — тот же алгоритм, что в Neo4j
        seen = set()
        roads = []
        while len(roads) < NUM_ROADS:
            f = rng.randint(1, NUM_CITIES)
            t = rng.randint(1, NUM_CITIES)
            if f == t or (f, t) in seen:
                continue
            seen.add((f, t))
            roads.append((f, t, rng.randint(50, 5000), rng.randint(30, 3000)))

        execute_values(cur,
            "INSERT INTO roads (from_city_id, to_city_id, distance, time_minutes) VALUES %s",
            roads)

        # Склады
        warehouses = [
            (f"Warehouse_{i}", rng.randint(1, NUM_CITIES), rng.randint(1000, 100000))
            for i in range(NUM_WAREHOUSES)
        ]
        execute_values(cur,
            "INSERT INTO warehouses (name, city_id, capacity) VALUES %s",
            warehouses)

        cur.execute("ANALYZE;")

    conn.commit()
    conn.close()
    logger.info("PostgreSQL: done")


def main():
    logger.info("Starting generator (seed=%d)", SEED)
    logger.info("Params: %d cities, %d roads, %d warehouses",
                NUM_CITIES, NUM_ROADS, NUM_WAREHOUSES)

    driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USER, NEO4J_PASSWORD))
    try:
        generate_neo4j(driver)
        generate_postgres()
    finally:
        driver.close()

    logger.info("Generation complete. Данные идентичны в Neo4j и PostgreSQL.")


if __name__ == "__main__":
    main()
