# 03a_semantic_type_analysis.R
# Extract semantic types from database and analyze their role in cycles
#
# Input:
#   - data/{Exposure}_{Outcome}/s1_graph/parsed_graph.rds
#   - data/{Exposure}_{Outcome}/s2_semantic/node_centrality_and_cycles.csv
#   - input/{Exposure}_{Outcome}*.json
# Output: data/{Exposure}_{Outcome}/s2_semantic/
#   - nodes_with_semantic_types.csv
#   - semantic_type_cycle_stats.csv
#   - problematic_semantic_types.csv
#   - semantic_type_summary.txt

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
library(RPostgreSQL)
library(jsonlite)
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

# ---- Find JSON assertions file ----
json_file <- find_json_file(exposure_name, outcome_name, degree)

if (is.null(json_file)) {
  stop("Could not find JSON assertions file for ", exposure_name, "_", outcome_name,
       " in ", get_input_dir())
}

# ---- Set paths using utility functions ----
parsed_graph_file <- get_parsed_graph_path(exposure_name, outcome_name, degree)
output_dir <- get_s2_semantic_dir(exposure_name, outcome_name, degree)
cycle_data_file <- file.path(output_dir, "node_centrality_and_cycles.csv")

# ---- Database connection parameters from config ----
validate_db_credentials()
db_host <- DB_CONFIG$host
db_port <- DB_CONFIG$port
db_name <- DB_CONFIG$dbname
db_user <- DB_CONFIG$user
db_password <- DB_CONFIG$password

# Create output directory
ensure_dir(output_dir)

print_header(paste0("Semantic Type Analysis (Stage 2) - Degree ", degree), exposure_name, outcome_name)
cat("This script extracts semantic types from the database and analyzes their distribution\n")
cat("in nodes that participate in cycles vs. nodes that don't.\n\n")
cat("Input graph:", parsed_graph_file, "\n")
cat("Output:", output_dir, "\n\n")

# ==========================================
# 1. LOAD EXISTING ANALYSIS DATA
# ==========================================
cat("=== 1. LOADING EXISTING DATA ===\n")

# Load the parsed graph
cat("Loading graph from:", parsed_graph_file, "\n")
graph <- readRDS(parsed_graph_file)
cat("Graph has", vcount(graph), "nodes and", ecount(graph), "edges\n")

# Load cycle analysis data
cat("Loading cycle analysis from:", cycle_data_file, "\n")
cycle_data <- read.csv(cycle_data_file)
cat("Loaded centrality and cycle data for", nrow(cycle_data), "nodes\n\n")

# ==========================================
# 2. EXTRACT CUIs FROM JSON ASSERTIONS FILE
# ==========================================
cat("=== 2. EXTRACTING CUIs FROM JSON ASSERTIONS FILE ===\n")
cat("Reading JSON file:", json_file, "\n")

# Read and parse JSON
json_data <- fromJSON(json_file)

# Extract assertions which contain CUI information
assertions <- json_data$assertions
cat("Found", nrow(assertions), "assertions in JSON file\n")

# Extract all unique CUIs from subject and object
subject_cuis <- unique(assertions$subj_cui)
object_cuis <- unique(assertions$obj_cui)
all_cuis <- unique(c(subject_cuis, object_cuis))
cat("Found", length(all_cuis), "unique CUIs in the JSON assertions file\n")

# Create a direct mapping from node names to CUIs from the assertions
# This gives us name -> CUI mapping without needing database lookup for names
name_cui_map <- rbind(
  data.frame(name = assertions$subj, cui = assertions$subj_cui, stringsAsFactors = FALSE),
  data.frame(name = assertions$obj, cui = assertions$obj_cui, stringsAsFactors = FALSE)
)
name_cui_map <- name_cui_map[!duplicated(name_cui_map), ]
cat("Created name-to-CUI mapping for", nrow(name_cui_map), "unique name-CUI pairs\n\n")

# ==========================================
# 3. CONNECT TO DATABASE AND QUERY SEMANTIC TYPES
# ==========================================
cat("=== 3. QUERYING DATABASE FOR SEMANTIC TYPES ===\n")
cat("Connecting to database:", db_name, "at", db_host, ":", db_port, "\n")

