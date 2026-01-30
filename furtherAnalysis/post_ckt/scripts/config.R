# config.R
# Central configuration file for Post-CKT Analysis Pipeline
#
# Users can modify this file to change default parameters.
# Database credentials should be set in a .env file (see below).
#
# Usage: source("config.R") at the top of each script

# ============================================
# DIRECTORY STRUCTURE
# ============================================
# post_ckt/
# ├── scripts/                          # R scripts
# ├── input/                            # Original CKT input files (.R, .json)
# ├── .env                              # Database credentials (create from .env.example)
# └── data/
#     └── {Exposure}_{Outcome}/
#         ├── s1_graph/                 # Parsed igraph object
#         ├── s2_semantic/              # Semantic type analysis
#         │   └── plots/
#         ├── s3_cycles/                # Cycle detection & analysis
#         │   ├── plots/
#         │   └── subgraphs/
#         ├── s4_node_removal/          # Generic node removal analysis
#         │   └── plots/
#         └── s5_post_removal/          # Post-removal cycle analysis
#             └── plots/

# ============================================
# LOAD .ENV FILE
# ============================================
# Look for .env file in post_ckt directory (parent of scripts)
load_env_file <- function() {
  env_file <- NULL

  # Method 1: Check relative to script location (for Rscript execution)
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    script_path <- normalizePath(sub("--file=", "", file_arg))
    script_dir <- dirname(script_path)
    # .env should be in parent of scripts directory
    env_file <- file.path(dirname(script_dir), ".env")
    if (!file.exists(env_file)) env_file <- NULL
  }

  # Method 2: Check relative to working directory
  if (is.null(env_file)) {
    cwd <- getwd()

    # If we're in scripts directory
    if (basename(cwd) == "scripts") {
      candidate <- file.path(dirname(cwd), ".env")
      if (file.exists(candidate)) env_file <- candidate
    }

    # If we're in post_ckt directory
    if (is.null(env_file)) {
      candidate <- file.path(cwd, ".env")
      if (file.exists(candidate)) env_file <- candidate
    }

    # If we're in project root
    if (is.null(env_file)) {
      candidate <- file.path(cwd, "furtherAnalysis", "post_ckt", ".env")
      if (file.exists(candidate)) env_file <- candidate
    }
  }

  if (!is.null(env_file) && file.exists(env_file)) {
    cat("Loading environment from:", env_file, "\n")
    lines <- readLines(env_file, warn = FALSE)
    for (line in lines) {
      # Skip empty lines and comments
      line <- trimws(line)
      if (nchar(line) == 0 || startsWith(line, "#")) next

      # Parse KEY=VALUE
      if (grepl("=", line)) {
        parts <- strsplit(line, "=", fixed = TRUE)[[1]]
        key <- trimws(parts[1])
        value <- trimws(paste(parts[-1], collapse = "="))
        # Remove surrounding quotes if present
        value <- gsub("^[\"']|[\"']$", "", value)
        # Set environment variable
        do.call(Sys.setenv, setNames(list(value), key))
      }
    }
    return(TRUE)
  } else {
    cat("Warning: .env file not found. Checking environment variables...\n")
    return(FALSE)
  }
}

# Load .env file if it exists
env_loaded <- load_env_file()

# ============================================
# DATABASE CONFIGURATION
# ============================================
# Create a .env file in the post_ckt directory with:
#   CKT_DB_HOST=localhost
#   CKT_DB_PORT=5432
#   CKT_DB_NAME=causalehr_db
#   CKT_DB_USER=your_username
#   CKT_DB_PASSWORD=your_password
#
# Or set environment variables directly before running scripts.

DB_CONFIG <- list(
  host     = Sys.getenv("CKT_DB_HOST", "localhost"),
  port     = as.integer(Sys.getenv("CKT_DB_PORT", "5432")),
  dbname   = Sys.getenv("CKT_DB_NAME", "causalehr_db"),
  user     = Sys.getenv("CKT_DB_USER", ""),
  password = Sys.getenv("CKT_DB_PASSWORD", "")
)

# ============================================
# GRAPH GENERATION PARAMETERS
# ============================================
GRAPH_CONFIG <- list(
  default_degree = 2,
  default_min_pmids = 50,
  predication_types = c("CAUSES", "STIMULATES", "PREVENTS", "INHIBITS")
)

# ============================================
# CYCLE ANALYSIS PARAMETERS
# ============================================
CYCLE_CONFIG <- list(
  max_cycles_to_save = 50,           # Maximum cycle subgraphs to save per SCC
  max_path_length = 10,              # Maximum path length for cycle detection
  sample_cycles_to_find = 5          # Number of sample cycles to display
)

