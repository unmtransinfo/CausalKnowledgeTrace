# Server Logic Module
# 
# This module contains the main server logic for the Causal Web Shiny application.
# It handles reactive values, network rendering, and core application state.
#
# Author: Refactored from app.R
# Date: February 2025

#' Create Main Server Logic
#' 
#' Creates the main server function with reactive values and core logic
#' 
#' @param input Shiny input object
#' @param output Shiny output object  
#' @param session Shiny session object
#' @return Server function
create_main_server <- function(input, output, session) {
    
    # Initialize reactive values for storing current data
    current_data <- reactiveValues(
        nodes = NULL,
        edges = NULL,
        dag_object = NULL,
        current_file = NULL,
        available_files = NULL,
        selected_node = NULL
    )
    
    # Initialize available files on startup
    observe({
        current_data$available_files <- scan_for_dag_files()
        choices <- current_data$available_files
        if (length(choices) == 0) {
            choices <- "No DAG files found"
        }
        updateSelectInput(session, "dag_file_selector", choices = choices)
    })
    
    # Render the main DAG network visualization
    output$dag_network <- renderVisNetwork({
        if (is.null(current_data$nodes) || is.null(current_data$edges)) {
            # Create empty network with message
            empty_nodes <- data.frame(
                id = "empty",
                label = "No DAG loaded\nUse 'Load Selected DAG' or 'Data Upload' tab",
                color = "#f0f0f0",
                shape = "box",
                font.size = 16,
                stringsAsFactors = FALSE
            )
            empty_edges <- data.frame(
                from = character(0),
                to = character(0),
                stringsAsFactors = FALSE
            )
            
            visNetwork(empty_nodes, empty_edges) %>%
                visOptions(highlightNearest = TRUE, nodesIdSelection = TRUE) %>%
                visPhysics(enabled = FALSE) %>%
                visInteraction(dragNodes = TRUE, dragView = TRUE, zoomView = TRUE)
        } else {
            visNetwork(current_data$nodes, current_data$edges) %>%
                visOptions(highlightNearest = TRUE, nodesIdSelection = TRUE) %>%
                visPhysics(
                    solver = "forceAtlas2Based",
                    forceAtlas2Based = list(gravitationalConstant = -50),
                    stabilization = list(iterations = 100)
                ) %>%
                visInteraction(dragNodes = TRUE, dragView = TRUE, zoomView = TRUE) %>%
                visEvents(select = "function(nodes) {
                    Shiny.onInputChange('dag_network_selected', nodes.nodes[0]);
                }")
        }
    })
    
    # Handle node selection
    observeEvent(input$dag_network_selected, {
        if (!is.null(input$dag_network_selected) && input$dag_network_selected != "") {
            current_data$selected_node <- input$dag_network_selected
        }
    })
    
    # Display graph information
    output$graph_info <- renderText({
        if (is.null(current_data$nodes) || is.null(current_data$edges)) {
            return("No graph loaded")
        }
        
        node_count <- nrow(current_data$nodes)
        edge_count <- nrow(current_data$edges)
        
        # Get exposure and outcome nodes if available
        exposure_nodes <- current_data$nodes[current_data$nodes$group == "Exposure", "label"]
        outcome_nodes <- current_data$nodes[current_data$nodes$group == "Outcome", "label"]
        
        info_text <- paste0(
            "Graph Statistics:\n",
            "Nodes: ", node_count, "\n",
            "Edges: ", edge_count, "\n"
        )
        
        if (length(exposure_nodes) > 0) {
            info_text <- paste0(info_text, "Exposure: ", paste(exposure_nodes, collapse = ", "), "\n")
        }
        
        if (length(outcome_nodes) > 0) {
            info_text <- paste0(info_text, "Outcome: ", paste(outcome_nodes, collapse = ", "), "\n")
        }
        
        if (!is.null(current_data$current_file)) {
            info_text <- paste0(info_text, "File: ", current_data$current_file)
        }
        
        return(info_text)
    })
    
    # Display selected node information
    output$selected_node_info <- renderText({
        if (is.null(current_data$selected_node) || is.null(current_data$nodes)) {
            return("No node selected")
        }
        
        selected_node_data <- current_data$nodes[current_data$nodes$id == current_data$selected_node, ]
        
        if (nrow(selected_node_data) == 0) {
            return("Selected node not found")
        }
        
        node_info <- paste0(
            "Selected Node:\n",
            "ID: ", selected_node_data$id, "\n",
            "Label: ", selected_node_data$label, "\n",
            "Type: ", selected_node_data$group, "\n"
        )
        
        return(node_info)
    })
    
    # Update causal analysis variable choices when DAG is loaded
    observe({
        if (!is.null(current_data$dag_object)) {
            vars_info <- get_dag_variables(current_data$dag_object)
            if (vars_info$success) {
                all_vars <- vars_info$all_variables
                updateSelectInput(session, "causal_exposure", choices = all_vars)
                updateSelectInput(session, "causal_outcome", choices = all_vars)
            }
        } else {
            updateSelectInput(session, "causal_exposure", choices = "No DAG loaded")
            updateSelectInput(session, "causal_outcome", choices = "No DAG loaded")
        }
    })
    
    # Detailed node information for info tab
    output$detailed_node_info <- renderText({
        if (is.null(current_data$selected_node) || is.null(current_data$dag_object)) {
            return("No node selected or no DAG loaded")
        }
        
        node_id <- current_data$selected_node
        
        # Get detailed information about the node
        tryCatch({
            node_info <- get_node_details(current_data$dag_object, node_id)
            if (node_info$success) {
                return(paste0(
                    "Node: ", node_id, "\n",
                    "Type: ", node_info$type, "\n",
                    "Position: ", node_info$position, "\n",
                    "Description: ", node_info$description
                ))
            } else {
                return(paste("Error getting node details:", node_info$message))
            }
        }, error = function(e) {
            return(paste("Error:", e$message))
        })
    })
    
    # Node parents information
    output$node_parents <- renderText({
        if (is.null(current_data$selected_node) || is.null(current_data$dag_object)) {
            return("No node selected")
        }
        
        tryCatch({
            parents_info <- get_node_parents(current_data$dag_object, current_data$selected_node)
            if (parents_info$success) {
                if (length(parents_info$parents) == 0) {
                    return("No parent nodes")
                } else {
                    return(paste(parents_info$parents, collapse = ", "))
                }
            } else {
                return(paste("Error:", parents_info$message))
            }
        }, error = function(e) {
            return(paste("Error:", e$message))
        })
    })
    
    # Node children information
    output$node_children <- renderText({
        if (is.null(current_data$selected_node) || is.null(current_data$dag_object)) {
            return("No node selected")
        }
        
        tryCatch({
            children_info <- get_node_children(current_data$dag_object, current_data$selected_node)
            if (children_info$success) {
                if (length(children_info$children) == 0) {
                    return("No child nodes")
                } else {
                    return(paste(children_info$children, collapse = ", "))
                }
            } else {
                return(paste("Error:", children_info$message))
            }
        }, error = function(e) {
            return(paste("Error:", e$message))
        })
    })
    
    # Node causal properties
    output$node_causal_properties <- renderText({
        if (is.null(current_data$selected_node) || is.null(current_data$dag_object)) {
            return("No node selected")
        }
        
        tryCatch({
            properties <- get_node_causal_properties(current_data$dag_object, current_data$selected_node)
            if (properties$success) {
                return(paste0(
                    "Causal Properties:\n",
                    "Is Exposure: ", properties$is_exposure, "\n",
                    "Is Outcome: ", properties$is_outcome, "\n",
                    "Is Confounder: ", properties$is_confounder, "\n",
                    "Is Mediator: ", properties$is_mediator
                ))
            } else {
                return(paste("Error:", properties$message))
            }
        }, error = function(e) {
            return(paste("Error:", e$message))
        })
    })
    
    # Check if node is selected (for conditional panels)
    output$has_node_selection <- reactive({
        !is.null(current_data$selected_node)
    })
    outputOptions(output, "has_node_selection", suspendWhenHidden = FALSE)
    
    # Return current_data for use by other modules
    return(current_data)
}
