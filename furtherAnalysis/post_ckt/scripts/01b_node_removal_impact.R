# 01b_node_removal_impact.R
# Evaluate the impact of removing generic/non-specific nodes using centrality metrics
#
# This script:
# 1. Loads the top-150 centrality/betweenness nodes from 01a
# 2. Cross-references with GENERIC_NODES from config to find candidates
# 3. For each candidate, evaluates: edges removed, SCC reduction
# 4. Produces impact comparison chart and summary table
#
# NOTE: This is an ANALYSIS script — it does NOT modify the graph.
#       The actual pruning is done by 01c_prune_generic_hubs.R
#
# Input:
#   - data/{E}_{O}/degreeN/s1_graph/parsed_graph.rds
#   - data/{E}_{O}/degreeN/s1_graph/top_150_by_degree.csv       (from 01a)
#   - data/{E}_{O}/degreeN/s1_graph/top_150_by_betweenness.csv  (from 01a)
# Output: data/{E}_{O}/degreeN/s1_graph/
#   - node_removal_impact.csv
#   - node_removal_summary.csv
#   - plots/node_removal_impact.png

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
library(ggplot2)

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
s1_dir <- get_s1_graph_dir(exposure_name, outcome_name, degree)
plots_dir <- file.path(s1_dir, "plots")

# Dynamically find top_N CSV files (01a generates these)
top_degree_file <- list.files(s1_dir, pattern = "^top_[0-9]+_by_degree\\.csv$", full.names = TRUE)
top_betweenness_file <- list.files(s1_dir, pattern = "^top_[0-9]+_by_betweenness\\.csv$", full.names = TRUE)

if (length(top_degree_file) == 0) {
  cat("WARNING: No top_N_by_degree.csv file found in", s1_dir, "\n")
}
if (length(top_betweenness_file) == 0) {
  cat("WARNING: No top_N_by_betweenness.csv file found in", s1_dir, "\n")
}

# Use first match if multiple files exist
if (length(top_degree_file) > 0) top_degree_file <- top_degree_file[1]
if (length(top_betweenness_file) > 0) top_betweenness_file <- top_betweenness_file[1]

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop("Parsed graph not found at: ", input_file, "\nPlease run 01_parse_dagitty.R first.\n")
}
ensure_dir(s1_dir)
ensure_dir(plots_dir)

