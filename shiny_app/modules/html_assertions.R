# HTML Assertions Module
# This module provides assertion-rendering functions for HTML reports
# Author: Refactored from json_to_html.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Create Fast Assertions Section
#'
#' Efficiently build assertions section with streamlined format
#'
#' @param assertions Assertions data
#' @param pmid_sentences PMID sentences data
#' @param progress_callback Optional function to report progress
#' @return HTML string for assertions section
#' @export
create_fast_assertions_section <- function(assertions, pmid_sentences = NULL, progress_callback = NULL) {
    if (is.null(assertions) || length(assertions) == 0) {
        return("<div class='section'><h2>🔗 Causal Assertions</h2><p>No causal assertions available.</p></div>")
    }

    cat("Converting", length(assertions), "assertions to streamlined format...\n")

    # Start section
    section_parts <- c("<div class='section'><h2>🔗 Causal Assertions</h2>")

    total_assertions <- length(assertions)

    if (!is.null(progress_callback)) {
        progress_callback(paste("⬇️ Processing", total_assertions, "assertions..."))
    }

    # Process each assertion efficiently
    for (i in seq_along(assertions)) {
        assertion <- assertions[[i]]

        # Extract fields with correct names from JSON structure
        subject <- assertion$subj %||% "Unknown"
        object <- assertion$obj %||% "Unknown"
        predicate <- assertion$predicate %||% "Unknown"
        subject_cui <- assertion$subj_cui %||% "Not available"
        object_cui <- assertion$obj_cui %||% "Not available"
        pmid_refs <- assertion$pmid_refs %||% c()

        # Build streamlined assertion header with clear labels including predicate
        assertion_header <- paste0(
            "<div class='streamlined-assertion'>",
            "<div class='streamlined-header sticky-relation-header'>",
            "<span class='label-text'>Subject:</span> <strong>", subject, "</strong> ",
            "<span class='label-text'>Subject CUI:</span> <strong>", subject_cui, "</strong> → ",
            "<span class='label-text predicate-text'>", predicate, "</span> → ",
            "<span class='label-text'>Object:</span> <strong>", object, "</strong> ",
            "<span class='label-text'>Object CUI:</span> <strong>", object_cui, "</strong>",
            "</div>"
        )

        # Build PMID entries with sentences
        pmid_entries_html <- ""
        if (length(pmid_refs) > 0 && !is.null(pmid_sentences)) {
            for (pmid in pmid_refs) {
                # Get sentences for this PMID
                sentences <- pmid_sentences[[pmid]]

                # Handle different sentence formats
                if (is.list(sentences) && !is.null(sentences$sentences)) {
                    sentence_list <- sentences$sentences
                } else if (is.character(sentences)) {
                    sentence_list <- sentences
                } else {
                    sentence_list <- c("No sentences available")
                }

                # Build PMID entry with sentences on same line
                pmid_link <- paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-link'>", pmid, "</a>")
                sentences_text <- paste(sentence_list, collapse = " ")

                # Escape HTML characters and ensure proper formatting
                sentences_text <- gsub("&", "&amp;", sentences_text)
                sentences_text <- gsub("<", "&lt;", sentences_text)
                sentences_text <- gsub(">", "&gt;", sentences_text)

                pmid_entry <- paste0(
                    "<div class='pmid-sentence-line'>",
                    "<span class='pmid-part'>", pmid_link, ":</span> ",
                    "<span class='sentence-part'>", sentences_text, "</span>",
                    "</div>"
                )

                pmid_entries_html <- paste0(pmid_entries_html, pmid_entry)
            }
        } else if (length(pmid_refs) > 0) {
            # Show PMIDs without sentences if sentences not available
            for (pmid in pmid_refs) {
                pmid_link <- paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-link'>", pmid, "</a>")
                pmid_entry <- paste0(
                    "<div class='pmid-sentence-line'>",
                    "<span class='pmid-part'>", pmid_link, ":</span> ",
                    "<span class='sentence-part'>No sentences available</span>",
                    "</div>"
                )
                pmid_entries_html <- paste0(pmid_entries_html, pmid_entry)
            }
        }

        # Complete assertion entry
        assertion_entry <- paste0(
            assertion_header,
            pmid_entries_html,
            "</div>"
        )

        section_parts <- c(section_parts, assertion_entry)

        # Update progress every 10% or every 100 assertions (whichever is smaller)
        update_interval <- max(1, floor(total_assertions / 10))
        if (i %% update_interval == 0 && !is.null(progress_callback)) {
            progress_pct <- round((i / total_assertions) * 100)
            progress_callback(paste("⬇️ Downloading HTML file:", progress_pct, "%"))
        }
    }

    # Close section
    section_parts <- c(section_parts, "</div>")

    return(paste(section_parts, collapse = "\n"))
}

