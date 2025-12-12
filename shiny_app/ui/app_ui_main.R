# UI Definition
# This file defines the main UI structure
# Author: Refactored from app.R UI section (817 lines → modular structure)

# Source UI head module (CSS and JavaScript)
source("modules/app_ui_head.R")

# Define UI
ui <- dashboardPage(
    dashboardHeader(title = "Interactive DAG Visualization"),
    
    dashboardSidebar(
        sidebarMenu(
            id = "sidebar",
            menuItem("Graph Configuration", tabName = "create_graph", icon = icon("cogs")),
            menuItem("Data Upload", tabName = "upload", icon = icon("upload")),
            menuItem("DAG Visualization", tabName = "dag", icon = icon("project-diagram")),
            menuItem("Causal Analysis", tabName = "causal", icon = icon("search-plus"))
        )
    ),
    
    dashboardBody(
        useShinyjs(),  # Enable shinyjs functionality

        # Application head (title, CSS, JavaScript)
        get_app_head(),

        # Tab items (source from separate file)
        source("ui/app_ui_tabs_content.R", local = TRUE)$value
    )
)

