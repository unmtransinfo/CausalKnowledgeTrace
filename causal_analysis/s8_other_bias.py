"""
s8_other_bias.py
Stage 8: Additional Bias Structure Analysis (Mediation, Collider, Confounding).

Identifies additional bias structures beyond butterfly and M-bias:
  - Confounding: E ← X → O (Upstream of both) - ADJUST
  - Mediation: E → X → O (Between them) - DO NOT ADJUST
  - Collider: E → X ← O (Downstream of both) - DO NOT ADJUST

Detection uses direct parent/child relationships (matching s7 approach).
Works on both DAGs and cyclic graphs.

Input:  data/{Exposure}_{Outcome}/s4_node_removal/reduced_graph.graphml
        (falls back to s1_graph/graph.graphml if reduced graph not found)
Output: data/{Exposure}_{Outcome}/s8_other_bias/
          - confounding_nodes.csv
          - mediation_nodes.csv
          - collider_nodes.csv
          - analysis_summary.txt
          - reports/confounding/
          - reports/mediation/
          - reports/collider/
"""

import csv
import logging
from datetime import datetime
from pathlib import Path
from typing import Any

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import networkx as nx

from .utils import (
    get_s1_graph_dir,
    get_s4_node_removal_dir,
    get_s8_other_bias_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)

logger = logging.getLogger(__name__)


# ── Bias structure identification ──────────────────────────────────────

def identify_confounding(G: nx.DiGraph, exposure: str, outcome: str) -> dict[str, Any]:
    """Identify confounding bias: E ← X → O (X is upstream of both).

    Confounding structure:
        Exposure ← X → Outcome

    Detection (direct parent/child):
        X is a common parent of both E and O
        X ∈ parents(E) ∩ parents(O)

    These should be ADJUSTED for to block backdoor paths.
    """
    if exposure not in G or outcome not in G:
        return {
            "confounding_vars": [],
            "confounding_structures": [],
        }

    parents_E = set(G.predecessors(exposure))
    parents_O = set(G.predecessors(outcome))

    # Confounding nodes = common parents of E and O
    confounding_set = parents_E & parents_O

    # Build structures
    structures = []
    for x in sorted(confounding_set):
        structures.append({
            "node": x,
            "structure_nodes": sorted({x, exposure, outcome}),
            "bias_type": "confounding",
        })

    return {
        "confounding_vars": sorted(confounding_set),
        "confounding_structures": structures,
    }


def identify_mediation(G: nx.DiGraph, exposure: str, outcome: str) -> dict[str, Any]:
    """Identify mediation bias: E → X → O (X is between them).

    Mediation structure:
        Exposure → X → Outcome

    Detection (direct parent/child):
        E → X (X is child of E)
        X → O (X is parent of O)

    These should NOT be adjusted for (would block the causal effect).
    """
    if exposure not in G or outcome not in G:
        return {
            "mediation_vars": [],
            "mediation_structures": [],
        }

    children_E = set(G.successors(exposure))
    parents_O = set(G.predecessors(outcome))

    # Mediation nodes = children of E that are also parents of O
    mediation_set = children_E & parents_O

    # Build structures
    structures = []
    for x in sorted(mediation_set):
        structures.append({
            "node": x,
            "structure_nodes": sorted({exposure, x, outcome}),
            "bias_type": "mediation",
        })

    return {
        "mediation_vars": sorted(mediation_set),
        "mediation_structures": structures,
    }


