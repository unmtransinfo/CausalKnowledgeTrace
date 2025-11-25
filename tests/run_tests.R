#!/usr/bin/env Rscript
# Test Runner for CausalKnowledgeTrace
# 
# This script runs all tests in the tests directory and provides a summary report.
# Tests are organized into categories:
#   - integration: Full pipeline tests (e.g., graph creation)
#   - shiny_app: Shiny application component tests
#   - unit: Unit tests for individual functions
#
# Usage:
#   Rscript tests/run_tests.R [options]
#
# Options:
#   --category=<name>  Run only tests in specified category (integration, shiny_app, unit)
#   --test=<file>      Run only a specific test file
#   --skip-integration Skip integration tests (they can be slow)
#   --verbose          Show detailed output from each test
#   --help             Show this help message
#
# Examples:
#   Rscript tests/run_tests.R                           # Run all tests
#   Rscript tests/run_tests.R --category=shiny_app     # Run only shiny_app tests
#   Rscript tests/run_tests.R --skip-integration       # Skip integration tests
#   Rscript tests/run_tests.R --test=test_cui_search.R # Run specific test
#
# Author: CausalKnowledgeTrace Application

cat("=== CausalKnowledgeTrace Test Runner ===\n\n")

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Default options
options <- list(
    category = NULL,
    test = NULL,
    skip_integration = FALSE,
    verbose = FALSE,
    help = FALSE
)

# Parse arguments
for (arg in args) {
    if (grepl("^--category=", arg)) {
        options$category <- sub("^--category=", "", arg)
    } else if (grepl("^--test=", arg)) {
        options$test <- sub("^--test=", "", arg)
    } else if (arg == "--skip-integration") {
        options$skip_integration <- TRUE
    } else if (arg == "--verbose") {
        options$verbose <- TRUE
    } else if (arg == "--help") {
        options$help <- TRUE
    }
}

# Show help if requested
if (options$help) {
    cat("Usage: Rscript tests/run_tests.R [options]\n\n")
    cat("Options:\n")
    cat("  --category=<name>  Run only tests in specified category (integration, shiny_app, unit)\n")
    cat("  --test=<file>      Run only a specific test file\n")
    cat("  --skip-integration Skip integration tests (they can be slow)\n")
    cat("  --verbose          Show detailed output from each test\n")
    cat("  --help             Show this help message\n\n")
    cat("Examples:\n")
    cat("  Rscript tests/run_tests.R                           # Run all tests\n")
    cat("  Rscript tests/run_tests.R --category=shiny_app     # Run only shiny_app tests\n")
    cat("  Rscript tests/run_tests.R --skip-integration       # Skip integration tests\n")
    cat("  Rscript tests/run_tests.R --test=test_cui_search.R # Run specific test\n")
    quit(status = 0)
}

# Set working directory to project root
if (basename(getwd()) == "tests") {
    setwd("..")
}

# Test results tracking
test_results <- list(
    total = 0,
    passed = 0,
    failed = 0,
    skipped = 0,
    details = list()
)

# Helper function to run a test file
run_test <- function(test_file, category) {
    test_name <- basename(test_file)
    cat("\n--- Running:", test_name, "(", category, ") ---\n")
    
    start_time <- Sys.time()
    
    if (options$verbose) {
        # Run with full output
        exit_code <- system(paste("Rscript", test_file), wait = TRUE)
    } else {
        # Capture output
        output <- tryCatch({
            system(paste("Rscript", test_file), intern = TRUE, ignore.stderr = FALSE)
        }, error = function(e) {
            return(NULL)
        })
        
        # Check exit code
        exit_code <- attr(output, "status")
        if (is.null(exit_code)) {
            exit_code <- 0  # Success if no error
        }
    }
    
    end_time <- Sys.time()
    execution_time <- as.numeric(difftime(end_time, start_time, units = "secs"))
    
    test_results$total <<- test_results$total + 1
    
    if (exit_code == 0) {
        test_results$passed <<- test_results$passed + 1
        cat("✅ PASSED in", round(execution_time, 2), "seconds\n")
        test_results$details[[test_name]] <<- list(
            status = "passed",
            time = execution_time,
            category = category
        )
    } else {
        test_results$failed <<- test_results$failed + 1
        cat("❌ FAILED (exit code:", exit_code, ") in", round(execution_time, 2), "seconds\n")
        test_results$details[[test_name]] <<- list(
            status = "failed",
            time = execution_time,
            category = category,
            exit_code = exit_code
        )
    }
}

# Find and run tests
cat("Discovering tests...\n")

