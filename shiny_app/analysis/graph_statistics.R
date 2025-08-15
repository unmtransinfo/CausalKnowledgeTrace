# Graph Statistics Module
# 
# This module contains basic graph metrics and statistical analysis functions
# for DAG visualization and analysis.
#
# Author: Refactored from statistics.R
# Date: February 2025

#' Calculate DAG Statistics
#'
#' Calculates basic statistics for a DAG including node and edge counts
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing various DAG statistics
#' @export
calculate_dag_statistics <- function(nodes_df, edges_df) {
    if (is.null(nodes_df)) nodes_df <- data.frame()
    if (is.null(edges_df)) edges_df <- data.frame()
    
    return(list(
        total_nodes = nrow(nodes_df),
        total_edges = nrow(edges_df),
        node_types = if (nrow(nodes_df) > 0 && "group" %in% names(nodes_df)) {
            table(nodes_df$group)
        } else {
            table(character(0))
        },
        density = if (nrow(nodes_df) > 1) {
            nrow(edges_df) / (nrow(nodes_df) * (nrow(nodes_df) - 1))
        } else {
            0
        },
        avg_degree = if (nrow(nodes_df) > 0) {
            (2 * nrow(edges_df)) / nrow(nodes_df)
        } else {
            0
        }
    ))
}

#' Analyze Node Distribution
#'
#' Analyzes the distribution of nodes by type/group
#'
#' @param nodes_df Data frame containing node information with 'group' column
#' @return Data frame with node distribution statistics
#' @export
analyze_node_distribution <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            group = character(0),
            count = integer(0),
            percentage = numeric(0),
            stringsAsFactors = FALSE
        ))
    }
    
    if (!"group" %in% names(nodes_df)) {
        # If no group column, treat all nodes as "Unknown"
        nodes_df$group <- "Unknown"
    }
    
    distribution <- table(nodes_df$group)
    total_nodes <- sum(distribution)
    
    result <- data.frame(
        group = names(distribution),
        count = as.integer(distribution),
        percentage = round((as.numeric(distribution) / total_nodes) * 100, 2),
        stringsAsFactors = FALSE
    )
    
    # Sort by count descending
    result <- result[order(result$count, decreasing = TRUE), ]
    rownames(result) <- NULL
    
    return(result)
}

#' Create Distribution Plot Data
#'
#' Prepares data for plotting node distribution
#'
#' @param nodes_df Data frame containing node information
#' @return List containing plot data and labels
#' @export
create_distribution_plot_data <- function(nodes_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(list(
            counts = numeric(0),
            labels = character(0),
            colors = character(0)
        ))
    }
    
    distribution <- analyze_node_distribution(nodes_df)
    
    # Define colors for different node types
    color_palette <- c(
        "Exposure" = "#FF6B6B",
        "Outcome" = "#4ECDC4", 
        "Other" = "#95A5A6",
        "Unknown" = "#BDC3C7",
        "Confounder" = "#F39C12",
        "Mediator" = "#9B59B6"
    )
    
    colors <- sapply(distribution$group, function(group) {
        if (group %in% names(color_palette)) {
            color_palette[[group]]
        } else {
            "#95A5A6"  # Default gray
        }
    })
    
    return(list(
        counts = distribution$count,
        labels = paste0(distribution$group, " (", distribution$count, ")"),
        colors = colors,
        percentages = distribution$percentage
    ))
}

#' Generate DAG Report
#'
#' Generates a comprehensive text report of DAG statistics
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @param dag_source Character string describing the source of the DAG
#' @return Character string containing formatted report
#' @export
generate_dag_report <- function(nodes_df, edges_df, dag_source = "unknown") {
    if (is.null(nodes_df)) nodes_df <- data.frame()
    if (is.null(edges_df)) edges_df <- data.frame()
    
    stats <- calculate_dag_statistics(nodes_df, edges_df)
    distribution <- analyze_node_distribution(nodes_df)
    
    report <- paste0(
        "DAG Analysis Report\n",
        "==================\n",
        "Source: ", dag_source, "\n",
        "Generated: ", Sys.time(), "\n\n",
        "Basic Statistics:\n",
        "- Total Nodes: ", stats$total_nodes, "\n",
        "- Total Edges: ", stats$total_edges, "\n",
        "- Graph Density: ", round(stats$density, 4), "\n",
        "- Average Degree: ", round(stats$avg_degree, 2), "\n\n"
    )
    
    if (nrow(distribution) > 0) {
        report <- paste0(report, "Node Distribution:\n")
        for (i in 1:nrow(distribution)) {
            report <- paste0(report, "- ", distribution$group[i], ": ", 
                           distribution$count[i], " (", distribution$percentage[i], "%)\n")
        }
    }
    
    return(report)
}

