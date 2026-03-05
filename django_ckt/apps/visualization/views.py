"""
Views for graph visualization.
"""
import copy
import json
import logging
import os

from django.conf import settings
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.generic import TemplateView

logger = logging.getLogger(__name__)

MAX_UNDO_STACK = 50


class GraphVisualizationView(TemplateView):
    """
    Main graph visualization view.
    """
    template_name = 'visualization/graph.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Graph Visualization'
        context['active_tab'] = 'dag'
        return context


# ── Graph file loading (mirrors upload/views.py logic) ──

def _get_graph_dirs():
    """Return list of directories to search for graph files."""
    return [
        os.path.join(settings.BASE_DIR.parent, 'graph_creation', 'result'),
        os.path.join(settings.MEDIA_ROOT, 'graphs'),
    ]


def _find_graph_file(filename):
    """Find graph file across known directories. Returns full path or None."""
    for directory in _get_graph_dirs():
        full_path = os.path.join(directory, filename)
        if os.path.isfile(full_path):
            return full_path
    return None


def _load_graph_from_disk(filename, filter_type='none'):
    """
    Load nodes, edges, metadata from disk by filename.
    Returns (nodes, edges, metadata) or ([], [], {}) on failure.
    """
    file_path = _find_graph_file(filename)
    if not file_path:
        logger.warning("Graph file not found: %s", filename)
        return [], [], {}

    try:
        with open(file_path, 'r') as f:
            graph_data = json.load(f)
    except Exception:
        logger.exception("Failed to read graph file: %s", file_path)
        return [], [], {}

    elements = graph_data.get('elements', graph_data)
    nodes = elements.get('nodes', [])
    edges = elements.get('edges', [])

    if filter_type == 'remove_leaf':
        degree = {}
        for node in nodes:
            degree[node['data']['id']] = 0
        for edge in edges:
            src = edge['data']['source']
            tgt = edge['data']['target']
            degree[src] = degree.get(src, 0) + 1
            degree[tgt] = degree.get(tgt, 0) + 1
        leaf_ids = {nid for nid, deg in degree.items() if deg <= 1}
        nodes = [n for n in nodes if n['data']['id'] not in leaf_ids]
        edges = [e for e in edges
                 if e['data']['source'] not in leaf_ids
                 and e['data']['target'] not in leaf_ids]

    metadata = graph_data.get('metadata', {})
    return nodes, edges, metadata


def _apply_deletions(nodes, edges, deleted_node_ids, deleted_edge_ids):
    """Remove deleted IDs from nodes/edges lists."""
    del_nodes = set(deleted_node_ids)
    del_edges = set(deleted_edge_ids)
    nodes = [n for n in nodes if n['data']['id'] not in del_nodes]
    edges = [e for e in edges
             if e['data']['id'] not in del_edges
             and e['data']['source'] not in del_nodes
             and e['data']['target'] not in del_nodes]
    return nodes, edges


def _get_current_graph(session):
    """
    Load graph from disk and apply current deletions.
    Returns (nodes, edges, metadata, filename).
    """
    source = session.get('graph_source', {})
    filename = source.get('filename', '')
    filter_type = source.get('filter_type', 'none')

    if not filename:
        return [], [], {}, ''

    nodes, edges, metadata = _load_graph_from_disk(filename, filter_type)
    deletions = session.get('graph_deletions', {'nodes': [], 'edges': []})
    nodes, edges = _apply_deletions(nodes, edges,
                                    deletions.get('nodes', []),
                                    deletions.get('edges', []))
    return nodes, edges, metadata, filename


def _save_undo_snapshot(session):
    """Push a copy of current deletions onto the undo stack."""
    current = session.get('graph_deletions', {'nodes': [], 'edges': []})
    stack = session.get('graph_undo_stack', [])
    stack.append(copy.deepcopy(current))
    if len(stack) > MAX_UNDO_STACK:
        stack = stack[-MAX_UNDO_STACK:]
    session['graph_undo_stack'] = stack


