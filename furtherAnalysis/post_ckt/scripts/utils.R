# utils.R
# Shared utility functions for Post-CKT Analysis Pipeline
#
# This file provides:
#   - Automatic project root detection
#   - Stage-based path getters for all directories
#   - CLI argument parsing helpers
#   - Directory creation utilities
#
# Directory Structure:
#   post_ckt/
#   ├── scripts/
#   ├── input/                          # Original CKT input files
#   └── data/
#       └── {Exposure}_{Outcome}/
#           ├── s1_graph/               # Parsed graph
#           ├── s2_semantic/            # Semantic type analysis
#           ├── s3_cycles/              # Cycle detection & analysis
#           ├── s4_node_removal/        # Generic node removal
#           └── s5_post_removal/        # Post-removal analysis
#
# Usage: source("utils.R") at the top of each script (after config.R)

# ============================================
# STAGE DEFINITIONS
# ============================================

STAGES <- list(
  S1_GRAPH = "s1_graph",
  S2_SEMANTIC = "s2_semantic",
  S3_CYCLES = "s3_cycles",
  S4_NODE_REMOVAL = "s4_node_removal",
  S5_POST_REMOVAL = "s5_post_removal"
)

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
    if (file.exists(file.path(check_dir, "scripts", "config.R"))) {
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
# BASE PATH GETTERS
# ============================================

#' Get the input directory path (for original CKT files)
#' @param root Project root (default: auto-detect)
#' @return Path to input directory
get_input_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "input")
}

#' Get the data directory path
#' @param root Project root (default: auto-detect)
#' @return Path to data directory
get_data_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "data")
}

#' Get the configs directory path
#' @param root Project root (default: auto-detect)
#' @return Path to configs directory
get_configs_dir <- function(root = NULL) {
  if (is.null(root)) root <- get_project_root()
  file.path(root, "configs")
}

# ============================================
# EXPOSURE/OUTCOME HELPERS
# ============================================

#' Build subdirectory name from exposure and outcome
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @return Subdirectory name (e.g., "Hypertension_Alzheimers")
get_subdir_name <- function(exposure, outcome) {
  paste0(exposure, "_", outcome)
}

#' Get the base data directory for a specific exposure/outcome/degree
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to exposure/outcome/degree data directory
get_pair_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  subdir <- get_subdir_name(exposure, outcome)
  file.path(get_data_dir(root), subdir, paste0("degree", degree))
}

# ============================================
# STAGE-BASED PATH GETTERS
# ============================================

#' Get stage directory for a specific exposure/outcome/degree
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param stage Stage name (use STAGES constants)
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to stage directory
get_stage_dir <- function(exposure, outcome, stage, degree = 2, root = NULL) {
  file.path(get_pair_dir(exposure, outcome, degree, root), stage)
}

# --- Stage 1: Graph ---

#' Get s1_graph directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s1_graph directory
get_s1_graph_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  get_stage_dir(exposure, outcome, STAGES$S1_GRAPH, degree, root)
}

#' Get the parsed graph file path
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to parsed_graph.rds
get_parsed_graph_path <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s1_graph_dir(exposure, outcome, degree, root), "parsed_graph.rds")
}

# --- Stage 2: Semantic Analysis ---

#' Get s2_semantic directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s2_semantic directory
get_s2_semantic_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  get_stage_dir(exposure, outcome, STAGES$S2_SEMANTIC, degree, root)
}

#' Get s2_semantic plots directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s2_semantic/plots directory
get_s2_plots_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s2_semantic_dir(exposure, outcome, degree, root), "plots")
}

# --- Stage 3: Cycle Detection ---

#' Get s3_cycles directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s3_cycles directory
get_s3_cycles_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  get_stage_dir(exposure, outcome, STAGES$S3_CYCLES, degree, root)
}

#' Get s3_cycles plots directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s3_cycles/plots directory
get_s3_plots_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s3_cycles_dir(exposure, outcome, degree, root), "plots")
}

#' Get s3_cycles subgraphs directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s3_cycles/subgraphs directory
get_s3_subgraphs_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s3_cycles_dir(exposure, outcome, degree, root), "subgraphs")
}

# --- Stage 4: Node Removal ---

#' Get s4_node_removal directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s4_node_removal directory
get_s4_node_removal_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  get_stage_dir(exposure, outcome, STAGES$S4_NODE_REMOVAL, degree, root)
}

#' Get s4_node_removal plots directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s4_node_removal/plots directory
get_s4_plots_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s4_node_removal_dir(exposure, outcome, degree, root), "plots")
}

