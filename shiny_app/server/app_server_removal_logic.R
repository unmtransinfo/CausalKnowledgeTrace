    # ===== NODE AND EDGE REMOVAL EVENT HANDLERS =====

    # Debug: Monitor node selections
    observeEvent(input$network_selected, {
        cat("DEBUG: Node selected:", input$network_selected, "\n")
    })

    # Debug: Monitor edge selections
    observeEvent(input$selected_edge_info, {
        cat("DEBUG: Edge selected:", input$selected_edge_info, "\n")
    })

    # Remove selected node
    observeEvent(input$remove_node_btn, {
        if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
            showNotification("No graph loaded", type = "warning")
            return()
        }

        # Get selected node from network
        selected_node <- input$network_selected
        cat("DEBUG: Selected node for removal:", selected_node, "\n")

        if (is.null(selected_node) || length(selected_node) == 0 || selected_node == "") {
            showNotification("Please select a node first by clicking on it", type = "warning")
            return()
        }

        # Remove the node
        result <- remove_node_from_network(session, "network", selected_node, current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)

            # Update DAG object if it exists
            if (!is.null(current_data$dag_object)) {
                # Note: DAG object becomes invalid after manual modifications
                current_data$dag_object <- NULL
                showNotification("DAG object cleared due to manual modifications", type = "message")
            }

            # Update DAG status to show it's been modified
            session$sendCustomMessage("updateDAGStatus", list(
                status = "Modified - Ready to save",
                color = "#ffc107"
            ))
        } else {
            showNotification(result$message, type = "error")
        }
    })

    # Remove selected edge
    observeEvent(input$remove_edge_btn, {
        if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
            showNotification("No edges in graph", type = "warning")
            return()
        }

        # Get selected edge
        selected_edge <- input$selected_edge_info
        cat("DEBUG: Selected edge for removal:", selected_edge, "\n")

        if (is.null(selected_edge) || selected_edge == "") {
            showNotification("Please select an edge first by clicking on it", type = "warning")
            return()
        }

        # Remove the edge
        result <- remove_edge_from_network(session, "network", selected_edge, current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)

            # Update DAG object if it exists
            if (!is.null(current_data$dag_object)) {
                # Note: DAG object becomes invalid after manual modifications
                current_data$dag_object <- NULL
                showNotification("DAG object cleared due to manual modifications", type = "message")
            }

            # Update DAG status to show it's been modified
            session$sendCustomMessage("updateDAGStatus", list(
                status = "Modified - Ready to save",
                color = "#ffc107"
            ))
        } else {
            showNotification(result$message, type = "error")
        }
    })

    # Undo last removal
    observeEvent(input$undo_removal, {
        result <- undo_last_removal(session, "network", current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)
        } else {
            showNotification(result$message, type = "warning")
        }
    })

    # ===== KEYBOARD SHORTCUT HANDLERS =====

    # Keyboard node removal (Delete/Backspace key)
    observeEvent(input$keyboard_remove_node, {
        if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
            return()
        }

        node_id <- input$keyboard_remove_node$nodeId
        if (!is.null(node_id) && node_id != "") {
            result <- remove_node_from_network(session, "network", node_id, current_data)

            if (result$success) {
                showNotification(paste("Deleted:", result$message), type = "message", duration = 2)

                # Update DAG object if it exists
                if (!is.null(current_data$dag_object)) {
                    current_data$dag_object <- NULL
                }
            }
        }
    })

    # Keyboard edge removal (Delete/Backspace key)
    observeEvent(input$keyboard_remove_edge, {
        if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
            return()
        }

        edge_id <- input$keyboard_remove_edge$edgeId
        if (!is.null(edge_id) && edge_id != "") {
            result <- remove_edge_from_network(session, "network", edge_id, current_data)

            if (result$success) {
                showNotification(paste("Deleted:", result$message), type = "message", duration = 2)

                # Update DAG object if it exists
                if (!is.null(current_data$dag_object)) {
                    current_data$dag_object <- NULL
                }
            }
        }
    })

    # Keyboard undo (Ctrl+Z)
    observeEvent(input$keyboard_undo, {
        result <- undo_last_removal(session, "network", current_data)

        if (result$success) {
            showNotification(paste("Undo:", result$message), type = "message", duration = 2)
        }
    })

    # Network statistics output
    output$network_stats_text <- renderText({
        if (is.null(current_data$nodes) || is.null(current_data$edges)) {
            return("No graph loaded")
        }
        stats <- get_network_stats(current_data)
        paste("Nodes:", stats$nodes, "| Edges:", stats$edges)
    })



