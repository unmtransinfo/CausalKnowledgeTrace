# Optimized Loading System for Causal Assertions
# 
# This module provides optimized loading strategies for causal assertion data
# including lazy loading, streaming, and caching to improve performance.

library(jsonlite)
library(digest)

# Global environment for lazy loading cache
.lazy_cache <- new.env(parent = emptyenv())
.lazy_cache$metadata <- list()
.lazy_cache$full_data <- list()
.lazy_cache$config <- list(
    enabled = TRUE,
    stream_threshold_mb = 100,  # Use streaming for files larger than 100MB (3-hop is 527MB)
    lazy_threshold_mb = 50,     # Use lazy loading for files larger than 50MB
    max_memory_mb = 1000,       # Maximum memory usage for cache (1GB for large graphs)
    cleanup_interval = 300      # Cleanup old cache entries every 5 minutes
)

# Memory management functions
manage_cache_memory <- function() {
    if (!.lazy_cache$config$enabled) return()

    # Calculate current memory usage
    current_size <- sum(sapply(.lazy_cache$full_data, function(x) {
        tryCatch(object.size(x), error = function(e) 0)
    })) / (1024^2)  # Convert to MB

    if (current_size > .lazy_cache$config$max_memory_mb) {
        cat("Cache memory usage:", round(current_size, 1), "MB - cleaning up...\n")

        # Remove oldest entries until under limit
        cache_keys <- names(.lazy_cache$full_data)
        if (length(cache_keys) > 1) {
            # Keep only the most recent entry
            latest_key <- cache_keys[length(cache_keys)]
            for (key in cache_keys[-length(cache_keys)]) {
                rm(list = key, envir = .lazy_cache$full_data)
                if (key %in% names(.lazy_cache$metadata)) {
                    rm(list = key, envir = .lazy_cache$metadata)
                }
            }
            cat("Cleaned cache, kept only latest entry:", latest_key, "\n")
        }
    }
}

