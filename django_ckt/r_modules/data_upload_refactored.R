# Data Upload Module (Refactored)
# 
# This module contains file upload handling, data ingestion, and data validation functions.
# It sources the refactored utility components for file operations and data validation.
#
# Author: Refactored from original data_upload.R
# Date: February 2025

# Source refactored utility components
source("utils/file_upload.R")
source("utils/data_validation.R")

#' Data Upload Module UI
#'
#' Creates the user interface for the data upload module
#'
#' @param id Character string. The namespace identifier for the module
#' @return Shiny UI elements for data upload
#' @export
dataUploadModuleUI <- function(id) {
    ns <- NS(id)
    
    tagList(
        fluidRow(
            box(
                title = "File Upload Options",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                tabsetPanel(
                    tabPanel("Upload DAG File",
                        br(),
                        fluidRow(
                            column(8,
                                fileInput(ns("dag_file_upload"),
                                        "Choose DAG File (.R)",
                                        accept = c(".R", ".r"),
                                        width = "100%")
                            ),
                            column(4,
                                br(),
                                actionButton(ns("load_uploaded_file"),
                                           "Load Uploaded File",
                                           icon = icon("upload"),
                                           class = "btn-success",
                                           style = "width: 100%;")
                            )
                        ),
                        
                        hr(),
                        
                        h4("Upload Instructions:"),
                        tags$ul(
                            tags$li("Upload R files containing DAG definitions"),
                            tags$li("Files should contain dagitty DAG objects"),
                            tags$li("Common variable names: g, dag, my_dag, graph"),
                            tags$li("Files will be copied to the graph_creation/result directory")
                        )
                    ),
                    
                    tabPanel("Load Example",
                        br(),
                        p("Load a pre-built example DAG for demonstration purposes."),
                        
                        fluidRow(
                            column(6,
                                actionButton(ns("load_example_dag"),
                                           "Load Example DAG",
                                           icon = icon("play"),
                                           class = "btn-info btn-lg",
                                           style = "width: 100%;")
                            ),
                            column(6,
                                actionButton(ns("load_fallback_dag"),
                                           "Load Complex Example",
                                           icon = icon("cogs"),
                                           class = "btn-warning btn-lg",
                                           style = "width: 100%;")
                            )
                        ),
                        
                        br(),
                        
                        h4("Example DAG Features:"),
                        tags$ul(
                            tags$li("Simple example: Basic causal relationships"),
                            tags$li("Complex example: Large network with multiple pathways"),
                            tags$li("Both include exposure and outcome variables"),
                            tags$li("Suitable for testing causal analysis features")
                        )
                    ),
                    
                    tabPanel("File Management",
                        br(),
                        fluidRow(
                            column(4,
                                actionButton(ns("refresh_file_list"),
                                           "Refresh File List",
                                           icon = icon("refresh"),
                                           class = "btn-info",
                                           style = "width: 100%;")
                            ),
                            column(4,
                                actionButton(ns("clear_current_dag"),
                                           "Clear Current DAG",
                                           icon = icon("trash"),
                                           class = "btn-danger",
                                           style = "width: 100%;")
                            ),
                            column(4,
                                downloadButton(ns("export_current_dag"),
                                             "Export Current DAG",
                                             icon = icon("download"),
                                             class = "btn-success",
                                             style = "width: 100%;")
                            )
                        ),
                        
                        br(),
                        
                        h4("Available DAG Files:"),
                        verbatimTextOutput(ns("available_files_list"))
                    )
                )
            )
        ),
        
        fluidRow(
            box(
                title = "Upload Status",
                status = "info",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                
                verbatimTextOutput(ns("upload_status"))
            )
        ),
        
        fluidRow(
            box(
                title = "Data Validation Results",
                status = "warning",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                collapsed = TRUE,
                
                verbatimTextOutput(ns("validation_results"))
            )
        )
    )
}

