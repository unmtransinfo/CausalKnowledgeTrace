# Load required libraries
library(shiny)
library(shinydashboard)
library(visNetwork)
library(dplyr)
library(DT)

# Try to load DAG data from external file
tryCatch({
    source("dag_data.R")
    cat("Successfully loaded DAG data from dag_data.R\n")
}, error = function(e) {
    cat("Could not load dag_data.R, using default data structure\n")
    # Fallback: create minimal data structure
    dag_nodes <- data.frame(
        id = c("Node1", "Node2", "Node3"),
        label = c("Node 1", "Node 2", "Node 3"),
        group = c("Primary", "Other", "Other"),
        color = c("#FF6B6B", "#A9B7C0", "#A9B7C0"),
        font.size = 16,
        font.color = "black",
        stringsAsFactors = FALSE
    )
    
    dag_edges <- data.frame(
        from = c("Node1", "Node2"),
        to = c("Node2", "Node3"),
        arrows = "to",
        smooth = TRUE,
        width = 1.5,
        color = "#2F4F4F80",
        stringsAsFactors = FALSE
    )
    
    dag_object <- NULL
})

# Function to validate and process loaded data
validate_dag_data <- function(nodes, edges) {
    # Validate nodes
    required_node_cols <- c("id", "label", "group", "color")
    missing_node_cols <- setdiff(required_node_cols, names(nodes))
    
    if (length(missing_node_cols) > 0) {
        warning(paste("Missing node columns:", paste(missing_node_cols, collapse = ", ")))
        # Add missing columns with defaults
        if (!"id" %in% names(nodes)) stop("Node 'id' column is required")
        if (!"label" %in% names(nodes)) nodes$label <- nodes$id
        if (!"group" %in% names(nodes)) nodes$group <- "Other"
        if (!"color" %in% names(nodes)) nodes$color <- "#A9B7C0"
    }
    
    # Add optional columns if missing
    if (!"font.size" %in% names(nodes)) nodes$font.size <- 16
    if (!"font.color" %in% names(nodes)) nodes$font.color <- "black"
    
    # Validate edges
    if (nrow(edges) > 0) {
        required_edge_cols <- c("from", "to")
        missing_edge_cols <- setdiff(required_edge_cols, names(edges))
        
        if (length(missing_edge_cols) > 0) {
            warning(paste("Missing edge columns:", paste(missing_edge_cols, collapse = ", ")))
            if (!"from" %in% names(edges) | !"to" %in% names(edges)) {
                stop("Edge 'from' and 'to' columns are required")
            }
        }
        
        # Add optional edge columns if missing
        if (!"arrows" %in% names(edges)) edges$arrows <- "to"
        if (!"smooth" %in% names(edges)) edges$smooth <- TRUE
        if (!"width" %in% names(edges)) edges$width <- 1.5
        if (!"color" %in% names(edges)) edges$color <- "#2F4F4F80"
    }
    
    return(list(nodes = nodes, edges = edges))
}

