#!/usr/bin/env Rscript

# =============================================================================
# Script: 08_extract_evidence.R
# Purpose: Extract evidence (PMIDs and sentences) from CKT JSON/HTML provenance files
#          and match with edges identified in confounder analysis
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
  library(rvest)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(jsonlite)
})

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 2
)
EXPOSURE <- args$exposure
OUTCOME <- args$outcome
DEGREE <- args$degree

# ---- Set paths ----
INPUT_DIR <- file.path(dirname(script_dir), "input")  # post_ckt/input
DATA_DIR <- get_pair_dir(EXPOSURE, OUTCOME, DEGREE)
CONFOUNDERS_DIR <- file.path(DATA_DIR, "s3_confounders", "reports")
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

# =============================================================================
# Function: Parse HTML to extract causal assertions
# =============================================================================

parse_causal_assertions <- function(html_file) {
  cat("Parsing causal assertions from HTML...\n")
  
  # Read HTML
  html <- read_html(html_file)
  
  # Find all assertion blocks
  assertions <- html %>% html_elements(".streamlined-assertion")
  
  cat("Found", length(assertions), "causal assertion blocks\n")
  
  # Extract data from each assertion
  results <- list()
  
  for (i in seq_along(assertions)) {
    assertion <- assertions[[i]]
    
    # Extract header info (subject -> predicate -> object)
    header <- assertion %>% html_element(".streamlined-header")
    header_text <- header %>% html_text(trim = TRUE)
    
    # Parse subject and object from header
    # Format: "Subject: [Name] Subject CUI: [CUI] → CAUSES → Object: [Name] Object CUI: [CUI]"
    
    # Get all strong elements for names
    strong_elements <- header %>% html_elements("strong")
    if (length(strong_elements) >= 4) {
      subject <- strong_elements[[1]] %>% html_text(trim = TRUE)
      subject_cui <- strong_elements[[2]] %>% html_text(trim = TRUE)
      object <- strong_elements[[3]] %>% html_text(trim = TRUE)
      object_cui <- strong_elements[[4]] %>% html_text(trim = TRUE)
    } else {
      next
    }
    
    # Extract all PMID-sentence pairs
    pmid_lines <- assertion %>% html_elements(".pmid-sentence-line")
    
    for (j in seq_along(pmid_lines)) {
      line <- pmid_lines[[j]]
      
      # Get PMID
      pmid_link <- line %>% html_element(".pmid-link")
      pmid <- pmid_link %>% html_text(trim = TRUE)
      pmid_url <- pmid_link %>% html_attr("href")
      
      # Get sentence
      sentence <- line %>% html_element(".sentence-part") %>% html_text(trim = TRUE)
      
      results[[length(results) + 1]] <- list(
        subject = subject,
        subject_cui = subject_cui,
        object = object,
        object_cui = object_cui,
        pmid = pmid,
        pmid_url = pmid_url,
        sentence = sentence
      )
    }
  }
  
  # Convert to dataframe
  df <- bind_rows(results)
  cat("Extracted", nrow(df), "evidence records\n")
  
  return(df)
}

# =============================================================================
# Function: Parse JSON to extract causal assertions
# =============================================================================

parse_json_assertions <- function(json_file) {
  cat("Parsing causal assertions from JSON...\n")
  
  # Read JSON
  json_data <- fromJSON(json_file, simplifyDataFrame = FALSE)
  
  assertions <- json_data$assertions
  pmid_sentences <- json_data$pmid_sentences
  
  cat("Found", length(assertions), "causal assertion blocks\n")
  cat("Found", length(pmid_sentences), "unique PMIDs\n")
  
  # Extract data from each assertion
  results <- list()
  
  for (i in seq_along(assertions)) {
    assertion <- assertions[[i]]
    
    subject <- assertion$subj
    subject_cui <- assertion$subj_cui
    object <- assertion$obj
    object_cui <- assertion$obj_cui
    pmid_refs <- assertion$pmid_refs
    
    # For each PMID in this assertion, extract all sentences
    for (pmid in pmid_refs) {
      if (pmid %in% names(pmid_sentences)) {
        sentences <- pmid_sentences[[pmid]]
        
        for (sentence in sentences) {
          results[[length(results) + 1]] <- list(
            subject = subject,
            subject_cui = subject_cui,
            object = object,
            object_cui = object_cui,
            pmid = pmid,
            pmid_url = paste0("https://pubmed.ncbi.nlm.nih.gov/", pmid),
            sentence = sentence
          )
        }
      }
    }
  }
  
  # Convert to dataframe
  df <- bind_rows(results)
  cat("Extracted", nrow(df), "evidence records\n")
  
  return(df)
}

# =============================================================================
# Function: Match evidence with confounder edges
# =============================================================================

match_evidence_with_edges <- function(evidence_df, edges_df) {
  # Normalize names for matching (replace underscores with spaces, lowercase)
  normalize_name <- function(name) {
    name %>%
      str_replace_all("_", " ") %>%
      str_replace_all("\\s+", " ") %>%
      str_trim() %>%
      tolower()
  }
  
  # Create normalized versions
  evidence_df <- evidence_df %>%
    mutate(
      subject_norm = normalize_name(subject),
      object_norm = normalize_name(object)
    )
  
  edges_df <- edges_df %>%
    mutate(
      from_norm = normalize_name(from),
      to_norm = normalize_name(to)
    )
  
  # Match edges with evidence
  matched <- edges_df %>%
    left_join(
      evidence_df %>% select(subject_norm, object_norm, pmid, pmid_url, sentence),
      by = c("from_norm" = "subject_norm", "to_norm" = "object_norm")
    ) %>%
    filter(!is.na(pmid))
  
  return(matched)
}

