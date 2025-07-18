# Data Upload Module
# This module contains file upload handling, data ingestion, and data validation functions
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dagitty, igraph

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Source required modules
if (file.exists("node_information.R")) {
    source("node_information.R")
} else {
    warning("node_information.R not found. Some functions may not work properly.")
}

#' Scan for Available DAG Files
#' 
#' Scans the current directory for R files that might contain DAG definitions
#' 
#' @param exclude_files Vector of filenames to exclude from scanning (default: system files)
#' @return Vector of valid DAG filenames
#' @export
scan_for_dag_files <- function(exclude_files = c("app.R", "dag_data.R", "dag_visualization.R", 
                                                 "node_information.R", "statistics.R", "data_upload.R")) {
    # Look for R files that might contain DAG definitions
    r_files <- list.files(pattern = "\\.(R|r)$", full.names = FALSE)
    
    # Filter out system files
    dag_files <- r_files[!r_files %in% exclude_files]
    
    # Check if files contain dagitty definitions
    valid_dag_files <- c()
    
    for (file in dag_files) {
        if (file.exists(file)) {
            tryCatch({
                # Read first few lines to check for dagitty syntax
                lines <- readLines(file, n = 50, warn = FALSE)
                content <- paste(lines, collapse = " ")
                
                # Check for dagitty syntax
                if (grepl("dagitty\\s*\\(", content, ignore.case = TRUE) || 
                    grepl("dag\\s*\\{", content, ignore.case = TRUE)) {
                    valid_dag_files <- c(valid_dag_files, file)
                }
            }, error = function(e) {
                # Skip files that can't be read
            })
        }
    }
    
    return(valid_dag_files)
}

#' Load DAG from Specified File
#' 
#' Loads a DAG definition from an R file
#' 
#' @param filename Name of the file to load
#' @return List containing success status, message, and DAG object if successful
#' @export
load_dag_from_file <- function(filename) {
    if (!file.exists(filename)) {
        return(list(success = FALSE, message = paste("File", filename, "not found")))
    }
    
    tryCatch({
        # Create a new environment to source the file
        file_env <- new.env()
        
        # Source the file in the new environment
        source(filename, local = file_env)
        
        # Check if g variable was created
        if (exists("g", envir = file_env) && !is.null(file_env$g)) {
            return(list(success = TRUE, message = paste("Successfully loaded DAG from", filename), dag = file_env$g))
        } else {
            return(list(success = FALSE, message = paste("No 'g' variable found in", filename)))
        }
    }, error = function(e) {
        return(list(success = FALSE, message = paste("Error loading", filename, ":", e$message)))
    })
}

#' Validate DAG Object
#' 
#' Validates that a loaded object is a proper dagitty DAG
#' 
#' @param dag_object Object to validate
#' @return List containing validation results
#' @export
validate_dag_object <- function(dag_object) {
    if (is.null(dag_object)) {
        return(list(valid = FALSE, message = "DAG object is NULL"))
    }
    
    tryCatch({
        # Check if it's a dagitty object
        if (!inherits(dag_object, "dagitty")) {
            return(list(valid = FALSE, message = "Object is not a dagitty DAG"))
        }
        
        # Try to get node names
        node_names <- names(dag_object)
        if (length(node_names) == 0) {
            return(list(valid = FALSE, message = "DAG contains no nodes"))
        }
        
        # Try to convert to igraph (this will catch structural issues)
        tryCatch({
            ig <- dagitty2graph(dag_object)
        }, error = function(e) {
            return(list(valid = FALSE, message = paste("DAG structure error:", e$message)))
        })
        
        return(list(valid = TRUE, message = "DAG is valid", node_count = length(node_names)))
        
    }, error = function(e) {
        return(list(valid = FALSE, message = paste("Validation error:", e$message)))
    })
}

