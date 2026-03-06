"""
s2_basic_analysis.py
Stage 2: Basic graph analysis — statistics, degree analysis, path analysis, centrality.

Mirrors: 02_basic_analysis.R and 04a_cycle_detection.R

Input:  data/{Exposure}_{Outcome}/s1_graph/graph.graphml
Output: data/{Exposure}_{Outcome}/s2_semantic/
          - node_degrees.csv
          - node_centrality_and_cycles.csv
          - strongly_connected_components.csv
          - graph_statistics.csv
"""

import csv
from pathlib import Path

import networkx as nx

from .config import SEMANTIC_CONFIG
from .utils import (
    get_s1_graph_dir,
    get_s2_semantic_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


def load_graph(exposure: str, outcome: str) -> nx.DiGraph:
    """Load the GraphML graph saved by Stage 1."""
    graphml_path = get_s1_graph_dir(exposure, outcome) / "graph.graphml"
    if not graphml_path.exists():
        raise FileNotFoundError(f"Stage 1 graph not found: {graphml_path}")
    return nx.read_graphml(str(graphml_path))


def run_stage2(exposure: str, outcome: str) -> dict:
    """Execute Stage 2: basic graph analysis."""
    print_header("Basic Graph Analysis (Stage 2)", exposure, outcome)

    G = load_graph(exposure, outcome)
    output_dir = get_s2_semantic_dir(exposure, outcome)
    ensure_dir(output_dir)

    n_nodes = G.number_of_nodes()
    n_edges = G.number_of_edges()
    density = nx.density(G)
    is_weakly_conn = nx.is_weakly_connected(G)
    is_dag = nx.is_directed_acyclic_graph(G)

    print(f"Nodes: {n_nodes}")
    print(f"Edges: {n_edges}")
    print(f"Density: {density:.4f}")
    print(f"Weakly connected: {is_weakly_conn}")
    print(f"Is DAG: {is_dag}")

    # --- Degree analysis ---
    in_deg = dict(G.in_degree())
    out_deg = dict(G.out_degree())
    total_deg = {n: in_deg[n] + out_deg[n] for n in G.nodes()}

    degrees_path = output_dir / "node_degrees.csv"
    with open(degrees_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "node_type", "in_degree", "out_degree", "total_degree"])
        for node in sorted(G.nodes(), key=lambda n: -total_deg[n]):
            ntype = G.nodes[node].get("node_type", "regular")
            w.writerow([node, ntype, in_deg[node], out_deg[node], total_deg[node]])
    print(f"Saved node degrees to: {degrees_path}")

    # --- SCC analysis ---
    sccs = list(nx.strongly_connected_components(G))
    large_sccs = [s for s in sccs if len(s) > 1]
    nodes_in_cycles = set().union(*large_sccs) if large_sccs else set()

    print(f"\nSCCs with cycles: {len(large_sccs)}")
    print(f"Nodes in cycles: {len(nodes_in_cycles)} ({100*len(nodes_in_cycles)/max(n_nodes,1):.1f}%)")

    scc_path = output_dir / "strongly_connected_components.csv"
    scc_map = {}
    for idx, scc in enumerate(sccs):
        for node in scc:
            scc_map[node] = (idx, len(scc))
    with open(scc_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "scc_id", "scc_size"])
        for node in sorted(scc_map, key=lambda n: -scc_map[n][1]):
            w.writerow([node, scc_map[node][0], scc_map[node][1]])
    print(f"Saved SCC data to: {scc_path}")

    # --- Centrality metrics ---
    print("\nComputing centrality metrics...")
    betweenness = nx.betweenness_centrality(G)
    pagerank = nx.pagerank(G)

    cent_path = output_dir / "node_centrality_and_cycles.csv"
    with open(cent_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "node_type", "in_degree", "out_degree", "total_degree",
                     "betweenness", "pagerank", "in_cycle", "scc_id", "scc_size"])
        for node in sorted(G.nodes(), key=lambda n: -betweenness[n]):
            ntype = G.nodes[node].get("node_type", "regular")
            sid, ssz = scc_map[node]
            w.writerow([node, ntype, in_deg[node], out_deg[node], total_deg[node],
                         f"{betweenness[node]:.6f}", f"{pagerank[node]:.6f}",
                         node in nodes_in_cycles, sid, ssz])
    print(f"Saved centrality data to: {cent_path}")

    # --- Graph statistics summary ---
    stats_path = output_dir / "graph_statistics.csv"
    with open(stats_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["metric", "value"])
        for k, v in [("nodes", n_nodes), ("edges", n_edges), ("density", f"{density:.6f}"),
                      ("weakly_connected", is_weakly_conn), ("is_dag", is_dag),
                      ("num_sccs_with_cycles", len(large_sccs)),
                      ("nodes_in_cycles", len(nodes_in_cycles)),
                      ("exposure", exposure), ("outcome", outcome)]:
            w.writerow([k, v])
    print(f"Saved graph statistics to: {stats_path}")

    # --- Path analysis (exposure → outcome) ---
    if exposure in G and outcome in G:
        has_direct = G.has_edge(exposure, outcome)
        try:
            shortest = nx.shortest_path(G, exposure, outcome)
            print(f"\nDirect edge {exposure}→{outcome}: {has_direct}")
            print(f"Shortest path length: {len(shortest)} nodes")
            print(f"Shortest path: {' -> '.join(shortest)}")
        except nx.NetworkXNoPath:
            print(f"\nNo directed path from {exposure} to {outcome}")

    print_complete("Basic Graph Analysis (Stage 2)")
    return {"n_nodes": n_nodes, "n_edges": n_edges, "is_dag": is_dag,
            "nodes_in_cycles": len(nodes_in_cycles), "num_sccs_with_cycles": len(large_sccs)}


if __name__ == "__main__":
    args = parse_args("Stage 2: Basic graph analysis")
    run_stage2(args.exposure, args.outcome)

