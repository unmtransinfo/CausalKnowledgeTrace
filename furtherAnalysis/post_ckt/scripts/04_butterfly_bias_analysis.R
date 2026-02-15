#!/usr/bin/env Rscript

# =============================================================================
# Script: 10_butterfly_bias_analysis.R
# Purpose: Detect butterfly bias in confounder relationships
#
# Approach (developed with Dr. Scott):
#   1. Convert igraph → dagitty
#   2. Use dagitty::parents() / dagitty::children() to find confounders
#      (these structural functions work even with cycles)
#   3. For each confounder, check if it has 2+ confounder parents
#      → butterfly candidate
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
  library(dagitty)
})

# ---- Argument handling ----
args <- commandArgs(trailingOnly = TRUE)

if (length(args) < 3) {
  cat("Usage: Rscript 10_butterfly_bias_analysis.R <Exposure> <Outcome> <Degree>\n")
  cat("Example: Rscript 10_butterfly_bias_analysis.R Hypertension Alzheimers 3\n")
  quit(status = 1)
}

EXPOSURE <- args[1]
OUTCOME <- args[2]
DEGREE <- as.integer(args[3])

# ---- Set paths ----
BASE_DIR <- getwd()
DATA_DIR <- file.path(BASE_DIR, "data", paste0(EXPOSURE, "_", OUTCOME), paste0("degree", DEGREE))
GRAPH_FILE <- file.path(DATA_DIR, "s3_confounders", "graph_cycle_broken.rds")
if (!file.exists(GRAPH_FILE)) {
  GRAPH_FILE <- file.path(DATA_DIR, "s1_graph", "pruned_graph.rds")
  cat("Note: Using original pruned graph (no cycle-broken graph found)\n")
}
CONFOUNDERS_FILE <- file.path(DATA_DIR, "s3_confounders", "valid_confounders.csv")
OUTPUT_DIR <- file.path(DATA_DIR, "s4_butterfly_bias")

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
# Helper Functions
# =============================================================================

#' Sanitize node names for dagitty compatibility
#'
#' @param node_names Character vector of original node names
#' @return List with: forward (original→safe), reverse (safe→original)
sanitize_node_names <- function(node_names) {
  safe <- gsub("[^A-Za-z0-9_]", "_", node_names)
  safe <- gsub("_+", "_", safe)
  safe <- gsub("^_|_$", "", safe)
  safe <- ifelse(grepl("^[0-9]", safe), paste0("n", safe), safe)
  
  # Handle duplicates
  if (any(duplicated(safe))) {
    for (d in unique(safe[duplicated(safe)])) {
      idx <- which(safe == d)
      safe[idx] <- paste0(safe[idx], "_", seq_along(idx))
    }
  }
  
  list(
    forward = setNames(safe, node_names),
    reverse = setNames(node_names, safe)
  )
}

#' Convert igraph to dagitty object
#'
#' @param graph igraph object
#' @param exposure Original exposure name
#' @param outcome Original outcome name
#' @return List with: dag (dagitty object), name_map, dag_string
igraph_to_dagitty <- function(graph, exposure, outcome) {
  cat("Converting igraph to dagitty format...\n")
  
  # Validate exposure/outcome exist
  if (!(exposure %in% V(graph)$name)) stop("Exposure '", exposure, "' not in graph")
  if (!(outcome %in% V(graph)$name)) stop("Outcome '", outcome, "' not in graph")
  
  # Get edges using igraph:: prefix to avoid tibble collision
  edges_df <- igraph::as_data_frame(graph, what = "edges")
  
  # Sanitize names
  all_nodes <- V(graph)$name
  name_map <- sanitize_node_names(all_nodes)
  
  safe_exp <- name_map$forward[exposure]
  safe_out <- name_map$forward[outcome]
  
  # Build dagitty string
  dag_string <- "dag {\n"
  dag_string <- paste0(dag_string, "  ", safe_exp, " [exposure]\n")
  dag_string <- paste0(dag_string, "  ", safe_out, " [outcome]\n\n")
  
  for (i in 1:nrow(edges_df)) {
    safe_from <- name_map$forward[edges_df$from[i]]
    safe_to <- name_map$forward[edges_df$to[i]]
    dag_string <- paste0(dag_string, "  ", safe_from, " -> ", safe_to, "\n")
  }
  dag_string <- paste0(dag_string, "}")
  
  dag <- dagitty(dag_string)
  cat("dagitty object created:", length(names(dag)), "nodes,", nrow(edges_df), "edges\n")
  cat("Is acyclic:", isAcyclic(dag), "\n")
  
  list(dag = dag, name_map = name_map, dag_string = dag_string)
}

