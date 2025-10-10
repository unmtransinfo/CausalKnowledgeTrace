# Separate Sentence Storage System
# 
# This module provides functionality to separate sentence data from main
# causal assertions files to reduce file sizes and improve loading performance.

library(jsonlite)

#' Separate Sentences from Assertions
#'
#' Extracts sentence data from causal assertions and saves it separately
#'
#' @param assertions_file Path to the main causal assertions JSON file
#' @param output_dir Directory to save the separated files
#' @param degree Degree parameter for file naming
#' @return List with success status and file paths
#' @export
separate_sentences_from_assertions <- function(assertions_file, output_dir = NULL, degree = NULL) {
    # Re-enabled optimized lightweight file creation
    cat("Creating lightweight format for", basename(assertions_file), "\n")

    if (!file.exists(assertions_file)) {
        return(list(
            success = FALSE,
            message = paste("Assertions file not found:", assertions_file)
        ))
    }
    
    # Determine output directory
    if (is.null(output_dir)) {
        output_dir <- dirname(assertions_file)
    }
    
    # Determine degree from filename if not provided
    if (is.null(degree)) {
        filename <- basename(assertions_file)
        degree_match <- regmatches(filename, regexpr("\\d+", filename))
        if (length(degree_match) > 0) {
            degree <- as.numeric(degree_match[1])
        } else {
            degree <- "unknown"
        }
    }
    
    tryCatch({
        cat("Loading assertions file for sentence separation...\n")
        start_time <- Sys.time()
        
        # Load the full assertions data
        assertions_data <- jsonlite::fromJSON(assertions_file, simplifyDataFrame = FALSE)
        
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty assertions data"
            ))
        }
        
        # Separate sentences and create lightweight assertions
        sentences_data <- list()
        lightweight_assertions <- list()
        
        for (i in seq_along(assertions_data)) {
            assertion <- assertions_data[[i]]
            
            # Create lightweight assertion (without pmid_data)
            # Extract PMID list from pmid_data keys (optimized structure)
            pmid_list <- if (!is.null(assertion$pmid_data)) {
                names(assertion$pmid_data)
            } else if (!is.null(assertion$pmid_list)) {
                assertion$pmid_list  # Backward compatibility
            } else {
                character(0)
            }

            lightweight_assertion <- list(
                subject_name = assertion$subject_name,
                subject_cui = assertion$subject_cui,
                predicate = assertion$predicate,
                object_name = assertion$object_name,
                object_cui = assertion$object_cui,
                evidence_count = assertion$evidence_count,
                relationship_degree = assertion$relationship_degree,
                pmid_list = pmid_list
            )
            
            # Extract sentence data if it exists
            if (!is.null(assertion$pmid_data)) {
                edge_key <- paste(assertion$subject_name, assertion$object_name, sep = " -> ")
                sentences_data[[edge_key]] <- assertion$pmid_data
            }
            
            lightweight_assertions[[i]] <- lightweight_assertion
        }
        
        # Generate output filenames
        base_name <- paste0("causal_assertions_", degree)
        lightweight_file <- file.path(output_dir, paste0(base_name, "_lightweight.json"))
        sentences_file <- file.path(output_dir, paste0("sentences_", degree, ".json"))
        
        # Save lightweight assertions
        cat("Saving lightweight assertions...\n")
        jsonlite::write_json(lightweight_assertions, lightweight_file, pretty = TRUE, auto_unbox = TRUE)
        
        # Save sentences data
        cat("Saving sentences data...\n")
        jsonlite::write_json(sentences_data, sentences_file, pretty = TRUE, auto_unbox = TRUE)
        
        # Calculate file size reductions
        original_size <- file.size(assertions_file)
        lightweight_size <- file.size(lightweight_file)
        sentences_size <- file.size(sentences_file)
        
        reduction_percent <- round((1 - lightweight_size / original_size) * 100, 1)
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        
        cat("Sentence separation completed in", round(load_time, 2), "seconds\n")
        cat("Original file:", round(original_size / (1024^2), 2), "MB\n")
        cat("Lightweight file:", round(lightweight_size / (1024^2), 2), "MB\n")
        cat("Sentences file:", round(sentences_size / (1024^2), 2), "MB\n")
        cat("Size reduction:", reduction_percent, "%\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully separated sentences with", reduction_percent, "% size reduction"),
            lightweight_file = lightweight_file,
            sentences_file = sentences_file,
            original_size_mb = round(original_size / (1024^2), 2),
            lightweight_size_mb = round(lightweight_size / (1024^2), 2),
            sentences_size_mb = round(sentences_size / (1024^2), 2),
            reduction_percent = reduction_percent,
            processing_time_seconds = load_time
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error separating sentences:", e$message)
        ))
    })
}

