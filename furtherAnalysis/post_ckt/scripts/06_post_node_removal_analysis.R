# 06_post_node_removal_analysis.R
# Analyze cycles in the graph AFTER removing generic/problematic nodes
#
# This script:
# 1. Loads the reduced graph (without generic nodes)
# 2. Detects SCCs and counts cycles
# 3. Reports top 15-20 nodes by cycle participation
# 4. Visualizes the reduced graph's cycle structure
#
# Input: data/{Exposure}_{Outcome}/s4_node_removal/reduced_graph.rds
# Output: data/{Exposure}_{Outcome}/s5_post_removal/
#   - top_nodes_by_cycles.csv
#   - all_node_cycle_participation.csv
#   - cycle_length_distribution.csv
#   - analysis_summary.csv
#   - plots/top_nodes_cycle_participation.png
#   - plots/cycle_length_distribution.png
#   - plots/cycle_subgraph.png

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
TOP_N_NODES <- NODE_REMOVAL_CONFIG$top_n_nodes_report  # Number of top nodes to report

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths ----
reduced_graph_file <- get_reduced_graph_path(exposure_name, outcome_name)
output_dir <- get_s5_post_removal_dir(exposure_name, outcome_name)
plots_dir <- file.path(output_dir, "plots")

# ---- Validate inputs ----
if (!file.exists(reduced_graph_file)) {
  stop(paste0(
    "Reduced graph not found at: ", reduced_graph_file, "\n",
    "Please run 05_node_removal_impact.R first.\n"
  ))
}

# Create output directories
ensure_dir(output_dir)
ensure_dir(plots_dir)

print_header("Post Node Removal - Cycle Analysis (Stage 5)", exposure_name, outcome_name)

# ==========================================
# 1. LOAD REDUCED GRAPH
# ==========================================
cat("=== 1. LOADING REDUCED GRAPH ===\n")
cat("Loading from:", reduced_graph_file, "\n")
graph <- readRDS(reduced_graph_file)

# Also load original for comparison
original_graph_file <- get_parsed_graph_path(exposure_name, outcome_name)
original_graph <- readRDS(original_graph_file)

cat("\nOriginal graph:", vcount(original_graph), "nodes,", ecount(original_graph), "edges\n")
cat("Reduced graph:", vcount(graph), "nodes,", ecount(graph), "edges\n")

# Load removed nodes list
s4_dir <- get_s4_node_removal_dir(exposure_name, outcome_name)
removed_nodes_file <- file.path(s4_dir, "removed_generic_nodes.txt")
if (file.exists(removed_nodes_file)) {
  removed_nodes <- readLines(removed_nodes_file)
  cat("Nodes removed:", paste(removed_nodes, collapse = ", "), "\n")
} else {
  removed_nodes <- character(0)
}
cat("\n")

# ==========================================
# 2. SCC DETECTION
# ==========================================
cat("=== 2. STRONGLY CONNECTED COMPONENT ANALYSIS ===\n")

scc <- components(graph, mode = "strong")
scc_sizes <- table(scc$membership)
large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))

cat("Total SCCs:", scc$no, "\n")
cat("SCCs with cycles (size > 1):", length(large_sccs), "\n")

if (length(large_sccs) > 0) {
  cat("\nSCCs with cycles:\n")
  for (scc_id in large_sccs) {
    scc_nodes <- V(graph)$name[scc$membership == scc_id]
    cat(sprintf("  SCC %d: %d nodes\n", scc_id, length(scc_nodes)))
    cat(sprintf("    Nodes: %s\n", paste(head(scc_nodes, 10), collapse = ", ")))
    if (length(scc_nodes) > 10) {
      cat(sprintf("    ... and %d more\n", length(scc_nodes) - 10))
    }
  }
} else {
  cat("\nNo cycles detected - the graph is a DAG!\n")
}
cat("\n")

# ==========================================
# 3. CYCLE COUNTING AND NODE PARTICIPATION
# ==========================================
cat("=== 3. CYCLE ANALYSIS ===\n")

