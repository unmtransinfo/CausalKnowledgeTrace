# Graph Configuration Module (Main Wrapper)
# This module provides a user interface for configuring knowledge graph parameters
# and saves them to a user_input.yaml file for downstream processing
# Author: CausalKnowledgeTrace Application
# Dependencies: shiny, yaml
#
# This file has been modularized into focused sub-modules:
# - graph_config_ui.R: UI components and JavaScript
# - graph_config_server.R: Server logic and event handlers
# - graph_config_validation.R: Validation functions
# - graph_config_helpers.R: Helper functions, YAML operations, and tests

# Required libraries for this module
if (!require(shiny)) stop("shiny package is required")
if (!require(yaml)) {
    message("Installing yaml package...")
    install.packages("yaml")
    library(yaml)
}

# Source CUI search module
tryCatch({
    source("modules/cui_search.R", local = TRUE)
    cui_search_available <- TRUE
    cat("CUI search module loaded successfully\n")
}, error = function(e) {
    cui_search_available <- FALSE
    cat("CUI search module not available:", e$message, "\n")
    cat("Falling back to manual CUI entry only\n")
})

# Try to load shinyjs for better UI updates
tryCatch({
    if (!require(shinyjs)) {
        message("Installing shinyjs package for better UI updates...")
        install.packages("shinyjs")
        library(shinyjs)
    }
    shinyjs_available <- TRUE
}, error = function(e) {
    shinyjs_available <- FALSE
    message("shinyjs not available, using alternative UI update methods")
})

# Source sub-modules with dynamic path resolution
source_module <- function(module_name) {
    # Try multiple possible paths
    possible_paths <- c(
        file.path("shiny_app", "modules", module_name),
        file.path("modules", module_name),
        module_name
    )

    for (path in possible_paths) {
        if (file.exists(path)) {
            tryCatch({
                source(path, local = FALSE)
                cat(sprintf("✓ Loaded %s from %s\n", module_name, path))
                return(TRUE)
            }, error = function(e) {
                cat(sprintf("✗ Error loading %s from %s: %s\n", module_name, path, e$message))
            })
        }
    }

    stop(sprintf("Could not find module: %s\nTried paths: %s",
                module_name, paste(possible_paths, collapse = ", ")))
}

# Source all graph_config sub-modules
cat("\n=== Loading Graph Configuration Sub-Modules ===\n")
source_module("graph_config_ui.R")
source_module("graph_config_validation.R")
source_module("graph_config_helpers.R")
source_module("graph_config_server.R")
cat("=== All Graph Configuration Sub-Modules Loaded ===\n\n")

# Note: All functions (graphConfigUI, graphConfigServer, validate_graph_config,
# load_graph_config, test_graph_config_module) are now defined in the sub-modules
# and are available for use in the main application.
