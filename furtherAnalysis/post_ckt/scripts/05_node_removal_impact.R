# 05_node_removal_impact.R
# Analyze the impact of removing generic/non-specific nodes on cycle reduction
#
# This script:
# 1. Removes each candidate node individually and counts remaining cycles
# 2. Removes all candidate nodes together and counts remaining cycles
# 3. Reports the impact on cycle reduction
#
# Input: data/{Exposure}_{Outcome}/s1_graph/parsed_graph.rds
# Output: data/{Exposure}_{Outcome}/s4_node_removal/
#   - node_removal_individual_impact.csv
#   - node_removal_summary.csv
#   - reduced_graph.rds
#   - removed_generic_nodes.txt
#   - plots/reduced_graph_full.png
#   - plots/reduced_graph_cycles_only.png
#   - plots/node_removal_impact_comparison.png

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

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths ----
input_file <- get_parsed_graph_path(exposure_name, outcome_name)
output_dir <- get_s4_node_removal_dir(exposure_name, outcome_name)
plots_dir <- file.path(output_dir, "plots")

# ---- Validate inputs and create output directory ----
validate_inputs(exposure_name, outcome_name, require_parsed_graph = TRUE)
ensure_dir(output_dir)
ensure_dir(plots_dir)

print_header("Node Removal Impact Analysis (Stage 4)", exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
cat("Loading graph from:", input_file, "\n")
graph <- readRDS(input_file)
cat("Original graph:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")

# ==========================================
# 2. FUNCTION TO COUNT CYCLES IN A GRAPH
# ==========================================

# Count total cycles using Johnson's algorithm approach
# For large graphs, we use SCC-based estimation
count_cycles_fast <- function(g) {
  if (vcount(g) == 0) return(0)

  # Find strongly connected components
  scc <- components(g, mode = "strong")
  scc_sizes <- table(scc$membership)
  large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))

  if (length(large_sccs) == 0) return(0)

  total_cycles <- 0

  for (scc_id in large_sccs) {
    scc_nodes <- which(scc$membership == scc_id)
    scc_subgraph <- induced_subgraph(g, scc_nodes)

    n <- vcount(scc_subgraph)
    if (n <= 1) next

    # For small SCCs, count exactly
    if (n <= 15) {
      cycles <- count_cycles_exact(scc_subgraph)
      total_cycles <- total_cycles + cycles
    } else {
      # For larger SCCs, use exact counting but with progress
      cycles <- count_cycles_exact(scc_subgraph)
      total_cycles <- total_cycles + cycles
    }
  }

  return(total_cycles)
}

# Exact cycle counting using DFS
count_cycles_exact <- function(g) {
  n <- vcount(g)
  if (n == 0) return(0)

  adj_list <- as_adj_list(g, mode = "out")
  total_cycles <- 0

  find_cycles_from_node <- function(start, current, visited) {
    neighbors <- adj_list[[current]]

    for (next_node in neighbors) {
      if (next_node == start && length(visited) >= 2) {
        total_cycles <<- total_cycles + 1
      } else if (!(next_node %in% visited) && next_node > start) {
        find_cycles_from_node(start, next_node, c(visited, next_node))
      }
    }
  }

  for (start in 1:n) {
    find_cycles_from_node(start, start, c(start))
  }

  return(total_cycles)
}

# Get SCC statistics (faster than full cycle count)
get_scc_stats <- function(g) {
  if (vcount(g) == 0) {
    return(list(
      num_sccs = 0,
      nodes_in_sccs = 0,
      largest_scc_size = 0,
      scc_sizes = integer(0)
    ))
  }

  scc <- components(g, mode = "strong")
  scc_sizes <- table(scc$membership)
  large_sccs <- scc_sizes[scc_sizes > 1]

  list(
    num_sccs = length(large_sccs),
    nodes_in_sccs = sum(large_sccs),
    largest_scc_size = ifelse(length(large_sccs) > 0, max(large_sccs), 0),
    scc_sizes = as.integer(large_sccs)
  )
}

