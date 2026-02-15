#!/usr/bin/env Rscript

# =============================================================================
# Script: 09_confounder_relationships.R
# Purpose: Extract 2nd and 3rd degree relationships between confounders
#          to identify which confounders are parents/grandparents of others
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
if (file.exists(file.path(script_dir, "config.R"))) {
  source(file.path(script_dir, "config.R"))
  source(file.path(script_dir, "utils.R"))
} else {
  source("scripts/config.R")
  source("scripts/utils.R")
}

# ---- Load required libraries ----
suppressPackageStartupMessages({
  library(igraph)
  library(dplyr)
})

# ---- Argument handling ----
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  cat("Usage: Rscript 09_confounder_relationships.R <Exposure> <Outcome> <Degree> [Relationship_Degree]\n")
  cat("Example: Rscript 09_confounder_relationships.R Hypertension Alzheimers 3 2\n")
  cat("\n")
  cat("Arguments:\n")
  cat("  Exposure: Name of exposure variable (e.g., Hypertension)\n")
  cat("  Outcome: Name of outcome variable (e.g., Alzheimers)\n")
  cat("  Degree: Graph degree (e.g., 3)\n")
  cat("  Relationship_Degree: 2 for 2nd degree, 3 for 3rd degree (default: 2)\n")
  quit(status = 1)
}

EXPOSURE <- args[1]
OUTCOME <- args[2]
DEGREE <- as.integer(args[3])
REL_DEGREE <- if (length(args) >= 4) as.integer(args[4]) else 2

# ---- Set paths ----
BASE_DIR <- getwd()
DATA_DIR <- file.path(BASE_DIR, "data", paste0(EXPOSURE, "_", OUTCOME), paste0("degree", DEGREE))
GRAPH_FILE <- file.path(DATA_DIR, "s3_confounders", "graph_cycle_broken.rds")
if (!file.exists(GRAPH_FILE)) {
  GRAPH_FILE <- file.path(DATA_DIR, "s1_graph", "pruned_graph.rds")
  cat("Note: Using original pruned graph (no cycle-broken graph found)\n")
}
CONFOUNDERS_FILE <- file.path(DATA_DIR, "s3_confounders", "valid_confounders.csv")
OUTPUT_DIR <- file.path(DATA_DIR, "s3c_relationships")

# Create output directory
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# ---- Validate inputs ----
if (!file.exists(GRAPH_FILE)) {
  stop("Graph file not found: ", GRAPH_FILE)
}

if (!file.exists(CONFOUNDERS_FILE)) {
  stop("Confounders file not found: ", CONFOUNDERS_FILE)
}

# =============================================================================
# Main Analysis
# =============================================================================

print_header(paste0("Confounder Relationship Analysis - ", REL_DEGREE, "nd/rd Degree"),
             EXPOSURE, OUTCOME)

cat("Graph degree:", DEGREE, "\n")
cat("Relationship degree:", REL_DEGREE, "\n\n")

# ---- 1. Load Data ----
cat("=== 1. LOADING DATA ===\n")
graph <- readRDS(GRAPH_FILE)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n")

confounders_df <- read.csv(CONFOUNDERS_FILE, stringsAsFactors = FALSE)
# Filter to valid confounders only (in case file includes excluded ones)
if ("is_valid_confounder" %in% colnames(confounders_df)) {
  confounders_df <- confounders_df[confounders_df$is_valid_confounder == TRUE, ]
}
confounders <- confounders_df$node
cat("Confounders loaded:", length(confounders), "\n\n")

# ---- 2. Extract 2nd Degree Relationships ----
# NOTE on terminology: "2nd degree" here means relationships BETWEEN confounders
# (i.e., confounders that are 2 hops from exposure/outcome via another confounder).
# In pure graph terms, these are distance-1 edges among confounders.
cat("=== 2. EXTRACTING 2ND DEGREE RELATIONSHIPS ===\n")
cat("Finding direct parent-child relationships among confounders...\n\n")

relationships_2nd <- data.frame(
  parent = character(),
  child = character(),
  path_length = integer(),
  relationship_type = character(),
  stringsAsFactors = FALSE
)