#' Map safe names back to originals
unsanitize <- function(safe_names, name_map) {
  result <- name_map$reverse[safe_names]
  result[is.na(result)] <- safe_names[is.na(result)]
  unname(result)
}

# =============================================================================
# Main Analysis
# =============================================================================

print_header("Butterfly Bias Analysis", EXPOSURE, OUTCOME)
cat("Graph degree:", DEGREE, "\n\n")

# ---- 1. Load Data ----
cat("=== 1. LOADING DATA ===\n")
graph <- readRDS(GRAPH_FILE)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n")

confounders_df <- read.csv(CONFOUNDERS_FILE, stringsAsFactors = FALSE)
if ("is_valid_confounder" %in% colnames(confounders_df)) {
  confounders_df <- confounders_df[confounders_df$is_valid_confounder == TRUE, ]
}
confounders_orig <- confounders_df$node
cat("Confounders loaded:", length(confounders_orig), "\n\n")

# ---- 2. Convert igraph → dagitty ----
cat("=== 2. CONVERTING TO DAGITTY ===\n")
conversion <- igraph_to_dagitty(graph, EXPOSURE, OUTCOME)
dag <- conversion$dag
name_map <- conversion$name_map

# Save DAG definition for inspection
dag_file <- file.path(OUTPUT_DIR, "dag_definition.txt")
writeLines(conversion$dag_string, dag_file)
cat("DAG definition saved to:", dag_file, "\n")

# Save name mapping (only changed names)
name_map_df <- data.frame(
  original = names(name_map$forward),
  safe = unname(name_map$forward),
  stringsAsFactors = FALSE
)
changed <- name_map_df[name_map_df$original != name_map_df$safe, ]
if (nrow(changed) > 0) {
  write.csv(changed, file.path(OUTPUT_DIR, "name_mapping.csv"), row.names = FALSE)
  cat("Name mapping saved (", nrow(changed), " names sanitized)\n")
}
cat("\n")

# ---- 3. Find confounders using dagitty (Professor's approach) ----
cat("=== 3. CONFOUNDER IDENTIFICATION (dagitty) ===\n")
cat("Using dagitty::parents() and dagitty::children()\n")
cat("(These functions work even with cycles)\n\n")

safe_exp <- name_map$forward[EXPOSURE]
safe_out <- name_map$forward[OUTCOME]

exposure_parents <- dagitty::parents(dag, dagitty::exposures(dag))
outcome_parents <- dagitty::parents(dag, dagitty::outcomes(dag))
exposure_children <- dagitty::children(dag, dagitty::exposures(dag))
outcome_children <- dagitty::children(dag, dagitty::outcomes(dag))

cat("Parents of exposure:", length(exposure_parents), "\n")
cat("Parents of outcome:", length(outcome_parents), "\n")
cat("Children of exposure:", length(exposure_children), "\n")
cat("Children of outcome:", length(outcome_children), "\n")

# Confounders = common parents - children (same as professor's code)
dagitty_confounders_safe <- setdiff(
  setdiff(
    intersect(exposure_parents, outcome_parents),
    exposure_children
  ),
  outcome_children
)

dagitty_confounders <- unsanitize(dagitty_confounders_safe, name_map)
cat("\nConfounders identified by dagitty:", length(dagitty_confounders), "\n")
cat("Confounders from our pipeline:", length(confounders_orig), "\n")

# Compare with our confounder list
in_both <- intersect(confounders_orig, dagitty_confounders)
only_ours <- setdiff(confounders_orig, dagitty_confounders)
only_dagitty <- setdiff(dagitty_confounders, confounders_orig)

