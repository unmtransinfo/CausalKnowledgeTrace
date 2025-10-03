# DAG Data Configuration File
# This file contains the DAG structure and can be easily modified
# Replace the 'g' variable with your own dagitty graph

library(SEMgraph)
library(dagitty)
library(igraph)
library(visNetwork)
library(dplyr)

# Source modular components
source("modules/dag_visualization.R")
source("modules/node_information.R")
source("modules/statistics.R")
source("modules/data_upload.R")
# Note: json_to_html.R is sourced in app.R for global availability

# DYNAMIC DAG LOADING SYSTEM
# This system allows users to load DAG files through the UI
# Modified to start without loading any graph files automatically

# Initialize variables for empty state
g <- NULL
dag_loaded_from <- NULL
available_dag_files <- character(0)

# Use modular functions (these are now defined in data_upload.R)
# scan_for_dag_files and load_dag_from_file are available from data_upload.R

# Scan for available DAG files but don't load them automatically
available_dag_files <- scan_for_dag_files()

cat("Application starting without loading graph files.\n")
cat("Available DAG files detected:", if(length(available_dag_files) > 0) paste(available_dag_files, collapse = ", ") else "None", "\n")
cat("Use the Data Upload tab to select and load a graph file.\n")

# Use modular functions (these are now defined in data_upload.R and node_information.R)
# create_network_data and process_large_dag are available from data_upload.R

# Initialize empty data structures for startup
# The app will start with no graph loaded, and users will load graphs through the UI

# Create empty data structures
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

cat("Application initialized with empty graph data.\n")
cat("Ready to load graph files through the user interface.\n")