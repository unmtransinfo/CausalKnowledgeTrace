# Modular Shiny Application Entry Point
# This is the main application file that sources all modular components
# Author: Refactored from app.R (2,980 lines → modular structure)

# Global logging control
VERBOSE_LOGGING <- FALSE

# ============================================================================
# INITIALIZATION
# ============================================================================

# Source initialization module
source("modules/app_init.R")

# Initialize libraries
init_app_libraries()

# Initialize logging
init_app_logging(log_dir = "../logs", console_output = FALSE)

# Source all application modules
module_availability <- source_app_modules()
graph_config_available <- module_availability$graph_config_available
database_connection_available <- module_availability$database_connection_available

# Initialize database connection pool
init_app_database(database_connection_available)

# Create empty data structures for immediate startup
empty_data <- create_empty_data_structures()
dag_nodes <- empty_data$dag_nodes
dag_edges <- empty_data$dag_edges
dag_object <- empty_data$dag_object
unique_groups <- empty_data$unique_groups
group_colors <- empty_data$group_colors

# ============================================================================
# UI DEFINITION
# ============================================================================

# Source UI main definition (which sources all UI modules)
source("ui/app_ui_main.R", local = TRUE)

# ============================================================================
# SERVER LOGIC
# ============================================================================

# Source server definition (which sources all server logic modules)
source("server/app_server_definition.R", local = TRUE)

# ============================================================================
# CREATE AND RETURN SHINY APP
# ============================================================================

# Create and return the Shiny application object
shinyApp(ui = ui, server = server)

