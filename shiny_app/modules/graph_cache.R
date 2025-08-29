# Graph Caching System for Large DAG Performance Optimization
# 
# This module provides intelligent caching for DAG objects and network data
# to avoid expensive reloading and reprocessing of large graphs.

library(digest)

# Global cache environment
.graph_cache <- new.env(parent = emptyenv())

#' Initialize Graph Cache
#' 
#' Sets up the caching system with configurable parameters
#' 
#' @param max_cache_size Maximum number of cached items (default: 10)
#' @param max_memory_mb Maximum memory usage in MB (default: 500)
#' @param cache_dir Directory for persistent cache (default: temp directory)
#' @export
init_graph_cache <- function(max_cache_size = 10, max_memory_mb = 500, cache_dir = NULL) {
    if (is.null(cache_dir)) {
        cache_dir <- file.path(tempdir(), "graph_cache")
    }
    
    if (!dir.exists(cache_dir)) {
        dir.create(cache_dir, recursive = TRUE)
    }
    
    .graph_cache$config <- list(
        max_cache_size = max_cache_size,
        max_memory_mb = max_memory_mb,
        cache_dir = cache_dir,
        enabled = TRUE
    )
    
    .graph_cache$items <- list()
    .graph_cache$access_times <- list()
    .graph_cache$memory_usage <- 0
    
    cat("Graph cache initialized:\n")
    cat("  Max items:", max_cache_size, "\n")
    cat("  Max memory:", max_memory_mb, "MB\n")
    cat("  Cache directory:", cache_dir, "\n")
}

#' Generate Cache Key
#' 
#' Creates a unique cache key based on file path and modification time
#' 
#' @param file_path Path to the graph file
#' @param additional_params Additional parameters to include in key
#' @return String cache key
#' @export
generate_cache_key <- function(file_path, additional_params = NULL) {
    if (!file.exists(file_path)) {
        return(NULL)
    }
    
    # Get file info
    file_info <- file.info(file_path)
    
    # Create key components
    key_components <- list(
        path = normalizePath(file_path),
        size = file_info$size,
        mtime = as.numeric(file_info$mtime),
        additional = additional_params
    )
    
    # Generate hash
    cache_key <- digest::digest(key_components, algo = "md5")
    return(cache_key)
}

#' Check Cache for DAG
#' 
#' Checks if a DAG is already cached and returns it if available
#' 
#' @param file_path Path to the graph file
#' @param additional_params Additional parameters used in processing
#' @return List with success status and cached data if available
#' @export
get_cached_dag <- function(file_path, additional_params = NULL) {
    if (!.graph_cache$config$enabled) {
        return(list(success = FALSE, message = "Cache disabled"))
    }
    
    cache_key <- generate_cache_key(file_path, additional_params)
    if (is.null(cache_key)) {
        return(list(success = FALSE, message = "Could not generate cache key"))
    }
    
    # Check memory cache first
    if (cache_key %in% names(.graph_cache$items)) {
        # Update access time
        .graph_cache$access_times[[cache_key]] <- Sys.time()
        
        cached_item <- .graph_cache$items[[cache_key]]
        cat("Cache HIT (memory):", basename(file_path), "\n")
        
        return(list(
            success = TRUE,
            message = "Retrieved from memory cache",
            data = cached_item$data,
            cache_info = cached_item$info
        ))
    }
    
    # Check persistent cache
    persistent_result <- get_persistent_cache(cache_key)
    if (persistent_result$success) {
        # Load into memory cache
        store_in_memory_cache(cache_key, persistent_result$data, file_path)
        
        cat("Cache HIT (disk):", basename(file_path), "\n")
        return(persistent_result)
    }
    
    return(list(success = FALSE, message = "Not found in cache"))
}

#' Store DAG in Cache
#' 
#' Stores processed DAG data in both memory and persistent cache
#' 
#' @param file_path Path to the original graph file
#' @param dag_data Processed DAG data to cache
#' @param additional_params Additional parameters used in processing
#' @export
store_cached_dag <- function(file_path, dag_data, additional_params = NULL) {
    if (!.graph_cache$config$enabled) {
        return()
    }
    
    cache_key <- generate_cache_key(file_path, additional_params)
    if (is.null(cache_key)) {
        return()
    }
    
    # Store in memory cache
    store_in_memory_cache(cache_key, dag_data, file_path)
    
    # Store in persistent cache
    store_persistent_cache(cache_key, dag_data, file_path)
    
    cat("Cached DAG data:", basename(file_path), "\n")
}

