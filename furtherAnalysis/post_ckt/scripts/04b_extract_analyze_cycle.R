# 04b_extract_analyze_cycle.R
# Extract ALL cycles from the graph for accurate node participation counts
# Save only a sample of cycle subgraphs for detailed analysis
#
# Input: data/{Exposure}_{Outcome}/s1_graph/parsed_graph.rds
# Output: data/{Exposure}_{Outcome}/s3_cycles/
#   - node_cycle_participation.csv
#   - cycle_summary.csv
#   - cycle_length_distribution.csv
#   - extraction_summary.txt
#   - scc{N}_cycle{NNN}.rds (sampled cycle subgraphs)

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

# ---- Configuration from config.R ----
MAX_CYCLES_TO_SAVE <- CYCLE_CONFIG$max_cycles_to_save

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
input_file <- get_parsed_graph_path(exposure_name, outcome_name)
output_dir <- get_s3_cycles_dir(exposure_name, outcome_name)

# ---- Validate inputs and create output directory ----
validate_inputs(exposure_name, outcome_name, require_parsed_graph = TRUE)
ensure_dir(output_dir)

print_header("Cycle Extraction and Subgraph Analysis (Stage 3)", exposure_name, outcome_name)
cat("Max cycles to save per SCC:", MAX_CYCLES_TO_SAVE, "\n\n")

# ==========================================
# 1. LOAD GRAPH
# ==========================================
cat("=== 1. LOADING GRAPH ===\n")
cat("Loading graph from:", input_file, "\n")
graph <- readRDS(input_file)
cat("Graph has", vcount(graph), "nodes and", ecount(graph), "edges\n\n")

# ==========================================
# 2. FIND STRONGLY CONNECTED COMPONENTS
# ==========================================
cat("=== 2. FINDING STRONGLY CONNECTED COMPONENTS ===\n")

scc <- components(graph, mode = "strong")
cat("Total SCCs:", scc$no, "\n")

# Get SCCs with size > 1 (these contain cycles)
scc_sizes <- table(scc$membership)
large_sccs <- as.numeric(names(scc_sizes[scc_sizes > 1]))
cat("SCCs with cycles (size > 1):", length(large_sccs), "\n")

for (scc_id in large_sccs) {
  cat("  SCC", scc_id, ": size", scc_sizes[as.character(scc_id)], "\n")
}
cat("\n")

# ==========================================
# 3. FUNCTION TO FIND ALL CYCLES AND TRACK NODE PARTICIPATION
# ==========================================

# Find ALL cycles, track node participation, and sample cycles for saving
# Returns: list with node_counts, sampled_cycles, total_count, cycle_length_dist
find_all_cycles_with_stats <- function(g, max_to_save = MAX_CYCLES_TO_SAVE) {
  n <- vcount(g)
  node_names <- V(g)$name

  # Initialize node participation counter
  node_cycle_counts <- rep(0, n)
  names(node_cycle_counts) <- node_names

  # Track cycle length distribution
  cycle_length_counts <- list()

  # Store sampled cycles (diverse lengths)
  sampled_cycles <- list()
  cycles_per_length <- list()  # Track how many we've sampled per length

  total_cycles <- 0

  if (n == 0) {
    return(list(
      node_counts = node_cycle_counts,
      sampled_cycles = sampled_cycles,
      total_count = 0,
      length_dist = cycle_length_counts
    ))
  }

  # Get adjacency list
  adj_list <- as_adj_list(g, mode = "out")

  # Progress tracking
  progress_interval <- 100000
  last_progress <- 0

  # For each starting node, do DFS to find cycles
  find_cycles_from_node <- function(start, current, path, visited) {
    neighbors <- adj_list[[current]]

    for (next_node in neighbors) {
      if (next_node == start && length(path) >= 2) {
        # Found a cycle back to start
        total_cycles <<- total_cycles + 1
        cycle_length <- length(path)

        # Update node participation counts
        for (node_idx in path) {
          node_cycle_counts[node_idx] <<- node_cycle_counts[node_idx] + 1
        }

        # Update cycle length distribution
        len_key <- as.character(cycle_length)
        if (is.null(cycle_length_counts[[len_key]])) {
          cycle_length_counts[[len_key]] <<- 0
        }
        cycle_length_counts[[len_key]] <<- cycle_length_counts[[len_key]] + 1

        # Sample this cycle for saving (diverse lengths strategy)
        if (is.null(cycles_per_length[[len_key]])) {
          cycles_per_length[[len_key]] <<- 0
        }

        # Decide whether to keep this cycle
        # Keep more short cycles and some long cycles
        max_per_length <- ceiling(max_to_save / max(n - 1, 1))  # Distribute across lengths

        if (cycles_per_length[[len_key]] < max_per_length || length(sampled_cycles) < max_to_save) {
          if (length(sampled_cycles) < max_to_save) {
            sampled_cycles <<- c(sampled_cycles, list(path))
            cycles_per_length[[len_key]] <<- cycles_per_length[[len_key]] + 1
          }
        }

        # Progress update
        if (total_cycles - last_progress >= progress_interval) {
          cat("    Found", total_cycles, "cycles so far...\n")
          last_progress <<- total_cycles
        }

      } else if (!(next_node %in% visited) && next_node > start) {
        # Continue DFS (only visit nodes > start to avoid duplicates)
        new_visited <- c(visited, next_node)
        new_path <- c(path, next_node)
        find_cycles_from_node(start, next_node, new_path, new_visited)
      }
    }
  }

  # Start DFS from each node
  for (start in 1:n) {
    find_cycles_from_node(start, start, c(start), c(start))
  }

  return(list(
    node_counts = node_cycle_counts,
    sampled_cycles = sampled_cycles,
    total_count = total_cycles,
    length_dist = cycle_length_counts
  ))
}

