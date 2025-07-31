# Simple Shiny App Launcher - Minimal version that should always work
# Usage: source("simple_launch.R")

cat("🚀 CausalKnowledgeTrace - Simple Launcher\n")
cat("==========================================\n")

# Load Shiny
library(shiny)

# Check directory
if (!dir.exists("shiny_app")) {
    stop("❌ shiny_app directory not found. Run from project root.")
}

# Set working directory and run
setwd("shiny_app")
cat("📂 Changed to shiny_app directory\n")
cat("🔄 Loading application...\n")

# Source the app
app <- source("app.R")$value

cat("✅ Application loaded\n")
cat("🌐 Starting server on http://127.0.0.1:3838\n")
cat("📱 Browser should open automatically\n")
cat("⏹️  Press Ctrl+C to stop\n")
cat("==========================================\n\n")

# Run the app
runApp(app, host = "127.0.0.1", port = 3838, launch.browser = TRUE)
