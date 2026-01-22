# Graph Configuration UI Module
# This module provides the user interface components for graph configuration
# Author: Refactored from graph_config_module.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Load graph configuration from YAML file at UI build time
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

#' Create JavaScript for Progress Handling
#'
#' Generates JavaScript code for progress bar control
#'
#' @param id Module namespace ID
#' @param ns Namespace function
#' @return HTML script tag with JavaScript
#' @keywords internal
create_progress_javascript <- function(id, ns) {
    tags$script(HTML(paste0("
        // Progress bar control functions for graph creation
        function updateGraphProgress_", id, "(percent, text, status) {
            $('#", ns("graph_progress"), "').css('width', percent + '%');
            $('#", ns("progress_text"), "').text(text);
            $('#", ns("progress_status"), "').text('Status: ' + status);
        }

        function showGraphProgressSection_", id, "() {
            // Show backdrop
            if ($('#progress-backdrop').length === 0) {
                $('body').append('<div id=\"progress-backdrop\" class=\"progress-backdrop\"></div>');
            }
            $('#progress-backdrop').addClass('active');
            // Show progress section with animation
            $('#", ns("progress_section"), "').show();
            // Scroll to top to ensure visibility
            $('html, body').animate({ scrollTop: 0 }, 300);
            updateGraphProgress_", id, "(10, 'Starting...', 'Initializing graph creation process');
        }

        function hideGraphProgressSection_", id, "() {
            // Hide progress section
            $('#", ns("progress_section"), "').hide();
            // Hide backdrop
            $('#progress-backdrop').removeClass('active');
            updateGraphProgress_", id, "(0, 'Initializing...', 'Ready to create graph...');
        }

        // Function to toggle threshold inputs based on degree
        function toggleThresholds_", id, "(degree) {
            var degree1 = $('#", ns("min_pmids_degree1"), "');
            var degree2 = $('#", ns("min_pmids_degree2"), "');
            var degree3 = $('#", ns("min_pmids_degree3"), "');

            // Degree 1: Enable only threshold 1
            if (degree == 1) {
                degree1.prop('disabled', false).parent().css('opacity', '1');
                degree2.prop('disabled', true).parent().css('opacity', '0.5');
                degree3.prop('disabled', true).parent().css('opacity', '0.5');
            }
            // Degree 2: Enable thresholds 1 and 2
            else if (degree == 2) {
                degree1.prop('disabled', false).parent().css('opacity', '1');
                degree2.prop('disabled', false).parent().css('opacity', '1');
                degree3.prop('disabled', true).parent().css('opacity', '0.5');
            }
            // Degree 3: Enable all thresholds
            else if (degree == 3) {
                degree1.prop('disabled', false).parent().css('opacity', '1');
                degree2.prop('disabled', false).parent().css('opacity', '1');
                degree3.prop('disabled', false).parent().css('opacity', '1');
            }
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

        Shiny.addCustomMessageHandler('toggleThresholds', function(data) {
            toggleThresholds_", id, "(data.degree);
        });

        // Initialize threshold states on page load
        $(document).ready(function() {
            var initialDegree = $('#", ns("degree"), "').val();
            if (initialDegree) {
                toggleThresholds_", id, "(parseInt(initialDegree));
            }
        });

        // Listen for degree changes
        $(document).on('change', '#", ns("degree"), "', function() {
            var selectedDegree = parseInt($(this).val());
            toggleThresholds_", id, "(selectedDegree);
        });
    ")))
}

#' Create CUI Input Fields
#'
#' Creates exposure, outcome, and blocklist CUI input fields
#'
#' @param ns Namespace function
#' @param ui_config Configuration loaded at UI time
#' @param cui_search_available Boolean indicating if CUI search is available
#' @return Column with CUI input fields
#' @keywords internal
create_cui_inputs <- function(ns, ui_config, cui_search_available) {
    # Extract CUI values from config
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

    blocklist_cuis_ui <- if (!is.null(ui_config) && !is.null(ui_config$blocklist_cuis)) {
        paste(unlist(ui_config$blocklist_cuis), collapse = ", ")
    } else {
        ""
    }

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
                    height = "200px",
                    initial_value = blocklist_cuis_ui
                )
            } else {
                # Fallback to manual entry
                tagList(
                    tags$label("Blocklist CUIs", class = "control-label"),
                    textAreaInput(
                        ns("blocklist_cuis"),
                        label = NULL,
                        value = blocklist_cuis_ui,
                        placeholder = "C0000000, C1111111, C2222222 (Press Enter to search)",
                        rows = 2,
                        width = "100%"
                    ),
                    helpText("Optional: CUIs to exclude from the graph analysis. Enter comma-delimited CUI codes (format: C followed by 7 digits). These concepts will be filtered out during graph creation. Press Enter to search for concepts.")
                )
            }
        )
    )
}

#' Create Configuration Parameter Inputs
#'
#' Creates configuration parameter input fields (names, thresholds, etc.)
#'
#' @param ns Namespace function
#' @param ui_config Configuration loaded at UI time
#' @return Column with configuration parameter fields
#' @keywords internal
create_config_inputs <- function(ns, ui_config) {
    # Extract values from config
    exposure_name_ui <- if (!is.null(ui_config) && !is.null(ui_config$exposure_name)) {
        ui_config$exposure_name
    } else {
        "Hypertension"  # Changed from "" to "Hypertension"
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

    column(6,
        # Consolidated Exposure Name
        div(
            class = "form-group",
            tags$label("Consolidated Exposure Name *", class = "control-label"),
            textInput(
                ns("exposure_name"),
                label = NULL,
                value = exposure_name_ui,  # Use the extracted value instead of hardcoded ""
                placeholder = "e.g., Hypertension, Diabetes",
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
                value = outcome_name_ui,  # Use the extracted value instead of hardcoded ""
                placeholder = "e.g., Alzheimers, Cancer",
                width = "100%"
            ),
            helpText("Required: Single consolidated name representing all outcome concepts. Spaces will be automatically converted to underscores.")
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

        # Squelch Thresholds (by degree)
        div(
            class = "form-group",
            h5("Squelch Thresholds (minimum unique PMIDs) *"),
            fluidRow(
                column(4,
                    numericInput(
                        ns("min_pmids_degree1"),
                        "Threshold for 1st Degree:",
                        value = 10,
                        min = 1,
                        max = 1000,
                        step = 1,
                        width = "100%"
                    )
                ),
                column(4,
                    numericInput(
                        ns("min_pmids_degree2"),
                        "Threshold for 2nd Degree:",
                        value = 10,
                        min = 1,
                        max = 1000,
                        step = 1,
                        width = "100%"
                    )
                ),
                column(4,
                    numericInput(
                        ns("min_pmids_degree3"),
                        "Threshold for 3rd Degree:",
                        value = 10,
                        min = 1,
                        max = 1000,
                        step = 1,
                        width = "100%"
                    )
                )
            ),
            helpText("Minimum number of unique PMIDs required for each degree level (1-1000).")
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
}

#' Create Progress Section UI
#'
#' Creates the progress section that shows during graph creation
#'
#' @param ns Namespace function
#' @return Div with progress section
#' @keywords internal
create_progress_section <- function(ns) {
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

    tagList(
        # Add JavaScript for progress handling
        create_progress_javascript(id, ns),

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
                    create_cui_inputs(ns, ui_config, exists("cui_search_available") && cui_search_available),

                    # Right Column: Configuration parameters
                    create_config_inputs(ns, ui_config)
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
                create_progress_section(ns)
            )
        )
    )
}