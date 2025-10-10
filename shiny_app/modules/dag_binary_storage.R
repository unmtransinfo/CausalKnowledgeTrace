# DAG Binary Storage Module
# Compiles degree_{}.R files into binary RDS format for instant loading

library(dagitty)

#' Convert DAG R Script to Binary RDS Format
#'
#' Compiles a degree_{}.R file into a binary RDS file for fast loading
#'
#' @param r_script_path Path to the R script file (e.g., "degree_1.R")
#' @param output_dir Directory to save the binary file (default: same as input)
#' @param force_regenerate Force regeneration even if binary file exists (default: FALSE)
#' @return List with success status and details
#' @export
compile_dag_to_binary <- function(r_script_path, output_dir = NULL, force_regenerate = FALSE) {
    if (!file.exists(r_script_path)) {
        return(list(success = FALSE, message = paste("R script not found:", r_script_path)))
    }
    
    # Determine output directory
    if (is.null(output_dir)) {
        output_dir <- dirname(r_script_path)
    }
    
    # Generate binary filename
    base_name <- tools::file_path_sans_ext(basename(r_script_path))
    binary_path <- file.path(output_dir, paste0(base_name, "_dag.rds"))
    
    # Check if binary file already exists and is newer
    if (!force_regenerate && file.exists(binary_path)) {
        r_mtime <- file.mtime(r_script_path)
        binary_mtime <- file.mtime(binary_path)
        
        if (binary_mtime > r_mtime) {
            binary_size_mb <- file.size(binary_path) / (1024 * 1024)
            return(list(
                success = TRUE,
                message = paste("Binary DAG already exists and is up-to-date:", basename(binary_path)),
                binary_path = binary_path,
                binary_size_mb = round(binary_size_mb, 2),
                action = "skipped"
            ))
        }
    }
    
    tryCatch({
        start_time <- Sys.time()
        
        # Load the DAG from R script
        cat("Compiling DAG from", basename(r_script_path), "...\n")
        
        # Create isolated environment
        dag_env <- new.env()
        source(r_script_path, local = dag_env)
        
        # Extract DAG object
        if (!exists("g", envir = dag_env)) {
            return(list(success = FALSE, message = "No 'g' variable found in R script"))
        }
        
        dag_object <- dag_env$g
        if (!inherits(dag_object, "dagitty")) {
            return(list(success = FALSE, message = "Variable 'g' is not a dagitty object"))
        }
        
        # Create comprehensive DAG data structure
        dag_data <- list(
            dag = dag_object,
            variables = names(dag_object),
            variable_count = length(names(dag_object)),
            dag_string = as.character(dag_object),
            compilation_time = Sys.time(),
            source_file = r_script_path,
            degree = extract_degree_from_filename(r_script_path)
        )
        
        # Save to binary RDS format with compression
        saveRDS(dag_data, binary_path, compress = "gzip")
        
        # Calculate file sizes and timing
        r_size_mb <- file.size(r_script_path) / (1024 * 1024)
        binary_size_mb <- file.size(binary_path) / (1024 * 1024)
        compile_time <- as.numeric(Sys.time() - start_time, units = "secs")
        compression_ratio <- round((1 - binary_size_mb / r_size_mb) * 100, 1)
        
        cat("✓ Compiled successfully in", round(compile_time, 2), "seconds\n")
        cat("  Original size:", round(r_size_mb, 2), "MB\n")
        cat("  Binary size:", round(binary_size_mb, 2), "MB\n")
        cat("  Compression:", compression_ratio, "%\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully compiled", basename(r_script_path), "to binary format"),
            binary_path = binary_path,
            r_size_mb = round(r_size_mb, 2),
            binary_size_mb = round(binary_size_mb, 2),
            compression_ratio = compression_ratio,
            compile_time_seconds = round(compile_time, 2),
            variable_count = dag_data$variable_count,
            degree = dag_data$degree,
            action = "compiled"
        ))
        
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error compiling DAG:", e$message)))
    })
}

