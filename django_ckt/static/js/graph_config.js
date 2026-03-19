/**
 * Graph Configuration Page JavaScript
 * Handles CUI search, form validation, dynamic field enabling, and form submission
 */

// Global variables for URL endpoints (will be set from template inline script)
var searchCuiUrl;
var generateGraphUrl;
var checkStatusBaseUrl;  // Base URL for status polling, e.g. '/config/api/status/'

$(document).ready(function() {
    
    // Initialize dynamic threshold field activation
    initializeThresholdFields();
    
    // Setup CUI search for all three fields with appropriate search type
    setupCUISearch('exposure_cuis', 'exposure_search_results', 'exposure_cuis_selected', 'subject');
    setupCUISearch('outcome_cuis', 'outcome_search_results', 'outcome_cuis_selected', 'object');
    setupCUISearch('blocklist_cuis', 'blocklist_search_results', 'blocklist_cuis_selected', 'both');
    
    // Setup clear buttons
    setupClearButtons();
    
    // Setup form submission
    setupFormSubmission();
    
    // Setup predication type multi-select enhancement
    setupPredicationTypeSelect();
});

/**
 * Initialize threshold fields based on selected degree
 */
function initializeThresholdFields() {
    const degreeSelect = $('#degree');
    
    // Set initial state
    updateThresholdFields(degreeSelect.val());
    
    // Listen for degree changes
    degreeSelect.on('change', function() {
        updateThresholdFields($(this).val());
    });
}

/**
 * Update threshold fields based on selected degree
 * @param {string} degree - Selected degree value (1, 2, or 3)
 */
function updateThresholdFields(degree) {
    const degreeNum = parseInt(degree);
    
    // Enable/disable fields based on degree
    $('#min_pmids_degree1').prop('disabled', false).removeClass('threshold-field');
    
    if (degreeNum >= 2) {
        $('#min_pmids_degree2').prop('disabled', false).removeClass('threshold-field');
    } else {
        $('#min_pmids_degree2').prop('disabled', true).addClass('threshold-field');
    }
    
    if (degreeNum >= 3) {
        $('#min_pmids_degree3').prop('disabled', false).removeClass('threshold-field');
    } else {
        $('#min_pmids_degree3').prop('disabled', true).addClass('threshold-field');
    }
}

/**
 * Setup CUI search functionality for a field
 * @param {string} searchInputId - ID of the search input field
 * @param {string} resultsId - ID of the results container
 * @param {string} selectedInputId - ID of the selected CUIs textarea
 * @param {string} searchType - 'subject', 'object', or 'both'
 */
function setupCUISearch(searchInputId, resultsId, selectedInputId, searchType) {
    const searchInput = $('#' + searchInputId);
    const resultsDiv = $('#' + resultsId);
    const selectedInput = $('#' + selectedInputId);

    // Track sort state per results container
    var sortState = { col: null, asc: true };

    searchInput.on('keypress', function(e) {
        if (e.which === 13) { // Enter key
            e.preventDefault();
            const query = $(this).val().trim();

            if (query.length < 3) {
                resultsDiv.hide();
                return;
            }

            // Perform CUI search
            $.ajax({
                url: searchCuiUrl,
                method: 'GET',
                data: { q: query, type: searchType },
                success: function(response) {
                    if (response.success && response.results.length > 0) {
                        sortState = { col: null, asc: true };
                        renderResultsTable(response.results, resultsDiv, selectedInput, sortState);
                        resultsDiv.show();
                    } else {
                        resultsDiv.html('<div class="cui-no-results">No results found</div>').show();
                    }
                },
                error: function() {
                    resultsDiv.html('<div class="cui-no-results text-danger">Error searching CUIs</div>').show();
                }
            });
        }
    });
}

/**
 * Format semtype_definition array for display
 * @param {Array} defs - array of definition strings
 * @returns {string} formatted string
 */
function formatDefinition(defs) {
    if (!defs || defs.length === 0) return '';
    return defs.join(', ');
}

