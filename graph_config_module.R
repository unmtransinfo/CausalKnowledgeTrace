# Graph Configuration Module
# This module provides a user interface for configuring knowledge graph parameters
# and saves them to a user_input.yaml file for downstream processing
# Author: CausalKnowledgeTrace Application
# Dependencies: shiny, yaml

# Required libraries for this module
if (!require(shiny)) stop("shiny package is required")
if (!require(yaml)) {
    message("Installing yaml package...")
    install.packages("yaml")
    library(yaml)
}

#' Graph Configuration UI Function
#' 
#' Creates the user interface for knowledge graph parameter configuration
#' 
#' @param id Character string. The namespace identifier for the module
#' @return Shiny UI elements for graph configuration
#' @export
graphConfigUI <- function(id) {
    ns <- NS(id)
    
    tagList(
        fluidRow(
            box(
                title = "Knowledge Graph Configuration", 
                status = "primary", 
                solidHeader = TRUE,
                width = 12,
                
                # Instructions
                div(
                    class = "alert alert-info",
                    icon("info-circle"),
                    strong("Instructions: "),
                    "Configure the parameters below to generate your knowledge graph. ",
                    "All fields marked with * are required."
                ),
                
                # Configuration Form
                fluidRow(
                    column(6,
                        # Exposure CUIs
                        div(
                            class = "form-group",
                            tags$label("Exposure CUIs *", class = "control-label"),
                            textAreaInput(
                                ns("exposure_cuis"),
                                label = NULL,
                                value = "C0011849, C0020538",
                                placeholder = "C0011849, C0020538",
                                rows = 3,
                                width = "100%"
                            ),
                            helpText("One or more CUIs representing exposure concepts. Enter comma-delimited CUI codes (format: C followed by 7 digits).")
                        ),

                        # Outcome CUIs
                        div(
                            class = "form-group",
                            tags$label("Outcome CUIs *", class = "control-label"),
                            textAreaInput(
                                ns("outcome_cuis"),
                                label = NULL,
                                value = "C0027051, C0038454",
                                placeholder = "C0027051, C0038454",
                                rows = 3,
                                width = "100%"
                            ),
                            helpText("One or more CUIs representing outcome concepts. Enter comma-delimited CUI codes (format: C followed by 7 digits).")
                        ),
                        
                        # Minimum PMIDs
                        selectInput(
                            ns("min_pmids"),
                            "Minimum Number of Unique PMIDs *",
                            choices = list(
                                "10" = 10,
                                "25" = 25,
                                "50" = 50,
                                "100" = 100,
                                "250" = 250,
                                "500" = 500,
                                "1000" = 1000,
                                "2000" = 2000,
                                "5000" = 5000
                            ),
                            selected = 100,
                            width = "100%"
                        ),
                        helpText("Minimum number of unique PMIDs required for inclusion."),
                        
                        # Publication Year Cutoff
                        selectInput(
                            ns("pub_year_cutoff"),
                            "Publication Year Cutoff *",
                            choices = list(
                                "2000" = 2000,
                                "2005" = 2005,
                                "2010" = 2010,
                                "2015" = 2015,
                                "2020" = 2020
                            ),
                            selected = 2010,
                            width = "100%"
                        ),
                        helpText("Only include citations published on or after this year.")
                    ),
                    
                    column(6,
                        # Squelch Threshold
                        selectInput(
                            ns("squelch_threshold"),
                            "Squelch Threshold *",
                            choices = list(
                                "10" = 10,
                                "25" = 25,
                                "50" = 50,
                                "100" = 100,
                                "500" = 500
                            ),
                            selected = 50,
                            width = "100%"
                        ),
                        helpText("Minimum number of distinct citations supporting a causal edge for inclusion."),
                        
                        # K-hops (temporarily restricted)
                        div(
                            selectInput(
                                ns("k_hops"),
                                "K-hops *",
                                choices = list("1" = 1),
                                selected = 1,
                                width = "100%"
                            ),
                            # Add disabled styling
                            tags$script(HTML(paste0(
                                "document.getElementById('", ns("k_hops"), "').disabled = true;"
                            )))
                        ),
                        helpText("K-hops is temporarily locked to 1. Additional options will be available in future updates."),
                        
                        # Predication Type
                        textInput(
                            ns("PREDICATION_TYPE"),
                            "Predication Types",
                            value = "",
                            placeholder = "e.g., TREATS, CAUSES, PREVENTS",
                            width = "100%"
                        ),
                        helpText("One or more PREDICATION types. Leave empty to include all types."),
                        
                        # SemMedDB Version
                        selectInput(
                            ns("SemMedDBD_version"),
                            "SemMedDB Version *",
                            choices = list(
                                "heuristic" = "heuristic",
                                "LLM-based" = "LLM-based",
                                "heuristic+LLM-based" = "heuristic+LLM-based"
                            ),
                            selected = "heuristic",
                            width = "100%"
                        ),
                        helpText("SemMedDB version by filtering method.")
                    )
                ),
                
                # Action Button and Status
                hr(),
                fluidRow(
                    column(6,
                        actionButton(
                            ns("create_graph"),
                            "Create Graph",
                            class = "btn-primary btn-lg",
                            icon = icon("cogs"),
                            width = "100%"
                        )
                    ),
                    column(6,
                        # Status output
                        div(
                            id = ns("status_area"),
                            style = "margin-top: 10px;",
                            uiOutput(ns("validation_feedback"))
                        )
                    )
                )
            )
        )
    )
}

