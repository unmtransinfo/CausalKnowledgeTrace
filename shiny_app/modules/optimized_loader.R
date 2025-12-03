# Optimized JSON Loader for Shiny App
#
# This module loads the new single optimized JSON format and expands it
# back to the standard format for use in the Shiny application

library(jsonlite)

#' Load Optimized JSON Format
#'
#' Loads the new optimized JSON format and expands it to standard format
#'
#' @param file_path Path to optimized JSON file
#' @param expand_full Whether to expand to full format (default: FALSE for lazy loading)
#' @param filtered_edges Optional data frame with columns 'v' and 'w' to filter edges (default: NULL for no filtering)
#' @return List with loaded data
#' @export
load_optimized_causal_assertions <- function(file_path, expand_full = FALSE, filtered_edges = NULL) {
    start_time <- Sys.time()

    if (!file.exists(file_path)) {
        return(list(
            success = FALSE,
            message = paste("Optimized file not found:", file_path),
            assertions = list()
        ))
    }

    tryCatch({
        cat("Loading optimized JSON format from", basename(file_path), "...\n")

        # Load optimized data
        optimized_data <- jsonlite::fromJSON(file_path, simplifyDataFrame = FALSE)

        # Check if this is the new optimized format
        if (is.null(optimized_data$pmid_sentences) || is.null(optimized_data$assertions)) {
            # This is the old standard format, load directly
            cat("Detected standard format, loading directly...\n")

            # Apply filtering if provided
            if (!is.null(filtered_edges) && nrow(filtered_edges) > 0) {
                cat("Filtering standard format assertions...\n")
                valid_edges <- paste0(filtered_edges$v, "->", filtered_edges$w)
                filtered_data <- list()
                for (assertion in optimized_data) {
                    edge_key <- paste0(assertion$subject_name, "->", assertion$object_name)
                    if (edge_key %in% valid_edges) {
                        filtered_data[[length(filtered_data) + 1]] <- assertion
                    }
                }
                optimized_data <- filtered_data
                cat("Kept", length(optimized_data), "assertions after filtering\n")
            }

            load_time <- as.numeric(Sys.time() - start_time, units = "secs")

            return(list(
                success = TRUE,
                message = paste("Loaded", length(optimized_data), "assertions from standard format"),
                assertions = optimized_data,
                loading_strategy = "standard_format",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(file_path) / (1024^2), 2)
            ))
        }

        if (expand_full) {
            cat("Expanding optimized format to standard format...\n")
            expanded_data <- expand_optimized_format(optimized_data, filtered_edges)

            load_time <- as.numeric(Sys.time() - start_time, units = "secs")

            cat("Loaded", length(expanded_data), "assertions in", round(load_time, 3), "seconds\n")

            return(list(
                success = TRUE,
                message = paste("Loaded", length(expanded_data), "assertions from optimized format"),
                assertions = expanded_data,
                loading_strategy = "optimized_expanded",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(file_path) / (1024^2), 2),
                unique_pmids = length(optimized_data$pmid_sentences),
                total_sentences = sum(sapply(optimized_data$pmid_sentences, length))
            ))
        } else {
            # Return compact format with lazy expansion function
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")

            cat("Loaded", length(optimized_data$assertions), "compact assertions in", round(load_time, 3), "seconds\n")
            cat("Using LAZY LOADING mode - assertions will be expanded on-demand when edges are clicked\n")

            # Create expansion cache for performance
            expansion_cache <- new.env(parent = emptyenv())

            # Create lazy expansion function
            lazy_expand_fn <- function(subject_name, object_name) {
                # Check cache first
                cache_key <- paste0(subject_name, "->", object_name)
                if (exists(cache_key, envir = expansion_cache)) {
                    return(get(cache_key, envir = expansion_cache))
                }

                # Find and expand the specific assertion
                for (compact_assertion in optimized_data$assertions) {
                    if (compact_assertion$subj == subject_name && compact_assertion$obj == object_name) {
                        # Expand this single assertion
                        expanded <- list(
                            subject_name = compact_assertion$subj,
                            subject_cui = compact_assertion$subj_cui,
                            predicate = compact_assertion$predicate %||% "CAUSES",
                            object_name = compact_assertion$obj,
                            object_cui = compact_assertion$obj_cui,
                            evidence_count = compact_assertion$ev_count,
                            relationship_degree = "unknown",
                            pmid_data = list()
                        )

                        # Expand PMID data
                        pmid_refs <- compact_assertion$pmid_refs
                        if (!is.null(pmid_refs) && length(pmid_refs) > 0) {
                            for (pmid in pmid_refs) {
                                if (!is.null(optimized_data$pmid_sentences[[pmid]])) {
                                    expanded$pmid_data[[pmid]] <- list(sentences = optimized_data$pmid_sentences[[pmid]])
                                }
                            }
                        }

                        # Cache the result
                        assign(cache_key, expanded, envir = expansion_cache)
                        return(expanded)
                    }
                }

                return(NULL)  # Not found
            }

            # Apply filtering if provided
            compact_assertions <- optimized_data$assertions
            if (!is.null(filtered_edges) && nrow(filtered_edges) > 0) {
                valid_edges <- paste0(filtered_edges$v, "->", filtered_edges$w)
                cat("Filtering compact assertions: keeping", length(valid_edges), "edges out of",
                    length(compact_assertions), "total assertions\n")

                filtered_compact <- list()
                for (assertion in compact_assertions) {
                    edge_key <- paste0(assertion$subj, "->", assertion$obj)
                    if (edge_key %in% valid_edges) {
                        filtered_compact[[length(filtered_compact) + 1]] <- assertion
                    }
                }
                compact_assertions <- filtered_compact
                cat("Kept", length(compact_assertions), "compact assertions after filtering\n")
            }

            return(list(
                success = TRUE,
                message = paste("Loaded", length(compact_assertions), "compact assertions (lazy loading enabled)"),
                assertions = compact_assertions,  # Store compact format
                compact_data = optimized_data,    # Store full compact data for lazy expansion
                lazy_loader = lazy_expand_fn,     # Provide lazy expansion function
                loading_strategy = "optimized_lazy",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(file_path) / (1024^2), 2),
                unique_pmids = length(optimized_data$pmid_sentences),
                total_assertions = length(optimized_data$assertions),
                filtered_assertions = length(compact_assertions)
            ))
        }
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading optimized format:", e$message),
            assertions = list()
        ))
    })
}

