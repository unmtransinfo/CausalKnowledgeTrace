#!/usr/bin/env python3
"""
Markov Blanket Analysis Module

This module provides functionality for computing Markov blankets in causal graphs.
Extracted from the main pushkin.py for modularity.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
from typing import Dict, Set, List
from config import TimingContext
import re


class MarkovBlanketComputer:
    """
    Class for computing Markov blankets for exposure and outcome variables.
    """
    
    def __init__(self, config, threshold: int, timing_data: Dict):
        """Initialize the Markov blanket computer."""
        self.config = config
        self.threshold = threshold
        self.timing_data = timing_data
        self.excluded_values = "('C0030705'),('C0030705'),('C0030705')"  # Placeholder exclusions
    
    def clean_output_name(self, name: str) -> str:
        """Clean node names for output by removing all special characters and punctuation."""
        if not name:
            return ""
        
        # Convert to string if not already
        name = str(name)
        
        # Remove or replace special characters with underscores
        # Handle pipe symbols, commas, apostrophes, colons, spaces, etc.
        cleaned = re.sub(r'[|,\':;()[\]{}<>!@#$%^&*+=~`"\\/?.\s-]+', '_', name)
        
        # Remove leading/trailing underscores and collapse multiple underscores
        cleaned = re.sub(r'_+', '_', cleaned)  # Collapse multiple underscores
        cleaned = cleaned.strip('_')  # Remove leading/trailing underscores
        
        # Ensure we don't have empty strings
        if not cleaned:
            cleaned = "unknown_node"
        
        return cleaned
    
    def compute_markov_blankets(self, cursor) -> Set[str]:
        """Calculate the union of Markov blankets for exposure and outcome."""
        with TimingContext("markov_blanket_computation", self.timing_data):
            print("\nComputing Markov blankets...")
            
            # Get exposure and outcome CUIs as lists
            exposure_cuis = self.config.exposure_cui_list
            outcome_cuis = self.config.outcome_cui_list
            
            all_mb_nodes = set()
            
            # Process each outcome CUI
            for outcome_cui in outcome_cuis:
                print(f"Computing Markov blanket for outcome CUI: {outcome_cui}")
                mb_outcome_nodes = self._compute_outcome_markov_blanket(cursor, outcome_cui)
                all_mb_nodes.update(mb_outcome_nodes)
            
            # Process each exposure CUI  
            for exposure_cui in exposure_cuis:
                print(f"Computing Markov blanket for exposure CUI: {exposure_cui}")
                mb_exposure_nodes = self._compute_exposure_markov_blanket(cursor, exposure_cui, outcome_cuis)
                all_mb_nodes.update(mb_exposure_nodes)
            
            print(f"Found {len(all_mb_nodes)} nodes across all Markov blankets")

            # Add exposure/outcome node names
            mb_union = all_mb_nodes.union({
                self.clean_output_name(self.config.exposure_name),
                self.clean_output_name(self.config.outcome_name)
            })
            
            return mb_union
    
    def _compute_outcome_markov_blanket(self, cursor, outcome_cui: str) -> Set[str]:
        """Compute Markov blanket for a specific outcome CUI."""
        outcome_condition = f"cp.object_cui = %s"
        outcome_condition_subj = f"cp.subject_cui = %s"
        
        query_outcome = f"""
        WITH outcome_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND {outcome_condition}
              AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND NOT EXISTS (
                  SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                  WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
              )
            GROUP BY cp.subject_name
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        ),
        outcome_children AS (
            SELECT cp.object_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND {outcome_condition_subj}
              AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND NOT EXISTS (
                  SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                  WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
              )
            GROUP BY cp.object_name
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        ),
        children_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND cp.object_cui IN (
                  SELECT DISTINCT cp2.object_cui
                  FROM causalpredication cp2
                  WHERE cp2.predicate = 'CAUSES'
                    AND {outcome_condition_subj}
                    AND cp2.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  GROUP BY cp2.object_cui
                  HAVING COUNT(DISTINCT cp2.pmid) >= %s
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
            outcome_cui,        # outcome_condition
            self.threshold,
            outcome_cui,        # outcome_condition_subj
            self.threshold,
            outcome_cui,        # children_parents subquery
            self.threshold,
            self.threshold
        ))
        
        return {row[0] for row in cursor.fetchall()}
    
    def _compute_exposure_markov_blanket(self, cursor, exposure_cui: str, outcome_cuis: List[str]) -> Set[str]:
        """Compute Markov blanket for a specific exposure CUI."""
        exposure_condition = f"cp.object_cui = %s"
        exposure_condition_subj = f"cp.subject_cui = %s"
        
        query_exposure = f"""
        WITH exposure_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND {exposure_condition}
              AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND NOT EXISTS (
                  SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                  WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
              )
            GROUP BY cp.subject_name
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        ),
        exposure_children AS (
            SELECT cp.object_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND {exposure_condition_subj}
              AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND NOT EXISTS (
                  SELECT 1 FROM (VALUES {self.excluded_values}) AS excluded(cui)
                  WHERE cp.subject_cui = excluded.cui OR cp.object_cui = excluded.cui
              )
            GROUP BY cp.object_name
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        ),
        children_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE cp.predicate = 'CAUSES'
              AND cp.object_cui IN (
                  SELECT DISTINCT cp2.object_cui
                  FROM causalpredication cp2
                  WHERE cp2.predicate = 'CAUSES'
                    AND {exposure_condition_subj}
                    AND cp2.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                    AND cp2.object_cui NOT IN %s
                  GROUP BY cp2.object_cui
                  HAVING COUNT(DISTINCT cp2.pmid) >= %s
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
            exposure_cui,       # exposure_condition
            self.threshold,
            exposure_cui,       # exposure_condition_subj
            self.threshold,
            tuple(outcome_cuis), # children_parents exclusion
            self.threshold,
            self.threshold
        ))
        
        return {row[0] for row in cursor.fetchall()}