# Establish database connection
tryCatch({
  con <- dbConnect(
    PostgreSQL(),
    host = db_host,
    port = db_port,
    dbname = db_name,
    user = db_user,
    password = db_password
  )

  cat("Successfully connected to database\n")

  # Query to get unique CUIs with their semantic types from predication table
  # Note: In SemMedDB, predication table has subject_cui, subject_semtype, object_cui, object_semtype
  cat("Querying semantic types for", length(all_cuis), "CUIs...\n")

  # Create a temporary table with our CUIs
  cui_list_str <- paste0("('", paste(all_cuis, collapse = "','"), "')")

  # Query for subject CUIs
  query_subjects <- sprintf("
    SELECT DISTINCT subject_cui as cui, subject_semtype as semtype, subject_name as name
    FROM public.predication
    WHERE subject_cui IN %s
  ", cui_list_str)

  subject_semtypes <- dbGetQuery(con, query_subjects)
  cat("Retrieved semantic types for", nrow(subject_semtypes), "subject CUIs\n")

  # Query for object CUIs
  query_objects <- sprintf("
    SELECT DISTINCT object_cui as cui, object_semtype as semtype, object_name as name
    FROM public.predication
    WHERE object_cui IN %s
  ", cui_list_str)

  object_semtypes <- dbGetQuery(con, query_objects)
  cat("Retrieved semantic types for", nrow(object_semtypes), "object CUIs\n")

  # Combine subject and object semantic types
  cui_semtype_data <- rbind(subject_semtypes, object_semtypes)
  cui_semtype_data <- cui_semtype_data[!duplicated(cui_semtype_data[, c("cui", "semtype")]), ]

  cat("Total unique CUI-SemType combinations:", nrow(cui_semtype_data), "\n")

  # Close database connection
  dbDisconnect(con)
  cat("Database connection closed\n\n")

}, error = function(e) {
  cat("ERROR connecting to database:\n")
  cat(conditionMessage(e), "\n")
  cat("\nPlease ensure:\n")
  cat("1. Docker container is running: docker-compose ps\n")
  cat("2. Database is accessible on port", db_port, "\n")
  cat("3. If running inside docker, change db_host to 'db'\n")
  cat("4. If running outside docker, use 'localhost' or '127.0.0.1'\n\n")
  stop("Database connection failed")
})

# ==========================================
# 4. MAP CUI TO NODE NAMES IN GRAPH
# ==========================================
cat("=== 4. MAPPING SEMANTIC TYPES TO GRAPH NODES ===\n")

# Create a cleaned name version for matching
clean_for_matching <- function(name) {
  # Convert to lowercase, replace spaces/special chars with underscore
  name <- tolower(name)
  name <- gsub("[^a-z0-9]+", "_", name)
  name <- gsub("^_|_$", "", name)  # Remove leading/trailing underscores
  name <- gsub("_+", "_", name)     # Collapse multiple underscores
  return(name)
}

# Clean names in the JSON-derived mapping
name_cui_map$name_cleaned <- sapply(name_cui_map$name, clean_for_matching)

# Create graph node data frame with cleaned names
graph_node_names <- data.frame(
  Node = V(graph)$name,
  Node_cleaned = sapply(V(graph)$name, clean_for_matching),
  stringsAsFactors = FALSE
)

# First, map graph nodes to CUIs using the JSON-derived mapping
node_cui_map <- merge(
  graph_node_names,
  name_cui_map[, c("name_cleaned", "cui")],
  by.x = "Node_cleaned",
  by.y = "name_cleaned",
  all.x = TRUE
)
# Remove duplicates (keep first match)
node_cui_map <- node_cui_map[!duplicated(node_cui_map$Node), ]

cat("Mapped CUIs to", sum(!is.na(node_cui_map$cui)), "out of",
    nrow(node_cui_map), "graph nodes\n")

# Now merge with semantic types from database
node_semtype_map <- merge(
  node_cui_map,
  cui_semtype_data[, c("cui", "semtype")],
  by = "cui",
  all.x = TRUE
)
# Remove duplicates (a CUI can have multiple semtypes, keep first)
node_semtype_map <- node_semtype_map[!duplicated(node_semtype_map$Node), ]

cat("Successfully mapped semantic types to",
    sum(!is.na(node_semtype_map$semtype)), "out of",
    nrow(node_semtype_map), "nodes\n")
cat("Nodes without semantic type mapping:",
    sum(is.na(node_semtype_map$semtype)), "\n\n")

# ==========================================
# 5. MERGE WITH CYCLE ANALYSIS DATA
# ==========================================
cat("=== 5. MERGING SEMANTIC TYPES WITH CYCLE ANALYSIS ===\n")

# Merge with cycle data
cycle_data_with_semtype <- merge(
  cycle_data,
  node_semtype_map[, c("Node", "cui", "semtype")],
  by = "Node",
  all.x = TRUE
)

cat("Merged semantic types with cycle analysis data\n")
cat("Nodes with semantic types:", sum(!is.na(cycle_data_with_semtype$semtype)), "\n\n")

# ==========================================
# 6. ANALYZE SEMANTIC TYPE DISTRIBUTION
# ==========================================
cat("=== 6. SEMANTIC TYPE DISTRIBUTION ANALYSIS ===\n\n")

# Overall semantic type distribution
cat("=== Overall Semantic Type Distribution ===\n")
semtype_dist <- table(cycle_data_with_semtype$semtype, useNA = "always")
semtype_dist_sorted <- sort(semtype_dist, decreasing = TRUE)
cat("\nTop 20 semantic types in the graph:\n")
print(head(semtype_dist_sorted, 20))
cat("\n")

# Semantic types in nodes that are IN cycles
cat("=== Semantic Types in Nodes PARTICIPATING IN CYCLES ===\n")
in_cycle_semtypes <- cycle_data_with_semtype[cycle_data_with_semtype$In_Cycle == TRUE, ]
semtype_in_cycles <- table(in_cycle_semtypes$semtype, useNA = "always")
semtype_in_cycles_sorted <- sort(semtype_in_cycles, decreasing = TRUE)
cat("\nTop 20 semantic types in nodes IN cycles:\n")
print(head(semtype_in_cycles_sorted, 20))
cat("\n")

# Semantic types in nodes NOT in cycles
cat("=== Semantic Types in Nodes NOT IN CYCLES ===\n")
not_in_cycle_semtypes <- cycle_data_with_semtype[cycle_data_with_semtype$In_Cycle == FALSE, ]
semtype_not_in_cycles <- table(not_in_cycle_semtypes$semtype, useNA = "always")
semtype_not_in_cycles_sorted <- sort(semtype_not_in_cycles, decreasing = TRUE)
cat("\nTop 20 semantic types in nodes NOT in cycles:\n")
print(head(semtype_not_in_cycles_sorted, 20))
cat("\n")

# ==========================================
# 7. CALCULATE CYCLE PARTICIPATION RATE BY SEMANTIC TYPE
# ==========================================
cat("=== 7. CYCLE PARTICIPATION RATE BY SEMANTIC TYPE ===\n\n")

# For each semantic type, calculate what % of nodes with that type are in cycles
semtype_cycle_stats <- cycle_data_with_semtype %>%
  filter(!is.na(semtype)) %>%
  group_by(semtype) %>%
  summarize(
    Total_Nodes = n(),
    Nodes_In_Cycles = sum(In_Cycle),
    Nodes_Not_In_Cycles = sum(!In_Cycle),
    Cycle_Participation_Rate = round(100 * sum(In_Cycle) / n(), 2),
    Mean_Degree = round(mean(Total_Degree), 2),
    Mean_Betweenness = round(mean(Betweenness), 2)
  ) %>%
  arrange(desc(Cycle_Participation_Rate))

cat("Semantic types ranked by cycle participation rate:\n")
print(head(semtype_cycle_stats, 30))
cat("\n")

# ==========================================
# 8. IDENTIFY PROBLEMATIC SEMANTIC TYPES
# ==========================================
cat("=== 8. IDENTIFYING PROBLEMATIC SEMANTIC TYPES ===\n\n")

# Define criteria for "problematic" semantic types:
# 1. High cycle participation rate (> 50% or 25% threshold can be adjusted as needed)

# 2. Present in at least 3 nodes

problematic_semtypes <- semtype_cycle_stats %>%
  filter(Cycle_Participation_Rate > 25, Total_Nodes >= 3) %>%
  arrange(desc(Cycle_Participation_Rate))

cat("Problematic semantic types (>50% in cycles, ≥3 nodes):\n")
print(problematic_semtypes)
cat("\n")

# ==========================================
# 9. SAVE RESULTS
# ==========================================
cat("=== 9. SAVING RESULTS ===\n")

# Save merged data with semantic types
output_file_merged <- file.path(output_dir, "nodes_with_semantic_types.csv")
write.csv(cycle_data_with_semtype, output_file_merged, row.names = FALSE)
cat("Saved node data with semantic types to:", output_file_merged, "\n")

# Save semantic type statistics
output_file_stats <- file.path(output_dir, "semantic_type_cycle_stats.csv")
write.csv(semtype_cycle_stats, output_file_stats, row.names = FALSE)
cat("Saved semantic type statistics to:", output_file_stats, "\n")

# Save problematic semantic types
output_file_problematic <- file.path(output_dir, "problematic_semantic_types.csv")
write.csv(problematic_semtypes, output_file_problematic, row.names = FALSE)
cat("Saved problematic semantic types to:", output_file_problematic, "\n")

# Save summary report
summary_file <- file.path(output_dir, "semantic_type_summary.txt")
sink(summary_file)
cat("=== SEMANTIC TYPE ANALYSIS SUMMARY ===\n\n")
cat("Total nodes in graph:", nrow(cycle_data_with_semtype), "\n")
cat("Nodes with semantic type mapping:", sum(!is.na(cycle_data_with_semtype$semtype)), "\n")
cat("Nodes in cycles:", sum(cycle_data_with_semtype$In_Cycle), "\n")
cat("Nodes not in cycles:", sum(!cycle_data_with_semtype$In_Cycle), "\n\n")
cat("Total unique semantic types:", nrow(semtype_cycle_stats), "\n")
cat("Problematic semantic types (>50% in cycles):", nrow(problematic_semtypes), "\n\n")
cat("Top 10 Problematic Semantic Types:\n")
print(head(problematic_semtypes, 10))
sink()
cat("Saved summary to:", summary_file, "\n")

print_complete("Semantic Type Analysis (Stage 2)")
