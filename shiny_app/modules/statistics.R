# Statistics Module
# This module contains statistical analysis functions, calculations, and reporting functionality
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dplyr, ggplot2 (optional for enhanced plotting)

# Required libraries for this module
if (!require(dplyr)) stop("dplyr package is required")
if (!require(igraph)) stop("igraph package is required for cycle detection")

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

#' Detect Cycles in DAG
#'
#' Detects cycles in the DAG, particularly focusing on cycles involving Exposure and Outcome nodes
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

    # Create igraph object from edges
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

#' DFS to Find Cycle
#'
#' Simple DFS to find a cycle starting and ending at a specific vertex
#'
#' @param g igraph object
#' @param current current vertex
#' @param target target vertex to return to
#' @param visited visited vertices
#' @param path current path
#' @param vertex_names vertex names
#' @return Vector of vertex names forming a cycle, or empty vector
#' @keywords internal
dfs_find_cycle <- function(g, current, target, visited, path, vertex_names) {
    visited[current] <- TRUE
    path <- c(path, vertex_names[current])

    # Get neighbors
    neighbors <- igraph::neighbors(g, current, mode = "out")

    for (neighbor in neighbors) {
        neighbor_idx <- as.numeric(neighbor)

        if (neighbor_idx == target && length(path) > 1) {
            # Found cycle back to target
            return(c(path, vertex_names[target]))
        } else if (!visited[neighbor_idx]) {
            # Continue searching
            result <- dfs_find_cycle(g, neighbor_idx, target, visited, path, vertex_names)
            if (length(result) > 0) {
                return(result)
            }
        }
    }

    return(character(0))
}

#' Filter Cycles Involving Exposure and Outcome Nodes
#'
#' Filters cycles to find those that involve both Exposure and Outcome nodes
#'
#' @param all_cycles List of all cycles
#' @param nodes_df Data frame containing node information
#' @return List of cycles involving both Exposure and Outcome nodes
#' @keywords internal
filter_exposure_outcome_cycles <- function(all_cycles, nodes_df) {
    if (length(all_cycles) == 0) return(list())

    # Get exposure and outcome nodes using vectorized operations
    exposure_nodes <- nodes_df$id[nodes_df$group == "Exposure"]
    outcome_nodes <- nodes_df$id[nodes_df$group == "Outcome"]

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

#' Generate Cycle Detection Report
#'
#' Creates a user-friendly report about cycle detection results
#'
#' @param nodes_df Data frame containing node information
#' @param edges_df Data frame containing edge information
#' @return Formatted text string with cycle detection information
#' @export
generate_cycle_report <- function(nodes_df, edges_df) {
    cycle_results <- detect_dag_cycles(nodes_df, edges_df)

    if (!is.null(cycle_results$error)) {
        return(paste0("Cycle Detection Error:\n", cycle_results$error))
    }

    if (!cycle_results$has_cycles) {
        return("✓ No cycles detected - DAG structure is valid\n\nThis confirms that the graph is a proper Directed Acyclic Graph (DAG).")
    }

    # Build report for cycles found
    report <- paste0("⚠ CYCLES DETECTED - DAG Validation Failed\n\n")
    report <- paste0(report, "Total cycles found: ", cycle_results$total_cycles, "\n")
    report <- paste0(report, "Cycles involving Exposure/Outcome nodes: ", length(cycle_results$exposure_outcome_cycles), "\n\n")

    # Report exposure-outcome cycles first (most important)
    if (length(cycle_results$exposure_outcome_cycles) > 0) {
        report <- paste0(report, "CRITICAL: Cycles involving Exposure and Outcome nodes:\n")
        for (i in seq_along(cycle_results$exposure_outcome_cycles)) {
            cycle <- cycle_results$exposure_outcome_cycles[[i]]
            cycle_path <- format_cycle_path(cycle, nodes_df)
            report <- paste0(report, "  ", i, ". ", cycle_path, "\n")
        }
        report <- paste0(report, "\n")
    }

    # Report other cycles
    other_cycles <- cycle_results$cycles[!cycle_results$cycles %in% cycle_results$exposure_outcome_cycles]
    if (length(other_cycles) > 0) {
        report <- paste0(report, "Other cycles detected:\n")
        max_other_cycles <- min(5, length(other_cycles))  # Limit to 5 for readability
        for (i in 1:max_other_cycles) {
            cycle <- other_cycles[[i]]
            cycle_path <- format_cycle_path(cycle, nodes_df)
            report <- paste0(report, "  ", i, ". ", cycle_path, "\n")
        }
        if (length(other_cycles) > 5) {
            report <- paste0(report, "  ... and ", length(other_cycles) - 5, " more cycles\n")
        }
    }

    report <- paste0(report, "\nNote: DAGs should not contain cycles. Please review the graph structure.")

    return(report)
}

#' Format Cycle Path for Display
#'
#' Formats a cycle path for user-friendly display, highlighting Exposure and Outcome nodes
#'
#' @param cycle Vector of node names in the cycle
#' @param nodes_df Data frame containing node information
#' @return Formatted string showing the cycle path
#' @keywords internal
format_cycle_path <- function(cycle, nodes_df) {
    if (length(cycle) == 0) return("")

    # Get node categories
    node_categories <- setNames(nodes_df$group, nodes_df$id)

    # Format each node in the cycle with category information
    formatted_nodes <- sapply(cycle, function(node) {
        category <- node_categories[node]
        if (is.na(category)) category <- "Unknown"

        # Add category indicators for important nodes
        if (category == "Exposure") {
            return(paste0(node, " [EXPOSURE]"))
        } else if (category == "Outcome") {
            return(paste0(node, " [OUTCOME]"))
        } else {
            return(node)
        }
    })

    # Create cycle path
    cycle_path <- paste(formatted_nodes, collapse = " → ")

    return(cycle_path)
}