#' Calculate Node Degrees
#'
#' Calculates in-degree and out-degree for each node
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Data frame with node degree information
#' @export
calculate_node_degrees <- function(nodes_df, edges_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0) {
        return(data.frame(
            node_id = character(0),
            in_degree = integer(0),
            out_degree = integer(0),
            total_degree = integer(0),
            stringsAsFactors = FALSE
        ))
    }
    
    if (is.null(edges_df) || nrow(edges_df) == 0) {
        # No edges, all degrees are 0
        return(data.frame(
            node_id = nodes_df$id,
            in_degree = rep(0, nrow(nodes_df)),
            out_degree = rep(0, nrow(nodes_df)),
            total_degree = rep(0, nrow(nodes_df)),
            stringsAsFactors = FALSE
        ))
    }
    
    # Calculate in-degrees
    in_degrees <- table(edges_df$to)
    
    # Calculate out-degrees
    out_degrees <- table(edges_df$from)
    
    # Create result data frame
    result <- data.frame(
        node_id = nodes_df$id,
        in_degree = 0,
        out_degree = 0,
        stringsAsFactors = FALSE
    )
    
    # Fill in degrees
    result$in_degree[result$node_id %in% names(in_degrees)] <- 
        in_degrees[result$node_id[result$node_id %in% names(in_degrees)]]
    
    result$out_degree[result$node_id %in% names(out_degrees)] <- 
        out_degrees[result$node_id[result$node_id %in% names(out_degrees)]]
    
    result$total_degree <- result$in_degree + result$out_degree
    
    return(result)
}

#' Generate Summary Stats
#'
#' Generates summary statistics for quick overview
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing summary statistics
#' @export
generate_summary_stats <- function(nodes_df, edges_df) {
    stats <- calculate_dag_statistics(nodes_df, edges_df)
    
    return(list(
        nodes = stats$total_nodes,
        edges = stats$total_edges,
        density = round(stats$density, 4),
        avg_degree = round(stats$avg_degree, 2),
        node_types = length(stats$node_types),
        largest_group = if (length(stats$node_types) > 0) {
            names(stats$node_types)[which.max(stats$node_types)]
        } else {
            "None"
        },
        largest_group_size = if (length(stats$node_types) > 0) {
            max(stats$node_types)
        } else {
            0
        }
    ))
}

#' Analyze Graph Connectivity
#'
#' Analyzes connectivity patterns in the graph
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
            hub_nodes = character(0),
            connectivity_score = 0
        ))
    }
    
    degrees <- calculate_node_degrees(nodes_df, edges_df)
    
    # Find different types of nodes
    isolated_nodes <- degrees$node_id[degrees$total_degree == 0]
    source_nodes <- degrees$node_id[degrees$in_degree == 0 & degrees$out_degree > 0]
    sink_nodes <- degrees$node_id[degrees$out_degree == 0 & degrees$in_degree > 0]
    
    # Hub nodes (high degree nodes - top 10% or nodes with degree > mean + sd)
    if (nrow(degrees) > 0) {
        degree_threshold <- max(3, quantile(degrees$total_degree, 0.9))
        hub_nodes <- degrees$node_id[degrees$total_degree >= degree_threshold]
    } else {
        hub_nodes <- character(0)
    }
    
    # Simple connectivity score (proportion of nodes that are connected)
    connected_nodes <- sum(degrees$total_degree > 0)
    connectivity_score <- if (nrow(degrees) > 0) {
        connected_nodes / nrow(degrees)
    } else {
        0
    }
    
    return(list(
        isolated_nodes = isolated_nodes,
        source_nodes = source_nodes,
        sink_nodes = sink_nodes,
        hub_nodes = hub_nodes,
        connectivity_score = round(connectivity_score, 3),
        total_connected = connected_nodes,
        total_isolated = length(isolated_nodes)
    ))
}

#' Generate Connectivity Report
#'
#' Generates a text report of graph connectivity
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Character string containing connectivity report
#' @export
generate_connectivity_report <- function(nodes_df, edges_df) {
    connectivity <- analyze_graph_connectivity(nodes_df, edges_df)
    
    report <- paste0(
        "Graph Connectivity Analysis\n",
        "===========================\n",
        "Connectivity Score: ", connectivity$connectivity_score, "\n",
        "Connected Nodes: ", connectivity$total_connected, "\n",
        "Isolated Nodes: ", connectivity$total_isolated, "\n\n",
        "Special Node Types:\n",
        "- Source Nodes (no incoming edges): ", length(connectivity$source_nodes), "\n",
        "- Sink Nodes (no outgoing edges): ", length(connectivity$sink_nodes), "\n",
        "- Hub Nodes (high degree): ", length(connectivity$hub_nodes), "\n"
    )
    
    if (length(connectivity$isolated_nodes) > 0) {
        report <- paste0(report, "\nIsolated Nodes: ", 
                        paste(head(connectivity$isolated_nodes, 10), collapse = ", "))
        if (length(connectivity$isolated_nodes) > 10) {
            report <- paste0(report, " (and ", length(connectivity$isolated_nodes) - 10, " more)")
        }
    }
    
    return(report)
}
