# 04a_cycle_detection.R
# Detect cycles in the graph and analyze nodes participating in cycles
#
# Input: data/{Exposure}_{Outcome}/s1_graph/parsed_graph.rds
# Output: data/{Exposure}_{Outcome}/s2_semantic/
#   - node_centrality_and_cycles.csv
#   - nodes_in_cycles.txt
#   - strongly_connected_components.csv
#   - cycle_detection_summary.txt

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

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 2
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths using utility functions ----
input_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
output_dir <- get_s2_semantic_dir(exposure_name, outcome_name, degree)

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop(paste0("Pruned graph not found at: ", input_file, "\nPlease run 01a_prune_generic_hubs.R first.\n"))
}

print_header(paste0("Cycle Detection Analysis (Stage 2) - Degree ", degree), exposure_name, outcome_name)
cat("Loading graph from:", input_file, "\n\n")

# Load the pruned graph
graph <- readRDS(input_file)

cat("Graph has", vcount(graph), "nodes and", ecount(graph), "edges\n\n")

# ==========================================
# 1. CHECK IF GRAPH IS A DAG
# ==========================================
cat("=== 1. DAG VALIDATION ===\n")
is_dag <- is_dag(graph)
cat("Is this a Directed Acyclic Graph (DAG)?", is_dag, "\n")

if (is_dag) {
  cat("SUCCESS: Graph is a valid DAG (no cycles found)\n\n")
} else {
  cat("PROBLEM: Graph contains cycles (not a valid DAG)\n\n")
}

# ==========================================
# 2. FIND ALL STRONGLY CONNECTED COMPONENTS
# ==========================================
cat("=== 2. STRONGLY CONNECTED COMPONENTS (SCCs) ===\n")
cat("SCCs are maximal subgraphs where every node can reach every other node.\n")
cat("SCCs with size > 1 indicate the presence of cycles.\n\n")

scc <- components(graph, mode = "strong")
cat("Number of strongly connected components:", scc$no, "\n")
cat("Component sizes:\n")
scc_sizes <- table(scc$csize)
print(scc_sizes)
cat("\n")

# Find components with more than 1 node (these contain cycles)
large_components <- which(scc$csize > 1)
cat("Number of SCCs with size > 1 (containing cycles):", length(large_components), "\n")

if (length(large_components) > 0) {
  cat("\nLarge SCCs (size > 1):\n")
  for (i in large_components) {
    comp_nodes <- V(graph)[scc$membership == i]$name
    cat("  Component", i, ": size =", length(comp_nodes), "\n")
    if (length(comp_nodes) <= 10) {
      cat("    Nodes:", paste(comp_nodes, collapse = ", "), "\n")
    } else {
      cat("    Nodes (first 10):", paste(comp_nodes[1:10], collapse = ", "), "...\n")
    }
  }
  cat("\n")
}

# ==========================================
# 3. IDENTIFY NODES IN CYCLES
# ==========================================
cat("=== 3. NODES PARTICIPATING IN CYCLES ===\n")

# Nodes in SCCs with size > 1 are participating in cycles
nodes_in_cycles <- V(graph)[scc$csize[scc$membership] > 1]$name
cat("Total nodes participating in cycles:", length(nodes_in_cycles), "\n")
cat("Percentage of graph:", round(100 * length(nodes_in_cycles) / vcount(graph), 2), "%\n\n")

if (length(nodes_in_cycles) > 0) {
  cat("Nodes in cycles (first 50):\n")
  print(head(nodes_in_cycles, 50))
  cat("\n")

  # Check if exposure and outcome are in cycles
  exposure_nodes <- V(graph)[V(graph)$type == "exposure"]$name
  outcome_nodes <- V(graph)[V(graph)$type == "outcome"]$name

  if (any(exposure_nodes %in% nodes_in_cycles)) {
    cat("WARNING: Exposure node(s) participate in cycles:",
        exposure_nodes[exposure_nodes %in% nodes_in_cycles], "\n")
  }
  if (any(outcome_nodes %in% nodes_in_cycles)) {
    cat("WARNING: Outcome node(s) participate in cycles:",
        outcome_nodes[outcome_nodes %in% nodes_in_cycles], "\n")
  }
  cat("\n")
}

