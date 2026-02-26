# Progress Tracking System for Large Graph Operations
# 
# This module provides comprehensive progress tracking for long-running
# graph loading and processing operations with Shiny integration.

library(shiny)

# Global progress tracking environment
.progress_tracker <- new.env(parent = emptyenv())

#' Initialize Progress Tracker
#' 
#' Sets up the progress tracking system
#' 
#' @param session Shiny session object (optional)
#' @export
init_progress_tracker <- function(session = NULL) {
    .progress_tracker$session <- session
    .progress_tracker$current_operation <- NULL
    .progress_tracker$operations <- list()
    .progress_tracker$enabled <- TRUE
    
    cat("Progress tracker initialized\n")
}

#' Start Progress Operation
#' 
#' Begins tracking progress for a long-running operation
#' 
#' @param operation_id Unique identifier for the operation
#' @param title Operation title for display
#' @param total_steps Total number of steps (optional)
#' @param show_modal Whether to show progress modal in Shiny (default: TRUE)
#' @return Progress object
#' @export
start_progress <- function(operation_id, title, total_steps = NULL, show_modal = TRUE) {
    if (!.progress_tracker$enabled) {
        return(NULL)
    }
    
    progress_obj <- list(
        id = operation_id,
        title = title,
        total_steps = total_steps,
        current_step = 0,
        start_time = Sys.time(),
        last_update = Sys.time(),
        status = "running",
        messages = character(0),
        show_modal = show_modal,
        shiny_progress = NULL
    )
    
    # Create Shiny progress object if session is available
    if (!is.null(.progress_tracker$session) && show_modal) {
        tryCatch({
            progress_obj$shiny_progress <- Progress$new(.progress_tracker$session, min = 0, max = 1)
            progress_obj$shiny_progress$set(message = title, value = 0)
        }, error = function(e) {
            cat("Warning: Could not create Shiny progress object:", e$message, "\n")
            progress_obj$shiny_progress <- NULL
        })
    }
    
    .progress_tracker$operations[[operation_id]] <- progress_obj
    .progress_tracker$current_operation <- operation_id
    
    cat("Started progress tracking:", title, "\n")
    return(progress_obj)
}

#' Update Progress
#' 
#' Updates progress for the current operation
#' 
#' @param operation_id Operation identifier
#' @param step Current step number (optional)
#' @param message Progress message
#' @param value Progress value between 0 and 1 (optional)
#' @export
update_progress <- function(operation_id = NULL, step = NULL, message = NULL, value = NULL) {
    if (!.progress_tracker$enabled) {
        return()
    }
    
    # Use current operation if not specified
    if (is.null(operation_id)) {
        operation_id <- .progress_tracker$current_operation
    }
    
    if (is.null(operation_id) || !operation_id %in% names(.progress_tracker$operations)) {
        return()
    }
    
    progress_obj <- .progress_tracker$operations[[operation_id]]
    
    # Update step
    if (!is.null(step)) {
        progress_obj$current_step <- step
    }
    
    # Calculate progress value
    if (is.null(value) && !is.null(progress_obj$total_steps) && progress_obj$total_steps > 0) {
        value <- progress_obj$current_step / progress_obj$total_steps
    }
    
    # Add message
    if (!is.null(message)) {
        progress_obj$messages <- c(progress_obj$messages, paste(Sys.time(), "-", message))
        cat("Progress:", message, "\n")
    }
    
    progress_obj$last_update <- Sys.time()
    
    # Update Shiny progress
    if (!is.null(progress_obj$shiny_progress)) {
        tryCatch({
            if (!is.null(value)) {
                progress_obj$shiny_progress$set(value = value, message = message)
            } else {
                progress_obj$shiny_progress$set(message = message)
            }
        }, error = function(e) {
            cat("Warning: Could not update Shiny progress:", e$message, "\n")
            progress_obj$shiny_progress <- NULL
        })
    }
    
    .progress_tracker$operations[[operation_id]] <- progress_obj
}

