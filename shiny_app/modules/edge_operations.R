# Edge Operations Module
# This module handles edge-related operations including PMID data lookup and edge matching
# Author: Refactored from data_upload.R
# Dependencies: None (uses base R)

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Helper Function: Normalize Names for Matching
#'
#' Normalizes node names for consistent matching
#'
#' @param name Name to normalize
#' @return Normalized name string
normalize_name <- function(name) {
    if (is.null(name) || name == "") return("")
    # Convert to lowercase, replace special chars with underscores, collapse multiple underscores
    normalized <- tolower(name)
    normalized <- gsub("[^a-z0-9]+", "_", normalized)
    normalized <- gsub("_+", "_", normalized)
    normalized <- gsub("^_|_$", "", normalized)
    return(normalized)
}

#' Helper Function: Handle Medical Term Variations
#'
#' Checks if two medical terms are variations of each other
#'
#' @param dag_name Name from DAG
#' @param json_name Name from JSON
#' @return TRUE if names match, FALSE otherwise
handle_medical_variations <- function(dag_name, json_name) {
    # Common medical term mappings - add specific mappings as needed
    medical_mappings <- list(
        # Example: c("term1", "term1_variation"),
        # Example: c("term2", "term2_variation")
    )

    dag_norm <- normalize_name(dag_name)
    json_norm <- normalize_name(json_name)

    # Check direct normalized match first
    if (dag_norm == json_norm) return(TRUE)

    # Check medical term variations
    for (mapping in medical_mappings) {
        if ((dag_norm == mapping[1] && json_norm == mapping[2]) ||
            (dag_norm == mapping[2] && json_norm == mapping[1])) {
            return(TRUE)
        }
    }

    return(FALSE)
}

#' Find Edge in Metadata
#'
#' Searches for an edge in metadata structure
#'
#' @param from_node Source node name
#' @param to_node Target node name
#' @param metadata_data Metadata structure
#' @return List with match information
find_edge_in_metadata <- function(from_node, to_node, metadata_data) {
    # Helper function to normalize names for matching
    normalize_name <- function(name) {
        if (is.null(name) || name == "") return("")
        normalized <- tolower(name)
        normalized <- gsub("[^a-z0-9]+", "_", normalized)
        normalized <- gsub("_+", "_", normalized)
        normalized <- gsub("^_|_$", "", normalized)
        return(normalized)
    }

    from_normalized <- normalize_name(from_node)
    to_normalized <- normalize_name(to_node)

    # Search through metadata
    for (item in metadata_data) {
        if (!is.null(item$subject_name) && !is.null(item$object_name)) {
            subject_normalized <- normalize_name(item$subject_name)
            object_normalized <- normalize_name(item$object_name)

            # Try exact match first
            if (item$subject_name == from_node && item$object_name == to_node) {
                return(list(
                    found = TRUE,
                    subject_name = item$subject_name,
                    object_name = item$object_name,
                    match_type = "exact"
                ))
            }

            # Try normalized match
            if (subject_normalized == from_normalized && object_normalized == to_normalized) {
                return(list(
                    found = TRUE,
                    subject_name = item$subject_name,
                    object_name = item$object_name,
                    match_type = "normalized"
                ))
            }
        }
    }

    return(list(found = FALSE))
}

#' Process Full Assertion
#'
#' Processes a full assertion and extracts PMID information
#'
#' @param assertion Full assertion data
#' @param match_type Type of match that was found
#' @return List with formatted PMID information
process_full_assertion <- function(assertion, match_type) {
    # Extract PMID list from pmid_data keys (optimized structure)
    pmid_list <- if (!is.null(assertion$pmid_data)) {
        names(assertion$pmid_data)
    } else if (!is.null(assertion$pmid_list)) {
        assertion$pmid_list  # Backward compatibility
    } else {
        character(0)
    }

    # Extract sentence data
    sentence_data <- list()
    if (!is.null(assertion$pmid_data)) {
        for (pmid in names(assertion$pmid_data)) {
            pmid_info <- assertion$pmid_data[[pmid]]
            if (!is.null(pmid_info$sentences)) {
                sentence_data[[pmid]] <- pmid_info$sentences
            }
        }
    }

    return(list(
        found = TRUE,
        message = paste("Found", length(pmid_list), "PMIDs for edge (", match_type, "match)"),
        pmid_list = pmid_list,
        sentence_data = sentence_data,
        evidence_count = assertion$evidence_count %||% length(pmid_list),
        predicate = assertion$predicate %||% "CAUSES",
        subject_cui = assertion$subject_cui %||% "",
        object_cui = assertion$object_cui %||% "",
        match_type = match_type
    ))
}

