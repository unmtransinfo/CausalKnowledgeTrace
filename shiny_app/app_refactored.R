# CKT - Causal Knowledge Trace (Refactored)
#
# This Shiny application provides an interactive interface for visualizing
# and analyzing Directed Acyclic Graphs (DAGs) for causal inference.
#
# Features:
# - CKT - Causal Knowledge Trace visualization with visNetwork
# - Causal analysis tools (adjustment sets, instrumental variables)
# - Node information and statistics
# - File upload and management
# - Graph configuration and creation
#
# Author: Scott A. Malec PhD (Refactored February 2025)
# Date: February 2025

# Load required libraries
library(shiny)
library(shinydashboard)
library(shinyjs)
library(visNetwork)
library(dagitty)
library(DT)
library(yaml)

# Source utility functions and modules (existing)
tryCatch({
    if (file.exists("utils/dag_utils.R")) source("utils/dag_utils.R")
    if (file.exists("utils/network_utils.R")) source("utils/network_utils.R")
    if (file.exists("utils/causal_utils.R")) source("utils/causal_utils.R")
}, error = function(e) {
    cat("Warning: Some utility files not found:", e$message, "\n")
})

# Source refactored modules instead of original ones
source("modules/statistics_refactored.R")
source("modules/data_upload_refactored.R")

# Try to source graph configuration module if it exists
tryCatch({
    if (file.exists("modules/graph_config_refactored.R")) {
        source("modules/graph_config_refactored.R")
        graph_config_available <- TRUE
    } else if (file.exists("modules/graph_config_module.R")) {
        source("modules/graph_config_module.R")
        graph_config_available <- TRUE
    } else {
        graph_config_available <- FALSE
    }
}, error = function(e) {
    graph_config_available <- FALSE
    cat("Graph configuration module not found:", e$message, "\n")
})

# Source refactored UI and server components
source("ui/ui_components.R")
source("server/server_logic.R")
source("server/file_operations.R")
source("server/causal_analysis.R")

# Define UI using modular components
ui <- dashboardPage(
    create_dashboard_header(),
    create_dashboard_sidebar(),
    create_dashboard_body()
)

# Define server using modular components
server <- function(input, output, session) {
    
    # Create main server logic and get current_data reactive values
    current_data <- create_main_server(input, output, session)
    
    # Initialize file operations server logic
    create_file_operations_server(input, output, session, current_data)
    
    # Initialize causal analysis server logic
    create_causal_analysis_server(input, output, session, current_data)
    
    # Initialize existing module servers
    callModule(statisticsModuleServer, "stats_module", 
               reactive({ current_data$nodes }), 
               reactive({ current_data$edges }),
               reactive({ current_data$dag_object }))
    
    callModule(dataUploadModuleServer, "upload_module")
    
    # Initialize graph configuration module if available
    if (exists("graph_config_available") && graph_config_available) {
        tryCatch({
            callModule(graphConfigModuleServer, "graph_config")
        }, error = function(e) {
            cat("Error initializing graph config module:", e$message, "\n")
        })
    }
}

# Create and return the Shiny application object
shinyApp(ui = ui, server = server)
