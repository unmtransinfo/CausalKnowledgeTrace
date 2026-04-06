#!/usr/bin/env Rscript

# =============================================================================
# Script: 03c_extract_confounder_evidence.R (Optimized & Extended)
# Purpose: Extract evidence (PMIDs and sentences) from CKT JSON/HTML provenance files
#          and match with edges for ALL identified confounders (valid + invalid).
#          Uses data.table for high performance handling of large datasets.
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
  library(data.table)
  library(jsonlite)
  library(stringr)
  library(rvest) # Kept for HTML fallback
  library(igraph) # Needed for subgraph extraction
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
INPUT_DIR <- file.path(dirname(script_dir), "input")  # post_ckt/input
DATA_DIR <- get_pair_dir(EXPOSURE, OUTCOME, DEGREE)
CONFOUNDERS_DIR <- file.path(DATA_DIR, "s3_confounders", "reports")
CLASSIFICATION_FILE <- file.path(DATA_DIR, "s3_confounders", "confounder_classification.csv")
GRAPH_FILE <- get_pruned_graph_path(EXPOSURE, OUTCOME, DEGREE)
OUTPUT_DIR <- file.path(DATA_DIR, "s3b_evidence")

# ---- Validate and create directories ----
ensure_dir(OUTPUT_DIR)

# Find the provenance file (JSON or HTML)
# First look for JSON files
json_pattern <- paste0(EXPOSURE, "_", OUTCOME, ".*", DEGREE, ".*\\.json$")
json_files <- list.files(INPUT_DIR, pattern = json_pattern, ignore.case = TRUE, full.names = TRUE)

if (length(json_files) == 0) {
  # Try alternative JSON pattern
  json_pattern2 <- paste0(EXPOSURE, ".*", OUTCOME, ".*\\.json$")
  json_files <- list.files(INPUT_DIR, pattern = json_pattern2, ignore.case = TRUE, full.names = TRUE)
}

# Then look for HTML files
html_pattern <- paste0(EXPOSURE, "_", OUTCOME, ".*degree.*", DEGREE, ".*\\.html$")
html_files <- list.files(INPUT_DIR, pattern = html_pattern, ignore.case = TRUE, full.names = TRUE)

if (length(html_files) == 0) {
  # Try alternative HTML pattern
  html_pattern2 <- paste0(EXPOSURE, ".*", OUTCOME, ".*\\.html$")
  html_files <- list.files(INPUT_DIR, pattern = html_pattern2, ignore.case = TRUE, full.names = TRUE)
}

# Determine which format to use
if (length(json_files) > 0) {
  PROV_FILE <- json_files[1]
  PROV_FORMAT <- "JSON"
  cat("Using JSON file:", PROV_FILE, "\n")
} else if (length(html_files) > 0) {
  PROV_FILE <- html_files[1]
  PROV_FORMAT <- "HTML"
  cat("Using HTML file:", PROV_FILE, "\n")
} else {
  stop("No JSON or HTML provenance file found for ", EXPOSURE, "-", OUTCOME, " degree ", DEGREE)
}

# Helper for memory monitoring
print_mem <- function() {
  cat("Memory usage:", paste0(round(sum(gc()[, 2]) / 1024, 2), " MB"), "\n")
}

# =============================================================================
# Subgraph Extraction Logic (from 03_confounder_analysis.R)
# =============================================================================

extract_confounder_subgraph <- function(g, confounder_name, exposure, outcome) {
  nodes <- c(confounder_name, exposure, outcome)
  
  # Add cycle paths if they exist
  tryCatch({
    path_A <- shortest_paths(g, from = exposure, to = confounder_name, mode = "out")$vpath[[1]]
    if (length(path_A) > 0) nodes <- c(nodes, names(path_A))
  }, error = function(e) {})
  
  tryCatch({
    path_Y <- shortest_paths(g, from = outcome, to = confounder_name, mode = "out")$vpath[[1]]
    if (length(path_Y) > 0) nodes <- c(nodes, names(path_Y))
  }, error = function(e) {})
  
  return(induced_subgraph(g, unique(nodes)))
}

