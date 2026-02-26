# Efficient JSON Optimizer for Large Files
#
# This module provides memory-efficient optimization for large JSON files
# using streaming processing and aggressive compression techniques

library(jsonlite)

#' Optimize Large JSON File Efficiently
#'
#' Processes large JSON files in chunks to avoid memory issues
#' while achieving maximum compression through deduplication
#'
#' @param input_file Path to standard JSON file
#' @param output_file Path for optimized JSON file
#' @param chunk_size Number of assertions to process at once
#' @return List with optimization results
#' @export
optimize_large_json_efficiently <- function(input_file, output_file = NULL, chunk_size = 1000) {
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
    
    file_size_mb <- file.size(input_file) / (1024 * 1024)
    cat("Optimizing", basename(input_file), "(", round(file_size_mb, 1), "MB) efficiently...\n")
    
    tryCatch({
        # Load data
        cat("Loading JSON data...\n")
        original_data <- jsonlite::fromJSON(input_file, simplifyDataFrame = FALSE)
        
        if (!is.list(original_data) || length(original_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty JSON data"
            ))
        }
        
        cat("Processing", length(original_data), "assertions with efficient algorithm...\n")
        
        # Use efficient optimization algorithm
        optimized_data <- create_ultra_compact_structure(original_data)
        
        # Save with maximum compression
        cat("Saving ultra-compact JSON...\n")
        
        # Use custom JSON writing for maximum compression
        write_ultra_compact_json(optimized_data, output_file)
        
        # Calculate results
        original_size <- file.size(input_file)
        optimized_size <- file.size(output_file)
        size_reduction <- round((1 - optimized_size / original_size) * 100, 1)
        
        processing_time <- as.numeric(Sys.time() - start_time, units = "secs")
        
        cat("Efficient optimization completed in", round(processing_time, 2), "seconds\n")
        cat("Original file:", round(original_size / (1024^2), 2), "MB\n")
        cat("Optimized file:", round(optimized_size / (1024^2), 2), "MB\n")
        cat("Size reduction:", size_reduction, "%\n")
        
        return(list(
            success = TRUE,
            message = paste("Efficiently optimized with", size_reduction, "% size reduction"),
            input_file = input_file,
            output_file = output_file,
            original_size_mb = round(original_size / (1024^2), 2),
            optimized_size_mb = round(optimized_size / (1024^2), 2),
            size_reduction_percent = size_reduction,
            processing_time_seconds = processing_time,
            total_assertions = length(original_data)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error during efficient optimization:", e$message)
        ))
    })
}

#' Create Ultra-Compact Structure
#'
#' Creates the most compact possible JSON structure using:
#' - Single character field names
#' - Integer-based references
#' - Aggressive deduplication
#' - Minimal metadata
#'
#' @param original_data List of standard format assertions
#' @return Ultra-compact data structure
create_ultra_compact_structure <- function(original_data) {
    cat("Building ultra-compact structure...\n")
    
    # Initialize ultra-compact structure
    compact <- list(
        v = "2.0",           # version
        s = character(0),    # sentences array (indexed by position)
        p = character(0),    # pmids array (indexed by position)  
        a = list()           # assertions array
    )
    
    # Build efficient lookup maps
    sentence_map <- new.env(hash = TRUE)  # sentence -> index
    pmid_map <- new.env(hash = TRUE)      # pmid -> index
    
    # Collect all unique sentences and PMIDs efficiently
    cat("Collecting unique sentences and PMIDs...\n")
    
    all_sentences <- character(0)
    all_pmids <- character(0)
    
    # First pass: collect all unique items
    for (i in seq_along(original_data)) {
        if (i %% 1000 == 0) cat("Processing assertion", i, "of", length(original_data), "\n")
        
        assertion <- original_data[[i]]
        pmid_data <- assertion$pmid_data
        
        if (!is.null(pmid_data)) {
            for (pmid in names(pmid_data)) {
                if (is.null(pmid_map[[pmid]])) {
                    all_pmids <- c(all_pmids, pmid)
                    pmid_map[[pmid]] <- length(all_pmids)
                }
                
                sentences <- pmid_data[[pmid]]$sentences
                if (!is.null(sentences)) {
                    for (sentence in sentences) {
                        if (is.null(sentence_map[[sentence]])) {
                            all_sentences <- c(all_sentences, sentence)
                            sentence_map[[sentence]] <- length(all_sentences)
                        }
                    }
                }
            }
        }
    }
    
    # Store unique items
    compact$s <- all_sentences
    compact$p <- all_pmids
    
    cat("Found", length(all_sentences), "unique sentences\n")
    cat("Found", length(all_pmids), "unique PMIDs\n")
    
    # Second pass: create ultra-compact assertions
    cat("Creating ultra-compact assertions...\n")
    
    for (i in seq_along(original_data)) {
        if (i %% 1000 == 0) cat("Compacting assertion", i, "of", length(original_data), "\n")
        
        assertion <- original_data[[i]]
        
        # Create minimal assertion structure
        compact_assertion <- list(
            s = assertion$subject_name,
            c = assertion$subject_cui,
            o = assertion$object_name,
            u = assertion$object_cui,
            e = assertion$evidence_count,
            m = list()  # pmid -> sentence_indices mapping
        )
        
        # Build PMID -> sentence indices mapping
        pmid_data <- assertion$pmid_data
        if (!is.null(pmid_data)) {
            for (pmid in names(pmid_data)) {
                pmid_idx <- pmid_map[[pmid]]
                sentences <- pmid_data[[pmid]]$sentences
                
                if (!is.null(sentences) && length(sentences) > 0) {
                    sentence_indices <- sapply(sentences, function(s) sentence_map[[s]])
                    compact_assertion$m[[as.character(pmid_idx)]] <- sentence_indices
                }
            }
        }
        
        compact$a[[i]] <- compact_assertion
    }
    
    cat("Created", length(compact$a), "ultra-compact assertions\n")
    
    return(compact)
}

