# Graph Configuration Validation Module
# 
# This module contains validation logic for graph configuration parameters.
# It includes CUI validation, parameter checking, and error handling.
#
# Author: Refactored from graph_config_module.R
# Date: February 2025

#' Validate CUI Input
#' 
#' Validates a string containing CUI identifiers
#' 
#' @param cui_string Character string containing CUIs (one per line or comma-separated)
#' @return List with validation results
validate_cui <- function(cui_string) {
    if (is.null(cui_string) || cui_string == "") {
        return(list(valid = FALSE, message = "CUI field cannot be empty"))
    }
    
    # Split and clean CUIs
    cuis <- unlist(strsplit(cui_string, "[\n,;]+"))
    cuis <- trimws(cuis)
    cuis <- cuis[cuis != ""]  # Remove empty strings
    
    if (length(cuis) == 0) {
        return(list(valid = FALSE, message = "No valid CUIs found"))
    }
    
    # Validate CUI format (should start with C followed by digits)
    cui_pattern <- "^C[0-9]{7}$"
    invalid_cuis <- cuis[!grepl(cui_pattern, cuis)]
    
    if (length(invalid_cuis) > 0) {
        return(list(
            valid = FALSE, 
            message = paste("Invalid CUI format:", paste(invalid_cuis, collapse = ", "), 
                          "\nCUIs should be in format C0000000 (C followed by 7 digits)")
        ))
    }
    
    return(list(valid = TRUE, cuis = cuis, count = length(cuis)))
}

#' Validate Name Input
#' 
#' Validates a name string for use in file names and identifiers
#' 
#' @param name_string Character string containing the name
#' @return List with validation results
validate_name <- function(name_string) {
    if (is.null(name_string) || name_string == "") {
        return(list(valid = FALSE, message = "Name field cannot be empty"))
    }
    
    # Clean the name - remove special characters and spaces
    cleaned_name <- gsub("[^A-Za-z0-9_]", "_", name_string)
    cleaned_name <- gsub("_+", "_", cleaned_name)  # Collapse multiple underscores
    cleaned_name <- gsub("^_|_$", "", cleaned_name)  # Remove leading/trailing underscores
    
    if (cleaned_name == "") {
        return(list(valid = FALSE, message = "Name contains no valid characters"))
    }
    
    if (nchar(cleaned_name) > 50) {
        return(list(valid = FALSE, message = "Name is too long (maximum 50 characters)"))
    }
    
    return(list(valid = TRUE, name = cleaned_name))
}