# Define test categories
categories <- list()

if (!options$skip_integration && (is.null(options$category) || options$category == "integration")) {
    integration_tests <- list.files("tests/integration", pattern = "^test_.*\\.R$", full.names = TRUE)
    if (length(integration_tests) > 0) {
        categories$integration <- integration_tests
    }
}

if (is.null(options$category) || options$category == "shiny_app") {
    shiny_tests <- list.files("tests/shiny_app", pattern = "^test_.*\\.R$", full.names = TRUE)
    if (length(shiny_tests) > 0) {
        categories$shiny_app <- shiny_tests
    }
}

if (is.null(options$category) || options$category == "unit") {
    unit_tests <- list.files("tests/unit", pattern = "^test_.*\\.R$", full.names = TRUE)
    if (length(unit_tests) > 0) {
        categories$unit <- unit_tests
    }
}

# Filter by specific test if requested
if (!is.null(options$test)) {
    filtered_categories <- list()
    for (category_name in names(categories)) {
        matching_tests <- categories[[category_name]][grepl(options$test, basename(categories[[category_name]]))]
        if (length(matching_tests) > 0) {
            filtered_categories[[category_name]] <- matching_tests
        }
    }
    categories <- filtered_categories
}

# Count total tests
total_test_count <- sum(sapply(categories, length))

if (total_test_count == 0) {
    cat("❌ No tests found matching the criteria.\n")
    quit(status = 1)
}

cat("Found", total_test_count, "test(s) to run\n")

# Run tests by category
for (category_name in names(categories)) {
    cat("\n=== Running", category_name, "tests ===\n")

    for (test_file in categories[[category_name]]) {
        run_test(test_file, category_name)
    }
}

# Print summary
cat("\n")
cat(paste(rep("=", 60), collapse = ""), "\n", sep = "")
cat("=== Test Summary ===\n")
cat(paste(rep("=", 60), collapse = ""), "\n", sep = "")
cat("\n")
cat("Total tests:  ", test_results$total, "\n")
cat("Passed:       ", test_results$passed, " ✅\n", sep = "")
cat("Failed:       ", test_results$failed, " ❌\n", sep = "")
cat("Skipped:      ", test_results$skipped, "\n")

if (test_results$total > 0) {
    success_rate <- round(test_results$passed / test_results$total * 100, 1)
    cat("Success rate: ", success_rate, "%\n", sep = "")
}

# Show details by category
if (test_results$total > 0) {
    cat("\n=== Results by Category ===\n")

    for (category_name in unique(sapply(test_results$details, function(x) x$category))) {
        cat_tests <- test_results$details[sapply(test_results$details, function(x) x$category == category_name)]
        cat_passed <- sum(sapply(cat_tests, function(x) x$status == "passed"))
        cat_failed <- sum(sapply(cat_tests, function(x) x$status == "failed"))

        cat("\n", category_name, ":\n", sep = "")
        cat("  Passed: ", cat_passed, "\n", sep = "")
        cat("  Failed: ", cat_failed, "\n", sep = "")
    }
}

# Show failed tests
if (test_results$failed > 0) {
    cat("\n=== Failed Tests ===\n")
    for (test_name in names(test_results$details)) {
        if (test_results$details[[test_name]]$status == "failed") {
            cat("❌ ", test_name, " (", test_results$details[[test_name]]$category, ")\n", sep = "")
            if (!is.null(test_results$details[[test_name]]$exit_code)) {
                cat("   Exit code: ", test_results$details[[test_name]]$exit_code, "\n", sep = "")
            }
        }
    }
}

# Show timing information
if (test_results$total > 0) {
    cat("\n=== Timing Information ===\n")
    total_time <- sum(sapply(test_results$details, function(x) x$time))
    cat("Total execution time: ", round(total_time, 2), " seconds\n", sep = "")

    # Show slowest tests
    sorted_tests <- test_results$details[order(sapply(test_results$details, function(x) -x$time))]
    cat("\nSlowest tests:\n")
    for (i in 1:min(5, length(sorted_tests))) {
        test_name <- names(sorted_tests)[i]
        test_time <- sorted_tests[[i]]$time
        cat("  ", i, ". ", test_name, " - ", round(test_time, 2), "s\n", sep = "")
    }
}

cat("\n")

# Exit with appropriate code
if (test_results$failed == 0) {
    cat("✅ All tests passed!\n\n")
    quit(status = 0)
} else {
    cat("❌ Some tests failed. Please review the errors above.\n\n")
    quit(status = 1)
}