print_header(paste0("Node Removal Impact Analysis (Centrality-Based) - Degree ", degree),
             exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
cat("Loading graph from:", input_file, "\n")
graph <- readRDS(input_file)
cat("Graph:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")

# ==========================================
# 2. LOAD TOP-N CENTRALITY LISTS FROM 01a
# ==========================================
cat("=== 2. LOADING TOP-N CENTRALITY LISTS ===\n")

top_degree_nodes <- character(0)
top_betweenness_nodes <- character(0)

if (file.exists(top_degree_file)) {
  top_degree_df <- read.csv(top_degree_file, stringsAsFactors = FALSE)
  top_degree_nodes <- top_degree_df$node
  cat("Loaded top", length(top_degree_nodes), "nodes by degree\n")
} else {
  cat("WARNING: Top degree file not found at:", top_degree_file, "\n")
  cat("  Computing degree inline...\n")
  deg <- sort(degree(graph, mode = "all"), decreasing = TRUE)
  top_degree_nodes <- names(head(deg, 150))
}

if (file.exists(top_betweenness_file)) {
  top_betw_df <- read.csv(top_betweenness_file, stringsAsFactors = FALSE)
  top_betweenness_nodes <- top_betw_df$node
  cat("Loaded top", length(top_betweenness_nodes), "nodes by betweenness\n")
} else {
  cat("WARNING: Top betweenness file not found at:", top_betweenness_file, "\n")
  cat("  Computing betweenness inline...\n")
  bw <- sort(betweenness(graph, directed = TRUE), decreasing = TRUE)
  top_betweenness_nodes <- names(head(bw, 150))
}

# Union of top-150 lists
top_nodes_union <- unique(c(top_degree_nodes, top_betweenness_nodes))
cat("Unique nodes in top-150 lists:", length(top_nodes_union), "\n\n")

# ==========================================
# 3. IDENTIFY CANDIDATE NODES FOR REMOVAL
# ==========================================
cat("=== 3. IDENTIFYING GENERIC NODES IN TOP-150 ===\n")

# Cross-reference: GENERIC_NODES that appear in the top-150 lists
candidates <- GENERIC_NODES[GENERIC_NODES %in% top_nodes_union]
candidates <- candidates[candidates %in% V(graph)$name]  # Must exist in graph

# Also flag generic nodes NOT in top-150 (low priority)
generic_not_in_top <- GENERIC_NODES[GENERIC_NODES %in% V(graph)$name & !(GENERIC_NODES %in% top_nodes_union)]

cat("GENERIC_NODES in top-150 centrality lists:", length(candidates), "\n")
if (length(candidates) > 0) {
  cat("  Candidates:", paste(candidates, collapse = ", "), "\n")
}
cat("GENERIC_NODES NOT in top-150 (low centrality, less impactful):", length(generic_not_in_top), "\n")
if (length(generic_not_in_top) > 0) {
  cat("  Low-priority:", paste(generic_not_in_top, collapse = ", "), "\n")
}
cat("\n")

if (length(candidates) == 0) {
  cat("No generic nodes found in top-150 centrality lists.\n")
  cat("Nothing to analyze. Exiting.\n")
  print_complete("Node Removal Impact Analysis")
  quit(save = "no")
}

# ==========================================
# 4. BASELINE SCC ANALYSIS
# ==========================================
cat("=== 4. BASELINE SCC ANALYSIS ===\n")

get_scc_stats <- function(g) {
  if (vcount(g) == 0) {
    return(list(num_sccs = 0, nodes_in_sccs = 0, largest_scc_size = 0))
  }
  scc <- components(g, mode = "strong")
  scc_sizes <- table(scc$membership)
  large_sccs <- scc_sizes[scc_sizes > 1]
  list(
    num_sccs = length(large_sccs),
    nodes_in_sccs = sum(large_sccs),
    largest_scc_size = ifelse(length(large_sccs) > 0, max(large_sccs), 0)
  )
}

baseline_stats <- get_scc_stats(graph)
cat("Baseline:\n")
cat("  SCCs with cycles:", baseline_stats$num_sccs, "\n")
cat("  Nodes in SCCs:", baseline_stats$nodes_in_sccs, "\n")
cat("  Largest SCC:", baseline_stats$largest_scc_size, "\n\n")

# ==========================================
# 5. INDIVIDUAL NODE REMOVAL IMPACT
# ==========================================
cat("=== 5. INDIVIDUAL NODE REMOVAL IMPACT ===\n\n")

# Header
cat(sprintf("%-25s | %6s | %6s | %6s | %10s | %8s | %13s | %13s\n",
            "Node", "InDeg", "OutDeg", "Total", "Betweenness", "EdgesRm",
            "SCC Nodes", "Largest SCC"))
cat(paste(rep("-", 120), collapse = ""), "\n")

individual_results <- data.frame(
  node = character(),
  in_degree = integer(),
  out_degree = integer(),
  total_degree = integer(),
  betweenness = numeric(),
  edges_removed = integer(),
  scc_nodes_before = integer(),
  scc_nodes_after = integer(),
  scc_node_reduction = integer(),
  largest_scc_before = integer(),
  largest_scc_after = integer(),
  stringsAsFactors = FALSE
)

for (node in candidates) {
  node_idx <- which(V(graph)$name == node)

  # Centrality metrics
  in_deg <- degree(graph, node_idx, mode = "in")
  out_deg <- degree(graph, node_idx, mode = "out")
  total_deg <- in_deg + out_deg
  bw <- betweenness(graph, v = node_idx, directed = TRUE, normalized = TRUE)

  # Edges that would be removed
  edges_touching <- incident(graph, node_idx, mode = "all")
  edges_removed <- length(edges_touching)

  # SCC stats after removal
  reduced <- delete_vertices(graph, node_idx)
  scc_after <- get_scc_stats(reduced)
  scc_reduction <- baseline_stats$nodes_in_sccs - scc_after$nodes_in_sccs

  cat(sprintf("%-25s | %6d | %6d | %6d | %10.4f | %8d | %5d → %5d | %5d → %5d\n",
              node, in_deg, out_deg, total_deg, bw, edges_removed,
              baseline_stats$nodes_in_sccs, scc_after$nodes_in_sccs,
              baseline_stats$largest_scc_size, scc_after$largest_scc_size))

  individual_results <- rbind(individual_results, data.frame(
    node = node,
    in_degree = in_deg,
    out_degree = out_deg,
    total_degree = total_deg,
    betweenness = bw,
    edges_removed = edges_removed,
    scc_nodes_before = baseline_stats$nodes_in_sccs,
    scc_nodes_after = scc_after$nodes_in_sccs,
    scc_node_reduction = scc_reduction,
    largest_scc_before = baseline_stats$largest_scc_size,
    largest_scc_after = scc_after$largest_scc_size,
    stringsAsFactors = FALSE
  ))
}

# Sort by SCC node reduction (most impactful first)
individual_results <- individual_results[order(-individual_results$scc_node_reduction), ]

cat("\n")

# ==========================================
# 6. COMBINED REMOVAL ANALYSIS
# ==========================================
cat("=== 6. COMBINED REMOVAL OF ALL CANDIDATES ===\n")

cat("Removing all", length(candidates), "candidate nodes together...\n")

node_indices <- which(V(graph)$name %in% candidates)
reduced_all <- delete_vertices(graph, node_indices)
combined_stats <- get_scc_stats(reduced_all)

edges_removed_total <- ecount(graph) - ecount(reduced_all)

cat("Before:", vcount(graph), "nodes,", ecount(graph), "edges\n")
cat("After: ", vcount(reduced_all), "nodes,", ecount(reduced_all), "edges\n")
cat("Removed:", length(candidates), "nodes,", edges_removed_total, "edges",
    sprintf("(%.1f%% of edges)\n", 100 * edges_removed_total / ecount(graph)))
cat("\nSCC comparison:\n")
cat("  Nodes in SCCs:", baseline_stats$nodes_in_sccs, "→", combined_stats$nodes_in_sccs, "\n")
cat("  Largest SCC:  ", baseline_stats$largest_scc_size, "→", combined_stats$largest_scc_size, "\n")
cat("  SCCs:          ", baseline_stats$num_sccs, "→", combined_stats$num_sccs, "\n")

is_dag <- combined_stats$num_sccs == 0
if (is_dag) {
  cat("\n  ✓ Reduced graph is a DAG!\n")
} else {
  cat("\n  ✗ Cycles still remain.\n")
}

# ==========================================
# 7. VISUALIZATION
# ==========================================
cat("\n=== 7. GENERATING VISUALIZATIONS ===\n")

# Dual-axis-style chart: bars for edges removed, points for SCC reduction
p <- ggplot(individual_results, aes(x = reorder(node, scc_node_reduction))) +
  geom_bar(aes(y = edges_removed, fill = "Edges Removed"),
           stat = "identity", alpha = 0.7, width = 0.6) +
  geom_point(aes(y = scc_node_reduction, color = "SCC Node Reduction"),
             size = 4) +
  geom_text(aes(y = edges_removed,
                label = sprintf("%d edges", edges_removed)),
            hjust = -0.1, size = 2.8, color = "gray30") +
  geom_text(aes(y = scc_node_reduction,
                label = sprintf("-%d SCC", scc_node_reduction)),
            vjust = -1, size = 2.8, color = "darkred") +
  coord_flip() +
  scale_fill_manual(values = c("Edges Removed" = "steelblue"), name = "") +
  scale_color_manual(values = c("SCC Node Reduction" = "coral"), name = "") +
  labs(
    title = "Impact of Removing Individual Generic Hub Nodes",
    subtitle = sprintf("%s → %s | Degree %d | Baseline: %d nodes in SCCs",
                       exposure_name, outcome_name, degree,
                       baseline_stats$nodes_in_sccs),
    x = "Node",
    y = "Count"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 10),
    legend.position = "bottom"
  ) +
  ylim(0, max(c(individual_results$edges_removed,
                individual_results$scc_node_reduction)) * 1.2)

