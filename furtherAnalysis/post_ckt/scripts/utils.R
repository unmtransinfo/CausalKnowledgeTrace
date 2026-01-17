# utils.R
# Shared utility functions for Post-CKT Analysis Pipeline
#
# This file provides:
#   - Automatic project root detection
#   - Standard path getters for all directories
#   - CLI argument parsing helpers
#   - Directory creation utilities
#
# Usage: source("utils.R") at the top of each script (after config.R)

# ============================================
# PROJECT ROOT DETECTION
# ============================================

#' Get the project root directory (furtherAnalysis/post_ckt)
#'
#' This function automatically detects the project root by:
#' 1. First checking if we're already in the scripts directory
#' 2. Walking up the directory tree looking for marker files
#' 3. Works regardless of where the script is called from
#'
#' @return Character string with absolute path to project root
get_project_root <- function() {
  # Get the directory where this script is located
  # This works both for source() and Rscript execution

  # Method 1: Try to get script path from command line args
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)

  if (length(file_arg) > 0) {
    # Running via Rscript
    script_path <- normalizePath(sub("--file=", "", file_arg))
    script_dir <- dirname(script_path)
    project_root <- dirname(script_dir)

    # Verify this looks like our project
    if (file.exists(file.path(project_root, "scripts", "config.R"))) {
      return(project_root)
    }
  }

  # Method 2: Check if current working directory is in the project

  current <- normalizePath(getwd())

  # If we're in the scripts directory
  if (basename(current) == "scripts" &&
      file.exists(file.path(current, "config.R"))) {
    return(dirname(current))
  }

  # Method 3: Walk up the directory tree
  check_dir <- current
  max_levels <- 10  # Prevent infinite loop
  level <- 0

  while (check_dir != dirname(check_dir) && level < max_levels) {
    # Check if this is the post_ckt directory
    if (file.exists(file.path(check_dir, "scripts", "config.R")) &&
        file.exists(file.path(check_dir, "input")) &&
        file.exists(file.path(check_dir, "output"))) {
      return(check_dir)
    }

    # Check if post_ckt is a subdirectory
    post_ckt_path <- file.path(check_dir, "furtherAnalysis", "post_ckt")
    if (dir.exists(post_ckt_path) &&
        file.exists(file.path(post_ckt_path, "scripts", "config.R"))) {
      return(post_ckt_path)
    }

    check_dir <- dirname(check_dir)
    level <- level + 1
  }

  stop(paste0(
    "\n",
    "========================================\n",
    "ERROR: Could not find project root!\n",
    "========================================\n",
    "\n",
    "Please run scripts from within the post_ckt directory:\n",
    "  cd furtherAnalysis/post_ckt/scripts\n",
    "  Rscript 01_parse_dagitty.R <exposure> <outcome>\n",
    "\n",
    "Current directory: ", getwd(), "\n",
    "\n"
  ))
}

# ============================================
# STANDARD PATH GETTERS
# ============================================

#' Get the input directory path
#' @param root Project root (default: auto-detect)
#' @return Path to input directory
get_input_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "input")
}

#' Get the output directory path
#' @param root Project root (default: auto-detect)
#' @return Path to output directory
get_output_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "output")
}

#' Get the parsed graphs directory path
#' @param root Project root (default: auto-detect)
#' @return Path to parsed_graphs directory
get_parsed_graphs_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "output", "parsed_graphs")
}

#' Get the analysis results directory path
#' @param root Project root (default: auto-detect)
#' @return Path to analysis_results directory
get_analysis_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "output", "analysis_results")
}

#' Get the cycle subgraph directory path
#' @param root Project root (default: auto-detect)
#' @return Path to cycle_subgraph directory
get_cycle_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "output", "cycle_subgraph")
}

#' Get the plots directory path
#' @param root Project root (default: auto-detect)
#' @return Path to plots directory
get_plots_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "output", "plots")
}

#' Get the configs directory path
#' @param root Project root (default: auto-detect)
#' @return Path to configs directory
get_configs_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "configs")
}

# ============================================
# EXPOSURE/OUTCOME PATH HELPERS
# ============================================