#' Load Causal Assertions with Optimization
#'
#' Intelligently loads causal assertions using the most appropriate strategy
#' based on file size and usage patterns.
#'
#' @param filename Path to the causal assertions JSON file
#' @param k_hops K-hops parameter for file matching
#' @param search_dirs Vector of directories to search
#' @param force_full_load Force loading of complete data (default: FALSE)
#' @return List containing success status, message, and assertions data
#' @export
load_causal_assertions_optimized <- function(filename = NULL, k_hops = NULL, 
                                           search_dirs = c("../graph_creation/result", "../graph_creation/output"),
                                           force_full_load = FALSE) {
    
    # Find the appropriate file
    if (is.null(filename)) {
        if (is.null(k_hops)) {
            return(list(
                success = FALSE,
                message = "Either filename or k_hops must be provided",
                assertions = list()
            ))
        }
        
        # Look for causal_assertions_{k_hops}.json
        target_filename <- paste0("causal_assertions_", k_hops, ".json")
        
        for (dir in search_dirs) {
            potential_path <- file.path(dir, target_filename)
            if (file.exists(potential_path)) {
                filename <- potential_path
                break
            }
        }
        
        if (is.null(filename)) {
            return(list(
                success = FALSE,
                message = paste("Could not find", target_filename, "in search directories"),
                assertions = list()
            ))
        }
    }
    
    if (!file.exists(filename)) {
        return(list(
            success = FALSE,
            message = paste("File not found:", filename),
            assertions = list()
        ))
    }
    
    # Get file size to determine loading strategy
    file_size_mb <- file.size(filename) / (1024 * 1024)
    cat("File size:", round(file_size_mb, 2), "MB\n")
    
    # Generate cache key
    cache_key <- generate_file_cache_key(filename)

    # Check graph cache system first (Phase 2 integration)
    if (exists("get_cached_causal_assertions")) {
        cached_result <- get_cached_causal_assertions(filename)
        if (cached_result$success) {
            cat("Using graph cache system for", basename(filename), "\n")
            return(list(
                success = TRUE,
                message = cached_result$message,
                assertions = cached_result$assertions,
                filename = filename,
                loading_strategy = cached_result$loading_strategy,
                lazy_loader = cached_result$lazy_loader
            ))
        }
    }

    # Check if we have cached data in lazy cache
    if (cache_key %in% names(.lazy_cache$metadata)) {
        cached_metadata <- .lazy_cache$metadata[[cache_key]]
        
        # Check if file has been modified
        if (cached_metadata$file_mtime == file.mtime(filename)) {
            cat("Using cached metadata for", basename(filename), "\n")
            
            if (force_full_load && cache_key %in% names(.lazy_cache$full_data)) {
                return(list(
                    success = TRUE,
                    message = paste("Loaded", length(.lazy_cache$full_data[[cache_key]]), "cached assertions"),
                    assertions = .lazy_cache$full_data[[cache_key]],
                    filename = filename,
                    loading_strategy = "cached_full"
                ))
            } else if (!force_full_load) {
                return(list(
                    success = TRUE,
                    message = paste("Loaded metadata for", cached_metadata$assertion_count, "assertions"),
                    assertions = cached_metadata$metadata,
                    filename = filename,
                    loading_strategy = "cached_lazy",
                    lazy_loader = create_lazy_loader(filename, cache_key)
                ))
            }
        } else {
            # File has been modified, clear cache
            clear_file_cache(cache_key)
        }
    }
    
    # Phase 2: Check for binary files first (fastest loading)
    if (!is.null(k_hops) && !force_full_load) {
        binary_result <- try_load_binary_files(k_hops, dirname(filename))
        if (binary_result$success) {
            return(binary_result)
        }
    }

    # Determine loading strategy based on file size and force_full_load
    if (force_full_load || file_size_mb <= .lazy_cache$config$lazy_threshold_mb) {
        return(load_full_assertions(filename, cache_key))
    } else if (file_size_mb <= .lazy_cache$config$stream_threshold_mb) {
        return(load_lazy_assertions(filename, cache_key))
    } else {
        # For very large files (like 3-hop causal assertions), use streaming
        cat("Very large file detected (", round(file_size_mb, 1), "MB) - using streaming strategy\n")
        return(load_streaming_assertions(filename, cache_key))
    }
}

