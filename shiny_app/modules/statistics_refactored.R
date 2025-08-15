# Statistics Module (Refactored)
# 
# This module contains statistical analysis functions, calculations, and reporting functionality
# for DAG visualization and analysis. It sources the refactored analysis components.
#
# Author: Refactored from original statistics.R
# Date: February 2025

# Source refactored analysis components
source("analysis/graph_statistics.R")
source("analysis/cycle_detection.R")

#' Statistics Module UI
#'
#' Creates the user interface for the statistics module
#'
#' @param id Character string. The namespace identifier for the module
#' @return Shiny UI elements for statistics display
#' @export
statisticsModuleUI <- function(id) {
    ns <- NS(id)
    
    tagList(
        fluidRow(
            column(6,
                box(
                    title = "Graph Overview",
                    status = "primary",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "300px",
                    
                    verbatimTextOutput(ns("basic_stats"))
                )
            ),
            column(6,
                box(
                    title = "Node Distribution",
                    status = "info",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "300px",
                    
                    verbatimTextOutput(ns("node_distribution"))
                )
            )
        ),
        
        fluidRow(
            column(6,
                box(
                    title = "Connectivity Analysis",
                    status = "warning",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "350px",
                    
                    verbatimTextOutput(ns("connectivity_report"))
                )
            ),
            column(6,
                box(
                    title = "DAG Validation",
                    status = "success",
                    solidHeader = TRUE,
                    width = NULL,
                    height = "350px",
                    
                    verbatimTextOutput(ns("cycle_report"))
                )
            )
        ),
        
        fluidRow(
            box(
                title = "Detailed Statistics",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                collapsed = TRUE,
                
                tabsetPanel(
                    tabPanel("Node Degrees",
                        br(),
                        DT::dataTableOutput(ns("node_degrees_table"))
                    ),
                    tabPanel("Full Report",
                        br(),
                        verbatimTextOutput(ns("full_report"))
                    ),
                    tabPanel("Export Data",
                        br(),
                        fluidRow(
                            column(4,
                                downloadButton(ns("download_stats"), 
                                             "Download Statistics",
                                             icon = icon("download"),
                                             class = "btn-primary")
                            ),
                            column(4,
                                downloadButton(ns("download_report"), 
                                             "Download Report",
                                             icon = icon("file-text"),
                                             class = "btn-info")
                            ),
                            column(4,
                                downloadButton(ns("download_cycles"), 
                                             "Download Cycle Analysis",
                                             icon = icon("exclamation-triangle"),
                                             class = "btn-warning")
                            )
                        )
                    )
                )
            )
        )
    )
}

#' Statistics Module Server
#'
#' Server logic for the statistics module
#'
#' @param id Character string. The namespace identifier for the module
#' @param nodes_reactive Reactive expression returning nodes data frame
#' @param edges_reactive Reactive expression returning edges data frame
#' @param dag_reactive Reactive expression returning DAG object (optional)
#' @return NULL (side effects only)
#' @export
statisticsModuleServer <- function(id, nodes_reactive, edges_reactive, dag_reactive = NULL) {
    moduleServer(id, function(input, output, session) {
        
        # Basic statistics output
        output$basic_stats <- renderText({
            nodes_df <- nodes_reactive()
            edges_df <- edges_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return("No graph data available")
            }
            
            summary_stats <- generate_summary_stats(nodes_df, edges_df)
            
            paste0(
                "Graph Summary\n",
                "=============\n",
                "Nodes: ", summary_stats$nodes, "\n",
                "Edges: ", summary_stats$edges, "\n",
                "Density: ", summary_stats$density, "\n",
                "Average Degree: ", summary_stats$avg_degree, "\n",
                "Node Types: ", summary_stats$node_types, "\n",
                "Largest Group: ", summary_stats$largest_group, 
                " (", summary_stats$largest_group_size, " nodes)"
            )
        })
        
        # Node distribution output
        output$node_distribution <- renderText({
            nodes_df <- nodes_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return("No node data available")
            }
            
            distribution <- analyze_node_distribution(nodes_df)
            
            if (nrow(distribution) == 0) {
                return("No node distribution data")
            }
            
            report <- "Node Distribution\n=================\n"
            for (i in 1:nrow(distribution)) {
                report <- paste0(report, distribution$group[i], ": ", 
                               distribution$count[i], " (", distribution$percentage[i], "%)\n")
            }
            
            return(report)
        })
        
        # Connectivity analysis output
        output$connectivity_report <- renderText({
            nodes_df <- nodes_reactive()
            edges_df <- edges_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return("No graph data available")
            }
            
            generate_connectivity_report(nodes_df, edges_df)
        })
        
        # Cycle detection output
        output$cycle_report <- renderText({
            nodes_df <- nodes_reactive()
            edges_df <- edges_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return("No graph data available")
            }
            
            generate_cycle_report(nodes_df, edges_df)
        })
        
        # Node degrees table
        output$node_degrees_table <- DT::renderDataTable({
            nodes_df <- nodes_reactive()
            edges_df <- edges_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return(data.frame(Message = "No data available"))
            }
            
            degrees <- calculate_node_degrees(nodes_df, edges_df)
            
            # Add node labels and groups if available
            if ("label" %in% names(nodes_df)) {
                degrees$label <- nodes_df$label[match(degrees$node_id, nodes_df$id)]
            }
            if ("group" %in% names(nodes_df)) {
                degrees$group <- nodes_df$group[match(degrees$node_id, nodes_df$id)]
            }
            
            degrees
        }, options = list(pageLength = 10, scrollX = TRUE))
        
        # Full report output
        output$full_report <- renderText({
            nodes_df <- nodes_reactive()
            edges_df <- edges_reactive()
            
            if (is.null(nodes_df) || nrow(nodes_df) == 0) {
                return("No graph data available")
            }
            
            generate_dag_report(nodes_df, edges_df, "Shiny Application")
        })
        
        # Download handlers
        output$download_stats <- downloadHandler(
            filename = function() {
                paste0("graph_statistics_", Sys.Date(), ".csv")
            },
            content = function(file) {
                nodes_df <- nodes_reactive()
                edges_df <- edges_reactive()
                
                if (!is.null(nodes_df) && nrow(nodes_df) > 0) {
                    degrees <- calculate_node_degrees(nodes_df, edges_df)
                    write.csv(degrees, file, row.names = FALSE)
                } else {
                    write.csv(data.frame(Message = "No data available"), file, row.names = FALSE)
                }
            }
        )
        
        output$download_report <- downloadHandler(
            filename = function() {
                paste0("graph_report_", Sys.Date(), ".txt")
            },
            content = function(file) {
                nodes_df <- nodes_reactive()
                edges_df <- edges_reactive()
                
                if (!is.null(nodes_df) && nrow(nodes_df) > 0) {
                    report <- generate_dag_report(nodes_df, edges_df, "Shiny Application")
                    writeLines(report, file)
                } else {
                    writeLines("No graph data available", file)
                }
            }
        )
        
        output$download_cycles <- downloadHandler(
            filename = function() {
                paste0("cycle_analysis_", Sys.Date(), ".txt")
            },
            content = function(file) {
                nodes_df <- nodes_reactive()
                edges_df <- edges_reactive()
                
                if (!is.null(nodes_df) && nrow(nodes_df) > 0) {
                    cycle_report <- generate_cycle_report(nodes_df, edges_df)
                    writeLines(cycle_report, file)
                } else {
                    writeLines("No graph data available", file)
                }
            }
        )
    })
}