#' Finish Progress Operation
#' 
#' Completes progress tracking for an operation
#' 
#' @param operation_id Operation identifier
#' @param success Whether the operation was successful (default: TRUE)
#' @param final_message Final status message
#' @export
finish_progress <- function(operation_id = NULL, success = TRUE, final_message = NULL) {
    if (!.progress_tracker$enabled) {
        return()
    }
    
    # Use current operation if not specified
    if (is.null(operation_id)) {
        operation_id <- .progress_tracker$current_operation
    }
    
    if (is.null(operation_id) || !operation_id %in% names(.progress_tracker$operations)) {
        return()
    }
    
    progress_obj <- .progress_tracker$operations[[operation_id]]
    
    # Update final status
    progress_obj$status <- if (success) "completed" else "failed"
    progress_obj$end_time <- Sys.time()
    progress_obj$duration <- as.numeric(progress_obj$end_time - progress_obj$start_time)
    
    if (!is.null(final_message)) {
        progress_obj$messages <- c(progress_obj$messages, paste(Sys.time(), "-", final_message))
    }
    
    # Close Shiny progress
    if (!is.null(progress_obj$shiny_progress)) {
        tryCatch({
            if (success) {
                progress_obj$shiny_progress$set(value = 1, message = final_message %||% "Completed")
            }
            progress_obj$shiny_progress$close()
        }, error = function(e) {
            cat("Warning: Could not close Shiny progress:", e$message, "\n")
        }, finally = {
            progress_obj$shiny_progress <- NULL
        })
    }
    
    .progress_tracker$operations[[operation_id]] <- progress_obj
    
    # Clear current operation if it was this one
    if (.progress_tracker$current_operation == operation_id) {
        .progress_tracker$current_operation <- NULL
    }
    
    cat("Finished progress tracking:", progress_obj$title, "- Duration:", round(progress_obj$duration, 2), "seconds\n")
}

#' Get Progress Status
#' 
#' Returns current progress status for an operation
#' 
#' @param operation_id Operation identifier
#' @return List containing progress information
#' @export
get_progress_status <- function(operation_id = NULL) {
    if (!.progress_tracker$enabled) {
        return(NULL)
    }
    
    # Use current operation if not specified
    if (is.null(operation_id)) {
        operation_id <- .progress_tracker$current_operation
    }
    
    if (is.null(operation_id) || !operation_id %in% names(.progress_tracker$operations)) {
        return(NULL)
    }
    
    return(.progress_tracker$operations[[operation_id]])
}

#' Create Progress Wrapper Function
#' 
#' Creates a wrapper function that automatically tracks progress
#' 
#' @param func Function to wrap
#' @param operation_title Title for the operation
#' @param steps Vector of step descriptions
#' @return Wrapped function with progress tracking
#' @export
with_progress <- function(func, operation_title, steps = NULL) {
    function(...) {
        operation_id <- paste0("op_", as.integer(Sys.time()), "_", sample(1000, 1))
        
        # Start progress
        start_progress(operation_id, operation_title, length(steps))
        
        tryCatch({
            # Execute function with progress updates
            if (!is.null(steps)) {
                result <- func(..., progress_callback = function(step_idx, message = NULL) {
                    if (step_idx <= length(steps)) {
                        update_progress(operation_id, step_idx, message %||% steps[step_idx])
                    }
                })
            } else {
                result <- func(...)
            }
            
            # Finish successfully
            finish_progress(operation_id, TRUE, "Operation completed successfully")
            return(result)
            
        }, error = function(e) {
            # Finish with error
            finish_progress(operation_id, FALSE, paste("Error:", e$message))
            stop(e)
        })
    }
}