# ==========================================
# 4. FIND SPECIFIC CYCLES (Sample)
# ==========================================
cat("=== 4. SAMPLE CYCLE DETECTION ===\n")
cat("Finding simple cycles involving high-degree nodes...\n")
cat("(This can be computationally expensive, limiting to first few)\n\n")

# Get top 10 nodes by degree that are in cycles
degree_data <- data.frame(
  Node = V(graph)$name,
  Total_Degree = degree(graph, mode = "all"),
  In_Cycles = V(graph)$name %in% nodes_in_cycles
)
degree_data <- degree_data[order(-degree_data$Total_Degree), ]

high_degree_in_cycles <- degree_data[degree_data$In_Cycles == TRUE, ]
cat("High-degree nodes in cycles (top 20):\n")
print(head(high_degree_in_cycles, 20))
cat("\n")

# Try to find a few example cycles
cat("Attempting to find sample cycles...\n")
sample_cycles_found <- 0
max_cycles_to_find <- 5

if (length(nodes_in_cycles) > 0) {
  # Pick a few nodes from the largest SCC to find cycles
  largest_scc_id <- which.max(scc$csize)
  largest_scc_nodes <- V(graph)[scc$membership == largest_scc_id]$name

  cat("Largest SCC contains", length(largest_scc_nodes), "nodes\n")

  # Try to find cycles starting from high-degree nodes in this SCC
  test_nodes <- intersect(head(high_degree_in_cycles$Node, 5), largest_scc_nodes)

  for (start_node in test_nodes) {
    if (sample_cycles_found >= max_cycles_to_find) break

    # Find neighbors
    neighbors_out <- neighbors(graph, start_node, mode = "out")

    for (next_node in neighbors_out$name) {
      if (sample_cycles_found >= max_cycles_to_find) break

      # Check if there's a path back to start_node
      paths <- all_simple_paths(graph, from = next_node, to = start_node, mode = "out", cutoff = 10)

      if (length(paths) > 0) {
        # Found a cycle!
        sample_cycles_found <- sample_cycles_found + 1
        cycle_path <- c(start_node, names(paths[[1]]))
        cat("\nCycle", sample_cycles_found, "(length", length(cycle_path), "):\n")
        cat("  ", paste(cycle_path, collapse = " -> "), "\n")
      }
    }
  }

  if (sample_cycles_found == 0) {
    cat("(No cycles found in sample - try increasing search depth)\n")
  }
  cat("\n")
}



# ==========================================
# 5. CALCULATE CENTRALITY METRICS
# ==========================================
cat("=== 5. CENTRALITY METRICS ===\n")
cat("Computing centrality metrics for all nodes...\n\n")

# Degree centrality (already computed)
degree_cent <- degree(graph, mode = "all")
in_degree <- degree(graph, mode = "in")
out_degree <- degree(graph, mode = "out")

# Betweenness centrality (how often a node appears on shortest paths)
cat("Computing betweenness centrality...\n")
betweenness_cent <- betweenness(graph, directed = TRUE)

# Closeness centrality (how close a node is to all other nodes)
cat("Computing closeness centrality...\n")
closeness_cent <- closeness(graph, mode = "all")

# PageRank (importance based on incoming links)
cat("Computing PageRank...\n")
pagerank_cent <- page_rank(graph)$vector

cat("Centrality metrics computed successfully!\n\n")

# ==========================================
# 6. ANALYZE NODES IN CYCLES BY CENTRALITY
# ==========================================
cat("=== 6. CENTRALITY ANALYSIS OF NODES IN CYCLES ===\n")

centrality_data <- data.frame(
  Node = V(graph)$name,
  Type = V(graph)$type,
  In_Degree = in_degree,
  Out_Degree = out_degree,
  Total_Degree = degree_cent,
  Betweenness = betweenness_cent,
  Closeness = closeness_cent,
  PageRank = pagerank_cent,
  In_Cycle = V(graph)$name %in% nodes_in_cycles,
  SCC_ID = scc$membership,
  SCC_Size = scc$csize[scc$membership]
)

# Sort by betweenness (nodes on many shortest paths)
centrality_data <- centrality_data[order(-centrality_data$Betweenness), ]

cat("Top 20 nodes by Betweenness Centrality:\n")
print(head(centrality_data[, c("Node", "Total_Degree", "Betweenness", "In_Cycle", "SCC_Size")], 20))
cat("\n")

