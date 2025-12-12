# DAG Loading Module
# This module contains functions for loading DAG files from various sources
# Author: Refactored from data_upload.R
# Dependencies: dagitty, igraph, file_scanning.R

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Source required modules
if (file.exists("modules/file_scanning.R")) {
    source("modules/file_scanning.R")
} else if (file.exists("file_scanning.R")) {
    source("file_scanning.R")
}

#' Load DAG from Specified File (with Binary Optimization)
#'
#' Loads a DAG definition from an R file, with automatic binary compilation and loading
#'
#' @param filename Name of the file to load
#' @return List containing success status, message, DAG object, and degree if successful
#' @export
load_dag_from_file <- function(filename) {
    # Check if filename is a full path or just a filename
    if (!file.exists(filename)) {
        # Try looking in the graph_creation/result directory (relative to project root)
        result_path <- file.path("../graph_creation/result", filename)
        if (file.exists(result_path)) {
            filename <- result_path
        } else {
            return(list(success = FALSE, message = paste("File", filename, "not found in current directory or ../graph_creation/result")))
        }
    }

    # If user selected a compiled binary DAG file directly ("*_dag.rds"),
    # load it using the binary loader and return immediately.
    if (grepl("_dag\\.rds$", filename, ignore.case = TRUE)) {
        # Load binary storage module if not already loaded
        if (!exists("load_dag_from_binary")) {
            source("modules/dag_binary_storage.R")
        }

        binary_result <- load_dag_from_binary(filename)
        if (binary_result$success) {
            return(list(
                success = TRUE,
                message = paste("Successfully loaded DAG from compiled binary file -", binary_result$variable_count, "variables"),
                dag = binary_result$dag,
                degree = binary_result$degree,
                filename = filename,
                load_method = "binary_direct",
                load_time_seconds = binary_result$load_time_seconds
            ))
        } else {
            return(list(success = FALSE, message = binary_result$message))
        }
    }

    # Load binary storage module if not already loaded
    if (!exists("load_dag_from_binary")) {
        source("modules/dag_binary_storage.R")
    }

    # Try binary loading first (much faster) starting from an R script
    base_name <- tools::file_path_sans_ext(basename(filename))
    binary_path <- file.path(dirname(filename), paste0(base_name, "_dag.rds"))

    if (file.exists(binary_path)) {
        # Check if binary is newer than source
        r_mtime <- file.mtime(filename)
        binary_mtime <- file.mtime(binary_path)

        if (binary_mtime >= r_mtime) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Loading from binary DAG file (fastest mode)...\n")
            }
            binary_result <- load_dag_from_binary(binary_path)

            if (binary_result$success) {
                return(list(
                    success = TRUE,
                    message = paste("Successfully loaded DAG from binary file -", binary_result$variable_count, "variables"),
                    dag = binary_result$dag,
                    degree = binary_result$degree,
                    filename = filename,
                    load_method = "binary",
                    load_time_seconds = binary_result$load_time_seconds
                ))
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Binary loading failed, falling back to R script:", binary_result$message, "\n")
                }
            }
        } else {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Binary file is older than source, recompiling...\n")
            }
            compile_result <- compile_dag_to_binary(filename, force_regenerate = TRUE)
            if (compile_result$success) {
                binary_result <- load_dag_from_binary(binary_path)
                if (binary_result$success) {
                    return(list(
                        success = TRUE,
                        message = paste("Recompiled and loaded DAG -", binary_result$variable_count, "variables"),
                        dag = binary_result$dag,
                        degree = binary_result$degree,
                        filename = filename,
                        load_method = "binary_recompiled",
                        load_time_seconds = binary_result$load_time_seconds
                    ))
                }
            }
        }
    } else {
        # No binary file exists, try to create one
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("No binary file found, compiling for future use...\n")
        }
        compile_result <- compile_dag_to_binary(filename)
        if (compile_result$success) {
            binary_result <- load_dag_from_binary(binary_path)
            if (binary_result$success) {
                return(list(
                    success = TRUE,
                    message = paste("Compiled and loaded DAG -", binary_result$variable_count, "variables"),
                    dag = binary_result$dag,
                    degree = binary_result$degree,
                    filename = filename,
                    load_method = "binary_first_time",
                    load_time_seconds = binary_result$load_time_seconds
                ))
            }
        }
    }

    # Fallback to traditional R script loading
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
        cat("Loading from R script (traditional mode)...\n")
    }
    tryCatch({
        start_time <- Sys.time()

        # Create a new environment to source the file
        file_env <- new.env()

        # Source the file in the new environment
        source(filename, local = file_env)

        # Check if g variable was created
        if (exists("g", envir = file_env) && !is.null(file_env$g)) {
            # Extract degree from filename
            degree <- extract_degree_from_filename(filename)
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")

            return(list(
                success = TRUE,
                message = paste("Successfully loaded DAG from R script -", length(names(file_env$g)), "variables"),
                dag = file_env$g,
                degree = degree,
                filename = filename,
                load_method = "r_script",
                load_time_seconds = round(load_time, 3)
            ))
        } else {
            return(list(success = FALSE, message = paste("No 'g' variable found in", filename)))
        }
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error loading", filename, ":", e$message)))
    })
}

#' Validate DAG Object
#' 
#' Validates that a loaded object is a proper dagitty DAG
#' 
#' @param dag_object Object to validate
#' @return List containing validation results
#' @export
validate_dag_object <- function(dag_object) {
    if (is.null(dag_object)) {
        return(list(valid = FALSE, message = "DAG object is NULL"))
    }
    
    tryCatch({
        # Check if it's a dagitty object
        if (!inherits(dag_object, "dagitty")) {
            return(list(valid = FALSE, message = "Object is not a dagitty DAG"))
        }
        
        # Try to get node names
        node_names <- names(dag_object)
        if (length(node_names) == 0) {
            return(list(valid = FALSE, message = "DAG contains no nodes"))
        }
        
        # Try to convert to igraph (this will catch structural issues)
        tryCatch({
            ig <- dagitty::dagitty2graph(dag_object)
        }, error = function(e) {
            return(list(valid = FALSE, message = paste("DAG structure error:", e$message)))
        })
        
        return(list(valid = TRUE, message = "DAG is valid", node_count = length(node_names)))
        
    }, error = function(e) {
        return(list(valid = FALSE, message = paste("Validation error:", e$message)))
    })
}