#' Create Simple Assertions Section
#'
#' @param assertions List of assertions
#' @return HTML string for assertions
#' @export
create_simple_assertions_section <- function(assertions) {
    if (is.null(assertions) || length(assertions) == 0) {
        return("<div class='section'><h2>🔗 Causal Assertions</h2><p>No causal assertions available.</p></div>")
    }

    section_html <- paste0(
        "<div class='section'>",
        "<h2>🔗 Causal Assertions (", length(assertions), ")</h2>"
    )

    # Process each assertion
    for (i in 1:length(assertions)) {
        assertion <- assertions[[i]]

        # Extract fields with correct names from JSON structure
        subject <- assertion$subj %||% "Unknown"
        object <- assertion$obj %||% "Unknown"
        predicate <- assertion$predicate %||% "Unknown"
        subject_cui <- assertion$subj_cui %||% "Not available"
        object_cui <- assertion$obj_cui %||% "Not available"
        evidence_count <- assertion$ev_count %||% 0
        pmid_refs <- assertion$pmid_refs %||% c()

        section_html <- paste0(section_html,
            "<div class='assertion'>",
            "<div class='assertion-title sticky-relation-header'>",
            "Assertion #", i, ": <strong>", subject, "</strong> (", subject_cui, ") → ",
            "<span class='predicate-text'>", predicate, "</span> → ",
            "<strong>", object, "</strong> (", object_cui, ")",
            "</div>",
            "<div class='assertion-details'>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Subject</div>",
            "<div class='detail-value'>", subject, "</div>",
            "</div>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Predicate</div>",
            "<div class='detail-value'>", predicate, "</div>",
            "</div>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Object</div>",
            "<div class='detail-value'>", object, "</div>",
            "</div>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Subject CUI</div>",
            "<div class='detail-value'>", subject_cui, "</div>",
            "</div>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Object CUI</div>",
            "<div class='detail-value'>", object_cui, "</div>",
            "</div>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Evidence Count</div>",
            "<div class='detail-value'>", evidence_count, " publication", if(evidence_count != 1) "s" else "", " (ev_count: ", evidence_count, ")</div>",
            "</div>",
            "</div>"
        )

        # Add evidence section if PMIDs are available
        if (length(pmid_refs) > 0) {
            section_html <- paste0(section_html,
                "<div class='evidence-section'>",
                "<div class='evidence-title'>📚 Supporting Evidence</div>",
                "<div class='pmid-list'>"
            )

            for (pmid in pmid_refs) {
                section_html <- paste0(section_html,
                    "<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-tag'>",
                    pmid, "</a>"
                )
            }

            section_html <- paste0(section_html, "</div></div>")
        }

        section_html <- paste0(section_html, "</div>")
    }

    section_html <- paste0(section_html, "</div>")
    return(section_html)
}