# =============================================================================
# Optimized Parser Functions
# =============================================================================

normalize_name_dt <- function(dt, col_name, new_col_name) {
  # Vectorized string normalization using stringr and fast assignment
  dt[, (new_col_name) := str_to_lower(str_trim(str_replace_all(str_replace_all(get(col_name), "_", " "), "\\s+", " ")))]
}

parse_json_assertions_optimized <- function(json_file) {
  cat("Parsing causal assertions from JSON (Optimized)...\n")
  print_mem()
  
  # Read JSON - creating a list
  json_data <- fromJSON(json_file, simplifyVector = FALSE)
  print_mem()
  
  # 1. Process Assertions
  cat("Converting assertions to data.table...\n")
  assertions_dt <- rbindlist(json_data$assertions, fill = TRUE)
  
  # Keep only relevant columns and rename
  if (!all(c("subj", "obj", "subj_cui", "obj_cui", "pmid_refs") %in% names(assertions_dt))) {
     # Handle case where fields might be missing or named differently
     # But assuming standard CKT format
  }
  
  cols_to_keep <- c("subj", "subj_cui", "obj", "obj_cui", "pmid_refs")
  assertions_dt <- assertions_dt[, ..cols_to_keep] 
  setnames(assertions_dt, old = c("subj", "subj_cui", "obj", "obj_cui"), 
           new = c("subject", "subject_cui", "object", "object_cui"))
  
  # Unnest PMIDs (this expands rows)
  cat("Unnesting PMIDs...\n")
  assertions_expanded <- assertions_dt[, .(pmid = unlist(pmid_refs)), by = .(subject, subject_cui, object, object_cui)]
  
  # Free memory
  rm(assertions_dt)
  gc()
  
  # 2. Process Sentences
  cat("Processing sentences...\n")
  pmid_list <- json_data$pmid_sentences
  
  sentences_dt <- data.table(
    pmid = rep(names(pmid_list), times = lengths(pmid_list)),
    sentence = unlist(pmid_list, use.names = FALSE)
  )
  
  # Clear original large JSON object
  rm(json_data, pmid_list)
  gc()
  print_mem()
  
  # 3. Join Assertions with Sentences
  cat("Joining assertions with sentences...\n")
  
  # Ensure Keys match type
  assertions_expanded[, pmid := as.character(pmid)]
  sentences_dt[, pmid := as.character(pmid)]
  
  # Inner join
  full_evidence <- merge(assertions_expanded, sentences_dt, by = "pmid", all.x = FALSE, all.y = FALSE)
  
  # Add URL
  full_evidence[, pmid_url := paste0("https://pubmed.ncbi.nlm.nih.gov/", pmid)]
  
  print_mem()
  cat("Extracted", nrow(full_evidence), "evidence records\n")
  
  return(full_evidence)
}

parse_causal_assertions_html_optimized <- function(html_file) {
  cat("Parsing causal assertions from HTML (Fallback to iterative parser)...\n")
  
  html <- read_html(html_file)
  assertions <- html %>% html_elements(".streamlined-assertion")
  
  cat("Found", length(assertions), "causal assertion blocks\n")
  
  n <- length(assertions)
  results_list <- vector("list", n)
  
  for (i in seq_along(assertions)) {
    if (i %% 500 == 0) cat(".")
    
    assertion <- assertions[[i]]
    header <- assertion %>% html_element(".streamlined-header")
    
    strong_elements <- header %>% html_elements("strong")
    if (length(strong_elements) < 4) next
    
    subject <- html_text(strong_elements[[1]], trim = TRUE)
    subject_cui <- html_text(strong_elements[[2]], trim = TRUE)
    object <- html_text(strong_elements[[3]], trim = TRUE)
    object_cui <- html_text(strong_elements[[4]], trim = TRUE)
    
    pmid_lines <- assertion %>% html_elements(".pmid-sentence-line")
    
    if (length(pmid_lines) > 0) {
      pmid_links <- html_elements(pmid_lines, ".pmid-link")
      pmids <- html_text(pmid_links, trim = TRUE)
      pmid_urls <- html_attr(pmid_links, "href")
      sentences <- html_text(html_elements(pmid_lines, ".sentence-part"), trim = TRUE)
      
      results_list[[i]] <- data.table(
        subject = subject,
        subject_cui = subject_cui,
        object = object,
        object_cui = object_cui,
        pmid = pmids,
        pmid_url = pmid_urls,
        sentence = sentences
      )
    }
  }
  cat("\n")
  
  full_evidence <- rbindlist(results_list)
  return(full_evidence)
}


