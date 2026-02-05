# UI Definition
# This file defines the main UI structure
# Author: Refactored from app.R UI section (817 lines → modular structure)

# Source UI head module (CSS and JavaScript)
source("modules/app_ui_head.R")

# Define UI
# Layout: Two-row header navigation
# Row 1: Hamburger menu (left) | Text (center) | Logo (right)
# Row 2: Horizontal navigation tabs
ui <- dashboardPage(
    dashboardHeader(
        title = "",
        titleWidth = 0,
        # Add custom title in center
        tags$li(
            class = "dropdown navbar-title-center",
            style = "position: absolute; left: 50%; transform: translateX(-50%); float: none !important;",
            tags$span(
                "CKT - Causal Knowledge Trace",
                style = "color: white; font-size: 20px; font-weight: bold; line-height: 50px; display: block;"
            )
        ),
        # Add logo on right
        tags$li(
            class = "dropdown custom-logo-container",
            tags$img(src = "www/hsclogo.png", height = "40px",
                    style = "margin-right: 15px; margin-top: 5px; vertical-align: middle;")
        )
    ),

    # Remove sidebar - use collapsed sidebar to maintain shinydashboard structure
    dashboardSidebar(
        collapsed = TRUE,
        disable = TRUE,
        width = 0
    ),

    dashboardBody(
        useShinyjs(),  # Enable shinyjs functionality

        # Application head (title, CSS, JavaScript)
        get_app_head(),

        # Add horizontal navigation bar as first element in body
        tags$div(
            class = "horizontal-nav-container",
            tags$ul(
                class = "horizontal-nav-menu",
                tags$li(
                    class = "horizontal-nav-item active",
                    `data-value` = "about",
                    tags$a(
                        href = "#",
                        onclick = "navigateToTab('about'); return false;",
                        icon("info-circle"),
                        "About"
                    )
                ),
                tags$li(
                    class = "horizontal-nav-item",
                    `data-value` = "create_graph",
                    tags$a(
                        href = "#",
                        onclick = "navigateToTab('create_graph'); return false;",
                        icon("cogs"),
                        "Graph Configuration"
                    )
                ),
                tags$li(
                    class = "horizontal-nav-item",
                    `data-value` = "upload",
                    tags$a(
                        href = "#",
                        onclick = "navigateToTab('upload'); return false;",
                        icon("upload"),
                        "Data Upload"
                    )
                ),
                tags$li(
                    class = "horizontal-nav-item",
                    `data-value` = "dag",
                    tags$a(
                        href = "#",
                        onclick = "navigateToTab('dag'); return false;",
                        icon("project-diagram"),
                        "Graph Visualization"
                    )
                ),
                tags$li(
                    class = "horizontal-nav-item",
                    `data-value` = "causal",
                    tags$a(
                        href = "#",
                        onclick = "navigateToTab('causal'); return false;",
                        icon("search-plus"),
                        "Causal Analysis"
                    )
                )
            )
        ),

        # Tab items (source from separate file)
        source("ui/app_ui_tabs_content.R", local = TRUE)$value
    )
)

