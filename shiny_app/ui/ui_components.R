# UI Components Module
# 
# This module contains all UI component definitions for the Causal Web Shiny application.
# It includes the dashboard header, sidebar, and main body structure.
#
# Author: Refactored from app.R
# Date: February 2025

#' Create Dashboard Header
#' 
#' Creates the main dashboard header with title and styling
#' 
#' @return dashboardHeader object
create_dashboard_header <- function() {
    dashboardHeader(
        title = span(
            icon("project-diagram", style = "margin-right: 10px;"),
            "Causal Web",
            style = "font-size: 24px; font-weight: bold;"
        ),
        titleWidth = 300
    )
}

#' Create Dashboard Sidebar
#' 
#' Creates the main navigation sidebar with menu items
#' 
#' @return dashboardSidebar object
create_dashboard_sidebar <- function() {
    dashboardSidebar(
        width = 300,
        sidebarMenu(
            id = "tabs",
            menuItem("Graph Configuration", tabName = "create_graph", icon = icon("cogs")),
            menuItem("Data Upload", tabName = "upload", icon = icon("upload")),
            menuItem("DAG Visualization", tabName = "dag", icon = icon("project-diagram")),
            menuItem("Causal Analysis", tabName = "causal", icon = icon("search-plus"))
        )
    )
}

