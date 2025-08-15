# Graph Configuration UI Module
# 
# This module contains the user interface components for the graph configuration functionality.
# It includes form inputs, progress indicators, and validation feedback displays.
#
# Author: Refactored from graph_config_module.R
# Date: February 2025

#' Graph Configuration UI Function
#' 
#' Creates the user interface for knowledge graph parameter configuration
#' 
#' @param id Character string. The namespace identifier for the module
#' @return Shiny UI elements for graph configuration
#' @export
graphConfigModuleUI <- function(id) {
    ns <- NS(id)
    
    tagList(
        # Add JavaScript for progress handling
        tags$script(HTML(paste0("
            // Progress bar control functions for graph configuration
            function showGraphProgressSection_", id, "() {
                $('#", ns("graph_progress_section"), "').show();
            }
            
            function hideGraphProgressSection_", id, "() {
                $('#", ns("graph_progress_section"), "').hide();
            }
            
            function updateGraphProgress_", id, "(data) {
                $('#", ns("graph_progress"), "').css('width', data.percent + '%');
                $('#", ns("progress_text"), "').text(data.text);
                $('#", ns("progress_status"), "').text('Status: ' + data.status);
            }
        "))),
        
        # Configuration Form
        fluidRow(
            box(
                title = "Graph Configuration Parameters",
                status = "primary",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                
                fluidRow(
                    column(6,
                        h4("Exposure Configuration"),
                        textAreaInput(ns("exposure_cuis"), 
                                    "Exposure CUIs (one per line):",
                                    value = "",
                                    height = "120px",
                                    placeholder = "Enter CUIs, one per line:\nC0011849\nC0020538"),
                        
                        textInput(ns("exposure_name"), 
                                "Exposure Name:",
                                value = "",
                                placeholder = "e.g., Diabetes_Hypertension")
                    ),
                    column(6,
                        h4("Outcome Configuration"),
                        textAreaInput(ns("outcome_cuis"), 
                                    "Outcome CUIs (one per line):",
                                    value = "",
                                    height = "120px",
                                    placeholder = "Enter CUIs, one per line:\nC0002395\nC0011265"),
                        
                        textInput(ns("outcome_name"), 
                                "Outcome Name:",
                                value = "",
                                placeholder = "e.g., Alzheimers_Dementia")
                    )
                ),
                
                hr(),
                
                fluidRow(
                    column(4,
                        h4("Analysis Parameters"),
                        numericInput(ns("min_pmids"), 
                                   "Minimum PMIDs:",
                                   value = 50,
                                   min = 1,
                                   max = 1000,
                                   step = 1),
                        
                        numericInput(ns("pub_year_cutoff"), 
                                   "Publication Year Cutoff:",
                                   value = 2000,
                                   min = 1990,
                                   max = 2025,
                                   step = 1)
                    ),
                    column(4,
                        h4("Graph Parameters"),
                        selectInput(ns("k_hops"), 
                                  "K-Hops:",
                                  choices = list("1" = 1, "2" = 2, "3" = 3),
                                  selected = 3),
                        
                        selectInput(ns("SemMedDBD_version"), 
                                  "SemMedDB Version:",
                                  choices = list(
                                      "VER43_R" = "VER43_R",
                                      "VER42_R" = "VER42_R",
                                      "VER41_R" = "VER41_R"
                                  ),
                                  selected = "VER43_R")
                    ),
                    column(4,
                        h4("Predication Types"),
                        checkboxGroupInput(ns("predication_types"),
                                         "Select Predication Types:",
                                         choices = list(
                                             "CAUSES" = "CAUSES",
                                             "TREATS" = "TREATS", 
                                             "PREVENTS" = "PREVENTS",
                                             "AFFECTS" = "AFFECTS",
                                             "ASSOCIATED_WITH" = "ASSOCIATED_WITH",
                                             "PREDISPOSES" = "PREDISPOSES"
                                         ),
                                         selected = "CAUSES"),
                        
                        textInput(ns("custom_predication"), 
                                "Custom Predication Types:",
                                placeholder = "INTERACTS_WITH,AUGMENTS")
                    )
                ),
                
                hr(),
                
                fluidRow(
                    column(12,
                        div(style = "text-align: center;",
                            actionButton(ns("create_graph"), 
                                       "Create Knowledge Graph",
                                       icon = icon("play"),
                                       class = "btn-success btn-lg",
                                       style = "margin: 10px;")
                        )
                    )
                )
            )
        ),
        
        # Progress Section
        fluidRow(
            div(id = ns("graph_progress_section"), 
                style = "display: none;",
                box(
                    title = "Graph Creation Progress",
                    status = "info",
                    solidHeader = TRUE,
                    width = 12,
                    
                    div(class = "progress progress-striped active",
                        div(id = ns("graph_progress"), 
                            class = "progress-bar progress-bar-info",
                            role = "progressbar",
                            style = "width: 0%")
                    ),
                    p(id = ns("progress_text"), "Initializing..."),
                    p(id = ns("progress_status"), "Status: Ready")
                )
            )
        ),
        
        # Validation Feedback
        fluidRow(
            box(
                title = "Configuration Status",
                status = "warning",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                collapsed = TRUE,
                
                uiOutput(ns("validation_feedback"))
            )
        ),
        
        # Results Section
        fluidRow(
            box(
                title = "Graph Creation Results",
                status = "success",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                collapsed = TRUE,
                
                verbatimTextOutput(ns("creation_results")),
                
                conditionalPanel(
                    condition = paste0("output['", ns("has_results"), "']"),
                    
                    hr(),
                    h4("Generated Files:"),
                    verbatimTextOutput(ns("generated_files")),
                    
                    br(),
                    div(style = "text-align: center;",
                        downloadButton(ns("download_config"), 
                                     "Download Configuration",
                                     icon = icon("download"),
                                     class = "btn-info"),
                        
                        actionButton(ns("load_created_graph"), 
                                   "Load Created Graph",
                                   icon = icon("upload"),
                                   class = "btn-primary",
                                   style = "margin-left: 10px;")
                    )
                )
            )
        ),
        
        # Help Section
        fluidRow(
            box(
                title = "Configuration Help",
                status = "info",
                solidHeader = TRUE,
                width = 12,
                collapsible = TRUE,
                collapsed = TRUE,
                
                h4("Parameter Descriptions:"),
                tags$ul(
                    tags$li(strong("Exposure CUIs:"), "Concept Unique Identifiers for exposure variables (one per line)"),
                    tags$li(strong("Outcome CUIs:"), "Concept Unique Identifiers for outcome variables (one per line)"),
                    tags$li(strong("Minimum PMIDs:"), "Minimum number of PubMed articles required for relationships"),
                    tags$li(strong("Publication Year Cutoff:"), "Only include articles published after this year"),
                    tags$li(strong("K-Hops:"), "Maximum relationship depth to include in the graph (1-3)"),
                    tags$li(strong("SemMedDB Version:"), "Version of the SemMedDB database to use"),
                    tags$li(strong("Predication Types:"), "Types of relationships to include in the graph")
                ),
                
                h4("Example CUIs:"),
                tags$ul(
                    tags$li("C0011849 - Diabetes Mellitus"),
                    tags$li("C0020538 - Hypertension"),
                    tags$li("C0002395 - Alzheimer's Disease"),
                    tags$li("C0011265 - Dementia")
                ),
                
                h4("Tips:"),
                tags$ul(
                    tags$li("Start with a small number of CUIs to test the configuration"),
                    tags$li("Higher minimum PMIDs will result in more reliable but fewer relationships"),
                    tags$li("K-Hops of 2-3 usually provide good balance between completeness and complexity"),
                    tags$li("Multiple predication types can capture different types of relationships")
                )
            )
        )
    )
}
