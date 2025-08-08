#!/usr/bin/env Rscript

# CausalKnowledgeTrace R Dependencies Installation Script
# This script installs all required and optional R packages for the application
# 
# Usage:
#   source("install_r_dependencies.R")
#   or
#   Rscript install_r_dependencies.R

cat("=== CausalKnowledgeTrace R Dependencies Installation ===\n\n")

# Function to check if a package is installed
is_package_installed <- function(package_name) {
    return(requireNamespace(package_name, quietly = TRUE))
}

# Function to install packages with error handling
install_package_safely <- function(package_name, required = TRUE) {
    if (is_package_installed(package_name)) {
        cat("✓", package_name, "is already installed\n")
        return(TRUE)
    }
    
    cat("📦 Installing", package_name, "...")
    
    tryCatch({
        install.packages(package_name, dependencies = TRUE, quiet = TRUE)
        
        if (is_package_installed(package_name)) {
            cat(" ✅ SUCCESS\n")
            return(TRUE)
        } else {
            cat(" ❌ FAILED (package not found after installation)\n")
            return(FALSE)
        }
    }, error = function(e) {
        cat(" ❌ FAILED:", e$message, "\n")
        return(FALSE)
    })
}

# Core required packages (application won't work without these)
cat("1️⃣  Installing REQUIRED packages...\n")
required_packages <- c(
    "shiny",           # Core Shiny framework
    "shinydashboard",  # Dashboard UI components
    "visNetwork",      # Interactive network visualization
    "dplyr",           # Data manipulation
    "DT",              # Interactive data tables
    "dagitty",         # DAG analysis and causal inference
    "igraph",          # Graph analysis and manipulation
    "yaml"             # YAML configuration file support
)

required_failed <- c()
for (pkg in required_packages) {
    success <- install_package_safely(pkg, required = TRUE)
    if (!success) {
        required_failed <- c(required_failed, pkg)
    }
}

# Optional packages (enhance functionality but not strictly required)
cat("\n2️⃣  Installing OPTIONAL packages...\n")
optional_packages <- c(
    "shinyjs",         # Enhanced UI interactions
    "SEMgraph",        # Structural equation modeling graphs
    "ggplot2",         # Enhanced plotting capabilities
    "testthat",        # Testing framework
    "knitr",           # Dynamic report generation
    "rmarkdown"        # R Markdown support
)

optional_failed <- c()
for (pkg in optional_packages) {
    success <- install_package_safely(pkg, required = FALSE)
    if (!success) {
        optional_failed <- c(optional_failed, pkg)
    }
}

# Installation summary
cat("\n=== Installation Summary ===\n")

if (length(required_failed) == 0) {
    cat("✅ All REQUIRED packages installed successfully!\n")
} else {
    cat("❌ FAILED to install required packages:", paste(required_failed, collapse = ", "), "\n")
    cat("   The application may not work properly without these packages.\n")
}

if (length(optional_failed) == 0) {
    cat("✅ All OPTIONAL packages installed successfully!\n")
} else {
    cat("⚠️  Some optional packages failed to install:", paste(optional_failed, collapse = ", "), "\n")
    cat("   The application will work but some features may be limited.\n")
}

# Final verification
cat("\n3️⃣  Verifying core functionality...\n")
core_test_packages <- c("shiny", "shinydashboard", "visNetwork", "dplyr", "DT", "dagitty", "igraph")
all_core_available <- all(sapply(core_test_packages, is_package_installed))

if (all_core_available) {
    cat("✅ Core functionality verification PASSED\n")
    cat("🚀 You can now run the Shiny application!\n")
    cat("\n   To start the application, run:\n")
    cat("   source('launch_shiny_app.R')\n")
    cat("   or\n")
    cat("   source('simple_launch.R')\n")
} else {
    cat("❌ Core functionality verification FAILED\n")
    cat("   Please manually install the missing required packages.\n")
}

cat("\n=== Installation Complete ===\n")
