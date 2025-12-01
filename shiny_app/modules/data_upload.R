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
#' and compiled binary DAG files ("*_dag.rds").
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
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Warning: graph_creation/result directory does not exist. Creating it...\n")
        }
        dir.create(result_dir, recursive = TRUE)
    }
    r_files <- list.files(path = result_dir, pattern = "\\.(R|r)$", full.names = FALSE)

    # Filter out system files
    dag_files <- r_files[!r_files %in% exclude_files]

    # Check if R files contain dagitty definitions
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

    # Also include compiled binary DAG files ("*_dag.rds") when no matching R script exists
    binary_files <- list.files(path = result_dir, pattern = "_dag\\.rds$", full.names = FALSE)
    if (length(binary_files) > 0) {
        for (bfile in binary_files) {
            # Corresponding source script would be <base>.R or <base>.r
            base_name <- sub("_dag\\.rds$", "", bfile)
            r_candidates <- paste0(base_name, c(".R", ".r"))
            if (!any(r_candidates %in% r_files)) {
                valid_dag_files <- c(valid_dag_files, bfile)
            }
        }
    }

    # Return unique, sorted file list
    valid_dag_files <- sort(unique(valid_dag_files))
    return(valid_dag_files)
}

#' Load DAG from Specified File (with Binary Optimization)
#'
#' Loads a DAG definition from an R file, with automatic binary compilation and loading
#'
#' @param filename Name of the file to load
#' @return List containing success status, message, DAG object, and degree if successful
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

    # If user selected a compiled binary DAG file directly ("*_dag.rds"),
    # load it using the binary loader and return immediately.
    if (grepl("_dag\\.rds$", filename, ignore.case = TRUE)) {
        # Load binary storage module if not already loaded
        if (!exists("load_dag_from_binary")) {
            source("modules/dag_binary_storage.R")
        }

        binary_result <- load_dag_from_binary(filename)
        if (binary_result$success) {
            return(list(
                success = TRUE,
                message = paste("Successfully loaded DAG from compiled binary file -", binary_result$variable_count, "variables"),
                dag = binary_result$dag,
                degree = binary_result$degree,
                filename = filename,
                load_method = "binary_direct",
                load_time_seconds = binary_result$load_time_seconds
            ))
        } else {
            return(list(success = FALSE, message = binary_result$message))
        }
    }

    # Load binary storage module if not already loaded
    if (!exists("load_dag_from_binary")) {
        source("modules/dag_binary_storage.R")
    }

    # Try binary loading first (much faster) starting from an R script
    base_name <- tools::file_path_sans_ext(basename(filename))
    binary_path <- file.path(dirname(filename), paste0(base_name, "_dag.rds"))

    if (file.exists(binary_path)) {
        # Check if binary is newer than source
        r_mtime <- file.mtime(filename)
        binary_mtime <- file.mtime(binary_path)

        if (binary_mtime >= r_mtime) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Loading from binary DAG file (fastest mode)...\n")
            }
            binary_result <- load_dag_from_binary(binary_path)

            if (binary_result$success) {
                return(list(
                    success = TRUE,
                    message = paste("Successfully loaded DAG from binary file -", binary_result$variable_count, "variables"),
                    dag = binary_result$dag,
                    degree = binary_result$degree,
                    filename = filename,
                    load_method = "binary",
                    load_time_seconds = binary_result$load_time_seconds
                ))
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Binary loading failed, falling back to R script:", binary_result$message, "\n")
                }
            }
        } else {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Binary file is older than source, recompiling...\n")
            }
            compile_result <- compile_dag_to_binary(filename, force_regenerate = TRUE)
            if (compile_result$success) {
                binary_result <- load_dag_from_binary(binary_path)
                if (binary_result$success) {
                    return(list(
                        success = TRUE,
                        message = paste("Recompiled and loaded DAG -", binary_result$variable_count, "variables"),
                        dag = binary_result$dag,
                        degree = binary_result$degree,
                        filename = filename,
                        load_method = "binary_recompiled",
                        load_time_seconds = binary_result$load_time_seconds
                    ))
                }
            }
        }
    } else {
        # No binary file exists, try to create one
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("No binary file found, compiling for future use...\n")
        }
        compile_result <- compile_dag_to_binary(filename)
        if (compile_result$success) {
            binary_result <- load_dag_from_binary(binary_path)
            if (binary_result$success) {
                return(list(
                    success = TRUE,
                    message = paste("Compiled and loaded DAG -", binary_result$variable_count, "variables"),
                    dag = binary_result$dag,
                    degree = binary_result$degree,
                    filename = filename,
                    load_method = "binary_first_time",
                    load_time_seconds = binary_result$load_time_seconds
                ))
            }
        }
    }

    # Fallback to traditional R script loading
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
        cat("Loading from R script (traditional mode)...\n")
    }
    tryCatch({
        start_time <- Sys.time()

        # Create a new environment to source the file
        file_env <- new.env()

        # Source the file in the new environment
        source(filename, local = file_env)

        # Check if g variable was created
        if (exists("g", envir = file_env) && !is.null(file_env$g)) {
            # Extract degree from filename
            degree <- extract_degree_from_filename(filename)
            load_time <- as.numeric(Sys.time() - start_time, units = "secs")

            return(list(
                success = TRUE,
                message = paste("Successfully loaded DAG from R script -", length(names(file_env$g)), "variables"),
                dag = file_env$g,
                degree = degree,
                filename = filename,
                load_method = "r_script",
                load_time_seconds = round(load_time, 3)
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
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Successfully converted DAG to igraph using dagitty2graph\n")
            }
        }, error = function(e) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Error converting DAG to igraph with dagitty2graph:", e$message, "\n")
            }
            conversion_success <- FALSE
        })
    } else {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("dagitty2graph function not available, trying alternative method\n")
        }
    }

    # Fallback: try to extract edges by parsing DAG string
    if (!conversion_success) {
        tryCatch({
            # Parse the DAG string to extract edges
            dag_str <- as.character(dag_object)
            # Find all edge patterns like "node1 -> node2"
            edge_matches <- regmatches(dag_str, gregexpr('[A-Za-z0-9_]+ -> [A-Za-z0-9_]+', dag_str))

            if (length(edge_matches[[1]]) > 0) {
                # Parse each edge pattern
                edges_raw <- edge_matches[[1]]
                edge_list <- matrix(nrow = length(edges_raw), ncol = 2)

                for (i in seq_along(edges_raw)) {
                    parts <- strsplit(edges_raw[i], " -> ")[[1]]
                    if (length(parts) == 2) {
                        edge_list[i, 1] <- parts[1]
                        edge_list[i, 2] <- parts[2]
                    }
                }

                # Remove any NA rows
                edge_list <- edge_list[complete.cases(edge_list), , drop = FALSE]

                if (nrow(edge_list) > 0) {
                    # Create igraph from edge list
                    ig <- graph_from_edgelist(edge_list, directed = TRUE)
                    conversion_success <- TRUE
                    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                        cat("Successfully created graph using DAG string parsing -", nrow(edge_list), "edges found\n")
                    }
                } else {
                    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                        cat("No valid edges found after parsing\n")
                    }
                }
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("No edge patterns found in DAG string\n")
                }
            }
        }, error = function(e) {
            if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                cat("Error with DAG string parsing:", e$message, "\n")
            }
        })
    }

    # Final fallback: create empty graph
    if (!conversion_success || is.null(ig)) {
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Using empty graph fallback\n")
        }
        ig <- make_empty_graph(n = 0, directed = TRUE)
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
            edge_list <- as_edgelist(ig)
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
        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
            cat("Warning: Could not extract edges from graph:", e$message, "\n")
        }
    })

    # Print summary for large graphs
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING && nrow(nodes) > 50) {
        cat("Graph summary:\n")
        cat("- Nodes:", nrow(nodes), "\n")
        cat("- Edges:", nrow(edges), "\n")
        cat("- Node categories:", length(unique(nodes$group)), "\n")
        cat("- Categories:", paste(sort(unique(nodes$group)), collapse = ", "), "\n")
    }
    
    return(list(nodes = nodes, edges = edges, dag = dag_object))
}

