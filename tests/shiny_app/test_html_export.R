# Test HTML Export Functionality
# This script tests the JSON to HTML conversion with sample data

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

# Load required libraries and modules
source("modules/json_to_html.R")
library(jsonlite)

# Create sample test data
create_sample_json_data <- function() {
    sample_data <- list(
        assertions = list(
            list(
                subj = "Hypertension",
                predicate = "CAUSES",
                obj = "Alzheimers",
                subj_cui = "C0020538",
                obj_cui = "C0002395",
                pmid_refs = c("12345678", "23456789"),
                ev_count = 2
            ),
            list(
                subj = "Diabetes",
                predicate = "ASSOCIATED_WITH",
                obj = "Hypertension",
                subj_cui = "C0011847",
                obj_cui = "C0020538",
                pmid_refs = c("34567890", "45678901"),
                ev_count = 2
            ),
            list(
                subj = "Oxidative_Stress",
                predicate = "CAUSES",
                obj = "Alzheimers",
                subj_cui = "C0242606",
                obj_cui = "C0002395",
                pmid_refs = c("56789012"),
                ev_count = 1
            )
        ),
        pmid_sentences = list(
            "12345678" = list(
                sentences = c("Hypertension is a major risk factor for Alzheimer's disease."),
                year = 2020
            ),
            "23456789" = list(
                sentences = c("Studies show a strong correlation between high blood pressure and cognitive decline."),
                year = 2021
            ),
            "34567890" = list(
                sentences = c("Diabetes and hypertension often co-occur in patients."),
                year = 2019
            ),
            "45678901" = list(
                sentences = c("The metabolic syndrome includes both diabetes and hypertension."),
                year = 2022
            ),
            "56789012" = list(
                sentences = c("Oxidative stress contributes to neurodegeneration in Alzheimer's disease."),
                year = 2021
            )
        )
    )
    
    return(sample_data)
}

# Test basic HTML conversion
test_basic_conversion <- function() {
    cat("Testing basic HTML conversion...\n")
    
    sample_data <- create_sample_json_data()
    
    tryCatch({
        html_output <- convert_json_to_html(
            sample_data,
            title = "Test Causal Assertions Report"
        )
        
        # Check if HTML was generated
        if (is.null(html_output) || nchar(html_output) == 0) {
            stop("HTML output is empty")
        }
        
        # Check for essential HTML elements
        essential_elements <- c(
            "<!DOCTYPE html>",
            "<html lang='en'>",
            "<title>Test Causal Assertions Report</title>",
            "Hypertension",
            "Alzheimers",
            "CAUSES",
            "pmid-link"
        )
        
        for (element in essential_elements) {
            if (!grepl(element, html_output, fixed = TRUE)) {
                stop(paste("Missing essential element:", element))
            }
        }
        
        cat("✓ Basic HTML conversion test passed\n")
        cat("  - HTML length:", nchar(html_output), "characters\n")
        cat("  - Contains all essential elements\n")
        
        return(TRUE)
        
    }, error = function(e) {
        cat("✗ Basic HTML conversion test failed:", e$message, "\n")
        return(FALSE)
    })
}

# Test optimized HTML generation
test_optimized_conversion <- function() {
    cat("Testing optimized HTML conversion...\n")
    
    sample_data <- create_sample_json_data()
    
    tryCatch({
        html_output <- optimized_html_generation(
            sample_data,
            title = "Test Optimized Report",
            max_assertions_per_section = 1000,
            enable_search = TRUE
        )
        
        # Check if HTML was generated
        if (is.null(html_output) || nchar(html_output) == 0) {
            stop("Optimized HTML output is empty")
        }
        
        # Check for search functionality
        search_elements <- c(
            "searchInput",
            "predicateFilter",
            "performSearch",
            "clearSearch"
        )
        
        for (element in search_elements) {
            if (!grepl(element, html_output, fixed = TRUE)) {
                stop(paste("Missing search element:", element))
            }
        }
        
        cat("✓ Optimized HTML conversion test passed\n")
        cat("  - HTML length:", nchar(html_output), "characters\n")
        cat("  - Contains search functionality\n")
        
        return(TRUE)
        
    }, error = function(e) {
        cat("✗ Optimized HTML conversion test failed:", e$message, "\n")
        return(FALSE)
    })
}

