"""
Views for causal analysis.
Runs analysis only on the graph explicitly loaded via Data Upload.
"""
import json
import logging
from collections import defaultdict, deque

from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.generic import TemplateView

from apps.core.graph_utils import get_selected_graph

logger = logging.getLogger(__name__)


# ── helpers ──────────────────────────────────────────────────────────

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


def _ancestors(predecessors, node):
    """Return set of ancestors of *node* (not including *node*)."""
    visited = set()
    stack = list(predecessors.get(node, []))
    while stack:
        n = stack.pop()
        if n not in visited:
            visited.add(n)
            stack.extend(predecessors.get(n, []))
    return visited


def _scc_kosaraju(node_ids, successors, predecessors):
    """Kosaraju's algorithm — returns list of SCCs (each a set)."""
    order = []
    visited = set()

    def dfs1(n):
        stack = [(n, False)]
        while stack:
            v, done = stack.pop()
            if done:
                order.append(v)
                continue
            if v in visited:
                continue
            visited.add(v)
            stack.append((v, True))
            for w in successors.get(v, []):
                if w not in visited:
                    stack.append((w, False))

    for n in node_ids:
        if n not in visited:
            dfs1(n)

    visited2 = set()
    sccs = []

    def dfs2(n):
        comp = set()
        stack = [n]
        while stack:
            v = stack.pop()
            if v in visited2:
                continue
            visited2.add(v)
            comp.add(v)
            for w in predecessors.get(v, []):
                if w not in visited2:
                    stack.append(w)
        return comp

    for n in reversed(order):
        if n not in visited2:
            c = dfs2(n)
            if len(c) > 1:
                sccs.append(c)
    return sccs


def _degree_stats(nodes, edges):
    """Return in-degree / out-degree dicts."""
    in_deg = defaultdict(int)
    out_deg = defaultdict(int)
    for e in edges:
        d = e['data']
        out_deg[d['source']] += 1
        in_deg[d['target']] += 1
    return dict(in_deg), dict(out_deg)


# ── page view ────────────────────────────────────────────────────────

class CausalAnalysisView(TemplateView):
    template_name = 'analysis/causal.html'

    def get_context_data(self, **kwargs):
        ctx = super().get_context_data(**kwargs)
        ctx['page_title'] = 'Causal Analysis'
        ctx['active_tab'] = 'causal'
        return ctx



# ── API: graph summary ──────────────────────────────────────────────

@require_http_methods(["GET"])
def get_graph_summary(request):
    """Full structural summary of the currently selected graph."""
    try:
        nodes, edges, metadata, filename = get_selected_graph(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    node_ids = [n['data']['id'] for n in nodes]
    in_deg, out_deg = _degree_stats(nodes, edges)

    # Exposure / outcome from node_type
    exposures = [n['data']['id'] for n in nodes
                 if n['data'].get('node_type') == 'exposure']
    outcomes = [n['data']['id'] for n in nodes
                if n['data'].get('node_type') == 'outcome']

    # Predicates distribution
    pred_counts = defaultdict(int)
    for e in edges:
        pred_counts[e['data'].get('predicate', 'unknown')] += 1

    # Cycles via SCC
    succ, pred = _build_adjacency(nodes, edges)
    sccs = _scc_kosaraju(set(node_ids), succ, pred)
    cycle_node_count = sum(len(c) for c in sccs)

    # Density
    n = len(nodes)
    m = len(edges)
    density = m / (n * (n - 1)) if n > 1 else 0

    # Top-degree nodes
    total_deg = {nid: in_deg.get(nid, 0) + out_deg.get(nid, 0) for nid in node_ids}
    top_nodes = sorted(total_deg.items(), key=lambda x: -x[1])[:15]

    return JsonResponse({
        'success': True,
        'filename': filename,
        'node_count': n,
        'edge_count': m,
        'density': round(density, 6),
        'exposures': exposures,
        'outcomes': outcomes,
        'predicate_distribution': dict(pred_counts),
        'cycle_count': len(sccs),
        'cycle_node_count': cycle_node_count,
        'top_nodes': [{'id': nid, 'degree': deg} for nid, deg in top_nodes],
    })


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



# ── API: adjustment sets (heuristic) ────────────────────────────────

@require_http_methods(["POST"])
def calculate_adjustment_sets(request):
    """
    Heuristic adjustment set: common ancestors of exposure and outcome
    (excluding exposure/outcome themselves).
    """
    try:
        nodes, edges, metadata, filename = get_selected_graph(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    exposure = data.get('exposure')
    outcome = data.get('outcome')

    node_ids = {n['data']['id'] for n in nodes}
    if exposure not in node_ids or outcome not in node_ids:
        return JsonResponse({'success': False, 'error': 'Exposure or outcome not in graph'}, status=400)

    _, pred = _build_adjacency(nodes, edges)
    anc_exp = _ancestors(pred, exposure)
    anc_out = _ancestors(pred, outcome)
    shared = (anc_exp & anc_out) - {exposure, outcome}

    return JsonResponse({
        'success': True,
        'filename': filename,
        'exposure': exposure,
        'outcome': outcome,
        'adjustment_sets': [sorted(shared)],
        'count': len(shared),
        'message': f'{len(shared)} candidate confounders (common ancestors of both exposure and outcome)',
    })


# ── API: instrumental variables (heuristic) ─────────────────────────

@require_http_methods(["POST"])
def find_instrumental_variables(request):
    """
    Heuristic: nodes that are parents of exposure but NOT ancestors of outcome
    through any path that doesn't go through exposure.
    """
    try:
        nodes, edges, metadata, filename = get_selected_graph(request.session)
    except (ValueError, FileNotFoundError) as exc:
        return JsonResponse({'success': False, 'error': str(exc)}, status=400)

    data = json.loads(request.body)
    exposure = data.get('exposure')
    outcome = data.get('outcome')

    node_ids = {n['data']['id'] for n in nodes}
    if exposure not in node_ids or outcome not in node_ids:
        return JsonResponse({'success': False, 'error': 'Exposure or outcome not in graph'}, status=400)

    succ, pred = _build_adjacency(nodes, edges)
    parents_of_exp = set(pred.get(exposure, []))

    # Build successors without going through exposure
    succ_no_exp = {k: [v for v in vs if v != exposure] for k, vs in succ.items()}
    # Ancestors of outcome excluding exposure path
    anc_out_no_exp = set()
    stack = list(pred.get(outcome, []))
    while stack:
        n = stack.pop()
        if n == exposure or n in anc_out_no_exp:
            continue
        anc_out_no_exp.add(n)
        stack.extend(pred.get(n, []))

    instruments = sorted(parents_of_exp - anc_out_no_exp - {outcome})

    return JsonResponse({
        'success': True,
        'filename': filename,
        'exposure': exposure,
        'outcome': outcome,
        'instruments': instruments,
        'count': len(instruments),
        'message': f'{len(instruments)} candidate instrumental variables',
    })
