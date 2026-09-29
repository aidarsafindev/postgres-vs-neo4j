"""
Сравнительный бенчмарк: SQL vs Cypher.
Запускает один и тот же запрос через HTTP-прокси и замеряет время.
"""

import csv
import os
import time

import requests

PROXY_URL = os.getenv("PROXY_URL", "http://proxy:8080")
ITERATIONS = int(os.getenv("ITERATIONS", "20"))
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "/app/output")

TEST_CASES = [
    {"from": "Москва", "to": "Новосибирск"},
    {"from": "Москва", "to": "Екатеринбург"},
    {"from": "Санкт-Петербург", "to": "Казань"},
]


def run_endpoint(endpoint, payload):
    times = []
    for _ in range(ITERATIONS):
        start = time.monotonic()
        resp = requests.post(f"{PROXY_URL}{endpoint}", json=payload)
        elapsed_ms = (time.monotonic() - start) * 1000
        if resp.status_code == 200:
            times.append(elapsed_ms)
    if not times:
        return None
    return {
        "avg": sum(times) / len(times),
        "min": min(times),
        "max": max(times),
        "n": len(times),
    }


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    results = []

    print("=" * 70)
    print(f"SQL vs Neo4j Benchmark ({ITERATIONS} iterations)")
    print("=" * 70)

    for case in TEST_CASES:
        print(f"\n{case['from']} → {case['to']}")
        payload = {"from": case["from"], "to": case["to"]}

        n4j = run_endpoint("/api/v1/graph/shortest-path", payload)
        sql = run_endpoint("/api/v1/benchmark/sql", payload)

        if n4j and sql:
            speedup = sql["avg"] / n4j["avg"] if n4j["avg"] > 0 else 0
            print(f"  Neo4j: {n4j['avg']:.2f} ms (min {n4j['min']:.2f}, max {n4j['max']:.2f})")
            print(f"  SQL:   {sql['avg']:.2f} ms (min {sql['min']:.2f}, max {sql['max']:.2f})")
            print(f"  Speedup: {speedup:.1f}x")

            results.append({
                "from": case["from"],
                "to": case["to"],
                "neo4j_avg_ms": round(n4j["avg"], 2),
                "sql_avg_ms": round(sql["avg"], 2),
                "speedup": round(speedup, 2),
            })

    csv_path = os.path.join(OUTPUT_DIR, "benchmark.csv")
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["from", "to", "neo4j_avg_ms", "sql_avg_ms", "speedup"])
        writer.writeheader()
        writer.writerows(results)

    print(f"\nРезультаты: {csv_path}")


if __name__ == "__main__":
    main()