#' Create Assertions Section with Chunked Processing
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @param chunk_size Number of assertions per chunk
#' @return HTML assertions string
#' @export
create_assertions_section <- function(assertions, pmid_sentences, chunk_size = 1000) {
    total_assertions <- length(assertions)

    if (total_assertions == 0) {
        return("<div class='loading'><h3>No assertions to display</h3></div>")
    }

    # Group assertions by predicate for better organization
    assertions_by_predicate <- list()
    for (assertion in assertions) {
        pred <- assertion$predicate %||% "Unknown"
        if (is.null(assertions_by_predicate[[pred]])) {
            assertions_by_predicate[[pred]] <- list()
        }
        assertions_by_predicate[[pred]][[length(assertions_by_predicate[[pred]]) + 1]] <- assertion
    }

    # Sort predicates by frequency
    predicate_counts <- sapply(assertions_by_predicate, length)
    sorted_predicates <- names(sort(predicate_counts, decreasing = TRUE))

    assertions_html <- "<div class='assertions-section'><h2>📋 Causal Assertions</h2>"

    # Process each predicate group
    for (pred in sorted_predicates) {
        pred_assertions <- assertions_by_predicate[[pred]]
        pred_id <- gsub("[^A-Za-z0-9]", "_", pred)

        assertions_html <- paste0(assertions_html,
            "<h3 id='pred_", pred_id, "' style='color: #007bff; margin-top: 40px; padding-top: 20px; border-top: 2px solid #e9ecef;'>",
            "🔗 ", pred, " (", length(pred_assertions), " assertions)</h3>"
        )

        # Process assertions in chunks within each predicate
        num_chunks <- ceiling(length(pred_assertions) / chunk_size)

        for (chunk_idx in 1:num_chunks) {
            start_idx <- (chunk_idx - 1) * chunk_size + 1
            end_idx <- min(chunk_idx * chunk_size, length(pred_assertions))
            chunk_assertions <- pred_assertions[start_idx:end_idx]

            if (num_chunks > 1) {
                assertions_html <- paste0(assertions_html,
                    "<div class='chunk-separator'>",
                    "Assertions ", start_idx, "-", end_idx, " of ", length(pred_assertions),
                    "</div>"
                )
            }

            # Process each assertion in the chunk
            for (i in 1:length(chunk_assertions)) {
                assertion <- chunk_assertions[[i]]
                assertion_html <- create_single_assertion_html(assertion, pmid_sentences, start_idx + i - 1)
                assertions_html <- paste0(assertions_html, assertion_html)
            }
        }
    }

    assertions_html <- paste0(assertions_html, "</div>")
    return(assertions_html)
}

#' Create HTML for Single Assertion
#'
#' @param assertion Single assertion object
#' @param pmid_sentences List of PMID sentences
#' @param index Assertion index for display
#' @return HTML string for single assertion
#' @export
create_single_assertion_html <- function(assertion, pmid_sentences, index) {
    # Extract assertion details using correct field names from JSON
    subject <- assertion$subj %||% "Unknown"
    object <- assertion$obj %||% "Unknown"
    predicate <- assertion$predicate %||% "Unknown"
    subject_cui <- assertion$subj_cui %||% "Not available"
    object_cui <- assertion$obj_cui %||% "Not available"

    # Create assertion header with sticky functionality and predicate
    assertion_html <- paste0(
        "<div class='assertion'>",
        "<div class='assertion-header sticky-relation-header'>",
        "Assertion #", index, ": <strong>", subject, "</strong> (", subject_cui, ") → ",
        "<span class='predicate-text'>", predicate, "</span> → ",
        "<strong>", object, "</strong> (", object_cui, ")",
        "</div>",
        "<div class='assertion-content'>"
    )

    # Add metadata
    assertion_html <- paste0(assertion_html,
        "<div class='assertion-meta'>",
        "<div class='meta-item'>",
        "<div class='meta-label'>Subject</div>",
        "<div class='meta-value'>", subject, "</div>",
        "</div>",
        "<div class='meta-item'>",
        "<div class='meta-label'>Predicate</div>",
        "<div class='meta-value'>", predicate, "</div>",
        "</div>",
        "<div class='meta-item'>",
        "<div class='meta-label'>Object</div>",
        "<div class='meta-value'>", object, "</div>",
        "</div>"
    )

    # Add additional metadata if available
    if (!is.null(assertion$subject_cui)) {
        assertion_html <- paste0(assertion_html,
            "<div class='meta-item'>",
            "<div class='meta-label'>Subject CUI</div>",
            "<div class='meta-value'>", assertion$subject_cui, "</div>",
            "</div>"
        )
    }

    if (!is.null(assertion$object_cui)) {
        assertion_html <- paste0(assertion_html,
            "<div class='meta-item'>",
            "<div class='meta-label'>Object CUI</div>",
            "<div class='meta-value'>", assertion$object_cui, "</div>",
            "</div>"
        )
    }

    assertion_html <- paste0(assertion_html, "</div>")

    # Add sentences if available
    if (!is.null(assertion$pmids) && length(assertion$pmids) > 0) {
        assertion_html <- paste0(assertion_html,
            "<div class='sentences'>",
            "<h4>📄 Supporting Evidence (", length(assertion$pmids), " publications)</h4>"
        )

        # Process each PMID
        for (pmid in assertion$pmids) {
            if (!is.null(pmid_sentences[[as.character(pmid)]])) {
                pmid_data <- pmid_sentences[[as.character(pmid)]]

                # Add sentences for this PMID
                if (!is.null(pmid_data$sentences) && length(pmid_data$sentences) > 0) {
                    for (sentence in pmid_data$sentences) {
                        assertion_html <- paste0(assertion_html,
                            "<div class='sentence'>",
                            "<div class='sentence-text'>\"", sentence, "\"</div>",
                            "<div class='sentence-meta'>",
                            "Source: <a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-link'>PMID:", pmid, "</a>"
                        )

                        # Add publication year if available
                        if (!is.null(pmid_data$year)) {
                            assertion_html <- paste0(assertion_html, " (", pmid_data$year, ")")
                        }

                        assertion_html <- paste0(assertion_html, "</div></div>")
                    }
                }
            }
        }

        assertion_html <- paste0(assertion_html, "</div>")
    }

    assertion_html <- paste0(assertion_html, "</div></div>")
    return(assertion_html)
}

