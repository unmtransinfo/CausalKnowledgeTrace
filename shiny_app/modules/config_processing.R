# Graph Configuration Processing Module
# 
# This module contains YAML processing, file operations, and graph creation logic
# for the graph configuration functionality.
#
# Author: Refactored from graph_config_module.R
# Date: February 2025

# Required libraries
if (!require(yaml)) {
    message("Installing yaml package...")
    install.packages("yaml")
    library(yaml)
}

#' Create YAML Configuration
#' 
#' Creates a YAML configuration from validated parameters
#' 
#' @param validated_params List of validated configuration parameters
#' @return Character string containing YAML content
create_yaml_config <- function(validated_params) {
    # Support both old format (min_pmids) and new format (min_pmids_degree1/2/3)
    config_list <- list(
        exposure_cuis = validated_params$exposure_cuis,
        outcome_cuis = validated_params$outcome_cuis,
        blacklist_cuis = validated_params$blacklist_cuis,
        exposure_name = validated_params$exposure_name,
        outcome_name = validated_params$outcome_name,
        pub_year_cutoff = validated_params$pub_year_cutoff,
        degree = validated_params$degree,
        predication_type = validated_params$predication_types,
        SemMedDBD_version = validated_params$semmeddb_version,
        created_timestamp = Sys.time(),
        created_by = "Causal Web Shiny Application"
    )

    # Add threshold fields - prefer new format if available
    if (!is.null(validated_params$min_pmids_degree1)) {
        config_list$min_pmids_degree1 = validated_params$min_pmids_degree1
        config_list$min_pmids_degree2 = validated_params$min_pmids_degree2
        config_list$min_pmids_degree3 = validated_params$min_pmids_degree3
    } else if (!is.null(validated_params$min_pmids)) {
        # Backward compatibility - save as old format
        config_list$min_pmids = validated_params$min_pmids
    }

    # Convert to YAML
    yaml_content <- yaml::as.yaml(config_list, indent = 2)
    return(yaml_content)
}

#' Save Configuration to File
#' 
#' Saves the configuration to a YAML file
#' 
#' @param validated_params List of validated configuration parameters
#' @param output_dir Character string path to output directory
#' @return List with save operation results
save_config_file <- function(validated_params, output_dir = "../graph_creation") {
    tryCatch({
        # Ensure output directory exists
        if (!dir.exists(output_dir)) {
            dir.create(output_dir, recursive = TRUE)
        }
        
        # Create YAML content
        yaml_content <- create_yaml_config(validated_params)
        
        # Save to file
        config_file <- file.path(output_dir, "user_input.yaml")
        writeLines(yaml_content, config_file)
        
        return(list(
            success = TRUE,
            file_path = config_file,
            message = paste("Configuration saved to", config_file)
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error saving configuration:", e$message)
        ))
    })
}

#' Execute Graph Creation Script
#'
#' Executes the Python graph creation script with the saved configuration
#'
#' @param config_file_path Character string path to the configuration file
#' @param python_script_path Character string path to the Python script
#' @return List with execution results
execute_graph_creation <- function(config_file_path = "../graph_creation/user_input.yaml",
                                 python_script_path = "../graph_creation/pushkin.py") {
    tryCatch({
        # Check if files exist
        if (!file.exists(config_file_path)) {
            return(list(
                success = FALSE,
                message = paste("Configuration file not found:", config_file_path)
            ))
        }

        if (!file.exists(python_script_path)) {
            return(list(
                success = FALSE,
                message = paste("Python script not found:", python_script_path)
            ))
        }

        # Construct command
        cmd <- paste("cd", dirname(python_script_path), "&&",
                    "python", basename(python_script_path),
                    "--yaml-config", basename(config_file_path),
                    "--host localhost --user myuser --password mypass --dbname causalehr")

        # Execute command and capture exit code
        # Note: We need to capture the exit code separately from the output
        exit_code <- system(cmd, wait = TRUE)

        # Check if execution was successful (exit code 0)
        if (exit_code == 0) {
            return(list(
                success = TRUE,
                exit_code = exit_code,
                message = "Graph creation completed successfully"
            ))
        } else {
            return(list(
                success = FALSE,
                exit_code = exit_code,
                message = paste("Graph creation script failed with exit code:", exit_code, ". Check the console output for details.")
            ))
        }

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error executing graph creation:", e$message)
        ))
    })
}

#' Check Generated Files
#' 
#' Checks for files generated by the graph creation process
#' 
#' @param output_dir Character string path to output directory
#' @return List with information about generated files
check_generated_files <- function(output_dir = "../graph_creation/output") {
    tryCatch({
        if (!dir.exists(output_dir)) {
            return(list(
                success = FALSE,
                message = "Output directory not found",
                files = character(0)
            ))
        }
        
        # Look for common output files
        expected_files <- c(
            "degree_1.R", "degree_2.R", "degree_3.R",
            "causal_assertions_1.json", "causal_assertions_2.json", "causal_assertions_3.json",
            "run_configuration.json",
            "MarkovBlanket_Union.R"
        )

        found_files <- character(0)
        for (file in expected_files) {
            file_path <- file.path(output_dir, file)
            if (file.exists(file_path)) {
                found_files <- c(found_files, file)
            }
        }
        
        # Also check for any .R files
        r_files <- list.files(output_dir, pattern = "\\.R$", full.names = FALSE)
        all_files <- unique(c(found_files, r_files))
        
        return(list(
            success = TRUE,
            files = all_files,
            count = length(all_files),
            output_dir = output_dir
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error checking generated files:", e$message),
            files = character(0)
        ))
    })
}

