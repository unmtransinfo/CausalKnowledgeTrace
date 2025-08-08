# DAG Visualization Module
# This module contains functions for rendering and displaying directed acyclic graphs
# Author: Refactored from original dag_data.R and app.R
# Dependencies: visNetwork, dplyr

# Required libraries for this module
if (!require(visNetwork)) stop("visNetwork package is required")
if (!require(dplyr)) stop("dplyr package is required")

#' Generate Legend HTML for DAG Visualization
#' 
#' Creates an HTML legend showing node groups, colors, and counts
#' 
#' @param nodes_df Data frame containing node information with group and color columns
#' @return HTML string for the legend
#' @export
generate_legend_html <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return("<div style='margin: 10px;'>No data available</div>")
    }
    
    # Group nodes by category and get color and count information
    group_info <- nodes_df %>%
        group_by(group) %>%
        summarise(color = first(color), count = n(), .groups = 'drop')
    
    # Build HTML legend
    legend_html <- "<div style='margin: 10px;'>"
    for (i in 1:nrow(group_info)) {
        legend_html <- paste0(legend_html,
            "<div style='margin-bottom: 10px;'>",
            "<span style='background-color: ", group_info$color[i], 
            "; padding: 5px 10px; border-radius: 3px; color: white; margin-right: 10px;'>",
            group_info$group[i], "</span>",
            "(", group_info$count[i], " nodes)",
            "</div>"
        )
    }
    legend_html <- paste0(legend_html, "</div>")
    return(legend_html)
}

#' Create Interactive Network Visualization
#' 
#' Creates a visNetwork object with specified physics and styling options
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @param physics_strength Gravitational constant for physics simulation (default: -150)
#' @param spring_length Spring length for physics simulation (default: 200)
#' @return visNetwork object
#' @export
create_interactive_network <- function(nodes_df, edges_df, physics_strength = -150, spring_length = 200) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        # Create empty network for error cases
        empty_nodes <- data.frame(
            id = "No Data",
            label = "No Data Available",
            color = "#FF0000",
            stringsAsFactors = FALSE
        )
        empty_edges <- data.frame(
            from = character(0),
            to = character(0),
            stringsAsFactors = FALSE
        )
        nodes_df <- empty_nodes
        edges_df <- empty_edges
    }
    
    # Create the network visualization
    network <- visNetwork(nodes_df, edges_df, width = "100%", height = "100%") %>%
        visPhysics(
            solver = "forceAtlas2Based",
            forceAtlas2Based = list(
                gravitationalConstant = physics_strength,
                centralGravity = 0.01,
                springLength = spring_length,
                springConstant = 0.08,
                damping = 0.4,
                avoidOverlap = 1
            )
        ) %>%
        visOptions(
            highlightNearest = list(enabled = TRUE, degree = 1),
            nodesIdSelection = TRUE
        ) %>%
        visInteraction(
            navigationButtons = TRUE,
            keyboard = list(
                enabled = TRUE,
                speed = list(x = 10, y = 10, zoom = 0.02),
                bindToWindow = FALSE
            ),
            dragView = TRUE,
            zoomView = TRUE,
            selectConnectedEdges = TRUE,
            hover = TRUE,
            hoverConnectedEdges = TRUE,
            tooltipDelay = 300
        ) %>%
        visLayout(randomSeed = 123) %>%
        visNodes(
            shadow = TRUE,
            font = list(size = 20, strokeWidth = 2),
            borderWidth = 2
        ) %>%
        visEdges(
            smooth = list(enabled = TRUE, type = "curvedCW"),
            arrows = list(to = list(enabled = TRUE, scaleFactor = 1))
        ) %>%
        visEvents(
            type = "once",
            afterDrawing = "function() {
                // Enhanced keyboard navigation
                var network = this;
                var container = network.body.container;

                // Make container focusable
                container.setAttribute('tabindex', '0');
                container.style.outline = 'none';

                // Focus on container to enable keyboard events
                container.focus();

                // Add keyboard event listener
                container.addEventListener('keydown', function(event) {
                    var moveDistance = 50;
                    var zoomFactor = 0.1;
                    var currentScale = network.getScale();
                    var currentPosition = network.getViewPosition();

                    switch(event.key) {
                        case 'ArrowUp':
                            event.preventDefault();
                            network.moveTo({
                                position: {x: currentPosition.x, y: currentPosition.y - moveDistance},
                                scale: currentScale
                            });
                            break;
                        case 'ArrowDown':
                            event.preventDefault();
                            network.moveTo({
                                position: {x: currentPosition.x, y: currentPosition.y + moveDistance},
                                scale: currentScale
                            });
                            break;
                        case 'ArrowLeft':
                            event.preventDefault();
                            network.moveTo({
                                position: {x: currentPosition.x - moveDistance, y: currentPosition.y},
                                scale: currentScale
                            });
                            break;
                        case 'ArrowRight':
                            event.preventDefault();
                            network.moveTo({
                                position: {x: currentPosition.x + moveDistance, y: currentPosition.y},
                                scale: currentScale
                            });
                            break;
                        case '+':
                        case '=':
                            event.preventDefault();
                            network.moveTo({
                                position: currentPosition,
                                scale: currentScale * (1 + zoomFactor)
                            });
                            break;
                        case '-':
                            event.preventDefault();
                            network.moveTo({
                                position: currentPosition,
                                scale: currentScale * (1 - zoomFactor)
                            });
                            break;
                        case '0':
                            event.preventDefault();
                            network.fit();
                            break;
                    }
                });
            }"
        )

    return(network)
}

