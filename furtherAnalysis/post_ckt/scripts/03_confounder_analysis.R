# 07_confounder_analysis.R
# Confounder Discovery, Classification, Reporting, and Cycle Breaking
#
# This script consolidates the previous 07 series (07, 07b, 07c):
# 1. Identifies common parents of Exposure and Outcome (Confouders)
# 2. Excludes nodes that are also direct children (Feedback loops)
# 3. Classifies relationships (Pure vs Feedback)
# 4. Generates visual reports for valid confounders
# 5. Breaks cycles for known STRONG_CONFOUNDERS (modifies graph)
# 6. Saves the cycle-broken graph for downstream analysis
#
# Input: data/{Exposure}_{Outcome}/degreeN/s1_graph/pruned_graph.rds
# Output: data/{Exposure}_{Outcome}/degreeN/s3_confounders/
#   - valid_confounders.csv
#   - graph_cycle_broken.rds
#   - reports/{confounder}/...

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
  default_degree = 2
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths ----
input_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
output_dir <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s3_confounders")
reports_dir <- file.path(output_dir, "reports")

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop("Pruned graph not found at: ", input_file, "\nPlease run 01c_prune_generic_hubs.R first.\n")
}

ensure_dir(output_dir)
ensure_dir(reports_dir)

print_header(paste0("Confounder Analysis (Discovery & Cycles) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
graph <- readRDS(input_file)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")

# Verify exposure and outcome exist
if (!(exposure_name %in% V(graph)$name)) stop("Exposure node not found!")
if (!(outcome_name %in% V(graph)$name)) stop("Outcome node not found!")

# ==========================================
# 2. IDENTIFY POTENTIAL CONFOUNDERS
# ==========================================
cat("=== 2. IDENTIFYING POTENTIAL CONFOUNDERS ===\n")

# Direct parents (incoming neighbors)
parents_A <- names(neighbors(graph, exposure_name, mode = "in"))
parents_Y <- names(neighbors(graph, outcome_name, mode = "in"))
common_parents <- intersect(parents_A, parents_Y)

# Direct children (outgoing neighbors)
children_A <- names(neighbors(graph, exposure_name, mode = "out"))
children_Y <- names(neighbors(graph, outcome_name, mode = "out"))
children_AY <- union(children_A, children_Y)

cat("Common Direct Parents:", length(common_parents), "\n")
cat("Direct Children (A or Y):", length(children_AY), "\n\n")

if (length(common_parents) == 0) {
  cat("No common direct parents found. Exiting.\n")
  quit(save = "no")
}

# ==========================================
# 3. CLASSIFY AND FILTER CONFOUNDERS
# ==========================================
cat("=== 3. CLASSIFYING CONFOUNDERS ===\n")

confounder_stats <- data.frame(
  node = character(),
  is_child_A = logical(),
  is_child_Y = logical(),
  cycle_len_A = numeric(),
  cycle_len_Y = numeric(),
  classification = character(),
  is_valid = logical(),
  stringsAsFactors = FALSE
)

cat(" Analyzing", length(common_parents), "candidates (calculating feedback loops)...\n")

for (node in common_parents) {
  # Check if direct child
  is_child_A <- node %in% children_A
  is_child_Y <- node %in% children_Y
  
  # Calculate cycle lengths (shortest path back to C)
  dist_A_C <- Inf
  if (!is_child_A) { # Optimize: if direct child, dist is 1 (len 2)
    path <- shortest_paths(graph, from = exposure_name, to = node, mode = "out")$vpath[[1]]
    if (length(path) > 0) dist_A_C <- length(path) - 1
  } else {
    dist_A_C <- 1
  }
  
  dist_Y_C <- Inf
  if (!is_child_Y) {
    path <- shortest_paths(graph, from = outcome_name, to = node, mode = "out")$vpath[[1]]
    if (length(path) > 0) dist_Y_C <- length(path) - 1
  } else {
    dist_Y_C <- 1
  }
  
  cycle_len_A <- dist_A_C + 1
  cycle_len_Y <- dist_Y_C + 1
  min_len <- min(cycle_len_A, cycle_len_Y)
  
  # Classification
  classification <- "Pure Confounder"
  if (min_len <= 3) {
    classification <- "Tight Feedback"
  } else if (!is.infinite(min_len)) {
    classification <- "Long Feedback"
  }
  
  # VALIDITY: Not a direct child (length 2 cycle)
  # This aligns with 07c "Exclude Direct Children" rule
  is_valid <- !(is_child_A || is_child_Y)
  
  confounder_stats <- rbind(confounder_stats, data.frame(
    node = node,
    is_child_A = is_child_A,
    is_child_Y = is_child_Y,
    cycle_len_A = cycle_len_A,
    cycle_len_Y = cycle_len_Y,
    classification = classification,
    is_valid = is_valid,
    stringsAsFactors = FALSE
  ))
}

valid_confounders <- confounder_stats$node[confounder_stats$is_valid]
cat("Valid Confounders (not direct children):", length(valid_confounders), "\n")
cat("Excluded (feedback/children):", sum(!confounder_stats$is_valid), "\n\n")

# Save detailed stats
write.csv(confounder_stats, file.path(output_dir, "confounder_classification.csv"), row.names = FALSE)
write.csv(confounder_stats[confounder_stats$is_valid, ], file.path(output_dir, "valid_confounders.csv"), row.names = FALSE)

# ==========================================
# 4. GENERATE SUMMARY REPORTS
# ==========================================
cat("=== 4. GENERATING REPORTS FOR VALID CONFOUNDERS ===\n")

# Helper functions from 07b
extract_confounder_subgraph <- function(g, confounder_name, exposure, outcome) {
  nodes <- c(confounder_name, exposure, outcome)
  
  # Add cycle paths if they exist
  path_A <- shortest_paths(g, from = exposure, to = confounder_name, mode = "out")$vpath[[1]]
  if (length(path_A) > 0) nodes <- c(nodes, names(path_A))
  
  path_Y <- shortest_paths(g, from = outcome, to = confounder_name, mode = "out")$vpath[[1]]
  if (length(path_Y) > 0) nodes <- c(nodes, names(path_Y))
  
  return(induced_subgraph(g, unique(nodes)))
}

save_subgraph_plot <- function(subgraph, confounder_name, exposure, outcome, filepath) {
  # Colors
  V(subgraph)$color <- "lightgray"
  V(subgraph)$color[V(subgraph)$name == confounder_name] <- "gold"
  V(subgraph)$color[V(subgraph)$name == exposure] <- "lightblue"
  V(subgraph)$color[V(subgraph)$name == outcome] <- "lightcoral"
  
  # Shapes
  V(subgraph)$shape <- "circle"
  V(subgraph)$shape[V(subgraph)$name == confounder_name] <- "square"
  
  png(filepath, width = 800, height = 600)
  plot(subgraph, layout = layout_with_fr, vertex.size = 30, vertex.label.cex = 0.8,
       main = paste("Confounder:", confounder_name))
  legend("bottomright", legend = c("Confounder", "Exposure", "Outcome"), 
         fill = c("gold", "lightblue", "lightcoral"))
  dev.off()
}

count <- 0
for (node in valid_confounders) {
  count <- count + 1
  if (count %% 10 == 0) cat("Processing", count, "/", length(valid_confounders), "...\n")
  
  # Create directory
  node_dir <- file.path(reports_dir, gsub("[^a-zA-Z0-9_]", "_", node))
  ensure_dir(node_dir)
  
  # Extract and save subgraph
  sub <- extract_confounder_subgraph(graph, node, exposure_name, outcome_name)
  saveRDS(sub, file.path(node_dir, "subgraph.rds"))
  save_subgraph_plot(sub, node, exposure_name, outcome_name, file.path(node_dir, "subgraph.png"))
  
  # Save edge list
  edges <- igraph::as_data_frame(sub, what = "edges")
  write.csv(edges, file.path(node_dir, "edges.csv"), row.names = FALSE)
}
cat("Reports generated.\n\n")

# ==========================================
# 5. BREAK CYCLES FOR STRONG CONFOUNDERS
# ==========================================
cat("=== 5. BREAKING CYCLES (STRONG CONFOUNDERS) ===\n")

strong_in_graph <- intersect(STRONG_CONFOUNDERS, V(graph)$name)
cat("Strong confounders in graph:", length(strong_in_graph), "\n")

edges_removed <- 0
for (sc in strong_in_graph) {
  # Remove E -> SC
  if (are_adjacent(graph, exposure_name, sc)) {
    graph <- delete_edges(graph, get_edge_ids(graph, c(exposure_name, sc)))
    edges_removed <- edges_removed + 1
  }
  # Remove O -> SC
  if (are_adjacent(graph, outcome_name, sc)) {
    graph <- delete_edges(graph, get_edge_ids(graph, c(outcome_name, sc)))
    edges_removed <- edges_removed + 1
  }
}

cat("Removed", edges_removed, "feedback edges from strong confounders.\n")

# Save cycle-broken graph
out_graph_file <- file.path(output_dir, "graph_cycle_broken.rds")
saveRDS(graph, out_graph_file)
cat("Saved cycle-broken graph to:", out_graph_file, "\n")
cat("(Downstream scripts should transform/use this graph)\n\n")

print_complete("Confounder Analysis")
