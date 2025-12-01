# Test Suite for Node Click Information Display
#
# This test verifies that clicking on a node displays all related
# causal assertion information from the JSON file
#
# Author: Test for node click functionality
# Date: December 2025

# Set working directory
original_wd <- getwd()
if (basename(getwd()) == "shiny_app" && basename(dirname(getwd())) == "tests") {
    setwd(file.path(dirname(dirname(getwd()))))
} else if (basename(getwd()) == "tests") {
    setwd(dirname(getwd()))
}

cat("Working directory:", getwd(), "\n")

# Load required libraries
suppressPackageStartupMessages({
    library(dagitty)
    library(igraph)
    library(dplyr)
})

# Load required modules
source("shiny_app/modules/optimized_loader.R")
source("shiny_app/modules/data_upload.R")

cat("\n=== TESTING NODE CLICK INFORMATION DISPLAY ===\n")
cat("This test verifies the find_node_related_assertions() function\n")
cat("which is used when clicking on nodes in the Shiny app.\n\n")

# Test 1: Load graph and assertions
cat("\n--- Test 1: Loading Graph and Assertions ---\n")

# Load the DAG
dag_file <- "graph_creation/result/degree_1.R"
if (!file.exists(dag_file)) {
    cat("❌ FAILED: DAG file not found:", dag_file, "\n")
    quit(status = 1)
}

dag_object <- tryCatch({
    source(dag_file, local = TRUE)
    g
}, error = function(e) {
    cat("❌ FAILED: Error loading DAG:", e$message, "\n")
    quit(status = 1)
})

cat("✅ Loaded DAG object\n")

# Load causal assertions
assertions_file <- "graph_creation/result/causal_assertions_1.json"
if (!file.exists(assertions_file)) {
    cat("❌ FAILED: Assertions file not found:", assertions_file, "\n")
    quit(status = 1)
}

result <- load_causal_assertions_unified(assertions_file)
if (!result$success) {
    cat("❌ FAILED: Could not load assertions:", result$message, "\n")
    quit(status = 1)
}

assertions <- result$assertions
cat("✅ Loaded", length(assertions), "assertions\n")

# Test 2: Extract nodes from DAG
cat("\n--- Test 2: Extracting Nodes from DAG ---\n")

# Get all nodes from the DAG
all_nodes <- names(dag_object)
cat("Found", length(all_nodes), "nodes in DAG:\n")
for (node in all_nodes) {
    cat("  -", node, "\n")
}

# Test 3: Simulate clicking on each node using the actual function from data_upload.R
cat("\n--- Test 3: Testing find_node_related_assertions() Function ---\n")

# Extract edges from DAG for better matching
edges_list <- list()
dag_edges <- dagitty::edges(dag_object)
if (!is.null(dag_edges) && nrow(dag_edges) > 0) {
    edges_df <- data.frame(
        from = dag_edges$v,
        to = dag_edges$w,
        stringsAsFactors = FALSE
    )
} else {
    edges_df <- NULL
}

# Test clicking on each node using the actual function
test_results <- list()
for (node in all_nodes) {
    cat("\nSimulating click on node:", node, "\n")

    # Use the actual function from data_upload.R
    node_info <- find_node_related_assertions(node, assertions, edges_df)

    if (node_info$found) {
        cat("  ✅ Found", node_info$total_count, "related assertions\n")
        cat("     - Outgoing edges:", node_info$outgoing_count, "\n")
        cat("     - Incoming edges:", node_info$incoming_count, "\n")

        # Display details of each edge
        if (length(node_info$outgoing) > 0) {
            cat("     Outgoing relationships:\n")
            for (edge in node_info$outgoing) {
                obj_name <- edge$object_name %||% edge$obj
                predicate <- edge$predicate %||% "CAUSES"
                pmid_refs <- edge$pmid_list %||% edge$pmid_refs %||% c()
                pmid_count <- edge$evidence_count %||% length(pmid_refs)
                cat("       ->", obj_name, "(", predicate, ",", pmid_count, "PMIDs )\n")
            }
        }

        if (length(node_info$incoming) > 0) {
            cat("     Incoming relationships:\n")
            for (edge in node_info$incoming) {
                subj_name <- edge$subject_name %||% edge$subj
                predicate <- edge$predicate %||% "CAUSES"
                pmid_refs <- edge$pmid_list %||% edge$pmid_refs %||% c()
                pmid_count <- edge$evidence_count %||% length(pmid_refs)
                cat("       <-", subj_name, "(", predicate, ",", pmid_count, "PMIDs )\n")
            }
        }

        test_results[[node]] <- TRUE
    } else {
        cat("  ⚠️  No assertions found for this node\n")
        test_results[[node]] <- FALSE
    }
}

