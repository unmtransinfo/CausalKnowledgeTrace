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
    # Handle both 'group' and 'category' column names for backward compatibility
    if ("group" %in% names(nodes_df)) {
        group_info <- nodes_df %>%
            group_by(group) %>%
            summarise(color = first(color), count = n(), .groups = 'drop')
    } else if ("category" %in% names(nodes_df)) {
        group_info <- nodes_df %>%
            group_by(category) %>%
            summarise(color = first(color), count = n(), .groups = 'drop')
        # Rename for consistent display
        names(group_info)[1] <- "group"
    } else {
        # Fallback if neither column exists
        return("<div style='margin: 10px;'>No category information available</div>")
    }

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
#' @param force_full_display Whether to force full display of all nodes/edges (default: FALSE)
#' @return visNetwork object
#' @export
create_interactive_network <- function(nodes_df, edges_df, physics_strength = -150, force_full_display = FALSE) {
    # Use fixed spring length value
    spring_length <- 200
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

    # Check for very large graphs and apply optimizations
    node_count <- nrow(nodes_df)
    edge_count <- if (!is.null(edges_df)) nrow(edges_df) else 0
    # Optimized thresholds for 3-hop graphs (8.8k nodes, 30k edges)
    # Use performance optimizations for graphs with >5k nodes or >15k edges
    is_large_graph <- node_count > 5000 || edge_count > 15000

    # Override large graph optimizations if user forces full display
    if (force_full_display) {
        cat("Force full display enabled - showing all", node_count, "nodes and", edge_count, "edges\n")
        is_large_graph <- FALSE  # Disable optimizations
    } else if (is_large_graph) {
        cat("Large graph detected (", node_count, "nodes,", edge_count, "edges) - applying performance optimizations\n")

        # Special handling for 3-hop graphs (around 8-9k nodes, 30k edges)
        if (node_count >= 8000 && node_count <= 10000 && edge_count >= 25000 && edge_count <= 35000) {
            cat("Detected 3-hop graph - using optimized 3-hop rendering settings\n")
        }

        # For very large graphs, create a simplified version for initial rendering
        # Allow 3-hop graphs to display fully, only sample for extremely large graphs
        if (node_count > 15000) {
            # Sample nodes to create a manageable subset - optimized for 3-hop graphs
            sample_size <- min(12000, node_count)
            sampled_indices <- sample(nrow(nodes_df), sample_size)
            nodes_subset <- nodes_df[sampled_indices, ]

            # Keep only edges between sampled nodes
            if (!is.null(edges_df) && nrow(edges_df) > 0) {
                edges_subset <- edges_df[
                    edges_df$from %in% nodes_subset$id & edges_df$to %in% nodes_subset$id,
                ]
            } else {
                edges_subset <- edges_df
            }

            # Create a warning node with the same structure as existing nodes
            warning_node <- nodes_subset[1, ]  # Copy structure from first node
            warning_node$id <- "LARGE_GRAPH_WARNING"
            warning_node$label <- paste("⚠️ Large Graph:", node_count, "nodes,", edge_count, "edges\nShowing", nrow(nodes_subset), "node subset for performance")
            warning_node$color <- "#FFA500"
            if ("font.size" %in% names(warning_node)) {
                warning_node$font.size <- 16
            }
            if ("font.color" %in% names(warning_node)) {
                warning_node$font.color <- "black"
            }
            if ("shape" %in% names(warning_node)) {
                warning_node$shape <- "box"
            }

            # Combine warning node with subset
            nodes_df <- rbind(warning_node, nodes_subset)
            edges_df <- edges_subset

            cat("Showing optimized subset:", nrow(nodes_subset), "nodes,", nrow(edges_subset), "edges (+ warning node)\n")
        }
    }

    # Ensure visNetwork uses explicit colors by renaming 'group' to avoid automatic coloring
    if ("group" %in% names(nodes_df)) {
        names(nodes_df)[names(nodes_df) == "group"] <- "category"
    }

    # Add unique IDs to edges for selection handling
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        if (!"id" %in% names(edges_df)) {
            edges_df$id <- paste(edges_df$from, edges_df$to, sep = "_")
        }
    }

    # Create the network visualization with optimizations for large graphs
    network <- visNetwork(nodes_df, edges_df, width = "100%", height = "100%")

    # Apply different configurations based on graph size
    if (is_large_graph) {
        # Optimized configuration for large graphs (including 3-hop graphs)
        network <- network %>%
            visPhysics(
                enabled = TRUE,
                solver = "barnesHut",  # More efficient for large graphs
                barnesHut = list(
                    gravitationalConstant = physics_strength * 1.5,  # Moderate gravity
                    centralGravity = 0.2,  # Moderate central gravity
                    springLength = spring_length * 0.7,  # Slightly shorter springs
                    springConstant = 0.08,  # Moderate spring strength
                    damping = 0.9,  # Moderate damping
                    avoidOverlap = 0.2  # Some overlap avoidance
                ),
                stabilization = list(
                    enabled = TRUE,
                    iterations = 300,  # More iterations for better layout
                    updateInterval = 50,  # Smoother updates
                    fit = TRUE  # Fit to screen after stabilization
                )
            ) %>%
            visOptions(
                highlightNearest = list(
                    enabled = TRUE,
                    degree = 1,
                    algorithm = "hierarchical"
                ),  # Enable but limit to 1 degree
                nodesIdSelection = TRUE,  # Keep node selection enabled
                collapse = list(enabled = FALSE)  # Disable clustering for clarity
            ) %>%
            visInteraction(
                navigationButtons = TRUE,
                dragView = TRUE,
                zoomView = TRUE,
                selectConnectedEdges = TRUE,  # Keep edge selection
                hover = TRUE,  # Keep hover for usability
                hoverConnectedEdges = FALSE,  # Disable connected edge hover for performance
                tooltipDelay = 200,  # Faster tooltip
                keyboard = list(enabled = TRUE, speed = list(x = 10, y = 10, zoom = 0.02))
            ) %>%
            visNodes(
                shadow = FALSE,  # Disable shadows for performance
                font = list(size = 14, strokeWidth = 1),  # Readable font size
                borderWidth = 1,  # Thin borders
                scaling = list(min = 8, max = 20),  # Reasonable node scaling
                chosen = list(node = "function(values, id, selected, hovering) { values.shadow = false; }")
            )
    } else {
        # Standard configuration for smaller graphs
        network <- network %>%
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
                highlightNearest = list(
                    enabled = TRUE,
                    degree = 1,
                    algorithm = "hierarchical"
                ),
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
            visNodes(
                shadow = TRUE,
                font = list(size = 20, strokeWidth = 2),
                borderWidth = 2
        )
    }

    # Configure edges based on graph size
    if (is_large_graph) {
        network <- network %>%
            visEdges(
                smooth = list(enabled = FALSE),  # Disable smooth edges for performance
                arrows = list(to = list(enabled = TRUE, scaleFactor = 0.9)),  # Slightly larger arrows
                width = 1.5,  # Slightly thicker edges for visibility
                color = list(color = "#666666", opacity = 0.7),  # Less transparent
                chosen = list(edge = "function(values, id, selected, hovering) { values.width = 3; }")
            )
    } else {
        network <- network %>%
            visEdges(
                smooth = list(enabled = TRUE, type = "curvedCW"),
                arrows = list(to = list(enabled = TRUE, scaleFactor = 1))
            )
    }

    # Add layout configuration
    network <- network %>%
        visLayout(randomSeed = 123)

    # Continue with events configuration
    network <- network %>%
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

                // Fit network to container on load
                network.fit({
                    animation: {
                        duration: 500,
                        easingFunction: 'easeInOutQuad'
                    }
                });

                // Store original colors for exposure and outcome nodes
                var allNodes = network.body.data.nodes.get();
                window.exposureOutcomeNodes = {};

                allNodes.forEach(function(node) {
                    var isExposure = (node.color === '#FF6B6B' || node.color === '#FF4500');
                    var isOutcome = (node.color === '#4ECDC4' || node.color === '#0066CC');

                    if (isExposure || isOutcome) {
                        window.exposureOutcomeNodes[node.id] = {
                            color: node.color,
                            fontColor: node.font && node.font.color ? node.font.color : 'black',
                            fontSize: node.font && node.font.size ? node.font.size : 14,
                            type: isExposure ? 'exposure' : 'outcome'
                        };
                    }
                });

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
                        case 'Delete':
                        case 'Backspace':
                            event.preventDefault();
                            // Get selected nodes and edges
                            var selection = network.getSelection();
                            if (selection.nodes.length > 0) {
                                // Trigger node removal
                                Shiny.onInputChange('keyboard_remove_node', {
                                    nodeId: selection.nodes[0],
                                    timestamp: new Date().getTime()
                                });
                            } else if (selection.edges.length > 0) {
                                // Trigger edge removal
                                Shiny.onInputChange('keyboard_remove_edge', {
                                    edgeId: selection.edges[0],
                                    timestamp: new Date().getTime()
                                });
                            }
                            break;
                        case 'z':
                            if (event.ctrlKey || event.metaKey) {
                                event.preventDefault();
                                // Trigger undo
                                Shiny.onInputChange('keyboard_undo', {
                                    timestamp: new Date().getTime()
                                });
                            }
                            break;
                    }
                });
            }"
        ) %>%
        visEvents(
            selectNode = "function(params) {
                var network = this;

                // Send selected node to Shiny for removal functionality
                if (params.nodes.length > 0) {
                    Shiny.onInputChange('network_selected', params.nodes[0]);
                    // Also send for information display
                    Shiny.onInputChange('clicked_node_info', params.nodes[0]);

                    // Custom highlighting: preserve exposure and outcome node colors
                    // Use setTimeout to apply after visNetwork's default highlighting
                    setTimeout(function() {
                        if (!window.exposureOutcomeNodes) return;

                        var updates = [];

                        // Restore exposure and outcome nodes to full visibility
                        Object.keys(window.exposureOutcomeNodes).forEach(function(nodeId) {
                            var nodeInfo = window.exposureOutcomeNodes[nodeId];
                            updates.push({
                                id: nodeId,
                                color: {
                                    background: nodeInfo.color,
                                    border: nodeInfo.color,
                                    highlight: {
                                        background: nodeInfo.color,
                                        border: nodeInfo.color
                                    }
                                },
                                opacity: 1.0,
                                font: {
                                    color: nodeInfo.fontColor,
                                    size: nodeInfo.fontSize
                                }
                            });
                        });

                        // Apply updates to keep exposure/outcome nodes visible
                        if (updates.length > 0) {
                            network.body.data.nodes.update(updates);
                        }
                    }, 10);
                } else {
                    Shiny.onInputChange('network_selected', null);
                    Shiny.onInputChange('clicked_node_info', null);
                }
            }",
            selectEdge = "function(params) {
                if (params.edges.length > 0) {
                    var edgeId = this.body.data.edges.get(params.edges[0]).id;
                    Shiny.onInputChange('selected_edge_info', edgeId);
                    // Clear node selection when edge is selected
                    Shiny.onInputChange('clicked_node_info', null);
                }
            }",
            deselectEdge = "function(params) {
                if (params.previousSelection.edges.length > 0) {
                    Shiny.onInputChange('selected_edge_info', null);
                }
            }",
            deselectNode = "function(params) {
                var network = this;

                if (params.previousSelection.nodes.length > 0) {
                    Shiny.onInputChange('clicked_node_info', null);

                    // Restore exposure and outcome nodes when deselecting
                    setTimeout(function() {
                        if (!window.exposureOutcomeNodes) return;

                        var updates = [];

                        Object.keys(window.exposureOutcomeNodes).forEach(function(nodeId) {
                            var nodeInfo = window.exposureOutcomeNodes[nodeId];
                            updates.push({
                                id: nodeId,
                                color: {
                                    background: nodeInfo.color,
                                    border: nodeInfo.color,
                                    highlight: {
                                        background: nodeInfo.color,
                                        border: nodeInfo.color
                                    }
                                },
                                opacity: 1.0,
                                font: {
                                    color: nodeInfo.fontColor,
                                    size: nodeInfo.fontSize
                                }
                            });
                        });

                        if (updates.length > 0) {
                            network.body.data.nodes.update(updates);
                        }
                    }, 10);
                }
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
apply_network_styling <- function(nodes_df, edges_df, max_nodes_for_full_styling = 12000) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(nodes = nodes_df, edges = edges_df))
    }
    
    # Adjust styling based on graph size - increased threshold for hop 3 graphs
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
        helpText("Adjust node clustering: More negative = tighter, Less negative = spread out"),
        actionButton("reset_physics", "Reset to Default", class = "btn-warning btn-sm", style = "margin-top: 5px;")
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
}

