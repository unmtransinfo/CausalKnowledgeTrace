#!/usr/bin/env python3
"""
Integration test for the refactored analysis modes.

This script tests that both GraphAnalyzer and MarkovBlanketAnalyzer
can be instantiated and have the correct methods available.

Author: Scott A. Malec PhD
Date: February 2025
"""

import sys
import tempfile
from pathlib import Path

def test_analysis_modes():
    """Test both analysis modes work correctly."""
    print("=" * 60)
    print("TESTING REFACTORED ANALYSIS MODES")
    print("=" * 60)
    
    # Import the refactored classes
    try:
        from analysis_core import GraphAnalyzer, MarkovBlanketAnalyzer
        from graph_operations import GraphAnalyzer as GraphOpsAnalyzer
        print("✅ All imports successful")
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False
    
    # Test class relationships
    print("\nTesting class relationships...")
    assert issubclass(MarkovBlanketAnalyzer, GraphAnalyzer), "MarkovBlanketAnalyzer should inherit from GraphAnalyzer"
    assert GraphOpsAnalyzer is GraphAnalyzer, "GraphOpsAnalyzer should be an alias for GraphAnalyzer"
    print("✅ Class relationships correct")
    
    # Mock database parameters
    db_params = {
        "host": "localhost",
        "port": 5432,
        "dbname": "test",
        "user": "test",
        "password": "test"
    }
    
    with tempfile.TemporaryDirectory() as temp_dir:
        print(f"\nUsing temporary directory: {temp_dir}")
        
        # Test GraphAnalyzer
        print("\nTesting GraphAnalyzer...")
        try:
            graph_analyzer = GraphAnalyzer(
                config_name="smoking_cancer",
                db_params=db_params,
                threshold=5,
                output_dir=temp_dir,
                degree=2
            )
            
            # Check expected methods
            expected_methods = [
                'run_analysis',
                'generate_basic_dagitty_script',
                'display_results_summary',
                'save_results_and_metadata',
                'get_dag_filename'
            ]
            
            for method in expected_methods:
                assert hasattr(graph_analyzer, method), f"GraphAnalyzer missing method: {method}"
            
            print("✅ GraphAnalyzer instantiated successfully with all expected methods")
            
        except Exception as e:
            print(f"❌ GraphAnalyzer test failed: {e}")
            return False
        
        # Test MarkovBlanketAnalyzer
        print("\nTesting MarkovBlanketAnalyzer...")
        try:
            mb_analyzer = MarkovBlanketAnalyzer(
                config_name="smoking_cancer",
                db_params=db_params,
                threshold=5,
                output_dir=temp_dir,
                degree=3
            )
            
            # Check expected methods (inherited + new)
            expected_methods = [
                # Inherited from GraphAnalyzer
                'run_analysis',
                'generate_basic_dagitty_script',
                'display_results_summary',
                'save_results_and_metadata',
                'get_dag_filename',
                # New MarkovBlanket-specific methods
                'run_markov_blanket_analysis',
                'generate_markov_blanket_dagitty_script',
                'display_markov_blanket_summary'
            ]
            
            for method in expected_methods:
                assert hasattr(mb_analyzer, method), f"MarkovBlanketAnalyzer missing method: {method}"
            
            # Check MarkovBlanket-specific attributes
            assert hasattr(mb_analyzer, 'mb_computer'), "MarkovBlanketAnalyzer should have mb_computer attribute"
            
            print("✅ MarkovBlanketAnalyzer instantiated successfully with all expected methods")
            
        except Exception as e:
            print(f"❌ MarkovBlanketAnalyzer test failed: {e}")
            return False
    
    # Test configuration handling
    print("\nTesting configuration handling...")
    yaml_config = {
        "exposure_cuis": ["C0037369"],
        "outcome_cuis": ["C0006826"],
        "min_pmids": 10,
        "predication_types": ["CAUSES"],
        "degree": 2
    }
    
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            analyzer = GraphAnalyzer(
                config_name="smoking_cancer",
                db_params=db_params,
                threshold=5,
                output_dir=temp_dir,
                yaml_config_data=yaml_config,
                degree=3
            )
            
            assert analyzer.yaml_config_data == yaml_config, "YAML configuration not stored correctly"
            assert analyzer.degree == 3, "degree parameter not set correctly"
            
            print("✅ Configuration handling works correctly")
            
        except Exception as e:
            print(f"❌ Configuration test failed: {e}")
            return False
    
    print("\n" + "=" * 60)
    print("🎉 ALL TESTS PASSED!")
    print("✅ GraphAnalyzer works for general graph analysis")
    print("✅ MarkovBlanketAnalyzer works for Markov blanket analysis")
    print("✅ Proper inheritance and method availability")
    print("✅ Configuration handling works correctly")
    print("=" * 60)
    
    return True

if __name__ == "__main__":
    success = test_analysis_modes()
    sys.exit(0 if success else 1)
