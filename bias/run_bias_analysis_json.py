#!/usr/bin/env python3
"""
Standalone CLI script to run M-bias and/or Butterfly bias analysis on a
Cytoscape-style graph JSON file (as produced by graph_creation/result/).

Exposure and outcome are detected automatically from the node_type field
("exposure" / "outcome") embedded in the graph file — no manual input needed.

Usage:
    python bias/run_bias_analysis_json.py --graph <path> [--mbias] [--butterfly] [--output-dir <dir>]

Examples:
    # Both analyses (default), output to bias/
    python bias/run_bias_analysis_json.py \\
        --graph graph_creation/result/Hypertension_to_Alzheimers_degree1.json

    # M-bias only
    python bias/run_bias_analysis_json.py -g graph_creation/result/Hypertension_to_Alzheimers_degree1.json --mbias

    # Butterfly only, custom output dir
    python bias/run_bias_analysis_json.py -g graph_creation/result/Hypertension_to_Alzheimers_degree1.json --butterfly -o results/
"""

import argparse
import json
import sys
from pathlib import Path

# Ensure the project root (parent of this file's directory) is on sys.path so
# that `causal_analysis` is importable regardless of the working directory.
_PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))

import networkx as nx

from causal_analysis.s7_bias_analysis import (
    analyze_butterfly_bias,
    analyze_m_bias,
    identify_variable_roles,
)


# ── Cytoscape JSON → NetworkX DiGraph ───────────────────────────────────

def cytoscape_json_to_networkx(data: dict) -> tuple[nx.DiGraph, str | None, str | None]:
    """Convert a graph dict into a NetworkX DiGraph.

    Also extracts the exposure and outcome node IDs from the ``node_type``
    field (values ``"exposure"`` and ``"outcome"``).

    Returns
    -------
    (G, exposure_id, outcome_id)
        exposure_id / outcome_id are ``None`` when the field is absent.
    """
    elements = data.get("elements", data)  # tolerate flat {"nodes":...,"edges":...}
    nodes = elements.get("nodes", [])
    edges = elements.get("edges", [])

    G = nx.DiGraph()
    exposure_id: str | None = None
    outcome_id:  str | None = None

    for node in nodes:
        d = node.get("data", {})
        node_id = d.get("id", "")
        if not node_id:
            continue
        label     = d.get("label", node_id)
        node_type = d.get("node_type", d.get("type", "regular"))
        if node_type in ("default", ""):
            node_type = "regular"
        G.add_node(node_id, label=label, node_type=node_type)

        if node_type == "exposure":
            exposure_id = node_id
        elif node_type == "outcome":
            outcome_id = node_id

    for edge in edges:
        d = edge.get("data", {})
        src = d.get("source", "")
        tgt = d.get("target", "")
        if not src or not tgt:
            continue
        predicate = d.get("predicate", "CAUSES")
        ev_count  = d.get("evidence_count", 0)
        G.add_edge(src, tgt, predicate=predicate, ev_count=ev_count)

    return G, exposure_id, outcome_id


def load_json_graph(path: str) -> tuple[nx.DiGraph, str | None, str | None]:
    """Read a Cytoscape JSON file and return (DiGraph, exposure_id, outcome_id)."""
    p = Path(path)
    if not p.exists():
        print(f"Error: Graph file not found: {p}", file=sys.stderr)
        sys.exit(1)
    with open(p, "r", encoding="utf-8") as f:
        data = json.load(f)
    return cytoscape_json_to_networkx(data)


# ── Argument parsing ─────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run M-bias and/or Butterfly bias analysis on a Cytoscape JSON graph.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )

    # ── required named arguments ──────────────────────────────────────────
    required = parser.add_argument_group("required arguments")
    required.add_argument(
        "--graph", "-g",
        required=True,
        metavar="PATH",
        help=(
            "Path to the graph JSON file. "
            "Exposure and outcome are read automatically from the "
            "node_type fields (\"exposure\" / \"outcome\") in this file."
        ),
    )

    # ── analysis selection ────────────────────────────────────────────────
    analysis = parser.add_argument_group(
        "analysis selection",
        "Choose which bias analyses to run. "
        "If neither flag is given, both analyses are run.",
    )
    analysis.add_argument(
        "--mbias", "-m",
        action="store_true",
        help="Run M-bias analysis.",
    )
    analysis.add_argument(
        "--butterfly", "-b",
        action="store_true",
        help="Run Butterfly bias analysis.",
    )

    # ── output ────────────────────────────────────────────────────────────
    parser.add_argument(
        "--output-dir", "-o",
        default=str(Path(__file__).resolve().parent),
        metavar="DIR",
        help="Directory for output JSON files (default: bias/).",
    )

    return parser.parse_args()


