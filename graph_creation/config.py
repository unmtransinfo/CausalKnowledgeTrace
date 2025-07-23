#!/usr/bin/env python3
"""
Configuration, Data Structures, and Database Operations for Epidemiological Analysis

This module contains configuration classes, constants, database operations,
and core analysis methods for the Markov blanket analysis script.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
import re
import unicodedata
import string
import time
import json
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, Set, Tuple, List
from pathlib import Path

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
    ),
    "diabetes_alzheimers": ExposureOutcomePair(
        name="diabetes_alzheimers",
        exposure_cui="C0011849",
        exposure_name="Diabetes_Mellitus",
        outcome_cui="C0002395",
        outcome_name="Alzheimers_Disease",
        description="Investigating the relationship between diabetes mellitus and Alzheimer's disease"
    ),
    "smoking_cancer": ExposureOutcomePair(
        name="smoking_cancer",
        exposure_cui="C0037369",
        exposure_name="Smoking",
        outcome_cui="C0006826",
        outcome_name="Cancer",
        description="Investigating the relationship between smoking and cancer"
    )
}

# Define excluded CUIs
EXCLUDED_CUIS = (
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

class DatabaseOperations:
    """Class containing all database operations and queries"""
    
    def __init__(self, config, thresholds, timing_data):
        self.config = config
        self.thresholds = thresholds
        self.timing_data = timing_data
        self.excluded_values = ", ".join([f"('{cui}')" for cui in EXCLUDED_CUIS])
    
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

    def fetch_second_degree_relationships(self, cursor, first_degree_cuis: Set[str]) -> Tuple[List[Dict], List[Tuple[str, str]]]:
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

def create_db_config(host: str, port: int, dbname: str, user: str, password: str, schema: str = None) -> Dict[str, str]:
    """Create database configuration dictionary."""
    config = {
        "host": host,
        "port": str(port),
        "dbname": dbname,
        "user": user,
        "password": password
    }
    if schema:
        config["options"] = f"-c search_path={schema}"
    return config

def validate_arguments(args):
    """Validate command line arguments."""
    # Validate thresholds
    if args.first_degree_threshold < 1:
        raise ValueError("First degree threshold must be >= 1")
    if args.second_degree_threshold < 1:
        raise ValueError("Second degree threshold must be >= 1")
    if args.markov_blanket_threshold < 1:
        raise ValueError("Markov blanket threshold must be >= 1")
    
    # Validate output directory
    try:
        output_path = Path(args.output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
    except Exception as e:
        raise ValueError(f"Cannot create output directory '{args.output_dir}': {e}")