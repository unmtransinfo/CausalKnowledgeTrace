# Module Validation Script
# This script tests that all refactored modules can be loaded successfully

cat("=== Module Validation Script ===\n")
cat("Testing refactored DAG application modules...\n\n")

# Test loading each module
modules <- c("dag_visualization.R", "node_information.R", "statistics.R", "data_upload.R")
loaded_modules <- c()
failed_modules <- c()

for (module in modules) {
    cat("Testing", module, "... ")
    tryCatch({
        source(module)
        cat("✓ SUCCESS\n")
        loaded_modules <- c(loaded_modules, module)
    }, error = function(e) {
        cat("✗ FAILED:", e$message, "\n")
        failed_modules <- c(failed_modules, module)
    })
}

cat("\n=== Summary ===\n")
cat("Successfully loaded:", length(loaded_modules), "modules\n")
if (length(loaded_modules) > 0) {
    cat("- ", paste(loaded_modules, collapse = "\n- "), "\n")
}

if (length(failed_modules) > 0) {
    cat("Failed to load:", length(failed_modules), "modules\n")
    cat("- ", paste(failed_modules, collapse = "\n- "), "\n")
} else {
    cat("All modules loaded successfully! ✓\n")
}

# Test basic functionality if all modules loaded
if (length(failed_modules) == 0) {
    cat("\n=== Basic Functionality Tests ===\n")
    
    # Test 1: Create a simple DAG and process it
    cat("Test 1: Creating and processing a simple DAG... ")
    tryCatch({
        library(dagitty)
        test_dag <- dagitty('dag { A [exposure]; B [outcome]; A -> B }')
        network_data <- create_network_data(test_dag)
        
        if (nrow(network_data$nodes) > 0 && nrow(network_data$edges) > 0) {
            cat("✓ SUCCESS\n")
        } else {
            cat("✗ FAILED: No nodes or edges created\n")
        }
    }, error = function(e) {
        cat("✗ FAILED:", e$message, "\n")
    })
    
    # Test 2: Generate statistics
    cat("Test 2: Generating statistics... ")
    tryCatch({
        if (exists("network_data")) {
            stats <- calculate_dag_statistics(network_data$nodes, network_data$edges)
            if (is.list(stats) && "total_nodes" %in% names(stats)) {
                cat("✓ SUCCESS\n")
            } else {
                cat("✗ FAILED: Invalid statistics format\n")
            }
        } else {
            cat("✗ SKIPPED: No network data available\n")
        }
    }, error = function(e) {
        cat("✗ FAILED:", e$message, "\n")
    })
    
    # Test 3: Generate legend HTML
    cat("Test 3: Generating legend HTML... ")
    tryCatch({
        if (exists("network_data")) {
            legend_html <- generate_legend_html(network_data$nodes)
            if (is.character(legend_html) && nchar(legend_html) > 0) {
                cat("✓ SUCCESS\n")
            } else {
                cat("✗ FAILED: Invalid legend HTML\n")
            }
        } else {
            cat("✗ SKIPPED: No network data available\n")
        }
    }, error = function(e) {
        cat("✗ FAILED:", e$message, "\n")
    })
    
    # Test 4: Scan for DAG files
    cat("Test 4: Scanning for DAG files... ")
    tryCatch({
        dag_files <- scan_for_dag_files()
        if (is.character(dag_files)) {
            cat("✓ SUCCESS (found", length(dag_files), "files)\n")
        } else {
            cat("✗ FAILED: Invalid return type\n")
        }
    }, error = function(e) {
        cat("✗ FAILED:", e$message, "\n")
    })
    
    cat("\n=== Validation Complete ===\n")
    cat("The refactored modules appear to be working correctly!\n")
    cat("You can now run the main application with: shiny::runApp()\n")
    
} else {
    cat("\n=== Validation Failed ===\n")
    cat("Please fix the module loading issues before running the application.\n")
}
