#!/usr/bin/env Rscript
# Generate Separated Files Utility
# 
# This script processes existing causal_assertions JSON files and creates
# separated lightweight and sentence files for improved loading performance.

# Load required libraries
library(jsonlite)

# Source required modules
source("../modules/sentence_storage.R")

#' Process All Causal Assertions Files
#'
#' Processes all causal_assertions_*.json files in the specified directories
#'
#' @param search_dirs Directories to search for files
#' @param output_dir Directory to save separated files (default: same as input)
#' @param force_regenerate Force regeneration even if separated files exist
#' @return List with processing results
process_all_assertions_files <- function(search_dirs = c("../../graph_creation/result", "../../graph_creation/output"),
                                        output_dir = NULL,
                                        force_regenerate = FALSE) {
    
    results <- list()
    total_original_size <- 0
    total_lightweight_size <- 0
    total_sentences_size <- 0
    
    cat("Searching for causal assertions files...\n")
    
    for (dir in search_dirs) {
        if (!dir.exists(dir)) {
            cat("Directory not found:", dir, "\n")
            next
        }
        
        # Find all causal_assertions files
        assertion_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
        
        if (length(assertion_files) == 0) {
            cat("No causal assertions files found in:", dir, "\n")
            next
        }
        
        cat("Found", length(assertion_files), "files in", dir, "\n")
        
        for (file_path in assertion_files) {
            # Extract k_hops from filename
            filename <- basename(file_path)
            k_hops_match <- regmatches(filename, regexpr("\\d+", filename))
            k_hops <- as.numeric(k_hops_match[1])
            
            cat("\nProcessing:", filename, "(k_hops =", k_hops, ")\n")
            
            # Check if separated files already exist
            use_output_dir <- if (is.null(output_dir)) dir else output_dir
            separated_files <- check_for_separated_files(k_hops, c(use_output_dir))
            
            if (separated_files$found && !force_regenerate) {
                cat("Separated files already exist for k_hops =", k_hops, ". Skipping...\n")
                cat("Use force_regenerate = TRUE to overwrite.\n")
                
                # Get statistics for existing files
                stats <- get_separation_stats(k_hops, c(use_output_dir))
                if (stats$available) {
                    results[[paste0("k_hops_", k_hops)]] <- list(
                        success = TRUE,
                        message = "Files already exist",
                        k_hops = k_hops,
                        original_file = file_path,
                        lightweight_file = separated_files$lightweight_file,
                        sentences_file = separated_files$sentences_file,
                        original_size_mb = stats$original_size_mb,
                        lightweight_size_mb = stats$lightweight_size_mb,
                        sentences_size_mb = stats$sentences_size_mb,
                        reduction_percent = stats$reduction_percent,
                        skipped = TRUE
                    )
                    
                    total_original_size <- total_original_size + stats$original_size_mb
                    total_lightweight_size <- total_lightweight_size + stats$lightweight_size_mb
                    total_sentences_size <- total_sentences_size + stats$sentences_size_mb
                }
                next
            }
            
            # Process the file
            result <- separate_sentences_from_assertions(
                assertions_file = file_path,
                output_dir = use_output_dir,
                k_hops = k_hops
            )
            
            if (result$success) {
                cat("✓ Successfully processed", filename, "\n")
                cat("  Original:", result$original_size_mb, "MB\n")
                cat("  Lightweight:", result$lightweight_size_mb, "MB\n")
                cat("  Sentences:", result$sentences_size_mb, "MB\n")
                cat("  Reduction:", result$reduction_percent, "%\n")
                
                results[[paste0("k_hops_", k_hops)]] <- c(result, list(
                    k_hops = k_hops,
                    original_file = file_path,
                    skipped = FALSE
                ))
                
                total_original_size <- total_original_size + result$original_size_mb
                total_lightweight_size <- total_lightweight_size + result$lightweight_size_mb
                total_sentences_size <- total_sentences_size + result$sentences_size_mb
            } else {
                cat("✗ Failed to process", filename, ":", result$message, "\n")
                results[[paste0("k_hops_", k_hops)]] <- list(
                    success = FALSE,
                    message = result$message,
                    k_hops = k_hops,
                    original_file = file_path,
                    skipped = FALSE
                )
            }
        }
    }
    
    # Print summary
    cat("\n" , "=== PROCESSING SUMMARY ===", "\n")
    successful_count <- sum(sapply(results, function(r) r$success))
    total_count <- length(results)
    
    cat("Files processed:", total_count, "\n")
    cat("Successful:", successful_count, "\n")
    cat("Failed:", total_count - successful_count, "\n")
    
    if (total_original_size > 0) {
        total_reduction <- round((1 - total_lightweight_size / total_original_size) * 100, 1)
        cat("\nSize Summary:\n")
        cat("  Total original size:", round(total_original_size, 2), "MB\n")
        cat("  Total lightweight size:", round(total_lightweight_size, 2), "MB\n")
        cat("  Total sentences size:", round(total_sentences_size, 2), "MB\n")
        cat("  Total separated size:", round(total_lightweight_size + total_sentences_size, 2), "MB\n")
        cat("  Overall reduction:", total_reduction, "%\n")
        cat("  Space saved:", round(total_original_size - total_lightweight_size, 2), "MB\n")
    }
    
    return(list(
        results = results,
        summary = list(
            total_files = total_count,
            successful = successful_count,
            failed = total_count - successful_count,
            total_original_size_mb = total_original_size,
            total_lightweight_size_mb = total_lightweight_size,
            total_sentences_size_mb = total_sentences_size,
            overall_reduction_percent = if (total_original_size > 0) round((1 - total_lightweight_size / total_original_size) * 100, 1) else 0
        )
    ))
}

