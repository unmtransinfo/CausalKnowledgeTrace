# Graph Configuration Server Module
# This module provides the server logic for graph configuration
# Author: Refactored from graph_config_module.R

# Source validation module
source_paths <- c(
    file.path("shiny_app", "modules", "graph_config_validation.R"),
    file.path("modules", "graph_config_validation.R"),
    "graph_config_validation.R"
)

for (path in source_paths) {
    if (file.exists(path)) {
        source(path)
        break
    }
}

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Graph Configuration Server Function
#'
#' Server logic for knowledge graph parameter configuration
#'
#' @param id Character string. The namespace identifier for the module
#' @param db_connection Reactive expression returning database connection
#' @return Server logic for graph configuration
#' @export
graphConfigServer <- function(id, db_connection = NULL) {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Check database connection
        if (!is.null(db_connection)) {
            observe({
                if (is.null(db_connection())) {
                    showNotification("Database connection not available", type = "warning")
                }
            })
        }

        # Load configuration from YAML file (non-reactive, just once at startup)
        config <- load_graph_config("../user_input.yaml")

        # Get initial CUIs from loaded config for CUI search modules
        initial_exposure_cuis <- if (!is.null(config) && !is.null(config$exposure_cuis)) {
            paste(unlist(config$exposure_cuis), collapse = ", ")
        } else {
            NULL
        }

        initial_outcome_cuis <- if (!is.null(config) && !is.null(config$outcome_cuis)) {
            paste(unlist(config$outcome_cuis), collapse = ", ")
        } else {
            NULL
        }

        initial_blocklist_cuis <- if (!is.null(config) && !is.null(config$blacklist_cuis)) {
            paste(unlist(config$blacklist_cuis), collapse = ", ")
        } else {
            NULL
        }

        # Initialize CUI search servers if available
        exposure_cui_search <- NULL
        outcome_cui_search <- NULL
        blocklist_cui_search <- NULL

        if (exists("cuiSearchServer")) {
            tryCatch({
                # Initialize exposure CUI search (uses subject_search table)
                exposure_cui_search <- cuiSearchServer(
                    "exposure_cui_search",
                    initial_cuis = initial_exposure_cuis,
                    search_type = "exposure"
                )

                # Initialize outcome CUI search (uses object_search table)
                outcome_cui_search <- cuiSearchServer(
                    "outcome_cui_search",
                    initial_cuis = initial_outcome_cuis,
                    search_type = "outcome"
                )

                # Initialize blocklist CUI search (uses subject_search table)
                blocklist_cui_search <- cuiSearchServer(
                    "blocklist_cui_search",
                    initial_cuis = initial_blocklist_cuis,
                    search_type = "exposure"
                )
            }, error = function(e) {
                cat("Warning: Could not initialize CUI search modules:", e$message, "\n")
            })
        }

        # Create reactive for loaded config (for UI updates)
        loaded_config <- reactive({
            load_graph_config("../user_input.yaml")
        })

        # Update UI inputs with loaded configuration
        observe({
            config <- loaded_config()
            if (!is.null(config)) {
                # Update exposure name
                if (!is.null(config$exposure_name)) {
                    updateTextInput(session, "exposure_name", value = config$exposure_name)
                }

                # Update outcome name
                if (!is.null(config$outcome_name)) {
                    updateTextInput(session, "outcome_name", value = config$outcome_name)
                }

                # Update degree-specific thresholds (new format)
                if (!is.null(config$min_pmids_degree1)) {
                    updateNumericInput(session, "min_pmids_degree1", value = config$min_pmids_degree1)
                }
                if (!is.null(config$min_pmids_degree2)) {
                    updateNumericInput(session, "min_pmids_degree2", value = config$min_pmids_degree2)
                }
                if (!is.null(config$min_pmids_degree3)) {
                    updateNumericInput(session, "min_pmids_degree3", value = config$min_pmids_degree3)
                }

                # Update pub_year_cutoff
                if (!is.null(config$pub_year_cutoff)) {
                    updateSelectInput(session, "pub_year_cutoff", selected = as.character(config$pub_year_cutoff))
                }

                # Update degree
                if (!is.null(config$degree)) {
                    updateSelectInput(session, "degree", selected = as.character(config$degree))
                }

                # Update predication_type
                if (!is.null(config$predication_type)) {
                    # Handle both comma-separated string and vector
                    if (is.character(config$predication_type) && grepl(",", config$predication_type)) {
                        types <- trimws(unlist(strsplit(config$predication_type, ",")))
                        updateSelectInput(session, "PREDICATION_TYPE", selected = types)
                    } else {
                        updateSelectInput(session, "PREDICATION_TYPE", selected = config$predication_type)
                    }
                }

                # Update SemMedDB version
                if (!is.null(config$SemMedDBD_version)) {
                    updateSelectInput(session, "SemMedDBD_version", selected = config$SemMedDBD_version)
                }
            }
        })

        # Reactive values for validation
        validation_state <- reactiveValues(
            is_valid = FALSE,
            errors = c(),
            graph_just_created = FALSE  # Flag to track if graph was just created
        )

        # Validation feedback output
        output$validation_feedback <- renderUI({
            # Don't show validation feedback if graph was just created
            if (validation_state$graph_just_created) {
                return(NULL)
            }

            if (validation_state$is_valid) {
                div(
                    class = "alert alert-success",
                    icon("check-circle"),
                    strong(" Ready to create graph"),
                    br(),
                    "All inputs are valid. Click 'Create Graph' to proceed."
                )
            } else if (length(validation_state$errors) > 0) {
                div(
                    class = "alert alert-danger",
                    icon("exclamation-triangle"),
                    strong(" Validation Errors:"),
                    tags$ul(
                        lapply(validation_state$errors, function(err) {
                            tags$li(err)
                        })
                    )
                )
            } else {
                div(
                    class = "alert alert-info",
                    icon("info-circle"),
                    " Fill in the required fields to create a graph."
                )
            }
        })

        # Observe input changes for real-time validation
        observe({
            # Trigger validation when any input changes
            validation_result <- validate_inputs(
                input,
                exposure_cui_search,
                outcome_cui_search,
                blocklist_cui_search
            )

            validation_state$is_valid <- validation_result$valid
            validation_state$errors <- validation_result$errors

            # Reset the "graph just created" flag when inputs change
            # This allows validation messages to show again
            validation_state$graph_just_created <- FALSE
        })

        # Create Graph button event handler
        observeEvent(input$create_graph, {
            # Validate inputs
            validation_result <- validate_inputs(
                input,
                exposure_cui_search,
                outcome_cui_search,
                blocklist_cui_search
            )

            if (!validation_result$valid) {
                showNotification(
                    paste("Validation errors:", paste(validation_result$errors, collapse = "; ")),
                    type = "error",
                    duration = 10
                )
                return()
            }

            # Show progress section
            session$sendCustomMessage(paste0("showGraphProgressSection_", id), list())

            # Update progress: Starting
            session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                percent = 10,
                text = "Preparing configuration...",
                status = "Validating inputs and preparing YAML file"
            ))

            # Prepare configuration for YAML
            config_data <- list(
                exposure_cuis = validation_result$exposure_cuis,
                outcome_cuis = validation_result$outcome_cuis,
                blacklist_cuis = if (length(validation_result$blacklist_cuis) > 0) validation_result$blacklist_cuis else NULL,
                exposure_name = validation_result$exposure_name,
                outcome_name = validation_result$outcome_name,
                min_pmids_degree1 = as.integer(input$min_pmids_degree1),
                min_pmids_degree2 = as.integer(input$min_pmids_degree2),
                min_pmids_degree3 = as.integer(input$min_pmids_degree3),
                pub_year_cutoff = as.integer(input$pub_year_cutoff),
                degree = as.integer(input$degree),
                predication_type = validation_result$predication_types,
                SemMedDBD_version = input$SemMedDBD_version
            )

            # Update progress: Saving YAML
            session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                percent = 20,
                text = "Saving configuration...",
                status = "Writing configuration to user_input.yaml"
            ))

            # Save configuration to YAML file
            tryCatch({
                yaml::write_yaml(config_data, "../user_input.yaml")
                cat("Configuration saved to user_input.yaml\n")

                # Update progress: Running script
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 30,
                    text = "Starting graph creation...",
                    status = "Executing graph creation script"
                ))

                # Execute graph creation script
                # Use relative path from shiny_app directory
                script_path <- "../graph_creation/example/run_pushkin.sh"

                # Also try absolute path if relative doesn't work
                if (!file.exists(script_path)) {
                    script_path <- "graph_creation/example/run_pushkin.sh"
                }

                if (!file.exists(script_path)) {
                    showNotification(
                        paste("Graph creation script not found:", script_path),
                        type = "error",
                        duration = 10
                    )
                    session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())
                    return()
                }

                # Update progress: Executing
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 40,
                    text = "Executing graph creation script...",
                    status = "This may take several minutes. Please wait..."
                ))

                # Run the script from the repository root directory
                # The script needs to be run from the root to access .env and use correct paths
                result <- tryCatch({
                    # Get the repository root directory (parent of shiny_app)
                    repo_root <- normalizePath("..", mustWork = FALSE)

                    # Change to repo root, run script, then return
                    old_wd <- getwd()
                    setwd(repo_root)

                    # Run the script
                    output <- system2("bash", args = "graph_creation/example/run_pushkin.sh",
                                     stdout = TRUE, stderr = TRUE, wait = TRUE)

                    # Return to original directory
                    setwd(old_wd)

                    # Return output
                    output
                }, error = function(e) {
                    # Make sure we return to original directory even on error
                    tryCatch(setwd(old_wd), error = function(e2) {})
                    return(list(status = 1, output = e$message))
                })

                # Update progress: Processing results
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 90,
                    text = "Processing results...",
                    status = "Checking output files"
                ))

                # Check if script executed successfully
                if (!is.null(attr(result, "status")) && attr(result, "status") != 0) {
                    showNotification(
                        paste("Graph creation failed. Check console for details."),
                        type = "error",
                        duration = 10
                    )
                    cat("Script output:\n", paste(result, collapse = "\n"), "\n")
                    session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())
                    return()
                }

                # Update progress: Complete
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 100,
                    text = "Graph creation complete!",
                    status = "Successfully created knowledge graph"
                ))

                showNotification(
                    "Graph creation completed successfully! You can now load the graph from the Data Upload tab.",
                    type = "message",
                    duration = 10
                )

                # Set flag to hide validation messages after successful creation
                validation_state$graph_just_created <- TRUE

                # Hide progress section (with delay handled by JavaScript if needed)
                session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())

            }, error = function(e) {
                showNotification(
                    paste("Error creating graph:", e$message),
                    type = "error",
                    duration = 10
                )
                cat("Error details:", e$message, "\n")
                session$sendCustomMessage(paste0("hideGraphProgressSection_", id), list())
            })
        })

        # Return reactive values that might be useful to parent
        return(reactive({
            list(
                config = loaded_config(),
                is_valid = validation_state$is_valid
            )
        }))
    })
}

