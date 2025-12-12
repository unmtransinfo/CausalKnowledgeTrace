# Graph Filtering Module
# This module handles graph filtering operations including leaf removal and path filtering
# Author: Refactored from data_upload.R
# Dependencies: dagitty, igraph

# Required libraries
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Remove Leaf Nodes from DAG
#'
#' Iteratively removes nodes with total degree = 1 (leaf nodes) from the DAG
#' Optionally preserves exposure and outcome nodes
#'
#' @param dag_object dagitty object containing the DAG
#' @param preserve_exposure_outcome Whether to preserve exposure/outcome nodes (default: TRUE)
#' @return List containing success status, message, filtered DAG object, and statistics
#' @export
remove_leaf_nodes <- function(dag_object, preserve_exposure_outcome = TRUE) {
    if (is.null(dag_object)) {
        return(list(
            success = FALSE,
            message = "Input DAG object is NULL",
            dag = NULL,
            original_nodes = 0,
            original_edges = 0,
            final_nodes = 0,
            final_edges = 0,
            iterations = 0
        ))
    }

    tryCatch({
        # Get original exposure and outcome nodes if we need to preserve them
        exposure_nodes <- character(0)
        outcome_nodes <- character(0)
        if (preserve_exposure_outcome) {
            exposure_nodes <- tryCatch(exposures(dag_object), error = function(e) character(0))
            outcome_nodes <- tryCatch(outcomes(dag_object), error = function(e) character(0))
        }
        protected_nodes <- c(exposure_nodes, outcome_nodes)

        # Extract edges from dagitty
        edges_df <- as.data.frame(dagitty::edges(dag_object))

        # Get all nodes
        all_nodes <- names(dag_object)

        # Create a data frame of nodes
        nodes_df <- data.frame(name = all_nodes, stringsAsFactors = FALSE)

        # Convert to igraph
        ig <- graph_from_data_frame(edges_df[, c("v", "w")],
                                    directed = TRUE,
                                    vertices = nodes_df)

        # Remove self-loops (zero-length arrows)
        ig <- simplify(ig, remove.loops = TRUE, remove.multiple = FALSE)

        original_node_count <- vcount(ig)
        original_edge_count <- ecount(ig)

        cat("Starting leaf removal with", original_node_count, "vertices and", original_edge_count, "edges\n")

        # Iteratively remove nodes with total degree = 1
        iteration <- 0
        repeat {
            iteration <- iteration + 1

            if (vcount(ig) == 0) break

            # Get total degree (in + out)
            total_deg <- degree(ig, mode = "all")

            # Find nodes with total degree = 1
            nodes_to_remove <- which(total_deg == 1)

            # Filter out protected nodes (exposure/outcome) if preservation is enabled
            if (preserve_exposure_outcome && length(protected_nodes) > 0) {
                node_names <- V(ig)$name
                protected_indices <- which(node_names %in% protected_nodes)
                nodes_to_remove <- setdiff(nodes_to_remove, protected_indices)
            }

            if (length(nodes_to_remove) == 0) break

            cat("Iteration", iteration, ": Removing", length(nodes_to_remove), "leaf nodes\n")

            ig <- delete_vertices(ig, nodes_to_remove)
        }

        final_node_count <- vcount(ig)
        final_edge_count <- ecount(ig)

        cat("Final graph has", final_node_count, "vertices and", final_edge_count, "edges\n")

        # Convert back to dagitty
        if (vcount(ig) > 0 && ecount(ig) > 0) {
            edge_list <- as_edgelist(ig)
            dag_edges <- paste(edge_list[,1], "->", edge_list[,2])
            dag_back <- dagitty(paste0("dag {", paste(dag_edges, collapse = "; "), "}"))

            # Restore exposure and outcome annotations if they still exist in the graph
            if (preserve_exposure_outcome) {
                remaining_nodes <- V(ig)$name
                remaining_exposures <- intersect(exposure_nodes, remaining_nodes)
                remaining_outcomes <- intersect(outcome_nodes, remaining_nodes)

                if (length(remaining_exposures) > 0) {
                    for (exp_node in remaining_exposures) {
                        tryCatch({
                            exposures(dag_back) <- exp_node
                        }, error = function(e) {
                            cat("Warning: Could not set exposure for node", exp_node, "\n")
                        })
                    }
                }

                if (length(remaining_outcomes) > 0) {
                    for (out_node in remaining_outcomes) {
                        tryCatch({
                            outcomes(dag_back) <- out_node
                        }, error = function(e) {
                            cat("Warning: Could not set outcome for node", out_node, "\n")
                        })
                    }
                }
            }
        } else {
            dag_back <- dagitty("dag {}")
        }

        removed_nodes <- original_node_count - final_node_count
        removed_edges <- original_edge_count - final_edge_count

        message <- paste0(
            "Leaf removal complete. ",
            "Removed ", removed_nodes, " nodes (", round(removed_nodes/original_node_count*100, 1), "%) ",
            "and ", removed_edges, " edges in ", iteration, " iterations."
        )

        return(list(
            success = TRUE,
            message = message,
            dag = dag_back,
            original_nodes = original_node_count,
            original_edges = original_edge_count,
            final_nodes = final_node_count,
            final_edges = final_edge_count,
            iterations = iteration,
            removed_nodes = removed_nodes,
            removed_edges = removed_edges
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error during leaf removal:", e$message),
            dag = dag_object,  # Return original DAG on error
            original_nodes = length(names(dag_object)),
            original_edges = 0,
            final_nodes = length(names(dag_object)),
            final_edges = 0,
            iterations = 0
        ))
    })
}