#' Graph Configuration Server Function
#' 
#' Server logic for the graph configuration module
#' 
#' @param id Character string. The namespace identifier for the module
#' @return Reactive value containing validated parameters
#' @export
graphConfigServer <- function(id) {
    moduleServer(id, function(input, output, session) {
        
        # Reactive value to store validated parameters
        validated_params <- reactiveVal(NULL)
        
        # Validation feedback output
        output$validation_feedback <- renderUI({
            # This will be updated when validation occurs
            NULL
        })
        
        # CUI validation function
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
        
        # Main validation function
        validate_inputs <- function() {
            errors <- c()
            
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
            
            # Validate required fields
            if (is.null(input$min_pmids) || input$min_pmids == "") {
                errors <- c(errors, "Minimum PMIDs is required")
            }
            
            if (is.null(input$pub_year_cutoff) || input$pub_year_cutoff == "") {
                errors <- c(errors, "Publication Year Cutoff is required")
            }
            
            if (is.null(input$squelch_threshold) || input$squelch_threshold == "") {
                errors <- c(errors, "Squelch Threshold is required")
            }
            
            if (is.null(input$k_hops) || input$k_hops == "") {
                errors <- c(errors, "K-Hops is required")
            }
            
            if (is.null(input$SemMedDBD_version) || input$SemMedDBD_version == "") {
                errors <- c(errors, "SemMedDB Version is required")
            }
            
            return(list(
                valid = length(errors) == 0,
                errors = errors,
                exposure_cuis = if (exposure_validation$valid) exposure_validation$cuis else NULL,
                outcome_cuis = if (outcome_validation$valid) outcome_validation$cuis else NULL
            ))
        }
        
        # Process and save configuration
        observeEvent(input$create_graph, {
            
            # Show loading indicator
            output$validation_feedback <- renderUI({
                div(
                    class = "alert alert-info",
                    icon("spinner", class = "fa-spin"),
                    "Validating inputs and saving configuration..."
                )
            })
            
            # Add small delay for user feedback
            Sys.sleep(0.5)
            
            # Validate inputs
            validation_result <- validate_inputs()
            
            if (!validation_result$valid) {
                # Show validation errors
                output$validation_feedback <- renderUI({
                    div(
                        class = "alert alert-danger",
                        icon("exclamation-triangle"),
                        strong("Validation Errors:"),
                        tags$ul(
                            lapply(validation_result$errors, function(error) {
                                tags$li(error)
                            })
                        )
                    )
                })
                return()
            }
            
            # Prepare parameters for saving
            tryCatch({
                # Process predication types
                predication_types <- if (is.null(input$PREDICATION_TYPE) || input$PREDICATION_TYPE == "") {
                    ""
                } else {
                    input$PREDICATION_TYPE
                }
                
                # Create parameter list
                params <- list(
                    exposure_cuis = validation_result$exposure_cuis,
                    outcome_cuis = validation_result$outcome_cuis,
                    min_pmids = as.integer(input$min_pmids),
                    pub_year_cutoff = as.integer(input$pub_year_cutoff),
                    squelch_threshold = as.integer(input$squelch_threshold),
                    k_hops = as.integer(input$k_hops),
                    PREDICATION_TYPE = predication_types,
                    SemMedDBD_version = input$SemMedDBD_version
                )
                
                # Save to YAML file
                yaml_file <- "user_input.yaml"
                write_yaml(params, yaml_file)
                
                # Store validated parameters
                validated_params(params)
                
                # Show success message
                output$validation_feedback <- renderUI({
                    div(
                        class = "alert alert-success",
                        icon("check-circle"),
                        strong("Success! "),
                        "Configuration saved to ", code("user_input.yaml"), ". ",
                        "You can now proceed with graph generation."
                    )
                })
                
                # Show notification
                showNotification(
                    paste("Configuration saved successfully to", yaml_file),
                    type = "message",
                    duration = 5
                )
                
            }, error = function(e) {
                # Handle file saving errors
                output$validation_feedback <- renderUI({
                    div(
                        class = "alert alert-danger",
                        icon("exclamation-triangle"),
                        strong("Error saving configuration: "),
                        e$message
                    )
                })
                
                showNotification(
                    paste("Error saving configuration:", e$message),
                    type = "error",
                    duration = 10
                )
            })
        })
        
        # Return reactive value with validated parameters
        return(validated_params)
    })
}

