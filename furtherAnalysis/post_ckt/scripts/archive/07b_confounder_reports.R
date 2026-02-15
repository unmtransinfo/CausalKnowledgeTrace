# 07b_confounder_reports.R
# Find confounders and generate subgraph reports for each
#
# This script is self-contained: it finds confounders (common parents) 
# and generates subgraph visualizations showing the confounder's relationship
# with Exposure and Outcome, including any cycle paths.
#
# Input: data/{Exposure}_{Outcome}/s1_graph/pruned_graph.rds
# Output: data/{Exposure}_{Outcome}/s7_confounders/reports/
#   - {confounder_name}/subgraph.rds
#   - {confounder_name}/subgraph.png
#   - {confounder_name}/edges.csv  
#   - confounders_list.csv (regenerated)

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
  default_degree = 3
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths ----
graph_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
output_dir <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s7_confounders")
reports_dir <- file.path(output_dir, "reports")

# ---- Validate inputs ----
if (!file.exists(graph_file)) {
  stop(paste0("Graph not found at: ", graph_file, "\nPlease run 01a_prune_generic_hubs.R first.\n"))
}

ensure_dir(output_dir)
ensure_dir(reports_dir)

print_header(paste0("Confounder Discovery & Reports - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH & IDENTIFY KEY NODES
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
graph <- readRDS(graph_file)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n")

# Verify exposure and outcome exist
if (!(exposure_name %in% V(graph)$name)) {
  stop(paste("Exposure node", exposure_name, "not found in the graph!"))
}
if (!(outcome_name %in% V(graph)$name)) {
  stop(paste("Outcome node", outcome_name, "not found in the graph!"))
}

cat("Exposure Node:", exposure_name, "\n")
cat("Outcome Node:", outcome_name, "\n\n")

# ==========================================
# 2. FIND COMMON PARENTS (CONFOUNDERS)
# ==========================================
cat("=== 2. FINDING CONFOUNDERS ===\n")

# Get parents (incoming neighbors)
parents_A <- names(neighbors(graph, exposure_name, mode = "in"))
parents_Y <- names(neighbors(graph, outcome_name, mode = "in"))

cat("Parents of Exposure:", length(parents_A), "\n")
cat("Parents of Outcome:", length(parents_Y), "\n")

# Intersect to find common parents
common_parents <- intersect(parents_A, parents_Y)
cat("Common Parents (Potential Confounders):", length(common_parents), "\n\n")

if (length(common_parents) == 0) {
  cat("No common parents found. No confounders to process.\n")
  quit(save = "no")
}

# ==========================================
# 3. HELPER FUNCTIONS
# ==========================================

#' Extract subgraph for a confounder
extract_confounder_subgraph <- function(g, confounder_name, exposure, outcome, dist_A_to_C, dist_Y_to_C) {
  
  # Start with base nodes: C, A, Y
  nodes_to_include <- c(confounder_name, exposure, outcome)
  
  # If cycle exists with Exposure, get the path A -> ... -> C
  if (!is.infinite(dist_A_to_C)) {
    path_A_C <- shortest_paths(g, from = exposure, to = confounder_name, mode = "out")$vpath[[1]]
    if (length(path_A_C) > 0) {
      nodes_to_include <- c(nodes_to_include, names(path_A_C))
    }
  }
  
  # If cycle exists with Outcome, get the path Y -> ... -> C
  if (!is.infinite(dist_Y_to_C)) {
    path_Y_C <- shortest_paths(g, from = outcome, to = confounder_name, mode = "out")$vpath[[1]]
    if (length(path_Y_C) > 0) {
      nodes_to_include <- c(nodes_to_include, names(path_Y_C))
    }
  }
  
  # Remove duplicates
  nodes_to_include <- unique(nodes_to_include)
  
  # Extract subgraph
  subgraph <- induced_subgraph(g, vids = nodes_to_include)
  
  return(subgraph)
}

#' Save visualization of confounder subgraph
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

# ==========================================
# 4. PROCESS EACH CONFOUNDER
# ==========================================
cat("=== 3. PROCESSING CONFOUNDERS ===\n")

confounder_stats <- data.frame(
  node = character(),
  dist_A_to_C = numeric(),
  dist_Y_to_C = numeric(),
  cycle_len_A = numeric(),
  cycle_len_Y = numeric(),
  min_cycle_len = numeric(),
  classification = character(),
  stringsAsFactors = FALSE
)

processed <- 0
failed <- 0

for (confounder_name in common_parents) {
  
  processed <- processed + 1
  if (processed %% 20 == 0 || processed == 1) {
    cat("Processing", processed, "/", length(common_parents), ":", confounder_name, "\n")
  }
  
  tryCatch({
    
    # --- Step A: Calculate cycle distances ---
    path_A_C <- shortest_paths(graph, from = exposure_name, to = confounder_name, mode = "out")
    len_A_C <- length(path_A_C$vpath[[1]])
    dist_A_C <- if(len_A_C > 0) len_A_C - 1 else Inf
    
    path_Y_C <- shortest_paths(graph, from = outcome_name, to = confounder_name, mode = "out")
    len_Y_C <- length(path_Y_C$vpath[[1]])
    dist_Y_C <- if(len_Y_C > 0) len_Y_C - 1 else Inf
    
    cycle_len_A <- if(is.infinite(dist_A_C)) Inf else dist_A_C + 1
    cycle_len_Y <- if(is.infinite(dist_Y_C)) Inf else dist_Y_C + 1
    min_len <- min(cycle_len_A, cycle_len_Y)
    
    classification <- "Pure Confounder"
    if (!is.infinite(min_len)) {
      if (min_len <= 3) {
        classification <- "Tight Feedback"
      } else {
        classification <- "Long Feedback"
      }
    }
    
    # Store stats
    confounder_stats <- rbind(confounder_stats, data.frame(
      node = confounder_name,
      dist_A_to_C = dist_A_C,
      dist_Y_to_C = dist_Y_C,
      cycle_len_A = cycle_len_A,
      cycle_len_Y = cycle_len_Y,
      min_cycle_len = min_len,
      classification = classification,
      stringsAsFactors = FALSE
    ))
    
    # --- FILTER: Only generate reports for Pure Confounders ---
    if (classification != "Pure Confounder") {
      # Skip report generation for feedback nodes
      next
    }
    
    # --- Step B: Extract subgraph (only for Pure Confounders) ---
    subgraph <- extract_confounder_subgraph(
      g = graph,
      confounder_name = confounder_name,
      exposure = exposure_name,
      outcome = outcome_name,
      dist_A_to_C = dist_A_C,
      dist_Y_to_C = dist_Y_C
    )
    
    # --- Step C: Save outputs ---
    safe_name <- gsub("[^a-zA-Z0-9_]", "_", confounder_name)
    conf_dir <- file.path(reports_dir, safe_name)
    ensure_dir(conf_dir)
    
    # Save subgraph RDS
    saveRDS(subgraph, file.path(conf_dir, "subgraph.rds"))
    
    # Save visualization
    save_subgraph_plot(
      subgraph = subgraph,
      confounder_name = confounder_name,
      exposure = exposure_name,
      outcome = outcome_name,
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

# ==========================================
# 5. SAVE SUMMARY
# ==========================================
cat("\n=== 4. SAVING SUMMARY ===\n")

# Organize and save all common parents with classifications
confounder_stats <- confounder_stats %>%
  arrange(min_cycle_len, node)

write.csv(confounder_stats, file.path(output_dir, "confounders_all_07b.csv"), row.names = FALSE)
cat("Saved all common parents to:", file.path(output_dir, "confounders_all_07b.csv"), "\n")

# Filter and save only Pure Confounders
pure_confounders <- confounder_stats %>%
  filter(classification == "Pure Confounder")

write.csv(pure_confounders, file.path(output_dir, "confounders_list_07b.csv"), row.names = FALSE)
cat("Saved PURE confounders to:", file.path(output_dir, "confounders_list_07b.csv"), "\n")

# Print summary
cat("\n=== SUMMARY ===\n")
cat("Total common parents:", nrow(confounder_stats), "\n")
cat("Pure Confounders (Valid):", nrow(pure_confounders), "\n")
cat("Excluded (Feedback):", nrow(confounder_stats) - nrow(pure_confounders), "\n\n")

cat("Classification Breakdown:\n")
print(table(confounder_stats$classification))

cat("\nReports generated ONLY for Pure Confounders:", nrow(pure_confounders), "\n")
cat("Reports saved to:", reports_dir, "\n")

print_complete("Confounder Discovery & Reports")
