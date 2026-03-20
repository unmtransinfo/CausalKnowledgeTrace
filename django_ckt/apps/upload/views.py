"""
Views for file upload and graph loading.
"""
import json
import logging
import os
import zipfile
from io import BytesIO

from django.conf import settings
from django.core.files.storage import default_storage
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.views.generic import TemplateView

logger = logging.getLogger(__name__)

ALLOWED_EXTENSIONS = ('.json', '.zip')


def _is_allowed_file(filename):
    """Check if filename has an allowed extension."""
    return any(filename.lower().endswith(ext) for ext in ALLOWED_EXTENSIONS)


def _get_graph_dirs():
    """Return list of directories to search for graph files."""
    return [
        os.path.join(settings.BASE_DIR, 'graph_creation', 'result'),  # Docker: /app/graph_creation/result
        os.path.join(settings.BASE_DIR, 'graph_data', 'result'),      # Docker: /app/graph_data/result
        os.path.join(settings.BASE_DIR.parent, 'graph_creation', 'result'),  # local dev
        os.path.join(settings.MEDIA_ROOT, 'graphs'),
    ]


def _find_graph_file(filename):
    """Find graph file across known directories. Returns full path or None."""
    for directory in _get_graph_dirs():
        full_path = os.path.join(directory, filename)
        if os.path.isfile(full_path):
            return full_path
    return None


def _validate_graph_for_visualization(nodes, edges):
    """
    Validate that graph data can be rendered by the Graph Visualization panel.

    The vis-network renderer expects:
      - nodes: non-empty list where each item has data.id
      - edges: list where each item has data.source and data.target
      - all edge source/target values reference existing node IDs

    Returns (is_valid, error_message).
    """
    if not isinstance(nodes, list) or not isinstance(edges, list):
        return False, 'Graph data is malformed: "nodes" and "edges" must be arrays'

    if len(nodes) == 0:
        return False, 'Graph contains no nodes and cannot be visualized'

    # Validate node structure
    node_ids = set()
    for i, node in enumerate(nodes):
        if not isinstance(node, dict) or 'data' not in node:
            return False, f'Node at index {i} is missing the required "data" object'
        node_data = node['data']
        if not isinstance(node_data, dict) or 'id' not in node_data:
            return False, f'Node at index {i} is missing a "data.id" field required for rendering'
        node_ids.add(node_data['id'])

    # Validate edge structure
    for i, edge in enumerate(edges):
        if not isinstance(edge, dict) or 'data' not in edge:
            return False, f'Edge at index {i} is missing the required "data" object'
        edge_data = edge['data']
        if not isinstance(edge_data, dict):
            return False, f'Edge at index {i} has an invalid "data" field'
        if 'source' not in edge_data or 'target' not in edge_data:
            return False, f'Edge at index {i} is missing "data.source" or "data.target" fields required for rendering'
        if edge_data['source'] not in node_ids:
            return False, (f'Edge at index {i} references source "{edge_data["source"]}" '
                           f'which does not match any node ID')
        if edge_data['target'] not in node_ids:
            return False, (f'Edge at index {i} references target "{edge_data["target"]}" '
                           f'which does not match any node ID')

    return True, None


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
                if (not _is_allowed_file(filename)
                        or filename in seen
                        or '_causal_assertions' in filename):
                    continue
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

        # Validate that the graph data can be rendered in Graph Visualization
        is_valid, validation_error = _validate_graph_for_visualization(nodes, edges)
        if not is_valid:
            return JsonResponse({
                'success': False,
                'error': f'Graph file "{filename}" cannot be visualized: {validation_error}'
            }, status=400)

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
            'message': f'Graph {filename} loaded and verified for visualization '
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
    API endpoint to upload a new graph file (.json or .zip).
    Supports:
      - Regular JSON graph files
      - ZIP files containing reduced_graph.json (from Analysis tab export)
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
                'error': f'Only JSON or ZIP files ({", ".join(ALLOWED_EXTENSIONS)}) are allowed'
            }, status=400)

        # Handle ZIP files (reduced graphs from Analysis tab)
        if uploaded_file.name.lower().endswith('.zip'):
            try:
                content = uploaded_file.read()
                zip_buffer = BytesIO(content)
                with zipfile.ZipFile(zip_buffer, 'r') as zip_file:
                    # Look for reduced_graph.json in the ZIP
                    if 'reduced_graph.json' not in zip_file.namelist():
                        return JsonResponse({
                            'success': False,
                            'error': 'ZIP file must contain reduced_graph.json'
                        }, status=400)

                    # Extract and parse the graph JSON
                    graph_json = zip_file.read('reduced_graph.json').decode('utf-8')
                    graph_data = json.loads(graph_json)

                    # Use the original filename but change extension to .json
                    json_filename = uploaded_file.name.rsplit('.', 1)[0] + '.json'
            except zipfile.BadZipFile:
                return JsonResponse({
                    'success': False,
                    'error': 'Invalid ZIP file'
                }, status=400)
            except json.JSONDecodeError as e:
                return JsonResponse({
                    'success': False,
                    'error': f'Invalid JSON in reduced_graph.json: {e}'
                }, status=400)
        else:
            # Handle regular JSON files
            # Reject causal assertions files — they are supporting evidence data,
            # not graph files, and would not appear in the file listing.
            if '_causal_assertions' in uploaded_file.name:
                return JsonResponse({
                    'success': False,
                    'error': 'Causal assertions files cannot be uploaded directly. '
                             'Please upload a graph file instead.'
                }, status=400)

            # Validate JSON content
            try:
                content = uploaded_file.read()
                graph_data = json.loads(content)
                uploaded_file.seek(0)
                json_filename = uploaded_file.name
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

        nodes = elements.get('nodes', [])
        edges = elements.get('edges', [])

        # Validate that the graph data can be rendered in Graph Visualization
        is_valid, validation_error = _validate_graph_for_visualization(nodes, edges)
        if not is_valid:
            return JsonResponse({
                'success': False,
                'error': f'Uploaded file cannot be visualized: {validation_error}'
            }, status=400)

        # Save to graph_creation/result directory
        result_dir = os.path.join(
            settings.BASE_DIR.parent, 'graph_creation', 'result'
        )
        os.makedirs(result_dir, exist_ok=True)
        dest_path = os.path.join(result_dir, json_filename)

        # Write the graph JSON to disk
        with open(dest_path, 'w') as f:
            json.dump(graph_data, f, indent=2)

        # Also load into session
        filter_type = request.POST.get('filter_type', 'none')
        metadata = graph_data.get('metadata', {})

        request.session.pop('graph_data', None)
        request.session['graph_source'] = {
            'filename': json_filename,
            'filter_type': filter_type,
        }
        request.session['graph_deletions'] = {'nodes': [], 'edges': []}
        request.session['graph_undo_stack'] = []
        request.session.modified = True

        return JsonResponse({
            'success': True,
            'message': f'Graph {json_filename} uploaded and verified for visualization '
                       f'({len(nodes)} nodes, {len(edges)} edges)',
            'file_path': dest_path,
            'nodes': nodes,
            'edges': edges,
        })
    except Exception as e:
        logger.exception("Error uploading graph file")
        return JsonResponse({'success': False, 'error': str(e)}, status=400)