#' Load DAG from Binary RDS Format
#'
#' Loads a pre-compiled DAG from binary RDS format for instant access
#'
#' @param binary_path Path to the binary RDS file
#' @return List with success status and DAG data
#' @export
load_dag_from_binary <- function(binary_path) {
    if (!file.exists(binary_path)) {
        return(list(success = FALSE, message = paste("Binary DAG file not found:", binary_path)))
    }
    
    tryCatch({
        start_time <- Sys.time()
        
        # Load binary data
        dag_data <- readRDS(binary_path)
        
        # Validate structure
        if (!is.list(dag_data) || !("dag" %in% names(dag_data))) {
            return(list(success = FALSE, message = "Invalid binary DAG format"))
        }
        
        if (!inherits(dag_data$dag, "dagitty")) {
            return(list(success = FALSE, message = "Binary file does not contain a valid dagitty object"))
        }
        
        load_time <- as.numeric(Sys.time() - start_time, units = "secs")
        file_size_mb <- file.size(binary_path) / (1024 * 1024)
        
        cat("✓ Loaded binary DAG in", round(load_time, 3), "seconds\n")
        cat("  Variables:", dag_data$variable_count, "\n")
        cat("  File size:", round(file_size_mb, 2), "MB\n")
        
        return(list(
            success = TRUE,
            message = paste("Successfully loaded binary DAG with", dag_data$variable_count, "variables"),
            dag = dag_data$dag,
            degree = dag_data$degree,
            variable_count = dag_data$variable_count,
            load_time_seconds = round(load_time, 3),
            file_size_mb = round(file_size_mb, 2),
            compilation_time = dag_data$compilation_time,
            source_file = dag_data$source_file
        ))
        
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error loading binary DAG:", e$message)))
    })
}

#' Extract degree from filename
#'
#' @param filename The filename to extract degree from
#' @return Integer degree value or NULL if not found
extract_degree_from_filename <- function(filename) {
    # Extract number from degree_X.R pattern
    match <- regexpr("degree_([0-9]+)", basename(filename))
    if (match > 0) {
        degree_str <- regmatches(basename(filename), match)
        degree <- as.integer(gsub("degree_", "", degree_str))
        return(degree)
    }
    return(NULL)
}

#' Compile All DAG Files in Directory
#'
#' Batch compiles all degree_{}.R files in a directory to binary format
#'
#' @param input_dir Directory containing R script files
#' @param output_dir Directory to save binary files (default: same as input)
#' @param force_regenerate Force regeneration of all files (default: FALSE)
#' @return List with compilation results
#' @export
compile_all_dag_files <- function(input_dir, output_dir = NULL, force_regenerate = FALSE) {
    if (is.null(output_dir)) {
        output_dir <- input_dir
    }
    
    # Find all degree_{}.R files
    r_files <- list.files(input_dir, pattern = "^degree_[0-9]+\\.R$", full.names = TRUE)
    
    if (length(r_files) == 0) {
        return(list(success = FALSE, message = "No degree_{}.R files found in directory"))
    }
    
    cat("Found", length(r_files), "DAG files to compile:\n")
    for (file in r_files) {
        cat("  -", basename(file), "\n")
    }
    cat("\n")
    
    results <- list()
    total_start_time <- Sys.time()
    
    for (r_file in r_files) {
        cat("Processing", basename(r_file), "...\n")
        result <- compile_dag_to_binary(r_file, output_dir, force_regenerate)
        results[[basename(r_file)]] <- result
        
        if (result$success) {
            cat("✓", result$message, "\n")
        } else {
            cat("✗", result$message, "\n")
        }
        cat("\n")
    }
    
    total_time <- as.numeric(Sys.time() - total_start_time, units = "secs")
    
    # Summary
    successful <- sum(sapply(results, function(x) x$success))
    cat("=== COMPILATION SUMMARY ===\n")
    cat("Total files processed:", length(r_files), "\n")
    cat("Successful compilations:", successful, "\n")
    cat("Failed compilations:", length(r_files) - successful, "\n")
    cat("Total time:", round(total_time, 2), "seconds\n")
    
    return(list(
        success = successful > 0,
        message = paste("Compiled", successful, "of", length(r_files), "DAG files"),
        results = results,
        total_time_seconds = round(total_time, 2)
    ))
}
