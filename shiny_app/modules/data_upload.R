# Data Upload Module
# This module contains file upload handling, data ingestion, and data validation functions
# Author: Refactored from original dag_data.R and app.R
# Dependencies: dagitty, igraph

# Required libraries for this module
if (!require(dagitty)) stop("dagitty package is required")
if (!require(igraph)) stop("igraph package is required")

# Source required modules
if (file.exists("modules/node_information.R")) {
    source("modules/node_information.R")
} else if (file.exists("node_information.R")) {
    source("node_information.R")
} else {
    warning("node_information.R not found. Some functions may not work properly.")
}

# Define null coalescing operator
`%||%` <- function(x, y) if (is.null(x)) y else x

#' Scan for Available DAG Files
#' 
#' Scans the current directory for R files that might contain DAG definitions
#' 
#' @param exclude_files Vector of filenames to exclude from scanning (default: system files)
#' @return Vector of valid DAG filenames
#' @export
scan_for_dag_files <- function(exclude_files = c("app.R", "dag_data.R", "dag_visualization.R",
                                                 "node_information.R", "statistics.R", "data_upload.R")) {
    # Look for R files that might contain DAG definitions in graph_creation/result directory
    # Since we're running from shiny_app/, we need to go up one level to reach graph_creation/
    result_dir <- "../graph_creation/result"
    if (!dir.exists(result_dir)) {
        cat("Warning: graph_creation/result directory does not exist. Creating it...\n")
        dir.create(result_dir, recursive = TRUE)
    }
    r_files <- list.files(path = result_dir, pattern = "\\.(R|r)$", full.names = FALSE)
    
    # Filter out system files
    dag_files <- r_files[!r_files %in% exclude_files]
    
    # Check if files contain dagitty definitions
    valid_dag_files <- c()
    
    for (file in dag_files) {
        file_path <- file.path(result_dir, file)
        if (file.exists(file_path)) {
            tryCatch({
                # Read first few lines to check for dagitty syntax
                lines <- readLines(file_path, n = 50, warn = FALSE)
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
#' @return List containing success status, message, DAG object, and k_hops if successful
#' @export
load_dag_from_file <- function(filename) {
    # Check if filename is a full path or just a filename
    if (!file.exists(filename)) {
        # Try looking in the graph_creation/result directory (relative to project root)
        result_path <- file.path("../graph_creation/result", filename)
        if (file.exists(result_path)) {
            filename <- result_path
        } else {
            return(list(success = FALSE, message = paste("File", filename, "not found in current directory or ../graph_creation/result")))
        }
    }

    tryCatch({
        # Create a new environment to source the file
        file_env <- new.env()

        # Source the file in the new environment
        source(filename, local = file_env)

        # Check if g variable was created
        if (exists("g", envir = file_env) && !is.null(file_env$g)) {
            # Extract k_hops from filename
            k_hops <- extract_k_hops_from_filename(filename)

            return(list(
                success = TRUE,
                message = paste("Successfully loaded DAG from", filename),
                dag = file_env$g,
                k_hops = k_hops,
                filename = filename
            ))
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

#' Load Causal Assertions Data
#'
#' Loads causal assertions JSON file with PMID information
#'
#' @param filename Name of the causal assertions file (e.g., "causal_assertions_2.json")
#' @param k_hops K-hops parameter to match with specific assertions file
#' @param search_dirs Vector of directories to search for the file
#' @return List containing success status, message, and assertions data if successful
#' @export
load_causal_assertions <- function(filename = NULL, k_hops = NULL, search_dirs = c("../graph_creation/result", "../graph_creation/output")) {
    # If no filename provided, try to find the appropriate causal_assertions file
    if (is.null(filename)) {
        # If k_hops is provided, look for the specific file first
        if (!is.null(k_hops) && is.numeric(k_hops) && k_hops >= 1 && k_hops <= 3) {
            target_filename <- paste0("causal_assertions_", k_hops, ".json")
            for (dir in search_dirs) {
                if (dir.exists(dir)) {
                    target_path <- file.path(dir, target_filename)
                    if (file.exists(target_path)) {
                        filename <- target_path
                        break
                    }
                }
            }
        }

        # If still no filename, try to find the most recent causal_assertions file
        if (is.null(filename)) {
            for (dir in search_dirs) {
                if (dir.exists(dir)) {
                    # Look for causal_assertions files with k_hops suffix
                    assertion_files <- list.files(dir, pattern = "^causal_assertions_[123]\\.json$", full.names = TRUE)
                    if (length(assertion_files) > 0) {
                        # Use the most recently modified file
                        file_info <- file.info(assertion_files)
                        filename <- assertion_files[which.max(file_info$mtime)]
                        break
                    }

                    # Fallback to original causal_assertions.json
                    fallback_file <- file.path(dir, "causal_assertions.json")
                    if (file.exists(fallback_file)) {
                        filename <- fallback_file
                        break
                    }
                }
            }
        }

        if (is.null(filename)) {
            return(list(
                success = FALSE,
                message = "No causal assertions files found in search directories",
                assertions = list()
            ))
        }
    } else {
        # Check if filename is a full path or just a filename
        if (!file.exists(filename)) {
            # Try looking in search directories
            found <- FALSE
            for (dir in search_dirs) {
                test_path <- file.path(dir, filename)
                if (file.exists(test_path)) {
                    filename <- test_path
                    found <- TRUE
                    break
                }
            }

            if (!found) {
                return(list(
                    success = FALSE,
                    message = paste("Causal assertions file not found:", filename),
                    assertions = list()
                ))
            }
        }
    }

    tryCatch({
        # Load JSON data with error handling for malformed JSON
        assertions_data <- tryCatch({
            jsonlite::fromJSON(filename, simplifyDataFrame = FALSE)
        }, error = function(e) {
            # If JSON parsing fails, try to read and fix common issues
            warning(paste("JSON parsing failed for", filename, ":", e$message))
            return(NULL)
        })

        if (is.null(assertions_data)) {
            return(list(
                success = FALSE,
                message = paste("Failed to parse JSON file:", basename(filename)),
                assertions = list()
            ))
        }

        # Validate the structure
        if (!is.list(assertions_data) || length(assertions_data) == 0) {
            return(list(
                success = FALSE,
                message = "Invalid or empty causal assertions data",
                assertions = list()
            ))
        }

        # Check if first item has expected structure
        first_item <- assertions_data[[1]]
        required_fields <- c("subject_name", "object_name", "pmid_list")
        missing_fields <- setdiff(required_fields, names(first_item))

        if (length(missing_fields) > 0) {
            return(list(
                success = FALSE,
                message = paste("Missing required fields in assertions data:", paste(missing_fields, collapse = ", ")),
                assertions = list()
            ))
        }

        return(list(
            success = TRUE,
            message = paste("Successfully loaded", length(assertions_data), "causal assertions from", basename(filename)),
            assertions = assertions_data,
            filename = filename
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading causal assertions:", e$message),
            assertions = list()
        ))
    })
}

#' Find PMID Data for Edge
#'
#' Finds PMID evidence for a specific causal relationship edge
#'
#' @param from_node Name of the source node (transformed/cleaned name)
#' @param to_node Name of the target node (transformed/cleaned name)
#' @param assertions_data List of causal assertions loaded from JSON
#' @return List containing PMID information for the edge
#' @export
find_edge_pmid_data <- function(from_node, to_node, assertions_data) {
    if (is.null(assertions_data) || length(assertions_data) == 0) {
        return(list(
            found = FALSE,
            message = "No assertions data available",
            pmid_list = character(0),
            evidence_count = 0
        ))
    }

    # Helper function to normalize names for matching
    normalize_name <- function(name) {
        if (is.null(name) || name == "") return("")
        # Convert to lowercase, replace special chars with underscores, collapse multiple underscores
        normalized <- tolower(name)
        normalized <- gsub("[^a-z0-9]+", "_", normalized)
        normalized <- gsub("_+", "_", normalized)
        normalized <- gsub("^_|_$", "", normalized)
        return(normalized)
    }

    # Helper function to handle common medical term variations
    handle_medical_variations <- function(dag_name, json_name) {
        # Common medical term mappings
        medical_mappings <- list(
            # Hypertension variations
            c("hypertension", "hypertensive_disease"),
            c("hypertension", "hypertensive_disorder"),
            # Alzheimer variations
            c("alzheimers", "alzheimer_s_disease"),
            c("alzheimers", "alzheimer_disease"),
            # Add more mappings as needed
            c("diabetes", "diabetes_mellitus"),
            c("heart_disease", "cardiovascular_disease")
        )

        dag_norm <- normalize_name(dag_name)
        json_norm <- normalize_name(json_name)

        # Check direct normalized match first
        if (dag_norm == json_norm) return(TRUE)

        # Check medical term variations
        for (mapping in medical_mappings) {
            if ((dag_norm == mapping[1] && json_norm == mapping[2]) ||
                (dag_norm == mapping[2] && json_norm == mapping[1])) {
                return(TRUE)
            }
        }

        return(FALSE)
    }

    # Normalize the input node names
    from_normalized <- normalize_name(from_node)
    to_normalized <- normalize_name(to_node)

    # Search for matching assertion using multiple matching strategies
    for (assertion in assertions_data) {
        if (!is.null(assertion$subject_name) && !is.null(assertion$object_name)) {
            # Strategy 1: Exact match (original logic)
            exact_match <- (assertion$subject_name == from_node && assertion$object_name == to_node)

            # Strategy 2: Normalized name matching with medical variations
            subject_match <- handle_medical_variations(from_node, assertion$subject_name)
            object_match <- handle_medical_variations(to_node, assertion$object_name)
            normalized_match <- (subject_match && object_match)

            # Strategy 3: Partial matching for common transformations
            # Handle cases like "Hypertensive disease" -> "Hypertension"
            partial_match <- FALSE
            if (!exact_match && !normalized_match) {
                # Get normalized versions for partial matching
                subject_normalized <- normalize_name(assertion$subject_name)
                object_normalized <- normalize_name(assertion$object_name)

                # Check if the normalized names contain each other or have significant overlap
                from_words <- strsplit(from_normalized, "_")[[1]]
                to_words <- strsplit(to_normalized, "_")[[1]]
                subject_words <- strsplit(subject_normalized, "_")[[1]]
                object_words <- strsplit(object_normalized, "_")[[1]]

                # Check for substantial word overlap (at least 50% of words match)
                from_overlap <- length(intersect(from_words, subject_words)) / max(length(from_words), length(subject_words))
                to_overlap <- length(intersect(to_words, object_words)) / max(length(to_words), length(object_words))

                partial_match <- (from_overlap >= 0.5 && to_overlap >= 0.5)
            }

            if (exact_match || normalized_match || partial_match) {
                pmid_list <- assertion$pmid_list
                if (is.null(pmid_list)) pmid_list <- character(0)

                # Handle mixed PMID formats (strings and objects)
                # Extract just the PMID strings, ignoring any object metadata
                if (is.list(pmid_list)) {
                    clean_pmids <- character(0)
                    for (item in pmid_list) {
                        if (is.character(item)) {
                            clean_pmids <- c(clean_pmids, item)
                        } else if (is.list(item) && !is.null(names(item))) {
                            # If it's a named list, use the name as the PMID
                            clean_pmids <- c(clean_pmids, names(item)[1])
                        }
                    }
                    pmid_list <- clean_pmids
                }

                # Determine match type for debugging
                match_type <- if (exact_match) "exact" else if (normalized_match) "normalized" else "partial"

                return(list(
                    found = TRUE,
                    message = paste("Found", length(pmid_list), "PMIDs for edge (", match_type, "match)"),
                    pmid_list = pmid_list,
                    evidence_count = assertion$evidence_count %||% length(pmid_list),
                    relationship_degree = assertion$relationship_degree %||% "unknown",
                    predicate = assertion$predicate %||% "CAUSES",
                    match_type = match_type,
                    original_subject = assertion$subject_name,
                    original_object = assertion$object_name
                ))
            }
        }
    }

    return(list(
        found = FALSE,
        message = "No PMID data found for this edge",
        pmid_list = character(0),
        evidence_count = 0
    ))
}

#' Format PMID List for Display
#'
#' Formats PMID list for display in the edge information panel
#'
#' @param pmid_list Vector of PMID strings
#' @param max_display Maximum number of PMIDs to display directly (default: 10)
#' @param create_links Whether to create clickable PubMed links (default: TRUE)
#' @return Formatted HTML string for display
#' @export
format_pmid_display <- function(pmid_list, max_display = 10, create_links = TRUE) {
    if (length(pmid_list) == 0) {
        return("No PMIDs available")
    }

    # Sort PMIDs for consistent display
    pmid_list <- sort(pmid_list)

    if (create_links) {
        # Create clickable links to PubMed
        pmid_links <- sapply(pmid_list[1:min(length(pmid_list), max_display)], function(pmid) {
            paste0('<a href="https://pubmed.ncbi.nlm.nih.gov/', pmid, '/" target="_blank">', pmid, '</a>')
        })

        formatted_pmids <- paste(pmid_links, collapse = ", ")

        # Add "and X more" if there are additional PMIDs
        if (length(pmid_list) > max_display) {
            remaining <- length(pmid_list) - max_display
            formatted_pmids <- paste0(formatted_pmids, ", <em>and ", remaining, " more PMIDs</em>")
        }
    } else {
        # Simple comma-separated list
        if (length(pmid_list) <= max_display) {
            formatted_pmids <- paste(pmid_list, collapse = ", ")
        } else {
            displayed_pmids <- pmid_list[1:max_display]
            remaining <- length(pmid_list) - max_display
            formatted_pmids <- paste0(paste(displayed_pmids, collapse = ", "), ", and ", remaining, " more")
        }
    }

    return(formatted_pmids)
}

#' Extract K-Hops from DAG Filename
#'
#' Extracts the k_hops parameter from a DAG filename (e.g., "degree_2.R" -> 2)
#'
#' @param filename Name of the DAG file
#' @return Integer k_hops value, or NULL if not found
#' @export
extract_k_hops_from_filename <- function(filename) {
    if (is.null(filename) || !is.character(filename)) {
        return(NULL)
    }

    # Extract basename to handle full paths
    basename_file <- basename(filename)

    # Check for degree_X.R pattern
    degree_match <- regexpr("degree_([123])\\.R$", basename_file, perl = TRUE)
    if (degree_match > 0) {
        # Extract the k_hops number
        k_hops_str <- regmatches(basename_file, degree_match)
        k_hops_num <- as.numeric(gsub("degree_([123])\\.R$", "\\1", k_hops_str))
        if (!is.na(k_hops_num) && k_hops_num >= 1 && k_hops_num <= 3) {
            return(k_hops_num)
        }
    }

    return(NULL)
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
