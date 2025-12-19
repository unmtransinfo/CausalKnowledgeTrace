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
            # Extract variable names from the list structure
            instrument_vars <- sapply(instruments, function(x) {
                if (is.list(x) && "I" %in% names(x)) {
                    return(x$I)
                } else {
                    return(as.character(x))
                }
            })
            # Remove any duplicates and ensure it's a character vector
            instrument_vars <- unique(as.character(instrument_vars))
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

#' Detect M-Bias Structures
#'
#' Identifies M-bias structures where colliders on backdoor paths should not be adjusted
#'
#' @param dag_object dagitty DAG object
#' @param exposure Name of exposure variable
#' @param outcome Name of outcome variable
#' @return List containing M-bias detection results
#' @export
detect_m_bias <- function(dag_object, exposure = NULL, outcome = NULL) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            mbias_vars = character(0)
        ))
    }

    tryCatch({
        # Get minimal adjustment sets
        minimal_sets <- adjustmentSets(dag_object, exposure, outcome, type = "minimal")

        # Get all nodes except exposure and outcome
        all_nodes <- setdiff(names(dag_object), c(exposure, outcome))

        mbias_vars <- character(0)
        mbias_details <- list()

        # Get all paths between exposure and outcome
        path_result <- paths(dag_object, from = exposure, to = outcome)
        all_paths <- path_result$paths
        path_status <- path_result$open

        # Check each node for M-bias structure
        for (v in all_nodes) {
            pars <- parents(dag_object, v)

            # Must have at least 2 parents (collider)
            if (length(pars) < 2) next

            # Check if it's in any minimal adjustment set
            in_adjustment_set <- any(vapply(minimal_sets, function(s) v %in% s, logical(1)))
            if (in_adjustment_set) next

            # Find paths that go through this variable
            paths_through_v <- character(0)
            for (i in seq_along(all_paths)) {
                path <- all_paths[i]
                is_open <- path_status[i]

                # Check if this is a backdoor path (starts with exposure <-)
                is_backdoor <- grepl(paste0("^", exposure, " <-"), path)

                # Check if path contains this variable
                contains_v <- grepl(v, path)

                # M-bias: backdoor path, currently closed, contains the collider
                if (is_backdoor && !is_open && contains_v) {
                    paths_through_v <- c(paths_through_v, path)
                }
            }

            if (length(paths_through_v) > 0) {
                mbias_vars <- c(mbias_vars, v)
                mbias_details[[v]] <- list(
                    parents = pars,
                    paths = paths_through_v
                )
            }
        }

        valid_adjustment_set <- if (length(minimal_sets) > 0) minimal_sets[[1]] else character(0)

        return(list(
            success = TRUE,
            message = if (length(mbias_vars) > 0)
                paste("Found", length(mbias_vars), "M-bias variable(s)")
                else "No M-bias detected",
            exposure = exposure,
            outcome = outcome,
            minimal_sets = minimal_sets,
            valid_adjustment_set = valid_adjustment_set,
            mbias_vars = mbias_vars,
            mbias_details = mbias_details,
            count = length(mbias_vars)
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error detecting M-bias:", e$message),
            mbias_vars = character(0)
        ))
    })
}

#' Detect Butterfly Bias Structures
#'
#' Identifies butterfly bias where confounders have multiple confounder parents
#'
#' @param dag_object dagitty DAG object
#' @param exposure Name of exposure variable
#' @param outcome Name of outcome variable
#' @return List containing butterfly bias detection results
#' @export
detect_butterfly_bias <- function(dag_object, exposure = NULL, outcome = NULL) {
    if (is.null(dag_object) || !inherits(dag_object, "dagitty")) {
        return(list(
            success = FALSE,
            message = "Invalid or missing DAG object",
            butterfly_vars = character(0)
        ))
    }

    tryCatch({
        # Get all adjustment sets to identify confounders
        all_adj_sets <- adjustmentSets(dag_object, exposure, outcome, type = "all")
        confounders <- unique(unlist(all_adj_sets))

        butterfly_vars <- character(0)
        butterfly_parents <- list()

        # Check each confounder for butterfly structure
        if (length(confounders) > 0) {
            for (v in confounders) {
                # Get parents that are also confounders
                pars <- intersect(parents(dag_object, v), confounders)

                # Butterfly bias: confounder with 2+ confounder parents
                if (length(pars) >= 2) {
                    butterfly_vars <- c(butterfly_vars, v)
                    butterfly_parents[[v]] <- pars
                }
            }
        }

        # Identify non-butterfly confounders
        non_butterfly_confounders <- confounders
        if (length(butterfly_vars) > 0) {
            for (bfly in butterfly_vars) {
                non_butterfly_confounders <- setdiff(
                    non_butterfly_confounders,
                    c(bfly, butterfly_parents[[bfly]])
                )
            }
        }

        return(list(
            success = TRUE,
            message = if (length(butterfly_vars) > 0)
                paste("Found", length(butterfly_vars), "butterfly bias variable(s)")
                else "No butterfly bias detected",
            exposure = exposure,
            outcome = outcome,
            butterfly_vars = butterfly_vars,
            butterfly_parents = butterfly_parents,
            non_butterfly_confounders = non_butterfly_confounders,
            all_confounders = confounders,
            count = length(butterfly_vars)
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error detecting butterfly bias:", e$message),
            butterfly_vars = character(0)
        ))
    })
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

    # Detect M-bias
    mbias_info <- NULL
    if (!is.null(exposure) && !is.null(outcome)) {
        mbias_info <- detect_m_bias(dag_object, exposure, outcome)
    }

    # Detect Butterfly bias
    butterfly_info <- NULL
    if (!is.null(exposure) && !is.null(outcome)) {
        butterfly_info <- detect_butterfly_bias(dag_object, exposure, outcome)
    }

    return(list(
        success = TRUE,
        variables = vars_info,
        adjustment_sets = adj_sets,
        instrumental_variables = instruments,
        causal_paths = paths_info,
        mbias = mbias_info,
        butterfly_bias = butterfly_info,
        dag_summary = list(
            total_variables = length(vars_info$variables),
            has_exposures = length(vars_info$exposures) > 0,
            has_outcomes = length(vars_info$outcomes) > 0,
            analysis_possible = adj_sets$success
        )
    ))
}