#' Get Default Physics Settings
#' 
#' Returns default physics settings for network visualization
#' 
#' @return List containing default physics parameters
#' @export
get_default_physics_settings <- function() {
    return(list(
        physics_strength = -150,
        spring_length = 200,
        central_gravity = 0.01,
        spring_constant = 0.08,
        damping = 0.4,
        avoid_overlap = 1
    ))
}

#' Apply Network Styling for Large Graphs
#' 
#' Adjusts visual parameters for better performance with large graphs
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @param max_nodes_for_full_styling Maximum nodes before applying simplified styling (default: 100)
#' @return List containing styled nodes and edges data frames
#' @export
apply_network_styling <- function(nodes_df, edges_df, max_nodes_for_full_styling = 100) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(nodes = nodes_df, edges = edges_df))
    }
    
    # Adjust styling based on graph size
    if (nrow(nodes_df) > max_nodes_for_full_styling) {
        # Simplified styling for large graphs
        nodes_df$font.size <- 12
        nodes_df$size <- 15
        
        if (!is.null(edges_df) && nrow(edges_df) > 0) {
            edges_df$width <- 1
            edges_df$color <- "#999999"
        }
        
        cat("Applied simplified styling for large graph (", nrow(nodes_df), " nodes)\n")
    } else {
        # Full styling for smaller graphs
        if (!"font.size" %in% names(nodes_df)) nodes_df$font.size <- 14
        if (!"size" %in% names(nodes_df)) nodes_df$size <- 20
        
        if (!is.null(edges_df) && nrow(edges_df) > 0) {
            if (!"width" %in% names(edges_df)) edges_df$width <- 1.5
            if (!"color" %in% names(edges_df)) edges_df$color <- "#666666"
        }
    }
    
    return(list(nodes = nodes_df, edges = edges_df))
}

#' Create Network Controls UI Elements
#' 
#' Generates UI elements for controlling network physics and appearance
#' 
#' @return List of Shiny UI elements for network controls
#' @export
create_network_controls_ui <- function() {
    default_settings <- get_default_physics_settings()
    
    return(list(
        sliderInput("physics_strength", "Physics Strength:", 
                   min = -500, max = 0, value = default_settings$physics_strength, step = 25),
        sliderInput("spring_length", "Spring Length:", 
                   min = 0, max = 400, value = default_settings$spring_length, step = 25),
        actionButton("reset_physics", "Reset Physics", class = "btn-warning"),
        br(), br(),
        actionButton("reload_data", "Reload DAG Data", class = "btn-success")
    ))
}

#' Reset Physics Controls to Default Values
#' 
#' Helper function to reset physics controls in Shiny session
#' 
#' @param session Shiny session object
#' @export
reset_physics_controls <- function(session) {
    default_settings <- get_default_physics_settings()
    updateSliderInput(session, "physics_strength", value = default_settings$physics_strength)
    updateSliderInput(session, "spring_length", value = default_settings$spring_length)
}

#' Format Node Information for Display
#' 
#' Formats selected node information for text output
#' 
#' @param selected_node_id ID of the selected node
#' @param nodes_df Data frame containing node information
#' @return Formatted text string with node information
#' @export
format_node_info <- function(selected_node_id, nodes_df) {
    if (is.null(selected_node_id)) {
        return("Click on a node to see its information.")
    }
    
    selected_node <- nodes_df[nodes_df$id == selected_node_id, ]
    if (nrow(selected_node) > 0) {
        return(paste0(
            "Selected Node: ", selected_node$label, "\n",
            "ID: ", selected_node$id, "\n",
            "Group: ", selected_node$group, "\n",
            "Color: ", selected_node$color
        ))
    } else {
        return("Node information not available.")
    }
}