#' Find PMID Data for Edge
#'
#' Finds PMID evidence for a specific causal relationship edge
#' Supports both full data and lazy loading modes
#'
#' @param from_node Name of the source node (transformed/cleaned name)
#' @param to_node Name of the target node (transformed/cleaned name)
#' @param assertions_data List of causal assertions loaded from JSON or lazy loader
#' @param lazy_loader Optional lazy loader function for on-demand data loading
#' @param edges_df Optional edges dataframe with CUI information for better matching
#' @return List containing PMID information for the edge
#' @export
find_edge_pmid_data <- function(from_node, to_node, assertions_data, lazy_loader = NULL, edges_df = NULL) {
    if (is.null(assertions_data) || length(assertions_data) == 0) {
        return(list(
            found = FALSE,
            message = "No assertions data available",
            pmid_list = character(0),
            evidence_count = 0
        ))
    }

    # Extract CUIs from edges_df if available
    from_cuis <- NULL
    to_cuis <- NULL
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        # Find the edge in edges_df
        edge_match <- edges_df[edges_df$from == from_node & edges_df$to == to_node, ]
        if (nrow(edge_match) > 0) {
            # Extract CUIs from the first matching edge
            from_cuis <- edge_match$from_cui[1]
            to_cuis <- edge_match$to_cui[1]

            # Split multiple CUIs if they exist (e.g., "C001|C002")
            if (!is.null(from_cuis) && !is.na(from_cuis)) {
                from_cuis <- strsplit(as.character(from_cuis), "\\|")[[1]]
            }
            if (!is.null(to_cuis) && !is.na(to_cuis)) {
                to_cuis <- strsplit(as.character(to_cuis), "\\|")[[1]]
            }
        }
    }

    # Check if we have indexed access (Phase 3 optimization)
    if (exists("current_data") && !is.null(current_data$edge_index)) {
        if (exists("fast_edge_lookup")) {
            indexed_result <- fast_edge_lookup(from_node, to_node, current_data$edge_index$edge_index, assertions_data)
            if (indexed_result$found) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Using indexed lookup for edge\n")
                }
                return(indexed_result)
            }
        }
    }

    # NEW: Check if we're using lazy loading with compact assertions
    use_lazy_loading <- !is.null(lazy_loader)
    if (use_lazy_loading) {
        # Check if assertions_data contains compact format (has 'subj' and 'obj' fields)
        is_compact_format <- FALSE
        if (length(assertions_data) > 0) {
            first_assertion <- assertions_data[[1]]
            is_compact_format <- !is.null(first_assertion$subj) && !is.null(first_assertion$obj)
        }

        if (is_compact_format) {
            # Working with compact assertions - use lazy expansion
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Using lazy loading for edge:", from_node, "->", to_node, "\n")
            }

            # Search for matching compact assertion
            for (compact_assertion in assertions_data) {
                # Try exact match first
                if (compact_assertion$subj == from_node && compact_assertion$obj == to_node) {
                    # Found it! Expand this assertion on-demand
                    expanded <- lazy_loader(compact_assertion$subj, compact_assertion$obj)

                    if (!is.null(expanded)) {
                        # Extract PMID data from expanded assertion
                        pmid_list <- if (!is.null(expanded$pmid_data)) {
                            names(expanded$pmid_data)
                        } else {
                            character(0)
                        }

                        # Extract sentence data
                        sentence_data <- list()
                        if (!is.null(expanded$pmid_data)) {
                            for (pmid in names(expanded$pmid_data)) {
                                pmid_info <- expanded$pmid_data[[pmid]]
                                if (!is.null(pmid_info$sentences)) {
                                    sentence_data[[pmid]] <- pmid_info$sentences
                                }
                            }
                        }

                        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                            cat("Lazy loaded", length(pmid_list), "PMIDs for edge\n")
                        }

                        return(list(
                            found = TRUE,
                            message = "Edge found (lazy loaded)",
                            pmid_list = pmid_list,
                            sentence_data = sentence_data,
                            evidence_count = expanded$evidence_count %||% length(pmid_list),
                            predicate = expanded$predicate %||% "CAUSES",
                            subject_cui = expanded$subject_cui %||% "",
                            object_cui = expanded$object_cui %||% "",
                            match_type = "exact_lazy"
                        ))
                    }
                }

                # Try CUI-based matching if exact match failed
                if (!is.null(from_cuis) && !is.null(to_cuis)) {
                    assertion_subj_cui <- compact_assertion$subj_cui
                    assertion_obj_cui <- compact_assertion$obj_cui

                    if (!is.null(assertion_subj_cui) && !is.null(assertion_obj_cui)) {
                        assertion_subj_cuis <- strsplit(as.character(assertion_subj_cui), "\\|")[[1]]
                        assertion_obj_cuis <- strsplit(as.character(assertion_obj_cui), "\\|")[[1]]

                        subj_cui_match <- any(from_cuis %in% assertion_subj_cuis)
                        obj_cui_match <- any(to_cuis %in% assertion_obj_cuis)

                        if (subj_cui_match && obj_cui_match) {
                            # Found via CUI match! Expand this assertion
                            expanded <- lazy_loader(compact_assertion$subj, compact_assertion$obj)

                            if (!is.null(expanded)) {
                                pmid_list <- if (!is.null(expanded$pmid_data)) {
                                    names(expanded$pmid_data)
                                } else {
                                    character(0)
                                }

                                sentence_data <- list()
                                if (!is.null(expanded$pmid_data)) {
                                    for (pmid in names(expanded$pmid_data)) {
                                        pmid_info <- expanded$pmid_data[[pmid]]
                                        if (!is.null(pmid_info$sentences)) {
                                            sentence_data[[pmid]] <- pmid_info$sentences
                                        }
                                    }
                                }

                                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                                    cat("Lazy loaded", length(pmid_list), "PMIDs for edge (CUI match)\n")
                                }

                                return(list(
                                    found = TRUE,
                                    message = "Edge found via CUI match (lazy loaded)",
                                    pmid_list = pmid_list,
                                    sentence_data = sentence_data,
                                    evidence_count = expanded$evidence_count %||% length(pmid_list),
                                    predicate = expanded$predicate %||% "CAUSES",
                                    subject_cui = expanded$subject_cui %||% "",
                                    object_cui = expanded$object_cui %||% "",
                                    match_type = "cui_lazy"
                                ))
                            }
                        }
                    }
                }
            }

            # Not found in compact assertions
            return(list(
                found = FALSE,
                message = "Edge not found in compact assertions",
                pmid_list = character(0),
                sentence_data = list(),
                evidence_count = 0,
                predicate = "UNKNOWN",
                subject_cui = "",
                object_cui = ""
            ))
        }

        # OLD lazy loading code for metadata-based loading (keep for backward compatibility)
        # First check metadata for the edge
        metadata_match <- find_edge_in_metadata(from_node, to_node, assertions_data)
        if (metadata_match$found) {
            # Load full data for this specific edge using lazy loader
            full_assertion <- lazy_loader(metadata_match$subject_name, metadata_match$object_name)
            if (!is.null(full_assertion)) {
                # Process the full assertion data
                return(process_full_assertion(full_assertion, metadata_match$match_type))
            }
        }
        # If not found in metadata, fall through to regular processing
    }

    # Normalize the input node names
    from_normalized <- normalize_name(from_node)
    to_normalized <- normalize_name(to_node)

    # Search for matching assertions using multiple matching strategies
    # Collect ALL matching assertions for this edge (to handle multiple predicates)
    matching_assertions <- list()

    for (assertion in assertions_data) {
        if (!is.null(assertion$subject_name) && !is.null(assertion$object_name)) {
            # Strategy 1: Exact match (original logic)
            exact_match <- (assertion$subject_name == from_node && assertion$object_name == to_node)

            # Strategy 2: CUI-based matching (if CUIs are available)
            cui_match <- FALSE
            if (!exact_match && !is.null(from_cuis) && !is.null(to_cuis)) {
                # Get assertion CUIs
                assertion_subj_cui <- assertion$subj_cui %||% assertion$subject_cui
                assertion_obj_cui <- assertion$obj_cui %||% assertion$object_cui

                if (!is.null(assertion_subj_cui) && !is.null(assertion_obj_cui)) {
                    # Split multiple CUIs if they exist
                    assertion_subj_cuis <- strsplit(as.character(assertion_subj_cui), "\\|")[[1]]
                    assertion_obj_cuis <- strsplit(as.character(assertion_obj_cui), "\\|")[[1]]

                    # Check if any CUI matches
                    subj_cui_match <- any(from_cuis %in% assertion_subj_cuis)
                    obj_cui_match <- any(to_cuis %in% assertion_obj_cuis)

                    cui_match <- (subj_cui_match && obj_cui_match)
                }
            }

            # Strategy 3: Normalized name matching with medical variations
            subject_match <- handle_medical_variations(from_node, assertion$subject_name)
            object_match <- handle_medical_variations(to_node, assertion$object_name)
            normalized_match <- (subject_match && object_match)

            # Strategy 4: Partial matching for common transformations
            partial_match <- FALSE
            if (!exact_match && !cui_match && !normalized_match) {
                # Get normalized versions for partial matching
                subject_normalized <- normalize_name(assertion$subject_name)
                object_normalized <- normalize_name(assertion$object_name)

                # Check if the normalized names contain each other or have significant overlap
                from_words <- strsplit(from_normalized, "_")[[1]]
                to_words <- strsplit(to_normalized, "_")[[1]]
                subject_words <- strsplit(subject_normalized, "_")[[1]]
                object_words <- strsplit(object_normalized, "_")[[1]]

                # Check for substantial word overlap (at least 50% of words match)
                from_overlap <- length(intersect(from_words, subject_words)) / max(length(from_words), length(subject_words))
                to_overlap <- length(intersect(to_words, object_words)) / max(length(to_words), length(object_words))

                partial_match <- (from_overlap >= 0.5 && to_overlap >= 0.5)
            }

            if (exact_match || cui_match || normalized_match || partial_match) {
                # Store this matching assertion
                matching_assertions[[length(matching_assertions) + 1]] <- list(
                    assertion = assertion,
                    match_type = if (exact_match) "exact" else if (cui_match) "cui" else if (normalized_match) "normalized" else "partial"
                )
            }
        }
    }

    # If we found matching assertions, aggregate them
    if (length(matching_assertions) > 0) {
        # Aggregate all predicates, PMIDs, and sentences from all matching assertions
        all_predicates <- character(0)
        all_pmids <- character(0)
        all_sentence_data <- list()
        total_evidence_count <- 0
        match_type <- "exact"  # Use the best match type
        original_subject <- ""
        original_object <- ""
        subject_cui <- ""
        object_cui <- ""

        for (match_info in matching_assertions) {
            assertion <- match_info$assertion

            # Collect predicate
            pred <- assertion$predicate %||% "CAUSES"
            if (!(pred %in% all_predicates)) {
                all_predicates <- c(all_predicates, pred)
            }

            # Extract PMID list from pmid_data keys (optimized structure)
            pmid_list <- if (!is.null(assertion$pmid_data)) {
                names(assertion$pmid_data)
            } else if (!is.null(assertion$pmid_list)) {
                assertion$pmid_list  # Backward compatibility
            } else {
                character(0)
            }

            # Handle mixed PMID formats (strings and objects) - for backward compatibility
            if (is.list(pmid_list)) {
                clean_pmids <- character(0)
                for (item in pmid_list) {
                    if (is.character(item)) {
                        clean_pmids <- c(clean_pmids, item)
                    } else if (is.list(item) && !is.null(names(item))) {
                        # If it's a named list, use the name as the PMID
                        clean_pmids <- c(clean_pmids, names(item)[1])
                    }
                }
                pmid_list <- clean_pmids
            }

            # Add unique PMIDs
            for (pmid in pmid_list) {
                if (!(pmid %in% all_pmids)) {
                    all_pmids <- c(all_pmids, pmid)
                }
            }

            # Extract sentence data if available
            pmid_data <- assertion$pmid_data
            if (!is.null(pmid_data) && is.list(pmid_data)) {
                for (pmid in pmid_list) {
                    tryCatch({
                        if (!is.null(pmid_data[[pmid]]) && is.list(pmid_data[[pmid]]) && !is.null(pmid_data[[pmid]]$sentences)) {
                            if (is.null(all_sentence_data[[pmid]])) {
                                all_sentence_data[[pmid]] <- pmid_data[[pmid]]$sentences
                            }
                        }
                    }, error = function(e) {
                        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                            cat("Warning: Error accessing sentence data for PMID", pmid, ":", e$message, "\n")
                        }
                    })
                }
            }

            # Accumulate evidence count
            total_evidence_count <- total_evidence_count + (assertion$evidence_count %||% length(pmid_list))

            # Store metadata from first assertion
            if (original_subject == "") {
                original_subject <- assertion$subject_name %||% ""
                original_object <- assertion$object_name %||% ""
                subject_cui <- assertion$subject_cui %||% ""
                object_cui <- assertion$object_cui %||% ""
                match_type <- match_info$match_type
            }
        }

        # Combine all predicates into a single string
        combined_predicate <- paste(sort(all_predicates), collapse = ", ")

        return(list(
            found = TRUE,
            message = paste("Found", length(all_pmids), "PMIDs for edge (", match_type, "match)"),
            pmid_list = all_pmids,
            sentence_data = all_sentence_data,
            evidence_count = total_evidence_count,
            relationship_degree = "unknown",
            predicate = combined_predicate,  # Now contains all predicates
            match_type = match_type,
            original_subject = original_subject,
            original_object = original_object,
            subject_cui = subject_cui,
            object_cui = object_cui
        ))
    }

    return(list(
        found = FALSE,
        message = "No PMID data found for this edge",
        pmid_list = character(0),
        evidence_count = 0
    ))
}

