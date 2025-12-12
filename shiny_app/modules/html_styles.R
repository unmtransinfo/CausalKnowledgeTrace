# HTML Styles Module
# This module provides CSS styling functions for HTML reports
# Author: Refactored from json_to_html.R

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Get Minimal CSS Styles
#'
#' Returns minimal CSS for fast HTML generation
#'
#' @return CSS string
#' @export
get_minimal_css_styles <- function() {
    return("
    <style>
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
        background-color: #f5f5f5;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        border-radius: 10px;
        margin-bottom: 30px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header h1 {
        margin: 0 0 10px 0;
        font-size: 2em;
    }
    .header p {
        margin: 5px 0;
        opacity: 0.9;
    }
    .section {
        background: white;
        padding: 25px;
        margin-bottom: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .section h2 {
        color: #667eea;
        border-bottom: 2px solid #667eea;
        padding-bottom: 10px;
        margin-top: 0;
    }
    .pmid-entry {
        margin-bottom: 20px;
        padding: 15px;
        background-color: #f8f9fa;
        border-left: 4px solid #667eea;
        border-radius: 4px;
    }
    .pmid-entry h3 {
        margin: 0 0 10px 0;
        color: #764ba2;
    }
    .pmid-entry a {
        color: #667eea;
        text-decoration: none;
        font-weight: 500;
    }
    .pmid-entry a:hover {
        text-decoration: underline;
    }
    .sentence {
        margin: 8px 0;
        padding: 8px;
        background-color: white;
        border-radius: 4px;
    }
    .assertion {
        margin-bottom: 15px;
        padding: 15px;
        background-color: #f8f9fa;
        border-left: 4px solid #28a745;
        border-radius: 4px;
    }
    .assertion-header {
        font-weight: bold;
        color: #28a745;
        margin-bottom: 8px;
    }
    .assertion-details {
        font-size: 0.9em;
        color: #666;
    }
    .footer {
        text-align: center;
        padding: 20px;
        color: #666;
        font-size: 0.9em;
        margin-top: 30px;
    }
    </style>
    ")
}

#' Create Simple HTML Styles
#'
#' Returns simple CSS for basic HTML reports
#'
#' @return CSS string
#' @export
create_simple_html_styles <- function() {
    css <- "
    <style>
    body {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', sans-serif;
        line-height: 1.6;
        color: #333;
        max-width: 1200px;
        margin: 0 auto;
        padding: 20px;
        background-color: #f5f5f5;
    }
    .header {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
        padding: 30px;
        border-radius: 10px;
        margin-bottom: 30px;
        box-shadow: 0 4px 6px rgba(0,0,0,0.1);
    }
    .header h1 {
        margin: 0 0 10px 0;
        font-size: 2em;
    }
    .header p {
        margin: 5px 0;
        opacity: 0.9;
    }
    .section {
        background: white;
        padding: 25px;
        margin-bottom: 20px;
        border-radius: 8px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .section h2 {
        color: #667eea;
        border-bottom: 2px solid #667eea;
        padding-bottom: 10px;
        margin-top: 0;
    }

