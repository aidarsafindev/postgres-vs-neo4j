"""
HTTP-прокси для интеграции 1С с Neo4j.

Эндпоинты:
- POST /api/v1/graph/shortest-path   — кратчайший путь (APOC Dijkstra)
- POST /api/v1/graph/supply-chain    — цепочка поставок
- POST /api/v1/graph/recommendations — рекомендации
- POST /api/v1/graph/update          — обновление графа
- POST /api/v1/benchmark/sql         — тот же запрос на SQL
- GET  /health                       — проверка
"""

import logging
import time

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request
from neo4j import GraphDatabase

from config import Config

config = Config()
logging.basicConfig(
    level=getattr(logging, config.LOG_LEVEL),
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("graph-proxy")

app = Flask(__name__)

neo4j_driver = GraphDatabase.driver(
    config.NEO4J_URI,
    auth=(config.NEO4J_USER, config.NEO4J_PASSWORD),
)


def get_pg_connection():
    return psycopg2.connect(config.postgres_dsn)


# ---------------------------------------------------------------------------
# Кратчайший путь — APOC Dijkstra (учитывает веса!)
# ---------------------------------------------------------------------------

@app.route("/api/v1/graph/shortest-path", methods=["POST"])
def shortest_path():
    data = request.get_json(force=True)
    from_city = data["from"]
    to_city   = data["to"]
    weight    = data.get("weight", "time_minutes")

    if weight not in ("time_minutes", "distance"):
        return jsonify({"error": "weight must be time_minutes or distance"}), 400

    query = f"""
        MATCH (from:City {{name: $from}}), (to:City {{name: $to}})
        CALL apoc.algo.dijkstra(from, to, 'ROAD>', '{weight}')
        YIELD path, weight AS total_weight
        RETURN [n IN nodes(path) | n.name] AS cities,
               total_weight,
               length(path) AS hops
    """

    start = time.monotonic()
    with neo4j_driver.session() as session:
        record = session.run(query, from=from_city, to=to_city).single()
    elapsed_ms = (time.monotonic() - start) * 1000

    if record is None:
        return jsonify({"error": "No path found", "elapsed_ms": elapsed_ms}), 404

    return jsonify({
        "path": record["cities"],
        "total_weight": record["total_weight"],
        "hops": record["hops"],
        "elapsed_ms": round(elapsed_ms, 2),
        "engine": "neo4j",
        "algorithm": "apoc.algo.dijkstra",
    })


# ---------------------------------------------------------------------------
# Цепочка поставок
# ---------------------------------------------------------------------------

@app.route("/api/v1/graph/supply-chain", methods=["POST"])
def supply_chain():
    data = request.get_json(force=True)
    code = data["product_code"]
    max_depth = int(data.get("max_depth", 5))

    if not (1 <= max_depth <= 10):
        return jsonify({"error": "max_depth must be 1..10"}), 400

    query = f"""
        MATCH path = (p:Product {{code: $code}})<-[:STOCKS*1..{max_depth}]-(w:Warehouse)
        MATCH (w)-[:LOCATED_IN]->(c:City)
        RETURN c.name AS city,
               w.name AS warehouse,
               length(path) AS depth,
               [r IN relationships(path) WHERE type(r) = 'STOCKS' | r.quantity] AS quantities
        ORDER BY depth
    """

    start = time.monotonic()
    with neo4j_driver.session() as session:
        records = [dict(r) for r in session.run(query, code=code)]
    elapsed_ms = (time.monotonic() - start) * 1000

    return jsonify({
        "supply_chain": records,
        "elapsed_ms": round(elapsed_ms, 2),
        "engine": "neo4j",
    })


# ---------------------------------------------------------------------------
# Рекомендации
# ---------------------------------------------------------------------------

@app.route("/api/v1/graph/recommendations", methods=["POST"])
def recommendations():
    data = request.get_json(force=True)
    code = data["product_code"]
    limit = int(data.get("limit", 5))

    if not (1 <= limit <= 100):
        return jsonify({"error": "limit must be 1..100"}), 400

    query = """
        MATCH (p:Product {code: $code})-[bw:BOUGHT_WITH]->(recommended:Product)
        RETURN recommended.code AS code,
               recommended.name AS name,
               bw.frequency AS frequency
        ORDER BY bw.frequency DESC
        LIMIT $limit
    """

    start = time.monotonic()
    with neo4j_driver.session() as session:
        records = [dict(r) for r in session.run(query, code=code, limit=limit)]
    elapsed_ms = (time.monotonic() - start) * 1000

    return jsonify({
        "recommendations": records,
        "elapsed_ms": round(elapsed_ms, 2),
        "engine": "neo4j",
    })


# ---------------------------------------------------------------------------
# Обновление графа — MERGE + SET r += props
# ---------------------------------------------------------------------------

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
            SET r.distance     = $distance,
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


# ---------------------------------------------------------------------------
# SQL-бенчмарк
# ---------------------------------------------------------------------------

@app.route("/api/v1/benchmark/sql", methods=["POST"])
def benchmark_sql():
    data = request.get_json(force=True)
    from_city = data["from"]
    to_city   = data["to"]

    query = """
        WITH from_id AS (SELECT id FROM cities WHERE name = %s),
             to_id   AS (SELECT id FROM cities WHERE name = %s)
        SELECT * FROM shortest_path_sql(
            (SELECT id FROM from_id),
            (SELECT id FROM to_id),
            10, 1000000
        )
    """

    start = time.monotonic()
    conn = get_pg_connection()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(query, (from_city, to_city))
            record = cur.fetchone()
    finally:
        conn.close()
    elapsed_ms = (time.monotonic() - start) * 1000

    if record is None:
        return jsonify({"error": "No path found", "elapsed_ms": elapsed_ms}), 404

    return jsonify({
        "path": record["path"],
        "total_weight": record["total_weight"],
        "hops": record["hops"],
        "elapsed_ms": round(elapsed_ms, 2),
        "engine": "postgresql",
        "algorithm": "recursive_cte_with_pruning",
    })


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.route("/health", methods=["GET"])
def health():
    neo4j_ok = pg_ok = False

    try:
        with neo4j_driver.session() as s:
            s.run("RETURN 1")
        neo4j_ok = True
    except Exception as e:
        logger.error("Neo4j health check failed: %s", e)

    try:
        conn = get_pg_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
        conn.close()
        pg_ok = True
    except Exception as e:
        logger.error("PostgreSQL health check failed: %s", e)

    status = "ok" if (neo4j_ok and pg_ok) else "degraded"
    return jsonify({"status": status, "neo4j": neo4j_ok, "postgresql": pg_ok}), \
           200 if status == "ok" else 503


if __name__ == "__main__":
    logger.info("Starting proxy on %s:%s", config.HOST, config.PORT)
    app.run(host=config.HOST, port=config.PORT, debug=False)
