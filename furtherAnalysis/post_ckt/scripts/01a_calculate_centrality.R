#!/usr/bin/env Rscript
# 01a_calculate_centrality.R
# Calculate node centrality metrics and save for review
#
# This script:
#   1. Loads the parsed graph from s1_graph
#   2. Calculates degree centrality and betweenness centrality
#   3. Saves top N high-centrality nodes to CSV for review
#   4. Does NOT prune - just provides data for decision-making
#
# Usage:
#   Rscript 01a_calculate_centrality.R <exposure> <outcome> <degree>
#   Rscript 01a_calculate_centrality.R Hypertension Alzheimers 3

# ---- Load dependencies ----
script_dir <- dirname(normalizePath(commandArgs()[grep("--file=", commandArgs())]))
if (length(script_dir) == 0) script_dir <- getwd()
script_dir <- gsub("--file=", "", script_dir)

source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "utils.R"))

# ---- Load required libraries ----
library(igraph)
library(dplyr)

# ---- Configuration ----
TOP_N_CENTRALITY <- 150  # Number of top nodes to report

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 2
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths ----
input_file <- get_parsed_graph_path(exposure_name, outcome_name, degree)
output_dir <- get_s1_graph_dir(exposure_name, outcome_name, degree)

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop(paste0(
    "Parsed graph not found at: ", input_file, "\n",
    "Please run 01_parse_dagitty.R first.\n"
  ))
}

print_header(paste0("Node Centrality Analysis (Stage 1a) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
cat("Loading graph from:", input_file, "\n")
graph <- readRDS(input_file)
cat("Graph has", vcount(graph), "nodes and", ecount(graph), "edges\n\n")

# ==========================================
# 2. CALCULATE CENTRALITY METRICS
# ==========================================
cat("=== 2. CALCULATING CENTRALITY ===\n")

# Calculate degree centrality
cat("Calculating degree centrality...\n")
in_degree <- degree(graph, mode = "in")
out_degree <- degree(graph, mode = "out")
total_degree <- degree(graph, mode = "all")

# Calculate betweenness centrality (this may take a moment for large graphs)
cat("Calculating betweenness centrality (this may take a moment)...\n")
start_time <- Sys.time()
betweenness_cent <- betweenness(graph, directed = TRUE, normalized = FALSE)
end_time <- Sys.time()
cat("  Betweenness calculation took", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

# Create a data frame with all centrality metrics
centrality_df <- data.frame(
  node = V(graph)$name,
  in_degree = in_degree,
  out_degree = out_degree,
  total_degree = total_degree,
  betweenness = betweenness_cent,
  stringsAsFactors = FALSE
)

cat("\nCentrality calculation complete.\n")
cat("  Degree - Min:", min(total_degree), " Max:", max(total_degree), " Mean:", round(mean(total_degree), 2), "\n")
cat("  Betweenness - Min:", round(min(betweenness_cent), 1), " Max:", round(max(betweenness_cent), 1), " Mean:", round(mean(betweenness_cent), 1), "\n\n")

# ==========================================
# 3. IDENTIFY TOP N HIGH-CENTRALITY NODES (by Degree)
# ==========================================
cat("=== 3. TOP", TOP_N_CENTRALITY, "NODES BY DEGREE ===\n")

top_by_degree <- centrality_df %>%
  arrange(desc(total_degree)) %>%
  head(TOP_N_CENTRALITY)

# Check which are in the GENERIC_NODES list
top_by_degree$is_generic <- top_by_degree$node %in% GENERIC_NODES

# Print summary
cat("\nTop 30 nodes by total degree:\n")
print(head(top_by_degree[, c("node", "total_degree", "betweenness", "is_generic")], 30), row.names = FALSE)

# Count generic nodes in top N
n_generic_degree <- sum(top_by_degree$is_generic)
cat("\n\nGeneric nodes found in top", TOP_N_CENTRALITY, "by degree:", n_generic_degree, "\n")
if (n_generic_degree > 0) {
  generic_in_degree <- top_by_degree$node[top_by_degree$is_generic]
  cat("  ", paste(generic_in_degree, collapse = ", "), "\n")
}

# ==========================================
# 4. IDENTIFY TOP N HIGH-BETWEENNESS NODES
# ==========================================
cat("\n=== 4. TOP", TOP_N_CENTRALITY, "NODES BY BETWEENNESS ===\n")

top_by_betweenness <- centrality_df %>%
  arrange(desc(betweenness)) %>%
  head(TOP_N_CENTRALITY)

# Check which are in the GENERIC_NODES list
top_by_betweenness$is_generic <- top_by_betweenness$node %in% GENERIC_NODES

# Print summary
cat("\nTop 30 nodes by betweenness:\n")
print(head(top_by_betweenness[, c("node", "betweenness", "total_degree", "is_generic")], 30), row.names = FALSE)

# Count generic nodes in top N
n_generic_betweenness <- sum(top_by_betweenness$is_generic)
cat("\n\nGeneric nodes found in top", TOP_N_CENTRALITY, "by betweenness:", n_generic_betweenness, "\n")
if (n_generic_betweenness > 0) {
  generic_in_betweenness <- top_by_betweenness$node[top_by_betweenness$is_generic]
  cat("  ", paste(generic_in_betweenness, collapse = ", "), "\n")
}

# ==========================================
# 5. SAVE CENTRALITY RESULTS
# ==========================================
cat("\n=== 5. SAVING CENTRALITY RESULTS ===\n")

# Save top N nodes by degree
top_degree_file <- file.path(output_dir, paste0("top_", TOP_N_CENTRALITY, "_by_degree.csv"))
write.csv(top_by_degree, top_degree_file, row.names = FALSE)
cat("Saved top", TOP_N_CENTRALITY, "by degree to:", basename(top_degree_file), "\n")

# Save top N nodes by betweenness
top_betweenness_file <- file.path(output_dir, paste0("top_", TOP_N_CENTRALITY, "_by_betweenness.csv"))
write.csv(top_by_betweenness, top_betweenness_file, row.names = FALSE)
cat("Saved top", TOP_N_CENTRALITY, "by betweenness to:", basename(top_betweenness_file), "\n")

# Save full centrality data
full_centrality_file <- file.path(output_dir, "all_nodes_centrality.csv")
write.csv(centrality_df, full_centrality_file, row.names = FALSE)
cat("Saved all nodes centrality to:", basename(full_centrality_file), "\n")

# ==========================================
# 6. SUMMARY
# ==========================================
cat("\n")
cat("============================================================\n")
cat("SUMMARY: Node Centrality Analysis\n")
cat("============================================================\n")
cat("\n")
cat("Graph:\n")
cat("  Nodes:", vcount(graph), "\n")
cat("  Edges:", ecount(graph), "\n")
cat("\n")
cat("Generic nodes in top", TOP_N_CENTRALITY, "by DEGREE:", n_generic_degree, "\n")
cat("Generic nodes in top", TOP_N_CENTRALITY, "by BETWEENNESS:", n_generic_betweenness, "\n")
cat("\n")
cat("Output Files:\n")
cat("  - ", basename(top_degree_file), "\n")
cat("  - ", basename(top_betweenness_file), "\n")
cat("  - ", basename(full_centrality_file), "\n")
cat("\n")
cat("NEXT STEPS:\n")
cat("  1. Review the CSV files to identify generic/non-specific nodes\n")
cat("  2. Update GENERIC_NODES list in config.R\n")
cat("  3. Run 01b_prune_generic_hubs.R to prune the graph\n")
cat("\n")

cat("==================================================\n")
cat("Centrality Analysis - COMPLETE\n")
cat("==================================================\n")
