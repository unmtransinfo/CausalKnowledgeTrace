# 02_basic_analysis.R
# Basic graph analysis: statistics, exposure/outcome connections, and node characteristics

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
  default_exposure = "Depression",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
input_file <- get_parsed_graph_path(exposure_name, outcome_name)
output_dir <- get_analysis_output_dir(exposure_name, outcome_name)

# ---- Validate inputs ----
validate_inputs(exposure_name, outcome_name, require_parsed_graph = TRUE)

print_header("Basic Graph Analysis", exposure_name, outcome_name)
cat("Loading graph from:", input_file, "\n\n")

# Load the parsed graph
graph <- readRDS(input_file)

# ==========================================
# 1. BASIC GRAPH STATISTICS
# ==========================================
cat("=== 1. GRAPH STATISTICS ===\n")
cat("Nodes:", vcount(graph), "\n")
cat("Edges:", ecount(graph), "\n")
cat("Directed:", is_directed(graph), "\n")
cat("Graph density:", round(graph.density(graph), 4), "\n")
cat("  (0 = sparse, 1 = complete graph)\n")
cat("Connected (weakly):", is_connected(graph, mode = "weak"), "\n")
cat("Connected (strongly):", is_connected(graph, mode = "strong"), "\n\n")

# ==========================================
# 2. EXPOSURE AND OUTCOME NODES
# ==========================================
cat("=== 2. EXPOSURE AND OUTCOME NODES ===\n")
exposure_nodes <- V(graph)[V(graph)$type == "exposure"]$name
outcome_nodes <- V(graph)[V(graph)$type == "outcome"]$name

cat("Exposure node:", exposure_nodes, "\n")
cat("Outcome node:", outcome_nodes, "\n\n")

# Analyze exposure node connections
if (length(exposure_nodes) > 0) {
  exposure <- exposure_nodes[1]

  # Outgoing edges from exposure (what does CVD cause?)
  out_neighbors <- neighbors(graph, exposure, mode = "out")
  cat("Exposure node '", exposure, "' has:\n", sep = "")
  cat("  - ", length(out_neighbors), " outgoing connections (direct effects)\n", sep = "")

  # Incoming edges to exposure (what causes CVD?)
  in_neighbors <- neighbors(graph, exposure, mode = "in")
  cat("  - ", length(in_neighbors), " incoming connections (causes)\n\n", sep = "")

  cat("Top 10 direct effects of ", exposure, ":\n", sep = "")
  if (length(out_neighbors) > 0) {
    print(head(out_neighbors$name, 10))
  } else {
    cat("  (none)\n")
  }
  cat("\n")

  cat("Top 10 causes of ", exposure, ":\n", sep = "")
  if (length(in_neighbors) > 0) {
    print(head(in_neighbors$name, 10))
  } else {
    cat("  (none)\n")
  }
  cat("\n")
}

# Analyze outcome node connections
if (length(outcome_nodes) > 0) {
  outcome <- outcome_nodes[1]

  # Incoming edges to outcome (what causes dementia?)
  in_neighbors <- neighbors(graph, outcome, mode = "in")
  cat("Outcome node '", outcome, "' has:\n", sep = "")
  cat("  - ", length(in_neighbors), " incoming connections (direct causes)\n", sep = "")

  # Outgoing edges from outcome (what does dementia cause?)
  out_neighbors <- neighbors(graph, outcome, mode = "out")
  cat("  - ", length(out_neighbors), " outgoing connections (effects)\n\n", sep = "")

  cat("Top 10 direct causes of ", outcome, ":\n", sep = "")
  if (length(in_neighbors) > 0) {
    print(head(in_neighbors$name, 10))
  } else {
    cat("  (none)\n")
  }
  cat("\n")

  cat("Top 10 effects of ", outcome, ":\n", sep = "")
  if (length(out_neighbors) > 0) {
    print(head(out_neighbors$name, 10))
  } else {
    cat("  (none)\n")
  }
  cat("\n")
}

