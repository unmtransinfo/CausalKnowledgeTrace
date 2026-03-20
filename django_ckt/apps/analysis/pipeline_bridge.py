"""
pipeline_bridge.py
Bridge between Django's Cytoscape-style graph data and the causal_analysis pipeline.

Converts in-memory Cytoscape JSON (nodes/edges lists) to NetworkX DiGraph,
then delegates to the pipeline's core computation functions — no file I/O needed.
"""
import logging
import time
from collections import Counter

import networkx as nx

from causal_analysis.config import GENERIC_NODES, CYCLE_CONFIG, NODE_REMOVAL_CONFIG
from causal_analysis.s3_cycle_analysis import count_cycles_with_participation
from causal_analysis.s4_node_removal import count_cycles, get_scc_stats
from causal_analysis.s6_causal_inference import find_adjustment_sets, find_instrumental_variables
from causal_analysis.s7_bias_analysis import analyze_bias

logger = logging.getLogger(__name__)


# ── In-memory cache for expensive computations ──────────────────────
# Keyed by (filename, filter_type, node_count, edge_count) to avoid
# recomputing on page refreshes for the same graph.
_analysis_cache: dict[str, dict] = {}


def _cache_key(G, label=''):
    """Build a cache key from graph identity + an operation label."""
    return f"{label}:{G.number_of_nodes()}:{G.number_of_edges()}"


def get_cached(G, label):
    """Return cached result or None."""
    key = _cache_key(G, label)
    return _analysis_cache.get(key)


def set_cached(G, label, value):
    """Store a value in the analysis cache."""
    key = _cache_key(G, label)
    _analysis_cache[key] = value
    return value


def cached_count_cycles(G):
    """count_cycles with caching."""
    cached = get_cached(G, 'count_cycles')
    if cached is not None:
        return cached
    result = count_cycles(G)
    return set_cached(G, 'count_cycles', result)


# ── Stage 1: Cytoscape JSON → NetworkX DiGraph ───────────────────────

def cytoscape_to_networkx(nodes, edges):
    """
    Convert Django's Cytoscape-style nodes/edges lists into a NetworkX DiGraph.
    Reuses the same logic as causal_analysis.s1_graph_parsing.parse_graph_json
    but operates on in-memory data instead of reading from a file.
    """
    G = nx.DiGraph()

    for node in nodes:
        d = node.get('data', {})
        node_id = d.get('id', '')
        label = d.get('label', node_id)
        node_type = d.get('node_type', d.get('type', 'regular'))
        if node_type in ('default', ''):
            node_type = 'regular'
        G.add_node(node_id, label=label, node_type=node_type)

    for edge in edges:
        d = edge.get('data', {})
        src = d.get('source', '')
        tgt = d.get('target', '')
        predicate = d.get('predicate', 'CAUSES')
        ev_count = d.get('evidence_count', 0)
        if src and tgt:
            G.add_edge(src, tgt, predicate=predicate, ev_count=ev_count)

    return G


# ── Stage 2: Basic graph analysis (NetworkX-powered) ─────────────────

