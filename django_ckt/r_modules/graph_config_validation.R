# Graph Configuration Validation Module
# This module provides validation functions for graph configuration parameters
# Author: Refactored from graph_config_module.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' CUI Validation Function
#'
#' Validates CUI format and returns cleaned CUI list
#'
#' @param cui_string String containing comma-separated CUIs
#' @return List with valid (TRUE/FALSE), message (if invalid), and cuis (if valid)
#' @keywords internal
validate_cui <- function(cui_string) {
    if (is.null(cui_string) || cui_string == "") {
        return(list(valid = FALSE, message = "CUI field cannot be empty"))
    }
    
    # Split and clean CUIs
    cuis <- trimws(unlist(strsplit(cui_string, ",")))
    cuis <- cuis[cuis != ""]  # Remove empty strings
    
    if (length(cuis) == 0) {
        return(list(valid = FALSE, message = "No valid CUIs found"))
    }
    
    # Validate CUI format (C followed by 7 digits)
    cui_pattern <- "^C[0-9]{7}$"
    invalid_cuis <- cuis[!grepl(cui_pattern, cuis)]
    
    if (length(invalid_cuis) > 0) {
        return(list(
            valid = FALSE, 
            message = paste("Invalid CUI format:", paste(invalid_cuis, collapse = ", "), 
                          ". CUIs must follow format C0000000 (C followed by 7 digits)")
        ))
    }
    
    return(list(valid = TRUE, cuis = cuis))
}

#' Predication Type Validation Function
#'
#' Validates predication types and returns comma-separated string
#'
#' @param predication_input Predication type input (can be vector or string)
#' @return List with valid (TRUE/FALSE), message (if invalid), and types (if valid)
#' @keywords internal
validate_predication_types <- function(predication_input) {
    # Define valid predication types (as specified by user)
    valid_types <- c("AFFECTS", "AUGMENTS", "CAUSES",
                   "COMPLICATES", "DISRUPTS", "INHIBITS",
                   "PRECEDES", "PREDISPOSES", "PREVENTS", "PRODUCES", "STIMULATES", "TREATS")

    # Handle null or empty input - default to CAUSES
    if (is.null(predication_input) || length(predication_input) == 0) {
        return(list(valid = TRUE, types = "CAUSES"))  # Default to CAUSES as single value
    }

    # Handle multiple selection from selectInput
    if (is.character(predication_input) && length(predication_input) > 1) {
        # Multiple values from selectInput
        types <- trimws(predication_input)
        types <- types[types != ""]  # Remove empty strings
    } else if (is.character(predication_input) && length(predication_input) == 1) {
        # Handle single string input (legacy comma-separated format still supported for backward compatibility)
        if (grepl(",", predication_input)) {
            # Split comma-separated values
            types <- trimws(unlist(strsplit(predication_input, ",")))
            types <- types[types != ""]  # Remove empty strings
        } else {
            # Single value
            types <- trimws(predication_input)
        }
    } else {
        # Handle vector input from selectInput
        types <- as.character(predication_input)
        types <- types[types != ""]  # Remove empty strings
    }

    types <- toupper(types)  # Convert to uppercase for comparison

    if (length(types) == 0) {
        return(list(valid = TRUE, types = "CAUSES"))  # Default if empty
    }

    # Check for invalid types
    invalid_types <- types[!types %in% valid_types]
    if (length(invalid_types) > 0) {
        return(list(
            valid = FALSE,
            message = paste("Invalid predication type(s):", paste(invalid_types, collapse = ", "),
                          ". Valid types include:", paste(head(valid_types, 10), collapse = ", "), "...")
        ))
    }

    # Return comma-separated string for YAML compatibility
    return(list(valid = TRUE, types = paste(types, collapse = ", ")))
}

#' Name Validation Function for Single Consolidated Names
#'
#' Validates and formats consolidated names (replaces spaces with underscores)
#'
#' @param name_string Name string to validate
#' @param field_name Field name for error messages
#' @return List with valid (TRUE/FALSE), message (if invalid), and name (if valid)
#' @keywords internal
validate_consolidated_name <- function(name_string, field_name) {
    if (is.null(name_string) || trimws(name_string) == "") {
        return(list(valid = FALSE, message = paste("Consolidated", field_name, "name is required and cannot be empty")))
    }

    # Clean the name and replace spaces with underscores
    clean_name <- trimws(name_string)

    if (clean_name == "") {
        return(list(valid = FALSE, message = paste("Consolidated", field_name, "name is required and cannot be empty")))
    }

    # Replace spaces with underscores for consistent formatting
    formatted_name <- gsub("\\s+", "_", clean_name)

    return(list(valid = TRUE, name = formatted_name))
}

