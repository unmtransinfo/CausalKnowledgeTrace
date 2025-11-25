# Test Suite for Refactored Shiny Application
#
# This test suite verifies that all refactored R modules work correctly
# and that the Shiny application can be loaded without errors.
#
# Author: Created for R refactoring validation
# Date: February 2025

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

cat("Working directory set to:", getwd(), "\n")

# Test function to check if a file can be sourced without errors
test_source_file <- function(file_path, description = NULL) {
    if (is.null(description)) {
        description <- basename(file_path)
    }
    
    cat("Testing:", description, "...")
    
    tryCatch({
        source(file_path, local = TRUE)
        cat(" ✓ PASSED\n")
        return(TRUE)
    }, error = function(e) {
        cat(" ✗ FAILED\n")
        cat("  Error:", e$message, "\n")
        return(FALSE)
    })
}

# Test function to check if required packages are available
test_required_packages <- function() {
    cat("Testing required packages...\n")
    
    required_packages <- c("shiny", "shinydashboard", "shinyjs", "visNetwork", 
                          "dagitty", "DT", "yaml", "igraph")
    
    missing_packages <- character(0)
    
    for (pkg in required_packages) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
            missing_packages <- c(missing_packages, pkg)
        }
    }
    
    if (length(missing_packages) > 0) {
        cat("  ✗ Missing packages:", paste(missing_packages, collapse = ", "), "\n")
        return(FALSE)
    } else {
        cat("  ✓ All required packages available\n")
        return(TRUE)
    }
}

# Test function to check if directories exist
test_directory_structure <- function() {
    cat("Testing directory structure...\n")
    
    required_dirs <- c("ui", "server", "utils", "analysis", "modules")
    missing_dirs <- character(0)
    
    for (dir in required_dirs) {
        if (!dir.exists(dir)) {
            missing_dirs <- c(missing_dirs, dir)
        }
    }
    
    if (length(missing_dirs) > 0) {
        cat("  ✗ Missing directories:", paste(missing_dirs, collapse = ", "), "\n")
        return(FALSE)
    } else {
        cat("  ✓ All required directories exist\n")
        return(TRUE)
    }
}

# Test individual refactored components
test_refactored_components <- function() {
    cat("\nTesting refactored components:\n")
    cat("=" %R% 40, "\n")
    
    results <- list()
    
    # Test UI components
    if (file.exists("ui/ui_components.R")) {
        results$ui_components <- test_source_file("ui/ui_components.R", "UI Components")
    }
    
    # Test server components
    if (file.exists("server/server_logic.R")) {
        results$server_logic <- test_source_file("server/server_logic.R", "Server Logic")
    }
    
    if (file.exists("server/file_operations.R")) {
        results$file_operations <- test_source_file("server/file_operations.R", "File Operations")
    }
    
    if (file.exists("server/causal_analysis.R")) {
        results$causal_analysis <- test_source_file("server/causal_analysis.R", "Causal Analysis")
    }
    
    # Test utility components
    if (file.exists("utils/file_upload.R")) {
        results$file_upload <- test_source_file("utils/file_upload.R", "File Upload Utils")
    }
    
    if (file.exists("utils/data_validation.R")) {
        results$data_validation <- test_source_file("utils/data_validation.R", "Data Validation Utils")
    }
    
    # Test analysis components
    if (file.exists("analysis/graph_statistics.R")) {
        results$graph_statistics <- test_source_file("analysis/graph_statistics.R", "Graph Statistics")
    }
    
    if (file.exists("analysis/cycle_detection.R")) {
        results$cycle_detection <- test_source_file("analysis/cycle_detection.R", "Cycle Detection")
    }
    
    # Test refactored modules
    if (file.exists("modules/config_ui.R")) {
        results$config_ui <- test_source_file("modules/config_ui.R", "Config UI")
    }
    
    if (file.exists("modules/config_validation.R")) {
        results$config_validation <- test_source_file("modules/config_validation.R", "Config Validation")
    }
    
    if (file.exists("modules/config_processing.R")) {
        results$config_processing <- test_source_file("modules/config_processing.R", "Config Processing")
    }
    
    if (file.exists("modules/statistics_refactored.R")) {
        results$statistics_refactored <- test_source_file("modules/statistics_refactored.R", "Statistics (Refactored)")
    }
    
    if (file.exists("modules/data_upload_refactored.R")) {
        results$data_upload_refactored <- test_source_file("modules/data_upload_refactored.R", "Data Upload (Refactored)")
    }
    
    if (file.exists("modules/graph_config_refactored.R")) {
        results$graph_config_refactored <- test_source_file("modules/graph_config_refactored.R", "Graph Config (Refactored)")
    }
    
    return(results)
}

