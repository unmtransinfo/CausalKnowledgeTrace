#!/usr/bin/env python3
"""
Test script to verify blocklist functionality
"""

import sys
import os

# Add the project root to the path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
sys.path.insert(0, os.path.join(project_root, 'graph_creation'))

from config_models import load_yaml_config

def test_blocklist_loading():
    """Test that blocklist CUIs are correctly loaded from YAML"""
    print("Testing blocklist functionality...")
    print("=" * 60)
    
    # Load the YAML config
    yaml_file = os.path.join(project_root, "user_input.yaml")
    print(f"\n1. Loading YAML config from: {yaml_file}")
    
    try:
        config_data = load_yaml_config(yaml_file)
        print("   ✓ YAML loaded successfully")
        
        # Check if blocklist_cuis is present
        if 'blocklist_cuis' in config_data:
            blocklist_cuis = config_data['blocklist_cuis']
            print(f"\n2. Blocklist CUIs found: {len(blocklist_cuis)} CUI(s)")
            print(f"   Blocklisted CUIs: {', '.join(blocklist_cuis)}")
            
            # Verify they are in the correct format
            for cui in blocklist_cuis:
                if not cui.startswith('C') or len(cui) != 8:
                    print(f"   ✗ Invalid CUI format: {cui}")
                    return False
            print("   ✓ All blocklist CUIs have valid format")
            
        else:
            print("\n2. No blocklist_cuis found in config")
            print("   Note: This is optional, so not an error")
        
        # Check exposure and outcome CUIs
        print(f"\n3. Exposure CUIs: {', '.join(config_data['exposure_cuis'])}")
        print(f"   Outcome CUIs: {', '.join(config_data['outcome_cuis'])}")
        
        # Verify no overlap between blocklist and exposure/outcome
        if 'blocklist_cuis' in config_data:
            exposure_set = set(config_data['exposure_cuis'])
            outcome_set = set(config_data['outcome_cuis'])
            blocklist_set = set(config_data['blocklist_cuis'])
            
            overlap_exposure = exposure_set & blocklist_set
            overlap_outcome = outcome_set & blocklist_set
            
            if overlap_exposure:
                print(f"\n   ⚠ WARNING: Blocklist overlaps with exposure CUIs: {overlap_exposure}")
            if overlap_outcome:
                print(f"\n   ⚠ WARNING: Blocklist overlaps with outcome CUIs: {overlap_outcome}")
            
            if not overlap_exposure and not overlap_outcome:
                print("\n   ✓ No overlap between blocklist and exposure/outcome CUIs")
        
        print("\n" + "=" * 60)
        print("✓ All blocklist tests PASSED!")
        print("=" * 60)
        return True
        
    except Exception as e:
        print(f"\n✗ Error loading config: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_blocklist_loading()
    sys.exit(0 if success else 1)