@require_http_methods(["POST"])
def remove_node(request):
    """
    API endpoint to remove a node from the graph.
    Tracks deleted node IDs in session; graph data is loaded from disk.
    """
    try:
        data = json.loads(request.body)
        node_id = data.get('node_id')

        if not node_id:
            return JsonResponse(
                {'success': False, 'error': 'No node_id provided'}, status=400
            )

        # Verify the node exists in the current (disk-loaded + filtered) graph
        nodes, edges, _, _ = _get_current_graph(request.session)
        node_ids = {n['data']['id'] for n in nodes}
        if node_id not in node_ids:
            return JsonResponse(
                {'success': False, 'error': f'Node {node_id} not found'}, status=404
            )

        # Snapshot deletions for undo, then record this deletion
        _save_undo_snapshot(request.session)
        deletions = request.session.get('graph_deletions', {'nodes': [], 'edges': []})
        if node_id not in deletions['nodes']:
            deletions['nodes'].append(node_id)
        request.session['graph_deletions'] = deletions
        request.session.modified = True

        # Re-apply deletions to get the updated graph
        nodes, edges, _, _ = _get_current_graph(request.session)
        removed_edge_count = sum(
            1 for e in edges
            if e['data']['source'] == node_id or e['data']['target'] == node_id
        )

        return JsonResponse({
            'success': True,
            'message': f'Node {node_id} removed (and connected edges)',
            'nodes': nodes,
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error removing node")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["POST"])
def remove_edge(request):
    """
    API endpoint to remove an edge from the graph.
    Accepts either edge_id or from/to node pair.
    """
    try:
        data = json.loads(request.body)
        edge_id = data.get('edge_id')
        from_node = data.get('from')
        to_node = data.get('to')

        nodes, edges, _, _ = _get_current_graph(request.session)

        # Resolve edge_id from from/to if not given directly
        if not edge_id and from_node and to_node:
            for e in edges:
                if e['data']['source'] == from_node and e['data']['target'] == to_node:
                    edge_id = e['data']['id']
                    break
        if not edge_id:
            return JsonResponse(
                {'success': False, 'error': 'Provide edge_id or from/to'}, status=400
            )

        edge_ids = {e['data']['id'] for e in edges}
        if edge_id not in edge_ids:
            return JsonResponse({'success': False, 'error': 'Edge not found'}, status=404)

        # Snapshot deletions for undo, then record this deletion
        _save_undo_snapshot(request.session)
        deletions = request.session.get('graph_deletions', {'nodes': [], 'edges': []})
        if edge_id not in deletions['edges']:
            deletions['edges'].append(edge_id)
        request.session['graph_deletions'] = deletions
        request.session.modified = True

        # Re-apply deletions to get updated graph
        nodes, edges, _, _ = _get_current_graph(request.session)

        return JsonResponse({
            'success': True,
            'message': 'Edge removed successfully',
            'nodes': nodes,
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error removing edge")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["POST"])
def undo_removal(request):
    """
    API endpoint to undo the last removal operation.
    Restores the previous deletions snapshot, then reloads from disk.
    """
    try:
        stack = request.session.get('graph_undo_stack', [])
        if not stack:
            return JsonResponse(
                {'success': False, 'error': 'Nothing to undo'}, status=400
            )

        previous_deletions = stack.pop()
        request.session['graph_undo_stack'] = stack
        request.session['graph_deletions'] = previous_deletions
        request.session.modified = True

        nodes, edges, _, _ = _get_current_graph(request.session)

        return JsonResponse({
            'success': True,
            'message': 'Last removal undone successfully',
            'nodes': nodes,
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error undoing removal")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["GET"])
def get_network_data(request):
    """
    API endpoint to get current network data for visualization.
    Loads graph from disk and applies any user-requested deletions.
    """
    try:
        source = request.session.get('graph_source', {})
        logger.info("get_network_data: session graph_source=%s", source)
        nodes, edges, metadata, filename = _get_current_graph(request.session)
        logger.info("get_network_data: returning %d nodes, %d edges, filename=%s",
                    len(nodes), len(edges), filename)
        return JsonResponse({
            'success': True,
            'nodes': nodes,
            'edges': edges,
            'metadata': metadata,
            'filename': filename,
        })
    except Exception as e:
        logger.exception("Error getting network data")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)

