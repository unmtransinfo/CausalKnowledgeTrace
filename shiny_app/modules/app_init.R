# Application Initialization Module
# This module handles library loading, logging setup, and initial data structures
# Author: Refactored from app.R

#' Initialize Application Libraries
#'
#' Loads all required libraries with suppressed startup messages
#' @keywords internal
init_app_libraries <- function() {
    suppressPackageStartupMessages({
        library(shiny)
        library(shinydashboard)
        library(visNetwork)
        library(dplyr)
        library(DT)
        library(jsonlite)
        library(htmltools)
        library(shinyjs)
        library(SEMgraph)
        library(dagitty)
        library(igraph)
    })
}

#' Initialize Application Logging
#'
#' Sets up logging system with specified configuration
#' @param log_dir Directory for log files
#' @param console_output Whether to output to console
#' @keywords internal
init_app_logging <- function(log_dir = "../logs", console_output = FALSE) {
    # Source logging utility (not local so functions are available globally)
    source("modules/logging_utility.R")

    # Initialize logging system
    init_logging(log_dir = log_dir, console_output = console_output)
}

#' Source Application Modules
#'
#' Sources all required modules for the application
#' @return List with availability flags for optional modules
#' @keywords internal
source_app_modules <- function() {
    # Source required modules (not local so functions are available globally)
    source("modules/dag_visualization.R")
    source("modules/node_information.R")
    source("modules/statistics.R")
    source("modules/data_upload.R")
    source("modules/causal_analysis.R")
    source("modules/optimized_loading.R")
    source("modules/json_to_html.R")

    # Try to source optional modules
    graph_config_available <- tryCatch({
        source("modules/graph_config_module.R")
        TRUE
    }, error = function(e) {
        FALSE
    })

    database_connection_available <- tryCatch({
        source("modules/database_connection.R")
        TRUE
    }, error = function(e) {
        FALSE
    })

    return(list(
        graph_config_available = graph_config_available,
        database_connection_available = database_connection_available
    ))
}

#' Initialize Database Connection Pool
#'
#' Pre-warms database connection pool before server starts
#' @param database_connection_available Whether database module is available
#' @keywords internal
init_app_database <- function(database_connection_available) {
    if (database_connection_available) {
        if (exists("log_message")) {
            log_message("=== PRE-WARMING CONNECTION POOL BEFORE SERVER START ===", "INFO")
        }
        
        db_init_result <- init_database_pool()
        if (!db_init_result$success) {
            if (exists("log_message")) {
                log_message(paste("⚠️  Database connection failed:", db_init_result$message), "WARNING")
            }
        } else {
            if (exists("log_message")) {
                log_message("✅ Database connection pool pre-warmed and ready!", "INFO")
                log_message("=== SERVER READY TO ACCEPT REQUESTS ===", "INFO")
            }
        }
    }
}

#' Create Empty Data Structures
#'
#' Creates empty data structures for immediate app startup
#' @return List with empty nodes, edges, dag_object, and legend data
#' @export
create_empty_data_structures <- function() {
    dag_nodes <- data.frame(
        id = character(0),
        label = character(0),
        group = character(0),
        color = character(0),
        font.size = numeric(0),
        font.color = character(0),
        stringsAsFactors = FALSE
    )
    
    dag_edges <- data.frame(
        from = character(0),
        to = character(0),
        arrows = character(0),
        smooth = logical(0),
        width = numeric(0),
        color = character(0),
        stringsAsFactors = FALSE
    )
    
    dag_object <- NULL
    unique_groups <- character(0)
    group_colors <- character(0)
    
    return(list(
        dag_nodes = dag_nodes,
        dag_edges = dag_edges,
        dag_object = dag_object,
        unique_groups = unique_groups,
        group_colors = group_colors
    ))
}

