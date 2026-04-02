#!/usr/bin/env python3
"""
bias/plot_bias.py
Visualise M-bias and Butterfly bias results from JSON reports produced by
bias/run_bias_analysis_json.py.

Usage (run from the project root):
    python bias/plot_bias.py [options]

Options:
    --mbias-report PATH       Path to m_bias_report.json
    --butterfly-report PATH   Path to butterfly_bias_report.json
    --output-dir DIR          Where to save PNGs (default: bias/)

Examples:
    # Use default paths (bias/m_bias_report.json, bias/butterfly_bias_report.json)
    python bias/plot_bias.py

    # Explicit paths
    python bias/plot_bias.py \
        --mbias-report bias/m_bias_report.json \
        --butterfly-report bias/butterfly_bias_report.json \
        --output-dir bias/

Outputs:
    variable_roles_summary.png   — bar chart of every variable-role count
    mbias_collider_detail.png    — small subgraph per M-bias variable (collider view)
    butterfly_summary.png        — butterfly confounder parent-count chart
"""

import argparse
import json
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")          # headless — no display needed
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import networkx as nx
import numpy as np

# ── colour palette ───────────────────────────────────────────────────────────
COL = {
    "exposure":    "#E45C3A",   # warm red
    "outcome":     "#4A90D9",   # blue
    "mbias":       "#F5A623",   # amber
    "butterfly":   "#9B59B6",   # purple
    "confounder":  "#27AE60",   # green
    "mediator":    "#1ABC9C",   # teal
    "collider":    "#E74C3C",   # red
    "precision":   "#3498DB",   # sky blue
    "iv":          "#95A5A6",   # grey
    "bar_bg":      "#ECF0F1",
}

_BIAS_DIR = Path(__file__).resolve().parent


# ── helpers ──────────────────────────────────────────────────────────────────

def _load(path: Path) -> dict | None:
    if not path.exists():
        print(f"  [skip] not found: {path}", file=sys.stderr)
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def _title_prefix(data: dict) -> str:
    exp = data.get("exposure", "?")
    out = data.get("outcome", "?")
    return f"{exp} → {out}"


# ── Plot 1: variable roles summary ───────────────────────────────────────────

def plot_variable_roles(bfly: dict | None, mbias: dict | None, out_dir: Path) -> None:
    """Horizontal bar chart of every causal-role count."""
    # Gather role counts from butterfly report (contains full roles dict)
    roles = (bfly or {}).get("roles", {})

    categories = [
        ("Confounders",          len(roles.get("confounders", [])),          COL["confounder"]),
        ("Mediators",            len(roles.get("mediators", [])),             COL["mediator"]),
        ("Colliders",            len(roles.get("colliders", [])),             COL["collider"]),
        ("Precision variables",  len(roles.get("precision_variables", [])),   COL["precision"]),
        ("Instrumental vars",    len(roles.get("instrumental_variables", [])),COL["iv"]),
        ("Adjustment set",       len(roles.get("adjustment_set", [])),        COL["confounder"]),
        ("M-bias variables",     len((mbias or {}).get("mbias_vars", [])),    COL["mbias"]),
        ("Butterfly variables",  len((bfly or {}).get("butterfly_vars", [])), COL["butterfly"]),
    ]

    labels = [c[0] for c in categories]
    values = [c[1] for c in categories]
    colors = [c[2] for c in categories]

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.barh(labels, values, color=colors, edgecolor="white", height=0.6)

    # value labels on bars
    for bar, val in zip(bars, values):
        ax.text(bar.get_width() + max(values) * 0.01, bar.get_y() + bar.get_height() / 2,
                str(val), va="center", ha="left", fontsize=10, fontweight="bold")

    prefix = _title_prefix(bfly or mbias or {})
    ax.set_title(f"Variable Roles Summary\n{prefix}", fontsize=13, fontweight="bold", pad=12)
    ax.set_xlabel("Count", fontsize=11)
    ax.set_xlim(0, max(values) * 1.15 if max(values) > 0 else 10)
    ax.invert_yaxis()
    ax.spines[["top", "right"]].set_visible(False)
    ax.set_facecolor(COL["bar_bg"])
    fig.patch.set_facecolor("white")
    fig.tight_layout()

    out = out_dir / "variable_roles_summary.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: {out}")


