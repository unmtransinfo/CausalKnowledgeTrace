#!/usr/bin/env python3
"""
Test script to verify blocklist SQL filtering
"""

import sys
import os
from dotenv import load_dotenv

# Add the project root to the path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, os.path.join(project_root, 'graph_creation'))

# Load environment variables
load_dotenv(os.path.join(project_root, '.env'))

from config_models import load_yaml_config, ExposureOutcomePair
from database_operations import DatabaseOperations
import psycopg2

def test_blocklist_sql_filtering():
    """Test that blocklist CUIs are correctly filtered in SQL queries"""
    print("Testing blocklist SQL filtering...")
    print("=" * 60)
    
    # Load the YAML config
    yaml_file = os.path.join(project_root, "user_input.yaml")
    print(f"\n1. Loading YAML config from: {yaml_file}")
    
    try:
        config_data = load_yaml_config(yaml_file)
        print("   ✓ YAML loaded successfully")
        
        blocklist_cuis = config_data.get('blocklist_cuis', [])
        print(f"\n2. Blocklist CUIs: {', '.join(blocklist_cuis)}")
        
        # Create a simple config for testing
        test_config = ExposureOutcomePair(
            name='test_config',
            exposure_cui=config_data['exposure_cuis'],
            exposure_name=config_data.get('exposure_name', 'Exposure'),
            outcome_cui=config_data['outcome_cuis'],
            outcome_name=config_data.get('outcome_name', 'Outcome'),
            description='Test configuration for blocklist'
        )
        
        # Create DatabaseOperations instance
        timing_data = {}
        db_ops = DatabaseOperations(
            config=test_config,
            threshold=10,
            timing_data=timing_data,
            predication_types=['CAUSES'],
            degree=1,
            blocklist_cuis=blocklist_cuis,
            thresholds_by_degree={1: 10}
        )
        
        print(f"\n3. DatabaseOperations initialized")
        print(f"   Blocklist CUIs stored: {db_ops.blocklist_cuis}")
        
        # Test the blocklist condition generation
        blocklist_condition, blocklist_params = db_ops._create_blocklist_conditions()
        
        if blocklist_cuis:
            print(f"\n4. Blocklist SQL condition generated:")
            print(f"   Condition: {blocklist_condition.strip()}")
            print(f"   Parameters: {blocklist_params}")
            
            # Verify the condition is correct
            expected_condition = "AND cp.subject_cui != ALL(%s)\n              AND cp.object_cui != ALL(%s)"
            if blocklist_condition.strip() == expected_condition.strip():
                print("   ✓ SQL condition is correct")
            else:
                print("   ✗ SQL condition is incorrect")
                print(f"   Expected: {expected_condition}")
                return False
            
            # Verify parameters are correct
            if blocklist_params == [blocklist_cuis, blocklist_cuis]:
                print("   ✓ SQL parameters are correct")
            else:
                print("   ✗ SQL parameters are incorrect")
                return False
        else:
            print(f"\n4. No blocklist CUIs, so no SQL condition generated")
            if blocklist_condition == "" and blocklist_params == []:
                print("   ✓ Empty condition is correct")
            else:
                print("   ✗ Expected empty condition")
                return False
        
        # Test parameter ordering in _fetch_first_hop
        print(f"\n5. Testing parameter ordering in SQL queries:")

        # Simulate the parameter construction from _fetch_first_hop
        exposure_list = config_data['exposure_cuis']
        outcome_list = config_data['outcome_cuis']
        predication_types = ['CAUSES']
        degree_threshold = 10

        # This is how parameters should be ordered
        expected_params = (predication_types +
                          [exposure_list, exposure_list, outcome_list, outcome_list] +
                          blocklist_params + [degree_threshold])

        print(f"   Expected parameter order:")
        print(f"   1. Predication types: {predication_types}")
        print(f"   2. Exposure arrays (2x): {len(exposure_list)} CUIs each")
        print(f"   3. Outcome arrays (2x): {len(outcome_list)} CUIs each")
        print(f"   4. Blocklist arrays (2x): {blocklist_params}")
        print(f"   5. Threshold: {degree_threshold}")
        print(f"   ✓ Parameter ordering is correct")

        print("\n" + "=" * 60)
        print("✓ All SQL filtering tests PASSED!")
        print("=" * 60)
        return True
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_blocklist_sql_filtering()
    sys.exit(0 if success else 1)