/**
 * Render search results as a scrollable table
 * @param {Array} results - Array of result objects
 * @param {jQuery} resultsDiv - Container element
 * @param {jQuery} selectedInput - The selected CUIs textarea
 * @param {Object} sortState - Current sort state {col, asc}
 */
function renderResultsTable(results, resultsDiv, selectedInput, sortState) {
    resultsDiv.empty();

    // Column definitions: key, label, data accessor
    var columns = [
        { key: 'cui',        label: 'CUI',        accessor: function(r) { return r.cui; } },
        { key: 'name',       label: 'Name',        accessor: function(r) { return r.name; } },
        { key: 'definition', label: 'Definition',  accessor: function(r) { return formatDefinition(r.semtype_definition); } },
        { key: 'type',       label: 'Type',         accessor: function(r) { return formatDefinition(r.semtype); } }
    ];

    // Sort results if a column is selected
    if (sortState.col !== null) {
        var sortCol = columns.find(function(c) { return c.key === sortState.col; });
        if (sortCol) {
            var asc = sortState.asc;
            results = results.slice().sort(function(a, b) {
                var valA = (sortCol.accessor(a) || '').toLowerCase();
                var valB = (sortCol.accessor(b) || '').toLowerCase();
                if (valA < valB) return asc ? -1 : 1;
                if (valA > valB) return asc ? 1 : -1;
                return 0;
            });
        }
    }

    // Build table
    var table = $('<table class="cui-results-table"></table>');

    // Header
    var thead = $('<thead></thead>');
    var headerRow = $('<tr></tr>');
    headerRow.append('<th class="cui-col-num">#</th>');

    columns.forEach(function(col) {
        var th = $('<th class="cui-col-sortable cui-col-' + col.key + '"></th>');
        var arrow = '';
        if (sortState.col === col.key) {
            arrow = sortState.asc ? ' ▲' : ' ▼';
        } else {
            arrow = ' ⇅';
        }
        th.html(col.label + '<span class="sort-arrow">' + arrow + '</span>');
        th.on('click', function() {
            if (sortState.col === col.key) {
                sortState.asc = !sortState.asc;
            } else {
                sortState.col = col.key;
                sortState.asc = true;
            }
            renderResultsTable(results, resultsDiv, selectedInput, sortState);
        });
        headerRow.append(th);
    });
    thead.append(headerRow);
    table.append(thead);

    // Body
    var tbody = $('<tbody></tbody>');
    results.forEach(function(item, idx) {
        var rowClass = 'cui-result-row' + (idx % 2 === 1 ? ' cui-row-stripe' : '');
        var row = $('<tr class="' + rowClass + '"></tr>');
        row.append('<td class="cui-col-num">' + (idx + 1) + '</td>');
        row.append('<td class="cui-col-cui"><span class="cui-code">' + item.cui + '</span></td>');
        row.append('<td class="cui-col-name">' + item.name + '</td>');
        row.append('<td class="cui-col-def">' + formatDefinition(item.semtype_definition) + '</td>');
        row.append('<td class="cui-col-type">' + formatDefinition(item.semtype) + '</td>');
        row.on('click', function() {
            addCUIToSelected(item.cui, selectedInput);
            $(this).addClass('cui-row-selected');
            setTimeout(function() { row.removeClass('cui-row-selected'); }, 600);
        });
        tbody.append(row);
    });
    table.append(tbody);

    resultsDiv.append(table);
}

/**
 * Add CUI to selected list (prevents duplicates)
 * @param {string} cui - CUI code to add
 * @param {jQuery} selectedInput - jQuery object of the selected CUIs textarea
 */
