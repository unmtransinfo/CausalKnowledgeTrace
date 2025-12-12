# HTML Sections Module
# This module provides section-building functions for HTML reports
# Author: Refactored from json_to_html.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Create Fast PMID Section
#'
#' Efficiently build PMID sentences section
#'
#' @param pmid_sentences PMID sentences data
#' @return HTML string for PMID section
#' @export
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

#' Create PMID Sentences Section
#'
#' @param pmid_sentences List of PMID sentences
#' @return HTML string for PMID sentences
#' @export
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

#' Create Summary Section
#'
#' @param assertions List of assertions
#' @param pmid_sentences List of PMID sentences
#' @return HTML string for summary section
#' @export
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
#' @export
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

#' Create Performance Warning
#'
#' @param total_assertions Total number of assertions
#' @return HTML warning string
#' @export
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
#' @export
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
#' @export
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
#' @export
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

#' Create Table of Contents
#'
#' @param predicates Vector of predicates
#' @param counts Vector of counts for each predicate
#' @return HTML table of contents string
#' @export
create_table_of_contents <- function(predicates, counts) {
    toc_html <- paste0(
        "<div class='table-of-contents' style='background-color: #f8f9fa; padding: 20px; ",
        "border-radius: 8px; margin-bottom: 30px;'>",
        "<h3>📑 Table of Contents</h3>",
        "<div style='display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 10px;'>"
    )

    for (i in 1:length(predicates)) {
        pred <- predicates[i]
        count <- counts[i]
        pred_id <- gsub("[^A-Za-z0-9]", "_", pred)

        toc_html <- paste0(toc_html,
            "<div style='background-color: white; padding: 10px; border-radius: 5px; ",
            "border-left: 3px solid #007bff;'>",
            "<a href='#pred_", pred_id, "' style='text-decoration: none; color: #007bff; font-weight: 500;'>",
            pred, "</a>",
            "<span style='float: right; color: #666; font-size: 0.9em;'>", count, "</span>",
            "</div>"
        )
    }

    toc_html <- paste0(toc_html, "</div></div>")
    return(toc_html)
}

