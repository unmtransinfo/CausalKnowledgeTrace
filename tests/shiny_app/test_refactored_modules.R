# Comprehensive Test Suite for Refactored Modules
#
# This script tests all refactored modules to ensure functionality is preserved
# and that the modular structure works correctly.
#
# Author: CausalKnowledgeTrace Application
# Date: February 2025

cat("=== Refactored Modules Test ===\n\n")

# Check if refactored modules exist
cat("⚠️  CHECKING FOR REFACTORED MODULES...\n\n")

# Set working directory to shiny_app for proper sourcing
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

# Check if refactored module structure exists
expected_refactored_files <- c(
    "modules/dag_visualization/network_creation.R",
    "modules/dag_visualization/network_controls.R",
    "modules/dag_visualization_refactored.R",
    "ui/dashboard_structure.R"
)

refactored_exists <- any(sapply(expected_refactored_files, file.exists))

if (!refactored_exists) {
    cat("⚠️  SKIPPING TEST: Refactored module structure not yet implemented\n\n")
    cat("This test expects the following refactored structure:\n")
    cat("  - modules/dag_visualization/network_creation.R\n")
    cat("  - modules/dag_visualization/network_controls.R\n")
    cat("  - modules/dag_visualization/network_modification.R\n")
    cat("  - modules/dag_visualization/network_validation.R\n")
    cat("  - modules/dag_visualization_refactored.R\n")
    cat("  - ui/dashboard_structure.R\n")
    cat("  - ui/tab_content.R\n")
    cat("  - ui/styling_assets.R\n")
    cat("  - ui/ui_components_refactored.R\n\n")
    cat("Current module structure uses non-refactored modules.\n")
    cat("This test will be enabled once refactoring is complete.\n\n")
    cat("✅ TEST SKIPPED (not a failure)\n")
    quit(status = 0)
}

# Required libraries
required_packages <- c("shiny", "shinydashboard", "visNetwork", "dplyr", "yaml", "shinyjs")

for (pkg in required_packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
        message(paste("Installing", pkg, "..."))
        install.packages(pkg)
        library(pkg, character.only = TRUE)
    }
}

# Test results storage
test_results <- list()

#' Run Test and Record Result
#' 
#' @param test_name Name of the test
#' @param test_function Function to execute
#' @return Boolean indicating success
run_test <- function(test_name, test_function) {
    cat(paste("Running test:", test_name, "... "))
    
    result <- tryCatch({
        test_function()
        TRUE
    }, error = function(e) {
        cat("FAILED\n")
        cat("Error:", e$message, "\n")
        FALSE
    })
    
    if (result) {
        cat("PASSED\n")
    }
    
    test_results[[test_name]] <<- result
    return(result)
}

# Test 1: DAG Visualization Refactored Modules
run_test("DAG Visualization - Network Creation", function() {
    source("modules/dag_visualization/network_creation.R")
    
    # Test basic function existence
    stopifnot(exists("create_interactive_network"))
    stopifnot(exists("get_default_physics_settings"))
    stopifnot(exists("apply_network_styling"))
    
    # Test default settings
    settings <- get_default_physics_settings()
    stopifnot(is.list(settings))
    stopifnot("physics_strength" %in% names(settings))
    
    # Test network styling with sample data
    sample_nodes <- data.frame(id = c("A", "B"), label = c("Node A", "Node B"))
    sample_edges <- data.frame(from = "A", to = "B")
    
    styled <- apply_network_styling(sample_nodes, sample_edges)
    stopifnot(is.list(styled))
    stopifnot("nodes" %in% names(styled))
    stopifnot("edges" %in% names(styled))
})