#' Expand Optimized Format to Standard Format
#'
#' Converts the optimized format back to standard causal assertions format
#'
#' @param optimized_data Optimized data structure
#' @param filtered_edges Optional data frame with columns 'v' and 'w' to filter edges (default: NULL for no filtering)
#' @return List of standard format assertions
expand_optimized_format <- function(optimized_data, filtered_edges = NULL) {
    expanded_assertions <- list()

    pmid_sentences <- optimized_data$pmid_sentences

    # Create a set of valid edges for fast lookup if filtering is enabled
    valid_edges <- NULL
    if (!is.null(filtered_edges) && nrow(filtered_edges) > 0) {
        # Create edge keys in format "subject->object"
        valid_edges <- paste0(filtered_edges$v, "->", filtered_edges$w)
        cat("Filtering assertions: only expanding", length(valid_edges), "edges out of",
            length(optimized_data$assertions), "total assertions\n")
    }

    for (compact_assertion in optimized_data$assertions) {
        # If filtering is enabled, check if this edge should be included
        if (!is.null(valid_edges)) {
            edge_key <- paste0(compact_assertion$subj, "->", compact_assertion$obj)
            if (!(edge_key %in% valid_edges)) {
                next  # Skip this assertion
            }
        }

        # Expand to standard format
        expanded_assertion <- list(
            subject_name = compact_assertion$subj,
            subject_cui = compact_assertion$subj_cui,
            predicate = compact_assertion$predicate %||% "CAUSES",  # Use actual predicate from compact assertion
            object_name = compact_assertion$obj,
            object_cui = compact_assertion$obj_cui,
            evidence_count = compact_assertion$ev_count,
            relationship_degree = "unknown",  # Default degree
            pmid_data = list()
        )

        # Expand PMID data
        pmid_refs <- compact_assertion$pmid_refs
        if (!is.null(pmid_refs) && length(pmid_refs) > 0) {
            for (pmid in pmid_refs) {
                if (!is.null(pmid_sentences[[pmid]])) {
                    expanded_assertion$pmid_data[[pmid]] <- list(sentences = pmid_sentences[[pmid]])
                }
            }
        }

        expanded_assertions[[length(expanded_assertions) + 1]] <- expanded_assertion
    }

    return(expanded_assertions)
}

