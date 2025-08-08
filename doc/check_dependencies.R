#!/usr/bin/env Rscript

# CausalKnowledgeTrace Dependency Checker
# This script verifies that all required dependencies are installed and working
# 
# Usage:
#   source("check_dependencies.R")
#   or
#   Rscript check_dependencies.R

cat("=== CausalKnowledgeTrace Dependency Checker ===\n\n")

# Function to check package availability and version
check_package <- function(package_name, required = TRUE) {
    status_icon <- if (required) "🔴" else "🟡"
    
    if (requireNamespace(package_name, quietly = TRUE)) {
        tryCatch({
            version <- as.character(packageVersion(package_name))
            cat("✅", package_name, paste0("(v", version, ")"), "\n")
            return(TRUE)
        }, error = function(e) {
            cat("⚠️ ", package_name, "- installed but version check failed\n")
            return(TRUE)
        })
    } else {
        priority <- if (required) "REQUIRED" else "OPTIONAL"
        cat(status_icon, package_name, paste0("- NOT INSTALLED (", priority, ")\n"))
        return(FALSE)
    }
}

# Check R version
cat("📋 R Environment Information:\n")
cat("   R Version:", R.version.string, "\n")
cat("   Platform: ", R.version$platform, "\n\n")

# Required packages
cat("1️⃣  Checking REQUIRED packages:\n")
required_packages <- c(
    "shiny", "shinydashboard", "visNetwork", "dplyr", 
    "DT", "dagitty", "igraph", "yaml"
)

required_missing <- c()
for (pkg in required_packages) {
    if (!check_package(pkg, required = TRUE)) {
        required_missing <- c(required_missing, pkg)
    }
}

# Optional packages
cat("\n2️⃣  Checking OPTIONAL packages:\n")
optional_packages <- c(
    "shinyjs", "SEMgraph", "ggplot2", "testthat", "knitr", "rmarkdown"
)

optional_missing <- c()
for (pkg in optional_packages) {
    if (!check_package(pkg, required = FALSE)) {
        optional_missing <- c(optional_missing, pkg)
    }
}

# Functionality tests
cat("\n3️⃣  Testing core functionality:\n")

# Test 1: Shiny app creation
cat("   Testing Shiny app creation... ")
tryCatch({
    library(shiny, quietly = TRUE)
    test_app <- shinyApp(
        ui = fluidPage("Test"),
        server = function(input, output) {}
    )
    if (inherits(test_app, "shiny.appobj")) {
        cat("✅ PASS\n")
    } else {
        cat("❌ FAIL\n")
    }
}, error = function(e) {
    cat("❌ FAIL:", e$message, "\n")
})

# Test 2: DAG processing
cat("   Testing DAG processing... ")
tryCatch({
    library(dagitty, quietly = TRUE)
    library(igraph, quietly = TRUE)
    test_dag <- dagitty('dag { A -> B }')
    if (length(names(test_dag)) > 0) {
        cat("✅ PASS\n")
    } else {
        cat("❌ FAIL\n")
    }
}, error = function(e) {
    cat("❌ FAIL:", e$message, "\n")
})

# Test 3: Network visualization
cat("   Testing network visualization... ")
tryCatch({
    library(visNetwork, quietly = TRUE)
    nodes <- data.frame(id = 1:2, label = c("A", "B"))
    edges <- data.frame(from = 1, to = 2)
    vis <- visNetwork(nodes, edges)
    if (inherits(vis, "visNetwork")) {
        cat("✅ PASS\n")
    } else {
        cat("❌ FAIL\n")
    }
}, error = function(e) {
    cat("❌ FAIL:", e$message, "\n")
})

# Summary
cat("\n=== Summary ===\n")

if (length(required_missing) == 0) {
    cat("✅ All REQUIRED packages are installed!\n")
    readiness_status <- "READY"
} else {
    cat("❌ Missing required packages:", paste(required_missing, collapse = ", "), "\n")
    readiness_status <- "NOT READY"
}

if (length(optional_missing) > 0) {
    cat("⚠️  Missing optional packages:", paste(optional_missing, collapse = ", "), "\n")
    cat("   (Application will work but some features may be limited)\n")
}

cat("\n🚀 Application Status:", readiness_status, "\n")

if (readiness_status == "READY") {
    cat("\n   You can now run the application with:\n")
    cat("   source('launch_shiny_app.R')\n")
} else {
    cat("\n   Install missing packages with:\n")
    cat("   source('install_r_dependencies.R')\n")
}

cat("\n=== Check Complete ===\n")
