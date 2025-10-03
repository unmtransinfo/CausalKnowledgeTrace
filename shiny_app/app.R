# Load required libraries
library(shiny)
library(shinydashboard)
library(visNetwork)
library(dplyr)
library(DT)
library(jsonlite)
library(htmltools)

# Load shinyjs for UI interactions (with error handling)
tryCatch({
    library(shinyjs)
    cat("✓ shinyjs library loaded\n")
}, error = function(e) {
    cat("⚠ shinyjs not available:", e$message, "\n")
    cat("  Some UI interactions may be limited\n")
})

# Load DAG processing libraries with error handling
tryCatch({
    library(SEMgraph)
    cat("✓ SEMgraph library loaded\n")
}, error = function(e) {
    cat("⚠ SEMgraph not available:", e$message, "\n")
    cat("  Some DAG processing features may be limited\n")
})

tryCatch({
    library(dagitty)
    cat("✓ dagitty library loaded\n")
}, error = function(e) {
    cat("⚠ dagitty not available:", e$message, "\n")
    cat("  DAG processing will not work without this package\n")
})

tryCatch({
    library(igraph)
    cat("✓ igraph library loaded\n")
}, error = function(e) {
    cat("⚠ igraph not available:", e$message, "\n")
    cat("  Graph conversion features may be limited\n")
})

# Source modular components
source("modules/dag_visualization.R")
source("modules/node_information.R")
source("modules/statistics.R")
source("modules/data_upload.R")
source("modules/causal_analysis.R")
source("modules/optimized_loading.R")  # For optimized causal assertions loading
source("modules/json_to_html.R")      # For HTML export functionality

# Try to source graph configuration module if it exists
tryCatch({
    source("modules/graph_config_module.R")
    graph_config_available <- TRUE
    cat("Graph configuration module loaded successfully\n")
}, error = function(e) {
    graph_config_available <- FALSE
    cat("Graph configuration module not found, creating placeholder\n")
})

# Initialize empty data structures for immediate app startup
# The app will start with no graph loaded, and users will load graphs through the UI
cat("Starting Shiny application without loading graph files...\n")

# Create empty data structures for immediate startup
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

# Initialize empty groups for legend
unique_groups <- character(0)
group_colors <- character(0)

cat("Application ready to start at localhost.\n")
cat("Use the Data Upload tab to select and load a graph file.\n")

