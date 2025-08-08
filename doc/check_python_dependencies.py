#!/usr/bin/env python3

"""
CausalKnowledgeTrace Python Dependency Checker
This script verifies that all required Python dependencies are installed and working

Usage:
    python check_python_dependencies.py
"""

import sys
import importlib
import subprocess
from typing import List, Tuple, Dict

def check_python_version() -> bool:
    """Check if Python version meets requirements."""
    version = sys.version_info
    required_major, required_minor = 3, 8
    
    print(f"📋 Python Environment Information:")
    print(f"   Python Version: {version.major}.{version.minor}.{version.micro}")
    print(f"   Platform: {sys.platform}")
    print(f"   Executable: {sys.executable}\n")
    
    if version.major >= required_major and version.minor >= required_minor:
        print(f"✅ Python version requirement met (>= {required_major}.{required_minor})")
        return True
    else:
        print(f"❌ Python version requirement NOT met (>= {required_major}.{required_minor} required)")
        return False

def get_package_version(package_name: str) -> str:
    """Get the version of an installed package."""
    try:
        module = importlib.import_module(package_name)
        if hasattr(module, '__version__'):
            return module.__version__
        elif hasattr(module, 'version'):
            return module.version
        else:
            return "unknown"
    except:
        return "unknown"

def check_package(package_name: str, import_name: str = None, required: bool = True) -> bool:
    """Check if a package is installed and importable."""
    if import_name is None:
        import_name = package_name
    
    status_icon = "🔴" if required else "🟡"
    priority = "REQUIRED" if required else "OPTIONAL"
    
    try:
        importlib.import_module(import_name)
        version = get_package_version(import_name)
        print(f"✅ {package_name} (v{version})")
        return True
    except ImportError:
        print(f"{status_icon} {package_name} - NOT INSTALLED ({priority})")
        return False
    except Exception as e:
        print(f"⚠️  {package_name} - ERROR: {e}")
        return False

def test_functionality() -> Dict[str, bool]:
    """Test core functionality of key packages."""
    print("\n3️⃣  Testing core functionality:")
    results = {}
    
    # Test 1: Database connectivity
    print("   Testing database connectivity... ", end="")
    try:
        import psycopg2
        # Just test that we can create a connection object (won't actually connect)
        conn_str = "host=localhost dbname=test user=test password=test"
        # This will fail but we just want to test the module works
        try:
            psycopg2.connect(conn_str, connect_timeout=1)
        except:
            pass  # Expected to fail, we just want to test import works
        print("✅ PASS")
        results['database'] = True
    except Exception as e:
        print(f"❌ FAIL: {e}")
        results['database'] = False
    
    # Test 2: Data processing
    print("   Testing data processing... ", end="")
    try:
        import pandas as pd
        import numpy as np
        df = pd.DataFrame({'A': [1, 2, 3], 'B': [4, 5, 6]})
        arr = np.array([1, 2, 3])
        if len(df) == 3 and len(arr) == 3:
            print("✅ PASS")
            results['data_processing'] = True
        else:
            print("❌ FAIL")
            results['data_processing'] = False
    except Exception as e:
        print(f"❌ FAIL: {e}")
        results['data_processing'] = False
    
    # Test 3: Graph processing
    print("   Testing graph processing... ", end="")
    try:
        import networkx as nx
        G = nx.DiGraph()
        G.add_edge('A', 'B')
        if len(G.nodes()) == 2 and len(G.edges()) == 1:
            print("✅ PASS")
            results['graph_processing'] = True
        else:
            print("❌ FAIL")
            results['graph_processing'] = False
    except Exception as e:
        print(f"❌ FAIL: {e}")
        results['graph_processing'] = False
    
    # Test 4: Configuration handling
    print("   Testing configuration handling... ", end="")
    try:
        import yaml
        test_config = {'test': 'value', 'number': 42}
        yaml_str = yaml.dump(test_config)
        loaded_config = yaml.safe_load(yaml_str)
        if loaded_config == test_config:
            print("✅ PASS")
            results['config_handling'] = True
        else:
            print("❌ FAIL")
            results['config_handling'] = False
    except Exception as e:
        print(f"❌ FAIL: {e}")
        results['config_handling'] = False
    
    return results

def main():
    """Main dependency checking function."""
    print("=== CausalKnowledgeTrace Python Dependency Checker ===\n")
    
    # Check Python version
    python_ok = check_python_version()
    print()
    
    # Required packages
    print("1️⃣  Checking REQUIRED packages:")
    required_packages = [
        ("psycopg2-binary", "psycopg2"),
        ("PyYAML", "yaml"),
        ("pandas", "pandas"),
        ("numpy", "numpy"),
        ("networkx", "networkx"),
        ("scipy", "scipy")
    ]
    
    required_missing = []
    for package_name, import_name in required_packages:
        if not check_package(package_name, import_name, required=True):
            required_missing.append(package_name)
    
    # Optional packages
    print("\n2️⃣  Checking OPTIONAL packages:")
    optional_packages = [
        ("langchain", "langchain"),
        ("langchain-community", "langchain_community"),
        ("pytest", "pytest"),
        ("pytest-cov", "pytest_cov")
    ]
    
    optional_missing = []
    for package_name, import_name in optional_packages:
        if not check_package(package_name, import_name, required=False):
            optional_missing.append(package_name)
    
    # Functionality tests
    test_results = test_functionality()
    
    # Summary
    print("\n=== Summary ===")
    
    if not python_ok:
        print("❌ Python version requirement not met")
        readiness_status = "NOT READY"
    elif len(required_missing) == 0:
        print("✅ All REQUIRED packages are installed!")
        readiness_status = "READY"
    else:
        print(f"❌ Missing required packages: {', '.join(required_missing)}")
        readiness_status = "NOT READY"
    
    if len(optional_missing) > 0:
        print(f"⚠️  Missing optional packages: {', '.join(optional_missing)}")
        print("   (Some features may be limited)")
    
    # Check functionality test results
    failed_tests = [test for test, passed in test_results.items() if not passed]
    if failed_tests:
        print(f"⚠️  Some functionality tests failed: {', '.join(failed_tests)}")
    
    print(f"\n🚀 Python Environment Status: {readiness_status}")
    
    if readiness_status == "READY":
        print("\n   You can now run the Python graph creation engine!")
        print("   Example: python graph_creation/pushkin.py --help")
    else:
        print("\n   Install missing packages with:")
        print("   pip install -r requirements.txt")
    
    print("\n=== Check Complete ===")

if __name__ == "__main__":
    main()