def analyze_graph_summary(G):
    """Run Stage-2 style analysis on a NetworkX DiGraph. Returns a dict.

    NOTE: total_cycles is NOT computed here (it blocks the page load).
    Use the dedicated /api/total-cycles/ endpoint for async cycle counting.
    """
    n_nodes = G.number_of_nodes()
    n_edges = G.number_of_edges()
    density = nx.density(G)
    is_dag = nx.is_directed_acyclic_graph(G)

    in_deg = dict(G.in_degree())
    out_deg = dict(G.out_degree())
    total_deg = {n: in_deg[n] + out_deg[n] for n in G.nodes()}

    sccs = list(nx.strongly_connected_components(G))
    large_sccs = [s for s in sccs if len(s) > 1]
    nodes_in_cycles = set().union(*large_sccs) if large_sccs else set()

    # Use approximate betweenness centrality (k-sampled) for speed
    k = min(100, n_nodes) if n_nodes > 0 else 0
    if k > 0:
        betweenness = nx.betweenness_centrality(G, k=k)
    else:
        betweenness = {}
    pagerank = nx.pagerank(G) if n_nodes > 0 else {}

    top_nodes = sorted(total_deg.items(), key=lambda x: -x[1])[:15]

    # Predicate distribution
    pred_counts = {}
    for u, v, d in G.edges(data=True):
        p = d.get('predicate', 'unknown')
        pred_counts[p] = pred_counts.get(p, 0) + 1

    # Exposures / outcomes from node attributes
    exposures = [n for n in G.nodes() if G.nodes[n].get('node_type') == 'exposure']
    outcomes = [n for n in G.nodes() if G.nodes[n].get('node_type') == 'outcome']

    return {
        'node_count': n_nodes,
        'edge_count': n_edges,
        'density': round(density, 6),
        'is_dag': is_dag,
        'is_weakly_connected': nx.is_weakly_connected(G) if n_nodes > 0 else False,
        'exposures': exposures,
        'outcomes': outcomes,
        'predicate_distribution': pred_counts,
        'total_cycles': None,  # loaded asynchronously via /api/total-cycles/
        'cycle_count': len(large_sccs),
        'cycle_node_count': len(nodes_in_cycles),
        'top_nodes': [{'id': nid, 'degree': deg} for nid, deg in top_nodes],
        'betweenness': {n: round(v, 6) for n, v in
                        sorted(betweenness.items(), key=lambda x: -x[1])[:15]},
        'pagerank': {n: round(v, 6) for n, v in
                     sorted(pagerank.items(), key=lambda x: -x[1])[:15]},
    }


# ── Async total_cycles computation ───────────────────────────────────

def compute_total_cycles(G):
    """Compute total cycle count with caching + DAG short-circuit."""
    if nx.is_directed_acyclic_graph(G):
        return set_cached(G, 'count_cycles', 0)
    return cached_count_cycles(G)


# ── Stage 3: Cycle analysis ──────────────────────────────────────────

def analyze_cycles(G, max_sample=None):
    """Run Stage-3 cycle extraction on a NetworkX DiGraph. Returns a dict."""
    if max_sample is None:
        max_sample = CYCLE_CONFIG['max_cycles_to_save']

    sccs = [s for s in nx.strongly_connected_components(G) if len(s) > 1]
    if not sccs:
        return {
            'total_cycles': 0, 'nodes_in_cycles': 0,
            'node_participation': [], 'sampled_cycles': [],
            'length_distribution': {},
        }

    total, node_counts, length_dist, sampled = count_cycles_with_participation(G, max_sample)

    # Cache the total so compute_total_cycles / cached_count_cycles can reuse it
    set_cached(G, 'count_cycles', total)

    return {
        'total_cycles': total,
        'nodes_in_cycles': len(node_counts),
        'node_participation': [
            {'node': n, 'count': c} for n, c in node_counts.most_common(20)
        ],
        'sampled_cycles': [
            {'id': i + 1, 'length': len(cyc), 'nodes': cyc}
            for i, cyc in enumerate(sampled)
        ],
        'length_distribution': {str(k): v for k, v in sorted(length_dist.items())},
    }


# ── Stage 4: Node removal impact ─────────────────────────────────────

