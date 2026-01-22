# Tab Items Content
# This file contains all tab content for the application
# Author: Extracted from app.R UI section

tabItems(
    # About Tab
    tabItem(tabName = "about",
        fluidRow(
            box(
                title = "About CKT - Causal Knowledge Trace",
                status = "primary",
                solidHeader = TRUE,
                width = 12,

                # Application Overview
                div(
                    style = "background-color: #e8f4fd; padding: 20px; margin-bottom: 20px; border-radius: 5px; border-left: 4px solid #2196F3;",
                    h3(icon("info-circle"), " What is CKT?"),
                    p(style = "font-size: 16px;",
                      "CKT (Causal Knowledge Trace) is an interactive web application for exploring and analyzing causal relationships in knowledge graphs.
                      It provides tools for visualizing graphs (which may contain cycles), performing causal inference analysis, and understanding
                      complex relationships between variables extracted from biomedical literature."
                    )
                ),

                # Key Features
                div(
                    style = "background-color: #f0f8ff; padding: 20px; margin-bottom: 20px; border-radius: 5px;",
                    h3(icon("star"), " Key Features"),
                    tags$ul(style = "font-size: 15px;",
                        tags$li(strong("Interactive Graph Visualization:"), " Explore causal graphs with zoom, pan, and physics-based layouts"),
                        tags$li(strong("Graph Editing:"), " Remove nodes and edges, undo changes, and save modified graphs"),
                        tags$li(strong("Causal Analysis:"), " Calculate adjustment sets, find instrumental variables, and analyze causal paths"),
                        tags$li(strong("Graph Configuration:"), " Generate knowledge graphs from biomedical databases with customizable parameters"),
                        tags$li(strong("Multiple Export Options:"), " Save graphs as R files or HTML reports")
                    )
                ),

                hr(),

                # User Guide
                h3(icon("book"), " User Guide"),

                # Step 1: Graph Configuration
                div(
                    style = "background-color: #fff9e6; padding: 15px; margin-bottom: 15px; border-radius: 5px; border-left: 4px solid #ffc107;",
                    h4(icon("cogs"), " Step 1: Graph Configuration (Optional)"),
                    p("If you want to generate a new knowledge graph from the SemMedDB database:"),
                    tags$ol(
                        tags$li("Navigate to the ", strong("Graph Configuration"), " tab"),
                        tags$li("Enter the ", strong("Exposure CUI"), " (Concept Unique Identifier) - you can search for a word and select from available CUIs"),
                        tags$li("Enter the ", strong("Outcome CUI"), " - you can search for a word and select from available CUIs"),
                        tags$li("Configure optional parameters:"),
                        tags$ul(
                            tags$li(strong("Squelch Threshold:"), " Minimum number of unique PMIDs (publications) required for an edge"),
                            tags$li(strong("Publication Year Cutoff:"), " Only include publications from this year onwards"),
                            tags$li(strong("Degree:"), " Maximum distance from exposure/outcome nodes to include"),
                            tags$li(strong("SemMedDB Version:"), " Select the database version to use")
                        ),
                        tags$li("Click ", strong("Generate Graph"), " to create your knowledge graph"),
                        tags$li("Wait for the process to complete - this may take several minutes")
                    ),
                    p(style = "margin-top: 10px; font-style: italic; color: #856404;",
                      icon("lightbulb"), " Tip: If you already have a graph file, you can skip this step and go directly to Data Upload.")
                ),

                # Step 2: Data Upload
                div(
                    style = "background-color: #e7f3ff; padding: 15px; margin-bottom: 15px; border-radius: 5px; border-left: 4px solid #2196F3;",
                    h4(icon("upload"), " Step 2: Data Upload"),
                    p("Load a graph file into the application:"),
                    tags$ol(
                        tags$li("Navigate to the ", strong("Data Upload"), " tab"),
                        tags$li("Choose one of two methods:"),
                        tags$ul(
                            tags$li(strong("Method 1 - Select Existing File:"),
                                   " Choose a file from the dropdown (files in graph_creation/result directory) and click 'Load Selected Graph'"),
                            tags$li(strong("Method 2 - Upload New File:"),
                                   " Use the file upload interface to upload an R file containing your DAG definition")
                        ),
                        tags$li("Optional: Apply filtering to remove leaf nodes (nodes with only one connection)"),
                        tags$li("Wait for the graph to load - you'll see a progress indicator")
                    ),
                    p(style = "margin-top: 10px;",
                      strong("Required File Format:"), " Your R file must contain a dagitty graph definition assigned to variable 'g'")
                ),

                # Step 3: Graph Visualization
                div(
                    style = "background-color: #e8f5e9; padding: 15px; margin-bottom: 15px; border-radius: 5px; border-left: 4px solid #4caf50;",
                    h4(icon("project-diagram"), " Step 3: Graph Visualization"),
                    p("Explore and modify your causal graph:"),
                    tags$ol(
                        tags$li("Navigate to the ", strong("Graph Visualization"), " tab"),
                        tags$li("Interact with the graph:"),
                        tags$ul(
                            tags$li(strong("Zoom:"), " Use mouse wheel or pinch gesture"),
                            tags$li(strong("Pan:"), " Click and drag the background"),
                            tags$li(strong("Select Nodes/Edges:"), " Click on them to view details"),
                            tags$li(strong("Move Nodes:"), " Drag nodes to reposition them")
                        ),
                        tags$li("View edge information in the table below the graph"),
                        tags$li("Modify the graph:"),
                        tags$ul(
                            tags$li("Select a node and click ", strong("Remove Selected Node")),
                            tags$li("Select an edge and click ", strong("Remove Selected Edge")),
                            tags$li("Click ", strong("Undo Last Removal"), " to revert changes")
                        ),
                        tags$li("Adjust physics settings for better layout"),
                        tags$li("Save your work:"),
                        tags$ul(
                            tags$li(strong("Save DAG:"), " Download modified graph as an R file"),
                            tags$li(strong("Save HTML:"), " Export as a readable HTML report")
                        )
                    ),
                    p(style = "margin-top: 10px;",
                      strong("Node Colors:"),
                      tags$span(style = "color: #FF6B6B; font-weight: bold;", " Red"), " = Exposure | ",
                      tags$span(style = "color: #4ECDC4; font-weight: bold;", " Cyan"), " = Outcome | ",
                      tags$span(style = "color: #95A5A6; font-weight: bold;", " Gray"), " = Other variables"
                    )
                ),

                # Step 4: Causal Analysis
                div(
                    style = "background-color: #fff3e0; padding: 15px; margin-bottom: 15px; border-radius: 5px; border-left: 4px solid #ff9800;",
                    h4(icon("search-plus"), " Step 4: Causal Analysis"),
                    p("Perform statistical causal inference analysis:"),
                    tags$ol(
                        tags$li("Navigate to the ", strong("Causal Analysis"), " tab"),
                        tags$li("Select your ", strong("Exposure Variable"), " from the dropdown"),
                        tags$li("Select your ", strong("Outcome Variable"), " from the dropdown"),
                        tags$li("Choose the ", strong("Effect Type"), " (Total Effect or Direct Effect)"),
                        tags$li("Run analyses:"),
                        tags$ul(
                            tags$li(strong("Calculate Adjustment Sets:"), " Find variables to control for to estimate causal effects"),
                            tags$li(strong("Find Instrumental Variables:"), " Identify variables for instrumental variable analysis"),
                            tags$li(strong("Analyze Causal Paths:"), " Examine all paths between exposure and outcome"),
                            tags$li(strong("Run Complete Analysis:"), " Execute all analyses at once")
                        ),
                        tags$li("Review results in the tabbed panels")
                    )
                ),

                hr(),

                # Understanding Causal Concepts
                h3(icon("graduation-cap"), " Understanding Causal Concepts"),

                fluidRow(
                    column(6,
                        div(
                            style = "background-color: #f5f5f5; padding: 15px; border-radius: 5px; height: 100%;",
                            h4(style = "color: #2196F3;", icon("adjust"), " Adjustment Sets"),
                            p("A set of variables that, when controlled for in your analysis, blocks all confounding paths
                              between exposure and outcome. This allows you to estimate the causal effect without bias."),
                            p(strong("Example:"), " If you want to know if smoking causes lung cancer, you might need to
                              adjust for age and genetics to block confounding paths.")
                        )
                    ),
                    column(6,
                        div(
                            style = "background-color: #f5f5f5; padding: 15px; border-radius: 5px; height: 100%;",
                            h4(style = "color: #ff9800;", icon("wrench"), " Instrumental Variables"),
                            p("A variable that (1) affects the exposure, (2) does not directly affect the outcome except
                              through the exposure, and (3) is not associated with confounders."),
                            p(strong("Example:"), " Distance to a smoking cessation clinic might be an instrument for
                              smoking behavior when studying health outcomes.")
                        )
                    )
                ),

                br(),

                fluidRow(
                    column(6,
                        div(
                            style = "background-color: #f5f5f5; padding: 15px; border-radius: 5px; height: 100%;",
                            h4(style = "color: #4caf50;", icon("route"), " Causal Paths"),
                            p("All directed paths from exposure to outcome in the graph. Paths can be 'open' (creating
                              confounding) or 'blocked' (already controlled)."),
                            p(strong("Example:"), " Smoking → Tar Deposits → Lung Cancer is a causal path.")
                        )
                    ),
                    column(6,
                        div(
                            style = "background-color: #f5f5f5; padding: 15px; border-radius: 5px; height: 100%;",
                            h4(style = "color: #9c27b0;", icon("project-diagram"), " Causal Graph"),
                            p("A graphical representation of causal relationships where nodes represent variables and
                              directed edges represent causal effects. The graph may contain cycles representing feedback loops."),
                            p(strong("Example:"), " Education → Income → Health Status")
                        )
                    )
                ),

            )
        )
    ),

    # Graph Visualization Tab
    tabItem(tabName = "dag",
                # Row 1: Interactive Causal Graph Explorer (top)
                fluidRow(
                    box(
                        title = "Interactive Causal Graph Explorer",
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
                                downloadButton("save_html_btn", "Save HTML",
                                             class = "btn-warning btn-sm",
                                             style = "margin-right: 10px; font-weight: bold;",
                                             icon = icon("file-text"),
                                             title = "Convert JSON to readable HTML report"),
                                span(id = "network_stats",
                                     style = "font-size: 12px; color: #666; margin-left: 10px;",
                                     textOutput("network_stats_text", inline = TRUE))
                            )
                        ),

                        hr(),

                        # Physics controls and color coding
                        fluidRow(
                            column(8,
                                create_network_controls_ui()
                            ),
                            column(4,
                                div(style = "padding: 10px; background-color: #f8f9fa; border-radius: 4px;",
                                    h5(style = "margin-top: 0; font-size: 14px;", icon("palette"), " Node Colors:"),
                                    tags$div(style = "font-size: 12px;",
                                        tags$span(style = "color: #FF6B6B; font-weight: bold;", "● Red"), " = Exposure | ",
                                        tags$span(style = "color: #4ECDC4; font-weight: bold;", "● Cyan"), " = Outcome | ",
                                        tags$span(style = "color: #95A5A6; font-weight: bold;", "● Gray"), " = Other"
                                    )
                                )
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
                                div(style = "background-color: #e8f4f8; padding: 10px; border-radius: 5px; margin-bottom: 15px;",
                                    h5(style = "margin-top: 0;", icon("info-circle"), " What are Adjustment Sets?"),
                                    p(style = "margin-bottom: 0;",
                                      strong("Definition:"), " A set of variables that, when controlled for (adjusted), blocks all confounding paths between exposure and outcome, allowing unbiased estimation of the causal effect.")
                                ),
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
                                div(style = "background-color: #fff8e1; padding: 10px; border-radius: 5px; margin-bottom: 15px;",
                                    h5(style = "margin-top: 0;", icon("info-circle"), " What are Instrumental Variables?"),
                                    p(style = "margin-bottom: 0;",
                                      strong("Definition:"), " A variable that (1) affects the exposure, (2) does not directly affect the outcome except through the exposure, and (3) is not associated with confounders.")
                                ),
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
                            h4(icon("info-circle"), " Welcome to CKT - Causal Knowledge Trace"),
                            p("The application is now running at localhost and ready to use! To get started, please select or upload a graph file below."),
                            p(strong("No graph file is currently loaded."), " Once you load a graph, you'll be able to explore it in the Graph Visualization tab.")
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
                                           class = "btn-primary", style = "margin-top: 5px; width: 100%;")
                            )
                        ),

                        # Graph filtering options
                        fluidRow(
                            column(12,
                                div(style = "margin-top: 15px; margin-bottom: 15px; padding: 15px; background-color: #f8f9fa; border-radius: 5px; border-left: 4px solid #28a745;",
                                    h4(icon("filter"), " Graph Filtering Options"),

                                    # Radio buttons for filter type
                                    radioButtons("filter_type",
                                                label = "Select filtering method:",
                                                choices = list(
                                                    "No filtering - Load original graph" = "none",
                                                    "Remove leaf nodes only (degree = 1)" = "leaf"
                                                ),
                                                selected = "none"),

                                    # Description for each option
                                    conditionalPanel(
                                        condition = "input.filter_type == 'leaf'",
                                        div(style = "margin-left: 25px; padding: 10px; background-color: #fff3cd; border-radius: 5px;",
                                            icon("info-circle"),
                                            strong(" Leaf Removal:"),
                                            p("Iteratively removes nodes with only one connection (degree = 1). Exposure and outcome nodes are preserved.")
                                        )
                                    )
                                )
                            )
                        ),

                        # Progress indication section (visibility controlled by JavaScript)
                        fluidRow(
                            column(12,
                                div(id = "loading_section", style = "margin: 20px 0; display: none;",
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

                                    tags$li("Degree parameter"),
                                    tags$li("SemMedDB version selection")
                                )
                            )
                        )
                    )
                }
            )
)