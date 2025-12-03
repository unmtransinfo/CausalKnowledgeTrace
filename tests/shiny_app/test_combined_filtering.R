# Test combined path filtering + leaf removal
# Verifies that the combination produces more restrictive results than leaf removal alone

library(dagitty)
library(igraph)

source("shiny_app/modules/data_upload.R")

cat("=== COMBINED FILTERING TEST ===\n\n")

# Load the real graph (use degree 1 for faster testing)
test_file <- "graph_creation/result/degree_1_dag.rds"

if (!file.exists(test_file)) {
    cat("❌ Test file not found:", test_file, "\n")
    quit(status = 1)
}

cat("Loading graph from:", test_file, "\n")
dag_data <- readRDS(test_file)
dag <- dag_data$dag

cat("\nOriginal graph:\n")
cat("  Nodes:", length(names(dag)), "\n")
cat("  Edges:", nrow(as.data.frame(dagitty::edges(dag))), "\n\n")

# Test 1: Leaf removal only
cat("=== TEST 1: LEAF REMOVAL ONLY ===\n")
result_leaf <- remove_leaf_nodes(dag, preserve_exposure_outcome = TRUE)
cat("Result: ", result_leaf$final_nodes, " nodes\n\n")

# Test 2: Path filtering only (old behavior)
cat("=== TEST 2: PATH FILTERING ONLY ===\n")
result_path <- filter_exposure_outcome_paths(dag)
cat("Result: ", result_path$final_nodes, " nodes\n\n")

# Test 3: Combined - path filtering THEN leaf removal (new behavior)
cat("=== TEST 3: PATH FILTERING + LEAF REMOVAL (COMBINED) ===\n")
result_combined_step1 <- filter_exposure_outcome_paths(dag)
if (result_combined_step1$success) {
    cat("After path filtering: ", result_combined_step1$final_nodes, " nodes\n")
    
    result_combined_step2 <- remove_leaf_nodes(result_combined_step1$dag, preserve_exposure_outcome = TRUE)
    if (result_combined_step2$success) {
        cat("After leaf removal: ", result_combined_step2$final_nodes, " nodes\n")
        cat("Total removed: ", result_combined_step1$removed_nodes + result_combined_step2$removed_nodes, " nodes\n\n")
    }
}

# Compare results
cat("=== COMPARISON ===\n")
cat("Leaf removal only:           ", result_leaf$final_nodes, " nodes\n")
cat("Path filtering only:         ", result_path$final_nodes, " nodes\n")
cat("Path filtering + leaf removal:", result_combined_step2$final_nodes, " nodes\n\n")

# Verify the logic
if (result_combined_step2$final_nodes <= result_leaf$final_nodes) {
    cat("✅ CORRECT: Combined filtering is more restrictive than leaf removal alone\n")
    cat("   Difference:", result_leaf$final_nodes - result_combined_step2$final_nodes, "fewer nodes\n")
} else {
    cat("❌ ERROR: Combined filtering kept MORE nodes than leaf removal alone!\n")
    cat("   This should not happen.\n")
}

if (result_combined_step2$final_nodes < result_path$final_nodes) {
    cat("✅ CORRECT: Combined filtering is more restrictive than path filtering alone\n")
    cat("   Removed:", result_path$final_nodes - result_combined_step2$final_nodes, "additional leaf nodes\n")
} else {
    cat("❌ ERROR: Combined filtering did not remove any leaves from path-filtered graph!\n")
}

cat("\n=== SUMMARY ===\n")
cat("The 'Keep only paths' option now:\n")
cat("  1. Filters to keep only nodes on directed paths (", result_path$final_nodes, " nodes)\n")
cat("  2. Then removes leaf nodes from filtered graph (", result_combined_step2$final_nodes, " nodes)\n")
cat("  3. Result: Most focused graph with well-connected causal relationships\n")

cat("\n=== TEST COMPLETE ===\n")