#' Get pruned graph path (after removing high-centrality generic nodes in step 01a)
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to pruned_graph.rds
get_pruned_graph_path <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s1_graph_dir(exposure, outcome, degree, root), "pruned_graph.rds")
}

#' Get reduced graph path (after removing generic nodes in step 05)
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to reduced_graph.rds
get_reduced_graph_path <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s4_node_removal_dir(exposure, outcome, degree, root), "reduced_graph.rds")
}

# --- Stage 5: Post Removal Analysis ---

#' Get s5_post_removal directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s5_post_removal directory
get_s5_post_removal_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  get_stage_dir(exposure, outcome, STAGES$S5_POST_REMOVAL, degree, root)
}

#' Get s5_post_removal plots directory
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to s5_post_removal/plots directory
get_s5_plots_dir <- function(exposure, outcome, degree = 2, root = NULL) {
  file.path(get_s5_post_removal_dir(exposure, outcome, degree, root), "plots")
}

# ============================================
# BACKWARD COMPATIBILITY (deprecated)
# ============================================
# These functions maintain compatibility with old scripts
# They will be removed in future versions

#' @deprecated Use get_s1_graph_dir instead
get_parsed_graphs_dir <- function(root = NULL) {
  warning("get_parsed_graphs_dir() is deprecated. Use get_s1_graph_dir() instead.")
  if (is.null(root)) root <- get_project_root()
  file.path(root, "data")
}

#' @deprecated Use get_s2_semantic_dir instead
get_analysis_dir <- function(root = NULL) {
  warning("get_analysis_dir() is deprecated. Use stage-specific functions instead.")
  if (is.null(root)) root <- get_project_root()
  file.path(root, "data")
}

#' @deprecated Use get_s3_cycles_dir instead
get_cycle_dir <- function(root = NULL) {
  warning("get_cycle_dir() is deprecated. Use get_s3_cycles_dir() instead.")
  if (is.null(root)) root <- get_project_root()
  file.path(root, "data")
}

#' @deprecated Use stage-specific plot directories instead
get_plots_dir <- function(root = NULL) {
  warning("get_plots_dir() is deprecated. Use stage-specific plot directories instead.")
  if (is.null(root)) root <- get_project_root()
  file.path(root, "data")
}

#' @deprecated Use get_s2_semantic_dir instead
get_analysis_output_dir <- function(exposure, outcome, root = NULL) {
  warning("get_analysis_output_dir() is deprecated. Use stage-specific functions instead.")
  get_s2_semantic_dir(exposure, outcome, root)
}

#' @deprecated Use get_s3_cycles_dir instead
get_cycle_output_dir <- function(exposure, outcome, root = NULL) {
  warning("get_cycle_output_dir() is deprecated. Use get_s3_cycles_dir() instead.")
  get_s3_cycles_dir(exposure, outcome, root)
}