def identify_collider(
    G: nx.DiGraph,
    exposure: str,
    outcome: str,
    exclude_confounders: set[str] | None = None,
    exclude_mediators: set[str] | None = None,
) -> dict[str, Any]:
    """Identify collider bias: E → X ← O (X is downstream of both).

    Collider structure:
        Exposure → X ← Outcome

    Detection (direct parent/child):
        E → X (X is child of E)
        O → X (X is child of O)

    Excludes nodes that are confounders or mediators to avoid duplicates.

    These should NOT be adjusted for (would open spurious paths).
    """
    if exposure not in G or outcome not in G:
        return {
            "collider_vars": [],
            "collider_structures": [],
        }

    if exclude_confounders is None:
        exclude_confounders = set()
    if exclude_mediators is None:
        exclude_mediators = set()

    children_E = set(G.successors(exposure))
    children_O = set(G.successors(outcome))

    # Collider nodes = common children of E and O
    collider_set = children_E & children_O

    # Exclude confounders and mediators
    collider_set -= exclude_confounders
    collider_set -= exclude_mediators

    # Build structures
    structures = []
    for x in sorted(collider_set):
        structures.append({
            "node": x,
            "structure_nodes": sorted({exposure, outcome, x}),
            "bias_type": "collider",
        })

    return {
        "collider_vars": sorted(collider_set),
        "collider_structures": structures,
    }


# ── Color scheme (consistent with s7) ──────────────────────────────────

# Node fill colors by type
_NODE_COLORS = {
    "exposure":     "#E74C3C",   # Red
    "outcome":      "#3498DB",   # Blue
    "confounding":  "#2ECC71",   # Green (matches confounder in s7)
    "mediation":    "#F1C40F",   # Yellow/Amber (on causal path)
    "collider":     "#E91E63",   # Pink/Magenta (distinct from M-bias purple)
    "other":        "#D5D8DC",   # Gray
}

# Node border colors by type
_BORDER_COLORS = {
    "exposure":     "#C0392B",
    "outcome":      "#2980B9",
    "confounding":  "#1E8449",
    "mediation":    "#D4AC0D",
    "collider":     "#AD1457",
    "other":        "#95A5A6",
}


# ── Subgraph extraction & plotting ──────────────────────────────────────

def _extract_bias_subgraph(
    G: nx.DiGraph,
    bias_node: str,
    exposure: str,
    outcome: str,
    bias_type: str,
) -> nx.DiGraph:
    """Extract 3-node subgraph for bias structure: E, X, O.

    Only keeps edges relevant to the specific bias structure:
      - confounding: X → E, X → O
      - mediation:   E → X, X → O
      - collider:    E → X, O → X
    """
    keep = {bias_node, exposure, outcome} & set(G.nodes())
    sub = nx.DiGraph()
    sub.add_nodes_from(keep)

    if bias_type == "mediation":
        # E → X and X → O only
        if G.has_edge(exposure, bias_node):
            sub.add_edge(exposure, bias_node)
        if G.has_edge(bias_node, outcome):
            sub.add_edge(bias_node, outcome)
    elif bias_type == "confounding":
        # X → E and X → O only
        if G.has_edge(bias_node, exposure):
            sub.add_edge(bias_node, exposure)
        if G.has_edge(bias_node, outcome):
            sub.add_edge(bias_node, outcome)
    elif bias_type == "collider":
        # E → X and O → X only
        if G.has_edge(exposure, bias_node):
            sub.add_edge(exposure, bias_node)
        if G.has_edge(outcome, bias_node):
            sub.add_edge(outcome, bias_node)
    else:
        # Fallback: all edges between the 3 nodes
        for u, v in G.subgraph(keep).edges():
            sub.add_edge(u, v)

    return sub


