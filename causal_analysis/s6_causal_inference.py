"""
s6_causal_inference.py
Stage 6: Formal causal inference — identify Adjustment Sets (Backdoor Criterion)
and Instrumental Variables (IVs) on the DAG.

Requires the reduced graph to be a DAG (run Stages 4-5 first).
Uses NetworkX graph-theoretic operations to implement:
  - Backdoor Criterion adjustment sets
  - Instrumental Variable identification

Input:  data/{Exposure}_{Outcome}/s4_node_removal/reduced_graph.graphml
Output: data/{Exposure}_{Outcome}/s5_post_removal/
          - adjustment_sets.csv
          - instrumental_variables.csv
          - causal_inference_summary.csv
"""

import csv
from pathlib import Path

import networkx as nx

from .utils import (
    get_s4_node_removal_dir,
    get_s5_post_removal_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)


def load_dag(exposure: str, outcome: str) -> nx.DiGraph:
    path = get_s4_node_removal_dir(exposure, outcome) / "reduced_graph.graphml"
    if not path.exists():
        raise FileNotFoundError(f"Reduced graph not found: {path}. Run Stage 4 first.")
    G = nx.read_graphml(str(path))
    if not nx.is_directed_acyclic_graph(G):
        raise ValueError(
            "The reduced graph is NOT a DAG. Cannot apply formal causal inference. "
            "Review Stage 5 output and remove additional nodes."
        )
    return G


def _ancestors(G: nx.DiGraph, node: str) -> set[str]:
    """All ancestors of `node` in DAG G."""
    return nx.ancestors(G, node)


def _descendants(G: nx.DiGraph, node: str) -> set[str]:
    return nx.descendants(G, node)


def find_adjustment_sets(G: nx.DiGraph, exposure: str, outcome: str) -> list[str]:
    """
    Backdoor criterion: find the minimal sufficient adjustment set.
    A valid adjustment set Z satisfies:
      1. No node in Z is a descendant of exposure
      2. Z blocks every backdoor path from exposure to outcome
    We return all common ancestors of exposure and outcome (minus
    descendants of exposure) as the adjustment set.
    """
    if exposure not in G or outcome not in G:
        return []

    anc_exp = _ancestors(G, exposure)
    anc_out = _ancestors(G, outcome)
    desc_exp = _descendants(G, exposure)

    # Nodes that are ancestors of both exposure and outcome (confounders)
    shared = (anc_exp & anc_out) - {exposure, outcome}

    # Also include parents of exposure that are ancestors of outcome
    parents_exp = set(G.predecessors(exposure))
    parent_confounders = parents_exp & anc_out

    # Combine and exclude descendants of exposure (to avoid conditioning on mediators)
    adjustment = (shared | parent_confounders) - desc_exp - {exposure, outcome}
    return sorted(adjustment)


def find_instrumental_variables(G: nx.DiGraph, exposure: str, outcome: str) -> list[str]:
    """
    Instrumental Variable (IV) identification.
    A valid instrument Z must satisfy:
      1. Z has a directed path to exposure  (relevance)
      2. Z has NO directed path to outcome except through exposure  (exclusion)
      3. Z shares no common cause with outcome  (independence / exogeneity)
    We approximate condition 3 by checking Z is NOT an ancestor of outcome
    when exposure is removed from the graph.
    """
    if exposure not in G or outcome not in G:
        return []

    # Build graph without exposure to check exclusion
    G_no_exp = G.copy()
    G_no_exp.remove_node(exposure)
    anc_out_no_exp = nx.ancestors(G_no_exp, outcome) if outcome in G_no_exp else set()

    parents_exp = set(G.predecessors(exposure))
    instruments = []
    for z in parents_exp:
        if z == outcome:
            continue
        # Exclusion: z should NOT reach outcome without going through exposure
        if z in anc_out_no_exp:
            continue
        instruments.append(z)

    return sorted(instruments)


def run_stage6(exposure: str, outcome: str) -> dict:
    """Execute Stage 6: causal inference on the DAG."""
    print_header("Causal Inference (Stage 6)", exposure, outcome)

    G = load_dag(exposure, outcome)
    output_dir = get_s5_post_removal_dir(exposure, outcome)
    ensure_dir(output_dir)

    print(f"DAG: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")
    print(f"Exposure: {exposure}")
    print(f"Outcome:  {outcome}\n")

    # --- Adjustment Sets ---
    adj_set = find_adjustment_sets(G, exposure, outcome)
    print(f"Adjustment Set ({len(adj_set)} nodes):")
    for node in adj_set:
        print(f"  - {node}")
    if not adj_set:
        print("  (empty — no confounders identified)")

    adj_path = output_dir / "adjustment_sets.csv"
    with open(adj_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "role"])
        for node in adj_set:
            w.writerow([node, "confounder"])
    print(f"Saved adjustment sets to: {adj_path}")

    # --- Instrumental Variables ---
    instruments = find_instrumental_variables(G, exposure, outcome)
    print(f"\nInstrumental Variables ({len(instruments)} candidates):")
    for node in instruments:
        print(f"  - {node}")
    if not instruments:
        print("  (none found)")

    iv_path = output_dir / "instrumental_variables.csv"
    with open(iv_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["node", "role"])
        for node in instruments:
            w.writerow([node, "instrument"])
    print(f"Saved instrumental variables to: {iv_path}")

    # --- Summary ---
    summary_path = output_dir / "causal_inference_summary.csv"
    with open(summary_path, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["metric", "value"])
        w.writerow(["exposure", exposure])
        w.writerow(["outcome", outcome])
        w.writerow(["dag_nodes", G.number_of_nodes()])
        w.writerow(["dag_edges", G.number_of_edges()])
        w.writerow(["adjustment_set_size", len(adj_set)])
        w.writerow(["adjustment_set", "; ".join(adj_set) if adj_set else "EMPTY"])
        w.writerow(["instrumental_variables_count", len(instruments)])
        w.writerow(["instrumental_variables", "; ".join(instruments) if instruments else "NONE"])
    print(f"Saved summary to: {summary_path}")

    print_complete("Causal Inference (Stage 6)")
    return {"adjustment_set": adj_set, "instruments": instruments}


if __name__ == "__main__":
    args = parse_args("Stage 6: Causal inference")
    run_stage6(args.exposure, args.outcome)

