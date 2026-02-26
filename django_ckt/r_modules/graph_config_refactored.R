# Graph Configuration Module for Causal Web (Refactored)
# Interactive Shiny module for configuring and creating knowledge graphs
# 
# This module provides a user interface for setting up graph creation parameters
# and executing the graph generation process with real-time progress feedback.
# 
# Dependencies: shiny, yaml
# 
# Author: Scott A. Malec PhD (Refactored February 2025)
# Date: February 2025

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

# Source refactored components
source("modules/config_ui.R")
source("modules/config_validation.R")
source("modules/config_processing.R")

#' Graph Configuration Server Function (Refactored)
#' 
#' Server logic for the graph configuration module using refactored components
#' 
#' @param id Character string. The namespace identifier for the module
#' @return Reactive value containing validated parameters
#' @export
graphConfigModuleServer <- function(id) {
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
            
            if (state == "idle") {
                return(div(
                    class = "alert alert-info",
                    icon("info-circle"),
                    "Ready to validate configuration parameters"
                ))
            } else if (state == "validating") {
                return(div(
                    class = "alert alert-warning",
                    icon("spinner fa-spin"),
                    "Validating inputs..."
                ))
            } else if (state == "saving") {
                return(div(
                    class = "alert alert-info",
                    icon("save"),
                    "Saving configuration to YAML file..."
                ))
            } else if (state == "executing") {
                return(div(
                    class = "alert alert-primary",
                    icon("cogs fa-spin"),
                    "Creating knowledge graph... This may take several minutes."
                ))
            } else if (state == "complete") {
                return(div(
                    class = "alert alert-success",
                    icon("check-circle"),
                    "Graph creation completed successfully!"
                ))
            } else if (state == "error") {
                return(div(
                    class = "alert alert-danger",
                    icon("exclamation-triangle"),
                    strong("Error: "), message
                ))
            }
        })

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

            # Validate inputs using refactored validation
            validation_result <- validate_all_inputs(input)

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

            # Save configuration using refactored processing
            tryCatch({
                save_result <- save_config_file(validation_result)
                
                if (!save_result$success) {
                    progress_state("error")
                    progress_message(save_result$message)
                    return()
                }

                # Update progress for execution
                progress_state("executing")
                progress_message("Configuration saved! Starting graph creation...")
                progress_percent(50)

                # Update progress bar
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 50,
                    text = "Executing graph creation...",
                    status = "Running Python analysis script"
                ))

                Sys.sleep(2)

                # Execute graph creation
                execution_result <- execute_graph_creation()
                
                if (!execution_result$success) {
                    progress_state("error")
                    progress_message(execution_result$message)
                    return()
                }

                # Update progress for completion
                progress_state("complete")
                progress_message("Graph creation completed successfully!")
                progress_percent(100)

                # Update progress bar
                session$sendCustomMessage(paste0("updateGraphProgress_", id), list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph creation finished"
                ))

                # Store validated parameters
                validated_params(validation_result)
                
                # Check for generated files
                files_result <- check_generated_files()
                
                # Update results outputs
                output$creation_results <- renderText({
                    create_config_summary(validation_result)
                })
                
                output$generated_files <- renderText({
                    if (files_result$success && files_result$count > 0) {
                        paste("Generated files:", paste(files_result$files, collapse = ", "))
                    } else {
                        "No output files detected. Check the graph creation logs."
                    }
                })
                
                # Show success notification
                showNotification(
                    "Graph creation completed! Check the results section below.",
                    type = "message",
                    duration = 10
                )

            }, error = function(e) {
                progress_state("error")
                progress_message(paste("Unexpected error:", e$message))
                showNotification(paste("Error:", e$message), type = "error")
            })
        })
        
        # Check if results are available
        output$has_results <- reactive({
            !is.null(validated_params())
        })
        outputOptions(output, "has_results", suspendWhenHidden = FALSE)
        
        # Download configuration handler
        output$download_config <- downloadHandler(
            filename = function() {
                params <- validated_params()
                if (!is.null(params)) {
                    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
                    paste0("causal_config_", timestamp, ".yaml")
                } else {
                    "causal_config.yaml"
                }
            },
            content = function(file) {
                params <- validated_params()
                if (!is.null(params)) {
                    yaml_content <- create_yaml_config(params)
                    writeLines(yaml_content, file)
                } else {
                    writeLines("# No configuration available", file)
                }
            },
            contentType = "text/yaml"
        )
        
        # Load created graph handler
        observeEvent(input$load_created_graph, {
            # This would integrate with the main app's graph loading functionality
            showNotification("Graph loading functionality would be integrated with main app", type = "message")
        })

        # Return the validated parameters for use by parent modules
        return(validated_params)
    })
}

# Backward compatibility aliases
graphConfigUI <- graphConfigModuleUI
graphConfigServer <- graphConfigModuleServer
