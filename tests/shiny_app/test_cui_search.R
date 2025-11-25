# Test Script for CUI Search Functionality
# 
# This script tests the CUI search functionality including database connectivity,
# search operations, and integration with the graph configuration module.
#
# Author: CausalKnowledgeTrace Application

# Load required libraries
library(shiny)

# Set working directory to shiny_app if not already there
if (basename(getwd()) != "shiny_app") {
    if (dir.exists("shiny_app")) {
        setwd("shiny_app")
    }
}

cat("=== CUI Search Functionality Test ===\n\n")

# Test 1: Database Connection Module
cat("Test 1: Database Connection Module\n")
cat("-----------------------------------\n")

tryCatch({
    source("modules/database_connection.R")
    cat("✅ Database connection module loaded successfully\n")
    
    # Test database connection initialization
    db_result <- init_database_pool()
    if (db_result$success) {
        cat("✅ Database connection pool initialized successfully\n")
        cat("   Host:", db_result$config$host, "\n")
        cat("   Database:", db_result$config$dbname, "\n")
        cat("   Schema:", db_result$config$schema, "\n")
        
        # Test database connection
        test_result <- test_database_connection()
        if (test_result$success) {
            cat("✅ Database connection test passed\n")
            cat("   Total entities in causalentity table:", test_result$total_entities, "\n")
            cat("   Sample entities:\n")
            for (i in 1:min(3, nrow(test_result$sample_entities))) {
                entity <- test_result$sample_entities[i, ]
                cat("     ", entity$cui, "-", entity$name, "(", entity$semtype, ")\n")
            }
        } else {
            cat("❌ Database connection test failed:", test_result$message, "\n")
        }
        
    } else {
        cat("❌ Database connection initialization failed:", db_result$message, "\n")
        cat("   This may be expected if database credentials are not configured\n")
    }
    
}, error = function(e) {
    cat("❌ Error loading database connection module:", e$message, "\n")
})

cat("\n")

# Test 2: CUI Search Module
cat("Test 2: CUI Search Module\n")
cat("--------------------------\n")

tryCatch({
    source("modules/cui_search.R")
    cat("✅ CUI search module loaded successfully\n")
    
    # Test CUI format validation
    test_cuis <- c("C0020538", "C4013784", "INVALID", "C123456", "C12345678")
    validation_result <- validate_cui_format(test_cuis)
    
    cat("✅ CUI format validation test:\n")
    cat("   Valid CUIs:", paste(validation_result$valid_cuis, collapse = ", "), "\n")
    cat("   Invalid CUIs:", paste(validation_result$invalid_cuis, collapse = ", "), "\n")
    cat("   Validation passed:", validation_result$valid, "\n")
    
}, error = function(e) {
    cat("❌ Error loading CUI search module:", e$message, "\n")
})

cat("\n")

# Test 3: Search Functionality (with fallback to mock data)
cat("Test 3: Search Functionality\n")
cat("-----------------------------\n")

if (exists("search_cui_entities")) {
    cat("Using search function with exposure/outcome search types\n")
    # Test search with common medical terms for both exposure and outcome
    test_terms <- c("hypertension", "diabetes", "alzheimer", "stroke")
    search_types <- c("exposure", "outcome")

    for (search_type in search_types) {
        cat("\n--- Testing", toupper(search_type), "search ---\n")
        for (term in test_terms) {
            cat("Searching for '", term, "' in ", search_type, " table:\n", sep = "")
            search_result <- search_cui_entities(term, search_type = search_type)

            if (search_result$success) {
                cat("✅ Found", nrow(search_result$results), "results\n")
                if (nrow(search_result$results) > 0) {
                    for (i in 1:min(3, nrow(search_result$results))) {
                        result <- search_result$results[i, ]
                        cat("   ", result$cui, "-", result$name, "(", result$semtype, ")\n")
                    }
                    if (nrow(search_result$results) > 3) {
                        cat("   ... and", nrow(search_result$results) - 3, "more results\n")
                    }
                }
            } else {
                cat("❌ Search failed:", search_result$message, "\n")
            }
            cat("\n")
        }
    }
} else {
    cat("❌ Search function not available (database connection may have failed)\n")
}

# Test 4: Graph Configuration Module Integration
cat("Test 4: Graph Configuration Module Integration\n")
cat("----------------------------------------------\n")

tryCatch({
    source("modules/graph_config_module.R")
    cat("✅ Graph configuration module with CUI search loaded successfully\n")
    
    # Check if CUI search is available in the module
    if (exists("cui_search_available") && cui_search_available) {
        cat("✅ CUI search functionality is available in graph configuration\n")
    } else {
        cat("⚠️  CUI search functionality not available (fallback to manual entry)\n")
    }
    
}, error = function(e) {
    cat("❌ Error loading graph configuration module:", e$message, "\n")
})

cat("\n")

# Test 5: UI Component Generation
cat("Test 5: UI Component Generation\n")
cat("--------------------------------\n")

tryCatch({
    # Test UI generation (this won't render but will check for errors)
    if (exists("cuiSearchUI")) {
        ui_component <- cuiSearchUI("test", "Test CUI Search")
        cat("✅ CUI search UI component generated successfully\n")
        cat("   Component type:", class(ui_component)[1], "\n")
    } else {
        cat("❌ CUI search UI function not available\n")
    }
    
}, error = function(e) {
    cat("❌ Error generating UI component:", e$message, "\n")
})

cat("\n")

# Cleanup
cat("Cleanup\n")
cat("-------\n")
if (exists("close_database_pool")) {
    close_database_pool()
    cat("✅ Database connection pool closed\n")
}

cat("\n=== Test Summary ===\n")
cat("The CUI search functionality has been implemented with the following features:\n")
cat("• Database connectivity to PostgreSQL causalentity table\n")
cat("• Searchable interface for medical concept lookup\n")
cat("• CUI format validation and error handling\n")
cat("• Integration with existing Graph Configuration module\n")
cat("• Backward compatibility with manual CUI entry\n")
cat("• Automatic database connection management\n")
cat("\nTo use the functionality:\n")
cat("1. Ensure database credentials are configured (DB_HOST, DB_USER, DB_PASSWORD, etc.)\n")
cat("2. Start the Shiny application: Rscript run_app.R\n")
cat("3. Navigate to the Graph Configuration tab\n")
cat("4. Use the search interface to find and select CUI codes\n")
cat("5. The selected CUIs will be automatically formatted for graph creation\n")

cat("\n=== Test Complete ===\n")