# ==========================================
# 4. EXTRACT CYCLES FROM EACH SCC
# ==========================================
cat("=== 3. EXTRACTING CYCLES FROM EACH SCC ===\n")
cat("This may take a while for large SCCs...\n")

total_cycles_all <- 0
total_saved <- 0

# Global node participation (across all SCCs)
all_node_participation <- data.frame(
  node = character(),
  scc_id = integer(),
  num_cycles = integer(),
  stringsAsFactors = FALSE
)

# Cycle summary for saved cycles
cycle_summary <- data.frame(
  scc_id = integer(),
  cycle_id = integer(),
  cycle_length = integer(),
  nodes = character(),
  stringsAsFactors = FALSE
)

# Cycle length distribution across all SCCs
all_length_dist <- list()

for (scc_id in large_sccs) {
  cat("\nProcessing SCC", scc_id, "...\n")

  # Extract subgraph for this SCC
  scc_nodes <- which(scc$membership == scc_id)
  scc_subgraph <- induced_subgraph(graph, scc_nodes)

  cat("  SCC subgraph:", vcount(scc_subgraph), "nodes,", ecount(scc_subgraph), "edges\n")
  cat("  Finding ALL cycles (this may take time)...\n")

  # Find all cycles and get statistics
  start_time <- Sys.time()
  result <- find_all_cycles_with_stats(scc_subgraph, MAX_CYCLES_TO_SAVE)
  end_time <- Sys.time()

  cat("  Found", result$total_count, "total cycles in",
      round(difftime(end_time, start_time, units = "secs"), 1), "seconds\n")

  total_cycles_all <- total_cycles_all + result$total_count

  # Add node participation to global tracker
  node_counts <- result$node_counts
  for (i in seq_along(node_counts)) {
    if (node_counts[i] > 0) {
      all_node_participation <- rbind(all_node_participation, data.frame(
        node = names(node_counts)[i],
        scc_id = scc_id,
        num_cycles = node_counts[i],
        stringsAsFactors = FALSE
      ))
    }
  }

  # Merge cycle length distributions
  for (len in names(result$length_dist)) {
    if (is.null(all_length_dist[[len]])) {
      all_length_dist[[len]] <- 0
    }
    all_length_dist[[len]] <- all_length_dist[[len]] + result$length_dist[[len]]
  }

  # Save sampled cycles as subgraphs
  cat("  Saving", length(result$sampled_cycles), "sampled cycle subgraphs...\n")

  cycle_counter <- 1
  for (cycle in result$sampled_cycles) {
    # Get node names for this cycle
    cycle_node_names <- V(scc_subgraph)$name[cycle]

    # Create subgraph for this cycle
    cycle_subgraph <- induced_subgraph(scc_subgraph, cycle)

    # Add cycle metadata as graph attributes
    cycle_subgraph <- set_graph_attr(cycle_subgraph, "scc_id", scc_id)
    cycle_subgraph <- set_graph_attr(cycle_subgraph, "cycle_id", cycle_counter)
    cycle_subgraph <- set_graph_attr(cycle_subgraph, "cycle_path", paste(cycle_node_names, collapse = " -> "))

    # Save the subgraph
    filename <- sprintf("scc%d_cycle%03d.rds", scc_id, cycle_counter)
    filepath <- file.path(output_dir, filename)
    saveRDS(cycle_subgraph, filepath)

    # Add to summary
    cycle_summary <- rbind(cycle_summary, data.frame(
      scc_id = scc_id,
      cycle_id = cycle_counter,
      cycle_length = length(cycle_node_names),
      nodes = paste(cycle_node_names, collapse = " -> "),
      stringsAsFactors = FALSE
    ))

    cycle_counter <- cycle_counter + 1
    total_saved <- total_saved + 1
  }

  cat("  Saved", cycle_counter - 1, "cycle subgraphs\n")
}

