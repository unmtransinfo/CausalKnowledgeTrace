    # ===== EDGE SELECTION EVENT HANDLERS =====

    # Reactive values for storing edge and node selection information
    selection_data <- reactiveValues(
        selected_edge = NULL,
        selected_node = NULL
    )

    # Handle node click for information display
    observeEvent(input$clicked_node_info, {
        if (!is.null(input$clicked_node_info)) {
            selection_data$selected_node <- input$clicked_node_info
            # Clear edge selection when node is selected
            selection_data$selected_edge <- NULL
        } else {
            selection_data$selected_node <- NULL
        }
    })

    # Handle edge selection only
    observeEvent(input$selected_edge_info, {
        if (!is.null(input$selected_edge_info)) {
            # Parse edge ID to extract from and to nodes
            edge_parts <- strsplit(input$selected_edge_info, "_", fixed = TRUE)[[1]]
            if (length(edge_parts) >= 2) {
                # Handle cases where node names might contain underscores
                for (split_point in 1:(length(edge_parts)-1)) {
                    potential_from <- paste(edge_parts[1:split_point], collapse = "_")
                    potential_to <- paste(edge_parts[(split_point+1):length(edge_parts)], collapse = "_")

                    # Check if this combination exists in our edges
                    if (!is.null(current_data$edges) && nrow(current_data$edges) > 0) {
                        edge_exists <- any(current_data$edges$from == potential_from &
                                         current_data$edges$to == potential_to)

                        if (edge_exists) {
                            selection_data$selected_edge <- list(
                                from = potential_from,
                                to = potential_to,
                                id = input$selected_edge_info
                            )
                            # Clear node selection when edge is selected
                            selection_data$selected_node <- NULL
                            break
                        }
                    }
                }
            }
        } else {
            # Clear selection when edge is deselected
            selection_data$selected_edge <- NULL
        }
    })

    # Render selection title (edge or node)
    output$selected_item_title <- renderText({
        if (!is.null(selection_data$selected_node)) {
            paste("Node Information:", selection_data$selected_node)
        } else if (!is.null(selection_data$selected_edge)) {
            paste("Edge Information:", selection_data$selected_edge$from, "→", selection_data$selected_edge$to)
        } else {
            "Click on a node or edge to view information"
        }
    })

    # Render edge or node information table
    output$selection_info_table <- DT::renderDataTable({
        # Handle node selection
        if (!is.null(selection_data$selected_node)) {
            # Get all assertions related to this node
            node_data <- tryCatch({
                find_node_related_assertions(
                    selection_data$selected_node,
                    current_data$causal_assertions,
                    current_data$edges
                )
            }, error = function(e) {
                cat("ERROR in find_node_related_assertions:", e$message, "\n")
                return(list(
                    found = FALSE,
                    message = paste("Error:", e$message),
                    incoming = list(),
                    outgoing = list(),
                    total_count = 0
                ))
            })

            if (node_data$found && node_data$total_count > 0) {
                # Create a table showing all related edges
                edge_rows <- list()

                # Add outgoing edges
                if (length(node_data$outgoing) > 0) {
                    for (assertion in node_data$outgoing) {
                        obj_name <- assertion$object_name %||% assertion$obj
                        predicate <- assertion$predicate %||% "CAUSES"

                        # Extract PMID list from different possible structures
                        pmid_refs <- c()
                        if (!is.null(assertion$pmid_data) && length(assertion$pmid_data) > 0) {
                            pmid_refs <- names(assertion$pmid_data)
                        } else if (!is.null(assertion$pmid_refs)) {
                            pmid_refs <- assertion$pmid_refs
                        } else if (!is.null(assertion$pmid_list)) {
                            pmid_refs <- assertion$pmid_list
                        }

                        pmid_count <- assertion$evidence_count %||% length(pmid_refs)

                        # Format PMID list
                        pmid_display <- if (length(pmid_refs) > 0) {
                            paste(pmid_refs, collapse = ", ")
                        } else {
                            "No PMIDs available"
                        }

                        edge_rows[[length(edge_rows) + 1]] <- data.frame(
                            Direction = "Outgoing →",
                            "From Node" = selection_data$selected_node,
                            Predicate = predicate,
                            "To Node" = obj_name,
                            "PMID Evidence List" = pmid_display,
                            "Evidence Count" = pmid_count,
                            stringsAsFactors = FALSE,
                            check.names = FALSE
                        )
                    }
                }

                # Add incoming edges
                if (length(node_data$incoming) > 0) {
                    for (assertion in node_data$incoming) {
                        subj_name <- assertion$subject_name %||% assertion$subj
                        predicate <- assertion$predicate %||% "CAUSES"

                        # Extract PMID list from different possible structures
                        pmid_refs <- c()
                        if (!is.null(assertion$pmid_data) && length(assertion$pmid_data) > 0) {
                            pmid_refs <- names(assertion$pmid_data)
                        } else if (!is.null(assertion$pmid_refs)) {
                            pmid_refs <- assertion$pmid_refs
                        } else if (!is.null(assertion$pmid_list)) {
                            pmid_refs <- assertion$pmid_list
                        }

                        pmid_count <- assertion$evidence_count %||% length(pmid_refs)

                        # Format PMID list
                        pmid_display <- if (length(pmid_refs) > 0) {
                            paste(pmid_refs, collapse = ", ")
                        } else {
                            "No PMIDs available"
                        }

                        edge_rows[[length(edge_rows) + 1]] <- data.frame(
                            Direction = "Incoming ←",
                            "From Node" = subj_name,
                            Predicate = predicate,
                            "To Node" = selection_data$selected_node,
                            "PMID Evidence List" = pmid_display,
                            "Evidence Count" = pmid_count,
                            stringsAsFactors = FALSE,
                            check.names = FALSE
                        )
                    }
                }

                # Combine all rows
                if (length(edge_rows) > 0) {
                    node_info <- do.call(rbind, edge_rows)
                } else {
                    node_info <- data.frame(
                        Information = "No assertion data found for this node",
                        stringsAsFactors = FALSE
                    )
                }
            } else {
                node_info <- data.frame(
                    Information = paste("No assertions found for node:", selection_data$selected_node),
                    stringsAsFactors = FALSE
                )
            }

            return(node_info)
        } else if (!is.null(selection_data$selected_edge)) {
            # Get PMID data for the selected edge
            pmid_data <- tryCatch({
                find_edge_pmid_data(
                    selection_data$selected_edge$from,
                    selection_data$selected_edge$to,
                    current_data$causal_assertions,
                    current_data$lazy_loader,
                    current_data$edges,  # Pass edges dataframe for CUI-based matching
                    current_data$pmid_sentences  # Pass pmid_sentences for new format
                )
            }, error = function(e) {
                cat("ERROR in find_edge_pmid_data:", e$message, "\n")
                return(list(
                    found = FALSE,
                    message = paste("Error:", e$message),
                    pmid_list = character(0),
                    sentence_data = list(),
                    evidence_count = 0,
                    predicate = "UNKNOWN",  # Changed from hardcoded "CAUSES" to "UNKNOWN" for error cases
                    subject_cui = "",
                    object_cui = ""
                ))
            })

            # Create edge information with individual PMID rows
            if (pmid_data$found && length(pmid_data$pmid_list) > 0) {
                # Create formatted node names with consolidated CUI information
                from_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$from,
                    pmid_data$subject_cui,
                    current_data$consolidated_cui_mappings
                )

                to_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$to,
                    pmid_data$object_cui,
                    current_data$consolidated_cui_mappings
                )

                # Create one row per PMID
                edge_info <- data.frame(
                    "From Node" = rep(from_node_with_cui, length(pmid_data$pmid_list)),
                    "Predicate" = rep(pmid_data$predicate, length(pmid_data$pmid_list)),
                    "To Node" = rep(to_node_with_cui, length(pmid_data$pmid_list)),
                    "PMID" = sapply(pmid_data$pmid_list, function(pmid) {
                        paste0('<a href="https://pubmed.ncbi.nlm.nih.gov/', pmid, '/" target="_blank">', pmid, '</a>')
                    }),
                    "Causal Sentences" = sapply(1:length(pmid_data$pmid_list), function(i) {
                        pmid <- pmid_data$pmid_list[i]
                        # Fix: Access sentence_data safely with error handling
                        sentences <- tryCatch({
                            if (is.list(pmid_data$sentence_data) && !is.null(pmid_data$sentence_data[[pmid]])) {
                                pmid_data$sentence_data[[pmid]]
                            } else {
                                character(0)
                            }
                        }, error = function(e) {
                            cat("ERROR accessing sentence_data for PMID", pmid, ":", e$message, "\n")
                            cat("sentence_data type:", class(pmid_data$sentence_data), "\n")
                            cat("sentence_data length:", length(pmid_data$sentence_data), "\n")
                            character(0)
                        })
                        if (is.null(sentences) || length(sentences) == 0) {
                            return("No sentences available")
                        } else {
                            # Create unique IDs for this PMID's content
                            short_id <- paste0("short_", pmid, "_", i)
                            full_id <- paste0("full_", pmid, "_", i)
                            expand_id <- paste0("expand_", pmid, "_", i)
                            collapse_id <- paste0("collapse_", pmid, "_", i)

                            # Format all sentences
                            all_formatted_sentences <- sapply(sentences, function(s) {
                                if (nchar(s) > 200) {
                                    paste0(substr(s, 1, 197), "...")
                                } else {
                                    s
                                }
                            })

                            # Create short version (first 3 sentences)
                            display_sentences <- all_formatted_sentences[1:min(3, length(all_formatted_sentences))]
                            short_content <- paste(display_sentences, collapse = "<br><br>")

                            # Create full version (all sentences)
                            full_content <- paste(all_formatted_sentences, collapse = "<br><br>")

                            if (length(sentences) > 3) {
                                # Create expandable content
                                result <- paste0(
                                    '<div id="', short_id, '">',
                                    short_content,
                                    '<br><a href="javascript:void(0)" onclick="',
                                    "document.getElementById('", short_id, "').style.display='none'; ",
                                    "document.getElementById('", full_id, "').style.display='block';",
                                    '" style="color: #337ab7; text-decoration: underline; cursor: pointer;">',
                                    '<i>... and ', length(sentences) - 3, ' more sentences (click to expand)</i>',
                                    '</a></div>',
                                    '<div id="', full_id, '" style="display: none;">',
                                    full_content,
                                    '<br><a href="javascript:void(0)" onclick="',
                                    "document.getElementById('", full_id, "').style.display='none'; ",
                                    "document.getElementById('", short_id, "').style.display='block';",
                                    '" style="color: #337ab7; text-decoration: underline; cursor: pointer;">',
                                    '<i>(click to collapse)</i>',
                                    '</a></div>'
                                )
                            } else {
                                result <- short_content
                            }
                            return(result)
                        }
                    }),
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                )
            } else {
                # Create formatted node names with consolidated CUI information
                from_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$from,
                    pmid_data$subject_cui,
                    current_data$consolidated_cui_mappings
                )

                to_node_with_cui <- format_node_with_cuis(
                    selection_data$selected_edge$to,
                    pmid_data$object_cui,
                    current_data$consolidated_cui_mappings
                )

                # Show single row with no PMID data message
                edge_info <- data.frame(
                    "From Node" = from_node_with_cui,
                    "Predicate" = if (current_data$assertions_loaded) {
                        pmid_data$predicate %||% "CAUSES"
                    } else {
                        "N/A"
                    },
                    "To Node" = to_node_with_cui,
                    "PMID" = if (current_data$assertions_loaded) {
                        "No PMID data available for this edge"
                    } else {
                        "Causal assertions data not loaded"
                    },
                    "Causal Sentences" = if (current_data$assertions_loaded) {
                        "No sentence data available"
                    } else {
                        "Causal assertions data not loaded"
                    },
                    stringsAsFactors = FALSE,
                    check.names = FALSE
                )
            }

            edge_info
        } else {
            data.frame(
                Information = "Click on a node or edge in the network above to view detailed information",
                stringsAsFactors = FALSE
            )
        }
    }, escape = FALSE, options = list(
        pageLength = 10,
        scrollX = TRUE,
        scrollY = "250px",
        dom = 'frtip',
        autoWidth = FALSE,
        responsive = TRUE,
        columnDefs = list(
            list(className = 'dt-left', targets = '_all'),
            list(width = '15%', targets = 0),  # From Node column
            list(width = '12%', targets = 1),  # Predicate column
            list(width = '15%', targets = 2),  # To Node column
            list(width = '12%', targets = 3),  # PMID column
            list(width = '46%', targets = 4),  # Causal Sentences column (wider for expandable content)
            list(className = 'dt-body-nowrap', targets = c(0, 1, 2, 3))  # Prevent wrapping in first 4 columns
        ),
        scrollCollapse = TRUE,
        paging = TRUE,
        searching = TRUE,
        ordering = TRUE,
        info = TRUE,
        lengthChange = FALSE
    ), rownames = FALSE, class = 'cell-border stripe hover')

    # Graph Parameters button handler
    observeEvent(input$graph_params_btn, {
        # Show notification about navigation
        showNotification(
            "Navigating to Graph Configuration tab...",
            type = "message",
            duration = 2
        )
    })

    # Quick causal analysis navigation
    observeEvent(input$quick_causal_analysis, {
        if (is.null(current_data$dag_object)) {
            showNotification("Please load a DAG first", type = "warning")
            return()
        }

        # Navigate to causal analysis tab
        updateTabItems(session, "sidebar", "causal")
        showNotification(
            "Navigating to Causal Analysis tab...",
            type = "message",
            duration = 2
        )
    })

