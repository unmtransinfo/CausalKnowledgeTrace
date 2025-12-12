# Server Logic Definition
# This file sources all server logic modules
# Author: Refactored from app.R server section (2,057 lines → modular structure)

# Define server function
server <- function(input, output, session) {
    
    # ============================================================================
    # REACTIVE VALUES AND INITIALIZATION
    # ============================================================================
    
    # Reactive values to store current data
    current_data <- reactiveValues(
        nodes = dag_nodes,
        edges = dag_edges,
        dag_object = dag_object,
        available_files = character(0),
        current_file = "No graph loaded",
        causal_assertions = list(),
        assertions_loaded = FALSE,
        consolidated_cui_mappings = list(),
        loading_strategy = NULL,
        lazy_loader = NULL,
        html_download_in_progress = FALSE,
        json_download_in_progress = FALSE,
        dag_download_in_progress = FALSE
    )

    # Initialize available files list and consolidated CUI mappings on startup
    observe({
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)

            # Load consolidated CUI mappings
            consolidated_cui_mappings_path <- file.path("..", "graph_creation", "result", "consolidated_cui_mappings.json")
            if (file.exists(consolidated_cui_mappings_path)) {
                current_data$consolidated_cui_mappings <- jsonlite::fromJSON(consolidated_cui_mappings_path)
            }
        }, error = function(e) {
            showNotification(paste("Error initializing file list:", e$message), type = "error")
        })
    })

    # Initialize graph configuration module if available
    if (graph_config_available) {
        graphConfigServer("config")
    }

    # Update file list on app start
    observe({
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
        }, error = function(e) {
            showNotification(paste("Error updating file list:", e$message), type = "error")
        })
    })

    # Current DAG status
    output$current_dag_status <- renderText({
        if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
            "No DAG loaded"
        } else {
            paste0("Current DAG: ", current_data$current_file,
                   " (", nrow(current_data$nodes), " nodes, ",
                   nrow(current_data$edges), " edges)")
        }
    })

    # ============================================================================
    # SOURCE SERVER LOGIC MODULES
    # ============================================================================
    
    # Source file loading and upload handlers
    source("server/app_server_file_loading_logic.R", local = TRUE)
    
    # Source network rendering and controls
    source("server/app_server_network_logic.R", local = TRUE)
    
    # Source edge/node selection and information display
    source("server/app_server_selection_logic.R", local = TRUE)
    
    # Source node/edge removal and undo
    source("server/app_server_removal_logic.R", local = TRUE)
    
    # Source causal analysis logic
    source("server/app_server_causal_logic.R", local = TRUE)
}