#' Main Input Validation Function
#'
#' Validates all inputs from the graph configuration form
#'
#' @param input Shiny input object
#' @param exposure_cui_search Reactive value from exposure CUI search (if available)
#' @param outcome_cui_search Reactive value from outcome CUI search (if available)
#' @param blocklist_cui_search Reactive value from blocklist CUI search (if available)
#' @return List with validation results
#' @keywords internal
validate_inputs <- function(input, exposure_cui_search = NULL, outcome_cui_search = NULL, blocklist_cui_search = NULL) {
    errors <- c()

    # Get CUI values from search modules or manual input
    exposure_cui_string <- if (!is.null(exposure_cui_search)) {
        tryCatch({
            exposure_search_data <- exposure_cui_search()
            if (!is.null(exposure_search_data) && !is.null(exposure_search_data$cui_string)) {
                exposure_search_data$cui_string
            } else {
                ""
            }
        }, error = function(e) {
            # If CUI search module fails, fall back to manual input
            input$exposure_cuis %||% ""
        })
    } else {
        input$exposure_cuis %||% ""
    }

    outcome_cui_string <- if (!is.null(outcome_cui_search)) {
        tryCatch({
            outcome_search_data <- outcome_cui_search()
            if (!is.null(outcome_search_data) && !is.null(outcome_search_data$cui_string)) {
                outcome_search_data$cui_string
            } else {
                ""
            }
        }, error = function(e) {
            # If CUI search module fails, fall back to manual input
            input$outcome_cuis %||% ""
        })
    } else {
        input$outcome_cuis %||% ""
    }

    # Get blocklist CUI string from search interface or manual input
    blocklist_cui_string <- if (!is.null(blocklist_cui_search)) {
        tryCatch({
            blocklist_search_data <- blocklist_cui_search()
            if (!is.null(blocklist_search_data) && !is.null(blocklist_search_data$cui_string)) {
                blocklist_search_data$cui_string
            } else {
                ""
            }
        }, error = function(e) {
            # If CUI search module fails, fall back to manual input
            input$blocklist_cuis %||% ""
        })
    } else {
        input$blocklist_cuis %||% ""
    }

    # Validate exposure CUIs
    exposure_validation <- validate_cui(exposure_cui_string)
    if (!exposure_validation$valid) {
        errors <- c(errors, paste("Exposure CUIs:", exposure_validation$message))
    }

    # Validate outcome CUIs
    outcome_validation <- validate_cui(outcome_cui_string)
    if (!outcome_validation$valid) {
        errors <- c(errors, paste("Outcome CUIs:", outcome_validation$message))
    }

    # Validate blocklist CUIs if provided
    blocklist_validation <- list(valid = TRUE, cuis = c())
    if (!is.null(blocklist_cui_string) && blocklist_cui_string != "") {
        blocklist_validation <- validate_cui(blocklist_cui_string)
        if (!blocklist_validation$valid) {
            errors <- c(errors, paste("Blocklist CUIs:", blocklist_validation$message))
        }
    }

    # Validate consolidated exposure name if provided
    exposure_name_validation <- validate_consolidated_name(input$exposure_name, "exposure")
    if (!exposure_name_validation$valid) {
        errors <- c(errors, paste("Exposure Name:", exposure_name_validation$message))
    }

    # Validate consolidated outcome name if provided
    outcome_name_validation <- validate_consolidated_name(input$outcome_name, "outcome")
    if (!outcome_name_validation$valid) {
        errors <- c(errors, paste("Outcome Name:", outcome_name_validation$message))
    }

    # Validate predication types
    predication_validation <- validate_predication_types(input$PREDICATION_TYPE)
    if (!predication_validation$valid) {
        errors <- c(errors, paste("Predication Types:", predication_validation$message))
    }

    # Validate required fields - Squelch Thresholds for each degree
    if (is.null(input$min_pmids_degree1) || is.na(input$min_pmids_degree1)) {
        errors <- c(errors, "Squelch Threshold for Degree 1 is required")
    } else if (!is.numeric(input$min_pmids_degree1) || input$min_pmids_degree1 < 1 || input$min_pmids_degree1 > 1000) {
        errors <- c(errors, "Squelch Threshold for Degree 1 must be a number between 1 and 1000")
    } else if (input$min_pmids_degree1 != as.integer(input$min_pmids_degree1)) {
        errors <- c(errors, "Squelch Threshold for Degree 1 must be a whole number")
    }

    if (is.null(input$min_pmids_degree2) || is.na(input$min_pmids_degree2)) {
        errors <- c(errors, "Squelch Threshold for Degree 2 is required")
    } else if (!is.numeric(input$min_pmids_degree2) || input$min_pmids_degree2 < 1 || input$min_pmids_degree2 > 1000) {
        errors <- c(errors, "Squelch Threshold for Degree 2 must be a number between 1 and 1000")
    } else if (input$min_pmids_degree2 != as.integer(input$min_pmids_degree2)) {
        errors <- c(errors, "Squelch Threshold for Degree 2 must be a whole number")
    }

    if (is.null(input$min_pmids_degree3) || is.na(input$min_pmids_degree3)) {
        errors <- c(errors, "Squelch Threshold for Degree 3 is required")
    } else if (!is.numeric(input$min_pmids_degree3) || input$min_pmids_degree3 < 1 || input$min_pmids_degree3 > 1000) {
        errors <- c(errors, "Squelch Threshold for Degree 3 must be a number between 1 and 1000")
    } else if (input$min_pmids_degree3 != as.integer(input$min_pmids_degree3)) {
        errors <- c(errors, "Squelch Threshold for Degree 3 must be a whole number")
    }

    if (is.null(input$pub_year_cutoff) || input$pub_year_cutoff == "") {
        errors <- c(errors, "Publication Year Cutoff is required")
    }

    if (is.null(input$degree) || input$degree == "") {
        errors <- c(errors, "Degree is required")
    }

    if (is.null(input$SemMedDBD_version) || input$SemMedDBD_version == "") {
        errors <- c(errors, "SemMedDB Version is required")
    }

    return(list(
        valid = length(errors) == 0,
        errors = errors,
        exposure_cuis = if (exposure_validation$valid) exposure_validation$cuis else NULL,
        outcome_cuis = if (outcome_validation$valid) outcome_validation$cuis else NULL,
        blocklist_cuis = if (blocklist_validation$valid) blocklist_validation$cuis else c(),
        exposure_name = if (exposure_name_validation$valid) exposure_name_validation$name else NULL,
        outcome_name = if (outcome_name_validation$valid) outcome_name_validation$name else NULL,
        predication_types = if (predication_validation$valid) predication_validation$types else c("CAUSES")
    ))
}

