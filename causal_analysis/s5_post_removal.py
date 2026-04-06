"""
s5_post_removal.py
Stage 5: Post-removal cycle analysis — enumerate remaining cycles, rank
problematic nodes, report cycle-length distribution.

Mirrors: 06_post_node_removal_analysis.R

Input:  data/{Exposure}_{Outcome}/s4_node_removal/reduced_graph.graphml
Output: data/{Exposure}_{Outcome}/s5_post_removal/
          - top_nodes_by_cycles.csv
          - all_node_cycle_participation.csv
          - cycle_length_distribution.csv
          - analysis_summary.csv
"""

import csv
import time
from collections import Counter
from pathlib import Path

import networkx as nx

from .config import CYCLE_CONFIG, NODE_REMOVAL_CONFIG
from .utils import (
    get_s1_graph_dir,
    get_s4_node_removal_dir,
    get_s5_post_removal_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


def load_reduced_graph(exposure: str, outcome: str) -> nx.DiGraph:
    path = get_s4_node_removal_dir(exposure, outcome) / "reduced_graph.graphml"
    if not path.exists():
        raise FileNotFoundError(f"Reduced graph not found: {path}. Run Stage 4 first.")
    return nx.read_graphml(str(path))


def load_original_graph(exposure: str, outcome: str) -> nx.DiGraph:
    path = get_s1_graph_dir(exposure, outcome) / "graph.graphml"
    return nx.read_graphml(str(path))


def run_stage5(exposure: str, outcome: str) -> dict:
    """Execute Stage 5: post-removal cycle analysis."""
    print_header("Post Node Removal — Cycle Analysis (Stage 5)", exposure, outcome)

    reduced = load_reduced_graph(exposure, outcome)
    original = load_original_graph(exposure, outcome)
    output_dir = get_s5_post_removal_dir(exposure, outcome)
    ensure_dir(output_dir)

    top_n = NODE_REMOVAL_CONFIG["top_n_nodes_report"]

    # Load removed-nodes list
    removed_path = get_s4_node_removal_dir(exposure, outcome) / "removed_generic_nodes.txt"
    removed_nodes = removed_path.read_text().strip().split("\n") if removed_path.exists() else []

    print(f"Original graph: {original.number_of_nodes()} nodes, {original.number_of_edges()} edges")
    print(f"Reduced graph:  {reduced.number_of_nodes()} nodes, {reduced.number_of_edges()} edges")
    print(f"Nodes removed:  {len(removed_nodes)} ({', '.join(removed_nodes)})")

    # --- SCC detection ---
    sccs = [s for s in nx.strongly_connected_components(reduced) if len(s) > 1]
    print(f"\nSCCs with cycles: {len(sccs)}")
    for i, scc in enumerate(sccs):
        nodes_preview = list(scc)[:10]
        extra = f" ... and {len(scc)-10} more" if len(scc) > 10 else ""
        print(f"  SCC {i}: {len(scc)} nodes — {', '.join(nodes_preview)}{extra}")

    if not sccs:
        print("\nNo cycles — the reduced graph is a DAG!")

    # --- Cycle enumeration with participation ---
    node_counts: Counter = Counter()
    length_dist: Counter = Counter()
    total_cycles = 0
    max_enumerate = CYCLE_CONFIG.get("max_cycles_to_enumerate", 1_000_000)
    capped = False

    if sccs:
        print(f"\nEnumerating cycles in the reduced graph (cap at {max_enumerate:,})...")
        t0 = time.time()
        for cycle in nx.simple_cycles(reduced):
            # Check limit BEFORE processing to avoid overcounting
            if total_cycles >= max_enumerate:
                print(f"  Stopped at {total_cycles:,} cycles (cap reached, {time.time()-t0:.1f}s)")
                capped = True
                break

            total_cycles += 1
            length_dist[len(cycle)] += 1
            for node in cycle:
                node_counts[node] += 1
            if total_cycles % 100_000 == 0:
                print(f"  {total_cycles:,} cycles found ({time.time()-t0:.1f}s)...")

        if capped:
            print(f"Total cycles: {total_cycles:,} (CAPPED at limit, {time.time()-t0:.1f}s)")
        else:
            print(f"Total cycles: {total_cycles:,} ({time.time()-t0:.1f}s)")

    # --- Save node participation ---
    all_part_path = output_dir / "all_node_cycle_participation.csv"
    with open(all_part_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "num_cycles"])
        for node, cnt in node_counts.most_common():
            w.writerow([node, cnt])

    top_nodes = node_counts.most_common(top_n)
    top_path = output_dir / "top_nodes_by_cycles.csv"
    with open(top_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "num_cycles"])
        for node, cnt in top_nodes:
            w.writerow([node, cnt])

    # --- Save cycle length distribution ---
    dist_path = output_dir / "cycle_length_distribution.csv"
    with open(dist_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["cycle_length", "count"])
        for length in sorted(length_dist):
            w.writerow([length, length_dist[length]])

    # --- Save summary ---
    summary_path = output_dir / "analysis_summary.csv"
    with open(summary_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["metric", "value"])
        for k, v in [
            ("original_nodes", original.number_of_nodes()),
            ("original_edges", original.number_of_edges()),
            ("reduced_nodes", reduced.number_of_nodes()),
            ("reduced_edges", reduced.number_of_edges()),
            ("nodes_removed", len(removed_nodes)),
            ("total_cycles", total_cycles),
            ("nodes_in_cycles", len(node_counts)),
            ("sccs_with_cycles", len(sccs)),
            ("is_dag", "YES" if total_cycles == 0 else "NO"),
        ]:
            w.writerow([k, v])

    # --- Print top problematic nodes ---
    if top_nodes:
        print(f"\nTop {len(top_nodes)} problematic nodes (still in cycles):")
        for rank, (node, cnt) in enumerate(top_nodes, 1):
            print(f"  {rank:3d}. {node:30s}  {cnt:,} cycles")
        print("\nConsider adding these to GENERIC_NODES for a second pruning pass.")

    print(f"\nSaved: {all_part_path.name}, {top_path.name}, {dist_path.name}, {summary_path.name}")
    print_complete("Post Node Removal — Cycle Analysis (Stage 5)")
    return {"total_cycles": total_cycles, "is_dag": total_cycles == 0,
            "nodes_in_cycles": len(node_counts)}


if __name__ == "__main__":
    args = parse_args("Stage 5: Post-removal cycle analysis")
    run_stage5(args.exposure, args.outcome)

