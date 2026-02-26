"""
Views for graph configuration.
"""
from django.shortcuts import render
from django.views.generic import TemplateView
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from apps.core.models import SubjectSearch, ObjectSearch
import json


class GraphConfigView(TemplateView):
    """
    Main graph configuration view.
    """
    template_name = 'graph_config/config.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Graph Configuration'
        context['active_tab'] = 'create_graph'
        return context


@require_http_methods(["GET"])
def search_cui(request):
    """
    API endpoint to search for CUIs by name.
    """
    try:
        query = request.GET.get('q', '')
        search_type = request.GET.get('type', 'subject')  # 'subject' or 'object'
        
        if len(query) < 2:
            return JsonResponse({
                'success': True,
                'results': []
            })
        
        # Search in appropriate table
        if search_type == 'subject':
            results = SubjectSearch.objects.filter(
                name__icontains=query
            )[:20]
        else:
            results = ObjectSearch.objects.filter(
                name__icontains=query
            )[:20]
        
        cui_list = [
            {
                'cui': r.cui,
                'name': r.name,
                'semtype': r.semtype if hasattr(r, 'semtype') else None
            }
            for r in results
        ]
        
        return JsonResponse({
            'success': True,
            'results': cui_list
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["POST"])
def generate_graph(request):
    """
    API endpoint to generate a new knowledge graph.
    """
    try:
        data = json.loads(request.body)
        exposure_cui = data.get('exposure_cui')
        outcome_cui = data.get('outcome_cui')
        squelch_threshold = data.get('squelch_threshold', 5)
        year_cutoff = data.get('year_cutoff', 2000)
        degree = data.get('degree', 1)
        semmeddb_version = data.get('semmeddb_version', 'VER43_R')
        
        # TODO: Implement graph generation using Python graph_creation modules
        # This will call the existing Python code in graph_creation/
        
        return JsonResponse({
            'success': True,
            'message': 'Graph generation started',
            'task_id': 'placeholder'  # TODO: Implement async task tracking
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["GET"])
def check_generation_status(request, task_id):
    """
    API endpoint to check graph generation status.
    """
    try:
        # TODO: Implement task status checking
        
        return JsonResponse({
            'success': True,
            'status': 'pending',  # 'pending', 'running', 'completed', 'failed'
            'progress': 0
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)

