# Data Validation Module
# 
# This module contains data validation and processing functions for DAG objects
# and network data structures in the Causal Web Shiny application.
#
# Author: Refactored from data_upload.R
# Date: February 2025

#' Validate DAG Object
#'
#' Validates a DAG object to ensure it's properly formatted
#'
#' @param dag_object A dagitty DAG object
#' @return List with validation results
#' @export
validate_dag_object <- function(dag_object) {
    if (is.null(dag_object)) {
        return(list(valid = FALSE, message = "DAG object is NULL"))
    }
    
    if (!inherits(dag_object, "dagitty")) {
        return(list(valid = FALSE, message = "Object is not a dagitty DAG"))
    }
    
    tryCatch({
        # Try to extract basic information
        node_names <- names(dag_object)
        if (length(node_names) == 0) {
            return(list(valid = FALSE, message = "DAG contains no nodes"))
        }
        
        # Try to convert to igraph to test structure
        tryCatch({
            ig <- dagitty2graph(dag_object)
        }, error = function(e) {
            return(list(valid = FALSE, message = paste("DAG structure error:", e$message)))
        })
        
        return(list(valid = TRUE, message = "DAG object is valid", node_count = length(node_names)))
        
    }, error = function(e) {
        return(list(valid = FALSE, message = paste("Validation error:", e$message)))
    })
}

#' Create Network Data
#'
#' Converts a DAG object to network data suitable for visNetwork
#'
#' @param dag_object A dagitty DAG object
#' @return List containing nodes and edges data frames
#' @export
create_network_data <- function(dag_object) {
    # Validate the DAG first
    validation <- validate_dag_object(dag_object)
    if (!validation$valid) {
        stop(paste("Invalid DAG object:", validation$message))
    }
    
    # Initialize empty data structures
    nodes_df <- data.frame(
        id = character(0),
        label = character(0),
        group = character(0),
        color = character(0),
        font.size = numeric(0),
        font.color = character(0),
        stringsAsFactors = FALSE
    )
    
    edges_df <- data.frame(
        from = character(0),
        to = character(0),
        arrows = character(0),
        smooth = logical(0),
        width = numeric(0),
        color = character(0),
        stringsAsFactors = FALSE
    )
    
    tryCatch({
        # Extract node information
        node_names <- names(dag_object)
        
        if (length(node_names) == 0) {
            warning("DAG contains no nodes")
            return(list(nodes = nodes_df, edges = edges_df))
        }
        
        # Get exposure and outcome variables
        exposures <- exposures(dag_object)
        outcomes <- outcomes(dag_object)
        
        # Create nodes data frame
        nodes_df <- data.frame(
            id = node_names,
            label = node_names,
            stringsAsFactors = FALSE
        )
        
        # Assign groups and colors using optimized approach
        nodes_df$group <- "Other"
        nodes_df$color <- "#808080"  # Gray for other nodes
        nodes_df$font.color <- "black"
        nodes_df$font.size <- 14

        # Set exposure nodes using vectorized operations
        if (length(exposures) > 0) {
            exposure_mask <- nodes_df$id %in% exposures
            nodes_df$group[exposure_mask] <- "Exposure"
            nodes_df$color[exposure_mask] <- "#FF4500"  # Orange-red for exposure
            nodes_df$font.color[exposure_mask] <- "white"
            nodes_df$font.size[exposure_mask] <- 16
        }

        # Set outcome nodes using vectorized operations
        if (length(outcomes) > 0) {
            outcome_mask <- nodes_df$id %in% outcomes
            nodes_df$group[outcome_mask] <- "Outcome"
            nodes_df$color[outcome_mask] <- "#0066CC"  # Blue for outcome
            nodes_df$font.color[outcome_mask] <- "white"
            nodes_df$font.size[outcome_mask] <- 16
        }
        
        # Extract edges using dagitty2graph
        conversion_success <- TRUE
        tryCatch({
            ig <- dagitty2graph(dag_object)
            edge_list <- igraph::as_edgelist(ig)
            cat("Successfully converted DAG to igraph using dagitty2graph\n")
        }, error = function(e) {
            cat("Error converting DAG to igraph with dagitty2graph:", e$message, "\n")
            conversion_success <- FALSE
        })
        
        # If dagitty2graph failed, try direct edge extraction
        if (!conversion_success) {
            tryCatch({
                # Try to extract edges directly from DAG string representation
                dag_str <- as.character(dag_object)
                
                # Parse edges from DAG string (simple approach)
                edge_pattern <- "([A-Za-z0-9_]+)\\s*->\\s*([A-Za-z0-9_]+)"
                matches <- gregexpr(edge_pattern, dag_str)
                
                if (length(matches[[1]]) > 0 && matches[[1]][1] != -1) {
                    edge_strings <- regmatches(dag_str, matches)[[1]]
                    edge_list <- matrix(nrow = 0, ncol = 2)
                    
                    for (edge_str in edge_strings) {
                        parts <- strsplit(edge_str, "\\s*->\\s*")[[1]]
                        if (length(parts) == 2) {
                            edge_list <- rbind(edge_list, c(parts[1], parts[2]))
                        }
                    }
                }
            }, error = function(e) {
                cat("Error with direct edge extraction:", e$message, "\n")
            })
        }
        
        # Create edges data frame
        if (exists("edge_list") && nrow(edge_list) > 0) {
            edges_df <- data.frame(
                from = edge_list[, 1],
                to = edge_list[, 2],
                arrows = "to",
                smooth = TRUE,
                width = 1.5,
                color = "#2F4F4F80",
                stringsAsFactors = FALSE
            )
            
            # Filter edges to only include nodes that exist in nodes_df
            valid_edges <- edges_df$from %in% nodes_df$id & edges_df$to %in% nodes_df$id
            edges_df <- edges_df[valid_edges, ]
            
            cat("Created", nrow(edges_df), "edges\n")
        } else {
            cat("No edges found or extracted\n")
        }
        
        cat("Created network data with", nrow(nodes_df), "nodes and", nrow(edges_df), "edges\n")
        
    }, error = function(e) {
        cat("Warning: Could not extract edges from graph:", e$message, "\n")
    })
    
    # Validate the created data
    nodes_df <- validate_node_data(nodes_df)
    edges_df <- validate_edge_data(edges_df)
    
    return(list(nodes = nodes_df, edges = edges_df))
}

