"""
R Interface for CausalKnowledgeTrace Django Application

This module provides a Python interface to R functions using rpy2.
It wraps all R modules from the original Shiny application.
"""

import os
from pathlib import Path
from django.conf import settings
import logging

logger = logging.getLogger(__name__)

# Try to import rpy2
try:
    import rpy2.robjects as ro
    from rpy2.robjects import pandas2ri
    from rpy2.robjects.packages import importr
    
    # Activate pandas conversion
    pandas2ri.activate()
    
    R_AVAILABLE = True
    logger.info("rpy2 successfully imported")
except ImportError as e:
    R_AVAILABLE = False
    logger.warning(f"rpy2 not available: {e}")
    ro = None


class RInterface:
    """
    Interface to R functions for DAG visualization and analysis.
    """
    
    def __init__(self):
        """Initialize R interface and load required R modules."""
        if not R_AVAILABLE:
            raise ImportError("rpy2 is not installed. Install with: pip install rpy2")
        
        self.r = ro.r
        self.r_modules_path = settings.R_MODULES_PATH
        
        # Initialize R libraries
        self._init_r_libraries()
        
        # Source R modules
        self._source_r_modules()
    
    def _init_r_libraries(self):
        """Initialize required R libraries."""
        try:
            logger.info("Loading R libraries...")
            
            # Import required R packages
            self.dagitty = importr('dagitty')
            self.igraph = importr('igraph')
            self.visNetwork = importr('visNetwork')
            self.dplyr = importr('dplyr')
            
            logger.info("R libraries loaded successfully")
        except Exception as e:
            logger.error(f"Error loading R libraries: {e}")
            raise
    
    def _source_r_modules(self):
        """Source all R modules from r_modules directory."""
        try:
            logger.info(f"Sourcing R modules from {self.r_modules_path}")

            # List of core R modules to source (in dependency order)
            modules = [
                # Core utilities
                'logging_utility.R',
                'cui_formatting.R',

                # Database and data loading
                'database_connection.R',
                'file_scanning.R',
                'dag_loading.R',

                # Graph processing
                'network_processing.R',
                'edge_operations.R',
                'graph_filtering.R',
                'node_information.R',

                # Visualization
                'dag_visualization.R',

                # Analysis
                'causal_analysis.R',
                'statistics.R',

                # Data upload
                'data_upload.R',
                'data_upload_refactored.R',

                # Graph configuration
                'cui_search.R',
                'config_validation.R',
                'config_processing.R',

                # Assertions and HTML generation
                'assertions_loading.R',
                'html_core.R',
                'html_headers.R',
                'html_sections.R',
                'html_styles.R',
                'html_assertions.R',
                'json_to_html.R',
            ]

            for module in modules:
                module_path = self.r_modules_path / module
                if module_path.exists():
                    self.r.source(str(module_path))
                    logger.info(f"Sourced {module}")
                else:
                    logger.warning(f"Module not found: {module_path}")

            logger.info("R modules sourced successfully")
        except Exception as e:
            logger.error(f"Error sourcing R modules: {e}")
            raise
    
    def load_dag_from_file(self, file_path):
        """
        Load a DAG from an R file.
        
        Args:
            file_path: Path to the R file containing DAG definition
            
        Returns:
            dict: Dictionary containing nodes and edges data
        """
        try:
            result = self.r['load_dag_from_file'](file_path)
            return {
                'success': True,
                'dag_object': result,
                'message': f'DAG loaded from {file_path}'
            }
        except Exception as e:
            logger.error(f"Error loading DAG: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def create_network_data(self, dag_object):
        """
        Create network visualization data from DAG object.
        
        Args:
            dag_object: R dagitty object
            
        Returns:
            dict: Dictionary containing nodes and edges for visualization
        """
        try:
            result = self.r['create_network_data'](dag_object)
            return {
                'success': True,
                'nodes': result.rx2('nodes'),
                'edges': result.rx2('edges')
            }
        except Exception as e:
            logger.error(f"Error creating network data: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def calculate_adjustment_sets(self, dag_object, exposure, outcome, effect_type='total'):
        """
        Calculate adjustment sets for causal inference.
        
        Args:
            dag_object: R dagitty object
            exposure: Exposure variable name
            outcome: Outcome variable name
            effect_type: 'total' or 'direct'
            
        Returns:
            dict: Dictionary containing adjustment sets
        """
        try:
            result = self.r['calculate_adjustment_sets'](
                dag_object, exposure, outcome, effect_type
            )
            return {
                'success': True,
                'adjustment_sets': result
            }
        except Exception as e:
            logger.error(f"Error calculating adjustment sets: {e}")
            return {
                'success': False,
                'error': str(e)
            }
    
    def find_instrumental_variables(self, dag_object, exposure, outcome):
        """
        Find instrumental variables.

        Args:
            dag_object: R dagitty object
            exposure: Exposure variable name
            outcome: Outcome variable name

        Returns:
            dict: Dictionary containing instrumental variables
        """
        try:
            result = self.r['find_instrumental_variables'](
                dag_object, exposure, outcome
            )
            return {
                'success': True,
                'instruments': result
            }
        except Exception as e:
            logger.error(f"Error finding instrumental variables: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def create_interactive_network(self, nodes_df, edges_df, physics_strength=-150, force_full_display=False):
        """
        Create interactive network visualization using visNetwork.

        Args:
            nodes_df: DataFrame containing node information
            edges_df: DataFrame containing edge information
            physics_strength: Gravitational constant for physics simulation
            force_full_display: Whether to force full display of all nodes/edges

        Returns:
            dict: Dictionary containing visNetwork HTML or error
        """
        try:
            result = self.r['create_interactive_network'](
                nodes_df, edges_df, physics_strength, force_full_display
            )
            return {
                'success': True,
                'network': result
            }
        except Exception as e:
            logger.error(f"Error creating interactive network: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def generate_legend_html(self, nodes_df):
        """
        Generate legend HTML for graph visualization.

        Args:
            nodes_df: DataFrame containing node information

        Returns:
            dict: Dictionary containing legend HTML
        """
        try:
            result = self.r['generate_legend_html'](nodes_df)
            return {
                'success': True,
                'legend_html': str(result[0])
            }
        except Exception as e:
            logger.error(f"Error generating legend: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def search_cui(self, search_term, search_type='both', limit=100):
        """
        Search for CUI (Concept Unique Identifier) in database.

        Args:
            search_term: Search term
            search_type: 'subject', 'object', or 'both'
            limit: Maximum number of results

        Returns:
            dict: Dictionary containing search results
        """
        try:
            result = self.r['search_cui'](search_term, search_type, limit)
            return {
                'success': True,
                'results': result
            }
        except Exception as e:
            logger.error(f"Error searching CUI: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def remove_node(self, dag_object, node_id):
        """
        Remove a node from the DAG.

        Args:
            dag_object: R dagitty object
            node_id: ID of node to remove

        Returns:
            dict: Dictionary containing updated DAG
        """
        try:
            result = self.r['remove_node'](dag_object, node_id)
            return {
                'success': True,
                'dag_object': result
            }
        except Exception as e:
            logger.error(f"Error removing node: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def remove_edge(self, dag_object, from_node, to_node):
        """
        Remove an edge from the DAG.

        Args:
            dag_object: R dagitty object
            from_node: Source node ID
            to_node: Target node ID

        Returns:
            dict: Dictionary containing updated DAG
        """
        try:
            result = self.r['remove_edge'](dag_object, from_node, to_node)
            return {
                'success': True,
                'dag_object': result
            }
        except Exception as e:
            logger.error(f"Error removing edge: {e}")
            return {
                'success': False,
                'error': str(e)
            }


# Global R interface instance
_r_interface = None


def get_r_interface():
    """
    Get or create the global R interface instance.

    Returns:
        RInterface: The R interface instance
    """
    global _r_interface

    if _r_interface is None:
        if not R_AVAILABLE:
            raise ImportError("rpy2 is not available")
        _r_interface = RInterface()

    return _r_interface

