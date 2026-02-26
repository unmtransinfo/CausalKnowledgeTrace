# Node Information Module
# This module contains functions for managing, processing, and displaying node data and metadata
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dplyr, dagitty, igraph

# Required libraries for this module
if (!require(dplyr)) stop("dplyr package is required")
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

#' Get Node Color Scheme
#'
#' Returns the color scheme mapping for different node categories
#'
#' @return Named list of colors for each category
#' @export
get_node_color_scheme <- function() {
    return(list(
        Exposure = "#FF6B6B",           # Red for exposure
        Outcome = "#4ECDC4",            # Teal for outcome
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

    # Get all node names
    all_nodes <- names(dag_object)

    # Get exposure and outcome nodes using dagitty functions
    exposure_nodes <- tryCatch(exposures(dag_object), error = function(e) character(0))
    outcome_nodes <- tryCatch(outcomes(dag_object), error = function(e) character(0))

    # Create nodes dataframe
    nodes <- data.frame(
        id = all_nodes,
        label = gsub("_", " ", all_nodes),
        stringsAsFactors = FALSE
    )

    # Assign groups and colors based on node type using centralized color scheme
    color_scheme <- get_node_color_scheme()

    nodes$group <- "Other"
    nodes$color <- color_scheme[["Other"]]

    # Set exposure nodes
    if (length(exposure_nodes) > 0) {
        nodes$group[nodes$id %in% exposure_nodes] <- "Exposure"
        nodes$color[nodes$id %in% exposure_nodes] <- color_scheme[["Exposure"]]
    }

    # Set outcome nodes
    if (length(outcome_nodes) > 0) {
        nodes$group[nodes$id %in% outcome_nodes] <- "Outcome"
        nodes$color[nodes$id %in% outcome_nodes] <- color_scheme[["Outcome"]]
    }

    # Add font properties
    nodes$font.size <- 14
    nodes$font.color <- "black"

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
        if (!"color" %in% names(nodes)) nodes$color <- "#808080"
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