#' Load Full Assertions Data
#'
#' Loads complete causal assertions data into memory
#'
#' @param filename Path to JSON file
#' @param cache_key Cache key for storing data
#' @return List with loaded data
load_full_assertions <- function(filename, cache_key) {
    tryCatch({
        cat("Loading full assertions data...\n")
        start_time <- Sys.time()
        
        assertions_data <- jsonlite::fromJSON(filename, simplifyDataFrame = FALSE)
        
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty causal assertions data",
                assertions = list()
            ))
        }
        
        # Cache the full data
        .lazy_cache$full_data[[cache_key]] <- assertions_data
        .lazy_cache$metadata[[cache_key]] <- list(
            metadata = extract_metadata(assertions_data),
            assertion_count = length(assertions_data),
            file_mtime = file.mtime(filename),
            cached_time = Sys.time()
        )

        # Manage memory usage
        manage_cache_memory()
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        cat("Loaded", length(assertions_data), "assertions in", round(load_time, 2), "seconds\n")

        result <- list(
            success = TRUE,
            message = paste("Successfully loaded", length(assertions_data), "causal assertions"),
            assertions = assertions_data,
            filename = filename,
            loading_strategy = "full",
            load_time_seconds = load_time
        )

        # Cache the result using graph cache system
        if (exists("cache_causal_assertions")) {
            cache_causal_assertions(filename, assertions_data, "full", NULL)
        }

        return(result)
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading full assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Load Lazy Assertions (Metadata Only)
#'
#' Loads only metadata for assertions, with lazy loading capability
#'
#' @param filename Path to JSON file
#' @param cache_key Cache key for storing data
#' @return List with metadata and lazy loader
load_lazy_assertions <- function(filename, cache_key) {
    tryCatch({
        cat("Loading assertions metadata (lazy mode)...\n")
        start_time <- Sys.time()
        
        # Load and extract metadata only
        assertions_data <- jsonlite::fromJSON(filename, simplifyDataFrame = FALSE)
        
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty causal assertions data",
                assertions = list()
            ))
        }
        
        # Extract lightweight metadata
        metadata <- extract_metadata(assertions_data)
        
        # Cache metadata and full data separately
        .lazy_cache$metadata[[cache_key]] <- list(
            metadata = metadata,
            assertion_count = length(assertions_data),
            file_mtime = file.mtime(filename),
            cached_time = Sys.time()
        )
        .lazy_cache$full_data[[cache_key]] <- assertions_data

        # Manage memory usage
        manage_cache_memory()

        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        cat("Loaded metadata for", length(metadata), "assertions in", round(load_time, 2), "seconds\n")

        lazy_loader <- create_lazy_loader(filename, cache_key)

        result <- list(
            success = TRUE,
            message = paste("Loaded metadata for", length(metadata), "assertions (lazy mode)"),
            assertions = metadata,
            filename = filename,
            loading_strategy = "lazy",
            load_time_seconds = load_time,
            lazy_loader = lazy_loader
        )

        # Cache the result using graph cache system
        if (exists("cache_causal_assertions")) {
            cache_causal_assertions(filename, metadata, "lazy", lazy_loader)
        }

        return(result)
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading lazy assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Load Streaming Assertions
#'
#' Loads assertions using streaming for very large files
#'
#' @param filename Path to JSON file
#' @param cache_key Cache key for storing data
#' @return List with streamed data
load_streaming_assertions <- function(filename, cache_key) {
    tryCatch({
        cat("Loading assertions using streaming (large file mode)...\n")
        start_time <- Sys.time()
        
        # For very large files, we'll still need to load into memory
        # but we can process in chunks if needed
        # This is a placeholder for future streaming implementation
        return(load_lazy_assertions(filename, cache_key))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading streaming assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Extract Metadata from Assertions
#'
#' Extracts lightweight metadata from full assertions data
#'
#' @param assertions_data Full assertions data
#' @return List of metadata objects
extract_metadata <- function(assertions_data) {
    lapply(assertions_data, function(assertion) {
        # Extract PMID list from pmid_data keys (optimized structure)
        pmid_list <- if (!is.null(assertion$pmid_data)) {
            names(assertion$pmid_data)
        } else if (!is.null(assertion$pmid_list)) {
            assertion$pmid_list  # Backward compatibility
        } else {
            character(0)
        }

        list(
            subject_name = assertion$subject_name,
            subject_cui = assertion$subject_cui,
            predicate = assertion$predicate,
            object_name = assertion$object_name,
            object_cui = assertion$object_cui,
            evidence_count = assertion$evidence_count,
            relationship_degree = assertion$relationship_degree,
            pmid_list = pmid_list,
            has_sentence_data = !is.null(assertion$pmid_data) && length(assertion$pmid_data) > 0
        )
    })
}

#' Create Lazy Loader Function
#'
#' Creates a function that can load full data for specific assertions on demand
#'
#' @param filename Original filename
#' @param cache_key Cache key
#' @return Function for lazy loading
create_lazy_loader <- function(filename, cache_key) {
    function(subject_name = NULL, object_name = NULL, pmid = NULL) {
        if (cache_key %in% names(.lazy_cache$full_data)) {
            full_data <- .lazy_cache$full_data[[cache_key]]
            
            # Filter data based on parameters
            if (!is.null(subject_name) && !is.null(object_name)) {
                # Find specific assertion
                for (assertion in full_data) {
                    if (assertion$subject_name == subject_name && assertion$object_name == object_name) {
                        return(assertion)
                    }
                }
                return(NULL)
            } else {
                # Return all full data
                return(full_data)
            }
        } else {
            # Load from file if not cached
            result <- load_full_assertions(filename, cache_key)
            if (result$success) {
                return(result$assertions)
            } else {
                return(NULL)
            }
        }
    }
}

#' Generate File Cache Key
#'
#' Generates a unique cache key for a file
#'
#' @param filename Path to file
#' @return Cache key string
generate_file_cache_key <- function(filename) {
    file_info <- file.info(filename)
    key_data <- paste(filename, file_info$size, file_info$mtime, sep = "_")
    return(digest(key_data, algo = "md5"))
}

#' Clear File Cache
#'
#' Clears cached data for a specific file
#'
#' @param cache_key Cache key to clear
clear_file_cache <- function(cache_key) {
    if (cache_key %in% names(.lazy_cache$metadata)) {
        rm(list = cache_key, envir = .lazy_cache$metadata)
    }
    if (cache_key %in% names(.lazy_cache$full_data)) {
        rm(list = cache_key, envir = .lazy_cache$full_data)
    }
    cat("Cleared cache for key:", cache_key, "\n")
}

#' Get Cache Statistics
#'
#' Returns information about current cache usage
#'
#' @return List with cache statistics
get_cache_stats <- function() {
    list(
        metadata_cached = length(.lazy_cache$metadata),
        full_data_cached = length(.lazy_cache$full_data),
        config = .lazy_cache$config
    )
}

# DISABLED: Fast Preview / Separated Files Loading
# This function has been disabled as the Fast Preview loading strategy has been removed
#
# #' Try Load Separated Files
# #'
# #' Attempts to load separated lightweight and sentence files
# #'
# #' @param k_hops K-hops parameter
# #' @param search_dir Directory to search in
# #' @return List with loading result
# try_load_separated_files <- function(k_hops, search_dir) {
#     # Source sentence storage module if not loaded
#     if (!exists("check_for_separated_files")) {
#         tryCatch({
#             source("modules/sentence_storage.R")
#         }, error = function(e) {
#             return(list(success = FALSE, message = "Could not load sentence storage module"))
#         })
#     }
#
#     # Check for separated files
#     separated_files <- check_for_separated_files(k_hops, c(search_dir))
#
#     if (!separated_files$found) {
#         return(list(success = FALSE, message = "Separated files not found"))
#     }
#
#     tryCatch({
#         cat("Loading separated files (optimized mode)...\n")
#         start_time <- Sys.time()
#
#         # Load lightweight assertions
#         lightweight_result <- load_lightweight_assertions(separated_files$lightweight_file)
#
#         if (!lightweight_result$success) {
#             return(lightweight_result)
#         }
#
#         # Create sentence loader
#         sentence_loader <- create_sentence_loader(separated_files$sentences_file)
#
#         # Create enhanced lazy loader that uses sentence loader
#         enhanced_lazy_loader <- function(subject_name = NULL, object_name = NULL, pmid = NULL) {
#             if (!is.null(subject_name) && !is.null(object_name)) {
#                 # Find the lightweight assertion
#                 for (assertion in lightweight_result$assertions) {
#                     if (assertion$subject_name == subject_name && assertion$object_name == object_name) {
#                         # Add sentence data
#                         pmid_data <- sentence_loader(subject_name, object_name)
#                         assertion$pmid_data <- pmid_data
#                         return(assertion)
#                     }
#                 }
#                 return(NULL)
#             } else {
#                 # Return all lightweight data
#                 return(lightweight_result$assertions)
#             }
#         }
#
#         load_time <- as.numeric(Sys.time() - start_time, units = "secs")
#
#         # Get file size statistics
#         lightweight_size <- file.size(separated_files$lightweight_file) / (1024 * 1024)
#
#         cat("Loaded separated files in", round(load_time, 2), "seconds\n")
#         cat("Lightweight file size:", round(lightweight_size, 2), "MB\n")
#
#         return(list(
#             success = TRUE,
#             message = paste("Loaded", length(lightweight_result$assertions), "assertions from separated files"),
#             assertions = lightweight_result$assertions,
#             loading_strategy = "separated",
#             load_time_seconds = load_time,
#             lazy_loader = enhanced_lazy_loader,
#             sentence_loader = sentence_loader,
#             lightweight_file = separated_files$lightweight_file,
#             sentences_file = separated_files$sentences_file
#         ))
#
#     }, error = function(e) {
#         return(list(
#             success = FALSE,
#             message = paste("Error loading separated files:", e$message)
#         ))
#     })
# }

# Function disabled - Fast Preview loading strategy has been removed
try_load_separated_files <- function(k_hops, search_dir) {
    return(list(success = FALSE, message = "Separated files loading has been disabled"))
}

#' Try Load Binary Files
#'
#' Attempts to load binary RDS files for fastest performance
#'
#' @param k_hops K-hops parameter
#' @param search_dir Directory to search in
#' @return List with loading result
try_load_binary_files <- function(k_hops, search_dir) {
    # Source binary storage module if not loaded
    if (!exists("check_for_binary_files")) {
        tryCatch({
            source("modules/binary_storage.R")
        }, error = function(e) {
            return(list(success = FALSE, message = "Could not load binary storage module"))
        })
    }

    # Check for binary files
    binary_files <- check_for_binary_files(k_hops, c(search_dir))

    if (!binary_files$found) {
        return(list(success = FALSE, message = "Binary files not found"))
    }

    tryCatch({
        cat("Loading binary file (fastest mode)...\n")
        start_time <- Sys.time()

        # Load binary assertions
        binary_result <- load_binary_assertions(binary_files$binary_file)

        if (!binary_result$success) {
            return(binary_result)
        }

        # Check for and load edge index
        edge_index <- NULL
        if (exists("check_for_index_files")) {
            index_files <- check_for_index_files(k_hops, c(search_dir))
            if (index_files$found) {
                index_result <- load_edge_index(index_files$index_file)
                if (index_result$success) {
                    edge_index <- index_result
                    cat("Loaded edge index for O(1) lookups\n")
                }
            }
        }

        # Create enhanced lazy loader with binary data and optional indexing
        enhanced_lazy_loader <- function(subject_name = NULL, object_name = NULL, pmid = NULL) {
            if (!is.null(subject_name) && !is.null(object_name)) {
                # Use indexed lookup if available
                if (!is.null(edge_index)) {
                    lookup_result <- fast_edge_lookup(subject_name, object_name, edge_index$edge_index, binary_result$assertions)
                    if (lookup_result$found) {
                        # Return full assertion with sentence data
                        assertion_index <- lookup_result$assertion_index
                        if (assertion_index <= length(binary_result$assertions)) {
                            return(binary_result$assertions[[assertion_index]])
                        }
                    }
                }

                # Fallback to linear search
                for (assertion in binary_result$assertions) {
                    if (assertion$subject_name == subject_name && assertion$object_name == object_name) {
                        return(assertion)
                    }
                }
                return(NULL)
            } else {
                # Return all binary data
                return(binary_result$assertions)
            }
        }

        load_time <- as.numeric(Sys.time() - start_time, units = "secs")

        cat("Loaded binary file in", round(load_time, 2), "seconds\n")
        cat("Binary file size:", binary_result$file_size_mb, "MB\n")
        if (!is.null(edge_index)) {
            cat("Using indexed access for O(1) edge lookups\n")
        }

        return(list(
            success = TRUE,
            message = paste("Loaded", length(binary_result$assertions), "assertions from binary file"),
            assertions = binary_result$assertions,
            loading_strategy = if (!is.null(edge_index)) "binary_indexed" else "binary",
            load_time_seconds = load_time,
            lazy_loader = enhanced_lazy_loader,
            edge_index = edge_index,
            binary_file = binary_files$binary_file,
            file_size_mb = binary_result$file_size_mb
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading binary files:", e$message)
        ))
    })
}
