#!/usr/bin/env python3
"""
Test Suite for Refactored Modules

This test suite verifies that all functionality still works correctly
after refactoring pushkin.py and config.py into smaller modules.

Author: Scott A. Malec PhD
Date: February 2025
"""

import sys
import os
import tempfile
import yaml
from pathlib import Path
from unittest.mock import Mock, patch, MagicMock

# Add the graph_creation directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_config_models_imports():
    """Test that all imports from config_models work correctly."""
    print("Testing config_models imports...")
    
    try:
        from config_models import (
            VALID_PREDICATION_TYPES,
            validate_predication_types,
            load_yaml_config,
            ExposureOutcomePair,
            create_dynamic_config_from_yaml,
            EXPOSURE_OUTCOME_CONFIGS,
            EXCLUDED_CUIS,
            TimingContext,
            create_db_config,
            validate_arguments
        )
        print("✅ All config_models imports successful")
        return True
    except ImportError as e:
        print(f"❌ Config models import failed: {e}")
        return False

def test_database_operations_imports():
    """Test that DatabaseOperations import works correctly."""
    print("Testing database_operations imports...")
    
    try:
        from database_operations import DatabaseOperations
        print("✅ DatabaseOperations import successful")
        return True
    except ImportError as e:
        print(f"❌ DatabaseOperations import failed: {e}")
        return False

def test_analysis_core_imports():
    """Test that analysis_core imports work correctly."""
    print("Testing analysis_core imports...")
    
    try:
        from analysis_core import MarkovBlanketAnalyzer
        print("✅ MarkovBlanketAnalyzer import successful")
        return True
    except ImportError as e:
        print(f"❌ MarkovBlanketAnalyzer import failed: {e}")
        return False

def test_cli_interface_imports():
    """Test that cli_interface imports work correctly."""
    print("Testing cli_interface imports...")
    
    try:
        from cli_interface import parse_arguments, create_analysis_configuration, main
        print("✅ CLI interface imports successful")
        return True
    except ImportError as e:
        print(f"❌ CLI interface import failed: {e}")
        return False

def test_backward_compatibility():
    """Test that the old config.py still provides backward compatibility."""
    print("Testing backward compatibility...")
    
    try:
        from config import (
            EXPOSURE_OUTCOME_CONFIGS,
            TimingContext,
            DatabaseOperations,
            create_db_config,
            validate_arguments,
            load_yaml_config,
            create_dynamic_config_from_yaml
        )
        print("✅ Backward compatibility maintained")
        return True
    except ImportError as e:
        print(f"❌ Backward compatibility failed: {e}")
        return False

def test_exposure_outcome_pair():
    """Test ExposureOutcomePair functionality."""
    print("Testing ExposureOutcomePair...")
    
    try:
        from config_models import ExposureOutcomePair
        
        # Test single CUI
        config1 = ExposureOutcomePair(
            name="test_single",
            exposure_cui="C0011570",
            exposure_name="Depression",
            outcome_cui="C0002395",
            outcome_name="Alzheimers_Disease",
            description="Test configuration"
        )
        
        assert config1.exposure_cui_list == ["C0011570"]
        assert config1.outcome_cui_list == ["C0002395"]
        assert config1.all_target_cuis == ["C0011570", "C0002395"]
        
        # Test multiple CUIs
        config2 = ExposureOutcomePair(
            name="test_multiple",
            exposure_cui=["C0011849", "C0011860"],
            exposure_name="Diabetes",
            outcome_cui=["C0002395", "C0011265"],
            outcome_name="Dementia",
            description="Test multiple CUIs"
        )
        
        assert len(config2.exposure_cui_list) == 2
        assert len(config2.outcome_cui_list) == 2
        assert len(config2.all_target_cuis) == 4
        
        print("✅ ExposureOutcomePair tests passed")
        return True
    except Exception as e:
        print(f"❌ ExposureOutcomePair test failed: {e}")
        return False