# ==========================================
# 3. BASELINE ANALYSIS
# ==========================================
cat("=== 2. BASELINE ANALYSIS ===\n")

baseline_stats <- get_scc_stats(graph)
cat("Baseline SCC statistics:\n")
cat("  SCCs with cycles:", baseline_stats$num_sccs, "\n")
cat("  Total nodes in SCCs:", baseline_stats$nodes_in_sccs, "\n")
cat("  Largest SCC size:", baseline_stats$largest_scc_size, "\n")

cat("\nCounting baseline cycles (this may take a while)...\n")
start_time <- Sys.time()
baseline_cycles <- count_cycles_fast(graph)
end_time <- Sys.time()
cat("Baseline total cycles:", format(baseline_cycles, big.mark = ","), "\n")
cat("Time taken:", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n\n")

# ==========================================
# 4. INDIVIDUAL NODE REMOVAL ANALYSIS
# ==========================================
cat("=== 3. INDIVIDUAL NODE REMOVAL ANALYSIS ===\n")

# Check which generic nodes exist in the graph
all_nodes <- V(graph)$name
existing_generic <- GENERIC_NODES[GENERIC_NODES %in% all_nodes]
missing_generic <- GENERIC_NODES[!GENERIC_NODES %in% all_nodes]

cat("Generic nodes found in graph:", length(existing_generic), "\n")
cat("Generic nodes NOT in graph:", length(missing_generic), "\n")
if (length(missing_generic) > 0) {
  cat("  Missing:", paste(missing_generic, collapse = ", "), "\n")
}
cat("\n")

# Analyze impact of removing each node individually
individual_results <- data.frame(
  node = character(),
  original_cycles = numeric(),
  remaining_cycles = numeric(),
  cycles_removed = numeric(),
  percent_reduction = numeric(),
  remaining_sccs = integer(),
  largest_scc_after = integer(),
  stringsAsFactors = FALSE
)

cat("Analyzing individual node removal impact...\n")
for (node in existing_generic) {
  cat(sprintf("  Removing '%s'... ", node))

  # Create graph without this node
  node_idx <- which(V(graph)$name == node)
  reduced_graph <- delete_vertices(graph, node_idx)

  # Get SCC stats
  scc_stats <- get_scc_stats(reduced_graph)

  # Count cycles
  cycles_after <- count_cycles_fast(reduced_graph)
  cycles_removed <- baseline_cycles - cycles_after
  percent_reduction <- (cycles_removed / baseline_cycles) * 100

  cat(sprintf("cycles: %s (-%s, -%.1f%%)\n",
              format(cycles_after, big.mark = ","),
              format(cycles_removed, big.mark = ","),
              percent_reduction))

  individual_results <- rbind(individual_results, data.frame(
    node = node,
    original_cycles = baseline_cycles,
    remaining_cycles = cycles_after,
    cycles_removed = cycles_removed,
    percent_reduction = percent_reduction,
    remaining_sccs = scc_stats$num_sccs,
    largest_scc_after = scc_stats$largest_scc_size,
    stringsAsFactors = FALSE
  ))
}

# Sort by percent reduction
individual_results <- individual_results[order(-individual_results$percent_reduction), ]

cat("\n")

# ==========================================
# 5. COMBINED REMOVAL ANALYSIS
# ==========================================
cat("=== 4. COMBINED REMOVAL ANALYSIS ===\n")

cat("Removing all", length(existing_generic), "generic nodes together...\n")
cat("Nodes to remove:", paste(existing_generic, collapse = ", "), "\n")

# Create graph without all generic nodes
node_indices <- which(V(graph)$name %in% existing_generic)
reduced_graph_all <- delete_vertices(graph, node_indices)

cat("\nReduced graph:", vcount(reduced_graph_all), "nodes,", ecount(reduced_graph_all), "edges\n")

# Get SCC stats
combined_scc_stats <- get_scc_stats(reduced_graph_all)
cat("SCCs with cycles:", combined_scc_stats$num_sccs, "\n")
cat("Nodes in SCCs:", combined_scc_stats$nodes_in_sccs, "\n")
cat("Largest SCC size:", combined_scc_stats$largest_scc_size, "\n")

# Count cycles
cat("\nCounting cycles after removal...\n")
start_time <- Sys.time()
combined_cycles <- count_cycles_fast(reduced_graph_all)
end_time <- Sys.time()

combined_removed <- baseline_cycles - combined_cycles
combined_percent <- (combined_removed / baseline_cycles) * 100

cat("Cycles after removing all generic nodes:", format(combined_cycles, big.mark = ","), "\n")
cat("Cycles removed:", format(combined_removed, big.mark = ","), "\n")
cat("Percent reduction:", sprintf("%.2f%%", combined_percent), "\n")
cat("Time taken:", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

# ==========================================
# 6. CHECK IF DAG IS ACHIEVED
# ==========================================
cat("\n=== 5. DAG STATUS ===\n")

if (combined_cycles == 0) {
  cat("SUCCESS! The reduced graph is a DAG (no cycles).\n")
  is_dag <- TRUE
} else {
  cat("The reduced graph still contains cycles.\n")
  cat("Remaining cycles:", format(combined_cycles, big.mark = ","), "\n")
  is_dag <- FALSE

  # Show remaining problematic nodes
  if (combined_scc_stats$num_sccs > 0) {
    cat("\nRemaining SCCs:\n")
    scc <- components(reduced_graph_all, mode = "strong")
    scc_sizes <- table(scc$membership)
    large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))

    for (scc_id in large_sccs) {
      scc_nodes <- V(reduced_graph_all)$name[scc$membership == scc_id]
      cat(sprintf("  SCC (size %d): %s\n",
                  length(scc_nodes),
                  paste(head(scc_nodes, 10), collapse = ", ")))
      if (length(scc_nodes) > 10) {
        cat(sprintf("    ... and %d more nodes\n", length(scc_nodes) - 10))
      }
    }
  }
}

