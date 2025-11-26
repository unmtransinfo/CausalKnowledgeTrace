#!/usr/bin/env Rscript
# Example Unit Test
# 
# This is a template/example for writing unit tests.
# Unit tests should be fast, isolated, and test specific functions.
#
# Usage:
#   Rscript tests/unit/test_example.R
#
# Author: CausalKnowledgeTrace Application

cat("=== Example Unit Test ===\n\n")

# Test results tracking
test_results <- list(
    total_tests = 0,
    passed = 0,
    failed = 0,
    errors = list()
)

# Helper function to record test result
record_test <- function(test_name, passed, error_msg = NULL) {
    test_results$total_tests <<- test_results$total_tests + 1
    if (passed) {
        test_results$passed <<- test_results$passed + 1
        cat("✅ PASS:", test_name, "\n")
    } else {
        test_results$failed <<- test_results$failed + 1
        cat("❌ FAIL:", test_name, "\n")
        if (!is.null(error_msg)) {
            cat("   Error:", error_msg, "\n")
            test_results$errors[[test_name]] <<- error_msg
        }
    }
}

# Test 1: Basic arithmetic
cat("\n--- Test 1: Basic Arithmetic ---\n")
result <- 2 + 2
expected <- 4
record_test("Addition works correctly", result == expected)

# Test 2: String operations
cat("\n--- Test 2: String Operations ---\n")
test_string <- "Hello, World!"
record_test("String length is correct", nchar(test_string) == 13)
record_test("String contains 'World'", grepl("World", test_string))

# Test 3: List operations
cat("\n--- Test 3: List Operations ---\n")
test_list <- list(a = 1, b = 2, c = 3)
record_test("List has correct length", length(test_list) == 3)
record_test("List contains key 'a'", "a" %in% names(test_list))
record_test("List value for 'b' is 2", test_list$b == 2)

# Test 4: Error handling
cat("\n--- Test 4: Error Handling ---\n")
error_caught <- FALSE
tryCatch({
    stop("Test error")
}, error = function(e) {
    error_caught <<- TRUE
})
record_test("Error was caught correctly", error_caught)

# Test 5: Vector operations
cat("\n--- Test 5: Vector Operations ---\n")
test_vector <- c(1, 2, 3, 4, 5)
record_test("Vector sum is correct", sum(test_vector) == 15)
record_test("Vector mean is correct", mean(test_vector) == 3)
record_test("Vector max is correct", max(test_vector) == 5)

# Print summary
cat("\n=== Test Summary ===\n")
cat("Total tests:", test_results$total_tests, "\n")
cat("Passed:", test_results$passed, "✅\n")
cat("Failed:", test_results$failed, "❌\n")

if (test_results$total_tests > 0) {
    success_rate <- round(test_results$passed / test_results$total_tests * 100, 1)
    cat("Success rate:", success_rate, "%\n")
}

if (test_results$failed > 0) {
    cat("\n=== Failed Tests ===\n")
    for (test_name in names(test_results$errors)) {
        cat("❌", test_name, "\n")
        cat("   ", test_results$errors[[test_name]], "\n")
    }
}

# Exit with appropriate code
if (test_results$failed == 0) {
    cat("\n✅ All tests passed!\n")
    quit(status = 0)
} else {
    cat("\n❌ Some tests failed. Please review the errors above.\n")
    quit(status = 1)
}

