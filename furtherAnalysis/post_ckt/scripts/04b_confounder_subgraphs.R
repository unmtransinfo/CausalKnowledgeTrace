#!/usr/bin/env Rscript

# =============================================================================
# Script: 04b_confounder_subgraphs.R
# Purpose: Extract and plot subgraphs for each confounder showing its 
#          relationship to Exposure (X) and Outcome (Y), its parents,
#          and children. Butterfly candidates are clearly marked.
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
})

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 3
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Paths ----
# Use utils.R functions to get standard paths
graph_file <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s3_confounders", "graph_cycle_broken.rds")

# Fallback if cycle broken graph doesn't exist
if (!file.exists(graph_file)) {
  graph_file <- get_pruned_graph_path(exposure_name, outcome_name, degree)
  cat("Note: Using original pruned graph (no cycle-broken graph found)\n")
}

confounders_file <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s3_confounders", "valid_confounders.csv")
butterfly_file <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s4_butterfly_bias", "butterfly_analysis_results.csv")
output_dir <- file.path(get_pair_dir(exposure_name, outcome_name, degree), "s4_butterfly_bias", "graphs")

ensure_dir(output_dir)

print_header(paste0("Confounder Subgraphs & Butterfly Visualization - Degree ", degree), exposure_name, outcome_name)

# ---- Validate inputs ----
if (!file.exists(graph_file)) stop("Graph file not found: ", graph_file)
if (!file.exists(confounders_file)) stop("Confounders file not found: ", confounders_file)
if (!file.exists(butterfly_file)) stop("Butterfly analysis results not found: ", butterfly_file)

# ---- Load data ----
cat("Loading data...\n")
graph <- readRDS(graph_file)

confounders_df <- read.csv(confounders_file, stringsAsFactors = FALSE)
# Handle potential column name differences (valid_confounders.csv usually has 'node')
if ("node" %in% colnames(confounders_df)) {
  all_confounders <- confounders_df$node
} else if ("confounder" %in% colnames(confounders_df)) {
  all_confounders <- confounders_df$confounder
} else {
  stop("Could not identify confounder column in valid_confounders.csv")
}

butterfly_df <- read.csv(butterfly_file, stringsAsFactors = FALSE)

cat("Graph:", vcount(graph), "nodes,", ecount(graph), "edges\n")
cat("Confounders:", length(all_confounders), "\n")
cat("Butterfly candidates:", sum(butterfly_df$is_butterfly), "\n\n")

# =============================================================================
# Function: Extract and plot a confounder's local subgraph
# =============================================================================

