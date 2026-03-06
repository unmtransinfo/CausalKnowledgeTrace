"""
s7_bias_analysis.py
Stage 7: M-Bias and Butterfly Bias Analysis.

Ported from furtherAnalysis/MnButterflyBiasReport.R.
Uses NetworkX graph-theoretic operations to implement:
  - Variable role classification (confounders, colliders, mediators, IVs, precision)
  - Butterfly bias detection (confounders with ≥2 confounder parents)
  - M-bias detection (colliders on backdoor paths that should NOT be adjusted)

Works on DAGs.  For cyclic graphs, results carry a warning.
"""

import itertools
import logging
from typing import Any

import networkx as nx

from .s6_causal_inference import find_adjustment_sets, find_instrumental_variables

logger = logging.getLogger(__name__)


# ── Helper: reachability on undirected skeleton ──────────────────────

def _on_undirected_path(G: nx.DiGraph, source: str, target: str,
                        node: str) -> bool:
    """Check if *node* lies on some simple path between *source* and *target*
    on the undirected skeleton of G.

    Instead of enumerating all paths (exponential), we use a two-BFS trick:
    remove *node* from the undirected skeleton and check whether *source* and
    *target* become disconnected.  If they do, *node* is a cut-vertex on every
    path.  If they don't, we still need to verify *node* is reachable from
    both endpoints — which means it lies on *some* path.

    Simplified O(n+e) approach: node is on some undirected path between
    source and target iff node is in the same connected component as both
    source and target on the undirected skeleton.
    """
    U = G.to_undirected(as_view=True)
    try:
        component = nx.node_connected_component(U, source)
        return target in component and node in component
    except (nx.NetworkXError, nx.NodeNotFound):
        return False


def _sample_path_through(U: nx.Graph, source: str, target: str,
                         node: str) -> list[str] | None:
    """Find ONE sample undirected path from source→node→target (if exists).
    Uses two shortest-path lookups on the pre-computed undirected skeleton *U*.
    Returns None if no path found."""
    try:
        path_s_v = nx.shortest_path(U, source, node)
        path_v_t = nx.shortest_path(U, node, target)
        # Combine avoiding duplicate of node
        return path_s_v + path_v_t[1:]
    except (nx.NetworkXError, nx.NodeNotFound, nx.NetworkXNoPath):
        return None


# ── Variable role identification ─────────────────────────────────────

def identify_variable_roles(G: nx.DiGraph, exposure: str, outcome: str) -> dict[str, Any]:
    """Classify every node into causal roles relative to exposure/outcome.

    Returns a dict with keys:
        exposure, outcome,
        adjustment_set          – from find_adjustment_sets (backdoor criterion)
        instrumental_variables  – from find_instrumental_variables
        confounders, mediators, colliders,
        precision_variables,
        raw_mediators, raw_colliders
    """
    if exposure not in G or outcome not in G:
        return _empty_roles(exposure, outcome)

    exp_out = {exposure, outcome}
    anc_exp = nx.ancestors(G, exposure)
    anc_out = nx.ancestors(G, outcome)
    desc_exp = nx.descendants(G, exposure)
    desc_out = nx.descendants(G, outcome)

    # Raw role sets (before refinement)
    raw_mediators = (desc_exp & anc_out) - exp_out
    raw_colliders = (desc_exp & desc_out) - exp_out

    # Instrumental variables (from s6)
    ivs = set(find_instrumental_variables(G, exposure, outcome))

    # Precision variables: ancestors of outcome but NOT of exposure, not mediators
    raw_precision = anc_out - anc_exp
    precision_variables = raw_precision - exp_out - raw_mediators

    # Confounders: common ancestors of both, excluding IVs
    adjustment_set = set(find_adjustment_sets(G, exposure, outcome))
    raw_confounders = anc_exp & anc_out
    confounders = (raw_confounders - ivs) & adjustment_set

    # Refined sets (mutually exclusive)
    colliders = raw_colliders - raw_mediators - confounders
    mediators = raw_mediators - raw_colliders - confounders

    return {
        'exposure': exposure,
        'outcome': outcome,
        'adjustment_set': sorted(adjustment_set),
        'instrumental_variables': sorted(ivs),
        'precision_variables': sorted(precision_variables),
        'confounders': sorted(confounders),
        'mediators': sorted(mediators),
        'colliders': sorted(colliders),
        'raw_mediators': sorted(raw_mediators),
        'raw_colliders': sorted(raw_colliders),
    }


