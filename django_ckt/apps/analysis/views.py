"""
Views for causal analysis.
Runs analysis only on the graph explicitly loaded via Data Upload.
Uses the causal_analysis pipeline (stages s1-s6) via pipeline_bridge.
"""
import json
import logging
from collections import defaultdict, deque
from datetime import datetime
from pathlib import Path

import networkx as nx
from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.generic import TemplateView

# Directory for persisted reduced graphs (inside BASE_DIR so it works in Docker)
# On host: django_ckt/reduced_graphs/
REDUCED_GRAPHS_DIR = Path(settings.BASE_DIR) / 'reduced_graphs'

from apps.core.graph_utils import get_selected_graph
from apps.analysis.pipeline_bridge import (
    cytoscape_to_networkx,
    analyze_graph_summary,
    compute_total_cycles,
    analyze_cycles,
    analyze_node_removal,
    analyze_post_removal,
    analyze_causal_inference,
)

logger = logging.getLogger(__name__)


# ── helpers ──────────────────────────────────────────────────────────

def _get_graph_nx(session):
    """Load the selected graph and return (nx_graph, nodes, edges, metadata, filename)."""
    nodes, edges, metadata, filename = get_selected_graph(session)
    G = cytoscape_to_networkx(nodes, edges)
    return G, nodes, edges, metadata, filename


def _build_adjacency(nodes, edges):
    """Build adjacency lists from Cytoscape-style nodes/edges."""
    successors = defaultdict(list)
    predecessors = defaultdict(list)
    for edge in edges:
        d = edge['data']
        successors[d['source']].append(d['target'])
        predecessors[d['target']].append(d['source'])
    return successors, predecessors


def _find_paths_bfs(successors, start, end, max_depth=6, limit=20):
    """Return up to *limit* simple directed paths from start to end."""
    paths = []
    queue = deque([(start, [start])])
    while queue and len(paths) < limit:
        node, path = queue.popleft()
        if len(path) > max_depth + 1:
            continue
        for nxt in successors.get(node, []):
            if nxt == end:
                paths.append(path + [end])
            elif nxt not in path:
                queue.append((nxt, path + [nxt]))
    return paths


# ── page view ────────────────────────────────────────────────────────

class CausalAnalysisView(TemplateView):
    template_name = 'analysis/causal.html'

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['page_title'] = 'Causal Analysis'
        ctx['active_tab'] = 'causal'
        return ctx



# ── API: graph summary (Stage 2 — NetworkX-powered) ─────────────────

@require_http_methods(["GET"])
def get_graph_summary(request):
    """Full structural summary using the causal_analysis pipeline."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    summary = analyze_graph_summary(G)
    summary['success'] = True
    summary['filename'] = filename
    return JsonResponse(summary)


# ── API: total cycles (async, separate from summary) ─────────────────

@require_http_methods(["GET"])
def get_total_cycles(request):
    """Compute total cycle count asynchronously (expensive)."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    total_cycles = compute_total_cycles(G)
    return JsonResponse({'success': True, 'total_cycles': total_cycles})


# ── API: variables ───────────────────────────────────────────────────

