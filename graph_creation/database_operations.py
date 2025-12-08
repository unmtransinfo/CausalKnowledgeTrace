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
import os
from typing import Dict, Set, Tuple, List, Union, Optional
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

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
        elif isinstance(param, bool):
            # Check bool before int/float since bool is subclass of int in Python
            formatted_params.append('TRUE' if param else 'FALSE')
        elif isinstance(param, str):
            # Escape single quotes and wrap in quotes
            escaped_param = param.replace("'", "''")
            formatted_params.append(f"'{escaped_param}'")
        elif isinstance(param, (int, float)):
            formatted_params.append(str(param))
        elif isinstance(param, (list, tuple)):
            # Handle array/list parameters for ANY operator
            # Convert list to PostgreSQL ARRAY literal: ARRAY['val1', 'val2', ...]
            array_items = []
            for item in param:
                if item is None:
                    array_items.append('NULL')
                elif isinstance(item, str):
                    escaped_item = item.replace("'", "''")
                    array_items.append(f"'{escaped_item}'")
                elif isinstance(item, (int, float)):
                    array_items.append(str(item))
                else:
                    escaped_item = str(item).replace("'", "''")
                    array_items.append(f"'{escaped_item}'")
            formatted_params.append(f"ARRAY[{', '.join(array_items)}]")
        else:
            # For other types, convert to string and quote
            escaped_param = str(param).replace("'", "''")
            formatted_params.append(f"'{escaped_param}'")

    # Replace %s placeholders with formatted parameters
    formatted_query = query
    for param in formatted_params:
        formatted_query = formatted_query.replace('%s', param, 1)

    return formatted_query


def execute_query_with_logging(cursor, query: str, params: Union[List, Tuple] = None):
    """
    Execute a database query with SQL logging.

    Args:
        cursor: Database cursor object
        query: SQL query string
        params: Query parameters (optional)
    """
    # Format and print the complete executable SQL query
    if params:
        formatted_query = format_sql_query_for_logging(query, params)
        print("-" * 80)
        print(formatted_query)
        print("-" * 80)

        # Execute the original parameterized query
        cursor.execute(query, params)
    else:
        # Execute the query without parameters
        cursor.execute(query)