#' Remove Node and Connected Edges from Network
#'
#' Removes a node and all its connected edges from the network using visNetworkProxy
#'
#' @param session Shiny session object
#' @param network_id ID of the visNetwork output
#' @param node_id ID of the node to remove
#' @param current_data Reactive values containing nodes and edges
#' @return List with success status and message
#' @export
remove_node_from_network <- function(session, network_id, node_id, current_data) {
    if (is.null(node_id) || node_id == "" || length(node_id) == 0) {
        return(list(success = FALSE, message = "No node selected for removal"))
    }

    # Check if node exists
    if (!node_id %in% current_data$nodes$id) {
        return(list(success = FALSE, message = paste("Node", node_id, "not found")))
    }

    tryCatch({
        # Store original data for undo functionality
        if (is.null(current_data$undo_stack)) {
            current_data$undo_stack <- list()
        }

        # Save current state
        current_state <- list(
            nodes = current_data$nodes,
            edges = current_data$edges,
            action = "remove_node",
            removed_id = node_id,
            timestamp = Sys.time()
        )
        current_data$undo_stack <- append(current_data$undo_stack, list(current_state), 0)

        # Keep only last 10 undo states
        if (length(current_data$undo_stack) > 10) {
            current_data$undo_stack <- current_data$undo_stack[1:10]
        }

        # Find connected edges before removal
        connected_edges <- current_data$edges[
            current_data$edges$from == node_id | current_data$edges$to == node_id,
        ]

        # Remove node from data
        current_data$nodes <- current_data$nodes[current_data$nodes$id != node_id, ]

        # Remove all edges connected to this node
        current_data$edges <- current_data$edges[
            current_data$edges$from != node_id & current_data$edges$to != node_id,
        ]

        # Update network using visNetworkProxy
        visNetworkProxy(network_id, session = session) %>%
            visRemoveNodes(id = node_id)

        # Validate network integrity after removal
        validation <- validate_network_integrity(current_data)

        # Clear any selections
        session$sendInputMessage("network_selected", NULL)

        message <- paste("Removed node:", node_id, "and", nrow(connected_edges), "connected edges")
        if (validation$fixes_applied > 0) {
            message <- paste(message, "|", validation$message)
        }
        return(list(success = TRUE, message = message))

    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error removing node:", e$message)))
    })
}

