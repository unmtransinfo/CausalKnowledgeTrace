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

        # Extract degree-specific thresholds from YAML config if available
        thresholds_by_degree = None
        if yaml_config_data and 'thresholds_by_degree' in yaml_config_data:
            thresholds_by_degree = yaml_config_data['thresholds_by_degree']

        # Initialize database operations with predication types, degree, blocklist_cuis, and thresholds_by_degree
        self.db_ops = DatabaseOperations(self.config, threshold, self.timing_data, predication_types, degree, blocklist_cuis, thresholds_by_degree)

        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory created: {self.output_dir.absolute()}")

    def _get_name_prefix(self) -> str:
        """Build the '{exposure}_to_{outcome}_degree{N}' prefix for output files."""
        exposure = getattr(self.config, 'exposure_name', None)
        outcome = getattr(self.config, 'outcome_name', None)
        if exposure and outcome:
            return f"{exposure}_to_{outcome}_degree{self.degree}"
        return f"degree_{self.degree}"

    def get_dag_filename(self) -> str:
        """Generate the DAG filename based on exposure, outcome, and degree."""
        return f"{self._get_name_prefix()}.R"

    def get_cytoscape_filename(self) -> str:
        """Generate the Cytoscape.js JSON filename based on exposure, outcome, and degree."""
        return f"{self._get_name_prefix()}.json"

    def generate_basic_dagitty_script(
        self,
        nodes: Set[str],
        edges: Set[Tuple[str, str]],
        exposure_nodes: Optional[Set[str]] = None,
        outcome_nodes: Optional[Set[str]] = None,
    ):
        """Create basic R script for DAGitty visualization.

        Nodes and edges are assumed to already use cleaned/consolidated ids.
        exposure_nodes and outcome_nodes (if provided) should be subsets of ``nodes``.
        """
        # Normalize optional sets
        exposure_nodes = exposure_nodes or set()
        outcome_nodes = outcome_nodes or set()

        with TimingContext("dagitty_generation", self.timing_data):
            dagitty_lines = ["g <- dagitty('dag {"]

            # Add nodes with dagitty exposure/outcome annotations
            for node in sorted(nodes):
                if node in exposure_nodes:
                    dagitty_lines.append(f" {node} [exposure]")
                elif node in outcome_nodes:
                    dagitty_lines.append(f" {node} [outcome]")
                else:
                    dagitty_lines.append(f" {node}")

            # Add edges
            for src, dst in sorted(edges):
                dagitty_lines.append(f" {src} -> {dst}")

            # Close the DAG definition
            dagitty_lines.append("}')")

            dagitty_format = "\n".join(dagitty_lines)

            # Save overall DAG script with dynamic filename based on degree
            dag_filename = self.get_dag_filename()
            with open(self.output_dir / dag_filename, "w") as f:
                f.write(dagitty_format)

    def generate_cytoscape_json(
        self,
        nodes: Set[str],
        edges: Set[Tuple[str, str]],
        exposure_nodes: Optional[Set[str]],
        outcome_nodes: Optional[Set[str]],
        detailed_assertions: List[Dict],
        cui_to_display_name: Dict[str, str],
    ):
        """Generate a Cytoscape.js-compatible JSON file for graph visualization.

        Each edge embeds PMID data (with sentences) and evidence count so the
        front-end Element Info panel can display full provenance on edge click.

        Args:
            nodes: Display-name node ids in the graph.
            edges: Set of (source, target) display-name tuples in the graph.
            exposure_nodes: Subset of nodes that are exposure variables.
            outcome_nodes: Subset of nodes that are outcome variables.
            detailed_assertions: Raw assertion dicts from the database, each with
                subject_cui, object_cui, predicate, evidence_count, pmid_data.
            cui_to_display_name: CUI -> display name mapping (single source of truth).
        """
        exposure_nodes = exposure_nodes or set()
        outcome_nodes = outcome_nodes or set()

        with TimingContext("cytoscape_generation", self.timing_data):
            # --- Nodes ---
            cytoscape_nodes = []
            for node in sorted(nodes):
                if node in exposure_nodes:
                    node_type = "exposure"
                elif node in outcome_nodes:
                    node_type = "outcome"
                else:
                    node_type = "default"
                cytoscape_nodes.append({
                    "data": {"id": node, "label": node, "node_type": node_type}
                })

            # --- Edges ---
            # Key: (display_source, predicate, display_target)
            # Multiple raw assertions collapsing to the same key are merged.
            edge_map: Dict[Tuple[str, str, str], Dict] = {}

            for assertion in detailed_assertions:
                subject_cui = assertion.get("subject_cui", "")
                object_cui = assertion.get("object_cui", "")
                predicate = assertion.get("predicate", "")

                # Resolve CUI → display name (same path as graph construction)
                cons_subj = cui_to_display_name.get(subject_cui, "")
                cons_obj = cui_to_display_name.get(object_cui, "")

                # Skip unmapped CUIs, self-loops, and edges not in the graph
                if not cons_subj or not cons_obj:
                    continue
                if cons_subj == cons_obj:
                    continue
                if (cons_subj, cons_obj) not in edges:
                    continue

                edge_key = (cons_subj, predicate, cons_obj)
                if edge_key not in edge_map:
                    edge_map[edge_key] = {
                        "source": cons_subj,
                        "target": cons_obj,
                        "predicate": predicate,
                        "subject_name": cons_subj,
                        "subject_cui": subject_cui,
                        "object_name": cons_obj,
                        "object_cui": object_cui,
                        "evidence_count": 0,
                        "pmid_data": {},
                    }

                entry = edge_map[edge_key]
                entry["evidence_count"] += assertion.get("evidence_count", 0)

                # Merge PMID -> sentences, deduplicating sentences
                for pmid, pmid_info in assertion.get("pmid_data", {}).items():
                    sentences = pmid_info.get("sentences", [])
                    if pmid not in entry["pmid_data"]:
                        entry["pmid_data"][pmid] = list(sentences)
                    else:
                        existing = set(entry["pmid_data"][pmid])
                        for s in sentences:
                            if s not in existing:
                                entry["pmid_data"][pmid].append(s)
                                existing.add(s)

            cytoscape_edges = []
            for edge_key in sorted(edge_map.keys()):
                source, predicate, target = edge_key
                ed = edge_map[edge_key]
                cytoscape_edges.append({
                    "data": {
                        "id": f"{source}__{predicate}__{target}",
                        "source": source,
                        "target": target,
                        "predicate": ed["predicate"],
                        "subject_name": ed["subject_name"],
                        "subject_cui": ed["subject_cui"],
                        "object_name": ed["object_name"],
                        "object_cui": ed["object_cui"],
                        "evidence_count": ed["evidence_count"],
                        "pmid_data": ed["pmid_data"],
                    }
                })

            cytoscape_data = {
                "elements": {
                    "nodes": cytoscape_nodes,
                    "edges": cytoscape_edges,
                }
            }

            cytoscape_filename = self.get_cytoscape_filename()
            with open(self.output_dir / cytoscape_filename, "w", encoding="utf-8") as f:
                json.dump(cytoscape_data, f, indent=2, ensure_ascii=False)

            print(f"Cytoscape.js JSON saved: {self.output_dir}/{cytoscape_filename}")
            print(f"  Nodes: {len(cytoscape_nodes)}, Edges: {len(cytoscape_edges)}")

    def save_optimized_json(
        self,
        data: List[Dict],
        filepath: Path,
        cui_to_display_name: Dict[str, str] = None
    ):
        """Save JSON using the new single optimized format."""
        print(f"Saving {len(data)} assertions in optimized format...")

        # Create optimized structure using CUI-based display name resolution
        optimized_data = self.create_optimized_structure(data, cui_to_display_name)

        # Save with custom readable formatting
        self._save_with_custom_formatting(optimized_data, filepath)

    def create_optimized_structure(
        self,
        data: List[Dict],
        cui_to_display_name: Dict[str, str] = None
    ) -> Dict:
        """Create optimized JSON structure with sentence deduplication and CUI-based name resolution."""
        optimized = {
            'pmid_sentences': {},      # pmid -> [sentences] mapping
            'assertions': []           # assertions array (compact)
        }

        if cui_to_display_name is None:
            cui_to_display_name = {}

        # First pass: collect PMID -> sentences mapping
        for assertion in data:
            pmid_data = assertion.get('pmid_data', {})
            for pmid, pmid_info in pmid_data.items():
                sentences = pmid_info.get('sentences', [])
                if sentences:
                    if pmid not in optimized['pmid_sentences']:
                        optimized['pmid_sentences'][pmid] = sentences
                    else:
                        existing_sentences = set(optimized['pmid_sentences'][pmid])
                        for sentence in sentences:
                            if sentence not in existing_sentences:
                                optimized['pmid_sentences'][pmid].append(sentence)
                                existing_sentences.add(sentence)

        # Second pass: create compact assertions using CUI → display name
        for assertion in data:
            subject_cui = assertion.get('subject_cui', '')
            object_cui = assertion.get('object_cui', '')

            # Resolve display names via CUI (same path as graph + Cytoscape)
            display_subject = cui_to_display_name.get(subject_cui, self.db_ops.clean_output_name(assertion.get('subject_name', '')))
            display_object = cui_to_display_name.get(object_cui, self.db_ops.clean_output_name(assertion.get('object_name', '')))

            compact_assertion = {
                'subj': display_subject,
                'subj_cui': subject_cui,
                'predicate': assertion.get('predicate', ''),
                'obj': display_object,
                'obj_cui': object_cui,
                'ev_count': assertion.get('evidence_count', 0),
                'pmid_refs': []
            }

            # Build PMID references list
            pmid_data = assertion.get('pmid_data', {})
            for pmid, pmid_info in pmid_data.items():
                sentences = pmid_info.get('sentences', [])
                if sentences:
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



    def run_analysis(self) -> Dict:
        """Execute the complete general graph analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            # Connect to database
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    # Fetch relationships — returns CUI pairs (stable identifiers)
                    _, cui_links, detailed_assertions = self.db_ops.fetch_k_hop_relationships(cursor)

                    # Build CUI -> canonical name mapping
                    cui_to_name_mapping = self.db_ops.build_cui_to_name_mapping(detailed_assertions)

                    print("\nConstructing causal graph...")
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Build the single CUI → display-name mapping used
                        # everywhere (graph, Cytoscape JSON export).
                        cui_to_display_name = self._build_cui_to_display_name(cui_to_name_mapping)

                        # Build graph from detailed_assertions
                        for assertion in detailed_assertions:
                            src_cui = assertion.get("subject_cui", "")
                            dst_cui = assertion.get("object_cui", "")
                            src = cui_to_display_name.get(src_cui)
                            dst = cui_to_display_name.get(dst_cui)
                            if src and dst and src != dst:
                                G.add_edge(src, dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (degree={self.degree})")

                        # Identify exposure / outcome nodes by their known display names
                        nodes_in_graph = set(G.nodes())
                        exposure_nodes, outcome_nodes = self._get_exposure_outcome_node_sets(nodes_in_graph)

                    print("\nGenerating Graph in JSON...")
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_cytoscape_json(
                        all_nodes, all_edges, exposure_nodes, outcome_nodes,
                        detailed_assertions, cui_to_display_name
                    )

        return self.timing_data

    def _build_cui_to_display_name(
        self,
        cui_to_name_mapping: Dict[str, str],
    ) -> Dict[str, str]:
        """Build a CUI → display-name mapping used everywhere in the pipeline.

        * Exposure CUIs → ``clean(config.exposure_name)``
        * Outcome CUIs  → ``clean(config.outcome_name)``
        * All other CUIs → ``clean(canonical_name)``

        Because every path through the code resolves names through this single
        mapping, graph edges and Cytoscape / assertion outputs are guaranteed to
        agree – eliminating the isolated-node bug that arose when canonical vs
        raw assertion names diverged.
        """
        cui_to_display: Dict[str, str] = {}

        exposure_display = self.db_ops.clean_output_name(self.config.exposure_name)
        outcome_display = self.db_ops.clean_output_name(self.config.outcome_name)

        # Exposure CUIs → single consolidated label
        for cui in getattr(self.config, "exposure_cui_list", []):
            cui_to_display[cui] = exposure_display

        # Outcome CUIs → single consolidated label
        for cui in getattr(self.config, "outcome_cui_list", []):
            cui_to_display[cui] = outcome_display

        # Remaining CUIs → cleaned canonical name (don't overwrite exposure/outcome)
        for cui, canonical_name in cui_to_name_mapping.items():
            if cui not in cui_to_display:
                cui_to_display[cui] = self.db_ops.clean_output_name(canonical_name)

        return cui_to_display

    def _get_exposure_outcome_node_sets(
        self,
        nodes_in_graph: Set[str],
    ) -> Tuple[Set[str], Set[str]]:
        """Return the exposure and outcome display-name sets present in the graph."""
        exposure_display = self.db_ops.clean_output_name(self.config.exposure_name)
        outcome_display = self.db_ops.clean_output_name(self.config.outcome_name)

        exposure_nodes = {exposure_display} if exposure_display in nodes_in_graph else set()
        outcome_nodes = {outcome_display} if outcome_display in nodes_in_graph else set()
        return exposure_nodes, outcome_nodes


    def display_results_summary(self):
        """Display a comprehensive summary of general graph analysis results."""
        output_path = self.output_dir
        print(f"Description: {self.config.description}")

        print("\nGenerated files:")
        print(f"  - {self.get_cytoscape_filename()}: Self-contained Cytoscape.js JSON (nodes, edges, evidence) (degree={self.degree})")

        print("\nTo visualize results, load the Cytoscape.js JSON in the visualization app:")
        print(f"  {output_path}/{self.get_cytoscape_filename()}")


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
        """Generate Markov blanket-specific DAGitty script.

        Args:
            edges: Set of (source, target) tuples already in display-name form
                   (resolved through CUI → display name during graph construction).
            mb_nodes: Raw Markov blanket node names from the database (will be cleaned).
        """
        with TimingContext("markov_blanket_dagitty_generation", self.timing_data):
            exposure_display = self.db_ops.clean_output_name(self.config.exposure_name)
            outcome_display = self.db_ops.clean_output_name(self.config.outcome_name)

            # Clean MB node names (they come as raw names from SQL queries)
            cleaned_mb_nodes = {self.db_ops.clean_output_name(node) for node in mb_nodes}

            # Edges are already in display-name form — filter to MB subgraph
            mb_edges = {
                (u, v) for u, v in edges
                if u in cleaned_mb_nodes and v in cleaned_mb_nodes and u != v
            }

            exposure_outcome = {exposure_display, outcome_display}
            dagitty_mb_lines = ["g <- dagitty('dag {"]

            if exposure_display in cleaned_mb_nodes:
                dagitty_mb_lines.append(f" {exposure_display} [exposure]")
            if outcome_display in cleaned_mb_nodes:
                dagitty_mb_lines.append(f" {outcome_display} [outcome]")

            for node in sorted(cleaned_mb_nodes):
                if node not in exposure_outcome:
                    dagitty_mb_lines.append(f" {node}")

            for src, dst in sorted(mb_edges):
                dagitty_mb_lines.append(f" {src} -> {dst}")

            dagitty_mb_lines.append("}')")

            dagitty_mb_format = "\n".join(dagitty_mb_lines)
            with open(self.output_dir / "MarkovBlanket_Union.R", "w") as f:
                f.write(dagitty_mb_format)

    def display_markov_blanket_summary(self):
        """Display a comprehensive summary of Markov blanket analysis results."""
        output_path = self.output_dir

        print(f"Configuration: {self.config.name}")
        print(f"Description: {self.config.description}")

        print("\nGenerated files:")
        print(f"  - {self.get_cytoscape_filename()}: Self-contained Cytoscape.js JSON (nodes, edges, evidence) (degree={self.degree})")
        print(f"  - MarkovBlanket_Union.R: R script for Markov blanket analysis")

        print("\nTo visualize results, load the Cytoscape.js JSON in the visualization app:")
        print(f"  {output_path}/{self.get_cytoscape_filename()}")
        print("\nFor Markov blanket analysis, run:")
        print(f"  cd {output_path}")
        print(f"  Rscript MarkovBlanket_Union.R")

    def run_markov_blanket_analysis(self) -> Dict:
        """Execute the complete Markov blanket analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            # Connect to database
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    # Fetch relationships — returns CUI pairs (stable identifiers)
                    _, cui_links, detailed_assertions = self.db_ops.fetch_k_hop_relationships(cursor)

                    # Build CUI -> canonical name mapping
                    cui_to_name_mapping = self.db_ops.build_cui_to_name_mapping(detailed_assertions)

                    # Compute Markov blankets
                    mb_union = self.mb_computer.compute_markov_blankets(cursor)

                    print("\nConstructing causal graph...")
                    with TimingContext("graph_construction", self.timing_data):
                        G = nx.DiGraph()

                        # Build the single CUI → display-name mapping
                        cui_to_display_name = self._build_cui_to_display_name(cui_to_name_mapping)

                        # Build graph from detailed_assertions
                        for assertion in detailed_assertions:
                            src_cui = assertion.get("subject_cui", "")
                            dst_cui = assertion.get("object_cui", "")
                            src = cui_to_display_name.get(src_cui)
                            dst = cui_to_display_name.get(dst_cui)
                            if src and dst and src != dst:
                                G.add_edge(src, dst)

                        print(f"Graph constructed with {len(G.nodes())} nodes and {len(G.edges())} edges (degree={self.degree})")

                        # Identify exposure / outcome nodes
                        nodes_in_graph = set(G.nodes())
                        exposure_nodes, outcome_nodes = self._get_exposure_outcome_node_sets(nodes_in_graph)

                    print("\nGenerating graph visualization JSON and Markov blanket script...")
                    all_nodes = set(G.nodes())
                    all_edges = set(G.edges())
                    self.generate_cytoscape_json(
                        all_nodes, all_edges, exposure_nodes, outcome_nodes,
                        detailed_assertions, cui_to_display_name
                    )

                    # Generate Markov blanket-specific DAGitty script
                    self.generate_markov_blanket_dagitty_script(all_edges, mb_union)

                    print(f"  - {self.output_dir}/MarkovBlanket_Union.R")

        print("\nMarkov blanket analysis complete!")
        return self.timing_data