plot_confounder_subgraph <- function(graph, confounder, exposure, outcome,
                                     all_confounders, butterfly_df, output_dir) {
  
  is_butterfly <- FALSE
  n_conf_parents <- 0
  
  # Check if this confounder is in the butterfly analysis results
  if (confounder %in% butterfly_df$confounder) {
    is_butterfly <- butterfly_df$is_butterfly[butterfly_df$confounder == confounder]
    n_conf_parents <- butterfly_df$n_confounder_parents[butterfly_df$confounder == confounder]
  }
  
  # Get immediate neighborhood: parents and children of this confounder
  parents <- V(graph)[neighbors(graph, confounder, mode = "in")]$name
  children <- V(graph)[neighbors(graph, confounder, mode = "out")]$name
  
  # Only keep relevant nodes: confounder, exposure, outcome, 
  # and other CONFOUNDERS that are parents or children
  confounder_parents <- intersect(parents, all_confounders)
  confounder_children <- intersect(children, all_confounders)
  subgraph_nodes <- unique(c(confounder, exposure, outcome, 
                              confounder_parents, confounder_children))
  
  # Filter to nodes that exist in graph
  subgraph_nodes <- subgraph_nodes[subgraph_nodes %in% V(graph)$name]
  
  sub_g <- induced_subgraph(graph, subgraph_nodes)
  
  # ---- Classify nodes ----
  node_types <- rep("other", vcount(sub_g))
  names(node_types) <- V(sub_g)$name
  
  node_types[exposure] <- "exposure"
  node_types[outcome] <- "outcome"
  node_types[confounder] <- if (is_butterfly) "butterfly" else "confounder_self"
  
  for (n in V(sub_g)$name) {
    if (n %in% c(exposure, outcome, confounder)) next
    if (n %in% all_confounders) {
      # Is this parent a confounder parent of the current butterfly?
      if (is_butterfly && n %in% parents && n %in% all_confounders) {
        node_types[n] <- "confounder_parent"
      } else {
        node_types[n] <- "confounder"
      }
    }
  }
  
  # ---- Colors ----
  color_map <- c(
    "exposure"          = "#E74C3C",   # Red
    "outcome"           = "#3498DB",   # Blue
    "butterfly"         = "#F39C12",   # Orange
    "confounder_self"   = "#2ECC71",   # Green (this confounder, non-butterfly)
    "confounder_parent" = "#27AE60",   # Darker green (confounder parent)
    "confounder"        = "#82E0AA",   # Light green
    "other"             = "#D5D8DC"    # Gray
  )
  
  border_map <- c(
    "exposure"          = "#C0392B",
    "outcome"           = "#2980B9",
    "butterfly"         = "#E67E22",
    "confounder_self"   = "#1E8449",
    "confounder_parent" = "#1E8449",
    "confounder"        = "#27AE60",
    "other"             = "#95A5A6"
  )
  
  v_colors <- color_map[node_types[V(sub_g)$name]]
  v_borders <- border_map[node_types[V(sub_g)$name]]
  
  # ---- Edge colors ----
  edge_df <- igraph::as_data_frame(sub_g, what = "edges")
  e_colors <- rep("#BDC3C7", nrow(edge_df))
  e_widths <- rep(1.5, nrow(edge_df))
  e_styles <- rep(1, nrow(edge_df))
  
  for (i in 1:nrow(edge_df)) {
    f <- edge_df$from[i]
    t <- edge_df$to[i]
    
    # Edges from confounder to exposure/outcome (backdoor paths) = green
    if (f == confounder && t %in% c(exposure, outcome)) {
      e_colors[i] <- "#2ECC71"
      e_widths[i] <- 2.5
    }
    # Edges from confounder parents to butterfly = orange
    if (is_butterfly && t == confounder && f %in% all_confounders) {
      e_colors[i] <- "#F39C12"
      e_widths[i] <- 2.5
    }
    # Edges involving exposure or outcome
    if (f == exposure || t == exposure) {
      e_colors[i] <- "#E74C3C"
      e_widths[i] <- 2
    }
    if (f == outcome || t == outcome) {
      e_colors[i] <- "#3498DB"
      e_widths[i] <- 2
    }
    # Re-apply confounder→exposure/outcome
    if (f == confounder && t == exposure) {
      e_colors[i] <- "#2ECC71"
      e_widths[i] <- 3
    }
    if (f == confounder && t == outcome) {
      e_colors[i] <- "#2ECC71"
      e_widths[i] <- 3
    }
  }
  
  # ---- Node labels ----
  labels <- gsub("_", "\n", V(sub_g)$name)
  
  # ---- Node sizes ----
  v_sizes <- rep(18, vcount(sub_g))
  v_sizes[V(sub_g)$name == confounder] <- 28
  v_sizes[V(sub_g)$name == exposure] <- 24
  v_sizes[V(sub_g)$name == outcome] <- 24
  
  # ---- Title ----
  marker <- if (is_butterfly) "BUTTERFLY" else "INDEPENDENT"
  title <- paste0(confounder, " [", marker, "]\n",
                  "Parents: ", length(parents), " | Children: ", length(children),
                  " | Confounder parents: ", n_conf_parents)
  
  # ---- File name with marker ----
  prefix <- if (is_butterfly) "BUTTERFLY_" else "INDEPENDENT_"
  filename <- paste0(prefix, confounder, ".png")
  filepath <- file.path(output_dir, filename)
  
  # ---- Plot ----
  png(filepath, width = 1000, height = 800, res = 100)
  par(mar = c(1, 1, 4, 1), bg = "white")
  
  # Use layout that puts confounder in center
  layout <- layout_with_fr(sub_g)
  
  plot(sub_g,
       layout = layout,
       vertex.color = v_colors,
       vertex.frame.color = v_borders,
       vertex.frame.width = 2,
       vertex.size = v_sizes,
       vertex.label = labels,
       vertex.label.cex = 0.6,
       vertex.label.color = "black",
       vertex.label.font = 2,
       edge.color = e_colors,
       edge.width = e_widths,
       edge.lty = e_styles,
       edge.arrow.size = 0.4,
       edge.curved = 0.15,
       main = title)
  
  # Legend
  legend_labels <- c("Exposure", "Outcome")
  legend_colors <- c(color_map["exposure"], color_map["outcome"])
  
  if (is_butterfly) {
    legend_labels <- c(legend_labels, "This confounder (BUTTERFLY)", "Confounder parent")
    legend_colors <- c(legend_colors, color_map["butterfly"], color_map["confounder_parent"])
  } else {
    legend_labels <- c(legend_labels, "This confounder (INDEPENDENT)")
    legend_colors <- c(legend_colors, color_map["confounder_self"])
  }
  legend_labels <- c(legend_labels, "Other confounder", "Other node")
  legend_colors <- c(legend_colors, color_map["confounder"], color_map["other"])
  
  legend("bottomright",
         legend = legend_labels,
         fill = legend_colors,
         cex = 0.7,
         bg = "white",
         title = "Node Types")
  
  dev.off()
  
  cat("  ", marker, ":", confounder, 
      "(", vcount(sub_g), "nodes,", ecount(sub_g), "edges) ->", filename, "\n")
  
  invisible(filepath)
}

# =============================================================================
# Generate all subgraphs
# =============================================================================

cat("=== GENERATING CONFOUNDER SUBGRAPHS ===\n\n")

# Sort: butterfly candidates first, then independent
butterflies_first <- butterfly_df[order(!butterfly_df$is_butterfly, butterfly_df$confounder), ]

cat("--- Processing", nrow(butterflies_first), "confounders ---\n")

for (i in 1:nrow(butterflies_first)) {
  conf <- butterflies_first$confounder[i]
  if (i %% 20 == 0) cat("  Processing", i, "/", nrow(butterflies_first), "...\n")
  
  plot_confounder_subgraph(graph, conf, exposure_name, outcome_name, 
                           all_confounders, butterfly_df, output_dir)
}

cat("\n=== DONE ===\n")
cat("Total graphs generated:", nrow(butterfly_df), "\n")
cat("  Butterfly:", sum(butterfly_df$is_butterfly), "\n")
cat("  Independent:", sum(!butterfly_df$is_butterfly), "\n")
cat("Output directory:", output_dir, "\n")
