# Test script for leaf removal functionality
# This script tests the remove_leaf_nodes function

library(dagitty)
library(igraph)

# Source the data_upload module
source("shiny_app/modules/data_upload.R")

# Create a test DAG with some leaf nodes
test_dag <- dagitty('dag {
    A [exposure]
    Z [outcome]
    B
    C
    D
    E
    F
    G
    
    A -> B
    B -> C
    C -> Z
    B -> D
    D -> E
    E -> F
    G -> B
}')

cat("Original DAG:\n")
print(test_dag)
cat("\nOriginal nodes:", length(names(test_dag)), "\n")
cat("Original edges:", nrow(as.data.frame(dagitty::edges(test_dag))), "\n")

# Test leaf removal
cat("\n=== Testing leaf removal ===\n")
result <- remove_leaf_nodes(test_dag, preserve_exposure_outcome = TRUE)

if (result$success) {
    cat("\n✓ Leaf removal successful!\n")
    cat(result$message, "\n")
    cat("\nCleaned DAG:\n")
    print(result$dag)
    cat("\nStatistics:\n")
    cat("  Original nodes:", result$original_nodes, "\n")
    cat("  Original edges:", result$original_edges, "\n")
    cat("  Final nodes:", result$final_nodes, "\n")
    cat("  Final edges:", result$final_edges, "\n")
    cat("  Removed nodes:", result$removed_nodes, "\n")
    cat("  Removed edges:", result$removed_edges, "\n")
    cat("  Iterations:", result$iterations, "\n")
    
    # Check if exposure and outcome are preserved
    remaining_exposures <- tryCatch(exposures(result$dag), error = function(e) character(0))
    remaining_outcomes <- tryCatch(outcomes(result$dag), error = function(e) character(0))
    
    cat("\nExposure nodes preserved:", paste(remaining_exposures, collapse = ", "), "\n")
    cat("Outcome nodes preserved:", paste(remaining_outcomes, collapse = ", "), "\n")
} else {
    cat("\n✗ Leaf removal failed!\n")
    cat("Error:", result$message, "\n")
}

cat("\n=== Test complete ===\n")

