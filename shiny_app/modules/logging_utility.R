#' Logging Utility Module
#' 
#' Provides centralized logging functionality for the Shiny application
#' Logs are written to files in the logs/ directory
#' 
#' Author: CausalKnowledgeTrace
#' Date: 2025

# Global logging configuration
.log_config <- list(
    enabled = TRUE,
    log_dir = "../logs",
    log_file = NULL,
    console_output = FALSE  # Set to TRUE to also print to console
)

#' Initialize Logging System
#'
#' Sets up the logging directory and creates a new log file with timestamp
#'
#' @param log_dir Directory to store log files (default: ../logs)
#' @param console_output Whether to also print to console (default: FALSE)
#' @return Invisibly returns the log file path
#' @export
init_logging <- function(log_dir = "../logs", console_output = FALSE) {
    # Create logs directory if it doesn't exist
    if (!dir.exists(log_dir)) {
        dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
    }
    
    # Create log file with timestamp
    timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
    log_file <- file.path(log_dir, paste0("app_", timestamp, ".log"))
    
    # Initialize log file with header
    header <- paste0(
        "=== CausalKnowledgeTrace Application Log ===\n",
        "Started: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
        "Log File: ", log_file, "\n",
        "=============================================\n\n"
    )
    
    write(header, file = log_file, append = FALSE)
    
    # Update global config
    .log_config$log_dir <<- log_dir
    .log_config$log_file <<- log_file
    .log_config$console_output <<- console_output
    .log_config$enabled <<- TRUE
    
    invisible(log_file)
}

#' Write to Log File
#'
#' Writes a message to the log file with timestamp
#'
#' @param message Character string to log
#' @param level Log level (INFO, WARNING, ERROR, DEBUG)
#' @param console_override Override global console_output setting
#' @return Invisibly returns TRUE if successful
#' @export
log_message <- function(message, level = "INFO", console_override = NULL) {
    if (!.log_config$enabled || is.null(.log_config$log_file)) {
        return(invisible(FALSE))
    }
    
    # Format log message with timestamp and level
    timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    formatted_msg <- paste0("[", timestamp, "] [", level, "] ", message)
    
    # Write to log file
    tryCatch({
        write(formatted_msg, file = .log_config$log_file, append = TRUE)
    }, error = function(e) {
        warning("Failed to write to log file: ", e$message)
    })
    
    # Optionally print to console
    console_output <- if (!is.null(console_override)) console_override else .log_config$console_output
    if (console_output) {
        cat(formatted_msg, "\n")
    }
    
    invisible(TRUE)
}

#' Log Database Configuration
#'
#' Logs database connection parameters
#'
#' @param host Database host
#' @param port Database port
#' @param dbname Database name
#' @param schema Database schema
#' @param user Database user
#' @export
log_db_config <- function(host, port, dbname, schema, user) {
    msg <- paste0(
        "Database Configuration: Host=", host, 
        " Port=", port, 
        " Database=", dbname, 
        " Schema=", schema, 
        " User=", user
    )
    log_message(msg, "INFO")
}

#' Log Database Pool Initialization
#'
#' Logs database pool initialization details
#'
#' @param min_size Minimum pool size
#' @param max_size Maximum pool size
#' @export
log_db_pool <- function(min_size, max_size) {
    msg <- paste0("Database Connection Pool: Size ", min_size, " - ", max_size, " connections")
    log_message(msg, "INFO")
}

#' Log Environment Variables
#'
#' Logs environment variables being set from .env file
#'
#' @param var_name Variable name
#' @param var_value Variable value (will be masked if contains password)
#' @export
log_env_var <- function(var_name, var_value) {
    # Mask sensitive values
    display_value <- if (grepl("PASSWORD|SECRET|TOKEN", toupper(var_name))) {
        "***MASKED***"
    } else {
        var_value
    }
    
    msg <- paste0("Environment: ", var_name, " = ", display_value)
    log_message(msg, "DEBUG")
}

#' Log CUI Mappings
#'
#' Logs consolidated CUI mappings
#'
#' @param count Number of mappings loaded
#' @param message Additional message
#' @export
log_cui_mappings <- function(count, message = "") {
    msg <- paste0("Loaded consolidated CUI mappings: ", count, " nodes")
    if (message != "") {
        msg <- paste0(msg, " - ", message)
    }
    log_message(msg, "INFO")
}

#' Get Log File Path
#'
#' Returns the current log file path
#'
#' @return Character string with log file path
#' @export
get_log_file <- function() {
    .log_config$log_file
}

#' Close Logging
#'
#' Finalizes the log file
#'
#' @export
close_logging <- function() {
    if (!is.null(.log_config$log_file)) {
        footer <- paste0(
            "\n=============================================\n",
            "Ended: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n",
            "=============================================\n"
        )
        write(footer, file = .log_config$log_file, append = TRUE)
        .log_config$enabled <<- FALSE
    }
}