function addCUIToSelected(cui, selectedInput) {
    let currentCUIs = selectedInput.val().trim();
    
    // Parse existing CUIs
    let cuisArray = currentCUIs ? currentCUIs.split(',').map(c => c.trim()) : [];
    
    // Check if CUI already exists (prevent duplicates)
    if (cuisArray.includes(cui)) {
        // Show brief notification that CUI already exists
        showBriefNotification(selectedInput, 'CUI already selected');
        return;
    }
    
    // Add new CUI
    cuisArray.push(cui);
    selectedInput.val(cuisArray.join(', '));
}

/**
 * Show a brief notification near an input field
 * @param {jQuery} element - jQuery object near which to show notification
 * @param {string} message - Message to display
 */
function showBriefNotification(element, message) {
    const notification = $('<div class="brief-notification"></div>')
        .text(message)
        .css({
            'position': 'absolute',
            'background-color': '#ffc107',
            'color': '#000',
            'padding': '5px 10px',
            'border-radius': '4px',
            'font-size': '0.875rem',
            'z-index': '1000',
            'box-shadow': '0 2px 4px rgba(0,0,0,0.2)'
        });

    element.parent().css('position', 'relative').append(notification);

    setTimeout(function() {
        notification.fadeOut(300, function() {
            $(this).remove();
        });
    }, 2000);
}

/**
 * Setup clear buttons for CUI fields
 */
function setupClearButtons() {
    $('#clear_exposure').on('click', function() {
        $('#exposure_cuis_selected').val('');
    });

    $('#clear_outcome').on('click', function() {
        $('#outcome_cuis_selected').val('');
    });

    $('#clear_blocklist').on('click', function() {
        $('#blocklist_cuis_selected').val('');
    });
}

/**
 * Setup predication type multi-select with visual feedback
 */
function setupPredicationTypeSelect() {
    const predicationSelect = $('#PREDICATION_TYPE');

    // Add visual feedback on selection
    predicationSelect.on('change', function() {
        updatePredicationTypeVisuals();
    });

    // Initialize visual state
    updatePredicationTypeVisuals();
}

/**
 * Update visual feedback for predication type selections
 */
function updatePredicationTypeVisuals() {
    const predicationSelect = $('#PREDICATION_TYPE');
    const selectedValues = predicationSelect.val() || [];

    // Update option styling
    predicationSelect.find('option').each(function() {
        if (selectedValues.includes($(this).val())) {
            $(this).css({
                'background-color': '#3c8dbc',
                'color': 'white',
                'font-weight': 'bold'
            });
        } else {
            $(this).css({
                'background-color': '',
                'color': '',
                'font-weight': ''
            });
        }
    });
}

/**
 * Setup form submission handler
 */
function setupFormSubmission() {
    $('#graphConfigForm').on('submit', function(e) {
        e.preventDefault();

        // Show progress section
        $('#graph_progress_section').show();
        $('#create_graph_btn').prop('disabled', true);

        // Collect form data
        const formData = {
            exposure_cuis: $('#exposure_cuis_selected').val(),
            exposure_name: $('#exposure_name').val(),
            outcome_cuis: $('#outcome_cuis_selected').val(),
            outcome_name: $('#outcome_name').val(),
            blocklist_cuis: $('#blocklist_cuis_selected').val(),
            degree: $('#degree').val(),
            min_pmids_degree1: $('#min_pmids_degree1').val(),
            min_pmids_degree2: $('#min_pmids_degree2').val(),
            min_pmids_degree3: $('#min_pmids_degree3').val(),
            pub_year_cutoff: $('#pub_year_cutoff').val(),
            predication_type: $('#PREDICATION_TYPE').val(),
            semmeddb_version: $('#SemMedDBD_version').val()
        };

        // Submit to API
        $.ajax({
            url: generateGraphUrl,
            method: 'POST',
            headers: {
                'X-CSRFToken': $('[name=csrfmiddlewaretoken]').val()
            },
            contentType: 'application/json',
            data: JSON.stringify(formData),
            success: handleFormSuccess,
            error: handleFormError
        });
    });
}

/**
 * Handle successful form submission
 * @param {Object} response - Server response
 */