#' Remove Edge from Network
#'
#' Removes a specific edge from the network using visNetworkProxy
#'
#' @param session Shiny session object
#' @param network_id ID of the visNetwork output
#' @param edge_id ID of the edge to remove
#' @param current_data Reactive values containing nodes and edges
#' @return List with success status and message
#' @export
remove_edge_from_network <- function(session, network_id, edge_id, current_data) {
    if (is.null(edge_id) || edge_id == "" || length(edge_id) == 0) {
        return(list(success = FALSE, message = "No edge selected for removal"))
    }

    # Check if edge exists
    if (!edge_id %in% current_data$edges$id) {
        return(list(success = FALSE, message = paste("Edge", edge_id, "not found")))
    }

    tryCatch({
        # Store original data for undo functionality
        if (is.null(current_data$undo_stack)) {
            current_data$undo_stack <- list()
        }

        # Save current state
        current_state <- list(
            nodes = current_data$nodes,
            edges = current_data$edges,
            action = "remove_edge",
            removed_id = edge_id,
            timestamp = Sys.time()
        )
        current_data$undo_stack <- append(current_data$undo_stack, list(current_state), 0)

        # Keep only last 10 undo states
        if (length(current_data$undo_stack) > 10) {
            current_data$undo_stack <- current_data$undo_stack[1:10]
        }

        # Get edge info for message
        edge_info <- current_data$edges[current_data$edges$id == edge_id, ]

        # Remove edge from data
        current_data$edges <- current_data$edges[current_data$edges$id != edge_id, ]

        # Update network using visNetworkProxy
        visNetworkProxy(network_id, session = session) %>%
            visRemoveEdges(id = edge_id)

        # Validate network integrity after removal
        validation <- validate_network_integrity(current_data)

        # Clear edge selection
        session$sendInputMessage("selected_edge_info", NULL)

        message <- paste("Removed edge:", edge_info$from[1], "->", edge_info$to[1])
        if (validation$fixes_applied > 0) {
            message <- paste(message, "|", validation$message)
        }
        return(list(success = TRUE, message = message))

    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error removing edge:", e$message)))
    })
}

