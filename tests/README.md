# CausalKnowledgeTrace Tests

This directory contains all tests for the CausalKnowledgeTrace application.

## Directory Structure

```
tests/
├── README.md                    # This file
├── run_tests.R                  # Main test runner script
├── integration/                 # Integration tests (full pipeline tests)
│   └── test_graph_creation.R   # Tests graph creation pipeline
├── shiny_app/                   # Shiny application component tests
│   ├── test_cui_search.R       # CUI search functionality
│   ├── test_edge_information.R # Edge information display
│   ├── test_html_export.R      # HTML export functionality
│   ├── test_optimized_loading.R # Optimized file loading
│   ├── test_refactored_app.R   # Refactored app components
│   ├── test_refactored_modules.R # Module validation
│   └── test_removal_functionality.R # Node/edge removal
└── unit/                        # Unit tests (individual functions)
```

## Running Tests

### Run All Tests

```bash
Rscript tests/run_tests.R
```

### Run Tests by Category

```bash
# Run only integration tests
Rscript tests/run_tests.R --category=integration

# Run only shiny_app tests
Rscript tests/run_tests.R --category=shiny_app

# Run only unit tests
Rscript tests/run_tests.R --category=unit
```

### Run Specific Test

```bash
# Run a specific test file
Rscript tests/run_tests.R --test=test_graph_creation.R
```

### Skip Integration Tests

Integration tests can be slow as they run the full pipeline. To skip them:

```bash
Rscript tests/run_tests.R --skip-integration
```

### Verbose Output

To see detailed output from each test:

```bash
Rscript tests/run_tests.R --verbose
```

## Test Categories

### Integration Tests

Integration tests validate complete workflows and pipelines. These tests:
- May take several minutes to complete
- Require database connectivity
- Test end-to-end functionality
- Validate output files and data structures

**Example:** `test_graph_creation.R` tests the complete graph creation pipeline from configuration to output validation.

### Shiny App Tests

These tests validate individual components of the Shiny application:
- Module functionality
- UI components
- Data processing
- File operations
- Database interactions

### Unit Tests

Unit tests validate individual functions in isolation:
- Fast execution
- No external dependencies
- Test specific function behavior
- Edge case validation

## Writing New Tests

### Test File Naming Convention

All test files must follow the naming pattern: `test_*.R`

### Test Structure

```r
#!/usr/bin/env Rscript
# Test Description
# 
# Brief description of what this test validates
#
# Author: Your Name

cat("=== Test Name ===\n\n")

# Test setup
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

# Your tests here
cat("\n--- Test 1: Description ---\n")
# ... test code ...

# Print summary
cat("\n=== Test Summary ===\n")
cat("Total tests:", test_results$total_tests, "\n")
cat("Passed:", test_results$passed, "✅\n")
cat("Failed:", test_results$failed, "❌\n")

# Exit with appropriate code
if (test_results$failed == 0) {
    quit(status = 0)
} else {
    quit(status = 1)
}
```

### Test Best Practices

1. **Make tests independent**: Each test should be able to run independently
2. **Clean up after tests**: Remove temporary files and restore state
3. **Use descriptive names**: Test names should clearly indicate what is being tested
4. **Provide clear error messages**: Help developers understand what went wrong
5. **Test both success and failure cases**: Validate error handling
6. **Document prerequisites**: Clearly state what is needed to run the test

## Prerequisites

### All Tests
- R (version 3.6 or higher)
- Required R packages: `yaml`, `jsonlite`

### Integration Tests
- Database connectivity (PostgreSQL)
- `.env` file with database credentials
- Python 3.x with required packages

### Shiny App Tests
- Shiny package
- dagitty package
- All Shiny app dependencies

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```bash
# Example CI script
Rscript tests/run_tests.R --skip-integration
exit_code=$?
if [ $exit_code -ne 0 ]; then
    echo "Tests failed!"
    exit 1
fi
```

## Troubleshooting

### Tests Not Found
- Ensure you're running from the project root directory
- Check that test files follow the `test_*.R` naming pattern

### Database Connection Errors
- Verify `.env` file exists with correct credentials
- Check database is running and accessible
- Ensure database schema is properly set up

### Module Loading Errors
- Verify all required R packages are installed
- Check that module files exist in expected locations
- Ensure working directory is set correctly

## Contributing

When adding new features, please:
1. Write tests for new functionality
2. Ensure all existing tests still pass
3. Update this README if adding new test categories
4. Follow the established test structure and naming conventions