def analyze_node_removal(G, custom_nodes=None):
    """Run Stage-4 node removal analysis on a NetworkX DiGraph. Returns a dict."""
    generic_nodes = custom_nodes if custom_nodes is not None else GENERIC_NODES
    existing = [n for n in generic_nodes if n in G]

    baseline_stats = get_scc_stats(G)
    baseline_cycles = cached_count_cycles(G)

    individual = []
    for node in existing:
        H = G.copy()
        H.remove_node(node)
        cycles_after = count_cycles(H)
        removed = baseline_cycles - cycles_after
        pct = (removed / baseline_cycles * 100) if baseline_cycles else 0
        scc_s = get_scc_stats(H)
        individual.append({
            'node': node, 'original_cycles': baseline_cycles,
            'remaining_cycles': cycles_after, 'cycles_removed': removed,
            'percent_reduction': round(pct, 2),
            'remaining_sccs': scc_s['num_sccs'],
            'largest_scc_after': scc_s['largest_scc'],
        })
    individual.sort(key=lambda r: -r['percent_reduction'])

    # Combined removal
    reduced = G.copy()
    for node in existing:
        if node in reduced:
            reduced.remove_node(node)

    combined_stats = get_scc_stats(reduced)
    combined_cycles = count_cycles(reduced)
    is_dag = nx.is_directed_acyclic_graph(reduced)

    return {
        'baseline_cycles': baseline_cycles,
        'baseline_sccs': baseline_stats['num_sccs'],
        'nodes_removed': existing,
        'individual_impact': individual,
        'combined_cycles': combined_cycles,
        'combined_sccs': combined_stats['num_sccs'],
        'reduced_nodes': reduced.number_of_nodes(),
        'reduced_edges': reduced.number_of_edges(),
        'is_dag_after': is_dag,
        'generic_nodes_available': GENERIC_NODES,
    }, reduced


# ── Stage 5: Post-removal analysis ──────────────────────────────────

def analyze_post_removal(G_original, G_reduced):
    """Run Stage-5 post-removal analysis comparing original vs reduced graph."""
    orig_cycles = cached_count_cycles(G_original)
    reduced_cycles = cached_count_cycles(G_reduced)
    is_dag = nx.is_directed_acyclic_graph(G_reduced)

    sccs_orig = [s for s in nx.strongly_connected_components(G_original) if len(s) > 1]
    sccs_reduced = [s for s in nx.strongly_connected_components(G_reduced) if len(s) > 1]

    # If still has cycles, find top participating nodes for next iteration
    top_candidates = []
    if not is_dag and sccs_reduced:
        try:
            _, node_counts, _, _ = count_cycles_with_participation(G_reduced, 200)
            top_candidates = [
                {'node': n, 'count': c} for n, c in node_counts.most_common(20)
            ]
        except Exception:
            pass

    return {
        'original_cycles': orig_cycles,
        'reduced_cycles': reduced_cycles,
        'cycle_reduction_pct': round(
            (orig_cycles - reduced_cycles) / orig_cycles * 100, 2
        ) if orig_cycles else 0,
        'is_dag': is_dag,
        'original_sccs': len(sccs_orig),
        'reduced_sccs': len(sccs_reduced),
        'original_nodes': G_original.number_of_nodes(),
        'reduced_nodes': G_reduced.number_of_nodes(),
        'original_edges': G_original.number_of_edges(),
        'reduced_edges': G_reduced.number_of_edges(),
        'next_removal_candidates': top_candidates,
    }


# ── Stage 6: Formal causal inference ────────────────────────────────

def analyze_causal_inference(G, exposure, outcome):
    """
    Run Stage-6 formal causal inference on a NetworkX DiGraph.
    Works on both DAGs and cyclic graphs (with appropriate warnings).
    """
    is_dag = nx.is_directed_acyclic_graph(G)

    result = {
        'exposure': exposure,
        'outcome': outcome,
        'is_dag': is_dag,
        'adjustment_sets': [],
        'instrumental_variables': [],
        'warnings': [],
    }

    if exposure not in G:
        result['warnings'].append(f'Exposure "{exposure}" not in graph')
        return result
    if outcome not in G:
        result['warnings'].append(f'Outcome "{outcome}" not in graph')
        return result

    if not is_dag:
        result['warnings'].append(
            'Graph is NOT a DAG. Causal inference results may be unreliable. '
            'Consider running node removal first to break cycles.'
        )

    try:
        adj_set = find_adjustment_sets(G, exposure, outcome)
        result['adjustment_sets'] = adj_set
    except Exception as e:
        result['warnings'].append(f'Adjustment set error: {e}')

    try:
        ivs = find_instrumental_variables(G, exposure, outcome)
        result['instrumental_variables'] = ivs
    except Exception as e:
        result['warnings'].append(f'IV identification error: {e}')

    return result

