# Streaming JSON Parser for Large Causal Assertions Files
#
# This module provides memory-efficient streaming JSON parsing for large files
# (100MB+) without loading everything into memory at once.

library(jsonlite)
library(R6)

#' Streaming JSON Parser Class
#'
#' Provides chunked reading and progressive parsing of large JSON files
StreamingJSONParser <- R6Class("StreamingJSONParser",
    public = list(
        #' @field file_path Path to the JSON file
        file_path = NULL,
        
        #' @field chunk_size Number of assertions to process at once
        chunk_size = 100,
        
        #' @field current_position Current position in file
        current_position = 0,
        
        #' @field total_assertions Total number of assertions (estimated)
        total_assertions = NULL,
        
        #' @field connection File connection
        connection = NULL,
        
        #' Initialize the streaming parser
        #'
        #' @param file_path Path to the JSON file
        #' @param chunk_size Number of assertions to process per chunk
        initialize = function(file_path, chunk_size = 100) {
            self$file_path <- file_path
            self$chunk_size <- chunk_size
            
            if (!file.exists(file_path)) {
                stop("File not found: ", file_path)
            }
            
            # Estimate total assertions by sampling
            self$estimate_total_assertions()
        },
        
        #' Estimate total number of assertions
        estimate_total_assertions = function() {
            tryCatch({
                # Read first few KB to estimate structure
                con <- file(self$file_path, "r")
                sample_text <- readChar(con, 50000, useBytes = TRUE)
                close(con)
                
                # Count assertion patterns in sample
                assertion_pattern <- '"subject_name":'
                sample_count <- length(gregexpr(assertion_pattern, sample_text, fixed = TRUE)[[1]])
                
                if (sample_count > 0) {
                    file_size <- file.size(self$file_path)
                    sample_size <- nchar(sample_text)
                    self$total_assertions <- round((file_size / sample_size) * sample_count)
                    cat("Estimated", self$total_assertions, "assertions in file\n")
                } else {
                    self$total_assertions <- 1000  # Default estimate
                }
            }, error = function(e) {
                self$total_assertions <- 1000
                warning("Could not estimate file size: ", e$message)
            })
        },
        
        #' Open file connection for streaming
        open_connection = function() {
            if (is.null(self$connection) || !isOpen(self$connection)) {
                self$connection <- file(self$file_path, "r")
            }
        },
        
        #' Close file connection
        close_connection = function() {
            if (!is.null(self$connection) && isOpen(self$connection)) {
                close(self$connection)
                self$connection <- NULL
            }
        },
        
        #' Read next chunk of assertions using line-by-line parsing
        #'
        #' @return List containing chunk data and metadata
        read_chunk = function() {
            self$open_connection()
            
            tryCatch({
                chunk_assertions <- list()
                assertion_count <- 0
                current_assertion <- ""
                bracket_depth <- 0
                in_assertion <- FALSE
                
                # Skip to start of array if at beginning
                if (self$current_position == 0) {
                    while (TRUE) {
                        line <- readLines(self$connection, n = 1, warn = FALSE)
                        if (length(line) == 0) break
                        if (grepl("\\[", line)) break
                    }
                }
                
                while (assertion_count < self$chunk_size) {
                    line <- readLines(self$connection, n = 1, warn = FALSE)
                    if (length(line) == 0) break  # End of file
                    
                    # Skip empty lines and array closing
                    line <- trimws(line)
                    if (nchar(line) == 0 || line == "]") next
                    
                    # Remove trailing comma
                    if (endsWith(line, ",")) {
                        line <- substr(line, 1, nchar(line) - 1)
                    }
                    
                    current_assertion <- paste0(current_assertion, line, "\n")
                    
                    # Count braces to detect complete assertion
                    for (char in strsplit(line, "")[[1]]) {
                        if (char == "{") {
                            bracket_depth <- bracket_depth + 1
                            if (!in_assertion) in_assertion <- TRUE
                        } else if (char == "}") {
                            bracket_depth <- bracket_depth - 1
                        }
                    }
                    
                    # Complete assertion found
                    if (in_assertion && bracket_depth == 0) {
                        tryCatch({
                            assertion_data <- jsonlite::fromJSON(current_assertion, simplifyDataFrame = FALSE)
                            chunk_assertions[[length(chunk_assertions) + 1]] <- assertion_data
                            assertion_count <- assertion_count + 1
                        }, error = function(e) {
                            warning("Failed to parse assertion: ", e$message)
                        })
                        
                        current_assertion <- ""
                        in_assertion <- FALSE
                    }
                }
                
                self$current_position <- self$current_position + assertion_count
                
                return(list(
                    data = chunk_assertions,
                    has_more = assertion_count == self$chunk_size,
                    chunk_size = assertion_count,
                    position = self$current_position
                ))
                
            }, error = function(e) {
                warning("Error reading chunk: ", e$message)
                return(list(
                    data = list(),
                    has_more = FALSE,
                    chunk_size = 0,
                    position = self$current_position
                ))
            })
        },
        
        #' Process entire file in chunks with callback
        #'
        #' @param callback Function to call for each chunk
        #' @param progress_callback Optional progress callback
        process_file = function(callback, progress_callback = NULL) {
            self$current_position <- 0
            total_processed <- 0
            
            cat("Starting streaming processing of", basename(self$file_path), "\n")
            start_time <- Sys.time()
            
            while (TRUE) {
                chunk_result <- self$read_chunk()
                
                if (length(chunk_result$data) == 0) {
                    break  # End of file
                }
                
                # Process chunk with callback
                callback(chunk_result$data, chunk_result$position)
                
                total_processed <- total_processed + chunk_result$chunk_size
                
                # Progress reporting
                if (!is.null(progress_callback)) {
                    progress_callback(total_processed, self$total_assertions)
                } else {
                    if (total_processed %% 500 == 0) {
                        elapsed <- as.numeric(Sys.time() - start_time, units = "secs")
                        rate <- total_processed / elapsed
                        cat("Processed", total_processed, "assertions (", round(rate, 1), "/sec)\n")
                    }
                }
                
                if (!chunk_result$has_more) {
                    break
                }
            }
            
            self$close_connection()
            
            elapsed_time <- as.numeric(Sys.time() - start_time, units = "secs")
            cat("Streaming processing completed:", total_processed, "assertions in", round(elapsed_time, 2), "seconds\n")
            
            return(total_processed)
        }
    ),
    
    private = list(
        finalize = function() {
            self$close_connection()
        }
    )
)

#' Load Large JSON File with Streaming
#'
#' Efficiently loads large causal assertions files using streaming parser
#'
#' @param file_path Path to the JSON file
#' @param max_assertions Maximum number of assertions to load (NULL for all)
#' @param chunk_size Number of assertions to process per chunk
#' @return List containing loaded data and metadata
#' @export
load_large_json_streaming <- function(file_path, max_assertions = NULL, chunk_size = 100) {
    parser <- StreamingJSONParser$new(file_path, chunk_size)
    
    all_data <- list()
    total_loaded <- 0
    
    # Callback to collect data
    collect_callback <- function(chunk_data, position) {
        for (assertion in chunk_data) {
            if (!is.null(max_assertions) && total_loaded >= max_assertions) {
                return()
            }
            all_data[[length(all_data) + 1]] <<- assertion
            total_loaded <<- total_loaded + 1
        }
    }
    
    # Process file
    start_time <- Sys.time()
    parser$process_file(collect_callback)
    load_time <- as.numeric(Sys.time() - start_time, units = "secs")
    
    return(list(
        success = TRUE,
        message = paste("Loaded", length(all_data), "assertions using streaming parser"),
        assertions = all_data,
        load_time_seconds = load_time,
        loading_strategy = "streaming"
    ))
}
