"""
Views for graph visualization.
"""
from django.shortcuts import render
from django.views.generic import TemplateView
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
import json


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


@require_http_methods(["POST"])
def remove_node(request):
    """
    API endpoint to remove a node from the graph.
    """
    try:
        data = json.loads(request.body)
        node_id = data.get('node_id')
        
        # TODO: Implement node removal logic using R interface
        
        return JsonResponse({
            'success': True,
            'message': f'Node {node_id} removed successfully'
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["POST"])
def remove_edge(request):
    """
    API endpoint to remove an edge from the graph.
    """
    try:
        data = json.loads(request.body)
        from_node = data.get('from')
        to_node = data.get('to')
        
        # TODO: Implement edge removal logic using R interface
        
        return JsonResponse({
            'success': True,
            'message': f'Edge from {from_node} to {to_node} removed successfully'
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["POST"])
def undo_removal(request):
    """
    API endpoint to undo the last removal operation.
    """
    try:
        # TODO: Implement undo logic
        
        return JsonResponse({
            'success': True,
            'message': 'Last removal undone successfully'
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["GET"])
def get_network_data(request):
    """
    API endpoint to get current network data for visualization.
    """
    try:
        # TODO: Implement network data retrieval using R interface
        
        return JsonResponse({
            'nodes': [],
            'edges': []
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)

