#!/usr/bin/env python3
"""
Enhanced Epidemiological Analysis Script with Performance Monitoring
and Centralized Variable Configuration

This script performs causal inference analysis using Markov blankets to identify 
minimal adjustment sets from SemMedDB-derived data. It includes comprehensive timing
measurements and centralized configuration.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
import re
import unicodedata
import networkx as nx
import json
import string
import time
from typing import Dict, Set, Tuple, List
from dataclasses import dataclass
from datetime import datetime

# -------------------------
# CENTRALIZED CONFIGURATION
# -------------------------
@dataclass
class ExposureOutcomePair:
    """Configuration class for exposure-outcome relationships"""
    name: str  # Name of this exposure-outcome configuration
    exposure_cui: str  # CUI for exposure
    exposure_name: str  # Clean name for exposure
    outcome_cui: str  # CUI for outcome 
    outcome_name: str  # Clean name for outcome
    description: str  # Description of this relationship

# Define available exposure-outcome configurations
EXPOSURE_OUTCOME_CONFIGS = {
    "depression_alzheimers": ExposureOutcomePair(
        name="depression_alzheimers",
        exposure_cui="C0011570",
        exposure_name="Depression",
        outcome_cui="C0002395", 
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between depression and Alzheimer's disease"
    ),
    "hypertension_alzheimers": ExposureOutcomePair(
        name="hypertension_alzheimers",
        exposure_cui="C0020538",
        exposure_name="Hypertension",
        outcome_cui="C0002395",
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between hypertension and Alzheimer's disease"
    )
}

# Define excluded CUIs
excluded_cuis = (
    'C0001687', 'C0002526', 'C0003043', 'C0003062', 'C0005515', 'C0009566', 'C0012634',
    'C0013227', 'C0021521', 'C0021948', 'C0027361', 'C0027362', 'C0027363', 'C0028622',
    'C0029224', 'C0029235', 'C0030705', 'C0039082', 'C0039796', 'C0087111', 'C0159028',
    'C0178310', 'C0178341', 'C0178353', 'C0178355', 'C0178359', 'C0243192', 'C0422820',
    'C0424450', 'C0436606', 'C0442826', 'C0476466', 'C0478681', 'C0478682', 'C0480773',
    'C0481349', 'C0481370', 'C0557587', 'C0565657', 'C0580210', 'C0580211', 'C0589603',
    'C0596048', 'C0596090', 'C0597010', 'C0597237', 'C0597240', 'C0677042', 'C0687732',
    'C1257890', 'C1258127', 'C1318101', 'C1457887', 'C1609432', 'C0007634', 'C0020114',
    'C0237401', 'C0011900', 'C1273869', 'C0449851', 'C0277785', 'C0184661', 'C1273870',
    'C0185125', 'C0879626', 'C0004927', 'C0936012', 'C0311392', 'C0597198', 'C0018684',
    'C0042567', 'C0029921', 'C0683971', 'C0016163', 'C0024660', 'C0687133', 'C0037080',
    'C0680022', 'C1185740', 'C0871261', 'C0544461', 'C1260954', 'C0877248', 'C0242485',
    'C0205147', 'C0486805', 'C0005839', 'C0021562', 'C0205148', 'C0031843', 'C0040223',
    'C0205145', 'C0205400', 'C0086388', 'C0014406', 'C0520510', 'C0035168', 'C0029237',
    'C0277784', 'C0001779', 'C0542559', 'C0035647', 'C0025664', 'C0700287', 'C0678587',
    'C0205099', 'C0205146', 'C0237753', 'C0441800', 'C0449719', 'C0348026', 'C0008902',
    'C0586173', 'C0332479', 'C0807955', 'C0559546', 'C0031845', 'C0678594', 'C0439792',
    'C0557854', 'C1522240', 'C1527144', 'C0449234', 'C0542341', 'C0079809', 'C0205094',
    'C0037455', 'C0025118', 'C0441471', 'C0441987', 'C0439534', 'C0392360', 'C0456603',
    'C0699733', 'C0036397', 'C0725066', 'C0496675', 'C0282354', 'C0015127', 'C1273937',
    'C1368999', 'C0442804', 'C0449286', 'C0205082', 'C0814472', 'C1551338', 'C0599883',
    'C0450429', 'C1299582', 'C0336791', 'C0443177', 'C0025080', 'C1372798', 'C0028811',
    'C0205246', 'C0449445', 'C0332185', 'C0332307', 'C0443228', 'C1516635', 'C0376636',
    'C0221423', 'C0037778', 'C0199168', 'C0008949', 'C0014442', 'C0456387', 'C1265611',
    'C0243113', 'C0549177', 'C0229962', 'C0600686', 'C1254351', 'C0243095', 'C1444647',
    'C0033684', 'C0338067', 'C0441712', 'C0679607', 'C0808233', 'C1373236', 'C0243082',
    'C1306673', 'C1524062', 'C0002085', 'C0243071', 'C0238767', 'C0005508', 'C0392747',
    'C0008633', 'C0205195', 'C0205198', 'C0456205', 'C0521116', 'C0011155', 'C1527240',
    'C1527148', 'C0743223', 'C0178602', 'C1446466', 'C0013879', 'C0015295', 'C1521761',
    'C1522492', 'C0017337', 'C0017428', 'C0017431', 'C0079411', 'C0018591', 'C0019932',
    'C0021149', 'C0233077', 'C0021920', 'C0022173', 'C1517945', 'C0680220', 'C0870883',
    'C0567416', 'C0596988', 'C0243132', 'C0029016', 'C1550456', 'C0243123', 'C0030956',
    'C0851347', 'C0031328', 'C0031327', 'C0031437', 'C1514468', 'C0033268', 'C0449258',
    'C0871161', 'C1521828', 'C0443286', 'C1547039', 'C1514873', 'C0035668', 'C0439793',
    'C0205171', 'C0449438', 'C1547045', 'C0449913', 'C0042153', 'C0205419', 'C1441526',
    'C1140999', 'C0679670', 'C0431085', 'C1185625', 'C1552130', 'C1553702', 'C1547020',
    'C0242114', 'C0439165', 'C0679646', 'C0599755', 'C0681850'
)

class TimingContext:
    """Context manager for timing code execution"""
    def __init__(self, step_name: str, timing_dict: Dict):
        self.step_name = step_name
        self.timing_dict = timing_dict
        
    def __enter__(self):
        self.start_time = time.time()
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        duration = time.time() - self.start_time
        self.timing_dict[self.step_name] = {
            "duration": duration,
            "timestamp": datetime.now().isoformat()
        }

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
                 thresholds: Dict[str, int]):
        """Initialize the analyzer with configuration parameters."""
        self.config = EXPOSURE_OUTCOME_CONFIGS[config_name]
        self.db_params = db_params
        self.thresholds = thresholds
        self.timing_data = {}
        self.excluded_values = ", ".join([f"('{cui}')" for cui in excluded_cuis])

    def clean_output_name(self, name: str) -> str:
        """Normalize and clean node names for consistent output."""
        with TimingContext("name_cleaning", self.timing_data):
            name = name.strip()
            normalized = unicodedata.normalize('NFKD', name)
            ascii_name = normalized.encode('ascii', 'ignore').decode('ascii')
            punct = string.punctuation.replace("_", "")
            ascii_name = re.sub("[" + re.escape(punct) + "]", "", ascii_name)
            cleaned = re.sub(r"\s+", "_", ascii_name)
            return cleaned

    def fetch_first_degree_relationships(self, cursor) -> Tuple[Set[str], Set[Tuple[str, str]]]:
        """Retrieve direct causal relationships from the database."""
        with TimingContext("first_degree_relationships", self.timing_data):
            query = f"""
            WITH first_degree AS (
                SELECT DISTINCT
                    cp.subject_cui,
                    cp.subject_name,
                    cp.object_cui,
                    cp.object_name,
                    cp.predicate,
                    cp.pmid
                FROM causalpredication cp
                WHERE cp.predicate = 'CAUSES'
                  AND (cp.subject_cui IN (%s, %s) OR cp.object_cui IN (%s, %s))
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
            )
            SELECT 
                subject_cui, subject_name, object_cui, object_name, predicate,
                COUNT(DISTINCT pmid) AS support_count
            FROM first_degree
            GROUP BY subject_cui, subject_name, object_cui, object_name, predicate
            HAVING COUNT(DISTINCT pmid) >= %s
            ORDER BY support_count DESC;
            """
            
            cursor.execute(query, (
                self.config.exposure_cui, 
                self.config.outcome_cui, 
                self.config.exposure_cui, 
                self.config.outcome_cui,
                self.thresholds['first_degree']
            ))
            
            results = cursor.fetchall()
            first_degree_cuis = set()
            first_degree_links = set()
            
            for row in results:
                if len(row) >= 4:
                    subj_cui, subj_name, obj_cui, obj_name = row[:4]
                    first_degree_cuis.add(subj_cui)
                    first_degree_cuis.add(obj_cui)
                    first_degree_links.add((
                        self.clean_output_name(subj_name),
                        self.clean_output_name(obj_name)
                    ))
            
            return first_degree_cuis, first_degree_links

    def fetch_second_degree_relationships(self, cursor, first_degree_cuis: Set[str]) -> List[Dict]:
        """Retrieve indirect causal relationships with provenance."""
        with TimingContext("second_degree_relationships", self.timing_data):
            cui_placeholder = ','.join([f"'{cui}'" for cui in first_degree_cuis])
            
            query = f"""
            WITH second_degree AS (
                SELECT
                    cp.subject_cui,
                    cp.subject_name,
                    cp.object_cui,
                    cp.object_name,
                    cp.predicate,
                    COUNT(DISTINCT cp.pmid) AS support_count,
                    MIN(cp.sentence_id) AS sentence_id,
                    MIN(cs.sentence) AS source_sentence
                FROM causalpredication cp
                JOIN causalsentence cs ON cp.sentence_id = cs.sentence_id
                WHERE (cp.subject_cui IN ({cui_placeholder}) 
                       OR cp.object_cui IN ({cui_placeholder}))
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.subject_cui, cp.subject_name, cp.object_cui, 
                         cp.object_name, cp.predicate
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            )
            SELECT *
            FROM second_degree
            ORDER BY subject_name, object_name;
            """
            
            cursor.execute(query, (self.thresholds['second_degree'],))
            results = cursor.fetchall()
            
            detailed_assertions = []
            second_degree_links = []
            
            for row in results:
                if len(row) >= 8:
                    assertion = {
                        "subject_cui": row[0],
                        "subject_name": self.clean_output_name(row[1]),
                        "object_cui": row[2],
                        "object_name": self.clean_output_name(row[3]),
                        "predicate": row[4],
                        "support_count": row[5],
                        "sentence_id": row[6],
                        "source_sentence": row[7]
                    }
                    detailed_assertions.append(assertion)
                    second_degree_links.append((
                        self.clean_output_name(row[1]),
                        self.clean_output_name(row[3])
                    ))
            
            return detailed_assertions, second_degree_links

    def compute_markov_blankets(self, cursor) -> Set[str]:
        """Calculate the union of Markov blankets for exposure and outcome."""
        with TimingContext("markov_blanket_computation", self.timing_data):
            print("\nComputing Markov blankets...")
            
            # Outcome Markov blanket query
            print("Computing outcome Markov blanket...")
            query_outcome = f"""
            WITH outcome_parents AS (
                SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                WHERE cp.predicate = 'CAUSES'
                  AND cp.object_cui = %s
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.subject_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            ),
            outcome_children AS (
                SELECT cp.object_name AS node, cp.object_cui AS cui, 
                       COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                WHERE cp.predicate = 'CAUSES'
                  AND cp.subject_cui = %s
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.object_name, cp.object_cui
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            ),
            children_parents AS (
                SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                INNER JOIN outcome_children oc ON cp.object_cui = oc.cui
                WHERE cp.predicate = 'CAUSES'
                  AND cp.subject_name <> (
                      SELECT subject_name 
                      FROM causalpredication 
                      WHERE subject_cui = %s 
                      LIMIT 1
                  )
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.subject_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            )
            SELECT DISTINCT node FROM outcome_parents
            UNION
            SELECT DISTINCT node FROM outcome_children
            UNION
            SELECT DISTINCT node FROM children_parents;
            """
            
            cursor.execute(query_outcome, (
                self.config.outcome_cui,
                self.thresholds['markov_blanket'],
                self.config.outcome_cui,
                self.thresholds['markov_blanket'],
                self.config.outcome_cui,
                self.thresholds['markov_blanket']
            ))
            mb_outcome_nodes = {row[0] for row in cursor.fetchall()}
            
            # Exposure Markov blanket query (similar structure)
            # [Implementation for exposure Markov blanket]
            
            # Take union and add exposure/outcome nodes
            print(f"Found {len(mb_outcome_nodes)} nodes in outcome Markov blanket")

            # Exposure Markov blanket query
            print("Computing exposure Markov blanket...")
            query_exposure = f"""
            WITH exposure_parents AS (
                SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                WHERE cp.predicate = 'CAUSES'
                  AND cp.object_cui = %s
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.subject_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            ),
            exposure_children AS (
                SELECT cp.object_name AS node, cp.object_cui AS cui, 
                       COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                WHERE cp.predicate = 'CAUSES'
                  AND cp.subject_cui = %s
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.object_name, cp.object_cui
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            ),
            children_parents AS (
                SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
                FROM causalpredication cp
                INNER JOIN exposure_children ec ON cp.object_cui = ec.cui
                WHERE cp.predicate = 'CAUSES'
                  AND cp.subject_name <> (
                      SELECT object_name 
                      FROM causalpredication 
                      WHERE object_cui = %s 
                      LIMIT 1
                  )
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND NOT EXISTS (
                      SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                      WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
                  )
                GROUP BY cp.subject_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            )
            SELECT DISTINCT node FROM exposure_parents
            UNION
            SELECT DISTINCT node FROM exposure_children
            UNION
            SELECT DISTINCT node FROM children_parents;
            """
            
            cursor.execute(query_exposure, (
                self.config.exposure_cui,
                self.thresholds['markov_blanket'],
                self.config.exposure_cui,
                self.thresholds['markov_blanket'],
                self.config.exposure_cui,
                self.thresholds['markov_blanket']
            ))
            mb_exposure_nodes = {row[0] for row in cursor.fetchall()}
            print(f"Found {len(mb_exposure_nodes)} nodes in exposure Markov blanket")

            # Take union and add exposure/outcome nodes
            mb_union = mb_outcome_nodes.union(mb_exposure_nodes).union({
                self.clean_output_name(self.config.exposure_name),
                self.clean_output_name(self.config.outcome_name)
            })
            print(f"Total of {len(mb_union)} nodes in combined Markov blanket")
            
            return mb_union

    def generate_dagitty_scripts(self, nodes: Set[str], edges: Set[Tuple[str, str]], 
                               mb_nodes: Set[str]):
        """Create R scripts for DAGitty visualization and adjustment set identification."""
        with TimingContext("dagitty_generation", self.timing_data):
            # Overall DAG script
            dagitty_lines = [
                "library(dagitty)",
                "library(SEMgraph)",
                "g <- dagitty('dag {",
                f" {self.clean_output_name(self.config.exposure_name)} [exposure]",
                f" {self.clean_output_name(self.config.outcome_name)} [outcome]"
            ]
            
            # Add nodes and edges
            for node in nodes:
                if node not in {self.clean_output_name(self.config.exposure_name),
                              self.clean_output_name(self.config.outcome_name)}:
                    dagitty_lines.append(f" {node}")
            
            for src, dst in edges:
                dagitty_lines.append(f" {src} -> {dst}")
            
            # Add visualization and adjustment set code
            dagitty_lines.extend([
                "}')",
                "",
                "gg <- dagitty2graph(g)",
                "coords <- layout_nicely(gg, dim = 2)",
                "plot(gg, layout = coords)",
                f"adjSets <- adjustmentSets(g, exposure='{self.clean_output_name(self.config.exposure_name)}', outcome='{self.clean_output_name(self.config.outcome_name)}')",
                "print(adjSets)",
                "for(i in seq_along(adjSets)) {",
                "  cat('Adjustment Set', i, ':\n')",
                "  print(adjSets[[i]])",
                "  V(gg)$color <- ifelse(V(gg)$name %in% adjSets[[i]], 'red', 'black')",
                "  plot(gg, layout=coords, vertex.color=V(gg)$color, main=paste('Adjustment Set', i))",
                "}"
            ])
            dagitty_format = "\n".join(dagitty_lines)
            
            # Save overall DAG script
            with open("SemDAG.R", "w") as f:
                f.write(dagitty_format)
            
            # Generate Markov blanket-specific script
            mb_edges = [(u, v) for u, v in edges if u in mb_nodes and v in mb_nodes]
            dagitty_mb_lines = [
                "library(dagitty)",
                "library(SEMgraph)",
                "g_mb <- dagitty('dag {",
                f" {self.clean_output_name(self.config.exposure_name)} [exposure]",
                f" {self.clean_output_name(self.config.outcome_name)} [outcome]"
            ]
            
            for node in mb_nodes:
                if node not in {self.clean_output_name(self.config.exposure_name),
                              self.clean_output_name(self.config.outcome_name)}:
                    dagitty_mb_lines.append(f" {node}")
            
            for src, dst in mb_edges:
                dagitty_mb_lines.append(f" {src} -> {dst}")
            
            dagitty_mb_lines.extend([
                "}')",
                "",
                "gg_mb <- dagitty2graph(g_mb)",
                "coords_mb <- layout_nicely(gg_mb, dim = 2)",
                "plot(gg_mb, layout = coords_mb)",
                f"adjSets_mb <- adjustmentSets(g_mb, exposure='{self.clean_output_name(self.config.exposure_name)}', outcome='{self.clean_output_name(self.config.outcome_name)}')",
                "print(adjSets_mb)",
                "for(i in seq_along(adjSets_mb)) {",
                "  cat('Union Markov Blanket Adjustment Set', i, ':\n')",
                "  print(adjSets_mb[[i]])",
                "  V(gg_mb)$color <- ifelse(V(gg_mb)$name %in% adjSets_mb[[i]], 'red', 'black')",
                "  plot(gg_mb, layout=coords_mb, vertex.color=V(gg_mb)$color, main=paste('Union MB Adj Set', i))",
                "}"
            ])
            
            dagitty_mb_format = "\n".join(dagitty_mb_lines)
            with open("MarkovBlanket_Union.R", "w") as f:
                f.write(dagitty_mb_format)

    def run_analysis(self) -> Dict:
        """Execute the complete analysis pipeline and return timing data."""
        with TimingContext("total_execution", self.timing_data):
            print(f"\nStarting analysis for {self.config.description}...")
            print(f"Using thresholds: {self.thresholds}")
            
            # Connect to database
            with psycopg2.connect(**self.db_params) as conn:
                with conn.cursor() as cursor:
                    print("\nFetching causal relationships from database...")
                    
                    # Fetch relationships
                    first_degree_cuis, first_degree_links = self.fetch_first_degree_relationships(cursor)
                    print(f"Found {len(first_degree_links)} first-degree relationships")
                    
                    detailed_assertions, second_degree_links = self.fetch_second_degree_relationships(
                        cursor, first_degree_cuis
                    )
                    print(f"Found {len(second_degree_links)} second-degree relationships")
                    
                    print("\nSaving detailed assertions to JSON...")
                    # Save detailed assertions
                    with open("causal_assertions.json", "w") as f:
                        json.dump(detailed_assertions, f, indent=2)
                    
                    # Compute Markov blankets
                    mb_union = self.compute_markov_blankets(cursor)
                    
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
                    print("DAGitty scripts generated: SemDAG.R and MarkovBlanket_Union.R")
            
        print("\nAnalysis complete!")
        return self.timing_data

# -------------------------
# USAGE EXAMPLE
# -------------------------
if __name__ == "__main__":
    # Database configuration
    DB_CONFIG = {
        "dbname": "causalehr",
        "user": "rajesh",
        "password": "Usps@6855",
        "host": "localhost",
        "port": "5432",
        "options": "-c search_path=causalehr"
    }
    
    # Analysis thresholds
    THRESHOLDS = {
        "first_degree": 50,
        "second_degree": 50,
        "markov_blanket": 50
    }
    
    # Initialize and run analysis
    analyzer = MarkovBlanketAnalyzer(
        config_name="hypertension_alzheimers",
        db_params=DB_CONFIG,
        thresholds=THRESHOLDS
    )
    
    timing_results = analyzer.run_analysis()
    
    # Save and display timing results
    with open("performance_metrics.json", "w") as f:
        json.dump(timing_results, f, indent=2)
    
    print("\nTiming Results:")
    for step, metrics in timing_results.items():
        print(f"{step}: {metrics['duration']:.2f} seconds")
    
    print("\nAll results saved to disk: performance_metrics.json")

