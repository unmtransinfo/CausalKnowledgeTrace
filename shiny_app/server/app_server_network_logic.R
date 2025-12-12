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

        # Show loading message for large graphs
        if (!is.null(current_data$nodes) && nrow(current_data$nodes) > 8000) {
            showNotification(
                "Rendering large graph visualization... Please wait.",
                type = "message",
                duration = 3,
                id = "large_graph_render"
            )
        }

        create_interactive_network(current_data$nodes, current_data$edges,
                                 input$physics_strength, input$spring_length,
                                 input$force_full_display)
    })

    # Fit network to container after rendering
    observe({
        if (!is.null(current_data$nodes) && !is.null(current_data$edges)) {
            visNetworkProxy("network") %>%
                visFit(nodes = NULL, animation = list(duration = 500, easingFunction = "easeInOutQuad"))
        }
    })

    # Reset physics button using modular function
    observeEvent(input$reset_physics, {
        reset_physics_controls(session)
    })

