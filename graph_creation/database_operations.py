#!/usr/bin/env python3
"""
Database Operations for Epidemiological Analysis

This module contains the DatabaseOperations class and all database query methods
for the Markov blanket analysis script.

Author: Scott A. Malec PhD
Date: February 2025
"""

import psycopg2
import re
import unicodedata
import string
from typing import Dict, Set, Tuple, List, Union, Optional

# Import configuration models
from config_models import TimingContext


def format_sql_query_for_logging(query: str, params: Union[List, Tuple]) -> str:
    """
    Format an SQL query with parameters substituted for logging purposes.

    Args:
        query: SQL query string with %s placeholders
        params: List or tuple of parameters to substitute

    Returns:
        Formatted SQL query string with parameters substituted
    """
    if not params:
        return query

    # Convert all parameters to strings and properly quote them
    formatted_params = []
    for param in params:
        if param is None:
            formatted_params.append('NULL')
        elif isinstance(param, str):
            # Escape single quotes and wrap in quotes
            escaped_param = param.replace("'", "''")
            formatted_params.append(f"'{escaped_param}'")
        elif isinstance(param, (int, float)):
            formatted_params.append(str(param))
        elif isinstance(param, bool):
            formatted_params.append('TRUE' if param else 'FALSE')
        else:
            # For other types, convert to string and quote
            escaped_param = str(param).replace("'", "''")
            formatted_params.append(f"'{escaped_param}'")

    # Replace %s placeholders with formatted parameters
    formatted_query = query
    for param in formatted_params:
        formatted_query = formatted_query.replace('%s', param, 1)

    return formatted_query


def execute_query_with_logging(cursor, query: str, params: Union[List, Tuple] = None, operation_name: str = "SQL Query"):
    """
    Execute a database query with complete SQL logging.

    Args:
        cursor: Database cursor object
        query: SQL query string
        params: Query parameters (optional)
        operation_name: Description of the operation for logging
    """
    # Format and print the complete executable SQL query
    if params:
        formatted_query = format_sql_query_for_logging(query, params)
        print(f"\n=== {operation_name} ===")
        print("Complete executable SQL query:")
        print("-" * 80)
        print(formatted_query)
        print("-" * 80)

        # Execute the original parameterized query
        cursor.execute(query, params)
    else:
        print(f"\n=== {operation_name} ===")
        print("Complete executable SQL query:")
        print("-" * 80)
        print(query)
        print("-" * 80)

        # Execute the query without parameters
        cursor.execute(query)


