#' JSON to HTML Conversion Module
#' 
#' This module provides functions to convert JSON causal assertions data
#' to readable HTML reports with proper styling and navigation.
#' Optimized for large datasets with thousands of nodes and edges.

library(jsonlite)
library(htmltools)

#' Convert JSON Causal Assertions to Simple HTML Report
#'
#' Creates a clean, focused HTML report showing PMID sentences and assertions
#' without unnecessary statistics or navigation
#'
#' @param json_data List containing causal assertions data
#' @param title Report title (default: "Causal Evidence Report")
#' @return HTML string
#' @export
convert_json_to_html <- function(json_data, title = "Causal Evidence Report") {

    # Validate input
    if (is.null(json_data) || length(json_data) == 0) {
        return(create_empty_html_report(title))
    }

    # Extract assertions and pmid_sentences with correct field names
    assertions <- json_data$assertions %||% list()
    pmid_sentences <- json_data$pmid_sentences %||% list()

    if (length(assertions) == 0 && length(pmid_sentences) == 0) {
        return(create_empty_html_report(title))
    }

    cat("Converting", length(assertions), "assertions and", length(pmid_sentences), "PMID entries to HTML...\n")

    # Use fast template-based HTML generation
    full_html <- create_fast_html_template(title, pmid_sentences, assertions)

    return(full_html)
}

#' Create Fast HTML Template
#'
#' Pre-built HTML template for faster generation
#'
#' @param title Report title
#' @param pmid_sentences PMID sentences data
#' @param assertions Assertions data
#' @return Complete HTML string
create_fast_html_template <- function(title, pmid_sentences, assertions) {

    # Pre-built HTML template parts
    html_head <- paste0(
        "<!DOCTYPE html>",
        "<html lang='en'>",
        "<head>",
        "<meta charset='UTF-8'>",
        "<meta name='viewport' content='width=device-width, initial-scale=1.0'>",
        "<title>", title, "</title>",
        get_minimal_css_styles(),
        "</head>",
        "<body>",
        "<div class='container'>",
        "<div class='header'><h1>", title, "</h1></div>"
    )

    # Build assertions section efficiently
    assertions_section <- create_fast_assertions_section(assertions, pmid_sentences)

    # Pre-built footer
    html_footer <- paste0(
        "<div class='footer'>",
        "<p><strong>CausalKnowledgeTrace</strong> - Evidence Report</p>",
        "</div>",
        "</div>",
        "</body>",
        "</html>"
    )

    # Combine all parts (streamlined assertions with integrated PMID sentences)
    return(paste(html_head, assertions_section, html_footer, sep = "\n"))
}

#' Create Fast PMID Section
#'
#' Efficiently build PMID section without counts
#'
#' @param pmid_sentences PMID sentences data
#' @return HTML string for PMID section
create_fast_pmid_section <- function(pmid_sentences) {
    if (is.null(pmid_sentences) || length(pmid_sentences) == 0) {
        return("<div class='section'><h2>📄 Publications</h2><p>No publication data available.</p></div>")
    }

    # Start section
    section_parts <- c("<div class='section'><h2>📄 Publications</h2>")

    # Process each PMID efficiently
    for (pmid in names(pmid_sentences)) {
        sentences <- pmid_sentences[[pmid]]

        # Handle different sentence formats
        if (is.list(sentences) && !is.null(sentences$sentences)) {
            sentence_list <- sentences$sentences
        } else if (is.character(sentences)) {
            sentence_list <- sentences
        } else {
            sentence_list <- c("No sentences available")
        }

        # Build sentences HTML properly
        sentences_html <- ""
        for (sentence in sentence_list) {
            sentences_html <- paste0(sentences_html, "<div class='sentence'>", sentence, "</div>")
        }

        # Build PMID entry
        pmid_entry <- paste0(
            "<div class='pmid-entry'>",
            "<div class='pmid-header'>",
            "<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-link'>",
            "PMID: ", pmid, "</a>",
            "</div>",
            sentences_html,
            "</div>"
        )

        section_parts <- c(section_parts, pmid_entry)
    }

    # Close section
    section_parts <- c(section_parts, "</div>")

    return(paste(section_parts, collapse = "\n"))
}

