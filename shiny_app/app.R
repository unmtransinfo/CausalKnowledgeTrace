# Load required libraries
library(shiny)
library(shinydashboard)
library(visNetwork)
library(dplyr)
library(DT)

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
            menuItem("DAG Visualization", tabName = "dag", icon = icon("project-diagram")),
            menuItem("Node Information", tabName = "info", icon = icon("info-circle")),
            menuItem("Statistics", tabName = "stats", icon = icon("chart-bar")),
            menuItem("Data Upload", tabName = "upload", icon = icon("upload")),
            menuItem("Graph Configuration", tabName = "create_graph", icon = icon("cogs"))
        )
    ),
    
    dashboardBody(
        tags$head(
            tags$style(HTML("
                .content-wrapper, .right-side {
                    background-color: #f4f4f4;
                }
                .box {
                    border-radius: 5px;
                }
            ")),
            tags$script(HTML("
                function openCreateGraph() {
                    // Navigate to the Graph Configuration tab
                    $('a[data-value=\"create_graph\"]').click();
                }
            "))
        ),
        
        tabItems(
            # DAG Visualization Tab
            tabItem(tabName = "dag",
                fluidRow(
                    box(
                        title = "Interactive DAG Network", 
                        status = "primary", 
                        solidHeader = TRUE,
                        width = 12,
                        height = "900px",
                        visNetworkOutput("network", height = "800px")
                    )
                ),
                fluidRow(
                    box(
                        title = "Network Controls",
                        status = "info",
                        solidHeader = TRUE,
                        width = 6,
                        create_network_controls_ui(),
                        br(),
                        # Add Graph Parameters button
                        actionButton("graph_params_btn",
                                   "Create Graph",
                                   class = "btn-info btn-block",
                                   icon = icon("cogs"),
                                   onclick = "openCreateGraph()")
                    ),
                    box(
                        title = "Legend",
                        status = "success",
                        solidHeader = TRUE,
                        width = 6,
                        htmlOutput("legend_html")
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
                                tags$li("Create an R file (e.g., 'SemDAG.R', 'MarkovBlanket_Union.R') with your DAG definition"),
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
                                    tags$li("Minimum PMIDs threshold"),
                                    tags$li("Publication year cutoff"),
                                    tags$li("Squelch threshold"),
                                    tags$li("K-hops parameter"),
                                    tags$li("SemMedDB version selection")
                                )
                            )
                        )
                    )
                }
            )
        )
    ),

    # Add custom JavaScript for progress indication
    tags$script(HTML("
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
    "))
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
            showNotification("File list refreshed", type = "success")
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

                showNotification(paste("Successfully loaded graph from", input$dag_file_selector), type = "success")
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

        showNotification(paste("File", new_filename, "uploaded successfully to graph_creation/result"), type = "success")
        
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

                showNotification(paste("Successfully uploaded and loaded graph from", new_filename), type = "success")
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
                showNotification("DAG data reloaded successfully!", type = "success")
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

    # Graph Parameters button handler
    observeEvent(input$graph_params_btn, {
        # Show notification about navigation
        showNotification(
            "Navigating to Graph Configuration tab...",
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
    
    # Remove the example_structure output since it's no longer needed
}

# Create and return the Shiny application object
# This works both when sourced directly and when called by runApp()
shinyApp(ui = ui, server = server)