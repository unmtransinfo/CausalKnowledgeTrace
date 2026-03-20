#!/usr/bin/env Rscript

# =============================================================================
# Script: 03d_extract_confounder_subgraphs.R
# Purpose: Generate subgraph visualizations and edge lists for ALL identified confounders
#          (both valid and invalid/feedback loops).
#          Logic and styling replicated from archived 07b_confounder_reports.R.
# =============================================================================

# =============================================================================
# Configuration
# =============================================================================

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

suppressPackageStartupMessages({
  library(igraph)
  library(dplyr)
  library(data.table)
})

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Depression",
  default_outcome = "Alzheimers",
  default_degree = 3
)
EXPOSURE <- args$exposure
OUTCOME <- args$outcome
DEGREE <- args$degree

# ---- Set paths ----
DATA_DIR <- get_pair_dir(EXPOSURE, OUTCOME, DEGREE)
GRAPH_FILE <- get_pruned_graph_path(EXPOSURE, OUTCOME, DEGREE)
CLASSIFICATION_FILE <- file.path(DATA_DIR, "s3_confounders", "confounder_classification.csv")
REPORTS_DIR <- file.path(DATA_DIR, "s3_confounders", "reports")

# ---- Validate inputs ----
if (!file.exists(GRAPH_FILE)) {
  stop("Graph file not found: ", GRAPH_FILE)
}
if (!file.exists(CLASSIFICATION_FILE)) {
  stop("Classification file not found: ", CLASSIFICATION_FILE)
}

ensure_dir(REPORTS_DIR)

print_header(paste0("Extracting Subgraphs for ALL Confounders - Degree ", DEGREE), EXPOSURE, OUTCOME)

# =============================================================================
# 1. LOAD GRAPH AND CONFOUNDERS
# =============================================================================

cat("Loading graph...\n")
graph <- readRDS(GRAPH_FILE)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")

# Verify exposure and outcome exist (Logic from 07b)
if (!(EXPOSURE %in% V(graph)$name)) {
  stop(paste("Exposure node", EXPOSURE, "not found in the graph!"))
}
if (!(OUTCOME %in% V(graph)$name)) {
  stop(paste("Outcome node", OUTCOME, "not found in the graph!"))
}

cat("Exposure Node:", EXPOSURE, "\n")
cat("Outcome Node:", OUTCOME, "\n\n")

cat("Loading confounder list...\n")
confounders_df <- fread(CLASSIFICATION_FILE)
all_confounders <- confounders_df$node
cat("Total confounders to process:", length(all_confounders), "\n\n")

# =============================================================================
# 2. HELPER FUNCTIONS (Replicated from 07b)
# =============================================================================

#' Extract subgraph for a confounder
extract_confounder_subgraph <- function(g, confounder_name, exposure, outcome, dist_A_to_C, dist_Y_to_C) {
  
  # Start with base nodes: C, A, Y
  nodes_to_include <- c(confounder_name, exposure, outcome)
  
  # If cycle exists with Exposure, get the path A -> ... -> C
  if (!is.infinite(dist_A_to_C)) {
    tryCatch({
      path_A_C <- shortest_paths(g, from = exposure, to = confounder_name, mode = "out")$vpath[[1]]
      if (length(path_A_C) > 0) {
        nodes_to_include <- c(nodes_to_include, names(path_A_C))
      }
    }, error = function(e) {})
  }
  
  # If cycle exists with Outcome, get the path Y -> ... -> C
  if (!is.infinite(dist_Y_to_C)) {
    tryCatch({
      path_Y_C <- shortest_paths(g, from = outcome, to = confounder_name, mode = "out")$vpath[[1]]
      if (length(path_Y_C) > 0) {
        nodes_to_include <- c(nodes_to_include, names(path_Y_C))
      }
    }, error = function(e) {})
  }
  
  # Remove duplicates and NA
  nodes_to_include <- unique(nodes_to_include[!is.na(nodes_to_include)])
  
  # Extract subgraph
  subgraph <- induced_subgraph(g, vids = nodes_to_include)
  
  return(subgraph)
}

