#!/usr/bin/env Rscript
# Integration Test for Graph Creation Pipeline
# 
# This test validates the complete graph creation workflow:
# 1. Reads configuration from user_input.yaml (default setup)
# 2. Executes the graph creation pipeline via pushkin.py
# 3. Validates that expected output files are generated
# 4. Checks the structure and content of generated files
#
# Usage:
#   Rscript tests/integration/test_graph_creation.R
#
# Author: CausalKnowledgeTrace Application

cat("=== Graph Creation Integration Test ===\n\n")

# Set working directory to project root if not already there
if (basename(getwd()) == "tests" || basename(getwd()) == "integration") {
    setwd("../..")
}

# Load required libraries
if (!require(yaml, quietly = TRUE)) {
    stop("yaml package is required. Install with: install.packages('yaml')")
}

if (!require(jsonlite, quietly = TRUE)) {
    stop("jsonlite package is required. Install with: install.packages('jsonlite')")
}

# Test configuration
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

# Test 1: Check if user_input.yaml exists
cat("\n--- Test 1: Configuration File Validation ---\n")
config_file <- "user_input.yaml"
if (file.exists(config_file)) {
    record_test("Configuration file exists", TRUE)
    
    # Read and validate configuration
    tryCatch({
        config <- yaml::read_yaml(config_file)
        record_test("Configuration file is valid YAML", TRUE)
        
        # Display configuration
        cat("\nConfiguration loaded:\n")
        cat("  Exposure CUIs:", paste(config$exposure_cuis, collapse = ", "), "\n")
        cat("  Outcome CUIs:", paste(config$outcome_cuis, collapse = ", "), "\n")
        cat("  Exposure Name:", config$exposure_name, "\n")
        cat("  Outcome Name:", config$outcome_name, "\n")

        # Display thresholds - support both old and new format
        if (!is.null(config$min_pmids_degree1)) {
            cat("  Min PMIDs (Degree 1):", config$min_pmids_degree1, "\n")
            cat("  Min PMIDs (Degree 2):", config$min_pmids_degree2, "\n")
            cat("  Min PMIDs (Degree 3):", config$min_pmids_degree3, "\n")
        } else if (!is.null(config$min_pmids)) {
            cat("  Min PMIDs:", config$min_pmids, "\n")
        }

        cat("  Degree:", config$degree, "\n")
        cat("  Predication Type:", config$predication_type, "\n")

        # Validate required fields - support both old and new format
        required_fields_base <- c("exposure_cuis", "outcome_cuis", "exposure_name",
                                 "outcome_name", "degree", "predication_type")

        # Check if either old or new threshold format is present
        has_old_format <- "min_pmids" %in% names(config)
        has_new_format <- all(c("min_pmids_degree1", "min_pmids_degree2", "min_pmids_degree3") %in% names(config))

        missing_fields <- required_fields_base[!required_fields_base %in% names(config)]

        if (length(missing_fields) == 0 && (has_old_format || has_new_format)) {
            record_test("All required configuration fields present", TRUE)
        } else {
            error_parts <- c()
            if (length(missing_fields) > 0) {
                error_parts <- c(error_parts, paste("Missing fields:", paste(missing_fields, collapse = ", ")))
            }
            if (!has_old_format && !has_new_format) {
                error_parts <- c(error_parts, "Missing threshold fields (need either min_pmids or min_pmids_degree1/2/3)")
            }
            record_test("All required configuration fields present", FALSE,
                       paste(error_parts, collapse = "; "))
        }
        
    }, error = function(e) {
        record_test("Configuration file is valid YAML", FALSE, e$message)
    })
} else {
    record_test("Configuration file exists", FALSE, 
               paste("File not found:", config_file))
}

# Test 2: Check if Python script exists
cat("\n--- Test 2: Graph Creation Script Validation ---\n")
python_script <- "graph_creation/pushkin.py"
if (file.exists(python_script)) {
    record_test("Python script exists", TRUE)
} else {
    record_test("Python script exists", FALSE, 
               paste("File not found:", python_script))
}

# Test 3: Check if .env file exists (required for database connection)
cat("\n--- Test 3: Environment Configuration ---\n")
env_file <- ".env"
if (file.exists(env_file)) {
    record_test("Environment file (.env) exists", TRUE)
} else {
    record_test("Environment file (.env) exists", FALSE, 
               "Database credentials file not found. Graph creation will fail without it.")
}

# Test 4: Execute graph creation pipeline
cat("\n--- Test 4: Graph Creation Execution ---\n")
cat("⚠️  This test will execute the actual graph creation pipeline.\n")
cat("   This may take several minutes depending on the configuration.\n")
cat("   Press Ctrl+C to cancel if you don't want to run this test.\n\n")

# Give user a chance to cancel
Sys.sleep(3)

cat("Starting graph creation...\n")

# Execute the graph creation script
script_path <- "graph_creation/example/run_pushkin.sh"
if (file.exists(script_path)) {
    start_time <- Sys.time()
    exit_code <- system(script_path, wait = TRUE)
    end_time <- Sys.time()
    execution_time <- as.numeric(difftime(end_time, start_time, units = "secs"))

    cat("\nExecution completed in", round(execution_time, 2), "seconds\n")

    if (exit_code == 0) {
        record_test("Graph creation script executed successfully", TRUE)
    } else {
        record_test("Graph creation script executed successfully", FALSE,
                   paste("Script exited with code:", exit_code))
    }
} else {
    cat("⚠️  Shell script not found, trying direct Python execution...\n")

    # Try direct Python execution
    cmd <- paste("python", python_script,
                "--yaml-config", config_file,
                "--output-dir graph_creation/result",
                "--verbose")

    start_time <- Sys.time()
    exit_code <- system(cmd, wait = TRUE)
    end_time <- Sys.time()
    execution_time <- as.numeric(difftime(end_time, start_time, units = "secs"))

    cat("\nExecution completed in", round(execution_time, 2), "seconds\n")

    if (exit_code == 0) {
        record_test("Graph creation (Python direct) executed successfully", TRUE)
    } else {
        record_test("Graph creation (Python direct) executed successfully", FALSE,
                   paste("Script exited with code:", exit_code))
    }
}

