"""
s7_bias_analysis.py
Stage 7: Butterfly Bias and M-Bias Analysis.

Matches R logic from furtherAnalysis/post_ckt/scripts/04_butterfly_bias_analysis.R:
  - Confounder identification via direct parents/children (NOT transitive ancestors)
    Formula: intersect(parents(exposure), parents(outcome))
             - children(exposure) - children(outcome)
  - Butterfly bias detection (confounders with >=2 confounder parents)

Additionally provides (not in R):
  - M-bias detection (colliders on backdoor paths that should NOT be adjusted)
    Uses direct parent/child only (top-down approach):
    M = children(parent_of_X) ∩ children(parent_of_Y) where P1 ≠ P2

Works on both DAGs and cyclic graphs (all checks use direct parent/child).

Input:  data/{Exposure}_{Outcome}/s4_node_removal/reduced_graph.graphml
        (falls back to s1_graph/graph.graphml if reduced graph not found)
Output: data/{Exposure}_{Outcome}/s7_bias/
          - butterfly_analysis_results.csv
          - butterfly_nodes.csv
          - independent_confounders.csv
          - m_bias_results.csv  (if M-bias nodes found)
          - analysis_summary.txt
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
    get_s7_bias_dir,
    ensure_dir,
    print_header,
    print_complete,
    parse_args,
)

logger = logging.getLogger(__name__)


# ── Confounder identification (matches R dagitty logic) ──────────────

def identify_confounders(G: nx.DiGraph, exposure: str, outcome: str) -> dict[str, Any]:
    """Identify confounders using direct parents/children.

    Matches R's dagitty::parents() / dagitty::children() approach:
      confounders = intersect(parents(exposure), parents(outcome))
                    - children(exposure) - children(outcome)

    These are direct (1-hop) structural relationships, NOT transitive ancestors.
    This works even with cyclic graphs.
    """
    if exposure not in G or outcome not in G:
        return {
            "parents_exposure": [],
            "parents_outcome": [],
            "children_exposure": [],
            "children_outcome": [],
            "confounders": [],
        }

    parents_exp = set(G.predecessors(exposure))
    parents_out = set(G.predecessors(outcome))
    children_exp = set(G.successors(exposure))
    children_out = set(G.successors(outcome))

    # Confounders = common direct parents minus direct children of either
    confounders = (parents_exp & parents_out) - children_exp - children_out

    return {
        "parents_exposure": sorted(parents_exp),
        "parents_outcome": sorted(parents_out),
        "children_exposure": sorted(children_exp),
        "children_outcome": sorted(children_out),
        "confounders": sorted(confounders),
    }


# ── Butterfly bias analysis ──────────────────────────────────────────

def analyze_butterfly_bias(
    G: nx.DiGraph,
    exposure: str,
    outcome: str,
    confounders: list[str] | None = None,
) -> dict[str, Any]:
    """Detect butterfly bias: a confounder with 2+ OTHER confounders pointing into it.

    Butterfly structure (C2 is the butterfly):
        Exposure <- C1 -> C2 <- C3 -> Outcome
                  Exposure <- C2 -> Outcome
                  C1 -> Outcome
                  Exposure <- C3

    Key criteria for C2 to be a butterfly:
      1. C2 is a confounder (parent of both Exposure and Outcome)
      2. C2 has 2+ parents that are ALSO confounders (C1, C3)
      3. The parent confounders also point to Exposure/Outcome

    This creates a bias because adjusting for C2 opens collider paths
    through C1->C2<-C3, creating spurious associations.
    """
    if confounders is None:
        info = identify_confounders(G, exposure, outcome)
        confounders = info["confounders"]

    confounder_set = set(confounders)

    # Build per-confounder results
    results: list[dict] = []
    butterfly_vars: list[str] = []
    butterfly_parents: dict[str, list[str]] = {}
    butterfly_structures: dict[str, dict] = {}

    for conf in sorted(confounder_set):
        # Direct parents of this confounder
        conf_parents = set(G.predecessors(conf))
        # Which of those parents are also confounders?
        confounder_pars = sorted(conf_parents & confounder_set)
        is_butterfly = len(confounder_pars) >= 2

        results.append(
            {
                "confounder": conf,
                "n_confounder_parents": len(confounder_pars),
                "confounder_parents": ", ".join(confounder_pars),
                "is_butterfly": is_butterfly,
            }
        )

        if is_butterfly:
            butterfly_vars.append(conf)
            butterfly_parents[conf] = confounder_pars

            # For each butterfly, record its full structure for visualization
            # Include: the butterfly, its confounder-parents, exposure, outcome
            # and any edges between these nodes
            structure_nodes = {conf, exposure, outcome} | set(confounder_pars)
            butterfly_structures[conf] = {
                "center": conf,
                "confounder_parents": confounder_pars,
                "structure_nodes": sorted(structure_nodes),
            }

    independent = [r for r in results if r["n_confounder_parents"] == 0]
    has_one_parent = [r for r in results if r["n_confounder_parents"] == 1]

    return {
        "all_results": results,
        "butterfly_vars": butterfly_vars,
        "butterfly_parents": butterfly_parents,
        "butterfly_structures": butterfly_structures,
        "independent_confounders": [r["confounder"] for r in independent],
        "has_one_parent": [r["confounder"] for r in has_one_parent],
        "n_total": len(results),
        "n_independent": len(independent),
        "n_one_parent": len(has_one_parent),
        "n_butterfly": len(butterfly_vars),
    }


# ── M-bias analysis (top-down, direct parent/child only) ─────────────


def analyze_m_bias(
    G: nx.DiGraph,
    exposure: str,
    outcome: str,
    confounders: list[str] | None = None,
) -> dict[str, Any]:
    """Detect M-bias using direct parent/child relationships only.

    M-bias structure (M is the collider):
          X ← P1 → M ← P2 → Y

    Algorithm (top-down):
      1. parents_X = direct parents of Exposure - {Outcome}
      2. parents_Y = direct parents of Outcome - {Exposure}
      3. For each P1 in parents_X, P2 in parents_Y where P1 ≠ P2:
         4. M = children(P1) ∩ children(P2) - {X, Y} - confounders
         5. Each such M is an M-bias collider

    All relationships are direct (1-hop), no transitive ancestry needed.
    Works identically on DAGs and cyclic graphs.

    This is a Python-only addition (not in R pipeline).
    """
    if exposure not in G or outcome not in G:
        return {
            "exposure": exposure,
            "outcome": outcome,
            "mbias_vars": [],
            "mbias_details": {},
            "mbias_structures": {},
        }

    confounder_set = set(confounders) if confounders else set()

    # Step 1: Direct parents of exposure and outcome (excluding each other)
    parents_X = set(G.predecessors(exposure)) - {outcome}
    parents_Y = set(G.predecessors(outcome)) - {exposure}

    # Step 2: For each (P1, P2) pair, find common children = M-bias colliders
    # Store ALL valid (M, P1, P2) structures (same M can have multiple P1, P2 pairs)
    # STRICT M-bias: P1 exclusive to X side, P2 exclusive to Y side
    mbias_found: list[tuple[str, str, str]] = []  # List of (m, p1, p2) tuples

    for p1 in sorted(parents_X):
        # STRICT: P1 must be parent of X and M, but NOT parent of Y
        if p1 in parents_Y:
            continue

        children_p1 = set(G.successors(p1))
        for p2 in sorted(parents_Y):
            # STRICT: P2 must be parent of Y and M, but NOT parent of X
            if p2 in parents_X:
                continue

            if p1 == p2:
                continue  # need distinct parents

            # STRICT: P1 and P2 must be independent (no edge between them)
            if G.has_edge(p1, p2) or G.has_edge(p2, p1):
                continue

            children_p2 = set(G.successors(p2))

            # Common children = potential M-bias colliders
            common = children_p1 & children_p2
            common -= {exposure, outcome}   # M can't be X or Y
            common -= confounder_set        # M can't be a confounder

            for m in sorted(common):
                # Store ALL (M, P1, P2) combinations
                mbias_found.append((m, p1, p2))

    # Step 3: Build results
    # mbias_details: m -> list of {p1, p2} pairs
    # mbias_structures: list of all individual structures
    mbias_details: dict[str, list[dict]] = {}
    mbias_structures: list[dict] = []

    for m, p1, p2 in mbias_found:
        if m not in mbias_details:
            mbias_details[m] = []

        mbias_details[m].append({
            "p1_exposure_side": p1,
            "p2_outcome_side": p2,
        })

        mbias_structures.append({
            "collider": m,
            "p1": p1,
            "p2": p2,
            "structure_nodes": sorted({m, p1, p2, exposure, outcome}),
        })

    # mbias_vars: list of unique collider nodes
    mbias_vars = sorted(mbias_details.keys())

    return {
        "exposure": exposure,
        "outcome": outcome,
        "mbias_vars": mbias_vars,
        "mbias_details": mbias_details,
        "mbias_structures": mbias_structures,
    }


# ── Color scheme (matches R 04b_confounder_subgraphs.R) ───────────────

# Node fill colors by type
_NODE_COLORS = {
    "exposure":          "#E74C3C",   # Red
    "outcome":           "#3498DB",   # Blue
    "butterfly":         "#F39C12",   # Orange
    "confounder_self":   "#2ECC71",   # Green (this confounder, non-butterfly)
    "confounder_parent": "#27AE60",   # Darker green (confounder parent of butterfly)
    "confounder":        "#82E0AA",   # Light green (other confounder)
    "mbias":             "#9B59B6",   # Purple (M-bias collider)
    "mbias_parent":      "#AF7AC5",   # Light purple (parent of M-bias collider)
    "other":             "#D5D8DC",   # Gray
}

# Node border colors by type
_BORDER_COLORS = {
    "exposure":          "#C0392B",
    "outcome":           "#2980B9",
    "butterfly":         "#E67E22",
    "confounder_self":   "#1E8449",
    "confounder_parent": "#1E8449",
    "confounder":        "#27AE60",
    "mbias":             "#7D3C98",
    "mbias_parent":      "#884EA0",
    "other":             "#95A5A6",
}


# ── Subgraph extraction & plotting ────────────────────────────────────

def _extract_butterfly_subgraph(
    G: nx.DiGraph,
    butterfly_node: str,
    exposure: str,
    outcome: str,
    butterfly_structure: dict,
    confounder_set: set[str],
) -> nx.DiGraph:
    """Extract subgraph showing the butterfly bias structure.

    Butterfly structure (butterfly_node = C2):
        Exposure <- C1 -> C2 <- C3 -> Outcome
                  Exposure <- C2 -> Outcome

    Keep:
      - The butterfly node (center)
      - Its confounder-parents (C1, C3)
      - Exposure and Outcome
      - Edges showing the collider pattern and backdoor paths
    """
    keep = {butterfly_node, exposure, outcome}

    # Add the confounder-parents of the butterfly
    confounder_parents = set(butterfly_structure.get("confounder_parents", []))
    keep.update(confounder_parents)

    # Add any other confounders in the immediate neighborhood for context
    # (to show they also point to exposure/outcome)
    all_parents = set(G.predecessors(butterfly_node))
    all_children = set(G.successors(butterfly_node))
    keep.update((all_parents | all_children) & confounder_set)

    # Only keep nodes that exist
    keep = {n for n in keep if n in G}
    return G.subgraph(keep).copy()


def _extract_confounder_subgraph(
    G: nx.DiGraph,
    node: str,
    exposure: str,
    outcome: str,
    confounder_set: set[str],
) -> nx.DiGraph:
    """Extract subgraph for a general confounder (not butterfly).

    Keep:
      - The confounder
      - Exposure and Outcome
      - Other confounders in its immediate neighborhood
    """
    keep = {node, exposure, outcome}

    parents = set(G.predecessors(node))
    children = set(G.successors(node))

    # Only keep confounder neighbors
    keep.update(parents & confounder_set)
    keep.update(children & confounder_set)

    keep = {n for n in keep if n in G}
    return G.subgraph(keep).copy()


def _classify_node(
    node: str,
    highlight: str,
    exposure: str,
    outcome: str,
    is_butterfly: bool,
    confounder_set: set[str],
    confounder_parents_of_highlight: set[str],
) -> str:
    """Classify a node into a type for coloring (matches R logic)."""
    if node == exposure:
        return "exposure"
    if node == outcome:
        return "outcome"
    if node == highlight:
        return "butterfly" if is_butterfly else "confounder_self"
    if node in confounder_set:
        # If the highlight is a butterfly, and this node is a parent
        # of the highlight AND a confounder → confounder_parent
        if is_butterfly and node in confounder_parents_of_highlight:
            return "confounder_parent"
        return "confounder"
    return "other"


def _plot_subgraph(
    sub: nx.DiGraph,
    highlight_node: str,
    exposure: str,
    outcome: str,
    title: str,
    filepath: Path,
    confounder_set: set[str] | None = None,
    is_butterfly: bool = False,
    confounder_parents_of_highlight: set[str] | None = None,
) -> None:
    """Save a subgraph plot with color-coded nodes.

    Color scheme matches R's 04b_confounder_subgraphs.R:
        Red (#E74C3C)          = Exposure
        Blue (#3498DB)         = Outcome
        Orange (#F39C12)       = Butterfly confounder (highlight, if butterfly)
        Green (#2ECC71)        = This confounder (highlight, if independent)
        Darker green (#27AE60) = Confounder parent of butterfly
        Light green (#82E0AA)  = Other confounder
        Gray (#D5D8DC)         = Other node
    Edge coloring (semantic, matching R):
        Green  = confounder → exposure/outcome (backdoor path)
        Orange = confounder-parent → butterfly
        Red    = edges touching exposure
        Blue   = edges touching outcome
        Gray   = other edges
    """
    if confounder_set is None:
        confounder_set = set()
    if confounder_parents_of_highlight is None:
        confounder_parents_of_highlight = set()

    nodes = list(sub.nodes())

    # --- Classify each node ---
    node_types = {
        n: _classify_node(
            n, highlight_node, exposure, outcome,
            is_butterfly, confounder_set, confounder_parents_of_highlight,
        )
        for n in nodes
    }

    fill_colors = [_NODE_COLORS[node_types[n]] for n in nodes]
    border_colors = [_BORDER_COLORS[node_types[n]] for n in nodes]

    # --- Node sizes (highlight and exposure/outcome larger) ---
    size_map = []
    for n in nodes:
        if n == highlight_node:
            size_map.append(1400)
        elif n in (exposure, outcome):
            size_map.append(1100)
        else:
            size_map.append(800)

    # --- Edge colors (semantic, matching R) ---
    edge_colors = []
    edge_widths = []
    for u, v in sub.edges():
        ec = "#BDC3C7"   # default gray
        ew = 1.5

        # Confounder → exposure/outcome (backdoor) = green
        if u == highlight_node and v in (exposure, outcome):
            ec, ew = "#2ECC71", 3.0
        # Parent-confounder → butterfly = orange
        elif is_butterfly and v == highlight_node and u in confounder_set:
            ec, ew = "#F39C12", 2.5
        # Edges touching exposure = red
        elif u == exposure or v == exposure:
            ec, ew = "#E74C3C", 2.0
        # Edges touching outcome = blue
        elif u == outcome or v == outcome:
            ec, ew = "#3498DB", 2.0

        # Re-apply confounder→exposure/outcome on top (match R precedence)
        if u == highlight_node and v == exposure:
            ec, ew = "#2ECC71", 3.0
        if u == highlight_node and v == outcome:
            ec, ew = "#2ECC71", 3.0

        edge_colors.append(ec)
        edge_widths.append(ew)

    fig, ax = plt.subplots(figsize=(10, 8))

    # Custom layout for butterfly bias - hierarchical structure
    if is_butterfly:
        pos = {}
        # Exposure and outcome at left/right
        pos[exposure] = (-3, 0)
        pos[outcome] = (3, 0)

        # Butterfly confounder at center
        pos[highlight_node] = (0, 0)

        # Confounder parents above
        parents_list = list(confounder_parents_of_highlight & set(nodes))
        for i, p in enumerate(parents_list):
            angle = (i - len(parents_list)/2) * 0.6
            pos[p] = (angle, 2)

        # Other confounders spread around
        other_confounders = [n for n in nodes if n in confounder_set
                            and n != highlight_node
                            and n not in confounder_parents_of_highlight
                            and n not in (exposure, outcome)]
        for i, c in enumerate(other_confounders):
            angle = (i - len(other_confounders)/2) * 0.8
            pos[c] = (angle, -1.5)

        # Other nodes fill remaining positions
        other_nodes = [n for n in nodes if n not in pos]
        for i, n in enumerate(other_nodes):
            angle = (i - len(other_nodes)/2) * 0.5
            pos[n] = (angle + 4, -0.5)
    else:
        pos = nx.spring_layout(sub, seed=42, k=2.5)

    # Draw edges
    if sub.number_of_edges() > 0:
        nx.draw_networkx_edges(
            sub, pos, ax=ax,
            edge_color=edge_colors, width=edge_widths,
            arrows=True, arrowsize=15,
            connectionstyle="arc3,rad=0.08",
        )

    nx.draw_networkx_nodes(
        sub, pos, ax=ax,
        node_color=fill_colors, node_size=size_map,
        edgecolors=border_colors, linewidths=2.0,
    )

    # Replace underscores with newlines in labels for readability (matches R)
    labels = {n: n.replace("_", "\n") for n in nodes}
    nx.draw_networkx_labels(sub, pos, labels=labels, ax=ax,
                            font_size=8.5, font_weight="bold")

    ax.set_title(title, fontsize=13, fontweight="bold")

    # --- Build legend (matching R) ---
    legend_items = [
        ("Exposure", _NODE_COLORS["exposure"]),
        ("Outcome", _NODE_COLORS["outcome"]),
    ]
    if is_butterfly:
        legend_items.append(("This confounder (BUTTERFLY)", _NODE_COLORS["butterfly"]))
        if confounder_parents_of_highlight & set(nodes):
            legend_items.append(("Confounder parent", _NODE_COLORS["confounder_parent"]))
    else:
        legend_items.append(("This confounder (INDEPENDENT)", _NODE_COLORS["confounder_self"]))

    # Only show "Other confounder" if there are other confounders in the subgraph
    other_conf = confounder_set - {highlight_node}
    if other_conf & set(nodes):
        legend_items.append(("Other confounder", _NODE_COLORS["confounder"]))
    if any(t == "other" for t in node_types.values()):
        legend_items.append(("Other node", _NODE_COLORS["other"]))

    legend_handles = [
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=c,
                   markeredgecolor="black", markersize=10, label=l)
        for l, c in legend_items
    ]
    ax.legend(handles=legend_handles, loc="upper left", fontsize=9,
              framealpha=0.9, edgecolor="gray", title="Node Types")

    # Adjust layout to prevent outcome node from being blocked by legend
    fig.subplots_adjust(left=0.1, right=0.95, top=0.92, bottom=0.08)
    fig.savefig(filepath, dpi=150, bbox_inches="tight")
    plt.close(fig)


def _save_node_reports(
    G: nx.DiGraph,
    nodes: list[str],
    exposure: str,
    outcome: str,
    reports_dir: Path,
    node_type: str,
    confounder_set: set[str] | None = None,
    butterfly_structures: dict | None = None,
) -> None:
    """Generate per-node subgraph reports for confounders (plot + edge CSV + graphml).

    Args:
        butterfly_structures: dict mapping node → structure dict with:
                              {"center": node, "confounder_parents": [...], "structure_nodes": [...]}
                              From ``analyze_butterfly_bias()['butterfly_structures']``.
    """
    if confounder_set is None:
        confounder_set = set()
    if butterfly_structures is None:
        butterfly_structures = {}

    ensure_dir(reports_dir)
    for node in nodes:
        safe_name = node.replace(" ", "_").replace("/", "_")
        is_butterfly = node in butterfly_structures

        node_dir = reports_dir / safe_name
        ensure_dir(node_dir)

        # Extract appropriate subgraph based on node type
        if is_butterfly:
            sub = _extract_butterfly_subgraph(
                G, node, exposure, outcome,
                butterfly_structures[node], confounder_set,
            )
            conf_parents = set(butterfly_structures[node].get("confounder_parents", []))
        else:
            sub = _extract_confounder_subgraph(
                G, node, exposure, outcome, confounder_set,
            )
            conf_parents = set()

        # Save edge list
        edges = list(sub.edges())
        with open(node_dir / "edges.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["from", "to"])
            for u, v in edges:
                w.writerow([u, v])

        # Save subgraph as graphml
        nx.write_graphml(sub, str(node_dir / "subgraph.graphml"))

        # Simple title: just node name and bias type
        if is_butterfly:
            plot_title = f"{node} - Butterfly Bias"
            prefix = "BUTTERFLY_"
        else:
            plot_title = f"{node} - Independent Confounder"
            prefix = "INDEPENDENT_"

        # Save as PDF
        plot_file = node_dir / f"{prefix}{safe_name}.pdf"

        # Save plot
        _plot_subgraph(
            sub, node, exposure, outcome,
            title=plot_title,
            filepath=plot_file,
            confounder_set=confounder_set,
            is_butterfly=is_butterfly,
            confounder_parents_of_highlight=conf_parents,
        )


# ── M-bias specific plotting (Python-only) ────────────────────────────

def _extract_mbias_subgraph(
    G: nx.DiGraph,
    m_node: str,
    exposure: str,
    outcome: str,
    mbias_structure: dict,
) -> nx.DiGraph:
    """Extract subgraph showing the 5-node M-bias collider structure.

    M-bias structure (m_node = M):
          P1 → M ← P2
           ↓       ↓
      Exposure   Outcome

    Only keeps the 5 core nodes: M, P1, P2, Exposure, Outcome.
    """
    # 5-node structure only
    p1 = mbias_structure.get("p1", "")
    p2 = mbias_structure.get("p2", "")
    keep = {m_node, p1, p2, exposure, outcome} & set(G.nodes())

    return G.subgraph(keep).copy()


def _plot_mbias_subgraph(
    sub: nx.DiGraph,
    mbias_node: str,
    exposure: str,
    outcome: str,
    title: str,
    filepath: Path,
    confounder_set: set[str] | None = None,
    mbias_parents: set[str] | None = None,
) -> None:
    """Plot an M-bias collider subgraph with distinct purple coloring.

    Color scheme:
        Purple (#9B59B6)       = M-bias collider (DO NOT condition on)
        Light purple (#AF7AC5) = Parents of the collider
        Red (#E74C3C)          = Exposure
        Blue (#3498DB)         = Outcome
        Light green (#82E0AA)  = Confounders in the subgraph
        Gray (#D5D8DC)         = Other nodes
    Edge coloring:
        Purple = edges INTO the collider (converging arrows)
        Red    = edges touching exposure
        Blue   = edges touching outcome
        Gray   = other edges
    """
    if confounder_set is None:
        confounder_set = set()
    if mbias_parents is None:
        mbias_parents = set()

    nodes = list(sub.nodes())

    # --- Classify each node ---
    fill_colors = []
    border_colors = []
    for n in nodes:
        if n == exposure:
            ntype = "exposure"
        elif n == outcome:
            ntype = "outcome"
        elif n == mbias_node:
            ntype = "mbias"
        elif n in mbias_parents:
            ntype = "mbias_parent"
        elif n in confounder_set:
            ntype = "confounder"
        else:
            ntype = "other"
        fill_colors.append(_NODE_COLORS[ntype])
        border_colors.append(_BORDER_COLORS[ntype])

    # --- Node sizes ---
    size_map = []
    for n in nodes:
        if n == mbias_node:
            size_map.append(1400)
        elif n in (exposure, outcome):
            size_map.append(1100)
        elif n in mbias_parents:
            size_map.append(1000)
        else:
            size_map.append(800)

    # --- Edge colors (emphasize collider structure) ---
    edge_colors = []
    edge_widths = []
    for u, v in sub.edges():
        ec = "#BDC3C7"   # default gray
        ew = 1.5

        # Edges INTO the collider = purple (the defining structure)
        if v == mbias_node:
            ec, ew = "#9B59B6", 3.0
        # Edges OUT of the collider
        elif u == mbias_node:
            ec, ew = "#9B59B6", 2.0
        # Edges touching exposure = red
        elif u == exposure or v == exposure:
            ec, ew = "#E74C3C", 2.0
        # Edges touching outcome = blue
        elif u == outcome or v == outcome:
            ec, ew = "#3498DB", 2.0

        edge_colors.append(ec)
        edge_widths.append(ew)

    fig, ax = plt.subplots(figsize=(10, 8))

    # Custom M-shaped layout for M-bias: X←P1→M←P2→Y
    # P1 and P2 at top, X and Y at bottom corners, M at bottom center
    pos = {}
    if mbias_node in nodes and exposure in nodes and outcome in nodes:
        # Get P1 and P2 from mbias_parents
        parents_list = list(mbias_parents & set(nodes))

        # Exposure at bottom-left, Outcome at bottom-right (moved UP to 1.5)
        pos[exposure] = (-4, 1)
        pos[outcome] = (4, 1)

        # M-bias collider at bottom-center (moved UP to 1.5)
        pos[mbias_node] = (0, 1.5)

        # Identify which parent connects to exposure vs outcome
        # P1 (exposure-side parent) should be on LEFT, P2 (outcome-side parent) on RIGHT
        if len(parents_list) >= 2:
            p1_exposure_side = None
            p2_outcome_side = None

            for p in parents_list:
                # Check if this parent connects to exposure
                if sub.has_edge(p, exposure):
                    p1_exposure_side = p
                # Check if this parent connects to outcome
                elif sub.has_edge(p, outcome):
                    p2_outcome_side = p

            # Position P1 on left, P2 on right
            if p1_exposure_side:
                pos[p1_exposure_side] = (-3.5, 2.5)
            if p2_outcome_side:
                pos[p2_outcome_side] = (3.5, 2.5)

            # If any parent wasn't positioned, place them
            for p in parents_list:
                if p not in pos:
                    pos[p] = (0, 2.5)

        elif len(parents_list) == 1:
            pos[parents_list[0]] = (0, 2.5)

        # Other nodes spread around
        other_nodes = [n for n in nodes if n not in pos]
        for i, n in enumerate(other_nodes):
            angle = (i - len(other_nodes)/2) * 1.2
            pos[n] = (angle, 0.5)
    else:
        pos = nx.spring_layout(sub, seed=42, k=2.5)

    # Draw edges
    if sub.number_of_edges() > 0:
        nx.draw_networkx_edges(
            sub, pos, ax=ax,
            edge_color=edge_colors, width=edge_widths,
            arrows=True, arrowsize=15,
            connectionstyle="arc3,rad=0.08",
        )

    nx.draw_networkx_nodes(
        sub, pos, ax=ax,
        node_color=fill_colors, node_size=size_map,
        edgecolors=border_colors, linewidths=2.0,
    )

    labels = {n: n.replace("_", "\n") for n in nodes}
    nx.draw_networkx_labels(sub, pos, labels=labels, ax=ax,
                            font_size=8.5, font_weight="bold")

    ax.set_title(title, fontsize=13, fontweight="bold")

    # --- Legend ---
    legend_items = [
        ("M-bias collider (DO NOT adjust)", _NODE_COLORS["mbias"]),
        ("Parent of collider", _NODE_COLORS["mbias_parent"]),
        ("Exposure", _NODE_COLORS["exposure"]),
        ("Outcome", _NODE_COLORS["outcome"]),
    ]
    if confounder_set & set(nodes):
        legend_items.append(("Confounder", _NODE_COLORS["confounder"]))
    if any(n not in (mbias_node, exposure, outcome)
           and n not in mbias_parents and n not in confounder_set
           for n in nodes):
        legend_items.append(("Other node", _NODE_COLORS["other"]))

    legend_handles = [
        plt.Line2D([0], [0], marker="o", color="w", markerfacecolor=c,
                   markeredgecolor="black", markersize=10, label=l)
        for l, c in legend_items
    ]
    # Place legend in lower right corner (inside the plot)
    ax.legend(handles=legend_handles, loc="lower right", fontsize=9,
              framealpha=0.9, edgecolor="gray", title="Node Types")

    fig.tight_layout()
    fig.savefig(filepath, dpi=150, bbox_inches="tight")
    plt.close(fig)


def _save_mbias_reports(
    G: nx.DiGraph,
    mbias_result: dict,
    exposure: str,
    outcome: str,
    reports_dir: Path,
    confounder_set: set[str] | None = None,
) -> None:
    """Generate per-structure reports for M-bias with numbered subdirectories for duplicates."""
    if confounder_set is None:
        confounder_set = set()

    mbias_structures = mbias_result.get("mbias_structures", [])

    ensure_dir(reports_dir)

    # Track count for each collider to create numbered subdirectories
    structure_counts: dict[str, int] = {}

    for structure in mbias_structures:
        m = structure.get("collider", "")
        p1 = structure.get("p1", "")
        p2 = structure.get("p2", "")

        # Increment count for this collider
        structure_counts[m] = structure_counts.get(m, 0) + 1
        struct_num = structure_counts[m]

        # Create safe name with number suffix for duplicates
        safe_name = m.replace(" ", "_").replace("/", "_")
        if struct_num > 1:
            safe_name = f"{safe_name}__{struct_num}"

        node_dir = reports_dir / safe_name
        ensure_dir(node_dir)

        sub = _extract_mbias_subgraph(G, m, exposure, outcome, structure)

        # Save edge list
        with open(node_dir / "edges.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["from", "to"])
            for u, v in sub.edges():
                w.writerow([u, v])

        # Save subgraph as graphml
        nx.write_graphml(sub, str(node_dir / "subgraph.graphml"))

        # Simple title: collider name and bias type
        plot_title = f"{m} - M-Bias"
        if struct_num > 1:
            plot_title = f"{m} (#{struct_num}) - M-Bias"

        # Save as PDF
        plot_file = node_dir / f"MBIAS_{safe_name}.pdf"

        # Only pass the 2 M-structure parents for coloring
        mbias_parents_set = {p1, p2}

        _plot_mbias_subgraph(
            sub, m, exposure, outcome,
            title=plot_title,
            filepath=plot_file,
            confounder_set=confounder_set,
            mbias_parents=mbias_parents_set,
        )


# ── File I/O (matches R output format) ───────────────────────────────

_CSV_FIELDS = ["confounder", "n_confounder_parents", "confounder_parents", "is_butterfly"]


def save_results(
    output_dir: Path,
    exposure: str,
    outcome: str,
    graph: nx.DiGraph,
    confounder_info: dict,
    butterfly: dict,
    mbias: dict,
    is_acyclic: bool,
) -> None:
    """Save all analysis results matching R's output format."""
    ensure_dir(output_dir)

    # 1. butterfly_analysis_results.csv -- all confounders with parent counts
    with open(output_dir / "butterfly_analysis_results.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=_CSV_FIELDS)
        w.writeheader()
        w.writerows(butterfly["all_results"])

    # 2. butterfly_nodes.csv -- butterfly nodes only
    with open(output_dir / "butterfly_nodes.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=_CSV_FIELDS)
        w.writeheader()
        for r in butterfly["all_results"]:
            if r["is_butterfly"]:
                w.writerow(r)

    # 3. independent_confounders.csv
    with open(output_dir / "independent_confounders.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=_CSV_FIELDS)
        w.writeheader()
        for r in butterfly["all_results"]:
            if r["n_confounder_parents"] == 0:
                w.writerow(r)

    # 4. m_bias_results.csv (Python-only) - one row per structure
    if mbias["mbias_structures"]:
        with open(output_dir / "m_bias_results.csv", "w", newline="") as f:
            w = csv.writer(f)
            w.writerow(["collider", "p1_exposure_side", "p2_outcome_side"])
            for structure in mbias["mbias_structures"]:
                collider = structure.get("collider", "")
                p1 = structure.get("p1", "")
                p2 = structure.get("p2", "")
                w.writerow([collider, p1, p2])

    # 5. Confounder subgraph reports (plots + edges)
    confounder_set = {r["confounder"] for r in butterfly["all_results"]}
    butterfly_structures = butterfly.get("butterfly_structures", {})

    if butterfly["all_results"]:
        confounders_list = [r["confounder"] for r in butterfly["all_results"]]
        _save_node_reports(
            graph, confounders_list, exposure, outcome,
            output_dir / "reports" / "confounders", "Confounder",
            confounder_set=confounder_set,
            butterfly_structures=butterfly_structures,
        )

    # 6. Butterfly subgraph reports
    if butterfly["butterfly_vars"]:
        _save_node_reports(
            graph, butterfly["butterfly_vars"], exposure, outcome,
            output_dir / "reports" / "butterfly", "Butterfly",
            confounder_set=confounder_set,
            butterfly_structures=butterfly_structures,
        )

    # 7. M-bias subgraph reports (dedicated M-bias visuals)
    if mbias["mbias_vars"]:
        _save_mbias_reports(
            graph, mbias, exposure, outcome,
            output_dir / "reports" / "m_bias",
            confounder_set=confounder_set,
        )

    # 8. analysis_summary.txt -- matches R format
    _write_summary(
        output_dir / "analysis_summary.txt",
        exposure, outcome, graph, confounder_info, butterfly, mbias, is_acyclic,
    )


def _write_summary(
    path: Path,
    exposure: str,
    outcome: str,
    graph: nx.DiGraph,
    confounder_info: dict,
    butterfly: dict,
    mbias: dict,
    is_acyclic: bool,
) -> None:
    with open(path, "w") as f:
        f.write("=======================================================\n")
        f.write("Butterfly Bias Analysis Summary\n")
        f.write("=======================================================\n\n")
        f.write(f"Exposure: {exposure}\n")
        f.write(f"Outcome: {outcome}\n")
        f.write(f"Graph is Acyclic: {is_acyclic}\n")
        f.write(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")

        f.write("=== Method ===\n")
        f.write("Approach: direct parents/children (matching R dagitty logic)\n")
        f.write("Confounder = common parent of both exposure and outcome,\n")
        f.write("             excluding direct children of either.\n")
        f.write("Butterfly = confounder with 2+ other confounders as parents.\n")
        f.write("M-bias = children(parent_of_X) ∩ children(parent_of_Y),\n")
        f.write("         where P1 ≠ P2 and M ≠ X,Y and M is not a confounder.\n\n")

        f.write("=== Graph Statistics ===\n")
        f.write(f"Total nodes: {graph.number_of_nodes()}\n")
        f.write(f"Total edges: {graph.number_of_edges()}\n")
        f.write(f"Parents of exposure: {len(confounder_info['parents_exposure'])}\n")
        f.write(f"Parents of outcome: {len(confounder_info['parents_outcome'])}\n\n")

        f.write("=== Confounder Counts ===\n")
        f.write(f"Confounders identified: {butterfly['n_total']}\n\n")

        f.write("=== Butterfly Bias Results ===\n")
        f.write(f"Independent confounders: {butterfly['n_independent']}\n")
        f.write(f"Confounders with 1 parent: {butterfly['n_one_parent']}\n")
        f.write(f"BUTTERFLY candidates: {butterfly['n_butterfly']}\n\n")

        if butterfly["butterfly_vars"]:
            f.write("Butterfly nodes (DO NOT adjust for these directly):\n")
            for i, bfly in enumerate(butterfly["butterfly_vars"], 1):
                parents = butterfly["butterfly_parents"][bfly]
                f.write(f"  {i}. {bfly} <- {{{', '.join(parents)}}}\n")
            f.write("\nRECOMMENDATION: Instead of adjusting for butterfly nodes,\n")
            f.write("adjust for their confounder parents to avoid opening\n")
            f.write("collider paths.\n")
        else:
            f.write("No butterfly bias detected.\n")
            f.write("All confounders are independent and safe to adjust for.\n")

        f.write("\n=== All Confounders by Type ===\n")
        if butterfly["independent_confounders"]:
            f.write("\nINDEPENDENT (safe to adjust for):\n")
            for c in sorted(butterfly["independent_confounders"]):
                f.write(f"  - {c}\n")

        one_parent_rows = [r for r in butterfly["all_results"] if r["n_confounder_parents"] == 1]
        if one_parent_rows:
            f.write("\nHAS 1 CONFOUNDER PARENT (monitor but likely safe):\n")
            for r in one_parent_rows:
                f.write(f"  - {r['confounder']} <- {r['confounder_parents']}\n")

        if butterfly["butterfly_vars"]:
            f.write("\nBUTTERFLY (avoid adjusting directly):\n")
            for r in butterfly["all_results"]:
                if r["is_butterfly"]:
                    f.write(f"  - {r['confounder']} <- {{{r['confounder_parents']}}}\n")

        # M-bias section (Python-only addition)
        if mbias["mbias_vars"]:
            f.write("\n\n=== M-Bias Analysis (Python-only) ===\n")
            f.write("Detection: direct parent/child (top-down)\n")
            f.write(f"M-bias colliders found: {len(mbias['mbias_vars'])}\n")
            f.write(f"M-bias structures found: {len(mbias['mbias_structures'])}\n")
            f.write("\nThese nodes are colliders on backdoor paths.\n")
            f.write("Do NOT adjust for them -- it would open spurious paths.\n\n")
            for structure in mbias["mbias_structures"]:
                v = structure.get("collider", "?")
                p1 = structure.get("p1", "?")
                p2 = structure.get("p2", "?")
                f.write(f"  - {v}:  {exposure} ← {p1} → {v} ← {p2} → {outcome}\n")


# ── Graph loading ────────────────────────────────────────────────────

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


# ── Main entry point ─────────────────────────────────────────────────

def run_stage7(exposure: str, outcome: str) -> dict:
    """Execute Stage 7: Butterfly bias and M-bias analysis."""
    print_header("Bias Analysis -- Butterfly & M-Bias (Stage 7)", exposure, outcome)

    G = load_graph(exposure, outcome)
    output_dir = get_s7_bias_dir(exposure, outcome)
    ensure_dir(output_dir)

    is_acyclic = nx.is_directed_acyclic_graph(G)
    print(f"Graph: {G.number_of_nodes()} nodes, {G.number_of_edges()} edges")
    print(f"Is acyclic (DAG): {is_acyclic}")
    if not is_acyclic:
        print("WARNING: Graph has cycles. Results use direct parent/child logic")
        print("         which works with cycles (same as R dagitty approach).\n")

    if exposure not in G:
        raise ValueError(f"Exposure '{exposure}' not found in graph")
    if outcome not in G:
        raise ValueError(f"Outcome '{outcome}' not found in graph")

    # --- Step 1: Identify confounders (R dagitty approach) ---
    print("\n=== 1. CONFOUNDER IDENTIFICATION ===")
    print("Using direct parents/children (matching R dagitty logic)")

    confounder_info = identify_confounders(G, exposure, outcome)
    confounders = confounder_info["confounders"]

    print(f"Parents of exposure: {len(confounder_info['parents_exposure'])}")
    print(f"Parents of outcome: {len(confounder_info['parents_outcome'])}")
    print(f"Children of exposure: {len(confounder_info['children_exposure'])}")
    print(f"Children of outcome: {len(confounder_info['children_outcome'])}")
    print(f"Confounders identified: {len(confounders)}")

    # --- Step 2: Butterfly bias detection ---
    # (Only runs if confounders exist)
    if confounders:
        print("\n=== 2. BUTTERFLY BIAS DETECTION ===")
        print("Checking each confounder's parents among other confounders...\n")

        butterfly = analyze_butterfly_bias(G, exposure, outcome, confounders)

        for r in butterfly["all_results"]:
            if r["n_confounder_parents"] == 0:
                print(f"  {r['confounder']}: character(0)")
            else:
                marker = " *** BUTTERFLY ***" if r["is_butterfly"] else ""
                print(f"  {r['confounder']}: [{r['confounder_parents']}]{marker}")

        print(f"\nTotal confounders: {butterfly['n_total']}")
        print(f"Independent (no confounder parents): {butterfly['n_independent']}")
        print(f"Has 1 confounder parent: {butterfly['n_one_parent']}")
        print(f"BUTTERFLY candidates (2+ confounder parents): {butterfly['n_butterfly']}")

        if butterfly["butterfly_vars"]:
            print("\nButterfly nodes:")
            for i, bfly in enumerate(butterfly["butterfly_vars"], 1):
                parents = butterfly["butterfly_parents"][bfly]
                print(f"  {i}. {bfly} <- {{{', '.join(parents)}}} ({len(parents)} parents)")
    else:
        print("\n=== 2. BUTTERFLY BIAS DETECTION ===")
        print("No confounders found - skipping butterfly analysis.")
        butterfly = {
            "all_results": [],
            "butterfly_vars": [],
            "butterfly_parents": {},
            "butterfly_structures": {},
            "independent_confounders": [],
            "has_one_parent": [],
            "n_total": 0,
            "n_independent": 0,
            "n_one_parent": 0,
            "n_butterfly": 0,
        }

    # --- Step 3: M-bias analysis (Python-only addition) ---
    print("\n=== 3. M-BIAS ANALYSIS (additional) ===")
    print("Using direct parent/child approach (top-down)")
    mbias = analyze_m_bias(G, exposure, outcome, confounders)

    if mbias["mbias_vars"]:
        print(f"M-bias colliders found: {len(mbias['mbias_vars'])}")
        print(f"M-bias structures found: {len(mbias['mbias_structures'])}")
        for structure in mbias["mbias_structures"]:
            v = structure.get("collider", "?")
            p1 = structure.get("p1", "?")
            p2 = structure.get("p2", "?")
            print(f"  - {v}:  {exposure} ← {p1} → {v} ← {p2} → {outcome}")
    else:
        print("No M-bias variables found.")

    # --- Step 4: Save results ---
    print("\n=== 4. SAVING RESULTS ===")
    save_results(output_dir, exposure, outcome, G, confounder_info,
                 butterfly, mbias, is_acyclic)

    print("Saved butterfly_analysis_results.csv")
    print("Saved butterfly_nodes.csv")
    print("Saved independent_confounders.csv")
    if mbias["mbias_vars"]:
        print("Saved m_bias_results.csv")
    print("Saved analysis_summary.txt")
    n_reports = butterfly["n_total"] + butterfly["n_butterfly"] + len(mbias["mbias_structures"])
    if n_reports > 0:
        print(f"Saved {n_reports} subgraph reports (plots + edges) in reports/")
    print(f"All outputs in: {output_dir}")

    print_complete("Bias Analysis (Stage 7)")

    return {
        "n_confounders": butterfly["n_total"],
        "n_butterfly": butterfly["n_butterfly"],
        "n_independent": butterfly["n_independent"],
        "n_mbias": len(mbias["mbias_vars"]),
        "butterfly_vars": butterfly["butterfly_vars"],
        "is_dag": is_acyclic,
    }


if __name__ == "__main__":
    args = parse_args("Stage 7: Butterfly bias and M-bias analysis")
    run_stage7(args.exposure, args.outcome)