#' Find All Assertions Related to a Node
#'
#' Finds all causal assertions where the node appears as subject or object
#'
#' @param node_name Name of the node to search for
#' @param assertions_data List of causal assertions
#' @param edges_df Optional data frame of edges to help with matching
#' @return List containing incoming and outgoing relationships
#' @export
find_node_related_assertions <- function(node_name, assertions_data, edges_df = NULL) {
    if (is.null(assertions_data) || length(assertions_data) == 0) {
        return(list(
            found = FALSE,
            message = "No assertions data available",
            incoming = list(),
            outgoing = list(),
            total_count = 0,
            node_name = node_name
        ))
    }

    incoming_edges <- list()
    outgoing_edges <- list()

    # Clean node name for matching (handle underscores and spaces)
    clean_node <- gsub("_", " ", node_name)
    node_variants <- c(node_name, clean_node)

    # Also try with different case
    node_variants <- c(node_variants, tolower(node_name), tolower(clean_node))

    for (assertion in assertions_data) {
        # Get subject and object names
        subj_name <- assertion$subject_name %||% assertion$subj
        obj_name <- assertion$object_name %||% assertion$obj

        # Clean assertion names
        clean_subj <- gsub("_", " ", subj_name)
        clean_obj <- gsub("_", " ", obj_name)

        # Check if node is the subject (outgoing edge from this node)
        if (!is.null(subj_name)) {
            subj_variants <- c(subj_name, clean_subj, tolower(subj_name), tolower(clean_subj))
            if (any(node_variants %in% subj_variants)) {
                outgoing_edges <- c(outgoing_edges, list(assertion))
            }
        }

        # Check if node is the object (incoming edge to this node)
        if (!is.null(obj_name)) {
            obj_variants <- c(obj_name, clean_obj, tolower(obj_name), tolower(clean_obj))
            if (any(node_variants %in% obj_variants)) {
                incoming_edges <- c(incoming_edges, list(assertion))
            }
        }
    }

    # If we have edges_df, try to match using actual edge connections
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        # Find edges connected to this node
        connected_edges <- edges_df[edges_df$from == node_name | edges_df$to == node_name, ]

        if (nrow(connected_edges) > 0) {
            # Try to find assertions for these edges
            for (i in 1:nrow(connected_edges)) {
                edge <- connected_edges[i, ]

                if (edge$from == node_name) {
                    # This is an outgoing edge
                    for (assertion in assertions_data) {
                        obj_name <- assertion$object_name %||% assertion$obj
                        if (!is.null(obj_name) && (obj_name == edge$to || gsub("_", " ", obj_name) == gsub("_", " ", edge$to))) {
                            # Check if not already in outgoing_edges
                            if (!any(sapply(outgoing_edges, function(x) identical(x, assertion)))) {
                                outgoing_edges <- c(outgoing_edges, list(assertion))
                            }
                        }
                    }
                } else {
                    # This is an incoming edge
                    for (assertion in assertions_data) {
                        subj_name <- assertion$subject_name %||% assertion$subj
                        if (!is.null(subj_name) && (subj_name == edge$from || gsub("_", " ", subj_name) == gsub("_", " ", edge$from))) {
                            # Check if not already in incoming_edges
                            if (!any(sapply(incoming_edges, function(x) identical(x, assertion)))) {
                                incoming_edges <- c(incoming_edges, list(assertion))
                            }
                        }
                    }
                }
            }
        }
    }

    total_count <- length(incoming_edges) + length(outgoing_edges)

    return(list(
        found = total_count > 0,
        message = if (total_count > 0) {
            paste("Found", total_count, "related assertions")
        } else {
            "No assertions found for this node"
        },
        incoming = incoming_edges,
        outgoing = outgoing_edges,
        total_count = total_count,
        node_name = node_name,
        incoming_count = length(incoming_edges),
        outgoing_count = length(outgoing_edges)
    ))
}

