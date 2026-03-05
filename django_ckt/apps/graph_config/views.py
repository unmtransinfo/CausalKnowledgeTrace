"""
Views for graph configuration.
"""
from django.shortcuts import render
from django.views.generic import TemplateView
from django.http import JsonResponse
from django.views.decorators.http import require_http_methods
from django.conf import settings
from apps.core.models import SubjectSearch, ObjectSearch
import json
import yaml
import os
import subprocess
import logging
import threading
from datetime import datetime

logger = logging.getLogger(__name__)


class _IndentedListDumper(yaml.Dumper):
    """Custom YAML dumper that indents list items under their parent key."""
    def increase_indent(self, flow=False, indentless=False):
        return super().increase_indent(flow, False)


class GraphConfigView(TemplateView):
    """
    Main graph configuration view.
    """
    template_name = 'graph_config/config.html'

    def _load_default_config(self):
        """Load default configuration from default_config.yaml."""
        config_path = os.path.join(settings.BASE_DIR, 'config', 'default_config.yaml')
        try:
            with open(config_path, 'r') as f:
                return yaml.safe_load(f)
        except (FileNotFoundError, yaml.YAMLError):
            return {}

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['page_title'] = 'Graph Configuration'
        context['active_tab'] = 'create_graph'

        # Load defaults from YAML config file
        defaults = self._load_default_config()

        # Generate year range for publication year cutoff dropdown
        current_year = datetime.now().year
        context['year_range'] = range(1980, current_year + 2)  # 1980 to current year + 1
        context['default_year'] = defaults.get('pub_year_cutoff', 2015)

        # CUI defaults as comma-separated strings for selected fields
        exposure_cuis = defaults.get('exposure_cuis', [])
        outcome_cuis = defaults.get('outcome_cuis', [])
        blocklist_cuis = defaults.get('blocklist_cuis') or []

        context['default_exposure_cuis_selected'] = ', '.join(exposure_cuis) if exposure_cuis else ''
        context['default_outcome_cuis_selected'] = ', '.join(outcome_cuis) if outcome_cuis else ''
        context['default_blocklist_cuis_selected'] = ', '.join(blocklist_cuis) if blocklist_cuis else ''

        # Scalar defaults
        context['default_exposure_name'] = defaults.get('exposure_name', '')
        context['default_outcome_name'] = defaults.get('outcome_name', '')
        context['default_degree'] = defaults.get('degree', 3)
        context['default_min_pmids_degree1'] = defaults.get('min_pmids_degree1', 10)
        context['default_min_pmids_degree2'] = defaults.get('min_pmids_degree2', 100)
        context['default_min_pmids_degree3'] = defaults.get('min_pmids_degree3', 200)
        context['default_predication_type'] = defaults.get('predication_type', 'CAUSES')
        context['default_semmeddb_version'] = defaults.get('SemMedDBD_version', 'heuristic')

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
    Saves configuration to user_input.yaml and initiates graph generation.
    """
    try:
        data = json.loads(request.body)

        # Extract and parse CUIs from comma-separated strings
        exposure_cuis_str = data.get('exposure_cuis', '')
        outcome_cuis_str = data.get('outcome_cuis', '')
        blocklist_cuis_str = data.get('blocklist_cuis', '')

        # Parse CUIs into lists (remove whitespace and filter empty strings)
        exposure_cuis = [cui.strip() for cui in exposure_cuis_str.split(',') if cui.strip()]
        outcome_cuis = [cui.strip() for cui in outcome_cuis_str.split(',') if cui.strip()]
        blocklist_cuis = [cui.strip() for cui in blocklist_cuis_str.split(',') if cui.strip()] if blocklist_cuis_str else None

        # Extract other parameters
        exposure_name = data.get('exposure_name', '').replace(' ', '_')
        outcome_name = data.get('outcome_name', '').replace(' ', '_')
        degree = int(data.get('degree', 3))
        min_pmids_degree1 = int(data.get('min_pmids_degree1', 10))
        min_pmids_degree2 = int(data.get('min_pmids_degree2', 100))
        min_pmids_degree3 = int(data.get('min_pmids_degree3', 200))
        pub_year_cutoff = int(data.get('pub_year_cutoff', 2015))

        # Handle predication_type (can be array or string)
        predication_type = data.get('predication_type', 'CAUSES')
        if isinstance(predication_type, list):
            predication_type = ','.join(predication_type)

        semmeddb_version = data.get('semmeddb_version', 'heuristic')

        # Validate required fields
        if not exposure_cuis or not outcome_cuis:
            return JsonResponse({
                'success': False,
                'error': 'Exposure CUIs and Outcome CUIs are required'
            }, status=400)

        if not exposure_name or not outcome_name:
            return JsonResponse({
                'success': False,
                'error': 'Exposure Name and Outcome Name are required'
            }, status=400)

        # Create configuration dictionary matching user_input.yaml structure
        config = {
            'exposure_cuis': exposure_cuis,
            'outcome_cuis': outcome_cuis,
            'blocklist_cuis': blocklist_cuis,
            'exposure_name': exposure_name,
            'outcome_name': outcome_name,
            'min_pmids_degree1': min_pmids_degree1,
            'min_pmids_degree2': min_pmids_degree2,
            'min_pmids_degree3': min_pmids_degree3,
            'pub_year_cutoff': pub_year_cutoff,
            'degree': degree,
            'predication_type': predication_type,
            'SemMedDBD_version': semmeddb_version,
        }

        # Determine the path to user_input.yaml
        # It should be in the project root directory
        base_dir = settings.BASE_DIR.parent  # Go up one level from django_ckt to CausalKnowledgeTrace
        yaml_path = os.path.join(base_dir, 'user_input.yaml')

        # Save configuration to YAML file
        with open(yaml_path, 'w') as f:
            yaml.dump(config, f, Dumper=_IndentedListDumper,
                      default_flow_style=False, sort_keys=False)

        # Build a descriptive graph name for the notification
        graph_name = f"{exposure_name}_to_{outcome_name}_degree{degree}"

        # Read database credentials from environment variables
        db_host = os.environ.get('DB_HOST', 'localhost')
        db_port = os.environ.get('DB_PORT', '5433')
        db_user = os.environ.get('DB_USER', 'rajesh')
        db_password = os.environ.get('DB_PASSWORD', 'Software292')
        db_name = os.environ.get('DB_NAME', 'causalehr')

        # Build the graph creation command
        project_root = str(settings.BASE_DIR.parent)
        cmd = [
            'python', 'graph_creation/pushkin.py',
            '--yaml-config', 'user_input.yaml',
            '--dbname', db_name,
            '--user', db_user,
            '--password', db_password,
            '--host', db_host,
            '--port', db_port,
            '--verbose',
        ]

        # Run the command asynchronously in a background thread
        def _run_graph_creation():
            try:
                result = subprocess.run(
                    cmd,
                    cwd=project_root,
                    capture_output=True,
                    text=True,
                    timeout=3600,  # 1 hour timeout
                )
                if result.returncode != 0:
                    logger.error(
                        "Graph creation failed for '%s'.\nstderr: %s\nstdout: %s",
                        graph_name, result.stderr, result.stdout,
                    )
                else:
                    logger.info(
                        "Graph creation completed for '%s'.\nstdout: %s",
                        graph_name, result.stdout,
                    )
            except subprocess.TimeoutExpired:
                logger.error("Graph creation timed out for '%s'.", graph_name)
            except Exception as exc:
                logger.exception("Unexpected error during graph creation for '%s': %s", graph_name, exc)

        thread = threading.Thread(target=_run_graph_creation, daemon=True)
        thread.start()

        return JsonResponse({
            'success': True,
            'message': f'Graph generation for "{graph_name}" has been started. This may take several minutes.',
            'graph_name': graph_name,
            'exposure_name': exposure_name,
            'outcome_name': outcome_name,
            'degree': degree,
            'config_path': str(yaml_path),
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