# ==========================================
# 7. VISUALIZE REDUCED GRAPH
# ==========================================
cat("\n=== 6. VISUALIZING REDUCED GRAPH ===\n")

# 7a. Visualize the full reduced graph
cat("Generating full reduced graph visualization...\n")

# Choose layout based on graph size (threshold 1000 to allow full visualization)
if (vcount(reduced_graph_all) <= 1000) {
  # For smaller graphs, use force-directed layout
  p_full <- ggraph(reduced_graph_all, layout = "fr") +
    geom_edge_link(arrow = arrow(length = unit(1.5, "mm"), type = "closed"),
                   end_cap = circle(2, "mm"),
                   alpha = 0.4,
                   color = "gray50") +
    geom_node_point(aes(color = ifelse(name == exposure_name, "Exposure",
                                       ifelse(name == outcome_name, "Outcome", "Other"))),
                    size = 3) +
    geom_node_text(aes(label = name), repel = TRUE, size = 2, max.overlaps = 30) +
    scale_color_manual(values = c("Exposure" = "red", "Outcome" = "blue", "Other" = "steelblue"),
                       name = "Node Type") +
    labs(
      title = "Reduced Graph (Generic Nodes Removed)",
      subtitle = sprintf("%s to %s | %d nodes, %d edges | Removed: %s",
                         exposure_name, outcome_name,
                         vcount(reduced_graph_all), ecount(reduced_graph_all),
                         paste(existing_generic, collapse = ", "))
    ) +
    theme_void() +
    theme(legend.position = "bottom",
          plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          plot.subtitle = element_text(hjust = 0.5, size = 9))

  full_graph_file <- file.path(plots_dir, "reduced_graph_full.png")
  ggsave(full_graph_file, p_full, width = 16, height = 14, dpi = 150)
  cat("Saved full graph visualization to:", full_graph_file, "\n")
} else {
  cat("Graph too large for full visualization (", vcount(reduced_graph_all), " nodes)\n")
  cat("Generating simplified visualization with top degree nodes...\n")

  # For larger graphs, show only high-degree nodes
  degrees <- degree(reduced_graph_all, mode = "all")
  top_nodes <- names(sort(degrees, decreasing = TRUE))[1:min(100, length(degrees))]

  # Always include exposure and outcome
  top_nodes <- unique(c(exposure_name, outcome_name, top_nodes))
  sub_graph <- induced_subgraph(reduced_graph_all, top_nodes)

  p_full <- ggraph(sub_graph, layout = "fr") +
    geom_edge_link(arrow = arrow(length = unit(1.5, "mm"), type = "closed"),
                   end_cap = circle(2, "mm"),
                   alpha = 0.4,
                   color = "gray50") +
    geom_node_point(aes(color = ifelse(name == exposure_name, "Exposure",
                                       ifelse(name == outcome_name, "Outcome", "Other"))),
                    size = 3) +
    geom_node_text(aes(label = name), repel = TRUE, size = 2.5, max.overlaps = 20) +
    scale_color_manual(values = c("Exposure" = "red", "Outcome" = "blue", "Other" = "steelblue"),
                       name = "Node Type") +
    labs(
      title = "Reduced Graph - Top Degree Nodes",
      subtitle = sprintf("%s to %s | Showing %d of %d nodes",
                         exposure_name, outcome_name,
                         vcount(sub_graph), vcount(reduced_graph_all))
    ) +
    theme_void() +
    theme(legend.position = "bottom",
          plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
          plot.subtitle = element_text(hjust = 0.5, size = 10))

  full_graph_file <- file.path(plots_dir, "reduced_graph_top_nodes.png")
  ggsave(full_graph_file, p_full, width = 16, height = 14, dpi = 150)
  cat("Saved top-nodes graph visualization to:", full_graph_file, "\n")
}

