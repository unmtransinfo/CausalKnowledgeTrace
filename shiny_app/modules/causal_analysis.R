# Causal Analysis Module
# This module contains functions for causal inference analysis using DAGitty
# Author: Created for minimal sufficient adjustment sets functionality
# Dependencies: dagitty, dplyr

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required for causal analysis")
if (!require(dplyr)) stop("dplyr package is required")

#' Calculate Minimal Sufficient Adjustment Sets
#' 
#' Identifies minimal sufficient adjustment sets for estimating causal effects
#' 
#' @param dag_object dagitty DAG object
#' @param exposure Name of exposure variable (if NULL, uses DAG-defined exposures)
#' @param outcome Name of outcome variable (if NULL, uses DAG-defined outcomes)
#' @param effect Type of effect to identify ("total" or "direct")
#' @param max_results Maximum number of adjustment sets to return
#' @return List containing adjustment sets and analysis information
#' @export
calculate_adjustment_sets <- function(dag_object, exposure = NULL, outcome = NULL, 
                                    effect = "total", max_results = 10) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            adjustment_sets = list(),
            exposure = NULL,
            outcome = NULL
        ))
    }
    
    tryCatch({
        # Get adjustment sets using dagitty
        adj_sets <- adjustmentSets(
            dag_object, 
            exposure = exposure, 
            outcome = outcome,
            type = "minimal",
            effect = effect,
            max.results = max_results
        )
        
        # Convert to list format for easier handling
        sets_list <- list()
        if (length(adj_sets) > 0) {
            for (i in seq_along(adj_sets)) {
                set_vars <- as.character(adj_sets[[i]])
                sets_list[[i]] <- list(
                    id = i,
                    variables = set_vars,
                    size = length(set_vars),
                    description = if (length(set_vars) == 0) "Empty set (no adjustment needed)" 
                                 else paste(set_vars, collapse = ", ")
                )
            }
        }
        
        # Get exposure and outcome variables
        exp_vars <- if (is.null(exposure)) exposures(dag_object) else exposure
        out_vars <- if (is.null(outcome)) outcomes(dag_object) else outcome
        
        return(list(
            success = TRUE,
            message = paste("Found", length(sets_list), "minimal sufficient adjustment set(s)"),
            adjustment_sets = sets_list,
            exposure = exp_vars,
            outcome = out_vars,
            effect_type = effect,
            total_sets = length(sets_list)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error calculating adjustment sets:", e$message),
            adjustment_sets = list(),
            exposure = exposure,
            outcome = outcome
        ))
    })
}

#' Identify Instrumental Variables
#' 
#' Finds instrumental variables for causal identification
#' 
#' @param dag_object dagitty DAG object
#' @param exposure Name of exposure variable
#' @param outcome Name of outcome variable
#' @return List containing instrumental variables information
#' @export
find_instrumental_variables <- function(dag_object, exposure = NULL, outcome = NULL) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            instruments = character(0)
        ))
    }
    
    tryCatch({
        # Find instrumental variables
        instruments <- instrumentalVariables(dag_object, exposure = exposure, outcome = outcome)
        
        # Convert to character vector
        instrument_vars <- character(0)
        if (length(instruments) > 0) {
            instrument_vars <- as.character(instruments)
        }
        
        return(list(
            success = TRUE,
            message = if (length(instrument_vars) > 0) 
                     paste("Found", length(instrument_vars), "instrumental variable(s)")
                     else "No instrumental variables found",
            instruments = instrument_vars,
            count = length(instrument_vars)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error finding instrumental variables:", e$message),
            instruments = character(0)
        ))
    })
}

#' Analyze Causal Paths
#' 
#' Identifies and analyzes causal paths between variables
#' 
#' @param dag_object dagitty DAG object
#' @param from Source variable
#' @param to Target variable
#' @param limit Maximum number of paths to return
#' @return List containing path analysis information
#' @export
analyze_causal_paths <- function(dag_object, from = NULL, to = NULL, limit = 10) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            paths = list()
        ))
    }
    
    if (is.null(from) || is.null(to)) {
        return(list(
            success = FALSE,
            message = "Both 'from' and 'to' variables must be specified",
            paths = list()
        ))
    }
    
    tryCatch({
        # Find paths between variables
        all_paths <- paths(dag_object, from = from, to = to, limit = limit)
        
        # Process paths into structured format
        paths_list <- list()
        if (length(all_paths$paths) > 0) {
            for (i in seq_along(all_paths$paths)) {
                path_vars <- all_paths$paths[[i]]
                paths_list[[i]] <- list(
                    id = i,
                    variables = path_vars,
                    length = length(path_vars),
                    description = paste(path_vars, collapse = " -> "),
                    is_open = all_paths$open[i] %in% TRUE
                )
            }
        }
        
        return(list(
            success = TRUE,
            message = paste("Found", length(paths_list), "path(s) from", from, "to", to),
            paths = paths_list,
            from = from,
            to = to,
            total_paths = length(paths_list)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error analyzing paths:", e$message),
            paths = list()
        ))
    })
}

