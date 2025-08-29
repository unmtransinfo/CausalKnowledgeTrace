#!/usr/bin/env python3
"""
Regenerate Optimized Causal Assertions Files

This script regenerates causal assertions files with the optimized structure:
1. Fixes empty sentences issue
2. Removes duplicate PMID storage (pmid_list removed, only pmid_data keys used)
3. Applies deduplication optimizations

Run this after making the database_operations.py fixes to get optimized files.
"""

import sys
import os
import argparse
from pathlib import Path

# Add the graph_creation directory to the path
sys.path.append(str(Path(__file__).parent / "graph_creation"))

try:
    from analysis_core import GraphAnalyzer
    from config_models import EXPOSURE_OUTCOME_CONFIGS
except ImportError as e:
    print(f"Error importing modules: {e}")
    print("Make sure you're running this from the project root directory.")
    sys.exit(1)

def regenerate_files(config_name="hypertension_alzheimers", k_hops_list=[1, 2, 3], force=False):
    """Regenerate causal assertions files with optimized structure."""
    
    print("=== Regenerating Optimized Causal Assertions Files ===")
    print(f"Config: {config_name}")
    print(f"K-hops levels: {k_hops_list}")
    print()
    
    # Database connection parameters
    db_params = {
        "host": "localhost",
        "port": 5432,
        "dbname": "semmeddb",
        "user": "postgres",
        "password": "password"
    }
    
    # Get configuration
    try:
        if config_name not in EXPOSURE_OUTCOME_CONFIGS:
            print(f"Error: Configuration '{config_name}' not found.")
            print(f"Available configurations: {list(EXPOSURE_OUTCOME_CONFIGS.keys())}")
            return False

        config = EXPOSURE_OUTCOME_CONFIGS[config_name]
        print(f"Using configuration: {config.name}")
        print(f"Description: {config.description}")
        print(f"Exposure: {config.exposure_name} (CUI: {config.exposure_cui})")
        print(f"Outcome: {config.outcome_name} (CUI: {config.outcome_cui})")
        print()
    except Exception as e:
        print(f"Error loading configuration '{config_name}': {e}")
        return False
    
    success_count = 0
    total_count = len(k_hops_list)
    
    for k_hops in k_hops_list:
        print(f"--- Generating k_hops = {k_hops} ---")
        
        # Check if file already exists
        output_dir = Path("graph_creation/result")
        output_file = output_dir / f"causal_assertions_{k_hops}.json"
        
        if output_file.exists() and not force:
            print(f"File {output_file} already exists. Use --force to overwrite.")
            continue
        
        try:
            # Create analyzer
            analyzer = GraphAnalyzer(
                config_name=config_name,
                db_params=db_params,
                threshold=5,  # Minimum evidence threshold
                output_dir="graph_creation/result",
                k_hops=k_hops
            )
            
            print(f"Running analysis for k_hops = {k_hops}...")
            
            # Run the analysis
            timing_results = analyzer.run_analysis()
            
            print(f"✓ Successfully generated optimized file for k_hops = {k_hops}")
            print(f"  Output: {output_file}")
            
            # Print timing information
            if timing_results:
                total_time = sum(timing_results.values())
                print(f"  Total time: {total_time:.2f} seconds")
            
            success_count += 1
            
        except Exception as e:
            print(f"✗ Error generating k_hops = {k_hops}: {e}")
            continue
        
        print()
    
    # Summary
    print("=== Generation Summary ===")
    print(f"Successfully generated: {success_count}/{total_count} files")
    
    if success_count > 0:
        print("\nOptimized files now have:")
        print("  ✓ Populated sentences (fixed empty sentences issue)")
        print("  ✓ No duplicate PMID storage (pmid_list removed)")
        print("  ✓ Deduplicated sentences for smaller file sizes")
        print("\nNext steps:")
        print("  1. Run: Rscript shiny_app/run_app.R --optimize")
        print("  2. The app will create additional optimized formats automatically")
    
    return success_count == total_count

def main():
    parser = argparse.ArgumentParser(description="Regenerate optimized causal assertions files")
    parser.add_argument("--config", default="hypertension_alzheimers",
                       help="Configuration name to use (default: hypertension_alzheimers)")
    parser.add_argument("--k-hops", nargs="+", type=int, default=[1, 2, 3],
                       help="K-hops levels to generate (default: 1 2 3)")
    parser.add_argument("--force", action="store_true",
                       help="Force overwrite existing files")
    parser.add_argument("--test-db", action="store_true",
                       help="Test database connection only")
    
    args = parser.parse_args()
    
    if args.test_db:
        print("Testing database connection...")
        db_params = {
            "host": "localhost",
            "port": 5432,
            "dbname": "semmeddb",
            "user": "postgres",
            "password": "password"
        }
        
        try:
            import psycopg2
            with psycopg2.connect(**db_params) as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT COUNT(*) FROM causalpredication LIMIT 1")
                    print("✓ Database connection successful")
                    return True
        except Exception as e:
            print(f"✗ Database connection failed: {e}")
            return False
    
    # Regenerate files
    success = regenerate_files(
        config_name=args.config,
        k_hops_list=args.k_hops,
        force=args.force
    )
    
    if success:
        print("\n🎉 All files regenerated successfully!")
        return True
    else:
        print("\n❌ Some files failed to regenerate.")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