impact_file <- file.path(plots_dir, "node_removal_impact.png")
ggsave(impact_file, p, width = 12, height = max(4, 0.5 * nrow(individual_results)), dpi = 150)
cat("Saved impact chart to:", impact_file, "\n")

# ==========================================
# 8. SAVE RESULTS
# ==========================================
cat("\n=== 8. SAVING RESULTS ===\n")

# Save individual impact analysis
impact_csv <- file.path(s1_dir, "node_removal_impact.csv")
write.csv(individual_results, impact_csv, row.names = FALSE)
cat("Saved:", impact_csv, "\n")

# Save summary
summary_df <- data.frame(
  metric = c("Baseline Nodes", "Baseline Edges",
             "Baseline SCCs", "Baseline Nodes in SCCs", "Baseline Largest SCC",
             "Candidates Found", "Candidates Removed",
             "After Nodes", "After Edges",
             "After SCCs", "After Nodes in SCCs", "After Largest SCC",
             "Total Edges Removed", "Is DAG"),
  value = c(vcount(graph), ecount(graph),
            baseline_stats$num_sccs, baseline_stats$nodes_in_sccs, baseline_stats$largest_scc_size,
            length(candidates), length(candidates),
            vcount(reduced_all), ecount(reduced_all),
            combined_stats$num_sccs, combined_stats$nodes_in_sccs, combined_stats$largest_scc_size,
            edges_removed_total, ifelse(is_dag, "YES", "NO")),
  stringsAsFactors = FALSE
)

summary_csv <- file.path(s1_dir, "node_removal_summary.csv")
write.csv(summary_df, summary_csv, row.names = FALSE)
cat("Saved:", summary_csv, "\n")

# ==========================================
# 9. PRINT SUMMARY
# ==========================================
cat("\n")
cat(rep("=", 70), "\n", sep = "")
cat("SUMMARY: Node Removal Impact (Centrality-Based)\n")
cat(rep("=", 70), "\n", sep = "")

cat("\nTop candidates by SCC node reduction:\n")
for (i in 1:nrow(individual_results)) {
  cat(sprintf("  %2d. %-25s | degree: %4d | betweenness: %.4f | SCC reduction: %d nodes\n",
              i,
              individual_results$node[i],
              individual_results$total_degree[i],
              individual_results$betweenness[i],
              individual_results$scc_node_reduction[i]))
}

cat(sprintf("\nCombined removal: %d nodes, %d edges lost → SCCs: %d→%d, SCC nodes: %d→%d\n",
            length(candidates), edges_removed_total,
            baseline_stats$num_sccs, combined_stats$num_sccs,
            baseline_stats$nodes_in_sccs, combined_stats$nodes_in_sccs))

cat("\n")
print_complete("Node Removal Impact Analysis (Centrality-Based)")
