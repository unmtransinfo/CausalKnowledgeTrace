# Statistics Module
# This module contains statistical analysis functions, calculations, and reporting functionality
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dplyr, ggplot2 (optional for enhanced plotting)

# Required libraries for this module
if (!require(dplyr)) stop("dplyr package is required")

#' Calculate Basic DAG Statistics
#' 
#' Calculates basic statistics about the DAG structure
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing basic DAG statistics
#' @export
calculate_dag_statistics <- function(nodes_df, edges_df) {
    if (is.null(nodes_df)) nodes_df <- data.frame()
    if (is.null(edges_df)) edges_df <- data.frame()
    
    stats <- list(
        total_nodes = nrow(nodes_df),
        total_edges = nrow(edges_df),
        total_groups = if(nrow(nodes_df) > 0) length(unique(nodes_df$group)) else 0,
        density = if(nrow(nodes_df) > 1) nrow(edges_df) / (nrow(nodes_df) * (nrow(nodes_df) - 1)) else 0,
        avg_degree = if(nrow(nodes_df) > 0) (2 * nrow(edges_df)) / nrow(nodes_df) else 0
    )
    
    return(stats)
}

#' Generate Node Distribution Analysis
#' 
#' Analyzes the distribution of nodes across different categories
#' 
#' @param nodes_df Data frame containing node information
#' @return Data frame with group distribution statistics
#' @export
analyze_node_distribution <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            group = character(0),
            count = numeric(0),
            percentage = numeric(0),
            color = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    distribution <- nodes_df %>%
        group_by(group) %>%
        summarise(
            count = n(),
            color = first(color),
            .groups = 'drop'
        ) %>%
        mutate(
            percentage = round((count / sum(count)) * 100, 1)
        ) %>%
        arrange(desc(count))
    
    return(distribution)
}

#' Create Node Distribution Plot Data
#' 
#' Prepares data for creating node distribution plots
#' 
#' @param nodes_df Data frame containing node information
#' @return List containing plot data and colors
#' @export
create_distribution_plot_data <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(
            counts = numeric(0),
            colors = character(0),
            labels = character(0)
        ))
    }
    
    group_counts <- table(nodes_df$group)
    colors <- nodes_df %>%
        group_by(group) %>%
        summarise(color = first(color), .groups = 'drop') %>%
        arrange(match(group, names(group_counts)))
    
    return(list(
        counts = as.numeric(group_counts),
        colors = colors$color,
        labels = names(group_counts)
    ))
}

#' Generate DAG Structure Report
#' 
#' Creates a comprehensive text report about the DAG structure
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @param dag_source Source of the DAG data (e.g., filename)
#' @return Formatted text string with DAG information
#' @export
generate_dag_report <- function(nodes_df, edges_df, dag_source = "unknown") {
    if (is.null(nodes_df)) nodes_df <- data.frame()
    if (is.null(edges_df)) edges_df <- data.frame()
    
    stats <- calculate_dag_statistics(nodes_df, edges_df)
    
    # Find primary variables (exposure/outcome)
    primary_nodes <- character(0)
    if (nrow(nodes_df) > 0) {
        primary_nodes <- nodes_df[nodes_df$group %in% c("Exposure", "Outcome"), ]$label
    }
    
    report <- paste0(
        "DAG Structure Information:\n\n",
        "- Total Variables: ", stats$total_nodes, "\n",
        "- Total Relationships: ", stats$total_edges, "\n",
        "- Node Groups: ", stats$total_groups, "\n",
        "- Graph Density: ", round(stats$density, 3), "\n",
        "- Average Degree: ", round(stats$avg_degree, 2), "\n",
        "- Primary Variables: ", if(length(primary_nodes) > 0) paste(primary_nodes, collapse = ", ") else "None", "\n",
        "- Graph Type: Directed Acyclic Graph (DAG)\n",
        "- Visualization: Interactive Network\n",
        "- Data Source: ", dag_source
    )
    
    return(report)
}

