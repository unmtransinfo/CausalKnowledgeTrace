# Test bidirectional path filtering
# Verifies that all 4 path types are correctly identified and kept

library(dagitty)
library(igraph)

# Set working directory to shiny_app for module loading
original_wd <- getwd()
current_dir <- basename(getwd())
parent_dir <- basename(dirname(getwd()))

if (current_dir == "shiny_app" && parent_dir == "tests") {
    # Running from tests/shiny_app, go up two levels then into shiny_app
    setwd(file.path(dirname(dirname(getwd())), "shiny_app"))
} else if (current_dir == "tests") {
    # Running from tests directory
    setwd(file.path(dirname(getwd()), "shiny_app"))
} else if (current_dir == "shiny_app" && dir.exists("modules")) {
    # Already in the correct shiny_app directory
    # Do nothing
} else {
    # Try to find and navigate to shiny_app directory
    if (dir.exists("shiny_app") && dir.exists("shiny_app/modules")) {
        setwd("shiny_app")
    } else if (dir.exists("../../shiny_app")) {
        setwd("../../shiny_app")
    } else {
        stop("Cannot find shiny_app directory with modules. Current dir: ", getwd())
    }
}

source("modules/data_upload.R")

cat("=== BIDIRECTIONAL PATH FILTERING TEST ===\n\n")

# Create a test DAG with all 4 path types
# 
# Path Type 1 (Forward): exposure → A → B → outcome
# Path Type 2 (Reverse): outcome → C → D → exposure  
# Path Type 3 (Common descendant): E → exposure AND E → outcome
# Path Type 4 (Common ancestor): exposure → F AND outcome → F
# 
# Isolated node: Z (should be removed)

dag_string <- "dag {
    exposure [exposure]
    outcome [outcome]
    exposure -> A
    A -> B
    B -> outcome
    outcome -> C
    C -> D
    D -> exposure
    E -> exposure
    E -> outcome
    exposure -> F
    outcome -> F
    Z -> isolated
}"

dag <- dagitty(dag_string)

cat("Original DAG:\n")
cat("  Nodes:", length(names(dag)), "\n")
cat("  Edges:", nrow(as.data.frame(dagitty::edges(dag))), "\n")
cat("  Exposure:", exposures(dag), "\n")
cat("  Outcome:", outcomes(dag), "\n\n")

# Apply path filtering
cat("Applying bidirectional path filtering...\n\n")
result <- filter_exposure_outcome_paths(dag)

cat("Result:\n")
cat("  Success:", result$success, "\n")
cat("  Original nodes:", result$original_nodes, "\n")
cat("  Final nodes:", result$final_nodes, "\n")
cat("  Removed nodes:", result$removed_nodes, "\n")
cat("  Removed edges:", result$removed_edges, "\n\n")

if (result$success) {
    filtered_dag <- result$dag
    kept_nodes <- names(filtered_dag)
    
    cat("Kept nodes:", paste(kept_nodes, collapse = ", "), "\n\n")
    
    # Verify each path type
    cat("=== VERIFICATION ===\n\n")
    
    # Expected nodes for each path type
    expected_forward <- c("exposure", "A", "B", "outcome")
    expected_reverse <- c("outcome", "C", "D", "exposure")
    expected_common_desc <- c("E", "exposure", "outcome")
    expected_common_anc <- c("exposure", "outcome", "F")
    
    # Check Type 1: Forward paths
    forward_kept <- all(expected_forward %in% kept_nodes)
    cat("✓ Type 1 (Forward: exposure → outcome):\n")
    cat("  Expected:", paste(expected_forward, collapse = ", "), "\n")
    cat("  All kept:", forward_kept, "\n\n")
    
    # Check Type 2: Reverse paths
    reverse_kept <- all(expected_reverse %in% kept_nodes)
    cat("✓ Type 2 (Reverse: outcome → exposure):\n")
    cat("  Expected:", paste(expected_reverse, collapse = ", "), "\n")
    cat("  All kept:", reverse_kept, "\n\n")
    
    # Check Type 3: Common descendant
    common_desc_kept <- all(expected_common_desc %in% kept_nodes)
    cat("✓ Type 3 (Common descendant: E → both):\n")
    cat("  Expected:", paste(expected_common_desc, collapse = ", "), "\n")
    cat("  All kept:", common_desc_kept, "\n\n")
    
    # Check Type 4: Common ancestor
    common_anc_kept <- all(expected_common_anc %in% kept_nodes)
    cat("✓ Type 4 (Common ancestor: both → F):\n")
    cat("  Expected:", paste(expected_common_anc, collapse = ", "), "\n")
    cat("  All kept:", common_anc_kept, "\n\n")
    
    # Check isolated nodes removed
    isolated_removed <- !("Z" %in% kept_nodes) && !("isolated" %in% kept_nodes)
    cat("✓ Isolated nodes removed:\n")
    cat("  Z and isolated removed:", isolated_removed, "\n\n")
    
    # Overall test result
    all_tests_passed <- forward_kept && reverse_kept && common_desc_kept && 
                        common_anc_kept && isolated_removed
    
    if (all_tests_passed) {
        cat("🎉 ALL TESTS PASSED!\n")
        cat("The bidirectional path filtering correctly identifies and keeps:\n")
        cat("  ✅ Forward paths (exposure → outcome)\n")
        cat("  ✅ Reverse paths (outcome → exposure)\n")
        cat("  ✅ Common descendants (node → both)\n")
        cat("  ✅ Common ancestors (both → node)\n")
        cat("  ✅ Removes isolated nodes\n")
    } else {
        cat("❌ SOME TESTS FAILED!\n")
        if (!forward_kept) cat("  ❌ Forward paths not fully kept\n")
        if (!reverse_kept) cat("  ❌ Reverse paths not fully kept\n")
        if (!common_desc_kept) cat("  ❌ Common descendants not fully kept\n")
        if (!common_anc_kept) cat("  ❌ Common ancestors not fully kept\n")
        if (!isolated_removed) cat("  ❌ Isolated nodes not removed\n")
    }
} else {
    cat("❌ Filtering failed:", result$message, "\n")
}

cat("\n=== TEST COMPLETE ===\n")

