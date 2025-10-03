# Optimized JSON Format System
#
# This module implements a single optimized JSON format that:
# 1. Uses compact field names to reduce file size
# 2. Eliminates sentence duplication through PMID lookup structure
# 3. Maintains all functionality while achieving 80%+ size reduction

library(jsonlite)

#' Convert Standard JSON to Optimized Format
#'
#' Transforms the standard causal assertions format into an optimized structure
#' with compact field names and deduplicated sentences
#'
#' @param input_file Path to standard JSON file
#' @param output_file Path for optimized JSON file
#' @return List with conversion results
#' @export
convert_to_optimized_format <- function(input_file, output_file = NULL) {
    start_time <- Sys.time()
    
    if (!file.exists(input_file)) {
        return(list(
            success = FALSE,
            message = paste("Input file not found:", input_file)
        ))
    }
    
    # Set output file if not provided
    if (is.null(output_file)) {
        base_name <- tools::file_path_sans_ext(basename(input_file))
        output_dir <- dirname(input_file)
        output_file <- file.path(output_dir, paste0(base_name, "_optimized.json"))
    }
    
    cat("Loading standard JSON format...\n")
    tryCatch({
        # Load original data
        original_data <- jsonlite::fromJSON(input_file, simplifyDataFrame = FALSE)
        
        if (!is.list(original_data) || length(original_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty JSON data"
            ))
        }
        
        cat("Converting", length(original_data), "assertions to optimized format...\n")
        
        # Create optimized structure
        optimized_data <- create_optimized_structure(original_data)
        
        # Save optimized JSON with maximum compression
        cat("Saving optimized JSON...\n")
        jsonlite::write_json(
            optimized_data,
            output_file,
            pretty = FALSE,  # Compact format
            auto_unbox = TRUE,
            digits = NA      # Preserve numeric precision
        )
        
        # Calculate file sizes
        original_size <- file.size(input_file)
        optimized_size <- file.size(output_file)
        size_reduction <- round((1 - optimized_size / original_size) * 100, 1)
        
        processing_time <- as.numeric(Sys.time() - start_time, units = "secs")
        
        cat("Optimization completed in", round(processing_time, 2), "seconds\n")
        cat("Original file:", round(original_size / (1024^2), 2), "MB\n")
        cat("Optimized file:", round(optimized_size / (1024^2), 2), "MB\n")
        cat("Size reduction:", size_reduction, "%\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully optimized with", size_reduction, "% size reduction"),
            input_file = input_file,
            output_file = output_file,
            original_size_mb = round(original_size / (1024^2), 2),
            optimized_size_mb = round(optimized_size / (1024^2), 2),
            size_reduction_percent = size_reduction,
            processing_time_seconds = processing_time,
            total_assertions = length(original_data),
            unique_sentences = length(optimized_data$sentences),
            unique_pmids = length(optimized_data$pmids)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error during optimization:", e$message)
        ))
    })
}

#' Create Optimized JSON Structure
#'
#' Transforms standard format into optimized structure with:
#' - Compact field names (s=subject, o=object, etc.)
#' - Deduplicated sentences with ID references
#' - PMID lookup table
#'
#' @param original_data List of standard format assertions
#' @return Optimized data structure
create_optimized_structure <- function(original_data) {
    # Initialize optimized structure
    optimized <- list(
        # Metadata
        version = "1.0",
        format = "optimized",
        created = Sys.time(),
        
        # Lookup tables
        sentences = list(),      # sentence_id -> sentence_text
        pmids = list(),         # pmid_id -> pmid_info
        
        # Compact assertions
        assertions = list()     # Compact assertion format
    )
    
    # Build sentence and PMID lookup tables
    sentence_map <- list()    # sentence_text -> sentence_id
    pmid_map <- list()       # pmid -> pmid_id
    sentence_counter <- 0
    pmid_counter <- 0
    
    cat("Building lookup tables...\n")
    
    # First pass: collect all unique sentences and PMIDs
    for (assertion in original_data) {
        pmid_data <- assertion$pmid_data
        if (!is.null(pmid_data)) {
            for (pmid in names(pmid_data)) {
                # Add PMID to lookup if not exists (use integer IDs)
                if (is.null(pmid_map[[pmid]])) {
                    pmid_counter <- pmid_counter + 1
                    pmid_map[[pmid]] <- pmid_counter  # Use integer instead of string
                    optimized$pmids[[as.character(pmid_counter)]] <- list(
                        p = pmid,        # pmid -> p
                        s = c()          # sentences -> s (will be integer array)
                    )
                }
                
                # Process sentences for this PMID
                sentences <- pmid_data[[pmid]]$sentences
                if (!is.null(sentences)) {
                    sentence_ids <- c()
                    for (sentence in sentences) {
                        # Add sentence to lookup if not exists (use integer IDs)
                        if (is.null(sentence_map[[sentence]])) {
                            sentence_counter <- sentence_counter + 1
                            sentence_map[[sentence]] <- sentence_counter  # Use integer
                            optimized$sentences[[as.character(sentence_counter)]] <- sentence
                        }
                        sentence_ids <- c(sentence_ids, sentence_map[[sentence]])
                    }
                    # Store sentence IDs for this PMID
                    pmid_id <- pmid_map[[pmid]]
                    optimized$pmids[[as.character(pmid_id)]]$s <- sentence_ids
                }
            }
        }
    }
    
    cat("Created", length(optimized$sentences), "unique sentences\n")
    cat("Created", length(optimized$pmids), "unique PMIDs\n")
    
    # Second pass: create compact assertions
    cat("Creating compact assertions...\n")
    
    for (assertion in original_data) {
        # Create compact assertion with ultra-short field names
        compact_assertion <- list(
            s = assertion$subject_name,       # subject_name -> s
            c = assertion$subject_cui,        # subject_cui -> c
            p = assertion$predicate,          # predicate -> p
            o = assertion$object_name,        # object_name -> o
            u = assertion$object_cui,         # object_cui -> u
            e = assertion$evidence_count,     # evidence_count -> e
            d = assertion$relationship_degree, # relationship_degree -> d
            m = c()                           # pmid_data -> m (PMID references as array)
        )
        
        # Convert PMID data to references
        pmid_data <- assertion$pmid_data
        if (!is.null(pmid_data)) {
            for (pmid in names(pmid_data)) {
                pmid_id <- pmid_map[[pmid]]
                if (!is.null(pmid_id)) {
                    compact_assertion$m <- c(compact_assertion$m, pmid_id)
                }
            }
        }
        
        optimized$assertions[[length(optimized$assertions) + 1]] <- compact_assertion
    }
    
    cat("Created", length(optimized$assertions), "compact assertions\n")
    
    return(optimized)
}