# ── Plot 2: M-bias collider detail ───────────────────────────────────────────

def _draw_mbias_subgraph(ax, var: str, details: dict, exposure: str, outcome: str) -> None:
    """
    Draw the actual M-bias causal structure for *var* onto *ax*.

    Classic M-bias structure:
        Exposure ──────────────────► Outcome
            │                            │
            ▼                            ▼
           (parent_a) ──► M ◄── (parent_b)

    When both parents are the exposure and outcome themselves the shape is:
        Exposure ──────────────────► Outcome
            └──────────► M ◄────────────┘
    Conditioning on M opens the backdoor path Exposure ↔ M ↔ Outcome.
    """
    parents     = details.get("parents", [])
    sample_path = details.get("sample_path", [])

    # ── fixed positions ──────────────────────────────────────────────────────
    # Two parents sit at top-left / top-right; collider sits at bottom-centre.
    # Extra (non-exposure, non-outcome) parents fan out above the collider.
    role_map = {exposure: "exposure", outcome: "outcome", var: "collider"}

    exp_parents  = [p for p in parents if p == exposure]
    out_parents  = [p for p in parents if p == outcome]
    other_parents = [p for p in parents if p not in (exposure, outcome)]

    # Build node list in display order
    top_nodes    = exp_parents + other_parents + out_parents
    all_nodes    = top_nodes + [var]

    n_top = max(len(top_nodes), 1)
    # Spread top nodes evenly across x ∈ [0, 1]
    pos = {}
    for i, n in enumerate(top_nodes):
        pos[n] = np.array([(i + 0.5) / n_top, 1.0])
    pos[var] = np.array([0.5, 0.0])   # collider at the bottom-centre

    # ── build directed graph ─────────────────────────────────────────────────
    G = nx.DiGraph()
    for n in all_nodes:
        G.add_node(n)
    for p in parents:
        G.add_edge(p, var)

    # ── colours ──────────────────────────────────────────────────────────────
    def _node_col(n):
        if n == exposure:  return COL["exposure"]
        if n == outcome:   return COL["outcome"]
        if n == var:       return COL["mbias"]
        return COL["iv"]

    node_colors = [_node_col(n) for n in G.nodes()]
    node_sizes  = [900 if n == var else 700 for n in G.nodes()]

    # ── draw ─────────────────────────────────────────────────────────────────
    nx.draw_networkx_nodes(G, pos, ax=ax, node_color=node_colors,
                           node_size=node_sizes, alpha=0.93)

    # Wrap labels at underscores
    labels = {n: n.replace("_", "\n") for n in G.nodes()}
    nx.draw_networkx_labels(G, pos, labels=labels, ax=ax,
                            font_size=6, font_weight="bold", font_color="white")

    nx.draw_networkx_edges(
        G, pos, ax=ax,
        edge_color="#333333", arrows=True, arrowsize=18,
        width=2.0, node_size=800,
        connectionstyle="arc3,rad=0.05",
        min_source_margin=12, min_target_margin=12,
    )

    # ── role annotations next to each top node ────────────────────────────────
    for n, (x, y) in pos.items():
        if n == exposure:
            ax.text(x, y + 0.12, "Exposure", ha="center", va="bottom",
                    fontsize=5.5, color=COL["exposure"], fontweight="bold",
                    transform=ax.transData)
        elif n == outcome:
            ax.text(x, y + 0.12, "Outcome", ha="center", va="bottom",
                    fontsize=5.5, color=COL["outcome"], fontweight="bold",
                    transform=ax.transData)

    # ── collider warning at the bottom ───────────────────────────────────────
    ax.text(0.5, -0.18,
            "⚠ Collider — do NOT condition on this variable",
            ha="center", va="top", fontsize=5.5, color="#C0392B",
            fontstyle="italic", transform=ax.transAxes)

    # ── sample path annotation ────────────────────────────────────────────────
    if sample_path:
        path_str = " → ".join(p.replace("_", " ") for p in sample_path)
        ax.text(0.5, -0.30,
                f"Path: {path_str}",
                ha="center", va="top", fontsize=5, color="#555555",
                transform=ax.transAxes, wrap=True)

    ax.set_title(var.replace("_", " "),
                 fontsize=7.5, fontweight="bold", pad=6, color="#2C3E50")
    ax.set_xlim(-0.15, 1.15)
    ax.set_ylim(-0.45, 1.25)
    ax.axis("off")


