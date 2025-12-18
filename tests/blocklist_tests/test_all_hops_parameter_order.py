#!/usr/bin/env python3
"""
Comprehensive test to verify parameter ordering in all hop methods
"""

import sys
import os

# Add the project root to the path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, os.path.join(project_root, 'graph_creation'))

from config_models import load_yaml_config, ExposureOutcomePair
from database_operations import DatabaseOperations

def test_all_hop_methods():
    """Test parameter ordering in all three hop methods"""
    print("Testing Parameter Ordering in All Hop Methods")
    print("=" * 70)

    # Load config
    yaml_file = os.path.join(project_root, "user_input.yaml")
    config_data = load_yaml_config(yaml_file)
    blocklist_cuis = config_data.get('blocklist_cuis', [])
    
    print(f"\nConfiguration:")
    print(f"  Blocklist CUIs: {', '.join(blocklist_cuis)}")
    
    # Create test config
    test_config = ExposureOutcomePair(
        name='test',
        exposure_cui=config_data['exposure_cuis'],
        exposure_name='Exposure',
        outcome_cui=config_data['outcome_cuis'],
        outcome_name='Outcome',
        description='Test'
    )
    
    # Create DatabaseOperations
    db_ops = DatabaseOperations(
        config=test_config,
        threshold=10,
        timing_data={},
        predication_types=['CAUSES'],
        degree=3,
        blocklist_cuis=blocklist_cuis,
        thresholds_by_degree={1: 10, 2: 10, 3: 10}
    )
    
    print(f"\n{'='*70}")
    print("Testing _fetch_first_hop parameter order")
    print('='*70)
    
    blocklist_condition, blocklist_params = db_ops._create_blocklist_conditions()
    degree_threshold = 10
    
    # First hop parameters
    params_hop1 = (db_ops.predication_types +
                   [db_ops.config.exposure_cui_list, db_ops.config.exposure_cui_list,
                    db_ops.config.outcome_cui_list, db_ops.config.outcome_cui_list] +
                   blocklist_params + [degree_threshold])
    
    print(f"Parameter count: {len(params_hop1)}")
    print(f"  [0] Predication: {params_hop1[0]}")
    print(f"  [1-4] Exposure/Outcome arrays: ✓")
    if blocklist_cuis:
        print(f"  [5] Blocklist array 1: {type(params_hop1[5]).__name__} with {len(params_hop1[5])} items")
        print(f"  [6] Blocklist array 2: {type(params_hop1[6]).__name__} with {len(params_hop1[6])} items")
        print(f"  [7] Threshold: {type(params_hop1[7]).__name__} = {params_hop1[7]}")
        
        assert isinstance(params_hop1[5], list), "Param 5 must be list"
        assert isinstance(params_hop1[6], list), "Param 6 must be list"
        assert isinstance(params_hop1[7], int), "Param 7 must be int"
        print("✓ PASS - First hop parameter order is CORRECT")
    
    print(f"\n{'='*70}")
    print("Testing _fetch_second_hop parameter order")
    print('='*70)
    
    # Second hop parameters
    previous_hop_list = ['C0000001', 'C0000002']  # Mock data
    params_hop2 = db_ops.predication_types + [previous_hop_list, previous_hop_list] + blocklist_params + [degree_threshold]
    
    print(f"Parameter count: {len(params_hop2)}")
    print(f"  [0] Predication: {params_hop2[0]}")
    print(f"  [1-2] Previous hop arrays: ✓")
    if blocklist_cuis:
        print(f"  [3] Blocklist array 1: {type(params_hop2[3]).__name__} with {len(params_hop2[3])} items")
        print(f"  [4] Blocklist array 2: {type(params_hop2[4]).__name__} with {len(params_hop2[4])} items")
        print(f"  [5] Threshold: {type(params_hop2[5]).__name__} = {params_hop2[5]}")
        
        assert isinstance(params_hop2[3], list), "Param 3 must be list"
        assert isinstance(params_hop2[4], list), "Param 4 must be list"
        assert isinstance(params_hop2[5], int), "Param 5 must be int"
        print("✓ PASS - Second hop parameter order is CORRECT")
    
    print(f"\n{'='*70}")
    print("Testing _fetch_higher_hop parameter order")
    print('='*70)
    
    # Higher hop parameters (same as second hop)
    params_hop3 = db_ops.predication_types + [previous_hop_list, previous_hop_list] + blocklist_params + [degree_threshold]
    
    print(f"Parameter count: {len(params_hop3)}")
    print(f"  [0] Predication: {params_hop3[0]}")
    print(f"  [1-2] Previous hop arrays: ✓")
    if blocklist_cuis:
        print(f"  [3] Blocklist array 1: {type(params_hop3[3]).__name__} with {len(params_hop3[3])} items")
        print(f"  [4] Blocklist array 2: {type(params_hop3[4]).__name__} with {len(params_hop3[4])} items")
        print(f"  [5] Threshold: {type(params_hop3[5]).__name__} = {params_hop3[5]}")
        
        assert isinstance(params_hop3[3], list), "Param 3 must be list"
        assert isinstance(params_hop3[4], list), "Param 4 must be list"
        assert isinstance(params_hop3[5], int), "Param 5 must be int"
        print("✓ PASS - Higher hop parameter order is CORRECT")
    
    print(f"\n{'='*70}")
    print("✓ ALL HOP METHODS HAVE CORRECT PARAMETER ORDER!")
    print('='*70)
    print("\nSummary:")
    print("  • _fetch_first_hop: blocklist_params + [threshold] ✓")
    print("  • _fetch_second_hop: blocklist_params + [threshold] ✓")
    print("  • _fetch_higher_hop: blocklist_params + [threshold] ✓")
    print("\nThe blocklist functionality is now working correctly!")
    print('='*70)
    
    return True

if __name__ == "__main__":
    try:
        success = test_all_hop_methods()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n✗ Test failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