class DatabaseOperations:
    """Helper class for database operations and queries."""

    def __init__(self, config, threshold: int, timing_data: Dict, predication_types: List[str] = None, degree: int = 3, blocklist_cuis: List[str] = None, thresholds_by_degree: Dict[int, int] = None):
        self.config = config
        self.threshold = threshold
        self.timing_data = timing_data
        self.predication_types = predication_types or ['CAUSES']
        self.degree = degree
        self.blocklist_cuis = blocklist_cuis or []

        # Support degree-specific thresholds
        if thresholds_by_degree:
            self.thresholds_by_degree = thresholds_by_degree
        else:
            # Fallback to single threshold for all degrees
            self.thresholds_by_degree = {i: threshold for i in range(1, degree + 1)}

        # Load database schema and table names from environment variables
        # Each table can have its own schema for maximum flexibility
        self.sentence_schema = os.getenv('DB_SENTENCE_SCHEMA', 'public')
        self.sentence_table = os.getenv('DB_SENTENCE_TABLE', 'sentence')

        self.predication_schema = os.getenv('DB_PREDICATION_SCHEMA', 'public')
        self.predication_table = os.getenv('DB_PREDICATION_TABLE', 'predication')

        # Log blocklist information if CUIs are provided
        if self.blocklist_cuis:
            print(f"Blocklist filtering enabled: {len(self.blocklist_cuis)} CUI(s) will be excluded from graph creation")
            print(f"Blocklisted CUIs: {', '.join(self.blocklist_cuis)}")

        # Log threshold information
        if thresholds_by_degree:
            print(f"Using degree-specific thresholds: {self.thresholds_by_degree}")
        else:
            print(f"Using single threshold for all degrees: {threshold}")
    
    def _create_cui_array_condition(self, field_name: str) -> str:
        """Create SQL condition for CUI array using ANY operator (optimized)"""
        return f"{field_name} = ANY(%s)"

    def _create_cui_placeholders(self, cui_list: List[str]) -> str:
        """Create placeholder string for multiple CUIs in SQL queries (deprecated - use array syntax)"""
        return ', '.join(['%s'] * len(cui_list))

    def _create_cui_conditions(self, cui_list: List[str], field_name: str) -> str:
        """Create SQL condition for multiple CUIs (deprecated - use array syntax)"""
        placeholders = ', '.join(['%s'] * len(cui_list))
        return f"{field_name} IN ({placeholders})"

    def _create_blocklist_conditions(self) -> Tuple[str, List]:
        """Create SQL conditions to exclude blocklisted CUIs using optimized ANY operator"""
        if not self.blocklist_cuis:
            return "", []

        # Create conditions to exclude blocklisted CUIs from both subject and object using ANY operator
        blocklist_condition = f"""
              AND cp.subject_cui != ALL(%s)
              AND cp.object_cui != ALL(%s)"""

        # Return condition and parameters (blocklist_cuis twice - once for subject, once for object)
        blocklist_params = [self.blocklist_cuis, self.blocklist_cuis]
        return blocklist_condition, blocklist_params
    
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
        """Fetch CUI-to-name mappings from the sentence table."""
        if not cui_list:
            return {}

        # Optimized query using ANY operator with array against the sentence table
        query = f"""
        SELECT DISTINCT cui, name
        FROM {self.sentence_schema}.{self.sentence_table}
        WHERE cui = ANY(%s)
        """

        try:
            execute_query_with_logging(cursor, query, [cui_list])
            results = cursor.fetchall()

            # Create mapping dictionary
            cui_name_mapping = {row[0]: row[1] for row in results}

            return cui_name_mapping

        except Exception as e:
            print(f"Warning: Error fetching CUI name mappings: {e}")
            return {}

    def fetch_causal_sentences(self, cursor, pmid_list: List[str]) -> Dict[str, List[str]]:
        """Fetch causal sentences from the causalsentence table for given PMIDs."""
        if not pmid_list:
            return {}

        # Optimized query using ANY operator with array
        query = f"""
        SELECT pmid, sentence
        FROM {self.sentence_schema}.{self.sentence_table}
        WHERE pmid = ANY(%s)
        ORDER BY pmid, sentence
        """

        try:
            cursor.execute(query, [pmid_list])
            results = cursor.fetchall()

            # Create mapping dictionary: PMID -> list of unique sentences
            pmid_sentences = {}
            for row in results:
                pmid = str(row[0])  # Ensure PMID is string
                sentence = row[1]
                if pmid not in pmid_sentences:
                    pmid_sentences[pmid] = []
                pmid_sentences[pmid].append(sentence)

            # Remove duplicate sentences for each PMID to optimize storage
            for pmid in pmid_sentences:
                pmid_sentences[pmid] = list(set(pmid_sentences[pmid]))

            return pmid_sentences

        except Exception as e:
            print(f"Warning: Error fetching causal sentences: {e}")
            return {}

    def fetch_causal_sentences_by_sentence_id(self, cursor, pmid_sentence_pairs: List[str]) -> Dict[str, List[str]]:
        """Fetch causal sentences from the causalsentence table using PMID and sentence_id pairs."""
        if not pmid_sentence_pairs:
            return {}

        # Parse PMID:sentence_id pairs
        pmid_list = []
        sentence_id_list = []
        for pair in pmid_sentence_pairs:
            if ':' in pair:
                pmid, sentence_id = pair.strip().split(':', 1)
                # Keep as strings since both pmid and sentence_id are text type in database
                pmid_list.append(pmid.strip())
                sentence_id_list.append(sentence_id.strip())

        if not pmid_list:
            return {}

        # Optimized query using ANY operator with arrays
        # Both pmid and sentence_id are text type in database, so use text[] casting
        query = f"""
        SELECT pmid, sentence_id, sentence
        FROM {self.sentence_schema}.{self.sentence_table}
        WHERE pmid = ANY(CAST(%s AS text[]))
          AND sentence_id = ANY(CAST(%s AS text[]))
        ORDER BY pmid, sentence_id
        """

        try:
            # Use concise logging for sentence fetching to avoid terminal clutter
            print(f"Fetching causal sentences for {len(pmid_list)} PMID-sentence_id pairs...")
            cursor.execute(query, [pmid_list, sentence_id_list])
            results = cursor.fetchall()

            # Create mapping dictionary: PMID -> list of unique sentences
            pmid_sentences = {}
            for row in results:
                pmid = str(row[0])  # Ensure PMID is string
                sentence = row[2]
                if pmid not in pmid_sentences:
                    pmid_sentences[pmid] = []
                pmid_sentences[pmid].append(sentence)

            # Remove duplicate sentences for each PMID to optimize storage
            for pmid in pmid_sentences:
                pmid_sentences[pmid] = list(set(pmid_sentences[pmid]))

            return pmid_sentences

        except Exception as e:
            print(f"Warning: Error fetching causal sentences by sentence_id: {e}")
            return {}







    def fetch_n_hop_relationships(self, cursor, hop_level: int, previous_hop_cuis: Set[str] = None) -> Tuple[List, List]:
        """
        Fetch causal relationships for a specific hop level using dynamic SQL generation.

        Args:
            cursor: Database cursor
            hop_level: The hop level to fetch (1, 2, 3, ...)
            previous_hop_cuis: Set of CUIs from previous hop (None for hop 1)

        Returns:
            Tuple of (detailed_assertions, links)
        """
        with TimingContext(f"hop_{hop_level}_fetch", self.timing_data):
            if hop_level == 1:
                return self._fetch_first_hop(cursor)
            elif hop_level == 2:
                return self._fetch_second_hop(cursor, previous_hop_cuis)
            else:
                return self._fetch_higher_hop(cursor, hop_level, previous_hop_cuis)

    def _get_hop_name(self, hop_level: int) -> str:
        """Convert hop level to ordinal name for consistency with existing code."""
        ordinals = {1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth"}
        return ordinals.get(hop_level, f"hop_{hop_level}")

    def _fetch_first_hop(self, cursor) -> Tuple[List, List]:
        """Fetch first-hop relationships (direct exposure -> outcome)."""
        # Create blocklist conditions for filtering
        blocklist_condition, blocklist_params = self._create_blocklist_conditions()

        # Create predication condition for multiple predication types
        predication_condition = self._create_predication_condition()

        # Get degree-specific threshold
        degree_threshold = self.thresholds_by_degree.get(1, self.threshold)

        # Optimized query using ANY operator with arrays instead of IN clauses
        query = f"""
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
        cp.subject_cui, cp.object_cui, cp.predicate,
        STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
        STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM {self.predication_schema}.{self.predication_table} cp
        WHERE {predication_condition}
        AND (
            (cp.subject_cui = ANY(%s)
             OR cp.object_cui = ANY(%s))
            OR
            (cp.subject_cui = ANY(%s)
             OR cp.object_cui = ANY(%s))
        ){blocklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC;
        """

        # Build parameters: predication_types + exposure array (twice) + outcome array (twice) + threshold + blocklist params
        params = (self.predication_types +  # Use all predication types
                 [self.config.exposure_cui_list, self.config.exposure_cui_list,
                  self.config.outcome_cui_list, self.config.outcome_cui_list] +
                 [degree_threshold] + blocklist_params)

        execute_query_with_logging(cursor, query, params)

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, 1), links

    def _fetch_second_hop(self, cursor, previous_hop_cuis: Set[str]) -> Tuple[List, List]:
        """Fetch second-hop relationships using first hop CUIs directly."""
        # Convert set to list for SQL array parameter
        previous_hop_list = list(previous_hop_cuis)

        if not previous_hop_list:
            return [], []

        # Create predication condition for multiple predication types
        predication_condition = self._create_predication_condition()
        blocklist_condition, blocklist_params = self._create_blocklist_conditions()

        # Get degree-specific threshold
        degree_threshold = self.thresholds_by_degree.get(2, self.threshold)

        # Optimized query using ANY operator with arrays instead of IN clauses
        query = f"""
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
            cp.subject_cui, cp.object_cui, cp.predicate,
            STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
            STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM {self.predication_schema}.{self.predication_table} cp
        WHERE {predication_condition}
        AND (cp.subject_cui = ANY(%s)
            OR cp.object_cui = ANY(%s))
        {blocklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC
        """

        # Parameters: predication_types + previous_hop_list array (twice) + blocklist_params + threshold
        params = self.predication_types + [previous_hop_list, previous_hop_list] + blocklist_params + [degree_threshold]

        execute_query_with_logging(cursor, query, params)

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, 2), links

    def _fetch_higher_hop(self, cursor, hop_level: int, previous_hop_cuis: Set[str]) -> Tuple[List, List]:
        """Fetch relationships for hop level 3 and above using direct ANY operator (no CTE needed)."""
        # Convert set to list for SQL array parameter
        previous_hop_list = list(previous_hop_cuis)

        if not previous_hop_list:
            return [], []

        # Create predication condition for multiple predication types
        predication_condition = self._create_predication_condition()
        blocklist_condition, blocklist_params = self._create_blocklist_conditions()

        # Get degree-specific threshold
        degree_threshold = self.thresholds_by_degree.get(hop_level, self.threshold)

        # Simplified query using ANY operator directly - no CTE needed
        # This finds relationships where either subject or object is in the previous hop nodes
        query = f"""
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
               cp.subject_cui, cp.object_cui, cp.predicate,
               STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
               STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM {self.predication_schema}.{self.predication_table} cp
        WHERE {predication_condition}
          AND (cp.subject_cui = ANY(%s) OR cp.object_cui = ANY(%s)){blocklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC;
        """

        # Parameters: predication_types + previous_hop_list array (twice) + blocklist_params + threshold
        params = self.predication_types + [previous_hop_list, previous_hop_list] + blocklist_params + [degree_threshold]

        execute_query_with_logging(cursor, query, params)

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, hop_level), links

    def build_cui_to_name_mapping(self, detailed_assertions: List[Dict]) -> Dict[str, str]:
        """
        Build a mapping from CUI to canonical name based on detailed assertions.
        Uses the most frequently occurring name for each CUI as the canonical name.

        Args:
            detailed_assertions: List of assertion dictionaries with subject_cui, object_cui, subject_name, object_name

        Returns:
            Dictionary mapping CUI to canonical name
        """
        cui_name_counts = {}

        # Count occurrences of each name for each CUI
        for assertion in detailed_assertions:
            subject_cui = assertion.get('subject_cui')
            object_cui = assertion.get('object_cui')
            subject_name = assertion.get('subject_name')
            object_name = assertion.get('object_name')

            if subject_cui and subject_name:
                if subject_cui not in cui_name_counts:
                    cui_name_counts[subject_cui] = {}
                cui_name_counts[subject_cui][subject_name] = cui_name_counts[subject_cui].get(subject_name, 0) + 1

            if object_cui and object_name:
                if object_cui not in cui_name_counts:
                    cui_name_counts[object_cui] = {}
                cui_name_counts[object_cui][object_name] = cui_name_counts[object_cui].get(object_name, 0) + 1

        # Select the most frequent name for each CUI as canonical
        cui_to_canonical_name = {}
        for cui, name_counts in cui_name_counts.items():
            # Get the name with highest count (most frequent)
            canonical_name = max(name_counts.items(), key=lambda x: x[1])[0]
            cui_to_canonical_name[cui] = canonical_name

        return cui_to_canonical_name

    def fetch_k_hop_relationships(self, cursor):
        """Fetch causal relationships up to k hops using dynamic loop-based approach."""
        all_links = []
        all_detailed_assertions = []
        current_hop_cuis = set()

        # Iterate through each hop level dynamically
        for hop_level in range(1, self.degree + 1):
            # For hop 1, we don't need previous CUIs; for others, we use the first hop CUIs
            previous_cuis = None if hop_level == 1 else current_hop_cuis

            # Fetch relationships for this hop level
            detailed_assertions, links = self.fetch_n_hop_relationships(cursor, hop_level, previous_cuis)

            # Add results to overall collections
            all_links.extend(links)
            all_detailed_assertions.extend(detailed_assertions)

            # For hop 1, collect the CUIs for use in subsequent hops
            if hop_level == 1:
                for assertion in detailed_assertions:
                    current_hop_cuis.add(assertion['subject_cui'])
                    current_hop_cuis.add(assertion['object_cui'])

        # Build CUI-to-canonical-name mapping from all assertions
        cui_to_name_mapping = self.build_cui_to_name_mapping(all_detailed_assertions)

        # Create CUI-based links with canonical names
        cui_based_links = []
        for assertion in all_detailed_assertions:
            subject_cui = assertion.get('subject_cui')
            object_cui = assertion.get('object_cui')

            if subject_cui and object_cui and subject_cui in cui_to_name_mapping and object_cui in cui_to_name_mapping:
                canonical_subject_name = cui_to_name_mapping[subject_cui]
                canonical_object_name = cui_to_name_mapping[object_cui]
                cui_based_links.append((canonical_subject_name, canonical_object_name))

        return current_hop_cuis, cui_based_links, all_detailed_assertions

    def _process_hop_results(self, cursor, results: List, hop_level: int) -> List:
        """
        Process database results into detailed assertions with PMID data.

        Args:
            results: Raw database query results
            hop_level: The hop level for labeling (1, 2, 3, ...)

        Returns:
            List of detailed assertion dictionaries
        """
        detailed_assertions = []

        # Collect all PMID-sentence_id pairs for sentence fetching
        all_pmid_sentence_pairs = []
        for row in results:
            _, _, _, _, _, _, pmid_list, pmid_sentence_id_list = row
            if pmid_sentence_id_list:
                all_pmid_sentence_pairs.extend(pmid_sentence_id_list.split(','))

        # Fetch sentences for all PMID-sentence_id pairs
        pmid_sentences = self.fetch_causal_sentences_by_sentence_id(cursor, all_pmid_sentence_pairs) if all_pmid_sentence_pairs else {}

        for row in results:
            subject_name, object_name, evidence, subject_cui, object_cui, predicate, pmid_list, pmid_sentence_id_list = row

            # Process PMID list and add sentence data
            pmids = pmid_list.split(',') if pmid_list else []
            pmid_data = {}

            # Use the updated pmid_sentences structure (PMID -> list of sentences)
            for pmid in pmids:
                pmid = pmid.strip()
                if pmid in pmid_sentences:
                    pmid_data[pmid] = {
                        "sentences": pmid_sentences[pmid]
                    }
                else:
                    pmid_data[pmid] = {
                        "sentences": []
                    }

            # Create detailed assertion with hop level name
            hop_name = self._get_hop_name(hop_level)
            detailed_assertions.append({
                "subject_name": subject_name,
                "subject_cui": subject_cui,
                "predicate": predicate,
                "object_name": object_name,
                "object_cui": object_cui,
                "evidence_count": evidence,
                "relationship_degree": hop_name,
                "pmid_data": pmid_data
            })

        return detailed_assertions
