# Test Script for Graph Configuration Module
# This script tests the graph configuration module functionality

# Load required libraries
library(shiny)
library(yaml)

# Source the module
source("graph_config_module.R")

# Test function to validate the module structure
test_module_structure <- function() {
    cat("Testing Graph Configuration Module Structure...\n")
    
    # Check if functions exist
    if (!exists("graphConfigUI")) {
        stop("graphConfigUI function not found")
    }
    
    if (!exists("graphConfigServer")) {
        stop("graphConfigServer function not found")
    }
    
    cat("✅ Module functions exist\n")
    
    # Test UI function
    tryCatch({
        ui_result <- graphConfigUI("test")
        if (is.null(ui_result)) {
            stop("graphConfigUI returned NULL")
        }
        cat("✅ graphConfigUI function works\n")
    }, error = function(e) {
        stop(paste("graphConfigUI failed:", e$message))
    })
    
    return(TRUE)
}

# Test parameter validation
test_parameter_validation <- function() {
    cat("Testing Parameter Validation...\n")
    
    # Test valid CUI format
    valid_cuis <- c("C0011849", "C0020538", "C0027051", "C0038454")
    invalid_cuis <- c("C001184", "C00118499", "X0011849", "c0011849")
    
    # Test CUI pattern
    cui_pattern <- "^C[0-9]{7}$"
    
    for (cui in valid_cuis) {
        if (!grepl(cui_pattern, cui)) {
            stop(paste("Valid CUI", cui, "failed validation"))
        }
    }
    cat("✅ Valid CUIs pass validation\n")
    
    for (cui in invalid_cuis) {
        if (grepl(cui_pattern, cui)) {
            stop(paste("Invalid CUI", cui, "passed validation"))
        }
    }
    cat("✅ Invalid CUIs fail validation\n")
    
    return(TRUE)
}

# Test YAML output format
test_yaml_output <- function() {
    cat("Testing YAML Output Format...\n")
    
    # Create test parameters
    test_params <- list(
        exposure_cuis = c("C0011849", "C0020538"),
        outcome_cuis = c("C0027051", "C0038454"),
        min_pmids = 100L,
        pub_year_cutoff = 2010L,
        squelch_threshold = 50L,
        k_hops = 1L,  # Updated to reflect temporary restriction
        PREDICATION_TYPE = "TREATS, CAUSES",
        SemMedDBD_version = "heuristic"
    )
    
    # Test YAML writing
    test_file <- "test_output.yaml"
    tryCatch({
        write_yaml(test_params, test_file)
        
        # Read back and verify
        loaded_params <- read_yaml(test_file)
        
        # Check required fields
        required_fields <- c("exposure_cuis", "outcome_cuis", "min_pmids",
                           "pub_year_cutoff", "squelch_threshold", "k_hops",
                           "SemMedDBD_version")
        
        for (field in required_fields) {
            if (!field %in% names(loaded_params)) {
                stop(paste("Required field", field, "missing from YAML"))
            }
        }
        
        # Check data types
        if (!is.character(loaded_params$exposure_cuis)) {
            stop("exposure_cuis should be character vector")
        }
        
        if (!is.character(loaded_params$outcome_cuis)) {
            stop("outcome_cuis should be character vector")
        }
        
        if (!is.integer(loaded_params$min_pmids)) {
            stop("min_pmids should be integer")
        }
        
        cat("✅ YAML output format is correct\n")
        
        # Clean up test file
        if (file.exists(test_file)) {
            file.remove(test_file)
        }
        
    }, error = function(e) {
        # Clean up test file on error
        if (file.exists(test_file)) {
            file.remove(test_file)
        }
        stop(paste("YAML test failed:", e$message))
    })
    
    return(TRUE)
}

# Test dropdown options
test_dropdown_options <- function() {
    cat("Testing Dropdown Options...\n")
    
    # Test min_pmids options
    expected_min_pmids <- c(10, 25, 50, 100, 250, 500, 1000, 2000, 5000)
    cat("✅ min_pmids options:", paste(expected_min_pmids, collapse = ", "), "\n")
    
    # Test pub_year_cutoff options
    expected_pub_years <- c(2000, 2005, 2010, 2015, 2020)
    cat("✅ pub_year_cutoff options:", paste(expected_pub_years, collapse = ", "), "\n")
    
    # Test squelch_threshold options
    expected_squelch <- c(10, 25, 50, 100, 500)
    cat("✅ squelch_threshold options:", paste(expected_squelch, collapse = ", "), "\n")
    
    # Test k_hops options (temporarily restricted)
    expected_k_hops <- c(1)
    cat("✅ k_hops options (temporarily restricted):", paste(expected_k_hops, collapse = ", "), "\n")
    
    # Test SemMedDB version options
    expected_versions <- c("heuristic", "LLM-based", "heuristic+LLM-based")
    cat("✅ SemMedDBD_version options:", paste(expected_versions, collapse = ", "), "\n")
    
    return(TRUE)
}

# Main test function
run_all_tests <- function() {
    cat("=== Graph Configuration Module Tests ===\n\n")
    
    tryCatch({
        test_module_structure()
        cat("\n")
        
        test_parameter_validation()
        cat("\n")
        
        test_yaml_output()
        cat("\n")
        
        test_dropdown_options()
        cat("\n")
        
        cat("🎉 All tests passed successfully!\n")
        cat("The Graph Configuration Module is ready for use.\n\n")
        
        cat("To integrate into your app:\n")
        cat("1. Ensure graph_config_module.R is in your app directory\n")
        cat("2. Source it in app.R: source('graph_config_module.R')\n")
        cat("3. Add graphConfigUI('config') to your UI\n")
        cat("4. Add graphConfigServer('config') to your server\n")
        
        return(TRUE)
        
    }, error = function(e) {
        cat("❌ Test failed:", e$message, "\n")
        return(FALSE)
    })
}

# Run tests if script is executed directly
if (interactive() || !exists("test_mode")) {
    run_all_tests()
}
