"""
Строит log-scale график «время vs объём» для слайда.
"""

import csv
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

OUTPUT_DIR = os.getenv("OUTPUT_DIR", "/app/output")

# Данные для графика — заполняются после прогонов на разных объёмах
# Формат: (объём, naive_sql_ms, optimized_sql_ms, pgrouting_ms, neo4j_ms)
DATA = [
    (100,      2000,  50,  5,   1),
    (1000,     15000, 500, 20,  2),
    (10000,    180000, 5000, 200, 3),
    (100000,   2700000, 180000, 800, 5),
]


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    sizes      = [d[0] for d in DATA]
    naive_sql  = [d[1] for d in DATA]
    opt_sql    = [d[2] for d in DATA]
    pgrouting  = [d[3] for d in DATA]
    neo4j      = [d[4] for d in DATA]

    plt.figure(figsize=(10, 6))
    plt.plot(sizes, naive_sql, "o-", label="SQL: наивный CTE", color="#d62728", linewidth=2)
    plt.plot(sizes, opt_sql,   "s-", label="SQL: + pruning", color="#ff7f0e", linewidth=2)
    plt.plot(sizes, pgrouting, "^-", label="pgRouting (Dijkstra)", color="#2ca02c", linewidth=2)
    plt.plot(sizes, neo4j,     "D-", label="Neo4j (APOC Dijkstra)", color="#1f77b4", linewidth=2)

    plt.xscale("log")
    plt.yscale("log")
    plt.xlabel("Объём графа (городов)", fontsize=12)
    plt.ylabel("Время выполнения, мс (log scale)", fontsize=12)
    plt.title("SQL vs Neo4j: кратчайший путь", fontsize=14, fontweight="bold")
    plt.grid(True, which="both", alpha=0.3)
    plt.legend(fontsize=11, loc="upper left")
    plt.tight_layout()

    out = os.path.join(OUTPUT_DIR, "benchmark.png")
    plt.savefig(out, dpi=150)
    print(f"График: {out}")


if __name__ == "__main__":
    main()
