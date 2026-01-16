# UI Definition
# This file defines the main UI structure
# Author: Refactored from app.R UI section (817 lines → modular structure)

# Source UI head module (CSS and JavaScript)
source("modules/app_ui_head.R")

# Define UI
# Layout: Hamburger menu (left) | Text (center) | Logo (right)
ui <- dashboardPage(
    dashboardHeader(
        title = tags$div(
            class = "custom-header-title",
            tags$span("CKT - Causal Knowledge Trace",
                     style = "vertical-align: middle; font-size: 20px; font-weight: bold;")
        ),
        tags$li(
            class = "dropdown custom-logo-container",
            tags$img(src = "www/hsclogo.png", height = "40px",
                    style = "margin-right: 15px; margin-top: 5px; vertical-align: middle;")
        ),
        titleWidth = 350
    ),

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