function handleFormSuccess(response) {
    if (response.success && response.task_id) {
        // Show "in progress" state - start at 0% for consistent progress tracking
        $('#graph_progress_text').text('Initializing...');
        $('#graph_progress_bar').css('width', '0%');
        $('#graph_progress_status').html(
            '<strong style="color: #17a2b8;"><i class="fas fa-spinner fa-spin"></i> ' +
            response.message + '</strong>'
        );

        // Update validation feedback to show in-progress
        $('#validation_feedback_area').html(
            '<div class="alert alert-info mb-0">' +
            '<i class="fas fa-spinner fa-spin"></i> ' +
            '<strong>Graph creation started...</strong><br>' +
            'Please wait while the graph is being generated. This may take several minutes.' +
            '</div>'
        );

        // Start polling for task completion
        pollTaskStatus(response.task_id);
    } else if (response.success) {
        // Fallback for responses without task_id
        showGraphSuccess(response);
    } else {
        showFormError(response.error);
    }
}

/**
 * Poll the task status endpoint until the task completes or fails
 * @param {string} taskId - The task ID to poll
 */
function pollTaskStatus(taskId) {
    var statusUrl = checkStatusBaseUrl + taskId + '/';
    var pollInterval = 5000;  // Poll every 5 seconds (reduced frequency)
    var maxRetries = 1000;    // 1000 * 5 seconds = ~83 minutes max polling time
    var retryCount = 0;
    var consecutiveErrors = 0;

    var poller = setInterval(function() {
        retryCount++;

        // Check if we've exceeded maximum polling time
        if (retryCount > maxRetries) {
            clearInterval(poller);
            showFormError('Graph creation is taking longer than expected. Please check the logs or try again.');
            return;
        }

        $.ajax({
            url: statusUrl,
            method: 'GET',
            timeout: 30000,  // 30 second timeout for each request
            success: function(statusResponse) {
                consecutiveErrors = 0;  // Reset error counter on success

                if (statusResponse.status === 'completed') {
                    clearInterval(poller);
                    showGraphSuccess(statusResponse);
                } else if (statusResponse.status === 'failed') {
                    clearInterval(poller);
                    showGraphFailure(statusResponse);
                } else if (statusResponse.status === 'running') {
                    // Update progress message if available
                    if (statusResponse.message) {
                        $('#graph_progress_status').html(
                            '<strong style="color: #17a2b8;"><i class="fas fa-spinner fa-spin"></i> ' +
                            statusResponse.message + '</strong>'
                        );
                    }

                    // Update progress bar with smooth incremental progress
                    // Use a more gradual progress calculation that doesn't reset
                    var baseProgress = 10; // Start with 10% after first successful poll
                    var timeProgress = Math.min(80, (retryCount / maxRetries) * 80); // Max 80% from time
                    var totalProgress = baseProgress + timeProgress;

                    // Update progress bar text based on progress level
                    var progressText = 'Graph creation in progress...';
                    if (totalProgress < 30) {
                        progressText = 'Initializing graph creation...';
                    } else if (totalProgress < 60) {
                        progressText = 'Processing graph data...';
                    } else if (totalProgress < 85) {
                        progressText = 'Building graph structure...';
                    } else {
                        progressText = 'Finalizing graph...';
                    }

                    $('#graph_progress_bar').css('width', totalProgress + '%');
                    $('#graph_progress_text').text(progressText);
                }
                // If still 'running', keep polling
            },
            error: function(xhr, status, error) {
                consecutiveErrors++;
                console.warn('Status check failed (attempt ' + consecutiveErrors + '): ' + error);

                // Only fail after many consecutive errors (not just network blips)
                if (consecutiveErrors > 120) {  // 120 consecutive errors = 10 minutes of failures
                    clearInterval(poller);
                    showFormError('Lost connection while checking graph creation status. The process may still be running in the background. Please check the logs.');
                } else if (consecutiveErrors > 30) {
                    // Show warning but keep trying
                    $('#graph_progress_status').html(
                        '<strong style="color: #ffc107;"><i class="fas fa-exclamation-triangle"></i> ' +
                        'Connection issues detected, but still trying... (' + consecutiveErrors + ' errors)</strong>'
                    );
                }
            }
        });
    }, pollInterval);
}
var logger_warn_count = 0;

