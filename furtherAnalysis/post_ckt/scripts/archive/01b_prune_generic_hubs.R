#!/usr/bin/env Rscript
# 01b_prune_generic_hubs.R
# Prune high-centrality generic nodes from the graph
#
# This script:
#   1. Loads the parsed graph from s1_graph
#   2. Identifies generic nodes from GENERIC_NODES (config.R)
#   3. Removes those nodes from the graph
#   4. Saves the pruned graph for downstream analysis
#
# Usage:
#   Rscript 01b_prune_generic_hubs.R <exposure> <outcome> <degree>
#   Rscript 01b_prune_generic_hubs.R Hypertension Alzheimers 3
#
# NOTE: Run 01a_calculate_centrality.R first to identify nodes to prune

# ---- Load dependencies ----
script_dir <- dirname(normalizePath(commandArgs()[grep("--file=", commandArgs())]))
if (length(script_dir) == 0) script_dir <- getwd()
script_dir <- gsub("--file=", "", script_dir)

source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "utils.R"))

# ---- Load required libraries ----
library(igraph)

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

print_header(paste0("Generic Hub Pruning (Stage 1b) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
cat("Loading graph from:", input_file, "\n")
graph <- readRDS(input_file)
cat("Graph has", vcount(graph), "nodes and", ecount(graph), "edges\n\n")

# ==========================================
# 2. IDENTIFY NODES TO PRUNE
# ==========================================
cat("=== 2. IDENTIFYING NODES TO PRUNE ===\n")

# Get all nodes in the graph
all_nodes <- V(graph)$name

# Find which generic nodes exist in the graph
nodes_to_prune <- intersect(GENERIC_NODES, all_nodes)

cat("Generic nodes defined in config.R:", length(GENERIC_NODES), "\n")
cat("Generic nodes present in graph:", length(nodes_to_prune), "\n\n")

if (length(nodes_to_prune) == 0) {
  cat("WARNING: No generic nodes found in graph!\n")
  cat("Either:\n")
  cat("  1. Update GENERIC_NODES in config.R with nodes to remove\n")
  cat("  2. Or the graph doesn't contain any of the defined generic nodes\n\n")
  
  # Save the original graph as pruned (no changes)
  pruned_graph_file <- file.path(output_dir, "pruned_graph.rds")
  saveRDS(graph, pruned_graph_file)
  cat("No pruning performed. Saved original graph as:", basename(pruned_graph_file), "\n")
  
  cat("\n==================================================\n")
  cat("Generic Hub Pruning - NO CHANGES\n")
  cat("==================================================\n")
  quit(status = 0)
}

cat("Nodes to prune:\n")
for (node in nodes_to_prune) {
  node_degree <- degree(graph, v = node, mode = "all")
  cat("  -", node, "(degree:", node_degree, ")\n")
}

# ==========================================
# 3. PRUNE GRAPH
# ==========================================
cat("\n=== 3. PRUNING GRAPH ===\n")
cat("Removing", length(nodes_to_prune), "nodes from graph...\n")

original_nodes <- vcount(graph)
original_edges <- ecount(graph)

# Remove nodes
pruned_graph <- delete_vertices(graph, nodes_to_prune)

pruned_nodes <- vcount(pruned_graph)
pruned_edges <- ecount(pruned_graph)

cat("\nGraph reduction:\n")
cat("  Nodes:", original_nodes, "->", pruned_nodes, "(-", original_nodes - pruned_nodes, ")\n")
cat("  Edges:", original_edges, "->", pruned_edges, "(-", original_edges - pruned_edges, ")\n")
cat("  Edge reduction:", round((original_edges - pruned_edges) / original_edges * 100, 1), "%\n")

# ==========================================
# 4. SAVE PRUNED GRAPH
# ==========================================
cat("\n=== 4. SAVING PRUNED GRAPH ===\n")

# Save pruned graph
pruned_graph_file <- file.path(output_dir, "pruned_graph.rds")
saveRDS(pruned_graph, pruned_graph_file)
cat("Saved pruned graph to:", basename(pruned_graph_file), "\n")

# Save list of pruned nodes
pruned_nodes_file <- file.path(output_dir, "pruned_nodes.txt")
writeLines(nodes_to_prune, pruned_nodes_file)
cat("Saved pruned nodes list to:", basename(pruned_nodes_file), "\n")

# ==========================================
# 5. SUMMARY
# ==========================================
cat("\n")
cat("============================================================\n")
cat("SUMMARY: Generic Hub Pruning\n")
cat("============================================================\n")
cat("\n")
cat("ORIGINAL Graph:\n")
cat("  Nodes:", original_nodes, "\n")
cat("  Edges:", original_edges, "\n")
cat("\n")
cat("PRUNED Graph:\n")
cat("  Nodes:", pruned_nodes, "\n")
cat("  Edges:", pruned_edges, "\n")
cat("  Nodes removed:", length(nodes_to_prune), "\n")
cat("  Edge reduction:", round((original_edges - pruned_edges) / original_edges * 100, 1), "%\n")
cat("\n")
cat("Output Files:\n")
cat("  - pruned_graph.rds (USE THIS FOR DOWNSTREAM ANALYSIS)\n")
cat("  - pruned_nodes.txt\n")
cat("\n")
cat("NEXT STEP:\n")
cat("  Run downstream analysis scripts (02_basic_analysis.R, etc.)\n")
cat("  They will automatically use the pruned graph.\n")
cat("\n")

cat("==================================================\n")
cat("Generic Hub Pruning - COMPLETE\n")
cat("==================================================\n")