for (C in confounders) {
  # Check if node exists in graph
  if (!(C %in% V(graph)$name)) {
    cat("  Warning: Confounder", C, "not found in graph\n")
    next
  }
  
  # Get parents (incoming neighbors) - using robust vertex name extraction
  parents <- V(graph)[neighbors(graph, C, mode = "in")]$name
  
  # Find which parents are also confounders
  conf_parents <- intersect(parents, confounders)
  
  if (length(conf_parents) > 0) {
    for (P in conf_parents) {
      relationships_2nd <- rbind(relationships_2nd, data.frame(
        parent = P,
        child = C,
        path_length = 1,
        relationship_type = "direct",
        stringsAsFactors = FALSE
      ))
    }
  }
}

cat("Found", nrow(relationships_2nd), "2nd degree relationships\n")

# ---- 3. Extract 3rd Degree Relationships (if requested) ----
relationships_3rd <- data.frame(
  parent = character(),
  child = character(),
  path_length = integer(),
  relationship_type = character(),
  intermediary = character(),
  stringsAsFactors = FALSE
)

if (REL_DEGREE >= 3) {
  cat("\n=== 3. EXTRACTING 3RD DEGREE RELATIONSHIPS ===\n")
  # NOTE: Intermediary nodes do NOT have to be confounders themselves.
  # This is intentional - we want to find confounder -> (any node) -> confounder
  # paths, which reveal indirect influence between confounders.
  cat("Finding grandparent relationships through intermediaries...\n")
  cat("(intermediary nodes may or may not be confounders)\n\n")
  
  for (C in confounders) {
    if (!(C %in% V(graph)$name)) next
    
    # Get all parents (not just confounders)
    parents <- V(graph)[neighbors(graph, C, mode = "in")]$name
    
    for (P in parents) {
      # Get grandparents through this parent
      if (P %in% V(graph)$name) {
        grandparents <- V(graph)[neighbors(graph, P, mode = "in")]$name
        conf_grandparents <- intersect(grandparents, confounders)
        
        for (GP in conf_grandparents) {
          # Avoid duplicates with 2nd degree (direct edges)
          is_direct <- any(relationships_2nd$parent == GP & relationships_2nd$child == C)
          # Avoid self-loops
          is_self <- (GP == C)
          
          if (!is_direct && !is_self) {
            relationships_3rd <- rbind(relationships_3rd, data.frame(
              parent = GP,
              child = C,
              path_length = 2,
              relationship_type = "indirect",
              intermediary = P,
              stringsAsFactors = FALSE
            ))
          }
        }
      }
    }
  }
  
  cat("Found", nrow(relationships_3rd), "3rd degree relationships\n")
}

# ---- 4. Summarize Results ----
cat("\n=== 4. SUMMARY ===\n")

if (nrow(relationships_2nd) > 0) {
  # Count how many confounders have confounder parents
  confounders_with_parents <- unique(relationships_2nd$child)
  cat("\nConfounders with confounder parents (2nd degree):", length(confounders_with_parents), "/", length(confounders), "\n")
  
  # Count how many confounders are parents of other confounders
  confounders_as_parents <- unique(relationships_2nd$parent)
  cat("Confounders that are parents of other confounders:", length(confounders_as_parents), "\n")
  
  # Find confounders with multiple parents (butterfly candidates)
  parent_counts <- relationships_2nd %>%
    group_by(child) %>%
    summarise(n_parents = n(), .groups = "drop") %>%
    filter(n_parents >= 2) %>%
    arrange(desc(n_parents))
  
  if (nrow(parent_counts) > 0) {
    cat("\nButterfly candidates (confounders with 2+ confounder parents):", nrow(parent_counts), "\n")
    for (i in 1:min(5, nrow(parent_counts))) {
      child <- parent_counts$child[i]
      n_parents <- parent_counts$n_parents[i]
      parents_list <- relationships_2nd %>%
        filter(child == !!child) %>%
        pull(parent) %>%
        paste(collapse = ", ")
      cat("  -", child, "has", n_parents, "parents:", parents_list, "\n")
    }
    if (nrow(parent_counts) > 5) {
      cat("  ... and", nrow(parent_counts) - 5, "more\n")
    }
  } else {
    cat("\nNo butterfly candidates found\n")
  }
}

# ---- 5. Save Results ----
cat("\n=== 5. SAVING RESULTS ===\n")

# Save 2nd degree relationships
output_file_2nd <- file.path(OUTPUT_DIR, "confounder_relationships_2nd.csv")
write.csv(relationships_2nd, output_file_2nd, row.names = FALSE)
cat("2nd degree relationships saved to:", output_file_2nd, "\n")