#' Build subdirectory name from exposure and outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @return Subdirectory name (e.g., "Depression_Alzheimers")
get_subdir_name <- function(exposure, outcome) {
  paste0(exposure, "_", outcome)
}

#' Get the parsed graph file path for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
#' @return Full path to parsed_graph.rds
get_parsed_graph_path <- function(exposure, outcome, root = NULL) {
  subdir <- get_subdir_name(exposure, outcome)
  file.path(get_parsed_graphs_dir(root), subdir, "parsed_graph.rds")
}

#' Get the analysis output directory for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
#' @return Full path to analysis output directory
get_analysis_output_dir <- function(exposure, outcome, root = NULL) {
  subdir <- get_subdir_name(exposure, outcome)
  file.path(get_analysis_dir(root), subdir)
}

#' Get the cycle subgraph directory for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
#' @return Full path to cycle subgraph directory
get_cycle_output_dir <- function(exposure, outcome, root = NULL) {
  subdir <- get_subdir_name(exposure, outcome)
  file.path(get_cycle_dir(root), subdir)
}

#' Get the plots directory for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
#' @return Full path to plots directory
get_plots_output_dir <- function(exposure, outcome, root = NULL) {
  subdir <- get_subdir_name(exposure, outcome)
  file.path(get_plots_dir(root), subdir)
}

# ============================================
# INPUT FILE HELPERS
# ============================================

#' Find the DAGitty R file for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to DAGitty R file, or NULL if not found
find_dagitty_file <- function(exposure, outcome, degree = 2, root = NULL) {
  input_dir <- get_input_dir(root)

  # Try exact match first
  exact_file <- file.path(input_dir, sprintf("%s_%s_degree_%d.R", exposure, outcome, degree))
  if (file.exists(exact_file)) {
    return(exact_file)
  }

  # Try pattern match
  pattern <- sprintf("%s_%s_degree_%d.R", exposure, outcome, degree)
  matching <- list.files(input_dir, pattern = glob2rx(pattern), full.names = TRUE)

  if (length(matching) > 0) {
    return(matching[1])
  }

  # Try broader pattern
  pattern <- sprintf("%s_%s*.R", exposure, outcome)
  matching <- list.files(input_dir, pattern = glob2rx(pattern), full.names = TRUE)

  if (length(matching) > 0) {
    if (length(matching) > 1) {
      cat("Warning: Multiple matching files found, using:", basename(matching[1]), "\n")
    }
    return(matching[1])
  }

  return(NULL)
}

#' Find the JSON assertions file for a specific exposure/outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
#' @return Full path to JSON file, or NULL if not found
find_json_file <- function(exposure, outcome, root = NULL) {
  input_dir <- get_input_dir(root)

  # Try pattern match
  pattern <- sprintf("%s_%s*.json", exposure, outcome)
  matching <- list.files(input_dir, pattern = glob2rx(pattern), full.names = TRUE)

  if (length(matching) > 0) {
    if (length(matching) > 1) {
      cat("Warning: Multiple JSON files found, using:", basename(matching[1]), "\n")
    }
    return(matching[1])
  }

  return(NULL)
}

# ============================================
# CLI ARGUMENT PARSING
# ============================================

#' Parse exposure and outcome from command line arguments
#'
#' Handles both interactive (RStudio) and CLI modes.
#' In interactive mode, uses default values if provided.
#'
#' @param default_exposure Default exposure for interactive mode (optional)
#' @param default_outcome Default outcome for interactive mode (optional)
#' @return List with exposure and outcome names
parse_exposure_outcome_args <- function(default_exposure = NULL, default_outcome = NULL) {
  if (interactive()) {
    # Interactive mode (RStudio, R console)
    if (!is.null(default_exposure) && !is.null(default_outcome)) {
      cat("Running in interactive mode with defaults:\n")
      cat("  Exposure:", default_exposure, "\n")
      cat("  Outcome:", default_outcome, "\n\n")
      return(list(exposure = default_exposure, outcome = default_outcome))
    } else {
      stop(paste0(
        "Running in interactive mode without defaults.\n",
        "Please either:\n",
        "  1. Run via command line: Rscript script.R <exposure> <outcome>\n",
        "  2. Set default_exposure and default_outcome in the script\n"
      ))
    }
  } else {
    # CLI mode
    args <- commandArgs(trailingOnly = TRUE)

    if (length(args) < 2) {
      stop(paste0(
        "\n",
        "Usage: Rscript ", basename(commandArgs()[4]), " <exposure_name> <outcome_name>\n",
        "\n",
        "Example:\n",
        "  Rscript ", basename(commandArgs()[4]), " Depression Alzheimers\n",
        "\n"
      ))
    }

    return(list(exposure = args[1], outcome = args[2]))
  }
}

