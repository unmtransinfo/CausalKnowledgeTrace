# Network Processing Module
# This module contains functions for converting DAG objects to network data
# Author: Refactored from data_upload.R
# Dependencies: dagitty, igraph, dag_loading.R

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Source required modules
if (file.exists("modules/dag_loading.R")) {
    source("modules/dag_loading.R")
} else if (file.exists("dag_loading.R")) {
    source("dag_loading.R")
}

# Source node_information module if available
if (file.exists("modules/node_information.R")) {
    source("modules/node_information.R")
} else if (file.exists("node_information.R")) {
    source("node_information.R")
}

#' Create Network Data from DAG Object
#' 
#' Converts a dagitty DAG object into network data suitable for visualization
#' 
#' @param dag_object dagitty DAG object
#' @return List containing nodes and edges data frames
#' @export
create_network_data <- function(dag_object) {
    # Validate the DAG first
    validation <- validate_dag_object(dag_object)
    if (!validation$valid) {
        warning(paste("DAG validation failed:", validation$message))
        # Return minimal fallback data
        return(list(
            nodes = data.frame(
                id = c("Error", "Fallback"),
                label = c("Error Node", "Fallback Node"),
                group = c("Other", "Other"),
                color = c("#FF0000", "#808080"),
                font.size = 14,
                font.color = "black",
                stringsAsFactors = FALSE
            ),
            edges = data.frame(
                from = "Error",
                to = "Fallback",
                arrows = "to",
                smooth = TRUE,
                width = 1,
                color = "#666666",
                stringsAsFactors = FALSE
            ),
            dag = dag_object
        ))
    }
    
    # Convert DAG to igraph with error handling
    ig <- NULL
    conversion_success <- FALSE

    # First try with dagitty2graph if available
    if (exists("dagitty2graph")) {
        tryCatch({
            ig <- dagitty2graph(dag_object)
            conversion_success <- TRUE
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Successfully converted DAG to igraph using dagitty2graph\n")
            }
        }, error = function(e) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Error converting DAG to igraph with dagitty2graph:", e$message, "\n")
            }
            conversion_success <- FALSE
        })
    } else {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("dagitty2graph function not available, trying alternative method\n")
        }
    }

    # Fallback: try to extract edges by parsing DAG string
    if (!conversion_success) {
        tryCatch({
            # Parse the DAG string to extract edges
            dag_str <- as.character(dag_object)
            # Find all edge patterns like "node1 -> node2"
            edge_matches <- regmatches(dag_str, gregexpr('[A-Za-z0-9_]+ -> [A-Za-z0-9_]+', dag_str))

            if (length(edge_matches[[1]]) > 0) {
                # Parse each edge pattern
                edges_raw <- edge_matches[[1]]
                edge_list <- matrix(nrow = length(edges_raw), ncol = 2)

                for (i in seq_along(edges_raw)) {
                    parts <- strsplit(edges_raw[i], " -> ")[[1]]
                    if (length(parts) == 2) {
                        edge_list[i, 1] <- parts[1]
                        edge_list[i, 2] <- parts[2]
                    }
                }

                # Remove any NA rows
                edge_list <- edge_list[complete.cases(edge_list), , drop = FALSE]

                if (nrow(edge_list) > 0) {
                    # Create igraph from edge list
                    ig <- igraph::graph_from_edgelist(edge_list, directed = TRUE)
                    conversion_success <- TRUE
                    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                        cat("Successfully created graph using DAG string parsing -", nrow(edge_list), "edges found\n")
                    }
                } else {
                    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                        cat("No valid edges found after parsing\n")
                    }
                }
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("No edge patterns found in DAG string\n")
                }
            }
        }, error = function(e) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Error with DAG string parsing:", e$message, "\n")
            }
        })
    }

    # Final fallback: create empty graph
    if (!conversion_success || is.null(ig)) {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Using empty graph fallback\n")
        }
        ig <- igraph::make_empty_graph(n = 0, directed = TRUE)
    }
    
    # Create nodes dataframe using the node_information module
    if (exists("create_nodes_dataframe")) {
        nodes <- create_nodes_dataframe(dag_object)
    } else {
        # Fallback if node_information module not available
        all_nodes <- names(dag_object)
        nodes <- data.frame(
            id = all_nodes,
            label = gsub("_", " ", all_nodes),
            group = "Other",
            color = "#808080",
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        )
    }
    
    # Create edges dataframe with error handling
    edges <- data.frame(
        from = character(0),
        to = character(0),
        arrows = character(0),
        smooth = logical(0),
        width = numeric(0),
        color = character(0),
        stringsAsFactors = FALSE
    )
    
    # Try to extract edges
    tryCatch({
        if (length(igraph::E(ig)) > 0) {
            edge_list <- igraph::as_edgelist(ig)
            if (nrow(edge_list) > 0) {
                edges <- data.frame(
                    from = edge_list[,1],
                    to = edge_list[,2],
                    arrows = "to",
                    smooth = TRUE,
                    width = 1,  # Thinner lines for large graphs
                    color = "#666666",
                    stringsAsFactors = FALSE
                )
            }
        }
    }, error = function(e) {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Warning: Could not extract edges from graph:", e$message, "\n")
        }
    })

    # Print summary for large graphs
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING && nrow(nodes) > 50) {
        cat("Graph summary:\n")
        cat("- Nodes:", nrow(nodes), "\n")
        cat("- Edges:", nrow(edges), "\n")
        cat("- Node categories:", length(unique(nodes$group)), "\n")
        cat("- Categories:", paste(sort(unique(nodes$group)), collapse = ", "), "\n")
    }
    
    return(list(nodes = nodes, edges = edges, dag = dag_object))
}

#' Process Large DAG
#' 
#' @param dag_object dagitty DAG object
#' @param max_nodes Maximum nodes before applying optimizations (default: 1000)
#' @return List containing processed network data
#' @export
process_large_dag <- function(dag_object, max_nodes = 1000) {
    all_nodes <- names(dag_object)
    
    # If graph is too large, provide warning
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING && length(all_nodes) > max_nodes) {
        cat("Warning: Graph has", length(all_nodes), "nodes, which is quite large.\n")
        cat("Consider using graph filtering or optimization features.\n")
    }
    
    # Use standard network data creation
    return(create_network_data(dag_object))
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
    
    # Ensure required columns exist
    required_cols <- c("from", "to")
    if (!all(required_cols %in% names(edges))) {
        stop("Edge data must contain 'from' and 'to' columns")
    }
    
    # Add default values for optional columns if missing
    if (!"arrows" %in% names(edges)) edges$arrows <- "to"
    if (!"smooth" %in% names(edges)) edges$smooth <- TRUE
    if (!"width" %in% names(edges)) edges$width <- 1
    if (!"color" %in% names(edges)) edges$color <- "#666666"
    
    return(edges)
}