# Save 3rd degree relationships
if (REL_DEGREE >= 3) {
  output_file_3rd <- file.path(OUTPUT_DIR, "confounder_relationships_3rd.csv")
  write.csv(relationships_3rd, output_file_3rd, row.names = FALSE)
  cat("3rd degree relationships saved to:", output_file_3rd, "\n")
}

# Create summary file
summary_file <- file.path(OUTPUT_DIR, "relationship_summary.txt")
sink(summary_file)

cat("=======================================================\n")
cat("Confounder Relationship Analysis Summary\n")
cat("=======================================================\n\n")
cat("Exposure:", EXPOSURE, "\n")
cat("Outcome:", OUTCOME, "\n")
cat("Graph Degree:", DEGREE, "\n")
cat("Relationship Degree:", REL_DEGREE, "\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("=== Data ===\n")
cat("Total nodes in graph:", vcount(graph), "\n")
cat("Total edges in graph:", ecount(graph), "\n")
cat("Total confounders:", length(confounders), "\n\n")

cat("=== 2nd Degree Relationships ===\n")
cat("Total relationships:", nrow(relationships_2nd), "\n")
if (nrow(relationships_2nd) > 0) {
  cat("Confounders with parents:", length(confounders_with_parents), "\n")
  cat("Confounders as parents:", length(confounders_as_parents), "\n\n")
  
  cat("Top parent-child relationships:\n")
  parent_child_counts <- relationships_2nd %>%
    group_by(parent) %>%
    summarise(n_children = n(), .groups = "drop") %>%
    arrange(desc(n_children)) %>%
    head(10)
  
  for (i in 1:nrow(parent_child_counts)) {
    parent <- parent_child_counts$parent[i]
    n_children <- parent_child_counts$n_children[i]
    children_list <- relationships_2nd %>%
      filter(parent == !!parent) %>%
      pull(child) %>%
      paste(collapse = ", ")
    cat("  ", parent, "->", n_children, "children:", children_list, "\n")
  }
  
  if (nrow(parent_counts) > 0) {
    cat("\nButterfly candidates:\n")
    for (i in 1:nrow(parent_counts)) {
      child <- parent_counts$child[i]
      n_parents <- parent_counts$n_parents[i]
      parents_list <- relationships_2nd %>%
        filter(child == !!child) %>%
        pull(parent) %>%
        paste(collapse = ", ")
      cat("  ", child, "<-", n_parents, "parents:", parents_list, "\n")
    }
  }
}

if (REL_DEGREE >= 3) {
  cat("\n=== 3rd Degree Relationships ===\n")
  cat("Total relationships:", nrow(relationships_3rd), "\n")
  if (nrow(relationships_3rd) > 0) {
    cat("Sample 3rd degree paths:\n")
    sample_3rd <- head(relationships_3rd, 10)
    for (i in 1:nrow(sample_3rd)) {
      cat("  ", sample_3rd$parent[i], "->", sample_3rd$intermediary[i], "->", sample_3rd$child[i], "\n")
    }
  }
}

sink()
cat("Summary saved to:", summary_file, "\n")

# Create confounder-only subgraph (include nodes from both 2nd and 3rd degree)
all_relationship_nodes <- unique(c(relationships_2nd$parent, relationships_2nd$child))

if (REL_DEGREE >= 3 && nrow(relationships_3rd) > 0) {
  all_relationship_nodes <- unique(c(
    all_relationship_nodes,
    relationships_3rd$parent,
    relationships_3rd$child,
    relationships_3rd$intermediary
  ))
}

if (length(all_relationship_nodes) > 0) {
  # Filter to nodes that exist in graph
  valid_nodes <- intersect(all_relationship_nodes, V(graph)$name)
  subgraph <- induced_subgraph(graph, valid_nodes)
  subgraph_file <- file.path(OUTPUT_DIR, "relationship_network.rds")
  saveRDS(subgraph, subgraph_file)
  cat("Confounder subgraph saved to:", subgraph_file, "\n")
  cat("  Nodes in subgraph:", vcount(subgraph), "\n")
  cat("  Edges in subgraph:", ecount(subgraph), "\n")
}

cat("\n=======================================================\n")
cat("Analysis Complete!\n")
cat("=======================================================\n")
cat("\nNext step: Run butterfly bias analysis (10_butterfly_bias_analysis.R)\n")