# Function to find all cycles and track node participation
find_all_cycles_with_participation <- function(g) {
  n <- vcount(g)
  if (n == 0) {
    return(list(
      total_cycles = 0,
      node_counts = integer(0),
      length_dist = list()
    ))
  }

  node_names <- V(g)$name
  node_cycle_counts <- rep(0, n)
  names(node_cycle_counts) <- node_names

  cycle_length_counts <- list()
  total_cycles <- 0

  adj_list <- as_adj_list(g, mode = "out")

  # Progress tracking
  progress_interval <- 100000
  last_progress <- 0

  find_cycles_from_node <- function(start, current, path, visited) {
    neighbors <- adj_list[[current]]

    for (next_node in neighbors) {
      if (next_node == start && length(path) >= 2) {
        # Found a cycle
        total_cycles <<- total_cycles + 1
        cycle_length <- length(path)

        # Update node participation
        for (node_idx in path) {
          node_cycle_counts[node_idx] <<- node_cycle_counts[node_idx] + 1
        }

        # Update length distribution
        len_key <- as.character(cycle_length)
        if (is.null(cycle_length_counts[[len_key]])) {
          cycle_length_counts[[len_key]] <<- 0
        }
        cycle_length_counts[[len_key]] <<- cycle_length_counts[[len_key]] + 1

        # Progress
        if (total_cycles - last_progress >= progress_interval) {
          cat("  Found", format(total_cycles, big.mark = ","), "cycles...\n")
          last_progress <<- total_cycles
        }

      } else if (!(next_node %in% visited) && next_node > start) {
        find_cycles_from_node(start, next_node, c(path, next_node), c(visited, next_node))
      }
    }
  }

  for (start in 1:n) {
    find_cycles_from_node(start, start, c(start), c(start))
  }

  return(list(
    total_cycles = total_cycles,
    node_counts = node_cycle_counts,
    length_dist = cycle_length_counts
  ))
}