#' Get Optimized Format Statistics
#'
#' Returns statistics about the optimized format file
#'
#' @param file_path Path to optimized JSON file
#' @return List with statistics
#' @export
get_optimized_format_stats <- function(file_path) {
    if (!file.exists(file_path)) {
        return(list(
            success = FALSE,
            message = "File not found"
        ))
    }
    
    tryCatch({
        # Load just the metadata
        optimized_data <- jsonlite::fromJSON(file_path, simplifyDataFrame = FALSE)
        
        # Check if optimized format
        if (is.null(optimized_data$pmid_sentences) || is.null(optimized_data$assertions)) {
            # Standard format
            return(list(
                success = TRUE,
                format = "standard",
                total_assertions = length(optimized_data),
                file_size_mb = round(file.size(file_path) / (1024^2), 2)
            ))
        }
        
        # Optimized format
        return(list(
            success = TRUE,
            format = "optimized",
            total_assertions = length(optimized_data$assertions),
            unique_pmids = length(optimized_data$pmid_sentences),
            total_sentences = sum(sapply(optimized_data$pmid_sentences, length)),
            file_size_mb = round(file.size(file_path) / (1024^2), 2)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error reading file:", e$message)
        ))
    })
}

#' Load Causal Assertions (Unified Interface)
#'
#' Unified interface that automatically detects and loads both standard and optimized formats
#'
#' @param file_path Path to JSON file (standard or optimized)
#' @param filtered_edges Optional data frame with columns 'v' and 'w' to filter edges (default: NULL for no filtering)
#' @param use_lazy_loading Whether to use lazy loading (default: TRUE for better performance)
#' @return List with loaded assertions
#' @export
load_causal_assertions_unified <- function(file_path, filtered_edges = NULL, use_lazy_loading = TRUE) {
    # Use the optimized loader which handles both formats
    # Default to lazy loading (expand_full = FALSE) for better performance
    return(load_optimized_causal_assertions(file_path, expand_full = !use_lazy_loading, filtered_edges = filtered_edges))
}

#' Test Optimized Format Loading
#'
#' Test function to verify optimized format loading works correctly
#'
#' @param file_path Path to optimized JSON file
#' @export
test_optimized_loading <- function(file_path) {
    cat("=== TESTING OPTIMIZED FORMAT LOADING ===\n")
    cat("File:", file_path, "\n")
    
    # Get stats
    stats <- get_optimized_format_stats(file_path)
    if (stats$success) {
        cat("Format:", stats$format, "\n")
        cat("File size:", stats$file_size_mb, "MB\n")
        
        if (stats$format == "optimized") {
            cat("Version:", stats$version, "\n")
            cat("Total assertions:", stats$total_assertions, "\n")
            cat("Unique sentences:", stats$unique_sentences, "\n")
            cat("Unique PMIDs:", stats$unique_pmids, "\n")
        } else {
            cat("Total assertions:", stats$total_assertions, "\n")
        }
    }
    
    # Test loading
    cat("\n=== TESTING LOAD ===\n")
    result <- load_optimized_causal_assertions(file_path)
    
    if (result$success) {
        cat("Success:", result$message, "\n")
        cat("Loading strategy:", result$loading_strategy, "\n")
        cat("Load time:", round(result$load_time_seconds, 3), "seconds\n")
        cat("Assertions loaded:", length(result$assertions), "\n")
        
        if (length(result$assertions) > 0) {
            first_assertion <- result$assertions[[1]]
            cat("First assertion subject:", first_assertion$subject_name, "\n")
            cat("First assertion evidence count:", first_assertion$evidence_count, "\n")
            pmid_count <- length(first_assertion$pmid_data)
            cat("PMIDs in first assertion:", pmid_count, "\n")
        }
    } else {
        cat("Error:", result$message, "\n")
    }
}
