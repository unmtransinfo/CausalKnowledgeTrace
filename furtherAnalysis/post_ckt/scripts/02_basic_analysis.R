# 02_basic_analysis.R
# Basic graph analysis & Semantic Type Analysis
#
# This script performs:
# 1. Basic graph statistics (nodes, edges, density)
# 2. Exposure/Outcome connection analysis
# 3. Node degree analysis (hubs)
# 4. Semantic type extraction from DB (if available)
# 5. Semantic type distribution analysis
#
# Input: data/{Exposure}_{Outcome}/degree{N}/s1_graph/pruned_graph.rds
#        input/{Exposure}_{Outcome}*.json (for semantic mapping)
# Output: data/{Exposure}_{Outcome}/degree{N}/s2_semantic/
#   - node_degrees.csv
#   - graph_statistics.txt
#   - nodes_with_semantic_types.csv
#   - semantic_type_distribution.csv
#   - plots/semantic_type_distribution.png

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
library(ggplot2)
library(jsonlite)
# Create a conditional dependency for RPostgreSQL
if (!require(RPostgreSQL, quietly = TRUE)) {
  cat("WARNING: RPostgreSQL package not installed. Database functionality will be skipped.\n")
}

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
output_dir <- get_s2_semantic_dir(exposure_name, outcome_name, degree)
plots_dir <- file.path(output_dir, "plots")

# ---- Validate inputs ----
if (!file.exists(input_file)) {
  stop(paste0("Pruned graph not found at: ", input_file, "\nPlease run 01c_prune_generic_hubs.R first.\n"))
}

ensure_dir(output_dir)
ensure_dir(plots_dir)

