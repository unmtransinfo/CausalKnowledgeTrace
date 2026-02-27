"""
Views for graph visualization.
"""
import copy
import json
import logging

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


def _get_graph_data(session):
    """Retrieve current graph data from session."""
    return session.get('graph_data', {'nodes': [], 'edges': [], 'metadata': {}, 'filename': ''})


def _save_undo_snapshot(session, graph_data):
    """Push current graph state onto the undo stack."""
    stack = session.get('graph_undo_stack', [])
    stack.append(copy.deepcopy(graph_data))
    if len(stack) > MAX_UNDO_STACK:
        stack = stack[-MAX_UNDO_STACK:]
    session['graph_undo_stack'] = stack


@require_http_methods(["POST"])
def remove_node(request):
    """
    API endpoint to remove a node from the graph.
    Also removes all edges connected to that node.
    """
    try:
        data = json.loads(request.body)
        node_id = data.get('node_id')

        if not node_id:
            return JsonResponse(
                {'success': False, 'error': 'No node_id provided'}, status=400
            )

        graph_data = _get_graph_data(request.session)
        _save_undo_snapshot(request.session, graph_data)

        nodes = graph_data.get('nodes', [])
        edges = graph_data.get('edges', [])

        # Find and remove the node
        original_count = len(nodes)
        nodes = [n for n in nodes if n['data']['id'] != node_id]
        if len(nodes) == original_count:
            return JsonResponse(
                {'success': False, 'error': f'Node {node_id} not found'}, status=404
            )

        # Remove connected edges
        removed_edges = [
            e for e in edges
            if e['data']['source'] == node_id or e['data']['target'] == node_id
        ]
        edges = [
            e for e in edges
            if e['data']['source'] != node_id and e['data']['target'] != node_id
        ]

        graph_data['nodes'] = nodes
        graph_data['edges'] = edges
        request.session['graph_data'] = graph_data
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': f'Node {node_id} removed (and {len(removed_edges)} connected edges)',
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

        graph_data = _get_graph_data(request.session)
        _save_undo_snapshot(request.session, graph_data)

        edges = graph_data.get('edges', [])
        original_count = len(edges)

        if edge_id:
            edges = [e for e in edges if e['data']['id'] != edge_id]
        elif from_node and to_node:
            edges = [
                e for e in edges
                if not (e['data']['source'] == from_node and e['data']['target'] == to_node)
            ]
        else:
            return JsonResponse(
                {'success': False, 'error': 'Provide edge_id or from/to'}, status=400
            )

        if len(edges) == original_count:
            return JsonResponse(
                {'success': False, 'error': 'Edge not found'}, status=404
            )

        graph_data['edges'] = edges
        request.session['graph_data'] = graph_data
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': 'Edge removed successfully',
            'nodes': graph_data['nodes'],
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error removing edge")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["POST"])
def undo_removal(request):
    """
    API endpoint to undo the last removal operation.
    """
    try:
        stack = request.session.get('graph_undo_stack', [])
        if not stack:
            return JsonResponse(
                {'success': False, 'error': 'Nothing to undo'}, status=400
            )

        previous_state = stack.pop()
        request.session['graph_undo_stack'] = stack
        request.session['graph_data'] = previous_state
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': 'Last removal undone successfully',
            'nodes': previous_state.get('nodes', []),
            'edges': previous_state.get('edges', []),
        })
    except Exception as e:
        logger.exception("Error undoing removal")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["GET"])
def get_network_data(request):
    """
    API endpoint to get current network data for visualization.
    Returns Cytoscape.js-compatible elements from session.
    """
    try:
        graph_data = _get_graph_data(request.session)
        return JsonResponse({
            'success': True,
            'nodes': graph_data.get('nodes', []),
            'edges': graph_data.get('edges', []),
            'metadata': graph_data.get('metadata', {}),
            'filename': graph_data.get('filename', ''),
        })
    except Exception as e:
        logger.exception("Error getting network data")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)

