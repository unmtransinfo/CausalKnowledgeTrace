# 01d_post_node_removal_analysis.R
# Analyze the pruned graph after generic hub nodes have been removed
#
# This script:
# 1. Loads the pruned graph (from 01c)
# 2. Compares basic stats with original graph
# 3. Recalculates centrality on the pruned graph
# 4. Reports SCC status (cheap)
# 5. Reports top nodes by degree/betweenness in the pruned graph
# 6. Generates comparison visualizations
#
# Input:
#   - data/{E}_{O}/degreeN/s1_graph/pruned_graph.rds      (from 01c)
#   - data/{E}_{O}/degreeN/s1_graph/parsed_graph.rds       (for comparison)
#   - data/{E}_{O}/degreeN/s1_graph/pruned_nodes.txt       (from 01c)
# Output: data/{E}_{O}/degreeN/s1_graph/
#   - post_removal_centrality.csv
#   - post_removal_top_nodes.csv
#   - post_removal_summary.csv
#   - plots/post_removal_centrality_comparison.png
#   - plots/post_removal_graph.png

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
library(ggraph)

# ---- Configuration ----
TOP_N <- 20  # Number of top nodes to report

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
s1_dir <- get_s1_graph_dir(exposure_name, outcome_name, degree)
pruned_graph_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
original_graph_file <- get_parsed_graph_path(exposure_name, outcome_name, degree)
pruned_nodes_file <- file.path(s1_dir, "pruned_nodes.txt")
plots_dir <- file.path(s1_dir, "plots")

# ---- Validate inputs ----
if (!file.exists(pruned_graph_file)) {
  stop("Pruned graph not found at: ", pruned_graph_file,
       "\nPlease run 01c_prune_generic_hubs.R first.\n")
}
ensure_dir(plots_dir)

print_header(paste0("Post Node Removal Analysis - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPHS
# ==========================================
cat("=== 1. LOADING GRAPHS ===\n")

pruned_graph <- readRDS(pruned_graph_file)
cat("Pruned graph:", vcount(pruned_graph), "nodes,", ecount(pruned_graph), "edges\n")

original_graph <- NULL
if (file.exists(original_graph_file)) {
  original_graph <- readRDS(original_graph_file)
  cat("Original graph:", vcount(original_graph), "nodes,", ecount(original_graph), "edges\n")
}

# Load pruned nodes list
pruned_nodes <- character(0)
if (file.exists(pruned_nodes_file)) {
  pruned_nodes <- readLines(pruned_nodes_file)
  cat("Nodes removed:", paste(pruned_nodes, collapse = ", "), "\n")
}
cat("\n")

# ==========================================
# 2. GRAPH COMPARISON
# ==========================================
cat("=== 2. GRAPH COMPARISON ===\n\n")

if (!is.null(original_graph)) {
  cat("                   Original     Pruned      Change\n")
  cat(paste(rep("-", 60), collapse = ""), "\n")
  cat(sprintf("  Nodes:        %8d   %8d      -%d\n",
              vcount(original_graph), vcount(pruned_graph),
              vcount(original_graph) - vcount(pruned_graph)))
  cat(sprintf("  Edges:        %8d   %8d      -%d (%.1f%%)\n",
              ecount(original_graph), ecount(pruned_graph),
              ecount(original_graph) - ecount(pruned_graph),
              100 * (ecount(original_graph) - ecount(pruned_graph)) / ecount(original_graph)))
  cat(sprintf("  Density:      %8.6f   %8.6f\n",
              graph.density(original_graph), graph.density(pruned_graph)))
  cat("\n")
}

# ==========================================
# 3. SCC ANALYSIS (cheap)
# ==========================================
cat("=== 3. SCC ANALYSIS ===\n")

scc <- components(pruned_graph, mode = "strong")
scc_sizes <- table(scc$membership)
large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))

cat("Total components (strong):", scc$no, "\n")
cat("SCCs with cycles (size > 1):", length(large_sccs), "\n")

if (length(large_sccs) > 0) {
  nodes_in_sccs <- sum(scc_sizes[scc_sizes > 1])
  largest_scc <- max(scc_sizes[scc_sizes > 1])
  cat("Nodes in SCCs:", nodes_in_sccs, "\n")
  cat("Largest SCC:", largest_scc, "nodes\n")

  cat("\nSCC details:\n")
  for (scc_id in large_sccs) {
    scc_nodes <- V(pruned_graph)$name[scc$membership == scc_id]
    cat(sprintf("  SCC %d (%d nodes): %s\n",
                scc_id, length(scc_nodes),
                paste(head(scc_nodes, 8), collapse = ", ")))
    if (length(scc_nodes) > 8) {
      cat(sprintf("    ... and %d more\n", length(scc_nodes) - 8))
    }
  }
} else {
  nodes_in_sccs <- 0
  largest_scc <- 0
  cat("\n  ✓ No SCCs with cycles — the pruned graph is a DAG!\n")
}
cat("\n")