def plot_mbias_colliders(mbias: dict, out_dir: Path) -> None:
    """Grid of M-bias structure diagrams, one per M-bias collider variable."""
    mbias_vars = mbias.get("mbias_vars", [])
    details    = mbias.get("mbias_details", {})
    exposure   = mbias.get("exposure", "")
    outcome    = mbias.get("outcome", "")

    if not mbias_vars:
        fig, ax = plt.subplots(figsize=(6, 3))
        ax.text(0.5, 0.5, "No M-bias variables detected.", ha="center", va="center",
                fontsize=14, color="#555555", transform=ax.transAxes)
        ax.axis("off")
        out = out_dir / "mbias_collider_detail.png"
        fig.savefig(out, dpi=150, bbox_inches="tight")
        plt.close(fig)
        print(f"  Saved: {out}")
        return

    MAX_SHOWN = 12
    shown = mbias_vars[:MAX_SHOWN]
    ncols = min(3, len(shown))
    nrows = (len(shown) + ncols - 1) // ncols

    fig, axes = plt.subplots(nrows, ncols,
                             figsize=(ncols * 4.5, nrows * 4.2))
    axes = np.array(axes).flatten() if nrows * ncols > 1 else [axes]

    for i, var in enumerate(shown):
        _draw_mbias_subgraph(axes[i], var, details.get(var, {}), exposure, outcome)

    # hide unused subplot panels
    for j in range(len(shown), len(axes)):
        axes[j].axis("off")

    # legend
    legend_handles = [
        mpatches.Patch(color=COL["exposure"],  label=f"Exposure ({exposure})"),
        mpatches.Patch(color=COL["outcome"],   label=f"Outcome ({outcome})"),
        mpatches.Patch(color=COL["mbias"],     label="M-bias collider (do not adjust)"),
        mpatches.Patch(color=COL["iv"],        label="Other confounder parent"),
    ]
    fig.legend(handles=legend_handles, loc="lower center", ncol=4,
               fontsize=8, frameon=True, bbox_to_anchor=(0.5, -0.02))

    capped  = mbias.get("capped", False)
    caption = f"(showing {len(shown)} of {len(mbias_vars)})" if capped else ""
    prefix  = _title_prefix(mbias)
    fig.suptitle(
        f"M-Bias Structures Present in Graph  {caption}\n"
        f"{prefix}\n"
        "Each diagram shows a collider (amber) with its parents — "
        "conditioning on the collider opens a spurious path.",
        fontsize=10, fontweight="bold", y=1.02,
    )
    fig.tight_layout(rect=[0, 0.04, 1, 1])

    out = out_dir / "mbias_collider_detail.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: {out}")


# ── Plot 3: Butterfly bias summary ───────────────────────────────────────────