#' Calculate Node Degree Statistics
#' 
#' Calculates in-degree and out-degree for each node
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Data frame with degree statistics for each node
#' @export
calculate_node_degrees <- function(nodes_df, edges_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            node_id = character(0),
            in_degree = numeric(0),
            out_degree = numeric(0),
            total_degree = numeric(0),
            stringsAsFactors = FALSE
        ))
    }
    
    # Initialize degree data frame
    degree_stats <- data.frame(
        node_id = nodes_df$id,
        in_degree = 0,
        out_degree = 0,
        stringsAsFactors = FALSE
    )
    
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        # Calculate in-degrees
        in_degrees <- table(edges_df$to)
        degree_stats$in_degree[match(names(in_degrees), degree_stats$node_id)] <- as.numeric(in_degrees)
        
        # Calculate out-degrees
        out_degrees <- table(edges_df$from)
        degree_stats$out_degree[match(names(out_degrees), degree_stats$node_id)] <- as.numeric(out_degrees)
    }
    
    # Calculate total degree
    degree_stats$total_degree <- degree_stats$in_degree + degree_stats$out_degree
    
    return(degree_stats)
}

#' Generate Summary Statistics for Value Boxes
#' 
#' Creates summary statistics suitable for Shiny value boxes
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing statistics for value boxes
#' @export
generate_summary_stats <- function(nodes_df, edges_df) {
    stats <- calculate_dag_statistics(nodes_df, edges_df)
    
    return(list(
        total_nodes = list(
            value = stats$total_nodes,
            subtitle = "Total Nodes",
            icon = "circle",
            color = "blue"
        ),
        total_edges = list(
            value = stats$total_edges,
            subtitle = "Total Edges", 
            icon = "arrow-right",
            color = "green"
        ),
        total_groups = list(
            value = stats$total_groups,
            subtitle = "Node Groups",
            icon = "tags",
            color = "purple"
        )
    ))
}

#' Analyze Graph Connectivity
#' 
#' Analyzes connectivity patterns in the DAG
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing connectivity analysis results
#' @export
analyze_graph_connectivity <- function(nodes_df, edges_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0 || is.null(edges_df) || nrow(edges_df) == 0) {
        return(list(
            isolated_nodes = character(0),
            source_nodes = character(0),
            sink_nodes = character(0),
            hub_nodes = character(0)
        ))
    }
    
    degree_stats <- calculate_node_degrees(nodes_df, edges_df)
    
    # Find different types of nodes
    isolated_nodes <- degree_stats$node_id[degree_stats$total_degree == 0]
    source_nodes <- degree_stats$node_id[degree_stats$in_degree == 0 & degree_stats$out_degree > 0]
    sink_nodes <- degree_stats$node_id[degree_stats$out_degree == 0 & degree_stats$in_degree > 0]
    
    # Define hub nodes as those with total degree > average + 1 standard deviation
    if (nrow(degree_stats) > 0) {
        avg_degree <- mean(degree_stats$total_degree)
        sd_degree <- sd(degree_stats$total_degree)
        hub_threshold <- avg_degree + sd_degree
        hub_nodes <- degree_stats$node_id[degree_stats$total_degree > hub_threshold]
    } else {
        hub_nodes <- character(0)
    }
    
    return(list(
        isolated_nodes = isolated_nodes,
        source_nodes = source_nodes,
        sink_nodes = sink_nodes,
        hub_nodes = hub_nodes
    ))
}

#' Generate Connectivity Report
#' 
#' Creates a text report about graph connectivity
#' 
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Formatted text string with connectivity information
#' @export
generate_connectivity_report <- function(nodes_df, edges_df) {
    connectivity <- analyze_graph_connectivity(nodes_df, edges_df)
    
    report <- paste0(
        "Graph Connectivity Analysis:\n\n",
        "- Isolated Nodes: ", length(connectivity$isolated_nodes), 
        if(length(connectivity$isolated_nodes) > 0) paste0(" (", paste(head(connectivity$isolated_nodes, 5), collapse = ", "), 
                                                          if(length(connectivity$isolated_nodes) > 5) "..." else "", ")") else "", "\n",
        "- Source Nodes: ", length(connectivity$source_nodes),
        if(length(connectivity$source_nodes) > 0) paste0(" (", paste(head(connectivity$source_nodes, 5), collapse = ", "),
                                                        if(length(connectivity$source_nodes) > 5) "..." else "", ")") else "", "\n",
        "- Sink Nodes: ", length(connectivity$sink_nodes),
        if(length(connectivity$sink_nodes) > 0) paste0(" (", paste(head(connectivity$sink_nodes, 5), collapse = ", "),
                                                      if(length(connectivity$sink_nodes) > 5) "..." else "", ")") else "", "\n",
        "- Hub Nodes: ", length(connectivity$hub_nodes),
        if(length(connectivity$hub_nodes) > 0) paste0(" (", paste(head(connectivity$hub_nodes, 5), collapse = ", "),
                                                     if(length(connectivity$hub_nodes) > 5) "..." else "", ")") else "", "\n"
    )
    
    return(report)
}