#' Create DAG Object from Current Network Data
#'
#' Reconstructs a dagitty DAG object from current nodes and edges data
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return dagitty DAG object or NULL if reconstruction fails
#' @export
create_dag_from_network_data <- function(nodes_df, edges_df) {
    if (is.null(nodes_df) || is.null(edges_df) || nrow(nodes_df) == 0) {
        return(NULL)
    }

    tryCatch({
        # Start building the DAG definition
        dag_lines <- c("dag {")

        # Add node definitions with their types
        valid_nodes <- c()
        for (i in 1:nrow(nodes_df)) {
            node_id <- nodes_df$id[i]

            # Skip special nodes (like warning nodes)
            if (grepl("^(Warning|No Data|Error)", node_id)) {
                next
            }

            # Determine node type based on group/category
            node_type <- ""
            if ("group" %in% names(nodes_df)) {
                group <- nodes_df$group[i]
            } else if ("category" %in% names(nodes_df)) {
                group <- nodes_df$category[i]
            } else {
                group <- "Other"
            }

            # Map group to dagitty node types
            if (group == "Exposure") {
                node_type <- " [exposure]"
            } else if (group == "Outcome") {
                node_type <- " [outcome]"
            }

            # Preserve original node name as much as possible
            # Only replace characters that dagitty absolutely cannot handle
            clean_node_id <- gsub("[^A-Za-z0-9_.-]", "_", node_id)
            # Remove any leading/trailing whitespace that might have been converted to underscores
            clean_node_id <- gsub("^_+|_+$", "", clean_node_id)
            # If somehow the name becomes empty, create a fallback
            if (clean_node_id == "" || is.na(clean_node_id)) {
                clean_node_id <- paste0("Node_", i)
            }

            valid_nodes <- c(valid_nodes, clean_node_id)
            dag_lines <- c(dag_lines, paste0("    ", clean_node_id, node_type))
        }

        # Add empty line before edges
        dag_lines <- c(dag_lines, "")

        # Add edge definitions
        if (nrow(edges_df) > 0) {
            for (i in 1:nrow(edges_df)) {
                from_node_orig <- edges_df$from[i]
                to_node_orig <- edges_df$to[i]

                # Skip edges involving special nodes
                if (grepl("^(Warning|No Data|Error)", from_node_orig) ||
                    grepl("^(Warning|No Data|Error)", to_node_orig)) {
                    next
                }

                # Apply same conservative cleaning as for nodes
                from_node <- gsub("[^A-Za-z0-9_.-]", "_", from_node_orig)
                from_node <- gsub("^_+|_+$", "", from_node)
                if (from_node == "" || is.na(from_node)) {
                    from_node <- paste0("Node_", from_node_orig)
                }

                to_node <- gsub("[^A-Za-z0-9_.-]", "_", to_node_orig)
                to_node <- gsub("^_+|_+$", "", to_node)
                if (to_node == "" || is.na(to_node)) {
                    to_node <- paste0("Node_", to_node_orig)
                }

                # Only add edge if both nodes are in our valid nodes list
                if (from_node %in% valid_nodes && to_node %in% valid_nodes) {
                    dag_lines <- c(dag_lines, paste0("    ", from_node, " -> ", to_node))
                }
            }
        }

        # Close the DAG definition
        dag_lines <- c(dag_lines, "}")

        # Create the full DAG string
        dag_string <- paste(dag_lines, collapse = "\n")

        # Create dagitty object
        dag_object <- dagitty(dag_string)

        return(dag_object)

    }, error = function(e) {
        warning(paste("Failed to create DAG from network data:", e$message))
        return(NULL)
    })
}

