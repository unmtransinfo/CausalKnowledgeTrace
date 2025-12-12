# HTML Core Module
# This module provides main HTML conversion functions
# Author: Refactored from json_to_html.R

# Determine the correct path to source modules
module_dir <- if (file.exists("modules/html_styles.R")) {
    "modules"
} else if (file.exists("shiny_app/modules/html_styles.R")) {
    "shiny_app/modules"
} else {
    dirname(sys.frame(1)$ofile)
}

# Source required modules
source(file.path(module_dir, "html_styles.R"), local = TRUE)
source(file.path(module_dir, "html_headers.R"), local = TRUE)
source(file.path(module_dir, "html_sections.R"), local = TRUE)
source(file.path(module_dir, "html_assertions.R"), local = TRUE)

library(jsonlite)

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Convert JSON Causal Assertions to Simple HTML Report
#'
#' Creates a clean, focused HTML report showing PMID sentences and assertions
#' without unnecessary statistics or navigation
#'
#' @param json_data List containing causal assertions data
#' @param title Report title (default: "Causal Evidence Report")
#' @param progress_callback Optional function to report progress (receives message string)
#' @return HTML string
#' @export
convert_json_to_html <- function(json_data, title = "Causal Evidence Report", progress_callback = NULL) {

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

    if (!is.null(progress_callback)) {
        progress_callback("⬇️ Preparing HTML generation...")
    }

    cat("Converting", length(assertions), "assertions and", length(pmid_sentences), "PMID entries to HTML...\n")

    # Use fast template-based HTML generation
    full_html <- create_fast_html_template(title, pmid_sentences, assertions, progress_callback)

    return(full_html)
}

#' Create Fast HTML Template
#'
#' Pre-built HTML template for faster generation
#'
#' @param title Report title
#' @param pmid_sentences PMID sentences data
#' @param assertions Assertions data
#' @param progress_callback Optional function to report progress
#' @return Complete HTML string
#' @export
create_fast_html_template <- function(title, pmid_sentences, assertions, progress_callback = NULL) {

    if (!is.null(progress_callback)) {
        progress_callback("⬇️ Building HTML structure...")
    }

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
    assertions_section <- create_fast_assertions_section(assertions, pmid_sentences, progress_callback)

    if (!is.null(progress_callback)) {
        progress_callback("⬇️ Compiling HTML file...")
    }

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

#' Fast JSON to HTML Conversion
#'
#' Converts JSON file to HTML file with progress reporting
#'
#' @param json_file_path Path to input JSON file
#' @param output_file_path Path to output HTML file
#' @param progress_callback Optional function to report progress
#' @param max_assertions Optional limit on number of assertions to process
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
            title = "Causal Assertions Report"
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
    html_parts$styles <- create_html_styles()
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
        html_parts$search_js <- create_search_javascript()
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