# Analyze only if there are SCCs with cycles
if (length(large_sccs) > 0) {
  cat("Counting cycles (this may take a while)...\n")
  start_time <- Sys.time()

  # Analyze each SCC
  all_node_counts <- c()
  all_length_dist <- list()
  total_cycles <- 0

  for (scc_id in large_sccs) {
    scc_nodes <- which(scc$membership == scc_id)
    scc_subgraph <- induced_subgraph(graph, scc_nodes)

    cat(sprintf("\nAnalyzing SCC %d (%d nodes, %d edges)...\n",
                scc_id, vcount(scc_subgraph), ecount(scc_subgraph)))

    result <- find_all_cycles_with_participation(scc_subgraph)

    total_cycles <- total_cycles + result$total_cycles
    all_node_counts <- c(all_node_counts, result$node_counts)

    # Merge length distributions
    for (len in names(result$length_dist)) {
      if (is.null(all_length_dist[[len]])) {
        all_length_dist[[len]] <- 0
      }
      all_length_dist[[len]] <- all_length_dist[[len]] + result$length_dist[[len]]
    }

    cat(sprintf("  Cycles in SCC %d: %s\n", scc_id, format(result$total_cycles, big.mark = ",")))
  }

  end_time <- Sys.time()
  cat("\nTotal cycles found:", format(total_cycles, big.mark = ","), "\n")
  cat("Time taken:", round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

  # Create node participation dataframe
  node_participation <- data.frame(
    node = names(all_node_counts),
    num_cycles = as.integer(all_node_counts),
    stringsAsFactors = FALSE
  ) %>%
    filter(num_cycles > 0) %>%
    arrange(desc(num_cycles))

  # Create length distribution dataframe
  length_dist_df <- data.frame(
    cycle_length = as.integer(names(all_length_dist)),
    count = unlist(all_length_dist),
    stringsAsFactors = FALSE
  ) %>%
    arrange(cycle_length)

} else {
  total_cycles <- 0
  node_participation <- data.frame(
    node = character(),
    num_cycles = integer(),
    stringsAsFactors = FALSE
  )
  length_dist_df <- data.frame(
    cycle_length = integer(),
    count = integer(),
    stringsAsFactors = FALSE
  )
  cat("No cycles to analyze - graph is acyclic.\n")
}

# ==========================================
# 4. REPORT TOP NODES
# ==========================================
cat("\n=== 4. TOP", TOP_N_NODES, "NODES BY CYCLE PARTICIPATION ===\n")

if (nrow(node_participation) > 0) {
  top_nodes <- head(node_participation, TOP_N_NODES)

  cat("\nRank | Node | Cycles\n")
  cat(paste(rep("-", 50), collapse = ""), "\n")
  for (i in 1:nrow(top_nodes)) {
    cat(sprintf("%4d | %-30s | %s\n",
                i,
                top_nodes$node[i],
                format(top_nodes$num_cycles[i], big.mark = ",")))
  }

  cat("\nTotal nodes in cycles:", nrow(node_participation), "\n")
} else {
  cat("No nodes participate in cycles.\n")
  top_nodes <- node_participation
}

# ==========================================
# 5. CYCLE LENGTH DISTRIBUTION
# ==========================================
cat("\n=== 5. CYCLE LENGTH DISTRIBUTION ===\n")

if (nrow(length_dist_df) > 0) {
  cat("\nLength | Count\n")
  cat(paste(rep("-", 30), collapse = ""), "\n")
  for (i in 1:nrow(length_dist_df)) {
    cat(sprintf("%6d | %s\n",
                length_dist_df$cycle_length[i],
                format(length_dist_df$count[i], big.mark = ",")))
  }
} else {
  cat("No cycles found.\n")
}

# ==========================================
# 6. VISUALIZATIONS
# ==========================================
cat("\n=== 6. GENERATING VISUALIZATIONS ===\n")

# 6a. Bar chart of top nodes by cycle participation
if (nrow(top_nodes) > 0) {
  p1 <- ggplot(top_nodes, aes(x = reorder(node, num_cycles), y = num_cycles)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    coord_flip() +
    labs(
      title = paste("Top", nrow(top_nodes), "Nodes by Cycle Participation"),
      subtitle = paste("After removing generic nodes -", exposure_name, "to", outcome_name),
      x = "Node",
      y = "Number of Cycles"
    ) +
    theme_minimal() +
    theme(axis.text.y = element_text(size = 8))

  ggsave(file.path(plots_dir, "top_nodes_cycle_participation.png"), p1,
         width = 10, height = 8, dpi = 150)
  cat("Saved: top_nodes_cycle_participation.png\n")
}

# 6b. Cycle length distribution
if (nrow(length_dist_df) > 0) {
  p2 <- ggplot(length_dist_df, aes(x = cycle_length, y = count)) +
    geom_bar(stat = "identity", fill = "coral") +
    labs(
      title = "Cycle Length Distribution",
      subtitle = paste("After removing generic nodes -", exposure_name, "to", outcome_name),
      x = "Cycle Length",
      y = "Count"
    ) +
    theme_minimal()

  ggsave(file.path(plots_dir, "cycle_length_distribution.png"), p2,
         width = 8, height = 6, dpi = 150)
  cat("Saved: cycle_length_distribution.png\n")
}

# 6c. Visualize the cycle subgraph (nodes in cycles only)
if (length(large_sccs) > 0) {
  # Extract all nodes in SCCs
  cycle_nodes <- which(scc$membership %in% large_sccs)
  cycle_subgraph <- induced_subgraph(graph, cycle_nodes)

  if (vcount(cycle_subgraph) <= 100) {
    # Small enough to visualize fully
    p3 <- ggraph(cycle_subgraph, layout = "fr") +
      geom_edge_link(arrow = arrow(length = unit(2, "mm")),
                     end_cap = circle(3, "mm"),
                     alpha = 0.6) +
      geom_node_point(size = 5, color = "steelblue") +
      geom_node_text(aes(label = name), repel = TRUE, size = 3) +
      labs(
        title = "Cycle Subgraph After Removing Generic Nodes",
        subtitle = paste(vcount(cycle_subgraph), "nodes,", ecount(cycle_subgraph), "edges")
      ) +
      theme_void()

    ggsave(file.path(plots_dir, "cycle_subgraph.png"), p3,
           width = 12, height = 10, dpi = 150)
    cat("Saved: cycle_subgraph.png\n")
  } else {
    cat("Cycle subgraph too large to visualize (", vcount(cycle_subgraph), " nodes)\n")
  }
}

# ==========================================
# 7. SAVE RESULTS
# ==========================================
cat("\n=== 7. SAVING RESULTS ===\n")

# Save top nodes
top_nodes_file <- file.path(output_dir, "top_nodes_by_cycles.csv")
write.csv(top_nodes, top_nodes_file, row.names = FALSE)
cat("Saved:", top_nodes_file, "\n")

# Save all node participation
all_nodes_file <- file.path(output_dir, "all_node_cycle_participation.csv")
write.csv(node_participation, all_nodes_file, row.names = FALSE)
cat("Saved:", all_nodes_file, "\n")

# Save cycle length distribution
length_file <- file.path(output_dir, "cycle_length_distribution.csv")
write.csv(length_dist_df, length_file, row.names = FALSE)
cat("Saved:", length_file, "\n")

# Save summary
summary_df <- data.frame(
  metric = c(
    "Original nodes",
    "Original edges",
    "Reduced nodes",
    "Reduced edges",
    "Nodes removed",
    "Total cycles",
    "Nodes in cycles",
    "SCCs with cycles",
    "Is DAG"
  ),
  value = c(
    vcount(original_graph),
    ecount(original_graph),
    vcount(graph),
    ecount(graph),
    length(removed_nodes),
    total_cycles,
    nrow(node_participation),
    length(large_sccs),
    ifelse(total_cycles == 0, "YES", "NO")
  ),
  stringsAsFactors = FALSE
)

summary_file <- file.path(output_dir, "analysis_summary.csv")
write.csv(summary_df, summary_file, row.names = FALSE)
cat("Saved:", summary_file, "\n")

# ==========================================
# 8. FINAL SUMMARY
# ==========================================
cat("\n")
cat(rep("=", 60), "\n", sep = "")
cat("POST NODE REMOVAL ANALYSIS SUMMARY\n")
cat(rep("=", 60), "\n", sep = "")
cat("\n")
cat("GRAPH COMPARISON:\n")
cat(sprintf("  Original: %d nodes, %d edges\n", vcount(original_graph), ecount(original_graph)))
cat(sprintf("  Reduced:  %d nodes, %d edges\n", vcount(graph), ecount(graph)))
cat(sprintf("  Removed:  %d nodes (%s)\n", length(removed_nodes), paste(removed_nodes, collapse = ", ")))
cat("\n")
cat("CYCLE STATUS:\n")
cat(sprintf("  Total cycles: %s\n", format(total_cycles, big.mark = ",")))
cat(sprintf("  Nodes in cycles: %d\n", nrow(node_participation)))
cat(sprintf("  SCCs with cycles: %d\n", length(large_sccs)))
cat(sprintf("  Is DAG: %s\n", ifelse(total_cycles == 0, "YES", "NO")))
cat("\n")

if (nrow(top_nodes) > 0) {
  cat("TOP 5 PROBLEMATIC NODES (still in cycles):\n")
  for (i in 1:min(5, nrow(top_nodes))) {
    cat(sprintf("  %d. %s (%s cycles)\n",
                i, top_nodes$node[i], format(top_nodes$num_cycles[i], big.mark = ",")))
  }
  cat("\n")
  cat("Consider removing these nodes next to further reduce cycles.\n")
}

cat("\n")
print_complete("Post Node Removal - Cycle Analysis")
