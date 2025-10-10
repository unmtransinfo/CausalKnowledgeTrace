#!/usr/bin/env python3
"""
Command Line Interface for Enhanced Epidemiological Analysis

This module provides the command line interface, argument parsing,
and orchestration logic for the Markov blanket analysis.

Author: Scott A. Malec PhD
Date: February 2025
"""

import argparse
import sys
import time

# Import configuration and database operations from separate modules
from config_models import (
    EXPOSURE_OUTCOME_CONFIGS, 
    create_db_config, 
    validate_arguments,
    load_yaml_config,
    create_dynamic_config_from_yaml
)

# Import the core analysis functionality
from analysis_core import GraphAnalyzer, MarkovBlanketAnalyzer


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Enhanced Epidemiological Analysis Script with Markov Blanket Analysis (Multiple CUIs Support + YAML Config)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Available exposure-outcome configurations (now supporting multiple CUIs):
{chr(10).join([f"  {name}: {config.description}" + 
              f"{chr(10)}    Exposure CUIs: {', '.join(config.exposure_cui_list)}" +
              f"{chr(10)}    Outcome CUIs: {', '.join(config.outcome_cui_list)}"
              for name, config in EXPOSURE_OUTCOME_CONFIGS.items()])}

YAML Configuration Support:
  Use --yaml-config to load exposure_cuis, outcome_cuis, min_pmids, and predication_type from a YAML file.
  YAML file should contain:
    exposure_cuis: [list of CUIs]
    outcome_cuis: [list of CUIs]
    min_pmids: threshold value (default: 50)
    predication_type: [list of predication types] or "comma,separated,string" (backward compatible)
    degree: number of degrees (1-3, default: 3)
    # other parameters for future use

