#!/usr/bin/env Rscript
# CausalKnowledgeTrace Shiny App Launcher with Optimization
# 
# This script launches the Shiny app with automatic optimization of causal assertions files
# for improved performance.

# Load required libraries
library(shiny)

# Set working directory to the shiny_app folder
if (basename(getwd()) != "shiny_app") {
    if (file.exists("shiny_app")) {
        setwd("shiny_app")
    } else {
        stop("Please run this script from the project root directory or shiny_app directory")
    }
}

cat("=== CausalKnowledgeTrace Shiny App Launcher ===\n")
cat("Starting app with performance optimizations...\n\n")

# Check for optimization utilities
optimization_available <- file.exists("utils/optimize_all_files.R") && 
                         file.exists("modules/optimized_loading.R")

if (optimization_available) {
    cat("Performance optimization modules detected.\n")
    
    # Parse command line arguments
    args <- commandArgs(trailingOnly = TRUE)
    auto_optimize <- "--optimize" %in% args || "--auto-optimize" %in% args
    force_optimize <- "--force-optimize" %in% args
    skip_optimize <- "--no-optimize" %in% args
    
    if (!skip_optimize) {
        # Check if optimized files exist
        result_dirs <- c("../graph_creation/result", "../graph_creation/output")
        needs_optimization <- FALSE
        
        for (dir in result_dirs) {
            if (dir.exists(dir)) {
                # Check for original causal_assertions files
                original_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
                
                if (length(original_files) > 0) {
                    cat("Found", length(original_files), "causal assertions files in", dir, "\n")
                    
                    # Check if optimized versions exist
                    for (file in original_files) {
                        k_hops_match <- regmatches(basename(file), regexpr("\\d+", basename(file)))
                        if (length(k_hops_match) > 0) {
                            k_hops <- as.numeric(k_hops_match[1])
                            
                            # Check for any optimized version
                            lightweight_file <- file.path(dir, paste0("causal_assertions_", k_hops, "_lightweight.json"))
                            binary_file <- file.path(dir, paste0("causal_assertions_", k_hops, "_binary.rds"))
                            
                            if (!file.exists(lightweight_file) && !file.exists(binary_file)) {
                                needs_optimization <- TRUE
                                cat("  - No optimized files found for k_hops =", k_hops, "\n")
                            } else {
                                cat("  - Optimized files exist for k_hops =", k_hops, "\n")
                            }
                        }
                    }
                }
            }
        }
        
        # Decide whether to run optimization
        run_optimization <- force_optimize || (needs_optimization && (auto_optimize || interactive()))
        
        if (needs_optimization && !auto_optimize && !force_optimize && interactive()) {
            cat("\nOptimized files not found. Running optimization will significantly improve app performance.\n")
            cat("This is a one-time process that may take a few minutes.\n")
            response <- readline("Run optimization now? (y/n): ")
            run_optimization <- tolower(substr(response, 1, 1)) == "y"
        }
        
        if (run_optimization) {
            cat("\nRunning performance optimization...\n")
            cat("This may take a few minutes for large files.\n\n")
            
            tryCatch({
                # Source and run optimization
                source("utils/optimize_all_files.R")
                result <- optimize_all_files(force_regenerate = force_optimize)
                
                if (result$summary$overall_success) {
                    cat("\n✓ Optimization completed successfully!\n")
                    cat("The app will now load significantly faster.\n\n")
                } else {
                    cat("\n⚠ Optimization completed with some issues.\n")
                    cat("The app will still work but may not be fully optimized.\n\n")
                }
            }, error = function(e) {
                cat("\n✗ Optimization failed:", e$message, "\n")
                cat("The app will still work with standard loading.\n\n")
            })
        } else if (needs_optimization) {
            cat("\nSkipping optimization. You can run it later with:\n")
            cat("  Rscript run_app.R --optimize\n\n")
        }
    } else {
        cat("Optimization skipped (--no-optimize flag detected).\n\n")
    }
} else {
    cat("Optimization modules not found. Using standard loading.\n\n")
}

# Initialize graph cache system
tryCatch({
    source("modules/graph_cache.R")
    initialize_graph_cache()
    cat("Graph cache system initialized.\n")
}, error = function(e) {
    cat("Warning: Could not initialize graph cache:", e$message, "\n")
})

# Source optimized loading if available
if (file.exists("modules/optimized_loading.R")) {
    tryCatch({
        source("modules/optimized_loading.R")
        cat("Optimized loading system loaded.\n")
    }, error = function(e) {
        cat("Warning: Could not load optimized loading system:", e$message, "\n")
    })
}

cat("\nStarting Shiny application...\n")
cat("The app will automatically use the fastest available loading method.\n")
cat("Access the app at: http://localhost:3838\n\n")

# Launch the Shiny app
tryCatch({
    # Check if app.R exists
    if (file.exists("app.R")) {
        runApp("app.R", port = 3838, host = "0.0.0.0")
    } else {
        stop("app.R not found in current directory")
    }
}, error = function(e) {
    cat("Error starting Shiny app:", e$message, "\n")
    cat("\nTrying alternative startup methods...\n")
    
    # Try running the app directly
    if (file.exists("app.R")) {
        source("app.R")
    } else {
        stop("Could not start the Shiny application")
    }
})

# Print usage information for command line arguments
print_usage <- function() {
    cat("\nUsage: Rscript run_app.R [options]\n")
    cat("\nOptions:\n")
    cat("  --optimize, --auto-optimize  Automatically run optimization if needed\n")
    cat("  --force-optimize            Force regeneration of all optimized files\n")
    cat("  --no-optimize               Skip optimization entirely\n")
    cat("\nExamples:\n")
    cat("  Rscript run_app.R                    # Interactive optimization prompt\n")
    cat("  Rscript run_app.R --optimize         # Auto-optimize if needed\n")
    cat("  Rscript run_app.R --force-optimize   # Force regenerate all optimized files\n")
    cat("  Rscript run_app.R --no-optimize      # Skip optimization\n")
}

# Show usage if help requested
args <- commandArgs(trailingOnly = TRUE)
if ("--help" %in% args || "-h" %in% args) {
    print_usage()
}