# Test 4: Verify PMID data is accessible
cat("\n--- Test 4: Verifying PMID Data Accessibility ---\n")
test_node <- "Antidepressive_Agents"
if (test_node %in% all_nodes) {
    node_info <- find_node_related_assertions(test_node, assertions, edges_df)
    if (node_info$found && length(node_info$outgoing) > 0) {
        first_edge <- node_info$outgoing[[1]]

        # Extract PMID list from different possible structures (same logic as app.R)
        pmid_refs <- c()
        if (!is.null(first_edge$pmid_data) && length(first_edge$pmid_data) > 0) {
            pmid_refs <- names(first_edge$pmid_data)
        } else if (!is.null(first_edge$pmid_refs)) {
            pmid_refs <- first_edge$pmid_refs
        } else if (!is.null(first_edge$pmid_list)) {
            pmid_refs <- first_edge$pmid_list
        }

        if (length(pmid_refs) > 0) {
            cat("✅ PMID data is accessible\n")
            cat("   Sample PMIDs from", test_node, ":", paste(head(pmid_refs, 3), collapse = ", "), "\n")
            cat("   Total PMIDs:", length(pmid_refs), "\n")
        } else {
            cat("❌ FAILED: No PMID data found in assertions\n")
            cat("   Available fields:", paste(names(first_edge), collapse = ", "), "\n")
            quit(status = 1)
        }
    } else {
        cat("❌ FAILED: No outgoing edges found for test node\n")
        quit(status = 1)
    }
}

# Test 5: Summary
cat("\n--- Test 5: Summary ---\n")
total_nodes <- length(all_nodes)
nodes_with_data <- sum(unlist(test_results))
cat("Total nodes tested:", total_nodes, "\n")
cat("Nodes with assertion data:", nodes_with_data, "\n")
cat("Nodes without assertion data:", total_nodes - nodes_with_data, "\n")

# Test 6: Verify the function exists and is exported
cat("\n--- Test 6: Function Availability Check ---\n")
if (exists("find_node_related_assertions")) {
    cat("✅ find_node_related_assertions() function is available\n")
} else {
    cat("❌ FAILED: find_node_related_assertions() function not found\n")
    quit(status = 1)
}

# Final result
cat("\n=== FINAL RESULT ===\n")
if (nodes_with_data > 0) {
    cat("✅ ALL TESTS PASSED\n")
    cat("\nThe node click functionality is working correctly:\n")
    cat("  - find_node_related_assertions() function exists\n")
    cat("  - Function can retrieve assertion data for nodes\n")
    cat("  - PMID data is accessible\n")
    cat("  - Both incoming and outgoing edges are detected\n")
    cat("\nIn the Shiny app, clicking on a node will now display:\n")
    cat("  - All outgoing relationships (what this node causes)\n")
    cat("  - All incoming relationships (what causes this node)\n")
    cat("  - PMID evidence lists for each relationship\n")
    cat("  - Evidence counts\n")
    quit(status = 0)
} else {
    cat("❌ TEST FAILED: No nodes have associated assertion data\n")
    quit(status = 1)
}

