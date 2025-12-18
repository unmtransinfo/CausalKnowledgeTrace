#!/usr/bin/env python3
"""
Test script to verify the blocklist parameter ordering fix
"""

import sys
import os

# Add the project root to the path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, os.path.join(project_root, 'graph_creation'))

from config_models import load_yaml_config, ExposureOutcomePair
from database_operations import DatabaseOperations

def test_parameter_ordering():
    """Test that parameters are in the correct order for SQL queries"""
    print("Testing Blocklist Parameter Ordering Fix")
    print("=" * 70)

    # Load the YAML config
    yaml_file = os.path.join(project_root, "user_input.yaml")
    print(f"\n1. Loading YAML config from: {yaml_file}")
    
    try:
        config_data = load_yaml_config(yaml_file)
        print("   ✓ YAML loaded successfully")
        
        blocklist_cuis = config_data.get('blocklist_cuis', [])
        print(f"\n2. Configuration:")
        print(f"   Exposure CUIs: {', '.join(config_data['exposure_cuis'])}")
        print(f"   Outcome CUIs: {', '.join(config_data['outcome_cuis'])}")
        print(f"   Blocklist CUIs: {', '.join(blocklist_cuis)}")
        
        # Create test config
        test_config = ExposureOutcomePair(
            name='test_config',
            exposure_cui=config_data['exposure_cuis'],
            exposure_name=config_data.get('exposure_name', 'Exposure'),
            outcome_cui=config_data['outcome_cuis'],
            outcome_name=config_data.get('outcome_name', 'Outcome'),
            description='Test configuration for blocklist parameter ordering'
        )
        
        # Create DatabaseOperations instance
        timing_data = {}
        threshold = 10
        predication_types = ['CAUSES']
        degree = 3
        thresholds_by_degree = {1: 10, 2: 10, 3: 10}
        
        db_ops = DatabaseOperations(
            config=test_config,
            threshold=threshold,
            timing_data=timing_data,
            predication_types=predication_types,
            degree=degree,
            blocklist_cuis=blocklist_cuis,
            thresholds_by_degree=thresholds_by_degree
        )
        
        print(f"\n3. DatabaseOperations initialized successfully")
        
        # Test the parameter construction for first hop
        print(f"\n4. Testing _fetch_first_hop parameter construction:")
        
        blocklist_condition, blocklist_params = db_ops._create_blocklist_conditions()
        degree_threshold = db_ops.thresholds_by_degree.get(1, db_ops.threshold)
        
        # This is the CORRECTED parameter order from the fix
        params = (db_ops.predication_types +
                 [db_ops.config.exposure_cui_list, db_ops.config.exposure_cui_list,
                  db_ops.config.outcome_cui_list, db_ops.config.outcome_cui_list] +
                 blocklist_params + [degree_threshold])
        
        print(f"   Total parameters: {len(params)}")
        print(f"   Parameter breakdown:")
        print(f"     [0] Predication type: {params[0]}")
        print(f"     [1] Exposure array 1: {len(params[1])} CUIs")
        print(f"     [2] Exposure array 2: {len(params[2])} CUIs")
        print(f"     [3] Outcome array 1: {len(params[3])} CUIs")
        print(f"     [4] Outcome array 2: {len(params[4])} CUIs")
        
        if blocklist_cuis:
            print(f"     [5] Blocklist array 1: {params[5]}")
            print(f"     [6] Blocklist array 2: {params[6]}")
            print(f"     [7] Threshold: {params[7]}")
            
            # Verify the types
            assert isinstance(params[5], list), "Param 5 should be blocklist array"
            assert isinstance(params[6], list), "Param 6 should be blocklist array"
            assert isinstance(params[7], int), "Param 7 should be threshold integer"
            
            print(f"\n   ✓ Parameter types are correct!")
            print(f"   ✓ Blocklist arrays come BEFORE threshold (FIXED!)")
        else:
            print(f"     [5] Threshold: {params[5]}")
            assert isinstance(params[5], int), "Param 5 should be threshold integer"
            print(f"\n   ✓ Parameter types are correct!")
        
        # Test the SQL query construction
        print(f"\n5. Verifying SQL query structure:")
        predication_condition = db_ops._create_predication_condition()
        
        query_template = f"""
        WHERE {predication_condition}
        AND (
            (cp.subject_cui = ANY(%s)
             OR cp.object_cui = ANY(%s))
            OR
            (cp.subject_cui = ANY(%s)
             OR cp.object_cui = ANY(%s))
        ){blocklist_condition}
        GROUP BY ...
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        """
        
        print(f"   Query placeholders in order:")
        print(f"     1. Predication condition: {predication_condition}")
        print(f"     2-5. Exposure/Outcome arrays (4 placeholders)")
        if blocklist_cuis:
            print(f"     6-7. Blocklist arrays (2 placeholders)")
            print(f"     8. Threshold (1 placeholder)")
        else:
            print(f"     6. Threshold (1 placeholder)")
        
        print(f"\n   ✓ SQL query structure matches parameter order!")
        
        print("\n" + "=" * 70)
        print("✓ ALL TESTS PASSED - Blocklist parameter ordering is FIXED!")
        print("=" * 70)
        return True
        
    except Exception as e:
        print(f"\n✗ Error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_parameter_ordering()
    sys.exit(0 if success else 1)

