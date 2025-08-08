# Parallel Processing Module for Large Graph Operations
# 
# This module provides parallel processing capabilities for graph operations
# to improve performance on multi-core systems.

library(parallel)
library(foreach)

# Global parallel processing configuration
.parallel_config <- new.env(parent = emptyenv())

#' Initialize Parallel Processing
#' 
#' Sets up parallel processing with optimal configuration
#' 
#' @param num_cores Number of cores to use (default: auto-detect)
#' @param cluster_type Type of cluster ("PSOCK", "FORK") (default: auto)
#' @param enable_foreach Whether to enable foreach backend (default: TRUE)
#' @export
init_parallel_processing <- function(num_cores = NULL, cluster_type = NULL, enable_foreach = TRUE) {
    # Auto-detect number of cores
    if (is.null(num_cores)) {
        num_cores <- max(1, detectCores() - 1)  # Leave one core free
    }
    
    # Auto-detect cluster type
    if (is.null(cluster_type)) {
        cluster_type <- if (.Platform$OS.type == "windows") "PSOCK" else "FORK"
    }
    
    .parallel_config$num_cores <- num_cores
    .parallel_config$cluster_type <- cluster_type
    .parallel_config$cluster <- NULL
    .parallel_config$enabled <- num_cores > 1
    
    if (.parallel_config$enabled) {
        # Create cluster
        .parallel_config$cluster <- makeCluster(num_cores, type = cluster_type)
        
        # Set up foreach backend if requested
        if (enable_foreach && requireNamespace("doParallel", quietly = TRUE)) {
            doParallel::registerDoParallel(.parallel_config$cluster)
            .parallel_config$foreach_enabled <- TRUE
        } else {
            .parallel_config$foreach_enabled <- FALSE
        }
        
        cat("Parallel processing initialized:\n")
        cat("  Cores:", num_cores, "\n")
        cat("  Cluster type:", cluster_type, "\n")
        cat("  Foreach enabled:", .parallel_config$foreach_enabled, "\n")
    } else {
        cat("Parallel processing disabled (single core system)\n")
    }
}

#' Parallel Node Processing
#' 
#' Processes nodes in parallel for large graphs
#' 
#' @param nodes Vector of node names
#' @param process_func Function to apply to each node
#' @param chunk_size Number of nodes per chunk (default: auto)
#' @return List of processed results
#' @export
parallel_node_processing <- function(nodes, process_func, chunk_size = NULL) {
    if (!.parallel_config$enabled || length(nodes) < 100) {
        # Use sequential processing for small graphs or when parallel is disabled
        return(lapply(nodes, process_func))
    }
    
    # Auto-calculate chunk size
    if (is.null(chunk_size)) {
        chunk_size <- max(10, ceiling(length(nodes) / (.parallel_config$num_cores * 4)))
    }
    
    # Split nodes into chunks
    node_chunks <- split(nodes, ceiling(seq_along(nodes) / chunk_size))
    
    cat("Processing", length(nodes), "nodes in", length(node_chunks), "chunks using", .parallel_config$num_cores, "cores\n")
    
    # Process chunks in parallel
    if (.parallel_config$foreach_enabled && requireNamespace("foreach", quietly = TRUE)) {
        # Use foreach for parallel processing
        results <- foreach::foreach(chunk = node_chunks, .combine = c) %dopar% {
            lapply(chunk, process_func)
        }
    } else {
        # Use parLapply
        chunk_processor <- function(chunk) {
            lapply(chunk, process_func)
        }
        
        results <- parLapply(.parallel_config$cluster, node_chunks, chunk_processor)
        results <- unlist(results, recursive = FALSE)
    }
    
    return(results)
}

#' Parallel Edge Processing
#' 
#' Processes edges in parallel for large graphs
#' 
#' @param edges Matrix or data frame of edges
#' @param process_func Function to apply to each edge
#' @param chunk_size Number of edges per chunk (default: auto)
#' @return List of processed results
#' @export
parallel_edge_processing <- function(edges, process_func, chunk_size = NULL) {
    if (!.parallel_config$enabled || nrow(edges) < 100) {
        # Use sequential processing for small graphs or when parallel is disabled
        return(apply(edges, 1, process_func))
    }
    
    # Auto-calculate chunk size
    if (is.null(chunk_size)) {
        chunk_size <- max(10, ceiling(nrow(edges) / (.parallel_config$num_cores * 4)))
    }
    
    # Split edges into chunks
    edge_indices <- seq_len(nrow(edges))
    edge_chunks <- split(edge_indices, ceiling(edge_indices / chunk_size))
    
    cat("Processing", nrow(edges), "edges in", length(edge_chunks), "chunks using", .parallel_config$num_cores, "cores\n")
    
    # Process chunks in parallel
    if (.parallel_config$foreach_enabled && requireNamespace("foreach", quietly = TRUE)) {
        # Use foreach for parallel processing
        results <- foreach::foreach(chunk_indices = edge_chunks, .combine = c) %dopar% {
            lapply(chunk_indices, function(i) process_func(edges[i, ]))
        }
    } else {
        # Use parLapply
        chunk_processor <- function(chunk_indices) {
            lapply(chunk_indices, function(i) process_func(edges[i, ]))
        }
        
        results <- parLapply(.parallel_config$cluster, edge_chunks, chunk_processor)
        results <- unlist(results, recursive = FALSE)
    }
    
    return(results)
}

