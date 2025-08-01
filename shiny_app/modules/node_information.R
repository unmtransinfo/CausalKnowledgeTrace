# Node Information Module
# This module contains functions for managing, processing, and displaying node data and metadata
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dplyr, dagitty, igraph

# Required libraries for this module
if (!require(dplyr)) stop("dplyr package is required")
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

#' Simplified Node Categorization Function
#'
#' Categorizes nodes based on DAG properties (exposure/outcome) or as "Other"
#'
#' @param node_name Name of the node to categorize
#' @param dag_object dagitty object containing the DAG
#' @return String representing the node category ("Exposure", "Outcome", or "Other")
#' @export
categorize_node <- function(node_name, dag_object = NULL) {
    # Extract exposure and outcome from dagitty object if available
    exposures <- character(0)
    outcomes <- character(0)

    if (!is.null(dag_object)) {
        exposures <- tryCatch(exposures(dag_object), error = function(e) character(0))
        outcomes <- tryCatch(outcomes(dag_object), error = function(e) character(0))
    }

    # Check if node is marked as exposure or outcome in the DAG
    if (length(exposures) > 0 && node_name %in% exposures) return("Exposure")
    if (length(outcomes) > 0 && node_name %in% outcomes) return("Outcome")

    # All other nodes are categorized as "Other"
    return("Other")
}

#' Get Node Color Scheme
#'
#' Returns the color scheme mapping for different node categories
#'
#' @return Named list of colors for each category
#' @export
get_node_color_scheme <- function() {
    return(list(
        Exposure = "#FF4500",           # Bright orange-red for exposure (highly contrasting)
        Outcome = "#0066CC",            # Bright blue for outcome (highly contrasting)
        Other = "#808080"               # Gray for all other nodes
    ))
}

#' Create Nodes Data Frame
#' 
#' Creates a properly formatted nodes data frame from DAG object
#' 
#' @param dag_object dagitty object containing the DAG
#' @return Data frame with node information including id, label, group, and color
#' @export
create_nodes_dataframe <- function(dag_object) {
    if (is.null(dag_object)) {
        # Return minimal fallback data
        return(data.frame(
            id = c("Node1", "Node2"),
            label = c("Node 1", "Node 2"),
            group = c("Other", "Other"),
            color = c("#808080", "#808080"),
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        ))
    }
    
    # Get all node names from the DAG
    all_nodes <- names(dag_object)
    
    if (length(all_nodes) == 0) {
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
    
    # Create nodes dataframe
    nodes <- data.frame(
        id = all_nodes,
        label = gsub("_", " ", all_nodes),
        stringsAsFactors = FALSE
    )
    
    # Apply categorization with progress indication for large graphs
    if (nrow(nodes) > 100) {
        cat("Processing", nrow(nodes), "nodes for categorization...\n")
    }
    
    nodes$group <- sapply(nodes$id, function(x) categorize_node(x, dag_object))
    
    # Add node properties
    nodes$font.size <- 14  # Smaller font for large graphs
    nodes$font.color <- "black"
    
    # Get color scheme and assign colors
    color_scheme <- get_node_color_scheme()
    nodes$color <- sapply(nodes$group, function(g) {
        if (g %in% names(color_scheme)) {
            return(color_scheme[[g]])
        } else {
            return("#808080")  # Default gray
        }
    })
    
    return(nodes)
}

#' Validate Node Data
#' 
#' Validates and fixes node data structure
#' 
#' @param nodes Data frame containing node information
#' @return Validated and corrected nodes data frame
#' @export
validate_node_data <- function(nodes) {
    # Validate nodes
    required_node_cols <- c("id", "label", "group", "color")
    missing_node_cols <- setdiff(required_node_cols, names(nodes))
    
    if (length(missing_node_cols) > 0) {
        warning(paste("Missing node columns:", paste(missing_node_cols, collapse = ", ")))
        # Add missing columns with defaults
        if (!"id" %in% names(nodes)) stop("Node 'id' column is required")
        if (!"label" %in% names(nodes)) nodes$label <- nodes$id
        if (!"group" %in% names(nodes)) nodes$group <- "Other"
        if (!"color" %in% names(nodes)) nodes$color <- "#A9B7C0"
    }
    
    # Add optional columns if missing
    if (!"font.size" %in% names(nodes)) nodes$font.size <- 16
    if (!"font.color" %in% names(nodes)) nodes$font.color <- "black"
    
    return(nodes)
}

#' Get Node Summary Statistics
#' 
#' Generates summary statistics for nodes
#' 
#' @param nodes_df Data frame containing node information
#' @return List containing various node statistics
#' @export
get_node_summary <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(
            total_nodes = 0,
            total_groups = 0,
            group_counts = data.frame(),
            primary_nodes = character(0)
        ))
    }
    
    group_counts <- nodes_df %>%
        group_by(group) %>%
        summarise(count = n(), .groups = 'drop') %>%
        arrange(desc(count))
    
    primary_nodes <- nodes_df[nodes_df$group %in% c("Exposure", "Outcome"), ]
    
    return(list(
        total_nodes = nrow(nodes_df),
        total_groups = length(unique(nodes_df$group)),
        group_counts = group_counts,
        primary_nodes = primary_nodes$label
    ))
}

#' Create Nodes Table for Display
#' 
#' Prepares node data for display in data tables
#' 
#' @param nodes_df Data frame containing node information
#' @return Data frame formatted for display
#' @export
create_nodes_display_table <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            ID = character(0),
            Label = character(0),
            Group = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    display_table <- nodes_df[, c("id", "label", "group")]
    names(display_table) <- c("ID", "Label", "Group")
    
    return(display_table)
}

#' Get Available Node Categories
#' 
#' Returns all available node categories with descriptions
#' 
#' @return Data frame with category names and descriptions
#' @export
get_node_categories_info <- function() {
    return(data.frame(
        Category = c("Exposure", "Outcome", "Other"),
        Description = c(
            "Variables marked as exposure in the DAG",
            "Variables marked as outcome in the DAG",
            "All other variables in the DAG"
        ),
        Color = unlist(get_node_color_scheme()),
        stringsAsFactors = FALSE
    ))
}
