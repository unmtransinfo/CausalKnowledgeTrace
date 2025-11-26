# Testing Guide for CausalKnowledgeTrace

## Quick Start

### Run All Tests (Skip Integration)
```bash
Rscript tests/run_tests.R --skip-integration
```

### Run Integration Test (Graph Creation)
```bash
Rscript tests/run_tests.R --category=integration
```

### Run Specific Test
```bash
Rscript tests/integration/test_graph_creation.R
```

## Test Structure

The test suite is organized into three categories:

### 1. Integration Tests (`tests/integration/`)

**Purpose:** Test complete workflows and pipelines

**Current Tests:**
- `test_graph_creation.R` - Tests the complete graph creation pipeline

**What it tests:**
1. Configuration file validation (user_input.yaml)
2. Python script existence
3. Environment configuration (.env file)
4. Graph creation execution
5. Output file validation (degree_*.R, causal_assertions_*.json)
6. DAG structure validation (nodes, edges, exposures, outcomes)

**Example Run:**
```bash
# Run the integration test
Rscript tests/integration/test_graph_creation.R

# Expected output:
# ✅ 14 tests passed
# - Configuration validation
# - Script validation
# - Graph creation execution
# - Output file validation
# - DAG structure validation
```

### 2. Shiny App Tests (`tests/shiny_app/`)

**Purpose:** Test Shiny application components

**Current Tests:**
- `test_cui_search.R` - CUI search functionality
- `test_edge_information.R` - Edge information display
- `test_html_export.R` - HTML export functionality
- `test_optimized_loading.R` - Optimized file loading
- `test_refactored_app.R` - Refactored app components
- `test_refactored_modules.R` - Module validation
- `test_removal_functionality.R` - Node/edge removal

**Note:** Some of these tests may need to be updated to work from the new location.

### 3. Unit Tests (`tests/unit/`)

**Purpose:** Test individual functions in isolation

**Current Tests:**
- `test_example.R` - Example/template for unit tests

**Example Run:**
```bash
Rscript tests/run_tests.R --category=unit
```

## Test Runner Features

The `tests/run_tests.R` script provides:

### Command Line Options

```bash
# Show help
Rscript tests/run_tests.R --help

# Run specific category
Rscript tests/run_tests.R --category=integration
Rscript tests/run_tests.R --category=shiny_app
Rscript tests/run_tests.R --category=unit

# Run specific test
Rscript tests/run_tests.R --test=test_graph_creation.R

# Skip integration tests (they can be slow)
Rscript tests/run_tests.R --skip-integration

# Verbose output
Rscript tests/run_tests.R --verbose
```

### Test Results

The test runner provides:
- ✅ Pass/Fail status for each test
- ⏱️ Execution time for each test
- 📊 Summary statistics
- 🐌 Slowest tests report
- 📋 Detailed error messages for failed tests

## Graph Creation Test Details

The `test_graph_creation.R` test validates the complete graph creation workflow:

### Prerequisites
- PostgreSQL database running
- `.env` file with database credentials
- `user_input.yaml` with valid configuration
- Python 3.x with required packages

### What Gets Tested

1. **Configuration Validation**
   - File exists and is valid YAML
   - All required fields present
   - Values are in correct format

2. **Script Validation**
   - Python script exists
   - Shell script exists (if available)

3. **Environment Validation**
   - .env file exists
   - Database credentials available

4. **Execution**
   - Graph creation runs successfully
   - No errors during execution
   - Completes within reasonable time

5. **Output Validation**
   - Output directory created
   - Expected files generated
   - Files have correct format
   - Files contain valid data

6. **DAG Structure Validation**
   - DAG can be loaded
   - Has correct number of nodes/edges
   - Has exposure nodes
   - Has outcome nodes

### Example Output

```
=== Graph Creation Integration Test ===

--- Test 1: Configuration File Validation ---
✅ PASS: Configuration file exists 
✅ PASS: Configuration file is valid YAML 
✅ PASS: All required configuration fields present 

--- Test 2: Graph Creation Script Validation ---
✅ PASS: Python script exists 

--- Test 3: Environment Configuration ---
✅ PASS: Environment file (.env) exists 

--- Test 4: Graph Creation Execution ---
Starting graph creation...
✅ PASS: Graph creation script executed successfully 

--- Test 5: Output File Validation ---
✅ PASS: Output directory exists 
✅ PASS: Output file exists: degree_1.R 
✅ PASS: R file contains valid DAG: degree_1.R 
✅ PASS: Output file exists: causal_assertions_1.json 
✅ PASS: JSON file is valid: causal_assertions_1.json 

--- Test 6: DAG Structure Validation ---
✅ PASS: DAG object loaded successfully 
✅ PASS: DAG has exposure nodes 
✅ PASS: DAG has outcome nodes 

=== Test Summary ===
Total tests: 14 
Passed: 14 ✅
Failed: 0 ❌
Success rate: 100 %

✅ All tests passed!
```

## Continuous Integration

To integrate into CI/CD:

```bash
#!/bin/bash
# CI test script

# Run unit tests (fast)
Rscript tests/run_tests.R --category=unit
if [ $? -ne 0 ]; then
    echo "Unit tests failed!"
    exit 1
fi

# Run integration tests (slower, optional)
# Rscript tests/run_tests.R --category=integration
# if [ $? -ne 0 ]; then
#     echo "Integration tests failed!"
#     exit 1
# fi

echo "All tests passed!"
```

## Troubleshooting

### Tests Not Found
- Ensure you're in the project root directory
- Check test files follow `test_*.R` naming pattern

### Integration Test Fails
- Check database is running
- Verify `.env` file has correct credentials
- Ensure `user_input.yaml` has valid configuration
- Check Python environment is set up

### Shiny App Tests Fail
- Some tests may need path updates after moving
- Ensure working directory is correct
- Check all required modules exist

## Adding New Tests

See `tests/README.md` for detailed instructions on writing new tests.

Quick template:

```r
#!/usr/bin/env Rscript
# Test Description

cat("=== Test Name ===\n\n")

test_results <- list(total_tests = 0, passed = 0, failed = 0, errors = list())

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

# Your tests here...

# Exit with appropriate code
quit(status = if (test_results$failed == 0) 0 else 1)
```