# 7b. Visualize cycle subgraph (if cycles remain)
if (combined_scc_stats$num_sccs > 0) {
  cat("Generating cycle subgraph visualization...\n")

  scc <- components(reduced_graph_all, mode = "strong")
  scc_sizes <- table(scc$membership)
  large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))

  # Extract nodes in cycles
  cycle_node_indices <- which(scc$membership %in% large_sccs)
  cycle_subgraph <- induced_subgraph(reduced_graph_all, cycle_node_indices)

  if (vcount(cycle_subgraph) <= 150) {
    p_cycle <- ggraph(cycle_subgraph, layout = "fr") +
      geom_edge_link(arrow = arrow(length = unit(2, "mm"), type = "closed"),
                     end_cap = circle(3, "mm"),
                     alpha = 0.6,
                     color = "darkred") +
      geom_node_point(size = 5, color = "coral") +
      geom_node_text(aes(label = name), repel = TRUE, size = 3) +
      labs(
        title = "Remaining Cycle Subgraph",
        subtitle = sprintf("%d nodes, %d edges still in cycles | %s remaining cycles",
                           vcount(cycle_subgraph), ecount(cycle_subgraph),
                           format(combined_cycles, big.mark = ","))
      ) +
      theme_void() +
      theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
            plot.subtitle = element_text(hjust = 0.5, size = 10))

    cycle_graph_file <- file.path(plots_dir, "reduced_graph_cycles_only.png")
    ggsave(cycle_graph_file, p_cycle, width = 12, height = 10, dpi = 150)
    cat("Saved cycle subgraph visualization to:", cycle_graph_file, "\n")
  } else {
    cat("Cycle subgraph too large for visualization (", vcount(cycle_subgraph), " nodes)\n")
  }
} else {
  cat("No cycles remain - no cycle subgraph to visualize.\n")
}

