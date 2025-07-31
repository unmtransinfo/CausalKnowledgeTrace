#!/usr/bin/env Rscript

# CausalKnowledgeTrace Application Launcher
# This script launches the Shiny application from the reorganized project structure
#
# Usage:
#   source("run_app.R")

# Load required library
if (!require(shiny, quietly = TRUE)) {
    stop("Shiny package is required but not installed. Please install it with: install.packages('shiny')")
}

# Set working directory to the shiny_app folder
app_dir <- file.path(getwd(), "shiny_app")

if (!dir.exists(app_dir)) {
    stop("Shiny app directory not found. Please ensure you're running this script from the project root directory.")
}

# Print startup information
cat("=== CausalKnowledgeTrace Application ===\n")
cat("Project Structure: Reorganized with separate Shiny app and graph creation components\n")
cat("Shiny App Directory:", app_dir, "\n")
cat("Graph Creation Directory:", file.path(dirname(app_dir), "graph_creation"), "\n")
cat("Configuration File: user_input.yaml (saved in project root)\n")
cat("=========================================\n\n")

# Configure application parameters
host <- "127.0.0.1"
port <- 3838  # Let Shiny handle port conflicts automatically

# Display connection information
cat("🚀 STARTING SHINY APPLICATION\n")
cat("=====================================\n")
cat("📍 URL: http://", host, ":", port, "\n", sep = "")
cat("🌐 Host: ", host, "\n")
cat("🔌 Port: ", port, "\n")
cat("=====================================\n")
cat("📱 Opening in your default browser...\n")
cat("🔗 If browser doesn't open, copy the URL above\n")
cat("⏹️  To stop: Press Ctrl+C (Cmd+C on Mac)\n")
cat("=====================================\n\n")

# Change to the shiny_app directory and run the app
old_wd <- getwd()

tryCatch({
    setwd(app_dir)
    cat("Loading application...\n")

    # Source and run the app
    app <- source("app.R")$value

    if (inherits(app, "shiny.appobj")) {
        cat("✅ Application loaded successfully\n")
        cat("🌐 Starting server...\n\n")

        # Run the application
        runApp(app,
               host = host,
               port = port,
               launch.browser = TRUE)
    } else {
        stop("app.R did not return a valid Shiny application object")
    }

}, error = function(e) {
    cat("❌ ERROR: ", e$message, "\n\n")
    cat("🔧 TROUBLESHOOTING:\n")
    cat("   1. Ensure all required packages are installed\n")
    cat("   2. Check for syntax errors in app.R\n")
    cat("   3. Try: warnings() to see detailed warnings\n")
    cat("   4. Try alternative: source('launch_shiny_app.R')\n")
}, finally = {
    setwd(old_wd)
})
