# Compare leaf removal vs path filtering
# This will help diagnose why path filtering keeps MORE nodes than leaf removal

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

cat("=== FILTERING COMPARISON TEST ===\n\n")

# Load a real graph (use degree 1 for faster testing)
test_file <- "../graph_creation/result/degree_1_dag.rds"

if (!file.exists(test_file)) {
    cat("❌ Test file not found:", test_file, "\n")
    quit(status = 1)
}

cat("Loading graph from:", test_file, "\n")
dag_data <- readRDS(test_file)
dag <- dag_data$dag

cat("\nOriginal graph:\n")
cat("  Nodes:", length(names(dag)), "\n")
cat("  Edges:", nrow(as.data.frame(dagitty::edges(dag))), "\n")
cat("  Exposure:", paste(exposures(dag), collapse = ", "), "\n")
cat("  Outcome:", paste(outcomes(dag), collapse = ", "), "\n\n")

# Test 1: Remove leaf nodes
cat("=== TEST 1: REMOVE LEAF NODES ===\n")
result_leaf <- remove_leaf_nodes(dag, preserve_exposure_outcome = TRUE)

cat("\nResult:\n")
cat("  Success:", result_leaf$success, "\n")
cat("  Final nodes:", result_leaf$final_nodes, "\n")
cat("  Removed nodes:", result_leaf$removed_nodes, "\n")
cat("  Iterations:", result_leaf$iterations, "\n\n")

# Test 2: Keep only paths
cat("=== TEST 2: KEEP ONLY PATHS ===\n")
result_path <- filter_exposure_outcome_paths(dag)

cat("\nResult:\n")
cat("  Success:", result_path$success, "\n")
cat("  Final nodes:", result_path$final_nodes, "\n")
cat("  Removed nodes:", result_path$removed_nodes, "\n\n")

# Compare results
cat("=== COMPARISON ===\n")
cat("Leaf removal kept:", result_leaf$final_nodes, "nodes\n")
cat("Path filtering kept:", result_path$final_nodes, "nodes\n")
cat("Difference:", result_path$final_nodes - result_leaf$final_nodes, "nodes\n\n")

if (result_path$final_nodes > result_leaf$final_nodes) {
    cat("⚠️  WARNING: Path filtering kept MORE nodes than leaf removal!\n")
    cat("This is unexpected - path filtering should be more restrictive.\n\n")
    
    # Find nodes kept by path filtering but removed by leaf removal
    if (result_leaf$success && result_path$success) {
        leaf_nodes <- names(result_leaf$dag)
        path_nodes <- names(result_path$dag)
        
        extra_nodes <- setdiff(path_nodes, leaf_nodes)
        
        cat("Nodes kept by path filtering but removed by leaf removal:", length(extra_nodes), "\n")
        if (length(extra_nodes) > 0 && length(extra_nodes) <= 20) {
            cat("Sample nodes:\n")
            for (node in head(extra_nodes, 20)) {
                cat("  -", node, "\n")
            }
        }
        
        # Analyze degree of these extra nodes in original graph
        edges_df <- as.data.frame(dagitty::edges(dag))
        all_nodes <- names(dag)
        nodes_df <- data.frame(name = all_nodes, stringsAsFactors = FALSE)
        ig <- graph_from_data_frame(edges_df[, c("v", "w")], directed = TRUE, vertices = nodes_df)
        
        cat("\nDegree analysis of extra nodes (in original graph):\n")
        for (node in head(extra_nodes, 10)) {
            if (node %in% V(ig)$name) {
                idx <- which(V(ig)$name == node)
                deg_in <- degree(ig, idx, mode = "in")
                deg_out <- degree(ig, idx, mode = "out")
                deg_total <- degree(ig, idx, mode = "all")
                cat("  ", node, ": in=", deg_in, " out=", deg_out, " total=", deg_total, "\n", sep="")
            }
        }
    }
} else {
    cat("✅ Path filtering is more restrictive than leaf removal (as expected)\n")
}

cat("\n=== RECOMMENDATION ===\n")
if (result_path$final_nodes > result_leaf$final_nodes) {
    cat("The path filtering should be combined with leaf removal.\n")
    cat("Suggested approach:\n")
    cat("  1. Apply path filtering first\n")
    cat("  2. Then apply leaf removal to the filtered graph\n")
    cat("  3. This will remove leaf nodes that are on paths but still have degree=1\n")
}

cat("\n=== TEST COMPLETE ===\n")

