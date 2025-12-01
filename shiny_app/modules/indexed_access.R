# Indexed Access System for Causal Assertions
# 
# This module provides O(1) lookup performance for causal assertions
# by creating and maintaining edge-to-assertion index structures.

library(jsonlite)
library(digest)

#' Create Edge Index
#'
#' Creates an index mapping edges to assertion positions for fast lookup
#'
#' @param assertions_data List of causal assertions
#' @param include_variations Include medical term variations in index
#' @return List with edge index and metadata
#' @export
create_edge_index <- function(assertions_data, include_variations = TRUE) {
    if (!is.list(assertions_data) || length(assertions_data) == 0) {
        return(list(
            success = FALSE,
            message = "Invalid or empty assertions data",
            index = list()
        ))
    }
    
    cat("Creating edge index for", length(assertions_data), "assertions...\n")
    start_time <- Sys.time()
    
    # Initialize index structures
    edge_index <- list()
    subject_index <- list()
    object_index <- list()
    
    # Helper function to normalize names
    normalize_name <- function(name) {
        if (is.null(name) || name == "") return("")
        normalized <- tolower(name)
        normalized <- gsub("[^a-z0-9]+", "_", normalized)
        normalized <- gsub("_+", "_", normalized)
        normalized <- gsub("^_|_$", "", normalized)
        return(normalized)
    }
    
    # Medical term variations for enhanced matching
    medical_variations <- list(
        c("hypertension", "hypertensive_disease", "hypertensive_disorder"),
        c("diabetes", "diabetes_mellitus"),
        c("heart_disease", "cardiovascular_disease", "coronary_artery_disease"),
        c("stroke", "cerebrovascular_accident", "cerebral_infarction"),
        c("cancer", "neoplasm", "malignant_neoplasm"),
        c("obesity", "overweight", "body_mass_index")
    )
    
    # Create index entries
    for (i in seq_along(assertions_data)) {
        assertion <- assertions_data[[i]]
        
        if (is.null(assertion$subject_name) || is.null(assertion$object_name)) {
            next
        }
        
        subject_norm <- normalize_name(assertion$subject_name)
        object_norm <- normalize_name(assertion$object_name)
        
        # Create primary edge key
        edge_key <- paste(subject_norm, object_norm, sep = " -> ")
        
        # Store assertion index
        assertion_info <- list(
            index = i,
            subject_name = assertion$subject_name,
            object_name = assertion$object_name,
            subject_cui = assertion$subject_cui %||% "",
            object_cui = assertion$object_cui %||% "",
            evidence_count = assertion$evidence_count %||% 0,
            relationship_degree = assertion$relationship_degree %||% "unknown",
            predicate = assertion$predicate %||% "CAUSES"
        )
        
        # Add to edge index
        if (edge_key %in% names(edge_index)) {
            # Multiple assertions for same edge (shouldn't happen but handle it)
            if (!is.list(edge_index[[edge_key]])) {
                edge_index[[edge_key]] <- list(edge_index[[edge_key]])
            }
            edge_index[[edge_key]][[length(edge_index[[edge_key]]) + 1]] <- assertion_info
        } else {
            edge_index[[edge_key]] <- assertion_info
        }
        
        # Add to subject index
        if (subject_norm %in% names(subject_index)) {
            subject_index[[subject_norm]] <- c(subject_index[[subject_norm]], i)
        } else {
            subject_index[[subject_norm]] <- i
        }
        
        # Add to object index
        if (object_norm %in% names(object_index)) {
            object_index[[object_norm]] <- c(object_index[[object_norm]], i)
        } else {
            object_index[[object_norm]] <- i
        }
        
        # Add medical variations if enabled
        if (include_variations) {
            for (variation_group in medical_variations) {
                # Check if subject matches any variation
                if (subject_norm %in% variation_group) {
                    for (variant in variation_group) {
                        if (variant != subject_norm) {
                            variant_edge_key <- paste(variant, object_norm, sep = " -> ")
                            edge_index[[variant_edge_key]] <- assertion_info
                        }
                    }
                }
                
                # Check if object matches any variation
                if (object_norm %in% variation_group) {
                    for (variant in variation_group) {
                        if (variant != object_norm) {
                            variant_edge_key <- paste(subject_norm, variant, sep = " -> ")
                            edge_index[[variant_edge_key]] <- assertion_info
                        }
                    }
                }
                
                # Check if both subject and object match variations
                subject_variants <- if (subject_norm %in% variation_group) variation_group else c(subject_norm)
                object_variants <- if (object_norm %in% variation_group) variation_group else c(object_norm)
                
                for (s_var in subject_variants) {
                    for (o_var in object_variants) {
                        if (s_var != subject_norm || o_var != object_norm) {
                            variant_edge_key <- paste(s_var, o_var, sep = " -> ")
                            edge_index[[variant_edge_key]] <- assertion_info
                        }
                    }
                }
            }
        }
    }
    
    index_time <- as.numeric(Sys.time() - start_time, units = "secs")
    
    cat("Created edge index with", length(edge_index), "entries in", round(index_time, 3), "seconds\n")
    cat("Subject index:", length(subject_index), "entries\n")
    cat("Object index:", length(object_index), "entries\n")
    
    return(list(
        success = TRUE,
        message = paste("Created index with", length(edge_index), "edge entries"),
        edge_index = edge_index,
        subject_index = subject_index,
        object_index = object_index,
        index_creation_time = index_time,
        total_assertions = length(assertions_data),
        total_edge_entries = length(edge_index),
        includes_variations = include_variations
    ))
}