def _empty_roles(exposure: str, outcome: str) -> dict[str, Any]:
    return {
        'exposure': exposure, 'outcome': outcome,
        'adjustment_set': [], 'instrumental_variables': [],
        'precision_variables': [], 'confounders': [],
        'mediators': [], 'colliders': [],
        'raw_mediators': [], 'raw_colliders': [],
    }


# ── Butterfly bias analysis ──────────────────────────────────────────

def analyze_butterfly_bias(G: nx.DiGraph, exposure: str, outcome: str,
                           roles: dict[str, Any] | None = None) -> dict[str, Any]:
    """Detect butterfly bias: confounders with ≥2 confounder parents.

    Args:
        roles: Pre-computed variable roles (optional). If None, computed here.

    Returns dict with:
        roles, butterfly_vars, butterfly_parents,
        valid_sets, non_butterfly_confounders
    """
    if roles is None:
        roles = identify_variable_roles(G, exposure, outcome)
    confounder_set = set(roles['confounders'])

    butterfly_vars: list[str] = []
    butterfly_parents: dict[str, list[str]] = {}
    non_butterfly_confounders = list(confounder_set)

    for v in sorted(confounder_set):
        pars = set(G.predecessors(v)) & confounder_set
        if len(pars) >= 2:
            butterfly_vars.append(v)
            butterfly_parents[v] = sorted(pars)

    # Remove butterfly nodes and their parents from "non-butterfly" set
    if butterfly_vars:
        exclude = set(butterfly_vars)
        for pars in butterfly_parents.values():
            exclude.update(pars)
        non_butterfly_confounders = sorted(confounder_set - exclude)

    # Build valid adjustment sets that avoid butterfly bias
    valid_sets = _build_butterfly_valid_sets(
        butterfly_vars, butterfly_parents, non_butterfly_confounders, confounder_set,
    )

    return {
        'roles': roles,
        'butterfly_vars': butterfly_vars,
        'butterfly_parents': butterfly_parents,
        'valid_sets': valid_sets,
        'non_butterfly_confounders': non_butterfly_confounders,
    }


def _build_butterfly_valid_sets(
    butterfly_vars: list[str],
    butterfly_parents: dict[str, list[str]],
    non_butterfly_confounders: list[str],
    all_confounders: set[str],
) -> list[list[str]]:
    """Generate all valid adjustment sets that avoid butterfly bias.

    For each butterfly node B with parents P1,P2,...,Pn the valid options are:
      • {P1, P2, ..., Pn}   (adjust for all parents, skip B)
      • {B, P_subset}       for each strict subset of parents
    The Cartesian product of per-butterfly options is combined with the
    non-butterfly confounders to form the final sets.
    """
    if not butterfly_vars:
        if all_confounders:
            return [sorted(all_confounders)]
        return [[]]

    per_butterfly_options: list[list[list[str]]] = []
    for bfly in butterfly_vars:
        pars = butterfly_parents[bfly]
        options: list[list[str]] = [sorted(pars)]  # option 1: all parents
        if len(pars) >= 2:
            for k in range(1, len(pars)):
                for subset in itertools.combinations(pars, k):
                    options.append(sorted([bfly] + list(subset)))
        per_butterfly_options.append(options)

    # Cartesian product across all butterfly nodes
    seen: set[tuple[str, ...]] = set()
    valid_sets: list[list[str]] = []
    for combo in itertools.product(*per_butterfly_options):
        adj = set(non_butterfly_confounders)
        for option_nodes in combo:
            adj.update(option_nodes)
        key = tuple(sorted(adj))
        if key not in seen:
            seen.add(key)
            valid_sets.append(list(key))

    return valid_sets


# ── M-bias analysis ──────────────────────────────────────────────────

