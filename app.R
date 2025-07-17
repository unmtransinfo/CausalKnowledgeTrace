# Load required libraries
library(shiny)
library(shinydashboard)
library(visNetwork)
library(dplyr)
library(DT)

# Source modular components
source("dag_visualization.R")
source("node_information.R")
source("statistics.R")
source("data_upload.R")

# Try to source graph configuration module if it exists
tryCatch({
    source("graph_config_module.R")
    graph_config_available <- TRUE
    cat("Graph configuration module loaded successfully\n")
}, error = function(e) {
    graph_config_available <- FALSE
    cat("Graph configuration module not found, creating placeholder\n")
})

# Try to load DAG data from external file
tryCatch({
    source("dag_data.R")
    cat("Successfully loaded DAG data from dag_data.R\n")
}, error = function(e) {
    cat("Could not load dag_data.R, using default data structure\n")
    # Fallback: create minimal data structure using modular functions
    dag_object <- create_fallback_dag()
    network_data <- create_network_data(dag_object)
    dag_nodes <- network_data$nodes
    dag_edges <- network_data$edges
})

# Validate the loaded data using modular functions
dag_nodes <- validate_node_data(dag_nodes)
dag_edges <- validate_edge_data(dag_edges)

# Get unique groups for legend
unique_groups <- unique(dag_nodes$group)
group_colors <- setNames(unique(dag_nodes$color), unique(dag_nodes$group))

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
                        create_network_controls_ui()
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
                        title = "DAG File Management",
                        status = "warning",
                        solidHeader = TRUE,
                        width = 12,
                        
                        # Current DAG status
                        h4("Current DAG Status"),
                        verbatimTextOutput("current_dag_status"),
                        
                        # File selection
                        h4("Load DAG from File"),
                        p("Select a DAG file from the dropdown below:"),
                        
                        fluidRow(
                            column(8,
                                selectInput("dag_file_selector", 
                                           "Choose DAG File:",
                                           choices = NULL,
                                           selected = NULL)
                            ),
                            column(4,
                                br(),
                                actionButton("load_selected_dag", "Load Selected DAG", 
                                           class = "btn-primary", style = "margin-top: 5px;"),
                                br(), br(),
                                actionButton("refresh_file_list", "Refresh File List", 
                                           class = "btn-info", style = "margin-top: 5px;")
                            )
                        ),
                        
                        # File upload
                        h4("Upload New DAG File"),
                        p("Upload a new R file containing your DAG definition:"),
                        
                        fluidRow(
                            column(8,
                                fileInput("dag_file_upload", "Choose R File",
                                         accept = c(".R", ".r"),
                                         multiple = FALSE)
                            ),
                            column(4,
                                br(),
                                actionButton("upload_and_load", "Upload & Load", 
                                           class = "btn-success", style = "margin-top: 5px;")
                            )
                        ),
                        
                        # Instructions
                        h4("Instructions"),
                        tags$div(
                            tags$h5("Method 1: Place files in app directory"),
                            tags$ul(
                                tags$li("Create an R file (e.g., 'graph.R') with your DAG definition"),
                                tags$li("Place it in the same directory as this app"),
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
    )
)

# Define server logic
server <- function(input, output, session) {
    
    # Reactive values to store current data
    current_data <- reactiveValues(
        nodes = dag_nodes,
        edges = dag_edges,
        dag_object = if(exists("dag_object")) dag_object else NULL,
        available_files = if(exists("available_dag_files")) available_dag_files else character(0),
        current_file = if(exists("dag_loaded_from")) dag_loaded_from else "default"
    )

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
        paste0(
            "Currently loaded DAG:\n",
            "- Source: ", current_data$current_file, "\n",
            "- Nodes: ", nrow(current_data$nodes), "\n",
            "- Edges: ", nrow(current_data$edges), "\n",
            "- Categories: ", length(unique(current_data$nodes$group)), "\n",
            "- Available files: ", if(length(current_data$available_files) > 0) 
                paste(current_data$available_files, collapse = ", ") else "None"
        )
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
    
    # Load selected DAG
    observeEvent(input$load_selected_dag, {
        if (is.null(input$dag_file_selector) || input$dag_file_selector == "No DAG files found") {
            showNotification("Please select a valid DAG file", type = "error")
            return()
        }

        tryCatch({
            result <- load_dag_from_file(input$dag_file_selector)
            if (result$success) {
                # Process the loaded DAG
                network_data <- create_network_data(result$dag)
                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- input$dag_file_selector

                showNotification(paste("Successfully loaded DAG from", input$dag_file_selector), type = "success")
            } else {
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Error loading DAG:", e$message), type = "error")
        })
    })
    
    # Handle file upload
    observeEvent(input$dag_file_upload, {
        if (is.null(input$dag_file_upload)) return()
        
        # Get the uploaded file info
        file_info <- input$dag_file_upload
        
        # Copy file to app directory
        new_filename <- file_info$name
        file.copy(file_info$datapath, new_filename, overwrite = TRUE)
        
        showNotification(paste("File", new_filename, "uploaded successfully"), type = "success")
        
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
    
    # Upload and load DAG
    observeEvent(input$upload_and_load, {
        if (is.null(input$dag_file_upload)) {
            showNotification("Please select a file first", type = "error")
            return()
        }
        
        # Get the uploaded file info
        file_info <- input$dag_file_upload
        new_filename <- file_info$name
        
        # Copy file to app directory
        file.copy(file_info$datapath, new_filename, overwrite = TRUE)
        
        # Load the DAG
        tryCatch({
            result <- load_dag_from_file(new_filename)
            if (result$success) {
                # Process the loaded DAG
                network_data <- create_network_data(result$dag)
                current_data$nodes <- network_data$nodes
                current_data$edges <- network_data$edges
                current_data$dag_object <- result$dag
                current_data$current_file <- new_filename

                # Update file list
                current_data$available_files <- scan_for_dag_files()
                choices <- current_data$available_files
                if (length(choices) == 0) {
                    choices <- "No DAG files found"
                }
                updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)

                showNotification(paste("Successfully uploaded and loaded DAG from", new_filename), type = "success")
            } else {
                showNotification(result$message, type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Error loading uploaded DAG:", e$message), type = "error")
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

# Run the application
shinyApp(ui = ui, server = server)