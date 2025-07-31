#!/usr/bin/env Rscript

# CausalKnowledgeTrace Shiny Application Launcher (Enhanced Version)
# This script provides a robust way to launch the Shiny application with detailed feedback
# 
# Usage:
#   source("launch_shiny_app.R")
#   or
#   Rscript launch_shiny_app.R

# Function to check and install required packages
check_and_install_packages <- function() {
    required_packages <- c("shiny", "shinydashboard", "visNetwork", "dplyr", "DT")
    missing_packages <- required_packages[!sapply(required_packages, requireNamespace, quietly = TRUE)]
    
    if (length(missing_packages) > 0) {
        cat("⚠️  Missing required packages:", paste(missing_packages, collapse = ", "), "\n")
        cat("Installing missing packages...\n")
        install.packages(missing_packages)
        
        # Verify installation
        still_missing <- missing_packages[!sapply(missing_packages, requireNamespace, quietly = TRUE)]
        if (length(still_missing) > 0) {
            stop("❌ Failed to install packages: ", paste(still_missing, collapse = ", "))
        }
        cat("✅ All required packages installed successfully!\n\n")
    }
}

# Function to find an available port
find_available_port <- function(start_port = 3838) {
    for (port in start_port:(start_port + 50)) {
        # Check if port is available by trying to bind to it
        tryCatch({
            # Create a temporary server socket to test the port
            sock <- socketConnection(host = "127.0.0.1", port = port, server = FALSE, 
                                   blocking = FALSE, open = "r+", timeout = 1)
            close(sock)
            # If we reach here, port might be in use, try next
        }, error = function(e) {
            # Error means port is likely available
            return(port)
        })
    }
    return(start_port)  # Fallback to default
}

# Main launch function
launch_shiny_app <- function() {
    cat("=== CausalKnowledgeTrace Shiny Application Launcher ===\n\n")
    
    # Step 1: Check packages
    cat("1️⃣  Checking required packages...\n")
    check_and_install_packages()
    
    # Step 2: Verify project structure
    cat("2️⃣  Verifying project structure...\n")
    project_root <- getwd()
    app_dir <- file.path(project_root, "shiny_app")
    
    if (!dir.exists(app_dir)) {
        stop("❌ Shiny app directory not found at: ", app_dir, 
             "\nPlease ensure you're running this script from the CausalKnowledgeTrace project root directory.")
    }
    
    if (!file.exists(file.path(app_dir, "app.R"))) {
        stop("❌ app.R not found in: ", app_dir)
    }
    
    cat("✅ Project structure verified\n")
    cat("   📁 Project root:", project_root, "\n")
    cat("   📁 Shiny app directory:", app_dir, "\n\n")
    
    # Step 3: Configure application
    cat("3️⃣  Configuring application...\n")
    host <- "127.0.0.1"
    port <- find_available_port()
    
    cat("✅ Configuration complete\n")
    cat("   🌐 Host:", host, "\n")
    cat("   🔌 Port:", port, "\n\n")
    
    # Step 4: Launch application
    cat("4️⃣  Launching Shiny application...\n")
    cat("=====================================\n")
    cat("🚀 STARTING CAUSAL KNOWLEDGE TRACE\n")
    cat("=====================================\n")
    cat("📍 Application URL: http://", host, ":", port, "\n", sep = "")
    cat("🌐 Host: ", host, "\n")
    cat("🔌 Port: ", port, "\n")
    cat("📂 App Directory: ", app_dir, "\n")
    cat("=====================================\n")
    cat("📱 Opening in your default browser...\n")
    cat("🔗 If browser doesn't open, copy the URL above\n")
    cat("⏹️  To stop: Press Ctrl+C (Cmd+C on Mac)\n")
    cat("=====================================\n\n")
    
    # Load required library
    library(shiny)
    
    # Launch the application
    tryCatch({
        # Change to app directory and source the app
        old_wd <- getwd()
        setwd(app_dir)

        # Source the app.R file which returns a shinyApp object
        app <- source("app.R")$value

        # Run the application with specified parameters
        runApp(app,
               host = host,
               port = port,
               launch.browser = TRUE)

    }, error = function(e) {
        cat("❌ Error launching application:\n")
        cat("   ", e$message, "\n\n")
        cat("🔧 Troubleshooting tips:\n")
        cat("   1. Check if port", port, "is already in use\n")
        cat("   2. Verify all required packages are installed\n")
        cat("   3. Check the app.R file for syntax errors\n")
        cat("   4. Run warnings() to see detailed warning messages\n")
        cat("   5. Try running from RStudio instead of command line\n")
        stop("Application launch failed")
    }, finally = {
        # Restore original working directory
        if (exists("old_wd")) setwd(old_wd)
    })
}

# Execute the launch function
launch_shiny_app()
