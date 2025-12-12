# Assertions Loading Module
# This module handles loading and managing causal assertions data from JSON files
# Author: Refactored from data_upload.R
# Dependencies: jsonlite

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Load Causal Assertions Data
#'
#' Loads causal assertions JSON file with PMID information
#' Uses optimized loading strategies based on file size
#'
#' @param filename Name of the causal assertions file (e.g., "causal_assertions_2.json")
#' @param degree Degree parameter to match with specific assertions file
#' @param search_dirs Vector of directories to search for the file
#' @param force_full_load Force loading of complete data (default: FALSE)
#' @param use_optimization Use optimized loading system (default: TRUE)
#' @return List containing success status, message, and assertions data if successful
#' @export
load_causal_assertions <- function(filename = NULL, degree = NULL,
                                 search_dirs = c("../graph_creation/result", "../graph_creation/output"),
                                 force_full_load = FALSE, use_optimization = TRUE) {
    # If no filename provided, try to find the appropriate causal_assertions file
    if (is.null(filename)) {
        # If degree is provided, look for the specific file first
        if (!is.null(degree) && is.numeric(degree) && degree >= 1 && degree <= 3) {
            target_filename <- paste0("causal_assertions_", degree, ".json")
            for (dir in search_dirs) {
                if (dir.exists(dir)) {
                    target_path <- file.path(dir, target_filename)
                    if (file.exists(target_path)) {
                        filename <- target_path
                        break
                    }
                }
            }
        }

        # If still no filename, try to find the most recent causal_assertions file
        if (is.null(filename)) {
            for (dir in search_dirs) {
                if (dir.exists(dir)) {
                    # Look for causal_assertions files with degree suffix
                    assertion_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
                    if (length(assertion_files) > 0) {
                        # Use the most recently modified file
                        file_info <- file.info(assertion_files)
                        filename <- assertion_files[which.max(file_info$mtime)]
                        break
                    }

                    # Fallback to original causal_assertions.json
                    fallback_file <- file.path(dir, "causal_assertions.json")
                    if (file.exists(fallback_file)) {
                        filename <- fallback_file
                        break
                    }
                }
            }
        }

        if (is.null(filename)) {
            return(list(
                success = FALSE,
                message = "No causal assertions files found in search directories",
                assertions = list()
            ))
        }
    } else {
        # Check if filename is a full path or just a filename
        if (!file.exists(filename)) {
            # Try looking in search directories
            found <- FALSE
            for (dir in search_dirs) {
                test_path <- file.path(dir, filename)
                if (file.exists(test_path)) {
                    filename <- test_path
                    found <- TRUE
                    break
                }
            }

            if (!found) {
                return(list(
                    success = FALSE,
                    message = paste("Causal assertions file not found:", filename),
                    assertions = list()
                ))
            }
        }
    }

    # Use optimized loading if enabled
    if (use_optimization) {
        # Source the new optimized loader module if not already loaded
        if (!exists("load_causal_assertions_unified")) {
            tryCatch({
                if (file.exists("modules/optimized_loader.R")) {
                    source("modules/optimized_loader.R")
                } else if (file.exists("optimized_loader.R")) {
                    source("optimized_loader.R")
                }
            }, error = function(e) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Warning: Could not load optimized loader module:", e$message, "\n")
                    cat("Falling back to standard loading...\n")
                }
                use_optimization <- FALSE
            })
        }

        if (use_optimization && exists("load_causal_assertions_unified")) {
            # Use the unified loader that handles both standard and optimized formats
            result <- load_causal_assertions_unified(filename)

            if (result$success) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Loaded using optimized loader:", result$message, "\n")
                    cat("Loading strategy:", result$loading_strategy, "\n")
                    cat("Load time:", round(result$load_time_seconds, 3), "seconds\n")
                }

                return(list(
                    success = TRUE,
                    message = result$message,
                    assertions = result$assertions,
                    loading_strategy = result$loading_strategy,
                    load_time_seconds = result$load_time_seconds,
                    file_size_mb = result$file_size_mb
                ))
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Optimized loader failed:", result$message, "\n")
                    cat("Falling back to standard loading...\n")
                }
                use_optimization <- FALSE
            }
        }
    }

    # Standard JSON loading
    tryCatch({
        # Load JSON data with error handling for malformed JSON
        assertions_data <- tryCatch({
            jsonlite::fromJSON(filename, simplifyDataFrame = FALSE)
        }, error = function(e) {
            # If JSON parsing fails, try to read and fix common issues
            warning(paste("JSON parsing failed for", filename, ":", e$message))
            return(NULL)
        })

        if (is.null(assertions_data)) {
            return(list(
                success = FALSE,
                message = paste("Failed to parse JSON file:", basename(filename)),
                assertions = list()
            ))
        }

        # Validate the structure
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty causal assertions data",
                assertions = list()
            ))
        }

        # Check if first item has expected structure
        first_item <- assertions_data[[1]]
        required_fields <- c("subject_name", "object_name", "pmid_data")
        missing_fields <- setdiff(required_fields, names(first_item))

        if (length(missing_fields) > 0) {
            return(list(
                success = FALSE,
                message = paste("Missing required fields in assertions data:", paste(missing_fields, collapse = ", ")),
                assertions = list()
            ))
        }

        return(list(
            success = TRUE,
            message = paste("Successfully loaded", length(assertions_data), "causal assertions from", basename(filename)),
            assertions = assertions_data,
            filename = filename
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading causal assertions:", e$message),
            assertions = list()
        ))
    })
}