#' Filter DAG to Keep Only Nodes on Paths Between Exposure and Outcome
#'
#' This function filters a DAG to keep only nodes that lie on directed paths
#' connecting exposure and outcome nodes. Keeps nodes on ANY of these path types:
#' 1. Forward paths: exposure → ... → outcome
#' 2. Reverse paths: outcome → ... → exposure
#' 3. Common descendants: node → ... → both exposure AND outcome
#' 4. Common ancestors: both exposure AND outcome → ... → node
#'
#' This is more aggressive than leaf removal - nodes not on any connecting path are removed.
#'
#' @param dag_object dagitty object containing the DAG
#' @return List containing success status, message, filtered DAG object, and statistics
#' @export
filter_exposure_outcome_paths <- function(dag_object) {
    if (is.null(dag_object)) {
        return(list(
            success = FALSE,
            message = "Input DAG object is NULL",
            dag = NULL,
            original_nodes = 0,
            original_edges = 0,
            final_nodes = 0,
            final_edges = 0,
            removed_nodes = 0,
            removed_edges = 0,
            kept_nodes = character(0)
        ))
    }

    tryCatch({
        # Get exposure and outcome nodes
        exposure_nodes <- tryCatch(exposures(dag_object), error = function(e) character(0))
        outcome_nodes <- tryCatch(outcomes(dag_object), error = function(e) character(0))

        if (length(exposure_nodes) == 0 || length(outcome_nodes) == 0) {
            return(list(
                success = FALSE,
                message = "DAG must have both exposure and outcome nodes defined",
                dag = dag_object,
                original_nodes = length(names(dag_object)),
                original_edges = nrow(as.data.frame(dagitty::edges(dag_object))),
                final_nodes = length(names(dag_object)),
                final_edges = nrow(as.data.frame(dagitty::edges(dag_object))),
                removed_nodes = 0,
                removed_edges = 0,
                kept_nodes = names(dag_object)
            ))
        }

        # Extract edges from dagitty
        edges_df <- as.data.frame(dagitty::edges(dag_object))

        # Get all nodes
        all_nodes <- names(dag_object)

        # Create a data frame of nodes
        nodes_df <- data.frame(name = all_nodes, stringsAsFactors = FALSE)

        # Convert to igraph
        ig <- graph_from_data_frame(edges_df[, c("v", "w")],
                                    directed = TRUE,
                                    vertices = nodes_df)

        original_node_count <- vcount(ig)
        original_edge_count <- ecount(ig)

        cat("Starting path filtering with", original_node_count, "vertices and", original_edge_count, "edges\n")
        cat("Exposure nodes:", paste(exposure_nodes, collapse = ", "), "\n")
        cat("Outcome nodes:", paste(outcome_nodes, collapse = ", "), "\n")

        # Strategy: Keep nodes on ANY directed path connecting exposure and outcome nodes
        # This includes:
        # 1. Paths from exposure → outcome (forward)
        # 2. Paths from outcome → exposure (reverse)
        # 3. Nodes that reach BOTH exposure and outcome (common descendants)
        # 4. Nodes reachable from BOTH exposure and outcome (common ancestors)

        # Find nodes reachable FROM exposure nodes (forward direction: exposure → X)
        nodes_from_exposure <- character(0)
        for (exp_node in exposure_nodes) {
            if (exp_node %in% V(ig)$name) {
                exp_idx <- which(V(ig)$name == exp_node)
                reachable <- subcomponent(ig, exp_idx, mode = "out")
                nodes_from_exposure <- union(nodes_from_exposure, V(ig)$name[reachable])
            }
        }

        # Find nodes that can reach exposure nodes (backward from exposure: X → exposure)
        nodes_to_exposure <- character(0)
        for (exp_node in exposure_nodes) {
            if (exp_node %in% V(ig)$name) {
                exp_idx <- which(V(ig)$name == exp_node)
                reachable <- subcomponent(ig, exp_idx, mode = "in")
                nodes_to_exposure <- union(nodes_to_exposure, V(ig)$name[reachable])
            }
        }

        # Find nodes reachable FROM outcome nodes (forward from outcome: outcome → X)
        nodes_from_outcome <- character(0)
        for (out_node in outcome_nodes) {
            if (out_node %in% V(ig)$name) {
                out_idx <- which(V(ig)$name == out_node)
                reachable <- subcomponent(ig, out_idx, mode = "out")
                nodes_from_outcome <- union(nodes_from_outcome, V(ig)$name[reachable])
            }
        }

        # Find nodes that can reach outcome nodes (backward to outcome: X → outcome)
        nodes_to_outcome <- character(0)
        for (out_node in outcome_nodes) {
            if (out_node %in% V(ig)$name) {
                out_idx <- which(V(ig)$name == out_node)
                reachable <- subcomponent(ig, out_idx, mode = "in")
                nodes_to_outcome <- union(nodes_to_outcome, V(ig)$name[reachable])
            }
        }

        cat("Nodes reachable from exposure (exposure → X):", length(nodes_from_exposure), "\n")
        cat("Nodes that reach exposure (X → exposure):", length(nodes_to_exposure), "\n")
        cat("Nodes reachable from outcome (outcome → X):", length(nodes_from_outcome), "\n")
        cat("Nodes that reach outcome (X → outcome):", length(nodes_to_outcome), "\n")

        # Keep nodes on ANY of these path types:
        # Type 1: exposure → ... → outcome (forward paths)
        forward_paths <- intersect(nodes_from_exposure, nodes_to_outcome)

        # Type 2: outcome → ... → exposure (reverse paths)
        reverse_paths <- intersect(nodes_from_outcome, nodes_to_exposure)

        # Type 3: X → both exposure AND outcome (common descendants)
        common_descendants <- intersect(nodes_to_exposure, nodes_to_outcome)

        # Type 4: Both exposure AND outcome → X (common ancestors)
        common_ancestors <- intersect(nodes_from_exposure, nodes_from_outcome)

        # Union of all path types
        nodes_on_paths <- union(forward_paths, reverse_paths)
        nodes_on_paths <- union(nodes_on_paths, common_descendants)
        nodes_on_paths <- union(nodes_on_paths, common_ancestors)

        cat("\nPath analysis:\n")
        cat("  Forward paths (exposure → outcome):", length(forward_paths), "nodes\n")
        cat("  Reverse paths (outcome → exposure):", length(reverse_paths), "nodes\n")
        cat("  Common descendants (X → both):", length(common_descendants), "nodes\n")
        cat("  Common ancestors (both → X):", length(common_ancestors), "nodes\n")
        cat("  Total nodes on paths:", length(nodes_on_paths), "nodes\n")

        if (length(nodes_on_paths) == 0) {
            return(list(
                success = FALSE,
                message = "No directed paths found connecting exposure and outcome nodes (checked forward, reverse, and common ancestor/descendant paths)",
                dag = dag_object,
                original_nodes = original_node_count,
                original_edges = original_edge_count,
                final_nodes = original_node_count,
                final_edges = original_edge_count,
                removed_nodes = 0,
                removed_edges = 0,
                kept_nodes = character(0)
            ))
        }

        # Filter the graph to keep only these nodes
        nodes_to_keep_idx <- which(V(ig)$name %in% nodes_on_paths)
        ig_filtered <- induced_subgraph(ig, nodes_to_keep_idx)

        final_node_count <- vcount(ig_filtered)
        final_edge_count <- ecount(ig_filtered)

        cat("Filtered graph has", final_node_count, "vertices and", final_edge_count, "edges\n")

        # Convert back to dagitty
        if (vcount(ig_filtered) > 0 && ecount(ig_filtered) > 0) {
            edge_list <- as_edgelist(ig_filtered)
            dag_edges <- paste(edge_list[,1], "->", edge_list[,2])
            dag_filtered <- dagitty(paste0("dag {", paste(dag_edges, collapse = "; "), "}"))

            # Restore exposure and outcome annotations
            remaining_nodes <- V(ig_filtered)$name
            remaining_exposures <- intersect(exposure_nodes, remaining_nodes)
            remaining_outcomes <- intersect(outcome_nodes, remaining_nodes)

            if (length(remaining_exposures) > 0) {
                for (exp_node in remaining_exposures) {
                    tryCatch({
                        exposures(dag_filtered) <- exp_node
                    }, error = function(e) {
                        cat("Warning: Could not set exposure for node", exp_node, "\n")
                    })
                }
            }

            if (length(remaining_outcomes) > 0) {
                for (out_node in remaining_outcomes) {
                    tryCatch({
                        outcomes(dag_filtered) <- out_node
                    }, error = function(e) {
                        cat("Warning: Could not set outcome for node", out_node, "\n")
                    })
                }
            }
        } else {
            dag_filtered <- dagitty("dag {}")
        }

        removed_nodes <- original_node_count - final_node_count
        removed_edges <- original_edge_count - final_edge_count

        message <- paste0(
            "Path filtering complete. ",
            "Kept ", final_node_count, " nodes (", round(final_node_count/original_node_count*100, 1), "%) ",
            "and ", final_edge_count, " edges. ",
            "Removed ", removed_nodes, " nodes and ", removed_edges, " edges."
        )

        return(list(
            success = TRUE,
            message = message,
            dag = dag_filtered,
            original_nodes = original_node_count,
            original_edges = original_edge_count,
            final_nodes = final_node_count,
            final_edges = final_edge_count,
            removed_nodes = removed_nodes,
            removed_edges = removed_edges,
            kept_nodes = nodes_on_paths
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error during path filtering:", e$message),
            dag = dag_object,
            original_nodes = length(names(dag_object)),
            original_edges = 0,
            final_nodes = length(names(dag_object)),
            final_edges = 0,
            removed_nodes = 0,
            removed_edges = 0,
            kept_nodes = character(0)
        ))
    })
}