# =============================================================================
# Main Processing Logic (Extended Batch)
# =============================================================================

process_all_confounders <- function(evidence_dt, confounders_dir, classification_file, graph_file, output_dir) {
  
  # 1. Identify ALL confounders from classification file
  if (!file.exists(classification_file)) {
    stop("Classification file not found: ", classification_file)
  }
  
  class_df <- fread(classification_file)
  all_confounders <- class_df$node
  cat("Identified", length(all_confounders), "total confounders from classification file.\n")
  
  # 2. Gather Edges for ALL confounders
  # Strategy: 
  # - If edges.csv exists in reports, use it.
  # - If not, load graph and generate it.
  
  all_edges_list <- list()
  nodes_needing_generation <- c()
  
  cat("Checking for existing edge reports...\n")
  for (node in all_confounders) {
    # Sanitize node name for directory match
    safe_node <- gsub("[^a-zA-Z0-9_]", "_", node)
    edge_file <- file.path(confounders_dir, safe_node, "edges.csv")
    
    if (file.exists(edge_file)) {
      dt <- fread(edge_file)
      dt[, confounder := node] # Use original node name
      all_edges_list[[node]] <- dt
    } else {
      nodes_needing_generation <- c(nodes_needing_generation, node)
    }
  }
  
  cat("Found existing reports for", length(all_edges_list), "confounders.\n")
  
  # 3. Generate missing edges
  if (length(nodes_needing_generation) > 0) {
    cat("Generating edges for", length(nodes_needing_generation), "confounders (no existing report)...\n")
    
    # Load graph only if needed
    if (!file.exists(graph_file)) {
      stop("Graph file needed for edge generation but not found: ", graph_file)
    }
    g <- readRDS(graph_file)
    
    for (node in nodes_needing_generation) {
      # Extract subgraph
      # Note: This reproduces logic from 03_confounder_analysis.R without saving the plots
      sub <- extract_confounder_subgraph(g, node, EXPOSURE, OUTCOME)
      
      # Convert to edges
      edges_df <- igraph::as_data_frame(sub, what = "edges")
      dt <- as.data.table(edges_df)
      dt[, confounder := node]
      
      all_edges_list[[node]] <- dt
    }
  }
  
  # Combine all edges
  all_edges_dt <- rbindlist(all_edges_list, fill = TRUE)
  cat("Total edges to check (all confounders):", nrow(all_edges_dt), "\n")
  
  # 4. Normalize Names and Join
  cat("Normalizing names for matching...\n")
  normalize_name_dt(evidence_dt, "subject", "subject_norm")
  normalize_name_dt(evidence_dt, "object", "object_norm")
  
  normalize_name_dt(all_edges_dt, "from", "from_norm")
  normalize_name_dt(all_edges_dt, "to", "to_norm")
  
  setkey(evidence_dt, subject_norm, object_norm)
  setkey(all_edges_dt, from_norm, to_norm)
  
  cat("Matching evidence (Inner Join)...\n")
  matched_evidence <- merge(
    all_edges_dt, 
    evidence_dt[, .(subject_norm, object_norm, subject, object, subject_cui, object_cui, pmid, pmid_url, sentence)],
    by.x = c("from_norm", "to_norm"),
    by.y = c("subject_norm", "object_norm"),
    all.x = FALSE, 
    all.y = FALSE
  )
  
  cat("Matched", nrow(matched_evidence), "evidence pieces across all confounders.\n")
  
  # 5. Write Outputs
  confounders_with_evidence <- unique(matched_evidence$confounder)
  cat("Writing individual evidence files...\n")
  
  # Directory for reports might not exist for invalid confounders
  # We create them if needed to store evidence.csv
  
  summary_stats <- data.table(
    confounder = all_confounders,
    n_edges = 0,
    n_edges_with_evidence = 0,
    n_pmids = 0,
    n_sentences = 0
  )
  
  # Calculate edge counts
  edge_counts <- all_edges_dt[, .N, by = confounder]
  summary_stats[edge_counts, n_edges := N, on = "confounder"]
  
  # Calculate evidence stats
  if (nrow(matched_evidence) > 0) {
    evidence_stats <- matched_evidence[, .(
      n_sentences = .N,
      n_pmids = uniqueN(pmid),
      n_edges_with_evidence = uniqueN(paste(from, to))
    ), by = confounder]
    
    summary_stats[evidence_stats, `:=`(
      n_sentences = i.n_sentences,
      n_pmids = i.n_pmids,
      n_edges_with_evidence = i.n_edges_with_evidence
    ), on = "confounder"]
  }
  
  # Write Loop
  for (conf in confounders_with_evidence) {
    subset_dt <- matched_evidence[confounder == conf]
    output_dt <- subset_dt[, .(from, to, subject_cui, object_cui, pmid, pmid_url, sentence)]
    
    safe_node <- gsub("[^a-zA-Z0-9_]", "_", conf)
    conf_dir <- file.path(confounders_dir, safe_node)
    
    if (!dir.exists(conf_dir)) {
      dir.create(conf_dir, recursive = TRUE)
    }
    
    fwrite(output_dt, file.path(conf_dir, "evidence.csv"))
  }
  
  # 6. Global Outputs
  cat("Writing summary reports...\n")
  fwrite(summary_stats, file.path(output_dir, "evidence_summary.csv"))
  
  if (nrow(matched_evidence) > 0) {
    combined_out <- matched_evidence[, .(confounder, from, to, subject_cui, object_cui, pmid, pmid_url, sentence)]
    fwrite(combined_out, file.path(output_dir, "all_evidence.csv"))
    cat("Combined evidence saved.\n")
  }
  
  return(summary_stats)
}


