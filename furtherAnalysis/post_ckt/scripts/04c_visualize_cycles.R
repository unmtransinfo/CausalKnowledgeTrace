# 04c_visualize_cycles.R
# Visualize saved cycle subgraphs and save as image files

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
library(ggraph)
library(ggplot2)

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Depression",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
cycle_dir <- get_cycle_output_dir(exposure_name, outcome_name)
images_dir <- file.path(cycle_dir, "images")

# Create images directory
ensure_dir(images_dir)

print_header("Cycle Subgraph Visualization", exposure_name, outcome_name)
cat("Cycle directory:", cycle_dir, "\n")
cat("Images directory:", images_dir, "\n\n")

# ==========================================
# 1. FIND ALL CYCLE SUBGRAPH FILES
# ==========================================
cat("=== 1. FINDING CYCLE SUBGRAPH FILES ===\n")

cycle_files <- list.files(cycle_dir, pattern = "^scc.*_cycle.*\\.rds$", full.names = TRUE)
cat("Found", length(cycle_files), "cycle subgraph files\n\n")

if (length(cycle_files) == 0) {
  stop("No cycle subgraph files found. Run 04b_extract_analyze_cycle.R first.")
}

# ==========================================
# 2. VISUALIZATION FUNCTION
# ==========================================

visualize_cycle <- function(cycle_file, output_dir) {
  # Load the cycle subgraph
  cycle_graph <- readRDS(cycle_file)

  # Get metadata
  scc_id <- graph_attr(cycle_graph, "scc_id")
  cycle_id <- graph_attr(cycle_graph, "cycle_id")
  cycle_path <- graph_attr(cycle_graph, "cycle_path")

  # Get file basename for output naming
  base_name <- tools::file_path_sans_ext(basename(cycle_file))

  # Number of nodes in cycle
  n_nodes <- vcount(cycle_graph)

  # Create title
  title <- sprintf("SCC %d - Cycle %d (%d nodes)", scc_id, cycle_id, n_nodes)

  # Choose layout based on cycle size
  if (n_nodes <= 10) {
    layout_type <- "circle"
  } else if (n_nodes <= 20) {
    layout_type <- "kk"  # Kamada-Kawai
  } else {
    layout_type <- "fr"  # Fruchterman-Reingold
  }

  # Create the visualization using ggraph
  p <- ggraph(cycle_graph, layout = layout_type) +
    geom_edge_link(
      arrow = arrow(length = unit(3, "mm"), type = "closed"),
      end_cap = circle(3, "mm"),
      edge_colour = "gray40",
      edge_width = 0.8
    ) +
    geom_node_point(size = 8, colour = "steelblue") +
    geom_node_text(aes(label = name), size = 3, repel = TRUE) +
    labs(
      title = title,
      subtitle = paste("Path:", cycle_path)
    ) +
    theme_void() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
      plot.subtitle = element_text(hjust = 0.5, size = 8, color = "gray40"),
      plot.margin = margin(10, 10, 10, 10)
    )

  # Adjust figure size based on cycle length
  fig_width <- max(8, n_nodes * 0.5)
  fig_height <- max(6, n_nodes * 0.4)

  # Cap the size
  fig_width <- min(fig_width, 16)
  fig_height <- min(fig_height, 12)

  # Save the plot
  output_file <- file.path(output_dir, paste0(base_name, ".png"))
  ggsave(output_file, p, width = fig_width, height = fig_height, dpi = 150)

  return(output_file)
}

# ==========================================
# 3. VISUALIZE ALL CYCLES
# ==========================================
cat("=== 2. VISUALIZING CYCLES ===\n")

successful <- 0
failed <- 0

for (i in seq_along(cycle_files)) {
  cycle_file <- cycle_files[i]
  base_name <- basename(cycle_file)

  cat(sprintf("[%d/%d] Visualizing %s... ", i, length(cycle_files), base_name))

  tryCatch({
    output_file <- visualize_cycle(cycle_file, images_dir)
    cat("OK\n")
    successful <- successful + 1
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    failed <<- failed + 1
  })
}

# ==========================================
# 4. SUMMARY
# ==========================================
cat("\n=== SUMMARY ===\n")
cat("Total cycle files:", length(cycle_files), "\n")
cat("Successfully visualized:", successful, "\n")
cat("Failed:", failed, "\n")
cat("Images saved to:", images_dir, "\n")

print_complete("Cycle Subgraph Visualization")