class DatabaseOperations:
    """Helper class for database operations and queries."""

    def __init__(self, config, threshold: int, timing_data: Dict, predication_types: List[str] = None, k_hops: int = 3):
        self.config = config
        self.threshold = threshold
        self.timing_data = timing_data
        self.predication_types = predication_types or ['CAUSES']
        self.k_hops = k_hops
    
    def _create_cui_placeholders(self, cui_list: List[str]) -> str:
        """Create placeholder string for multiple CUIs in SQL queries"""
        return ', '.join(['%s'] * len(cui_list))
    
    def _create_cui_conditions(self, cui_list: List[str], field_name: str) -> str:
        """Create SQL condition for multiple CUIs"""
        placeholders = ', '.join(['%s'] * len(cui_list))
        return f"{field_name} IN ({placeholders})"
    
    def _create_predication_condition(self) -> str:
        """Create SQL condition for predication types"""
        if len(self.predication_types) == 1:
            return "cp.predicate = %s"
        else:
            placeholders = ', '.join(['%s'] * len(self.predication_types))
            return f"cp.predicate IN ({placeholders})"
    
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

    def create_consolidated_node_mapping(self, cursor) -> Dict[str, str]:
        """Create mapping from individual CUI names to consolidated node names."""
        consolidated_mapping = {}

        try:
            # Get all CUIs for mapping
            all_cuis = self.config.exposure_cui_list + self.config.outcome_cui_list
            cui_name_mapping = self.fetch_cui_name_mappings(cursor, all_cuis)

            # Map exposure CUI names to consolidated exposure name
            consolidated_exposure_name = self.clean_output_name(self.config.exposure_name)
            for cui in self.config.exposure_cui_list:
                if cui in cui_name_mapping:
                    cui_name = self.clean_output_name(cui_name_mapping[cui])
                    consolidated_mapping[cui_name] = consolidated_exposure_name
                else:
                    # Fallback to CUI-based name
                    cui_name = self.clean_output_name(f"Exposure_{cui}")
                    consolidated_mapping[cui_name] = consolidated_exposure_name

            # Map outcome CUI names to consolidated outcome name
            consolidated_outcome_name = self.clean_output_name(self.config.outcome_name)
            for cui in self.config.outcome_cui_list:
                if cui in cui_name_mapping:
                    cui_name = self.clean_output_name(cui_name_mapping[cui])
                    consolidated_mapping[cui_name] = consolidated_outcome_name
                else:
                    # Fallback to CUI-based name
                    cui_name = self.clean_output_name(f"Outcome_{cui}")
                    consolidated_mapping[cui_name] = consolidated_outcome_name

        except Exception as e:
            print(f"Warning: Could not create consolidated node mapping: {e}")
            # Fallback mapping using CUI-based names
            consolidated_exposure_name = self.clean_output_name(self.config.exposure_name)
            consolidated_outcome_name = self.clean_output_name(self.config.outcome_name)

            for cui in self.config.exposure_cui_list:
                cui_name = self.clean_output_name(f"Exposure_{cui}")
                consolidated_mapping[cui_name] = consolidated_exposure_name

            for cui in self.config.outcome_cui_list:
                cui_name = self.clean_output_name(f"Outcome_{cui}")
                consolidated_mapping[cui_name] = consolidated_outcome_name

        return consolidated_mapping

    def apply_consolidated_mapping(self, node_name: str, consolidated_mapping: Dict[str, str]) -> str:
        """Apply consolidated mapping to a node name if it exists in the mapping."""
        return consolidated_mapping.get(node_name, node_name)

    def fetch_cui_name_mappings(self, cursor, cui_list: List[str]) -> Dict[str, str]:
        """Fetch CUI-to-name mappings from the causalentity table."""
        if not cui_list:
            return {}

        # Create placeholders for the CUI list
        cui_placeholders = self._create_cui_placeholders(cui_list)

        query = f"""
        SELECT cui, name
        FROM causalentity
        WHERE cui IN ({cui_placeholders})
        """

        try:
            execute_query_with_logging(cursor, query, cui_list, "Fetch CUI Name Mappings")
            results = cursor.fetchall()

            # Create mapping dictionary
            cui_name_mapping = {row[0]: row[1] for row in results}

            return cui_name_mapping

        except Exception as e:
            print(f"Warning: Error fetching CUI name mappings: {e}")
            return {}

    def fetch_first_degree_relationships(self, cursor):
        """Fetch first-degree causal relationships with detailed assertions including PMIDs."""
        with TimingContext("first_degree_fetch", self.timing_data):
            # Create conditions for multiple CUIs and predication types
            exposure_condition = self._create_cui_conditions(self.config.exposure_cui_list, "cp.subject_cui")
            outcome_condition = self._create_cui_conditions(self.config.outcome_cui_list, "cp.object_cui")
            predication_condition = self._create_predication_condition()

            # Enhanced query to include CUIs, predicate, and individual PMIDs
            query_first_degree = f"""
            SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
                   cp.subject_cui, cp.object_cui, cp.predicate,
                   STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list
            FROM causalpredication cp
            WHERE {predication_condition}
              AND ({exposure_condition})
              AND ({outcome_condition})
              AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
            GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
            HAVING COUNT(DISTINCT cp.pmid) >= %s
            ORDER BY cp.subject_name ASC;
            """

            # Execute with predication types + CUIs + threshold as parameters
            params = self.predication_types + self.config.exposure_cui_list + self.config.outcome_cui_list + [self.threshold]
            execute_query_with_logging(cursor, query_first_degree, params, "Fetch First Degree Relationships")

            first_degree_results = cursor.fetchall()
            first_degree_links = [(row[0], row[1]) for row in first_degree_results]
            first_degree_cuis = set()
            detailed_assertions = []

            for row in first_degree_results:
                subject_name, object_name, evidence, subject_cui, object_cui, predicate, pmid_list = row

                # Add to CUI set for further degree processing
                first_degree_cuis.add(subject_name)
                first_degree_cuis.add(object_name)

                # Create detailed assertion with PMID information
                detailed_assertions.append({
                    "subject_name": subject_name,
                    "subject_cui": subject_cui,
                    "predicate": predicate,
                    "object_name": object_name,
                    "object_cui": object_cui,
                    "evidence_count": evidence,
                    "relationship_degree": "first",
                    "pmid_list": pmid_list.split(',') if pmid_list else []
                })

            return first_degree_cuis, first_degree_links, detailed_assertions

    def fetch_second_degree_relationships(self, cursor, first_degree_cuis):
        """Fetch second-degree causal relationships."""
        with TimingContext("second_degree_fetch", self.timing_data):
            # Convert set to list for SQL IN clause
            first_degree_list = list(first_degree_cuis)

            if not first_degree_list:
                return [], []

            # Create placeholders for the CUI list and predication condition
            cui_placeholders = self._create_cui_placeholders(first_degree_list)
            predication_condition = self._create_predication_condition()

            query_second_degree = f"""
            SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
                   cp.subject_cui, cp.object_cui, cp.predicate,
                   STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list
            FROM causalpredication cp
            WHERE {predication_condition}
              AND (cp.subject_name IN ({cui_placeholders}) OR cp.object_name IN ({cui_placeholders}))
              AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
            GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
            HAVING COUNT(DISTINCT cp.pmid) >= %s
            ORDER BY cp.subject_name ASC;
            """

            # Parameters: predication_types + first_degree_list (twice) + threshold
            params = self.predication_types + first_degree_list + first_degree_list + [self.threshold]
            execute_query_with_logging(cursor, query_second_degree, params, "Fetch Second Degree Relationships")

            second_degree_results = cursor.fetchall()

            # Create detailed assertions
            detailed_assertions = []
            second_degree_links = []

            for row in second_degree_results:
                subject_name, object_name, evidence, subject_cui, object_cui, predicate, pmid_list = row

                detailed_assertions.append({
                    "subject_name": subject_name,
                    "subject_cui": subject_cui,
                    "predicate": predicate,
                    "object_name": object_name,
                    "object_cui": object_cui,
                    "evidence_count": evidence,
                    "relationship_degree": "second",
                    "pmid_list": pmid_list.split(',') if pmid_list else []
                })

                second_degree_links.append((subject_name, object_name))

            return detailed_assertions, second_degree_links

    def fetch_third_degree_relationships(self, cursor, first_degree_cuis):
        """Fetch third-degree causal relationships with detailed assertions including PMIDs."""
        with TimingContext("third_degree_fetch", self.timing_data):
            # Convert set to list for SQL IN clause
            first_degree_list = list(first_degree_cuis)

            if not first_degree_list:
                return [], []

            # Create placeholders for the CUI list and predication condition
            cui_placeholders = self._create_cui_placeholders(first_degree_list)
            predication_condition = self._create_predication_condition()

            query_third_degree = f"""
            WITH second_degree_nodes AS (
                SELECT DISTINCT cp.subject_name AS node_name
                FROM causalpredication cp
                WHERE {predication_condition}
                  AND (cp.subject_name IN ({cui_placeholders}) OR cp.object_name IN ({cui_placeholders}))
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                GROUP BY cp.subject_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s

                UNION

                SELECT DISTINCT cp.object_name AS node_name
                FROM causalpredication cp
                WHERE {predication_condition}
                  AND (cp.subject_name IN ({cui_placeholders}) OR cp.object_name IN ({cui_placeholders}))
                  AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                  AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
                GROUP BY cp.object_name
                HAVING COUNT(DISTINCT cp.pmid) >= %s
            )
            SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
                   cp.subject_cui, cp.object_cui, cp.predicate,
                   STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list
            FROM causalpredication cp
            WHERE {predication_condition}
              AND (cp.subject_name IN (SELECT node_name FROM second_degree_nodes)
                   OR cp.object_name IN (SELECT node_name FROM second_degree_nodes))
              AND cp.subject_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
              AND cp.object_semtype NOT IN ('acty','bhvr','evnt','gora','mcha','ocac')
            GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
            HAVING COUNT(DISTINCT cp.pmid) >= %s
            ORDER BY cp.subject_name ASC;
            """

            # Parameters: predication_types (3 times) + first_degree_list (4 times) + threshold (3 times)
            params = (self.predication_types + first_degree_list + first_degree_list + [self.threshold] +
                     self.predication_types + first_degree_list + first_degree_list + [self.threshold] +
                     self.predication_types + [self.threshold])
            execute_query_with_logging(cursor, query_third_degree, params, "Fetch Third Degree Relationships")

            third_degree_results = cursor.fetchall()
            third_degree_links = [(row[0], row[1]) for row in third_degree_results]
            detailed_assertions = []

            for row in third_degree_results:
                subject_name, object_name, evidence, subject_cui, object_cui, predicate, pmid_list = row

                detailed_assertions.append({
                    "subject_name": subject_name,
                    "subject_cui": subject_cui,
                    "predicate": predicate,
                    "object_name": object_name,
                    "object_cui": object_cui,
                    "evidence_count": evidence,
                    "relationship_degree": "third",
                    "pmid_list": pmid_list.split(',') if pmid_list else []
                })

            return third_degree_links, detailed_assertions

    def fetch_k_hop_relationships(self, cursor):
        """Fetch causal relationships up to k hops based on the k_hops parameter."""
        print(f"Fetching relationships up to {self.k_hops} hops...")

        # Always fetch first-degree relationships as the starting point
        first_degree_cuis, first_degree_links, first_degree_assertions = self.fetch_first_degree_relationships(cursor)

        all_links = first_degree_links.copy()
        all_detailed_assertions = first_degree_assertions.copy()

        if self.k_hops >= 2:
            # Fetch second-degree relationships
            detailed_assertions, second_degree_links = self.fetch_second_degree_relationships(cursor, first_degree_cuis)
            all_links.extend(second_degree_links)
            all_detailed_assertions.extend(detailed_assertions)

        if self.k_hops >= 3:
            # Fetch third-degree relationships
            third_degree_links, third_degree_assertions = self.fetch_third_degree_relationships(cursor, first_degree_cuis)
            all_links.extend(third_degree_links)
            all_detailed_assertions.extend(third_degree_assertions)

        return first_degree_cuis, all_links, all_detailed_assertions
