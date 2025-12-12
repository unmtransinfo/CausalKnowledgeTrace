# CUI Formatting Module
# This module contains functions for formatting node names with CUI information
# Author: Refactored from data_upload.R
# Dependencies: yaml

#' Load and Cache Consolidated CUI Mappings
#'
#' Loads the user_input.yaml configuration and creates mappings for consolidated nodes
#'
#' @param config_file Path to the configuration file (default: "../user_input.yaml")
#' @return List containing consolidated node mappings
#' @export
load_consolidated_cui_mappings <- function(config_file = "../user_input.yaml") {
    tryCatch({
        if (!file.exists(config_file)) {
            return(list(
                success = FALSE,
                message = paste("Configuration file not found:", config_file),
                mappings = list()
            ))
        }

        # Load YAML configuration
        config <- yaml::read_yaml(config_file)

        # Create consolidated mappings
        mappings <- list()

        # Map exposure name to its CUIs
        if (!is.null(config$exposure_name) && !is.null(config$exposure_cuis)) {
            exposure_name <- gsub("_", " ", config$exposure_name)  # Convert underscores to spaces
            mappings[[exposure_name]] <- config$exposure_cuis
        }

        # Map outcome name to its CUIs
        if (!is.null(config$outcome_name) && !is.null(config$outcome_cuis)) {
            outcome_name <- gsub("_", " ", config$outcome_name)  # Convert underscores to spaces
            mappings[[outcome_name]] <- config$outcome_cuis
        }

        return(list(
            success = TRUE,
            message = paste("Loaded consolidated mappings for", length(mappings), "nodes"),
            mappings = mappings
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading consolidated CUI mappings:", e$message),
            mappings = list()
        ))
    })
}

#' Format Node Name with CUI Information
#'
#' Formats a node name with its associated CUI(s), handling both single and multiple CUIs
#'
#' @param node_name The display name of the node
#' @param single_cui Single CUI from causal assertions (if available)
#' @param consolidated_mappings List of consolidated node mappings from configuration
#' @return Formatted string with node name and CUI(s) in brackets
#' @export
format_node_with_cuis <- function(node_name, single_cui = NULL, consolidated_mappings = list()) {
    # First check if this node has consolidated CUI mappings
    if (length(consolidated_mappings) > 0 && node_name %in% names(consolidated_mappings)) {
        multiple_cuis <- consolidated_mappings[[node_name]]
        if (length(multiple_cuis) > 0) {
            cui_string <- paste(multiple_cuis, collapse = ", ")
            return(paste0(node_name, " [", cui_string, "]"))
        }
    }

    # Fallback to single CUI if available
    if (!is.null(single_cui) && single_cui != "") {
        return(paste0(node_name, " [", single_cui, "]"))
    }

    # Return plain node name if no CUI information available
    return(node_name)
}

#' Format PMID Display
#'
#' Formats a list of PMIDs for display with optional links
#'
#' @param pmid_list Vector of PMID strings
#' @param max_display Maximum number of PMIDs to display directly (default: 10)
#' @param create_links Whether to create clickable PubMed links (default: TRUE)
#' @return Formatted HTML string for display
#' @export
format_pmid_display <- function(pmid_list, max_display = 10, create_links = TRUE) {
    if (length(pmid_list) == 0) {
        return("No PMIDs available")
    }

    # Sort PMIDs for consistent display
    pmid_list <- sort(unique(pmid_list))
    total_pmids <- length(pmid_list)

    if (total_pmids <= max_display) {
        # Display all PMIDs
        if (create_links) {
            pmid_links <- sapply(pmid_list, function(pmid) {
                paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank'>", pmid, "</a>")
            })
            return(paste(pmid_links, collapse = ", "))
        } else {
            return(paste(pmid_list, collapse = ", "))
        }
    } else {
        # Display first few PMIDs and indicate there are more
        display_pmids <- pmid_list[1:max_display]
        if (create_links) {
            pmid_links <- sapply(display_pmids, function(pmid) {
                paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank'>", pmid, "</a>")
            })
            return(paste0(
                paste(pmid_links, collapse = ", "),
                " ... and ", total_pmids - max_display, " more"
            ))
        } else {
            return(paste0(
                paste(display_pmids, collapse = ", "),
                " ... and ", total_pmids - max_display, " more"
            ))
        }
    }
}

