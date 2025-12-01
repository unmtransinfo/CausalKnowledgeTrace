# File Upload Module
# 
# This module contains file upload functionality, file scanning, and DAG loading operations
# for the Causal Web Shiny application.
#
# Author: Refactored from data_upload.R
# Date: February 2025

#' Scan for DAG Files
#'
#' Scans for R files that might contain DAG definitions
#'
#' @param exclude_files Character vector of files to exclude from scanning
#' @return Character vector of potential DAG files
#' @export
scan_for_dag_files <- function(exclude_files = c("app.R", "dag_data.R", "dag_visualization.R",
                                                 "node_information.R", "statistics.R", "data_upload.R")) {
    # Look for R files that might contain DAG definitions in graph_creation/result directory
    # Since we're running from shiny_app/, we need to go up one level to reach graph_creation/
    
    search_dirs <- c(
        "../graph_creation/result",
        "../graph_creation/output", 
        "../graph_creation",
        "."
    )
    
    dag_files <- character(0)
    
    for (dir in search_dirs) {
        if (dir.exists(dir)) {
            r_files <- list.files(dir, pattern = "\\.R$", full.names = FALSE, ignore.case = TRUE)
            
            # Filter out excluded files
            r_files <- r_files[!r_files %in% exclude_files]
            
            # Check if files contain DAG-like content
            for (file in r_files) {
                full_path <- file.path(dir, file)
                tryCatch({
                    content <- readLines(full_path, n = 50, warn = FALSE)  # Read first 50 lines
                    
                    # Look for DAG indicators
                    if (any(grepl("dagitty|dag\\s*\\{|\\[exposure\\]|\\[outcome\\]", content, ignore.case = TRUE))) {
                        dag_files <- c(dag_files, file.path(dir, file))
                    }
                }, error = function(e) {
                    # Skip files that can't be read
                })
            }
        }
    }
    
    # Remove duplicates and return
    unique_files <- unique(basename(dag_files))
    
    if (length(unique_files) == 0) {
        cat("No DAG files found in search directories\n")
        return(character(0))
    }
    
    cat("Found", length(unique_files), "potential DAG files\n")
    return(unique_files)
}

#' Load DAG from File
#'
#' Loads a DAG object from an R file
#'
#' @param filename Character string path to the R file
#' @return List with success status and DAG object or error message
#' @export
load_dag_from_file <- function(filename) {
    # Check if filename is a full path or just a filename
    if (!file.exists(filename)) {
        # Try looking in the graph_creation/result directory (relative to project root)
        search_paths <- c(
            file.path("../graph_creation/result", filename),
            file.path("../graph_creation/output", filename),
            file.path("../graph_creation", filename),
            filename
        )
        
        file_found <- FALSE
        for (path in search_paths) {
            if (file.exists(path)) {
                filename <- path
                file_found <- TRUE
                break
            }
        }
        
        if (!file_found) {
            return(list(success = FALSE, message = paste("File not found:", filename)))
        }
    }
    
    tryCatch({
        # Source the file in a new environment to avoid conflicts
        env <- new.env()
        source(filename, local = env)
        
        # Look for DAG objects in the environment
        dag_candidates <- ls(env)
        dag_object <- NULL
        
        # Try to find a DAG object
        for (obj_name in dag_candidates) {
            obj <- get(obj_name, envir = env)
            if (inherits(obj, "dagitty")) {
                dag_object <- obj
                break
            }
        }
        
        # If no dagitty object found, try to evaluate common DAG variable names
        if (is.null(dag_object)) {
            common_names <- c("g", "dag", "my_dag", "graph", "causal_dag")
            for (name in common_names) {
                if (exists(name, envir = env)) {
                    obj <- get(name, envir = env)
                    if (inherits(obj, "dagitty")) {
                        dag_object <- obj
                        break
                    }
                }
            }
        }
        
        if (is.null(dag_object)) {
            return(list(success = FALSE, message = "No DAG object found in file"))
        }
        
        return(list(success = TRUE, dag = dag_object, filename = filename))
        
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error loading", filename, ":", e$message)))
    })
}

#' Load DAG from Path
#'
#' Loads a DAG object from a specific file path (used for uploaded files)
#'
#' @param file_path Character string path to the file
#' @return List with success status and DAG object or error message
#' @export
load_dag_from_path <- function(file_path) {
    if (!file.exists(file_path)) {
        return(list(success = FALSE, message = "File does not exist"))
    }
    
    tryCatch({
        # Read file content
        content <- readLines(file_path, warn = FALSE)
        
        # Check if it looks like a DAG file
        if (!any(grepl("dagitty|dag\\s*\\{", content, ignore.case = TRUE))) {
            return(list(success = FALSE, message = "File does not appear to contain a DAG definition"))
        }
        
        # Try to evaluate the content
        env <- new.env()
        
        # Source the file
        source(file_path, local = env)
        
        # Look for DAG objects
        dag_candidates <- ls(env)
        dag_object <- NULL
        
        for (obj_name in dag_candidates) {
            obj <- get(obj_name, envir = env)
            if (inherits(obj, "dagitty")) {
                dag_object <- obj
                break
            }
        }
        
        if (is.null(dag_object)) {
            # Try common variable names
            common_names <- c("g", "dag", "my_dag", "graph", "causal_dag")
            for (name in common_names) {
                if (exists(name, envir = env)) {
                    obj <- get(name, envir = env)
                    if (inherits(obj, "dagitty")) {
                        dag_object <- obj
                        break
                    }
                }
            }
        }
        
        if (is.null(dag_object)) {
            return(list(success = FALSE, message = "No valid DAG object found in uploaded file"))
        }
        
        return(list(success = TRUE, dag = dag_object))
        
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error processing uploaded file:", e$message)))
    })
}

