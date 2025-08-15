# Causal Analysis Module
# 
# This module contains causal analysis functionality for the Causal Web Shiny application.
# It includes adjustment set identification, instrumental variable analysis, and path analysis.
#
# Author: Refactored from app.R
# Date: February 2025

#' Create Causal Analysis Server Logic
#' 
#' Creates server logic for causal analysis including adjustment sets and instrumental variables
#' 
#' @param input Shiny input object
#' @param output Shiny output object  
#' @param session Shiny session object
#' @param current_data Reactive values object containing current application state
#' @return NULL (side effects only)
create_causal_analysis_server <- function(input, output, session, current_data) {
    
    # Run complete causal analysis
    observeEvent(input$run_causal_analysis, {
        # Validate inputs
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }
        
        if (is.null(input$causal_exposure) || input$causal_exposure == "No DAG loaded") {
            showNotification("Please select an exposure variable", type = "error")
            return()
        }
        
        if (is.null(input$causal_outcome) || input$causal_outcome == "No DAG loaded") {
            showNotification("Please select an outcome variable", type = "error")
            return()
        }
        
        if (input$causal_exposure == input$causal_outcome) {
            showNotification("Exposure and outcome variables must be different", type = "error")
            return()
        }
        
        # Show progress
        shinyjs::show("causal_progress")
        
        # Run comprehensive causal analysis
        summary_result <- run_comprehensive_causal_analysis(
            dag = current_data$dag_object,
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
    
    # Individual adjustment set analysis
    observeEvent(input$run_adjustment_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }
        
        if (is.null(input$causal_exposure) || input$causal_exposure == "No DAG loaded") {
            showNotification("Please select an exposure variable", type = "error")
            return()
        }
        
        if (is.null(input$causal_outcome) || input$causal_outcome == "No DAG loaded") {
            showNotification("Please select an outcome variable", type = "error")
            return()
        }
        
        tryCatch({
            result <- get_adjustment_sets(
                dag = current_data$dag_object,
                exposure = input$causal_exposure,
                outcome = input$causal_outcome
            )
            
            output$adjustment_sets_result <- renderText({
                format_adjustment_sets_display(result)
            })
            
            showNotification("Adjustment set analysis complete", type = "message")
        }, error = function(e) {
            showNotification(paste("Error in adjustment set analysis:", e$message), type = "error")
        })
    })
    
    # Individual instrumental variable analysis
    observeEvent(input$run_instrumental_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }
        
        if (is.null(input$causal_exposure) || input$causal_exposure == "No DAG loaded") {
            showNotification("Please select an exposure variable", type = "error")
            return()
        }
        
        if (is.null(input$causal_outcome) || input$causal_outcome == "No DAG loaded") {
            showNotification("Please select an outcome variable", type = "error")
            return()
        }
        
        tryCatch({
            result <- get_instrumental_variables(
                dag = current_data$dag_object,
                exposure = input$causal_exposure,
                outcome = input$causal_outcome
            )
            
            output$instrumental_vars_result <- renderText({
                if (!result$success) {
                    return(paste("Error:", result$message))
                }
                
                if (result$count == 0) {
                    return("No instrumental variables found")
                } else {
                    return(paste0(
                        "Instrumental Variables: ",
                        paste(result$instruments, collapse = ", ")
                    ))
                }
            })
            
            showNotification("Instrumental variable analysis complete", type = "message")
        }, error = function(e) {
            showNotification(paste("Error in instrumental variable analysis:", e$message), type = "error")
        })
    })
    
    # Individual path analysis
    observeEvent(input$run_path_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "error")
            return()
        }
        
        if (is.null(input$causal_exposure) || input$causal_exposure == "No DAG loaded") {
            showNotification("Please select an exposure variable", type = "error")
            return()
        }
        
        if (is.null(input$causal_outcome) || input$causal_outcome == "No DAG loaded") {
            showNotification("Please select an outcome variable", type = "error")
            return()
        }
        
        tryCatch({
            result <- analyze_causal_paths(
                dag = current_data$dag_object,
                exposure = input$causal_exposure,
                outcome = input$causal_outcome
            )
            
            output$causal_paths_result <- renderText({
                if (!result$success) {
                    return(paste("Error:", result$message))
                }
                
                if (result$total_paths == 0) {
                    return("No causal paths found")
                } else {
                    return(paste0(
                        "Found ", result$total_paths, " causal paths\n",
                        "See detailed analysis above"
                    ))
                }
            })
            
            showNotification("Path analysis complete", type = "message")
        }, error = function(e) {
            showNotification(paste("Error in path analysis:", e$message), type = "error")
        })
    })
}