# =============================================================================
# Function: Process all confounders
# =============================================================================

process_confounders <- function(evidence_df, confounders_dir, output_dir) {
  # Get list of confounder directories
  confounder_dirs <- list.dirs(confounders_dir, recursive = FALSE, full.names = TRUE)
  
  cat("Processing", length(confounder_dirs), "confounders...\n")
  
  all_evidence <- list()
  summary_data <- list()
  
  for (confounder_path in confounder_dirs) {
    confounder_name <- basename(confounder_path)
    edges_file <- file.path(confounder_path, "edges.csv")
    
    if (!file.exists(edges_file)) {
      cat("  ", confounder_name, ": No edges.csv found, skipping\n")
      next
    }
    
    # Read edges
    edges_df <- read.csv(edges_file, stringsAsFactors = FALSE)
    
    # Match with evidence
    matched <- match_evidence_with_edges(evidence_df, edges_df)
    
    if (nrow(matched) > 0) {
      # Save evidence for this confounder
      evidence_file <- file.path(confounder_path, "evidence.csv")
      write.csv(matched, evidence_file, row.names = FALSE)
      
      # Create summary
      summary_data[[length(summary_data) + 1]] <- data.frame(
        confounder = confounder_name,
        n_edges = nrow(edges_df),
        n_edges_with_evidence = length(unique(paste(matched$from, matched$to))),
        n_pmids = length(unique(matched$pmid)),
        n_sentences = nrow(matched)
      )
      
      all_evidence[[confounder_name]] <- matched
      cat("  ", confounder_name, ": Found", nrow(matched), "evidence records for", 
          length(unique(paste(matched$from, matched$to))), "edges\n")
    } else {
      summary_data[[length(summary_data) + 1]] <- data.frame(
        confounder = confounder_name,
        n_edges = nrow(edges_df),
        n_edges_with_evidence = 0,
        n_pmids = 0,
        n_sentences = 0
      )
      cat("  ", confounder_name, ": No matching evidence found\n")
    }
  }
  
  # Create summary report
  summary_df <- bind_rows(summary_data)
  summary_file <- file.path(output_dir, "evidence_summary.csv")
  write.csv(summary_df, summary_file, row.names = FALSE)
  
  # Save all evidence combined
  if (length(all_evidence) > 0) {
    combined_evidence <- bind_rows(all_evidence, .id = "confounder")
    combined_file <- file.path(output_dir, "all_evidence.csv")
    write.csv(combined_evidence, combined_file, row.names = FALSE)
    cat("\nCombined evidence saved to:", combined_file, "\n")
  }
  
  cat("\nSummary saved to:", summary_file, "\n")
  
  return(list(summary = summary_df, all_evidence = all_evidence))
}

# =============================================================================
# Main Execution
# =============================================================================

cat("\n")
cat("========================================\n")
cat("Evidence Extraction for Causal Analysis\n")
cat("========================================\n")
cat("\n")
cat("Exposure:", EXPOSURE, "\n")
cat("Outcome:", OUTCOME, "\n")
cat("Degree:", DEGREE, "\n")
cat("Format:", PROV_FORMAT, "\n")
cat("\n")

# Step 1: Parse provenance file to extract all causal assertions with evidence
if (PROV_FORMAT == "JSON") {
  evidence_df <- parse_json_assertions(PROV_FILE)
} else {
  evidence_df <- parse_causal_assertions(PROV_FILE)
}

# Save the full evidence database
full_evidence_file <- file.path(OUTPUT_DIR, "full_evidence_database.csv")
write.csv(evidence_df, full_evidence_file, row.names = FALSE)
cat("Full evidence database saved to:", full_evidence_file, "\n\n")

# Step 2: Process each confounder and match with evidence
if (dir.exists(CONFOUNDERS_DIR)) {
  results <- process_confounders(evidence_df, CONFOUNDERS_DIR, OUTPUT_DIR)
  
  cat("\n")
  cat("========================================\n")
  cat("Evidence Extraction Complete\n")
  cat("========================================\n")
  cat("\n")
  cat("Total assertions extracted:", nrow(evidence_df), "\n")
  cat("Unique PMIDs:", length(unique(evidence_df$pmid)), "\n")
  cat("Unique subject-object pairs:", nrow(unique(evidence_df[, c("subject", "object")])), "\n")
  cat("\n")
  cat("Confounders with evidence:", sum(results$summary$n_edges_with_evidence > 0), "/", nrow(results$summary), "\n")
  cat("Total edges with evidence:", sum(results$summary$n_edges_with_evidence), "\n")
  cat("Total evidence sentences:", sum(results$summary$n_sentences), "\n")
  
} else {
  cat("Warning: Confounders directory not found:", CONFOUNDERS_DIR, "\n")
  cat("Run the confounder analysis first (07_confounder_discovery.R and 07b_confounder_reports.R)\n")
}

cat("\nDone!\n")