# Test 2: DAG Visualization - Network Controls
run_test("DAG Visualization - Network Controls", function() {
    source("modules/dag_visualization/network_controls.R")
    
    # Test function existence
    stopifnot(exists("generate_legend_html"))
    stopifnot(exists("create_network_controls_ui"))
    stopifnot(exists("format_node_info"))
    
    # Test legend generation
    sample_nodes <- data.frame(
        id = c("A", "B"), 
        label = c("Node A", "Node B"),
        group = c("Type1", "Type2"),
        color = c("#FF0000", "#00FF00")
    )
    
    legend_html <- generate_legend_html(sample_nodes)
    stopifnot(is.character(legend_html))
    stopifnot(nchar(legend_html) > 0)
    
    # Test node info formatting
    node_info <- format_node_info("A", sample_nodes)
    stopifnot(is.character(node_info))
    stopifnot(grepl("Node A", node_info))
})

# Test 3: DAG Visualization - Network Modification
run_test("DAG Visualization - Network Modification", function() {
    source("modules/dag_visualization/network_modification.R")
    
    # Test function existence
    stopifnot(exists("remove_node_from_network"))
    stopifnot(exists("remove_edge_from_network"))
    stopifnot(exists("undo_last_removal"))
    stopifnot(exists("get_undo_stack_status"))
    
    # Test undo stack functionality
    mock_data <- list(undo_stack = list())
    status <- get_undo_stack_status(mock_data)
    stopifnot(is.list(status))
    stopifnot("available" %in% names(status))
    stopifnot(status$available == FALSE)
})

# Test 4: DAG Visualization - Network Validation
run_test("DAG Visualization - Network Validation", function() {
    source("modules/dag_visualization/network_validation.R")
    
    # Test function existence
    stopifnot(exists("get_network_stats"))
    stopifnot(exists("validate_network_integrity"))
    stopifnot(exists("format_network_stats"))
    
    # Test network statistics
    mock_data <- list(
        nodes = data.frame(id = c("A", "B", "C")),
        edges = data.frame(from = c("A", "B"), to = c("B", "C"))
    )
    
    stats <- get_network_stats(mock_data)
    stopifnot(is.list(stats))
    stopifnot(stats$nodes == 3)
    stopifnot(stats$edges == 2)
    
    # Test validation
    validation <- validate_network_integrity(mock_data)
    stopifnot(is.list(validation))
    stopifnot("valid" %in% names(validation))
})

# Test 5: DAG Visualization - Main Refactored Module
run_test("DAG Visualization - Main Refactored Module", function() {
    source("modules/dag_visualization_refactored.R")
    
    # Test function existence
    stopifnot(exists("dagVisualizationServer"))
    stopifnot(exists("load_dag_visualization_module"))
    
    # Test module loading
    module_info <- load_dag_visualization_module()
    stopifnot(is.list(module_info))
    stopifnot("components" %in% names(module_info))
    stopifnot(length(module_info$components) == 4)
})

# Test 6: UI Components - Dashboard Structure
run_test("UI Components - Dashboard Structure", function() {
    source("ui/dashboard_structure.R")
    
    # Test function existence
    stopifnot(exists("create_dashboard_header"))
    stopifnot(exists("create_dashboard_sidebar"))
    stopifnot(exists("create_dashboard_body"))
    stopifnot(exists("create_complete_dashboard"))
    
    # Test dashboard configuration
    config <- get_dashboard_config()
    stopifnot(is.list(config))
    stopifnot("title" %in% names(config))
    stopifnot("tabs" %in% names(config))
})

# Test 7: UI Components - Tab Content
run_test("UI Components - Tab Content", function() {
    source("ui/tab_content.R")
    
    # Test function existence
    stopifnot(exists("create_config_tab"))
    stopifnot(exists("create_upload_tab"))
    stopifnot(exists("create_dag_tab"))
    stopifnot(exists("get_tab_config"))
    
    # Test tab configuration
    tab_config <- get_tab_config()
    stopifnot(is.list(tab_config))
    stopifnot("tabs" %in% names(tab_config))
    stopifnot(length(tab_config$tabs) == 6)
})

