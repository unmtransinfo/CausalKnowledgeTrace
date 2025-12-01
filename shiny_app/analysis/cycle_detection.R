# Cycle Detection Module
# 
# This module contains cycle detection algorithms and analysis functions
# for DAG validation and analysis.
#
# Author: Refactored from statistics.R
# Date: February 2025

#' Detect DAG Cycles
#'
#' Detects cycles in a directed graph to validate DAG properties
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List containing cycle detection results
#' @export
detect_dag_cycles <- function(nodes_df, edges_df) {
    if (is.null(nodes_df) || nrow(nodes_df) == 0 || is.null(edges_df) || nrow(edges_df) == 0) {
        return(list(
            has_cycles = FALSE,
            cycles = list(),
            exposure_outcome_cycles = list(),
            total_cycles = 0
        ))
    }

    tryCatch({
        g <- igraph::graph_from_data_frame(edges_df, directed = TRUE, vertices = nodes_df)

        # Check if graph is acyclic
        is_acyclic <- igraph::is_dag(g)

        if (is_acyclic) {
            return(list(
                has_cycles = FALSE,
                cycles = list(),
                exposure_outcome_cycles = list(),
                total_cycles = 0
            ))
        }

        # Find all cycles using DFS-based approach
        all_cycles <- find_all_cycles(g, nodes_df)

        # Filter cycles that involve both Exposure and Outcome nodes
        exposure_outcome_cycles <- filter_exposure_outcome_cycles(all_cycles, nodes_df)

        return(list(
            has_cycles = length(all_cycles) > 0,
            cycles = all_cycles,
            exposure_outcome_cycles = exposure_outcome_cycles,
            total_cycles = length(all_cycles)
        ))

    }, error = function(e) {
        warning(paste("Error in cycle detection:", e$message))
        return(list(
            has_cycles = FALSE,
            cycles = list(),
            exposure_outcome_cycles = list(),
            total_cycles = 0,
            error = e$message
        ))
    })
}

#' Find All Cycles in Graph
#'
#' Internal function to find all cycles in a directed graph using a simplified approach
#'
#' @param g igraph object
#' @param nodes_df Data frame containing node information
#' @return List of cycles, each cycle is a vector of node names
#' @keywords internal
find_all_cycles <- function(g, nodes_df) {
    cycles <- list()

    # Get vertex names
    vertex_names <- igraph::V(g)$name
    if (is.null(vertex_names)) {
        vertex_names <- as.character(1:igraph::vcount(g))
    }

    # Simple approach: try to find strongly connected components
    # If there are SCCs with more than one vertex, they contain cycles
    scc <- igraph::components(g, mode = "strong")

    for (i in 1:scc$no) {
        component_vertices <- which(scc$membership == i)
        if (length(component_vertices) > 1) {
            # This component has a cycle
            component_names <- vertex_names[component_vertices]

            # Try to find a simple cycle within this component
            subgraph <- igraph::induced_subgraph(g, component_vertices)

            # Find a path that forms a cycle
            cycle_path <- find_simple_cycle_in_component(subgraph, vertex_names[component_vertices])
            if (length(cycle_path) > 0) {
                cycles <- c(cycles, list(cycle_path))
            }
        }
    }

    return(cycles)
}

#' Find Simple Cycle in Component
#'
#' Find a simple cycle within a strongly connected component
#'
#' @param subgraph igraph subgraph object
#' @param vertex_names names of vertices in the subgraph
#' @return Vector of node names forming a cycle, or empty vector if none found
#' @keywords internal
find_simple_cycle_in_component <- function(subgraph, vertex_names) {
    if (igraph::vcount(subgraph) < 2) return(character(0))

    # Start from the first vertex and try to find a path back to it
    start_vertex <- 1
    visited <- rep(FALSE, igraph::vcount(subgraph))
    path <- character(0)

    cycle <- dfs_find_cycle(subgraph, start_vertex, start_vertex, visited, path, vertex_names)
    return(cycle)
}

#' DFS Find Cycle
#'
#' Depth-first search to find a cycle starting and ending at target vertex
#'
#' @param g igraph object
#' @param current current vertex index
#' @param target target vertex index to return to
#' @param visited logical vector of visited vertices
#' @param path current path as character vector
#' @param vertex_names names of vertices
#' @return Vector of node names forming a cycle, or empty vector if none found
#' @keywords internal
dfs_find_cycle <- function(g, current, target, visited, path, vertex_names) {
    visited[current] <- TRUE
    path <- c(path, vertex_names[current])

    # Get neighbors
    neighbors <- igraph::neighbors(g, current, mode = "out")

    for (neighbor in neighbors) {
        if (neighbor == target && length(path) > 1) {
            # Found a cycle back to target
            return(c(path, vertex_names[target]))
        } else if (!visited[neighbor]) {
            # Continue DFS
            result <- dfs_find_cycle(g, neighbor, target, visited, path, vertex_names)
            if (length(result) > 0) {
                return(result)
            }
        }
    }

    return(character(0))
}

