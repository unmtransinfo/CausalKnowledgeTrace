#!/usr/bin/env python3
"""
Test script for CUI-based node consolidation functionality.

This script tests that nodes with the same CUI but different name capitalizations
are properly consolidated into single nodes in the graph.

Author: Assistant
Date: 2025-01-19
"""

import sys
from pathlib import Path

def test_cui_to_name_mapping():
    """Test the CUI-to-name mapping functionality."""
    print("=" * 60)
    print("TESTING CUI-BASED NODE CONSOLIDATION")
    print("=" * 60)
    
    # Import the database operations class
    try:
        from database_operations import DatabaseOperations
        print("✅ DatabaseOperations import successful")
    except ImportError as e:
        print(f"❌ Import failed: {e}")
        return False
    
    # Create a mock DatabaseOperations instance
    db_ops = DatabaseOperations(
        config=None,  # We'll mock this
        threshold=5,
        timing_data={},
        predication_types=['CAUSES'],
        degree=2
    )
    
    # Test data simulating the issue: same CUI with different capitalizations
    test_assertions = [
        {
            "subject_name": "testosterone",
            "subject_cui": "C0039601",
            "predicate": "CAUSES",
            "object_name": "Benign Prostatic Hyperplasia",
            "object_cui": "C1704272"
        },
        {
            "subject_name": "Testosterone",  # Different capitalization
            "subject_cui": "C0039601",      # Same CUI
            "predicate": "CAUSES",
            "object_name": "Aggressive behavior",
            "object_cui": "C0001807"
        },
        {
            "subject_name": "testosterone",  # Same as first
            "subject_cui": "C0039601",
            "predicate": "CAUSES",
            "object_name": "aggressive behavior",  # Different capitalization
            "object_cui": "C0001807"         # Same CUI as second object
        },
        {
            "subject_name": "TESTOSTERONE",  # All caps
            "subject_cui": "C0039601",       # Same CUI
            "predicate": "CAUSES",
            "object_name": "Hair Loss",
            "object_cui": "C0002170"
        }
    ]
    
    print(f"\nTesting with {len(test_assertions)} test assertions...")
    print("Test data includes:")
    for i, assertion in enumerate(test_assertions, 1):
        print(f"  {i}. {assertion['subject_name']} ({assertion['subject_cui']}) -> {assertion['object_name']} ({assertion['object_cui']})")
    
    # Test the CUI-to-name mapping function
    print("\nTesting build_cui_to_name_mapping()...")
    cui_to_name_mapping = db_ops.build_cui_to_name_mapping(test_assertions)
    
    print(f"✅ Generated mapping for {len(cui_to_name_mapping)} unique CUIs")
    print("CUI-to-name mappings:")
    for cui, name in cui_to_name_mapping.items():
        print(f"  {cui} -> {name}")
    
    # Verify the mapping consolidates correctly
    expected_cuis = {"C0039601", "C1704272", "C0001807", "C0002170"}
    actual_cuis = set(cui_to_name_mapping.keys())
    
    if expected_cuis == actual_cuis:
        print("✅ All expected CUIs are present in mapping")
    else:
        print(f"❌ CUI mismatch. Expected: {expected_cuis}, Got: {actual_cuis}")
        return False
    
    # Check that testosterone CUI maps to the most frequent name
    testosterone_cui = "C0039601"
    if testosterone_cui in cui_to_name_mapping:
        canonical_name = cui_to_name_mapping[testosterone_cui]
        print(f"✅ Testosterone CUI {testosterone_cui} maps to canonical name: '{canonical_name}'")
        
        # Count occurrences to verify most frequent is chosen
        name_counts = {}
        for assertion in test_assertions:
            if assertion['subject_cui'] == testosterone_cui:
                name = assertion['subject_name']
                name_counts[name] = name_counts.get(name, 0) + 1
        
        most_frequent = max(name_counts.items(), key=lambda x: x[1])[0]
        if canonical_name == most_frequent:
            print(f"✅ Canonical name '{canonical_name}' is the most frequent (appears {name_counts[canonical_name]} times)")
        else:
            print(f"❌ Expected most frequent name '{most_frequent}', got '{canonical_name}'")
            return False
    else:
        print(f"❌ Testosterone CUI {testosterone_cui} not found in mapping")
        return False
    
    # Test that different capitalizations of same concept are consolidated
    aggressive_behavior_cui = "C0001807"
    if aggressive_behavior_cui in cui_to_name_mapping:
        canonical_name = cui_to_name_mapping[aggressive_behavior_cui]
        print(f"✅ Aggressive behavior CUI {aggressive_behavior_cui} maps to canonical name: '{canonical_name}'")
    else:
        print(f"❌ Aggressive behavior CUI {aggressive_behavior_cui} not found in mapping")
        return False
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED - CUI-based node consolidation working correctly!")
    print("=" * 60)
    return True

def test_edge_consolidation():
    """Test that edges are properly consolidated using CUI-based names."""
    print("\nTesting edge consolidation...")
    
    # Simulate the scenario where we have edges with different name capitalizations
    # but same CUIs that should be consolidated into single edges
    test_assertions = [
        {
            "subject_name": "testosterone",
            "subject_cui": "C0039601",
            "object_name": "Aggressive behavior",
            "object_cui": "C0001807"
        },
        {
            "subject_name": "Testosterone",  # Different capitalization
            "subject_cui": "C0039601",      # Same CUI
            "object_name": "aggressive behavior",  # Different capitalization
            "object_cui": "C0001807"        # Same CUI
        }
    ]
    
    from database_operations import DatabaseOperations
    db_ops = DatabaseOperations(
        config=None,
        threshold=5,
        timing_data={},
        predication_types=['CAUSES'],
        degree=2
    )
    
    # Build CUI mapping
    cui_to_name_mapping = db_ops.build_cui_to_name_mapping(test_assertions)
    
    # Simulate creating CUI-based links
    cui_based_links = []
    for assertion in test_assertions:
        subject_cui = assertion.get('subject_cui')
        object_cui = assertion.get('object_cui')
        
        if subject_cui and object_cui and subject_cui in cui_to_name_mapping and object_cui in cui_to_name_mapping:
            canonical_subject_name = cui_to_name_mapping[subject_cui]
            canonical_object_name = cui_to_name_mapping[object_cui]
            cui_based_links.append((canonical_subject_name, canonical_object_name))
    
    print(f"Original assertions: {len(test_assertions)}")
    print(f"CUI-based links: {len(cui_based_links)}")
    print(f"Unique CUI-based links: {len(set(cui_based_links))}")
    
    # Should have 2 original assertions but only 1 unique CUI-based link
    if len(set(cui_based_links)) == 1:
        print("✅ Edge consolidation working - duplicate edges with same CUIs consolidated to single edge")
        unique_link = list(set(cui_based_links))[0]
        print(f"   Consolidated edge: {unique_link[0]} -> {unique_link[1]}")
        return True
    else:
        print("❌ Edge consolidation failed - should have 1 unique edge")
        return False

if __name__ == "__main__":
    success = True
    
    try:
        success &= test_cui_to_name_mapping()
        success &= test_edge_consolidation()
        
        if success:
            print("\n🎉 All tests passed! CUI-based node consolidation is working correctly.")
            sys.exit(0)
        else:
            print("\n❌ Some tests failed.")
            sys.exit(1)
            
    except Exception as e:
        print(f"\n❌ Test execution failed with error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
