# Application UI Head Module
# This module contains CSS styles and JavaScript for the application
# Author: Refactored from app.R

#' Get Application CSS Styles
#'
#' Returns HTML tags with links to external CSS files
#' @return tagList with CSS link tags
#' @export
get_app_css_styles <- function() {
    tagList(
        tags$link(rel = "stylesheet", type = "text/css", href = "css/general-layout.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "css/header-navigation.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "css/graph-visualization.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "css/edge-information.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "css/progress-indicators.css"),
        tags$link(rel = "stylesheet", type = "text/css", href = "css/responsive-layout.css")
    )
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