@require_http_methods(["GET"])
def get_dag_variables(request):
    """Return all variables, exposures, outcomes from the selected graph."""
    try:
        nodes, edges, metadata, filename = get_selected_graph(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    variables = sorted(n['data']['id'] for n in nodes)
    exposures = sorted(n['data']['id'] for n in nodes
                       if n['data'].get('node_type') == 'exposure')
    outcomes = sorted(n['data']['id'] for n in nodes
                      if n['data'].get('node_type') == 'outcome')

    return JsonResponse({
        'success': True,
        'filename': filename,
        'variables': variables,
        'exposures': exposures,
        'outcomes': outcomes,
    })


# ── API: causal paths ───────────────────────────────────────────────

@require_http_methods(["POST"])
def analyze_causal_paths(request):
    """Find directed paths between two variables."""
    try:
        nodes, edges, metadata, filename = get_selected_graph(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    from_var = data.get('from')
    to_var = data.get('to')
    limit = min(int(data.get('limit', 20)), 50)

    node_ids = {n['data']['id'] for n in nodes}
    if from_var not in node_ids:
        return JsonResponse({'success': False, 'error': f'Node "{from_var}" not in graph'}, status=400)
    if to_var not in node_ids:
        return JsonResponse({'success': False, 'error': f'Node "{to_var}" not in graph'}, status=400)

    succ, _ = _build_adjacency(nodes, edges)
    paths = _find_paths_bfs(succ, from_var, to_var, max_depth=6, limit=limit)

    return JsonResponse({
        'success': True,
        'filename': filename,
        'from': from_var,
        'to': to_var,
        'path_count': len(paths),
        'paths': paths,
    })



# ── API: cycle analysis (Stage 3 — NetworkX) ────────────────────────

@require_http_methods(["GET"])
def get_cycle_analysis(request):
    """Full cycle enumeration via the causal_analysis pipeline."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    result = analyze_cycles(G)
    result['success'] = True
    result['filename'] = filename
    return JsonResponse(result)


# ── API: node removal impact (Stage 4 — NetworkX) ───────────────────

@require_http_methods(["POST"])
def get_node_removal(request):
    """Analyze impact of removing generic/custom nodes on cycles."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body) if request.body else {}
    custom_nodes = data.get('nodes_to_remove')  # optional list

    result, reduced_G = analyze_node_removal(G, custom_nodes)
    # Store reduced graph in session for post-removal analysis
    request.session['_reduced_graph_data'] = {
        'nodes': [n for n in reduced_G.nodes()],
        'edges': [(u, v) for u, v in reduced_G.edges()],
    }

    # Persist reduced graph to disk for CLI usage
    try:
        REDUCED_GRAPHS_DIR.mkdir(parents=True, exist_ok=True)
        # Build a descriptive filename: <original_name>_reduced_<timestamp>.graphml
        base = Path(filename).stem if filename else 'graph'
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        graphml_name = f"{base}_reduced_{timestamp}.graphml"
        graphml_path = REDUCED_GRAPHS_DIR / graphml_name
        nx.write_graphml(reduced_G, str(graphml_path))
        result['reduced_graph_path'] = str(graphml_path)
        logger.info("Saved reduced graph to %s", graphml_path)
    except Exception as exc:
        logger.warning("Could not save reduced graph to disk: %s", exc)
        result['reduced_graph_path'] = None

    result['success'] = True
    result['filename'] = filename
    return JsonResponse(result)


# ── API: post-removal analysis (Stage 5 — NetworkX) ─────────────────

@require_http_methods(["GET"])
def get_post_removal(request):
    """Compare original vs reduced graph after node removal."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    # Rebuild reduced graph from session data
    reduced_data = request.session.get('_reduced_graph_data')
    if not reduced_data:
        return JsonResponse({
            'success': False,
            'error': 'No node removal has been run yet. Run node removal first.'
        }, status=400)

    reduced_G = nx.DiGraph()
    reduced_G.add_nodes_from(reduced_data['nodes'])
    reduced_G.add_edges_from(reduced_data['edges'])

    result = analyze_post_removal(G, reduced_G)
    result['success'] = True
    result['filename'] = filename
    return JsonResponse(result)


# ── API: causal inference (formal backdoor + IV) ─────────────────────

@require_http_methods(["POST"])
def get_causal_inference(request):
    """
    Formal causal inference: backdoor criterion adjustment sets
    and instrumental variable identification using NetworkX.
    Runs on both the original graph and the reduced graph (if available).
    """
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    exposure = data.get('exposure')
    outcome = data.get('outcome')

    if not exposure or not outcome:
        return JsonResponse({
            'success': False, 'error': 'Both exposure and outcome are required'
        }, status=400)

    # Run on original graph
    original_result = analyze_causal_inference(G, exposure, outcome)

    # Run on reduced graph if available
    reduced_result = None
    has_reduced = False
    reduced_data = request.session.get('_reduced_graph_data')
    if reduced_data:
        reduced_G = nx.DiGraph()
        reduced_G.add_nodes_from(reduced_data['nodes'])
        reduced_G.add_edges_from(reduced_data['edges'])
        # Only run if exposure and outcome still exist in reduced graph
        if exposure in reduced_G and outcome in reduced_G:
            reduced_result = analyze_causal_inference(reduced_G, exposure, outcome)
            has_reduced = True

    return JsonResponse({
        'success': True,
        'filename': filename,
        'exposure': exposure,
        'outcome': outcome,
        'original': original_result,
        'reduced': reduced_result,
        'has_reduced': has_reduced,
    })



# ── Legacy endpoints (now backed by pipeline) ────────────────────────

@require_http_methods(["POST"])
def calculate_adjustment_sets(request):
    """Adjustment sets via formal backdoor criterion (replaces heuristic)."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    exposure = data.get('exposure')
    outcome = data.get('outcome')

    if not exposure or not outcome:
        return JsonResponse({'success': False, 'error': 'Both exposure and outcome required'}, status=400)

    result = analyze_causal_inference(G, exposure, outcome)
    return JsonResponse({
        'success': True,
        'filename': filename,
        'exposure': exposure,
        'outcome': outcome,
        'adjustment_sets': [result['adjustment_sets']],
        'count': len(result['adjustment_sets']),
        'message': f'{len(result["adjustment_sets"])} adjustment variables (backdoor criterion)',
        'warnings': result.get('warnings', []),
    })


@require_http_methods(["POST"])
def find_instrumental_variables(request):
    """Instrumental variables via formal IV identification (replaces heuristic)."""
    try:
        G, nodes, edges, metadata, filename = _get_graph_nx(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    exposure = data.get('exposure')
    outcome = data.get('outcome')

    if not exposure or not outcome:
        return JsonResponse({'success': False, 'error': 'Both exposure and outcome required'}, status=400)

    result = analyze_causal_inference(G, exposure, outcome)
    return JsonResponse({
        'success': True,
        'filename': filename,
        'exposure': exposure,
        'outcome': outcome,
        'instruments': result['instrumental_variables'],
        'count': len(result['instrumental_variables']),
        'message': f'{len(result["instrumental_variables"])} instrumental variables',
        'warnings': result.get('warnings', []),
    })