#' Load Configuration from YAML File
#' 
#' Loads and parses a YAML configuration file
#' 
#' @param file_path Character string path to YAML file
#' @return List with loaded configuration
load_yaml_config <- function(file_path) {
    tryCatch({
        if (!file.exists(file_path)) {
            return(list(
                success = FALSE,
                message = paste("Configuration file not found:", file_path)
            ))
        }
        
        # Read and parse YAML
        config_data <- yaml::read_yaml(file_path)
        
        # Validate required fields
        required_fields <- c("exposure_cuis", "outcome_cuis", "min_pmids")
        missing_fields <- setdiff(required_fields, names(config_data))
        
        if (length(missing_fields) > 0) {
            return(list(
                success = FALSE,
                message = paste("Missing required fields:", paste(missing_fields, collapse = ", "))
            ))
        }
        
        return(list(
            success = TRUE,
            config = config_data,
            message = "Configuration loaded successfully"
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading configuration:", e$message)
        ))
    })
}

#' Create Configuration Summary
#' 
#' Creates a human-readable summary of the configuration
#' 
#' @param validated_params List of validated configuration parameters
#' @return Character string containing configuration summary
create_config_summary <- function(validated_params) {
    summary_text <- paste0(
        "Configuration Summary\n",
        "====================\n",
        "Exposure CUIs: ", paste(validated_params$exposure_cuis, collapse = ", "),
        " (", length(validated_params$exposure_cuis), " CUIs)\n",
        "Exposure Name: ", validated_params$exposure_name, "\n",
        "Outcome CUIs: ", paste(validated_params$outcome_cuis, collapse = ", "),
        " (", length(validated_params$outcome_cuis), " CUIs)\n",
        "Outcome Name: ", validated_params$outcome_name, "\n",
        if (length(validated_params$blacklist_cuis) > 0) {
            paste0("Blacklist CUIs: ", paste(validated_params$blacklist_cuis, collapse = ", "),
                   " (", length(validated_params$blacklist_cuis), " CUIs)\n")
        } else {
            "Blacklist CUIs: None\n"
        },
        # Support both old and new format for thresholds
        if (!is.null(validated_params$min_pmids_degree1)) {
            paste0("Minimum PMIDs (Degree 1): ", validated_params$min_pmids_degree1, "\n",
                   "Minimum PMIDs (Degree 2): ", validated_params$min_pmids_degree2, "\n",
                   "Minimum PMIDs (Degree 3): ", validated_params$min_pmids_degree3, "\n")
        } else {
            paste0("Minimum PMIDs: ", validated_params$min_pmids, "\n")
        },
        "Publication Year Cutoff: ", validated_params$pub_year_cutoff, "\n",
        "Degree: ", validated_params$degree, "\n",
        "SemMedDB Version: ", validated_params$semmeddb_version, "\n",
        "Predication Type: ", if (is.character(validated_params$predication_types) && length(validated_params$predication_types) == 1) {
            validated_params$predication_types
        } else {
            paste(validated_params$predication_types, collapse = ", ")
        }, "\n"
    )
    
    return(summary_text)
}

#' Estimate Processing Time
#' 
#' Provides an estimate of processing time based on configuration parameters
#' 
#' @param validated_params List of validated configuration parameters
#' @return Character string with time estimate
estimate_processing_time <- function(validated_params) {
    # Simple heuristic based on number of CUIs and k-hops
    total_cuis <- length(validated_params$exposure_cuis) + length(validated_params$outcome_cuis)
    degree <- validated_params$degree
    min_pmids <- validated_params$min_pmids
    
    # Base time estimate (in minutes)
    base_time <- 2
    cui_factor <- total_cuis * 0.5
    hop_factor <- degree * 1.5
    pmid_factor <- max(0, (50 - min_pmids) / 10)  # Lower thresholds take longer
    
    estimated_minutes <- base_time + cui_factor + hop_factor + pmid_factor
    
    if (estimated_minutes < 1) {
        return("Less than 1 minute")
    } else if (estimated_minutes < 60) {
        return(paste(round(estimated_minutes), "minutes"))
    } else {
        hours <- floor(estimated_minutes / 60)
        minutes <- round(estimated_minutes %% 60)
        return(paste(hours, "hours", minutes, "minutes"))
    }
}

#' Create Download Configuration
#' 
#' Creates a downloadable configuration file
#' 
#' @param validated_params List of validated configuration parameters
#' @return List with download information
create_download_config <- function(validated_params) {
    tryCatch({
        # Create YAML content
        yaml_content <- create_yaml_config(validated_params)
        
        # Create filename with timestamp
        timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
        filename <- paste0("causal_config_", timestamp, ".yaml")
        
        return(list(
            success = TRUE,
            content = yaml_content,
            filename = filename,
            content_type = "text/yaml"
        ))
        
    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error creating download configuration:", e$message)
        ))
    })
}
