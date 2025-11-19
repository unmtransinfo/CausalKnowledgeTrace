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

# Source CUI search module
tryCatch({
    source("modules/cui_search.R", local = TRUE)
    cui_search_available <- TRUE
    cat("CUI search module loaded successfully\n")
}, error = function(e) {
    cui_search_available <- FALSE
    cat("CUI search module not available:", e$message, "\n")
    cat("Falling back to manual CUI entry only\n")
})

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

#' Load graph configuration from YAML file
#'
#' Helper function to load configuration at UI build time
#'
#' @return List containing configuration or NULL if not found
#' @keywords internal
load_graph_config_at_ui_time <- function() {
    config_file <- "../user_input.yaml"
    if (file.exists(config_file)) {
        tryCatch({
            config <- yaml::read_yaml(config_file)
            return(config)
        }, error = function(e) {
            return(NULL)
        })
    }
    return(NULL)
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

    # Load configuration at UI build time (before rendering)
    ui_config <- load_graph_config_at_ui_time()

    # Extract CUIs for use in UI
    exposure_cuis_ui <- if (!is.null(ui_config) && !is.null(ui_config$exposure_cuis)) {
        paste(unlist(ui_config$exposure_cuis), collapse = ", ")
    } else {
        "C0020538, C4013784, C0221155, C0745114, C0745135"
    }

    outcome_cuis_ui <- if (!is.null(ui_config) && !is.null(ui_config$outcome_cuis)) {
        paste(unlist(ui_config$outcome_cuis), collapse = ", ")
    } else {
        "C2677888, C0750901, C0494463, C0002395"
    }

    exposure_name_ui <- if (!is.null(ui_config) && !is.null(ui_config$exposure_name)) {
        ui_config$exposure_name
    } else {
        "Hypertension"
    }

    outcome_name_ui <- if (!is.null(ui_config) && !is.null(ui_config$outcome_name)) {
        ui_config$outcome_name
    } else {
        "Alzheimers"
    }

    min_pmids_ui <- if (!is.null(ui_config) && !is.null(ui_config$min_pmids)) {
        ui_config$min_pmids
    } else {
        10
    }

    pub_year_cutoff_ui <- if (!is.null(ui_config) && !is.null(ui_config$pub_year_cutoff)) {
        ui_config$pub_year_cutoff
    } else {
        2015
    }

    degree_ui <- if (!is.null(ui_config) && !is.null(ui_config$degree)) {
        as.character(ui_config$degree)
    } else {
        "2"
    }

    predication_type_ui <- if (!is.null(ui_config) && !is.null(ui_config$predication_type)) {
        ui_config$predication_type
    } else {
        "CAUSES"
    }

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
                
                # Configuration Form - Two Column Layout
                fluidRow(
                    # Left Column: CUI-related components
                    column(6,
                        # Exposure CUIs
                        div(
                            class = "form-group",
                            if (exists("cui_search_available") && cui_search_available) {
                                # Use searchable CUI interface
                                cuiSearchUI(
                                    ns("exposure_cui_search"),
                                    label = "Exposure CUIs *",
                                    placeholder = "Search for exposure concepts (e.g., hypertension, diabetes)...",
                                    height = "250px",
                                    initial_value = exposure_cuis_ui
                                )
                            } else {
                                # Fallback to manual entry
                                tagList(
                                    tags$label("Exposure CUIs *", class = "control-label"),
                                    textAreaInput(
                                        ns("exposure_cuis"),
                                        label = NULL,
                                        value = exposure_cuis_ui,
                                        placeholder = "C0020538, C4013784, C0221155, C0745114, C0745135",
                                        rows = 3,
                                        width = "100%"
                                    ),
                                    helpText("One or more CUIs representing exposure concepts. Enter comma-delimited CUI codes (format: C followed by 7 digits).")
                                )
                            }
                        ),

                        # Outcome CUIs
                        div(
                            class = "form-group",
                            if (exists("cui_search_available") && cui_search_available) {
                                # Use searchable CUI interface
                                cuiSearchUI(
                                    ns("outcome_cui_search"),
                                    label = "Outcome CUIs *",
                                    placeholder = "Search for outcome concepts (e.g., alzheimer, stroke)...",
                                    height = "250px",
                                    initial_value = outcome_cuis_ui
                                )
                            } else {
                                # Fallback to manual entry
                                tagList(
                                    tags$label("Outcome CUIs *", class = "control-label"),
                                    textAreaInput(
                                        ns("outcome_cuis"),
                                        label = NULL,
                                        value = outcome_cuis_ui,
                                        placeholder = "C2677888, C0750901, C0494463, C0002395",
                                        rows = 3,
                                        width = "100%"
                                    ),
                                    helpText("One or more CUIs representing outcome concepts. Enter comma-delimited CUI codes (format: C followed by 7 digits).")
                                )
                            }
                        ),

                        # Blocklist CUIs
                        div(
                            class = "form-group",
                            if (exists("cui_search_available") && cui_search_available) {
                                # Use searchable CUI interface
                                cuiSearchUI(
                                    ns("blocklist_cui_search"),
                                    label = "Blocklist CUIs",
                                    placeholder = "Search for concepts to exclude from analysis (e.g., demographics, age)...",
                                    height = "200px"
                                )
                            } else {
                                # Fallback to manual entry
                                tagList(
                                    tags$label("Blocklist CUIs", class = "control-label"),
                                    textAreaInput(
                                        ns("blocklist_cuis"),
                                        label = NULL,
                                        value = "",
                                        placeholder = "C0000000, C1111111, C2222222 (Press Enter to search)",
                                        rows = 2,
                                        width = "100%"
                                    ),
                                    helpText("Optional: CUIs to exclude from the graph analysis. Enter comma-delimited CUI codes (format: C followed by 7 digits). These concepts will be filtered out during graph creation. Press Enter to search for concepts.")
                                )
                            }
                        )
                    ),

                    # Right Column: Configuration parameters
                    column(6,
                        # Consolidated Exposure Name
                        div(
                            class = "form-group",
                            tags$label("Consolidated Exposure Name *", class = "control-label"),
                            textInput(
                                ns("exposure_name"),
                                label = NULL,
                                value = "Hypertension",
                                placeholder = "Hypertension",
                                width = "100%"
                            ),
                            helpText("Required: Single consolidated name representing all exposure concepts. Spaces will be automatically converted to underscores.")
                        ),

                        # Consolidated Outcome Name
                        div(
                            class = "form-group",
                            tags$label("Consolidated Outcome Name *", class = "control-label"),
                            textInput(
                                ns("outcome_name"),
                                label = NULL,
                                value = "Alzheimers",
                                placeholder = "Alzheimers",
                                width = "100%"
                            ),
                            helpText("Required: Single consolidated name representing all outcome concepts. Spaces will be automatically converted to underscores.")
                        ),

                        # Squelch Threshold
                        div(
                            class = "form-group",
                            numericInput(
                                ns("min_pmids"),
                                "Squelch Threshold (minimum unique pmids) *",
                                value = 10,
                                min = 1,
                                max = 1000,
                                step = 1,
                                width = "100%"
                            ),
                            helpText("Minimum number of unique PMIDs required for inclusion (1-1000).")
                        ),

                        # Degree
                        div(
                            class = "form-group",
                            selectInput(
                                ns("degree"),
                                "Degree *",
                                choices = list(
                                    "1" = 1,
                                    "2" = 2,
                                    "3" = 3
                                ),
                                selected = 1,
                                width = "100%"
                            ),
                            helpText("Number of degrees for graph traversal (1-3). Controls the depth of relationships included in the graph.")
                        ),

                        # Publication Year Cutoff
                        div(
                            class = "form-group",
                            selectInput(
                                ns("pub_year_cutoff"),
                                "Publication Year Cutoff *",
                                choices = setNames(1980:2025, 1980:2025),
                                selected = 2015,
                                width = "100%"
                            ),
                            helpText("Only include citations published on or after this year.")
                        ),

                        # Predication Types
                        div(
                            class = "form-group",
                            selectInput(
                                ns("PREDICATION_TYPE"),
                                "Predication Types",
                                choices = list(
                                    "AFFECTS" = "AFFECTS",
                                    "AUGMENTS" = "AUGMENTS",
                                    "CAUSES" = "CAUSES",
                                    "COMPLICATES" = "COMPLICATES",
                                    "DISRUPTS" = "DISRUPTS",
                                    "INHIBITS" = "INHIBITS",
                                    "PRECEDES" = "PRECEDES",
                                    "PREDISPOSES" = "PREDISPOSES",
                                    "PREVENTS" = "PREVENTS",
                                    "PRODUCES" = "PRODUCES",
                                    "STIMULATES" = "STIMULATES",
                                    "TREATS" = "TREATS"
                                ),
                                selected = "CAUSES",
                                multiple = TRUE,
                                width = "100%"
                            ),
                            helpText("Select one or more predication types. CAUSES is selected by default. Hold Ctrl/Cmd to select multiple. Will be saved as comma-separated values in YAML format.")
                        ),

                        # SemMedDB Version
                        div(
                            class = "form-group",
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

        # Initialize database connection for CUI search
        if (exists("cui_search_available") && cui_search_available) {
            # Initialize database connection pool
            db_init_result <- init_database_pool()
            if (!db_init_result$success) {
                if (exists("log_message")) {
                    log_message(paste("Database connection failed:", db_init_result$message), "WARNING")
                    log_message("CUI search functionality will be limited", "WARNING")
                }
            } else {
                if (exists("log_message")) {
                    log_message("Database connection initialized for CUI search", "INFO")
                }
            }

            # Load configuration from YAML file if it exists
            loaded_config <- load_graph_config("../user_input.yaml")

            # Debug logging
            if (!is.null(loaded_config)) {
                cat("✓ Configuration loaded from user_input.yaml\n")
                cat("  Exposure CUIs:", paste(unlist(loaded_config$exposure_cuis), collapse = ", "), "\n")
                cat("  Outcome CUIs:", paste(unlist(loaded_config$outcome_cuis), collapse = ", "), "\n")
            } else {
                cat("⚠ No configuration file found, using defaults\n")
            }

            # Use loaded config CUIs if available, otherwise use defaults
            exposure_cuis_initial <- if (!is.null(loaded_config) && !is.null(loaded_config$exposure_cuis)) {
                unlist(loaded_config$exposure_cuis)
            } else {
                c("C0020538", "C4013784", "C0221155", "C0745114", "C0745135")
            }

            outcome_cuis_initial <- if (!is.null(loaded_config) && !is.null(loaded_config$outcome_cuis)) {
                unlist(loaded_config$outcome_cuis)
            } else {
                c("C2677888", "C0750901", "C0494463", "C0002395")
            }

            blocklist_cuis_initial <- if (!is.null(loaded_config) && !is.null(loaded_config$blacklist_cuis)) {
                unlist(loaded_config$blacklist_cuis)
            } else {
                NULL
            }

            # Initialize CUI search servers with appropriate search types
            exposure_cui_search <- cuiSearchServer("exposure_cui_search",
                                                 initial_cuis = exposure_cuis_initial,
                                                 search_type = "exposure")
            outcome_cui_search <- cuiSearchServer("outcome_cui_search",
                                                initial_cuis = outcome_cuis_initial,
                                                search_type = "outcome")
            blocklist_cui_search <- cuiSearchServer("blocklist_cui_search",
                                                   initial_cuis = blocklist_cuis_initial,
                                                   search_type = "exposure")
        }

        # Update UI inputs with loaded configuration values
        if (!is.null(loaded_config)) {
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

            # Get CUI values from search modules or manual input
            exposure_cui_string <- if (exists("cui_search_available") && cui_search_available && exists("exposure_cui_search")) {
                exposure_search_data <- exposure_cui_search()
                exposure_search_data$cui_string
            } else {
                input$exposure_cuis
            }

            outcome_cui_string <- if (exists("cui_search_available") && cui_search_available && exists("outcome_cui_search")) {
                outcome_search_data <- outcome_cui_search()
                outcome_search_data$cui_string
            } else {
                input$outcome_cuis
            }

            # Get blocklist CUI string from search interface or manual input
            blocklist_cui_string <- if (exists("cui_search_available") && cui_search_available && exists("blocklist_cui_search")) {
                blocklist_search_data <- blocklist_cui_search()
                blocklist_search_data$cui_string
            } else {
                input$blocklist_cuis
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

            # Validate blacklist CUIs if provided
            blacklist_validation <- list(valid = TRUE, cuis = c())
            if (!is.null(blocklist_cui_string) && blocklist_cui_string != "") {
                blacklist_validation <- validate_cui(blocklist_cui_string)
                if (!blacklist_validation$valid) {
                    errors <- c(errors, paste("Blacklist CUIs:", blacklist_validation$message))
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
                blacklist_cuis = if (blacklist_validation$valid) blacklist_validation$cuis else c(),
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
                    blacklist_cuis = validation_result$blacklist_cuis,
                    exposure_name = validation_result$exposure_name,
                    outcome_name = validation_result$outcome_name,
                    min_pmids = as.integer(input$min_pmids),
                    pub_year_cutoff = as.integer(input$pub_year_cutoff),
                    degree = as.integer(input$degree),
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

        # Cleanup database connection when session ends
        session$onSessionEnded(function() {
            if (exists("cui_search_available") && cui_search_available) {
                close_database_pool()
            }
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
                           "min_pmids", "pub_year_cutoff", "degree",
                           "SemMedDBD_version", "predication_type")
        # Note: blacklist_cuis is optional, so not included in required_fields

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
        blacklist_cuis = c("C0000001", "C0000002"),
        exposure_name = "Test Exposure",
        outcome_name = "Test Outcome",
        min_pmids = 100,
        pub_year_cutoff = 2010,
        degree = 2,
        predication_type = "CAUSES",
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

#' Load Configuration from YAML File (Duplicate - kept for backward compatibility)
#'
#' This is a duplicate of the earlier load_graph_config function.
#' The first definition (around line 995) is the one being used.
#' This duplicate is kept for backward compatibility but is not actively used.
#'
#' @param yaml_file Path to the YAML configuration file (default: "user_input.yaml")
#' @return List containing configuration parameters, or NULL if file doesn't exist
#' @keywords internal

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
                        "min_pmids", "pub_year_cutoff", "degree",
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

    if ("degree" %in% names(config)) {
        if (!is.numeric(config$degree) || config$degree < 1 || config$degree > 3) {
            errors <- c(errors, "degree must be between 1 and 3")
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
        blacklist_cuis = c("C0000001", "C0000002"),
        exposure_name = "Test_Exposure",
        outcome_name = "Test_Outcome",
        min_pmids = 100,
        pub_year_cutoff = 2010,
        degree = 2,
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