#' Store in Memory Cache
#' 
#' Internal function to store data in memory cache with LRU eviction
#' 
#' @param cache_key Cache key
#' @param data Data to store
#' @param file_path Original file path for metadata
store_in_memory_cache <- function(cache_key, data, file_path) {
    # Estimate memory usage (rough approximation)
    estimated_size_mb <- as.numeric(object.size(data)) / (1024 * 1024)
    
    # Check if we need to evict items
    while (length(.graph_cache$items) >= .graph_cache$config$max_cache_size ||
           (.graph_cache$memory_usage + estimated_size_mb) > .graph_cache$config$max_memory_mb) {
        evict_lru_item()
    }
    
    # Store the item
    .graph_cache$items[[cache_key]] <- list(
        data = data,
        info = list(
            file_path = file_path,
            cached_time = Sys.time(),
            estimated_size_mb = estimated_size_mb
        )
    )
    
    .graph_cache$access_times[[cache_key]] <- Sys.time()
    .graph_cache$memory_usage <- .graph_cache$memory_usage + estimated_size_mb
}

#' Evict LRU Item
#' 
#' Removes the least recently used item from memory cache
evict_lru_item <- function() {
    if (length(.graph_cache$items) == 0) {
        return()
    }
    
    # Find least recently used item
    access_times <- sapply(.graph_cache$access_times, as.numeric)
    lru_key <- names(access_times)[which.min(access_times)]
    
    # Remove from cache
    if (lru_key %in% names(.graph_cache$items)) {
        removed_size <- .graph_cache$items[[lru_key]]$info$estimated_size_mb
        .graph_cache$memory_usage <- .graph_cache$memory_usage - removed_size
        
        rm(list = lru_key, envir = .graph_cache$items)
        rm(list = lru_key, envir = .graph_cache$access_times)
        
        cat("Evicted from cache:", lru_key, "(", round(removed_size, 2), "MB)\n")
    }
}

#' Get Persistent Cache
#' 
#' Retrieves data from persistent disk cache
#' 
#' @param cache_key Cache key
#' @return List with success status and data if available
get_persistent_cache <- function(cache_key) {
    cache_file <- file.path(.graph_cache$config$cache_dir, paste0(cache_key, ".rds"))
    
    if (file.exists(cache_file)) {
        tryCatch({
            cached_data <- readRDS(cache_file)
            return(list(
                success = TRUE,
                message = "Retrieved from persistent cache",
                data = cached_data$data,
                cache_info = cached_data$info
            ))
        }, error = function(e) {
            cat("Error reading persistent cache:", e$message, "\n")
            # Clean up corrupted cache file
            unlink(cache_file)
        })
    }
    
    return(list(success = FALSE, message = "Not found in persistent cache"))
}

#' Store Persistent Cache
#' 
#' Stores data in persistent disk cache
#' 
#' @param cache_key Cache key
#' @param data Data to store
#' @param file_path Original file path for metadata
store_persistent_cache <- function(cache_key, data, file_path) {
    cache_file <- file.path(.graph_cache$config$cache_dir, paste0(cache_key, ".rds"))
    
    tryCatch({
        cache_data <- list(
            data = data,
            info = list(
                file_path = file_path,
                cached_time = Sys.time(),
                cache_key = cache_key
            )
        )
        
        saveRDS(cache_data, cache_file, compress = TRUE)
    }, error = function(e) {
        cat("Error storing persistent cache:", e$message, "\n")
    })
}

#' Clear Cache
#' 
#' Clears all cached data
#' 
#' @param memory_only Whether to clear only memory cache (default: FALSE)
#' @export
clear_cache <- function(memory_only = FALSE) {
    # Clear memory cache
    .graph_cache$items <- list()
    .graph_cache$access_times <- list()
    .graph_cache$memory_usage <- 0
    
    if (!memory_only && !is.null(.graph_cache$config$cache_dir)) {
        # Clear persistent cache
        cache_files <- list.files(.graph_cache$config$cache_dir, pattern = "\\.rds$", full.names = TRUE)
        unlink(cache_files)
        cat("Cleared", length(cache_files), "persistent cache files\n")
    }
    
    cat("Cache cleared\n")
}

