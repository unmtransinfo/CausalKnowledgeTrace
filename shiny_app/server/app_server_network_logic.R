    # Reload data function
    reload_dag_data <- function() {
        tryCatch({
            source("dag_data.R", local = TRUE)
            if (exists("dag_nodes") && exists("dag_edges")) {
                # Validate the reloaded data using modular functions
                current_data$nodes <- validate_node_data(dag_nodes)
                current_data$edges <- validate_edge_data(dag_edges)
                if (exists("dag_object")) {
                    current_data$dag_object <- dag_object
                }
                if (exists("dag_loaded_from")) {
                    current_data$current_file <- dag_loaded_from
                }
                if (exists("available_dag_files")) {
                    current_data$available_files <- available_dag_files
                }
                showNotification("DAG data reloaded successfully!", type = "message")
            } else {
                showNotification("Error: dag_nodes or dag_edges not found in dag_data.R", type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Error reloading data:", e$message), type = "error")
        })
    }
    
    # Reload data button
    observeEvent(input$reload_data, {
        reload_dag_data()
    })
    
    # Render the network using modular function
    output$network <- renderVisNetwork({
        # Include force_refresh to trigger re-rendering for undo functionality
        current_data$force_refresh

        # Set rendering flag to FALSE when starting to render
        current_data$rendering_complete <- FALSE

        create_interactive_network(current_data$nodes, current_data$edges,
                                 input$physics_strength,
                                 force_full_display = FALSE)
    })

    # Fit network to container after rendering
    observe({
        if (!is.null(current_data$nodes) && !is.null(current_data$edges)) {
            visNetworkProxy("network") %>%
                visFit(nodes = NULL, animation = list(duration = 500, easingFunction = "easeInOutQuad"))
        }
    })

    # Handle network rendering completion
    observeEvent(input$network_rendering_complete, {
        # Mark rendering as complete
        current_data$rendering_complete <- TRUE

        # Update Data Upload tab progress to 100% and hide loading
        session$sendCustomMessage("updateProgress", list(
            percent = 100,
            text = "Complete!",
            status = "Graph fully rendered and ready"
        ))

        session$sendCustomMessage("hideLoadingSection", list())
    })

    # Reset physics button using modular function
    observeEvent(input$reset_physics, {
        reset_physics_controls(session)
    })