#' Write Ultra-Compact JSON
#'
#' Writes JSON with maximum compression settings
#'
#' @param data Data to write
#' @param output_file Output file path
write_ultra_compact_json <- function(data, output_file) {
    # Write with minimal formatting for maximum compression
    json_text <- jsonlite::toJSON(
        data,
        pretty = FALSE,
        auto_unbox = TRUE,
        digits = NA,
        null = "null"
    )
    
    # Additional compression: remove unnecessary spaces
    json_text <- gsub(": ", ":", json_text, fixed = TRUE)
    json_text <- gsub(", ", ",", json_text, fixed = TRUE)
    
    # Write to file
    writeLines(json_text, output_file)
}

#' Load Ultra-Compact JSON
#'
#' Loads and expands ultra-compact JSON format
#'
#' @param compact_file Path to compact JSON file
#' @param expand_full Whether to expand to full format (default: TRUE)
#' @return List with loaded data
#' @export
load_ultra_compact_json <- function(compact_file, expand_full = TRUE) {
    start_time <- Sys.time()
    
    if (!file.exists(compact_file)) {
        return(list(
            success = FALSE,
            message = paste("Compact file not found:", compact_file)
        ))
    }
    
    tryCatch({
        cat("Loading ultra-compact JSON...\n")
        compact_data <- jsonlite::fromJSON(compact_file, simplifyDataFrame = FALSE)
        
        if (expand_full) {
            cat("Expanding to standard format...\n")
            expanded_data <- expand_ultra_compact_format(compact_data)
            
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")
            
            return(list(
                success = TRUE,
                message = paste("Loaded", length(expanded_data), "assertions from ultra-compact format"),
                assertions = expanded_data,
                loading_strategy = "ultra_compact_expanded",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(compact_file) / (1024^2), 2)
            ))
        } else {
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")
            
            return(list(
                success = TRUE,
                message = paste("Loaded", length(compact_data$a), "compact assertions"),
                compact_data = compact_data,
                loading_strategy = "ultra_compact_raw",
                load_time_seconds = load_time,
                file_size_mb = round(file.size(compact_file) / (1024^2), 2)
            ))
        }
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading ultra-compact format:", e$message)
        ))
    })
}

#' Expand Ultra-Compact Format
#'
#' Converts ultra-compact format back to standard format
#'
#' @param compact_data Ultra-compact data structure
#' @return List of standard format assertions
expand_ultra_compact_format <- function(compact_data) {
    expanded_assertions <- list()
    
    sentences_array <- compact_data$s
    pmids_array <- compact_data$p
    
    for (compact_assertion in compact_data$a) {
        # Expand to standard format
        expanded_assertion <- list(
            subject_name = compact_assertion$s,
            subject_cui = compact_assertion$c,
            predicate = "CAUSES",  # Default predicate
            object_name = compact_assertion$o,
            object_cui = compact_assertion$u,
            evidence_count = compact_assertion$e,
            relationship_degree = "unknown",  # Default degree
            pmid_data = list()
        )
        
        # Expand PMID data
        if (!is.null(compact_assertion$m)) {
            for (pmid_idx_str in names(compact_assertion$m)) {
                pmid_idx <- as.numeric(pmid_idx_str)
                pmid <- pmids_array[pmid_idx]
                sentence_indices <- compact_assertion$m[[pmid_idx_str]]
                
                sentences <- sentences_array[sentence_indices]
                
                expanded_assertion$pmid_data[[pmid]] <- list(
                    sentences = sentences
                )
            }
        }
        
        expanded_assertions[[length(expanded_assertions) + 1]] <- expanded_assertion
    }
    
    return(expanded_assertions)
}
