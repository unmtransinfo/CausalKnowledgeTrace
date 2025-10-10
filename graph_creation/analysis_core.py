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


# Import configuration and database operations from separate modules
from config_models import EXPOSURE_OUTCOME_CONFIGS, TimingContext
from database_operations import DatabaseOperations, format_sql_query_for_logging

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
                 degree: int = 3):
        """Initialize the graph analyzer with configuration parameters.

        Args:
            config_name: Name of the predefined configuration
            db_params: Database connection parameters
            threshold: Minimum evidence threshold for relationships
            output_dir: Directory for output files
            yaml_config_data: Optional YAML configuration data
            degree: Number of degrees for graph traversal (1+, default: 3)
        """
        if config_name not in EXPOSURE_OUTCOME_CONFIGS:
            raise ValueError(f"Unknown config: {config_name}. Available: {list(EXPOSURE_OUTCOME_CONFIGS.keys())}")

        # Validate degree parameter - now supports any positive integer
        if not isinstance(degree, int) or degree < 1:
            raise ValueError(f"degree must be a positive integer, got: {degree}")

        self.degree = degree

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

        # Extract blocklist CUIs from YAML config if available
        blocklist_cuis = []
        if yaml_config_data and 'blocklist_cuis' in yaml_config_data:
            blocklist_cuis = yaml_config_data['blocklist_cuis']

        # Initialize database operations with predication types, degree, and blocklist_cuis
        self.db_ops = DatabaseOperations(self.config, threshold, self.timing_data, predication_types, degree, blocklist_cuis)

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory created: {self.output_dir.absolute()}")

    def get_dag_filename(self) -> str:
        """Generate the DAG filename based on degree parameter."""
        return f"degree_{self.degree}.R"

    def get_causal_assertions_filename(self) -> str:
        """Generate the causal assertions filename based on degree parameter."""
        return f"causal_assertions_{self.degree}.json"

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

            # Save overall DAG script with dynamic filename based on degree
            dag_filename = self.get_dag_filename()
            with open(self.output_dir / dag_filename, "w") as f:
                f.write(dagitty_format)

    def save_results_and_metadata(self, timing_results: Dict, detailed_assertions: List[Dict]):
        """Save analysis results, timing data, and configuration metadata with optimization."""
        output_path = self.output_dir

        # Save timing results
        with open(output_path / "performance_metrics.json", "w") as f:
            json.dump(timing_results, f, indent=2)

        # Save detailed assertions with degree suffix using optimized serialization
        causal_assertions_filename = self.get_causal_assertions_filename()
        print(f"Saving {len(detailed_assertions)} assertions to {causal_assertions_filename}...")

        # Use optimized JSON serialization for large files
        self.save_optimized_json(detailed_assertions, output_path / causal_assertions_filename)

        # Automatically create optimized formats for large files
        file_size_mb = (output_path / causal_assertions_filename).stat().st_size / (1024 * 1024)
        if file_size_mb > 50:  # For files larger than 50MB
            print(f"Large file detected ({file_size_mb:.1f}MB) - creating optimized formats...")
            self.create_optimized_formats(output_path / causal_assertions_filename)

    def save_optimized_json(self, data: List[Dict], filepath: Path):
        """Save JSON using the new single optimized format."""
        print(f"Saving {len(data)} assertions in optimized format...")

        # Create optimized structure
        optimized_data = self.create_optimized_structure(data)

        # Save with custom readable formatting
        self._save_with_custom_formatting(optimized_data, filepath)

        print(f"Saved optimized format with {len(optimized_data['pmid_sentences'])} unique PMIDs and {sum(len(sentences) for sentences in optimized_data['pmid_sentences'].values())} total sentences")

    def create_optimized_structure(self, data: List[Dict]) -> Dict:
        """Create optimized JSON structure with sentence deduplication."""
        optimized = {
            'pmid_sentences': {},      # pmid -> [sentences] mapping
            'assertions': []           # assertions array (compact)
        }

        # First pass: collect PMID -> sentences mapping
        for assertion in data:
            pmid_data = assertion.get('pmid_data', {})
            for pmid, pmid_info in pmid_data.items():
                sentences = pmid_info.get('sentences', [])
                if sentences:
                    # Store sentences directly with PMID
                    if pmid not in optimized['pmid_sentences']:
                        optimized['pmid_sentences'][pmid] = sentences
                    else:
                        # Merge sentences if PMID appears multiple times
                        existing_sentences = set(optimized['pmid_sentences'][pmid])
                        for sentence in sentences:
                            if sentence not in existing_sentences:
                                optimized['pmid_sentences'][pmid].append(sentence)
                                existing_sentences.add(sentence)

        # Second pass: create compact assertions
        for assertion in data:
            # Create compact assertion with meaningful short field names
            compact_assertion = {
                'subj': assertion.get('subject_name', ''),      # subject_name -> subj
                'subj_cui': assertion.get('subject_cui', ''),   # subject_cui -> subj_cui
                'predicate': assertion.get('predicate', ''),    # predicate -> predicate
                'obj': assertion.get('object_name', ''),        # object_name -> obj
                'obj_cui': assertion.get('object_cui', ''),     # object_cui -> obj_cui
                'ev_count': assertion.get('evidence_count', 0), # evidence_count -> ev_count
                'pmid_refs': []                                 # List of PMIDs for this assertion
            }

            # Build PMID references list
            pmid_data = assertion.get('pmid_data', {})
            for pmid, pmid_info in pmid_data.items():
                sentences = pmid_info.get('sentences', [])
                if sentences:
                    # Just store the PMID - sentences are stored in pmid_sentences
                    compact_assertion['pmid_refs'].append(pmid)

            optimized['assertions'].append(compact_assertion)

        return optimized

    def _save_with_custom_formatting(self, data: Dict, filepath: Path):
        """Save JSON with custom readable formatting."""
        def format_json_custom(obj, indent_level=0, parent_key=None):
            """Custom JSON formatter with special handling for nested structures."""
            indent = "  " * indent_level
            next_indent = "  " * (indent_level + 1)

            if isinstance(obj, dict):
                if not obj:
                    return "{}"

                lines = ["{"]
                items = list(obj.items())

                for i, (key, value) in enumerate(items):
                    comma = "," if i < len(items) - 1 else ""

                    # Special formatting for pmid_sentences to put each PMID on separate line
                    if key == "pmid_sentences" and isinstance(value, dict):
                        lines.append(f'{next_indent}"{key}": {{')
                        pmid_items = list(value.items())
                        for j, (pmid_key, pmid_value) in enumerate(pmid_items):
                            pmid_comma = "," if j < len(pmid_items) - 1 else ""
                            formatted_value = format_json_custom(pmid_value, indent_level + 2, key)
                            lines.append(f'{next_indent}  "{pmid_key}": {formatted_value}{pmid_comma}')
                        lines.append(f'{next_indent}}}{comma}')
                    else:
                        formatted_value = format_json_custom(value, indent_level + 1, key)
                        lines.append(f'{next_indent}"{key}": {formatted_value}{comma}')

                lines.append(f"{indent}}}")
                return "\n".join(lines)

            elif isinstance(obj, list):
                if not obj:
                    return "[]"

                # Always keep pmid_refs arrays on one line regardless of length
                if parent_key == "pmid_refs" and all(isinstance(item, (int, str)) for item in obj):
                    formatted_items = [json.dumps(item, ensure_ascii=False) for item in obj]
                    return f"[{', '.join(formatted_items)}]"

                # For short lists (like sentence indices), keep on one line
                if all(isinstance(item, (int, str)) for item in obj) and len(obj) <= 10:
                    formatted_items = [json.dumps(item, ensure_ascii=False) for item in obj]
                    return f"[{', '.join(formatted_items)}]"

                # For longer lists, use multi-line format
                lines = ["["]
                for i, item in enumerate(obj):
                    comma = "," if i < len(obj) - 1 else ""
                    formatted_item = format_json_custom(item, indent_level + 1, parent_key)
                    lines.append(f"{next_indent}{formatted_item}{comma}")
                lines.append(f"{indent}]")
                return "\n".join(lines)

            else:
                return json.dumps(obj, ensure_ascii=False)

        # Save with custom formatting
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(format_json_custom(data))

    def create_optimized_formats(self, json_filepath: Path):
        """Create optimized formats (binary, lightweight) for large JSON files."""
        import subprocess
        import sys

        try:
            # Call R script to create optimized formats
            r_script = f"""
# Load required modules
setwd("{Path(__file__).parent.parent / 'shiny_app'}")
source("modules/binary_storage.R")
source("modules/sentence_storage.R")

# Convert to binary format
cat("Creating binary format...\\n")
binary_result <- convert_json_to_binary("{json_filepath}", compression = "gzip")

if (binary_result$success) {{
    cat("✓ Binary format created:", binary_result$compression_ratio, "% compression\\n")
}} else {{
    cat("✗ Binary format failed:", binary_result$message, "\\n")
}}

# Create lightweight format
cat("Creating lightweight format...\\n")
degree <- {self.degree}
lightweight_result <- create_separated_files("{json_filepath}", degree = degree)

if (lightweight_result$success) {{
    cat("✓ Lightweight format created:", lightweight_result$size_reduction_percent, "% size reduction\\n")
}} else {{
    cat("✗ Lightweight format failed:", lightweight_result$message, "\\n")
}}
"""

            # Write and execute R script
            r_script_path = json_filepath.parent / "optimize_temp.R"
            with open(r_script_path, "w") as f:
                f.write(r_script)

            print("Running optimization script...")
            result = subprocess.run([
                "Rscript", str(r_script_path)
            ], capture_output=True, text=True, cwd=json_filepath.parent)

            if result.returncode == 0:
                print("✓ Optimization completed successfully")
                print(result.stdout)
            else:
                print("⚠ Optimization had issues:")
                print(result.stderr)

            # Clean up temp script
            r_script_path.unlink(missing_ok=True)

        except Exception as e:
            print(f"⚠ Could not create optimized formats: {e}")

    def check_evidence_exists(self, cursor) -> bool:
        """
        Check if there is sufficient evidence in the database before proceeding with graph creation.
        Uses the same CUIs and threshold from user_input.yaml configuration.

        Returns:
            bool: True if evidence exists, False otherwise
        """
        print("\nChecking if sufficient evidence exists in database...")

        # Get predication types from database operations
        predication_types = self.db_ops.predication_types

        # Create conditions for multiple CUIs and predication types
        exposure_condition = self.db_ops._create_cui_conditions(self.config.exposure_cui_list, "cp.subject_cui")
        outcome_condition = self.db_ops._create_cui_conditions(self.config.outcome_cui_list, "cp.object_cui")
        predication_condition = self.db_ops._create_predication_condition()

        # Build the evidence check query
        query = f"""
        SELECT EXISTS (
            SELECT 1
            FROM causalpredication cp
            WHERE {predication_condition}
              AND {exposure_condition}
              AND {outcome_condition}
            GROUP BY cp.subject_cui, cp.object_cui, cp.predicate
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        ) AS has_evidence;
        """

        # Parameters: predication types + exposure CUIs + outcome CUIs + threshold
        params = predication_types + self.config.exposure_cui_list + self.config.outcome_cui_list + [self.threshold]

        print("Evidence check query:")
        print("-" * 40)
        formatted_query = format_sql_query_for_logging(query, params)
        print(formatted_query)
        print("-" * 40)

        cursor.execute(query, params)
        result = cursor.fetchone()
        has_evidence = result[0] if result else False

        if has_evidence:
            print("✓ Evidence found: Sufficient causal relationships exist in database")
            print(f"  At least one relationship meets the threshold of {self.threshold} PMIDs")
        else:
            print("✗ No evidence found: No causal relationships meet the threshold")
            print(f"  No relationships found with >= {self.threshold} PMIDs between:")
            print(f"    Exposure CUIs: {', '.join(self.config.exposure_cui_list)}")
            print(f"    Outcome CUIs: {', '.join(self.config.outcome_cui_list)}")
            print(f"    Predication types: {', '.join(predication_types)}")

        return has_evidence

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
                    # Check if evidence exists before proceeding
                    if not self.check_evidence_exists(cursor):
                        print("\n" + "="*60)
                        print("GRAPH CREATION ABORTED")
                        print("="*60)
                        print("Reason: No sufficient evidence found in database")
                        print("Recommendation: Try adjusting the following parameters:")
                        print(f"  - Lower the threshold (currently {self.threshold})")
                        print("  - Add more exposure or outcome CUIs")
                        print("  - Check if the CUIs exist in the database")
                        print("  - Verify predication types are correct")
                        return {"error": "No evidence found", "total_execution": {"duration": 0}}

                    print("\nFetching causal relationships from database...")
                    print("Note: Queries now support multiple CUIs per exposure/outcome")
                    print(f"Using degree parameter: {self.degree} (maximum relationship depth)")

                    # Fetch relationships using degree functionality with CUI-based node identification
                    _, cui_based_links, detailed_assertions = self.db_ops.fetch_k_hop_relationships(cursor)
                    print(f"Found {len(cui_based_links)} CUI-based relationships up to {self.degree} degrees")

                    print("\nConstructing causal graph...")
                    # Build graph with cleaned node names and consolidated mapping
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Add edges with cleaned node names from CUI-based relationships
                        consolidated_edges = set()
                        for src, dst in cui_based_links:
                            clean_src = self.db_ops.clean_output_name(src)
                            clean_dst = self.db_ops.clean_output_name(dst)

                            # Apply consolidated mapping
                            consolidated_src = self.db_ops.apply_consolidated_mapping(clean_src, consolidated_mapping)
                            consolidated_dst = self.db_ops.apply_consolidated_mapping(clean_dst, consolidated_mapping)

                            # Only add edge if source and destination are different (avoid self-loops from consolidation)
                            if consolidated_src != consolidated_dst:
                                consolidated_edges.add((consolidated_src, consolidated_dst))
                                G.add_edge(consolidated_src, consolidated_dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (degree={self.degree})")
                        print(f"Consolidated {len(cui_based_links)} CUI-based relationships into {len(consolidated_edges)} consolidated relationships")

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
        print(f"  - {self.get_causal_assertions_filename()}: Detailed causal relationships")
        print(f"  - {self.get_dag_filename()}: R script for DAG visualization (degree={self.degree})")
        print(f"  - performance_metrics.json: Timing information")

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
                 degree: int = 3):
        """Initialize the Markov blanket analyzer with configuration parameters.

        Args:
            config_name: Name of the predefined configuration
            db_params: Database connection parameters
            threshold: Minimum evidence threshold for relationships
            output_dir: Directory for output files
            yaml_config_data: Optional YAML configuration data
            degree: Number of degrees for graph traversal (1+, default: 3)
        """
        # Initialize the base GraphAnalyzer
        super().__init__(config_name, db_params, threshold, output_dir, yaml_config_data, degree)

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
        print(f"  - {self.get_causal_assertions_filename()}: Detailed causal relationships")
        print(f"  - {self.get_dag_filename()}: R script for full DAG visualization (degree={self.degree})")
        print(f"  - MarkovBlanket_Union.R: R script for Markov blanket analysis")
        print(f"  - performance_metrics.json: Timing information")

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
                    # Check if evidence exists before proceeding
                    if not self.check_evidence_exists(cursor):
                        print("\n" + "="*60)
                        print("MARKOV BLANKET ANALYSIS ABORTED")
                        print("="*60)
                        print("Reason: No sufficient evidence found in database")
                        print("Recommendation: Try adjusting the following parameters:")
                        print(f"  - Lower the threshold (currently {self.threshold})")
                        print("  - Add more exposure or outcome CUIs")
                        print("  - Check if the CUIs exist in the database")
                        print("  - Verify predication types are correct")
                        return {"error": "No evidence found", "total_execution": {"duration": 0}}

                    print("\nFetching causal relationships from database...")
                    print("Note: Queries now support multiple CUIs per exposure/outcome")
                    print(f"Using degree parameter: {self.degree} (maximum relationship depth)")

                    # Fetch relationships using k-hop functionality with CUI-based node identification
                    _, cui_based_links, detailed_assertions = self.db_ops.fetch_k_hop_relationships(cursor)
                    print(f"Found {len(cui_based_links)} CUI-based relationships up to {self.degree} degrees")

                    # Compute Markov blankets
                    mb_union = self.mb_computer.compute_markov_blankets(cursor)

                    print("\nConstructing causal graph...")
                    # Build graph with cleaned node names and consolidated mapping
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Create consolidated node mapping
                        consolidated_mapping = self.db_ops.create_consolidated_node_mapping(cursor)

                        # Add edges with cleaned node names from CUI-based relationships
                        consolidated_edges = set()
                        for src, dst in cui_based_links:
                            clean_src = self.db_ops.clean_output_name(src)
                            clean_dst = self.db_ops.clean_output_name(dst)

                            # Apply consolidated mapping
                            consolidated_src = self.db_ops.apply_consolidated_mapping(clean_src, consolidated_mapping)
                            consolidated_dst = self.db_ops.apply_consolidated_mapping(clean_dst, consolidated_mapping)

                            # Only add edge if source and destination are different (avoid self-loops from consolidation)
                            if consolidated_src != consolidated_dst:
                                consolidated_edges.add((consolidated_src, consolidated_dst))
                                G.add_edge(consolidated_src, consolidated_dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (degree={self.degree})")
                        print(f"Consolidated {len(cui_based_links)} CUI-based relationships into {len(consolidated_edges)} consolidated relationships")

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
