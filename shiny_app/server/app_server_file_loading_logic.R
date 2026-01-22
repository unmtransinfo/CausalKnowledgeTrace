    # Load selected DAG with progress indication and strategy selection
    observeEvent(input$load_selected_dag, {
        if (is.null(input$dag_file_selector) || input$dag_file_selector == "No DAG files found") {
            showNotification("Please select a valid graph file", type = "error")
            return()
        }

        # Use optimized loading (binary if available, otherwise full JSON)
        loading_strategy <- "auto"

        tryCatch({
            # Update progress: File validation
            session$sendCustomMessage("updateProgress", list(
                percent = 20,
                text = "Validating file...",
                status = paste("Checking", input$dag_file_selector, "with", loading_strategy, "strategy")
            ))

            result <- load_dag_from_file(input$dag_file_selector)

            if (result$success) {
                # Apply filtering based on selected option
                dag_to_use <- result$dag
                filter_result <- NULL
                filter_type_name <- "original"

                if (!is.null(input$filter_type) && input$filter_type != "none") {
                    if (input$filter_type == "leaf") {
                        # Leaf removal filtering
                        session$sendCustomMessage("updateProgress", list(
                            percent = 30,
                            text = "Removing leaf nodes...",
                            status = "Cleaning graph structure"
                        ))

                        filter_result <- remove_leaf_nodes(result$dag, preserve_exposure_outcome = TRUE)
                        filter_type_name <- "leaf_removed"

                        if (filter_result$success) {
                            dag_to_use <- filter_result$dag
                            cat(filter_result$message, "\n")
                            showNotification(
                                HTML(paste0("Leaf removal complete:<br/>",
                                           "Removed ", filter_result$removed_nodes, " nodes and ",
                                           filter_result$removed_edges, " edges in ",
                                           filter_result$iterations, " iterations")),
                                type = "message",
                                duration = 5
                            )
                        } else {
                            showNotification(
                                paste("Leaf removal failed:", filter_result$message),
                                type = "warning",
                                duration = 5
                            )
                        }
                    }
                }

                # Update progress: Processing graph
                node_count <- length(names(dag_to_use))
                progress_text <- if (node_count > 8000) {
                    "Processing large graph structure (this may take a moment)..."
                } else {
                    "Processing graph..."
                }

                session$sendCustomMessage("updateProgress", list(
                    percent = 40,
                    text = progress_text,
                    status = paste("Converting", node_count, "nodes to network format")
                ))

                # Process the loaded DAG (potentially with leaves removed)
                network_data <- create_network_data(dag_to_use)
                edge_count <- nrow(network_data$edges)

                # Update progress: Network created
                session$sendCustomMessage("updateProgress", list(
                    percent = 50,
                    text = "Network structure created successfully",
                    status = paste("Generated", nrow(network_data$nodes), "nodes and", nrow(network_data$edges), "edges")
                ))

                # Update progress: Loading assertions
                session$sendCustomMessage("updateProgress", list(
                    percent = 60,
                    text = paste("Loading assertions (", loading_strategy, "mode)..."),
                    status = "Applying selected loading strategy"
                ))

                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- dag_to_use  # Use the potentially cleaned DAG
                current_data$current_file <- input$dag_file_selector

                # Load causal assertions using unified optimized loading
                tryCatch({
                    # Source the new optimized loader
                    if (!exists("load_causal_assertions_unified")) {
                        source("modules/optimized_loader.R")
                    }

                    # Find the appropriate causal assertions file
                    degree <- result$degree
                    search_dirs <- c("../graph_creation/result", "../graph_creation/output")

                    # Look for optimized file first, then standard file
                    causal_file <- NULL
                    for (dir in search_dirs) {
                        # Try optimized file first
                        optimized_file <- file.path(dir, paste0("causal_assertions_", degree, "_optimized_readable.json"))
                        if (file.exists(optimized_file)) {
                            causal_file <- optimized_file
                            break
                        }

                        # Try standard optimized file
                        optimized_file2 <- file.path(dir, paste0("causal_assertions_", degree, "_optimized.json"))
                        if (file.exists(optimized_file2)) {
                            causal_file <- optimized_file2
                            break
                        }

                        # Try standard file
                        standard_file <- file.path(dir, paste0("causal_assertions_", degree, ".json"))
                        if (file.exists(standard_file)) {
                            causal_file <- standard_file
                            break
                        }
                    }

                    if (!is.null(causal_file)) {
                        # If filtering was applied, pass the filtered edges to the loader
                        # This allows the loader to only expand the assertions we need
                        filtered_edges_df <- NULL
                        if (!is.null(filter_result) && filter_result$success) {
                            filtered_edges_df <- as.data.frame(dagitty::edges(dag_to_use))
                            cat("Passing", nrow(filtered_edges_df), "filtered edges to assertion loader\n")
                        }

                        assertions_result <- load_causal_assertions_unified(causal_file, filtered_edges = filtered_edges_df)
                    } else {
                        assertions_result <- list(
                            success = FALSE,
                            message = paste("No causal assertions file found for degree =", degree)
                        )
                    }

                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$lazy_loader <- assertions_result$lazy_loader
                        current_data$compact_data <- assertions_result$compact_data  # Store compact data for lazy loading
                        current_data$assertions_loaded <- TRUE
                        current_data$loading_strategy <- assertions_result$loading_strategy

                        cat("Loaded causal assertions for degree =", result$degree, "\n")
                        cat("Strategy used:", assertions_result$loading_strategy, "\n")
                        cat("Load time:", round(assertions_result$load_time_seconds %||% 0, 2), "seconds\n")

                        # Show additional info for lazy loading
                        if (assertions_result$loading_strategy == "optimized_lazy") {
                            cat("Lazy loading enabled: assertions will be expanded on-demand\n")
                            cat("Total assertions available:", assertions_result$total_assertions %||% length(assertions_result$assertions), "\n")
                            if (!is.null(assertions_result$filtered_assertions)) {
                                cat("Filtered assertions:", assertions_result$filtered_assertions, "\n")
                            }
                        }

                        # Show simple success notification
                        load_time_msg <- if (!is.null(assertions_result$load_time_seconds)) {
                            paste0(" (", round(assertions_result$load_time_seconds, 1), "s)")
                        } else {
                            ""
                        }

                        # Show success modal with option to go to DAG Visualization
                        modal_content <- div(
                            style = "font-size: 16px;",
                            h4(paste0("Graph loaded successfully! (", node_count, " nodes, ", edge_count, " edges)")),
                            if (!is.null(load_time_msg)) p(HTML(load_time_msg)),
                            if (assertions_result$loading_strategy == "optimized_lazy") {
                                p(icon("bolt"), strong("Lazy loading enabled"), "- edge details will load instantly when clicked!")
                            } else if (node_count > 8000) {
                                p(icon("info-circle"), "Large graph - the interactive visualization may take a moment to render.")
                            },
                            hr(),
                            p(strong("Next step:"), "Go to the", strong("DAG Visualization"), "tab to explore your graph interactively."),
                            br(),
                            actionButton("goto_dag_viz", "Go to DAG Visualization",
                                       icon = icon("project-diagram"),
                                       class = "btn-primary btn-lg")
                        )

                        showModal(modalDialog(
                            title = div(icon("check-circle", style = "color: #28a745;"), " Graph Loaded Successfully!"),
                            modal_content,
                            footer = modalButton("Close"),
                            easyClose = TRUE,
                            size = "m"
                        ))
                    } else {
                        current_data$causal_assertions <- list()
                        current_data$lazy_loader <- NULL
                        current_data$assertions_loaded <- FALSE
                        current_data$loading_strategy <- "none"
                        cat("Could not load causal assertions for degree =", result$degree, ":", assertions_result$message, "\n")

                        showNotification(
                            "Graph loaded but causal assertions could not be loaded. Edge information may be limited.",
                            type = "warning",
                            duration = 5
                        )
                    }
                }, error = function(e) {
                    current_data$causal_assertions <- list()
                    current_data$lazy_loader <- NULL
                    current_data$assertions_loaded <- FALSE
                    current_data$loading_strategy <- "error"
                    cat("Error loading causal assertions:", e$message, "\n")
                })

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph loaded successfully"
                ))

                # Hide loading section (JavaScript will handle the delay)
                session$sendCustomMessage("hideLoadingSection", list())

                # Update DAG status to show it's ready to save
                session$sendCustomMessage("updateDAGStatus", list(
                    status = "Loaded - Ready to save",
                    color = "#28a745"
                ))

                # Suggest causal analysis for newly loaded DAGs
                if (!is.null(current_data$dag_object)) {
                    vars_info <- get_dag_variables(current_data$dag_object)
                    if (vars_info$success && vars_info$total_count >= 3) {
                        showNotification(
                            HTML("Ready for analysis! <br/>Try the <strong>Causal Analysis</strong> tab to identify adjustment sets."),
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
            updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)
        }, error = function(e) {
            showNotification(paste("Error refreshing file list:", e$message), type = "error")
        })
    })
    
    # Upload and load DAG with progress indication
    observeEvent(input$upload_and_load, {
        if (is.null(input$dag_file_upload)) {
            showNotification("Please select a file first", type = "error")
            session$sendCustomMessage("hideLoadingSection", list())
            return()
        }

        tryCatch({
            # Get the uploaded file info
            file_info <- input$dag_file_upload
            new_filename <- file_info$name

            # Update progress: Copying file
            session$sendCustomMessage("updateProgress", list(
                percent = 30,
                text = "Copying file...",
                status = paste("Saving", new_filename, "to graph_creation/result directory")
            ))

            # Copy file to graph_creation/result directory
            result_dir <- "../graph_creation/result"
            if (!dir.exists(result_dir)) {
                dir.create(result_dir, recursive = TRUE)
            }
            destination_path <- file.path(result_dir, new_filename)
            file.copy(file_info$datapath, destination_path, overwrite = TRUE)

            # Update progress: Validating file
            session$sendCustomMessage("updateProgress", list(
                percent = 50,
                text = "Validating file...",
                status = paste("Checking", new_filename)
            ))

            # Load the DAG
            result <- load_dag_from_file(new_filename)

            if (result$success) {
                # Apply filtering based on selected option
                dag_to_use <- result$dag
                filter_result <- NULL
                filter_type_name <- "original"

                if (!is.null(input$filter_type) && input$filter_type != "none") {
                    if (input$filter_type == "leaf") {
                        # Leaf removal filtering
                        session$sendCustomMessage("updateProgress", list(
                            percent = 60,
                            text = "Removing leaf nodes...",
                            status = "Cleaning graph structure"
                        ))

                        filter_result <- remove_leaf_nodes(result$dag, preserve_exposure_outcome = TRUE)
                        filter_type_name <- "leaf_removed"

                        if (filter_result$success) {
                            dag_to_use <- filter_result$dag
                            cat(filter_result$message, "\n")
                        }
                    }
                }

                # Update progress: Processing graph
                session$sendCustomMessage("updateProgress", list(
                    percent = 70,
                    text = "Processing graph...",
                    status = "Converting graph data structure"
                ))

                # Process the loaded DAG (potentially with leaves removed)
                network_data <- create_network_data(dag_to_use)
                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- dag_to_use  # Use the potentially cleaned DAG
                current_data$current_file <- new_filename

                # Update progress: Loading causal assertions
                session$sendCustomMessage("updateProgress", list(
                    percent = 75,
                    text = "Loading causal assertions...",
                    status = "Loading edge information"
                ))

                # Load causal assertions
                tryCatch({
                    assertions_result <- load_causal_assertions(new_filename)

                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$lazy_loader <- assertions_result$lazy_loader
                        current_data$assertions_loaded <- TRUE
                        current_data$loading_strategy <- assertions_result$loading_strategy
                        cat("Loaded causal assertions for uploaded file:", new_filename,
                            "- Strategy:", assertions_result$loading_strategy, "\n")
                    } else {
                        current_data$causal_assertions <- list()
                        current_data$lazy_loader <- NULL
                        current_data$assertions_loaded <- FALSE
                        current_data$loading_strategy <- "none"
                        cat("Could not load causal assertions for uploaded file:", new_filename, "\n")
                    }
                }, error = function(e) {
                    current_data$causal_assertions <- list()
                    current_data$lazy_loader <- NULL
                    current_data$assertions_loaded <- FALSE
                    current_data$loading_strategy <- "none"
                    cat("Error loading causal assertions for uploaded file:", e$message, "\n")
                })

                # Update progress: Updating file list
                session$sendCustomMessage("updateProgress", list(
                    percent = 90,
                    text = "Updating file list...",
                    status = "Refreshing available files"
                ))

                # Update file list
                current_data$available_files <- scan_for_dag_files()
                choices <- current_data$available_files
                if (length(choices) == 0) {
                    choices <- "No DAG files found"
                }
                updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph uploaded and loaded successfully"
                ))

                # Hide loading section after a brief delay
                session$sendCustomMessage("hideLoadingSection", list())

                # Update DAG status to show it's ready to save
                session$sendCustomMessage("updateDAGStatus", list(
                    status = "Uploaded - Ready to save",
                    color = "#28a745"
                ))

                # Get graph stats
                node_count <- length(V(dag_to_use))
                edge_count <- length(E(dag_to_use))

                # Show success modal with option to go to DAG Visualization
                modal_content <- div(
                    style = "font-size: 16px;",
                    h4(paste0("Graph uploaded successfully! (", node_count, " nodes, ", edge_count, " edges)")),
                    p(icon("file"), strong("File:"), new_filename),
                    if (current_data$loading_strategy == "optimized_lazy") {
                        p(icon("bolt"), strong("Lazy loading enabled"), "- edge details will load instantly when clicked!")
                    },
                    if (!is.null(filter_result) && filter_result$success) {
                        p(icon("filter"), strong("Filtering applied:"), filter_result$message)
                    },
                    hr(),
                    p(strong("Next step:"), "Go to the", strong("DAG Visualization"), "tab to explore your graph interactively."),
                    br(),
                    actionButton("goto_dag_viz_upload", "Go to DAG Visualization",
                               icon = icon("project-diagram"),
                               class = "btn-primary btn-lg")
                )

                showModal(modalDialog(
                    title = div(icon("check-circle", style = "color: #28a745;"), " Graph Uploaded Successfully!"),
                    modal_content,
                    footer = modalButton("Close"),
                    easyClose = TRUE,
                    size = "m"
                ))
            } else {
                session$sendCustomMessage("hideLoadingSection", list())
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            session$sendCustomMessage("hideLoadingSection", list())
            showNotification(paste("Error loading uploaded graph:", e$message), type = "error")
        })
    })
    
    # Generate legend HTML using modular function
    output$legend_html <- renderUI({
        HTML(generate_legend_html(current_data$nodes))
    })

    # Observer for "Go to DAG Visualization" button from file loading modal
    observeEvent(input$goto_dag_viz, {
        updateTabItems(session, "sidebar", "dag")
        removeModal()
    })

    # Observer for "Go to DAG Visualization" button from file upload modal
    observeEvent(input$goto_dag_viz_upload, {
        updateTabItems(session, "sidebar", "dag")
        removeModal()
    })

