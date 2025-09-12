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

    def __init__(self, config, threshold: int, timing_data: Dict, predication_types: List[str] = None, k_hops: int = 3, blacklist_cuis: List[str] = None):
        self.config = config
        self.threshold = threshold
        self.timing_data = timing_data
        self.predication_types = predication_types or ['CAUSES']
        self.k_hops = k_hops
        self.blacklist_cuis = blacklist_cuis or []

        # Log blacklist information if CUIs are provided
        if self.blacklist_cuis:
            print(f"Blacklist filtering enabled: {len(self.blacklist_cuis)} CUI(s) will be excluded from graph creation")
            print(f"Blacklisted CUIs: {', '.join(self.blacklist_cuis)}")
    
    def _create_cui_placeholders(self, cui_list: List[str]) -> str:
        """Create placeholder string for multiple CUIs in SQL queries"""
        return ', '.join(['%s'] * len(cui_list))
    
    def _create_cui_conditions(self, cui_list: List[str], field_name: str) -> str:
        """Create SQL condition for multiple CUIs"""
        placeholders = ', '.join(['%s'] * len(cui_list))
        return f"{field_name} IN ({placeholders})"

    def _create_blacklist_conditions(self) -> Tuple[str, List[str]]:
        """Create SQL conditions to exclude blacklisted CUIs"""
        if not self.blacklist_cuis:
            return "", []

        # Create conditions to exclude blacklisted CUIs from both subject and object
        subject_placeholders = ', '.join(['%s'] * len(self.blacklist_cuis))
        object_placeholders = ', '.join(['%s'] * len(self.blacklist_cuis))

        blacklist_condition = f"""
              AND cp.subject_cui NOT IN ({subject_placeholders})
              AND cp.object_cui NOT IN ({object_placeholders})"""

        # Return condition and parameters (blacklist_cuis twice - once for subject, once for object)
        blacklist_params = self.blacklist_cuis + self.blacklist_cuis
        return blacklist_condition, blacklist_params
    
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

    def fetch_causal_sentences(self, cursor, pmid_list: List[str]) -> Dict[str, List[str]]:
        """Fetch causal sentences from the causalsentence table for given PMIDs."""
        if not pmid_list:
            return {}

        # Create placeholders for the PMID list
        pmid_placeholders = self._create_cui_placeholders(pmid_list)

        query = f"""
        SELECT pmid, sentence
        FROM causalsentence
        WHERE pmid IN ({pmid_placeholders})
        ORDER BY pmid, sentence
        """

        try:
            # Use concise logging for sentence fetching to avoid terminal clutter
            print(f"Fetching causal sentences for {len(pmid_list)} PMIDs...")
            cursor.execute(query, pmid_list)
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
                pmid_list.append(pmid)
                sentence_id_list.append(sentence_id)

        if not pmid_list:
            return {}

        # Create placeholders for the lists
        pmid_placeholders = self._create_cui_placeholders(pmid_list)
        sentence_id_placeholders = self._create_cui_placeholders(sentence_id_list)

        query = f"""
        SELECT pmid, sentence_id, sentence
        FROM causalsentence
        WHERE pmid IN ({pmid_placeholders})
          AND sentence_id IN ({sentence_id_placeholders})
        ORDER BY pmid, sentence_id
        """

        try:
            # Use concise logging for sentence fetching to avoid terminal clutter
            print(f"Fetching causal sentences for {len(pmid_list)} PMID-sentence_id pairs...")
            cursor.execute(query, pmid_list + sentence_id_list)
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
        # Create blacklist conditions for filtering
        blacklist_condition, blacklist_params = self._create_blacklist_conditions()

        # Create placeholders for exposure and outcome CUIs from YAML config
        exposure_placeholders = ', '.join(['%s'] * len(self.config.exposure_cui_list))
        outcome_placeholders = ', '.join(['%s'] * len(self.config.outcome_cui_list))

        # Query structure exactly matching the user's requested format with placeholders from input_user.yaml
        query = f"""
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
        cp.subject_cui, cp.object_cui, cp.predicate,
        STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
        STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM causalpredication cp
        WHERE cp.predicate = %s
        AND (
            (cp.subject_cui IN ({exposure_placeholders})
             OR cp.object_cui IN ({exposure_placeholders}))
            OR
            (cp.subject_cui IN ({outcome_placeholders})
             OR cp.object_cui IN ({outcome_placeholders}))
        ){blacklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC;
        """

        # Build parameters: predicate + exposure CUIs (twice) + outcome CUIs (twice) + min_pmids threshold + blacklist params
        params = ([self.predication_types[0]] +  # Use first predication type (typically 'CAUSES')
                 self.config.exposure_cui_list + self.config.exposure_cui_list +
                 self.config.outcome_cui_list + self.config.outcome_cui_list +
                 [self.threshold] + blacklist_params)

        execute_query_with_logging(cursor, query, params, f"Fetch Hop 1 Relationships")

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, 1), links

    def _fetch_second_hop(self, cursor, previous_hop_cuis: Set[str]) -> Tuple[List, List]:
        """Fetch second-hop relationships using first hop CUIs directly."""
        # Convert set to list for SQL IN clause
        previous_hop_list = list(previous_hop_cuis)

        if not previous_hop_list:
            return [], []

        # Create placeholders for the CUI list and predication condition
        cui_placeholders = self._create_cui_placeholders(previous_hop_list)
        predication_condition = self._create_predication_condition()
        blacklist_condition, blacklist_params = self._create_blacklist_conditions()

        # Find extended network using first hop CUIs directly
        query = f"""
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
            cp.subject_cui, cp.object_cui, cp.predicate,
            STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
            STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM causalpredication cp
        WHERE {predication_condition}
        AND (cp.subject_cui IN ({cui_placeholders}) 
            OR cp.object_cui IN ({cui_placeholders}))
        {blacklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC
        """

        # Parameters: predication_types + previous_hop_list (twice) + blacklist_params + threshold
        params = self.predication_types + previous_hop_list + previous_hop_list + blacklist_params + [self.threshold]

        execute_query_with_logging(cursor, query, params, f"Fetch Hop 2 Relationships")

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, 2), links

    def _fetch_higher_hop(self, cursor, hop_level: int, previous_hop_cuis: Set[str]) -> Tuple[List, List]:
        """Fetch relationships for hop level 3 and above using CTE pattern."""
        # Convert set to list for SQL IN clause
        previous_hop_list = list(previous_hop_cuis)

        if not previous_hop_list:
            return [], []

        # Create placeholders for the CUI list and predication condition
        cui_placeholders = self._create_cui_placeholders(previous_hop_list)
        predication_condition = self._create_predication_condition()
        blacklist_condition, blacklist_params = self._create_blacklist_conditions()

        # Use CTE pattern for higher hops - fixed to use CUIs consistently
        query = f"""
        WITH previous_hop_nodes AS (
            SELECT DISTINCT cp.subject_cui AS node_cui
            FROM causalpredication cp
            WHERE {predication_condition}
              AND (cp.subject_cui IN ({cui_placeholders}) OR cp.object_cui IN ({cui_placeholders})){blacklist_condition}
            GROUP BY cp.subject_cui
            HAVING COUNT(DISTINCT cp.pmid) >= %s

            UNION

            SELECT DISTINCT cp.object_cui AS node_cui
            FROM causalpredication cp
            WHERE {predication_condition}
              AND (cp.subject_cui IN ({cui_placeholders}) OR cp.object_cui IN ({cui_placeholders})){blacklist_condition}
            GROUP BY cp.object_cui
            HAVING COUNT(DISTINCT cp.pmid) >= %s
        )
        SELECT cp.subject_name, cp.object_name, COUNT(DISTINCT cp.pmid) AS evidence,
               cp.subject_cui, cp.object_cui, cp.predicate,
               STRING_AGG(DISTINCT cp.pmid::text, ',' ORDER BY cp.pmid::text) AS pmid_list,
               STRING_AGG(DISTINCT CONCAT(cp.pmid::text, ':', cp.sentence_id::text), ',') AS pmid_sentence_id_list
        FROM causalpredication cp
        WHERE {predication_condition}
          AND (cp.subject_cui IN (SELECT node_cui FROM previous_hop_nodes)
               OR cp.object_cui IN (SELECT node_cui FROM previous_hop_nodes)){blacklist_condition}
        GROUP BY cp.subject_name, cp.object_name, cp.subject_cui, cp.object_cui, cp.predicate
        HAVING COUNT(DISTINCT cp.pmid) >= %s
        ORDER BY cp.subject_name ASC;
        """

        # Parameters: predication_types (3 times) + previous_hop_list (4 times) + blacklist_params (3 times) + threshold (3 times)
        params = (self.predication_types + previous_hop_list + previous_hop_list + blacklist_params + [self.threshold] +
                 self.predication_types + previous_hop_list + previous_hop_list + blacklist_params + [self.threshold] +
                 self.predication_types + blacklist_params + [self.threshold])
        
        execute_query_with_logging(cursor, query, params, f"Fetch Hop {hop_level} Relationships")

        results = cursor.fetchall()
        links = [(row[0], row[1]) for row in results]

        return self._process_hop_results(cursor, results, hop_level), links

    def fetch_k_hop_relationships(self, cursor):
        """Fetch causal relationships up to k hops using dynamic loop-based approach."""
        print(f"Fetching relationships up to {self.k_hops} hops using dynamic approach...")

        all_links = []
        all_detailed_assertions = []
        current_hop_cuis = set()

        # Iterate through each hop level dynamically
        for hop_level in range(1, self.k_hops + 1):
            print(f"Processing hop {hop_level}...")

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
                print(f"Collected {len(current_hop_cuis)} unique CUIs from hop 1 for subsequent hops")

        print(f"Found {len(all_links)} total relationships across {self.k_hops} hops")
        return current_hop_cuis, all_links, all_detailed_assertions

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