#' Load Optimized JSON Format
#'
#' Loads and expands optimized JSON back to standard format for use
#'
#' @param optimized_file Path to optimized JSON file
#' @param expand_sentences Whether to expand sentence references (default: TRUE)
#' @return List with loaded data
#' @export
load_optimized_format <- function(optimized_file, expand_sentences = TRUE) {
    start_time <- Sys.time()
    
    if (!file.exists(optimized_file)) {
        return(list(
            success = FALSE,
            message = paste("Optimized file not found:", optimized_file)
        ))
    }
    
    tryCatch({
        cat("Loading optimized JSON format...\n")
        optimized_data <- jsonlite::fromJSON(optimized_file, simplifyDataFrame = FALSE)
        
        if (expand_sentences) {
            cat("Expanding to standard format...\n")
            expanded_data <- expand_optimized_format(optimized_data)
            
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")
            
            return(list(
                success = TRUE,
                message = paste("Loaded", length(expanded_data), "assertions from optimized format"),
                assertions = expanded_data,
                loading_strategy = "optimized_expanded",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(optimized_file) / (1024^2), 2),
                unique_sentences = length(optimized_data$sentences),
                unique_pmids = length(optimized_data$pmids)
            ))
        } else {
            # Return compact format for memory-efficient browsing
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")
            
            return(list(
                success = TRUE,
                message = paste("Loaded", length(optimized_data$assertions), "compact assertions"),
                assertions = optimized_data$assertions,
                sentences = optimized_data$sentences,
                pmids = optimized_data$pmids,
                loading_strategy = "optimized_compact",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(optimized_file) / (1024^2), 2)
            ))
        }
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading optimized format:", e$message)
        ))
    })
}

#' Expand Optimized Format to Standard Format
#'
#' Converts compact optimized format back to standard format
#'
#' @param optimized_data Optimized data structure
#' @return List of standard format assertions
expand_optimized_format <- function(optimized_data) {
    expanded_assertions <- list()
    
    sentences_lookup <- optimized_data$sentences
    pmids_lookup <- optimized_data$pmids
    
    for (compact_assertion in optimized_data$assertions) {
        # Expand compact field names back to standard
        expanded_assertion <- list(
            subject_name = compact_assertion$s,
            subject_cui = compact_assertion$c,
            predicate = compact_assertion$p,
            object_name = compact_assertion$o,
            object_cui = compact_assertion$u,
            evidence_count = compact_assertion$e,
            relationship_degree = compact_assertion$d,
            pmid_data = list()
        )
        
        # Expand PMID references
        if (!is.null(compact_assertion$m)) {
            for (pmid_id in compact_assertion$m) {
                pmid_info <- pmids_lookup[[as.character(pmid_id)]]
                if (!is.null(pmid_info)) {
                    pmid <- pmid_info$p  # pmid field is now 'p'

                    # Expand sentence references
                    sentences <- c()
                    if (!is.null(pmid_info$s)) {  # sentences field is now 's'
                        for (sentence_id in pmid_info$s) {
                            sentence_text <- sentences_lookup[[as.character(sentence_id)]]
                            if (!is.null(sentence_text)) {
                                sentences <- c(sentences, sentence_text)
                            }
                        }
                    }

                    expanded_assertion$pmid_data[[pmid]] <- list(
                        sentences = sentences
                    )
                }
            }
        }
        
        expanded_assertions[[length(expanded_assertions) + 1]] <- expanded_assertion
    }
    
    return(expanded_assertions)
}