cat("\nOverlap:", length(in_both), "\n")
if (length(only_ours) > 0) {
  cat("In our list but NOT dagitty:", paste(only_ours, collapse = ", "), "\n")
}
if (length(only_dagitty) > 0) {
  cat("In dagitty but NOT our list:", paste(only_dagitty, collapse = ", "), "\n")
}
cat("\n")

# ---- 4. Butterfly Detection (Professor's approach) ----
cat("=== 4. BUTTERFLY BIAS DETECTION ===\n")
cat("Checking each confounder's parents among other confounders...\n\n")

butterfly_results <- data.frame(
  confounder = character(),
  n_confounder_parents = integer(),
  confounder_parents = character(),
  is_butterfly = logical(),
  stringsAsFactors = FALSE
)

for (conf_safe in dagitty_confounders_safe) {
  conf_orig <- unsanitize(conf_safe, name_map)
  
  # Get parents of this confounder (dagitty)
  conf_parents_safe <- dagitty::parents(dag, conf_safe)
  
  # Which parents are also confounders?
  confounder_parents_safe <- intersect(conf_parents_safe, dagitty_confounders_safe)
  confounder_parents_orig <- unsanitize(confounder_parents_safe, name_map)
  
  is_butterfly <- length(confounder_parents_safe) >= 2
  
  butterfly_results <- rbind(butterfly_results, data.frame(
    confounder = conf_orig,
    n_confounder_parents = length(confounder_parents_safe),
    confounder_parents = paste(confounder_parents_orig, collapse = ", "),
    is_butterfly = is_butterfly,
    stringsAsFactors = FALSE
  ))
  
  # Print results (matching professor's output style)
  if (length(confounder_parents_safe) == 0) {
    cat("  ", conf_orig, ": character(0)\n")
  } else {
    marker <- if (is_butterfly) " *** BUTTERFLY ***" else ""
    cat("  ", conf_orig, ": [", paste(confounder_parents_orig, collapse = ", "), 
        "]", marker, "\n")
  }
}

# ---- 5. Summarize Results ----
cat("\n=== 5. RESULTS SUMMARY ===\n")

butterflies <- butterfly_results[butterfly_results$is_butterfly, ]
independent <- butterfly_results[butterfly_results$n_confounder_parents == 0, ]
has_one_parent <- butterfly_results[butterfly_results$n_confounder_parents == 1, ]

cat("\nTotal confounders (dagitty):", nrow(butterfly_results), "\n")
cat("Independent (no confounder parents):", nrow(independent), "\n")
cat("Has 1 confounder parent:", nrow(has_one_parent), "\n")
cat("BUTTERFLY candidates (2+ confounder parents):", nrow(butterflies), "\n")

if (nrow(butterflies) > 0) {
  cat("\nButterfly nodes:\n")
  for (i in 1:nrow(butterflies)) {
    cat("  ", i, ". ", butterflies$confounder[i], 
        " <- {", butterflies$confounder_parents[i], 
        "} (", butterflies$n_confounder_parents[i], " parents)\n", sep = "")
  }
}

# ---- 6. Save Results ----
cat("\n=== 6. SAVING RESULTS ===\n")

# Full results table
results_file <- file.path(OUTPUT_DIR, "butterfly_analysis_results.csv")
write.csv(butterfly_results, results_file, row.names = FALSE)
cat("Full results saved to:", results_file, "\n")

# Butterfly nodes only
butterfly_file <- file.path(OUTPUT_DIR, "butterfly_nodes.csv")
write.csv(butterflies, butterfly_file, row.names = FALSE)
cat("Butterfly nodes saved to:", butterfly_file, "\n")

# Independent confounders
independent_file <- file.path(OUTPUT_DIR, "independent_confounders.csv")
write.csv(independent, independent_file, row.names = FALSE)
cat("Independent confounders saved to:", independent_file, "\n")

# Confounder comparison
comparison_df <- data.frame(
  confounder = union(confounders_orig, dagitty_confounders),
  stringsAsFactors = FALSE
)
comparison_df$in_pipeline <- comparison_df$confounder %in% confounders_orig
comparison_df$in_dagitty <- comparison_df$confounder %in% dagitty_confounders
comparison_file <- file.path(OUTPUT_DIR, "confounder_comparison.csv")
write.csv(comparison_df, comparison_file, row.names = FALSE)
cat("Confounder comparison saved to:", comparison_file, "\n")