#' Save visualization of confounder subgraph (Exact style from 07b)
save_subgraph_plot <- function(subgraph, confounder_name, exposure, outcome, output_path) {
  
  # Set node colors
  node_colors <- rep("lightgray", vcount(subgraph))
  node_names <- V(subgraph)$name
  
  node_colors[node_names == confounder_name] <- "gold"      # Confounder = gold
  node_colors[node_names == exposure] <- "lightblue"        # Exposure = blue
  node_colors[node_names == outcome] <- "lightcoral"        # Outcome = red
  
  # Set node shapes
  node_shapes <- rep("circle", vcount(subgraph))
  node_shapes[node_names == confounder_name] <- "square"
  
  # Open PNG device
  png(output_path, width = 800, height = 600, res = 100)
  
  # Set layout
  layout <- layout_with_fr(subgraph)
  
  # Plot
  plot(subgraph,
       vertex.color = node_colors,
       vertex.shape = node_shapes,
       vertex.size = 30,
       vertex.label = V(subgraph)$name,
       vertex.label.cex = 0.8,
       vertex.label.color = "black",
       edge.arrow.size = 0.5,
       edge.color = "darkgray",
       main = paste0("Confounder: ", confounder_name))
  
  # Add legend
  legend("bottomright",
         legend = c("Confounder", "Exposure", "Outcome", "Other"),
         fill = c("gold", "lightblue", "lightcoral", "lightgray"),
         cex = 0.8)
  
  dev.off()
}

# =============================================================================
# 3. PROCESS ALL CONFOUNDERS
# =============================================================================

processed <- 0
failed <- 0

for (confounder_name in all_confounders) {
  
  processed <- processed + 1
  cat(sprintf("[%d/%d] Processing: %s\n", processed, length(all_confounders), confounder_name))
  
  tryCatch({
    
    # --- Step A: Calculate cycle distances (Replicating logic) ---
    dist_A_C <- Inf
    tryCatch({
      path_A_C <- shortest_paths(graph, from = EXPOSURE, to = confounder_name, mode = "out")
      len_A_C <- length(path_A_C$vpath[[1]])
      if(len_A_C > 0) dist_A_C <- len_A_C - 1
    }, error = function(e) {})
    
    dist_Y_C <- Inf
    tryCatch({
      path_Y_C <- shortest_paths(graph, from = OUTCOME, to = confounder_name, mode = "out")
      len_Y_C <- length(path_Y_C$vpath[[1]])
      if(len_Y_C > 0) dist_Y_C <- len_Y_C - 1
    }, error = function(e) {})
    
    # --- Step B: Extract subgraph ---
    # We do NOT skip based on classification. We process ALL.
    
    subgraph <- extract_confounder_subgraph(
      g = graph,
      confounder_name = confounder_name,
      exposure = EXPOSURE,
      outcome = OUTCOME,
      dist_A_to_C = dist_A_C,
      dist_Y_to_C = dist_Y_C
    )
    
    # --- Step C: Save outputs ---
    safe_name <- gsub("[^a-zA-Z0-9_]", "_", confounder_name)
    conf_dir <- file.path(REPORTS_DIR, safe_name)
    ensure_dir(conf_dir)
    
    # Save subgraph RDS
    saveRDS(subgraph, file.path(conf_dir, "subgraph.rds"))
    
    # Save visualization
    save_subgraph_plot(
      subgraph = subgraph,
      confounder_name = confounder_name,
      exposure = EXPOSURE,
      outcome = OUTCOME,
      output_path = file.path(conf_dir, "subgraph.png")
    )
    
    # Save edge list (use igraph:: to avoid dplyr conflict)
    edges_df <- igraph::as_data_frame(subgraph, what = "edges")
    edges_df$confounder <- confounder_name
    write.csv(edges_df, file.path(conf_dir, "edges.csv"), row.names = FALSE)
    
  }, error = function(e) {
    cat("  ERROR processing", confounder_name, ":", e$message, "\n")
    failed <<- failed + 1
  })
}

print_complete("Subgraph Extraction (All Confounders)")
cat("Processed:", processed, "\n")
cat("Failed:", failed, "\n")
cat("Output Directory:", REPORTS_DIR, "\n")
