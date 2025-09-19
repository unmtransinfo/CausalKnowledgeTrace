# Binary Storage System for Causal Assertions
# 
# This module provides binary format storage and loading for causal assertions
# using R's native RDS format with compression for optimal performance.

library(jsonlite)

#' Convert JSON to Binary Format
#'
#' Converts causal assertions JSON file to compressed RDS format
#'
#' @param json_file Path to the JSON file
#' @param output_dir Directory to save binary file (default: same as input)
#' @param compression Compression method ("gzip", "bzip2", "xz", or "none")
#' @param k_hops K-hops parameter for file naming
#' @return List with conversion results
#' @export
convert_json_to_binary <- function(json_file, output_dir = NULL, compression = "gzip", k_hops = NULL) {
    # Binary file creation disabled to speed up process
    return(list(
        success = FALSE,
        message = "Binary file creation has been disabled to speed up the graph creation process"
    ))

    if (!file.exists(json_file)) {
        return(list(
            success = FALSE,
            message = paste("JSON file not found:", json_file)
        ))
    }
    
    # Determine output directory
    if (is.null(output_dir)) {
        output_dir <- dirname(json_file)
    }
    
    # Determine k_hops from filename if not provided
    if (is.null(k_hops)) {
        filename <- basename(json_file)
        k_hops_match <- regmatches(filename, regexpr("\\d+", filename))
        if (length(k_hops_match) > 0) {
            k_hops <- as.numeric(k_hops_match[1])
        } else {
            k_hops <- "unknown"
        }
    }
    
    tryCatch({
        cat("Converting JSON to binary format...\n")
        start_time <- Sys.time()
        
        # Load JSON data
        cat("Loading JSON data...\n")
        json_data <- jsonlite::fromJSON(json_file, simplifyDataFrame = FALSE)
        
        if (!is.list(json_data) || length(json_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty JSON data"
            ))
        }
        
        # Generate output filename
        binary_file <- file.path(output_dir, paste0("causal_assertions_", k_hops, "_binary.rds"))
        
        # Save as RDS with compression
        cat("Saving binary data with", compression, "compression...\n")
        saveRDS(json_data, binary_file, compress = compression)
        
        # Calculate file sizes and compression ratio
        json_size <- file.size(json_file)
        binary_size <- file.size(binary_file)
        compression_ratio <- round((1 - binary_size / json_size) * 100, 1)
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        
        cat("Binary conversion completed in", round(load_time, 2), "seconds\n")
        cat("JSON file:", round(json_size / (1024^2), 2), "MB\n")
        cat("Binary file:", round(binary_size / (1024^2), 2), "MB\n")
        cat("Compression ratio:", compression_ratio, "%\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully converted to binary format with", compression_ratio, "% compression"),
            json_file = json_file,
            binary_file = binary_file,
            json_size_mb = round(json_size / (1024^2), 2),
            binary_size_mb = round(binary_size / (1024^2), 2),
            compression_ratio = compression_ratio,
            compression_method = compression,
            conversion_time_seconds = load_time
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error converting to binary format:", e$message)
        ))
    })
}

#' Load Binary Assertions
#'
#' Loads causal assertions from binary RDS format
#'
#' @param binary_file Path to the binary RDS file
#' @return List with loaded assertions
#' @export
load_binary_assertions <- function(binary_file) {
    if (!file.exists(binary_file)) {
        return(list(
            success = FALSE,
            message = paste("Binary file not found:", binary_file),
            assertions = list()
        ))
    }
    
    tryCatch({
        cat("Loading binary assertions...\n")
        start_time <- Sys.time()
        
        # Load RDS data
        assertions_data <- readRDS(binary_file)
        
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty binary data",
                assertions = list()
            ))
        }
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        file_size_mb <- round(file.size(binary_file) / (1024^2), 2)
        
        cat("Loaded", length(assertions_data), "binary assertions in", round(load_time, 2), "seconds\n")
        cat("File size:", file_size_mb, "MB\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully loaded", length(assertions_data), "binary assertions"),
            assertions = assertions_data,
            load_time_seconds = load_time,
            file_size_mb = file_size_mb
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading binary assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Check for Binary Files
#'
#' Checks if binary files exist for a given k_hops value
#'
#' @param k_hops K-hops parameter
#' @param search_dirs Directories to search in
#' @return List with file paths if they exist
#' @export
check_for_binary_files <- function(k_hops, search_dirs = c("../graph_creation/result", "../graph_creation/output")) {
    binary_filename <- paste0("causal_assertions_", k_hops, "_binary.rds")
    
    for (dir in search_dirs) {
        if (dir.exists(dir)) {
            binary_path <- file.path(dir, binary_filename)
            
            if (file.exists(binary_path)) {
                return(list(
                    found = TRUE,
                    binary_file = binary_path
                ))
            }
        }
    }
    
    return(list(found = FALSE))
}