# Test main application files
test_main_app_files <- function() {
    cat("\nTesting main application files:\n")
    cat("=" %R% 40, "\n")
    
    results <- list()
    
    # Test refactored app
    if (file.exists("app_refactored.R")) {
        results$app_refactored <- test_source_file("app_refactored.R", "Refactored App")
    }
    
    # Test if original app still works (backward compatibility)
    if (file.exists("app.R")) {
        results$app_original <- test_source_file("app.R", "Original App")
    }
    
    return(results)
}

# Test function availability
test_function_availability <- function() {
    cat("\nTesting function availability:\n")
    cat("=" %R% 40, "\n")
    
    # Load required libraries
    suppressMessages({
        library(shiny)
        library(shinydashboard)
        library(dagitty)
    })
    
    # Source key files to test function availability
    if (file.exists("utils/file_upload.R")) {
        source("utils/file_upload.R", local = TRUE)
    }
    
    if (file.exists("utils/data_validation.R")) {
        source("utils/data_validation.R", local = TRUE)
    }
    
    # Test key functions
    functions_to_test <- c(
        "scan_for_dag_files",
        "load_dag_from_file", 
        "validate_dag_object",
        "create_network_data",
        "create_example_dag"
    )
    
    results <- list()
    
    for (func_name in functions_to_test) {
        cat("Testing function:", func_name, "...")
        
        if (exists(func_name)) {
            cat(" ✓ EXISTS\n")
            results[[func_name]] <- TRUE
        } else {
            cat(" ✗ MISSING\n")
            results[[func_name]] <- FALSE
        }
    }
    
    return(results)
}

# Main test runner
run_all_tests <- function() {
    cat("R MODULES REFACTORING TEST SUITE\n")
    cat("=" %R% 50, "\n")
    cat("Date:", Sys.time(), "\n")
    cat("Working directory:", getwd(), "\n\n")
    
    # Initialize results
    all_results <- list()
    
    # Test 1: Required packages
    all_results$packages <- test_required_packages()
    
    # Test 2: Directory structure
    all_results$directories <- test_directory_structure()
    
    # Test 3: Refactored components
    all_results$components <- test_refactored_components()
    
    # Test 4: Main app files
    all_results$main_apps <- test_main_app_files()
    
    # Test 5: Function availability
    all_results$functions <- test_function_availability()
    
    # Summary
    cat("\n")
    cat("TEST SUMMARY\n")
    cat("=" %R% 50, "\n")
    
    # Count successes and failures
    total_tests <- 0
    passed_tests <- 0
    
    for (category in names(all_results)) {
        category_results <- all_results[[category]]
        
        if (is.logical(category_results)) {
            total_tests <- total_tests + 1
            if (category_results) passed_tests <- passed_tests + 1
        } else if (is.list(category_results)) {
            for (test_name in names(category_results)) {
                total_tests <- total_tests + 1
                if (category_results[[test_name]]) passed_tests <- passed_tests + 1
            }
        }
    }
    
    cat("Total tests:", total_tests, "\n")
    cat("Passed:", passed_tests, "\n")
    cat("Failed:", total_tests - passed_tests, "\n")
    cat("Success rate:", round((passed_tests / total_tests) * 100, 1), "%\n")
    
    if (passed_tests == total_tests) {
        cat("\n🎉 ALL TESTS PASSED! Refactoring was successful.\n")
        cat("The Shiny application should run correctly with the refactored modules.\n")
    } else {
        cat("\n⚠️  Some tests failed. Please review the issues above.\n")
        cat("The application may not run correctly until these issues are resolved.\n")
    }
    
    return(all_results)
}

# Helper function for string repetition (if not available)
if (!exists("%R%")) {
    `%R%` <- function(string, times) {
        paste(rep(string, times), collapse = "")
    }
}

# Run the tests
if (interactive()) {
    cat("Running R modules refactoring tests...\n\n")
    test_results <- run_all_tests()
} else {
    # If running as script, run tests and exit with appropriate code
    test_results <- run_all_tests()
    
    # Count failures
    total_failures <- 0
    for (category in names(test_results)) {
        category_results <- test_results[[category]]
        if (is.logical(category_results) && !category_results) {
            total_failures <- total_failures + 1
        } else if (is.list(category_results)) {
            for (result in category_results) {
                if (is.logical(result) && !result) {
                    total_failures <- total_failures + 1
                }
            }
        }
    }
    
    # Exit with appropriate code
    if (total_failures == 0) {
        quit(status = 0)  # Success
    } else {
        quit(status = 1)  # Failure
    }
}