#' Validate Predication Types
#'
#' Validates predication type selection from dropdown (supports multiple selection)
#'
#' @param selected_types Character vector of selected predication types
#' @return List with validation results
validate_predication_types <- function(selected_types) {
    # Define valid predication types (as specified by user)
    valid_types <- c("AFFECTS", "ASSOCIATED_WITH", "AUGMENTS", "CAUSES", "COEXISTS_WITH",
                    "COMPLICATES", "DISRUPTS", "INHIBITS", "INTERACTS_WITH", "MANIFESTATION_OF",
                    "PRECEDES", "PREDISPOSES", "PREVENTS", "PRODUCES", "STIMULATES", "TREATS")

    # Handle null or empty input - default to CAUSES
    if (is.null(selected_types) || length(selected_types) == 0) {
        return(list(valid = TRUE, types = "CAUSES", count = 1))
    }

    # Handle multiple selection from selectInput
    if (is.character(selected_types) && length(selected_types) > 1) {
        # Multiple values from selectInput
        types <- trimws(selected_types)
        types <- types[types != ""]  # Remove empty strings
    } else if (is.character(selected_types) && length(selected_types) == 1) {
        # Handle single string input (legacy comma-separated format still supported for backward compatibility)
        if (grepl(",", selected_types)) {
            # Split comma-separated values
            types <- trimws(unlist(strsplit(selected_types, ",")))
            types <- types[types != ""]  # Remove empty strings
        } else {
            # Single value
            types <- trimws(selected_types)
        }
    } else {
        # Handle vector input from selectInput
        types <- as.character(selected_types)
        types <- types[types != ""]  # Remove empty strings
    }

    types <- toupper(types)  # Convert to uppercase for comparison

    if (length(types) == 0) {
        return(list(valid = TRUE, types = "CAUSES", count = 1))  # Default if empty
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

    # Return comma-separated string for compatibility
    return(list(valid = TRUE, types = paste(types, collapse = ", "), count = length(types)))
}

#' Validate Numeric Parameter
#' 
#' Validates a numeric parameter with range checking
#' 
#' @param value Numeric value to validate
#' @param param_name Character string name of the parameter
#' @param min_val Minimum allowed value
#' @param max_val Maximum allowed value
#' @param integer_only Logical, whether value must be an integer
#' @return List with validation results
validate_numeric_param <- function(value, param_name, min_val = NULL, max_val = NULL, integer_only = TRUE) {
    if (is.null(value) || is.na(value)) {
        return(list(valid = FALSE, message = paste(param_name, "is required")))
    }
    
    if (!is.numeric(value)) {
        return(list(valid = FALSE, message = paste(param_name, "must be a number")))
    }
    
    if (integer_only && (value != as.integer(value))) {
        return(list(valid = FALSE, message = paste(param_name, "must be a whole number")))
    }
    
    if (!is.null(min_val) && value < min_val) {
        return(list(valid = FALSE, message = paste(param_name, "must be at least", min_val)))
    }
    
    if (!is.null(max_val) && value > max_val) {
        return(list(valid = FALSE, message = paste(param_name, "must be at most", max_val)))
    }
    
    return(list(valid = TRUE, value = if (integer_only) as.integer(value) else value))
}

#' Validate All Configuration Inputs
#' 
#' Comprehensive validation of all configuration parameters
#' 
#' @param input Shiny input object containing all form values
#' @return List with overall validation results
validate_all_inputs <- function(input) {
    errors <- character(0)
    
    # Validate exposure CUIs
    exposure_validation <- validate_cui(input$exposure_cuis)
    if (!exposure_validation$valid) {
        errors <- c(errors, paste("Exposure CUIs:", exposure_validation$message))
    }
    
    # Validate outcome CUIs
    outcome_validation <- validate_cui(input$outcome_cuis)
    if (!outcome_validation$valid) {
        errors <- c(errors, paste("Outcome CUIs:", outcome_validation$message))
    }

    # Validate blacklist CUIs if provided
    blacklist_validation <- list(valid = TRUE, cuis = c())
    if (!is.null(input$blacklist_cuis) && input$blacklist_cuis != "") {
        blacklist_validation <- validate_cui(input$blacklist_cuis)
        if (!blacklist_validation$valid) {
            errors <- c(errors, paste("Blacklist CUIs:", blacklist_validation$message))
        }
    }
    
    # Validate exposure name
    exposure_name_validation <- validate_name(input$exposure_name)
    if (!exposure_name_validation$valid) {
        errors <- c(errors, paste("Exposure Name:", exposure_name_validation$message))
    }
    
    # Validate outcome name
    outcome_name_validation <- validate_name(input$outcome_name)
    if (!outcome_name_validation$valid) {
        errors <- c(errors, paste("Outcome Name:", outcome_name_validation$message))
    }
    
    # Validate predication types
    predication_validation <- validate_predication_types(input$predication_types)
    if (!predication_validation$valid) {
        errors <- c(errors, paste("Predication Types:", predication_validation$message))
    }
    
    # Validate numeric parameters
    min_pmids_validation <- validate_numeric_param(input$min_pmids, "Minimum PMIDs", min_val = 1, max_val = 10000)
    if (!min_pmids_validation$valid) {
        errors <- c(errors, min_pmids_validation$message)
    }
    
    pub_year_validation <- validate_numeric_param(input$pub_year_cutoff, "Publication Year Cutoff", 
                                                 min_val = 1990, max_val = 2025)
    if (!pub_year_validation$valid) {
        errors <- c(errors, pub_year_validation$message)
    }
    
    degree_validation <- validate_numeric_param(input$degree, "Degree", min_val = 1, max_val = 3)
    if (!degree_validation$valid) {
        errors <- c(errors, degree_validation$message)
    }
    
    # Validate SemMedDB version
    if (is.null(input$SemMedDBD_version) || input$SemMedDBD_version == "") {
        errors <- c(errors, "SemMedDB Version is required")
    }
    
    # Return validation results
    return(list(
        valid = length(errors) == 0,
        errors = errors,
        exposure_cuis = if (exposure_validation$valid) exposure_validation$cuis else NULL,
        outcome_cuis = if (outcome_validation$valid) outcome_validation$cuis else NULL,
        blacklist_cuis = if (blacklist_validation$valid) blacklist_validation$cuis else c(),
        exposure_name = if (exposure_name_validation$valid) exposure_name_validation$name else NULL,
        outcome_name = if (outcome_name_validation$valid) outcome_name_validation$name else NULL,
        predication_types = if (predication_validation$valid) predication_validation$types else c("CAUSES"),
        min_pmids = if (min_pmids_validation$valid) min_pmids_validation$value else NULL,
        pub_year_cutoff = if (pub_year_validation$valid) pub_year_validation$value else NULL,
        degree = if (degree_validation$valid) degree_validation$value else NULL,
        semmeddb_version = input$SemMedDBD_version
    ))
}

#' Check CUI Overlap
#' 
#' Checks if there's overlap between exposure and outcome CUIs
#' 
#' @param exposure_cuis Character vector of exposure CUIs
#' @param outcome_cuis Character vector of outcome CUIs
#' @return List with overlap check results
check_cui_overlap <- function(exposure_cuis, outcome_cuis) {
    overlap <- intersect(exposure_cuis, outcome_cuis)
    
    if (length(overlap) > 0) {
        return(list(
            has_overlap = TRUE,
            overlapping_cuis = overlap,
            warning = paste("Warning: The following CUIs appear in both exposure and outcome:",
                          paste(overlap, collapse = ", "),
                          "\nThis may affect causal analysis results.")
        ))
    }
    
    return(list(has_overlap = FALSE, warning = NULL))
}
