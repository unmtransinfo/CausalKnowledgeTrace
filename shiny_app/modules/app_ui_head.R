# Application UI Head Module
# This module contains CSS styles and JavaScript for the application
# Author: Refactored from app.R

#' Get Application CSS Styles
#'
#' Returns HTML tags with CSS styles for the application
#' @return tags$style object with CSS
#' @export
get_app_css_styles <- function() {
    tags$style(HTML("
        /* Header Layout: Hamburger (left) | Text (center) | Logo (right) */
        .main-header .navbar {
            margin-left: 0 !important;
            position: relative !important;
        }

        /* Hide the default logo element */
        .main-header .logo {
            display: none !important;
        }

        /* Position hamburger menu on the left */
        .main-header .sidebar-toggle {
            float: left !important;
        }

        /* Center the custom title */
        .navbar-title-center {
            position: absolute !important;
            left: 50% !important;
            transform: translateX(-50%) !important;
            float: none !important;
            top: 0 !important;
            z-index: 1000 !important;
        }

        .navbar-title-center span {
            color: white !important;
            font-size: 20px !important;
            font-weight: bold !important;
            line-height: 50px !important;
            white-space: nowrap !important;
            display: block !important;
        }

        /* Position logo on the right */
        .custom-logo-container {
            float: right !important;
            order: 3;
            margin-right: 10px;
        }

        .main-header .navbar-custom-menu {
            float: right !important;
        }

        /* Sidebar active menu item - only change the left border color to orange */
        .skin-blue .main-sidebar .sidebar .sidebar-menu .active > a {
            border-left-color: #ff8c42 !important;  /* Orange border instead of blue */
            border-left-width: 4px !important;
            border-left-style: solid !important;
        }

        /* General sidebar menu item styling */
        .sidebar-menu > li.active > a {
            border-left-color: #ff8c42 !important;  /* Orange border */
            border-left-width: 4px !important;
        }

        .content-wrapper, .right-side {
            background-color: #f4f4f4;
        }
        .box {
            border-radius: 5px;
        }

        /* Override shinydashboard box constraints for DAG container */
        .box .box-body {
            padding: 10px;
        }

        .box.dag-network-box {
            height: auto !important;
        }

        .box.dag-network-box .box-body {
            height: auto !important;
            padding: 0 !important;
        }

        /* Resizable DAG visualization styles */
        .resizable-dag-container {
            position: relative;
            min-height: 500px;
            max-height: calc(100vh - 200px);
            height: calc(100vh - 300px);
            border: 1px solid #ddd;
            border-radius: 4px;
            overflow: visible;
            width: 100%;
        }

        /* Fix for visNetwork nodesIdSelection dropdown */
        .resizable-dag-container .vis-network {
            overflow: visible !important;
        }

        .resizable-dag-container .vis-option-container {
            position: relative;
            z-index: 10;
            background: white;
            padding: 8px;
            border-bottom: 1px solid #ddd;
            display: block !important;
            visibility: visible !important;
        }

        .resizable-dag-container input.vis-input {
            width: 200px;
            padding: 6px 8px;
            border: 1px solid #ccc;
            border-radius: 3px;
            font-size: 13px;
            display: block !important;
            visibility: visible !important;
        }

        .dag-resize-handle {
            position: absolute;
            bottom: -1px;
            left: 50%;
            transform: translateX(-50%);
            width: 60px;
            height: 12px;
            background: #f8f9fa;
            border: 1px solid #dee2e6;
            border-radius: 6px 6px 0 0;
            cursor: ns-resize;
            z-index: 1000;
            display: flex;
            align-items: center;
            justify-content: center;
            transition: all 0.2s ease;
        }

        .dag-resize-handle:before {
            content: '';
            width: 30px;
            height: 3px;
            background: #6c757d;
            border-radius: 2px;
            box-shadow: 0 3px 0 #6c757d, 0 6px 0 #6c757d;
        }

        .dag-resize-handle:hover {
            background: #e9ecef;
            border-color: #007bff;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        .dag-resize-handle:hover:before {
            background: #007bff;
            box-shadow: 0 3px 0 #007bff, 0 6px 0 #007bff;
        }

        .dag-network-output {
            width: 100%;
            height: 100%;
        }

        /* Network container sizing */
        .resizable-dag-container #network {
            width: 100% !important;
            height: 100% !important;
        }

        /* Ensure proper viewport sizing */
        .content-wrapper {
            min-height: calc(100vh - 50px);
        }

        /* Responsive adjustments */
        @media (max-width: 768px) {
            .resizable-dag-container {
                height: 60vh;
                min-height: 400px;
            }
        }

        /* Edge Information Panel Styling */
        .edge-info-box {
            height: auto !important;
            min-height: 350px;
        }

        .edge-info-box .box-body {
            padding: 15px !important;
            height: auto !important;
        }

        .edge-info-table-container {
            width: 100%;
            overflow: hidden;
        }

        /* DataTable styling for Edge Information */
        .edge-info-table-container .dataTables_wrapper {
            width: 100% !important;
        }

        .edge-info-table-container .dataTables_scroll {
            width: 100% !important;
        }

        .edge-info-table-container .dataTables_scrollHead,
        .edge-info-table-container .dataTables_scrollBody {
            width: 100% !important;
        }

        .edge-info-table-container table.dataTable {
            width: 100% !important;
            margin: 0 !important;
        }

        .edge-info-table-container .dataTables_filter {
            float: right;
            margin-bottom: 10px;
        }

        .edge-info-table-container .dataTables_info {
            float: left;
            margin-top: 10px;
        }

        .edge-info-table-container .dataTables_paginate {
            float: right;
            margin-top: 10px;
        }
    "))
}

#' Get Application JavaScript
#'
#' Returns HTML tags with JavaScript for the application
#' @return tags$script object with JavaScript
#' @export
get_app_javascript <- function() {
    tags$script(HTML("
        function openCreateGraph() {
            // Navigate to the Graph Configuration tab
            $('a[data-value=\"create_graph\"]').click();
        }

        function openCausalAnalysis() {
            // Navigate to the Causal Analysis tab
            $('a[data-value=\"causal\"]').click();
        }

        // Progress bar control functions
        function updateProgress(percent, text, status) {
            $('#loading_progress').css('width', percent + '%');
            $('#progress_text').text(text);
            $('#loading_status').text('Status: ' + status);
        }

        function showLoadingSection() {
            $('#loading_section').show();
            updateProgress(10, 'Starting...', 'Initializing file loading process');
        }

        function hideLoadingSection() {
            $('#loading_section').hide();
            updateProgress(0, 'Initializing...', 'Ready to load...');
        }

        // Event handlers for loading buttons
        $(document).on('click', '#load_selected_dag', function() {
            showLoadingSection();
            updateProgress(20, 'Reading file...', 'Loading selected graph file');
        });

        $(document).on('click', '#upload_and_load', function() {
            showLoadingSection();
            updateProgress(20, 'Uploading file...', 'Processing uploaded graph file');
        });

        // Hide loading section on page load
        $(document).ready(function() {
            hideLoadingSection();
        });

        // Message handlers for server communication
        Shiny.addCustomMessageHandler('updateProgress', function(data) {
            updateProgress(data.percent, data.text, data.status);
        });

        Shiny.addCustomMessageHandler('hideLoadingSection', function(data) {
            setTimeout(function() {
                hideLoadingSection();
            }, 1000); // Brief delay to show completion (1 second)
        });
    "))
}

#' Get DAG Resize JavaScript
#'
#' Returns JavaScript for DAG visualization resize functionality
#' @return tags$script object
#' @keywords internal
get_dag_resize_javascript <- function() {
    tags$script(HTML("
        // DAG Visualization Resize Functionality
        function initializeDAGResize() {
            var isResizing = false;
            var startY = 0;
            var startHeight = 0;
            var container = null;

            // Initialize resize functionality when DOM is ready
            $(document).ready(function() {
                setTimeout(function() {
                    setupResizeHandlers();
                }, 1000); // Delay to ensure elements are rendered
            });

            function setupResizeHandlers() {
                container = $('.resizable-dag-container');
                var handle = $('.dag-resize-handle');

                if (container.length === 0 || handle.length === 0) {
                    // Retry setup if elements not found
                    setTimeout(setupResizeHandlers, 500);
                    return;
                }

                handle.on('mousedown', function(e) {
                    isResizing = true;
                    startY = e.clientY;
                    startHeight = container.height();

                    // Prevent text selection during resize
                    $('body').addClass('no-select');
                    e.preventDefault();
                });

                $(document).on('mousemove', function(e) {
                    if (!isResizing) return;

                    var deltaY = e.clientY - startY;
                    var newHeight = startHeight + deltaY;

                    // Enforce min and max height constraints
                    newHeight = Math.max(400, Math.min(1200, newHeight));

                    container.height(newHeight);

                    // Trigger resize event for visNetwork
                    if (window.Shiny && window.Shiny.onInputChange) {
                        window.Shiny.onInputChange('dag_container_height', newHeight);
                    }
                });

                $(document).on('mouseup', function() {
                    if (isResizing) {
                        isResizing = false;
                        $('body').removeClass('no-select');

                        // Force visNetwork to redraw and fit after resize
                        setTimeout(function() {
                            if (typeof HTMLWidgets !== 'undefined') {
                                HTMLWidgets.resize();
                            }
                            if (window.network && typeof window.network.redraw === 'function') {
                                window.network.redraw();
                                if (typeof window.network.fit === 'function') {
                                    window.network.fit({
                                        animation: { duration: 300 }
                                    });
                                }
                            }
                        }, 100);
                    }
                });
            }
        }

        // Initialize resize functionality
        initializeDAGResize();

        // Add CSS for preventing text selection during resize
        $('<style>')
            .prop('type', 'text/css')
            .html('.no-select { -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none; user-select: none; }')
            .appendTo('head');

        // Function to update DAG status
        window.updateDAGStatus = function(status, color) {
            var statusElement = $('#dag_status_text');
            if (statusElement.length) {
                statusElement.text(status).css('color', color);
            }
        };

        // Update status when DAG is modified
        Shiny.addCustomMessageHandler('updateDAGStatus', function(message) {
            window.updateDAGStatus(message.status, message.color);
        });
    "))
}

#' Get Application Head Tags
#'
#' Returns complete head section with title, CSS, and JavaScript
#' @return tags$head object
#' @export
get_app_head <- function() {
    tags$head(
        tags$title("CKT - Causal Knowledge Trace"),
        get_app_css_styles(),
        get_app_javascript(),
        get_dag_resize_javascript()
    )
}

