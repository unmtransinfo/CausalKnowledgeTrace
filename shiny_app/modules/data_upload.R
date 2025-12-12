# Data Upload Module (Modularized)
# This module serves as a central hub that sources all data upload related sub-modules
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dagitty, igraph

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

# Source all sub-modules in correct dependency order
module_files <- c(
    "modules/file_scanning.R",
    "modules/dag_loading.R",
    "modules/network_processing.R",
    "modules/cui_formatting.R",
    "modules/node_information.R"
)

for (module_file in module_files) {
    if (file.exists(module_file)) {
        source(module_file)
    } else {
        # Try without modules/ prefix (for when sourced from modules directory)
        alt_file <- basename(module_file)
        if (file.exists(alt_file)) {
            source(alt_file)
        } else {
            warning(paste(module_file, "not found. Some functions may not work properly."))
        }
    }
}

# Note: The following functions are now defined in sub-modules:
# - file_scanning.R: scan_for_dag_files, get_default_dag_files, extract_degree_from_filename, create_fallback_dag
# - dag_loading.R: load_dag_from_file, validate_dag_object
# - network_processing.R: create_network_data, process_large_dag, validate_edge_data
# - cui_formatting.R: load_consolidated_cui_mappings, format_node_with_cuis, format_pmid_display
# - node_information.R: create_nodes_dataframe (if exists)

# The remaining functions in this file handle causal assertions and edge operations

# Source additional sub-modules for assertions, edge operations, and filtering
additional_modules <- c(
    "modules/assertions_loading.R",
    "modules/edge_operations.R",
    "modules/graph_filtering.R"
)

for (module_file in additional_modules) {
    if (file.exists(module_file)) {
        source(module_file)
    } else {
        # Try without modules/ prefix (for when sourced from modules directory)
        alt_file <- basename(module_file)
        if (file.exists(alt_file)) {
            source(alt_file)
        } else {
            warning(paste(module_file, "not found. Some functions may not work properly."))
        }
    }
}

# ============================================================================
# ALL FUNCTIONS ARE NOW DEFINED IN SUB-MODULES
# ============================================================================
# This file now serves as a central hub that sources all data upload related modules.
#
# Module breakdown:
# - file_scanning.R: scan_for_dag_files, get_default_dag_files, extract_degree_from_filename, create_fallback_dag
# - dag_loading.R: load_dag_from_file, validate_dag_object
# - network_processing.R: create_network_data, process_large_dag, validate_edge_data
# - cui_formatting.R: load_consolidated_cui_mappings, format_node_with_cuis, format_pmid_display
# - assertions_loading.R: load_causal_assertions
# - edge_operations.R: find_edge_pmid_data, find_node_related_assertions, find_edge_in_metadata, process_full_assertion
# - graph_filtering.R: remove_leaf_nodes, filter_exposure_outcome_paths
# - node_information.R: create_nodes_dataframe (if exists)
#
# All functions maintain their original signatures for backward compatibility.
#
# Note: This file previously contained 1,960 lines of code. It has been refactored
# into 7 smaller, focused modules for better maintainability.