#' Load Lightweight Assertions
#'
#' Loads lightweight assertions without sentence data
#'
#' @param lightweight_file Path to lightweight assertions file
#' @return List with loaded assertions
#' @export
load_lightweight_assertions <- function(lightweight_file) {
    if (!file.exists(lightweight_file)) {
        return(list(
            success = FALSE,
            message = paste("Lightweight assertions file not found:", lightweight_file),
            assertions = list()
        ))
    }
    
    tryCatch({
        cat("Loading lightweight assertions...\n")
        start_time <- Sys.time()
        
        assertions_data <- jsonlite::fromJSON(lightweight_file, simplifyDataFrame = FALSE)
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        cat("Loaded", length(assertions_data), "lightweight assertions in", round(load_time, 2), "seconds\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully loaded", length(assertions_data), "lightweight assertions"),
            assertions = assertions_data,
            load_time_seconds = load_time
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading lightweight assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Load Sentences for Edge
#'
#' Loads sentence data for a specific edge on demand
#'
#' @param sentences_file Path to sentences file
#' @param subject_name Subject node name
#' @param object_name Object node name
#' @return List with sentence data for the edge
#' @export
load_sentences_for_edge <- function(sentences_file, subject_name, object_name) {
    if (!file.exists(sentences_file)) {
        return(list(
            success = FALSE,
            message = "Sentences file not found",
            sentences = list()
        ))
    }
    
    # Create edge key
    edge_key <- paste(subject_name, object_name, sep = " -> ")
    
    tryCatch({
        # Load sentences data (this could be optimized further with indexing)
        sentences_data <- jsonlite::fromJSON(sentences_file, simplifyDataFrame = FALSE)
        
        if (edge_key %in% names(sentences_data)) {
            return(list(
                success = TRUE,
                message = "Sentences found for edge",
                sentences = sentences_data[[edge_key]]
            ))
        } else {
            return(list(
                success = FALSE,
                message = "No sentences found for this edge",
                sentences = list()
            ))
        }
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading sentences:", e$message),
            sentences = list()
        ))
    })
}

#' Create Sentence Loader Function
#'
#' Creates a function that can load sentences on demand for any edge
#'
#' @param sentences_file Path to sentences file
#' @return Function for loading sentences
#' @export
create_sentence_loader <- function(sentences_file) {
    # Cache the sentences data in memory for faster access
    sentences_cache <- NULL
    
    function(subject_name, object_name) {
        # Load sentences data if not cached
        if (is.null(sentences_cache)) {
            if (file.exists(sentences_file)) {
                tryCatch({
                    sentences_cache <<- jsonlite::fromJSON(sentences_file, simplifyDataFrame = FALSE)
                    cat("Cached sentences data from", basename(sentences_file), "\n")
                }, error = function(e) {
                    cat("Error caching sentences data:", e$message, "\n")
                    return(list())
                })
            } else {
                return(list())
            }
        }
        
        # Create edge key and return sentences
        edge_key <- paste(subject_name, object_name, sep = " -> ")
        if (edge_key %in% names(sentences_cache)) {
            return(sentences_cache[[edge_key]])
        } else {
            return(list())
        }
    }
}

#' Check for Separated Files
#'
#' Checks if separated files exist for a given degree value
#'
#' @param degree Degree parameter
#' @param search_dirs Directories to search in
#' @return List with file paths if they exist
#' @export
check_for_separated_files <- function(degree, search_dirs = c("../graph_creation/result", "../graph_creation/output")) {
    lightweight_filename <- paste0("causal_assertions_", degree, "_lightweight.json")
    sentences_filename <- paste0("sentences_", degree, ".json")
    
    for (dir in search_dirs) {
        if (dir.exists(dir)) {
            lightweight_path <- file.path(dir, lightweight_filename)
            sentences_path <- file.path(dir, sentences_filename)
            
            if (file.exists(lightweight_path) && file.exists(sentences_path)) {
                return(list(
                    found = TRUE,
                    lightweight_file = lightweight_path,
                    sentences_file = sentences_path
                ))
            }
        }
    }
    
    return(list(found = FALSE))
}

#' Get Separation Statistics
#'
#' Returns statistics about file separation benefits
#'
#' @param degree Degree parameter
#' @param search_dirs Directories to search in
#' @return List with statistics
#' @export
get_separation_stats <- function(degree, search_dirs = c("../graph_creation/result", "../graph_creation/output")) {
    original_filename <- paste0("causal_assertions_", degree, ".json")
    separated_files <- check_for_separated_files(degree, search_dirs)
    
    if (!separated_files$found) {
        return(list(
            available = FALSE,
            message = "Separated files not found"
        ))
    }
    
    # Find original file
    original_path <- NULL
    for (dir in search_dirs) {
        test_path <- file.path(dir, original_filename)
        if (file.exists(test_path)) {
            original_path <- test_path
            break
        }
    }
    
    if (is.null(original_path)) {
        return(list(
            available = FALSE,
            message = "Original file not found for comparison"
        ))
    }
    
    # Calculate statistics
    original_size <- file.size(original_path)
    lightweight_size <- file.size(separated_files$lightweight_file)
    sentences_size <- file.size(separated_files$sentences_file)
    
    reduction_percent <- round((1 - lightweight_size / original_size) * 100, 1)
    
    return(list(
        available = TRUE,
        original_size_mb = round(original_size / (1024^2), 2),
        lightweight_size_mb = round(lightweight_size / (1024^2), 2),
        sentences_size_mb = round(sentences_size / (1024^2), 2),
        reduction_percent = reduction_percent,
        total_separated_size_mb = round((lightweight_size + sentences_size) / (1024^2), 2)
    ))
}