#' Validate Configuration Parameters
#'
#' Validates a configuration list to ensure all parameters are correct
#'
#' @param config List containing configuration parameters
#' @return List with validation results (valid = TRUE/FALSE, errors = character vector)
#' @export
validate_graph_config <- function(config) {
    if (is.null(config)) {
        return(list(valid = FALSE, errors = "Configuration is NULL"))
    }

    errors <- c()

    # Check required fields - support both old and new format
    has_new_format <- all(c("min_pmids_degree1", "min_pmids_degree2", "min_pmids_degree3") %in% names(config))
    has_old_format <- "min_pmids" %in% names(config)

    if (!has_new_format && !has_old_format) {
        errors <- c(errors, "Configuration must have either min_pmids or min_pmids_degree1/2/3 fields")
    }

    required_fields_base <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                        "pub_year_cutoff", "degree", "SemMedDBD_version")

    missing_fields <- required_fields_base[!required_fields_base %in% names(config)]
    if (length(missing_fields) > 0) {
        errors <- c(errors, paste("Missing required fields:", paste(missing_fields, collapse = ", ")))
    }

    # Validate CUI format if fields exist
    if ("exposure_cuis" %in% names(config)) {
        cui_pattern <- "^C[0-9]{7}$"
        invalid_exposure <- config$exposure_cuis[!grepl(cui_pattern, config$exposure_cuis)]
        if (length(invalid_exposure) > 0) {
            errors <- c(errors, paste("Invalid exposure CUIs:", paste(invalid_exposure, collapse = ", ")))
        }
    }

    if ("outcome_cuis" %in% names(config)) {
        cui_pattern <- "^C[0-9]{7}$"
        invalid_outcome <- config$outcome_cuis[!grepl(cui_pattern, config$outcome_cuis)]
        if (length(invalid_outcome) > 0) {
            errors <- c(errors, paste("Invalid outcome CUIs:", paste(invalid_outcome, collapse = ", ")))
        }
    }

    # Validate consolidated name fields (these are required single strings, not arrays)
    if (!"exposure_name" %in% names(config) || is.null(config$exposure_name) || config$exposure_name == "") {
        errors <- c(errors, "exposure_name is required and cannot be empty")
    } else {
        if (!is.character(config$exposure_name) || length(config$exposure_name) != 1) {
            errors <- c(errors, "exposure_name must be a single character string")
        } else {
            # Check if name contains spaces (should be underscores in saved format)
            if (grepl("\\s", config$exposure_name)) {
                errors <- c(errors, "exposure_name should not contain spaces (use underscores instead)")
            }
        }
    }

    if (!"outcome_name" %in% names(config) || is.null(config$outcome_name) || config$outcome_name == "") {
        errors <- c(errors, "outcome_name is required and cannot be empty")
    } else {
        if (!is.character(config$outcome_name) || length(config$outcome_name) != 1) {
            errors <- c(errors, "outcome_name must be a single character string")
        } else {
            # Check if name contains spaces (should be underscores in saved format)
            if (grepl("\\s", config$outcome_name)) {
                errors <- c(errors, "outcome_name should not contain spaces (use underscores instead)")
            }
        }
    }

    # Validate numeric ranges - support both old and new format
    if ("min_pmids" %in% names(config)) {
        if (!is.numeric(config$min_pmids) || config$min_pmids < 1 || config$min_pmids > 1000) {
            errors <- c(errors, "min_pmids must be a number between 1 and 1000")
        } else if (config$min_pmids != as.integer(config$min_pmids)) {
            errors <- c(errors, "min_pmids must be a whole number")
        }
    }

    # Validate new format thresholds
    if ("min_pmids_degree1" %in% names(config)) {
        if (!is.numeric(config$min_pmids_degree1) || config$min_pmids_degree1 < 1 || config$min_pmids_degree1 > 1000) {
            errors <- c(errors, "min_pmids_degree1 must be a number between 1 and 1000")
        } else if (config$min_pmids_degree1 != as.integer(config$min_pmids_degree1)) {
            errors <- c(errors, "min_pmids_degree1 must be a whole number")
        }
    }

    if ("min_pmids_degree2" %in% names(config)) {
        if (!is.numeric(config$min_pmids_degree2) || config$min_pmids_degree2 < 1 || config$min_pmids_degree2 > 1000) {
            errors <- c(errors, "min_pmids_degree2 must be a number between 1 and 1000")
        } else if (config$min_pmids_degree2 != as.integer(config$min_pmids_degree2)) {
            errors <- c(errors, "min_pmids_degree2 must be a whole number")
        }
    }

    if ("min_pmids_degree3" %in% names(config)) {
        if (!is.numeric(config$min_pmids_degree3) || config$min_pmids_degree3 < 1 || config$min_pmids_degree3 > 1000) {
            errors <- c(errors, "min_pmids_degree3 must be a number between 1 and 1000")
        } else if (config$min_pmids_degree3 != as.integer(config$min_pmids_degree3)) {
            errors <- c(errors, "min_pmids_degree3 must be a whole number")
        }
    }

    if ("pub_year_cutoff" %in% names(config)) {
        if (!is.numeric(config$pub_year_cutoff) || config$pub_year_cutoff < 1980 || config$pub_year_cutoff > 2025) {
            errors <- c(errors, "pub_year_cutoff must be a number between 1980 and 2025")
        }
    }

    if ("degree" %in% names(config)) {
        if (!is.numeric(config$degree) || !config$degree %in% c(1, 2, 3)) {
            errors <- c(errors, "degree must be 1, 2, or 3")
        }
    }

    return(list(
        valid = length(errors) == 0,
        errors = errors
    ))
}

