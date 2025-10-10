#!/usr/bin/env python3
"""
General Graph Operations Module

This module provides functionality for general causal graph analysis on biomedical literature data.
It focuses on core graph operations without Markov blanket-specific functionality, following
the single responsibility principle.

This module is the result of refactoring the original mixed-responsibility code to separate
general graph operations from Markov blanket-specific operations.

Author: Scott A. Malec PhD
Date: February 2025
"""

# Re-export the GraphAnalyzer class for backward compatibility and clear naming
from analysis_core import GraphAnalyzer

# Make GraphAnalyzer available as the main class for this module
__all__ = ['GraphAnalyzer']

# For convenience, create an alias that makes the purpose clear
GeneralGraphAnalyzer = GraphAnalyzer

def create_graph_analyzer(config_name: str,
                         db_params: dict,
                         threshold: int,
                         output_dir: str = "output",
                         yaml_config_data: dict = None,
                         degree: int = 3) -> GraphAnalyzer:
    """
    Factory function to create a GraphAnalyzer instance for general graph operations.
    
    This function provides a clear entry point for creating graph analyzers that focus
    only on general graph operations without Markov blanket functionality.
    
    Args:
        config_name: Name of the predefined configuration
        db_params: Database connection parameters
        threshold: Minimum evidence threshold for relationships
        output_dir: Directory for output files
        yaml_config_data: Optional YAML configuration data
        degree: Number of degrees for graph traversal (1-3, default: 3)
        
    Returns:
        GraphAnalyzer: Configured analyzer for general graph operations
        
    Example:
        >>> analyzer = create_graph_analyzer(
        ...     config_name="smoking_lung_cancer",
        ...     db_params={"host": "localhost", "port": 5432, "dbname": "causal"},
        ...     threshold=5,
        ...     degree=2
        ... )
        >>> results = analyzer.run_analysis()
    """
    return GraphAnalyzer(
        config_name=config_name,
        db_params=db_params,
        threshold=threshold,
        output_dir=output_dir,
        yaml_config_data=yaml_config_data,
        degree=degree
    )