#' Create Fast Assertions Section
#'
#' Efficiently build assertions section
#'
#' @param assertions Assertions data
#' @return HTML string for assertions section
create_fast_assertions_section <- function(assertions, pmid_sentences = NULL) {
    if (is.null(assertions) || length(assertions) == 0) {
        return("<div class='section'><h2>🔗 Causal Assertions</h2><p>No causal assertions available.</p></div>")
    }

    cat("Converting", length(assertions), "assertions to streamlined format...\n")

    # Start section
    section_parts <- c("<div class='section'><h2>🔗 Causal Assertions</h2>")

    # Process each assertion efficiently
    for (i in seq_along(assertions)) {
        assertion <- assertions[[i]]

        # Extract fields with correct names from JSON structure
        subject <- assertion$subj %||% "Unknown"
        object <- assertion$obj %||% "Unknown"
        subject_cui <- assertion$subj_cui %||% "Not available"
        object_cui <- assertion$obj_cui %||% "Not available"
        pmid_refs <- assertion$pmid_refs %||% c()

        # Build streamlined assertion header with clear labels
        assertion_header <- paste0(
            "<div class='streamlined-assertion'>",
            "<div class='streamlined-header'>",
            "<span class='label-text'>Subject:</span> <strong>", subject, "</strong> ",
            "<span class='label-text'>Subject CUI:</span> <strong>", subject_cui, "</strong> → ",
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
    }

    # Close section
    section_parts <- c(section_parts, "</div>")

    return(paste(section_parts, collapse = "\n"))
}

#' Get Minimal CSS Styles
#'
#' Streamlined CSS for faster loading
#'
#' @return CSS style string
get_minimal_css_styles <- function() {
    return("
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; border-bottom: 3px solid #007bff; padding-bottom: 20px; }
        .header h1 { color: #333; margin: 0; font-size: 2.5em; }
        .section { margin-bottom: 40px; }
        .section h2 { color: #007bff; border-bottom: 2px solid #e9ecef; padding-bottom: 10px; margin-bottom: 20px; }
        .pmid-entry { margin-bottom: 25px; padding: 15px; background-color: #f8f9fa; border-left: 4px solid #007bff; border-radius: 5px; }
        .pmid-header { font-weight: bold; margin-bottom: 10px; }
        .pmid-link {
            color: #007bff;
            text-decoration: none;
            padding: 2px 4px;
            margin: 1px;
            border-radius: 3px;
            background-color: #f8f9fa;
            border: 1px solid #dee2e6;
            display: inline-block;
        }
        .pmid-link:hover {
            text-decoration: none;
            background-color: #e9ecef;
            border-color: #adb5bd;
        }
        .sentence { margin: 8px 0; padding: 8px; background-color: white; border-radius: 3px; border-left: 3px solid #28a745; }
        .streamlined-assertion { margin-bottom: 25px; padding: 15px; background-color: #f8f9fa; border-left: 4px solid #007bff; border-radius: 5px; }
        .streamlined-header { font-weight: normal; color: #495057; margin-bottom: 12px; font-size: 1.1em; line-height: 1.4; }
        .label-text { color: #6c757d; font-weight: normal; font-size: 0.9em; }
        .pmid-sentence-line { margin: 8px 0; padding: 10px; background-color: white; border-radius: 3px; border-left: 3px solid #28a745; line-height: 1.5; word-wrap: break-word; overflow-wrap: break-word; }
        .pmid-part { font-weight: bold; }
        .sentence-part { color: #495057; }
        .assertion { margin-bottom: 20px; padding: 15px; background-color: #fff3cd; border-left: 4px solid #ffc107; border-radius: 5px; }
        .assertion-header { font-weight: bold; color: #856404; margin-bottom: 10px; }
        .assertion-details { margin-top: 10px; }
        .detail-item { margin-bottom: 8px; display: flex; align-items: flex-start; }
        .detail-label { font-weight: bold; min-width: 140px; color: #495057; margin-right: 10px; flex-shrink: 0; }
        .detail-value { color: #212529; flex: 1; word-wrap: break-word; }
        .footer { text-align: center; margin-top: 40px; padding-top: 20px; border-top: 2px solid #e9ecef; color: #666; }
    </style>
    ")
}

#' Create Simple CSS Styles for Clean HTML Report
#'
#' @return CSS style string
create_simple_html_styles <- function() {
    css <- "
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f8f9fa;
            color: #333;
        }
        .container {
            max-width: 1000px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 2px solid #007bff;
        }
        .header h1 {
            color: #007bff;
            margin-bottom: 10px;
            font-size: 2.2em;
        }
        .header .info {
            color: #666;
            font-size: 1em;
        }
        .section {
            margin-bottom: 40px;
        }
        .section h2 {
            color: #28a745;
            border-bottom: 1px solid #dee2e6;
            padding-bottom: 10px;
            margin-bottom: 20px;
        }
        .pmid-entry {
            background-color: #f8f9fa;
            border: 1px solid #e9ecef;
            border-radius: 6px;
            padding: 15px;
            margin-bottom: 15px;
        }
        .pmid-header {
            font-weight: bold;
            color: #007bff;
            margin-bottom: 10px;
        }
        .pmid-link {
            color: #007bff;
            text-decoration: none;
            font-weight: bold;
        }
        .pmid-link:hover {
            text-decoration: underline;
        }
        .sentence {
            background-color: white;
            padding: 10px;
            border-left: 3px solid #28a745;
            margin: 8px 0;
            border-radius: 3px;
        }
        .assertion {
            background-color: #fff;
            border: 1px solid #dee2e6;
            border-radius: 6px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .assertion-title {
            font-size: 1.1em;
            font-weight: bold;
            color: #495057;
            margin-bottom: 15px;
            padding: 10px;
            background-color: #e9ecef;
            border-radius: 4px;
        }
        .assertion-details {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 15px;
        }
        .detail-item {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 4px;
            border-left: 3px solid #007bff;
        }
        .detail-label {
            font-weight: bold;
            color: #495057;
            font-size: 0.9em;
            margin-bottom: 5px;
        }
        .detail-value {
            color: #212529;
        }
        .evidence-section {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #dee2e6;
        }
        .evidence-title {
            font-weight: bold;
            color: #28a745;
            margin-bottom: 10px;
        }
        .pmid-list {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
        }
        .pmid-tag {
            background-color: #007bff;
            color: white;
            padding: 4px 8px;
            border-radius: 12px;
            font-size: 0.85em;
            text-decoration: none;
        }
        .pmid-tag:hover {
            background-color: #0056b3;
            color: white;
        }
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #666;
            font-size: 0.9em;
        }
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { padding: 20px; }
            .header h1 { font-size: 1.8em; }
            .assertion-details { grid-template-columns: 1fr; }
            .pmid-list { flex-direction: column; }
        }
    </style>"

    return(css)
}

#' Create Simple Header
#'
#' @param title Report title
#' @param num_assertions Number of assertions
#' @param num_pmids Number of PMIDs
#' @return HTML header string
create_simple_header <- function(title, num_assertions, num_pmids) {
    header <- paste0(
        "<div class='header'>",
        "<h1>", title, "</h1>",
        "</div>"
    )
    return(header)
}

#' Create PMID Sentences Section
#'
#' @param pmid_sentences List of PMID sentences
#' @return HTML string for PMID sentences
create_pmid_sentences_section <- function(pmid_sentences) {
    if (is.null(pmid_sentences) || length(pmid_sentences) == 0) {
        return("<div class='section'><h2>📄 Publications</h2><p>No publication data available.</p></div>")
    }

    section_html <- paste0(
        "<div class='section'>",
        "<h2>📄 Publications</h2>"
    )

    # Process each PMID entry
    pmid_count <- 0
    for (pmid in names(pmid_sentences)) {
        pmid_count <- pmid_count + 1
        sentences <- pmid_sentences[[pmid]]

        # Handle both array of strings and object with sentences array
        if (is.list(sentences) && !is.null(sentences$sentences)) {
            sentence_list <- sentences$sentences
        } else if (is.character(sentences)) {
            sentence_list <- sentences
        } else {
            sentence_list <- c("No sentences available")
        }

        section_html <- paste0(section_html,
            "<div class='pmid-entry'>",
            "<div class='pmid-header'>",
            "<a href='https://pubmed.ncbi.nlm.nih.gov/", pmid, "' target='_blank' class='pmid-link'>",
            "PMID: ", pmid, "</a>",
            "</div>"
        )

        # Add sentences
        for (sentence in sentence_list) {
            section_html <- paste0(section_html,
                "<div class='sentence'>", sentence, "</div>"
            )
        }

        section_html <- paste0(section_html, "</div>")

        # Limit display for very large datasets
        if (pmid_count >= 100) {
            remaining <- length(pmid_sentences) - pmid_count
            if (remaining > 0) {
                section_html <- paste0(section_html,
                    "<div class='pmid-entry' style='text-align: center; font-style: italic; color: #666;'>",
                    "... and ", remaining, " more publications (limited display for performance)",
                    "</div>"
                )
            }
            break
        }
    }

    section_html <- paste0(section_html, "</div>")
    return(section_html)
}

#' Create Simple Assertions Section
#'
#' @param assertions List of assertions
#' @return HTML string for assertions
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
        subject_cui <- assertion$subj_cui %||% "Not available"
        object_cui <- assertion$obj_cui %||% "Not available"
        evidence_count <- assertion$ev_count %||% 0
        pmid_refs <- assertion$pmid_refs %||% c()

        section_html <- paste0(section_html,
            "<div class='assertion'>",
            "<div class='assertion-title'>",
            "Assertion #", i, ": ", subject, " → ", object,
            "</div>",
            "<div class='assertion-details'>",
            "<div class='detail-item'>",
            "<div class='detail-label'>Subject</div>",
            "<div class='detail-value'>", subject, "</div>",
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

#' Create Simple Footer
#'
#' @return HTML footer string
create_simple_footer <- function() {
    footer <- paste0(
        "<div class='footer'>",
        "<p><strong>CausalKnowledgeTrace</strong> - Evidence Report</p>",
        "</div>"
    )
    return(footer)
}

#' Create CSS Styles for HTML Report
#' 
#' @return CSS style string
create_html_styles <- function() {
    css <- "
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 20px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 3px solid #007bff;
        }
        .header h1 {
            color: #007bff;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        .header .meta {
            color: #666;
            font-size: 1.1em;
        }
        .summary {
            background-color: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 30px;
            border-left: 5px solid #28a745;
        }
        .summary h2 {
            color: #28a745;
            margin-top: 0;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .stat-item {
            background: white;
            padding: 15px;
            border-radius: 5px;
            text-align: center;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .stat-number {
            font-size: 2em;
            font-weight: bold;
            color: #007bff;
        }
        .stat-label {
            color: #666;
            font-size: 0.9em;
        }
        .navigation {
            background-color: #e9ecef;
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 30px;
        }
        .nav-links {
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
        }
        .nav-link {
            background-color: #007bff;
            color: white;
            padding: 8px 15px;
            text-decoration: none;
            border-radius: 5px;
            font-size: 0.9em;
            transition: background-color 0.3s;
        }
        .nav-link:hover {
            background-color: #0056b3;
        }
        .assertion {
            background-color: white;
            border: 1px solid #dee2e6;
            border-radius: 8px;
            margin-bottom: 20px;
            overflow: hidden;
            box-shadow: 0 2px 5px rgba(0,0,0,0.05);
        }
        .assertion-header {
            background-color: #007bff;
            color: white;
            padding: 15px;
            font-weight: bold;
            font-size: 1.1em;
        }
        .assertion-content {
            padding: 20px;
        }
        .assertion-meta {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-bottom: 20px;
        }
        .meta-item {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 5px;
            border-left: 3px solid #007bff;
        }
        .meta-label {
            font-weight: bold;
            color: #495057;
            font-size: 0.9em;
        }
        .meta-value {
            color: #212529;
            margin-top: 5px;
        }
        .sentences {
            margin-top: 20px;
        }
        .sentences h4 {
            color: #28a745;
            margin-bottom: 15px;
        }
        .sentence {
            background-color: #f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 10px;
            border-left: 3px solid #28a745;
        }
        .sentence-text {
            font-style: italic;
            margin-bottom: 10px;
            line-height: 1.7;
        }
        .sentence-meta {
            font-size: 0.9em;
            color: #666;
        }
        .pmid-link {
            color: #007bff;
            text-decoration: none;
            font-weight: bold;
        }
        .pmid-link:hover {
            text-decoration: underline;
        }
        .footer {
            text-align: center;
            margin-top: 50px;
            padding-top: 20px;
            border-top: 1px solid #dee2e6;
            color: #666;
            font-size: 0.9em;
        }
        .loading {
            text-align: center;
            padding: 50px;
            color: #666;
        }
        .chunk-separator {
            text-align: center;
            margin: 30px 0;
            padding: 10px;
            background-color: #e9ecef;
            border-radius: 5px;
            color: #666;
            font-weight: bold;
        }
        @media (max-width: 768px) {
            body { padding: 10px; }
            .container { padding: 15px; }
            .header h1 { font-size: 2em; }
            .stats-grid { grid-template-columns: 1fr; }
            .assertion-meta { grid-template-columns: 1fr; }
            .nav-links { flex-direction: column; }
        }
    </style>"
    
    return(css)
}

#' Create HTML Header Section
#' 
#' @param title Report title
#' @param num_assertions Number of assertions
#' @param num_pmids Number of PMIDs
#' @return HTML header string
create_html_header <- function(title, num_assertions, num_pmids) {
    header <- paste0(
        "<div class='container'>",
        "<div class='header'>",
        "<h1>", title, "</h1>",
        "<div class='meta'>",
        "Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "<br>",
        "Contains ", num_assertions, " causal assertions from ", num_pmids, " publications",
        "</div>",
        "</div>"
    )
    return(header)
}

#' Create Empty HTML Report
#' 
#' @param title Report title
#' @return HTML string for empty report
create_empty_html_report <- function(title) {
    html <- paste(
        "<!DOCTYPE html>",
        "<html lang='en'>",
        "<head>",
        "<meta charset='UTF-8'>",
        "<meta name='viewport' content='width=device-width, initial-scale=1.0'>",
        paste0("<title>", title, "</title>"),
        create_html_styles(),
        "</head>",
        "<body>",
        "<div class='container'>",
        "<div class='header'>",
        paste0("<h1>", title, "</h1>"),
        "<div class='meta'>No data available</div>",
        "</div>",
        "<div class='loading'>",
        "<h3>No causal assertions data found</h3>",
        "<p>Please ensure you have loaded a graph with causal assertions data.</p>",
        "</div>",
        "</div>",
        "</body>",
        "</html>",
        sep = "\n"
    )
    return(html)
}

#' Create Summary Section
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @return HTML summary string
create_summary_section <- function(assertions, pmid_sentences) {
    # Calculate statistics
    unique_subjects <- length(unique(sapply(assertions, function(x) x$subject %||% "")))
    unique_objects <- length(unique(sapply(assertions, function(x) x$object %||% "")))
    unique_predicates <- length(unique(sapply(assertions, function(x) x$predicate %||% "")))

    # Count assertions by predicate
    predicates <- sapply(assertions, function(x) x$predicate %||% "Unknown")
    predicate_counts <- sort(table(predicates), decreasing = TRUE)
    top_predicates <- head(predicate_counts, 5)

    summary_html <- paste0(
        "<div class='summary'>",
        "<h2>📊 Summary Statistics</h2>",
        "<div class='stats-grid'>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", length(assertions), "</div>",
        "<div class='stat-label'>Total Assertions</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", length(pmid_sentences), "</div>",
        "<div class='stat-label'>Publications</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", unique_subjects, "</div>",
        "<div class='stat-label'>Unique Subjects</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", unique_objects, "</div>",
        "<div class='stat-label'>Unique Objects</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", unique_predicates, "</div>",
        "<div class='stat-label'>Unique Predicates</div>",
        "</div>",
        "</div>"
    )

    # Add top predicates if available
    if (length(top_predicates) > 0) {
        summary_html <- paste0(summary_html,
            "<h3>🔗 Most Common Relationships</h3>",
            "<div class='stats-grid'>"
        )

        for (i in 1:min(5, length(top_predicates))) {
            pred_name <- names(top_predicates)[i]
            pred_count <- top_predicates[i]
            summary_html <- paste0(summary_html,
                "<div class='stat-item'>",
                "<div class='stat-number'>", pred_count, "</div>",
                "<div class='stat-label'>", pred_name, "</div>",
                "</div>"
            )
        }

        summary_html <- paste0(summary_html, "</div>")
    }

    summary_html <- paste0(summary_html, "</div>")
    return(summary_html)
}

#' Create Navigation Section
#'
#' @param assertions List of assertions
#' @return HTML navigation string
create_navigation_section <- function(assertions) {
    # Create navigation based on predicates
    predicates <- unique(sapply(assertions, function(x) x$predicate %||% "Unknown"))
    predicates <- sort(predicates)

    nav_html <- paste0(
        "<div class='navigation'>",
        "<h3>🧭 Quick Navigation</h3>",
        "<div class='nav-links'>"
    )

    # Add links for each predicate (limit to prevent UI overload)
    for (i in 1:min(20, length(predicates))) {
        pred <- predicates[i]
        # Create anchor-friendly ID
        pred_id <- gsub("[^A-Za-z0-9]", "_", pred)
        nav_html <- paste0(nav_html,
            "<a href='#pred_", pred_id, "' class='nav-link'>", pred, "</a>"
        )
    }

    if (length(predicates) > 20) {
        nav_html <- paste0(nav_html,
            "<span class='nav-link' style='background-color: #6c757d;'>... and ",
            length(predicates) - 20, " more</span>"
        )
    }

    nav_html <- paste0(nav_html, "</div></div>")
    return(nav_html)
}

#' Create Assertions Section with Chunked Processing
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @param chunk_size Number of assertions per chunk
#' @return HTML assertions string
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
create_single_assertion_html <- function(assertion, pmid_sentences, index) {
    # Extract assertion details
    subject <- assertion$subject %||% "Unknown"
    object <- assertion$object %||% "Unknown"
    predicate <- assertion$predicate %||% "Unknown"

    # Create assertion header
    assertion_html <- paste0(
        "<div class='assertion'>",
        "<div class='assertion-header'>",
        "Assertion #", index, ": ", subject, " → ", predicate, " → ", object,
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

#' Create HTML Footer
#'
#' @return HTML footer string
create_html_footer <- function() {
    footer <- paste0(
        "<div class='footer'>",
        "<p>Generated by CausalKnowledgeTrace Shiny Application</p>",
        "<p>Report created on ", format(Sys.time(), "%Y-%m-%d at %H:%M:%S"), "</p>",
        "<p>For more information, visit the application interface</p>",
        "</div>",
        "</div>"  # Close container
    )
    return(footer)
}

#' Fast JSON to HTML Conversion for Large Files
#'
#' Optimized version for very large JSON files with progress tracking
#'
#' @param json_file_path Path to JSON file
#' @param output_file_path Path for output HTML file
#' @param progress_callback Optional callback function for progress updates
#' @param max_assertions Maximum number of assertions to process (for testing)
#' @return List with success status and message
#' @export
fast_json_to_html <- function(json_file_path, output_file_path,
                             progress_callback = NULL, max_assertions = NULL) {

    tryCatch({
        if (!file.exists(json_file_path)) {
            return(list(success = FALSE, message = "JSON file not found"))
        }

        # Load JSON data
        if (!is.null(progress_callback)) {
            progress_callback("Loading JSON data...")
        }

        json_data <- jsonlite::fromJSON(json_file_path, simplifyDataFrame = FALSE)

        if (is.null(json_data) || length(json_data) == 0) {
            return(list(success = FALSE, message = "Empty or invalid JSON data"))
        }

        # Limit assertions if specified (for testing)
        if (!is.null(max_assertions) && !is.null(json_data$assertions)) {
            if (length(json_data$assertions) > max_assertions) {
                json_data$assertions <- json_data$assertions[1:max_assertions]
                cat("Limited to", max_assertions, "assertions for processing\n")
            }
        }

        if (!is.null(progress_callback)) {
            progress_callback("Converting to HTML...")
        }

        # Convert to HTML
        html_content <- convert_json_to_html(
            json_data,
            title = "Causal Assertions Report",
            include_summary = TRUE,
            chunk_size = 500  # Smaller chunks for better performance
        )

        if (!is.null(progress_callback)) {
            progress_callback("Writing HTML file...")
        }

        # Write to file
        writeLines(html_content, output_file_path, useBytes = TRUE)

        file_size <- file.info(output_file_path)$size
        file_size_mb <- round(file_size / (1024 * 1024), 2)

        return(list(
            success = TRUE,
            message = paste("HTML report generated successfully.",
                          "File size:", file_size_mb, "MB"),
            file_path = output_file_path,
            file_size_mb = file_size_mb
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error converting JSON to HTML:", e$message)
        ))
    })
}

#' Optimized HTML Generation with Memory Management
#'
#' Enhanced version that handles very large datasets by streaming HTML generation
#' and implementing memory-efficient processing
#'
#' @param json_data JSON data object
#' @param title Report title
#' @param max_assertions_per_section Maximum assertions per predicate section
#' @param enable_search Whether to include JavaScript search functionality
#' @return HTML string with optimizations
#' @export
optimized_html_generation <- function(json_data, title = "Causal Assertions Report",
                                    max_assertions_per_section = 2000, enable_search = TRUE) {

    if (is.null(json_data) || length(json_data) == 0) {
        return(create_empty_html_report(title))
    }

    assertions <- json_data$assertions %||% list()
    pmid_sentences <- json_data$pmid_sentences %||% list()

    if (length(assertions) == 0) {
        return(create_empty_html_report(title))
    }

    total_assertions <- length(assertions)
    cat("Optimizing HTML generation for", total_assertions, "assertions...\n")

    # Create optimized HTML structure
    html_parts <- list()

    # Header with enhanced meta information
    html_parts$doctype <- "<!DOCTYPE html>"
    html_parts$html_open <- "<html lang='en'>"
    html_parts$head <- create_optimized_head(title, total_assertions, enable_search)
    html_parts$body_open <- "<body>"
    html_parts$container_open <- "<div class='container'>"

    # Header section
    html_parts$header <- create_enhanced_header(title, total_assertions, length(pmid_sentences))

    # Performance warning for large datasets
    if (total_assertions > 5000) {
        html_parts$performance_warning <- create_performance_warning(total_assertions)
    }

    # Summary section with enhanced statistics
    html_parts$summary <- create_enhanced_summary(assertions, pmid_sentences)

    # Navigation with search if enabled
    if (enable_search) {
        html_parts$search_nav <- create_search_navigation(assertions)
    } else {
        html_parts$navigation <- create_navigation_section(assertions)
    }

    # Optimized assertions section
    html_parts$assertions <- create_optimized_assertions_section(
        assertions, pmid_sentences, max_assertions_per_section
    )

    # Footer
    html_parts$footer <- create_enhanced_footer(total_assertions)
    html_parts$container_close <- "</div>"
    html_parts$body_close <- "</body>"
    html_parts$html_close <- "</html>"

    # Combine all parts efficiently
    full_html <- paste(html_parts, collapse = "\n")

    cat("HTML generation completed. Estimated size:",
        round(nchar(full_html) / (1024 * 1024), 2), "MB\n")

    return(full_html)
}

#' Create Optimized HTML Head Section
#'
#' @param title Page title
#' @param total_assertions Number of assertions
#' @param enable_search Whether to include search functionality
#' @return HTML head string
create_optimized_head <- function(title, total_assertions, enable_search = TRUE) {
    head_content <- paste0(
        "<head>",
        "<meta charset='UTF-8'>",
        "<meta name='viewport' content='width=device-width, initial-scale=1.0'>",
        "<meta name='description' content='Causal assertions report with ", total_assertions, " assertions'>",
        "<meta name='generator' content='CausalKnowledgeTrace'>",
        paste0("<title>", title, "</title>"),
        create_html_styles()
    )

    if (enable_search) {
        head_content <- paste0(head_content, create_search_javascript())
    }

    head_content <- paste0(head_content, "</head>")
    return(head_content)
}

#' Create Enhanced Header with Progress Information
#'
#' @param title Report title
#' @param num_assertions Number of assertions
#' @param num_pmids Number of PMIDs
#' @return Enhanced HTML header string
create_enhanced_header <- function(title, num_assertions, num_pmids) {
    header <- paste0(
        "<div class='header'>",
        "<h1>", title, "</h1>",
        "<div class='meta'>",
        "Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "<br>",
        "📊 ", format(num_assertions, big.mark = ","), " causal assertions from ",
        format(num_pmids, big.mark = ","), " publications<br>",
        "🔬 Optimized for large-scale causal analysis",
        "</div>",
        "</div>"
    )
    return(header)
}

#' Create Performance Warning for Large Datasets
#'
#' @param total_assertions Number of assertions
#' @return HTML warning string
create_performance_warning <- function(total_assertions) {
    warning_html <- paste0(
        "<div class='performance-warning' style='background-color: #fff3cd; border: 1px solid #ffeaa7; ",
        "border-radius: 8px; padding: 15px; margin-bottom: 20px; color: #856404;'>",
        "<h4 style='margin-top: 0; color: #856404;'>⚡ Large Dataset Detected</h4>",
        "<p>This report contains <strong>", format(total_assertions, big.mark = ","),
        "</strong> assertions. For optimal performance:</p>",
        "<ul>",
        "<li>Use the search function to find specific content</li>",
        "<li>Consider using browser's find function (Ctrl+F) for quick searches</li>",
        "<li>Sections are organized by relationship type for easier navigation</li>",
        "<li>Large sections may take a moment to load completely</li>",
        "</ul>",
        "</div>"
    )
    return(warning_html)
}

#' Create Search Navigation with JavaScript
#'
#' @param assertions List of assertions
#' @return HTML search navigation string
create_search_navigation <- function(assertions) {
    # Get unique predicates for filter options
    predicates <- unique(sapply(assertions, function(x) x$predicate %||% "Unknown"))
    predicates <- sort(predicates)

    search_html <- paste0(
        "<div class='search-section' style='background-color: #f8f9fa; padding: 20px; ",
        "border-radius: 8px; margin-bottom: 30px;'>",
        "<h3>🔍 Search & Filter</h3>",
        "<div style='display: flex; gap: 15px; flex-wrap: wrap; align-items: center;'>",
        "<input type='text' id='searchInput' placeholder='Search assertions...' ",
        "style='flex: 1; min-width: 300px; padding: 10px; border: 1px solid #ddd; border-radius: 5px;'>",
        "<select id='predicateFilter' style='padding: 10px; border: 1px solid #ddd; border-radius: 5px;'>",
        "<option value=''>All Relationships</option>"
    )

    # Add predicate options (limit to prevent UI overload)
    for (i in 1:min(50, length(predicates))) {
        pred <- predicates[i]
        search_html <- paste0(search_html,
            "<option value='", pred, "'>", pred, "</option>"
        )
    }

    search_html <- paste0(search_html,
        "</select>",
        "<button onclick='clearSearch()' style='padding: 10px 15px; background-color: #6c757d; ",
        "color: white; border: none; border-radius: 5px; cursor: pointer;'>Clear</button>",
        "</div>",
        "<div id='searchResults' style='margin-top: 15px; font-size: 0.9em; color: #666;'></div>",
        "</div>"
    )

    return(search_html)
}

#' Create JavaScript for Search Functionality
#'
#' @return JavaScript code string
create_search_javascript <- function() {
    js_code <- "
    <script>
        let allAssertions = [];

        function initializeSearch() {
            const searchInput = document.getElementById('searchInput');
            const predicateFilter = document.getElementById('predicateFilter');

            if (searchInput) {
                searchInput.addEventListener('input', performSearch);
            }
            if (predicateFilter) {
                predicateFilter.addEventListener('change', performSearch);
            }

            // Collect all assertions for searching
            const assertions = document.querySelectorAll('.assertion');
            allAssertions = Array.from(assertions);
        }

        function performSearch() {
            const searchTerm = document.getElementById('searchInput').value.toLowerCase();
            const selectedPredicate = document.getElementById('predicateFilter').value;
            const resultsDiv = document.getElementById('searchResults');

            let visibleCount = 0;
            let totalCount = allAssertions.length;

            allAssertions.forEach(assertion => {
                const text = assertion.textContent.toLowerCase();
                const matchesSearch = searchTerm === '' || text.includes(searchTerm);
                const matchesPredicate = selectedPredicate === '' || text.includes(selectedPredicate.toLowerCase());

                if (matchesSearch && matchesPredicate) {
                    assertion.style.display = 'block';
                    visibleCount++;
                } else {
                    assertion.style.display = 'none';
                }
            });

            if (resultsDiv) {
                resultsDiv.innerHTML = `Showing ${visibleCount} of ${totalCount} assertions`;
            }
        }

        function clearSearch() {
            document.getElementById('searchInput').value = '';
            document.getElementById('predicateFilter').value = '';
            performSearch();
        }

        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', initializeSearch);
    </script>"

    return(js_code)
}

#' Create Enhanced Summary with Additional Statistics
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @return Enhanced HTML summary string
create_enhanced_summary <- function(assertions, pmid_sentences) {
    # Calculate enhanced statistics
    unique_subjects <- length(unique(sapply(assertions, function(x) x$subject %||% "")))
    unique_objects <- length(unique(sapply(assertions, function(x) x$object %||% "")))
    unique_predicates <- length(unique(sapply(assertions, function(x) x$predicate %||% "")))

    # Calculate average assertions per publication
    total_pmids <- length(pmid_sentences)
    avg_assertions_per_pmid <- if (total_pmids > 0) round(length(assertions) / total_pmids, 1) else 0

    # Count assertions by predicate
    predicates <- sapply(assertions, function(x) x$predicate %||% "Unknown")
    predicate_counts <- sort(table(predicates), decreasing = TRUE)
    top_predicates <- head(predicate_counts, 8)  # Show more predicates

    # Calculate publication years if available
    years <- c()
    for (pmid_data in pmid_sentences) {
        if (!is.null(pmid_data$year)) {
            years <- c(years, pmid_data$year)
        }
    }

    year_range <- if (length(years) > 0) {
        paste(min(years, na.rm = TRUE), "-", max(years, na.rm = TRUE))
    } else {
        "Not available"
    }

    summary_html <- paste0(
        "<div class='summary'>",
        "<h2>📊 Comprehensive Statistics</h2>",
        "<div class='stats-grid'>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", format(length(assertions), big.mark = ","), "</div>",
        "<div class='stat-label'>Total Assertions</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", format(length(pmid_sentences), big.mark = ","), "</div>",
        "<div class='stat-label'>Publications</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", format(unique_subjects, big.mark = ","), "</div>",
        "<div class='stat-label'>Unique Subjects</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", format(unique_objects, big.mark = ","), "</div>",
        "<div class='stat-label'>Unique Objects</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", unique_predicates, "</div>",
        "<div class='stat-label'>Relationship Types</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", avg_assertions_per_pmid, "</div>",
        "<div class='stat-label'>Avg. Assertions/Publication</div>",
        "</div>",
        "<div class='stat-item'>",
        "<div class='stat-number'>", year_range, "</div>",
        "<div class='stat-label'>Publication Years</div>",
        "</div>",
        "</div>"
    )

    # Add top predicates section
    if (length(top_predicates) > 0) {
        summary_html <- paste0(summary_html,
            "<h3>🔗 Most Frequent Relationships</h3>",
            "<div class='stats-grid'>"
        )

        for (i in 1:length(top_predicates)) {
            pred_name <- names(top_predicates)[i]
            pred_count <- top_predicates[i]
            percentage <- round((pred_count / length(assertions)) * 100, 1)

            summary_html <- paste0(summary_html,
                "<div class='stat-item'>",
                "<div class='stat-number'>", format(pred_count, big.mark = ","), "</div>",
                "<div class='stat-label'>", pred_name, " (", percentage, "%)</div>",
                "</div>"
            )
        }

        summary_html <- paste0(summary_html, "</div>")
    }

    summary_html <- paste0(summary_html, "</div>")
    return(summary_html)
}

#' Create Optimized Assertions Section with Better Memory Management
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @param max_per_section Maximum assertions per predicate section
#' @return HTML assertions string
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

    # Add table of contents for large datasets
    if (length(sorted_predicates) > 10) {
        assertions_html <- paste0(assertions_html, create_table_of_contents(sorted_predicates, predicate_counts))
    }

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

#' Create Table of Contents for Large Reports
#'
#' @param predicates List of predicate names
#' @param counts Named vector of predicate counts
#' @return HTML table of contents string
create_table_of_contents <- function(predicates, counts) {
    toc_html <- paste0(
        "<div class='table-of-contents' style='background-color: #f8f9fa; padding: 20px; ",
        "border-radius: 8px; margin-bottom: 30px;'>",
        "<h3>📑 Table of Contents</h3>",
        "<div style='columns: 2; column-gap: 30px;'>"
    )

    for (i in 1:min(20, length(predicates))) {  # Limit TOC size
        pred <- predicates[i]
        count <- counts[pred]
        pred_id <- gsub("[^A-Za-z0-9]", "_", pred)

        toc_html <- paste0(toc_html,
            "<div style='break-inside: avoid; margin-bottom: 8px;'>",
            "<a href='#pred_", pred_id, "' style='text-decoration: none; color: #007bff;'>",
            pred, " <span style='color: #666;'>(", format(count, big.mark = ","), ")</span>",
            "</a></div>"
        )
    }

    if (length(predicates) > 20) {
        toc_html <- paste0(toc_html,
            "<div style='color: #666; font-style: italic; margin-top: 10px;'>",
            "... and ", length(predicates) - 20, " more sections</div>"
        )
    }

    toc_html <- paste0(toc_html, "</div></div>")
    return(toc_html)
}

#' Create Compact HTML for Single Assertion (Memory Optimized)
#'
#' @param assertion Single assertion object
#' @param pmid_sentences List of PMID sentences
#' @param index Assertion index for display
#' @return Compact HTML string for single assertion
create_compact_assertion_html <- function(assertion, pmid_sentences, index) {
    # Extract assertion details
    subject <- assertion$subject %||% "Unknown"
    object <- assertion$object %||% "Unknown"
    predicate <- assertion$predicate %||% "Unknown"

    # Create more compact assertion display
    assertion_html <- paste0(
        "<div class='assertion' style='margin-bottom: 15px;'>",
        "<div class='assertion-header' style='padding: 10px;'>",
        "<strong>", subject, "</strong> → ", predicate, " → <strong>", object, "</strong>",
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

#' Create Enhanced Footer with Performance Information
#'
#' @param total_assertions Number of assertions processed
#' @return Enhanced HTML footer string
create_enhanced_footer <- function(total_assertions) {
    footer <- paste0(
        "<div class='footer'>",
        "<h4>📈 Report Information</h4>",
        "<p><strong>Generated by:</strong> CausalKnowledgeTrace Shiny Application</p>",
        "<p><strong>Report created:</strong> ", format(Sys.time(), "%Y-%m-%d at %H:%M:%S"), "</p>",
        "<p><strong>Total assertions processed:</strong> ", format(total_assertions, big.mark = ","), "</p>",
        "<p><strong>Optimization:</strong> Memory-efficient HTML generation with chunked processing</p>",
        "<hr style='margin: 20px 0; border: none; border-top: 1px solid #ddd;'>",
        "<p style='font-size: 0.9em; color: #666;'>",
        "This report was optimized for large datasets. Use browser search (Ctrl+F) for quick navigation. ",
        "For technical support, refer to the application documentation.",
        "</p>",
        "</div>"
    )
    return(footer)
}
