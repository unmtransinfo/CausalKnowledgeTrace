# Graph Configuration Helper Functions Module
# This module provides helper functions for YAML operations and testing
# Author: Refactored from graph_config_module.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Load Graph Configuration from YAML File
#'
#' Helper function to load previously saved configuration
#'
#' @param yaml_file Path to the YAML configuration file (default: "../user_input.yaml")
#' @return List containing configuration parameters, or NULL if file doesn't exist
#' @export
load_graph_config <- function(yaml_file = "../user_input.yaml") {
    if (!file.exists(yaml_file)) {
        warning(paste("Configuration file", yaml_file, "not found"))
        return(NULL)
    }

    tryCatch({
        config <- yaml::read_yaml(yaml_file)

        # Validate loaded configuration
        # Support both old format (min_pmids) and new format (min_pmids_degree1/2/3)
        required_fields_new <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                           "min_pmids_degree1", "min_pmids_degree2", "min_pmids_degree3",
                           "pub_year_cutoff", "degree",
                           "SemMedDBD_version", "predication_type")
        required_fields_old <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                           "min_pmids", "pub_year_cutoff", "degree",
                           "SemMedDBD_version", "predication_type")
        # Note: blocklist_cuis is optional, so not included in required_fields

        # Check if it's new format or old format
        has_new_format <- all(c("min_pmids_degree1", "min_pmids_degree2", "min_pmids_degree3") %in% names(config))
        has_old_format <- "min_pmids" %in% names(config)

        if (!has_new_format && !has_old_format) {
            warning("Configuration must have either min_pmids or min_pmids_degree1/2/3 fields")
            return(NULL)
        }

        # If old format, convert to new format
        if (has_old_format && !has_new_format) {
            config$min_pmids_degree1 <- config$min_pmids
            config$min_pmids_degree2 <- config$min_pmids
            config$min_pmids_degree3 <- config$min_pmids
        }

        # Validate required fields based on format
        required_fields <- if (has_new_format) required_fields_new else required_fields_old
        missing_fields <- required_fields[!required_fields %in% names(config)]
        if (length(missing_fields) > 0) {
            warning(paste("Missing required fields in configuration:",
                         paste(missing_fields, collapse = ", ")))
            return(NULL)
        }

        return(config)

    }, error = function(e) {
        warning(paste("Error loading configuration:", e$message))
        return(NULL)
    })
}

#' Update UI Inputs with Loaded Configuration
#'
#' Updates Shiny UI inputs with values from loaded configuration
#'
#' @param session Shiny session object
#' @param loaded_config Configuration list loaded from YAML
#' @keywords internal
update_ui_with_config <- function(session, loaded_config) {
    if (is.null(loaded_config)) {
        return(NULL)
    }

    # Update exposure CUIs
    if (!is.null(loaded_config$exposure_cuis)) {
        exposure_cuis_text <- paste(unlist(loaded_config$exposure_cuis), collapse = "\n")
        updateTextAreaInput(session, "exposure_cuis", value = exposure_cuis_text)
    }

    # Update outcome CUIs
    if (!is.null(loaded_config$outcome_cuis)) {
        outcome_cuis_text <- paste(unlist(loaded_config$outcome_cuis), collapse = "\n")
        updateTextAreaInput(session, "outcome_cuis", value = outcome_cuis_text)
    }

    # Update exposure name
    if (!is.null(loaded_config$exposure_name)) {
        updateTextInput(session, "exposure_name", value = loaded_config$exposure_name)
    }

    # Update outcome name
    if (!is.null(loaded_config$outcome_name)) {
        updateTextInput(session, "outcome_name", value = loaded_config$outcome_name)
    }

    # Update min_pmids
    if (!is.null(loaded_config$min_pmids)) {
        updateNumericInput(session, "min_pmids", value = loaded_config$min_pmids)
    }

    # Update pub_year_cutoff
    if (!is.null(loaded_config$pub_year_cutoff)) {
        updateNumericInput(session, "pub_year_cutoff", value = loaded_config$pub_year_cutoff)
    }

    # Update degree
    if (!is.null(loaded_config$degree)) {
        updateSelectInput(session, "degree", selected = as.character(loaded_config$degree))
    }

    # Update predication_type
    if (!is.null(loaded_config$predication_type)) {
        updateSelectInput(session, "predication_type", selected = loaded_config$predication_type)
    }
}

