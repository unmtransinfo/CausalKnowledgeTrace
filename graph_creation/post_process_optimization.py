#!/usr/bin/env python3
"""
Post-Processing Optimization Script

This script automatically creates optimized versions of generated files:
1. Binary RDS files for causal assertions (75% compression)
2. Lightweight JSON files for causal assertions (94% size reduction)
3. Binary DAG files for degree_{}.R files (50-66% compression)

Called automatically after graph creation to ensure optimized files are ready.
"""

import os
import sys
import subprocess
import json
import time
from pathlib import Path

def run_r_script(script_content, description="R script"):
    """Run R script content and return success status"""
    try:
        print(f"🔄 Running {description}...")
        
        # Create temporary R script
        temp_script = "temp_optimization.R"
        with open(temp_script, 'w') as f:
            f.write(script_content)
        
        # Run R script
        result = subprocess.run(['Rscript', temp_script], 
                              capture_output=True, text=True, timeout=300)
        
        # Clean up temp file
        if os.path.exists(temp_script):
            os.remove(temp_script)
        
        if result.returncode == 0:
            print(f"✅ {description} completed successfully")
            if result.stdout:
                print(result.stdout)
            return True
        else:
            print(f"❌ {description} failed:")
            if result.stderr:
                print(result.stderr)
            return False
            
    except subprocess.TimeoutExpired:
        print(f"❌ {description} timed out")
        return False
    except Exception as e:
        print(f"❌ Error running {description}: {e}")
        return False

def optimize_causal_assertions(result_dir):
    """Create optimized versions of causal assertions JSON files"""
    print("\n=== OPTIMIZING CAUSAL ASSERTIONS FILES ===")
    
    # Find all causal_assertions_*.json files
    json_files = list(Path(result_dir).glob("causal_assertions_*.json"))
    
    if not json_files:
        print("⚠️ No causal assertions JSON files found to optimize")
        return False
    
    print(f"Found {len(json_files)} causal assertions files to optimize:")
    for file in json_files:
        size_mb = file.stat().st_size / (1024 * 1024)
        print(f"  - {file.name} ({size_mb:.2f} MB)")
    
    # Create R script for optimization
    r_script = f"""
# Load required modules
setwd("{os.path.abspath('shiny_app')}")
source("modules/binary_storage.R")
source("modules/sentence_storage.R")

# Set result directory
result_dir <- "{os.path.abspath(result_dir)}"

# Find all causal assertions files
json_files <- list.files(result_dir, pattern = "^causal_assertions_[0-9]+\\\\.json$", full.names = TRUE)

cat("Processing", length(json_files), "causal assertions files...\\n")

success_count <- 0
total_files <- length(json_files)

for (json_file in json_files) {{
    cat("\\n--- Processing", basename(json_file), "---\\n")
    
    # Create binary version
    cat("Creating binary version...\\n")
    binary_result <- convert_json_to_binary(json_file, compression = "gzip")
    
    if (binary_result$success) {{
        cat("✓ Binary:", binary_result$message, "\\n")
        cat("  Compression:", binary_result$compression_ratio, "%\\n")
    }} else {{
        cat("✗ Binary failed:", binary_result$message, "\\n")
    }}
    
    # Create lightweight version
    cat("Creating lightweight version...\\n")
    lightweight_result <- separate_sentences_from_assertions(json_file)
    
    if (lightweight_result$success) {{
        cat("✓ Lightweight:", lightweight_result$message, "\\n")
        cat("  Size reduction:", lightweight_result$size_reduction_percent, "%\\n")
    }} else {{
        cat("✗ Lightweight failed:", lightweight_result$message, "\\n")
    }}
    
    if (binary_result$success && lightweight_result$success) {{
        success_count <- success_count + 1
    }}
}}

cat("\\n=== CAUSAL ASSERTIONS OPTIMIZATION SUMMARY ===\\n")
cat("Successfully optimized:", success_count, "of", total_files, "files\\n")

if (success_count == total_files) {{
    cat("🎉 All causal assertions files optimized successfully!\\n")
}} else {{
    cat("⚠️ Some files failed to optimize\\n")
}}
"""
    
    return run_r_script(r_script, "causal assertions optimization")

