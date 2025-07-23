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
import os
import sys
from pathlib import Path
from typing import Dict, Set, Tuple, List
from datetime import datetime

# Import configuration and database operations from separate module
from config import (
    EXPOSURE_OUTCOME_CONFIGS, 
    TimingContext, 
    DatabaseOperations,
    create_db_config, 
    validate_arguments
)

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
                 thresholds: Dict[str, int],
                 output_dir: str = "output"):
        """Initialize the analyzer with configuration parameters."""
        if config_name not in EXPOSURE_OUTCOME_CONFIGS:
            raise ValueError(f"Unknown config: {config_name}. Available: {list(EXPOSURE_OUTCOME_CONFIGS.keys())}")
        
        self.config = EXPOSURE_OUTCOME_CONFIGS[config_name]
        self.db_params = db_params
        self.thresholds = thresholds
        self.timing_data = {}
        self.output_dir = Path(output_dir)
        
        # Initialize database operations helper
        self.db_ops = DatabaseOperations(self.config, self.thresholds, self.timing_data)
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory created: {self.output_dir.absolute()}")

    def generate_dagitty_scripts(self, nodes: Set[str], edges: Set[Tuple[str, str]], 
                               mb_nodes: Set[str]):
        """Create R scripts for DAGitty visualization and adjustment set identification."""
        with TimingContext("dagitty_generation", self.timing_data):
            # Overall DAG script - SIMPLIFIED FORMAT
            dagitty_lines = [
                "g <- dagitty('dag {",
                f" {self.db_ops.clean_output_name(self.config.exposure_name)} [exposure]",
                f" {self.db_ops.clean_output_name(self.config.outcome_name)} [outcome]"
            ]
            
            # Add nodes and edges
            for node in nodes:
                if node not in {self.db_ops.clean_output_name(self.config.exposure_name),
                              self.db_ops.clean_output_name(self.config.outcome_name)}:
                    dagitty_lines.append(f" {node}")
            
            for src, dst in edges:
                dagitty_lines.append(f" {src} -> {dst}")
            
            # Close the DAG definition
            dagitty_lines.append("}')")
            
            dagitty_format = "\n".join(dagitty_lines)
            
            # Save overall DAG script
            with open(self.output_dir / "SemDAG.R", "w") as f:
                f.write(dagitty_format)
            
            # Generate Markov blanket-specific script - SIMPLIFIED FORMAT
            mb_edges = [(u, v) for u, v in edges if u in mb_nodes and v in mb_nodes]
            dagitty_mb_lines = [
                "g <- dagitty('dag {",
                f" {self.db_ops.clean_output_name(self.config.exposure_name)} [exposure]",
                f" {self.db_ops.clean_output_name(self.config.outcome_name)} [outcome]"
            ]
            
            for node in mb_nodes:
                if node not in {self.db_ops.clean_output_name(self.config.exposure_name),
                              self.db_ops.clean_output_name(self.config.outcome_name)}:
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
        
        # Save run configuration
        run_config = {
            "config_name": self.config.name,
            "config_description": self.config.description,
            "exposure_cui": self.config.exposure_cui,
            "exposure_name": self.config.exposure_name,
            "outcome_cui": self.config.outcome_cui,
            "outcome_name": self.config.outcome_name,
            "thresholds": self.thresholds,
            "database": {
                "host": self.db_params.get("host"),
                "port": self.db_params.get("port"),
                "dbname": self.db_params.get("dbname"),
                "user": self.db_params.get("user"),
                "schema": self.db_params.get("options", "").replace("-c search_path=", "") if "options" in self.db_params else None
            },
            "run_timestamp": datetime.now().isoformat(),
            "output_directory": str(output_path.absolute())
        }
        
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
        print(f"Output directory: {output_path.absolute()}")
        print("\nGenerated files:")
        print(f"  - causal_assertions.json: Detailed causal relationships")
        print(f"  - SemDAG.R: R script for full DAG visualization")
        print(f"  - MarkovBlanket_Union.R: R script for Markov blanket analysis")
        print(f"  - performance_metrics.json: Timing information")
        print(f"  - run_configuration.json: Complete run parameters")
        
        print("\nTiming Results:")
        total_time = timing_results.get("total_execution", {}).get("duration", 0)
        print(f"  Total execution time: {total_time:.2f} seconds")
        for step, metrics in timing_results.items():
            if step != "total_execution":
                print(f"  {step}: {metrics['duration']:.2f} seconds")
        
        print("\nTo visualize results, run the R scripts in the output directory:")
        print(f"  cd {output_path}")
        print(f"  Rscript SemDAG.R")
        print(f"  Rscript MarkovBlanket_Union.R")

    def run_analysis(self) -> Dict:
        """Execute the complete analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            print(f"\nStarting analysis for {self.config.description}...")
            print(f"Using thresholds: {self.thresholds}")
            print(f"Output directory: {self.output_dir.absolute()}")
            
            # Connect to database
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    print("\nFetching causal relationships from database...")
                    
                    # Fetch relationships using database operations helper
                    first_degree_cuis, first_degree_links = self.db_ops.fetch_first_degree_relationships(cursor)
                    print(f"Found {len(first_degree_links)} first-degree relationships")
                    
                    detailed_assertions, second_degree_links = self.db_ops.fetch_second_degree_relationships(
                        cursor, first_degree_cuis
                    )
                    print(f"Found {len(second_degree_links)} second-degree relationships")
                    
                    # Compute Markov blankets
                    mb_union = self.db_ops.compute_markov_blankets(cursor)
                    
                    print("\nConstructing causal graph...")
                    # Build graph
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()
                        for src, dst in first_degree_links:
                            G.add_edge(src, dst)
                        for src, dst in second_degree_links:
                            G.add_edge(src, dst)
                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges")
                    
                    print("\nGenerating DAGitty visualization scripts...")
                    # Generate visualization scripts
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_dagitty_scripts(all_nodes, all_edges, mb_union)
                    print(f"DAGitty scripts generated: {self.output_dir}/SemDAG.R and {self.output_dir}/MarkovBlanket_Union.R")
                    
                    # Save all results and metadata
                    self.save_results_and_metadata(self.timing_data, detailed_assertions)
            
        print("\nAnalysis complete!")
        return self.timing_data

def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Enhanced Epidemiological Analysis Script with Markov Blanket Analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
Available exposure-outcome configurations:
{chr(10).join([f"  {name}: {config.description}" for name, config in EXPOSURE_OUTCOME_CONFIGS.items()])}

Example usage:
  python {sys.argv[0]} --config hypertension_alzheimers --host localhost --user myuser --password mypass --dbname causalehr
  python {sys.argv[0]} --config depression_alzheimers --output-dir results_2025 --first-degree-threshold 100
        """
    )
    
    # Required arguments
    parser.add_argument(
        "--config", 
        required=True,
        choices=list(EXPOSURE_OUTCOME_CONFIGS.keys()),
        help="Exposure-outcome configuration to analyze"
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
        "--first-degree-threshold", 
        type=int, 
        default=50,
        help="Minimum support count for first-degree relationships (default: 50)"
    )
    analysis_group.add_argument(
        "--second-degree-threshold", 
        type=int, 
        default=50,
        help="Minimum support count for second-degree relationships (default: 50)"
    )
    analysis_group.add_argument(
        "--markov-blanket-threshold", 
        type=int, 
        default=50,
        help="Minimum support count for Markov blanket computation (default: 50)"
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
    
    # Create analysis thresholds
    thresholds = {
        "first_degree": args.first_degree_threshold,
        "second_degree": args.second_degree_threshold,
        "markov_blanket": args.markov_blanket_threshold
    }
    
    return db_config, thresholds

def main():
    """Main function with command line interface."""
    try:
        args = parse_arguments()
        validate_arguments(args)
        
        if args.verbose:
            print(f"Running analysis with configuration: {args.config}")
            print(f"Database: {args.host}:{args.port}/{args.dbname}")
            print(f"Thresholds: first={args.first_degree_threshold}, second={args.second_degree_threshold}, markov={args.markov_blanket_threshold}")
            print(f"Output directory: {args.output_dir}")
        
        # Create analysis configuration
        db_config, thresholds = create_analysis_configuration(args)
        
        # Initialize and run analysis
        analyzer = MarkovBlanketAnalyzer(
            config_name=args.config,
            db_params=db_config,
            thresholds=thresholds,
            output_dir=args.output_dir
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
    print(f"  python {sys.argv[0]} --config hypertension_alzheimers --dbname causalehr --user myuser --password mypass")
    print(f"  python {sys.argv[0]} --help")
    print("\nAvailable configurations:")
    for name, config in EXPOSURE_OUTCOME_CONFIGS.items():
        print(f"  {name}: {config.description}")

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