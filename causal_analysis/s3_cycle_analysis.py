"""
s3_cycle_analysis.py
Stage 3: Cycle extraction, node participation counting, and cycle length distribution.

Mirrors: 04b_extract_analyze_cycle.R

Input:  data/{Exposure}_{Outcome}/s1_graph/graph.graphml
Output: data/{Exposure}_{Outcome}/s3_cycles/
          - node_cycle_participation.csv
          - cycle_summary.csv
          - cycle_length_distribution.csv
"""

import csv
import time
from collections import Counter, defaultdict
from pathlib import Path

import networkx as nx

from .config import CYCLE_CONFIG
from .utils import (
    get_s1_graph_dir,
    get_s3_cycles_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


def load_graph(exposure: str, outcome: str) -> nx.DiGraph:
    graphml_path = get_s1_graph_dir(exposure, outcome) / "graph.graphml"
    if not graphml_path.exists():
        raise FileNotFoundError(f"Stage 1 graph not found: {graphml_path}")
    return nx.read_graphml(str(graphml_path))


def count_cycles_with_participation(G: nx.DiGraph, max_sample: int = 50):
    """
    Enumerate simple cycles using SCC-scoped Johnson's algorithm.
    Only searches within strongly connected components (size > 1),
    skipping acyclic parts of the graph entirely.
    Track per-node participation counts and cycle length distribution.
    Sample up to max_sample cycles for detailed reporting.
    """
    node_counts: Counter = Counter()
    length_dist: Counter = Counter()
    sampled_cycles: list[list[str]] = []
    total = 0

    sccs = [s for s in nx.strongly_connected_components(G) if len(s) > 1]
    start = time.time()
    for scc in sccs:
        sub = G.subgraph(scc)
        for cycle in nx.simple_cycles(sub):
            total += 1
            length_dist[len(cycle)] += 1
            for node in cycle:
                node_counts[node] += 1
            if len(sampled_cycles) < max_sample:
                sampled_cycles.append(cycle)
            if total % 100_000 == 0:
                elapsed = time.time() - start
                print(f"  Found {total:,} cycles so far ({elapsed:.1f}s)...")

    return total, node_counts, length_dist, sampled_cycles


def run_stage3(exposure: str, outcome: str) -> dict:
    """Execute Stage 3: cycle extraction and participation analysis."""
    print_header("Cycle Extraction & Analysis (Stage 3)", exposure, outcome)

    G = load_graph(exposure, outcome)
    output_dir = get_s3_cycles_dir(exposure, outcome)
    ensure_dir(output_dir)

    max_sample = CYCLE_CONFIG["max_cycles_to_save"]

    # --- SCC overview ---
    sccs = [s for s in nx.strongly_connected_components(G) if len(s) > 1]
    print(f"SCCs with cycles: {len(sccs)}")
    for i, scc in enumerate(sccs):
        print(f"  SCC {i}: {len(scc)} nodes")

    if not sccs:
        print("Graph is already a DAG — no cycles to extract.")
        # Write empty CSVs for downstream compatibility
        for fname, header in [
            ("node_cycle_participation.csv", ["node", "num_cycles"]),
            ("cycle_summary.csv", ["cycle_id", "cycle_length", "nodes"]),
            ("cycle_length_distribution.csv", ["cycle_length", "count"]),
        ]:
            with open(output_dir / fname, "w", newline="") as f:
                csv.writer(f).writerow(header)
        print_complete("Cycle Extraction & Analysis (Stage 3)")
        return {"total_cycles": 0}

    # --- Enumerate cycles ---
    print(f"\nEnumerating all simple cycles (sampling up to {max_sample})...")
    t0 = time.time()
    total, node_counts, length_dist, sampled = count_cycles_with_participation(G, max_sample)
    elapsed = time.time() - t0
    print(f"Total cycles found: {total:,}  ({elapsed:.1f}s)")

    # --- Save node participation ---
    part_path = output_dir / "node_cycle_participation.csv"
    with open(part_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "num_cycles"])
        for node, cnt in node_counts.most_common():
            w.writerow([node, cnt])
    print(f"Saved node participation to: {part_path}")

    # --- Save cycle summary (sampled) ---
    summary_path = output_dir / "cycle_summary.csv"
    with open(summary_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cycle_id", "cycle_length", "nodes"])
        for idx, cycle in enumerate(sampled, 1):
            w.writerow([idx, len(cycle), " -> ".join(cycle)])
    print(f"Saved {len(sampled)} sampled cycles to: {summary_path}")

    # --- Save cycle length distribution ---
    dist_path = output_dir / "cycle_length_distribution.csv"
    with open(dist_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cycle_length", "count"])
        for length in sorted(length_dist):
            w.writerow([length, length_dist[length]])
    print(f"Saved cycle length distribution to: {dist_path}")

    # --- Top nodes report ---
    top_n = min(20, len(node_counts))
    print(f"\nTop {top_n} nodes by cycle participation:")
    for rank, (node, cnt) in enumerate(node_counts.most_common(top_n), 1):
        print(f"  {rank:3d}. {node:30s}  {cnt:,} cycles")

    print_complete("Cycle Extraction & Analysis (Stage 3)")
    return {"total_cycles": total, "nodes_in_cycles": len(node_counts)}


if __name__ == "__main__":
    args = parse_args("Stage 3: Cycle extraction and analysis")
    run_stage3(args.exposure, args.outcome)