#' Clean Up Old Files
#'
#' Removes old separated files to force regeneration
#'
#' @param search_dirs Directories to search in
#' @param k_hops_list List of k_hops values to clean (default: c(1,2,3))
clean_separated_files <- function(search_dirs = c("../../graph_creation/result", "../../graph_creation/output"),
                                 k_hops_list = c(1, 2, 3)) {
    
    cat("Cleaning up old separated files...\n")
    
    for (dir in search_dirs) {
        if (!dir.exists(dir)) next
        
        for (k_hops in k_hops_list) {
            lightweight_file <- file.path(dir, paste0("causal_assertions_", k_hops, "_lightweight.json"))
            sentences_file <- file.path(dir, paste0("sentences_", k_hops, ".json"))
            
            if (file.exists(lightweight_file)) {
                unlink(lightweight_file)
                cat("Removed:", basename(lightweight_file), "\n")
            }
            
            if (file.exists(sentences_file)) {
                unlink(sentences_file)
                cat("Removed:", basename(sentences_file), "\n")
            }
        }
    }
    
    cat("Cleanup completed.\n")
}

# Main execution when script is run directly
if (!interactive()) {
    cat("=== Causal Assertions File Separator ===\n")
    cat("This utility creates optimized separated files from causal assertions.\n\n")
    
    # Parse command line arguments
    args <- commandArgs(trailingOnly = TRUE)
    force_regenerate <- "--force" %in% args
    clean_first <- "--clean" %in% args
    
    if (clean_first) {
        cat("Cleaning existing separated files first...\n")
        clean_separated_files()
        cat("\n")
    }
    
    # Process all files
    result <- process_all_assertions_files(force_regenerate = force_regenerate)
    
    if (result$summary$successful > 0) {
        cat("\n✓ File separation completed successfully!\n")
        cat("The Shiny app will now automatically use the optimized files for faster loading.\n")
    } else {
        cat("\n✗ No files were processed successfully.\n")
    }
}

# Export functions for use in other scripts
if (interactive()) {
    cat("Separated file generation utilities loaded.\n")
    cat("Use process_all_assertions_files() to generate separated files.\n")
    cat("Use clean_separated_files() to remove existing separated files.\n")
}
