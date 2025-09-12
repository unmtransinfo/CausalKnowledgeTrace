#!/usr/bin/env Rscript
# Utility script to compile all DAG files to binary format

# Load required modules
source("modules/dag_binary_storage.R")

cat("=== DAG BINARY COMPILATION UTILITY ===\n")
cat("This script compiles all degree_{}.R files to binary RDS format for faster loading.\n\n")

# Define directories
input_dir <- "../graph_creation/result"
output_dir <- input_dir  # Save binary files in the same directory

# Check if input directory exists
if (!dir.exists(input_dir)) {
    cat("❌ Error: Input directory not found:", input_dir, "\n")
    cat("Please make sure you're running this from the shiny_app directory.\n")
    quit(status = 1)
}

# List existing files
cat("📁 Checking directory:", input_dir, "\n")
all_files <- list.files(input_dir, pattern = "\\.(R|rds)$")
r_files <- list.files(input_dir, pattern = "^degree_[0-9]+\\.R$")
existing_binary <- list.files(input_dir, pattern = "^degree_[0-9]+_dag\\.rds$")

cat("Found files:\n")
cat("  R scripts:", length(r_files), "\n")
cat("  Existing binary files:", length(existing_binary), "\n")

if (length(r_files) == 0) {
    cat("❌ No degree_{}.R files found in", input_dir, "\n")
    quit(status = 1)
}

cat("\nR script files to process:\n")
for (file in r_files) {
    file_path <- file.path(input_dir, file)
    file_size <- file.size(file_path) / 1024  # KB
    cat("  -", file, sprintf("(%.1f KB)", file_size), "\n")
}

cat("\nExisting binary files:\n")
if (length(existing_binary) > 0) {
    for (file in existing_binary) {
        file_path <- file.path(input_dir, file)
        file_size <- file.size(file_path) / 1024  # KB
        file_time <- format(file.mtime(file_path), "%Y-%m-%d %H:%M:%S")
        cat("  -", file, sprintf("(%.1f KB, %s)", file_size, file_time), "\n")
    }
} else {
    cat("  (none)\n")
}

# Ask user for confirmation
cat("\n🔄 Compilation options:\n")
cat("1. Compile only missing binary files (recommended)\n")
cat("2. Force recompile all files\n")
cat("3. Exit without changes\n")

choice <- readline(prompt = "Enter your choice (1-3): ")

force_regenerate <- FALSE
if (choice == "2") {
    force_regenerate <- TRUE
    cat("Will force recompile all files.\n")
} else if (choice == "3") {
    cat("Exiting without changes.\n")
    quit(status = 0)
} else {
    cat("Will compile only missing or outdated binary files.\n")
}

cat("\n🚀 Starting compilation...\n")
cat("=====================================\n")

# Compile all DAG files
result <- compile_all_dag_files(input_dir, output_dir, force_regenerate)

cat("\n📊 FINAL SUMMARY\n")
cat("=====================================\n")

if (result$success) {
    cat("✅ Compilation completed successfully!\n")
    
    # Show detailed results
    successful_files <- names(result$results)[sapply(result$results, function(x) x$success)]
    failed_files <- names(result$results)[!sapply(result$results, function(x) x$success)]
    
    if (length(successful_files) > 0) {
        cat("\n✅ Successfully processed files:\n")
        for (file in successful_files) {
            res <- result$results[[file]]
            if (res$action == "compiled") {
                cat(sprintf("  ✓ %s -> %s (%.1f%% compression, %.2fs)\n", 
                           file, 
                           basename(res$binary_path),
                           res$compression_ratio,
                           res$compile_time_seconds))
            } else if (res$action == "skipped") {
                cat(sprintf("  ↻ %s (already up-to-date, %.2f MB)\n", 
                           file, res$binary_size_mb))
            }
        }
    }
    
    if (length(failed_files) > 0) {
        cat("\n❌ Failed files:\n")
        for (file in failed_files) {
            res <- result$results[[file]]
            cat("  ✗", file, "-", res$message, "\n")
        }
    }
    
    # Performance summary
    cat(sprintf("\n⏱️  Total time: %.2f seconds\n", result$total_time_seconds))
    cat(sprintf("📁 Output directory: %s\n", output_dir))
    
    # Show final file listing
    cat("\n📋 Final binary files:\n")
    final_binary <- list.files(input_dir, pattern = "^degree_[0-9]+_dag\\.rds$", full.names = TRUE)
    for (file_path in final_binary) {
        file_size <- file.size(file_path) / (1024 * 1024)  # MB
        cat(sprintf("  📦 %s (%.2f MB)\n", basename(file_path), file_size))
    }
    
    cat("\n🎉 Binary DAG files are ready for ultra-fast loading!\n")
    cat("The Shiny app will now automatically use these binary files for instant DAG loading.\n")
    
} else {
    cat("❌ Compilation failed:", result$message, "\n")
    quit(status = 1)
}

cat("\n✨ Done! You can now start the Shiny app for lightning-fast DAG loading.\n")
