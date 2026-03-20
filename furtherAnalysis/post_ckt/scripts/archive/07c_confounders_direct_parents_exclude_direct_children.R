# 07c_confounders_direct_parents_exclude_direct_children.R
# 
# Confounder Discovery - First Pass (1st Degree Relationships Only)
# 
# INCLUSION CRITERIA: Direct parents only (1st degree common parents)
# EXCLUSION CRITERIA: Direct children only (1st degree effects)
#
# This implements the professor's "first pass" approach:
# - Identify confounders as nodes that are DIRECT parents of both Exposure and Outcome
# - Exclude nodes that are DIRECT children of either Exposure or Outcome
# - Focus on immediate relationships to establish baseline before exploring higher degrees
#
# Input: data/{Exposure}_{Outcome}/s1_graph/pruned_graph.rds
# Output: data/{Exposure}_{Outcome}/s7_confounders_1st_degree/
#   - confounders_direct_parents.csv
#   - confounders_summary.txt

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
input_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
output_dir <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s7_confounders_1st_degree")

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop(paste0("Pruned graph not found at: ", input_file, "\nPlease run 01a_prune_generic_hubs.R first.\n"))
}

ensure_dir(output_dir)

print_header(paste0("Confounder Discovery - 1st Degree Only (Stage 7c) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH & IDENTIFY KEY NODES
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
graph <- readRDS(input_file)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n")

# Verify exposure and outcome exist
if (!(exposure_name %in% V(graph)$name)) {
  stop(paste("Exposure node", exposure_name, "not found in the graph!"))
}
if (!(outcome_name %in% V(graph)$name)) {
  stop(paste("Outcome node", outcome_name, "not found in the graph!"))
}

cat("Exposure Node:", exposure_name, "\n")
cat("Outcome Node:", outcome_name, "\n\n")

# ==========================================
# 2. FIND DIRECT PARENTS (POTENTIAL CONFOUNDERS)
# ==========================================
cat("=== 2. IDENTIFYING DIRECT PARENTS ===\n")

# Get DIRECT parents only (incoming neighbors)
parents_A <- names(neighbors(graph, exposure_name, mode = "in"))
parents_Y <- names(neighbors(graph, outcome_name, mode = "in"))

cat("Direct Parents of Exposure (A):", length(parents_A), "\n")
cat("Direct Parents of Outcome (Y):", length(parents_Y), "\n")

# Intersect to find common direct parents
common_parents <- intersect(parents_A, parents_Y)
cat("Common Direct Parents (Potential Confounders):", length(common_parents), "\n\n")

if (length(common_parents) == 0) {
  cat("No common direct parents found. No confounders to analyze.\n")
  write.csv(data.frame(), file.path(output_dir, "confounders_direct_parents.csv"))
  quit(save = "no")
}

# ==========================================
# 2b. BREAK CYCLES FOR STRONG CONFOUNDERS
# ==========================================
# Some nodes (e.g., Diabetes, Obesity) are known confounders but get
# excluded because they are also children of Exposure/Outcome (creating cycles).
# We break the cycle by removing the "effect" edges:
#   Remove: Exposure → Confounder, Outcome → Confounder
#   Keep:   Confounder → Exposure, Confounder → Outcome

strong_in_graph <- intersect(STRONG_CONFOUNDERS, V(graph)$name)
edges_removed <- 0

if (length(strong_in_graph) > 0) {
  cat("\n=== 2b. BREAKING CYCLES FOR STRONG CONFOUNDERS ===\n")
  cat("Strong confounders defined in config:", length(STRONG_CONFOUNDERS), "\n")
  cat("Strong confounders found in graph:", length(strong_in_graph), "\n\n")
  
  for (sc in strong_in_graph) {
    # Remove edge: Exposure → Strong Confounder
    if (are_adjacent(graph, exposure_name, sc)) {
      eid <- get_edge_ids(graph, c(exposure_name, sc))
      if (eid > 0) {
        graph <- delete_edges(graph, eid)
        cat("  Removed edge:", exposure_name, "->", sc, "\n")
        edges_removed <- edges_removed + 1
      }
    }
    # Remove edge: Outcome → Strong Confounder
    if (are_adjacent(graph, outcome_name, sc)) {
      eid <- get_edge_ids(graph, c(outcome_name, sc))
      if (eid > 0) {
        graph <- delete_edges(graph, eid)
        cat("  Removed edge:", outcome_name, "->", sc, "\n")
        edges_removed <- edges_removed + 1
      }
    }
  }
  
  cat("\nTotal effect edges removed:", edges_removed, "\n")
  cat("Graph after cycle-breaking:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")
}

# ==========================================
# 3. FIND DIRECT CHILDREN (FOR EXCLUSION)
# ==========================================
cat("=== 3. IDENTIFYING DIRECT CHILDREN (EFFECTS) ===\n")

# Get DIRECT children only (outgoing neighbors)
# Note: Strong confounders will no longer appear as children 
# because we removed the effect edges above
children_A <- names(neighbors(graph, exposure_name, mode = "out"))
children_Y <- names(neighbors(graph, outcome_name, mode = "out"))

cat("Direct Children of Exposure (A):", length(children_A), "\n")
cat("Direct Children of Outcome (Y):", length(children_Y), "\n")

# Union of all direct children
children_AY <- union(children_A, children_Y)
cat("Total Direct Children (A ∪ Y):", length(children_AY), "\n\n")

# ==========================================
# 4. APPLY EXCLUSION CRITERIA
# ==========================================
cat("=== 4. APPLYING EXCLUSION CRITERIA ===\n")

# Check which common parents are also direct children
excluded_nodes <- intersect(common_parents, children_AY)
cat("Nodes that are BOTH parents AND children (excluded):", length(excluded_nodes), "\n")

if (length(excluded_nodes) > 0) {
  cat("\nExcluded nodes:\n")
  print(excluded_nodes)
  cat("\n")
}

# Final valid confounders = common parents - direct children
valid_confounders <- setdiff(common_parents, children_AY)
cat("Valid Confounders (after exclusion):", length(valid_confounders), "\n\n")

# ==========================================
# 5. SAVE CYCLE-BROKEN GRAPH
# ==========================================
# Save the graph with effect edges removed so downstream scripts
# (09, 10, 10b) can load it directly without repeating cycle-breaking
graph_out_file <- file.path(output_dir, "graph_cycle_broken.rds")
saveRDS(graph, graph_out_file)
cat("=== 5. SAVED CYCLE-BROKEN GRAPH ===\n")
cat("Graph saved to:", graph_out_file, "\n")
cat("(Downstream scripts should load this graph)\n\n")

# ==========================================
# 6. CREATE DETAILED RESULTS
# ==========================================
cat("=== 6. CREATING DETAILED RESULTS ===\n")

# Build results dataframe
confounder_results <- data.frame(
  node = common_parents,
  is_direct_parent_A = common_parents %in% parents_A,
  is_direct_parent_Y = common_parents %in% parents_Y,
  is_direct_child_A = common_parents %in% children_A,
  is_direct_child_Y = common_parents %in% children_Y,
  is_valid_confounder = common_parents %in% valid_confounders,
  exclusion_reason = ifelse(
    common_parents %in% children_AY,
    "Direct child of Exposure/Outcome",
    "None"
  ),
  stringsAsFactors = FALSE
)

# Sort by validity and name
confounder_results <- confounder_results %>%
  arrange(desc(is_valid_confounder), node)

# ==========================================
# 7. SAVE RESULTS
# ==========================================
cat("=== 7. SAVING RESULTS ===\n")

# Save main results
out_file <- file.path(output_dir, "confounders_direct_parents.csv")
write.csv(confounder_results, out_file, row.names = FALSE)
cat("Saved results to:", out_file, "\n")

# Save valid confounders only
valid_file <- file.path(output_dir, "valid_confounders.csv")
valid_df <- confounder_results[confounder_results$is_valid_confounder, ]
write.csv(valid_df, valid_file, row.names = FALSE)
cat("Saved valid confounders to:", valid_file, "\n")

# Save excluded nodes
if (length(excluded_nodes) > 0) {
  excluded_file <- file.path(output_dir, "excluded_nodes.csv")
  excluded_df <- confounder_results[!confounder_results$is_valid_confounder, ]
  write.csv(excluded_df, excluded_file, row.names = FALSE)
  cat("Saved excluded nodes to:", excluded_file, "\n")
}

# ==========================================
# 8. SAVE TEXT SUMMARY
# ==========================================
summary_file <- file.path(output_dir, "confounder_summary.txt")
sink(summary_file)

cat("=== CONFOUNDER ANALYSIS SUMMARY ===\n")
cat("Analysis Type: 1st Degree Relationships Only\n")
cat("Exposure:", exposure_name, "\n")
cat("Outcome:", outcome_name, "\n")
cat("Graph Degree:", degree, "\n\n")

cat("=== INCLUSION CRITERIA ===\n")
cat("- Direct parents ONLY (1st degree incoming edges)\n")
cat("- Must be parent of BOTH Exposure and Outcome\n\n")

cat("=== EXCLUSION CRITERIA ===\n")
cat("- Direct children ONLY (1st degree outgoing edges)\n")
cat("- Exclude if direct child of EITHER Exposure or Outcome\n\n")

cat("=== RESULTS ===\n")
cat("Direct Parents of Exposure:", length(parents_A), "\n")
cat("Direct Parents of Outcome:", length(parents_Y), "\n")
cat("Common Direct Parents:", length(common_parents), "\n\n")

cat("Direct Children of Exposure:", length(children_A), "\n")
cat("Direct Children of Outcome:", length(children_Y), "\n")
cat("Total Direct Children (union):", length(children_AY), "\n\n")

cat("Excluded (are also direct children):", length(excluded_nodes), "\n")
cat("VALID CONFOUNDERS:", length(valid_confounders), "\n\n")

cat("=== VALID CONFOUNDERS LIST ===\n")
if (length(valid_confounders) > 0) {
  for (i in 1:length(valid_confounders)) {
    cat(sprintf("%2d. %s\n", i, valid_confounders[i]))
  }
} else {
  cat("(None)\n")
}
cat("\n")

if (length(excluded_nodes) > 0) {
  cat("=== EXCLUDED NODES (Direct Children) ===\n")
  for (i in 1:length(excluded_nodes)) {
    is_child_A <- excluded_nodes[i] %in% children_A
    is_child_Y <- excluded_nodes[i] %in% children_Y
    reason <- if (is_child_A && is_child_Y) {
      "Child of both A and Y"
    } else if (is_child_A) {
      "Child of Exposure"
    } else {
      "Child of Outcome"
    }
    cat(sprintf("%2d. %s (%s)\n", i, excluded_nodes[i], reason))
  }
  cat("\n")
}

cat("=== INTERPRETATION ===\n")
cat("This analysis focuses on immediate (1st degree) relationships only.\n")
cat("Valid confounders are nodes that:\n")
cat("  1. Have direct edges TO both Exposure and Outcome, AND\n")
cat("  2. Do NOT have direct edges FROM either Exposure or Outcome\n\n")
cat("This establishes a baseline understanding of direct causal relationships\n")
cat("before exploring higher-degree (indirect) paths.\n")

sink()
cat("Saved summary to:", summary_file, "\n\n")

# ==========================================
# 9. PRINT SUMMARY TO CONSOLE
# ==========================================
cat("=== SUMMARY ===\n")
cat("Total common direct parents:", length(common_parents), "\n")
cat("Valid confounders:", length(valid_confounders), "\n")
cat("Excluded (direct children):", length(excluded_nodes), "\n")

print_complete("Confounder Discovery - 1st Degree Only")
