"""
Views for file upload and graph loading.
"""
import json
import logging
import os

from django.conf import settings
from django.core.files.storage import default_storage
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.generic import TemplateView

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = ('.json',)


def _is_allowed_file(filename):
    """Check if filename has an allowed extension."""
    return any(filename.lower().endswith(ext) for ext in ALLOWED_EXTENSIONS)


def _get_graph_dirs():
    """Return list of directories to search for graph files."""
    return [
        os.path.join(settings.BASE_DIR.parent, 'graph_creation', 'result'),
        os.path.join(settings.BASE_DIR, 'static', 'sample_data'),
        os.path.join(settings.MEDIA_ROOT, 'graphs'),
    ]


def _find_graph_file(filename):
    """Find graph file across known directories. Returns full path or None."""
    for directory in _get_graph_dirs():
        full_path = os.path.join(directory, filename)
        if os.path.isfile(full_path):
            return full_path
    return None


def _load_json_graph(file_path, filter_type='none'):
    """
    Load a JSON graph file and return nodes/edges in Cytoscape.js format.

    Expected JSON format:
    {
        "elements": {
            "nodes": [{"data": {"id": "n1", "label": "...", "type": "...", ...}}],
            "edges": [{"data": {"id": "e1", "source": "n1", "target": "n2", ...}}]
        },
        "metadata": { ... }
    }
    """
    with open(file_path, 'r') as f:
        graph_data = json.load(f)

    elements = graph_data.get('elements', graph_data)
    nodes = elements.get('nodes', [])
    edges = elements.get('edges', [])

    if filter_type == 'remove_leaf':
        # Build degree map
        degree = {}
        for node in nodes:
            nid = node['data']['id']
            degree[nid] = 0
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
        files = []
        seen = set()

        for directory in _get_graph_dirs():
            if not os.path.exists(directory):
                continue
            for filename in sorted(os.listdir(directory)):
                if _is_allowed_file(filename) and filename not in seen:
                    seen.add(filename)
                    full_path = os.path.join(directory, filename)
                    # Try to read metadata for node/edge counts
                    node_count = None
                    edge_count = None
                    try:
                        with open(full_path, 'r') as f:
                            data = json.load(f)
                        meta = data.get('metadata', {})
                        node_count = meta.get('node_count')
                        edge_count = meta.get('edge_count')
                        if node_count is None:
                            elems = data.get('elements', data)
                            node_count = len(elems.get('nodes', []))
                            edge_count = len(elems.get('edges', []))
                    except Exception:
                        pass
                    files.append({
                        'name': filename,
                        'path': full_path,
                        'node_count': node_count,
                        'edge_count': edge_count,
                    })

        return JsonResponse({'success': True, 'files': files})
    except Exception as e:
        logger.exception("Error listing files")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["POST"])
def load_graph_file(request):
    """
    API endpoint to load a selected graph file.
    Returns nodes and edges in Cytoscape.js JSON format.
    """
    try:
        data = json.loads(request.body)
        filename = data.get('filename')
        filter_type = data.get('filter_type', 'none')

        if not filename:
            return JsonResponse(
                {'success': False, 'error': 'No filename provided'}, status=400
            )

        file_path = _find_graph_file(filename)
        if not file_path:
            return JsonResponse(
                {'success': False, 'error': f'File {filename} not found'}, status=404
            )

        if not _is_allowed_file(filename):
            return JsonResponse(
                {'success': False, 'error': 'Unsupported file format'}, status=400
            )

        nodes, edges, metadata = _load_json_graph(file_path, filter_type)

        # Remove the legacy large 'graph_data' key if it exists (it bloats the session)
        request.session.pop('graph_data', None)
        # Store only lightweight reference in session (full data is loaded from disk on demand)
        # This avoids storing multi-MB graph data in the session backend
        request.session['graph_source'] = {
            'filename': filename,
            'filter_type': filter_type,
        }
        request.session['graph_deletions'] = {'nodes': [], 'edges': []}
        request.session['graph_undo_stack'] = []
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': f'Graph {filename} loaded successfully '
                       f'({len(nodes)} nodes, {len(edges)} edges)',
            'nodes': nodes,
            'edges': edges,
            'metadata': metadata,
        })
    except json.JSONDecodeError as e:
        return JsonResponse(
            {'success': False, 'error': f'Invalid JSON: {e}'}, status=400
        )
    except Exception as e:
        logger.exception("Error loading graph file")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)


@require_http_methods(["POST"])
def upload_graph_file(request):
    """
    API endpoint to upload a new graph file (.json).
    """
    try:
        if 'file' not in request.FILES:
            return JsonResponse(
                {'success': False, 'error': 'No file provided'}, status=400
            )

        uploaded_file = request.FILES['file']

        # Validate file extension
        if not _is_allowed_file(uploaded_file.name):
            return JsonResponse({
                'success': False,
                'error': f'Only JSON files ({", ".join(ALLOWED_EXTENSIONS)}) are allowed'
            }, status=400)

        # Validate JSON content
        try:
            content = uploaded_file.read()
            graph_data = json.loads(content)
            uploaded_file.seek(0)
        except json.JSONDecodeError as e:
            return JsonResponse(
                {'success': False, 'error': f'Invalid JSON file: {e}'}, status=400
            )

        # Validate structure
        elements = graph_data.get('elements', graph_data)
        if 'nodes' not in elements or 'edges' not in elements:
            return JsonResponse({
                'success': False,
                'error': 'JSON must contain "elements" with "nodes" and "edges" arrays'
            }, status=400)

        # Save to graph_creation/result directory
        result_dir = os.path.join(
            settings.BASE_DIR.parent, 'graph_creation', 'result'
        )
        os.makedirs(result_dir, exist_ok=True)
        dest_path = os.path.join(result_dir, uploaded_file.name)

        with open(dest_path, 'wb') as f:
            for chunk in uploaded_file.chunks():
                f.write(chunk)

        # Also load into session
        nodes = elements.get('nodes', [])
        edges = elements.get('edges', [])
        metadata = graph_data.get('metadata', {})

        request.session.pop('graph_data', None)
        request.session['graph_source'] = {
            'filename': uploaded_file.name,
            'filter_type': 'none',
        }
        request.session['graph_deletions'] = {'nodes': [], 'edges': []}
        request.session['graph_undo_stack'] = []
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': f'File {uploaded_file.name} uploaded successfully '
                       f'({len(nodes)} nodes, {len(edges)} edges)',
            'file_path': dest_path,
            'nodes': nodes,
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error uploading graph file")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)

