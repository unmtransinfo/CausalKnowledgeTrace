# File Operations Module
# 
# This module contains file handling operations for the Causal Web Shiny application.
# It includes file loading, uploading, and DAG processing functionality.
#
# Author: Refactored from app.R
# Date: February 2025

#' Create File Operations Server Logic
#' 
#' Creates server logic for file operations including loading and uploading DAG files
#' 
#' @param input Shiny input object
#' @param output Shiny output object  
#' @param session Shiny session object
#' @param current_data Reactive values object containing current application state
#' @return NULL (side effects only)
create_file_operations_server <- function(input, output, session, current_data) {
    
    # Refresh file list
    observeEvent(input$refresh_files, {
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
            showNotification("File list refreshed", type = "message")
        }, error = function(e) {
            showNotification(paste("Error refreshing file list:", e$message), type = "error")
        })
    })
    
    # Load selected DAG with progress indication
    observeEvent(input$load_selected_dag, {
        if (is.null(input$dag_file_selector) || input$dag_file_selector == "No DAG files found") {
            showNotification("Please select a valid graph file", type = "error")
            session$sendCustomMessage("hideLoadingSection", list())
            return()
        }

        tryCatch({
            # Update progress: File validation
            session$sendCustomMessage("updateProgress", list(
                percent = 40,
                text = "Validating file...",
                status = paste("Checking", input$dag_file_selector)
            ))

            result <- load_dag_from_file(input$dag_file_selector)

            if (result$success) {
                # Update progress: Processing graph
                session$sendCustomMessage("updateProgress", list(
                    percent = 60,
                    text = "Processing graph...",
                    status = "Converting graph data structure"
                ))

                # Process the loaded DAG
                network_data <- create_network_data(result$dag)

                # Update progress: Finalizing
                session$sendCustomMessage("updateProgress", list(
                    percent = 80,
                    text = "Finalizing...",
                    status = "Updating visualization data"
                ))

                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- input$dag_file_selector

                # Try to load corresponding causal assertions data using k_hops
                tryCatch({
                    assertions_result <- load_causal_assertions(k_hops = result$k_hops)
                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$assertions_loaded <- TRUE
                        current_data$lazy_loader <- assertions_result$lazy_loader  # Store lazy loader if available
                        current_data$loading_strategy <- assertions_result$loading_strategy %||% "standard"
                        current_data$edge_index <- assertions_result$edge_index  # Store edge index if available

                        cat("Loaded causal assertions for k_hops =", result$k_hops, ":", assertions_result$message, "\n")
                        if (!is.null(assertions_result$loading_strategy)) {
                            cat("Loading strategy:", assertions_result$loading_strategy, "\n")
                        }

                        # Show notification about loaded assertions
                        notification_msg <- paste("Loaded causal assertions with", length(assertions_result$assertions), "relationships")
                        if (!is.null(assertions_result$loading_strategy) && assertions_result$loading_strategy != "standard") {
                            notification_msg <- paste(notification_msg, "(", assertions_result$loading_strategy, "mode )")
                        }
                        showNotification(
                            notification_msg,
                            type = "message",
                            duration = 3
                        )
                    } else {
                        current_data$causal_assertions <- list()
                        current_data$assertions_loaded <- FALSE
                        cat("Could not load causal assertions for k_hops =", result$k_hops, ":", assertions_result$message, "\n")
                    }
                }, error = function(e) {
                    current_data$causal_assertions <- list()
                    current_data$assertions_loaded <- FALSE
                    cat("Error loading causal assertions:", e$message, "\n")
                })

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph loaded successfully"
                ))

                # Hide loading section after a brief delay
                session$sendCustomMessage("hideLoadingSection", list())

                showNotification(paste("Successfully loaded graph from", input$dag_file_selector), type = "message")

                # Suggest causal analysis for newly loaded DAGs
                if (!is.null(current_data$dag_object)) {
                    vars_info <- get_dag_variables(current_data$dag_object)
                    if (vars_info$success && vars_info$total_count >= 3) {
                        showNotification(
                            HTML("DAG loaded successfully! <br/>Try the <strong>Causal Analysis</strong> tab to identify adjustment sets."),
                            type = "message",
                            duration = 5
                        )
                    }
                }
            } else {
                session$sendCustomMessage("hideLoadingSection", list())
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            session$sendCustomMessage("hideLoadingSection", list())
            showNotification(paste("Error loading graph:", e$message), type = "error")
        })
    })
    
    # Handle file upload
    observeEvent(input$dag_file_upload, {
        if (is.null(input$dag_file_upload)) return()

        # Get the uploaded file info
        file_info <- input$dag_file_upload

        # Copy file to graph_creation/result directory
        result_dir <- "../graph_creation/result"
        if (!dir.exists(result_dir)) {
            dir.create(result_dir, recursive = TRUE)
        }

        new_filename <- file_info$name
        destination_path <- file.path(result_dir, new_filename)
        file.copy(file_info$datapath, destination_path, overwrite = TRUE)

        showNotification(paste("File", new_filename, "uploaded successfully to graph_creation/result"), type = "message")
        
        # Refresh file list
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
            
            # Auto-select the uploaded file if it appears in the list
            if (new_filename %in% choices) {
                updateSelectInput(session, "dag_file_selector", selected = new_filename)
                showNotification(paste("File", new_filename, "is now available for loading"), type = "message")
            }
        }, error = function(e) {
            showNotification(paste("Error refreshing file list after upload:", e$message), type = "warning")
        })
    })
    
    # Handle direct file loading from upload
    observeEvent(input$load_uploaded_file, {
        if (is.null(input$dag_file_upload)) {
            showNotification("Please upload a file first", type = "error")
            return()
        }

        tryCatch({
            # Try to load the uploaded file directly
            file_path <- input$dag_file_upload$datapath
            
            # Read and parse the file
            result <- load_dag_from_path(file_path)
            
            if (result$success) {
                # Process the loaded DAG
                network_data <- create_network_data(result$dag)

                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- input$dag_file_upload$name

                # Try to load corresponding causal assertions data using k_hops
                tryCatch({
                    assertions_result <- load_causal_assertions(k_hops = result$k_hops)
                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$assertions_loaded <- TRUE
                        current_data$lazy_loader <- assertions_result$lazy_loader  # Store lazy loader if available
                        current_data$loading_strategy <- assertions_result$loading_strategy %||% "standard"
                        current_data$edge_index <- assertions_result$edge_index  # Store edge index if available

                        cat("Loaded causal assertions for uploaded file k_hops =", result$k_hops, ":", assertions_result$message, "\n")
                        if (!is.null(assertions_result$loading_strategy)) {
                            cat("Loading strategy:", assertions_result$loading_strategy, "\n")
                        }
                    } else {
                        current_data$causal_assertions <- list()
                        current_data$assertions_loaded <- FALSE
                        cat("Could not load causal assertions for uploaded file:", assertions_result$message, "\n")
                    }
                }, error = function(e) {
                    current_data$causal_assertions <- list()
                    current_data$assertions_loaded <- FALSE
                    cat("Error loading causal assertions for uploaded file:", e$message, "\n")
                })

                showNotification(paste("Successfully loaded uploaded file:", input$dag_file_upload$name), type = "message")
                
                # Suggest causal analysis
                if (!is.null(current_data$dag_object)) {
                    vars_info <- get_dag_variables(current_data$dag_object)
                    if (vars_info$success && vars_info$total_count >= 3) {
                        showNotification(
                            HTML("DAG loaded successfully! <br/>Try the <strong>Causal Analysis</strong> tab to identify adjustment sets."),
                            type = "message",
                            duration = 5
                        )
                    }
                }
            } else {
                showNotification(paste("Error loading uploaded file:", result$message), type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Error processing uploaded file:", e$message), type = "error")
        })
    })
    
    # Handle example file loading
    observeEvent(input$load_example_dag, {
        tryCatch({
            # Create and load example DAG
            example_dag <- create_example_dag()
            network_data <- create_network_data(example_dag)
            
            current_data$nodes <- network_data$nodes
            current_data$edges <- network_data$edges
            current_data$dag_object <- example_dag
            current_data$current_file <- "Example DAG"
            
            showNotification("Example DAG loaded successfully", type = "message")
            
            # Suggest causal analysis
            vars_info <- get_dag_variables(example_dag)
            if (vars_info$success && vars_info$total_count >= 3) {
                showNotification(
                    HTML("Example DAG loaded! <br/>Try the <strong>Causal Analysis</strong> tab to explore causal relationships."),
                    type = "message",
                    duration = 5
                )
            }
        }, error = function(e) {
            showNotification(paste("Error loading example DAG:", e$message), type = "error")
        })
    })
    
    # Clear current DAG
    observeEvent(input$clear_dag, {
        current_data$nodes <- NULL
        current_data$edges <- NULL
        current_data$dag_object <- NULL
        current_data$current_file <- NULL
        current_data$selected_node <- NULL
        
        showNotification("DAG cleared", type = "message")
    })
    
    # Export current DAG
    output$download_dag <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                paste0("exported_", current_data$current_file)
            } else {
                paste0("exported_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            if (is.null(current_data$dag_object)) {
                stop("No DAG to export")
            }
            
            tryCatch({
                # Export DAG to R format
                dag_code <- as.character(current_data$dag_object)
                writeLines(dag_code, file)
            }, error = function(e) {
                stop(paste("Error exporting DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )
}