#' Process Large DAG
#'
#' Handles large DAG objects by providing warnings and potential simplification
#'
#' @param dag_object A dagitty DAG object
#' @param max_nodes Maximum number of nodes to display without warning
#' @return List with processing results and recommendations
#' @export
process_large_dag <- function(dag_object, max_nodes = 1000) {
    all_nodes <- names(dag_object)
    
    # If graph is too large, provide warning
    if (length(all_nodes) > max_nodes) {
        return(list(
            large_graph = TRUE,
            node_count = length(all_nodes),
            recommendation = paste("Graph has", length(all_nodes), "nodes. Consider filtering or simplifying for better visualization."),
            max_recommended = max_nodes
        ))
    }
    
    return(list(
        large_graph = FALSE,
        node_count = length(all_nodes),
        recommendation = "Graph size is suitable for visualization"
    ))
}

#' Validate Node Data
#' 
#' Validates and fixes node data structure
#' 
#' @param nodes Data frame containing node information
#' @return Validated and corrected nodes data frame
#' @export
validate_node_data <- function(nodes) {
    if (is.null(nodes) || nrow(nodes) == 0) {
        return(data.frame(
            id = character(0),
            label = character(0),
            group = character(0),
            color = character(0),
            font.size = numeric(0),
            font.color = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    # Validate nodes
    required_node_cols <- c("id", "label")
    missing_node_cols <- setdiff(required_node_cols, names(nodes))
    
    if (length(missing_node_cols) > 0) {
        warning(paste("Missing node columns:", paste(missing_node_cols, collapse = ", ")))
        if (!"id" %in% names(nodes)) {
            stop("Node 'id' column is required")
        }
        if (!"label" %in% names(nodes)) {
            nodes$label <- nodes$id
        }
    }
    
    # Add optional node columns if missing
    if (!"group" %in% names(nodes)) nodes$group <- "Other"
    if (!"color" %in% names(nodes)) nodes$color <- "#95A5A6"
    if (!"font.size" %in% names(nodes)) nodes$font.size <- 14
    if (!"font.color" %in% names(nodes)) nodes$font.color <- "#2C3E50"
    
    # Ensure no duplicate IDs
    if (any(duplicated(nodes$id))) {
        warning("Duplicate node IDs found, removing duplicates")
        nodes <- nodes[!duplicated(nodes$id), ]
    }
    
    # Ensure all required columns are present and properly typed
    nodes$id <- as.character(nodes$id)
    nodes$label <- as.character(nodes$label)
    nodes$group <- as.character(nodes$group)
    nodes$color <- as.character(nodes$color)
    nodes$font.size <- as.numeric(nodes$font.size)
    nodes$font.color <- as.character(nodes$font.color)
    
    return(nodes)
}

#' Validate Edge Data
#' 
#' Validates and fixes edge data structure
#' 
#' @param edges Data frame containing edge information
#' @return Validated and corrected edges data frame
#' @export
validate_edge_data <- function(edges) {
    if (is.null(edges) || nrow(edges) == 0) {
        return(data.frame(
            from = character(0),
            to = character(0),
            arrows = character(0),
            smooth = logical(0),
            width = numeric(0),
            color = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    # Validate edges
    required_edge_cols <- c("from", "to")
    missing_edge_cols <- setdiff(required_edge_cols, names(edges))
    
    if (length(missing_edge_cols) > 0) {
        warning(paste("Missing edge columns:", paste(missing_edge_cols, collapse = ", ")))
        if (!"from" %in% names(edges) | !"to" %in% names(edges)) {
            stop("Edge 'from' and 'to' columns are required")
        }
    }
    
    # Add optional edge columns if missing
    if (!"arrows" %in% names(edges)) edges$arrows <- "to"
    if (!"smooth" %in% names(edges)) edges$smooth <- TRUE
    if (!"width" %in% names(edges)) edges$width <- 1.5
    if (!"color" %in% names(edges)) edges$color <- "#2F4F4F80"
    
    # Remove self-loops
    self_loops <- edges$from == edges$to
    if (any(self_loops)) {
        warning(paste("Removing", sum(self_loops), "self-loop edges"))
        edges <- edges[!self_loops, ]
    }
    
    # Remove duplicate edges
    edge_pairs <- paste(edges$from, edges$to, sep = "->")
    if (any(duplicated(edge_pairs))) {
        warning("Duplicate edges found, removing duplicates")
        edges <- edges[!duplicated(edge_pairs), ]
    }
    
    # Ensure all required columns are properly typed
    edges$from <- as.character(edges$from)
    edges$to <- as.character(edges$to)
    edges$arrows <- as.character(edges$arrows)
    edges$smooth <- as.logical(edges$smooth)
    edges$width <- as.numeric(edges$width)
    edges$color <- as.character(edges$color)
    
    return(edges)
}

#' Check Data Consistency
#'
#' Checks consistency between nodes and edges data
#'
#' @param nodes Data frame containing node information
#' @param edges Data frame containing edge information
#' @return List with consistency check results
#' @export
check_data_consistency <- function(nodes, edges) {
    issues <- character(0)
    
    if (is.null(nodes) || nrow(nodes) == 0) {
        issues <- c(issues, "No nodes data available")
    }
    
    if (is.null(edges) || nrow(edges) == 0) {
        issues <- c(issues, "No edges data available")
    }
    
    if (length(issues) > 0) {
        return(list(consistent = FALSE, issues = issues))
    }
    
    # Check if all edge endpoints exist in nodes
    missing_from <- setdiff(edges$from, nodes$id)
    missing_to <- setdiff(edges$to, nodes$id)
    
    if (length(missing_from) > 0) {
        issues <- c(issues, paste("Edge 'from' nodes not in nodes data:", paste(missing_from, collapse = ", ")))
    }
    
    if (length(missing_to) > 0) {
        issues <- c(issues, paste("Edge 'to' nodes not in nodes data:", paste(missing_to, collapse = ", ")))
    }
    
    # Check for isolated nodes
    connected_nodes <- unique(c(edges$from, edges$to))
    isolated_nodes <- setdiff(nodes$id, connected_nodes)
    
    if (length(isolated_nodes) > 0) {
        issues <- c(issues, paste("Isolated nodes found:", length(isolated_nodes), "nodes"))
    }
    
    return(list(
        consistent = length(issues) == 0,
        issues = issues,
        isolated_nodes = isolated_nodes,
        total_nodes = nrow(nodes),
        total_edges = nrow(edges),
        connected_nodes = length(connected_nodes)
    ))
}
