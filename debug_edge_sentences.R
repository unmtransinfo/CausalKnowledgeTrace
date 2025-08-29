#!/usr/bin/env Rscript
# Debug Edge Sentences Issue
# 
# This script specifically tests the exact edge that's showing "No sentences available"
# to identify where the issue is occurring.

library(jsonlite)

cat("=== Debugging Edge Sentences Issue ===\n\n")

# Test both the UI names and the data names
from_node_ui <- "Overweight"
to_node_ui <- "Hypertension"  # What the UI shows
from_node_data <- "Overweight"
to_node_data <- "Hypertensive disease"  # What's in the data
test_pmid <- "10726145"

cat("Testing UI edge:", from_node_ui, "->", to_node_ui, "\n")
cat("Testing data edge:", from_node_data, "->", to_node_data, "\n")
cat("Expected PMID:", test_pmid, "\n\n")

# Load the k_hops=2 file (where this edge should be)
file_path <- "graph_creation/result/causal_assertions_2.json"

if (!file.exists(file_path)) {
    cat("✗ File not found:", file_path, "\n")
    quit(status = 1)
}

cat("1. Loading causal assertions data...\n")
tryCatch({
    data <- jsonlite::fromJSON(file_path, simplifyDataFrame = FALSE)
    cat("  ✓ Loaded", length(data), "assertions\n")
    
    # Search for the specific edge manually
    cat("\n2. Manual search for edge...\n")
    found_assertion <- NULL
    
    for (i in seq_along(data)) {
        assertion <- data[[i]]
        
        # Check if this matches our edge (exact match with data names)
        subject_match <- assertion$subject_name == from_node_data
        object_match <- assertion$object_name == to_node_data
        
        if (subject_match && object_match) {
            cat("  ✓ Found matching assertion:\n")
            cat("    Subject:", assertion$subject_name, "\n")
            cat("    Object:", assertion$object_name, "\n")
            cat("    Relationship degree:", assertion$relationship_degree, "\n")
            
            # Check PMID data structure
            if (!is.null(assertion$pmid_data)) {
                pmids <- names(assertion$pmid_data)
                cat("    PMIDs available:", length(pmids), "\n")
                
                # Check if our test PMID is there
                if (test_pmid %in% pmids) {
                    cat("    ✓ Test PMID", test_pmid, "found\n")
                    sentences <- assertion$pmid_data[[test_pmid]]$sentences
                    if (!is.null(sentences) && length(sentences) > 0) {
                        cat("    ✓ Sentences found:", length(sentences), "\n")
                        cat("    First sentence:", substr(sentences[1], 1, 100), "...\n")
                    } else {
                        cat("    ✗ No sentences for PMID", test_pmid, "\n")
                    }
                } else {
                    cat("    ✗ Test PMID", test_pmid, "not found\n")
                    cat("    Available PMIDs:", paste(head(pmids, 5), collapse = ", "), "...\n")
                }
            } else {
                cat("    ✗ No pmid_data found\n")
            }
            
            found_assertion <- assertion
            break
        }
    }
    
    if (is.null(found_assertion)) {
        cat("  ✗ No matching assertion found\n")
        quit(status = 1)
    }
    
}, error = function(e) {
    cat("  ✗ Error loading data:", e$message, "\n")
    quit(status = 1)
})

# Test the find_edge_pmid_data function
cat("\n3. Testing find_edge_pmid_data function...\n")

tryCatch({
    setwd("shiny_app")
    source("modules/data_upload.R")
    
    # Test the function with UI names (what the app actually uses)
    cat("  Testing with UI names:", from_node_ui, "->", to_node_ui, "\n")
    result_ui <- find_edge_pmid_data(from_node_ui, to_node_ui, data)

    cat("  UI Function result:\n")
    cat("    Found:", result_ui$found, "\n")
    cat("    Message:", result_ui$message, "\n")

    if (!result_ui$found) {
        cat("  ✗ UI names don't work - this is the problem!\n")

        # Test with data names
        cat("  Testing with data names:", from_node_data, "->", to_node_data, "\n")
        result_data <- find_edge_pmid_data(from_node_data, to_node_data, data)

        cat("  Data Function result:\n")
        cat("    Found:", result_data$found, "\n")
        cat("    Message:", result_data$message, "\n")

        result <- result_data  # Use data result for further testing
    } else {
        result <- result_ui
    }
    
    cat("  Function result:\n")
    cat("    Found:", result$found, "\n")
    cat("    Message:", result$message, "\n")
    
    if (result$found) {
        cat("    PMID list length:", length(result$pmid_list), "\n")
        cat("    Sentence data entries:", length(result$sentence_data), "\n")
        
        # Check if our test PMID is in the result
        if (test_pmid %in% result$pmid_list) {
            cat("    ✓ Test PMID", test_pmid, "in result\n")
            
            # Check sentence data for this PMID
            if (test_pmid %in% names(result$sentence_data)) {
                sentences <- result$sentence_data[[test_pmid]]
                if (!is.null(sentences) && length(sentences) > 0) {
                    cat("    ✓ Sentences found in result:", length(sentences), "\n")
                    cat("    First sentence:", substr(sentences[1], 1, 100), "...\n")
                } else {
                    cat("    ✗ No sentences in result for PMID", test_pmid, "\n")
                }
            } else {
                cat("    ✗ PMID", test_pmid, "not in sentence_data\n")
                cat("    Available in sentence_data:", paste(names(result$sentence_data)[1:5], collapse = ", "), "...\n")
            }
        } else {
            cat("    ✗ Test PMID", test_pmid, "not in result pmid_list\n")
            cat("    PMIDs in result:", paste(head(result$pmid_list, 5), collapse = ", "), "...\n")
        }
        
        # Test the exact structure the UI expects
        cat("\n4. Testing UI data structure...\n")
        cat("    pmid_list type:", class(result$pmid_list), "\n")
        cat("    sentence_data type:", class(result$sentence_data), "\n")
        
        # Simulate what the UI does
        if (length(result$pmid_list) > 0) {
            first_pmid <- result$pmid_list[1]
            cat("    Testing first PMID:", first_pmid, "\n")
            
            # This is what the UI code does
            sentences <- result$sentence_data[[first_pmid]]
            cat("    UI access result:", class(sentences), "length:", length(sentences %||% c()), "\n")
            
            if (!is.null(sentences) && length(sentences) > 0) {
                cat("    ✓ UI would show sentences\n")
            } else {
                cat("    ✗ UI would show 'No sentences available'\n")
            }
        }
    } else {
        cat("    ✗ Function did not find the edge\n")
    }
    
    setwd("..")
    
}, error = function(e) {
    cat("  ✗ Error testing function:", e$message, "\n")
    if (getwd() != dirname(getwd())) setwd("..")
})

cat("\n=== Debug Complete ===\n")
cat("This should help identify exactly where the sentence data is being lost.\n")
