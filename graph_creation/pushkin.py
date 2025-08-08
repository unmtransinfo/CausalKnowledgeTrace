#!/usr/bin/env python3
"""
Main Analysis Script for Enhanced Epidemiological Analysis

This script provides the main analyzer class, command line interface,
and orchestration logic for the Markov blanket analysis.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
import networkx as nx
import json
import argparse
# import os  # Not used in this module
import sys
from pathlib import Path
from typing import Dict, Set, Tuple, List, Optional
from datetime import datetime
import time

# Import configuration and database operations from separate module
from config import (
    EXPOSURE_OUTCOME_CONFIGS, 
    TimingContext, 
    DatabaseOperations,
    create_db_config, 
    validate_arguments,
    load_yaml_config,
    create_dynamic_config_from_yaml
)

# Add import for the new Markov blanket module
from markov_blanket import MarkovBlanketComputer

class MarkovBlanketAnalyzer:
    """
    Main class for performing Markov blanket analysis on biomedical literature data.
    
    Epidemiological Rationale:
    -------------------------
    Markov blankets provide a principled approach to identifying confounders in causal inference.
    The Markov blanket of a node contains all variables that make it conditionally independent
    of all other variables, making it valuable for confounder selection.
    """
    
    def __init__(self,
                 config_name: str,
                 db_params: Dict[str, str],
                 threshold: int,
                 output_dir: str = "output",
                 yaml_config_data: Optional[Dict] = None,
                 enable_markov_blanket: bool = False,
                 k_hops: int = 3):
        """Initialize the analyzer with configuration parameters.

        Args:
            config_name: Name of the predefined configuration
            db_params: Database connection parameters
            threshold: Minimum evidence threshold for relationships
            output_dir: Directory for output files
            yaml_config_data: Optional YAML configuration data
            enable_markov_blanket: Whether to enable Markov blanket analysis
            k_hops: Number of hops for graph traversal (1-3, default: 3)
        """
        if config_name not in EXPOSURE_OUTCOME_CONFIGS:
            raise ValueError(f"Unknown config: {config_name}. Available: {list(EXPOSURE_OUTCOME_CONFIGS.keys())}")

        # Validate k_hops parameter
        if not isinstance(k_hops, int) or k_hops < 1 or k_hops > 3:
            raise ValueError(f"k_hops must be an integer between 1 and 3, got: {k_hops}")

        self.k_hops = k_hops
        
        self.config = EXPOSURE_OUTCOME_CONFIGS[config_name]
        self.db_params = db_params
        self.threshold = threshold
        self.output_dir = Path(output_dir)  # Convert to Path object
        self.yaml_config_data = yaml_config_data
        self.enable_markov_blanket = enable_markov_blanket
        self.timing_data = {}
        
        # Extract predication types from YAML config if available
        predication_types = ['CAUSES']  # default
        if yaml_config_data and 'predication_types' in yaml_config_data:
            predication_types = yaml_config_data['predication_types']

        # Initialize database operations with predication types and k_hops
        self.db_ops = DatabaseOperations(self.config, threshold, self.timing_data, predication_types, k_hops)
        
        # Initialize Markov blanket computer if enabled
        if self.enable_markov_blanket:
            self.mb_computer = MarkovBlanketComputer(self.config, threshold, self.timing_data)
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory created: {self.output_dir.absolute()}")

    def get_dag_filename(self) -> str:
        """Generate the DAG filename based on k_hops parameter."""
        return f"degree_{self.k_hops}.R"

    def generate_dagitty_scripts(self, nodes: Set[str], edges: Set[Tuple[str, str]],
                               mb_nodes: Optional[Set[str]] = None):
        """Create R scripts for DAGitty visualization and adjustment set identification."""
        with TimingContext("dagitty_generation", self.timing_data):
            # Fetch CUI-to-name mappings for exposure and outcome CUIs
            exposure_concept_names = []
            outcome_concept_names = []

            try:
                with psycopg2.connect(**self.db_params) as conn:
                    with conn.cursor() as cursor:
                        # Get all CUIs for mapping
                        all_cuis = self.config.exposure_cui_list + self.config.outcome_cui_list
                        cui_name_mapping = self.db_ops.fetch_cui_name_mappings(cursor, all_cuis)

                        # Build exposure concept names
                        for cui in self.config.exposure_cui_list:
                            if cui in cui_name_mapping:
                                concept_name = self.db_ops.clean_output_name(cui_name_mapping[cui])
                                exposure_concept_names.append(concept_name)
                            else:
                                # Fallback to CUI if name not found
                                exposure_concept_names.append(f"Exposure_{cui}")

                        # Build outcome concept names
                        for cui in self.config.outcome_cui_list:
                            if cui in cui_name_mapping:
                                concept_name = self.db_ops.clean_output_name(cui_name_mapping[cui])
                                outcome_concept_names.append(concept_name)
                            else:
                                # Fallback to CUI if name not found
                                outcome_concept_names.append(f"Outcome_{cui}")

            except Exception as e:
                print(f"Warning: Could not fetch CUI name mappings for DAG generation: {e}")
                # Fallback to original CUI-based names
                exposure_concept_names = [f"Exposure_{cui}" for cui in self.config.exposure_cui_list]
                outcome_concept_names = [f"Outcome_{cui}" for cui in self.config.outcome_cui_list]

            # Clean all node names before generating scripts
            cleaned_nodes = {self.db_ops.clean_output_name(node) for node in nodes}
            cleaned_edges = {(self.db_ops.clean_output_name(src), self.db_ops.clean_output_name(dst))
                           for src, dst in edges}

            # Overall DAG script - ENHANCED FORMAT with human-readable names
            dagitty_lines = ["g <- dagitty('dag {"]

            # Add exposure nodes with human-readable names
            for concept_name in exposure_concept_names:
                dagitty_lines.append(f" {concept_name} [exposure]")

            # Add outcome nodes with human-readable names
            for concept_name in outcome_concept_names:
                dagitty_lines.append(f" {concept_name} [outcome]")

            # Collect all exposure and outcome concept names for filtering
            all_exposure_outcome_names = set(exposure_concept_names + outcome_concept_names)

            # Add other cleaned nodes (excluding exposure/outcome nodes)
            for node in cleaned_nodes:
                if node not in all_exposure_outcome_names:
                    dagitty_lines.append(f" {node}")

            # Add cleaned edges
            for src, dst in cleaned_edges:
                dagitty_lines.append(f" {src} -> {dst}")

            # Close the DAG definition
            dagitty_lines.append("}')")

            dagitty_format = "\n".join(dagitty_lines)

            # Save overall DAG script with dynamic filename based on k_hops
            dag_filename = self.get_dag_filename()
            with open(self.output_dir / dag_filename, "w") as f:
                f.write(dagitty_format)
            
            # Generate Markov blanket-specific script only if enabled and mb_nodes provided
            if self.enable_markov_blanket and mb_nodes is not None:
                # Clean Markov blanket nodes
                cleaned_mb_nodes = {self.db_ops.clean_output_name(node) for node in mb_nodes}
                mb_edges = [(self.db_ops.clean_output_name(u), self.db_ops.clean_output_name(v))
                           for u, v in edges if self.db_ops.clean_output_name(u) in cleaned_mb_nodes
                           and self.db_ops.clean_output_name(v) in cleaned_mb_nodes]

                dagitty_mb_lines = ["g <- dagitty('dag {"]

                # Add exposure nodes with human-readable names for Markov blanket
                for concept_name in exposure_concept_names:
                    dagitty_mb_lines.append(f" {concept_name} [exposure]")

                # Add outcome nodes with human-readable names for Markov blanket
                for concept_name in outcome_concept_names:
                    dagitty_mb_lines.append(f" {concept_name} [outcome]")

                # Add other Markov blanket nodes (excluding exposure/outcome nodes)
                for node in cleaned_mb_nodes:
                    if node not in all_exposure_outcome_names:
                        dagitty_mb_lines.append(f" {node}")

                for src, dst in mb_edges:
                    dagitty_mb_lines.append(f" {src} -> {dst}")

                # Close the DAG definition
                dagitty_mb_lines.append("}')")

                dagitty_mb_format = "\n".join(dagitty_mb_lines)
                with open(self.output_dir / "MarkovBlanket_Union.R", "w") as f:
                    f.write(dagitty_mb_format)

    def save_results_and_metadata(self, timing_results: Dict, detailed_assertions: List[Dict]):
        """Save analysis results, timing data, and configuration metadata."""
        output_path = self.output_dir
        
        # Save timing results
        with open(output_path / "performance_metrics.json", "w") as f:
            json.dump(timing_results, f, indent=2)
        
        # Save detailed assertions
        with open(output_path / "causal_assertions.json", "w") as f:
            json.dump(detailed_assertions, f, indent=2)
        
        # Save run configuration with multiple CUIs support
        run_config = {
            "config_name": self.config.name,
            "config_description": self.config.description,
            "exposure_cuis": self.config.exposure_cui_list,
            "exposure_name": self.config.exposure_name,
            "outcome_cuis": self.config.outcome_cui_list,
            "outcome_name": self.config.outcome_name,
            "all_target_cuis": self.config.all_target_cuis,
            "threshold": self.threshold,
            "threshold_source": "yaml_min_pmids" if self.yaml_config_data else "command_line",
            "predication_types": self.db_ops.predication_types,
            "predication_type_source": "yaml_config" if self.yaml_config_data else "default",
            "database": {
                "host": self.db_params.get("host"),
                "port": self.db_params.get("port"),
                "dbname": self.db_params.get("dbname"),
                "user": self.db_params.get("user"),
                "schema": self.db_params.get("options", "").replace("-c search_path=", "") if "options" in self.db_params else None
            },
            "run_timestamp": datetime.now().isoformat(),
            "output_directory": str(output_path.absolute()),
            "multiple_cuis_used": {
                "exposure_count": len(self.config.exposure_cui_list),
                "outcome_count": len(self.config.outcome_cui_list),
                "total_target_cuis": len(self.config.all_target_cuis)
            }
        }
        
        # Add YAML configuration data if available
        if self.yaml_config_data:
            run_config["yaml_configuration"] = self.yaml_config_data
            run_config["config_source"] = "yaml_file"
        else:
            run_config["config_source"] = "predefined"
        
        with open(output_path / "run_configuration.json", "w") as f:
            json.dump(run_config, f, indent=2)

    def display_results_summary(self, timing_results: Dict):
        """Display a comprehensive summary of analysis results."""
        output_path = self.output_dir

        print("\n" + "="*60)
        print("ANALYSIS COMPLETE")
        print("="*60)
        print(f"Configuration: {self.config.name}")
        print(f"Description: {self.config.description}")

        # Fetch CUI-to-name mappings from database
        exposure_cui_display = []
        outcome_cui_display = []

        try:
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    # Get all CUIs for mapping
                    all_cuis = self.config.exposure_cui_list + self.config.outcome_cui_list
                    cui_name_mapping = self.db_ops.fetch_cui_name_mappings(cursor, all_cuis)

                    # Build exposure CUI display with names
                    for cui in self.config.exposure_cui_list:
                        if cui in cui_name_mapping:
                            exposure_cui_display.append(f"{cui} -> {cui_name_mapping[cui]}")
                        else:
                            exposure_cui_display.append(f"{cui} -> CUI name mapping not found for {cui}")

                    # Build outcome CUI display with names
                    for cui in self.config.outcome_cui_list:
                        if cui in cui_name_mapping:
                            outcome_cui_display.append(f"{cui} -> {cui_name_mapping[cui]}")
                        else:
                            outcome_cui_display.append(f"{cui} -> CUI name mapping not found for {cui}")

        except Exception as e:
            print(f"Warning: Could not fetch CUI name mappings: {e}")
            # Fallback to CUI-only display
            exposure_cui_display = self.config.exposure_cui_list
            outcome_cui_display = self.config.outcome_cui_list

        print(f"Exposure CUIs: {', '.join(exposure_cui_display)} ({len(self.config.exposure_cui_list)} CUIs)")
        print(f"Outcome CUIs: {', '.join(outcome_cui_display)} ({len(self.config.outcome_cui_list)} CUIs)")
        print(f"Total target CUIs: {len(self.config.all_target_cuis)}")
        print(f"Output directory: {output_path.absolute()}")
        
        print("\nGenerated files:")
        print(f"  - causal_assertions.json: Detailed causal relationships")
        print(f"  - {self.get_dag_filename()}: R script for full DAG visualization (k_hops={self.k_hops})")
        if self.enable_markov_blanket:
            print(f"  - MarkovBlanket_Union.R: R script for Markov blanket analysis")
        print(f"  - performance_metrics.json: Timing information")
        print(f"  - run_configuration.json: Complete run parameters")
        
        print("\nTiming Results:")
        total_time = timing_results.get("total_execution", {}).get("duration", 0)
        print(f"  Total execution time: {total_time:.2f} seconds")
        for step, metrics in timing_results.items():
            if step != "total_execution":
                print(f"  {step}: {metrics['duration']:.2f} seconds")
        
        print("\nMultiple CUIs Configuration:")
        print(f"  This analysis used {len(self.config.exposure_cui_list)} exposure CUI(s) and {len(self.config.outcome_cui_list)} outcome CUI(s)")
        print(f"  Total relationships analyzed across {len(self.config.all_target_cuis)} target concepts")
        if self.yaml_config_data:
            print(f"  Configuration loaded from YAML file")
            print(f"  Threshold (min_pmids): {self.threshold}")
        
        print("\nTo visualize results, run the R scripts in the output directory:")
        print(f"  cd {output_path}")
        print(f"  Rscript {self.get_dag_filename()}")
        if self.enable_markov_blanket:
            print(f"  Rscript MarkovBlanket_Union.R")

    def run_analysis(self) -> Dict:
        """Execute the complete analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            print(f"\nStarting analysis for {self.config.description}...")
            print(f"Configuration supports multiple CUIs:")
            print(f"  Exposure CUIs: {', '.join(self.config.exposure_cui_list)} ({len(self.config.exposure_cui_list)} CUIs)")
            print(f"  Outcome CUIs: {', '.join(self.config.outcome_cui_list)} ({len(self.config.outcome_cui_list)} CUIs)")
            print(f"Using threshold: {self.threshold}")
            print(f"Markov blanket analysis: {'Enabled' if self.enable_markov_blanket else 'Disabled'}")
            print(f"Output directory: {self.output_dir.absolute()}")
            
            # Connect to database
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    print("\nFetching causal relationships from database...")
                    print("Note: Queries now support multiple CUIs per exposure/outcome")
                    print(f"Using k-hop parameter: {self.k_hops} (maximum relationship depth)")

                    # Fetch relationships using k-hop functionality
                    _, all_links, detailed_assertions = self.db_ops.fetch_k_hop_relationships(cursor)
                    print(f"Found {len(all_links)} total relationships up to {self.k_hops} hops")
                    
                    # Compute Markov blankets only if enabled
                    mb_union = None
                    if self.enable_markov_blanket:
                        mb_union = self.mb_computer.compute_markov_blankets(cursor)
                    else:
                        print("\nSkipping Markov blanket computation (disabled)")
                    
                    print("\nConstructing causal graph...")
                    # Build graph with cleaned node names
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Add edges with cleaned node names from all k-hop relationships
                        for src, dst in all_links:
                            clean_src = self.db_ops.clean_output_name(src)
                            clean_dst = self.db_ops.clean_output_name(dst)
                            G.add_edge(clean_src, clean_dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (k_hops={self.k_hops})")
                    
                    print("\nGenerating DAGitty visualization scripts...")
                    # Generate visualization scripts
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_dagitty_scripts(all_nodes, all_edges, mb_union)
                    
                    if self.enable_markov_blanket:
                        print(f"DAGitty scripts generated with Markov blanket support:")
                        print(f"  - {self.output_dir}/{self.get_dag_filename()}")
                        print(f"  - {self.output_dir}/MarkovBlanket_Union.R")
                    else:
                        print(f"DAGitty script generated:")
                        print(f"  - {self.output_dir}/{self.get_dag_filename()}")
                    
                    # Save all results and metadata
                    self.save_results_and_metadata(self.timing_data, detailed_assertions)
            
        print("\nAnalysis complete!")
        return self.timing_data

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
  Use --yaml-config to load exposure_cuis, outcome_cuis, and min_pmids from a YAML file.
  YAML file should contain:
    exposure_cuis: [list of CUIs]
    outcome_cuis: [list of CUIs] 
    min_pmids: threshold value (default: 50)
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
    db_group.add_argument("--port", type=int, default=5432, help="Database port (default: 5432)")
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
        "--k-hops",
        type=int,
        default=3,
        choices=[1, 2, 3],
        help="Number of hops for graph traversal (1-3, default: 3). Controls the depth of relationships included in the graph."
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
    # Create database configuration
    db_config = create_db_config(
        host=args.host,
        port=args.port,
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
        
        # Initialize and run analysis
        analyzer = MarkovBlanketAnalyzer(
            config_name=config_name,
            db_params=db_config,
            threshold=threshold,
            output_dir=args.output_dir,
            yaml_config_data=yaml_config_data,
            enable_markov_blanket=args.markov_blanket,
            k_hops=yaml_config_data.get('k_hops') if yaml_config_data else getattr(args, 'k_hops', 3)  # Use YAML k_hops, then command line, then default
        )
        
        timing_results = analyzer.run_analysis()
        
        # Display comprehensive results summary
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