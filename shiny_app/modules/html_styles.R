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
    .streamlined-header {
        background-color: #f8f9fa;
        padding: 12px;
        margin-bottom: 15px;
        border-radius: 5px;
        border: 1px solid #dee2e6;
    }
    .sticky-relation-header {
        position: sticky;
        top: 0;
        background-color: #e3f2fd;
        border: 2px solid #1976d2;
        border-radius: 5px;
        padding: 12px;
        margin-bottom: 15px;
        z-index: 100;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }
    .label-text {
        color: #6c757d;
        font-weight: normal;
        font-size: 0.9em;
    }
    .predicate-text {
        color: #495057;
        font-weight: bold;
        font-size: 1.0em;
        background-color: #f8f9fa;
        padding: 2px 6px;
        border-radius: 3px;
        border: 1px solid #dee2e6;
    }
    .pmid-sentence-line {
        margin: 8px 0;
        padding: 10px;
        background-color: white;
        border-radius: 3px;
        border-left: 3px solid #28a745;
        line-height: 1.5;
        word-wrap: break-word;
        overflow-wrap: break-word;
    }
    .pmid-part {
        font-weight: bold;
    }
    .sentence-part {
        color: #495057;
    }
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
        background-color: #007bff;
        color: white;
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

#' Create Full HTML Styles
#'
#' Returns comprehensive CSS for full-featured HTML reports
#'
#' @return CSS string
#' @export
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

