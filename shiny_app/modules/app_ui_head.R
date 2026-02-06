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
        .skin-blue .main-header .navbar,
        .main-header .navbar {
            margin-left: 0 !important;
            margin-bottom: 0 !important;
            position: relative !important;
            background-color: #222d32 !important; /* background color */
        }

        /* Remove any margin/padding from main header */
        .main-header {
            margin-bottom: 0 !important;
            background-color: #222d32 !important;
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

        /* Hide sidebar completely */
        .main-sidebar {
            display: none !important;
        }

        /* Adjust content wrapper to use full width */
        .content-wrapper, .right-side {
            margin-left: 0 !important;
            margin-top: 0 !important;
            background-color: #f4f4f4;
        }

        /* Horizontal Navigation Container - Second Row */
        .horizontal-nav-container {
            position: relative;
            width: 100%;
            background-color: #1a2226;
            border-bottom: 1px solid #374850;
            margin-top: 0 !important;
            z-index: 1000;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }

        /* Horizontal Navigation Menu */
        .horizontal-nav-menu {
            list-style: none;
            margin: 0;
            padding: 0;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 50px;
        }

        /* Horizontal Navigation Items */
        .horizontal-nav-item {
            margin: 0;
            padding: 0;
            position: relative;
        }

        .horizontal-nav-item a {
            display: flex;
            align-items: center;
            padding: 15px 25px;
            color: #b8c7ce;
            text-decoration: none;
            font-size: 14px;
            font-weight: 500;
            transition: all 0.3s ease;
            border-bottom: 3px solid transparent;
            height: 50px;
        }

        .horizontal-nav-item a i {
            margin-right: 8px;
            font-size: 16px;
        }

        .horizontal-nav-item a:hover {
            background-color: #243035;
            color: #ffffff;
        }

        /* Active tab styling with orange border */
        .horizontal-nav-item.active a {
            color: #ffffff;
            background-color: #2c3b41;
            border-bottom-color: #ff8c42 !important;
            border-bottom-width: 3px !important;
            border-bottom-style: solid !important;
        }

        /* Adjust content wrapper to accommodate navigation bar */
        .content-wrapper {
            margin-top: 0 !important;
            padding-top: 0 !important;
        }

        /* Remove spacing from content section */
        .content {
            min-height: auto !important;
            padding: 0 !important;
            margin: 0 !important;
        }

        /* Ensure tab content appears below navigation */
        .tab-content {
            margin-top: 0 !important;
            padding-top: 15px !important;
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

        /* Resizable graph visualization styles */
        .resizable-dag-container {
            position: relative;
            min-height: 400px;
            max-height: calc(100vh - 200px);
            height: calc(100vh - 300px);
            min-width: 400px;
            max-width: calc(100vw - 100px);
            width: 100%;
            border: 1px solid #ddd;
            border-radius: 4px;
            overflow: visible;
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
            right: 0;
            bottom: 0;
            width: 20px;
            height: 20px;
            background: #6c757d;
            cursor: nwse-resize;
            z-index: 1000;
            transition: all 0.2s ease;
            opacity: 0.6;
        }

        .dag-resize-handle:before {
            content: '';
            position: absolute;
            right: 2px;
            bottom: 2px;
            width: 0;
            height: 0;
            border-style: solid;
            border-width: 0 0 14px 14px;
            border-color: transparent transparent #ffffff transparent;
        }

        .dag-resize-handle:hover {
            opacity: 1;
            background: #007bff;
        }

        .dag-resize-handle:hover:before {
            border-color: transparent transparent #ffffff transparent;
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

        /* Responsive Two-Column Layout for Graph Visualization */
        .dag-responsive-layout {
            display: flex;
            flex-wrap: wrap;
            transition: all 0.3s ease;
        }

        .dag-graph-col {
            flex: 1 1 66.666%;
            min-width: 400px;
            transition: all 0.3s ease;
        }

        .dag-edge-col {
            flex: 1 1 33.333%;
            min-width: 300px;
            transition: all 0.3s ease;
        }

        /* When layout stacks (responsive breakpoint) */
        .dag-responsive-layout.stacked .dag-graph-col,
        .dag-responsive-layout.stacked .dag-edge-col {
            flex: 1 1 100%;
            max-width: 100%;
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

        /* Media query for narrow viewports - force stacking */
        @media (max-width: 1200px) {
            .dag-responsive-layout {
                flex-direction: column;
            }

            .dag-graph-col,
            .dag-edge-col {
                flex: 1 1 100%;
                max-width: 100%;
                width: 100%;
            }

            .resizable-dag-container {
                width: 100% !important;
            }
        }

        /* Progress Section Styling - Make it prominent and visible */
        /* Target both possible progress section IDs */
        #config-graph_progress_section,
        #config-progress_section {
            position: fixed !important;
            top: 60px !important;
            left: 50% !important;
            transform: translateX(-50%) !important;
            z-index: 9999 !important;
            width: 90% !important;
            max-width: 800px !important;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3) !important;
            animation: slideDown 0.3s ease-out !important;
        }

        /* Backdrop overlay when progress is shown */
        .progress-backdrop {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100% !important;
            height: 100% !important;
            background-color: rgba(0, 0, 0, 0.5) !important;
            z-index: 9998 !important;
            display: none !important;
        }

        .progress-backdrop.active {
            display: block !important;
        }

        /* Enhanced progress styling - Clean white box design */
        #config-graph_progress_section > div,
        #config-progress_section > div {
            background-color: #ffffff !important;
            padding: 25px 30px !important;
            border-radius: 10px !important;
            border: 4px solid #28a745 !important;
            box-shadow: 0 4px 20px rgba(40, 167, 69, 0.3) !important;
        }

        #config-graph_progress_section h4,
        #config-progress_section h4 {
            color: #28a745 !important;
            font-size: 22px !important;
            font-weight: bold !important;
            margin-top: 0 !important;
            margin-bottom: 20px !important;
            text-align: center !important;
        }

        #config-graph_progress_section .progress,
        #config-progress_section .progress {
            height: 40px !important;
            margin-bottom: 15px !important;
            font-size: 15px !important;
            background-color: #e9ecef !important;
            border: 2px solid #dee2e6 !important;
            border-radius: 20px !important;
            overflow: hidden !important;
        }

        #config-graph_progress_section .progress-bar,
        #config-progress_section .progress-bar {
            line-height: 40px !important;
            font-size: 15px !important;
            font-weight: bold !important;
            background: linear-gradient(90deg, #28a745 0%, #34ce57 100%) !important;
            color: white !important;
            text-shadow: 1px 1px 3px rgba(0,0,0,0.4) !important;
            border-radius: 20px !important;
        }

        #config-graph_progress_section p,
        #config-progress_section p,
        #config-graph_progress_section div,
        #config-progress_section div[id$='progress_status'] {
            font-size: 15px !important;
            margin: 8px 0 !important;
        }

        /* Slide down animation */
        @keyframes slideDown {
            from {
                opacity: 0;
                transform: translateX(-50%) translateY(-20px);
            }
            to {
                opacity: 1;
                transform: translateX(-50%) translateY(0);
            }
        }

        /* Responsive adjustments for progress section */
        @media (max-width: 768px) {
            #config-graph_progress_section,
            #config-progress_section {
                width: 95% !important;
                top: 10px !important;
            }
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
        // Navigation function for horizontal tabs
        function navigateToTab(tabName) {
            console.log('Navigating to tab:', tabName);

            // Remove active class from all nav items
            $('.horizontal-nav-item').removeClass('active');

            // Add active class to clicked nav item
            $('.horizontal-nav-item[data-value=\"' + tabName + '\"]').addClass('active');

            // Hide all tab content (shinydashboard uses .tab-pane class)
            $('.tab-pane').removeClass('active').removeClass('in');

            // Show selected tab content
            var targetTab = $('#shiny-tab-' + tabName);
            if (targetTab.length > 0) {
                targetTab.addClass('active').addClass('in');
            }

            // Update Shiny input value to trigger server-side observers (if needed)
            // Note: We don't set this anymore to avoid loops
            // if (typeof Shiny !== 'undefined') {
            //     Shiny.setInputValue('sidebar', tabName, {priority: 'event'});
            // }
        }

        function openCreateGraph() {
            // Navigate to the Graph Configuration tab
            navigateToTab('create_graph');
        }

        function openCausalAnalysis() {
            // Navigate to the Causal Analysis tab
            navigateToTab('causal');
        }

        // Initialize navigation on page load
        $(document).ready(function() {
            // Set initial active tab (About)
            navigateToTab('about');

            // Hide sidebar toggle button since we don't have a sidebar
            $('.sidebar-toggle').hide();
        });

        // Custom message handler for server-side navigation
        $(document).on('shiny:connected', function() {
            if (typeof Shiny !== 'undefined') {
                // Handle custom navigateToTab messages from server
                Shiny.addCustomMessageHandler('navigateToTab', function(message) {
                    console.log('Received navigateToTab message:', message);
                    if (message.tab) {
                        navigateToTab(message.tab);
                    }
                });
            }
        });

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
#' Returns JavaScript for graph visualization resize functionality
#' @return tags$script object
#' @keywords internal
get_dag_resize_javascript <- function() {
    tags$script(HTML("
        // Graph Visualization Resize Functionality with Responsive Layout Support
        function initializeDAGResize() {
            var isResizing = false;
            var startX = 0;
            var startY = 0;
            var startWidth = 0;
            var startHeight = 0;
            var container = null;
            var layoutRow = null;

            // Initialize resize functionality when DOM is ready
            $(document).ready(function() {
                setTimeout(function() {
                    setupResizeHandlers();
                    checkResponsiveLayout();
                }, 1000); // Delay to ensure elements are rendered
            });

            // Check and update responsive layout based on container width
            function checkResponsiveLayout() {
                layoutRow = $('#dag-main-row');
                container = $('.resizable-dag-container');

                if (layoutRow.length === 0 || container.length === 0) {
                    setTimeout(checkResponsiveLayout, 500);
                    return;
                }

                var containerWidth = container.width();
                var windowWidth = $(window).width();

                // Threshold: if container width exceeds 900px or window is narrow, stack the layout
                if (containerWidth > 900 || windowWidth < 1200) {
                    layoutRow.addClass('stacked');
                } else {
                    layoutRow.removeClass('stacked');
                }
            }

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
                    startX = e.clientX;
                    startY = e.clientY;
                    startWidth = container.width();
                    startHeight = container.height();

                    // Prevent text selection during resize
                    $('body').addClass('no-select');
                    e.preventDefault();
                });

                $(document).on('mousemove', function(e) {
                    if (!isResizing) return;

                    var deltaX = e.clientX - startX;
                    var deltaY = e.clientY - startY;
                    var newWidth = startWidth + deltaX;
                    var newHeight = startHeight + deltaY;

                    // Enforce min and max width constraints
                    var maxWidth = $(window).width() - 100;
                    newWidth = Math.max(400, Math.min(maxWidth, newWidth));

                    // Enforce min and max height constraints
                    var maxHeight = $(window).height() - 200;
                    newHeight = Math.max(400, Math.min(maxHeight, newHeight));

                    container.width(newWidth);
                    container.height(newHeight);

                    // Check if layout should be responsive based on new width
                    checkResponsiveLayout();

                    // Trigger resize event for visNetwork
                    if (window.Shiny && window.Shiny.onInputChange) {
                        window.Shiny.onInputChange('dag_container_dimensions', {
                            width: newWidth,
                            height: newHeight
                        });
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

            // Monitor window resize events
            $(window).on('resize', function() {
                checkResponsiveLayout();
            });
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