#' Fast Edge Lookup
#'
#' Performs O(1) lookup for edge information using the index
#'
#' @param from_node Source node name
#' @param to_node Target node name
#' @param edge_index Edge index created by create_edge_index
#' @param assertions_data Original assertions data (for full data retrieval)
#' @return List with edge information
#' @export
fast_edge_lookup <- function(from_node, to_node, edge_index, assertions_data = NULL) {
    if (is.null(edge_index) || length(edge_index) == 0) {
        return(list(
            found = FALSE,
            message = "No edge index available",
            pmid_list = character(0),
            evidence_count = 0
        ))
    }
    
    # Normalize input names
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
    edge_key <- paste(from_normalized, to_normalized, sep = " -> ")
    
    # Perform O(1) lookup
    if (edge_key %in% names(edge_index)) {
        assertion_info <- edge_index[[edge_key]]
        
        # Handle multiple assertions for same edge
        if (is.list(assertion_info) && "index" %in% names(assertion_info)) {
            # Single assertion
            assertion_index <- assertion_info$index
        } else if (is.list(assertion_info) && is.list(assertion_info[[1]])) {
            # Multiple assertions - use the first one
            assertion_index <- assertion_info[[1]]$index
            assertion_info <- assertion_info[[1]]
        } else {
            return(list(
                found = FALSE,
                message = "Invalid index structure",
                pmid_list = character(0),
                evidence_count = 0
            ))
        }
        
        # Get full assertion data if available
        if (!is.null(assertions_data) && assertion_index <= length(assertions_data)) {
            full_assertion <- assertions_data[[assertion_index]]
            
            # Extract PMID list from pmid_data keys (optimized structure)
            pmid_list <- if (!is.null(full_assertion$pmid_data)) {
                names(full_assertion$pmid_data)
            } else if (!is.null(full_assertion$pmid_list)) {
                full_assertion$pmid_list  # Backward compatibility
            } else {
                character(0)
            }

            sentence_data <- list()
            if (!is.null(full_assertion$pmid_data)) {
                for (pmid in names(full_assertion$pmid_data)) {
                    if (!is.null(full_assertion$pmid_data[[pmid]]$sentences)) {
                        sentence_data[[pmid]] <- full_assertion$pmid_data[[pmid]]$sentences
                    }
                }
            }
            
            return(list(
                found = TRUE,
                message = paste("Found", length(pmid_list), "PMIDs for edge (indexed lookup)"),
                pmid_list = pmid_list,
                sentence_data = sentence_data,
                evidence_count = assertion_info$evidence_count,
                relationship_degree = assertion_info$relationship_degree,
                predicate = assertion_info$predicate,
                match_type = "indexed",
                original_subject = assertion_info$subject_name,
                original_object = assertion_info$object_name,
                subject_cui = assertion_info$subject_cui,
                object_cui = assertion_info$object_cui,
                assertion_index = assertion_index
            ))
        } else {
            # Return basic information from index
            return(list(
                found = TRUE,
                message = "Found edge in index (basic info only)",
                pmid_list = character(0),
                sentence_data = list(),
                evidence_count = assertion_info$evidence_count,
                relationship_degree = assertion_info$relationship_degree,
                predicate = assertion_info$predicate,
                match_type = "indexed_basic",
                original_subject = assertion_info$subject_name,
                original_object = assertion_info$object_name,
                subject_cui = assertion_info$subject_cui,
                object_cui = assertion_info$object_cui,
                assertion_index = assertion_index
            ))
        }
    } else {
        return(list(
            found = FALSE,
            message = "Edge not found in index",
            pmid_list = character(0),
            evidence_count = 0
        ))
    }
}