# Path from exposure to outcome
if (length(exposure_nodes) > 0 && length(outcome_nodes) > 0) {
  exposure <- exposure_nodes[1]
  outcome <- outcome_nodes[1]

  cat("=== Path Analysis: ", exposure, " -> ", outcome, " ===\n", sep = "")

  # Check if there's a direct edge
  direct_path <- are_adjacent(graph, exposure, outcome)
  cat("Direct edge exists:", direct_path, "\n")

  # Find all simple paths (warning: can be computationally expensive)
  cat("Finding all simple paths (this may take a moment)...\n")
  all_paths <- all_simple_paths(graph, from = exposure, to = outcome, mode = "out")
  cat("Total simple paths from exposure to outcome:", length(all_paths), "\n")

  if (length(all_paths) > 0) {
    # Show shortest path
    shortest <- all_paths[[which.min(sapply(all_paths, length))]]
    cat("Shortest path length:", length(shortest), "nodes\n")
    cat("Shortest path: ", paste(names(shortest), collapse = " -> "), "\n\n", sep = "")

    # Show distribution of path lengths
    path_lengths <- sapply(all_paths, length)
    cat("Path length distribution:\n")
    print(table(path_lengths))
    cat("\n")
  }
}

# ==========================================
# 3. NODE DEGREE ANALYSIS
# ==========================================
cat("=== 3. NODE DEGREE ANALYSIS ===\n")

# Calculate degrees
in_degree <- degree(graph, mode = "in")
out_degree <- degree(graph, mode = "out")
total_degree <- degree(graph, mode = "all")

cat("Degree statistics:\n")
cat("  In-degree  - Min:", min(in_degree), " Max:", max(in_degree), " Mean:", round(mean(in_degree), 2), "\n")
cat("  Out-degree - Min:", min(out_degree), " Max:", max(out_degree), " Mean:", round(mean(out_degree), 2), "\n")
cat("  Total      - Min:", min(total_degree), " Max:", max(total_degree), " Mean:", round(mean(total_degree), 2), "\n\n")

# Top 20 nodes by total degree
cat("=== TOP 20 MOST CONNECTED NODES (by total degree) ===\n")
top_nodes <- sort(total_degree, decreasing = TRUE)[1:20]
top_df <- data.frame(
  Node = names(top_nodes),
  Total_Degree = as.numeric(top_nodes),
  In_Degree = in_degree[names(top_nodes)],
  Out_Degree = out_degree[names(top_nodes)]
)
print(top_df)
cat("\n")

# Nodes with very high in-degree (potential "effect hubs")
cat("=== TOP 15 NODES BY IN-DEGREE (potential effect hubs) ===\n")
top_in <- sort(in_degree, decreasing = TRUE)[1:15]
print(data.frame(Node = names(top_in), In_Degree = as.numeric(top_in)))
cat("\n")

# Nodes with very high out-degree (potential "cause hubs")
cat("=== TOP 15 NODES BY OUT-DEGREE (potential cause hubs) ===\n")
top_out <- sort(out_degree, decreasing = TRUE)[1:15]
print(data.frame(Node = names(top_out), Out_Degree = as.numeric(top_out)))
cat("\n")

# ==========================================
# 4. SAVE RESULTS
# ==========================================
cat("=== 4. SAVING RESULTS ===\n")

# Create output directory if needed
ensure_dir(output_dir)

# Save degree data
degree_data <- data.frame(
  Node = V(graph)$name,
  Type = V(graph)$type,
  In_Degree = in_degree,
  Out_Degree = out_degree,
  Total_Degree = total_degree
)
degree_data <- degree_data[order(-degree_data$Total_Degree), ]

output_file <- file.path(output_dir, "node_degrees.csv")
write.csv(degree_data, output_file, row.names = FALSE)
cat("Saved node degree data to:", output_file, "\n")

# Save basic stats
stats_file <- file.path(output_dir, "graph_statistics.txt")
sink(stats_file)
cat("=== GRAPH STATISTICS ===\n")
cat("Nodes:", vcount(graph), "\n")
cat("Edges:", ecount(graph), "\n")
cat("Density:", graph.density(graph), "\n")
cat("Weakly connected:", is_connected(graph, mode = "weak"), "\n")
cat("Strongly connected:", is_connected(graph, mode = "strong"), "\n")
cat("\nExposure:", exposure_nodes, "\n")
cat("Outcome:", outcome_nodes, "\n")
cat("\nDegree Statistics:\n")
cat("Mean in-degree:", mean(in_degree), "\n")
cat("Mean out-degree:", mean(out_degree), "\n")
cat("Max in-degree:", max(in_degree), "\n")
cat("Max out-degree:", max(out_degree), "\n")
sink()
cat("Saved graph statistics to:", stats_file, "\n")

print_complete("Basic Graph Analysis")