#' Create Compact HTML for Single Assertion (Memory Optimized)
#'
#' @param assertion Single assertion object
#' @param pmid_sentences List of PMID sentences
#' @param index Assertion index for display
#' @return Compact HTML string for single assertion
#' @export
create_compact_assertion_html <- function(assertion, pmid_sentences, index) {
    # Extract assertion details using correct field names from JSON
    subject <- assertion$subj %||% "Unknown"
    object <- assertion$obj %||% "Unknown"
    predicate <- assertion$predicate %||% "Unknown"
    subject_cui <- assertion$subj_cui %||% "Not available"
    object_cui <- assertion$obj_cui %||% "Not available"

    # Create more compact assertion display with sticky header and predicate
    assertion_html <- paste0(
        "<div class='assertion' style='margin-bottom: 15px;'>",
        "<div class='assertion-header sticky-relation-header' style='padding: 10px;'>",
        "<strong>", subject, "</strong> (", subject_cui, ") → ",
        "<span class='predicate-text'>", predicate, "</span> → ",
        "<strong>", object, "</strong> (", object_cui, ")",
        "</div>"
    )

    # Add evidence count and sample if available
    if (!is.null(assertion$pmids) && length(assertion$pmids) > 0) {
        evidence_count <- length(assertion$pmids)
        assertion_html <- paste0(assertion_html,
            "<div class='assertion-content' style='padding: 15px;'>",
            "<div style='background-color: #f8f9fa; padding: 10px; border-radius: 5px;'>",
            "<strong>📄 Evidence:</strong> ", evidence_count, " publication(s) | ",
            "<strong>PMIDs:</strong> "
        )

        # Show first few PMIDs as links
        pmid_links <- c()
        for (i in 1:min(5, length(assertion$pmids))) {
            pmid <- assertion$pmids[i]
            pmid_links <- c(pmid_links,
                paste0("<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid,
                      "' target='_blank' class='pmid-link'>", pmid, "</a>"))
        }

        assertion_html <- paste0(assertion_html, paste(pmid_links, collapse = ", "))

        if (length(assertion$pmids) > 5) {
            assertion_html <- paste0(assertion_html, " and ", length(assertion$pmids) - 5, " more")
        }

        assertion_html <- paste0(assertion_html, "</div></div>")
    }

    assertion_html <- paste0(assertion_html, "</div>")
    return(assertion_html)
}