#' Save Edge Index
#'
#' Saves edge index to disk for reuse
#'
#' @param edge_index_result Result from create_edge_index
#' @param output_file Path to save the index
#' @param degree Degree parameter for file naming
#' @param output_dir Directory to save index (default: current directory)
#' @return List with save results
#' @export
save_edge_index <- function(edge_index_result, output_file = NULL, degree = NULL, output_dir = ".") {
    if (!edge_index_result$success) {
        return(list(
            success = FALSE,
            message = "Cannot save invalid edge index"
        ))
    }
    
    # Generate output filename if not provided
    if (is.null(output_file)) {
        if (!is.null(degree)) {
            output_file <- file.path(output_dir, paste0("edge_index_", degree, ".rds"))
        } else {
            output_file <- file.path(output_dir, "edge_index.rds")
        }
    }
    
    tryCatch({
        cat("Saving edge index to", basename(output_file), "...\n")
        start_time <- Sys.time()
        
        # Save with compression
        saveRDS(edge_index_result, output_file, compress = "gzip")
        
        save_time <- as.numeric(Sys.time() - start_time, units = "secs")
        file_size_mb <- round(file.size(output_file) / (1024^2), 2)
        
        cat("Edge index saved in", round(save_time, 3), "seconds\n")
        cat("Index file size:", file_size_mb, "MB\n")
        
        return(list(
            success = TRUE,
            message = "Edge index saved successfully",
            index_file = output_file,
            file_size_mb = file_size_mb,
            save_time_seconds = save_time
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error saving edge index:", e$message)
        ))
    })
}

#' Load Edge Index
#'
#' Loads edge index from disk
#'
#' @param index_file Path to the index file
#' @return List with loaded index
#' @export
load_edge_index <- function(index_file) {
    if (!file.exists(index_file)) {
        return(list(
            success = FALSE,
            message = paste("Index file not found:", index_file)
        ))
    }
    
    tryCatch({
        cat("Loading edge index from", basename(index_file), "...\n")
        start_time <- Sys.time()
        
        edge_index_result <- readRDS(index_file)
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        
        cat("Edge index loaded in", round(load_time, 3), "seconds\n")
        cat("Index contains", edge_index_result$total_edge_entries, "edge entries\n")
        
        return(c(edge_index_result, list(
            load_time_seconds = load_time
        )))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading edge index:", e$message)
        ))
    })
}

#' Check for Index Files
#'
#' Checks if index files exist for a given degree value
#'
#' @param degree Degree parameter
#' @param search_dirs Directories to search in
#' @return List with file paths if they exist
#' @export
check_for_index_files <- function(degree, search_dirs = c("../graph_creation/result", "../graph_creation/output")) {
    index_filename <- paste0("edge_index_", degree, ".rds")
    
    for (dir in search_dirs) {
        if (dir.exists(dir)) {
            index_path <- file.path(dir, index_filename)
            
            if (file.exists(index_path)) {
                return(list(
                    found = TRUE,
                    index_file = index_path
                ))
            }
        }
    }
    
    return(list(found = FALSE))
}