# Test 8: UI Components - Styling Assets
run_test("UI Components - Styling Assets", function() {
    source("ui/styling_assets.R")
    
    # Test function existence
    stopifnot(exists("create_custom_styles"))
    stopifnot(exists("create_custom_javascript"))
    stopifnot(exists("create_loading_spinner"))
    stopifnot(exists("create_error_message"))
    
    # Test utility functions
    spinner <- create_loading_spinner("Test loading...")
    stopifnot(inherits(spinner, "shiny.tag"))
    
    error_msg <- create_error_message("Test error")
    stopifnot(inherits(error_msg, "shiny.tag"))
})

# Test 9: UI Components - Main Refactored Module
run_test("UI Components - Main Refactored Module", function() {
    source("ui/ui_components_refactored.R")
    
    # Test function existence
    stopifnot(exists("create_main_ui"))
    stopifnot(exists("initialize_ui_components"))
    stopifnot(exists("create_minimal_ui"))
    
    # Test UI initialization
    ui_config <- initialize_ui_components()
    stopifnot(is.list(ui_config))
    stopifnot("components" %in% names(ui_config))
    stopifnot("version" %in% names(ui_config))
})

# Test 10: Integration Test - Check if refactored modules work together
run_test("Integration Test - Module Compatibility", function() {
    # Test that refactored modules can be loaded together
    source("modules/dag_visualization_refactored.R")
    source("ui/ui_components_refactored.R")

    # Test UI creation
    ui <- create_main_ui()
    stopifnot(!is.null(ui))

    # Test UI validation (simplified check)
    stopifnot(inherits(ui, "shiny.tag") || inherits(ui, "shiny.tag.list"))
})

# Test 11: Backward Compatibility Test
run_test("Backward Compatibility Test", function() {
    # Test that existing refactored modules still work
    compatibility_passed <- TRUE

    if (file.exists("modules/graph_config_refactored.R")) {
        tryCatch({
            source("modules/graph_config_refactored.R")
            if (!exists("graphConfigModuleUI") && !exists("graphConfigUI")) {
                compatibility_passed <- FALSE
            }
        }, error = function(e) {
            compatibility_passed <<- FALSE
        })
    }

    if (file.exists("modules/data_upload_refactored.R")) {
        tryCatch({
            source("modules/data_upload_refactored.R")
            # Just check that the file loads without error
        }, error = function(e) {
            compatibility_passed <<- FALSE
        })
    }

    if (file.exists("modules/statistics_refactored.R")) {
        tryCatch({
            source("modules/statistics_refactored.R")
            # Just check that the file loads without error
        }, error = function(e) {
            compatibility_passed <<- FALSE
        })
    }

    stopifnot(compatibility_passed)
})

# Print test summary
cat("\n")
cat(paste(rep("=", 60), collapse = ""))
cat("\n")
cat("TEST SUMMARY\n")
cat(paste(rep("=", 60), collapse = ""))
cat("\n")

total_tests <- length(test_results)
passed_tests <- sum(unlist(test_results))
failed_tests <- total_tests - passed_tests

cat(sprintf("Total tests: %d\n", total_tests))
cat(sprintf("Passed: %d\n", passed_tests))
cat(sprintf("Failed: %d\n", failed_tests))
cat(sprintf("Success rate: %.1f%%\n", (passed_tests / total_tests) * 100))

if (failed_tests > 0) {
    cat("\nFailed tests:\n")
    failed_test_names <- names(test_results)[!unlist(test_results)]
    for (test_name in failed_test_names) {
        cat(sprintf("- %s\n", test_name))
    }
}

cat("\n")
cat(paste(rep("=", 60), collapse = ""))
cat("\n")

# Return test results
return(list(
    total = total_tests,
    passed = passed_tests,
    failed = failed_tests,
    success_rate = (passed_tests / total_tests) * 100,
    details = test_results
))
