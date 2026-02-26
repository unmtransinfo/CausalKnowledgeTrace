#' JSON to HTML Conversion Module
#' 
#' This module provides functions to convert JSON causal assertions data
#' to readable HTML reports with proper styling and navigation.
#' Optimized for large datasets with thousands of nodes and edges.
#'
#' Note: This file previously contained 1,840 lines of code. It has been refactored
#' into 5 smaller, focused modules for better maintainability:
#'
#' 1. html_styles.R (466 lines) - CSS styling functions
#'    - get_minimal_css_styles()
#'    - create_simple_html_styles()
#'    - create_html_styles()
#'
#' 2. html_headers.R (157 lines) - Header and footer functions
#'    - create_simple_header()
#'    - create_html_header()
#'    - create_enhanced_header()
#'    - create_optimized_head()
#'    - create_empty_html_report()
#'    - create_simple_footer()
#'    - create_html_footer()
#'    - create_enhanced_footer()
#'
#' 3. html_sections.R (490 lines) - Section building functions
#'    - create_fast_pmid_section()
#'    - create_pmid_sentences_section()
#'    - create_summary_section()
#'    - create_navigation_section()
#'    - create_performance_warning()
#'    - create_search_navigation()
#'    - create_search_javascript()
#'    - create_enhanced_summary()
#'    - create_table_of_contents()
#'
#' 4. html_assertions.R (537 lines) - Assertion rendering functions
#'    - create_fast_assertions_section()
#'    - create_simple_assertions_section()
#'    - create_assertions_section()
#'    - create_single_assertion_html()
#'    - create_compact_assertion_html()
#'    - create_optimized_assertions_section()
#'
#' 5. html_core.R (255 lines) - Main conversion functions
#'    - convert_json_to_html()
#'    - create_fast_html_template()
#'    - fast_json_to_html()
#'    - optimized_html_generation()
#'
#' All functions maintain their original signatures for backward compatibility.

library(jsonlite)
library(htmltools)

# Determine the correct path to source modules
module_dir <- if (file.exists("modules/html_styles.R")) {
    "modules"
} else if (file.exists("shiny_app/modules/html_styles.R")) {
    "shiny_app/modules"
} else {
    dirname(sys.frame(1)$ofile)
}

# Source all HTML generation sub-modules
source(file.path(module_dir, "html_styles.R"), local = TRUE)
source(file.path(module_dir, "html_headers.R"), local = TRUE)
source(file.path(module_dir, "html_sections.R"), local = TRUE)
source(file.path(module_dir, "html_assertions.R"), local = TRUE)
source(file.path(module_dir, "html_core.R"), local = TRUE)