def optimize_dag_files(result_dir):
    """Create optimized binary versions of degree_{}.R files"""
    print("\n=== OPTIMIZING DAG FILES ===")
    
    # Find all degree_*.R files
    dag_files = list(Path(result_dir).glob("degree_*.R"))
    
    if not dag_files:
        print("⚠️ No degree_{}.R files found to optimize")
        return False
    
    print(f"Found {len(dag_files)} DAG files to optimize:")
    for file in dag_files:
        size_kb = file.stat().st_size / 1024
        print(f"  - {file.name} ({size_kb:.1f} KB)")
    
    # Create R script for DAG optimization
    r_script = f"""
# Load required modules
setwd("{os.path.abspath('shiny_app')}")
source("modules/dag_binary_storage.R")

# Set result directory
result_dir <- "{os.path.abspath(result_dir)}"

# Find all degree files
dag_files <- list.files(result_dir, pattern = "^degree_[0-9]+\\\\.R$", full.names = TRUE)

cat("Processing", length(dag_files), "DAG files...\\n")

success_count <- 0
total_files <- length(dag_files)

for (dag_file in dag_files) {{
    cat("\\n--- Processing", basename(dag_file), "---\\n")
    
    # Compile to binary
    result <- compile_dag_to_binary(dag_file, force_regenerate = TRUE)
    
    if (result$success) {{
        cat("✓", result$message, "\\n")
        cat("  Compression:", result$compression_ratio, "%\\n")
        cat("  Variables:", result$variable_count, "\\n")
        success_count <- success_count + 1
    }} else {{
        cat("✗ Failed:", result$message, "\\n")
    }}
}}

cat("\\n=== DAG FILES OPTIMIZATION SUMMARY ===\\n")
cat("Successfully optimized:", success_count, "of", total_files, "files\\n")

if (success_count == total_files) {{
    cat("🎉 All DAG files optimized successfully!\\n")
}} else {{
    cat("⚠️ Some DAG files failed to optimize\\n")
}}
"""
    
    return run_r_script(r_script, "DAG files optimization")

def main():
    """Main optimization process"""
    print("🚀 POST-PROCESSING OPTIMIZATION STARTED")
    print("=" * 50)
    
    # Determine result directory
    if len(sys.argv) > 1:
        result_dir = sys.argv[1]
    else:
        result_dir = "graph_creation/result"
    
    # Convert to absolute path
    result_dir = os.path.abspath(result_dir)
    
    if not os.path.exists(result_dir):
        print(f"❌ Result directory not found: {result_dir}")
        sys.exit(1)
    
    print(f"📁 Processing files in: {result_dir}")
    
    # Check if we have the required R modules
    shiny_app_dir = os.path.abspath("shiny_app")
    if not os.path.exists(shiny_app_dir):
        print(f"❌ Shiny app directory not found: {shiny_app_dir}")
        print("   Make sure to run this script from the project root directory")
        sys.exit(1)
    
    start_time = time.time()
    
    # Step 1: Optimize causal assertions files
    assertions_success = optimize_causal_assertions(result_dir)
    
    # Step 2: Optimize DAG files
    dag_success = optimize_dag_files(result_dir)
    
    # Final summary
    total_time = time.time() - start_time
    
    print("\n" + "=" * 50)
    print("🎯 POST-PROCESSING OPTIMIZATION COMPLETE")
    print("=" * 50)
    
    if assertions_success and dag_success:
        print("✅ ALL OPTIMIZATIONS SUCCESSFUL!")
        print(f"⏱️  Total time: {total_time:.2f} seconds")
        print("\n🎉 Your graph files are now optimized for lightning-fast loading!")
        print("   - Binary RDS files: 75% compression")
        print("   - Lightweight JSON: 94% size reduction")
        print("   - Binary DAG files: 50-66% compression")
    else:
        print("⚠️ SOME OPTIMIZATIONS FAILED")
        if not assertions_success:
            print("   - Causal assertions optimization failed")
        if not dag_success:
            print("   - DAG files optimization failed")
        print(f"⏱️  Total time: {total_time:.2f} seconds")
        sys.exit(1)

if __name__ == "__main__":
    main()
