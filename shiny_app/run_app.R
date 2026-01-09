#!/usr/bin/env Rscript
# CausalKnowledgeTrace Shiny App Launcher
#
# This script launches the Shiny app.

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
cat("Starting Shiny application...\n\n")

# Get port from environment variable or use default
app_port_env <- Sys.getenv("APP_PORT", unset = "")
if (app_port_env != "") {
    app_port <- as.integer(app_port_env)
} else {
    app_port <- 3838
}

cat("Access the app at: http://localhost:", app_port, "\n\n", sep = "")

# Launch the Shiny app
tryCatch({
    # Check if app.R exists
    if (file.exists("app.R")) {
        runApp("app.R", port = app_port, host = "0.0.0.0")
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

# Show usage if help requested
args <- commandArgs(trailingOnly = TRUE)
if ("--help" %in% args || "-h" %in% args) {
    cat("\nUsage: Rscript run_app.R\n")
    cat("Launches the CausalKnowledgeTrace Shiny application.\n\n")
}