#' @deprecated Use stage-specific plot directories instead
get_plots_output_dir <- function(exposure, outcome, root = NULL) {
  warning("get_plots_output_dir() is deprecated. Use stage-specific plot directories.")
  get_s4_plots_dir(exposure, outcome, root)
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

#' Find the JSON assertions file for a specific exposure/outcome/degree
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
#' @return Full path to JSON file, or NULL if not found
find_json_file <- function(exposure, outcome, degree = 2, root = NULL) {
  input_dir <- get_input_dir(root)

  # Try exact match first
  exact_file <- file.path(input_dir, sprintf("%s_%s_causal_assertions_%d.json", exposure, outcome, degree))
  if (file.exists(exact_file)) {
    return(exact_file)
  }

  # Try pattern match
  pattern <- sprintf("%s_%s*%d.json", exposure, outcome, degree)
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

#' Parse exposure, outcome, and degree from command line arguments
#'
#' Handles both interactive (RStudio) and CLI modes.
#' In interactive mode, uses default values if provided.
#'
#' @param default_exposure Default exposure for interactive mode (optional)
#' @param default_outcome Default outcome for interactive mode (optional)
#' @param default_degree Default degree for interactive mode (default: 2)
#' @return List with exposure, outcome, and degree
parse_exposure_outcome_args <- function(default_exposure = NULL, default_outcome = NULL, default_degree = 2) {
  if (interactive()) {
    # Interactive mode (RStudio, R console)
    if (!is.null(default_exposure) && !is.null(default_outcome)) {
      cat("Running in interactive mode with defaults:\n")
      cat("  Exposure:", default_exposure, "\n")
      cat("  Outcome:", default_outcome, "\n")
      cat("  Degree:", default_degree, "\n\n")
      return(list(exposure = default_exposure, outcome = default_outcome, degree = default_degree))
    } else {
      stop(paste0(
        "Running in interactive mode without defaults.\n",
        "Please either:\n",
        "  1. Run via command line: Rscript script.R <exposure> <outcome> <degree>\n",
        "  2. Set default_exposure and default_outcome in the script\n"
      ))
    }
  } else {
    # CLI mode
    args <- commandArgs(trailingOnly = TRUE)

    if (length(args) < 3) {
      stop(paste0(
        "\n",
        "Usage: Rscript ", basename(commandArgs()[4]), " <exposure> <outcome> <degree>\n",
        "\n",
        "Example:\n",
        "  Rscript ", basename(commandArgs()[4]), " Hypertension Alzheimers 2\n",
        "\n"
      ))
    }

    degree <- as.integer(args[3])
    if (is.na(degree) || degree < 1 || degree > 3) {
      stop("Degree must be 1, 2, or 3")
    }

    return(list(exposure = args[1], outcome = args[2], degree = degree))
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

#' Create all stage directories for an exposure/outcome/degree
#' @param exposure Exposure name
#' @param outcome Outcome name
#' @param degree Graph degree (default: 2)
#' @param root Project root (default: auto-detect)
create_all_stage_dirs <- function(exposure, outcome, degree = 2, root = NULL) {
  ensure_dir(get_s1_graph_dir(exposure, outcome, degree, root))
  ensure_dir(get_s2_semantic_dir(exposure, outcome, degree, root))
  ensure_dir(get_s2_plots_dir(exposure, outcome, degree, root))
  ensure_dir(get_s3_cycles_dir(exposure, outcome, degree, root))
  ensure_dir(get_s3_plots_dir(exposure, outcome, degree, root))
  ensure_dir(get_s3_subgraphs_dir(exposure, outcome, degree, root))
  ensure_dir(get_s4_node_removal_dir(exposure, outcome, degree, root))
  ensure_dir(get_s4_plots_dir(exposure, outcome, degree, root))
  ensure_dir(get_s5_post_removal_dir(exposure, outcome, degree, root))
  ensure_dir(get_s5_plots_dir(exposure, outcome, degree, root))
  invisible(TRUE)
}

#' @deprecated Use create_all_stage_dirs instead
create_output_dirs <- function(exposure, outcome, root = NULL) {
  warning("create_output_dirs() is deprecated. Use create_all_stage_dirs() instead.")
  create_all_stage_dirs(exposure, outcome, root)
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
#' @param degree Graph degree (default: 2)
#' @param require_dagitty Check for DAGitty file
#' @param require_json Check for JSON file
#' @param require_parsed_graph Check for parsed graph (s1)
#' @param require_reduced_graph Check for reduced graph (s4)
#' @param root Project root (default: auto-detect)
#' @return TRUE if all required files exist, stops with error otherwise
validate_inputs <- function(exposure, outcome,
                           degree = 2,
                           require_dagitty = FALSE,
                           require_json = FALSE,
                           require_parsed_graph = FALSE,
                           require_reduced_graph = FALSE,
                           root = NULL) {

  if (require_dagitty) {
    dagitty_file <- find_dagitty_file(exposure, outcome, degree, root = root)
    if (is.null(dagitty_file)) {
      stop(paste0(
        "Could not find DAGitty R file for ", exposure, "_", outcome, "_degree_", degree, "\n",
        "Expected location: ", get_input_dir(root), "/", exposure, "_", outcome, "_degree_", degree, ".R\n",
        "Please run generate_graph.sh first.\n"
      ))
    }
  }

  if (require_json) {
    json_file <- find_json_file(exposure, outcome, degree, root = root)
    if (is.null(json_file)) {
      stop(paste0(
        "Could not find JSON file for ", exposure, "_", outcome, "\n",
        "Expected location: ", get_input_dir(root), "/", exposure, "_", outcome, "*", degree, ".json\n",
        "Please run generate_graph.sh first.\n"
      ))
    }
  }

  if (require_parsed_graph) {
    parsed_graph <- get_parsed_graph_path(exposure, outcome, degree, root)
    if (!file.exists(parsed_graph)) {
      stop(paste0(
        "Could not find parsed graph for ", exposure, "_", outcome, " degree ", degree, "\n",
        "Expected location: ", parsed_graph, "\n",
        "Please run 01_parse_dagitty.R first.\n"
      ))
    }
  }

  if (require_reduced_graph) {
    reduced_graph <- get_reduced_graph_path(exposure, outcome, degree, root)
    if (!file.exists(reduced_graph)) {
      stop(paste0(
        "Could not find reduced graph for ", exposure, "_", outcome, " degree ", degree, "\n",
        "Expected location: ", reduced_graph, "\n",
        "Please run 05_node_removal_impact.R first.\n"
      ))
    }
  }

  invisible(TRUE)
}