#' Filter Exposure Outcome Cycles
#'
#' Filter cycles that involve both exposure and outcome nodes
#'
#' @param all_cycles List of all detected cycles
#' @param nodes_df Data frame containing node information with group column
#' @return List of cycles involving both exposure and outcome nodes
#' @keywords internal
filter_exposure_outcome_cycles <- function(all_cycles, nodes_df) {
    if (length(all_cycles) == 0) return(list())

    # Get exposure and outcome nodes using vectorized operations
    exposure_nodes <- character(0)
    outcome_nodes <- character(0)

    if ("group" %in% names(nodes_df)) {
        exposure_nodes <- nodes_df$id[nodes_df$group == "Exposure"]
        outcome_nodes <- nodes_df$id[nodes_df$group == "Outcome"]
    }

    if (length(exposure_nodes) == 0 || length(outcome_nodes) == 0) {
        return(list())
    }

    exposure_outcome_cycles <- list()

    for (cycle in all_cycles) {
        has_exposure <- any(cycle %in% exposure_nodes)
        has_outcome <- any(cycle %in% outcome_nodes)

        if (has_exposure && has_outcome) {
            exposure_outcome_cycles <- c(exposure_outcome_cycles, list(cycle))
        }
    }

    return(exposure_outcome_cycles)
}

#' Generate Cycle Report
#'
#' Generates a comprehensive report of cycle detection results
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Character string containing formatted cycle report
#' @export
generate_cycle_report <- function(nodes_df, edges_df) {
    cycle_results <- detect_dag_cycles(nodes_df, edges_df)

    if (!is.null(cycle_results$error)) {
        return(paste("Error in cycle detection:", cycle_results$error))
    }

    report <- paste0(
        "Cycle Detection Report\n",
        "=====================\n",
        "Graph is ", if (cycle_results$has_cycles) "NOT " else "", "acyclic (DAG property)\n",
        "Total cycles found: ", cycle_results$total_cycles, "\n"
    )

    if (cycle_results$has_cycles) {
        report <- paste0(report, "\nCycle Details:\n")

        # Report general cycles
        if (length(cycle_results$cycles) > 0) {
            report <- paste0(report, "All cycles (", length(cycle_results$cycles), "):\n")
            for (i in seq_along(cycle_results$cycles)) {
                cycle <- cycle_results$cycles[[i]]
                formatted_cycle <- format_cycle_path(cycle, nodes_df)
                report <- paste0(report, "  ", i, ". ", formatted_cycle, "\n")
            }
        }

        # Report exposure-outcome cycles specifically
        if (length(cycle_results$exposure_outcome_cycles) > 0) {
            report <- paste0(report, "\nExposure-Outcome cycles (", 
                           length(cycle_results$exposure_outcome_cycles), "):\n")
            for (i in seq_along(cycle_results$exposure_outcome_cycles)) {
                cycle <- cycle_results$exposure_outcome_cycles[[i]]
                formatted_cycle <- format_cycle_path(cycle, nodes_df)
                report <- paste0(report, "  ", i, ". ", formatted_cycle, "\n")
            }
            report <- paste0(report, "\nWarning: Cycles involving both exposure and outcome nodes\n",
                           "may indicate problems with causal identification.\n")
        }
    } else {
        report <- paste0(report, "\nThe graph satisfies the DAG property (no cycles detected).\n",
                        "This is good for causal inference applications.\n")
    }

    return(report)
}

#' Format Cycle Path
#'
#' Formats a cycle path for display with node categories
#'
#' @param cycle Vector of node names in the cycle
#' @param nodes_df Data frame containing node information
#' @return Character string with formatted cycle path
#' @keywords internal
format_cycle_path <- function(cycle, nodes_df) {
    if (length(cycle) == 0) return("")

    # Get node categories
    node_categories <- setNames(nodes_df$group, nodes_df$id)

    # Format each node in the cycle with category information
    formatted_nodes <- sapply(cycle, function(node) {
        category <- node_categories[node]
        if (is.na(category)) category <- "Unknown"
        paste0(node, " (", category, ")")
    })

    # Create cycle path
    cycle_path <- paste(formatted_nodes, collapse = " -> ")
    
    # Add arrow back to start to show it's a cycle
    if (length(cycle) > 1) {
        cycle_path <- paste0(cycle_path, " -> ", formatted_nodes[1])
    }

    return(cycle_path)
}

#' Check DAG Validity
#'
#' Quick check to determine if the graph is a valid DAG
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return List with validity check results
#' @export
check_dag_validity <- function(nodes_df, edges_df) {
    cycle_results <- detect_dag_cycles(nodes_df, edges_df)
    
    validity <- list(
        is_valid_dag = !cycle_results$has_cycles,
        has_cycles = cycle_results$has_cycles,
        cycle_count = cycle_results$total_cycles,
        has_exposure_outcome_cycles = length(cycle_results$exposure_outcome_cycles) > 0,
        exposure_outcome_cycle_count = length(cycle_results$exposure_outcome_cycles)
    )
    
    # Add validation message
    if (validity$is_valid_dag) {
        validity$message <- "Graph is a valid DAG (no cycles detected)"
        validity$status <- "valid"
    } else {
        validity$message <- paste("Graph contains", validity$cycle_count, "cycle(s)")
        validity$status <- "invalid"
        
        if (validity$has_exposure_outcome_cycles) {
            validity$message <- paste0(validity$message, 
                                     " including ", validity$exposure_outcome_cycle_count, 
                                     " involving exposure-outcome relationships")
            validity$status <- "critical"
        }
    }
    
    return(validity)
}