# ── Main ─────────────────────────────────────────────────────────────────

def main() -> None:
    args = parse_args()

    # When neither flag is set, run both analyses
    run_mbias = args.mbias or not (args.mbias or args.butterfly)
    run_butterfly = args.butterfly or not (args.mbias or args.butterfly)

    # Load graph + auto-detect exposure / outcome from node_type fields
    print(f"Loading graph from: {args.graph}")
    G, exposure, outcome = load_json_graph(args.graph)
    is_dag = nx.is_directed_acyclic_graph(G)
    print(f"  Nodes: {G.number_of_nodes()}, Edges: {G.number_of_edges()}")
    print(f"  Is DAG: {is_dag}")

    if not is_dag:
        print(
            "  WARNING: Graph is NOT a DAG. Bias analysis results may be unreliable. "
            "Consider running node removal first to break cycles.",
            file=sys.stderr,
        )

    # Validate that node_type="exposure" / "outcome" were present in the file
    if exposure is None:
        print(
            "Error: No node with node_type=\"exposure\" found in the graph file.",
            file=sys.stderr,
        )
        sys.exit(1)
    if outcome is None:
        print(
            "Error: No node with node_type=\"outcome\" found in the graph file.",
            file=sys.stderr,
        )
        sys.exit(1)

    print(f"\nExposure: {exposure}  (from node_type field)")
    print(f"Outcome:  {outcome}  (from node_type field)")

    # Shared metadata for every report
    common_meta = {
        "exposure": exposure,
        "outcome":  outcome,
        "graph_file": str(Path(args.graph).resolve()),
        "node_count": G.number_of_nodes(),
        "edge_count": G.number_of_edges(),
        "is_dag": is_dag,
    }

    # Compute variable roles ONCE (shared between both analyses)
    print("\nComputing variable roles...")
    roles = identify_variable_roles(G, exposure, outcome)

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # ── Butterfly bias ───────────────────────────────────────────────
    if run_butterfly:
        print("Running Butterfly bias analysis...")
        butterfly = analyze_butterfly_bias(G, exposure, outcome, roles=roles)

        butterfly_path = out_dir / "butterfly_bias_report.json"
        butterfly_report = {
            **common_meta,
            "roles": butterfly["roles"],
            "butterfly_vars": butterfly["butterfly_vars"],
            "butterfly_parents": butterfly["butterfly_parents"],
            "valid_sets": butterfly["valid_sets"],
            "non_butterfly_confounders": butterfly["non_butterfly_confounders"],
        }
        with open(butterfly_path, "w", encoding="utf-8") as f:
            json.dump(butterfly_report, f, indent=2)
        print(f"  Saved Butterfly bias report: {butterfly_path}")

    # ── M-bias ───────────────────────────────────────────────────────
    if run_mbias:
        print("Running M-bias analysis...")
        mbias = analyze_m_bias(G, exposure, outcome, roles=roles)

        mbias_path = out_dir / "m_bias_report.json"
        mbias_report = {
            **common_meta,
            "adjustment_set": mbias["adjustment_set"],
            "mbias_vars": mbias["mbias_vars"],
            "mbias_details": mbias["mbias_details"],
            "capped": mbias.get("capped", False),
        }
        with open(mbias_path, "w", encoding="utf-8") as f:
            json.dump(mbias_report, f, indent=2)
        print(f"  Saved M-bias report:        {mbias_path}")

    # ── Summary ──────────────────────────────────────────────────────
    print("\n--- Summary ---")
    if run_butterfly:
        print(f"Butterfly bias variables: {len(butterfly['butterfly_vars'])}")
    if run_mbias:
        capped_note = " (capped)" if mbias.get("capped") else ""
        print(f"M-bias variables:         {len(mbias['mbias_vars'])}{capped_note}")
        print(f"Adjustment set size:      {len(mbias['adjustment_set'])}")


if __name__ == "__main__":
    main()