def _plot_bias_subgraph(
    sub: nx.DiGraph,
    bias_node: str,
    exposure: str,
    outcome: str,
    bias_type: str,
    title: str,
    filepath: Path,
) -> None:
    """Plot a bias structure subgraph with color-coded nodes.

    Color scheme:
        Red (#E74C3C)      = Exposure
        Blue (#3498DB)     = Outcome
        Green (#2ECC71)    = Confounding (adjust for)
        Yellow (#F1C40F)   = Mediation (do not adjust)
        Pink (#E91E63)     = Collider (do not adjust)
        Gray (#D5D8DC)     = Other nodes

    Edge coloring:
        - Color matches the bias type for edges involving the bias node
        - Red for edges touching exposure
        - Blue for edges touching outcome
    """
    nodes = list(sub.nodes())

    # --- Classify each node ---
    fill_colors = []
    border_colors = []
    for n in nodes:
        if n == exposure:
            ntype = "exposure"
        elif n == outcome:
            ntype = "outcome"
        elif n == bias_node:
            ntype = bias_type
        else:
            ntype = "other"
        fill_colors.append(_NODE_COLORS[ntype])
        border_colors.append(_BORDER_COLORS[ntype])

    # --- Node sizes (bias node and exposure/outcome larger) ---
    size_map = []
    for n in nodes:
        if n == bias_node:
            size_map.append(1400)
        elif n in (exposure, outcome):
            size_map.append(1100)
        else:
            size_map.append(800)

    # --- Edge colors (semantic) ---
    bias_edge_color = _NODE_COLORS[bias_type]
    edge_colors = []
    edge_widths = []
    for u, v in sub.edges():
        ec = "#BDC3C7"   # default gray
        ew = 1.5

        # Edges involving the bias node get the bias color
        if u == bias_node or v == bias_node:
            ec, ew = bias_edge_color, 3.0
        # Edges touching exposure = red
        elif u == exposure or v == exposure:
            ec, ew = "#E74C3C", 2.0
        # Edges touching outcome = blue
        elif u == outcome or v == outcome:
            ec, ew = "#3498DB", 2.0

        edge_colors.append(ec)
        edge_widths.append(ew)

    fig, ax = plt.subplots(figsize=(10, 8))

    # Custom layout based on bias type (compact for better arrow visibility)
    pos = {}
    if bias_type == "confounding":
        # E ← X → O: X at top, E and O at bottom
        pos[bias_node] = (0, 1.2)
        pos[exposure] = (-1.2, 0)
        pos[outcome] = (1.2, 0)
    elif bias_type == "mediation":
        # E → X → O: linear left to right
        pos[exposure] = (-1.2, 0)
        pos[bias_node] = (0, 0)
        pos[outcome] = (1.2, 0)
    elif bias_type == "collider":
        # E → X ← O: X at bottom, E and O at top
        pos[exposure] = (-1.2, 1.2)
        pos[outcome] = (1.2, 1.2)
        pos[bias_node] = (0, 0)
    else:
        pos = nx.spring_layout(sub, seed=42, k=1.5)

    # Handle nodes not in positions
    for n in nodes:
        if n not in pos:
            pos[n] = (0, -1)

    # Draw edges
    if sub.number_of_edges() > 0:
        nx.draw_networkx_edges(
            sub, pos, ax=ax,
            edge_color=edge_colors, width=edge_widths,
            arrows=True, arrowsize=25,
            connectionstyle="arc3,rad=0.15",
            min_source_margin=15,
            min_target_margin=15,
        )

    nx.draw_networkx_nodes(
        sub, pos, ax=ax,
        node_color=fill_colors, node_size=size_map,
        edgecolors=border_colors, linewidths=2.5,
    )

    # Replace underscores with newlines in labels for readability
    labels = {n: n.replace("_", "\n") for n in nodes}
    nx.draw_networkx_labels(sub, pos, labels=labels, ax=ax,
                            font_size=9, font_weight="bold")

    # Center mediation layout vertically (arc edges skew auto-limits)
    if bias_type == "mediation":
        ax.set_ylim(-1.5, 1.5)

    ax.set_title(title, fontsize=14, fontweight="bold", pad=20)

    # --- Build legend ---
    legend_items = [
        ("Exposure", _NODE_COLORS["exposure"]),
        ("Outcome", _NODE_COLORS["outcome"]),
    ]

    if bias_type == "confounding":
        legend_items.append(("Confounder (ADJUST)", _NODE_COLORS["confounding"]))
    elif bias_type == "mediation":
        legend_items.append(("Mediator (DO NOT adjust)", _NODE_COLORS["mediation"]))
    elif bias_type == "collider":
        legend_items.append(("Collider (DO NOT adjust)", _NODE_COLORS["collider"]))

    if any(n not in (bias_node, exposure, outcome) for n in nodes):
        legend_items.append(("Other node", _NODE_COLORS["other"]))

    legend_handles = [
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=c,
                   markeredgecolor="black", markersize=10, label=l)
        for l, c in legend_items
    ]
    ax.legend(handles=legend_handles, loc="lower right", fontsize=9,
              framealpha=0.9, edgecolor="gray", title="Node Types")

    # Adjust layout to prevent nodes from being blocked by legend
    fig.subplots_adjust(left=0.1, right=0.95, top=0.92, bottom=0.08)
    fig.savefig(filepath, dpi=150, bbox_inches="tight")
    plt.close(fig)


