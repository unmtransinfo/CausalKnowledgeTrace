# Load required libraries
library(shiny)
library(shinydashboard)
library(visNetwork)
library(dplyr)
library(DT)

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

                /* Resizable DAG visualization styles */
                .resizable-dag-container {
                    position: relative;
                    min-height: 400px;
                    max-height: 1200px;
                    height: 800px;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    overflow: hidden;
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

                                // Force visNetwork to redraw after resize
                                setTimeout(function() {
                                    if (window.network && typeof window.network.redraw === 'function') {
                                        window.network.redraw();
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
                        div(class = "resizable-dag-container",
                            visNetworkOutput("network", height = "100%", width = "100%"),
                            div(class = "dag-resize-handle")
                        ),
                        div(style = "margin-top: 10px;",
                            helpText("Click on edges to view information below.")
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
                        height = "400px",
                        div(id = "selection_info_panel",
                            h5(textOutput("selected_item_title")),
                            DT::dataTableOutput("selection_info_table", height = "300px")
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
        current_file = "No graph loaded"
    )

    # Initialize available files list on startup
    observe({
        tryCatch({
            current_data$available_files <- scan_for_dag_files()
            choices <- current_data$available_files
            if (length(choices) == 0) {
                choices <- "No DAG files found"
            }
            updateSelectInput(session, "dag_file_selector", choices = choices)
        }, error = function(e) {
            cat("Error scanning for DAG files on startup:", e$message, "\n")
            updateSelectInput(session, "dag_file_selector", choices = "No DAG files found")
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
            paste0(
                "STATUS: Graph loaded successfully ✓\n",
                "SOURCE: ", current_data$current_file, "\n",
                "NODES: ", nrow(current_data$nodes), "\n",
                "EDGES: ", nrow(current_data$edges), "\n",
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
    
    # Load selected DAG with progress indication
    observeEvent(input$load_selected_dag, {
        if (is.null(input$dag_file_selector) || input$dag_file_selector == "No DAG files found") {
            showNotification("Please select a valid graph file", type = "error")
            session$sendCustomMessage("hideLoadingSection", list())
            return()
        }

        tryCatch({
            # Update progress: File validation
            session$sendCustomMessage("updateProgress", list(
                percent = 40,
                text = "Validating file...",
                status = paste("Checking", input$dag_file_selector)
            ))

            result <- load_dag_from_file(input$dag_file_selector)

            if (result$success) {
                # Update progress: Processing graph
                session$sendCustomMessage("updateProgress", list(
                    percent = 60,
                    text = "Processing graph...",
                    status = "Converting graph data structure"
                ))

                # Process the loaded DAG
                network_data <- create_network_data(result$dag)

                # Update progress: Finalizing
                session$sendCustomMessage("updateProgress", list(
                    percent = 80,
                    text = "Finalizing...",
                    status = "Updating visualization data"
                ))

                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- input$dag_file_selector

                # Update progress: Complete
                session$sendCustomMessage("updateProgress", list(
                    percent = 100,
                    text = "Complete!",
                    status = "Graph loaded successfully"
                ))

                # Hide loading section after a brief delay
                session$sendCustomMessage("hideLoadingSection", list())

                showNotification(paste("Successfully loaded graph from", input$dag_file_selector), type = "message")

                # Suggest causal analysis for newly loaded DAGs
                if (!is.null(current_data$dag_object)) {
                    vars_info <- get_dag_variables(current_data$dag_object)
                    if (vars_info$success && vars_info$total_count >= 3) {
                        showNotification(
                            HTML("DAG loaded successfully! <br/>Try the <strong>Causal Analysis</strong> tab to identify adjustment sets."),
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
        create_interactive_network(current_data$nodes, current_data$edges,
                                 input$physics_strength, input$spring_length)
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
            # Create simplified edge information with only node identification columns
            edge_info <- data.frame(
                "From Node" = selection_data$selected_edge$from,
                "To Node" = selection_data$selected_edge$to,
                stringsAsFactors = FALSE,
                check.names = FALSE
            )
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
        dom = 't',
        columnDefs = list(
            list(className = 'dt-left', targets = '_all')
        )
    ))

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

    # Remove the example_structure output since it's no longer needed
}

# Create and return the Shiny application object
# This works both when sourced directly and when called by runApp()
shinyApp(ui = ui, server = server)