# Nodes in cycles sorted by betweenness
nodes_in_cycles_data <- centrality_data[centrality_data$In_Cycle == TRUE, ]
cat("Top 20 nodes IN CYCLES by Betweenness:\n")
print(head(nodes_in_cycles_data[, c("Node", "Total_Degree", "Betweenness", "SCC_Size")], 20))
cat("\n")

# Statistics on centrality for nodes in cycles vs not in cycles
cat("=== Centrality Statistics: Nodes in Cycles vs Not in Cycles ===\n")
cat("\nNodes IN cycles:\n")
cat("  Count:", sum(centrality_data$In_Cycle), "\n")
cat("  Mean degree:", round(mean(centrality_data$Total_Degree[centrality_data$In_Cycle]), 2), "\n")
cat("  Mean betweenness:", round(mean(centrality_data$Betweenness[centrality_data$In_Cycle]), 2), "\n")
cat("  Mean PageRank:", round(mean(centrality_data$PageRank[centrality_data$In_Cycle]), 4), "\n")

cat("\nNodes NOT in cycles:\n")
cat("  Count:", sum(!centrality_data$In_Cycle), "\n")
cat("  Mean degree:", round(mean(centrality_data$Total_Degree[!centrality_data$In_Cycle]), 2), "\n")
cat("  Mean betweenness:", round(mean(centrality_data$Betweenness[!centrality_data$In_Cycle]), 2), "\n")
cat("  Mean PageRank:", round(mean(centrality_data$PageRank[!centrality_data$In_Cycle]), 4), "\n")
cat("\n")

# ==========================================
# 7. SAVE RESULTS
# ==========================================
cat("=== 7. SAVING RESULTS ===\n")

# Create output directory if needed
ensure_dir(output_dir)

# Save centrality data with cycle information
output_file <- file.path(output_dir, "node_centrality_and_cycles.csv")
write.csv(centrality_data, output_file, row.names = FALSE)
cat("Saved centrality and cycle data to:", output_file, "\n")

# Save list of nodes in cycles
cycles_file <- file.path(output_dir, "nodes_in_cycles.txt")
writeLines(nodes_in_cycles, cycles_file)
cat("Saved list of nodes in cycles to:", cycles_file, "\n")

# Save SCC information
scc_file <- file.path(output_dir, "strongly_connected_components.csv")
scc_data <- data.frame(
  Node = V(graph)$name,
  SCC_ID = scc$membership,
  SCC_Size = scc$csize[scc$membership]
)
scc_data <- scc_data[order(-scc_data$SCC_Size, scc_data$SCC_ID), ]
write.csv(scc_data, scc_file, row.names = FALSE)
cat("Saved SCC information to:", scc_file, "\n")

# Save summary statistics
summary_file <- file.path(output_dir, "cycle_detection_summary.txt")
sink(summary_file)
cat("=== CYCLE DETECTION SUMMARY ===\n\n")
cat("Graph: ", vcount(graph), " nodes, ", ecount(graph), " edges\n\n", sep = "")
cat("Is DAG (no cycles):", is_dag, "\n\n")
cat("Strongly Connected Components:\n")
cat("  Total SCCs:", scc$no, "\n")
cat("  SCCs with size > 1:", length(large_components), "\n")
cat("  Largest SCC size:", max(scc$csize), "\n\n")
cat("Nodes in Cycles:\n")
cat("  Count:", length(nodes_in_cycles), "\n")
cat("  Percentage:", round(100 * length(nodes_in_cycles) / vcount(graph), 2), "%\n\n")
cat("Centrality Statistics:\n")
cat("  Nodes in cycles - Mean degree:", round(mean(centrality_data$Total_Degree[centrality_data$In_Cycle]), 2), "\n")
cat("  Nodes NOT in cycles - Mean degree:", round(mean(centrality_data$Total_Degree[!centrality_data$In_Cycle]), 2), "\n")
cat("  Nodes in cycles - Mean betweenness:", round(mean(centrality_data$Betweenness[centrality_data$In_Cycle]), 2), "\n")
cat("  Nodes NOT in cycles - Mean betweenness:", round(mean(centrality_data$Betweenness[!centrality_data$In_Cycle]), 2), "\n")
sink()
cat("Saved summary to:", summary_file, "\n")

print_complete("Cycle Detection Analysis")
