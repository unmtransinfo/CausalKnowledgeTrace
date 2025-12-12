
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

    # Helper function to extract causal assertions for modified DAG
    extract_modified_dag_assertions <- function(edges_data, assertions_data) {
        if (is.null(edges_data) || nrow(edges_data) == 0 || is.null(assertions_data) || length(assertions_data) == 0) {
            return(list(
                pmid_sentences = list(),
                assertions = list()
            ))
        }

        # Initialize optimized structure
        pmid_sentences <- list()
        assertions <- list()

        for (i in seq_len(nrow(edges_data))) {
            edge <- edges_data[i, ]
            from_node <- edge$from
            to_node <- edge$to

            # Find matching assertion in original data
            pmid_data <- find_edge_pmid_data(from_node, to_node, assertions_data, current_data$lazy_loader)

            if (pmid_data$found && length(pmid_data$pmid_list) > 0) {
                # Create assertion entry in optimized format
                assertion_entry <- list(
                    subj = pmid_data$original_subject %||% from_node,
                    subj_cui = pmid_data$subject_cui %||% "",
                    predicate = pmid_data$predicate %||% "CAUSES",
                    obj = pmid_data$original_object %||% to_node,
                    obj_cui = pmid_data$object_cui %||% "",
                    ev_count = pmid_data$evidence_count %||% length(pmid_data$pmid_list),
                    pmid_refs = pmid_data$pmid_list
                )

                # Add sentences to pmid_sentences mapping
                for (pmid in pmid_data$pmid_list) {
                    sentences <- if (!is.null(pmid_data$sentence_data[[pmid]])) {
                        pmid_data$sentence_data[[pmid]]
                    } else {
                        list("Evidence sentence not available")
                    }

                    # Only add if not already present
                    if (is.null(pmid_sentences[[pmid]])) {
                        pmid_sentences[[pmid]] <- sentences
                    }
                }

                assertions[[length(assertions) + 1]] <- assertion_entry
            }
        }

        return(list(
            pmid_sentences = pmid_sentences,
            assertions = assertions
        ))
    }

    # Save DAG functionality - Main save button
    output$save_dag_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

                # Show success notification
                showNotification(
                    paste("DAG saved successfully as", basename(file)),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving DAG:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Save DAG functionality - Small button (same as main)
    output$save_dag_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract base filename without extension
                base_name <- tools::file_path_sans_ext(basename(current_data$current_file))
                paste0("modified_", base_name, "_", Sys.Date(), ".R")
            } else {
                paste0("saved_dag_", Sys.Date(), ".R")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data
                if (is.null(current_data$nodes) || nrow(current_data$nodes) == 0) {
                    stop("No graph data to save")
                }

                # Try to use original DAG object if available and unmodified
                if (!is.null(current_data$dag_object)) {
                    # Use original DAG object
                    dag_code <- as.character(current_data$dag_object)
                    r_script <- paste0("# Exported DAG from ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown source",
                                     "\n# Generated on ", Sys.time(), "\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                } else {
                    # Reconstruct DAG from current network data (for modified graphs)
                    reconstructed_dag <- create_dag_from_network_data(current_data$nodes, current_data$edges)

                    if (is.null(reconstructed_dag)) {
                        stop("Failed to reconstruct DAG from current network data")
                    }

                    dag_code <- as.character(reconstructed_dag)
                    r_script <- paste0("# Modified DAG reconstructed from network visualization\n",
                                     "# Original source: ",
                                     if(!is.null(current_data$current_file)) current_data$current_file else "Unknown",
                                     "\n# Generated on ", Sys.time(), "\n",
                                     "# Note: This DAG was modified through the web interface\n\n",
                                     "library(dagitty)\n\n",
                                     "g <- dagitty('", dag_code, "')")
                }

                writeLines(r_script, file)

                # Show success notification
                showNotification(
                    paste("DAG saved successfully as", basename(file)),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving DAG:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving DAG:", e$message))
            })
        },
        contentType = "text/plain"
    )

    # Save updated causal assertions JSON file
    output$save_json_btn <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract degree from current file or use default
                degree <- current_data$degree %||% 1
                paste0("evidence_from_graph_", degree, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Save updated causal assertions JSON file - Main button (same as save_json_btn)
    output$save_json_main <- downloadHandler(
        filename = function() {
            if (!is.null(current_data$current_file)) {
                # Extract degree from current file or use default
                degree <- current_data$degree %||% 1
                paste0("evidence_from_graph_", degree, ".json")
            } else {
                paste0("evidence_from_graph_1.json")
            }
        },
        content = function(file) {
            tryCatch({
                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Extract assertions for the modified DAG
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Save as JSON with pretty formatting
                jsonlite::write_json(
                    modified_assertions,
                    file,
                    pretty = TRUE,
                    auto_unbox = TRUE
                )

                showNotification(
                    paste("Causal assertions JSON saved successfully with",
                          length(modified_assertions$assertions), "assertions and",
                          length(modified_assertions$pmid_sentences), "unique PMIDs"),
                    type = "message",
                    duration = 3
                )

            }, error = function(e) {
                showNotification(
                    paste("Error saving causal assertions JSON:", e$message),
                    type = "error",
                    duration = 5
                )
                stop(paste("Error saving causal assertions JSON:", e$message))
            })
        },
        contentType = "application/json"
    )

    # Save HTML functionality - Main button
    output$save_html_main <- downloadHandler(
        filename = function() {
            "evidence_from_graph.html"
        },
        content = function(file) {
            tryCatch({
                # Check if download is already in progress
                if (current_data$html_download_in_progress) {
                    showNotification("⬇️ HTML file is already downloading. Please wait for it to complete.",
                                   type = "warning", duration = 5)
                    stop("Download already in progress")
                }

                # Set flag to indicate download is in progress
                current_data$html_download_in_progress <- TRUE

                # Disable both HTML download buttons
                shinyjs::disable("save_html_main")
                shinyjs::disable("save_html_btn")

                on.exit({
                    current_data$html_download_in_progress <- FALSE
                    # Re-enable both HTML download buttons
                    shinyjs::enable("save_html_main")
                    shinyjs::enable("save_html_btn")
                })

                # Create progress bar with download styling
                progress <- shiny::Progress$new()
                on.exit(progress$close(), add = TRUE)
                progress$set(message = "⬇️ Preparing to download HTML file...", value = 0)

                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Progress callback function
                progress_callback <- function(message) {
                    progress$set(value = NULL, message = message)
                }

                # Extract assertions for the modified DAG
                progress_callback("⬇️ Preparing data for download...")
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Convert to HTML using the simplified module with progress callback
                html_content <- convert_json_to_html(
                    modified_assertions,
                    title = "Causal Knowledge Trace - Evidence Report",
                    progress_callback = progress_callback
                )

                # Write HTML to file
                progress_callback("⬇️ Finalizing download...")
                writeLines(html_content, file, useBytes = TRUE)

                # Complete progress
                progress$set(value = 1, message = "✓ HTML file ready for download!")
                showNotification("✓ HTML report generated successfully!", type = "message")

            }, error = function(e) {
                showNotification(paste("Error generating HTML report:", e$message), type = "error")
                stop(paste("Error generating HTML report:", e$message))
            })
        },
        contentType = "text/html"
    )

    # Save HTML functionality - Small button (same as main)
    output$save_html_btn <- downloadHandler(
        filename = function() {
            "evidence_from_graph.html"
        },
        content = function(file) {
            tryCatch({
                # Check if download is already in progress
                if (current_data$html_download_in_progress) {
                    showNotification("⬇️ HTML file is already downloading. Please wait for it to complete.",
                                   type = "warning", duration = 5)
                    stop("Download already in progress")
                }

                # Set flag to indicate download is in progress
                current_data$html_download_in_progress <- TRUE

                # Disable both HTML download buttons
                shinyjs::disable("save_html_main")
                shinyjs::disable("save_html_btn")

                on.exit({
                    current_data$html_download_in_progress <- FALSE
                    # Re-enable both HTML download buttons
                    shinyjs::enable("save_html_main")
                    shinyjs::enable("save_html_btn")
                })

                # Create progress bar with download styling
                progress <- shiny::Progress$new()
                on.exit(progress$close(), add = TRUE)
                progress$set(message = "⬇️ Preparing to download HTML file...", value = 0)

                # Check if we have network data and assertions
                if (is.null(current_data$edges) || nrow(current_data$edges) == 0) {
                    stop("No graph data to save")
                }

                if (is.null(current_data$causal_assertions) || length(current_data$causal_assertions) == 0) {
                    stop("No causal assertions data available")
                }

                # Progress callback function
                progress_callback <- function(message) {
                    progress$set(value = NULL, message = message)
                }

                # Extract assertions for the modified DAG
                progress_callback("⬇️ Preparing data for download...")
                modified_assertions <- extract_modified_dag_assertions(
                    current_data$edges,
                    current_data$causal_assertions
                )

                if (length(modified_assertions$assertions) == 0) {
                    stop("No causal assertions found for the current edges")
                }

                # Convert to HTML using the simplified module with progress callback
                html_content <- convert_json_to_html(
                    modified_assertions,
                    title = "Causal Knowledge Trace - Evidence Report",
                    progress_callback = progress_callback
                )

                # Write HTML to file
                progress_callback("⬇️ Finalizing download...")
                writeLines(html_content, file, useBytes = TRUE)

                # Complete progress
                progress$set(value = 1, message = "✓ HTML file ready for download!")
                showNotification("✓ HTML report generated successfully!", type = "message")

            }, error = function(e) {
                showNotification(paste("Error generating HTML report:", e$message), type = "error")
                stop(paste("Error generating HTML report:", e$message))
            })
        },
        contentType = "text/html"
    )

    # Remove the example_structure output since it's no longer needed
