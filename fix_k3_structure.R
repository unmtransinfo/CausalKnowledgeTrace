#!/usr/bin/env Rscript
# Fix K-hops=3 File Structure
# 
# This script removes the duplicate pmid_list field from the k_hops=3 file
# to optimize the structure while preserving all sentence data.

library(jsonlite)

cat("=== Fixing K-hops=3 File Structure ===\n")

# File paths
input_file <- "graph_creation/result/causal_assertions_3.json"
backup_file <- "graph_creation/result/causal_assertions_3_backup.json"
output_file <- input_file

# Check if file exists
if (!file.exists(input_file)) {
    cat("✗ Input file not found:", input_file, "\n")
    quit(status = 1)
}

cat("Loading k_hops=3 file...\n")
start_time <- Sys.time()

# Load the data
tryCatch({
    data <- jsonlite::fromJSON(input_file, simplifyDataFrame = FALSE)
    
    if (length(data) == 0) {
        cat("✗ File is empty\n")
        quit(status = 1)
    }
    
    cat("Loaded", length(data), "assertions\n")
    
    # Create backup
    cat("Creating backup...\n")
    file.copy(input_file, backup_file, overwrite = TRUE)
    
    # Check current structure
    duplicates_found <- 0
    sentences_preserved <- 0
    
    for (i in seq_along(data)) {
        assertion <- data[[i]]
        
        # Check if it has both pmid_list and pmid_data
        if (!is.null(assertion$pmid_list) && !is.null(assertion$pmid_data)) {
            duplicates_found <- duplicates_found + 1
            
            # Remove the pmid_list field (keep only pmid_data)
            data[[i]]$pmid_list <- NULL
            
            # Count sentences preserved
            if (!is.null(assertion$pmid_data)) {
                for (pmid in names(assertion$pmid_data)) {
                    if (!is.null(assertion$pmid_data[[pmid]]$sentences)) {
                        sentences_preserved <- sentences_preserved + length(assertion$pmid_data[[pmid]]$sentences)
                    }
                }
            }
        }
    }
    
    cat("Structure optimization:\n")
    cat("  Duplicate pmid_list fields removed:", duplicates_found, "\n")
    cat("  Sentences preserved:", sentences_preserved, "\n")
    
    if (duplicates_found > 0) {
        # Save the optimized data
        cat("Saving optimized file...\n")
        jsonlite::write_json(data, output_file, pretty = TRUE, auto_unbox = TRUE)
        
        # Calculate file size reduction
        original_size <- file.size(backup_file)
        optimized_size <- file.size(output_file)
        reduction_percent <- round((1 - optimized_size / original_size) * 100, 1)
        
        cat("File optimization completed:\n")
        cat("  Original size:", round(original_size / (1024^2), 2), "MB\n")
        cat("  Optimized size:", round(optimized_size / (1024^2), 2), "MB\n")
        cat("  Size reduction:", reduction_percent, "%\n")
        
        # Verify the optimized file
        cat("Verifying optimized file...\n")
        test_data <- jsonlite::fromJSON(output_file, simplifyDataFrame = FALSE)
        
        if (length(test_data) == length(data)) {
            # Check structure
            structure_issues <- 0
            for (i in 1:min(10, length(test_data))) {
                assertion <- test_data[[i]]
                if (!is.null(assertion$pmid_list) && !is.null(assertion$pmid_data)) {
                    structure_issues <- structure_issues + 1
                }
            }
            
            if (structure_issues == 0) {
                cat("✓ Verification successful: Optimized structure confirmed\n")
                cat("✓ Backup saved as:", backup_file, "\n")
            } else {
                cat("✗ Verification failed: Structure issues remain\n")
            }
        } else {
            cat("✗ Verification failed: Data length mismatch\n")
        }
    } else {
        cat("✓ File already has optimized structure\n")
    }
    
    total_time <- as.numeric(Sys.time() - start_time, units = "secs")
    cat("Total processing time:", round(total_time, 2), "seconds\n")
    
}, error = function(e) {
    cat("✗ Error processing file:", e$message, "\n")
    quit(status = 1)
})

cat("\n=== Fix Complete ===\n")
cat("The k_hops=3 file now has the optimized structure.\n")
cat("Edge information panel should now work correctly for all k-hops levels.\n")
cat("\nNext steps:\n")
cat("1. Test the app: Rscript run_app.R --optimize\n")
cat("2. Click on edges in k_hops=3 graphs to verify sentences appear\n")
cat("3. If satisfied, you can delete the backup file\n")
