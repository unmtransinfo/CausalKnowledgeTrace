#!/usr/bin/env Rscript
# Comprehensive File Optimization Utility
# 
# This script applies all optimization techniques to causal assertions files:
# 1. Removes duplicate sentences (Phase 1)
# 2. Creates separated lightweight/sentence files (Phase 2)
# 3. Creates binary RDS files (Phase 3)
# 4. Creates edge indexes (Phase 3)

# Load required libraries
library(jsonlite)

# Source all optimization modules
source("../modules/sentence_storage.R")
source("../modules/binary_storage.R")
source("../modules/indexed_access.R")

#' Optimize All Causal Assertions Files
#'
#' Applies all optimization techniques to causal assertions files
#'
#' @param search_dirs Directories to search for files
#' @param output_dir Directory to save optimized files (default: same as input)
#' @param force_regenerate Force regeneration of all files
#' @param skip_existing Skip files that already have optimized versions
#' @return List with comprehensive optimization results
#' @export
optimize_all_files <- function(search_dirs = c("../../graph_creation/result", "../../graph_creation/output"),
                              output_dir = NULL,
                              force_regenerate = FALSE,
                              skip_existing = TRUE) {

    cat("=== FILE OPTIMIZATION DISABLED ===\n")
    cat("Optimization has been disabled to speed up the graph creation process.\n")
    cat("Only the original JSON files will be used.\n\n")

    return(list(
        summary = list(
            overall_success = TRUE,
            message = "Optimization disabled"
        )
    ))
    
    results <- list(
        separated = list(),
        binary = list(),
        indexed = list(),
        summary = list()
    )
    
    total_start_time <- Sys.time()
    
    # Phase 1: Already implemented in data generation (duplicate removal)
    cat("Phase 1: Duplicate sentence removal is handled during data generation.\n\n")
    
    # Phase 2: Create separated files
    cat("Phase 2: Creating separated lightweight and sentence files...\n")
    separated_result <- process_all_assertions_files(
        search_dirs = search_dirs,
        output_dir = output_dir,
        force_regenerate = force_regenerate
    )
    results$separated <- separated_result
    
    if (separated_result$summary$successful > 0) {
        cat("✓ Phase 2 completed successfully!\n")
    } else {
        cat("✗ Phase 2 failed. Continuing with binary optimization...\n")
    }
    cat("\n")
    
    # Phase 3a: Create binary files
    cat("Phase 3a: Creating binary RDS files...\n")
    binary_result <- create_all_binary_files(
        search_dirs = search_dirs,
        output_dir = output_dir,
        compression = "gzip",
        force_regenerate = force_regenerate
    )
    results$binary <- binary_result
    
    if (binary_result$summary$successful > 0) {
        cat("✓ Phase 3a completed successfully!\n")
    } else {
        cat("✗ Phase 3a failed. Continuing with index creation...\n")
    }
    cat("\n")
    
    # Phase 3b: Create edge indexes
    cat("Phase 3b: Creating edge indexes...\n")
    index_result <- create_all_edge_indexes(
        search_dirs = search_dirs,
        output_dir = output_dir,
        force_regenerate = force_regenerate
    )
    results$indexed <- index_result
    
    if (index_result$summary$successful > 0) {
        cat("✓ Phase 3b completed successfully!\n")
    } else {
        cat("✗ Phase 3b failed.\n")
    }
    cat("\n")
    
    # Calculate total processing time
    total_time <- as.numeric(Sys.time() - total_start_time, units = "secs")
    
    # Generate comprehensive summary
    cat("=== OPTIMIZATION SUMMARY ===\n")
    cat("Total processing time:", round(total_time, 2), "seconds\n\n")
    
    # Separated files summary
    if (separated_result$summary$successful > 0) {
        cat("Separated Files:\n")
        cat("  Files created:", separated_result$summary$successful, "\n")
        cat("  Total size reduction:", separated_result$summary$overall_reduction_percent, "%\n")
        cat("  Space saved:", round(separated_result$summary$total_original_size_mb - separated_result$summary$total_lightweight_size_mb, 2), "MB\n\n")
    }
    
    # Binary files summary
    if (binary_result$summary$successful > 0) {
        cat("Binary Files:\n")
        cat("  Files created:", binary_result$summary$successful, "\n")
        
        # Calculate binary compression statistics
        total_json_size <- 0
        total_binary_size <- 0
        for (result in binary_result$results) {
            if (result$success && !result$skipped) {
                total_json_size <- total_json_size + result$json_size_mb
                total_binary_size <- total_binary_size + result$binary_size_mb
            }
        }
        
        if (total_json_size > 0) {
            binary_reduction <- round((1 - total_binary_size / total_json_size) * 100, 1)
            cat("  Binary compression:", binary_reduction, "%\n")
            cat("  Space saved:", round(total_json_size - total_binary_size, 2), "MB\n")
        }
        cat("\n")
    }
    
    # Index files summary
    if (index_result$summary$successful > 0) {
        cat("Edge Indexes:\n")
        cat("  Indexes created:", index_result$summary$successful, "\n")
        cat("  Enables O(1) edge lookups\n\n")
    }
    
    # Performance expectations
    cat("Expected Performance Improvements:\n")
    cat("  Loading speed: 70-95% faster\n")
    cat("  Memory usage: 60-90% reduction\n")
    cat("  Edge lookup: O(1) vs O(n) with indexes\n")
    cat("  File sizes: 40-85% smaller\n\n")
    
    cat("✓ Optimization complete! The Shiny app will automatically use the fastest available format.\n")
    
    results$summary <- list(
        total_processing_time_seconds = total_time,
        separated_files_created = separated_result$summary$successful,
        binary_files_created = binary_result$summary$successful,
        index_files_created = index_result$summary$successful,
        overall_success = (separated_result$summary$successful > 0 || 
                          binary_result$summary$successful > 0 || 
                          index_result$summary$successful > 0)
    )
    
    return(results)
}