# Define UI
ui <- dashboardPage(
    dashboardHeader(title = "Interactive DAG Visualization"),
    
    dashboardSidebar(
        sidebarMenu(
            id = "sidebar",
            menuItem("Graph Configuration", tabName = "create_graph", icon = icon("cogs")),
            menuItem("Data Upload", tabName = "upload", icon = icon("upload")),
            menuItem("DAG Visualization", tabName = "dag", icon = icon("project-diagram")),
            menuItem("Causal Analysis", tabName = "causal", icon = icon("search-plus")),
            menuItem("Node Information", tabName = "info", icon = icon("info-circle")),
            menuItem("Statistics", tabName = "stats", icon = icon("chart-bar"))
        )
    ),
    
    dashboardBody(
        useShinyjs(),  # Enable shinyjs functionality
        tags$head(
            tags$title("Causal Web"),
            tags$style(HTML("
                .content-wrapper, .right-side {
                    background-color: #f4f4f4;
                }
                .box {
                    border-radius: 5px;
                }

                /* Override shinydashboard box constraints for DAG container */
                .box .box-body {
                    padding: 10px;
                }

                .box.dag-network-box {
                    height: auto !important;
                }

                .box.dag-network-box .box-body {
                    height: auto !important;
                    padding: 0 !important;
                }

                /* Resizable DAG visualization styles */
                .resizable-dag-container {
                    position: relative;
                    min-height: 500px;
                    max-height: calc(100vh - 200px);
                    height: calc(100vh - 300px);
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    overflow: hidden;
                    width: 100%;
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

                /* Network container sizing */
                .resizable-dag-container #network {
                    width: 100% !important;
                    height: 100% !important;
                }

                /* Ensure proper viewport sizing */
                .content-wrapper {
                    min-height: calc(100vh - 50px);
                }

                /* Responsive adjustments */
                @media (max-width: 768px) {
                    .resizable-dag-container {
                        height: 60vh;
                        min-height: 400px;
                    }
                }

                /* Edge Information Panel Styling */
                .edge-info-box {
                    height: auto !important;
                    min-height: 350px;
                }

                .edge-info-box .box-body {
                    padding: 15px !important;
                    height: auto !important;
                }

                .edge-info-table-container {
                    width: 100%;
                    overflow: hidden;
                }

                /* DataTable styling for Edge Information */
                .edge-info-table-container .dataTables_wrapper {
                    width: 100% !important;
                }

                .edge-info-table-container .dataTables_scroll {
                    width: 100% !important;
                }

                .edge-info-table-container .dataTables_scrollHead,
                .edge-info-table-container .dataTables_scrollBody {
                    width: 100% !important;
                }

                .edge-info-table-container table.dataTable {
                    width: 100% !important;
                    margin: 0 !important;
                }

                .edge-info-table-container .dataTables_filter {
                    float: right;
                    margin-bottom: 10px;
                }

                .edge-info-table-container .dataTables_info {
                    float: left;
                    margin-top: 10px;
                }

                .edge-info-table-container .dataTables_paginate {
                    float: right;
                    margin-top: 10px;
                }
            ")),
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

                // Event handlers for loading buttons
                $(document).on('click', '#load_selected_dag', function() {
                    showLoadingSection();
                    updateProgress(20, 'Reading file...', 'Loading selected graph file');
                });

                $(document).on('click', '#upload_and_load', function() {
                    showLoadingSection();
                    updateProgress(20, 'Uploading file...', 'Processing uploaded graph file');
                });

                // Hide loading section on page load
                $(document).ready(function() {
                    hideLoadingSection();
                });

                // Message handlers for server communication
                Shiny.addCustomMessageHandler('updateProgress', function(data) {
                    updateProgress(data.percent, data.text, data.status);
                });

                Shiny.addCustomMessageHandler('hideLoadingSection', function(data) {
                    setTimeout(function() {
                        hideLoadingSection();
                    }, 1000); // Brief delay to show completion
                });

                // DAG Visualization Resize Functionality
                function initializeDAGResize() {
                    var isResizing = false;
                    var startY = 0;
                    var startHeight = 0;
                    var container = null;

                    // Initialize resize functionality when DOM is ready
                    $(document).ready(function() {
                        setTimeout(function() {
                            setupResizeHandlers();
                        }, 1000); // Delay to ensure elements are rendered
                    });

                    function setupResizeHandlers() {
                        container = $('.resizable-dag-container');
                        var handle = $('.dag-resize-handle');

                        if (container.length === 0 || handle.length === 0) {
                            // Retry setup if elements not found
                            setTimeout(setupResizeHandlers, 500);
                            return;
                        }

                        handle.on('mousedown', function(e) {
                            isResizing = true;
                            startY = e.clientY;
                            startHeight = container.height();

                            // Prevent text selection during resize
                            $('body').addClass('no-select');
                            e.preventDefault();
                        });

                        $(document).on('mousemove', function(e) {
                            if (!isResizing) return;

                            var deltaY = e.clientY - startY;
                            var newHeight = startHeight + deltaY;

                            // Enforce min and max height constraints
                            newHeight = Math.max(400, Math.min(1200, newHeight));

                            container.height(newHeight);

                            // Trigger resize event for visNetwork
                            if (window.Shiny && window.Shiny.onInputChange) {
                                window.Shiny.onInputChange('dag_container_height', newHeight);
                            }
                        });

                        $(document).on('mouseup', function() {
                            if (isResizing) {
                                isResizing = false;
                                $('body').removeClass('no-select');

                                // Force visNetwork to redraw and fit after resize
                                setTimeout(function() {
                                    if (typeof HTMLWidgets !== 'undefined') {
                                        HTMLWidgets.resize();
                                    }
                                    if (window.network && typeof window.network.redraw === 'function') {
                                        window.network.redraw();
                                        if (typeof window.network.fit === 'function') {
                                            window.network.fit({
                                                animation: { duration: 300 }
                                            });
                                        }
                                    }
                                }, 100);
                            }
                        });
                    }
                }

                // Initialize resize functionality
                initializeDAGResize();

                // Add CSS for preventing text selection during resize
                $('<style>')
                    .prop('type', 'text/css')
                    .html('.no-select { -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none; user-select: none; }')
                    .appendTo('head');

                // Function to update DAG status
                window.updateDAGStatus = function(status, color) {
                    var statusElement = $('#dag_status_text');
                    if (statusElement.length) {
                        statusElement.text(status).css('color', color);
                    }
                };

                // Update status when DAG is modified
                Shiny.addCustomMessageHandler('updateDAGStatus', function(message) {
                    window.updateDAGStatus(message.status, message.color);
                });
            "))
        ),
        
        tabItems(
            # DAG Visualization Tab
            tabItem(tabName = "dag",
                # Row 1: Interactive DAG Network (top)
                fluidRow(
                    box(
                        title = "Interactive DAG Network",
                        status = "primary",
                        solidHeader = TRUE,
                        width = 12,
                        class = "dag-network-box",
                        div(class = "resizable-dag-container",
                            visNetworkOutput("network", height = "100%", width = "100%"),
                            div(class = "dag-resize-handle")
                        ),
                        div(style = "margin-top: 10px;",
                            helpText("Click on edges to view information below. Select nodes or edges and use removal buttons. Use 'Save DAG' to download your modified graph."),
                            div(style = "margin-top: 5px;",
                                actionButton("remove_node_btn", "Remove Selected Node",
                                           class = "btn-danger btn-sm",
                                           style = "margin-right: 5px;",
                                           icon = icon("trash")),
                                actionButton("remove_edge_btn", "Remove Selected Edge",
                                           class = "btn-warning btn-sm",
                                           style = "margin-right: 5px;",
                                           icon = icon("scissors")),
                                actionButton("undo_removal", "Undo Last Removal",
                                           class = "btn-info btn-sm",
                                           style = "margin-right: 10px;",
                                           icon = icon("undo")),
                                downloadButton("save_dag_btn", "Save DAG",
                                             class = "btn-success btn-sm",
                                             style = "margin-right: 5px; font-weight: bold;",
                                             icon = icon("download"),
                                             title = "Download your modified DAG as an R file"),
                                downloadButton("save_json_btn", "Save JSON",
                                             class = "btn-info btn-sm",
                                             style = "margin-right: 5px; font-weight: bold;",
                                             icon = icon("file-code"),
                                             title = "Save causal assertions JSON for modified DAG"),
                                downloadButton("save_html_btn", "Save HTML",
                                             class = "btn-warning btn-sm",
                                             style = "margin-right: 10px; font-weight: bold;",
                                             icon = icon("file-text"),
                                             title = "Convert JSON to readable HTML report"),
                                span(id = "network_stats",
                                     style = "font-size: 12px; color: #666; margin-left: 10px;",
                                     textOutput("network_stats_text", inline = TRUE))
                            )
                        )
                    )
                ),
                # Row 2: Edge Information (directly below DAG)
                fluidRow(
                    box(
                        title = "Edge Information",
                        status = "info",
                        solidHeader = TRUE,
                        width = 12,
                        class = "edge-info-box",
                        div(id = "selection_info_panel",
                            h5(textOutput("selected_item_title")),
                            div(class = "edge-info-table-container",
                                DT::dataTableOutput("selection_info_table")
                            )
                        )
                    )
                ),
                # Row 3: Controls, Navigation Guide, and Legend (bottom)
                fluidRow(
                    box(
                        title = "Network Controls",
                        status = "info",
                        solidHeader = TRUE,
                        width = 4,
                        create_network_controls_ui(),
                        br(),

                        # Save DAG Section
                        h5(icon("save"), " Save Modified DAG"),
                        div(id = "dag_status_indicator",
                            p("Status: ",
                              span(id = "dag_status_text", "Ready to save",
                                   style = "color: #28a745; font-weight: bold;"),
                              style = "font-size: 12px; margin-bottom: 5px;")),
                        p("Download your current graph as an R file:", style = "font-size: 12px; margin-bottom: 10px;"),
                        downloadButton("save_dag_main", "Download DAG File",
                                     class = "btn-success btn-block",
                                     icon = icon("download"),
                                     style = "margin-bottom: 10px; font-weight: bold;",
                                     title = "Save your modified DAG as an R file"),
                        downloadButton("save_json_main", "Download JSON File",
                                     class = "btn-info btn-block",
                                     icon = icon("file-code"),
                                     style = "margin-bottom: 10px; font-weight: bold;",
                                     title = "Save causal assertions JSON for modified DAG"),
                        downloadButton("save_html_main", "Download HTML Report",
                                     class = "btn-warning btn-block",
                                     icon = icon("file-text"),
                                     style = "margin-bottom: 15px; font-weight: bold;",
                                     title = "Convert JSON to readable HTML report"),

                        hr(),

                        # Add Graph Parameters button
                        actionButton("graph_params_btn",
                                   "Create Graph",
                                   class = "btn-info btn-block",
                                   icon = icon("cogs"),
                                   onclick = "openCreateGraph()"),

                        br(),

                        # Quick access to causal analysis
                        actionButton("quick_causal_analysis",
                                   "Causal Analysis",
                                   class = "btn-success btn-block",
                                   icon = icon("search-plus"),
                                   onclick = "openCausalAnalysis()",
                                   title = "Go to causal analysis tab")
                    ),
                    box(
                        title = "Navigation Guide",
                        status = "warning",
                        solidHeader = TRUE,
                        width = 4,
                        h5(icon("keyboard"), " Keyboard Controls:"),
                        tags$ul(
                            tags$li(HTML("<strong>Arrow Keys:</strong> Pan the graph (↑↓←→)")),
                            tags$li(HTML("<strong>+ / =:</strong> Zoom in")),
                            tags$li(HTML("<strong>-:</strong> Zoom out")),
                            tags$li(HTML("<strong>0:</strong> Fit graph to view"))
                        ),
                        h5(icon("mouse-pointer"), " Mouse Controls:"),
                        tags$ul(
                            tags$li("Drag to pan the view"),
                            tags$li("Scroll wheel to zoom"),
                            tags$li("Click edges to view information"),
                            tags$li("Use navigation buttons (bottom-right)")
                        ),
                        tags$small(class = "text-muted",
                                  "Click on the graph area first to enable keyboard navigation.")
                    ),
                    box(
                        title = "Legend",
                        status = "success",
                        solidHeader = TRUE,
                        width = 4,
                        htmlOutput("legend_html")
                    )
                )
            ),

            # Causal Analysis Tab
            tabItem(tabName = "causal",
                fluidRow(
                    box(
                        title = "Causal Analysis Controls",
                        status = "primary",
                        solidHeader = TRUE,
                        width = 4,
                        h4(icon("cogs"), " Analysis Settings"),

                        # Variable selection
                        selectInput("causal_exposure",
                                  "Exposure Variable:",
                                  choices = NULL,
                                  selected = NULL),

                        selectInput("causal_outcome",
                                  "Outcome Variable:",
                                  choices = NULL,
                                  selected = NULL),

                        selectInput("causal_effect_type",
                                  "Effect Type:",
                                  choices = list("Total Effect" = "total", "Direct Effect" = "direct"),
                                  selected = "total"),

                        br(),

                        # Analysis buttons
                        actionButton("calculate_adjustment_sets",
                                   "Calculate Adjustment Sets",
                                   class = "btn-primary btn-block",
                                   icon = icon("calculator")),

                        br(),

                        actionButton("find_instruments",
                                   "Find Instrumental Variables",
                                   class = "btn-info btn-block",
                                   icon = icon("search")),

                        br(),

                        actionButton("analyze_paths",
                                   "Analyze Causal Paths",
                                   class = "btn-success btn-block",
                                   icon = icon("route")),

                        br(),

                        # Quick analysis button
                        actionButton("run_full_analysis",
                                   "Run Complete Analysis",
                                   class = "btn-warning btn-block",
                                   icon = icon("magic"),
                                   title = "Run all analyses at once"),

                        br(),

                        # Progress indicator
                        div(id = "causal_progress", style = "display: none;",
                            h5("Analysis in progress..."),
                            div(class = "progress progress-striped active",
                                div(class = "progress-bar", style = "width: 100%")
                            )
                        )
                    ),

                    box(
                        title = "Analysis Results",
                        status = "success",
                        solidHeader = TRUE,
                        width = 8,

                        # Results tabs
                        tabsetPanel(
                            id = "causal_results_tabs",

                            tabPanel("Adjustment Sets",
                                br(),
                                verbatimTextOutput("adjustment_sets_result"),
                                br(),
                                h5("Quick Guide:"),
                                tags$ul(
                                    tags$li("Empty set (∅) means no adjustment needed"),
                                    tags$li("Multiple sets give you options - choose based on data availability"),
                                    tags$li("Control for ALL variables in the chosen set")
                                )
                            ),

                            tabPanel("Instrumental Variables",
                                br(),
                                verbatimTextOutput("instrumental_vars_result"),
                                br(),
                                h5("About Instrumental Variables:"),
                                tags$ul(
                                    tags$li("Variables that affect exposure but not outcome directly"),
                                    tags$li("Useful when adjustment sets are not sufficient"),
                                    tags$li("Enable causal identification through natural experiments")
                                )
                            ),

                            tabPanel("Causal Paths",
                                br(),
                                verbatimTextOutput("causal_paths_result"),
                                br(),
                                h5("Path Analysis:"),
                                tags$ul(
                                    tags$li("Shows all paths from exposure to outcome"),
                                    tags$li("Open paths create confounding"),
                                    tags$li("Blocked paths are already controlled")
                                )
                            )
                        )
                    )
                ),

                fluidRow(
                    box(
                        title = "DAG Variables Overview",
                        status = "info",
                        solidHeader = TRUE,
                        width = 12,
                        verbatimTextOutput("dag_variables_info")
                    )
                )
            ),

            # Node Information Tab
            tabItem(tabName = "info",
                fluidRow(
                    box(
                        title = "Selected Node Information",
                        status = "primary",
                        solidHeader = TRUE,
                        width = 12,
                        verbatimTextOutput("node_info")
                    )
                ),
                fluidRow(
                    box(
                        title = "All Nodes",
                        status = "info",
                        solidHeader = TRUE,
                        width = 12,
                        DT::dataTableOutput("nodes_table")
                    )
                )
            ),
            
            # Statistics Tab
            tabItem(tabName = "stats",
                fluidRow(
                    valueBoxOutput("total_nodes"),
                    valueBoxOutput("total_edges"),
                    valueBoxOutput("total_groups")
                ),
                fluidRow(
                    box(
                        title = "Node Distribution by Category",
                        status = "primary",
                        solidHeader = TRUE,
                        width = 6,
                        plotOutput("node_distribution")
                    ),
                    box(
                        title = "DAG Structure Information",
                        status = "info",
                        solidHeader = TRUE,
                        width = 6,
                        verbatimTextOutput("dag_info")
                    )
                ),
                fluidRow(
                    box(
                        title = "Cycle Detection",
                        status = "warning",
                        solidHeader = TRUE,
                        width = 12,
                        verbatimTextOutput("cycle_detection")
                    )
                )
            ),
            
            # Data Upload Tab
            tabItem(tabName = "upload",
                fluidRow(
                    box(
                        title = "Graph File Selection & Loading",
                        status = "primary",
                        solidHeader = TRUE,
                        width = 12,

                        # Welcome message for new users
                        div(
                            style = "background-color: #e8f4fd; padding: 15px; margin-bottom: 20px; border-radius: 5px; border-left: 4px solid #2196F3;",
                            h4(icon("info-circle"), " Welcome to the Interactive DAG Visualization"),
                            p("The application is now running at localhost and ready to use! To get started, please select or upload a graph file below."),
                            p(strong("No graph file is currently loaded."), " Once you load a graph, you'll be able to explore it in the DAG Visualization tab.")
                        ),

                        # Current DAG status
                        h4(icon("chart-line"), " Current Graph Status"),
                        verbatimTextOutput("current_dag_status"),

                        # File selection section
                        h4(icon("folder-open"), " Load Graph from Existing File"),
                        p("Select a graph file from the dropdown below:"),

                        fluidRow(
                            column(8,
                                selectInput("dag_file_selector",
                                           "Choose Graph File:",
                                           choices = NULL,
                                           selected = NULL)
                            ),
                            column(4,
                                br(),
                                actionButton("load_selected_dag", "Load Selected Graph",
                                           class = "btn-primary", style = "margin-top: 5px; width: 100%;"),
                                br(), br(),
                                actionButton("refresh_file_list", "Refresh File List",
                                           class = "btn-info", style = "margin-top: 5px; width: 100%;")
                            )
                        ),



                        # Progress indication section
                        conditionalPanel(
                            condition = "input.load_selected_dag > 0 || input.upload_and_load > 0",
                            div(id = "loading_section", style = "margin: 20px 0;",
                                h4(icon("spinner", class = "fa-spin"), " Loading Graph File..."),
                                div(
                                    style = "background-color: #f8f9fa; padding: 15px; border-radius: 5px; border: 1px solid #dee2e6;",
                                    p("Please wait while your graph file is being processed and loaded."),
                                    div(class = "progress", style = "height: 25px;",
                                        div(id = "loading_progress", class = "progress-bar progress-bar-striped progress-bar-animated",
                                            role = "progressbar", style = "width: 0%; background-color: #007bff;",
                                            span(id = "progress_text", "Initializing...")
                                        )
                                    ),
                                    br(),
                                    div(id = "loading_status", style = "font-size: 14px; color: #6c757d;",
                                        "Status: Ready to load..."
                                    )
                                )
                            )
                        ),

                        hr(),

                        # File upload section
                        h4(icon("upload"), " Upload New Graph File"),
                        p("Upload a new R file containing your graph definition:"),

                        fluidRow(
                            column(8,
                                fileInput("dag_file_upload", "Choose R File",
                                         accept = c(".R", ".r"),
                                         multiple = FALSE,
                                         placeholder = "No file selected")
                            ),
                            column(4,
                                br(),
                                actionButton("upload_and_load", "Upload & Load",
                                           class = "btn-success", style = "margin-top: 5px; width: 100%;")
                            )
                        ),
                        
                        # Instructions
                        h4("Instructions"),
                        tags$div(
                            tags$h5("Method 1: Place files in graph_creation/result directory"),
                            tags$ul(
                                tags$li("Create an R file (e.g., 'degree_1.R', 'degree_2.R', 'degree_3.R', 'MarkovBlanket_Union.R') with your DAG definition"),
                                tags$li("Place it in the 'graph_creation/result' directory (generated graphs are automatically saved here)"),
                                tags$li("Click 'Refresh File List' and select your file"),
                                tags$li("Click 'Load Selected DAG'")
                            ),
                            
                            tags$h5("Method 2: Upload files through the interface"),
                            tags$ul(
                                tags$li("Use the file upload interface above"),
                                tags$li("Select your R file containing the DAG"),
                                tags$li("Click 'Upload & Load'")
                            ),
                            
                            tags$h5("DAG File Format"),
                            tags$p("Your R file should contain a dagitty graph definition like:"),
                            tags$pre(style = "background-color: #f8f9fa; padding: 10px;",
'g <- dagitty(\'dag {
    Variable1 [exposure]
    Variable2 [outcome]
    Variable3
    Variable4
    
    Variable1 -> Variable2
    Variable2 -> Variable3
    Variable3 -> Variable4
}\')'),
                            tags$p("The variable name must be 'g' for the app to recognize it.")
                        )
                    )
                )
            ),

            # Graph Configuration Tab
            tabItem(tabName = "create_graph",
                if (exists("graph_config_available") && graph_config_available) {
                    graphConfigUI("config")
                } else {
                    fluidRow(
                        box(
                            title = "Graph Configuration",
                            status = "primary",
                            solidHeader = TRUE,
                            width = 12,
                            div(
                                class = "alert alert-warning",
                                icon("exclamation-triangle"),
                                strong("Graph Configuration Module Not Available"),
                                br(), br(),
                                p("The graph configuration module (graph_config_module.R) was not found."),
                                p("To enable this feature, please ensure the graph_config_module.R file is in the same directory as this application."),
                                br(),
                                p("This module allows you to configure parameters for knowledge graph generation including:"),
                                tags$ul(
                                    tags$li("Exposure and Outcome CUIs"),
                                    tags$li("Squelch Threshold (minimum unique pmids)"),
                                    tags$li("Publication year cutoff"),

                                    tags$li("K-hops parameter"),
                                    tags$li("SemMedDB version selection")
                                )
                            )
                        )
                    )
                }
            )
        )
    )
)

# Define server logic
server <- function(input, output, session) {
    
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
        lazy_loader = NULL
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
            cui_mappings_result <- load_consolidated_cui_mappings()
            if (cui_mappings_result$success) {
                current_data$consolidated_cui_mappings <- cui_mappings_result$mappings
                cat("Loaded consolidated CUI mappings:", cui_mappings_result$message, "\n")
            } else {
                current_data$consolidated_cui_mappings <- list()
                cat("Could not load consolidated CUI mappings:", cui_mappings_result$message, "\n")
            }
        }, error = function(e) {
            cat("Error during initialization:", e$message, "\n")
            updateSelectInput(session, "dag_file_selector", choices = "No DAG files found")
            current_data$consolidated_cui_mappings <- list()
        })
    })

    # Initialize graph configuration module if available
    if (exists("graph_config_available") && graph_config_available) {
        config_params <- graphConfigServer("config")
    }
    
    # Update file list on app start
    observe({
        if (exists("available_dag_files")) {
            choices <- available_dag_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
        }
    })
    
    # Current DAG status
    output$current_dag_status <- renderText({
        if (is.null(current_data$dag_object) || nrow(current_data$nodes) == 0) {
            paste0(
                "STATUS: No graph currently loaded\n",
                "APPLICATION: Running at localhost and ready to use\n",
                "NEXT STEP: Select or upload a graph file below\n\n",
                "Available files detected: ", length(current_data$available_files), "\n",
                if(length(current_data$available_files) > 0)
                    paste("Files:", paste(current_data$available_files, collapse = ", "))
                else "No graph files found in graph_creation/result directory"
            )
        } else {
            loading_strategy_info <- if (!is.null(current_data$loading_strategy)) {
                paste0("LOADING: Optimized\n")
            } else {
                ""
            }

            assertions_info <- if (current_data$assertions_loaded) {
                paste0("ASSERTIONS: ", length(current_data$causal_assertions), " loaded ✓\n")
            } else {
                "ASSERTIONS: Not loaded\n"
            }

            paste0(
                "STATUS: Graph loaded successfully ✓\n",
                "SOURCE: ", current_data$current_file, "\n",
                loading_strategy_info,
                "NODES: ", nrow(current_data$nodes), "\n",
                "EDGES: ", nrow(current_data$edges), "\n",
                assertions_info,
                "CATEGORIES: ", length(unique(current_data$nodes$group)), "\n\n",
                "You can now explore the graph in the DAG Visualization tab!"
            )
        }
    })
    
    # Refresh file list
    observeEvent(input$refresh_file_list, {
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
            showNotification("File list refreshed", type = "message")
        }, error = function(e) {
            showNotification(paste("Error refreshing file list:", e$message), type = "error")
        })
    })
    
    # Load selected DAG with progress indication and strategy selection
    observeEvent(input$load_selected_dag, {
        if (is.null(input$dag_file_selector) || input$dag_file_selector == "No DAG files found") {
            showNotification("Please select a valid graph file", type = "error")
            session$sendCustomMessage("hideLoadingSection", list())
            return()
        }

        # Use optimized loading (binary if available, otherwise full JSON)
        loading_strategy <- "auto"

        tryCatch({
            # Update progress: File validation
            session$sendCustomMessage("updateProgress", list(
                percent = 20,
                text = "Validating file...",
                status = paste("Checking", input$dag_file_selector, "with", loading_strategy, "strategy")
            ))

            result <- load_dag_from_file(input$dag_file_selector)

            if (result$success) {
                # Update progress: Processing graph
                node_count <- length(names(result$dag))
                progress_text <- if (node_count > 8000) {
                    "Processing large graph structure (this may take a moment)..."
                } else {
                    "Processing graph..."
                }

                session$sendCustomMessage("updateProgress", list(
                    percent = 40,
                    text = progress_text,
                    status = paste("Converting", node_count, "nodes to network format")
                ))

                # Process the loaded DAG
                network_data <- create_network_data(result$dag)

                # Update progress: Network created
                session$sendCustomMessage("updateProgress", list(
                    percent = 50,
                    text = "Network structure created successfully",
                    status = paste("Generated", nrow(network_data$nodes), "nodes and", nrow(network_data$edges), "edges")
                ))

                # Update progress: Loading assertions
                session$sendCustomMessage("updateProgress", list(
                    percent = 60,
                    text = paste("Loading assertions (", loading_strategy, "mode)..."),
                    status = "Applying selected loading strategy"
                ))

                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- input$dag_file_selector

                # Load causal assertions using unified optimized loading
                tryCatch({
                    # Source the new optimized loader
                    if (!exists("load_causal_assertions_unified")) {
                        source("modules/optimized_loader.R")
                    }

                    # Find the appropriate causal assertions file
                    k_hops <- result$k_hops
                    search_dirs <- c("../graph_creation/result", "../graph_creation/output")

                    # Look for optimized file first, then standard file
                    causal_file <- NULL
                    for (dir in search_dirs) {
                        # Try optimized file first
                        optimized_file <- file.path(dir, paste0("causal_assertions_", k_hops, "_optimized_readable.json"))
                        if (file.exists(optimized_file)) {
                            causal_file <- optimized_file
                            break
                        }

                        # Try standard optimized file
                        optimized_file2 <- file.path(dir, paste0("causal_assertions_", k_hops, "_optimized.json"))
                        if (file.exists(optimized_file2)) {
                            causal_file <- optimized_file2
                            break
                        }

                        # Try standard file
                        standard_file <- file.path(dir, paste0("causal_assertions_", k_hops, ".json"))
                        if (file.exists(standard_file)) {
                            causal_file <- standard_file
                            break
                        }
                    }

                    if (!is.null(causal_file)) {
                        assertions_result <- load_causal_assertions_unified(causal_file)
                    } else {
                        assertions_result <- list(
                            success = FALSE,
                            message = paste("No causal assertions file found for k_hops =", k_hops)
                        )
                    }

                    if (assertions_result$success) {
                        current_data$causal_assertions <- assertions_result$assertions
                        current_data$lazy_loader <- assertions_result$lazy_loader
                        current_data$assertions_loaded <- TRUE
                        current_data$loading_strategy <- assertions_result$loading_strategy

                        cat("Loaded causal assertions for k_hops =", result$k_hops, "\n")
                        cat("Strategy used:", assertions_result$loading_strategy, "\n")
                        cat("Load time:", round(assertions_result$load_time_seconds %||% 0, 2), "seconds\n")

                        # Show simple success notification
                        load_time_msg <- if (!is.null(assertions_result$load_time_seconds)) {
                            paste0(" (", round(assertions_result$load_time_seconds, 1), "s)")
                        } else {
                            ""
                        }

                        # Special message for large graphs
                        success_msg <- if (node_count > 8000) {
                            paste0("Large graph (", node_count, " nodes) loaded successfully!", load_time_msg,
                                  "<br/>The interactive visualization may take a moment to render.")
                        } else {
                            paste0("Graph loaded successfully!", load_time_msg)
                        }

                        showNotification(
                            HTML(success_msg),
                            type = "message",
                            duration = if (node_count > 8000) 6 else 4
                        )
                    } else {
                        current_data$causal_assertions <- list()
                        current_data$lazy_loader <- NULL
                        current_data$assertions_loaded <- FALSE
                        current_data$loading_strategy <- "none"
                        cat("Could not load causal assertions for k_hops =", result$k_hops, ":", assertions_result$message, "\n")

                        showNotification(
                            "Graph loaded but causal assertions could not be loaded. Edge information may be limited.",
                            type = "warning",
                            duration = 5
                        )
                    }
                }, error = function(e) {
                    current_data$causal_assertions <- list()
                    current_data$lazy_loader <- NULL
                    current_data$assertions_loaded <- FALSE
                    current_data$loading_strategy <- "error"
                    cat("Error loading causal assertions:", e$message, "\n")
                })

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph loaded successfully"
                ))

                # Hide loading section after a brief delay
                session$sendCustomMessage("hideLoadingSection", list())

                # Update DAG status to show it's ready to save
                session$sendCustomMessage("updateDAGStatus", list(
                    status = "Loaded - Ready to save",
                    color = "#28a745"
                ))

                # Suggest causal analysis for newly loaded DAGs
                if (!is.null(current_data$dag_object)) {
                    vars_info <- get_dag_variables(current_data$dag_object)
                    if (vars_info$success && vars_info$total_count >= 3) {
                        showNotification(
                            HTML("Ready for analysis! <br/>Try the <strong>Causal Analysis</strong> tab to identify adjustment sets."),
                            type = "message",
                            duration = 5
                        )
                    }
                }
            } else {
                session$sendCustomMessage("hideLoadingSection", list())
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            session$sendCustomMessage("hideLoadingSection", list())
            showNotification(paste("Error loading graph:", e$message), type = "error")
        })
    })
    
    # Handle file upload
    observeEvent(input$dag_file_upload, {
        if (is.null(input$dag_file_upload)) return()

        # Get the uploaded file info
        file_info <- input$dag_file_upload

        # Copy file to graph_creation/result directory
        result_dir <- "../graph_creation/result"
        if (!dir.exists(result_dir)) {
            dir.create(result_dir, recursive = TRUE)
        }

        new_filename <- file_info$name
        destination_path <- file.path(result_dir, new_filename)
        file.copy(file_info$datapath, destination_path, overwrite = TRUE)

        showNotification(paste("File", new_filename, "uploaded successfully to graph_creation/result"), type = "message")
        
        # Refresh file list
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)
        }, error = function(e) {
            showNotification(paste("Error refreshing file list:", e$message), type = "error")
        })
    })
    
    # Upload and load DAG with progress indication
    observeEvent(input$upload_and_load, {
        if (is.null(input$dag_file_upload)) {
            showNotification("Please select a file first", type = "error")
            session$sendCustomMessage("hideLoadingSection", list())
            return()
        }

        tryCatch({
            # Get the uploaded file info
            file_info <- input$dag_file_upload
            new_filename <- file_info$name

            # Update progress: Copying file
            session$sendCustomMessage("updateProgress", list(
                percent = 30,
                text = "Copying file...",
                status = paste("Saving", new_filename, "to graph_creation/result directory")
            ))

            # Copy file to graph_creation/result directory
            result_dir <- "../graph_creation/result"
            if (!dir.exists(result_dir)) {
                dir.create(result_dir, recursive = TRUE)
            }
            destination_path <- file.path(result_dir, new_filename)
            file.copy(file_info$datapath, destination_path, overwrite = TRUE)

            # Update progress: Validating file
            session$sendCustomMessage("updateProgress", list(
                percent = 50,
                text = "Validating file...",
                status = paste("Checking", new_filename)
            ))

            # Load the DAG
            result <- load_dag_from_file(new_filename)

            if (result$success) {
                # Update progress: Processing graph
                session$sendCustomMessage("updateProgress", list(
                    percent = 70,
                    text = "Processing graph...",
                    status = "Converting graph data structure"
                ))

                # Process the loaded DAG
                network_data <- create_network_data(result$dag)
                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- new_filename

                # Update progress: Updating file list
                session$sendCustomMessage("updateProgress", list(
                    percent = 90,
                    text = "Updating file list...",
                    status = "Refreshing available files"
                ))

                # Update file list
                current_data$available_files <- scan_for_dag_files()
                choices <- current_data$available_files
                if (length(choices) == 0) {
                    choices <- "No DAG files found"
                }
                updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph uploaded and loaded successfully"
                ))

                # Hide loading section after a brief delay
                session$sendCustomMessage("hideLoadingSection", list())

                # Update DAG status to show it's ready to save
                session$sendCustomMessage("updateDAGStatus", list(
                    status = "Uploaded - Ready to save",
                    color = "#28a745"
                ))

                showNotification(paste("Successfully uploaded and loaded graph from", new_filename), type = "message")
            } else {
                session$sendCustomMessage("hideLoadingSection", list())
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            session$sendCustomMessage("hideLoadingSection", list())
            showNotification(paste("Error loading uploaded graph:", e$message), type = "error")
        })
    })
    
    # Generate legend HTML using modular function
    output$legend_html <- renderUI({
        HTML(generate_legend_html(current_data$nodes))
    })
    
    # Reload data function
    reload_dag_data <- function() {
        tryCatch({
            source("dag_data.R", local = TRUE)
            if (exists("dag_nodes") && exists("dag_edges")) {
                # Validate the reloaded data using modular functions
                current_data$nodes <- validate_node_data(dag_nodes)
                current_data$edges <- validate_edge_data(dag_edges)
                if (exists("dag_object")) {
                    current_data$dag_object <- dag_object
                }
                if (exists("dag_loaded_from")) {
                    current_data$current_file <- dag_loaded_from
                }
                if (exists("available_dag_files")) {
                    current_data$available_files <- available_dag_files
                }
                showNotification("DAG data reloaded successfully!", type = "message")
            } else {
                showNotification("Error: dag_nodes or dag_edges not found in dag_data.R", type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Error reloading data:", e$message), type = "error")
        })
    }
    
    # Reload data button
    observeEvent(input$reload_data, {
        reload_dag_data()
    })
    
    # Render the network using modular function
    output$network <- renderVisNetwork({
        # Include force_refresh to trigger re-rendering for undo functionality
        current_data$force_refresh

        # Show loading message for large graphs
        if (!is.null(current_data$nodes) && nrow(current_data$nodes) > 8000) {
            showNotification(
                "Rendering large graph visualization... Please wait.",
                type = "message",
                duration = 3,
                id = "large_graph_render"
            )
        }

        create_interactive_network(current_data$nodes, current_data$edges,
                                 input$physics_strength, input$spring_length,
                                 input$force_full_display)
    })

    # Fit network to container after rendering
    observe({
        if (!is.null(current_data$nodes) && !is.null(current_data$edges)) {
            visNetworkProxy("network") %>%
                visFit(nodes = NULL, animation = list(duration = 500, easingFunction = "easeInOutQuad"))
        }
    })

    # Reset physics button using modular function
    observeEvent(input$reset_physics, {
        reset_physics_controls(session)
    })

    # ===== EDGE SELECTION EVENT HANDLERS =====

    # Reactive values for storing edge selection information
    selection_data <- reactiveValues(
        selected_edge = NULL
    )

    # Handle edge selection only
    observeEvent(input$selected_edge_info, {
        if (!is.null(input$selected_edge_info)) {
            # Parse edge ID to extract from and to nodes
            edge_parts <- strsplit(input$selected_edge_info, "_", fixed = TRUE)[[1]]
            if (length(edge_parts) >= 2) {
                # Handle cases where node names might contain underscores
                for (split_point in 1:(length(edge_parts)-1)) {
                    potential_from <- paste(edge_parts[1:split_point], collapse = "_")
                    potential_to <- paste(edge_parts[(split_point+1):length(edge_parts)], collapse = "_")

                    # Check if this combination exists in our edges
                    if (!is.null(current_data$edges) && nrow(current_data$edges) > 0) {
                        edge_exists <- any(current_data$edges$from == potential_from &
                                         current_data$edges$to == potential_to)

                        if (edge_exists) {
                            selection_data$selected_edge <- list(
                                from = potential_from,
                                to = potential_to,
                                id = input$selected_edge_info
                            )
                            break
                        }
                    }
                }
            }
        } else {
            # Clear selection when edge is deselected
            selection_data$selected_edge <- NULL
        }
    })

    # Render edge selection title
    output$selected_item_title <- renderText({
        if (!is.null(selection_data$selected_edge)) {
            paste("Edge Information:", selection_data$selected_edge$from, "→", selection_data$selected_edge$to)
        } else {
            "Select an edge to view information"
        }
    })

    # Render edge information table
    output$selection_info_table <- DT::renderDataTable({
        if (!is.null(selection_data$selected_edge)) {
            # Get PMID data for the selected edge
            pmid_data <- tryCatch({
                find_edge_pmid_data(
                    selection_data$selected_edge$from,
                    selection_data$selected_edge$to,
                    current_data$causal_assertions,
                    current_data$lazy_loader
                )
            }, error = function(e) {
                cat("ERROR in find_edge_pmid_data:", e$message, "\n")
                return(list(
                    found = FALSE,
                    message = paste("Error:", e$message),
                    pmid_list = character(0),
                    sentence_data = list(),
                    evidence_count = 0,
                    predicate = "CAUSES",
                    subject_cui = "",
                    object_cui = ""
                ))
            })

            # Create edge information with individual PMID rows
            if (pmid_data$found && length(pmid_data$pmid_list) > 0) {
                # Create formatted node names with consolidated CUI information
                from_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$from,
                    pmid_data$subject_cui,
                    current_data$consolidated_cui_mappings
                )

                to_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$to,
                    pmid_data$object_cui,
                    current_data$consolidated_cui_mappings
                )

                # Create one row per PMID
                edge_info <- data.frame(
                    "From Node" = rep(from_node_with_cui, length(pmid_data$pmid_list)),
                    "Predicate" = rep(pmid_data$predicate, length(pmid_data$pmid_list)),
                    "To Node" = rep(to_node_with_cui, length(pmid_data$pmid_list)),
                    "PMID" = sapply(pmid_data$pmid_list, function(pmid) {
                        paste0('<a href="https://pubmed.ncbi.nlm.nih.gov/', pmid, '/" target="_blank">', pmid, '</a>')
                    }),
                    "Causal Sentences" = sapply(1:length(pmid_data$pmid_list), function(i) {
                        pmid <- pmid_data$pmid_list[i]
                        # Fix: Access sentence_data safely with error handling
                        sentences <- tryCatch({
                            if (is.list(pmid_data$sentence_data) && !is.null(pmid_data$sentence_data[[pmid]])) {
                                pmid_data$sentence_data[[pmid]]
                            } else {
                                character(0)
                            }
                        }, error = function(e) {
                            cat("ERROR accessing sentence_data for PMID", pmid, ":", e$message, "\n")
                            cat("sentence_data type:", class(pmid_data$sentence_data), "\n")
                            cat("sentence_data length:", length(pmid_data$sentence_data), "\n")
                            character(0)
                        })
                        if (is.null(sentences) || length(sentences) == 0) {
                            return("No sentences available")
                        } else {
                            # Create unique IDs for this PMID's content
                            short_id <- paste0("short_", pmid, "_", i)
                            full_id <- paste0("full_", pmid, "_", i)
                            expand_id <- paste0("expand_", pmid, "_", i)
                            collapse_id <- paste0("collapse_", pmid, "_", i)

                            # Format all sentences
                            all_formatted_sentences <- sapply(sentences, function(s) {
                                if (nchar(s) > 200) {
                                    paste0(substr(s, 1, 197), "...")
                                } else {
                                    s
                                }
                            })

                            # Create short version (first 3 sentences)
                            display_sentences <- all_formatted_sentences[1:min(3, length(all_formatted_sentences))]
                            short_content <- paste(display_sentences, collapse = "<br><br>")

                            # Create full version (all sentences)
                            full_content <- paste(all_formatted_sentences, collapse = "<br><br>")

                            if (length(sentences) > 3) {
                                # Create expandable content
                                result <- paste0(
                                    '<div id="', short_id, '">',
                                    short_content,
                                    '<br><a href="javascript:void(0)" onclick="',
                                    "document.getElementById('", short_id, "').style.display='none'; ",
                                    "document.getElementById('", full_id, "').style.display='block';",
                                    '" style="color: #337ab7; text-decoration: underline; cursor: pointer;">',
                                    '<i>... and ', length(sentences) - 3, ' more sentences (click to expand)</i>',
                                    '</a></div>',
                                    '<div id="', full_id, '" style="display: none;">',
                                    full_content,
                                    '<br><a href="javascript:void(0)" onclick="',
                                    "document.getElementById('", full_id, "').style.display='none'; ",
                                    "document.getElementById('", short_id, "').style.display='block';",
                                    '" style="color: #337ab7; text-decoration: underline; cursor: pointer;">',
                                    '<i>(click to collapse)</i>',
                                    '</a></div>'
                                )
                            } else {
                                result <- short_content
                            }
                            return(result)
                        }
                    }),
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                )
            } else {
                # Create formatted node names with consolidated CUI information
                from_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$from,
                    pmid_data$subject_cui,
                    current_data$consolidated_cui_mappings
                )

                to_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$to,
                    pmid_data$object_cui,
                    current_data$consolidated_cui_mappings
                )

                # Show single row with no PMID data message
                edge_info <- data.frame(
                    "From Node" = from_node_with_cui,
                    "Predicate" = if (current_data$assertions_loaded) {
                        pmid_data$predicate %||% "CAUSES"
                    } else {
                        "N/A"
                    },
                    "To Node" = to_node_with_cui,
                    "PMID" = if (current_data$assertions_loaded) {
                        "No PMID data available for this edge"
                    } else {
                        "Causal assertions data not loaded"
                    },
                    "Causal Sentences" = if (current_data$assertions_loaded) {
                        "No sentence data available"
                    } else {
                        "Causal assertions data not loaded"
                    },
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                )
            }

            edge_info
        } else {
            data.frame(
                Information = "Click on an edge in the network above to view detailed information",
                stringsAsFactors = FALSE
            )
        }
    }, escape = FALSE, options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "250px",
        dom = 'frtip',
        autoWidth = FALSE,
        responsive = TRUE,
        columnDefs = list(
            list(className = 'dt-left', targets = '_all'),
            list(width = '15%', targets = 0),  # From Node column
            list(width = '12%', targets = 1),  # Predicate column
            list(width = '15%', targets = 2),  # To Node column
            list(width = '12%', targets = 3),  # PMID column
            list(width = '46%', targets = 4),  # Causal Sentences column (wider for expandable content)
            list(className = 'dt-body-nowrap', targets = c(0, 1, 2, 3))  # Prevent wrapping in first 4 columns
        ),
        scrollCollapse = TRUE,
        paging = TRUE,
        searching = TRUE,
        ordering = TRUE,
        info = TRUE,
        lengthChange = FALSE
    ), rownames = FALSE, class = 'cell-border stripe hover')

    # Graph Parameters button handler
    observeEvent(input$graph_params_btn, {
        # Show notification about navigation
        showNotification(
            "Navigating to Graph Configuration tab...",
            type = "message",
            duration = 2
        )
    })

    # Quick causal analysis navigation
    observeEvent(input$quick_causal_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "warning")
            return()
        }

        # Navigate to causal analysis tab
        updateTabItems(session, "sidebar", "causal")
        showNotification(
            "Navigating to Causal Analysis tab...",
            type = "message",
            duration = 2
        )
    })

    # ===== NODE AND EDGE REMOVAL EVENT HANDLERS =====

    # Debug: Monitor node selections
    observeEvent(input$network_selected, {
        cat("DEBUG: Node selected:", input$network_selected, "\n")
    })

    # Debug: Monitor edge selections
    observeEvent(input$selected_edge_info, {
        cat("DEBUG: Edge selected:", input$selected_edge_info, "\n")
    })

    # Remove selected node
    observeEvent(input$remove_node_btn, {
        if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
            showNotification("No graph loaded", type = "warning")
            return()
        }

        # Get selected node from network
        selected_node <- input$network_selected
        cat("DEBUG: Selected node for removal:", selected_node, "\n")

        if (is.null(selected_node) || length(selected_node) == 0 || selected_node == "") {
            showNotification("Please select a node first by clicking on it", type = "warning")
            return()
        }

        # Remove the node
        result <- remove_node_from_network(session, "network", selected_node, current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)

            # Update DAG object if it exists
            if (!is.null(current_data$dag_object)) {
                # Note: DAG object becomes invalid after manual modifications
                current_data$dag_object <- NULL
                showNotification("DAG object cleared due to manual modifications", type = "message")
            }

            # Update DAG status to show it's been modified
            session$sendCustomMessage("updateDAGStatus", list(
                status = "Modified - Ready to save",
                color = "#ffc107"
            ))
        } else {
            showNotification(result$message, type = "error")
        }
    })

    # Remove selected edge
    observeEvent(input$remove_edge_btn, {
        if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
            showNotification("No edges in graph", type = "warning")
            return()
        }

        # Get selected edge
        selected_edge <- input$selected_edge_info
        cat("DEBUG: Selected edge for removal:", selected_edge, "\n")

        if (is.null(selected_edge) || selected_edge == "") {
            showNotification("Please select an edge first by clicking on it", type = "warning")
            return()
        }

        # Remove the edge
        result <- remove_edge_from_network(session, "network", selected_edge, current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)

            # Update DAG object if it exists
            if (!is.null(current_data$dag_object)) {
                # Note: DAG object becomes invalid after manual modifications
                current_data$dag_object <- NULL
                showNotification("DAG object cleared due to manual modifications", type = "message")
            }

            # Update DAG status to show it's been modified
            session$sendCustomMessage("updateDAGStatus", list(
                status = "Modified - Ready to save",
                color = "#ffc107"
            ))
        } else {
            showNotification(result$message, type = "error")
        }
    })

    # Undo last removal
    observeEvent(input$undo_removal, {
        result <- undo_last_removal(session, "network", current_data)

        if (result$success) {
            showNotification(result$message, type = "message", duration = 3)
        } else {
            showNotification(result$message, type = "warning")
        }
    })

    # ===== KEYBOARD SHORTCUT HANDLERS =====

    # Keyboard node removal (Delete/Backspace key)
    observeEvent(input$keyboard_remove_node, {
        if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
            return()
        }

        node_id <- input$keyboard_remove_node$nodeId
        if (!is.null(node_id) && node_id != "") {
            result <- remove_node_from_network(session, "network", node_id, current_data)

            if (result$success) {
                showNotification(paste("Deleted:", result$message), type = "message", duration = 2)

                # Update DAG object if it exists
                if (!is.null(current_data$dag_object)) {
                    current_data$dag_object <- NULL
                }
            }
        }
    })

    # Keyboard edge removal (Delete/Backspace key)
    observeEvent(input$keyboard_remove_edge, {
        if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
            return()
        }

        edge_id <- input$keyboard_remove_edge$edgeId
        if (!is.null(edge_id) && edge_id != "") {
            result <- remove_edge_from_network(session, "network", edge_id, current_data)

            if (result$success) {
                showNotification(paste("Deleted:", result$message), type = "message", duration = 2)

                # Update DAG object if it exists
                if (!is.null(current_data$dag_object)) {
                    current_data$dag_object <- NULL
                }
            }
        }
    })

    # Keyboard undo (Ctrl+Z)
    observeEvent(input$keyboard_undo, {
        result <- undo_last_removal(session, "network", current_data)

        if (result$success) {
            showNotification(paste("Undo:", result$message), type = "message", duration = 2)
        }
    })

    # Network statistics output
    output$network_stats_text <- renderText({
        if (is.null(current_data$nodes) || is.null(current_data$edges)) {
            return("No graph loaded")
        }
        stats <- get_network_stats(current_data)
        paste("Nodes:", stats$nodes, "| Edges:", stats$edges)
    })

    # Node information output using modular function
    output$node_info <- renderText({
        format_node_info(input$network_selected, current_data$nodes)
    })

    # Nodes table using modular function
    output$nodes_table <- DT::renderDataTable({
        create_nodes_display_table(current_data$nodes)
    }, options = list(pageLength = 15))
    
    # Value boxes using modular function
    summary_stats <- reactive({
        generate_summary_stats(current_data$nodes, current_data$edges)
    })

    output$total_nodes <- renderValueBox({
        stats <- summary_stats()$total_nodes
        valueBox(
            value = stats$value,
            subtitle = stats$subtitle,
            icon = icon(stats$icon),
            color = stats$color
        )
    })

    output$total_edges <- renderValueBox({
        stats <- summary_stats()$total_edges
        valueBox(
            value = stats$value,
            subtitle = stats$subtitle,
            icon = icon(stats$icon),
            color = stats$color
        )
    })

    output$total_groups <- renderValueBox({
        stats <- summary_stats()$total_groups
        valueBox(
            value = stats$value,
            subtitle = stats$subtitle,
            icon = icon(stats$icon),
            color = stats$color
        )
    })
    
    # Node distribution plot using modular function
    output$node_distribution <- renderPlot({
        plot_data <- create_distribution_plot_data(current_data$nodes)
        if (length(plot_data$counts) > 0) {
            barplot(plot_data$counts,
                    names.arg = plot_data$labels,
                    main = "Node Distribution by Group",
                    xlab = "Group",
                    ylab = "Count",
                    col = plot_data$colors,
                    las = 2)
        }
    })

    # DAG information using modular function
    output$dag_info <- renderText({
        generate_dag_report(current_data$nodes, current_data$edges, current_data$current_file)
    })

    # Cycle detection using modular function
    output$cycle_detection <- renderText({
        generate_cycle_report(current_data$nodes, current_data$edges)
    })

    # ===== CAUSAL ANALYSIS SERVER LOGIC =====

    # Update variable choices when DAG changes
    observe({
        if (!is.null(current_data$dag_object)) {
            vars_info <- get_dag_variables(current_data$dag_object)
            if (vars_info$success) {
                # Update exposure choices
                exp_choices <- vars_info$variables
                names(exp_choices) <- vars_info$variables
                updateSelectInput(session, "causal_exposure",
                                choices = exp_choices,
                                selected = if (length(vars_info$exposures) > 0) vars_info$exposures[1] else NULL)

                # Update outcome choices
                out_choices <- vars_info$variables
                names(out_choices) <- vars_info$variables
                updateSelectInput(session, "causal_outcome",
                                choices = out_choices,
                                selected = if (length(vars_info$outcomes) > 0) vars_info$outcomes[1] else NULL)
            }
        } else {
            # Clear choices when no DAG is loaded
            updateSelectInput(session, "causal_exposure", choices = NULL)
            updateSelectInput(session, "causal_outcome", choices = NULL)
        }
    })

    # DAG variables overview
    output$dag_variables_info <- renderText({
        if (is.null(current_data$dag_object)) {
            return("No DAG loaded. Please load a DAG file from the Data Upload tab.")
        }

        vars_info <- get_dag_variables(current_data$dag_object)
        if (!vars_info$success) {
            return(paste("Error:", vars_info$message))
        }

        paste0(
            "DAG Variables Summary\n",
            "====================\n",
            "Total Variables: ", vars_info$total_count, "\n",
            "Exposure Variables: ", if (length(vars_info$exposures) > 0) paste(vars_info$exposures, collapse = ", ") else "None defined", "\n",
            "Outcome Variables: ", if (length(vars_info$outcomes) > 0) paste(vars_info$outcomes, collapse = ", ") else "None defined", "\n",
            "Other Variables: ", if (length(vars_info$other_variables) > 0) paste(vars_info$other_variables, collapse = ", ") else "None", "\n\n",
            "Note: You can select any variable as exposure or outcome for analysis, regardless of DAG definitions."
        )
    })

    # Calculate adjustment sets
    observeEvent(input$calculate_adjustment_sets, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }

        if (is.null(input$causal_exposure) || is.null(input$causal_outcome)) {
            showNotification("Please select both exposure and outcome variables", type = "warning")
            return()
        }

        if (input$causal_exposure == input$causal_outcome) {
            showNotification("Exposure and outcome must be different variables", type = "warning")
            return()
        }

        # Show progress
        shinyjs::show("causal_progress")

        # Calculate adjustment sets
        result <- calculate_adjustment_sets(
            current_data$dag_object,
            exposure = input$causal_exposure,
            outcome = input$causal_outcome,
            effect = input$causal_effect_type
        )

        # Hide progress
        shinyjs::hide("causal_progress")

        # Update results
        output$adjustment_sets_result <- renderText({
            format_adjustment_sets_display(result)
        })

        # Show notification
        if (result$success) {
            showNotification(
                paste("Found", result$total_sets, "adjustment set(s)"),
                type = "message"
            )
        } else {
            showNotification(result$message, type = "error")
        }
    })

    # Find instrumental variables
    observeEvent(input$find_instruments, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }

        if (is.null(input$causal_exposure) || is.null(input$causal_outcome)) {
            showNotification("Please select both exposure and outcome variables", type = "warning")
            return()
        }

        # Show progress
        shinyjs::show("causal_progress")

        # Find instruments
        result <- find_instrumental_variables(
            current_data$dag_object,
            exposure = input$causal_exposure,
            outcome = input$causal_outcome
        )

        # Hide progress
        shinyjs::hide("causal_progress")

        # Update results
        output$instrumental_vars_result <- renderText({
            if (!result$success) {
                return(paste("Error:", result$message))
            }

            if (result$count == 0) {
                return(paste0(
                    "No instrumental variables found for:\n",
                    "Exposure: ", input$causal_exposure, "\n",
                    "Outcome: ", input$causal_outcome, "\n\n",
                    "This means there are no variables in the DAG that:\n",
                    "1. Affect the exposure variable\n",
                    "2. Do not directly affect the outcome\n",
                    "3. Are not affected by unmeasured confounders\n\n",
                    "Consider using adjustment sets for causal identification."
                ))
            } else {
                return(paste0(
                    "Instrumental Variables Found\n",
                    "============================\n",
                    "Exposure: ", input$causal_exposure, "\n",
                    "Outcome: ", input$causal_outcome, "\n",
                    "Instruments: ", paste(result$instruments, collapse = ", "), "\n\n",
                    "These variables can be used for instrumental variable analysis\n",
                    "to estimate causal effects when adjustment is not sufficient."
                ))
            }
        })

        # Show notification
        showNotification(result$message, type = if (result$success) "message" else "error")
    })

    # Analyze causal paths
    observeEvent(input$analyze_paths, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }

        if (is.null(input$causal_exposure) || is.null(input$causal_outcome)) {
            showNotification("Please select both exposure and outcome variables", type = "warning")
            return()
        }

        if (input$causal_exposure == input$causal_outcome) {
            showNotification("Exposure and outcome must be different variables", type = "warning")
            return()
        }

        # Show progress
        shinyjs::show("causal_progress")

        # Analyze paths
        result <- analyze_causal_paths(
            current_data$dag_object,
            from = input$causal_exposure,
            to = input$causal_outcome
        )

        # Hide progress
        shinyjs::hide("causal_progress")

        # Update results
        output$causal_paths_result <- renderText({
            if (!result$success) {
                return(paste("Error:", result$message))
            }

            if (result$total_paths == 0) {
                return(paste0(
                    "No paths found from ", input$causal_exposure, " to ", input$causal_outcome, "\n\n",
                    "This means there is no causal relationship between these variables\n",
                    "according to the current DAG structure."
                ))
            }

            # Format paths output
            header <- paste0(
                "Causal Paths Analysis\n",
                "====================\n",
                "From: ", result$from, "\n",
                "To: ", result$to, "\n",
                "Total Paths: ", result$total_paths, "\n\n"
            )

            paths_text <- ""
            for (i in seq_along(result$paths)) {
                path_info <- result$paths[[i]]
                status <- if (path_info$is_open) "OPEN (creates confounding)" else "BLOCKED"
                paths_text <- paste0(
                    paths_text,
                    "Path ", i, ": ", path_info$description, "\n",
                    "Status: ", status, "\n",
                    "Length: ", path_info$length, " variables\n\n"
                )
            }

            interpretation <- paste0(
                "Interpretation:\n",
                "- OPEN paths create confounding and need to be blocked\n",
                "- BLOCKED paths are already controlled by the DAG structure\n",
                "- Use adjustment sets to block open confounding paths"
            )

            return(paste0(header, paths_text, interpretation))
        })

        # Show notification
        showNotification(result$message, type = if (result$success) "message" else "error")
    })

    # Run complete causal analysis
    observeEvent(input$run_full_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }

        if (is.null(input$causal_exposure) || is.null(input$causal_outcome)) {
            showNotification("Please select both exposure and outcome variables", type = "warning")
            return()
        }

        if (input$causal_exposure == input$causal_outcome) {
            showNotification("Exposure and outcome must be different variables", type = "warning")
            return()
        }

        # Show progress
        shinyjs::show("causal_progress")

        # Run complete analysis
        summary_result <- create_causal_analysis_summary(
            current_data$dag_object,
            exposure = input$causal_exposure,
            outcome = input$causal_outcome
        )

        # Hide progress
        shinyjs::hide("causal_progress")

        if (summary_result$success) {
            # Update all result tabs
            output$adjustment_sets_result <- renderText({
                format_adjustment_sets_display(summary_result$adjustment_sets)
            })

            output$instrumental_vars_result <- renderText({
                result <- summary_result$instrumental_variables
                if (!result$success) {
                    return(paste("Error:", result$message))
                }

                if (result$count == 0) {
                    return(paste0(
                        "No instrumental variables found for:\n",
                        "Exposure: ", input$causal_exposure, "\n",
                        "Outcome: ", input$causal_outcome, "\n\n",
                        "This means there are no variables in the DAG that:\n",
                        "1. Affect the exposure variable\n",
                        "2. Do not directly affect the outcome\n",
                        "3. Are not affected by unmeasured confounders\n\n",
                        "Consider using adjustment sets for causal identification."
                    ))
                } else {
                    return(paste0(
                        "Instrumental Variables Found\n",
                        "============================\n",
                        "Exposure: ", input$causal_exposure, "\n",
                        "Outcome: ", input$causal_outcome, "\n",
                        "Instruments: ", paste(result$instruments, collapse = ", "), "\n\n",
                        "These variables can be used for instrumental variable analysis\n",
                        "to estimate causal effects when adjustment is not sufficient."
                    ))
                }
            })

            output$causal_paths_result <- renderText({
                result <- summary_result$causal_paths
                if (is.null(result) || !result$success) {
                    return("Path analysis not available")
                }

                if (result$total_paths == 0) {
                    return(paste0(
                        "No paths found from ", input$causal_exposure, " to ", input$causal_outcome, "\n\n",
                        "This means there is no causal relationship between these variables\n",
                        "according to the current DAG structure."
                    ))
                }

                # Format paths output
                header <- paste0(
                    "Causal Paths Analysis\n",
                    "====================\n",
                    "From: ", result$from, "\n",
                    "To: ", result$to, "\n",
                    "Total Paths: ", result$total_paths, "\n\n"
                )

                paths_text <- ""
                for (i in seq_along(result$paths)) {
                    path_info <- result$paths[[i]]
                    status <- if (path_info$is_open) "OPEN (creates confounding)" else "BLOCKED"
                    paths_text <- paste0(
                        paths_text,
                        "Path ", i, ": ", path_info$description, "\n",
                        "Status: ", status, "\n",
                        "Length: ", path_info$length, " variables\n\n"
                    )
                }

                interpretation <- paste0(
                    "Interpretation:\n",
                    "- OPEN paths create confounding and need to be blocked\n",
                    "- BLOCKED paths are already controlled by the DAG structure\n",
                    "- Use adjustment sets to block open confounding paths"
                )

                return(paste0(header, paths_text, interpretation))
            })

            # Show success notification
            showNotification(
                "Complete causal analysis finished! Check all result tabs.",
                type = "message",
                duration = 5
            )
        } else {
            showNotification(
                paste("Analysis failed:", summary_result$message),
                type = "error"
            )
        }
    })

    # Helper function to extract causal assertions for modified DAG
    extract_modified_dag_assertions <- function(edges_data, assertions_data) {
        if (is.null(edges_data) || nrow(edges_data) == 0 || is.null(assertions_data) || length(assertions_data) == 0) {
            return(list(
                pmid_sentences = list(),
                assertions = list()
            ))
        }

        # Initialize optimized structure
        pmid_sentences <- list()
        assertions <- list()

        for (i in seq_len(nrow(edges_data))) {
            edge <- edges_data[i, ]
            from_node <- edge$from
            to_node <- edge$to

            # Find matching assertion in original data
            pmid_data <- find_edge_pmid_data(from_node, to_node, assertions_data, current_data$lazy_loader)

            if (pmid_data$found && length(pmid_data$pmid_list) > 0) {
                # Create assertion entry in optimized format
                assertion_entry <- list(
                    subj = pmid_data$original_subject %||% from_node,
                    subj_cui = pmid_data$subject_cui %||% "",
                    obj = pmid_data$original_object %||% to_node,
                    obj_cui = pmid_data$object_cui %||% "",
                    ev_count = pmid_data$evidence_count %||% length(pmid_data$pmid_list),
                    pmid_refs = pmid_data$pmid_list
                )

                # Add sentences to pmid_sentences mapping
                for (pmid in pmid_data$pmid_list) {
                    sentences <- if (!is.null(pmid_data$sentence_data[[pmid]])) {
                        pmid_data$sentence_data[[pmid]]
                    } else {
                        list("Evidence sentence not available")
                    }

                    # Only add if not already present
                    if (is.null(pmid_sentences[[pmid]])) {
                        pmid_sentences[[pmid]] <- sentences
                    }
                }

                assertions[[length(assertions) + 1]] <- assertion_entry
            }
        }

        return(list(
            pmid_sentences = pmid_sentences,
            assertions = assertions
        ))
    }

    # Save DAG functionality - Main save button
    output$save_dag_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

                # Show success notification
                showNotification(
                    paste("DAG saved successfully as", basename(file)),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving DAG:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Save DAG functionality - Small button (same as main)
    output$save_dag_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

                # Show success notification
                showNotification(
                    paste("DAG saved successfully as", basename(file)),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving DAG:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Save updated causal assertions JSON file
    output$save_json_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract k_hops from current file or use default
                k_hops <- current_data$k_hops %||% 1
                paste0("evidence_from_graph_", k_hops, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Save updated causal assertions JSON file - Main button (same as save_json_btn)
    output$save_json_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract k_hops from current file or use default
                k_hops <- current_data$k_hops %||% 1
                paste0("evidence_from_graph_", k_hops, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Save HTML functionality - Main button
    output$save_html_main <- downloadHandler(
        filename = function() {
            "evidence_from_graph.html"
        },
        content = function(file) {
            tryCatch({
                # Show progress notification
                showNotification("Converting JSON to HTML... This may take a moment for large datasets.",
                               type = "message", duration = 5, id = "html_conversion")

                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Convert to HTML using the simplified module
                html_content <- convert_json_to_html(
                    modified_assertions,
                    title = "Causal Knowledge Trace - Evidence Report"
                )

                # Write HTML to file
                writeLines(html_content, file, useBytes = TRUE)

                # Remove progress notification
                removeNotification("html_conversion")
                showNotification("HTML report generated successfully!", type = "message")

            }, error = function(e) {
                removeNotification("html_conversion")
                showNotification(paste("Error generating HTML report:", e$message), type = "error")
                stop(paste("Error generating HTML report:", e$message))
            })
        },
        contentType = "text/html"
    )

    # Save HTML functionality - Small button (same as main)
    output$save_html_btn <- downloadHandler(
        filename = function() {
            "evidence_from_graph.html"
        },
        content = function(file) {
            tryCatch({
                # Show progress notification
                showNotification("Converting JSON to HTML... This may take a moment for large datasets.",
                               type = "message", duration = 5, id = "html_conversion_small")

                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Convert to HTML using the simplified module
                html_content <- convert_json_to_html(
                    modified_assertions,
                    title = "Causal Knowledge Trace - Evidence Report"
                )

                # Write HTML to file
                writeLines(html_content, file, useBytes = TRUE)

                # Remove progress notification
                removeNotification("html_conversion_small")
                showNotification("HTML report generated successfully!", type = "message")

            }, error = function(e) {
                removeNotification("html_conversion_small")
                showNotification(paste("Error generating HTML report:", e$message), type = "error")
                stop(paste("Error generating HTML report:", e$message))
            })
        },
        contentType = "text/html"
    )

    # Remove the example_structure output since it's no longer needed
}

# Create and return the Shiny application object
# This works both when sourced directly and when called by runApp()
shinyApp(ui = ui, server = server)