# Test 5: Validate output files
cat("\n--- Test 5: Output File Validation ---\n")
output_dir <- "graph_creation/result"

if (dir.exists(output_dir)) {
    record_test("Output directory exists", TRUE)

    # Check for expected output files based on degree in config
    if (exists("config") && !is.null(config$degree)) {
        degree <- config$degree

        # Expected files for each degree
        expected_files <- c(
            paste0("degree_", degree, ".R"),
            paste0("causal_assertions_", degree, ".json")
        )

        for (expected_file in expected_files) {
            file_path <- file.path(output_dir, expected_file)
            if (file.exists(file_path)) {
                file_size <- file.size(file_path)
                record_test(paste("Output file exists:", expected_file), TRUE)
                cat("   File size:", round(file_size / 1024, 2), "KB\n")

                # Validate file content
                if (grepl("\\.R$", expected_file)) {
                    # Validate R file contains DAGitty code
                    tryCatch({
                        content <- readLines(file_path, n = 100, warn = FALSE)
                        has_dag <- any(grepl("dag\\s*\\{", content, ignore.case = TRUE))
                        if (has_dag) {
                            record_test(paste("R file contains valid DAG:", expected_file), TRUE)
                        } else {
                            record_test(paste("R file contains valid DAG:", expected_file), FALSE,
                                       "No DAG definition found in file")
                        }
                    }, error = function(e) {
                        record_test(paste("R file readable:", expected_file), FALSE, e$message)
                    })
                } else if (grepl("\\.json$", expected_file)) {
                    # Validate JSON file
                    tryCatch({
                        json_data <- jsonlite::fromJSON(file_path)
                        if (is.list(json_data) && length(json_data) > 0) {
                            record_test(paste("JSON file is valid:", expected_file), TRUE)
                            cat("   Assertions count:", length(json_data), "\n")
                        } else {
                            record_test(paste("JSON file is valid:", expected_file), FALSE,
                                       "JSON file is empty or invalid structure")
                        }
                    }, error = function(e) {
                        record_test(paste("JSON file is valid:", expected_file), FALSE, e$message)
                    })
                }
            } else {
                record_test(paste("Output file exists:", expected_file), FALSE,
                           paste("File not found:", file_path))
            }
        }
    }
} else {
    record_test("Output directory exists", FALSE,
               paste("Directory not found:", output_dir))
}

# Test 6: Validate DAG structure
cat("\n--- Test 6: DAG Structure Validation ---\n")
if (exists("config") && !is.null(config$degree)) {
    dag_file <- file.path(output_dir, paste0("degree_", config$degree, ".R"))

    if (file.exists(dag_file)) {
        tryCatch({
            # Load dagitty library
            if (!require(dagitty, quietly = TRUE)) {
                cat("⚠️  dagitty package not installed. Skipping DAG structure validation.\n")
                cat("   Install with: install.packages('dagitty')\n")
            } else {
                # Source the DAG file
                dag_env <- new.env()
                source(dag_file, local = dag_env)

                # Find the DAG object
                dag_obj <- NULL
                for (obj_name in ls(dag_env)) {
                    obj <- get(obj_name, envir = dag_env)
                    if (inherits(obj, "dagitty")) {
                        dag_obj <- obj
                        break
                    }
                }

                if (!is.null(dag_obj)) {
                    record_test("DAG object loaded successfully", TRUE)

                    # Get DAG statistics
                    nodes <- names(dag_obj)
                    edges <- edges(dag_obj)

                    cat("   Nodes:", length(nodes), "\n")
                    cat("   Edges:", nrow(edges), "\n")

                    # Check for exposure and outcome nodes
                    exposures <- exposures(dag_obj)
                    outcomes <- outcomes(dag_obj)

                    if (length(exposures) > 0) {
                        record_test("DAG has exposure nodes", TRUE)
                        cat("   Exposures:", paste(exposures, collapse = ", "), "\n")
                    } else {
                        record_test("DAG has exposure nodes", FALSE, "No exposure nodes found")
                    }

                    if (length(outcomes) > 0) {
                        record_test("DAG has outcome nodes", TRUE)
                        cat("   Outcomes:", paste(outcomes, collapse = ", "), "\n")
                    } else {
                        record_test("DAG has outcome nodes", FALSE, "No outcome nodes found")
                    }

                } else {
                    record_test("DAG object loaded successfully", FALSE,
                               "No dagitty object found in file")
                }
            }
        }, error = function(e) {
            record_test("DAG file can be loaded", FALSE, e$message)
        })
    }
}

# Print summary
cat("\n=== Test Summary ===\n")
cat("Total tests:", test_results$total_tests, "\n")
cat("Passed:", test_results$passed, "✅\n")
cat("Failed:", test_results$failed, "❌\n")
cat("Success rate:", round(test_results$passed / test_results$total_tests * 100, 1), "%\n")

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

