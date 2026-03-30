#!/usr/bin/env python3
"""
run_pipeline.py
Orchestrate the full Post-CKT Analysis Pipeline (Stages 1-7).

Usage:
    python -m causal_analysis.run_pipeline Hypertension Alzheimers
    python -m causal_analysis.run_pipeline Hypertension Alzheimers --degree 2
    python -m causal_analysis.run_pipeline Hypertension Alzheimers --skip-causal

Stages:
    1. Graph Parsing       — JSON → NetworkX DiGraph
    2. Basic Analysis       — degree, centrality, SCC overview
    3. Cycle Analysis       — full cycle enumeration and participation
    4. Node Removal         — generic-node pruning and impact measurement
    5. Post-Removal         — residual cycle analysis after pruning
    6. Causal Inference     — adjustment sets & instrumental variables (DAG only)
    7. Bias Analysis        — butterfly bias & M-bias detection
"""

import argparse
import sys
import time

from .config import GRAPH_CONFIG
from .utils import create_all_stage_dirs, print_header, print_complete
from .s1_graph_parsing import run_stage1
from .s2_basic_analysis import run_stage2
from .s3_cycle_analysis import run_stage3
from .s4_node_removal import run_stage4
from .s5_post_removal import run_stage5
from .s6_causal_inference import run_stage6
from .s7_bias_analysis import run_stage7


def main():
    parser = argparse.ArgumentParser(
        description="Run the full Post-CKT Causal Analysis Pipeline"
    )
    parser.add_argument("exposure", help="Exposure name (e.g. Hypertension)")
    parser.add_argument("outcome", help="Outcome name (e.g. Alzheimers)")
    parser.add_argument(
        "--degree", type=int, default=GRAPH_CONFIG["default_degree"],
        help="Graph degree (default: 2)"
    )
    parser.add_argument(
        "--skip-causal", action="store_true",
        help="Skip Stage 6 (causal inference) even if the graph is a DAG"
    )
    args = parser.parse_args()

    exposure = args.exposure
    outcome = args.outcome
    degree = args.degree

    print_header("Post-CKT Analysis Pipeline", exposure, outcome)
    t_start = time.time()

    # Create all output directories
    create_all_stage_dirs(exposure, outcome)

    # Stage 1 — Graph Parsing
    print("\n" + "=" * 60)
    print("STAGE 1: Graph Parsing")
    print("=" * 60)
    G = run_stage1(exposure, outcome, degree)

    # Stage 2 — Basic Analysis
    print("\n" + "=" * 60)
    print("STAGE 2: Basic Analysis")
    print("=" * 60)
    s2 = run_stage2(exposure, outcome)

    # Stage 3 — Cycle Extraction & Participation
    print("\n" + "=" * 60)
    print("STAGE 3: Cycle Extraction & Participation")
    print("=" * 60)
    s3 = run_stage3(exposure, outcome)

    # Stage 4 — Node Removal Impact
    print("\n" + "=" * 60)
    print("STAGE 4: Node Removal Impact")
    print("=" * 60)
    s4 = run_stage4(exposure, outcome)

    # Stage 5 — Post-Removal Analysis
    print("\n" + "=" * 60)
    print("STAGE 5: Post-Removal Analysis")
    print("=" * 60)
    s5 = run_stage5(exposure, outcome)

    # Stage 6 — Causal Inference (only if DAG achieved)
    s6 = None
    if not args.skip_causal and s4.get("is_dag"):
        print("\n" + "=" * 60)
        print("STAGE 6: Causal Inference")
        print("=" * 60)
        try:
            s6 = run_stage6(exposure, outcome)
        except ValueError as e:
            print(f"Skipping causal inference: {e}")
    elif not s4.get("is_dag"):
        print("\n" + "=" * 60)
        print("STAGE 6: SKIPPED — graph is not a DAG after node removal")
        print("Review Stage 5 output and add more nodes to GENERIC_NODES.")
        print("=" * 60)
    else:
        print("\n" + "=" * 60)
        print("STAGE 6: SKIPPED (--skip-causal)")
        print("=" * 60)

    # Stage 7 — Bias Analysis (butterfly + M-bias)
    s7 = None
    print("\n" + "=" * 60)
    print("STAGE 7: Bias Analysis (Butterfly & M-Bias)")
    print("=" * 60)
    try:
        s7 = run_stage7(exposure, outcome)
    except Exception as e:
        print(f"Stage 7 failed: {e}")

    # --- Final summary ---
    elapsed = time.time() - t_start
    print("\n")
    print("=" * 60)
    print("PIPELINE COMPLETE")
    print("=" * 60)
    print(f"Exposure:          {exposure}")
    print(f"Outcome:           {outcome}")
    print(f"Total time:        {elapsed:.1f}s")
    print(f"Original nodes:    {s2['n_nodes']}")
    print(f"Original edges:    {s2['n_edges']}")
    print(f"Baseline cycles:   {s3.get('total_cycles', 'N/A'):,}")
    print(f"Nodes removed:     {s4.get('nodes_removed', 0)}")
    print(f"Post-removal cycles: {s5.get('total_cycles', 'N/A'):,}")
    print(f"Is DAG:            {s4.get('is_dag', False)}")
    if s6:
        print(f"Adjustment set:    {len(s6['adjustment_set'])} nodes")
        print(f"Instruments:       {len(s6['instruments'])} candidates")
    if s7:
        print(f"Confounders:       {s7.get('n_confounders', 0)}")
        print(f"Butterfly nodes:   {s7.get('n_butterfly', 0)}")
        print(f"M-bias nodes:      {s7.get('n_mbias', 0)}")
    print("=" * 60)


if __name__ == "__main__":
    main()