#' Get Available Variables for Causal Analysis
#'
#' Extracts all variables from a DAG for selection in causal analysis
#'
#' @param dag_object dagitty DAG object
#' @return List containing variable information
#' @export
get_dag_variables <- function(dag_object) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            variables = character(0),
            exposures = character(0),
            outcomes = character(0)
        ))
    }

    tryCatch({
        # Get all variables
        all_vars <- names(dag_object)

        # Get exposure and outcome variables
        exp_vars <- exposures(dag_object)
        out_vars <- outcomes(dag_object)

        # Create variable categories
        other_vars <- setdiff(all_vars, c(exp_vars, out_vars))

        return(list(
            success = TRUE,
            message = paste("Found", length(all_vars), "variables in DAG"),
            variables = all_vars,
            exposures = exp_vars,
            outcomes = out_vars,
            other_variables = other_vars,
            total_count = length(all_vars)
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error extracting variables:", e$message),
            variables = character(0),
            exposures = character(0),
            outcomes = character(0)
        ))
    })
}

#' Format Adjustment Sets for Display
#'
#' Creates formatted text output for adjustment sets results
#'
#' @param adjustment_result Result from calculate_adjustment_sets function
#' @return Formatted text string
#' @export
format_adjustment_sets_display <- function(adjustment_result) {
    if (!adjustment_result$success) {
        return(paste("Error:", adjustment_result$message))
    }

    if (length(adjustment_result$adjustment_sets) == 0) {
        return(paste(
            "No valid adjustment sets found for the specified causal relationship.\n",
            "This may indicate that the causal effect cannot be identified from observational data",
            "given the current DAG structure."
        ))
    }

    # Create header
    header <- paste0(
        "Minimal Sufficient Adjustment Sets\n",
        "==================================\n",
        "Exposure: ", paste(adjustment_result$exposure, collapse = ", "), "\n",
        "Outcome: ", paste(adjustment_result$outcome, collapse = ", "), "\n",
        "Effect Type: ", adjustment_result$effect_type, "\n",
        "Total Sets Found: ", adjustment_result$total_sets, "\n\n"
    )

    # Format each adjustment set
    sets_text <- ""
    for (i in seq_along(adjustment_result$adjustment_sets)) {
        set_info <- adjustment_result$adjustment_sets[[i]]
        sets_text <- paste0(
            sets_text,
            "Set ", i, ": ",
            if (set_info$size == 0) {
                "∅ (Empty set - no adjustment needed)"
            } else {
                paste0("{", set_info$description, "}")
            },
            "\n"
        )
    }

    # Add interpretation
    interpretation <- paste0(
        "\nInterpretation:\n",
        "- Each set represents variables that should be controlled for (adjusted)\n",
        "- Empty set means no adjustment is needed for unbiased causal estimation\n",
        "- Choose the most practical set based on data availability and measurement quality"
    )

    return(paste0(header, sets_text, interpretation))
}

#' Create Causal Analysis Summary
#'
#' Creates a comprehensive summary of causal analysis results
#'
#' @param dag_object dagitty DAG object
#' @param exposure Exposure variable
#' @param outcome Outcome variable
#' @return List containing comprehensive analysis results
#' @export
create_causal_analysis_summary <- function(dag_object, exposure = NULL, outcome = NULL) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object"
        ))
    }

    # Get variables information
    vars_info <- get_dag_variables(dag_object)

    # Calculate adjustment sets
    adj_sets <- calculate_adjustment_sets(dag_object, exposure, outcome)

    # Find instrumental variables
    instruments <- find_instrumental_variables(dag_object, exposure, outcome)

    # Analyze paths if exposure and outcome are specified
    paths_info <- NULL
    if (!is.null(exposure) && !is.null(outcome)) {
        paths_info <- analyze_causal_paths(dag_object, exposure, outcome)
    }

    return(list(
        success = TRUE,
        variables = vars_info,
        adjustment_sets = adj_sets,
        instrumental_variables = instruments,
        causal_paths = paths_info,
        dag_summary = list(
            total_variables = length(vars_info$variables),
            has_exposures = length(vars_info$exposures) > 0,
            has_outcomes = length(vars_info$outcomes) > 0,
            analysis_possible = adj_sets$success
        )
    ))
}