#' Compare Loading Performance
#'
#' Compares loading performance between JSON and binary formats
#'
#' @param k_hops K-hops parameter
#' @param search_dirs Directories to search in
#' @param iterations Number of loading iterations for benchmarking
#' @return List with performance comparison
#' @export
compare_loading_performance <- function(k_hops, search_dirs = c("../graph_creation/result", "../graph_creation/output"), iterations = 3) {
    # Find files
    json_filename <- paste0("causal_assertions_", k_hops, ".json")
    binary_files <- check_for_binary_files(k_hops, search_dirs)
    
    json_file <- NULL
    for (dir in search_dirs) {
        test_path <- file.path(dir, json_filename)
        if (file.exists(test_path)) {
            json_file <- test_path
            break
        }
    }
    
    if (is.null(json_file)) {
        return(list(
            success = FALSE,
            message = "JSON file not found for comparison"
        ))
    }
    
    if (!binary_files$found) {
        return(list(
            success = FALSE,
            message = "Binary file not found for comparison"
        ))
    }
    
    cat("Comparing loading performance (", iterations, "iterations each)...\n")
    
    # Benchmark JSON loading
    json_times <- numeric(iterations)
    for (i in 1:iterations) {
        start_time <- Sys.time()
        json_data <- jsonlite::fromJSON(json_file, simplifyDataFrame = FALSE)
        json_times[i] <- as.numeric(Sys.time() - start_time, units = "secs")
        rm(json_data)  # Free memory
        gc()  # Garbage collection
    }
    
    # Benchmark binary loading
    binary_times <- numeric(iterations)
    for (i in 1:iterations) {
        start_time <- Sys.time()
        binary_data <- readRDS(binary_files$binary_file)
        binary_times[i] <- as.numeric(Sys.time() - start_time, units = "secs")
        rm(binary_data)  # Free memory
        gc()  # Garbage collection
    }
    
    # Calculate statistics
    json_mean <- mean(json_times)
    json_sd <- sd(json_times)
    binary_mean <- mean(binary_times)
    binary_sd <- sd(binary_times)
    
    speedup <- json_mean / binary_mean
    
    # File sizes
    json_size_mb <- round(file.size(json_file) / (1024^2), 2)
    binary_size_mb <- round(file.size(binary_files$binary_file) / (1024^2), 2)
    
    cat("\nPerformance Comparison Results:\n")
    cat("JSON loading time:", round(json_mean, 3), "±", round(json_sd, 3), "seconds\n")
    cat("Binary loading time:", round(binary_mean, 3), "±", round(binary_sd, 3), "seconds\n")
    cat("Speedup:", round(speedup, 2), "x faster\n")
    cat("JSON file size:", json_size_mb, "MB\n")
    cat("Binary file size:", binary_size_mb, "MB\n")
    
    return(list(
        success = TRUE,
        json_file = json_file,
        binary_file = binary_files$binary_file,
        json_loading_time_mean = json_mean,
        json_loading_time_sd = json_sd,
        binary_loading_time_mean = binary_mean,
        binary_loading_time_sd = binary_sd,
        speedup_factor = speedup,
        json_size_mb = json_size_mb,
        binary_size_mb = binary_size_mb,
        iterations = iterations
    ))
}

#' Create Binary Files for All K-hops
#'
#' Creates binary versions of all causal assertions files
#'
#' @param search_dirs Directories to search for JSON files
#' @param output_dir Directory to save binary files (default: same as input)
#' @param compression Compression method
#' @param force_regenerate Force regeneration even if binary files exist
#' @return List with processing results
#' @export
create_all_binary_files <- function(search_dirs = c("../graph_creation/result", "../graph_creation/output"),
                                   output_dir = NULL,
                                   compression = "gzip",
                                   force_regenerate = FALSE) {
    
    results <- list()
    
    cat("Creating binary files for all causal assertions...\n")
    
    for (dir in search_dirs) {
        if (!dir.exists(dir)) {
            cat("Directory not found:", dir, "\n")
            next
        }
        
        # Find all causal_assertions files
        json_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
        
        if (length(json_files) == 0) {
            cat("No causal assertions files found in:", dir, "\n")
            next
        }
        
        for (json_file in json_files) {
            # Extract k_hops
            filename <- basename(json_file)
            k_hops_match <- regmatches(filename, regexpr("\\d+", filename))
            k_hops <- as.numeric(k_hops_match[1])
            
            cat("\nProcessing:", filename, "(k_hops =", k_hops, ")\n")
            
            # Check if binary file already exists
            use_output_dir <- if (is.null(output_dir)) dir else output_dir
            binary_files <- check_for_binary_files(k_hops, c(use_output_dir))
            
            if (binary_files$found && !force_regenerate) {
                cat("Binary file already exists for k_hops =", k_hops, ". Skipping...\n")
                results[[paste0("k_hops_", k_hops)]] <- list(
                    success = TRUE,
                    message = "Binary file already exists",
                    k_hops = k_hops,
                    json_file = json_file,
                    binary_file = binary_files$binary_file,
                    skipped = TRUE
                )
                next
            }
            
            # Convert to binary
            result <- convert_json_to_binary(
                json_file = json_file,
                output_dir = use_output_dir,
                compression = compression,
                k_hops = k_hops
            )
            
            if (result$success) {
                cat("✓ Successfully created binary file for", filename, "\n")
                results[[paste0("k_hops_", k_hops)]] <- c(result, list(
                    k_hops = k_hops,
                    skipped = FALSE
                ))
            } else {
                cat("✗ Failed to create binary file for", filename, ":", result$message, "\n")
                results[[paste0("k_hops_", k_hops)]] <- list(
                    success = FALSE,
                    message = result$message,
                    k_hops = k_hops,
                    json_file = json_file,
                    skipped = FALSE
                )
            }
        }
    }
    
    # Print summary
    cat("\n=== BINARY CONVERSION SUMMARY ===\n")
    successful_count <- sum(sapply(results, function(r) r$success))
    total_count <- length(results)
    
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