# ============================================
# DIRECTORY UTILITIES
# ============================================

#' Ensure a directory exists, creating it if necessary
#' @param path Directory path to ensure
#' @return The path (invisibly)
ensure_dir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE)
    cat("Created directory:", path, "\n")
  }
  invisible(path)
}

#' Create all standard output directories for an exposure/outcome pair
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param root Project root (default: auto-detect)
create_output_dirs <- function(exposure, outcome, root = NULL) {
  ensure_dir(file.path(get_parsed_graphs_dir(root), get_subdir_name(exposure, outcome)))
  ensure_dir(get_analysis_output_dir(exposure, outcome, root))
  ensure_dir(get_cycle_output_dir(exposure, outcome, root))
  ensure_dir(get_plots_output_dir(exposure, outcome, root))
  invisible(TRUE)
}

# ============================================
# LOGGING UTILITIES
# ============================================

#' Print a section header
#' @param title Section title
print_section <- function(title) {
  cat("\n")
  cat("=== ", title, " ===\n", sep = "")
}

#' Print script header with exposure/outcome info
#' @param script_name Name of the script
#' @param exposure Exposure name
#' @param outcome Outcome name
print_header <- function(script_name, exposure, outcome) {
  cat("\n")
  cat(rep("=", 50), "\n", sep = "")
  cat(script_name, "\n")
  cat(rep("=", 50), "\n", sep = "")
  cat("Exposure:", exposure, "\n")
  cat("Outcome:", outcome, "\n")
  cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
  cat(rep("=", 50), "\n", sep = "")
  cat("\n")
}

#' Print script completion message
#' @param script_name Name of the script
print_complete <- function(script_name) {
  cat("\n")
  cat(rep("=", 50), "\n", sep = "")
  cat(script_name, "- COMPLETE\n")
  cat(rep("=", 50), "\n", sep = "")
  cat("\n")
}

# ============================================
# VALIDATION UTILITIES
# ============================================

#' Check if required input files exist
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param require_dagitty Check for DAGitty file
#' @param require_json Check for JSON file
#' @param require_parsed_graph Check for parsed graph
#' @param root Project root (default: auto-detect)
#' @return TRUE if all required files exist, stops with error otherwise
validate_inputs <- function(exposure, outcome,
                           require_dagitty = FALSE,
                           require_json = FALSE,
                           require_parsed_graph = FALSE,
                           root = NULL) {

  if (require_dagitty) {
    dagitty_file <- find_dagitty_file(exposure, outcome, root = root)
    if (is.null(dagitty_file)) {
      stop(paste0(
        "Could not find DAGitty R file for ", exposure, "_", outcome, "\n",
        "Expected location: ", get_input_dir(root), "/", exposure, "_", outcome, "_degree_*.R\n",
        "Please run generate_graph.sh first.\n"
      ))
    }
  }

  if (require_json) {
    json_file <- find_json_file(exposure, outcome, root = root)
    if (is.null(json_file)) {
      stop(paste0(
        "Could not find JSON file for ", exposure, "_", outcome, "\n",
        "Expected location: ", get_input_dir(root), "/", exposure, "_", outcome, "*.json\n",
        "Please run generate_graph.sh first.\n"
      ))
    }
  }

  if (require_parsed_graph) {
    parsed_graph <- get_parsed_graph_path(exposure, outcome, root)
    if (!file.exists(parsed_graph)) {
      stop(paste0(
        "Could not find parsed graph for ", exposure, "_", outcome, "\n",
        "Expected location: ", parsed_graph, "\n",
        "Please run 01_parse_dagitty.R first.\n"
      ))
    }
  }

  invisible(TRUE)
}