# Test empty data handling
test_empty_data <- function() {
    cat("Testing empty data handling...\n")
    
    tryCatch({
        # Test with null data
        html_output1 <- convert_json_to_html(NULL)
        if (!grepl("No data available", html_output1)) {
            stop("Empty data not handled correctly for NULL input")
        }
        
        # Test with empty list
        html_output2 <- convert_json_to_html(list())
        if (!grepl("No data available", html_output2)) {
            stop("Empty data not handled correctly for empty list")
        }
        
        # Test with empty assertions
        empty_data <- list(assertions = list(), pmid_sentences = list())
        html_output3 <- convert_json_to_html(empty_data)
        if (!grepl("No causal assertions data found", html_output3)) {
            stop("Empty assertions not handled correctly")
        }
        
        cat("✓ Empty data handling test passed\n")
        return(TRUE)
        
    }, error = function(e) {
        cat("✗ Empty data handling test failed:", e$message, "\n")
        return(FALSE)
    })
}

# Test file writing
test_file_writing <- function() {
    cat("Testing file writing functionality...\n")
    
    sample_data <- create_sample_json_data()
    temp_json_file <- tempfile(fileext = ".json")
    temp_html_file <- tempfile(fileext = ".html")
    
    tryCatch({
        # Write sample data to JSON file
        jsonlite::write_json(sample_data, temp_json_file, pretty = TRUE, auto_unbox = TRUE)
        
        # Test fast_json_to_html function
        result <- fast_json_to_html(temp_json_file, temp_html_file, max_assertions = 10)
        
        if (!result$success) {
            stop(paste("File writing failed:", result$message))
        }
        
        # Check if HTML file was created
        if (!file.exists(temp_html_file)) {
            stop("HTML file was not created")
        }
        
        # Check file size
        file_size <- file.info(temp_html_file)$size
        if (file_size == 0) {
            stop("HTML file is empty")
        }
        
        cat("✓ File writing test passed\n")
        cat("  - HTML file created successfully\n")
        cat("  - File size:", round(file_size / 1024, 2), "KB\n")
        
        # Clean up
        unlink(c(temp_json_file, temp_html_file))
        
        return(TRUE)
        
    }, error = function(e) {
        cat("✗ File writing test failed:", e$message, "\n")
        # Clean up on error
        unlink(c(temp_json_file, temp_html_file))
        return(FALSE)
    })
}

# Run all tests
run_all_tests <- function() {
    cat("=== JSON to HTML Export Tests ===\n\n")
    
    tests <- list(
        "Basic Conversion" = test_basic_conversion,
        "Optimized Conversion" = test_optimized_conversion,
        "Empty Data Handling" = test_empty_data,
        "File Writing" = test_file_writing
    )
    
    results <- list()
    
    for (test_name in names(tests)) {
        cat("Running", test_name, "test...\n")
        results[[test_name]] <- tests[[test_name]]()
        cat("\n")
    }
    
    # Summary
    cat("=== Test Summary ===\n")
    passed <- sum(unlist(results))
    total <- length(results)
    
    for (test_name in names(results)) {
        status <- if (results[[test_name]]) "✓ PASSED" else "✗ FAILED"
        cat(test_name, ":", status, "\n")
    }
    
    cat("\nOverall:", passed, "out of", total, "tests passed\n")
    
    if (passed == total) {
        cat("🎉 All tests passed! HTML export functionality is working correctly.\n")
    } else {
        cat("⚠️  Some tests failed. Please check the implementation.\n")
    }
    
    return(passed == total)
}

# Run the tests if this script is executed directly
if (!interactive()) {
    run_all_tests()
}
