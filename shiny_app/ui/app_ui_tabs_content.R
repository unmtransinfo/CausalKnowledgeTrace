# Tab Items Content
# This file contains all tab content for the application
# Author: Extracted from app.R UI section

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
                                                    "Remove leaf nodes only (degree = 1)" = "leaf",
                                                    "Keep only paths between exposure and outcome" = "path"
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
                                    ),

                                    conditionalPanel(
                                        condition = "input.filter_type == 'path'",
                                        div(style = "margin-left: 25px; padding: 10px; background-color: #d1ecf1; border-radius: 5px;",
                                            icon("info-circle"),
                                            strong(" Path-Based Filtering + Leaf Removal:"),
                                            p("Keeps only nodes on directed paths connecting exposure and outcome. This includes:"),
                                            tags$ul(
                                                tags$li("Forward paths: exposure → ... → outcome"),
                                                tags$li("Reverse paths: outcome → ... → exposure"),
                                                tags$li("Common descendants: node → both exposure AND outcome"),
                                                tags$li("Common ancestors: both exposure AND outcome → node")
                                            ),
                                            p(strong("Then removes leaf nodes"), " (degree = 1) from the filtered graph."),
                                            p("This creates the most focused graph showing only well-connected bidirectional causal relationships.")
                                        )
                                    )
                                )
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

                                    tags$li("Degree parameter"),
                                    tags$li("SemMedDB version selection")
                                )
                            )
                        )
                    )
                }
            )
)