# =============================================================================
# Main Execution
# =============================================================================

cat("\n")
cat("========================================\n")
cat("Evidence Extraction (Optimized 03c)\n")
cat("========================================\n")
cat("Exposure:", EXPOSURE, "\n")
cat("Outcome:", OUTCOME, "\n")
cat("Degree:", DEGREE, "\n")
cat("Format:", PROV_FORMAT, "\n")
cat("\n")

# Start Timer
start_time <- Sys.time()

# Step 1: Parse Data
if (PROV_FORMAT == "JSON") {
  evidence_dt <- parse_json_assertions_optimized(PROV_FILE)
} else {
  evidence_dt <- parse_causal_assertions_html_optimized(PROV_FILE)
}

setDT(evidence_dt)

# Save the full evidence database
full_evidence_file <- file.path(OUTPUT_DIR, "full_evidence_database.csv")
if (!file.exists(full_evidence_file)) {
    cat("Saving full evidence database...\n")
    fwrite(evidence_dt, full_evidence_file)
}

print_mem()

# Step 2: Process ALL Confounders
if (file.exists(CLASSIFICATION_FILE)) {
  results <- process_all_confounders(evidence_dt, CONFOUNDERS_DIR, CLASSIFICATION_FILE, GRAPH_FILE, OUTPUT_DIR)
  
  cat("\n")
  cat("========================================\n")
  cat("Evidence Extraction Complete\n")
  cat("========================================\n")
  
  end_time <- Sys.time()
  cat("Total Runtime:", round(difftime(end_time, start_time, units = "mins"), 2), "minutes\n")
  
} else {
  cat("Error: Confounder Classification file not found:", CLASSIFICATION_FILE, "\n")
}

cat("\nDone!\n")