def test_yaml_config_loading():
    """Test YAML configuration loading."""
    print("Testing YAML configuration loading...")
    
    try:
        from config_models import load_yaml_config
        
        # Create a temporary YAML file
        test_config = {
            'exposure_cuis': ['C0011849', 'C0020538'],
            'outcome_cuis': ['C0027051', 'C0038454'],
            'min_pmids': 100,
            'degree': 2,
            'predication_type': 'CAUSES,TREATS'
        }
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
            yaml.dump(test_config, f)
            temp_file = f.name
        
        try:
            loaded_config = load_yaml_config(temp_file)
            
            assert loaded_config['exposure_cuis'] == ['C0011849', 'C0020538']
            assert loaded_config['outcome_cuis'] == ['C0027051', 'C0038454']
            assert loaded_config['threshold'] == 100
            assert loaded_config['degree'] == 2
            assert 'CAUSES' in loaded_config['predication_types']
            assert 'TREATS' in loaded_config['predication_types']
            
            print("✅ YAML configuration loading tests passed")
            return True
        finally:
            os.unlink(temp_file)
            
    except Exception as e:
        print(f"❌ YAML configuration loading test failed: {e}")
        return False

def test_database_operations_creation():
    """Test DatabaseOperations class creation."""
    print("Testing DatabaseOperations creation...")
    
    try:
        from database_operations import DatabaseOperations
        from config_models import EXPOSURE_OUTCOME_CONFIGS
        
        config = EXPOSURE_OUTCOME_CONFIGS["depression_alzheimers"]
        timing_data = {}
        
        db_ops = DatabaseOperations(config, 50, timing_data, ['CAUSES'], 3, ['C1111111'])

        assert db_ops.config == config
        assert db_ops.threshold == 50
        assert db_ops.predication_types == ['CAUSES']
        assert db_ops.degree == 3
        assert db_ops.blacklist_cuis == ['C1111111']
        
        print("✅ DatabaseOperations creation test passed")
        return True
    except Exception as e:
        print(f"❌ DatabaseOperations creation test failed: {e}")
        return False

def test_timing_context():
    """Test TimingContext functionality."""
    print("Testing TimingContext...")
    
    try:
        from config_models import TimingContext
        import time
        
        timing_data = {}
        
        with TimingContext("test_operation", timing_data):
            time.sleep(0.01)  # Small delay to test timing
        
        assert "test_operation" in timing_data
        assert "duration" in timing_data["test_operation"]
        assert "timestamp" in timing_data["test_operation"]
        assert timing_data["test_operation"]["duration"] > 0
        
        print("✅ TimingContext test passed")
        return True
    except Exception as e:
        print(f"❌ TimingContext test failed: {e}")
        return False

def test_predication_type_validation():
    """Test predication type validation."""
    print("Testing predication type validation...")
    
    try:
        from config_models import validate_predication_types
        
        # Test valid types
        valid_types = ['CAUSES', 'TREATS', 'PREVENTS']
        is_valid, invalid = validate_predication_types(valid_types)
        assert is_valid == True
        assert len(invalid) == 0
        
        # Test invalid types
        invalid_types = ['CAUSES', 'INVALID_TYPE', 'TREATS']
        is_valid, invalid = validate_predication_types(invalid_types)
        assert is_valid == False
        assert 'INVALID_TYPE' in invalid
        
        print("✅ Predication type validation tests passed")
        return True
    except Exception as e:
        print(f"❌ Predication type validation test failed: {e}")
        return False

def run_all_tests():
    """Run all tests and report results."""
    print("="*60)
    print("REFACTORED MODULES TEST SUITE")
    print("="*60)
    
    tests = [
        test_config_models_imports,
        test_database_operations_imports,
        test_analysis_core_imports,
        test_cli_interface_imports,
        test_backward_compatibility,
        test_exposure_outcome_pair,
        test_yaml_config_loading,
        test_database_operations_creation,
        test_timing_context,
        test_predication_type_validation
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"❌ Test {test.__name__} failed with exception: {e}")
            failed += 1
        print()
    
    print("="*60)
    print("TEST RESULTS")
    print("="*60)
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Total: {passed + failed}")
    
    if failed == 0:
        print("\n🎉 All tests passed! Refactoring was successful.")
        return True
    else:
        print(f"\n⚠️  {failed} test(s) failed. Please review the issues above.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)
