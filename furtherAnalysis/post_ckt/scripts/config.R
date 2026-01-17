# config.R
# Central configuration file for Post-CKT Analysis Pipeline
#
# Users can modify this file to change default parameters.
# Database credentials should be set via environment variables for security.
#
# Usage: source("config.R") at the top of each script

# ============================================
# DATABASE CONFIGURATION
# ============================================
# Set these environment variables before running scripts:
#   export CKT_DB_HOST="localhost"
#   export CKT_DB_PORT="5432"
#   export CKT_DB_NAME="causalehr_db"
#   export CKT_DB_USER="your_username"
#   export CKT_DB_PASSWORD="your_password"

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
# VISUALIZATION PARAMETERS
# ============================================
VIZ_CONFIG <- list(
  dpi = 300,
  default_width = 10,
  default_height = 8,
  max_fig_width = 16,
  max_fig_height = 12
)

# ============================================
# FILE NAMING CONVENTION
# ============================================
# Input file pattern: {Exposure}_{Outcome}_degree_{N}.R
# Output subdirectory: {Exposure}_{Outcome}/

FILE_CONFIG <- list(
  input_pattern = "%s_%s_degree_%d.R",           # exposure, outcome, degree
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

  cat("\n")
}