#' Get Default DAG Files
#' 
#' Returns a list of default filenames to try loading
#' 
#' @return Vector of default filenames
#' @export
get_default_dag_files <- function() {
    return(c("graph.R", "my_dag.R", "dag.R", "consolidated.R"))
}

#' Create Example DAG
#'
#' Creates a simple example DAG for demonstration purposes
#'
#' @return dagitty DAG object
#' @export
create_example_dag <- function() {
    return(dagitty('dag {
        Exposure_Condition [exposure]
        Outcome_Condition [outcome]
        Age
        Gender
        Education
        Smoking
        Diabetes
        Cardiovascular_Disease

        Age -> Exposure_Condition
        Age -> Outcome_Condition
        Age -> Cardiovascular_Disease
        Gender -> Exposure_Condition
        Gender -> Outcome_Condition
        Education -> Outcome_Condition
        Smoking -> Exposure_Condition
        Smoking -> Cardiovascular_Disease
        Diabetes -> Exposure_Condition
        Diabetes -> Cardiovascular_Disease
        Exposure_Condition -> Cardiovascular_Disease
        Exposure_Condition -> Outcome_Condition
        Cardiovascular_Disease -> Outcome_Condition
    }'))
}

#' Create Fallback DAG
#' 
#' Creates a simple fallback DAG when no files are found
#' 
#' @return dagitty DAG object
#' @export
create_fallback_dag <- function() {
    return(dagitty('dag {
        Exposure_Condition [exposure]
        Outcome_Condition [outcome]
        Surgical_margins
        PeptidylDipeptidase_A
        TP73ARHGAP24
        Diarrhea
        Superoxides
        Neurohormones
        Cocaine
        Induction
        Excessive_daytime_somnolence
        resistance_education
        Fibromuscular_Dysplasia
        genotoxicity
        Pancreatic_Ductal_Adenocarcinoma
        Gadolinium
        Inspiration_function
        Ataxia_Telangiectasia
        Myocardial_Infarction
        Alteplase
        3MC
        donepezil
        Ovarian_Carcinoma
        semaglutide
        Heart_failure
        Mandibular_Advancement_Devices
        Cerebrovascular_accident
        Allelic_Imbalance
        Sickle_Cell_Anemia
        Cerebral_Infarction
        Mitral_Valve_Insufficiency
        Stents
        Behavioral_and_psychological_symptoms_of_dementia
        Sedation
        Adrenergic_Antagonists
        Hereditary_Diseases
        tau_Proteins
        Norepinephrine
        Substance_P
        Senile_Plaques
        Myopathy

        Triglycerides -> Hypertensive_disease
        Hypertensive_disease -> Hypertension
        Hypertension -> Surgical_margins
        Surgical_margins -> PeptidylDipeptidase_A
        PeptidylDipeptidase_A -> TP73ARHGAP24
        TP73ARHGAP24 -> Diarrhea
        Diarrhea -> Superoxides
        Superoxides -> Neurohormones
        Neurohormones -> Cocaine
        Cocaine -> Induction
        Induction -> Excessive_daytime_somnolence
        Excessive_daytime_somnolence -> resistance_education
        resistance_education -> Fibromuscular_Dysplasia
        Fibromuscular_Dysplasia -> genotoxicity
        genotoxicity -> Pancreatic_Ductal_Adenocarcinoma
        Pancreatic_Ductal_Adenocarcinoma -> Gadolinium
        Gadolinium -> Inspiration_function
        Inspiration_function -> Ataxia_Telangiectasia
        Ataxia_Telangiectasia -> Myocardial_Infarction
        Myocardial_Infarction -> Alteplase
        Alteplase -> 3MC
        3MC -> donepezil
        donepezil -> Ovarian_Carcinoma
        Ovarian_Carcinoma -> semaglutide
        semaglutide -> Heart_failure
        Heart_failure -> Mandibular_Advancement_Devices
        Mandibular_Advancement_Devices -> Cerebrovascular_accident
        Cerebrovascular_accident -> Allelic_Imbalance
        Allelic_Imbalance -> Sickle_Cell_Anemia
        Sickle_Cell_Anemia -> Cerebral_Infarction
        Cerebral_Infarction -> Mitral_Valve_Insufficiency
        Mitral_Valve_Insufficiency -> Stents
        Stents -> Behavioral_and_psychological_symptoms_of_dementia
        Behavioral_and_psychological_symptoms_of_dementia -> Sedation
        Sedation -> Adrenergic_Antagonists
        Adrenergic_Antagonists -> Hereditary_Diseases
        Hereditary_Diseases -> tau_Proteins
        tau_Proteins -> Norepinephrine
        Norepinephrine -> Substance_P
        Substance_P -> Senile_Plaques
        Senile_Plaques -> Myopathy
        Myopathy -> Outcome_Condition
    }'))
}