# ==========================================
# 5. AGGREGATE NODE PARTICIPATION
# ==========================================
cat("\n=== 4. AGGREGATING NODE CYCLE PARTICIPATION ===\n")

# Aggregate by node (sum across SCCs if node appears in multiple)
node_cycle_participation <- all_node_participation %>%
  group_by(node) %>%
  summarize(
    num_cycles = sum(num_cycles),
    scc_ids = paste(unique(scc_id), collapse = ", "),
    .groups = "drop"
  ) %>%
  arrange(desc(num_cycles))

# Save node cycle participation (based on ALL cycles, not just saved ones)
node_participation_file <- file.path(output_dir, "node_cycle_participation.csv")
write.csv(node_cycle_participation, node_participation_file, row.names = FALSE)
cat("Saved node cycle participation to:", node_participation_file, "\n")

cat("Nodes participating in cycles:", nrow(node_cycle_participation), "\n")
cat("Top 10 nodes by cycle participation (across ALL cycles):\n")
print(head(node_cycle_participation[, c("node", "num_cycles")], 10))

# ==========================================
# 6. SAVE CYCLE SUMMARY
# ==========================================
cat("\n=== 5. SAVING SUMMARIES ===\n")

# Save cycle summary (only sampled cycles)
summary_file <- file.path(output_dir, "cycle_summary.csv")
write.csv(cycle_summary, summary_file, row.names = FALSE)
cat("Saved cycle summary to:", summary_file, "\n")

# Convert length distribution to data frame
length_dist_df <- data.frame(
  cycle_length = as.integer(names(all_length_dist)),
  count = unlist(all_length_dist),
  stringsAsFactors = FALSE
)
length_dist_df <- length_dist_df[order(length_dist_df$cycle_length), ]

length_dist_file <- file.path(output_dir, "cycle_length_distribution.csv")
write.csv(length_dist_df, length_dist_file, row.names = FALSE)
cat("Saved cycle length distribution to:", length_dist_file, "\n")

# Print summary statistics
cat("\n=== SUMMARY ===\n")
cat("Total cycles found (ALL):", format(total_cycles_all, big.mark = ","), "\n")
cat("Total cycles saved (sampled):", total_saved, "\n")
cat("\nCycles by SCC:\n")
print(table(cycle_summary$scc_id))
cat("\nCycle length distribution (ALL cycles):\n")
print(length_dist_df)

# Save a text summary
summary_txt <- file.path(output_dir, "extraction_summary.txt")
sink(summary_txt)
cat("=== CYCLE EXTRACTION SUMMARY ===\n\n")
cat("Exposure:", exposure_name, "\n")
cat("Outcome:", outcome_name, "\n")
cat("Max cycles to save per SCC:", MAX_CYCLES_TO_SAVE, "\n\n")
cat("Total cycles found (ALL):", format(total_cycles_all, big.mark = ","), "\n")
cat("Total cycles saved (sampled):", total_saved, "\n")
cat("Total nodes in cycles:", nrow(node_cycle_participation), "\n\n")
cat("Saved cycles by SCC:\n")
print(table(cycle_summary$scc_id))
cat("\nCycle length distribution (ALL cycles):\n")
print(length_dist_df)
cat("\n\nTop 20 nodes by cycle participation (based on ALL cycles):\n")
print(head(node_cycle_participation, 20))
cat("\n\nSampled cycles saved:\n")
print(cycle_summary)
sink()
cat("Saved extraction summary to:", summary_txt, "\n")

print_complete("Cycle Extraction and Subgraph Analysis")
cat("Cycle subgraphs saved to:", output_dir, "\n")