#' Create Optimized Assertions Section with Better Memory Management
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @param max_per_section Maximum assertions per predicate section
#' @return HTML assertions string
#' @export
create_optimized_assertions_section <- function(assertions, pmid_sentences, max_per_section = 2000) {
    total_assertions <- length(assertions)

    if (total_assertions == 0) {
        return("<div class='loading'><h3>No assertions to display</h3></div>")
    }

    # Group assertions by predicate
    assertions_by_predicate <- list()
    for (assertion in assertions) {
        pred <- assertion$predicate %||% "Unknown"
        if (is.null(assertions_by_predicate[[pred]])) {
            assertions_by_predicate[[pred]] <- list()
        }
        assertions_by_predicate[[pred]][[length(assertions_by_predicate[[pred]]) + 1]] <- assertion
    }

    # Sort predicates by frequency
    predicate_counts <- sapply(assertions_by_predicate, length)
    sorted_predicates <- names(sort(predicate_counts, decreasing = TRUE))

    assertions_html <- "<div class='assertions-section'><h2>📋 Causal Assertions by Relationship Type</h2>"

    # Process each predicate group with memory optimization
    for (pred_idx in 1:length(sorted_predicates)) {
        pred <- sorted_predicates[pred_idx]
        pred_assertions <- assertions_by_predicate[[pred]]
        pred_count <- length(pred_assertions)
        pred_id <- gsub("[^A-Za-z0-9]", "_", pred)

        # Add predicate header with progress indicator
        assertions_html <- paste0(assertions_html,
            "<h3 id='pred_", pred_id, "' style='color: #007bff; margin-top: 40px; padding-top: 20px; ",
            "border-top: 2px solid #e9ecef;'>",
            "🔗 ", pred, " <span style='color: #666; font-size: 0.8em;'>(",
            format(pred_count, big.mark = ","), " assertions - ",
            round((pred_count / total_assertions) * 100, 1), "%)</span></h3>"
        )

        # Handle large sections by limiting display
        if (pred_count > max_per_section) {
            assertions_html <- paste0(assertions_html,
                "<div class='large-section-warning' style='background-color: #e7f3ff; border: 1px solid #b3d9ff; ",
                "border-radius: 5px; padding: 15px; margin-bottom: 20px;'>",
                "<p><strong>⚠️ Large Section:</strong> This section contains ",
                format(pred_count, big.mark = ","), " assertions. ",
                "Showing first ", format(max_per_section, big.mark = ","), " for performance. ",
                "Use search function to find specific content.</p>",
                "</div>"
            )

            # Limit to max_per_section for display
            pred_assertions <- pred_assertions[1:max_per_section]
        }

        # Process assertions in smaller chunks for memory efficiency
        chunk_size <- min(100, length(pred_assertions))
        num_chunks <- ceiling(length(pred_assertions) / chunk_size)

        for (chunk_idx in 1:num_chunks) {
            start_idx <- (chunk_idx - 1) * chunk_size + 1
            end_idx <- min(chunk_idx * chunk_size, length(pred_assertions))
            chunk_assertions <- pred_assertions[start_idx:end_idx]

            # Process each assertion in the chunk
            for (i in 1:length(chunk_assertions)) {
                assertion <- chunk_assertions[[i]]
                global_idx <- (pred_idx - 1) * 1000 + start_idx + i - 1  # Approximate global index
                assertion_html <- create_compact_assertion_html(assertion, pmid_sentences, global_idx)
                assertions_html <- paste0(assertions_html, assertion_html)
            }

            # Add memory cleanup hint for large chunks
            if (chunk_idx %% 10 == 0 && num_chunks > 10) {
                assertions_html <- paste0(assertions_html,
                    "<!-- Chunk ", chunk_idx, " of ", num_chunks, " completed -->\n"
                )
            }
        }
    }

    assertions_html <- paste0(assertions_html, "</div>")
    return(assertions_html)
}