# Compare with original graph SCC stats
if (!is.null(original_graph)) {
  orig_scc <- components(original_graph, mode = "strong")
  orig_scc_sizes <- table(orig_scc$membership)
  orig_large <- orig_scc_sizes[orig_scc_sizes > 1]

  cat("SCC Comparison: Original → Pruned\n")
  cat(sprintf("  SCCs:          %d → %d\n", length(orig_large), length(large_sccs)))
  cat(sprintf("  Nodes in SCCs: %d → %d\n", sum(orig_large), nodes_in_sccs))
  cat(sprintf("  Largest SCC:   %d → %d\n",
              ifelse(length(orig_large) > 0, max(orig_large), 0), largest_scc))
  cat("\n")
}

# ==========================================
# 4. CENTRALITY ON PRUNED GRAPH
# ==========================================
cat("=== 4. CENTRALITY ANALYSIS (Pruned Graph) ===\n")

cat("Computing centrality on pruned graph...\n")
pruned_centrality <- data.frame(
  node = V(pruned_graph)$name,
  in_degree = degree(pruned_graph, mode = "in"),
  out_degree = degree(pruned_graph, mode = "out"),
  total_degree = degree(pruned_graph, mode = "all"),
  betweenness = betweenness(pruned_graph, directed = TRUE, normalized = TRUE),
  stringsAsFactors = FALSE
)

# Mark exposure and outcome
pruned_centrality$is_exposure <- pruned_centrality$node == exposure_name
pruned_centrality$is_outcome <- pruned_centrality$node == outcome_name

# Mark if in SCC
in_scc_nodes <- V(pruned_graph)$name[scc$membership %in% large_sccs]
pruned_centrality$in_scc <- pruned_centrality$node %in% in_scc_nodes

cat("Done.\n\n")

# Top nodes by degree
top_by_degree <- pruned_centrality %>%
  arrange(desc(total_degree)) %>%
  head(TOP_N)

cat("Top", TOP_N, "nodes by degree (pruned graph):\n")
cat(sprintf("  %-30s | %6s | %6s | %6s | %10s | %5s\n",
            "Node", "InDeg", "OutDeg", "Total", "Betweenness", "InSCC"))
cat(paste(rep("-", 85), collapse = ""), "\n")
for (i in 1:nrow(top_by_degree)) {
  cat(sprintf("  %-30s | %6d | %6d | %6d | %10.4f | %5s\n",
              top_by_degree$node[i],
              top_by_degree$in_degree[i],
              top_by_degree$out_degree[i],
              top_by_degree$total_degree[i],
              top_by_degree$betweenness[i],
              top_by_degree$in_scc[i]))
}
cat("\n")

# Top nodes by betweenness
top_by_betweenness <- pruned_centrality %>%
  arrange(desc(betweenness)) %>%
  head(TOP_N)

cat("Top", TOP_N, "nodes by betweenness (pruned graph):\n")
cat(sprintf("  %-30s | %6s | %10s | %5s\n",
            "Node", "Degree", "Betweenness", "InSCC"))
cat(paste(rep("-", 65), collapse = ""), "\n")
for (i in 1:nrow(top_by_betweenness)) {
  cat(sprintf("  %-30s | %6d | %10.4f | %5s\n",
              top_by_betweenness$node[i],
              top_by_betweenness$total_degree[i],
              top_by_betweenness$betweenness[i],
              top_by_betweenness$in_scc[i]))
}
cat("\n")

# ==========================================
# 5. VISUALIZATIONS
# ==========================================
cat("=== 5. GENERATING VISUALIZATIONS ===\n")

# 5a. Top nodes comparison bar chart
top_combined <- pruned_centrality %>%
  arrange(desc(total_degree)) %>%
  head(TOP_N) %>%
  mutate(node = factor(node, levels = rev(node)))

p1 <- ggplot(top_combined, aes(x = node, y = total_degree, fill = in_scc)) +
  geom_bar(stat = "identity", width = 0.7) +
  geom_text(aes(label = total_degree), hjust = -0.1, size = 3) +
  coord_flip() +
  scale_fill_manual(values = c("FALSE" = "steelblue", "TRUE" = "coral"),
                    labels = c("FALSE" = "Not in SCC", "TRUE" = "In SCC"),
                    name = "SCC Status") +
  labs(
    title = paste("Top", TOP_N, "Nodes by Degree (After Pruning)"),
    subtitle = sprintf("%s → %s | Degree %d | %d nodes, %d edges",
                       exposure_name, outcome_name, degree,
                       vcount(pruned_graph), ecount(pruned_graph)),
    x = "Node",
    y = "Total Degree"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    plot.subtitle = element_text(hjust = 0.5, size = 10),
    legend.position = "bottom"
  ) +
  ylim(0, max(top_combined$total_degree) * 1.15)

ggsave(file.path(plots_dir, "post_removal_centrality_comparison.png"), p1,
       width = 10, height = 8, dpi = 150)
cat("Saved: post_removal_centrality_comparison.png\n")