#' Load and Cache Consolidated CUI Mappings
#'
#' Loads the user_input.yaml configuration and creates mappings for consolidated nodes
#'
#' @param config_file Path to the configuration file (default: "../user_input.yaml")
#' @return List containing consolidated node mappings
#' @export
load_consolidated_cui_mappings <- function(config_file = "../user_input.yaml") {
    tryCatch({
        if (!file.exists(config_file)) {
            return(list(
                success = FALSE,
                message = paste("Configuration file not found:", config_file),
                mappings = list()
            ))
        }

        # Load YAML configuration
        config <- yaml::read_yaml(config_file)

        # Create consolidated mappings
        mappings <- list()

        # Map exposure name to its CUIs
        if (!is.null(config$exposure_name) && !is.null(config$exposure_cuis)) {
            exposure_name <- gsub("_", " ", config$exposure_name)  # Convert underscores to spaces
            mappings[[exposure_name]] <- config$exposure_cuis
        }

        # Map outcome name to its CUIs
        if (!is.null(config$outcome_name) && !is.null(config$outcome_cuis)) {
            outcome_name <- gsub("_", " ", config$outcome_name)  # Convert underscores to spaces
            mappings[[outcome_name]] <- config$outcome_cuis
        }

        return(list(
            success = TRUE,
            message = paste("Loaded consolidated mappings for", length(mappings), "nodes"),
            mappings = mappings
        ))

    }, error = function(e) {
        return(list(
            success = FALSE,
            message = paste("Error loading consolidated CUI mappings:", e$message),
            mappings = list()
        ))
    })
}