#' Data Upload Module Server
#'
#' Server logic for the data upload module
#'
#' @param id Character string. The namespace identifier for the module
#' @return Reactive values containing uploaded data
#' @export
dataUploadModuleServer <- function(id) {
    moduleServer(id, function(input, output, session) {
        
        # Reactive values to store upload state
        upload_state <- reactiveValues(
            current_dag = NULL,
            current_nodes = NULL,
            current_edges = NULL,
            upload_status = "Ready to upload files",
            validation_results = NULL,
            available_files = character(0)
        )
        
        # Initialize available files on startup
        observe({
            upload_state$available_files <- scan_for_dag_files()
        })
        
        # Display upload status
        output$upload_status <- renderText({
            upload_state$upload_status
        })
        
        # Display validation results
        output$validation_results <- renderText({
            if (is.null(upload_state$validation_results)) {
                return("No validation performed yet")
            }
            
            results <- upload_state$validation_results
            
            if (results$valid) {
                paste0(
                    "✓ DAG Validation: PASSED\n",
                    "Node count: ", results$node_count, "\n",
                    "Message: ", results$message
                )
            } else {
                paste0(
                    "✗ DAG Validation: FAILED\n",
                    "Error: ", results$message
                )
            }
        })
        
        # Display available files
        output$available_files_list <- renderText({
            if (length(upload_state$available_files) == 0) {
                return("No DAG files found in search directories")
            }
            
            paste0(
                "Found ", length(upload_state$available_files), " DAG files:\n",
                paste(upload_state$available_files, collapse = "\n")
            )
        })
        
        # Handle file upload
        observeEvent(input$dag_file_upload, {
            if (is.null(input$dag_file_upload)) return()
            
            upload_state$upload_status <- "Processing uploaded file..."
            
            tryCatch({
                # Get file info
                file_info <- input$dag_file_upload
                
                # Copy to result directory
                result_dir <- "../graph_creation/result"
                if (!dir.exists(result_dir)) {
                    dir.create(result_dir, recursive = TRUE)
                }
                
                destination <- file.path(result_dir, file_info$name)
                file.copy(file_info$datapath, destination, overwrite = TRUE)
                
                upload_state$upload_status <- paste("File uploaded:", file_info$name)
                
                # Refresh file list
                upload_state$available_files <- scan_for_dag_files()
                
                showNotification(
                    paste("File", file_info$name, "uploaded successfully"),
                    type = "message"
                )
                
            }, error = function(e) {
                upload_state$upload_status <- paste("Upload error:", e$message)
                showNotification(paste("Upload error:", e$message), type = "error")
            })
        })
        
        # Handle loading uploaded file
        observeEvent(input$load_uploaded_file, {
            if (is.null(input$dag_file_upload)) {
                showNotification("Please upload a file first", type = "error")
                return()
            }
            
            upload_state$upload_status <- "Loading uploaded DAG..."
            
            tryCatch({
                # Load DAG from uploaded file
                result <- load_dag_from_path(input$dag_file_upload$datapath)
                
                if (result$success) {
                    # Validate the DAG
                    validation <- validate_dag_object(result$dag)
                    upload_state$validation_results <- validation
                    
                    if (validation$valid) {
                        # Create network data
                        network_data <- create_network_data(result$dag)
                        
                        # Store in reactive values
                        upload_state$current_dag <- result$dag
                        upload_state$current_nodes <- network_data$nodes
                        upload_state$current_edges <- network_data$edges
                        
                        upload_state$upload_status <- paste(
                            "DAG loaded successfully from", input$dag_file_upload$name,
                            "\nNodes:", nrow(network_data$nodes),
                            "Edges:", nrow(network_data$edges)
                        )
                        
                        showNotification("DAG loaded successfully!", type = "message")
                    } else {
                        upload_state$upload_status <- paste("DAG validation failed:", validation$message)
                        showNotification(paste("Validation error:", validation$message), type = "error")
                    }
                } else {
                    upload_state$upload_status <- paste("Loading failed:", result$message)
                    showNotification(paste("Loading error:", result$message), type = "error")
                }
                
            }, error = function(e) {
                upload_state$upload_status <- paste("Error loading DAG:", e$message)
                showNotification(paste("Error:", e$message), type = "error")
            })
        })
        
        # Handle example DAG loading
        observeEvent(input$load_example_dag, {
            upload_state$upload_status <- "Loading example DAG..."
            
            tryCatch({
                example_dag <- create_example_dag()
                validation <- validate_dag_object(example_dag)
                upload_state$validation_results <- validation
                
                if (validation$valid) {
                    network_data <- create_network_data(example_dag)
                    
                    upload_state$current_dag <- example_dag
                    upload_state$current_nodes <- network_data$nodes
                    upload_state$current_edges <- network_data$edges
                    
                    upload_state$upload_status <- paste(
                        "Example DAG loaded successfully",
                        "\nNodes:", nrow(network_data$nodes),
                        "Edges:", nrow(network_data$edges)
                    )
                    
                    showNotification("Example DAG loaded!", type = "message")
                } else {
                    upload_state$upload_status <- "Example DAG validation failed"
                    showNotification("Example DAG validation failed", type = "error")
                }
                
            }, error = function(e) {
                upload_state$upload_status <- paste("Error loading example:", e$message)
                showNotification(paste("Error:", e$message), type = "error")
            })
        })
        
        # Handle fallback DAG loading
        observeEvent(input$load_fallback_dag, {
            upload_state$upload_status <- "Loading complex example DAG..."
            
            tryCatch({
                fallback_dag <- create_fallback_dag()
                validation <- validate_dag_object(fallback_dag)
                upload_state$validation_results <- validation
                
                if (validation$valid) {
                    network_data <- create_network_data(fallback_dag)
                    
                    upload_state$current_dag <- fallback_dag
                    upload_state$current_nodes <- network_data$nodes
                    upload_state$current_edges <- network_data$edges
                    
                    upload_state$upload_status <- paste(
                        "Complex example DAG loaded successfully",
                        "\nNodes:", nrow(network_data$nodes),
                        "Edges:", nrow(network_data$edges)
                    )
                    
                    showNotification("Complex example DAG loaded!", type = "message")
                } else {
                    upload_state$upload_status <- "Complex example DAG validation failed"
                    showNotification("Complex example DAG validation failed", type = "error")
                }
                
            }, error = function(e) {
                upload_state$upload_status <- paste("Error loading complex example:", e$message)
                showNotification(paste("Error:", e$message), type = "error")
            })
        })
        
        # Handle file list refresh
        observeEvent(input$refresh_file_list, {
            upload_state$available_files <- scan_for_dag_files()
            upload_state$upload_status <- "File list refreshed"
            showNotification("File list refreshed", type = "message")
        })
        
        # Handle clear current DAG
        observeEvent(input$clear_current_dag, {
            upload_state$current_dag <- NULL
            upload_state$current_nodes <- NULL
            upload_state$current_edges <- NULL
            upload_state$validation_results <- NULL
            upload_state$upload_status <- "Current DAG cleared"
            showNotification("Current DAG cleared", type = "message")
        })
        
        # Handle DAG export
        output$export_current_dag <- downloadHandler(
            filename = function() {
                paste0("exported_dag_", Sys.Date(), ".R")
            },
            content = function(file) {
                if (is.null(upload_state$current_dag)) {
                    writeLines("# No DAG to export", file)
                } else {
                    dag_code <- as.character(upload_state$current_dag)
                    writeLines(c("# Exported DAG", "g <- ", dag_code), file)
                }
            },
            contentType = "text/plain"
        )
        
        # Return reactive values for use by parent modules
        return(upload_state)
    })
}
