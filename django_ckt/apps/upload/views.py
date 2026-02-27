"""
Views for file upload and graph loading.
"""
from django.shortcuts import render
from django.views.generic import TemplateView
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.core.files.storage import default_storage
from django.conf import settings
import json
import os


class DataUploadView(TemplateView):
    """
    Main data upload view.
    """
    template_name = 'upload/upload.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Data Upload'
        context['active_tab'] = 'upload'
        return context


@require_http_methods(["GET"])
def list_available_files(request):
    """
    API endpoint to list available graph files.
    """
    try:
        # Look for files in graph_creation/result directory
        result_dir = os.path.join(settings.BASE_DIR.parent, 'graph_creation', 'result')
        
        files = []
        if os.path.exists(result_dir):
            for filename in os.listdir(result_dir):
                if filename.endswith('.R') or filename.endswith('.r') or filename.endswith('.rds'):
                    files.append({
                        'name': filename,
                        'path': os.path.join(result_dir, filename)
                    })
        
        return JsonResponse({
            'success': True,
            'files': files
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["POST"])
def load_graph_file(request):
    """
    API endpoint to load a selected graph file.
    """
    try:
        data = json.loads(request.body)
        filename = data.get('filename')
        filter_type = data.get('filter_type', 'none')
        
        # TODO: Implement graph loading using R interface
        
        return JsonResponse({
            'success': True,
            'message': f'Graph {filename} loaded successfully',
            'nodes': [],
            'edges': []
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)


@require_http_methods(["POST"])
def upload_graph_file(request):
    """
    API endpoint to upload a new graph file.
    """
    try:
        if 'file' not in request.FILES:
            return JsonResponse({
                'success': False,
                'error': 'No file provided'
            }, status=400)
        
        uploaded_file = request.FILES['file']
        
        # Validate file extension
        if not (uploaded_file.name.endswith('.R') or uploaded_file.name.endswith('.r')):
            return JsonResponse({
                'success': False,
                'error': 'Only R files (.R, .r) are allowed'
            }, status=400)
        
        # Save file
        file_path = default_storage.save(
            f'graphs/{uploaded_file.name}',
            uploaded_file
        )
        
        # TODO: Load the uploaded file using R interface
        
        return JsonResponse({
            'success': True,
            'message': f'File {uploaded_file.name} uploaded successfully',
            'file_path': file_path
        })
    except Exception as e:
        return JsonResponse({
            'success': False,
            'error': str(e)
        }, status=400)

