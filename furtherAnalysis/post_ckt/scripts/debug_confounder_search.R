#!/usr/bin/env Rscript

# =============================================================================
# Script: debug_confounder_search.R
# Purpose: Investigate why expected confounders (Obesity, Stress, etc.) are 
#          not appearing in the main analysis.
#          Checks:
#          1. Are these nodes in the graph?
#          2. Are they ancestors of BOTH Exposure and Outcome?
#          3. What is their distance (degree) to E and O?
# =============================================================================

# ---- Load configuration and utilities ----
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }
  return(getwd())
}
script_dir <- get_script_dir()
source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "utils.R"))

suppressPackageStartupMessages({
  library(igraph)
  library(dplyr)
})

# ---- Argument handling ----
# Default to Depression -> Alzheimers
args <- parse_exposure_outcome_args(
  default_exposure = "Depression",
  default_outcome = "Alzheimers",
  default_degree = 3
)
EXPOSURE <- args$exposure
OUTCOME <- args$outcome
DEGREE <- args$degree

# ---- List of Expected Confounders to Check ----
# Based on user input + domain knowledge
target_nodes <- c(
  "Obesity", "Stress", "Oxidative_Stress", "Aging", 
  "Diabetes", "Diabetes_Mellitus", "Cholesterol", "Hypercholesterolemia",
  "Sleep", "Sleep_Initiation_and_Maintenance_Disorders", 
  "Hypertension", "Physical_Activity", "Exercise",
  "Smoking", "Alcohol_Drinking", "Diet", "Inflammation" # Added Inflammation as control (known confounder)
)

# Normalize names for fuzzy matching if needed (simple case-insensitive check first)
# But standard graph nodes are capitalized (e.g., "Depression").

# ---- Paths ----
DATA_DIR <- get_pair_dir(EXPOSURE, OUTCOME, DEGREE)
GRAPH_FILE <- get_pruned_graph_path(EXPOSURE, OUTCOME, DEGREE)
OUTPUT_FILE <- file.path(DATA_DIR, "debug_confounder_search.csv")

# ---- Load Graph ----
cat("Loading graph from:", GRAPH_FILE, "\n")
if (!file.exists(GRAPH_FILE)) stop("Graph file not found!")
g <- readRDS(GRAPH_FILE)
cat("Graph loaded:", vcount(g), "nodes,", ecount(g), "edges\n\n")

# ---- Analysis ----
results <- data.frame(
  Node = character(),
  In_Graph = logical(),
  Is_Direct_Parent_E = logical(),
  Is_Direct_Parent_O = logical(),
  Path_To_Exposure = logical(),
  Dist_To_Exposure = numeric(),
  Path_To_Outcome = logical(),
  Dist_To_Outcome = numeric(),
  Is_Confounder_Any_Degree = logical(),
  stringsAsFactors = FALSE
)

cat(sprintf("%-30s %-10s %-10s %-10s\n", "Node", "In Graph", "Dist to E", "Dist to O"))
cat(paste(rep("-", 70), collapse=""), "\n")

for (target in target_nodes) {
  
  # Check if exists (try exact match first)
  node_name <- NA
  if (target %in% V(g)$name) {
    node_name <- target
  } else {
    # Try case-insensitive search
    matches <- grep(paste0("^", target, "$"), V(g)$name, ignore.case = TRUE, value = TRUE)
    if (length(matches) > 0) node_name <- matches[1]
  }
  
  if (is.na(node_name)) {
    # Not found
    cat(sprintf("%-30s %-10s %-10s %-10s\n", target, "NO", "-", "-"))
    results <- rbind(results, data.frame(
      Node = target,
      In_Graph = FALSE,
      Is_Direct_Parent_E = FALSE,
      Is_Direct_Parent_O = FALSE,
      Path_To_Exposure = FALSE,
      Dist_To_Exposure = NA,
      Path_To_Outcome = FALSE,
      Dist_To_Outcome = NA,
      Is_Confounder_Any_Degree = FALSE
    ))
  } else {
    # Found
    
    # 1. Distances (Shortest Path)
    # Distance FROM candidate TO Exposure (because confounder causes exposure)
    # Path: Candidate -> ... -> Exposure
    d_E <- shortest_paths(g, from = node_name, to = EXPOSURE, mode = "out")$vpath[[1]]
    dist_E <- if (length(d_E) > 0) length(d_E) - 1 else Inf
    
    # Distance FROM candidate TO Outcome
    # Path: Candidate -> ... -> Outcome
    d_O <- shortest_paths(g, from = node_name, to = OUTCOME, mode = "out")$vpath[[1]]
    dist_O <- if (length(d_O) > 0) length(d_O) - 1 else Inf
    
    # 2. Direct Parent Check
    is_parent_E <- (dist_E == 1)
    is_parent_O <- (dist_O == 1)
    
    # 3. Ancestry Check
    is_ancestor <- (dist_E < Inf && dist_O < Inf)
    
    cat(sprintf("%-30s %-10s %-10s %-10s\n", node_name, "YES", 
                ifelse(is.infinite(dist_E), "Inf", dist_E), 
                ifelse(is.infinite(dist_O), "Inf", dist_O)))
    
    results <- rbind(results, data.frame(
      Node = node_name,
      In_Graph = TRUE,
      Is_Direct_Parent_E = is_parent_E,
      Is_Direct_Parent_O = is_parent_O,
      Path_To_Exposure = (dist_E < Inf),
      Dist_To_Exposure = dist_E,
      Path_To_Outcome = (dist_O < Inf),
      Dist_To_Outcome = dist_O,
      Is_Confounder_Any_Degree = is_ancestor
    ))
  }
}

cat(paste(rep("-", 70), collapse=""), "\n\n")

# ---- Summary ----
cat("=== Summary ===\n")
valid_deep_confounders <- results %>% 
  filter(In_Graph, Is_Confounder_Any_Degree, (!Is_Direct_Parent_E | !Is_Direct_Parent_O))

if (nrow(valid_deep_confounders) > 0) {
  cat("Found", nrow(valid_deep_confounders), "potential HIGHER-DEGREE confounders (ancestors of both, but not direct parents of both):\n")
  print(valid_deep_confounders[, c("Node", "Dist_To_Exposure", "Dist_To_Outcome")])
} else {
  cat("No higher-degree confounders found among the target list.\n")
}

write.csv(results, OUTPUT_FILE, row.names = FALSE)
cat("\nResults saved to:", OUTPUT_FILE, "\n")