# Validate the loaded data
validated_data <- validate_dag_data(dag_nodes, dag_edges)
dag_nodes <- validated_data$nodes
dag_edges <- validated_data$edges

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
            menuItem("Data Upload", tabName = "upload", icon = icon("upload"))
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
                        sliderInput("physics_strength", "Physics Strength:", 
                                   min = -500, max = -50, value = -150, step = 25),
                        sliderInput("spring_length", "Spring Length:", 
                                   min = 100, max = 400, value = 200, step = 25),
                        actionButton("reset_physics", "Reset Physics", class = "btn-warning"),
                        br(), br(),
                        actionButton("reload_data", "Reload DAG Data", class = "btn-success")
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
            source("dag_data.R", local = TRUE)
            if (exists("available_dag_files")) {
                current_data$available_files <- available_dag_files
                choices <- available_dag_files
                if (length(choices) == 0) {
                    choices <- "No DAG files found"
                }
                updateSelectInput(session, "dag_file_selector", choices = choices)
                showNotification("File list refreshed", type = "success")
            }
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
            source("dag_data.R", local = TRUE)
            if (exists("load_dag_from_file")) {
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
            source("dag_data.R", local = TRUE)
            if (exists("scan_for_dag_files")) {
                current_data$available_files <- scan_for_dag_files()
                choices <- current_data$available_files
                if (length(choices) == 0) {
                    choices <- "No DAG files found"
                }
                updateSelectInput(session, "dag_file_selector", choices = choices, selected = new_filename)
            }
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
            source("dag_data.R", local = TRUE)
            if (exists("load_dag_from_file")) {
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
            }
        }, error = function(e) {
            showNotification(paste("Error loading uploaded DAG:", e$message), type = "error")
        })
    })
    
    # Function to generate legend HTML
    generate_legend <- function(nodes_df) {
        unique_groups <- unique(nodes_df$group)
        group_info <- nodes_df %>%
            group_by(group) %>%
            summarise(color = first(color), count = n(), .groups = 'drop')
        
        legend_html <- "<div style='margin: 10px;'>"
        for (i in 1:nrow(group_info)) {
            legend_html <- paste0(legend_html,
                "<div style='margin-bottom: 10px;'>",
                "<span style='background-color: ", group_info$color[i], 
                "; padding: 5px 10px; border-radius: 3px; color: white; margin-right: 10px;'>",
                group_info$group[i], "</span>",
                "(", group_info$count[i], " nodes)",
                "</div>"
            )
        }
        legend_html <- paste0(legend_html, "</div>")
        return(legend_html)
    }
    
    # Generate legend HTML
    output$legend_html <- renderUI({
        HTML(generate_legend(current_data$nodes))
    })
    
    # Reload data function
    reload_dag_data <- function() {
        tryCatch({
            source("dag_data.R", local = TRUE)
            if (exists("dag_nodes") && exists("dag_edges")) {
                # Validate the reloaded data
                validated_data <- validate_dag_data(dag_nodes, dag_edges)
                current_data$nodes <- validated_data$nodes
                current_data$edges <- validated_data$edges
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
    
    # Render the network
    output$network <- renderVisNetwork({
        visNetwork(current_data$nodes, current_data$edges, width = "100%", height = "100%") %>%
            visPhysics(
                solver = "forceAtlas2Based",
                forceAtlas2Based = list(
                    gravitationalConstant = input$physics_strength,
                    centralGravity = 0.01,
                    springLength = input$spring_length,
                    springConstant = 0.08,
                    damping = 0.4,
                    avoidOverlap = 1
                )
            ) %>%
            visOptions(
                highlightNearest = list(enabled = TRUE, degree = 1),
                nodesIdSelection = TRUE
            ) %>%
            visNodes(
                shadow = TRUE,
                font = list(size = 20, strokeWidth = 2)
            ) %>%
            visEdges(
                smooth = list(enabled = TRUE, type = "curvedCW")
            )
    })
    
    # Reset physics button
    observeEvent(input$reset_physics, {
        updateSliderInput(session, "physics_strength", value = -150)
        updateSliderInput(session, "spring_length", value = 200)
    })
    
    # Node information output
    output$node_info <- renderText({
        if (is.null(input$network_selected)) {
            "Click on a node to see its information."
        } else {
            selected_node <- current_data$nodes[current_data$nodes$id == input$network_selected, ]
            if (nrow(selected_node) > 0) {
                paste0(
                    "Selected Node: ", selected_node$label, "\n",
                    "ID: ", selected_node$id, "\n",
                    "Group: ", selected_node$group, "\n",
                    "Color: ", selected_node$color
                )
            } else {
                "Node information not available."
            }
        }
    })
    
    # Nodes table
    output$nodes_table <- DT::renderDataTable({
        current_data$nodes[, c("id", "label", "group")]
    }, options = list(pageLength = 15))
    
    # Value boxes
    output$total_nodes <- renderValueBox({
        valueBox(
            value = nrow(current_data$nodes),
            subtitle = "Total Nodes",
            icon = icon("circle"),
            color = "blue"
        )
    })
    
    output$total_edges <- renderValueBox({
        valueBox(
            value = nrow(current_data$edges),
            subtitle = "Total Edges",
            icon = icon("arrow-right"),
            color = "green"
        )
    })
    
    output$total_groups <- renderValueBox({
        valueBox(
            value = length(unique(current_data$nodes$group)),
            subtitle = "Node Groups",
            icon = icon("tags"),
            color = "purple"
        )
    })
    
    # Node distribution plot
    output$node_distribution <- renderPlot({
        group_counts <- table(current_data$nodes$group)
        colors <- current_data$nodes %>%
            group_by(group) %>%
            summarise(color = first(color), .groups = 'drop') %>%
            arrange(match(group, names(group_counts)))
        
        barplot(group_counts, 
                main = "Node Distribution by Group",
                xlab = "Group",
                ylab = "Count",
                col = colors$color,
                las = 2)
    })
    
    # DAG information
    output$dag_info <- renderText({
        primary_nodes <- current_data$nodes[current_data$nodes$group == "Primary", ]
        paste0(
            "DAG Structure Information:\n\n",
            "- Total Variables: ", nrow(current_data$nodes), "\n",
            "- Total Relationships: ", nrow(current_data$edges), "\n",
            "- Node Groups: ", length(unique(current_data$nodes$group)), "\n",
            "- Primary Variables: ", if(nrow(primary_nodes) > 0) paste(primary_nodes$label, collapse = ", ") else "None", "\n",
            "- Graph Type: Directed Acyclic Graph (DAG)\n",
            "- Visualization: Interactive Network\n",
            "- Data Source: ", current_data$current_file
        )
    })
    
    # Remove the example_structure output since it's no longer needed
}

# Run the application
shinyApp(ui = ui, server = server)