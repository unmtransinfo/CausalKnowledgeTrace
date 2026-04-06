"""
utils.py
Shared utility functions for the Post-CKT Analysis Pipeline (Python version).
Mirrors furtherAnalysis/post_ckt/scripts/utils.R
"""

import os
import glob
import re
import argparse
from pathlib import Path
from datetime import datetime

from .config import STAGES, FILE_CONFIG, GRAPH_CONFIG


# ============================================
# PROJECT ROOT DETECTION
# ============================================

def get_repo_root() -> Path:
    """Walk up from this file to find the repository root (contains graph_creation/)."""
    current = Path(__file__).resolve().parent
    for _ in range(10):
        if (current / "graph_creation").is_dir() or (current / ".git").is_dir():
            return current
        current = current.parent
    raise RuntimeError("Could not find repository root from " + str(Path(__file__).resolve()))


def get_data_dir() -> Path:
    """Base data output directory: causal_analysis/data/"""
    return Path(__file__).resolve().parent / "data"


def get_graph_creation_result_dir() -> Path:
    return get_repo_root() / "graph_creation" / "result"


# ============================================
# EXPOSURE / OUTCOME HELPERS
# ============================================

def get_subdir_name(exposure: str, outcome: str) -> str:
    return f"{exposure}_{outcome}"


def get_pair_dir(exposure: str, outcome: str) -> Path:
    return get_data_dir() / get_subdir_name(exposure, outcome)


# ============================================
# STAGE-BASED PATH GETTERS
# ============================================

def get_stage_dir(exposure: str, outcome: str, stage: str) -> Path:
    return get_pair_dir(exposure, outcome) / stage


def get_s1_graph_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S1_GRAPH"])


def get_s2_semantic_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S2_SEMANTIC"])


def get_s3_cycles_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S3_CYCLES"])


def get_s4_node_removal_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S4_NODE_REMOVAL"])


def get_s5_post_removal_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S5_POST_REMOVAL"])


def get_s7_bias_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S7_BIAS"])


def get_s8_other_bias_dir(exposure: str, outcome: str) -> Path:
    return get_stage_dir(exposure, outcome, STAGES["S8_OTHER_BIAS"])


# ============================================
# DIRECTORY UTILITIES
# ============================================

def ensure_dir(path: Path) -> Path:
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True)
    return path


def create_all_stage_dirs(exposure: str, outcome: str) -> None:
    for stage in STAGES.values():
        ensure_dir(get_stage_dir(exposure, outcome, stage))
        plots_dir = get_stage_dir(exposure, outcome, stage) / "plots"
        ensure_dir(plots_dir)


# ============================================
# INPUT FILE HELPERS
# ============================================

def extract_degree_from_path(filepath: str) -> int | None:
    filename = os.path.basename(filepath)
    m = re.search(r"_degree(\d+)(?:_causal_assertions)?\.json$", filename)
    if m:
        return int(m.group(1))
    m = re.search(r"_degree_(\d+)\.(R|json)$", filename)
    if m:
        return int(m.group(1))
    return None


def find_assertions_json(exposure: str, outcome: str, degree: int = 2) -> Path | None:
    """Find the causal assertions JSON file for an exposure/outcome pair."""
    search_dirs = [get_graph_creation_result_dir()]
    for d in search_dirs:
        exact = d / FILE_CONFIG["assertions_json_pattern"].format(
            exposure=exposure, outcome=outcome, degree=degree
        )
        if exact.is_file():
            return exact
    # Fallback: glob for any matching file
    for d in search_dirs:
        if not d.is_dir():
            continue
        pattern = f"{exposure}_to_{outcome}_degree*_causal_assertions.json"
        matches = sorted(d.glob(pattern), reverse=True)
        if matches:
            return matches[0]
    return None


def find_graph_json(exposure: str, outcome: str, degree: int = 2) -> Path | None:
    """Find the Cytoscape graph JSON file for an exposure/outcome pair."""
    search_dirs = [get_graph_creation_result_dir()]
    for d in search_dirs:
        exact = d / FILE_CONFIG["graph_json_pattern"].format(
            exposure=exposure, outcome=outcome, degree=degree
        )
        if exact.is_file():
            return exact
    for d in search_dirs:
        if not d.is_dir():
            continue
        pattern = f"{exposure}_to_{outcome}_degree*.json"
        matches = [p for p in d.glob(pattern) if "causal_assertions" not in p.name]
        if matches:
            return sorted(matches, reverse=True)[0]
    return None


# ============================================
# CLI ARGUMENT PARSING
# ============================================

def parse_args(description: str = "Post-CKT Pipeline Stage") -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("exposure", help="Exposure name (e.g. Hypertension)")
    parser.add_argument("outcome", help="Outcome name (e.g. Alzheimers)")
    parser.add_argument("--degree", type=int, default=GRAPH_CONFIG["default_degree"],
                        help="Graph degree (default: 2)")
    return parser.parse_args()


# ============================================
# LOGGING UTILITIES
# ============================================

def print_header(script_name: str, exposure: str, outcome: str) -> None:
    print()
    print("=" * 50)
    print(script_name)
    print("=" * 50)
    print(f"Exposure: {exposure}")
    print(f"Outcome: {outcome}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 50)
    print()


def print_complete(script_name: str) -> None:
    print()
    print("=" * 50)
    print(f"{script_name} - COMPLETE")
    print("=" * 50)
    print()