#' Format Node Name with CUI Information
#'
#' Formats a node name with its associated CUI(s), handling both single and multiple CUIs
#'
#' @param node_name The display name of the node
#' @param single_cui Single CUI from causal assertions (if available)
#' @param consolidated_mappings List of consolidated node mappings from configuration
#' @return Formatted string with node name and CUI(s) in brackets
#' @export
format_node_with_cuis <- function(node_name, single_cui = NULL, consolidated_mappings = list()) {
    # First check if this node has consolidated CUI mappings
    if (length(consolidated_mappings) > 0 && node_name %in% names(consolidated_mappings)) {
        multiple_cuis <- consolidated_mappings[[node_name]]
        if (length(multiple_cuis) > 0) {
            cui_string <- paste(multiple_cuis, collapse = ", ")
            return(paste0(node_name, " [", cui_string, "]"))
        }
    }

    # Fallback to single CUI if available
    if (!is.null(single_cui) && single_cui != "") {
        return(paste0(node_name, " [", single_cui, "]"))
    }

    # Return plain node name if no CUI information available
    return(node_name)
}

#' Load Causal Assertions Data
#'
#' Loads causal assertions JSON file with PMID information
#' Uses optimized loading strategies based on file size
#'
#' @param filename Name of the causal assertions file (e.g., "causal_assertions_2.json")
#' @param degree Degree parameter to match with specific assertions file
#' @param search_dirs Vector of directories to search for the file
#' @param force_full_load Force loading of complete data (default: FALSE)
#' @param use_optimization Use optimized loading system (default: TRUE)
#' @return List containing success status, message, and assertions data if successful
#' @export
load_causal_assertions <- function(filename = NULL, degree = NULL,
                                 search_dirs = c("../graph_creation/result", "../graph_creation/output"),
                                 force_full_load = FALSE, use_optimization = TRUE) {
    # If no filename provided, try to find the appropriate causal_assertions file
    if (is.null(filename)) {
        # If degree is provided, look for the specific file first
        if (!is.null(degree) && is.numeric(degree) && degree >= 1 && degree <= 3) {
            target_filename <- paste0("causal_assertions_", degree, ".json")
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
                    # Look for causal_assertions files with degree suffix
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

    # Use optimized loading if enabled
    if (use_optimization) {
        # Source the new optimized loader module if not already loaded
        if (!exists("load_causal_assertions_unified")) {
            tryCatch({
                source("modules/optimized_loader.R")
            }, error = function(e) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Warning: Could not load optimized loader module:", e$message, "\n")
                    cat("Falling back to standard loading...\n")
                }
                use_optimization <- FALSE
            })
        }

        if (use_optimization && exists("load_causal_assertions_unified")) {
            # Use the unified loader that handles both standard and optimized formats
            result <- load_causal_assertions_unified(file_path)

            if (result$success) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Loaded using optimized loader:", result$message, "\n")
                    cat("Loading strategy:", result$loading_strategy, "\n")
                    cat("Load time:", round(result$load_time_seconds, 3), "seconds\n")
                }

                return(list(
                    success = TRUE,
                    message = result$message,
                    assertions = result$assertions,
                    loading_strategy = result$loading_strategy,
                    load_time_seconds = result$load_time_seconds,
                    file_size_mb = result$file_size_mb
                ))
            } else {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Optimized loader failed:", result$message, "\n")
                    cat("Falling back to standard loading...\n")
                }
                use_optimization <- FALSE
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
        required_fields <- c("subject_name", "object_name", "pmid_data")
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
#' Supports both full data and lazy loading modes
#'
#' @param from_node Name of the source node (transformed/cleaned name)
#' @param to_node Name of the target node (transformed/cleaned name)
#' @param assertions_data List of causal assertions loaded from JSON or lazy loader
#' @param lazy_loader Optional lazy loader function for on-demand data loading
#' @param edges_df Optional edges dataframe with CUI information for better matching
#' @return List containing PMID information for the edge
#' @export
find_edge_pmid_data <- function(from_node, to_node, assertions_data, lazy_loader = NULL, edges_df = NULL) {
    if (is.null(assertions_data) || length(assertions_data) == 0) {
        return(list(
            found = FALSE,
            message = "No assertions data available",
            pmid_list = character(0),
            evidence_count = 0
        ))
    }

    # Extract CUIs from edges_df if available
    from_cuis <- NULL
    to_cuis <- NULL
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        # Find the edge in edges_df
        edge_match <- edges_df[edges_df$from == from_node & edges_df$to == to_node, ]
        if (nrow(edge_match) > 0) {
            # Extract CUIs from the first matching edge
            from_cuis <- edge_match$from_cui[1]
            to_cuis <- edge_match$to_cui[1]

            # Split multiple CUIs if they exist (e.g., "C001|C002")
            if (!is.null(from_cuis) && !is.na(from_cuis)) {
                from_cuis <- strsplit(as.character(from_cuis), "\\|")[[1]]
            }
            if (!is.null(to_cuis) && !is.na(to_cuis)) {
                to_cuis <- strsplit(as.character(to_cuis), "\\|")[[1]]
            }
        }
    }

    # Check if we have indexed access (Phase 3 optimization)
    if (exists("current_data") && !is.null(current_data$edge_index)) {
        if (exists("fast_edge_lookup")) {
            indexed_result <- fast_edge_lookup(from_node, to_node, current_data$edge_index$edge_index, assertions_data)
            if (indexed_result$found) {
                if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                    cat("Using indexed lookup for edge\n")
                }
                return(indexed_result)
            }
        }
    }

    # Check if we need to use lazy loading for full sentence data
    use_lazy_loading <- !is.null(lazy_loader)
    if (use_lazy_loading) {
        # First check metadata for the edge
        metadata_match <- find_edge_in_metadata(from_node, to_node, assertions_data)
        if (metadata_match$found) {
            # Load full data for this specific edge using lazy loader
            full_assertion <- lazy_loader(metadata_match$subject_name, metadata_match$object_name)
            if (!is.null(full_assertion)) {
                # Process the full assertion data
                return(process_full_assertion(full_assertion, metadata_match$match_type))
            }
        }
        # If not found in metadata, fall through to regular processing
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
        # Common medical term mappings - add specific mappings as needed
        medical_mappings <- list(
            # Example: c("term1", "term1_variation"),
            # Example: c("term2", "term2_variation")
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

    # Search for matching assertions using multiple matching strategies
    # Collect ALL matching assertions for this edge (to handle multiple predicates)
    matching_assertions <- list()

    for (assertion in assertions_data) {
        if (!is.null(assertion$subject_name) && !is.null(assertion$object_name)) {
            # Strategy 1: Exact match (original logic)
            exact_match <- (assertion$subject_name == from_node && assertion$object_name == to_node)

            # Strategy 2: CUI-based matching (if CUIs are available)
            cui_match <- FALSE
            if (!exact_match && !is.null(from_cuis) && !is.null(to_cuis)) {
                # Get assertion CUIs
                assertion_subj_cui <- assertion$subj_cui %||% assertion$subject_cui
                assertion_obj_cui <- assertion$obj_cui %||% assertion$object_cui

                if (!is.null(assertion_subj_cui) && !is.null(assertion_obj_cui)) {
                    # Split multiple CUIs if they exist
                    assertion_subj_cuis <- strsplit(as.character(assertion_subj_cui), "\\|")[[1]]
                    assertion_obj_cuis <- strsplit(as.character(assertion_obj_cui), "\\|")[[1]]

                    # Check if any CUI matches
                    subj_cui_match <- any(from_cuis %in% assertion_subj_cuis)
                    obj_cui_match <- any(to_cuis %in% assertion_obj_cuis)

                    cui_match <- (subj_cui_match && obj_cui_match)
                }
            }

            # Strategy 3: Normalized name matching with medical variations
            subject_match <- handle_medical_variations(from_node, assertion$subject_name)
            object_match <- handle_medical_variations(to_node, assertion$object_name)
            normalized_match <- (subject_match && object_match)

            # Strategy 4: Partial matching for common transformations
            partial_match <- FALSE
            if (!exact_match && !cui_match && !normalized_match) {
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

            if (exact_match || cui_match || normalized_match || partial_match) {
                # Store this matching assertion
                matching_assertions[[length(matching_assertions) + 1]] <- list(
                    assertion = assertion,
                    match_type = if (exact_match) "exact" else if (cui_match) "cui" else if (normalized_match) "normalized" else "partial"
                )
            }
        }
    }

    # If we found matching assertions, aggregate them
    if (length(matching_assertions) > 0) {
        # Aggregate all predicates, PMIDs, and sentences from all matching assertions
        all_predicates <- character(0)
        all_pmids <- character(0)
        all_sentence_data <- list()
        total_evidence_count <- 0
        match_type <- "exact"  # Use the best match type
        original_subject <- ""
        original_object <- ""
        subject_cui <- ""
        object_cui <- ""

        for (match_info in matching_assertions) {
            assertion <- match_info$assertion

            # Collect predicate
            pred <- assertion$predicate %||% "CAUSES"
            if (!(pred %in% all_predicates)) {
                all_predicates <- c(all_predicates, pred)
            }

            # Extract PMID list from pmid_data keys (optimized structure)
            pmid_list <- if (!is.null(assertion$pmid_data)) {
                names(assertion$pmid_data)
            } else if (!is.null(assertion$pmid_list)) {
                assertion$pmid_list  # Backward compatibility
            } else {
                character(0)
            }

            # Handle mixed PMID formats (strings and objects) - for backward compatibility
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

            # Add unique PMIDs
            for (pmid in pmid_list) {
                if (!(pmid %in% all_pmids)) {
                    all_pmids <- c(all_pmids, pmid)
                }
            }

            # Extract sentence data if available
            pmid_data <- assertion$pmid_data
            if (!is.null(pmid_data) && is.list(pmid_data)) {
                for (pmid in pmid_list) {
                    tryCatch({
                        if (!is.null(pmid_data[[pmid]]) && is.list(pmid_data[[pmid]]) && !is.null(pmid_data[[pmid]]$sentences)) {
                            if (is.null(all_sentence_data[[pmid]])) {
                                all_sentence_data[[pmid]] <- pmid_data[[pmid]]$sentences
                            }
                        }
                    }, error = function(e) {
                        if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING) {
                            cat("Warning: Error accessing sentence data for PMID", pmid, ":", e$message, "\n")
                        }
                    })
                }
            }

            # Accumulate evidence count
            total_evidence_count <- total_evidence_count + (assertion$evidence_count %||% length(pmid_list))

            # Store metadata from first assertion
            if (original_subject == "") {
                original_subject <- assertion$subject_name %||% ""
                original_object <- assertion$object_name %||% ""
                subject_cui <- assertion$subject_cui %||% ""
                object_cui <- assertion$object_cui %||% ""
                match_type <- match_info$match_type
            }
        }

        # Combine all predicates into a single string
        combined_predicate <- paste(sort(all_predicates), collapse = ", ")

        return(list(
            found = TRUE,
            message = paste("Found", length(all_pmids), "PMIDs for edge (", match_type, "match)"),
            pmid_list = all_pmids,
            sentence_data = all_sentence_data,
            evidence_count = total_evidence_count,
            relationship_degree = "unknown",
            predicate = combined_predicate,  # Now contains all predicates
            match_type = match_type,
            original_subject = original_subject,
            original_object = original_object,
            subject_cui = subject_cui,
            object_cui = object_cui
        ))
    }

    return(list(
        found = FALSE,
        message = "No PMID data found for this edge",
        pmid_list = character(0),
        evidence_count = 0
    ))
}

#' Find All Assertions Related to a Node
#'
#' Finds all causal assertions where the node appears as subject or object
#'
#' @param node_name Name of the node to search for
#' @param assertions_data List of causal assertions
#' @param edges_df Optional data frame of edges to help with matching
#' @return List containing incoming and outgoing relationships
#' @export
find_node_related_assertions <- function(node_name, assertions_data, edges_df = NULL) {
    if (is.null(assertions_data) || length(assertions_data) == 0) {
        return(list(
            found = FALSE,
            message = "No assertions data available",
            incoming = list(),
            outgoing = list(),
            total_count = 0,
            node_name = node_name
        ))
    }

    incoming_edges <- list()
    outgoing_edges <- list()

    # Clean node name for matching (handle underscores and spaces)
    clean_node <- gsub("_", " ", node_name)
    node_variants <- c(node_name, clean_node)

    # Also try with different case
    node_variants <- c(node_variants, tolower(node_name), tolower(clean_node))

    for (assertion in assertions_data) {
        # Get subject and object names
        subj_name <- assertion$subject_name %||% assertion$subj
        obj_name <- assertion$object_name %||% assertion$obj

        # Clean assertion names
        clean_subj <- gsub("_", " ", subj_name)
        clean_obj <- gsub("_", " ", obj_name)

        # Check if node is the subject (outgoing edge from this node)
        if (!is.null(subj_name)) {
            subj_variants <- c(subj_name, clean_subj, tolower(subj_name), tolower(clean_subj))
            if (any(node_variants %in% subj_variants)) {
                outgoing_edges <- c(outgoing_edges, list(assertion))
            }
        }

        # Check if node is the object (incoming edge to this node)
        if (!is.null(obj_name)) {
            obj_variants <- c(obj_name, clean_obj, tolower(obj_name), tolower(clean_obj))
            if (any(node_variants %in% obj_variants)) {
                incoming_edges <- c(incoming_edges, list(assertion))
            }
        }
    }

    # If we have edges_df, try to match using actual edge connections
    if (!is.null(edges_df) && nrow(edges_df) > 0) {
        # Find edges connected to this node
        connected_edges <- edges_df[edges_df$from == node_name | edges_df$to == node_name, ]

        if (nrow(connected_edges) > 0) {
            # Try to find assertions for these edges
            for (i in 1:nrow(connected_edges)) {
                edge <- connected_edges[i, ]

                if (edge$from == node_name) {
                    # This is an outgoing edge
                    for (assertion in assertions_data) {
                        obj_name <- assertion$object_name %||% assertion$obj
                        if (!is.null(obj_name) && (obj_name == edge$to || gsub("_", " ", obj_name) == gsub("_", " ", edge$to))) {
                            # Check if not already in outgoing_edges
                            if (!any(sapply(outgoing_edges, function(x) identical(x, assertion)))) {
                                outgoing_edges <- c(outgoing_edges, list(assertion))
                            }
                        }
                    }
                } else {
                    # This is an incoming edge
                    for (assertion in assertions_data) {
                        subj_name <- assertion$subject_name %||% assertion$subj
                        if (!is.null(subj_name) && (subj_name == edge$from || gsub("_", " ", subj_name) == gsub("_", " ", edge$from))) {
                            # Check if not already in incoming_edges
                            if (!any(sapply(incoming_edges, function(x) identical(x, assertion)))) {
                                incoming_edges <- c(incoming_edges, list(assertion))
                            }
                        }
                    }
                }
            }
        }
    }

    total_count <- length(incoming_edges) + length(outgoing_edges)

    return(list(
        found = total_count > 0,
        message = if (total_count > 0) {
            paste("Found", total_count, "related assertions")
        } else {
            "No assertions found for this node"
        },
        incoming = incoming_edges,
        outgoing = outgoing_edges,
        total_count = total_count,
        node_name = node_name,
        incoming_count = length(incoming_edges),
        outgoing_count = length(outgoing_edges)
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

#' Extract Degree from DAG Filename
#'
#' Extracts the degree parameter from a DAG filename (e.g., "degree_2.R" -> 2)
#'
#' @param filename Name of the DAG file
#' @return Integer degree value, or NULL if not found
#' @export
extract_degree_from_filename <- function(filename) {
    if (is.null(filename) || !is.character(filename)) {
        return(NULL)
    }

    # Extract basename to handle full paths
    basename_file <- basename(filename)

    # Check for degree_X.R pattern
    degree_match <- regexpr("degree_([123])\\.R$", basename_file, perl = TRUE)
    if (degree_match > 0) {
        # Extract the degree number
        degree_str <- regmatches(basename_file, degree_match)
        degree_num <- as.numeric(gsub("degree_([123])\\.R$", "\\1", degree_str))
        if (!is.na(degree_num) && degree_num >= 1 && degree_num <= 3) {
            return(degree_num)
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
    if (exists("VERBOSE_LOGGING") && VERBOSE_LOGGING && length(all_nodes) > max_nodes) {
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

        Triglycerides -> Mutation
        Mutation -> Neurodegenerative_Disorders
        Screening_procedure -> Kidney_Diseases
    }'))
}

#' Find Edge in Metadata
#'
#' Searches for an edge in metadata (lightweight) assertions data
#'
#' @param from_node Source node name
#' @param to_node Target node name
#' @param metadata_data Metadata assertions data
#' @return List with match information
find_edge_in_metadata <- function(from_node, to_node, metadata_data) {
    # Helper function to normalize names for matching
    normalize_name <- function(name) {
        if (is.null(name) || name == "") return("")
        normalized <- tolower(name)
        normalized <- gsub("[^a-z0-9]+", "_", normalized)
        normalized <- gsub("_+", "_", normalized)
        normalized <- gsub("^_|_$", "", normalized)
        return(normalized)
    }

    # Helper function to handle medical term variations
    handle_medical_variations <- function(dag_name, json_name) {
        medical_mappings <- list(
            # Example: c("term1", "term1_variation"),
            # Example: c("term2", "term2_variation")
        )

        dag_norm <- normalize_name(dag_name)
        json_norm <- normalize_name(json_name)

        if (dag_norm == json_norm) return(TRUE)

        for (mapping in medical_mappings) {
            if ((dag_norm == mapping[1] && json_norm == mapping[2]) ||
                (dag_norm == mapping[2] && json_norm == mapping[1])) {
                return(TRUE)
            }
        }
        return(FALSE)
    }

    from_normalized <- normalize_name(from_node)
    to_normalized <- normalize_name(to_node)

    # Search through metadata
    for (assertion in metadata_data) {
        subject_normalized <- normalize_name(assertion$subject_name)
        object_normalized <- normalize_name(assertion$object_name)

        # Try exact normalized match
        if (from_normalized == subject_normalized && to_normalized == object_normalized) {
            return(list(
                found = TRUE,
                subject_name = assertion$subject_name,
                object_name = assertion$object_name,
                match_type = "exact"
            ))
        }

        # Try medical variations
        if (handle_medical_variations(from_node, assertion$subject_name) &&
            handle_medical_variations(to_node, assertion$object_name)) {
            return(list(
                found = TRUE,
                subject_name = assertion$subject_name,
                object_name = assertion$object_name,
                match_type = "medical_variation"
            ))
        }
    }

    return(list(found = FALSE))
}

#' Process Full Assertion
#'
#' Processes a full assertion object and returns formatted PMID data
#'
#' @param assertion Full assertion object with pmid_data
#' @param match_type Type of match found
#' @return List with formatted PMID information
process_full_assertion <- function(assertion, match_type) {
    # Extract PMID list from pmid_data keys (optimized structure)
    pmid_list <- if (!is.null(assertion$pmid_data)) {
        names(assertion$pmid_data)
    } else if (!is.null(assertion$pmid_list)) {
        assertion$pmid_list  # Backward compatibility
    } else {
        character(0)
    }

    sentence_data <- list()

    # Extract sentence data from pmid_data
    if (!is.null(assertion$pmid_data)) {
        for (pmid in names(assertion$pmid_data)) {
            if (!is.null(assertion$pmid_data[[pmid]]$sentences)) {
                sentence_data[[pmid]] <- assertion$pmid_data[[pmid]]$sentences
            }
        }
    }

    return(list(
        found = TRUE,
        message = paste("Found", length(pmid_list), "PMIDs for edge (", match_type, "match)"),
        pmid_list = pmid_list,
        sentence_data = sentence_data,
        evidence_count = assertion$evidence_count %||% length(pmid_list),
        relationship_degree = assertion$relationship_degree %||% "unknown",
        predicate = assertion$predicate %||% "CAUSES",
        match_type = match_type,
        original_subject = assertion$subject_name,
        original_object = assertion$object_name,
        subject_cui = assertion$subject_cui %||% "",
        object_cui = assertion$object_cui %||% ""
    ))
}