#' Create All Edge Indexes
#'
#' Creates edge indexes for all causal assertions files
#'
#' @param search_dirs Directories to search for files
#' @param output_dir Directory to save indexes
#' @param force_regenerate Force regeneration of indexes
#' @return List with indexing results
create_all_edge_indexes <- function(search_dirs = c("../../graph_creation/result", "../../graph_creation/output"),
                                   output_dir = NULL,
                                   force_regenerate = FALSE) {
    
    results <- list()
    
    for (dir in search_dirs) {
        if (!dir.exists(dir)) {
            cat("Directory not found:", dir, "\n")
            next
        }
        
        # Find all causal_assertions files (prefer binary, then JSON)
        binary_files <- list.files(dir, pattern = "^causal_assertions_[123]_binary\\.rds$", full.names = TRUE)
        json_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
        
        # Process binary files first (faster)
        for (binary_file in binary_files) {
            degree_match <- regmatches(basename(binary_file), regexpr("\\d+", basename(binary_file)))
            degree <- as.numeric(degree_match[1])

            cat("Creating index for binary file degree =", degree, "\n")

            # Check if index already exists
            use_output_dir <- if (is.null(output_dir)) dir else output_dir
            index_files <- check_for_index_files(degree, c(use_output_dir))

            if (index_files$found && !force_regenerate) {
                cat("Index already exists for degree =", degree, ". Skipping...\n")
                results[[paste0("degree_", degree)]] <- list(
                    success = TRUE,
                    message = "Index already exists",
                    degree = degree,
                    source_file = binary_file,
                    index_file = index_files$index_file,
                    skipped = TRUE
                )
                next
            }
            
            # Load binary data and create index
            binary_result <- load_binary_assertions(binary_file)
            if (binary_result$success) {
                index_result <- create_edge_index(binary_result$assertions, include_variations = TRUE)
                if (index_result$success) {
                    save_result <- save_edge_index(index_result, degree = degree, output_dir = use_output_dir)
                    if (save_result$success) {
                        cat("✓ Created index for degree =", degree, "\n")
                        results[[paste0("degree_", degree)]] <- list(
                            success = TRUE,
                            message = "Index created successfully",
                            degree = degree,
                            source_file = binary_file,
                            index_file = save_result$index_file,
                            file_size_mb = save_result$file_size_mb,
                            total_edge_entries = index_result$total_edge_entries,
                            skipped = FALSE
                        )
                    } else {
                        cat("✗ Failed to save index for degree =", degree, "\n")
                        results[[paste0("degree_", degree)]] <- list(
                            success = FALSE,
                            message = save_result$message,
                            degree = degree,
                            source_file = binary_file,
                            skipped = FALSE
                        )
                    }
                } else {
                    cat("✗ Failed to create index for degree =", degree, "\n")
                    results[[paste0("degree_", degree)]] <- list(
                        success = FALSE,
                        message = index_result$message,
                        degree = degree,
                        source_file = binary_file,
                        skipped = FALSE
                    )
                }
            }
        }
        
        # Process JSON files for degree not covered by binary files
        for (json_file in json_files) {
            degree_match <- regmatches(basename(json_file), regexpr("\\d+", basename(json_file)))
            degree <- as.numeric(degree_match[1])

            # Skip if we already processed this degree from binary file
            if (paste0("degree_", degree) %in% names(results)) {
                next
            }

            cat("Creating index for JSON file degree =", degree, "\n")
            
            # Check if index already exists
            use_output_dir <- if (is.null(output_dir)) dir else output_dir
            index_files <- check_for_index_files(degree, c(use_output_dir))

            if (index_files$found && !force_regenerate) {
                cat("Index already exists for degree =", degree, ". Skipping...\n")
                results[[paste0("degree_", degree)]] <- list(
                    success = TRUE,
                    message = "Index already exists",
                    degree = degree,
                    source_file = json_file,
                    index_file = index_files$index_file,
                    skipped = TRUE
                )
                next
            }
            
            # Load JSON data and create index
            json_data <- jsonlite::fromJSON(json_file, simplifyDataFrame = FALSE)
            if (is.list(json_data) && length(json_data) > 0) {
                index_result <- create_edge_index(json_data, include_variations = TRUE)
                if (index_result$success) {
                    save_result <- save_edge_index(index_result, degree = degree, output_dir = use_output_dir)
                    if (save_result$success) {
                        cat("✓ Created index for degree =", degree, "\n")
                        results[[paste0("degree_", degree)]] <- list(
                            success = TRUE,
                            message = "Index created successfully",
                            degree = degree,
                            source_file = json_file,
                            index_file = save_result$index_file,
                            file_size_mb = save_result$file_size_mb,
                            total_edge_entries = index_result$total_edge_entries,
                            skipped = FALSE
                        )
                    }
                }
            }
        }
    }
    
    # Generate summary
    successful_count <- sum(sapply(results, function(r) r$success))
    total_count <- length(results)
    
    cat("\nIndex Creation Summary:\n")
    cat("Files processed:", total_count, "\n")
    cat("Successful:", successful_count, "\n")
    cat("Failed:", total_count - successful_count, "\n")
    
    return(list(
        results = results,
        summary = list(
            total_files = total_count,
            successful = successful_count,
            failed = total_count - successful_count
        )
    ))
}

# Main execution when script is run directly
if (!interactive()) {
    cat("=== COMPREHENSIVE CAUSAL ASSERTIONS OPTIMIZER ===\n")
    cat("This utility applies all optimization techniques to improve loading performance.\n\n")
    
    # Parse command line arguments
    args <- commandArgs(trailingOnly = TRUE)
    force_regenerate <- "--force" %in% args
    
    if (force_regenerate) {
        cat("Force regeneration enabled - will overwrite existing optimized files.\n\n")
    }
    
    # Run comprehensive optimization
    result <- optimize_all_files(force_regenerate = force_regenerate)
    
    if (result$summary$overall_success) {
        cat("\n🎉 Optimization completed successfully!\n")
        cat("Your Shiny app will now load significantly faster.\n")
    } else {
        cat("\n❌ Optimization failed.\n")
        cat("Please check the error messages above.\n")
    }
}

# Export functions for interactive use
if (interactive()) {
    cat("Comprehensive optimization utilities loaded.\n")
    cat("Use optimize_all_files() to apply all optimizations.\n")
}
