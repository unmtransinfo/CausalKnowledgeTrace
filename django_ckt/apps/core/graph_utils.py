"""
Shared graph-loading utilities used by upload, visualization, and analysis apps.
"""
import json
import logging
import os

from django.conf import settings

logger = logging.getLogger(__name__)


def get_graph_dirs():
    """Return list of directories to search for graph files."""
    return [
        os.path.join(settings.BASE_DIR, 'graph_creation', 'result'),  # Docker: /app/graph_creation/result
        os.path.join(settings.BASE_DIR, 'graph_data', 'result'),      # Docker: /app/graph_data/result
        os.path.join(settings.BASE_DIR.parent, 'graph_creation', 'result'),  # local dev
        os.path.join(settings.MEDIA_ROOT, 'graphs'),
    ]


def find_graph_file(filename):
    """Find graph file across known directories. Returns full path or None."""
    for directory in get_graph_dirs():
        full_path = os.path.join(directory, filename)
        if os.path.isfile(full_path):
            return full_path
    return None


def load_graph_from_disk(filename, filter_type='none'):
    """
    Load nodes, edges, metadata from disk by filename.
    Returns (nodes, edges, metadata) or raises FileNotFoundError.
    """
    file_path = find_graph_file(filename)
    if not file_path:
        raise FileNotFoundError(f'Graph file not found: {filename}')

    with open(file_path, 'r') as f:
        graph_data = json.load(f)

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


def get_selected_graph(session):
    """
    Load the graph that was explicitly selected via Data Upload.
    Returns (nodes, edges, metadata, filename).
    Raises ValueError if no graph was selected.
    """
    source = session.get('graph_source', {})
    filename = source.get('filename', '')
    filter_type = source.get('filter_type', 'none')

    if not filename:
        raise ValueError(
            'No graph loaded. Please upload or select a graph from the Data Upload tab first.'
        )

    nodes, edges, metadata = load_graph_from_disk(filename, filter_type)
    return nodes, edges, metadata, filename


def apply_deletions(nodes, edges, deleted_node_ids, deleted_edge_ids):
    """Remove deleted IDs from nodes/edges lists."""
    del_nodes = set(deleted_node_ids)
    del_edges = set(deleted_edge_ids)
    nodes = [n for n in nodes if n['data']['id'] not in del_nodes]
    edges = [e for e in edges
             if e['data']['id'] not in del_edges
             and e['data']['source'] not in del_nodes
             and e['data']['target'] not in del_nodes]
    return nodes, edges

