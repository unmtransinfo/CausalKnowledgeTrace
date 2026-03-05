/**
 * Graph Configuration Page JavaScript
 * Handles CUI search, form validation, dynamic field enabling, and form submission
 */

// Global variables for URL endpoints (will be set from template inline script)
var searchCuiUrl;
var generateGraphUrl;

$(document).ready(function() {
    
    // Initialize dynamic threshold field activation
    initializeThresholdFields();
    
    // Setup CUI search for all three fields
    setupCUISearch('exposure_cuis', 'exposure_search_results', 'exposure_cuis_selected');
    setupCUISearch('outcome_cuis', 'outcome_search_results', 'outcome_cuis_selected');
    setupCUISearch('blocklist_cuis', 'blocklist_search_results', 'blocklist_cuis_selected');
    
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
 */
function setupCUISearch(searchInputId, resultsId, selectedInputId) {
    const searchInput = $('#' + searchInputId);
    const resultsDiv = $('#' + resultsId);
    const selectedInput = $('#' + selectedInputId);
    
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
                data: { q: query },
                success: function(response) {
                    if (response.success && response.results.length > 0) {
                        resultsDiv.empty();
                        response.results.forEach(function(item) {
                            const resultItem = $('<div class="cui-result-item"></div>')
                                .html('<strong>' + item.cui + '</strong> - ' + item.name)
                                .on('click', function() {
                                    addCUIToSelected(item.cui, selectedInput);
                                    resultsDiv.hide();
                                });
                            resultsDiv.append(resultItem);
                        });
                        resultsDiv.show();
                    } else {
                        resultsDiv.html('<div class="cui-result-item">No results found</div>').show();
                    }
                },
                error: function() {
                    resultsDiv.html('<div class="cui-result-item text-danger">Error searching CUIs</div>').show();
                }
            });
        }
    });
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
    if (response.success) {
        $('#graph_progress_text').text('Graph created!');
        $('#graph_progress_bar').css('width', '100%').removeClass('progress-bar-animated');
        $('#graph_progress_status').html('<strong style="color: #28a745;">✓ ' + response.message + '</strong>');

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
                response.message +
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
    } else {
        showFormError(response.error);
    }
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