#' Test Graph Configuration Module
#'
#' Function to test the module functionality independently
#'
#' @return TRUE if all tests pass, FALSE otherwise
#' @export
test_graph_config_module <- function() {
    cat("Testing Graph Configuration Module...\n")

    # Test configuration (use underscores in names, not spaces)
    test_config <- list(
        exposure_cuis = c("C0011849", "C0020538"),
        outcome_cuis = c("C0027051", "C0038454"),
        blocklist_cuis = c("C0000001", "C0000002"),
        exposure_name = "Test_Exposure",
        outcome_name = "Test_Outcome",
        min_pmids_degree1 = 100,
        min_pmids_degree2 = 80,
        min_pmids_degree3 = 60,
        pub_year_cutoff = 2010,
        degree = 2,
        predication_type = "CAUSES",
        SemMedDBD_version = "heuristic"
    )

    # Test YAML save/load
    tryCatch({
        temp_file <- tempfile(fileext = ".yaml")
        yaml::write_yaml(test_config, temp_file)
        loaded_config <- load_graph_config(temp_file)

        if (is.null(loaded_config)) {
            cat("❌ Test FAILED: Could not load saved configuration\n")
            return(FALSE)
        }

        unlink(temp_file)  # Clean up
        cat("✅ Test PASSED: YAML save/load works correctly\n")

    }, error = function(e) {
        cat("❌ Test FAILED: YAML save/load error:", e$message, "\n")
        return(FALSE)
    })

    # Test validation functions (if validation module is loaded)
    if (exists("validate_graph_config")) {
        # Test valid configuration
        validation_result <- validate_graph_config(test_config)
        if (!validation_result$valid) {
            cat("❌ Test FAILED: Valid configuration marked as invalid\n")
            cat("Errors:", paste(validation_result$errors, collapse = ", "), "\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Valid configuration validated correctly\n")

        # Test invalid configuration (missing required field)
        invalid_config <- test_config
        invalid_config$exposure_cuis <- NULL
        validation_result <- validate_graph_config(invalid_config)
        if (validation_result$valid) {
            cat("❌ Test FAILED: Invalid configuration marked as valid\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Invalid configuration detected correctly\n")

        # Test invalid CUI format
        invalid_cui_config <- test_config
        invalid_cui_config$exposure_cuis <- c("INVALID", "C0011849")
        validation_result <- validate_graph_config(invalid_cui_config)
        if (validation_result$valid) {
            cat("❌ Test FAILED: Invalid CUI format not detected\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Invalid CUI format detected correctly\n")

        # Test invalid consolidated name (with spaces)
        invalid_name_config <- test_config
        invalid_name_config$exposure_name <- "Test Exposure With Spaces"
        validation_result <- validate_graph_config(invalid_name_config)
        if (validation_result$valid) {
            cat("❌ Test FAILED: Consolidated name with spaces not detected\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Consolidated name with spaces detected correctly\n")

        # Test invalid min_pmids range
        invalid_pmids_config <- test_config
        invalid_pmids_config$min_pmids_degree1 <- 2000  # Out of range (max 1000)
        validation_result <- validate_graph_config(invalid_pmids_config)
        if (validation_result$valid) {
            cat("❌ Test FAILED: Invalid min_pmids range not detected\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Invalid min_pmids range detected correctly\n")

        # Test old format compatibility
        old_format_config <- list(
            exposure_cuis = c("C0011849", "C0020538"),
            outcome_cuis = c("C0027051", "C0038454"),
            exposure_name = "Test_Exposure",
            outcome_name = "Test_Outcome",
            min_pmids = 100,  # Old format
            pub_year_cutoff = 2010,
            degree = 2,
            predication_type = "CAUSES",
            SemMedDBD_version = "heuristic"
        )
        validation_result <- validate_graph_config(old_format_config)
        if (!validation_result$valid) {
            cat("❌ Test FAILED: Old format configuration not supported\n")
            cat("Errors:", paste(validation_result$errors, collapse = ", "), "\n")
            return(FALSE)
        }
        cat("✅ Test PASSED: Old format configuration validated correctly\n")
    }

    cat("\n✅ All tests PASSED!\n")
    return(TRUE)
}