def plot_butterfly_summary(bfly: dict, out_dir: Path) -> None:
    """Two-panel figure: confounder parent-count bars + valid-set sizes."""
    butterfly_vars    = bfly.get("butterfly_vars", [])
    butterfly_parents = bfly.get("butterfly_parents", {})
    non_bfly          = bfly.get("non_butterfly_confounders", [])
    valid_sets        = bfly.get("valid_sets", [])
    prefix            = _title_prefix(bfly)

    fig, axes = plt.subplots(1, 2, figsize=(14, 5))
    fig.suptitle(f"Butterfly Bias Summary\n{prefix}", fontsize=13,
                 fontweight="bold", y=1.02)

    # ── left panel: confounder parent-count bar chart ─────────────────
    ax = axes[0]
    if butterfly_vars:
        parent_counts = {v: len(butterfly_parents.get(v, [])) for v in butterfly_vars}
        sorted_vars   = sorted(parent_counts, key=lambda v: -parent_counts[v])
        labels        = [v.replace("_", " ") for v in sorted_vars]
        counts        = [parent_counts[v] for v in sorted_vars]

        bars = ax.barh(labels, counts, color=COL["butterfly"],
                       edgecolor="white", height=0.55)
        for bar, cnt in zip(bars, counts):
            ax.text(bar.get_width() + 0.05, bar.get_y() + bar.get_height() / 2,
                    str(cnt), va="center", ha="left", fontsize=10, fontweight="bold")

        ax.set_title("Butterfly Confounders\n(# confounder parents ≥ 2)",
                     fontsize=11, fontweight="bold")
        ax.set_xlabel("# Confounder parents")
        ax.invert_yaxis()
        ax.set_xlim(0, max(counts) * 1.2)
    else:
        ax.text(0.5, 0.6, "✓  No butterfly bias\n    variables detected.",
                ha="center", va="center", fontsize=14, color="#27AE60",
                fontweight="bold", transform=ax.transAxes)
        n_conf = len(non_bfly)
        ax.text(0.5, 0.35,
                f"{n_conf} non-butterfly confounder{'s' if n_conf != 1 else ''}",
                ha="center", va="center", fontsize=11, color="#555555",
                transform=ax.transAxes)
        ax.set_title("Butterfly Confounders", fontsize=11, fontweight="bold")

    ax.spines[["top", "right"]].set_visible(False)
    ax.set_facecolor(COL["bar_bg"])

    # ── right panel: valid adjustment set sizes ───────────────────────
    ax2 = axes[1]
    if valid_sets:
        set_sizes = sorted([len(s) for s in valid_sets])
        # histogram of set sizes
        unique_sizes, counts_per_size = np.unique(set_sizes, return_counts=True)
        ax2.bar(unique_sizes.astype(str), counts_per_size,
                color=COL["confounder"], edgecolor="white", width=0.55)
        ax2.set_title("Valid Adjustment Set Sizes\n(butterfly-safe)",
                      fontsize=11, fontweight="bold")
        ax2.set_xlabel("Set size (# variables)")
        ax2.set_ylabel("# valid sets")
        for x, cnt in zip(unique_sizes.astype(str), counts_per_size):
            ax2.text(x, cnt + max(counts_per_size) * 0.02, str(cnt),
                     ha="center", va="bottom", fontsize=10, fontweight="bold")
    else:
        ax2.text(0.5, 0.5, "No valid sets computed.", ha="center", va="center",
                 fontsize=12, color="#555555", transform=ax2.transAxes)
        ax2.set_title("Valid Adjustment Sets", fontsize=11, fontweight="bold")

    ax2.spines[["top", "right"]].set_visible(False)
    ax2.set_facecolor(COL["bar_bg"])

    fig.tight_layout()
    out = out_dir / "butterfly_summary.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print(f"  Saved: {out}")


# ── CLI ──────────────────────────────────────────────────────────────────────

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Plot M-bias and Butterfly bias results from JSON reports.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "--mbias-report",
        default=str(_BIAS_DIR / "m_bias_report.json"),
        help="Path to m_bias_report.json  (default: bias/m_bias_report.json).",
    )
    parser.add_argument(
        "--butterfly-report",
        default=str(_BIAS_DIR / "butterfly_bias_report.json"),
        help="Path to butterfly_bias_report.json  (default: bias/butterfly_bias_report.json).",
    )
    parser.add_argument(
        "--output-dir", "-o",
        default=str(_BIAS_DIR),
        help="Directory for output PNG files  (default: bias/).",
    )
    return parser.parse_args()


def main() -> None:
    args  = parse_args()
    bfly  = _load(Path(args.butterfly_report))
    mbias = _load(Path(args.mbias_report))

    if bfly is None and mbias is None:
        print("Error: no report files found.  Run bias/run_bias_analysis_json.py first.",
              file=sys.stderr)
        sys.exit(1)

    out_dir = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    print("Generating plots...")

    if bfly is not None or mbias is not None:
        plot_variable_roles(bfly, mbias, out_dir)

    if mbias is not None:
        plot_mbias_colliders(mbias, out_dir)

    if bfly is not None:
        plot_butterfly_summary(bfly, out_dir)

    print("Done.")


if __name__ == "__main__":
    main()

