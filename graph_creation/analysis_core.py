#!/usr/bin/env python3
"""
Core Analysis Module for Enhanced Epidemiological Analysis

This module contains the main analyzer classes for both general graph analysis
and specialized Markov blanket analysis.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
import networkx as nx
import json
from pathlib import Path
from typing import Dict, Set, Tuple, List, Optional
from datetime import datetime

# Import configuration and database operations from separate modules
from config_models import EXPOSURE_OUTCOME_CONFIGS, TimingContext
from database_operations import DatabaseOperations

# Add import for the new Markov blanket module
from markov_blanket import MarkovBlanketComputer


class GraphAnalyzer:
    """
    Base class for performing general causal graph analysis on biomedical literature data.

    This class handles the core functionality of:
    - Database operations and k-hop relationship fetching
    - Graph construction and consolidation
    - Basic DAGitty script generation
    - Results saving and performance metrics

    This class follows the single responsibility principle by focusing only on
    general graph operations, without Markov blanket-specific functionality.
    """

    def __init__(self,
                 config_name: str,
                 db_params: Dict[str, str],
                 threshold: int,
                 output_dir: str = "output",
                 yaml_config_data: Optional[Dict] = None,
                 k_hops: int = 3):
        """Initialize the graph analyzer with configuration parameters.

        Args:
            config_name: Name of the predefined configuration
            db_params: Database connection parameters
            threshold: Minimum evidence threshold for relationships
            output_dir: Directory for output files
            yaml_config_data: Optional YAML configuration data
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
        self.timing_data = {}

        # Extract predication types from YAML config if available
        predication_types = ['CAUSES']  # default
        if yaml_config_data and 'predication_types' in yaml_config_data:
            predication_types = yaml_config_data['predication_types']

        # Initialize database operations with predication types and k_hops
        self.db_ops = DatabaseOperations(self.config, threshold, self.timing_data, predication_types, k_hops)

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory created: {self.output_dir.absolute()}")

    def get_dag_filename(self) -> str:
        """Generate the DAG filename based on k_hops parameter."""
        return f"degree_{self.k_hops}.R"

    def generate_basic_dagitty_script(self, nodes: Set[str], edges: Set[Tuple[str, str]]):
        """Create basic R script for DAGitty visualization."""
        with TimingContext("dagitty_generation", self.timing_data):
            try:
                with psycopg2.connect(**self.db_params) as conn:
                    with conn.cursor() as cursor:
                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Get consolidated exposure and outcome names
                        consolidated_exposure_name = self.db_ops.clean_output_name(self.config.exposure_name)
                        consolidated_outcome_name = self.db_ops.clean_output_name(self.config.outcome_name)

            except Exception as e:
                print(f"Warning: Could not create consolidated mapping for DAG generation: {e}")
                # Fallback to basic consolidated names
                consolidated_mapping = {}
                consolidated_exposure_name = self.db_ops.clean_output_name(self.config.exposure_name)
                consolidated_outcome_name = self.db_ops.clean_output_name(self.config.outcome_name)

            # Clean all node names and apply consolidated mapping
            cleaned_nodes = set()
            for node in nodes:
                clean_node = self.db_ops.clean_output_name(node)
                consolidated_node = self.db_ops.apply_consolidated_mapping(clean_node, consolidated_mapping)
                cleaned_nodes.add(consolidated_node)

            # Clean edges and apply consolidated mapping
            cleaned_edges = set()
            for src, dst in edges:
                clean_src = self.db_ops.clean_output_name(src)
                clean_dst = self.db_ops.clean_output_name(dst)
                consolidated_src = self.db_ops.apply_consolidated_mapping(clean_src, consolidated_mapping)
                consolidated_dst = self.db_ops.apply_consolidated_mapping(clean_dst, consolidated_mapping)
                # Only add edge if source and destination are different (avoid self-loops from consolidation)
                if consolidated_src != consolidated_dst:
                    cleaned_edges.add((consolidated_src, consolidated_dst))

            # Overall DAG script - ENHANCED FORMAT with consolidated nodes
            dagitty_lines = ["g <- dagitty('dag {"]

            # Add consolidated exposure node
            dagitty_lines.append(f" {consolidated_exposure_name} [exposure]")

            # Add consolidated outcome node
            dagitty_lines.append(f" {consolidated_outcome_name} [outcome]")

            # Collect consolidated exposure and outcome names for filtering
            all_exposure_outcome_names = {consolidated_exposure_name, consolidated_outcome_name}

            # Add other cleaned nodes (excluding consolidated exposure/outcome nodes)
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

    def run_analysis(self) -> Dict:
        """Execute the complete general graph analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            print(f"\nStarting graph analysis for {self.config.description}...")
            print(f"Configuration supports multiple CUIs:")
            print(f"  Exposure CUIs: {', '.join(self.config.exposure_cui_list)} ({len(self.config.exposure_cui_list)} CUIs)")
            print(f"  Outcome CUIs: {', '.join(self.config.outcome_cui_list)} ({len(self.config.outcome_cui_list)} CUIs)")
            print(f"Using threshold: {self.threshold}")
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

                    print("\nConstructing causal graph...")
                    # Build graph with cleaned node names and consolidated mapping
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Add edges with cleaned node names from all k-hop relationships
                        consolidated_edges = set()
                        for src, dst in all_links:
                            clean_src = self.db_ops.clean_output_name(src)
                            clean_dst = self.db_ops.clean_output_name(dst)

                            # Apply consolidated mapping
                            consolidated_src = self.db_ops.apply_consolidated_mapping(clean_src, consolidated_mapping)
                            consolidated_dst = self.db_ops.apply_consolidated_mapping(clean_dst, consolidated_mapping)

                            # Only add edge if source and destination are different (avoid self-loops from consolidation)
                            if consolidated_src != consolidated_dst:
                                consolidated_edges.add((consolidated_src, consolidated_dst))
                                G.add_edge(consolidated_src, consolidated_dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (k_hops={self.k_hops})")
                        print(f"Consolidated {len(all_links)} original relationships into {len(consolidated_edges)} consolidated relationships")

                    print("\nGenerating DAGitty visualization script...")
                    # Generate basic DAG script
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_basic_dagitty_script(all_nodes, all_edges)

                    print(f"DAGitty script generated:")
                    print(f"  - {self.output_dir}/{self.get_dag_filename()}")

                    # Save all results and metadata
                    self.save_results_and_metadata(self.timing_data, detailed_assertions)

        print("\nGraph analysis complete!")
        return self.timing_data

    def display_results_summary(self, timing_results: Dict):
        """Display a comprehensive summary of general graph analysis results."""
        output_path = self.output_dir

        print("\n" + "="*60)
        print("GRAPH ANALYSIS COMPLETE")
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
        print(f"  - {self.get_dag_filename()}: R script for DAG visualization (k_hops={self.k_hops})")
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

        print("\nTo visualize results, run the R script in the output directory:")
        print(f"  cd {output_path}")
        print(f"  Rscript {self.get_dag_filename()}")


class MarkovBlanketAnalyzer(GraphAnalyzer):
    """
    Specialized class for performing Markov blanket analysis on biomedical literature data.

    This class extends GraphAnalyzer to add Markov blanket-specific functionality:
    - Markov blanket computation for exposure and outcome variables
    - Enhanced DAGitty script generation with Markov blanket filtering
    - Markov blanket-specific output files and reporting

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
                 k_hops: int = 3):
        """Initialize the Markov blanket analyzer with configuration parameters.

        Args:
            config_name: Name of the predefined configuration
            db_params: Database connection parameters
            threshold: Minimum evidence threshold for relationships
            output_dir: Directory for output files
            yaml_config_data: Optional YAML configuration data
            k_hops: Number of hops for graph traversal (1-3, default: 3)
        """
        # Initialize the base GraphAnalyzer
        super().__init__(config_name, db_params, threshold, output_dir, yaml_config_data, k_hops)

        # Extract predication types from YAML config if available
        predication_types = ['CAUSES']  # default
        if yaml_config_data and 'predication_types' in yaml_config_data:
            predication_types = yaml_config_data['predication_types']

        # Initialize Markov blanket computer
        self.mb_computer = MarkovBlanketComputer(self.config, threshold, self.timing_data, predication_types)

    def generate_markov_blanket_dagitty_script(self, edges: Set[Tuple[str, str]], mb_nodes: Set[str]):
        """Generate Markov blanket-specific DAGitty script."""
        with TimingContext("markov_blanket_dagitty_generation", self.timing_data):
            try:
                with psycopg2.connect(**self.db_params) as conn:
                    with conn.cursor() as cursor:
                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Get consolidated exposure and outcome names
                        consolidated_exposure_name = self.db_ops.clean_output_name(self.config.exposure_name)
                        consolidated_outcome_name = self.db_ops.clean_output_name(self.config.outcome_name)

            except Exception as e:
                print(f"Warning: Could not create consolidated mapping for Markov blanket DAG generation: {e}")
                # Fallback to basic consolidated names
                consolidated_mapping = {}
                consolidated_exposure_name = self.db_ops.clean_output_name(self.config.exposure_name)
                consolidated_outcome_name = self.db_ops.clean_output_name(self.config.outcome_name)

            # Clean Markov blanket nodes and apply consolidated mapping
            cleaned_mb_nodes = set()
            for node in mb_nodes:
                clean_node = self.db_ops.clean_output_name(node)
                consolidated_node = self.db_ops.apply_consolidated_mapping(clean_node, consolidated_mapping)
                cleaned_mb_nodes.add(consolidated_node)

            # Create consolidated Markov blanket edges
            mb_edges = set()
            for u, v in edges:
                clean_u = self.db_ops.clean_output_name(u)
                clean_v = self.db_ops.clean_output_name(v)
                consolidated_u = self.db_ops.apply_consolidated_mapping(clean_u, consolidated_mapping)
                consolidated_v = self.db_ops.apply_consolidated_mapping(clean_v, consolidated_mapping)

                # Only include edges where both nodes are in the Markov blanket and not self-loops
                if (consolidated_u in cleaned_mb_nodes and consolidated_v in cleaned_mb_nodes
                    and consolidated_u != consolidated_v):
                    mb_edges.add((consolidated_u, consolidated_v))

            # Collect consolidated exposure and outcome names for filtering
            all_exposure_outcome_names = {consolidated_exposure_name, consolidated_outcome_name}

            dagitty_mb_lines = ["g <- dagitty('dag {"]

            # Add consolidated exposure node for Markov blanket
            if consolidated_exposure_name in cleaned_mb_nodes:
                dagitty_mb_lines.append(f" {consolidated_exposure_name} [exposure]")

            # Add consolidated outcome node for Markov blanket
            if consolidated_outcome_name in cleaned_mb_nodes:
                dagitty_mb_lines.append(f" {consolidated_outcome_name} [outcome]")

            # Add other Markov blanket nodes (excluding consolidated exposure/outcome nodes)
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

    def display_markov_blanket_summary(self, timing_results: Dict):
        """Display a comprehensive summary of Markov blanket analysis results."""
        output_path = self.output_dir

        print("\n" + "="*60)
        print("MARKOV BLANKET ANALYSIS COMPLETE")
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
        print(f"  - MarkovBlanket_Union.R: R script for Markov blanket analysis")
        print(f"  - performance_metrics.json: Timing information")
        print(f"  - run_configuration.json: Complete run parameters")

        print("\nTiming Results:")
        total_time = timing_results.get("total_execution", {}).get("duration", 0)
        print(f"  Total execution time: {total_time:.2f} seconds")
        for step, metrics in timing_results.items():
            if step != "total_execution":
                print(f"  {step}: {metrics['duration']:.2f} seconds")

        print("\nMarkov Blanket Analysis:")
        print(f"  This analysis computed Markov blankets for {len(self.config.exposure_cui_list)} exposure CUI(s) and {len(self.config.outcome_cui_list)} outcome CUI(s)")
        print(f"  Total relationships analyzed across {len(self.config.all_target_cuis)} target concepts")
        if self.yaml_config_data:
            print(f"  Configuration loaded from YAML file")
            print(f"  Threshold (min_pmids): {self.threshold}")

        print("\nTo visualize results, run the R scripts in the output directory:")
        print(f"  cd {output_path}")
        print(f"  Rscript {self.get_dag_filename()}")
        print(f"  Rscript MarkovBlanket_Union.R")

    def run_markov_blanket_analysis(self) -> Dict:
        """Execute the complete Markov blanket analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            print(f"\nStarting Markov blanket analysis for {self.config.description}...")
            print(f"Configuration supports multiple CUIs:")
            print(f"  Exposure CUIs: {', '.join(self.config.exposure_cui_list)} ({len(self.config.exposure_cui_list)} CUIs)")
            print(f"  Outcome CUIs: {', '.join(self.config.outcome_cui_list)} ({len(self.config.outcome_cui_list)} CUIs)")
            print(f"Using threshold: {self.threshold}")
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

                    # Compute Markov blankets
                    mb_union = self.mb_computer.compute_markov_blankets(cursor)

                    print("\nConstructing causal graph...")
                    # Build graph with cleaned node names and consolidated mapping
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Add edges with cleaned node names from all k-hop relationships
                        consolidated_edges = set()
                        for src, dst in all_links:
                            clean_src = self.db_ops.clean_output_name(src)
                            clean_dst = self.db_ops.clean_output_name(dst)

                            # Apply consolidated mapping
                            consolidated_src = self.db_ops.apply_consolidated_mapping(clean_src, consolidated_mapping)
                            consolidated_dst = self.db_ops.apply_consolidated_mapping(clean_dst, consolidated_mapping)

                            # Only add edge if source and destination are different (avoid self-loops from consolidation)
                            if consolidated_src != consolidated_dst:
                                consolidated_edges.add((consolidated_src, consolidated_dst))
                                G.add_edge(consolidated_src, consolidated_dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (k_hops={self.k_hops})")
                        print(f"Consolidated {len(all_links)} original relationships into {len(consolidated_edges)} consolidated relationships")

                    print("\nGenerating DAGitty visualization scripts...")
                    # Generate basic DAG script using parent class method
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_basic_dagitty_script(all_nodes, all_edges)

                    # Generate Markov blanket-specific script
                    self.generate_markov_blanket_dagitty_script(all_edges, mb_union)

                    print(f"DAGitty scripts generated with Markov blanket support:")
                    print(f"  - {self.output_dir}/{self.get_dag_filename()}")
                    print(f"  - {self.output_dir}/MarkovBlanket_Union.R")

                    # Save all results and metadata
                    self.save_results_and_metadata(self.timing_data, detailed_assertions)

        print("\nMarkov blanket analysis complete!")
        return self.timing_data