def _save_bias_reports(
    G: nx.DiGraph,
    structures: list[dict],
    exposure: str,
    outcome: str,
    reports_dir: Path,
    bias_type: str,
) -> None:
    """Generate per-node subgraph reports (plot + edge CSV + graphml)."""
    ensure_dir(reports_dir)

    for structure in structures:
        node = structure.get("node", "")
        safe_name = node.replace(" ", "_").replace("/", "_")

        node_dir = reports_dir / safe_name
        ensure_dir(node_dir)

        # Extract subgraph
        sub = _extract_bias_subgraph(G, node, exposure, outcome, bias_type)

        # Save edge list
        with open(node_dir / "edges.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["from", "to"])
            for u, v in sub.edges():
                w.writerow([u, v])

        # Save subgraph as graphml
        nx.write_graphml(sub, str(node_dir / "subgraph.graphml"))

        # Plot title
        plot_title = f"{node} - {bias_type.capitalize()} Bias"

        # Save as PDF
        prefix = bias_type.upper()
        plot_file = node_dir / f"{prefix}_{safe_name}.pdf"

        # Save plot
        _plot_bias_subgraph(
            sub, node, exposure, outcome, bias_type,
            title=plot_title,
            filepath=plot_file,
        )


# ── File I/O ────────────────────────────────────────────────────────────

def save_results(
    output_dir: Path,
    exposure: str,
    outcome: str,
    graph: nx.DiGraph,
    confounding: dict,
    mediation: dict,
    collider: dict,
    is_acyclic: bool,
) -> None:
    """Save all analysis results."""
    ensure_dir(output_dir)

    # 1. CSV files for each bias type
    # Confounding
    if confounding["confounding_structures"]:
        with open(output_dir / "confounding_nodes.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["node", "bias_type", "recommendation"])
            for s in confounding["confounding_structures"]:
                w.writerow([s["node"], "confounding", "ADJUST"])

    # Mediation
    if mediation["mediation_structures"]:
        with open(output_dir / "mediation_nodes.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["node", "bias_type", "recommendation"])
            for s in mediation["mediation_structures"]:
                w.writerow([s["node"], "mediation", "DO NOT ADJUST"])

    # Collider
    if collider["collider_structures"]:
        with open(output_dir / "collider_nodes.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["node", "bias_type", "recommendation"])
            for s in collider["collider_structures"]:
                w.writerow([s["node"], "collider", "DO NOT ADJUST"])

    # 2. Subgraph reports for each bias type
    if confounding["confounding_structures"]:
        _save_bias_reports(
            graph, confounding["confounding_structures"],
            exposure, outcome,
            output_dir / "reports" / "confounding",
            "confounding",
        )

    if mediation["mediation_structures"]:
        _save_bias_reports(
            graph, mediation["mediation_structures"],
            exposure, outcome,
            output_dir / "reports" / "mediation",
            "mediation",
        )

    if collider["collider_structures"]:
        _save_bias_reports(
            graph, collider["collider_structures"],
            exposure, outcome,
            output_dir / "reports" / "collider",
            "collider",
        )

    # 3. Summary text file
    _write_summary(
        output_dir / "analysis_summary.txt",
        exposure, outcome, graph,
        confounding, mediation, collider, is_acyclic,
    )


def _write_summary(
    path: Path,
    exposure: str,
    outcome: str,
    graph: nx.DiGraph,
    confounding: dict,
    mediation: dict,
    collider: dict,
    is_acyclic: bool,
) -> None:
    """Write analysis summary text file."""
    with open(path, "w") as f:
        f.write("=======================================================\n")
        f.write("Other Bias Structure Analysis Summary\n")
        f.write("=======================================================\n\n")
        f.write(f"Exposure: {exposure}\n")
        f.write(f"Outcome: {outcome}\n")
        f.write(f"Graph is Acyclic: {is_acyclic}\n")
        f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        f.write("=== Method ===\n")
        f.write("Detection uses direct parent/child relationships only.\n")
        f.write("Works on both DAGs and cyclic graphs.\n\n")

        f.write("Bias structures detected:\n")
        f.write("  1. Confounding: E ← X → O (X upstream of both)\n")
        f.write("     → ADJUST for these to block backdoor paths\n")
        f.write("  2. Mediation: E → X → O (X between them)\n")
        f.write("     → DO NOT adjust (blocks causal effect)\n")
        f.write("  3. Collider: E → X ← O (X downstream of both)\n")
        f.write("     → DO NOT adjust (opens spurious paths)\n\n")

        f.write("=== Graph Statistics ===\n")
        f.write(f"Total nodes: {graph.number_of_nodes()}\n")
        f.write(f"Total edges: {graph.number_of_edges()}\n\n")

        f.write("=== Results ===\n\n")

        # Confounding
        n_conf = len(confounding["confounding_vars"])
        f.write(f"1. CONFOUNDING (E ← X → O): {n_conf} nodes found\n")
        if n_conf > 0:
            f.write("   Recommendation: ADJUST for these\n")
            f.write("   Nodes:\n")
            for i, node in enumerate(confounding["confounding_vars"], 1):
                f.write(f"     {i}. {node}\n")
        else:
            f.write("   No confounding nodes found.\n")
        f.write("\n")

        # Mediation
        n_med = len(mediation["mediation_vars"])
        f.write(f"2. MEDIATION (E → X → O): {n_med} nodes found\n")
        if n_med > 0:
            f.write("   Recommendation: DO NOT adjust (would block causal effect)\n")
            f.write("   Nodes:\n")
            for i, node in enumerate(mediation["mediation_vars"], 1):
                f.write(f"     {i}. {node}\n")
        else:
            f.write("   No mediation nodes found.\n")
        f.write("\n")

        # Collider
        n_col = len(collider["collider_vars"])
        f.write(f"3. COLLIDER (E → X ← O): {n_col} nodes found\n")
        if n_col > 0:
            f.write("   Recommendation: DO NOT adjust (would open spurious paths)\n")
            f.write("   Nodes:\n")
            for i, node in enumerate(collider["collider_vars"], 1):
                f.write(f"     {i}. {node}\n")
        else:
            f.write("   No collider nodes found.\n")
        f.write("\n")

        # Summary table
        f.write("=== Summary ===\n")
        f.write(f"Total bias structures found: {n_conf + n_med + n_col}\n")
        f.write(f"  - Confounding (adjust): {n_conf}\n")
        f.write(f"  - Mediation (do not adjust): {n_med}\n")
        f.write(f"  - Collider (do not adjust): {n_col}\n")


# ── Graph loading ───────────────────────────────────────────────────────

def load_graph(exposure: str, outcome: str) -> nx.DiGraph:
    """Load the best available graph (reduced > original)."""
    reduced_path = get_s4_node_removal_dir(exposure, outcome) / "reduced_graph.graphml"
    if reduced_path.exists():
        print(f"Loading reduced graph from: {reduced_path}")
        return nx.read_graphml(str(reduced_path))

    original_path = get_s1_graph_dir(exposure, outcome) / "graph.graphml"
    if original_path.exists():
        print("Note: Using original graph (no reduced graph found)")
        print(f"Loading from: {original_path}")
        return nx.read_graphml(str(original_path))

    raise FileNotFoundError(
        f"No graph found. Looked for:\n"
        f"  {reduced_path}\n"
        f"  {original_path}\n"
        f"Please run earlier pipeline stages first."
    )


# ── Main entry point ────────────────────────────────────────────────────

def run_stage8(exposure: str, outcome: str) -> dict:
    """Execute Stage 8: Other bias structure analysis."""
    print_header("Other Bias Analysis -- Confounding, Mediation, Collider (Stage 8)",
                 exposure, outcome)

    G = load_graph(exposure, outcome)
    output_dir = get_s8_other_bias_dir(exposure, outcome)
    ensure_dir(output_dir)

    is_acyclic = nx.is_directed_acyclic_graph(G)
    print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")
    print(f"Is acyclic (DAG): {is_acyclic}")
    if not is_acyclic:
        print("WARNING: Graph has cycles. Results use direct parent/child logic.\n")

    if exposure not in G:
        raise ValueError(f"Exposure '{exposure}' not found in graph")
    if outcome not in G:
        raise ValueError(f"Outcome '{outcome}' not found in graph")

    # --- Step 1: Identify confounding (E ← X → O) ---
    print("\n=== 1. CONFOUNDING BIAS (E ← X → O) ===")
    print("Identifying nodes that are common parents of E and O...")

    confounding = identify_confounding(G, exposure, outcome)
    n_conf = len(confounding["confounding_vars"])
    print(f"Found {n_conf} confounding nodes")

    if n_conf > 0:
        print("Confounding nodes (ADJUST for these):")
        for i, node in enumerate(confounding["confounding_vars"], 1):
            print(f"  {i}. {node}")

    # --- Step 2: Identify mediation (E → X → O) ---
    print("\n=== 2. MEDIATION BIAS (E → X → O) ===")
    print("Identifying nodes on the direct causal path from E to O...")

    mediation = identify_mediation(G, exposure, outcome)
    n_med = len(mediation["mediation_vars"])
    print(f"Found {n_med} mediation nodes")

    if n_med > 0:
        print("Mediation nodes (DO NOT adjust - would block causal effect):")
        for i, node in enumerate(mediation["mediation_vars"], 1):
            print(f"  {i}. {node}")

    # --- Step 3: Identify collider (E → X ← O) ---
    print("\n=== 3. COLLIDER BIAS (E → X ← O) ===")
    print("Identifying nodes that are common children of E and O...")
    print("(Excluding confounders and mediators to avoid duplicates)")

    confounders_set = set(confounding["confounding_vars"])
    mediators_set = set(mediation["mediation_vars"])

    collider = identify_collider(G, exposure, outcome, confounders_set, mediators_set)
    n_col = len(collider["collider_vars"])
    print(f"Found {n_col} collider nodes")

    if n_col > 0:
        print("Collider nodes (DO NOT adjust - would open spurious paths):")
        for i, node in enumerate(collider["collider_vars"], 1):
            print(f"  {i}. {node}")

    # --- Step 4: Save results ---
    print("\n=== 4. SAVING RESULTS ===")
    save_results(output_dir, exposure, outcome, G,
                 confounding, mediation, collider, is_acyclic)

    if n_conf > 0:
        print("Saved confounding_nodes.csv")
    if n_med > 0:
        print("Saved mediation_nodes.csv")
    if n_col > 0:
        print("Saved collider_nodes.csv")
    print("Saved analysis_summary.txt")

    n_reports = n_conf + n_med + n_col
    if n_reports > 0:
        print(f"Saved {n_reports} subgraph reports (plots + edges) in reports/")
    print(f"All outputs in: {output_dir}")

    print_complete("Other Bias Analysis (Stage 8)")

    return {
        "n_confounding": n_conf,
        "n_mediation": n_med,
        "n_collider": n_col,
        "confounding_vars": confounding["confounding_vars"],
        "mediation_vars": mediation["mediation_vars"],
        "collider_vars": collider["collider_vars"],
        "is_dag": is_acyclic,
    }


if __name__ == "__main__":
    args = parse_args("Stage 8: Other bias structure analysis")
    run_stage8(args.exposure, args.outcome)