print_header(paste0("Basic & Semantic Analysis - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
graph <- readRDS(input_file)
cat("Graph loaded:", vcount(graph), "nodes,", ecount(graph), "edges\n\n")

# ==========================================
# 2. BASIC GRAPH STATISTICS
# ==========================================
cat("=== 2. GRAPH STATISTICS ===\n")
cat("Nodes:", vcount(graph), "\n")
cat("Edges:", ecount(graph), "\n")
cat("Density:", round(graph.density(graph), 6), "\n")
cat("Directed:", is_directed(graph), "\n")
cat("Weakly connected:", is_connected(graph, mode = "weak"), "\n")
cat("Strongly connected:", is_connected(graph, mode = "strong"), "\n\n")

# Save detailed stats
stats_file <- file.path(output_dir, "graph_statistics.txt")
sink(stats_file)
cat("=== GRAPH STATISTICS ===\n")
cat("Nodes:", vcount(graph), "\n")
cat("Edges:", ecount(graph), "\n")
cat("Density:", graph.density(graph), "\n")
cat("\nExposure:", exposure_name, "\n")
cat("Outcome:", outcome_name, "\n")
sink()
cat("Saved statistics to:", stats_file, "\n\n")

# ==========================================
# 3. NODE DEGREE ANALYSIS
# ==========================================
cat("=== 3. NODE DEGREE ANALYSIS ===\n")

in_degree <- degree(graph, mode = "in")
out_degree <- degree(graph, mode = "out")
total_degree <- degree(graph, mode = "all")
betweenness_score <- betweenness(graph, normalized = TRUE)

degree_data <- data.frame(
  Node = V(graph)$name,
  In_Degree = in_degree,
  Out_Degree = out_degree,
  Total_Degree = total_degree,
  Betweenness = betweenness_score,
  stringsAsFactors = FALSE
)

# Sort by total degree and save
degree_data <- degree_data[order(-degree_data$Total_Degree), ]
write.csv(degree_data, file.path(output_dir, "node_degrees.csv"), row.names = FALSE)
cat("Saved node degrees to:", file.path(output_dir, "node_degrees.csv"), "\n")

cat("Top 10 hubs:\n")
print(head(degree_data[, c("Node", "Total_Degree", "Betweenness")], 10), row.names = FALSE)
cat("\n")

# ==========================================
# 4. SEMANTIC TYPE ANALYSIS (DB INTEGRATION)
# ==========================================
cat("=== 4. SEMANTIC TYPE ANALYSIS ===\n")

# Initialize semantic type column
degree_data$semtype <- NA
degree_data$cui <- NA

# Helper to map names
clean_for_matching <- function(name) {
  name <- tolower(name)
  name <- gsub("[^a-z0-9]+", "_", name)
  name <- gsub("^_|_$", "", name)
  name <- gsub("_+", "_", name)
  return(name)
}

# Try to connect to DB and fetch semantic types
db_success <- FALSE

tryCatch({
  # 1. Find JSON assertions file to map Node Name -> CUI
  json_file <- find_json_file(exposure_name, outcome_name, degree)
  
  if (!is.null(json_file) && require(RPostgreSQL, quietly = TRUE)) {
    cat("Found JSON file:", json_file, "\n")
    
    # Load JSON
    json_data <- fromJSON(json_file)
    assertions <- json_data$assertions
    
    # Create Name -> CUI map from assertions
    name_cui_map <- rbind(
      data.frame(name = assertions$subj, cui = assertions$subj_cui, stringsAsFactors = FALSE),
      data.frame(name = assertions$obj, cui = assertions$obj_cui, stringsAsFactors = FALSE)
    )
    name_cui_map <- name_cui_map[!duplicated(name_cui_map), ]
    name_cui_map$name_cleaned <- sapply(name_cui_map$name, clean_for_matching)
    
    # Map graph nodes to CUIs
    graph_nodes_clean <- sapply(degree_data$Node, clean_for_matching)
    degree_data$cui <- name_cui_map$cui[match(graph_nodes_clean, name_cui_map$name_cleaned)]
    
    # Get unique CUIs to query
    unique_cuis <- unique(na.omit(degree_data$cui))
    cat("Mapped", length(unique_cuis), "unique CUIs from graph nodes.\n")
    
    if (length(unique_cuis) > 0) {
      # Connect to DB
      validate_db_credentials()
      con <- dbConnect(PostgreSQL(),
                       host = DB_CONFIG$host,
                       port = DB_CONFIG$port,
                       dbname = DB_CONFIG$dbname,
                       user = DB_CONFIG$user,
                       password = DB_CONFIG$password)
      
      cat("Connected to database for semantic type lookup.\n")
      
      # Query semantic types
      cui_list_str <- paste0("('", paste(unique_cuis, collapse = "','"), "')")
      
      # Query subject semantic types
      q1 <- sprintf("SELECT DISTINCT subject_cui as cui, subject_semtype as semtype FROM public.predication WHERE subject_cui IN %s", cui_list_str)
      r1 <- dbGetQuery(con, q1)
      
      # Query object semantic types
      q2 <- sprintf("SELECT DISTINCT object_cui as cui, object_semtype as semtype FROM public.predication WHERE object_cui IN %s", cui_list_str)
      r2 <- dbGetQuery(con, q2)
      
      dbDisconnect(con)
      
      # Merge results
      all_semtypes <- unique(rbind(r1, r2))
      
      # Map back to degree_data
      # Note: A CUI might have multiple semtypes; we'll take the first one or comma-separate
      semtype_map <- aggregate(semtype ~ cui, data = all_semtypes, FUN = function(x) paste(unique(x), collapse = "|"))
      
      degree_data$semtype <- semtype_map$semtype[match(degree_data$cui, semtype_map$cui)]
      
      db_success <- TRUE
      cat("Successfully mapped semantic types for", sum(!is.na(degree_data$semtype)), "nodes.\n")
    }
  } else {
    if (is.null(json_file)) cat("JSON assertions file not found. Skipping DB lookup.\n")
    if (!require(RPostgreSQL, quietly = TRUE)) cat("RPostgreSQL not available. Skipping DB lookup.\n")
  }
}, error = function(e) {
  cat("WARNING: Database lookup failed:", e$message, "\n")
  cat("Continuing without semantic type information.\n")
})

# Save updated node data with semantic types
write.csv(degree_data, file.path(output_dir, "nodes_with_semantic_types.csv"), row.names = FALSE)

# ==========================================
# 5. SEMANTIC TYPE DISTRIBUTION
# ==========================================
if (db_success && sum(!is.na(degree_data$semtype)) > 0) {
  cat("\n=== 5. SEMANTIC TYPE DISTRIBUTION ===\n")
  
  # Split pipe-separated semtypes if any
  expanded_semtypes <- degree_data %>%
    filter(!is.na(semtype)) %>%
    select(Node, semtype) %>%
    tidyr::separate_rows(semtype, sep = "\\|")
  
  dist_stats <- expanded_semtypes %>%
    count(semtype, sort = TRUE) %>%
    rename(Count = n) %>%
    mutate(Percentage = round(Count / sum(Count) * 100, 1))
  
  print(head(dist_stats, 10))
  
  write.csv(dist_stats, file.path(output_dir, "semantic_type_distribution.csv"), row.names = FALSE)
  
  # Visualization
  p <- ggplot(head(dist_stats, 20), aes(x = reorder(semtype, Count), y = Count)) +
    geom_bar(stat = "identity", fill = "steelblue") +
    geom_text(aes(label = Count), hjust = -0.1, size = 3) +
    coord_flip() +
    labs(
      title = "Top 20 Semantic Types",
      subtitle = paste(exposure_name, "->", outcome_name),
      x = "Semantic Type",
      y = "Count"
    ) +
    theme_minimal()
  
  ggsave(file.path(plots_dir, "semantic_type_distribution.png"), p, width = 8, height = 6)
  cat("Saved distribution plot to:", file.path(plots_dir, "semantic_type_distribution.png"), "\n")
  
} else {
  cat("\nSkipping semantic distribution analysis (no data available).\n")
}

print_complete("Basic & Semantic Analysis")