# ============================================
# SEMANTIC TYPE ANALYSIS PARAMETERS
# ============================================
SEMANTIC_CONFIG <- list(
  cycle_participation_threshold = 25,  # % threshold for "problematic" semantic types
  min_nodes_for_problematic = 3,       # Minimum nodes to consider a semantic type problematic
  top_n_display = 20                   # Number of top items to display in reports
)

# ============================================
# NODE REMOVAL PARAMETERS
# ============================================
# Generic/non-specific biomedical terms to consider for removal
# These nodes often create many cycles by connecting unrelated concepts
GENERIC_NODES <- c(
  "Disease",
  "Functional_disorder",
  "Complication",
  "Syndrome",
  "Symptoms",
  "Diagnosis",
  "Obstruction",
  "Physical_findings",
  "Adverse_effects"
)

NODE_REMOVAL_CONFIG <- list(
  top_n_nodes_report = 20,             # Number of top nodes to report by cycle participation
  graph_viz_threshold = 1000,          # Max nodes for full graph visualization
  cycle_subgraph_viz_threshold = 150   # Max nodes for cycle subgraph visualization
)

# ============================================
# VISUALIZATION PARAMETERS
# ============================================
VIZ_CONFIG <- list(
  dpi = 150,
  default_width = 10,
  default_height = 8,
  max_fig_width = 16,
  max_fig_height = 14
)

# ============================================
# FILE NAMING CONVENTION
# ============================================
# Input file pattern: {Exposure}_{Outcome}_degree_{N}.R
# Output subdirectory: {Exposure}_{Outcome}/

FILE_CONFIG <- list(
  input_pattern = "%s_%s_degree_%d.R",              # exposure, outcome, degree
  json_pattern = "%s_%s_causal_assertions_%d.json"  # exposure, outcome, degree
)

# ============================================
# HELPER FUNCTION: Validate DB credentials
# ============================================
validate_db_credentials <- function() {
  if (DB_CONFIG$user == "" || DB_CONFIG$password == "") {
    stop(paste0(
      "\n",
      "========================================\n",
      "ERROR: Database credentials not set!\n",
      "========================================\n",
      "\n",
      "Please set the following environment variables:\n",
      "\n",
      "  export CKT_DB_USER='your_username'\n",
      "  export CKT_DB_PASSWORD='your_password'\n",
      "\n",
      "Optional (if different from defaults):\n",
      "  export CKT_DB_HOST='localhost'\n",
      "  export CKT_DB_PORT='5432'\n",
      "  export CKT_DB_NAME='causalehr_db'\n",
      "\n"
    ))
  }
  invisible(TRUE)
}

# Print config summary (useful for debugging)
print_config <- function() {
  cat("=== Post-CKT Analysis Configuration ===\n\n")

  cat("Database:\n")
  cat("  Host:", DB_CONFIG$host, "\n")
  cat("  Port:", DB_CONFIG$port, "\n")
  cat("  Database:", DB_CONFIG$dbname, "\n")
  cat("  User:", ifelse(DB_CONFIG$user != "", DB_CONFIG$user, "(not set)"), "\n")
  cat("  Password:", ifelse(DB_CONFIG$password != "", "****", "(not set)"), "\n")

  cat("\nGraph Generation:\n")
  cat("  Default degree:", GRAPH_CONFIG$default_degree, "\n")
  cat("  Default min PMIDs:", GRAPH_CONFIG$default_min_pmids, "\n")

  cat("\nCycle Analysis:\n")
  cat("  Max cycles to save:", CYCLE_CONFIG$max_cycles_to_save, "\n")
  cat("  Max path length:", CYCLE_CONFIG$max_path_length, "\n")

  cat("\nSemantic Analysis:\n")
  cat("  Cycle participation threshold:", SEMANTIC_CONFIG$cycle_participation_threshold, "%\n")
  cat("  Min nodes for problematic:", SEMANTIC_CONFIG$min_nodes_for_problematic, "\n")

  cat("\nNode Removal:\n")
  cat("  Generic nodes to remove:", length(GENERIC_NODES), "\n")
  cat("    ", paste(GENERIC_NODES, collapse = ", "), "\n")
  cat("  Top N nodes to report:", NODE_REMOVAL_CONFIG$top_n_nodes_report, "\n")

  cat("\nVisualization:\n")
  cat("  DPI:", VIZ_CONFIG$dpi, "\n")
  cat("  Graph viz threshold:", NODE_REMOVAL_CONFIG$graph_viz_threshold, "nodes\n")

  cat("\n")
}