def analyze_m_bias(G: nx.DiGraph, exposure: str, outcome: str,
                   roles: dict[str, Any] | None = None) -> dict[str, Any]:
    """Detect M-bias: colliders on backdoor paths that should NOT be adjusted.

    An M-bias variable is a node that:
      1. Has ≥2 parents (collider structure)
      2. Is NOT in the adjustment set
      3. Lies on at least one undirected path between exposure and outcome

    Uses O(n+e) reachability checks instead of exponential path enumeration.

    Args:
        roles: Pre-computed variable roles (optional). If None, adjustment set
               is computed independently.

    Returns dict with:
        exposure, outcome, adjustment_set,
        mbias_vars, mbias_details
    """
    if exposure not in G or outcome not in G:
        return {
            'exposure': exposure, 'outcome': outcome,
            'adjustment_set': [],
            'mbias_vars': [], 'mbias_details': {},
        }

    # Reuse adjustment set from pre-computed roles if available
    if roles is not None:
        adjustment_set = set(roles['adjustment_set'])
    else:
        adjustment_set = set(find_adjustment_sets(G, exposure, outcome))

    all_nodes = set(G.nodes()) - {exposure, outcome}

    # Pre-compute undirected skeleton and connected component — O(n+e) once
    U = G.to_undirected(as_view=True)
    try:
        component = nx.node_connected_component(U, exposure)
    except (nx.NetworkXError, nx.NodeNotFound):
        component = set()
    outcome_reachable = outcome in component

    # On cyclic graphs nearly every node qualifies; cap to keep it fast
    MAX_MBIAS_REPORTED = 20
    MAX_SAMPLE_PATHS = 10  # only compute sample paths for top N

    mbias_vars: list[str] = []
    mbias_details: dict[str, dict] = {}

    for v in sorted(all_nodes):
        if len(mbias_vars) >= MAX_MBIAS_REPORTED:
            break
        parents_v = list(G.predecessors(v))
        if len(parents_v) < 2:
            continue
        if v in adjustment_set:
            continue

        # Check reachability: v is on some undirected path between
        # exposure and outcome iff all three are in the same component
        if outcome_reachable and v in component:
            mbias_vars.append(v)
            # Only compute sample paths for the first few (expensive on big graphs)
            if len(mbias_vars) <= MAX_SAMPLE_PATHS:
                sample = _sample_path_through(U, exposure, outcome, v)
                sample_path = [str(n) for n in sample] if sample else []
            else:
                sample_path = []
            mbias_details[v] = {
                'parents': sorted(parents_v),
                'sample_path': sample_path,
            }

    return {
        'exposure': exposure,
        'outcome': outcome,
        'adjustment_set': sorted(adjustment_set),
        'mbias_vars': mbias_vars,
        'mbias_details': mbias_details,
        'capped': len(mbias_vars) >= MAX_MBIAS_REPORTED,
    }


# ── Combined analysis entry point ────────────────────────────────────

def analyze_bias(G: nx.DiGraph, exposure: str, outcome: str) -> dict[str, Any]:
    """Run both M-bias and butterfly bias analysis.  Main entry point."""
    is_dag = nx.is_directed_acyclic_graph(G)
    warnings: list[str] = []

    if exposure not in G:
        warnings.append(f'Exposure "{exposure}" not in graph')
    if outcome not in G:
        warnings.append(f'Outcome "{outcome}" not in graph')

    if warnings:
        return {
            'success': False,
            'warnings': warnings,
            'is_dag': is_dag,
            'roles': _empty_roles(exposure, outcome),
            'butterfly': {'butterfly_vars': [], 'butterfly_parents': {},
                          'valid_sets': [], 'non_butterfly_confounders': []},
            'mbias': {'mbias_vars': [], 'mbias_details': {}},
        }

    if not is_dag:
        warnings.append(
            'Graph is NOT a DAG. Bias analysis results may be unreliable. '
            'Consider running node removal first to break cycles.'
        )

    # Compute roles ONCE and share across both analyses
    roles = identify_variable_roles(G, exposure, outcome)

    butterfly = analyze_butterfly_bias(G, exposure, outcome, roles=roles)
    mbias = analyze_m_bias(G, exposure, outcome, roles=roles)

    return {
        'success': True,
        'is_dag': is_dag,
        'warnings': warnings,
        'roles': butterfly['roles'],
        'butterfly': {
            'butterfly_vars': butterfly['butterfly_vars'],
            'butterfly_parents': butterfly['butterfly_parents'],
            'valid_sets': butterfly['valid_sets'],
            'non_butterfly_confounders': butterfly['non_butterfly_confounders'],
        },
        'mbias': {
            'mbias_vars': mbias['mbias_vars'],
            'mbias_details': mbias['mbias_details'],
        },
    }