#' Undo Last Removal Operation
#'
#' Restores the last removed node or edge from the undo stack
#'
#' @param session Shiny session object
#' @param network_id ID of the visNetwork output
#' @param current_data Reactive values containing nodes and edges
#' @return List with success status and message
#' @export
undo_last_removal <- function(session, network_id, current_data) {
    if (is.null(current_data$undo_stack) || length(current_data$undo_stack) == 0) {
        return(list(success = FALSE, message = "No operations to undo"))
    }

    tryCatch({
        # Get the last state
        last_state <- current_data$undo_stack[[1]]

        # Remove from undo stack
        current_data$undo_stack <- current_data$undo_stack[-1]

        # Restore data
        current_data$nodes <- last_state$nodes
        current_data$edges <- last_state$edges

        # Re-render the entire network (more reliable than trying to add back)
        # This will trigger the renderVisNetwork reactive
        current_data$force_refresh <- Sys.time()

        message <- paste("Undid", last_state$action, "of", last_state$removed_id)
        return(list(success = TRUE, message = message))

    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error during undo:", e$message)))
    })
}

#' Get Network Statistics
#'
#' Returns current network statistics after modifications
#'
#' @param current_data Reactive values containing nodes and edges
#' @return List with node and edge counts
#' @export
get_network_stats <- function(current_data) {
    if (is.null(current_data$nodes) || is.null(current_data$edges)) {
        return(list(nodes = 0, edges = 0))
    }

    return(list(
        nodes = nrow(current_data$nodes),
        edges = nrow(current_data$edges)
    ))
}

