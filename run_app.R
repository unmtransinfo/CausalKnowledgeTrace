#!/usr/bin/env Rscript

# CausalKnowledgeTrace Application Launcher
# This script launches the Shiny application from the reorganized project structure
#
# Usage:
#   source("run_app.R")

# Load required libraries
if (!require(shiny, quietly = TRUE)) {
    stop("Shiny package is required but not installed. Please install it with: install.packages('shiny')")
}

# Function to check if a port is available using system netstat command
is_port_available <- function(port, host = "127.0.0.1") {
    # Method 1: Use system command to check if port is in use
    if (Sys.info()["sysname"] == "Linux" || Sys.info()["sysname"] == "Darwin") {
        # Use netstat to check for listening ports
        result <- tryCatch({
            system_output <- system(paste0("netstat -tuln | grep ':", port, " '"), intern = TRUE, ignore.stderr = TRUE)
            length(system_output) == 0  # If no output, port is available
        }, error = function(e) {
            # If netstat fails, fall back to socket method
            NULL
        })

        if (!is.null(result)) {
            return(result)
        }
    }

    # Method 2: Fallback socket-based check
    tryCatch({
        # Try to create a server socket and immediately close it
        con <- socketConnection(host = host, port = port, server = TRUE, blocking = FALSE, timeout = 0.1)
        close(con)
        return(TRUE)  # Port is available
    }, error = function(e) {
        # Check specific error messages that indicate port is in use
        error_msg <- tolower(as.character(e$message))
        if (grepl("address already in use|bind|cannot be opened|port.*cannot be opened", error_msg)) {
            return(FALSE)  # Port is definitely in use
        }
        # For other errors, be conservative and assume port is in use
        return(FALSE)
    })
}

# Function to find an available port starting from a given port
find_available_port <- function(start_port = 3838, max_attempts = 100, host = "127.0.0.1") {
    for (port in start_port:(start_port + max_attempts - 1)) {
        if (is_port_available(port, host)) {
            return(port)
        }
    }
    stop("Could not find an available port after ", max_attempts, " attempts starting from port ", start_port)
}

# Set working directory to the shiny_app folder
app_dir <- file.path(getwd(), "shiny_app")

if (!dir.exists(app_dir)) {
    stop("Shiny app directory not found. Please ensure you're running this script from the project root directory.")
}

# Parse command line arguments
args <- commandArgs(trailingOnly = TRUE)

# Configure application parameters
# Use environment variable or default to 0.0.0.0 for Docker compatibility
# Set SHINY_HOST=127.0.0.1 for local development if needed
host <- Sys.getenv("SHINY_HOST", unset = "0.0.0.0")

# Get port from environment variable or use default
app_port_env <- Sys.getenv("APP_PORT", unset = "")
if (app_port_env != "") {
    default_port <- as.integer(app_port_env)
} else {
    default_port <- 3838
}

# Find an available port (silently)
port_available <- is_port_available(default_port, host)

if (port_available) {
    port <- default_port
} else {
    port <- find_available_port(default_port + 1, host = host)
}

# Display connection information
cat("\n🚀 STARTING SHINY APPLICATION\n")
cat("=====================================\n")
cat("📍 URL: http://", host, ":", port, "\n", sep = "")
cat("🌐 Host: ", host, "\n")
cat("🔌 Port: ", port, "\n")
if (port != default_port) {
    cat("📝 Note: Using port", port, "instead of default", default_port, "\n")
}
cat("=====================================\n")
cat("📱 Opening in your default browser...\n")
cat("🔗 If browser doesn't open, copy the URL above\n")
cat("⏹️  To stop: Press Ctrl+C (Cmd+C on Mac)\n")
cat("=====================================\n\n")

# Change to the shiny_app directory and run the app
old_wd <- getwd()

tryCatch({
    setwd(app_dir)

    # Source and run the app (suppress library loading messages)
    suppressPackageStartupMessages({
        app <- source("app.R")$value
    })

    if (inherits(app, "shiny.appobj")) {
        # Get and display log file path if logging is available
        if (exists("get_log_file")) {
            log_file_path <- get_log_file()
            if (!is.null(log_file_path)) {
                cat("📋 Log File: ", log_file_path, "\n")
                cat("=====================================\n\n")
            }
        }

        # Handle browser detection for different environments
        browser_option <- getOption("browser")
        if (is.null(browser_option) || browser_option == "") {
            # Set browser for environments without default browser
            if (Sys.which("xdg-open") != "") {
                options(browser = "xdg-open")
                launch_browser <- TRUE
            } else if (Sys.which("open") != "") {  # macOS
                options(browser = "open")
                launch_browser <- TRUE
            } else {
                launch_browser <- FALSE
            }
        } else {
            launch_browser <- TRUE
        }

        # Run the application
        runApp(app,
               host = host,
               port = port,
               launch.browser = launch_browser)
    } else {
        stop("app.R did not return a valid Shiny application object")
    }

}, error = function(e) {
    cat("❌ ERROR: ", e$message, "\n\n")
    cat("🔧 TROUBLESHOOTING:\n")
    cat("   1. Ensure all required packages are installed\n")
    cat("   2. Check for syntax errors in app.R\n")
    cat("   3. Try: warnings() to see detailed warnings\n")
}, finally = {
    setwd(old_wd)
})