#' Create Custom CSS Styles
#' 
#' Creates custom CSS styling for the application
#' 
#' @return tags$style object with CSS
create_custom_styles <- function() {
    tags$style(HTML("
        .content-wrapper, .right-side {
            background-color: #f4f4f4;
        }
        .box {
            border-radius: 5px;
        }

        /* Resizable DAG visualization styles */
        .resizable-dag-container {
            position: relative;
            min-height: 400px;
            max-height: 1200px;
            height: 800px;
            border: 1px solid #ddd;
            border-radius: 4px;
            overflow: visible;
        }

        /* Fix for visNetwork nodesIdSelection dropdown */
        .resizable-dag-container .vis-network {
            overflow: visible !important;
        }

        .resizable-dag-container .vis-option-container {
            position: relative;
            z-index: 10;
            background: white;
            padding: 8px;
            border-bottom: 1px solid #ddd;
            display: block !important;
            visibility: visible !important;
        }

        .resizable-dag-container input.vis-input {
            width: 200px;
            padding: 6px 8px;
            border: 1px solid #ccc;
            border-radius: 3px;
            font-size: 13px;
            display: block !important;
            visibility: visible !important;
        }

        .dag-resize-handle {
            position: absolute;
            bottom: -1px;
            left: 50%;
            transform: translateX(-50%);
            width: 60px;
            height: 12px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 6px 6px 0 0;
            cursor: ns-resize;
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s ease;
        }

        .dag-resize-handle:before {
            content: '';
            width: 30px;
            height: 3px;
            background: #6c757d;
            border-radius: 2px;
            box-shadow: 0 3px 0 #6c757d, 0 6px 0 #6c757d;
        }

        .dag-resize-handle:hover {
            background: #e9ecef;
            border-color: #007bff;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .dag-resize-handle:hover:before {
            background: #007bff;
            box-shadow: 0 3px 0 #007bff, 0 6px 0 #007bff;
        }

        .dag-network-output {
            width: 100%;
            height: 100%;
        }

        /* Form layout improvements */
        .form-group {
            margin-bottom: 20px;
        }

        /* Ensure consistent vertical alignment in two-column layouts */
        .row .col-sm-6 {
            display: flex;
            flex-direction: column;
        }

        .row .col-sm-6 .form-group {
            flex: 1;
            display: flex;
            flex-direction: column;
        }
    "))
}

#' Create Custom JavaScript Functions
#' 
#' Creates custom JavaScript functions for the application
#' 
#' @return tags$script object with JavaScript
create_custom_javascript <- function() {
    tags$script(HTML("
        function openCreateGraph() {
            // Navigate to the Graph Configuration tab
            $('a[data-value=\"create_graph\"]').click();
        }

        function openCausalAnalysis() {
            // Navigate to the Causal Analysis tab
            $('a[data-value=\"causal\"]').click();
        }

        // Progress bar control functions
        function updateProgress(percent, text, status) {
            $('#loading_progress').css('width', percent + '%');
            $('#progress_text').text(text);
            $('#loading_status').text('Status: ' + status);
        }

        function showLoadingSection() {
            $('#loading_section').show();
            updateProgress(10, 'Starting...', 'Initializing file loading process');
        }

        function hideLoadingSection() {
            $('#loading_section').hide();
            updateProgress(0, 'Initializing...', 'Ready to load...');
        }

        // DAG resizing functionality
        $(document).ready(function() {
            let isResizing = false;
            let startY = 0;
            let startHeight = 0;

            $(document).on('mousedown', '.dag-resize-handle', function(e) {
                isResizing = true;
                startY = e.clientY;
                startHeight = $(this).parent().height();
                $('body').css('user-select', 'none');
                e.preventDefault();
            });

            $(document).mousemove(function(e) {
                if (!isResizing) return;
                
                const deltaY = e.clientY - startY;
                const newHeight = Math.max(400, Math.min(1200, startHeight + deltaY));
                $('.resizable-dag-container').height(newHeight);
            });

            $(document).mouseup(function() {
                if (isResizing) {
                    isResizing = false;
                    $('body').css('user-select', '');
                }
            });
        });
    "))
}

#' Create DAG Visualization Tab Content
#' 
#' Creates the content for the DAG visualization tab
#' 
#' @return tabItem object
create_dag_tab <- function() {
    tabItem(
        tabName = "dag",
        fluidRow(
            box(
                title = "DAG File Selection",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                
                fluidRow(
                    column(6,
                        selectInput("dag_file_selector", 
                                  "Select DAG File:", 
                                  choices = "Loading...",
                                  width = "100%")
                    ),
                    column(3,
                        actionButton("refresh_files", 
                                   "Refresh Files", 
                                   icon = icon("refresh"),
                                   class = "btn-info",
                                   style = "margin-top: 25px;")
                    ),
                    column(3,
                        actionButton("load_selected_dag", 
                                   "Load Selected DAG", 
                                   icon = icon("upload"),
                                   class = "btn-success",
                                   style = "margin-top: 25px;")
                    )
                ),
                
                # Loading progress section
                div(id = "loading_section", style = "display: none; margin-top: 15px;",
                    div(class = "progress",
                        div(id = "loading_progress", 
                            class = "progress-bar progress-bar-striped active",
                            role = "progressbar",
                            style = "width: 0%")
                    ),
                    p(id = "progress_text", "Initializing..."),
                    p(id = "loading_status", "Status: Ready to load...")
                )
            )
        ),
        
        fluidRow(
            box(
                title = "Interactive DAG Visualization",
                status = "primary", 
                solidHeader = TRUE,
                width = 12,
                
                div(class = "resizable-dag-container",
                    visNetworkOutput("dag_network", height = "100%"),
                    div(class = "dag-resize-handle")
                ),
                
                br(),
                
                fluidRow(
                    column(4,
                        h4("Graph Information"),
                        verbatimTextOutput("graph_info")
                    ),
                    column(4,
                        h4("Selected Node"),
                        verbatimTextOutput("selected_node_info")
                    ),
                    column(4,
                        h4("Quick Actions"),
                        actionButton("btn_causal_analysis", 
                                   "Causal Analysis", 
                                   icon = icon("search-plus"),
                                   class = "btn-primary",
                                   onclick = "openCausalAnalysis()",
                                   style = "margin-bottom: 10px; width: 100%;"),
                        actionButton("btn_create_graph", 
                                   "Create New Graph", 
                                   icon = icon("plus"),
                                   class = "btn-success",
                                   onclick = "openCreateGraph()",
                                   style = "width: 100%;")
                    )
                )
            )
        )
    )
}

#' Create Node Information Tab Content
#' 
#' Creates the content for the node information tab
#' 
#' @return tabItem object
create_info_tab <- function() {
    tabItem(
        tabName = "info",
        fluidRow(
            box(
                title = "Node Details",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                
                p("Click on a node in the DAG visualization to see detailed information here."),
                
                conditionalPanel(
                    condition = "output.has_node_selection",
                    
                    h3("Selected Node Information"),
                    verbatimTextOutput("detailed_node_info"),
                    
                    h4("Node Relationships"),
                    h5("Parents (nodes pointing to this node):"),
                    verbatimTextOutput("node_parents"),
                    
                    h5("Children (nodes this node points to):"),
                    verbatimTextOutput("node_children"),
                    
                    h4("Causal Properties"),
                    verbatimTextOutput("node_causal_properties")
                )
            )
        )
    )
}

#' Create Causal Analysis Tab Content
#'
#' Creates the content for the causal analysis tab
#'
#' @return tabItem object
create_causal_tab <- function() {
    tabItem(
        tabName = "causal",
        fluidRow(
            box(
                title = "Causal Analysis Configuration",
                status = "primary",
                solidHeader = TRUE,
                width = 12,

                fluidRow(
                    column(4,
                        selectInput("causal_exposure",
                                  "Select Exposure Variable:",
                                  choices = "No DAG loaded",
                                  width = "100%")
                    ),
                    column(4,
                        selectInput("causal_outcome",
                                  "Select Outcome Variable:",
                                  choices = "No DAG loaded",
                                  width = "100%")
                    ),
                    column(4,
                        br(),
                        actionButton("run_causal_analysis",
                                   "Run Complete Analysis",
                                   icon = icon("play"),
                                   class = "btn-success",
                                   style = "width: 100%;")
                    )
                ),

                # Progress indicator
                div(id = "causal_progress", style = "display: none; margin-top: 15px;",
                    div(class = "progress",
                        div(class = "progress-bar progress-bar-striped active",
                            role = "progressbar",
                            style = "width: 100%")
                    ),
                    p("Running causal analysis...")
                )
            )
        ),

        fluidRow(
            column(4,
                box(
                    title = "Adjustment Sets",
                    status = "info",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "400px",

                    div(style = "height: 320px; overflow-y: auto;",
                        verbatimTextOutput("adjustment_sets_result")
                    )
                )
            ),
            column(4,
                box(
                    title = "Instrumental Variables",
                    status = "warning",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "400px",

                    div(style = "height: 320px; overflow-y: auto;",
                        verbatimTextOutput("instrumental_vars_result")
                    )
                )
            ),
            column(4,
                box(
                    title = "Causal Paths",
                    status = "success",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "400px",

                    div(style = "height: 320px; overflow-y: auto;",
                        verbatimTextOutput("causal_paths_result")
                    )
                )
            )
        )
    )
}

#' Create Statistics Tab Content
#'
#' Creates the content for the statistics tab
#'
#' @return tabItem object
create_stats_tab <- function() {
    tabItem(
        tabName = "stats",
        fluidRow(
            box(
                title = "Graph Statistics",
                status = "primary",
                solidHeader = TRUE,
                width = 12,

                statisticsModuleUI("stats_module")
            )
        )
    )
}

#' Create Data Upload Tab Content
#'
#' Creates the content for the data upload tab
#'
#' @return tabItem object
create_upload_tab <- function() {
    tabItem(
        tabName = "upload",
        fluidRow(
            box(
                title = "Data Upload",
                status = "primary",
                solidHeader = TRUE,
                width = 12,

                dataUploadModuleUI("upload_module")
            )
        )
    )
}

#' Create Graph Configuration Tab Content
#'
#' Creates the content for the graph configuration tab
#'
#' @return tabItem object
create_config_tab <- function() {
    tabItem(
        tabName = "create_graph",
        fluidRow(
            box(
                title = "Graph Configuration",
                status = "primary",
                solidHeader = TRUE,
                width = 12,

                graphConfigModuleUI("graph_config")
            )
        )
    )
}

#' Create Complete Dashboard Body
#'
#' Creates the complete dashboard body with all tabs
#'
#' @return dashboardBody object
create_dashboard_body <- function() {
    dashboardBody(
        useShinyjs(),  # Enable shinyjs functionality
        tags$head(
            tags$title("Causal Web"),
            create_custom_styles(),
            create_custom_javascript()
        ),

        tabItems(
            create_config_tab(),
            create_upload_tab(),
            create_dag_tab(),
            create_causal_tab()
        )
    )
}