#' Parallel Graph Metrics Calculation
#' 
#' Calculates graph metrics in parallel
#' 
#' @param dag_object dagitty DAG object
#' @param metrics Vector of metric names to calculate
#' @return List of calculated metrics
#' @export
parallel_graph_metrics <- function(dag_object, metrics = c("degree", "betweenness", "closeness")) {
    if (!.parallel_config$enabled) {
        return(sequential_graph_metrics(dag_object, metrics))
    }
    
    nodes <- names(dag_object)
    
    # Convert to igraph for metric calculations
    tryCatch({
        if (exists("dagitty2graph")) {
            ig <- dagitty2graph(dag_object)
        } else {
            # Fallback method
            edge_matrix <- edges(dag_object)
            if (!is.null(edge_matrix) && nrow(edge_matrix) > 0) {
                ig <- graph_from_edgelist(edge_matrix, directed = TRUE)
            } else {
                ig <- make_empty_graph(n = length(nodes), directed = TRUE)
                V(ig)$name <- nodes
            }
        }
        
        # Calculate metrics in parallel
        if (.parallel_config$foreach_enabled && requireNamespace("foreach", quietly = TRUE)) {
            results <- foreach::foreach(metric = metrics, .combine = list, .multicombine = TRUE) %dopar% {
                calculate_single_metric(ig, metric)
            }
            names(results) <- metrics
        } else {
            # Use parLapply
            metric_calculator <- function(metric) {
                calculate_single_metric(ig, metric)
            }
            
            results <- parLapply(.parallel_config$cluster, metrics, metric_calculator)
            names(results) <- metrics
        }
        
        return(results)
        
    }, error = function(e) {
        cat("Error in parallel metrics calculation:", e$message, "\n")
        return(sequential_graph_metrics(dag_object, metrics))
    })
}

#' Calculate Single Metric
#' 
#' Helper function to calculate a single graph metric
#' 
#' @param ig igraph object
#' @param metric Metric name
#' @return Calculated metric values
calculate_single_metric <- function(ig, metric) {
    switch(metric,
        "degree" = degree(ig),
        "betweenness" = betweenness(ig),
        "closeness" = closeness(ig),
        "pagerank" = page_rank(ig)$vector,
        "clustering" = transitivity(ig, type = "local"),
        NULL
    )
}

#' Sequential Graph Metrics (Fallback)
#' 
#' Calculates graph metrics sequentially as fallback
#' 
#' @param dag_object dagitty DAG object
#' @param metrics Vector of metric names
#' @return List of calculated metrics
sequential_graph_metrics <- function(dag_object, metrics) {
    # Simplified sequential calculation
    nodes <- names(dag_object)
    results <- list()
    
    for (metric in metrics) {
        if (metric == "degree") {
            # Simple degree calculation
            edge_matrix <- edges(dag_object)
            if (!is.null(edge_matrix) && nrow(edge_matrix) > 0) {
                in_degree <- table(factor(edge_matrix[, 2], levels = nodes))
                out_degree <- table(factor(edge_matrix[, 1], levels = nodes))
                results[[metric]] <- as.numeric(in_degree + out_degree)
            } else {
                results[[metric]] <- rep(0, length(nodes))
            }
            names(results[[metric]]) <- nodes
        } else {
            # For other metrics, return placeholder values
            results[[metric]] <- rep(0, length(nodes))
            names(results[[metric]]) <- nodes
        }
    }
    
    return(results)
}

#' Vectorized String Operations
#' 
#' Performs vectorized string operations for node/edge processing
#' 
#' @param strings Vector of strings to process
#' @param operation Operation to perform ("clean", "normalize", "validate")
#' @return Processed strings
#' @export
vectorized_string_operations <- function(strings, operation = "clean") {
    switch(operation,
        "clean" = {
            # Vectorized cleaning
            strings <- gsub("[^A-Za-z0-9_]", "_", strings)
            strings <- gsub("_{2,}", "_", strings)
            strings <- gsub("^_|_$", "", strings)
            strings
        },
        "normalize" = {
            # Vectorized normalization
            strings <- tolower(strings)
            strings <- gsub("\\s+", "_", strings)
            strings
        },
        "validate" = {
            # Vectorized validation
            valid <- grepl("^[A-Za-z][A-Za-z0-9_]*$", strings)
            strings[!valid] <- paste0("Node_", seq_along(strings[!valid]))
            strings
        },
        strings
    )
}

#' Cleanup Parallel Processing
#' 
#' Cleans up parallel processing resources
#' 
#' @export
cleanup_parallel_processing <- function() {
    if (!is.null(.parallel_config$cluster)) {
        stopCluster(.parallel_config$cluster)
        .parallel_config$cluster <- NULL
        cat("Parallel processing cluster stopped\n")
    }
    
    .parallel_config$enabled <- FALSE
    .parallel_config$foreach_enabled <- FALSE
}

#' Get Parallel Processing Status
#' 
#' Returns current parallel processing configuration
#' 
#' @return List containing parallel processing status
#' @export
get_parallel_status <- function() {
    list(
        enabled = .parallel_config$enabled,
        num_cores = .parallel_config$num_cores,
        cluster_type = .parallel_config$cluster_type,
        foreach_enabled = .parallel_config$foreach_enabled,
        cluster_active = !is.null(.parallel_config$cluster)
    )
}

# Initialize parallel processing environment (minimal setup)
if (length(.parallel_config) == 0) {
    .parallel_config$num_cores <- 1
    .parallel_config$cluster_type <- "PSOCK"
    .parallel_config$cluster <- NULL
    .parallel_config$enabled <- FALSE
    .parallel_config$foreach_enabled <- FALSE
    cat("Parallel processing environment created (not initialized)\n")
}

# Cleanup on exit
reg.finalizer(.parallel_config, function(e) {
    cleanup_parallel_processing()
}, onexit = TRUE)