Example usage:
  python {sys.argv[0]} --config hypertension_alzheimers --host localhost --user myuser --password mypass --dbname causalehr
  python {sys.argv[0]} --yaml-config config.yaml --host localhost --user myuser --password mypass --dbname causalehr --markov-blanket
  python {sys.argv[0]} --config cardiovascular_dementia --output-dir results_2025 --threshold 100
        """
    )
    
    # Configuration method - either predefined or YAML
    config_group = parser.add_mutually_exclusive_group(required=True)
    config_group.add_argument(
        "--config", 
        choices=list(EXPOSURE_OUTCOME_CONFIGS.keys()),
        help="Exposure-outcome configuration to analyze (supports multiple CUIs)"
    )
    config_group.add_argument(
        "--yaml-config",
        help="Path to YAML configuration file containing exposure_cuis, outcome_cuis, and min_pmids"
    )
    
    # Database connection parameters
    db_group = parser.add_argument_group("Database Connection")
    db_group.add_argument("--host", default="localhost", help="Database host (default: localhost)")
    db_group.add_argument("--port", default="5432", help="Database port (default: 5432)")
    db_group.add_argument("--dbname", required=True, help="Database name")
    db_group.add_argument("--user", required=True, help="Database user")
    db_group.add_argument("--password", required=True, help="Database password")
    db_group.add_argument("--schema", help="Database schema (optional)")
    
    # Analysis parameters
    analysis_group = parser.add_argument_group("Analysis Parameters")
    analysis_group.add_argument(
        "--threshold", 
        type=int, 
        default=50,
        help="Minimum support count for all relationship degrees (default: 50). Ignored if using YAML config with min_pmids."
    )
    analysis_group.add_argument(
        "--markov-blanket",
        action="store_true",
        default=False,
        help="Enable Markov blanket computation and generate MarkovBlanket_Union.R (default: False)"
    )
    analysis_group.add_argument(
        "--degree",
        type=int,
        default=3,
        choices=[1, 2, 3],
        help="Number of degrees for graph traversal (1-3, default: 3). Controls the depth of relationships included in the graph."
    )
    
    # Output parameters
    output_group = parser.add_argument_group("Output Parameters")
    output_group.add_argument(
        "--output-dir", 
        default="output",
        help="Output directory for results (default: output)"
    )
    output_group.add_argument(
        "--verbose", 
        action="store_true",
        help="Enable verbose output"
    )
    
    return parser.parse_args()


def create_analysis_configuration(args):
    """Create analysis configuration from command line arguments."""
    # Convert port to integer if it's a string
    try:
        port = int(args.port)
    except (ValueError, TypeError):
        raise ValueError(f"Invalid port value: {args.port}. Port must be a valid integer.")

    # Create database configuration
    db_config = create_db_config(
        host=args.host,
        port=port,
        dbname=args.dbname,
        user=args.user,
        password=args.password,
        schema=args.schema
    )
    
    # Handle YAML configuration
    if args.yaml_config:
        dynamic_config, yaml_threshold, yaml_config_data = create_dynamic_config_from_yaml(args.yaml_config)
        # Add the dynamic config to the global configs for the session
        config_name = f"yaml_config_{int(time.time())}"
        EXPOSURE_OUTCOME_CONFIGS[config_name] = dynamic_config
        return db_config, config_name, yaml_threshold, yaml_config_data
    else:
        # Use predefined configuration and command-line threshold
        return db_config, args.config, args.threshold, None


def show_usage_help():
    """Display usage help when no arguments are provided."""
    print("Error: Missing required arguments.")
    print("\nThis script requires command line arguments to run.")
    print("Use --help to see all available options.\n")
    print("Example usage:")
    print(f"  # Using predefined configuration:")
    print(f"  python {sys.argv[0]} --config hypertension_alzheimers --dbname causalehr --user myuser --password mypass")
    print(f"  # Using YAML configuration:")
    print(f"  python {sys.argv[0]} --yaml-config config.yaml --dbname causalehr --user myuser --password mypass")
    print(f"  python {sys.argv[0]} --help")
    print("\nAvailable predefined configurations (with multiple CUIs support):")
    for name, config in EXPOSURE_OUTCOME_CONFIGS.items():
        print(f"  {name}: {config.description}")
        print(f"    Exposure CUIs: {', '.join(config.exposure_cui_list)}")
        print(f"    Outcome CUIs: {', '.join(config.outcome_cui_list)}")
    print("\nYAML Configuration:")
    print("  Create a YAML file with exposure_cuis, outcome_cuis, and min_pmids")
    print("  Example YAML content:")
    print("    exposure_cuis:")
    print("    - C0011849") 
    print("    - C0020538")
    print("    outcome_cuis:")
    print("    - C0027051")
    print("    - C0038454")
    print("    min_pmids: 50")


def main():
    """Main function with command line interface."""
    try:
        args = parse_arguments()
        validate_arguments(args)
        
        # Create analysis configuration (handles both predefined and YAML configs)
        config_result = create_analysis_configuration(args)
        if len(config_result) == 4:
            db_config, config_name, threshold, yaml_config_data = config_result
        else:
            # Legacy support (shouldn't happen with new argument structure)
            db_config, threshold = config_result
            config_name = args.config
            yaml_config_data = None
        
        # Display configuration info including multiple CUIs
        selected_config = EXPOSURE_OUTCOME_CONFIGS[config_name]
        
        if args.verbose:
            print(f"Running analysis with configuration: {config_name}")
            if yaml_config_data:
                print(f"  Configuration source: YAML file ({args.yaml_config})")
                print(f"  YAML min_pmids (threshold): {threshold}")
            else:
                print(f"  Configuration source: Predefined")
                print(f"  Command-line threshold: {threshold}")
            print(f"  Description: {selected_config.description}")
            print(f"  Exposure CUIs: {', '.join(selected_config.exposure_cui_list)} ({len(selected_config.exposure_cui_list)} CUIs)")
            print(f"  Outcome CUIs: {', '.join(selected_config.outcome_cui_list)} ({len(selected_config.outcome_cui_list)} CUIs)")
            print(f"  Total target CUIs: {len(selected_config.all_target_cuis)}")
            print(f"  Markov blanket: {'Enabled' if args.markov_blanket else 'Disabled'}")
            print(f"Database: {args.host}:{args.port}/{args.dbname}")
            print(f"Output directory: {args.output_dir}")
        
        # Initialize and run analysis based on whether Markov blanket is enabled
        degree = yaml_config_data.get('degree') if yaml_config_data else getattr(args, 'degree', 3)

        if args.markov_blanket:
            # Use MarkovBlanketAnalyzer for Markov blanket analysis
            analyzer = MarkovBlanketAnalyzer(
                config_name=config_name,
                db_params=db_config,
                threshold=threshold,
                output_dir=args.output_dir,
                yaml_config_data=yaml_config_data,
                degree=degree
            )

            timing_results = analyzer.run_markov_blanket_analysis()
            analyzer.display_markov_blanket_summary(timing_results)
        else:
            # Use GraphAnalyzer for general graph analysis
            analyzer = GraphAnalyzer(
                config_name=config_name,
                db_params=db_config,
                threshold=threshold,
                output_dir=args.output_dir,
                yaml_config_data=yaml_config_data,
                degree=degree
            )

            timing_results = analyzer.run_analysis()
            analyzer.display_results_summary(timing_results)
        
    except KeyboardInterrupt:
        print("\nAnalysis interrupted by user.")
        sys.exit(1)
    except Exception as e:
        print(f"\nError: {e}")
        if args.verbose if 'args' in locals() else False:
            import traceback
            traceback.print_exc()
        sys.exit(1)


# -------------------------
# MAIN ENTRY POINT
# -------------------------
if __name__ == "__main__":
    # Always require command line arguments - no legacy mode
    if len(sys.argv) == 1:
        show_usage_help()
        sys.exit(1)
    
    # Run with command line arguments
    main()
