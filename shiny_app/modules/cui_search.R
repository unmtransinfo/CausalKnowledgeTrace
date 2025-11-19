# CUI Search Module for CausalKnowledgeTrace
# 
# This module provides server-side functions for CUI search functionality
# including debounced search, result formatting, and selection management.
#
# Author: CausalKnowledgeTrace Application
# Dependencies: shiny, DT, database_connection

# Required libraries
if (!require(shiny, quietly = TRUE)) {
    install.packages("shiny")
    library(shiny)
}

if (!require(DT, quietly = TRUE)) {
    install.packages("DT")
    library(DT)
}

if (!require(htmltools, quietly = TRUE)) {
    install.packages("htmltools")
    library(htmltools)
}

# Source database connection module
source("modules/database_connection.R", local = TRUE)

#' CUI Search UI Module
#'
#' Creates the user interface for CUI search functionality
#'
#' @param id Character string. The namespace identifier for the module
#' @param label Character string. Label for the search input
#' @param placeholder Character string. Placeholder text for the search input
#' @param height Character string. Height of the results container
#' @param initial_value Character string. Initial value for the selected CUIs text area
#' @return Shiny UI elements for CUI search
#' @export
cuiSearchUI <- function(id, label = "Search Medical Concepts",
                       placeholder = "Type to search for medical concepts...",
                       height = "250px",
                       initial_value = NULL) {
    ns <- NS(id)
    
    tagList(
        div(class = "cui-search-container",
            # Search input
            div(class = "form-group",
                tags$label(label, class = "control-label"),
                textInput(
                    ns("search_input"),
                    label = NULL,
                    placeholder = paste(placeholder, "(Press Enter to search)"),
                    width = "100%"
                ),
                # Add JavaScript to handle Enter key press
                tags$script(HTML(paste0("
                    $(document).on('keypress', '#", ns("search_input"), "', function(e) {
                        if(e.which == 13) {
                            Shiny.setInputValue('", ns("search_trigger"), "', Math.random());
                        }
                    });
                "))),
                helpText("Type at least 3 characters and press Enter to search. Click on results to select CUIs.")
            ),
            
            # Search results container
            div(id = ns("results_container"),
                style = paste("max-height:", height, "; overflow-y: auto; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 10px;"),
                
                # Loading indicator
                div(id = ns("loading_indicator"), 
                    style = "display: none; padding: 20px; text-align: center;",
                    icon("spinner", class = "fa-spin"),
                    " Searching..."
                ),
                
                # Results table
                DT::dataTableOutput(ns("search_results"), height = "auto")
            ),
            
            # Selected CUIs display
            div(class = "form-group",
                tags$label("Selected CUIs:", class = "control-label"),
                textAreaInput(
                    ns("selected_cuis"),
                    label = NULL,
                    value = if (!is.null(initial_value)) initial_value else "",
                    placeholder = "Selected CUI codes will appear here (comma-separated)",
                    rows = 3,
                    width = "100%"
                ),
                helpText("You can also manually enter CUI codes here (format: C followed by 7 digits).")
            ),
            
            # Action button
            div(style = "margin-top: 10px;",
                actionButton(ns("clear_selection"), "Clear Selection",
                           class = "btn-warning btn-sm")
            )
        ),
        
        # Custom CSS for styling
        tags$style(HTML(paste0("
            .cui-search-container .dataTables_wrapper {
                margin: 0;
            }
            .cui-search-container .dataTables_length,
            .cui-search-container .dataTables_filter,
            .cui-search-container .dataTables_info,
            .cui-search-container .dataTables_paginate {
                display: none;
            }
            .cui-search-container table.dataTable tbody tr {
                cursor: pointer;
            }
            .cui-search-container table.dataTable tbody tr:hover {
                background-color: #f5f5f5;
            }
            .cui-search-container table.dataTable tbody tr.selected {
                background-color: #d9edf7;
            }
            #", ns("results_container"), " {
                background-color: #fafafa;
            }
        ")))
    )
}

#' CUI Search Server Module
#'
#' Server logic for CUI search functionality
#'
#' @param id Character string. The namespace identifier for the module
#' @param initial_cuis Character vector. Initial CUI codes to populate
#' @param search_type Character string. Type of search: "exposure" (subject_search) or "outcome" (object_search)
#' @return Reactive values containing selected CUIs
#' @export
cuiSearchServer <- function(id, initial_cuis = NULL, search_type = "exposure") {
    moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Reactive values for managing state
        values <- reactiveValues(
            search_results = data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_definition = character(0)),
            selected_cuis = character(0),
            last_search = ""
        )

        # Initialize with initial CUIs if provided
        # Parse the initial CUIs and set them in reactive values
        if (!is.null(initial_cuis) && length(initial_cuis) > 0) {
            # Convert to vector if it's a string
            if (is.character(initial_cuis) && length(initial_cuis) == 1) {
                # Split comma-separated string
                parsed_cuis <- trimws(unlist(strsplit(initial_cuis, ",")))
                parsed_cuis <- parsed_cuis[parsed_cuis != ""]
            } else {
                parsed_cuis <- initial_cuis
            }

            # Set the reactive values immediately
            values$selected_cuis <- parsed_cuis
        }

        # Search triggered by Enter key press only
        observeEvent(input$search_trigger, {
            search_term <- trimws(input$search_input)

            # Only search if term is at least 3 characters and different from last search
            if (nchar(search_term) >= 3 && search_term != values$last_search) {
                values$last_search <- search_term
                cat("🔍 Search triggered by Enter key for term:", search_term, "| Type:", search_type, "\n")

                # Show loading indicator
                shinyjs::show("loading_indicator")

                # Perform search (no limit - show all results) with search type
                search_result <- search_cui_entities(search_term, search_type = search_type)

                if (search_result$success) {
                    values$search_results <- search_result$results
                } else {
                    values$search_results <- data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_definition = character(0))
                    showNotification(
                        paste("Search error:", search_result$message),
                        type = "error",
                        duration = 5
                    )
                }

                # Hide loading indicator
                shinyjs::hide("loading_indicator")

            } else if (nchar(search_term) < 3) {
                values$search_results <- data.frame(cui = character(0), name = character(0), semtype = character(0), semtype_definition = character(0))
                values$last_search <- ""
            }
        })
        
        # Render search results table
        output$search_results <- DT::renderDataTable({
            if (nrow(values$search_results) == 0) {
                return(data.frame())
            }

            # Format results for display and reorder columns: CUI, Name, Definition, Type
            display_data <- values$search_results[, c("cui", "name", "semtype_definition", "semtype")]
            display_data$cui <- paste0('<code>', display_data$cui, '</code>')
            display_data$name <- htmltools::htmlEscape(display_data$name)
            display_data$semtype_definition <- htmltools::htmlEscape(display_data$semtype_definition)
            display_data$semtype <- htmltools::htmlEscape(display_data$semtype)

            DT::datatable(
                display_data,
                selection = 'single',
                escape = FALSE,
                options = list(
                    pageLength = -1,  # Show ALL rows (no pagination limit)
                    scrollY = "200px",  # Compact height for better space usage
                    scrollCollapse = TRUE,
                    dom = 't',  # Only show table
                    columnDefs = list(
                        list(width = '80px', targets = 0),   # CUI column
                        list(width = '200px', targets = 1),  # Name column
                        list(width = '200px', targets = 2),  # Definition column
                        list(width = '80px', targets = 3)    # Type column (moved to last)
                    )
                ),
                colnames = c('CUI', 'Name', 'Definition', 'Type')
            )
        })
        
        # Handle row selection in search results
        observeEvent(input$search_results_rows_selected, {
            if (length(input$search_results_rows_selected) > 0) {
                selected_row <- input$search_results_rows_selected[1]
                selected_cui <- values$search_results$cui[selected_row]
                
                # Add to selected CUIs if not already present
                current_cuis <- values$selected_cuis
                if (!selected_cui %in% current_cuis) {
                    values$selected_cuis <- c(current_cuis, selected_cui)
                    
                    # Update text area
                    cui_string <- paste(values$selected_cuis, collapse = ", ")
                    updateTextAreaInput(session, "selected_cuis", value = cui_string)
                    
                    showNotification(
                        paste("Added CUI:", selected_cui),
                        type = "message",
                        duration = 3
                    )
                } else {
                    showNotification(
                        paste("CUI already selected:", selected_cui),
                        type = "warning",
                        duration = 3
                    )
                }
            }
        })
        
        # Handle manual CUI input changes
        observeEvent(input$selected_cuis, {
            cui_text <- trimws(input$selected_cuis)
            if (cui_text != "") {
                # Parse comma-separated CUIs
                cuis <- trimws(unlist(strsplit(cui_text, ",")))
                cuis <- cuis[cuis != ""]
                values$selected_cuis <- cuis
            } else {
                values$selected_cuis <- character(0)
            }
        })
        
        # Clear selection button
        observeEvent(input$clear_selection, {
            values$selected_cuis <- character(0)
            updateTextAreaInput(session, "selected_cuis", value = "")
            showNotification("Selection cleared", type = "message", duration = 2)
        })
        

        
        # Return reactive values for parent module
        return(reactive({
            list(
                selected_cuis = values$selected_cuis,
                cui_string = paste(values$selected_cuis, collapse = ", "),
                cui_count = length(values$selected_cuis)
            )
        }))
    })
}
