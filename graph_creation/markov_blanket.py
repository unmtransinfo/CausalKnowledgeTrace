#!/usr/bin/env python3
"""
Markov Blanket Analysis Module

This module provides specialized functionality for computing Markov blankets in causal graphs.
It follows the single responsibility principle by focusing exclusively on Markov blanket
computation and related operations.

Key Responsibilities:
- Computing Markov blankets for exposure and outcome variables
- Handling complex SQL queries for parent, child, and spouse relationships
- Managing multiple CUI (Concept Unique Identifier) processing
- Providing clean, consolidated node names for Markov blanket analysis

This module does NOT handle:
- General graph construction or visualization
- Basic DAGitty script generation
- Database connection management
- Performance metrics or result saving

For general graph operations without Markov blanket functionality, use the
GraphAnalyzer class from analysis_core.py or graph_operations.py.

Epidemiological Context:
Markov blankets provide a principled approach to identifying confounders in causal inference.
The Markov blanket of a node contains all variables that make it conditionally independent
of all other variables, making it valuable for confounder selection in epidemiological studies.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
from typing import Dict, Set, List
from config import TimingContext
import re


class MarkovBlanketComputer:
    """
    Specialized class for computing Markov blankets for exposure and outcome variables.

    This class implements the core Markov blanket computation algorithm for causal graphs
    derived from biomedical literature. It focuses exclusively on Markov blanket operations
    and follows the single responsibility principle.

    Key Features:
    - Computes Markov blankets for multiple exposure and outcome CUIs
    - Handles complex parent-child-spouse relationships in causal graphs
    - Supports configurable predication types (e.g., 'CAUSES', 'TREATS')
    - Provides evidence-based filtering using publication thresholds
    - Excludes irrelevant semantic types (activities, behaviors, events, etc.)

    Markov Blanket Definition:
    For a target node X, the Markov blanket MB(X) consists of:
    1. Parents of X (direct causes)
    2. Children of X (direct effects)
    3. Spouses of X (other parents of X's children)

    This implementation computes the union of Markov blankets for all specified
    exposure and outcome variables, providing a comprehensive set of potential
    confounders for causal inference.

    Usage:
        computer = MarkovBlanketComputer(config, threshold=5, timing_data={})
        mb_nodes = computer.compute_markov_blankets(cursor)
    """
    
    def __init__(self, config, threshold: int, timing_data: Dict, predication_types: List[str] = None):
        """Initialize the Markov blanket computer."""
        self.config = config
        self.threshold = threshold
        self.timing_data = timing_data
        self.predication_types = predication_types or ['CAUSES']
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

    def _create_predication_condition(self) -> str:
        """Create SQL condition for predication types"""
        if len(self.predication_types) == 1:
            return "cp.predicate = %s"
        else:
            placeholders = ', '.join(['%s'] * len(self.predication_types))
            return f"cp.predicate IN ({placeholders})"

    def compute_markov_blankets(self, cursor) -> Set[str]:
        """
        Calculate the union of Markov blankets for all exposure and outcome variables.

        This is the main entry point for Markov blanket computation. It processes
        each exposure and outcome CUI separately, computes their individual Markov
        blankets, and returns the union of all nodes.

        Args:
            cursor: Database cursor for executing SQL queries

        Returns:
            Set[str]: Union of all Markov blanket nodes, including cleaned exposure
                     and outcome names

        Note:
            This method handles multiple CUIs per exposure/outcome, which is important
            for complex medical concepts that may be represented by multiple identifiers.
        """
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
        predication_condition = self._create_predication_condition()
        
        query_outcome = f"""
        WITH outcome_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE {predication_condition}
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
            WHERE {predication_condition}
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
            WHERE {predication_condition}
              AND cp.object_cui IN (
                  SELECT DISTINCT cp2.object_cui
                  FROM causalpredication cp2
                  WHERE {predication_condition}
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
        """
        
        # Parameters: predication_types (4 times) + outcome_cui (3 times) + threshold (4 times)
        params = (self.predication_types + [outcome_cui] + [self.threshold] +
                 self.predication_types + [outcome_cui] + [self.threshold] +
                 self.predication_types + self.predication_types + [outcome_cui] + [self.threshold] + [self.threshold])
        
        cursor.execute(query_outcome, params)
        
        return {row[0] for row in cursor.fetchall()}
    
    def _compute_exposure_markov_blanket(self, cursor, exposure_cui: str, outcome_cuis: List[str]) -> Set[str]:
        """Compute Markov blanket for a specific exposure CUI."""
        exposure_condition = f"cp.object_cui = %s"
        exposure_condition_subj = f"cp.subject_cui = %s"
        predication_condition = self._create_predication_condition()

        query_exposure = f"""
        WITH exposure_parents AS (
            SELECT cp.subject_name AS node, COUNT(DISTINCT cp.pmid) AS evidence
            FROM causalpredication cp
            WHERE {predication_condition}
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
            WHERE {predication_condition}
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
            WHERE {predication_condition}
              AND cp.object_cui IN (
                  SELECT DISTINCT cp2.object_cui
                  FROM causalpredication cp2
                  WHERE {predication_condition}
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
        
        # Parameters: predication_types (4 times) + exposure_cui (3 times) + threshold (4 times) + outcome_cuis (1 time)
        params = (self.predication_types + [exposure_cui] + [self.threshold] +
                 self.predication_types + [exposure_cui] + [self.threshold] +
                 self.predication_types + self.predication_types + [exposure_cui] + tuple(outcome_cuis) + [self.threshold] + [self.threshold])

        cursor.execute(query_exposure, params)
        
        return {row[0] for row in cursor.fetchall()}