# 5b. Graph visualization (if not too large)
if (vcount(pruned_graph) <= 500) {
  cat("Generating graph visualization...\n")

  # Color nodes: exposure=red, outcome=blue, SCC=coral, other=steelblue
  node_colors <- ifelse(V(pruned_graph)$name == exposure_name, "Exposure",
                 ifelse(V(pruned_graph)$name == outcome_name, "Outcome",
                 ifelse(V(pruned_graph)$name %in% in_scc_nodes, "In SCC", "Normal")))

  p2 <- ggraph(pruned_graph, layout = "fr") +
    geom_edge_link(arrow = arrow(length = unit(1.5, "mm"), type = "closed"),
                   end_cap = circle(2, "mm"), alpha = 0.3, color = "gray50") +
    geom_node_point(aes(color = node_colors), size = 3) +
    geom_node_text(aes(label = name), repel = TRUE, size = 2, max.overlaps = 25) +
    scale_color_manual(values = c("Exposure" = "red", "Outcome" = "blue",
                                  "In SCC" = "coral", "Normal" = "steelblue"),
                       name = "Node Type") +
    labs(
      title = "Pruned Graph Visualization",
      subtitle = sprintf("%s → %s | %d nodes, %d edges | Removed: %s",
                         exposure_name, outcome_name,
                         vcount(pruned_graph), ecount(pruned_graph),
                         paste(pruned_nodes, collapse = ", "))
    ) +
    theme_void() +
    theme(legend.position = "bottom",
          plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          plot.subtitle = element_text(hjust = 0.5, size = 9))

  ggsave(file.path(plots_dir, "post_removal_graph.png"), p2,
         width = 16, height = 14, dpi = 150)
  cat("Saved: post_removal_graph.png\n")
} else {
  cat("Graph too large for full visualization (", vcount(pruned_graph), " nodes)\n")
  cat("Skipping graph plot.\n")
}

# ==========================================
# 6. SAVE RESULTS
# ==========================================
cat("\n=== 6. SAVING RESULTS ===\n")

# Save full centrality data for pruned graph
centrality_csv <- file.path(s1_dir, "post_removal_centrality.csv")
write.csv(pruned_centrality, centrality_csv, row.names = FALSE)
cat("Saved:", centrality_csv, "\n")

# Save top nodes
top_nodes_csv <- file.path(s1_dir, "post_removal_top_nodes.csv")
write.csv(top_by_degree, top_nodes_csv, row.names = FALSE)
cat("Saved:", top_nodes_csv, "\n")

# Save summary
summary_df <- data.frame(
  metric = c(
    "Pruned Nodes", "Pruned Edges", "Pruned Density",
    "Nodes Removed", "Edges Removed",
    "SCCs With Cycles", "Nodes in SCCs", "Largest SCC",
    "Is DAG",
    "Top Node by Degree", "Top Node by Betweenness"
  ),
  value = c(
    vcount(pruned_graph), ecount(pruned_graph),
    round(graph.density(pruned_graph), 6),
    length(pruned_nodes),
    ifelse(!is.null(original_graph), ecount(original_graph) - ecount(pruned_graph), "N/A"),
    length(large_sccs), nodes_in_sccs, largest_scc,
    ifelse(length(large_sccs) == 0, "YES", "NO"),
    top_by_degree$node[1],
    top_by_betweenness$node[1]
  ),
  stringsAsFactors = FALSE
)

summary_csv <- file.path(s1_dir, "post_removal_summary.csv")
write.csv(summary_df, summary_csv, row.names = FALSE)
cat("Saved:", summary_csv, "\n")

# ==========================================
# 7. FINAL SUMMARY
# ==========================================
cat("\n")
cat(rep("=", 60), "\n", sep = "")
cat("POST NODE REMOVAL ANALYSIS SUMMARY\n")
cat(rep("=", 60), "\n", sep = "")
cat("\n")

if (!is.null(original_graph)) {
  cat("GRAPH COMPARISON:\n")
  cat(sprintf("  Original: %d nodes, %d edges\n", vcount(original_graph), ecount(original_graph)))
  cat(sprintf("  Pruned:   %d nodes, %d edges\n", vcount(pruned_graph), ecount(pruned_graph)))
  cat(sprintf("  Removed:  %d nodes (%s)\n", length(pruned_nodes), paste(pruned_nodes, collapse = ", ")))
  cat("\n")
}

cat("CYCLE STATUS (SCC-based):\n")
cat(sprintf("  SCCs with cycles: %d\n", length(large_sccs)))
cat(sprintf("  Nodes in SCCs:    %d\n", nodes_in_sccs))
cat(sprintf("  Largest SCC:      %d\n", largest_scc))
cat(sprintf("  Is DAG:           %s\n", ifelse(length(large_sccs) == 0, "YES", "NO")))
cat("\n")

cat("TOP 5 NODES BY DEGREE (pruned graph):\n")
for (i in 1:min(5, nrow(top_by_degree))) {
  cat(sprintf("  %d. %s (degree: %d, betweenness: %.4f, in SCC: %s)\n",
              i, top_by_degree$node[i], top_by_degree$total_degree[i],
              top_by_degree$betweenness[i], top_by_degree$in_scc[i]))
}
cat("\n")

print_complete("Post Node Removal Analysis")
