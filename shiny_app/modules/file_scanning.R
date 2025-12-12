# File Scanning Module
# This module contains functions for scanning and discovering DAG files
# Author: Refactored from data_upload.R
# Dependencies: None

#' Scan for Available DAG Files
#'
#' Scans the current directory for R files that might contain DAG definitions
#' and compiled binary DAG files ("*_dag.rds").
#'
#' @param exclude_files Vector of filenames to exclude from scanning (default: system files)
#' @return Vector of valid DAG filenames
#' @export
scan_for_dag_files <- function(exclude_files = c("app.R", "dag_data.R", "dag_visualization.R",
                                                 "node_information.R", "statistics.R", "data_upload.R")) {
    # Look for R files that might contain DAG definitions in graph_creation/result directory
    # Since we're running from shiny_app/, we need to go up one level to reach graph_creation/
    result_dir <- "../graph_creation/result"
    if (!dir.exists(result_dir)) {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Warning: graph_creation/result directory does not exist. Creating it...\n")
        }
        dir.create(result_dir, recursive = TRUE)
    }
    r_files <- list.files(path = result_dir, pattern = "\\.(R|r)$", full.names = FALSE)

    # Filter out system files
    dag_files <- r_files[!r_files %in% exclude_files]

    # Check if R files contain dagitty definitions
    valid_dag_files <- c()

    for (file in dag_files) {
        file_path <- file.path(result_dir, file)
        if (file.exists(file_path)) {
            tryCatch({
                # Read first few lines to check for dagitty syntax
                lines <- readLines(file_path, n = 50, warn = FALSE)
                content <- paste(lines, collapse = " ")

                # Check for dagitty syntax
                if (grepl("dagitty\\s*\\(", content, ignore.case = TRUE) ||
                    grepl("dag\\s*\\{", content, ignore.case = TRUE)) {
                    valid_dag_files <- c(valid_dag_files, file)
                }
            }, error = function(e) {
                # Skip files that can't be read
            })
        }
    }

    # Also include compiled binary DAG files ("*_dag.rds") when no matching R script exists
    binary_files <- list.files(path = result_dir, pattern = "_dag\\.rds$", full.names = FALSE)
    if (length(binary_files) > 0) {
        for (bfile in binary_files) {
            # Corresponding source script would be <base>.R or <base>.r
            base_name <- sub("_dag\\.rds$", "", bfile)
            r_candidates <- paste0(base_name, c(".R", ".r"))
            if (!any(r_candidates %in% r_files)) {
                valid_dag_files <- c(valid_dag_files, bfile)
            }
        }
    }

    # Return unique, sorted file list
    valid_dag_files <- sort(unique(valid_dag_files))
    return(valid_dag_files)
}

#' Get Default DAG Files
#' 
#' Returns a list of default filenames to try loading
#' 
#' @return Vector of default filenames
#' @export
get_default_dag_files <- function() {
    return(c("graph.R", "my_dag.R", "dag.R", "consolidated.R"))
}

#' Extract Degree from Filename
#'
#' Extracts the degree parameter from a DAG filename (e.g., "degree_2.R" -> 2)
#'
#' @param filename Name of the DAG file
#' @return Integer degree value, or NULL if not found
#' @export
extract_degree_from_filename <- function(filename) {
    if (is.null(filename) || !is.character(filename)) {
        return(NULL)
    }

    # Extract basename to handle full paths
    base_name <- basename(filename)

    # Try to extract degree from various patterns
    # Pattern 1: degree_N.R or degree_N_dag.rds
    if (grepl("degree[_-]?(\\d+)", base_name, ignore.case = TRUE)) {
        degree_match <- regmatches(base_name, regexpr("degree[_-]?(\\d+)", base_name, ignore.case = TRUE))
        degree_num <- as.integer(gsub("\\D", "", degree_match))
        if (!is.na(degree_num)) {
            return(degree_num)
        }
    }

    # Pattern 2: N_hop or N-hop
    if (grepl("(\\d+)[_-]?hop", base_name, ignore.case = TRUE)) {
        hop_match <- regmatches(base_name, regexpr("(\\d+)[_-]?hop", base_name, ignore.case = TRUE))
        degree_num <- as.integer(gsub("\\D", "", hop_match))
        if (!is.na(degree_num)) {
            return(degree_num)
        }
    }

    # Pattern 3: Just a number in the filename
    if (grepl("\\d+", base_name)) {
        numbers <- as.integer(regmatches(base_name, gregexpr("\\d+", base_name))[[1]])
        if (length(numbers) > 0) {
            # Return the first number found
            return(numbers[1])
        }
    }

    # Default to NULL if no degree found
    return(NULL)
}

#' Create Fallback DAG
#' 
#' Creates a simple fallback DAG when no files are found
#' 
#' @return dagitty DAG object
#' @export
create_fallback_dag <- function() {
    return(dagitty::dagitty('dag {
        Exposure_Condition [exposure]
        Outcome_Condition [outcome]
        Surgical_margins
        PeptidylDipeptidase_A
        Exposure_Condition -> Surgical_margins
        Surgical_margins -> PeptidylDipeptidase_A
        PeptidylDipeptidase_A -> Outcome_Condition
    }'))
}

