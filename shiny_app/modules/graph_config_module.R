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

# Try to load shinyjs for better UI updates
tryCatch({
    if (!require(shinyjs)) {
        message("Installing shinyjs package for better UI updates...")
        install.packages("shinyjs")
        library(shinyjs)
    }
    shinyjs_available <- TRUE
}, error = function(e) {
    shinyjs_available <- FALSE
    message("shinyjs not available, using alternative UI update methods")
})

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
        # Add JavaScript for progress handling
        tags$script(HTML(paste0("
            // Progress bar control functions for graph creation
            function updateGraphProgress_", id, "(percent, text, status) {
                $('#", ns("graph_progress"), "').css('width', percent + '%');
                $('#", ns("progress_text"), "').text(text);
                $('#", ns("progress_status"), "').text('Status: ' + status);
            }

            function showGraphProgressSection_", id, "() {
                $('#", ns("progress_section"), "').show();
                updateGraphProgress_", id, "(10, 'Starting...', 'Initializing graph creation process');
            }

            function hideGraphProgressSection_", id, "() {
                $('#", ns("progress_section"), "').hide();
                updateGraphProgress_", id, "(0, 'Initializing...', 'Ready to create graph...');
            }

            // Message handlers for server communication
            Shiny.addCustomMessageHandler('updateGraphProgress_", id, "', function(data) {
                updateGraphProgress_", id, "(data.percent, data.text, data.status);
            });

            Shiny.addCustomMessageHandler('showGraphProgressSection_", id, "', function(data) {
                showGraphProgressSection_", id, "();
            });

            Shiny.addCustomMessageHandler('hideGraphProgressSection_", id, "', function(data) {
                setTimeout(function() {
                    hideGraphProgressSection_", id, "();
                }, 2000); // Brief delay to show completion
            });
        "))),
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
                
                # Configuration Form - Structured Layout

                # Row 1: Exposure CUIs and Consolidated Exposure Name
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
                        )
                    ),
                    column(6,
                        # Consolidated Exposure Name
                        div(
                            class = "form-group",
                            tags$label("Consolidated Exposure Name *", class = "control-label"),
                            textInput(
                                ns("exposure_name"),
                                label = NULL,
                                value = "",
                                placeholder = "e.g., Mental Health Conditions",
                                width = "100%"
                            ),
                            helpText("Required: Single consolidated name representing all exposure concepts. Spaces will be automatically converted to underscores.")
                        )
                    )
                ),

                # Row 2: Outcome CUIs and Consolidated Outcome Name
                fluidRow(
                    column(6,
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
                        )
                    ),
                    column(6,
                        # Consolidated Outcome Name
                        div(
                            class = "form-group",
                            tags$label("Consolidated Outcome Name *", class = "control-label"),
                            textInput(
                                ns("outcome_name"),
                                label = NULL,
                                value = "",
                                placeholder = "e.g., Cardiovascular Events",
                                width = "100%"
                            ),
                            helpText("Required: Single consolidated name representing all outcome concepts. Spaces will be automatically converted to underscores.")
                        )
                    )
                ),

                # Row 3: Squelch Threshold and K-hops
                fluidRow(
                    column(6,
                        # Squelch Threshold (minimum unique pmids)
                        numericInput(
                            ns("min_pmids"),
                            "Squelch Threshold (minimum unique pmids) *",
                            value = 50,
                            min = 1,
                            max = 1000,
                            step = 1,
                            width = "100%"
                        ),
                        helpText("Minimum number of unique PMIDs required for inclusion (1-1000).")
                    ),
                    column(6,
                        # K-hops
                        selectInput(
                            ns("k_hops"),
                            "K-hops *",
                            choices = list(
                                "1" = 1,
                                "2" = 2,
                                "3" = 3
                            ),
                            selected = 1,
                            width = "100%"
                        ),
                        helpText("Number of hops for graph traversal (1-3). Controls the depth of relationships included in the graph.")
                    )
                ),

                # Row 4: Publication Year Cutoff and Predication Types
                fluidRow(
                    column(6,
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
                        # Predication Type
                        textInput(
                            ns("PREDICATION_TYPE"),
                            "Predication Types",
                            value = "CAUSES",
                            placeholder = "e.g., TREATS, CAUSES, PREVENTS",
                            width = "100%"
                        ),
                        helpText("One or more PREDICATION types. Leave as 'CAUSES' for default behavior, or specify custom types (comma-separated). Will be saved as a list in YAML format.")
                    )
                ),

                # Row 5: SemMedDB Version (centered)
                fluidRow(
                    column(6,
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
                    ),
                    column(6,
                        # Empty column for balance
                        div(style = "height: 1px;")
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
                ),

                # Progress Section (initially hidden)
                div(id = ns("progress_section"), style = "margin-top: 20px; display: none;",
                    h4(icon("spinner", class = "fa-spin"), " Creating Graph..."),
                    div(
                        style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; border: 1px solid #dee2e6;",
                        p("Please wait while your graph is being created. This process may take several minutes."),
                        div(class = "progress", style = "height: 25px;",
                            div(id = ns("graph_progress"), class = "progress-bar progress-bar-striped progress-bar-animated",
                                role = "progressbar", style = "width: 0%; background-color: #007bff;",
                                span(id = ns("progress_text"), "Initializing...")
                            )
                        ),
                        br(),
                        div(id = ns("progress_status"), style = "font-size: 14px; color: #6c757d;",
                            "Status: Ready to start..."
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
        
        # Reactive values to store validated parameters and progress
        validated_params <- reactiveVal(NULL)
        progress_state <- reactiveVal("idle")  # idle, validating, saving, executing, complete, error
        progress_message <- reactiveVal("")
        progress_percent <- reactiveVal(0)

        # Validation feedback output with reactive progress
        output$validation_feedback <- renderUI({
            state <- progress_state()
            message <- progress_message()
            percent <- progress_percent()

            if (state == "idle") {
                return(NULL)
            }

            # Determine alert class and icon based on state
            alert_class <- switch(state,
                "validating" = "alert-info",
                "saving" = "alert-info",
                "executing" = "alert-info",
                "complete" = "alert-success",
                "warning" = "alert-warning",
                "error" = "alert-danger",
                "alert-info"
            )

            icon_name <- switch(state,
                "validating" = "spinner",
                "saving" = "spinner",
                "executing" = "spinner",
                "complete" = "check-circle",
                "warning" = "exclamation-triangle",
                "error" = "exclamation-triangle",
                "spinner"
            )

            icon_class <- if (state %in% c("validating", "saving", "executing")) "fa-spin" else ""

            div(
                class = paste("alert", alert_class),
                icon(icon_name, class = icon_class),
                strong(message),
                if (state %in% c("saving", "executing", "complete", "warning")) {
                    tagList(
                        br(), br(),
                        div(class = "progress", style = "height: 25px;",
                            div(class = if (state == "executing") "progress-bar progress-bar-striped progress-bar-animated" else "progress-bar",
                                role = "progressbar",
                                style = paste0("width: ", percent, "%; background-color: ",
                                    switch(state,
                                        "saving" = "#17a2b8",
                                        "executing" = "#17a2b8",
                                        "complete" = "#28a745",
                                        "warning" = "#ffc107",
                                        "error" = "#dc3545",
                                        "#17a2b8"
                                    ), ";"),
                                span(switch(state,
                                    "saving" = "Saving configuration...",
                                    "executing" = "Processing data...",
                                    "complete" = "Complete!",
                                    "warning" = "Completed with warnings",
                                    "error" = "Failed",
                                    "Processing..."
                                ))
                            )
                        )
                    )
                }
            )
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

        # Predication type validation function
        validate_predication_types <- function(predication_string) {
            # Define valid predication types (common ones from SemMedDB)
            valid_types <- c("CAUSES", "TREATS", "PREVENTS", "INTERACTS_WITH", "AFFECTS",
                           "ASSOCIATED_WITH", "PREDISPOSES", "COMPLICATES", "AUGMENTS",
                           "DISRUPTS", "INHIBITS", "STIMULATES", "PRODUCES", "MANIFESTATION_OF",
                           "RESULT_OF", "PROCESS_OF", "PART_OF", "ISA", "LOCATION_OF",
                           "ADMINISTERED_TO", "METHOD_OF", "USES", "DIAGNOSES")

            if (is.null(predication_string) || trimws(predication_string) == "") {
                return(list(valid = TRUE, types = c("CAUSES")))  # Default to CAUSES
            }

            # Split and clean predication types
            types <- trimws(unlist(strsplit(predication_string, ",")))
            types <- types[types != ""]  # Remove empty strings
            types <- toupper(types)  # Convert to uppercase for comparison

            if (length(types) == 0) {
                return(list(valid = TRUE, types = c("CAUSES")))  # Default if empty
            }

            # Check for invalid types
            invalid_types <- types[!types %in% valid_types]

            if (length(invalid_types) > 0) {
                return(list(
                    valid = FALSE,
                    message = paste("Invalid predication types:", paste(invalid_types, collapse = ", "),
                                  ". Valid types include:", paste(head(valid_types, 10), collapse = ", "), "...")
                ))
            }

            return(list(valid = TRUE, types = types))
        }

        # Name validation function for single consolidated names
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

            # Validate required fields
            if (is.null(input$min_pmids) || is.na(input$min_pmids)) {
                errors <- c(errors, "Squelch Threshold (minimum unique pmids) is required")
            } else if (!is.numeric(input$min_pmids) || input$min_pmids < 1 || input$min_pmids > 1000) {
                errors <- c(errors, "Squelch Threshold (minimum unique pmids) must be a number between 1 and 1000")
            } else if (input$min_pmids != as.integer(input$min_pmids)) {
                errors <- c(errors, "Squelch Threshold (minimum unique pmids) must be a whole number")
            }
            
            if (is.null(input$pub_year_cutoff) || input$pub_year_cutoff == "") {
                errors <- c(errors, "Publication Year Cutoff is required")
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
                outcome_cuis = if (outcome_validation$valid) outcome_validation$cuis else NULL,
                exposure_name = if (exposure_name_validation$valid) exposure_name_validation$name else NULL,
                outcome_name = if (outcome_name_validation$valid) outcome_name_validation$name else NULL,
                predication_types = if (predication_validation$valid) predication_validation$types else c("CAUSES")
            ))
        }
        
        # Process and save configuration
        observeEvent(input$create_graph, {

            # Show progress section and start progress
            session$sendCustomMessage(paste0("showGraphProgressSection_", id), list())

            # Set initial progress state
            progress_state("validating")
            progress_message("Validating inputs and saving configuration...")
            progress_percent(10)

            # Update progress bar
            session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                percent = 10,
                text = "Validating inputs...",
                status = "Checking configuration parameters"
            ))

            # Allow UI to update
            Sys.sleep(1)

            # Validate inputs
            validation_result <- validate_inputs()

            if (!validation_result$valid) {
                # Show validation errors
                progress_state("error")
                progress_message("Validation Errors:")
                progress_percent(0)

                # Also show detailed errors in a separate output
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
            
            # Update progress for saving
            progress_state("saving")
            progress_message("Configuration validated! Saving to YAML file...")
            progress_percent(30)

            # Update progress bar
            session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                percent = 30,
                text = "Saving configuration...",
                status = "Writing parameters to user_input.yaml"
            ))

            Sys.sleep(1)

            # Prepare parameters for saving
            tryCatch({
                # Use validated predication types from validation result
                predication_types <- validation_result$predication_types

                # Create parameter list
                params <- list(
                    exposure_cuis = validation_result$exposure_cuis,
                    outcome_cuis = validation_result$outcome_cuis,
                    exposure_name = validation_result$exposure_name,
                    outcome_name = validation_result$outcome_name,
                    min_pmids = as.integer(input$min_pmids),
                    pub_year_cutoff = as.integer(input$pub_year_cutoff),
                    k_hops = as.integer(input$k_hops),
                    predication_type = predication_types,
                    SemMedDBD_version = input$SemMedDBD_version
                )

                # Save to YAML file in the project root directory
                yaml_file <- "../user_input.yaml"
                write_yaml(params, yaml_file)

                # Store validated parameters
                validated_params(params)

                # Update progress for script execution - this will show immediately
                progress_state("executing")
                progress_message("Configuration saved! Now executing graph creation script...")
                progress_percent(60)

                # Update progress bar for script execution
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 60,
                    text = "Executing script...",
                    status = "Running graph creation pipeline - this may take several minutes"
                ))

                # Add delay to ensure UI updates before blocking system call
                Sys.sleep(2)

                # Execute the graph creation shell script in a way that allows UI updates
                tryCatch({
                    # Change to project root directory for script execution
                    original_wd <- getwd()
                    setwd("..")  # Move to project root

                    # Check if script exists and is executable
                    script_path <- "graph_creation/example/run_pushkin.sh"
                    if (!file.exists(script_path)) {
                        stop(paste("Script not found:", script_path))
                    }

                    # Update progress to show script is actually running
                    progress_state("executing")
                    progress_message("Script is running... This may take several minutes. Please wait.")
                    progress_percent(80)

                    # Update progress bar to show script is running
                    session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                        percent = 80,
                        text = "Processing data...",
                        status = "Graph creation script is running - please be patient"
                    ))

                    # Execute the shell script with proper error handling
                    script_exit_code <- system(script_path, wait = TRUE)

                    # Return to original working directory
                    setwd(original_wd)

                    # Check exit code and update progress accordingly
                    if (script_exit_code == 0) {
                        # Success
                        progress_state("complete")
                        progress_message("Success! Configuration saved and graph creation script executed successfully. Check the graph_creation/result directory for generated graphs.")
                        progress_percent(100)

                        # Update progress bar to show completion
                        session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                            percent = 100,
                            text = "Complete!",
                            status = "Graph creation completed successfully"
                        ))

                        # Hide progress section after delay
                        session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())

                        # Show notification with correct type
                        showNotification(
                            "Configuration saved and graph creation script executed successfully",
                            type = "message",
                            duration = 8
                        )
                    } else {
                        # Script executed but returned non-zero exit code
                        progress_state("warning")
                        progress_message(paste("Configuration saved, but script execution completed with warnings. Exit code:", script_exit_code, ". Check the console output or graph_creation/result directory for details."))
                        progress_percent(100)

                        # Update progress bar to show warning
                        session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                            percent = 100,
                            text = "Completed with warnings",
                            status = paste("Script completed with exit code:", script_exit_code)
                        ))

                        # Hide progress section after delay
                        session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())

                        showNotification(
                            paste("Configuration saved. Script completed with exit code:", script_exit_code),
                            type = "warning",
                            duration = 10
                        )
                    }

                }, error = function(script_error) {
                    # Return to original working directory in case of error
                    if (exists("original_wd")) {
                        setwd(original_wd)
                    }

                    # Update progress to show error
                    progress_state("error")
                    progress_message(paste("Configuration saved successfully, but script execution failed:", as.character(script_error$message), ". The configuration has been saved to user_input.yaml. You can manually run the script: graph_creation/example/run_pushkin.sh"))
                    progress_percent(100)

                    # Update progress bar to show error
                    session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                        percent = 100,
                        text = "Script execution failed",
                        status = paste("Error:", as.character(script_error$message))
                    ))

                    # Hide progress section after delay
                    session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())

                    # Show notification about partial success with correct type
                    showNotification(
                        paste("Configuration saved, but script execution failed:", as.character(script_error$message)),
                        type = "warning",
                        duration = 10
                    )
                })
                
            }, error = function(e) {
                # Handle file saving errors
                progress_state("error")
                progress_message(paste("Error saving configuration:", as.character(e$message)))
                progress_percent(0)

                # Update progress bar to show error
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 100,
                    text = "Configuration save failed",
                    status = paste("Error:", as.character(e$message))
                ))

                # Hide progress section after delay
                session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())

                showNotification(
                    paste("Error saving configuration:", as.character(e$message)),
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
load_graph_config <- function(yaml_file = "../user_input.yaml") {
    if (!file.exists(yaml_file)) {
        warning(paste("Configuration file", yaml_file, "not found"))
        return(NULL)
    }

    tryCatch({
        config <- read_yaml(yaml_file)

        # Validate loaded configuration
        required_fields <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                           "min_pmids", "pub_year_cutoff", "k_hops",
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
load_graph_config <- function(yaml_file = "../user_input.yaml") {
    if (!file.exists(yaml_file)) {
        warning(paste("Configuration file", yaml_file, "not found"))
        return(NULL)
    }

    tryCatch({
        config <- read_yaml(yaml_file)

        # Validate loaded configuration
        required_fields <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                           "min_pmids", "pub_year_cutoff", "k_hops",
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
    required_fields <- c("exposure_cuis", "outcome_cuis", "exposure_name", "outcome_name",
                        "min_pmids", "pub_year_cutoff", "k_hops",
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

    # Validate numeric ranges
    if ("min_pmids" %in% names(config)) {
        if (!is.numeric(config$min_pmids) || config$min_pmids < 1 || config$min_pmids > 1000) {
            errors <- c(errors, "min_pmids must be a number between 1 and 1000")
        } else if (config$min_pmids != as.integer(config$min_pmids)) {
            errors <- c(errors, "min_pmids must be a whole number")
        }
    }

    if ("pub_year_cutoff" %in% names(config)) {
        if (!is.numeric(config$pub_year_cutoff) || config$pub_year_cutoff < 1900 || config$pub_year_cutoff > as.numeric(format(Sys.Date(), "%Y"))) {
            errors <- c(errors, "pub_year_cutoff must be a valid year")
        }
    }

    if ("k_hops" %in% names(config)) {
        if (!is.numeric(config$k_hops) || config$k_hops < 1 || config$k_hops > 3) {
            errors <- c(errors, "k_hops must be between 1 and 3")
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
        exposure_name = "Test_Exposure",
        outcome_name = "Test_Outcome",
        min_pmids = 100,
        pub_year_cutoff = 2010,
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