# 7c. Bar chart of individual node removal impact
cat("Generating impact comparison chart...\n")
p_impact <- ggplot(individual_results, aes(x = reorder(node, percent_reduction), y = percent_reduction)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  geom_text(aes(label = sprintf("%.1f%%", percent_reduction)), hjust = -0.1, size = 3) +
  coord_flip() +
  labs(
    title = "Cycle Reduction by Removing Individual Generic Nodes",
    subtitle = sprintf("%s to %s | Baseline: %s cycles",
                       exposure_name, outcome_name,
                       format(baseline_cycles, big.mark = ",")),
    x = "Node Removed",
    y = "Percent Cycle Reduction"
  ) +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
        plot.subtitle = element_text(hjust = 0.5, size = 10)) +
  ylim(0, max(individual_results$percent_reduction) * 1.1)

impact_file <- file.path(plots_dir, "node_removal_impact_comparison.png")
ggsave(impact_file, p_impact, width = 10, height = 6, dpi = 150)
cat("Saved impact comparison chart to:", impact_file, "\n")

# ==========================================
# 8. SAVE RESULTS
# ==========================================
cat("\n=== 7. SAVING RESULTS ===\n")

# Save individual results
individual_file <- file.path(output_dir, "node_removal_individual_impact.csv")
write.csv(individual_results, individual_file, row.names = FALSE)
cat("Saved individual impact analysis to:", individual_file, "\n")

# Create summary dataframe
summary_results <- data.frame(
  analysis_type = c("Baseline", "Combined Removal"),
  nodes_removed = c(0, length(existing_generic)),
  total_nodes = c(vcount(graph), vcount(reduced_graph_all)),
  total_edges = c(ecount(graph), ecount(reduced_graph_all)),
  num_cycles = c(baseline_cycles, combined_cycles),
  num_sccs = c(baseline_stats$num_sccs, combined_scc_stats$num_sccs),
  largest_scc = c(baseline_stats$largest_scc_size, combined_scc_stats$largest_scc_size),
  is_dag = c(FALSE, is_dag),
  stringsAsFactors = FALSE
)

summary_file <- file.path(output_dir, "node_removal_summary.csv")
write.csv(summary_results, summary_file, row.names = FALSE)
cat("Saved summary to:", summary_file, "\n")

# Save the reduced graph for future use
reduced_graph_file <- file.path(output_dir, "reduced_graph.rds")
saveRDS(reduced_graph_all, reduced_graph_file)
cat("Saved reduced graph to:", reduced_graph_file, "\n")

# Save list of removed nodes
removed_nodes_file <- file.path(output_dir, "removed_generic_nodes.txt")
writeLines(existing_generic, removed_nodes_file)
cat("Saved removed nodes list to:", removed_nodes_file, "\n")

# ==========================================
# 9. PRINT SUMMARY
# ==========================================
cat("\n")
cat(rep("=", 60), "\n", sep = "")
cat("SUMMARY: Node Removal Impact Analysis\n")
cat(rep("=", 60), "\n", sep = "")
cat("\n")
cat("BASELINE:\n")
cat("  Nodes:", vcount(graph), "\n")
cat("  Edges:", ecount(graph), "\n")
cat("  Cycles:", format(baseline_cycles, big.mark = ","), "\n")
cat("  SCCs with cycles:", baseline_stats$num_sccs, "\n")
cat("\n")
cat("INDIVIDUAL NODE IMPACT (sorted by reduction):\n")
for (i in 1:nrow(individual_results)) {
  cat(sprintf("  %s: -%.1f%% (%s cycles removed)\n",
              individual_results$node[i],
              individual_results$percent_reduction[i],
              format(individual_results$cycles_removed[i], big.mark = ",")))
}
cat("\n")
cat("COMBINED REMOVAL (all generic nodes):\n")
cat("  Nodes removed:", length(existing_generic), "\n")
cat("  Remaining nodes:", vcount(reduced_graph_all), "\n")
cat("  Remaining edges:", ecount(reduced_graph_all), "\n")
cat("  Remaining cycles:", format(combined_cycles, big.mark = ","), "\n")
cat("  Total reduction:", sprintf("%.2f%%", combined_percent), "\n")
cat("  Is DAG:", ifelse(is_dag, "YES", "NO"), "\n")
cat("\n")

print_complete("Node Removal Impact Analysis")
