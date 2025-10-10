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

                # Try to load corresponding causal assertions data using degree
                tryCatch({
                    assertions_result <- load_causal_assertions(degree = result$degree)
                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$assertions_loaded <- TRUE
                        current_data$lazy_loader <- assertions_result$lazy_loader  # Store lazy loader if available
                        current_data$loading_strategy <- assertions_result$loading_strategy %||% "standard"
                        current_data$edge_index <- assertions_result$edge_index  # Store edge index if available

                        cat("Loaded causal assertions for degree =", result$degree, ":", assertions_result$message, "\n")
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
                        cat("Could not load causal assertions for degree =", result$degree, ":", assertions_result$message, "\n")
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

                # Try to load corresponding causal assertions data using degree
                tryCatch({
                    assertions_result <- load_causal_assertions(degree = result$degree)
                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$assertions_loaded <- TRUE
                        current_data$lazy_loader <- assertions_result$lazy_loader  # Store lazy loader if available
                        current_data$loading_strategy <- assertions_result$loading_strategy %||% "standard"
                        current_data$edge_index <- assertions_result$edge_index  # Store edge index if available

                        cat("Loaded causal assertions for uploaded file degree =", result$degree, ":", assertions_result$message, "\n")
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

    # Helper function to extract causal assertions for modified DAG
    extract_modified_dag_assertions <- function(edges_data, assertions_data) {
        if (is.null(edges_data) || nrow(edges_data) == 0 || is.null(assertions_data) || length(assertions_data) == 0) {
            return(list(
                pmid_sentences = list(),
                assertions = list()
            ))
        }

        # Initialize optimized structure
        pmid_sentences <- list()
        assertions <- list()

        for (i in seq_len(nrow(edges_data))) {
            edge <- edges_data[i, ]
            from_node <- edge$from
            to_node <- edge$to

            # Find matching assertion in original data
            pmid_data <- find_edge_pmid_data(from_node, to_node, assertions_data, current_data$lazy_loader)

            if (pmid_data$found && length(pmid_data$pmid_list) > 0) {
                # Create assertion entry in optimized format
                assertion_entry <- list(
                    subj = pmid_data$original_subject %||% from_node,
                    subj_cui = pmid_data$subject_cui %||% "",
                    predicate = pmid_data$predicate %||% "CAUSES",
                    obj = pmid_data$original_object %||% to_node,
                    obj_cui = pmid_data$object_cui %||% "",
                    ev_count = pmid_data$evidence_count %||% length(pmid_data$pmid_list),
                    pmid_refs = pmid_data$pmid_list
                )

                # Add sentences to pmid_sentences mapping
                for (pmid in pmid_data$pmid_list) {
                    sentences <- if (!is.null(pmid_data$sentence_data[[pmid]])) {
                        pmid_data$sentence_data[[pmid]]
                    } else {
                        list("Evidence sentence not available")
                    }

                    # Only add if not already present
                    if (is.null(pmid_sentences[[pmid]])) {
                        pmid_sentences[[pmid]] <- sentences
                    }
                }

                assertions[[length(assertions) + 1]] <- assertion_entry
            }
        }

        return(list(
            pmid_sentences = pmid_sentences,
            assertions = assertions
        ))
    }
    
    # Save updated DAG (handles both original and modified DAGs)
    output$save_dag_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

            }, error = function(e) {
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Main save DAG button (same functionality as save_dag_btn but more prominent)
    output$save_dag_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

            }, error = function(e) {
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Save updated causal assertions JSON file
    output$save_json_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract degree from current file or use default
                degree <- current_data$degree %||% 1
                paste0("evidence_from_graph_", degree, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Save updated causal assertions JSON file - Main button (same as save_json_btn)
    output$save_json_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract degree from current file or use default
                degree <- current_data$degree %||% 1
                paste0("evidence_from_graph_", degree, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Export current DAG (legacy function - kept for compatibility)
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