# ============================================================================
# HELPER FUNCTIONS AND UTILITIES
# ============================================================================

#' Load Configuration from YAML File
#'
#' Helper function to load previously saved configuration
#'
#' @param yaml_file Path to the YAML configuration file (default: "user_input.yaml")
#' @return List containing configuration parameters, or NULL if file doesn't exist
#' @export
load_graph_config <- function(yaml_file = "user_input.yaml") {
    if (!file.exists(yaml_file)) {
        warning(paste("Configuration file", yaml_file, "not found"))
        return(NULL)
    }

    tryCatch({
        config <- read_yaml(yaml_file)

        # Validate loaded configuration
        required_fields <- c("exposure_cuis", "outcome_cuis", "min_pmids",
                           "pub_year_cutoff", "squelch_threshold", "k_hops",
                           "SemMedDBD_version")

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

#' Test Graph Configuration Module
#'
#' Function to test the module functionality independently
#'
#' @return TRUE if all tests pass, FALSE otherwise
#' @export
test_graph_config_module <- function() {
    cat("Testing Graph Configuration Module...\n")

    # Test configuration
    test_config <- list(
        exposure_cuis = c("C0011849", "C0020538"),
        outcome_cuis = c("C0027051", "C0038454"),
        min_pmids = 100,
        pub_year_cutoff = 2010,
        squelch_threshold = 50,
        k_hops = 2,
        PREDICATION_TYPE = "TREATS, CAUSES",
        SemMedDBD_version = "heuristic"
    )

    # Test YAML save/load
    tryCatch({
        temp_file <- tempfile(fileext = ".yaml")
        write_yaml(test_config, temp_file)
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

    cat("🎉 Module test completed successfully!\n")
    return(TRUE)
}

# ============================================================================
# INTEGRATION EXAMPLES AND DOCUMENTATION
# ============================================================================

#' Example Integration Code
#'
#' This section provides examples of how to integrate the graph configuration
#' module into the main CausalKnowledgeTrace application.
#'
#' @examples
#' # In your main app.R file, add the following:
#'
#' # 1. Source the module at the top of app.R
#' source("graph_config_module.R")
#'
#' # 2. Add to your dashboardSidebar menu:
#' menuItem("Graph Configuration", tabName = "config", icon = icon("cogs"))
#'
#' # 3. Add to your dashboardBody tabItems:
#' tabItem(tabName = "config",
#'     graphConfigUI("config")
#' )
#'
#' # 4. Add to your server function:
#' config_params <- graphConfigServer("config")
#'
#' # 5. Access the validated parameters:
#' observe({
#'     params <- config_params()
#'     if (!is.null(params)) {
#'         # Parameters are available and validated
#'         cat("Configuration updated with", length(params$exposure_cuis), "exposure CUIs\n")
#'     }
#' })

#' Load Configuration from YAML File
#'
#' Helper function to load previously saved configuration
#'
#' @param yaml_file Path to the YAML configuration file (default: "user_input.yaml")
#' @return List containing configuration parameters, or NULL if file doesn't exist
#' @export
load_graph_config <- function(yaml_file = "user_input.yaml") {
    if (!file.exists(yaml_file)) {
        warning(paste("Configuration file", yaml_file, "not found"))
        return(NULL)
    }

    tryCatch({
        config <- read_yaml(yaml_file)

        # Validate loaded configuration
        required_fields <- c("exposure_cuis", "outcome_cuis", "min_pmids",
                           "pub_year_cutoff", "squelch_threshold", "k_hops",
                           "SemMedDBD_version")

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

    # Check required fields
    required_fields <- c("exposure_cuis", "outcome_cuis", "min_pmids",
                        "pub_year_cutoff", "squelch_threshold", "k_hops",
                        "SemMedDBD_version")

    missing_fields <- required_fields[!required_fields %in% names(config)]
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

    # Validate numeric ranges
    if ("min_pmids" %in% names(config)) {
        if (!is.numeric(config$min_pmids) || config$min_pmids < 1) {
            errors <- c(errors, "min_pmids must be a positive number")
        }
    }

    if ("pub_year_cutoff" %in% names(config)) {
        if (!is.numeric(config$pub_year_cutoff) || config$pub_year_cutoff < 1900 || config$pub_year_cutoff > as.numeric(format(Sys.Date(), "%Y"))) {
            errors <- c(errors, "pub_year_cutoff must be a valid year")
        }
    }

    if ("k_hops" %in% names(config)) {
        if (!is.numeric(config$k_hops) || config$k_hops < 1 || config$k_hops > 5) {
            errors <- c(errors, "k_hops must be between 1 and 5")
        }
    }

    # Validate SemMedDB version
    if ("SemMedDBD_version" %in% names(config)) {
        valid_versions <- c("heuristic", "LLM-based", "heuristic+LLM-based")
        if (!config$SemMedDBD_version %in% valid_versions) {
            errors <- c(errors, paste("SemMedDBD_version must be one of:", paste(valid_versions, collapse = ", ")))
        }
    }

    return(list(valid = length(errors) == 0, errors = errors))
}

# ============================================================================
# TESTING FUNCTIONS
# ============================================================================

#' Test Graph Configuration Module
#'
#' Function to test the module functionality independently
#'
#' @return TRUE if all tests pass, FALSE otherwise
#' @export
test_graph_config_module <- function() {
    cat("Testing Graph Configuration Module...\n")

    # Test 1: Valid configuration
    test_config <- list(
        exposure_cuis = c("C0011849", "C0020538"),
        outcome_cuis = c("C0027051", "C0038454"),
        min_pmids = 100,
        pub_year_cutoff = 2010,
        squelch_threshold = 50,
        k_hops = 2,
        PREDICATION_TYPE = "TREATS, CAUSES",
        SemMedDBD_version = "heuristic"
    )

    validation_result <- validate_graph_config(test_config)
    if (!validation_result$valid) {
        cat("❌ Test 1 FAILED: Valid configuration rejected\n")
        cat("Errors:", paste(validation_result$errors, collapse = "; "), "\n")
        return(FALSE)
    }
    cat("✅ Test 1 PASSED: Valid configuration accepted\n")

    # Test 2: Invalid CUI format
    test_config_invalid <- test_config
    test_config_invalid$exposure_cuis <- c("C001184", "INVALID")  # Wrong format

    validation_result <- validate_graph_config(test_config_invalid)
    if (validation_result$valid) {
        cat("❌ Test 2 FAILED: Invalid CUI format accepted\n")
        return(FALSE)
    }
    cat("✅ Test 2 PASSED: Invalid CUI format rejected\n")

    # Test 3: Missing required fields
    test_config_missing <- test_config
    test_config_missing$exposure_cuis <- NULL

    validation_result <- validate_graph_config(test_config_missing)
    if (validation_result$valid) {
        cat("❌ Test 3 FAILED: Missing required field accepted\n")
        return(FALSE)
    }
    cat("✅ Test 3 PASSED: Missing required field rejected\n")

    # Test 4: YAML save/load
    tryCatch({
        temp_file <- tempfile(fileext = ".yaml")
        write_yaml(test_config, temp_file)
        loaded_config <- load_graph_config(temp_file)

        if (is.null(loaded_config)) {
            cat("❌ Test 4 FAILED: Could not load saved configuration\n")
            return(FALSE)
        }

        # Compare key fields
        if (!identical(loaded_config$exposure_cuis, test_config$exposure_cuis) ||
            !identical(loaded_config$outcome_cuis, test_config$outcome_cuis)) {
            cat("❌ Test 4 FAILED: Loaded configuration doesn't match saved\n")
            return(FALSE)
        }

        unlink(temp_file)  # Clean up
        cat("✅ Test 4 PASSED: YAML save/load works correctly\n")

    }, error = function(e) {
        cat("❌ Test 4 FAILED: YAML save/load error:", e$message, "\n")
        return(FALSE)
    })

    cat("🎉 All tests passed! Module is ready for integration.\n")
    return(TRUE)
}