# ---- 7. Summary Report ----
cat("\n=== 7. WRITING SUMMARY REPORT ===\n")

summary_file <- file.path(OUTPUT_DIR, "analysis_summary.txt")
sink(summary_file)

cat("=======================================================\n")
cat("Butterfly Bias Analysis Summary\n")
cat("=======================================================\n\n")
cat("Exposure:", EXPOSURE, "\n")
cat("Outcome:", OUTCOME, "\n")
cat("Graph Degree:", DEGREE, "\n")
cat("Graph is Acyclic:", isAcyclic(dag), "\n")
cat("Timestamp:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("=== Method ===\n")
cat("Approach: dagitty structural functions (parents/children)\n")
cat("These functions work even with cyclic graphs.\n")
cat("Butterfly = confounder with 2+ other confounders as parents.\n\n")

cat("=== Graph Statistics ===\n")
cat("Total nodes:", vcount(graph), "\n")
cat("Total edges:", ecount(graph), "\n")
cat("Parents of exposure:", length(exposure_parents), "\n")
cat("Parents of outcome:", length(outcome_parents), "\n\n")

cat("=== Confounder Counts ===\n")
cat("Pipeline confounders:", length(confounders_orig), "\n")
cat("dagitty confounders:", length(dagitty_confounders), "\n")
cat("Overlap:", length(in_both), "\n")
if (length(only_ours) > 0) {
  cat("In pipeline only:", paste(only_ours, collapse = ", "), "\n")
}
if (length(only_dagitty) > 0) {
  cat("In dagitty only:", paste(only_dagitty, collapse = ", "), "\n")
}
cat("\n")

cat("=== Butterfly Bias Results ===\n")
cat("Independent confounders:", nrow(independent), "\n")
cat("Confounders with 1 parent:", nrow(has_one_parent), "\n")
cat("BUTTERFLY candidates:", nrow(butterflies), "\n\n")

if (nrow(butterflies) > 0) {
  cat("Butterfly nodes (DO NOT adjust for these directly):\n")
  for (i in 1:nrow(butterflies)) {
    cat("  ", i, ". ", butterflies$confounder[i],
        " <- {", butterflies$confounder_parents[i], "}\n", sep = "")
  }
  cat("\nRECOMMENDATION: Instead of adjusting for butterfly nodes,\n")
  cat("adjust for their confounder parents to avoid opening\n")
  cat("collider paths.\n")
} else {
  cat("No butterfly bias detected.\n")
  cat("All confounders are independent and safe to adjust for.\n")
}

cat("\n=== All Confounders by Type ===\n")
if (nrow(independent) > 0) {
  cat("\nINDEPENDENT (safe to adjust for):\n")
  for (c in sort(independent$confounder)) cat("  -", c, "\n")
}
if (nrow(has_one_parent) > 0) {
  cat("\nHAS 1 CONFOUNDER PARENT (monitor but likely safe):\n")
  for (i in 1:nrow(has_one_parent)) {
    cat("  -", has_one_parent$confounder[i], 
        "<-", has_one_parent$confounder_parents[i], "\n")
  }
}
if (nrow(butterflies) > 0) {
  cat("\nBUTTERFLY (avoid adjusting directly):\n")
  for (i in 1:nrow(butterflies)) {
    cat("  -", butterflies$confounder[i], 
        "<- {", butterflies$confounder_parents[i], "}\n")
  }
}

sink()
cat("Summary report saved to:", summary_file, "\n")

# ---- Done ----
cat("\n=======================================================\n")
cat("Butterfly Bias Analysis Complete!\n")
cat("=======================================================\n\n")

cat("Key Files:\n")
cat("  - Full results:", results_file, "\n")
cat("  - Butterfly nodes:", butterfly_file, "\n")
cat("  - Independent confounders:", independent_file, "\n")
cat("  - Confounder comparison:", comparison_file, "\n")
cat("  - Summary report:", summary_file, "\n")
