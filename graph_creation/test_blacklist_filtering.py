#!/usr/bin/env python3
"""
Test script to verify blacklist CUI filtering functionality.

This script tests that the blacklist filtering is properly applied in SQL queries
and that blacklisted CUIs are excluded from graph creation.

Author: Scott A. Malec PhD
Date: February 2025
"""

import sys
from pathlib import Path

# Add the graph_creation directory to the Python path
sys.path.insert(0, str(Path(__file__).parent))

from database_operations import DatabaseOperations
from config_models import EXPOSURE_OUTCOME_CONFIGS


def test_blacklist_conditions():
    """Test that blacklist conditions are properly generated."""
    print("Testing blacklist condition generation...")
    
    # Create a DatabaseOperations instance with blacklist CUIs
    config = EXPOSURE_OUTCOME_CONFIGS["depression_alzheimers"]
    timing_data = {}
    blacklist_cuis = ['C1111111', 'C2222222', 'C3333333']
    
    db_ops = DatabaseOperations(config, 50, timing_data, ['CAUSES'], 3, blacklist_cuis)
    
    # Test blacklist condition generation
    blacklist_condition, blacklist_params = db_ops._create_blacklist_conditions()
    
    print(f"Generated blacklist condition: {blacklist_condition}")
    print(f"Generated blacklist parameters: {blacklist_params}")
    
    # Verify the condition contains the expected structure
    assert "cp.subject_cui NOT IN" in blacklist_condition
    assert "cp.object_cui NOT IN" in blacklist_condition
    
    # Verify parameters are duplicated (once for subject, once for object)
    expected_params = blacklist_cuis + blacklist_cuis
    assert blacklist_params == expected_params
    
    print("✅ Blacklist condition generation test passed")
    return True


def test_empty_blacklist():
    """Test that empty blacklist doesn't affect queries."""
    print("Testing empty blacklist handling...")
    
    config = EXPOSURE_OUTCOME_CONFIGS["depression_alzheimers"]
    timing_data = {}
    
    # Test with empty blacklist
    db_ops = DatabaseOperations(config, 50, timing_data, ['CAUSES'], 3, [])
    blacklist_condition, blacklist_params = db_ops._create_blacklist_conditions()
    
    assert blacklist_condition == ""
    assert blacklist_params == []
    
    # Test with None blacklist
    db_ops = DatabaseOperations(config, 50, timing_data, ['CAUSES'], 3, None)
    blacklist_condition, blacklist_params = db_ops._create_blacklist_conditions()
    
    assert blacklist_condition == ""
    assert blacklist_params == []
    
    print("✅ Empty blacklist handling test passed")
    return True


def test_sql_query_integration():
    """Test that blacklist conditions are properly integrated into SQL queries."""
    print("Testing SQL query integration...")
    
    config = EXPOSURE_OUTCOME_CONFIGS["depression_alzheimers"]
    timing_data = {}
    blacklist_cuis = ['C1111111', 'C2222222']
    
    db_ops = DatabaseOperations(config, 50, timing_data, ['CAUSES'], 3, blacklist_cuis)
    
    # Test that the blacklist condition is properly formatted
    blacklist_condition, blacklist_params = db_ops._create_blacklist_conditions()
    
    # Verify the condition can be integrated into a SQL query
    test_query = f"""
    SELECT * FROM causalpredication cp
    WHERE cp.predicate = 'CAUSES'
      AND cp.subject_cui = 'C0011570'
      AND cp.object_cui = 'C0002395'{blacklist_condition}
    """
    
    # Check that the query contains the blacklist conditions
    assert "cp.subject_cui NOT IN" in test_query
    assert "cp.object_cui NOT IN" in test_query
    
    print("✅ SQL query integration test passed")
    return True


def main():
    """Run all blacklist filtering tests."""
    print("=" * 60)
    print("BLACKLIST FILTERING TEST SUITE")
    print("=" * 60)
    
    tests = [
        test_blacklist_conditions,
        test_empty_blacklist,
        test_sql_query_integration
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
            print(f"❌ {test.__name__} failed with error: {e}")
            failed += 1
        print()
    
    print("=" * 60)
    print("TEST RESULTS")
    print("=" * 60)
    print(f"✅ Passed: {passed}")
    print(f"❌ Failed: {failed}")
    print(f"📊 Total: {passed + failed}")
    
    if failed == 0:
        print("\n🎉 All blacklist filtering tests passed!")
        return True
    else:
        print(f"\n⚠️  {failed} test(s) failed.")
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