#' Progress-Aware DAG Loading
#' 
#' Loads DAG with progress tracking
#' 
#' @param filename File to load
#' @param prefer_optimized Whether to prefer optimized formats
#' @param use_cache Whether to use caching
#' @return DAG loading result with progress tracking
#' @export
load_dag_with_progress <- function(filename, prefer_optimized = TRUE, use_cache = TRUE) {
    operation_id <- paste0("load_dag_", as.integer(Sys.time()))
    
    # Define loading steps
    steps <- c(
        "Initializing file loading",
        "Checking cache",
        "Loading optimized format",
        "Loading R file",
        "Validating DAG",
        "Processing network data",
        "Finalizing"
    )
    
    start_progress(operation_id, paste("Loading DAG:", basename(filename)), length(steps))
    
    tryCatch({
        update_progress(operation_id, 1, "Checking file existence")
        
        # Check if file exists
        if (!file.exists(filename)) {
            result_path <- file.path("../graph_creation/result", filename)
            if (file.exists(result_path)) {
                filename <- result_path
            } else {
                finish_progress(operation_id, FALSE, "File not found")
                return(list(success = FALSE, message = paste("File", filename, "not found")))
            }
        }
        
        update_progress(operation_id, 2, "Checking cache for existing data")
        
        # Try cache first
        if (use_cache && exists("get_cached_dag")) {
            cache_params <- list(prefer_optimized = prefer_optimized)
            cached_result <- get_cached_dag(filename, cache_params)
            
            if (cached_result$success) {
                finish_progress(operation_id, TRUE, "Loaded from cache")
                return(list(
                    success = TRUE, 
                    message = paste("Successfully loaded DAG from cache:", basename(filename)), 
                    dag = cached_result$data$dag
                ))
            }
        }
        
        update_progress(operation_id, 3, "Attempting optimized format loading")
        
        # Try optimized formats
        dag_result <- NULL
        if (prefer_optimized) {
            optimized_result <- try_load_optimized_format(filename)
            if (optimized_result$success) {
                dag_result <- optimized_result
                update_progress(operation_id, 4, "Optimized format loaded successfully")
            } else {
                update_progress(operation_id, 4, "Falling back to R file format")
            }
        } else {
            update_progress(operation_id, 4, "Loading R file format")
        }
        
        # Load R file if needed
        if (is.null(dag_result)) {
            file_env <- new.env()
            source(filename, local = file_env)
            
            if (exists("g", envir = file_env) && !is.null(file_env$g)) {
                dag_result <- list(success = TRUE, message = paste("Successfully loaded DAG from", filename), dag = file_env$g)
            } else {
                finish_progress(operation_id, FALSE, "No 'g' variable found in R file")
                return(list(success = FALSE, message = paste("No 'g' variable found in", filename)))
            }
        }
        
        update_progress(operation_id, 5, "Validating DAG structure")
        
        # Validate DAG
        if (!dag_result$success) {
            finish_progress(operation_id, FALSE, "DAG loading failed")
            return(dag_result)
        }
        
        update_progress(operation_id, 6, "Processing network data")
        
        # Store in cache if successful
        if (use_cache && exists("store_cached_dag")) {
            cache_params <- list(prefer_optimized = prefer_optimized)
            store_cached_dag(filename, dag_result, cache_params)
        }
        
        update_progress(operation_id, 7, "Loading completed successfully")
        finish_progress(operation_id, TRUE, "DAG loaded and processed successfully")
        
        return(dag_result)
        
    }, error = function(e) {
        finish_progress(operation_id, FALSE, paste("Error:", e$message))
        return(list(success = FALSE, message = paste("Error loading", filename, ":", e$message)))
    })
}

#' Disable Progress Tracking
#' 
#' Disables progress tracking (useful for batch operations)
#' 
#' @export
disable_progress <- function() {
    .progress_tracker$enabled <- FALSE
    cat("Progress tracking disabled\n")
}

#' Enable Progress Tracking
#' 
#' Enables progress tracking
#' 
#' @export
enable_progress <- function() {
    .progress_tracker$enabled <- TRUE
    cat("Progress tracking enabled\n")
}

# Initialize progress tracker environment (minimal setup)
if (length(.progress_tracker) == 0) {
    .progress_tracker$session <- NULL
    .progress_tracker$current_operation <- NULL
    .progress_tracker$operations <- list()
    .progress_tracker$enabled <- FALSE
    cat("Progress tracker environment created (not initialized)\n")
}