#' Validate Network Integrity After Modifications
#'
#' Checks network integrity after node/edge removals and fixes issues
#'
#' @param current_data Reactive values containing nodes and edges
#' @return List with validation results and any fixes applied
#' @export
validate_network_integrity <- function(current_data) {
    if (is.null(current_data$nodes) || is.null(current_data$edges)) {
        return(list(valid = TRUE, message = "No data to validate", fixes_applied = 0))
    }

    fixes_applied <- 0
    messages <- character(0)

    # Check for orphaned edges (edges pointing to non-existent nodes)
    if (nrow(current_data$edges) > 0 && nrow(current_data$nodes) > 0) {
        valid_from <- current_data$edges$from %in% current_data$nodes$id
        valid_to <- current_data$edges$to %in% current_data$nodes$id
        valid_edges <- valid_from & valid_to

        if (!all(valid_edges)) {
            orphaned_count <- sum(!valid_edges)
            current_data$edges <- current_data$edges[valid_edges, ]
            fixes_applied <- fixes_applied + orphaned_count
            messages <- c(messages, paste("Removed", orphaned_count, "orphaned edges"))
        }
    }

    # Check for duplicate edges
    if (nrow(current_data$edges) > 0) {
        edge_pairs <- paste(current_data$edges$from, current_data$edges$to, sep = "->")
        if (any(duplicated(edge_pairs))) {
            duplicate_count <- sum(duplicated(edge_pairs))
            current_data$edges <- current_data$edges[!duplicated(edge_pairs), ]
            fixes_applied <- fixes_applied + duplicate_count
            messages <- c(messages, paste("Removed", duplicate_count, "duplicate edges"))
        }
    }

    # Ensure edge IDs are consistent
    if (nrow(current_data$edges) > 0) {
        if (!"id" %in% names(current_data$edges) || any(is.na(current_data$edges$id))) {
            current_data$edges$id <- paste(current_data$edges$from, current_data$edges$to, sep = "_")
            fixes_applied <- fixes_applied + 1
            messages <- c(messages, "Fixed edge IDs")
        }
    }

    final_message <- if (length(messages) > 0) {
        paste(messages, collapse = "; ")
    } else {
        "Network integrity validated"
    }

    return(list(
        valid = TRUE,
        message = final_message,
        fixes_applied = fixes_applied
    ))
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