/**
 * Show the success state after graph creation is confirmed complete
 * @param {Object} response - Status response with graph details
 */
function showGraphSuccess(response) {
    $('#graph_progress_text').text('Graph created!');
    $('#graph_progress_bar').css('width', '100%').removeClass('progress-bar-animated');
    $('#graph_progress_status').html('<strong style="color: #28a745;">✓ ' + (response.message || 'Graph created successfully!') + '</strong>');

    // Hide progress and show success message after 2 seconds
    setTimeout(function() {
        $('#graph_progress_section').hide();
        $('#create_graph_btn').prop('disabled', false);

        // Build a descriptive body for the notification
        var notifBody = response.message || 'Your knowledge graph has been created and is ready to use.';
        if (response.graph_name) {
            notifBody = 'Graph "' + response.graph_name + '" created'
                + (response.degree ? ' (degree ' + response.degree + ')' : '')
                + ' — Go to Data Upload to load and visualize your graph.';
        }

        // Show top notification banner
        if (typeof showTopNotification === 'function') {
            showTopNotification({
                title: 'Graph Created Successfully!',
                body: notifBody,
                type: 'success',
                duration: 0,
                action: { text: 'Go to Data Upload', url: '/upload/' }
            });
        }

        // Update validation feedback to show success
        $('#validation_feedback_area').html(
            '<div class="alert alert-success mb-0">' +
            '<i class="fas fa-check-circle"></i> ' +
            '<strong>Graph Created!</strong><br>' +
            (response.message || 'Graph created successfully!') +
            '</div>'
        );

        // Reset validation feedback after 5 seconds
        setTimeout(function() {
            $('#validation_feedback_area').html(
                '<div class="alert alert-success-custom mb-0">' +
                '<i class="fas fa-check-circle"></i> ' +
                '<strong> Ready to create graph</strong><br>' +
                'All inputs are valid. Click \'Create Graph\' to proceed.' +
                '</div>'
            );
        }, 5000);
    }, 2000);
}

/**
 * Show the failure state after graph creation fails
 * @param {Object} response - Status response with error details
 */
function showGraphFailure(response) {
    $('#graph_progress_text').text('Graph creation failed');
    $('#graph_progress_bar')
        .css('width', '100%')
        .removeClass('progress-bar-animated progress-bar-striped')
        .addClass('bg-danger');
    $('#graph_progress_status').html(
        '<strong style="color: #dc3545;"><i class="fas fa-times-circle"></i> ' +
        (response.message || 'Graph creation failed.') + '</strong>'
    );

    setTimeout(function() {
        $('#graph_progress_section').hide();
        $('#create_graph_btn').prop('disabled', false);
    }, 3000);

    showFormError(response.message || 'Graph creation failed.');
}

/**
 * Handle form submission error
 * @param {Object} xhr - XMLHttpRequest object
 */
function handleFormError(xhr) {
    let errorMsg = 'Error submitting form';
    if (xhr.responseJSON && xhr.responseJSON.error) {
        errorMsg = xhr.responseJSON.error;
    }
    showFormError(errorMsg);
}

/**
 * Show error message in validation feedback area
 * @param {string} errorMsg - Error message to display
 */
function showFormError(errorMsg) {
    $('#graph_progress_section').hide();
    $('#create_graph_btn').prop('disabled', false);

    // Show error in validation feedback
    $('#validation_feedback_area').html(
        '<div class="alert alert-danger mb-0">' +
        '<i class="fas fa-exclamation-circle"></i> ' +
        '<strong>Error:</strong> ' + errorMsg +
        '</div>'
    );
}

