#!/usr/bin/env python3
"""
run_bias_analysis.py
Standalone CLI script to run M-bias and Butterfly bias analysis on a reduced graph.

Usage:
    python run_bias_analysis.py <graph_path> <exposure> <outcome> [--output-dir DIR]

Example:
    python run_bias_analysis.py data/Smoking_LungCancer/s4_node_removal/reduced_graph.graphml \
        Smoking LungCancer --output-dir results/

Input:
    A GraphML file produced by Stage 4 (Node Removal).

Output:
    - butterfly_bias_report.json  — Butterfly bias detection results
    - m_bias_report.json          — M-bias detection results
"""

import argparse
import json
import sys
from pathlib import Path

import networkx as nx

from causal_analysis.s7_bias_analysis import (
    analyze_butterfly_bias,
    analyze_m_bias,
    identify_variable_roles,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run M-bias and Butterfly bias analysis on a reduced graph.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "graph_path",
        help="Path to the reduced graph file (GraphML format from Stage 4).",
    )
    parser.add_argument("exposure", help="Name of the exposure variable.")
    parser.add_argument("outcome", help="Name of the outcome variable.")
    parser.add_argument(
        "--output-dir", "-o",
        default=".",
        help="Directory for output files (default: current directory).",
    )
    return parser.parse_args()


def load_graph(path: str) -> nx.DiGraph:
    """Load a directed graph from a GraphML file."""
    p = Path(path)
    if not p.exists():
        print(f"Error: Graph file not found: {p}", file=sys.stderr)
        sys.exit(1)
    G = nx.read_graphml(str(p))
    if not isinstance(G, nx.DiGraph):
        G = nx.DiGraph(G)
    return G


def main() -> None:
    args = parse_args()

    # Load graph
    print(f"Loading graph from: {args.graph_path}")
    G = load_graph(args.graph_path)
    print(f"  Nodes: {G.number_of_nodes()}, Edges: {G.number_of_edges()}")
    print(f"  Is DAG: {nx.is_directed_acyclic_graph(G)}")

    # Validate exposure / outcome
    if args.exposure not in G:
        print(f"Error: Exposure '{args.exposure}' not found in graph.", file=sys.stderr)
        sys.exit(1)
    if args.outcome not in G:
        print(f"Error: Outcome '{args.outcome}' not found in graph.", file=sys.stderr)
        sys.exit(1)

    print(f"\nExposure: {args.exposure}")
    print(f"Outcome:  {args.outcome}")

    # Compute variable roles once (shared by both analyses)
    print("\nComputing variable roles...")
    roles = identify_variable_roles(G, args.exposure, args.outcome)

    # Run Butterfly bias analysis
    print("Running Butterfly bias analysis...")
    butterfly = analyze_butterfly_bias(G, args.exposure, args.outcome, roles=roles)

    # Run M-bias analysis
    print("Running M-bias analysis...")
    mbias = analyze_m_bias(G, args.exposure, args.outcome, roles=roles)

    # Prepare output directory
    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Write Butterfly bias report
    butterfly_path = out_dir / "butterfly_bias_report.json"
    butterfly_report = {
        "exposure": args.exposure,
        "outcome": args.outcome,
        "graph_file": str(Path(args.graph_path).resolve()),
        "node_count": G.number_of_nodes(),
        "edge_count": G.number_of_edges(),
        "is_dag": nx.is_directed_acyclic_graph(G),
        "roles": butterfly["roles"],
        "butterfly_vars": butterfly["butterfly_vars"],
        "butterfly_parents": butterfly["butterfly_parents"],
        "valid_sets": butterfly["valid_sets"],
        "non_butterfly_confounders": butterfly["non_butterfly_confounders"],
    }
    with open(butterfly_path, "w") as f:
        json.dump(butterfly_report, f, indent=2)
    print(f"\nSaved Butterfly bias report: {butterfly_path}")

    # Write M-bias report
    mbias_path = out_dir / "m_bias_report.json"
    mbias_report = {
        "exposure": args.exposure,
        "outcome": args.outcome,
        "graph_file": str(Path(args.graph_path).resolve()),
        "node_count": G.number_of_nodes(),
        "edge_count": G.number_of_edges(),
        "is_dag": nx.is_directed_acyclic_graph(G),
        "adjustment_set": mbias["adjustment_set"],
        "mbias_vars": mbias["mbias_vars"],
        "mbias_details": mbias["mbias_details"],
        "capped": mbias.get("capped", False),
    }
    with open(mbias_path, "w") as f:
        json.dump(mbias_report, f, indent=2)
    print(f"Saved M-bias report:        {mbias_path}")

    # Summary
    print(f"\n--- Summary ---")
    print(f"Butterfly bias variables: {len(butterfly['butterfly_vars'])}")
    print(f"M-bias variables:         {len(mbias['mbias_vars'])}"
          + (" (capped)" if mbias.get("capped") else ""))
    print(f"Adjustment set size:      {len(mbias['adjustment_set'])}")


if __name__ == "__main__":
    main()