#' Create Network Data from DAG Object
#' 
#' Converts a dagitty DAG object into network data suitable for visualization
#' 
#' @param dag_object dagitty DAG object
#' @return List containing nodes and edges data frames
#' @export
create_network_data <- function(dag_object) {
    # Validate the DAG first
    validation <- validate_dag_object(dag_object)
    if (!validation$valid) {
        warning(paste("DAG validation failed:", validation$message))
        # Return minimal fallback data
        return(list(
            nodes = data.frame(
                id = c("Error", "Fallback"),
                label = c("Error Node", "Fallback Node"),
                group = c("Other", "Other"),
                color = c("#FF0000", "#808080"),
                font.size = 14,
                font.color = "black",
                stringsAsFactors = FALSE
            ),
            edges = data.frame(
                from = "Error",
                to = "Fallback",
                arrows = "to",
                smooth = TRUE,
                width = 1,
                color = "#666666",
                stringsAsFactors = FALSE
            ),
            dag = dag_object
        ))
    }
    
    # Convert DAG to igraph with error handling
    ig <- NULL
    conversion_success <- FALSE

    # First try with dagitty2graph if available
    if (exists("dagitty2graph")) {
        tryCatch({
            ig <- dagitty2graph(dag_object)
            conversion_success <- TRUE
            cat("Successfully converted DAG to igraph using dagitty2graph\n")
        }, error = function(e) {
            cat("Error converting DAG to igraph with dagitty2graph:", e$message, "\n")
            conversion_success <- FALSE
        })
    } else {
        cat("dagitty2graph function not available, trying alternative method\n")
    }

    # Fallback: try to extract edges directly from dagitty object
    if (!conversion_success) {
        tryCatch({
            # Extract edges directly from dagitty object
            edge_matrix <- edges(dag_object)
            if (!is.null(edge_matrix) && nrow(edge_matrix) > 0) {
                # Create a simple igraph from edge list
                ig <- graph_from_edgelist(as.matrix(edge_matrix[, c("from", "to")]), directed = TRUE)
                conversion_success <- TRUE
                cat("Successfully created graph using direct edge extraction\n")
            } else {
                cat("No edges found in DAG object\n")
            }
        }, error = function(e) {
            cat("Error with direct edge extraction:", e$message, "\n")
        })
    }

    # Final fallback: create empty graph
    if (!conversion_success || is.null(ig)) {
        cat("Using empty graph fallback\n")
        ig <- graph.empty(n = 0, directed = TRUE)
    }
    
    # Create nodes dataframe using the node_information module
    if (exists("create_nodes_dataframe")) {
        nodes <- create_nodes_dataframe(dag_object)
    } else {
        # Fallback if node_information module not available
        all_nodes <- names(dag_object)
        nodes <- data.frame(
            id = all_nodes,
            label = gsub("_", " ", all_nodes),
            group = "Other",
            color = "#808080",
            font.size = 14,
            font.color = "black",
            stringsAsFactors = FALSE
        )
    }
    
    # Create edges dataframe with error handling
    edges <- data.frame(
        from = character(0),
        to = character(0),
        arrows = character(0),
        smooth = logical(0),
        width = numeric(0),
        color = character(0),
        stringsAsFactors = FALSE
    )
    
    # Try to extract edges
    tryCatch({
        if (length(E(ig)) > 0) {
            edge_list <- get.edgelist(ig)
            if (nrow(edge_list) > 0) {
                edges <- data.frame(
                    from = edge_list[,1],
                    to = edge_list[,2],
                    arrows = "to",
                    smooth = TRUE,
                    width = 1,  # Thinner lines for large graphs
                    color = "#666666",
                    stringsAsFactors = FALSE
                )
            }
        }
    }, error = function(e) {
        cat("Warning: Could not extract edges from graph:", e$message, "\n")
    })
    
    # Print summary for large graphs
    if (nrow(nodes) > 50) {
        cat("Graph summary:\n")
        cat("- Nodes:", nrow(nodes), "\n")
        cat("- Edges:", nrow(edges), "\n")
        cat("- Node categories:", length(unique(nodes$group)), "\n")
        cat("- Categories:", paste(sort(unique(nodes$group)), collapse = ", "), "\n")
    }
    
    return(list(nodes = nodes, edges = edges, dag = dag_object))
}

#' Process Large DAG with Memory Optimization
#' 
#' Handles very large graphs with memory optimization
#' 
#' @param dag_object dagitty DAG object
#' @param max_nodes Maximum nodes before applying optimizations (default: 1000)
#' @return List containing processed network data
#' @export
process_large_dag <- function(dag_object, max_nodes = 1000) {
    all_nodes <- names(dag_object)
    
    # If graph is too large, provide warning
    if (length(all_nodes) > max_nodes) {
        cat("Warning: Graph has", length(all_nodes), "nodes, which is quite large.\n")
        cat("Consider filtering the graph or increasing max_nodes parameter.\n")
        cat("Processing with current settings...\n")
    }
    
    # Use the standard processing function
    return(create_network_data(dag_object))
}

#' Validate Edge Data
#' 
#' Validates and fixes edge data structure
#' 
#' @param edges Data frame containing edge information
#' @return Validated and corrected edges data frame
#' @export
validate_edge_data <- function(edges) {
    if (is.null(edges) || nrow(edges) == 0) {
        return(data.frame(
            from = character(0),
            to = character(0),
            arrows = character(0),
            smooth = logical(0),
            width = numeric(0),
            color = character(0),
            stringsAsFactors = FALSE
        ))
    }
    
    # Validate edges
    required_edge_cols <- c("from", "to")
    missing_edge_cols <- setdiff(required_edge_cols, names(edges))
    
    if (length(missing_edge_cols) > 0) {
        warning(paste("Missing edge columns:", paste(missing_edge_cols, collapse = ", ")))
        if (!"from" %in% names(edges) | !"to" %in% names(edges)) {
            stop("Edge 'from' and 'to' columns are required")
        }
    }
    
    # Add optional edge columns if missing
    if (!"arrows" %in% names(edges)) edges$arrows <- "to"
    if (!"smooth" %in% names(edges)) edges$smooth <- TRUE
    if (!"width" %in% names(edges)) edges$width <- 1.5
    if (!"color" %in% names(edges)) edges$color <- "#2F4F4F80"
    
    return(edges)
}

#' Get Default DAG Files to Try
#' 
#' Returns a list of default filenames to try loading
#' 
#' @return Vector of default filenames
#' @export
get_default_dag_files <- function() {
    return(c("graph.R", "my_dag.R", "dag.R", "consolidated.R"))
}

#' Create Fallback DAG
#' 
#' Creates a simple fallback DAG when no files are found
#' 
#' @return dagitty DAG object
#' @export
create_fallback_dag <- function() {
    return(dagitty('dag {
        Hypertension [exposure]
        Alzheimers_Disease [outcome]
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
        Mutation -> Neurodegenerative_Disorders
        Screening_procedure -> Kidney_Diseases
    }'))
}
