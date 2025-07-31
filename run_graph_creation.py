#!/usr/bin/env python3

"""
CausalKnowledgeTrace Graph Creation Launcher
This script launches the graph creation component from the reorganized project structure

Usage:
    python run_graph_creation.py [options]
    
The script will automatically look for user_input.yaml in the project root directory
and pass the configuration to the graph creation component.
"""

import os
import sys
import subprocess
from pathlib import Path

def main():
    # Get the project root directory
    project_root = Path(__file__).parent.absolute()
    graph_creation_dir = project_root / "graph_creation"
    config_file = project_root / "user_input.yaml"
    
    print("=== CausalKnowledgeTrace Graph Creation ===")
    print(f"Project Root: {project_root}")
    print(f"Graph Creation Directory: {graph_creation_dir}")
    print(f"Configuration File: {config_file}")
    print("==========================================\n")
    
    # Check if directories exist
    if not graph_creation_dir.exists():
        print("ERROR: Graph creation directory not found!")
        print("Please ensure you're running this script from the project root directory.")
        sys.exit(1)
    
    # Check if configuration file exists
    if not config_file.exists():
        print("WARNING: Configuration file (user_input.yaml) not found!")
        print("Please run the Shiny app first and create a configuration using the Graph Configuration tab.")
        print("The configuration will be saved to user_input.yaml in the project root.")
        
        # Ask user if they want to continue anyway
        response = input("\nDo you want to continue without a configuration file? (y/N): ")
        if response.lower() != 'y':
            print("Exiting. Please create a configuration first.")
            sys.exit(1)
    
    # Change to graph creation directory
    os.chdir(graph_creation_dir)
    
    # Prepare command arguments
    cmd_args = [sys.executable]  # Use the same Python interpreter
    
    # Check which script to run (you may need to adjust this based on your main script)
    main_scripts = ["pushkin.py", "consolidation.py", "SemDAGconsolidator.py"]
    main_script = None
    
    for script in main_scripts:
        if Path(script).exists():
            main_script = script
            break
    
    if main_script is None:
        print("ERROR: No main graph creation script found!")
        print(f"Looking for: {', '.join(main_scripts)}")
        sys.exit(1)
    
    cmd_args.append(main_script)
    
    # Add configuration file argument if it exists
    if config_file.exists():
        cmd_args.extend(["--yaml-config", str(config_file)])
    
    # Add any additional command line arguments passed to this script
    if len(sys.argv) > 1:
        cmd_args.extend(sys.argv[1:])
    
    print(f"Running: {' '.join(cmd_args)}")
    print("=" * 50)
    
    # Execute the graph creation script
    try:
        subprocess.run(cmd_args, check=True)
    except subprocess.CalledProcessError as e:
        print(f"\nERROR: Graph creation script failed with exit code {e.returncode}")
        sys.exit(e.returncode)
    except KeyboardInterrupt:
        print("\nGraph creation interrupted by user.")
        sys.exit(1)

if __name__ == "__main__":
    main()
