# DAG Data Configuration File
# This file contains the DAG structure and can be easily modified
# Replace the 'g' variable with your own dagitty graph

library(SEMgraph)
library(dagitty)
library(igraph)
library(visNetwork)
library(dplyr)

# Source modular components
source("dag_visualization.R")
source("node_information.R")
source("statistics.R")
source("data_upload.R")

# DYNAMIC DAG LOADING SYSTEM
# This system allows users to load DAG files through the UI

# Initialize variables
g <- NULL
dag_loaded_from <- "default"
available_dag_files <- character(0)

# Use modular functions (these are now defined in data_upload.R)
# scan_for_dag_files and load_dag_from_file are available from data_upload.R

# Scan for available DAG files
available_dag_files <- scan_for_dag_files()

# Try to load default file if available
default_files <- get_default_dag_files()
loaded_successfully <- FALSE

for (default_file in default_files) {
    if (default_file %in% available_dag_files) {
        result <- load_dag_from_file(default_file)
        if (result$success) {
            g <- result$dag
            dag_loaded_from <- default_file
            loaded_successfully <- TRUE
            cat("Auto-loaded DAG from", default_file, "\n")
            break
        }
    }
}

# If no default file worked, create a simple fallback
if (!loaded_successfully) {
    cat("No DAG files found. Using default example.\n")
    cat("Available DAG files detected:", if(length(available_dag_files) > 0) paste(available_dag_files, collapse = ", ") else "None", "\n")

    g <- create_fallback_dag()
    dag_loaded_from <- "default"
}

# Use modular functions (these are now defined in data_upload.R and node_information.R)
# create_network_data and process_large_dag are available from data_upload.R

# Create the network data with error handling
tryCatch({
    network_data <- process_large_dag(g)
    
    # Export the data for the Shiny app
    dag_nodes <- network_data$nodes
    dag_edges <- network_data$edges
    dag_object <- network_data$dag
    
    # Validate the data
    if (nrow(dag_nodes) == 0) {
        warning("No nodes found in the DAG. Please check your dagitty syntax.")
        # Create minimal fallback data
        dag_nodes <- data.frame(
            id = c("Node1", "Node2"),
            label = c("Node 1", "Node 2"),
            group = c("Other", "Other"),
            color = c("#808080", "#808080"),
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        )
        dag_edges <- data.frame(
            from = "Node1",
            to = "Node2",
            arrows = "to",
            smooth = TRUE,
            width = 1,
            color = "#666666",
            stringsAsFactors = FALSE
        )
    }
    
    cat("Successfully processed DAG with", nrow(dag_nodes), "nodes and", nrow(dag_edges), "edges.\n")
    cat("DAG loaded from:", dag_loaded_from, "\n")
    
}, error = function(e) {
    cat("Error processing DAG:", e$message, "\n")
    cat("Creating minimal fallback data...\n")
    
    # Create minimal fallback data
    dag_nodes <- data.frame(
        id = c("Error", "Fallback"),
        label = c("Error Node", "Fallback Node"),
        group = c("Other", "Other"),
        color = c("#FF0000", "#808080"),
        font.size = 14,
        font.color = "black",
        stringsAsFactors = FALSE
    )
    
    dag_edges <- data.frame(
        from = "Error",
        to = "Fallback",
        arrows = "to",
        smooth = TRUE,
        width = 1,
        color = "#666666",
        stringsAsFactors = FALSE
    )
    
    dag_object <- NULL
})

# Clean up intermediate variables
rm(network_data)
if (exists("g")) {
    cat("DAG loaded successfully. You can now run the Shiny app.\n")
}