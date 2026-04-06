"""
s4_node_removal.py
Stage 4: Analyze impact of removing generic/non-specific nodes on cycle reduction.

Mirrors: 05_node_removal_impact.R

Input:  data/{Exposure}_{Outcome}/s1_graph/graph.graphml
Output: data/{Exposure}_{Outcome}/s4_node_removal/
          - node_removal_individual_impact.csv
          - node_removal_summary.csv
          - reduced_graph.graphml
          - removed_generic_nodes.txt
"""

import csv
import time
from pathlib import Path

import networkx as nx

from .config import GENERIC_NODES, CYCLE_CONFIG
from .utils import (
    get_s1_graph_dir,
    get_s4_node_removal_dir,
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


def count_cycles(G: nx.DiGraph) -> tuple[int, bool]:
    """Count total simple cycles via SCC-scoped enumeration.

    Stops at max_cycles_to_enumerate (from config) to avoid runaway computation.
    Returns (count, capped) where capped=True if the limit was hit.
    """
    max_enumerate = CYCLE_CONFIG.get("max_cycles_to_enumerate", 1_000_000)
    total = 0
    capped = False
    for scc in nx.strongly_connected_components(G):
        if len(scc) > 1:
            sub = G.subgraph(scc)
            for _ in nx.simple_cycles(sub):
                total += 1
                if total >= max_enumerate:
                    capped = True
                    break
        if capped:
            break
    return total, capped


def get_scc_stats(G: nx.DiGraph) -> dict:
    sccs = [s for s in nx.strongly_connected_components(G) if len(s) > 1]
    nodes_in = sum(len(s) for s in sccs)
    largest = max((len(s) for s in sccs), default=0)
    return {"num_sccs": len(sccs), "nodes_in_sccs": nodes_in, "largest_scc": largest}


def run_stage4(exposure: str, outcome: str) -> dict:
    """Execute Stage 4: node removal impact analysis."""
    print_header("Node Removal Impact Analysis (Stage 4)", exposure, outcome)

    G = load_graph(exposure, outcome)
    output_dir = get_s4_node_removal_dir(exposure, outcome)
    ensure_dir(output_dir)

    print(f"Original graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")

    # --- Baseline ---
    baseline_stats = get_scc_stats(G)
    print(f"Baseline SCCs with cycles: {baseline_stats['num_sccs']}")
    print(f"Nodes in SCCs: {baseline_stats['nodes_in_sccs']}")

    print("\nCounting baseline cycles...")
    t0 = time.time()
    baseline_cycles, baseline_capped = count_cycles(G)
    cap_note = " (CAPPED)" if baseline_capped else ""
    print(f"Baseline cycles: {baseline_cycles:,}{cap_note}  ({time.time()-t0:.1f}s)")

    # --- Individual removal ---
    existing = [n for n in GENERIC_NODES if n in G]
    missing = [n for n in GENERIC_NODES if n not in G]
    print(f"\nGeneric nodes in graph: {len(existing)}")
    if missing:
        print(f"Generic nodes NOT in graph: {', '.join(missing)}")

    individual_rows = []
    for node in existing:
        H = G.copy()
        H.remove_node(node)
        cycles_after, after_capped = count_cycles(H)
        removed = baseline_cycles - cycles_after
        pct = (removed / baseline_cycles * 100) if baseline_cycles else 0
        scc_s = get_scc_stats(H)
        cap_note = " (capped)" if after_capped else ""
        print(f"  Remove '{node}': {cycles_after:,}{cap_note} cycles (-{removed:,}, -{pct:.1f}%)")
        individual_rows.append({
            "node": node, "original_cycles": baseline_cycles,
            "remaining_cycles": cycles_after, "cycles_removed": removed,
            "percent_reduction": round(pct, 2),
            "remaining_sccs": scc_s["num_sccs"], "largest_scc_after": scc_s["largest_scc"],
        })
    individual_rows.sort(key=lambda r: -r["percent_reduction"])

    # --- Combined removal ---
    print(f"\nRemoving all {len(existing)} generic nodes together...")
    reduced = G.copy()
    for node in existing:
        if node in reduced:
            reduced.remove_node(node)

    print(f"Reduced graph: {reduced.number_of_nodes()} nodes, {reduced.number_of_edges()} edges")
    combined_stats = get_scc_stats(reduced)
    t0 = time.time()
    combined_cycles, combined_capped = count_cycles(reduced)
    combined_removed = baseline_cycles - combined_cycles
    combined_pct = (combined_removed / baseline_cycles * 100) if baseline_cycles else 0
    is_dag = nx.is_directed_acyclic_graph(reduced)
    cap_note = " (CAPPED)" if combined_capped else ""
    print(f"Cycles after combined removal: {combined_cycles:,}{cap_note} (-{combined_pct:.1f}%)")
    print(f"Is DAG: {is_dag}")

    # --- Save results ---
    ind_path = output_dir / "node_removal_individual_impact.csv"
    with open(ind_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(individual_rows[0].keys()) if individual_rows else [])
        w.writeheader()
        w.writerows(individual_rows)

    summary_path = output_dir / "node_removal_summary.csv"
    with open(summary_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["analysis_type", "nodes_removed", "total_nodes", "total_edges",
                     "num_cycles", "num_sccs", "largest_scc", "is_dag"])
        w.writerow(["Baseline", 0, G.number_of_nodes(), G.number_of_edges(),
                     baseline_cycles, baseline_stats["num_sccs"], baseline_stats["largest_scc"], False])
        w.writerow(["Combined Removal", len(existing), reduced.number_of_nodes(),
                     reduced.number_of_edges(), combined_cycles,
                     combined_stats["num_sccs"], combined_stats["largest_scc"], is_dag])

    graphml_path = output_dir / "reduced_graph.graphml"
    nx.write_graphml(reduced, str(graphml_path))

    removed_path = output_dir / "removed_generic_nodes.txt"
    removed_path.write_text("\n".join(existing) + "\n")

    print(f"\nSaved individual impact: {ind_path}")
    print(f"Saved summary: {summary_path}")
    print(f"Saved reduced graph: {graphml_path}")
    print(f"Saved removed nodes list: {removed_path}")

    print_complete("Node Removal Impact Analysis (Stage 4)")
    return {"baseline_cycles": baseline_cycles, "combined_cycles": combined_cycles,
            "is_dag": is_dag, "nodes_removed": len(existing)}


if __name__ == "__main__":
    args = parse_args("Stage 4: Node removal impact analysis")
    run_stage4(args.exposure, args.outcome)

