# 07_confounder_discovery.R
# Identify potential confounders (common parents) and analyze their feedback loops
#
# Input: data/{Exposure}_{Outcome}/s1_graph/pruned_graph.rds
# Output: data/{Exposure}_{Outcome}/s7_confounders/
#   - confounders_list.csv
#   - confounder_summary.txt

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
if (file.exists(file.path(script_dir, "config.R"))) {
  source(file.path(script_dir, "config.R"))
  source(file.path(script_dir, "utils.R"))
} else {
  # Fallback if running from project root
  source("scripts/config.R")
  source("scripts/utils.R")
}

# ---- Load required libraries ----
library(igraph)
library(dplyr)

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 3
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths ----
# We use s1_graph (pruned) as input, similar to other analysis steps
input_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)

# We define a custom output directory since it's not in STAGES
output_dir <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s7_confounders")

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop(paste0("Pruned graph not found at: ", input_file, "\nPlease run 01a_prune_generic_hubs.R first.\n"))
}

ensure_dir(output_dir)

print_header(paste0("Confounder Discovery (Stage 7) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH & IDENTIFY KEY NODES
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
graph <- readRDS(input_file)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n")

# Identify Exposure and Outcome nodes by name
# Note: Input file is likely pruned, so we verify they still exist
if (!(exposure_name %in% V(graph)$name)) {
  stop(paste("Exposure node", exposure_name, "not found in the graph!"))
}
if (!(outcome_name %in% V(graph)$name)) {
  stop(paste("Outcome node", outcome_name, "not found in the graph!"))
}

cat("Exposure Node:", exposure_name, "\n")
cat("Outcome Node:", outcome_name, "\n\n")

# ==========================================
# 2. FIND COMMON PARENTS (POTENTIAL CONFOUNDERS)
# ==========================================
cat("=== 2. IDENTIFYING COMMON PARENTS ===\n")

# Get parents (incoming neighbors)
parents_A <- names(neighbors(graph, exposure_name, mode = "in"))
parents_Y <- names(neighbors(graph, outcome_name, mode = "in"))

cat("Parents of Exposure (A):", length(parents_A), "\n")
cat("Parents of Outcome (Y):", length(parents_Y), "\n")

# Intersect to find common parents
common_parents <- intersect(parents_A, parents_Y)
cat("Common Parents (Intersection):", length(common_parents), "\n\n")

if (length(common_parents) == 0) {
  cat("No common parents found. No confounders to analyze.\n")
  # Save empty results
  write.csv(data.frame(), file.path(output_dir, "confounders_list.csv"))
  quit(save = "no")
}

# ==========================================
# 3. ANALYZE CYCLES FOR EACH CONFOUNDER
# ==========================================
cat("=== 3. ANALYZING CYCLES FOR SAVED CONFOUNDERS ===\n")
cat("checking feedback loops (A -> ... -> C) and (Y -> ... -> C)...\n")

confounder_stats <- data.frame(
  node = character(),
  dist_A_to_C = numeric(), # Distance A -> C
  dist_Y_to_C = numeric(), # Distance Y -> C
  cycle_len_A = numeric(), # Cycle A-C-A length
  cycle_len_Y = numeric(), # Cycle Y-C-Y length
  min_cycle_len = numeric(),
  classification = character(),
  stringsAsFactors = FALSE
)

# Loop through each common parent
count <- 0
for (prop_confounder in common_parents) {
  count <- count + 1
  if (count %% 100 == 0) cat(".")
  
  # 1. Check Cycle with Exposure (A)
  # We know C -> A exists (C is parent).
  # Check if A -> ... -> C exists.
  # If it does, there is a cycle.
  
  # Calculate shortest path A -> C
  path_A_C <- shortest_paths(graph, from = exposure_name, to = prop_confounder, mode = "out")
  len_A_C <- length(path_A_C$vpath[[1]])
  
  # If path found, length > 1 (it includes start node). Steps = length - 1.
  # The vertex sequence includes both start and end. 
  # e.g. A->B->C is 3 vertices. Distance is 2.
  # If no path, vpath is empty (length 0).
  
  dist_A_C <- Inf
  if (len_A_C > 0) {
    dist_A_C <- len_A_C - 1 # Edge count
  }
  
  # 2. Check Cycle with Outcome (Y)
  # We know C -> Y exists.
  # Check if Y -> ... -> C exists.
  
  path_Y_C <- shortest_paths(graph, from = outcome_name, to = prop_confounder, mode = "out")
  len_Y_C <- length(path_Y_C$vpath[[1]])
  
  dist_Y_C <- Inf
  if (len_Y_C > 0) {
    dist_Y_C <- len_Y_C - 1
  }
  
  # 3. Calculate Cycle Lengths
  # If dist_A_C is Inf, then no A->C path, so no cycle.
  # If dist_A_C is finite (e.g. 2), then cycle is A->...->C->A. 
  # The closing edge is C->A (length 1).
  # Total cycle length = dist_A_C + 1.
  
  cycle_len_A <- if(is.infinite(dist_A_C)) Inf else dist_A_C + 1
  cycle_len_Y <- if(is.infinite(dist_Y_C)) Inf else dist_Y_C + 1
  
  min_len <- min(cycle_len_A, cycle_len_Y)
  
  # 4. Classification
  classification <- "Pure Confounder"
  if (!is.infinite(min_len)) {
    if (min_len <= 3) {
      classification <- "Tight Feedback"
    } else {
      classification <- "Long Feedback"
    }
  }
  
  confounder_stats <- rbind(confounder_stats, data.frame(
    node = prop_confounder,
    dist_A_to_C = dist_A_C,
    dist_Y_to_C = dist_Y_C,
    cycle_len_A = cycle_len_A,
    cycle_len_Y = cycle_len_Y,
    min_cycle_len = min_len,
    classification = classification,
    stringsAsFactors = FALSE
  ))
}
cat("\nAnalysis complete.\n\n")

# ==========================================
# 4. REPORTING
# ==========================================
cat("=== 4. SUMMARY ===\n")

# Organize table
confounder_stats <- confounder_stats %>%
  arrange(min_cycle_len, node)

# Print Summary
table_class <- table(confounder_stats$classification)
print(table_class)

# Save complete list (all common parents with classifications)
all_file <- file.path(output_dir, "confounders_all.csv")
write.csv(confounder_stats, all_file, row.names = FALSE)
cat("\nSaved complete list (all common parents) to:", all_file, "\n")

# Filter and save ONLY Pure Confounders (exclude feedback loops)
pure_confounders <- confounder_stats[confounder_stats$classification == "Pure Confounder", ]
pure_file <- file.path(output_dir, "confounders_list.csv")
write.csv(pure_confounders, pure_file, row.names = FALSE)
cat("Saved PURE confounders (valid for adjustment) to:", pure_file, "\n")
cat("  → Pure Confounders:", nrow(pure_confounders), "\n")
cat("  → Excluded (Feedback):", nrow(confounder_stats) - nrow(pure_confounders), "\n\n")

# Save text summary
summary_file <- file.path(output_dir, "confounder_summary.txt")
sink(summary_file)
cat("=== CONFOUNDER ANALYSIS SUMMARY ===\n")
cat("Exposure:", exposure_name, "\n")
cat("Outcome:", outcome_name, "\n")
cat("Common Parents found:", nrow(confounder_stats), "\n\n")

cat("Classification Breakdown:\n")
print(table_class)
cat("\n")

cat("IMPORTANT: Only 'Pure Confounders' are valid for causal adjustment.\n")
cat("Nodes classified as 'Tight Feedback' or 'Long Feedback' are EXCLUDED\n")
cat("because they are effects (descendants) of the exposure or outcome.\n\n")

cat("Pure Confounders (Valid for Adjustment):", nrow(pure_confounders), "\n")
if (nrow(pure_confounders) > 0) {
  print(head(pure_confounders, 20))
} else {
  cat("(None)\n")
}
cat("\n")

cat("Excluded Nodes - Tight Feedback (Cannot be confounders):\n")
tight <- confounder_stats[confounder_stats$classification == "Tight Feedback", ]
if (nrow(tight) > 0) {
  print(head(tight, 20))
} else {
  cat("(None)\n")
}
cat("\n")

cat("Excluded Nodes - Long Feedback (Cannot be confounders):\n")
long <- confounder_stats[confounder_stats$classification == "Long Feedback", ]
if (nrow(long) > 0) {
  print(head(long, 20))
} else {
  cat("(None)\n")
}

sink()
cat("Saved summary to:", summary_file, "\n")

print_complete("Confounder Discovery")