#' Get Cache Statistics
#' 
#' Returns information about current cache usage
#' 
#' @return List containing cache statistics
#' @export
get_cache_stats <- function() {
    if (!.graph_cache$config$enabled) {
        return(list(enabled = FALSE))
    }
    
    persistent_files <- 0
    if (!is.null(.graph_cache$config$cache_dir) && dir.exists(.graph_cache$config$cache_dir)) {
        persistent_files <- length(list.files(.graph_cache$config$cache_dir, pattern = "\\.rds$"))
    }
    
    list(
        enabled = TRUE,
        memory_items = length(.graph_cache$items),
        memory_usage_mb = round(.graph_cache$memory_usage, 2),
        persistent_items = persistent_files,
        max_items = .graph_cache$config$max_cache_size,
        max_memory_mb = .graph_cache$config$max_memory_mb,
        cache_dir = .graph_cache$config$cache_dir
    )
}

# Initialize cache environment (minimal setup)
if (length(.graph_cache) == 0) {
    .graph_cache$config <- list(
        max_cache_size = 5,
        max_memory_mb = 100,
        cache_dir = tempdir(),
        enabled = FALSE
    )
    .graph_cache$items <- list()
    .graph_cache$access_times <- list()
    .graph_cache$memory_usage <- 0
    cat("Graph cache environment created (not initialized)\n")
}

#' Cache Causal Assertions
#'
#' Caches causal assertions data with file modification time tracking
#'
#' @param file_path Path to the assertions file
#' @param assertions_data Assertions data to cache
#' @param loading_strategy Strategy used to load the data
#' @param lazy_loader Optional lazy loader function
#' @export
cache_causal_assertions <- function(file_path, assertions_data, loading_strategy = "standard", lazy_loader = NULL) {
    if (!.graph_cache$config$enabled) {
        return()
    }

    cache_key <- paste0("assertions_", generate_cache_key(file_path))

    cache_data <- list(
        assertions = assertions_data,
        loading_strategy = loading_strategy,
        lazy_loader = lazy_loader,
        file_mtime = file.mtime(file_path),
        cached_time = Sys.time()
    )

    # Store in memory cache
    store_in_memory_cache(cache_key, cache_data, file_path)

    # Store in persistent cache (without lazy_loader function)
    persistent_data <- cache_data
    persistent_data$lazy_loader <- NULL  # Functions can't be serialized
    store_persistent_cache(cache_key, persistent_data, file_path)

    cat("Cached causal assertions:", basename(file_path), "(", loading_strategy, "mode )\n")
}

#' Get Cached Causal Assertions
#'
#' Retrieves cached causal assertions if available and up-to-date
#'
#' @param file_path Path to the assertions file
#' @return List with success status and cached data if available
#' @export
get_cached_causal_assertions <- function(file_path) {
    if (!.graph_cache$config$enabled) {
        return(list(success = FALSE, message = "Cache disabled"))
    }

    cache_key <- paste0("assertions_", generate_cache_key(file_path))

    # Check memory cache first
    if (cache_key %in% names(.graph_cache$items)) {
        cached_item <- .graph_cache$items[[cache_key]]

        # Check if file has been modified
        if (cached_item$data$file_mtime == file.mtime(file_path)) {
            # Update access time
            .graph_cache$access_times[[cache_key]] <- Sys.time()

            cat("Cache HIT (memory) for assertions:", basename(file_path), "\n")

            return(list(
                success = TRUE,
                message = "Retrieved from memory cache",
                assertions = cached_item$data$assertions,
                loading_strategy = cached_item$data$loading_strategy,
                lazy_loader = cached_item$data$lazy_loader
            ))
        } else {
            # File has been modified, remove from cache
            clear_assertions_cache(file_path)
        }
    }

    return(list(success = FALSE, message = "Not found in cache"))
}

#' Clear Assertions Cache
#'
#' Clears cached assertions for a specific file
#'
#' @param file_path Path to the assertions file
#' @export
clear_assertions_cache <- function(file_path) {
    cache_key <- paste0("assertions_", generate_cache_key(file_path))

    # Clear from memory cache
    if (cache_key %in% names(.graph_cache$items)) {
        removed_size <- .graph_cache$items[[cache_key]]$info$estimated_size_mb
        .graph_cache$memory_usage <- .graph_cache$memory_usage - removed_size

        rm(list = cache_key, envir = .graph_cache$items)
        rm(list = cache_key, envir = .graph_cache$access_times)

        cat("Cleared assertions cache (memory):", basename(file_path), "\n")
    }

    # Clear from persistent cache
    cache_file <- file.path(.graph_cache$config$cache_dir, paste0(cache_key, ".rds"))
    if (file.exists(cache_file)) {
        unlink(cache_file)
        cat("Cleared assertions cache (disk):", basename(file_path), "\n")
    }
}
