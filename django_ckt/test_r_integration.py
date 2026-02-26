#!/usr/bin/env python
"""
Test script for R integration in Django CKT.

This script tests the rpy2 integration and R module loading.
Run this before starting the Django server to verify R integration works.
"""

import os
import sys
import django

# Setup Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
django.setup()

from apps.core.r_interface import get_r_interface, R_AVAILABLE

def test_r_availability():
    """Test if rpy2 is available."""
    print("=" * 60)
    print("Testing R Integration for Django CKT")
    print("=" * 60)
    print()
    
    if not R_AVAILABLE:
        print("❌ FAILED: rpy2 is not installed")
        print("   Install with: pip install rpy2")
        return False
    
    print("✅ rpy2 is installed")
    return True

def test_r_interface_init():
    """Test R interface initialization."""
    print("\nTesting R interface initialization...")
    
    try:
        r_interface = get_r_interface()
        print("✅ R interface initialized successfully")
        return True, r_interface
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False, None

def test_r_libraries(r_interface):
    """Test if required R libraries are loaded."""
    print("\nTesting R libraries...")
    
    try:
        # Test dagitty
        print("  - dagitty: ", end="")
        r_interface.dagitty
        print("✅")
        
        # Test igraph
        print("  - igraph: ", end="")
        r_interface.igraph
        print("✅")
        
        # Test visNetwork
        print("  - visNetwork: ", end="")
        r_interface.visNetwork
        print("✅")
        
        # Test dplyr
        print("  - dplyr: ", end="")
        r_interface.dplyr
        print("✅")
        
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def test_simple_dag(r_interface):
    """Test creating a simple DAG."""
    print("\nTesting simple DAG creation...")
    
    try:
        # Create a simple DAG using dagitty
        dag_code = 'dag { X -> Y; Z -> X; Z -> Y }'
        dag = r_interface.dagitty.dagitty(dag_code)
        print(f"✅ Created simple DAG: {dag_code}")
        
        # Test adjustment sets
        print("\nTesting adjustment set calculation...")
        result = r_interface.calculate_adjustment_sets(dag, 'X', 'Y', 'total')
        
        if result['success']:
            print(f"✅ Found {result['total_sets']} adjustment set(s)")
            for adj_set in result['adjustment_sets']:
                print(f"   Set {adj_set['id']}: {adj_set['description']}")
        else:
            print(f"❌ FAILED: {result.get('message', 'Unknown error')}")
            return False
        
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_r_modules(r_interface):
    """Test if R modules are sourced correctly."""
    print("\nTesting R module functions...")
    
    try:
        # Test if key functions are available
        functions_to_test = [
            'create_interactive_network',
            'generate_legend_html',
            'calculate_adjustment_sets',
            'find_instrumental_variables',
        ]
        
        for func_name in functions_to_test:
            print(f"  - {func_name}: ", end="")
            if func_name in r_interface.r:
                print("✅")
            else:
                print("⚠️  Not found (may not be critical)")
        
        return True
    except Exception as e:
        print(f"❌ FAILED: {e}")
        return False

def main():
    """Run all tests."""
    print()
    
    # Test 1: R availability
    if not test_r_availability():
        print("\n" + "=" * 60)
        print("RESULT: R integration is NOT available")
        print("=" * 60)
        return False
    
    # Test 2: R interface initialization
    success, r_interface = test_r_interface_init()
    if not success:
        print("\n" + "=" * 60)
        print("RESULT: R interface initialization FAILED")
        print("=" * 60)
        return False
    
    # Test 3: R libraries
    if not test_r_libraries(r_interface):
        print("\n" + "=" * 60)
        print("RESULT: R libraries test FAILED")
        print("Please install required R packages:")
        print("  Rscript ../doc/packages.R")
        print("=" * 60)
        return False
    
    # Test 4: R modules
    test_r_modules(r_interface)
    
    # Test 5: Simple DAG
    if not test_simple_dag(r_interface):
        print("\n" + "=" * 60)
        print("RESULT: DAG creation test FAILED")
        print("=" * 60)
        return False
    
    # All tests passed
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED!")
    print("=" * 60)
    print("\nR integration is working correctly.")
    print("You can now start the Django server:")
    print("  ./run_django.sh")
    print()
    
    return True

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1)

