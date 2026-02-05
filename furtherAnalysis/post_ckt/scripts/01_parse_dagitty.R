# 01_parse_dagitty.R
# Parse DAGitty R script and convert to igraph object
#
# Output: data/{Exposure}_{Outcome}/s1_graph/
#   - parsed_graph.rds (igraph object)
#   - parsed_dag_raw.rds (raw parsed data)
#   - metadata.rds (exposure/outcome info)

# ---- Load configuration and utilities ----
# Detect script directory for both interactive and Rscript modes
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
library(stringr)

# ---- Argument handling (CLI + interactive safe) ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
input_dir <- get_input_dir()
output_dir <- get_s1_graph_dir(exposure_name, outcome_name)

# ---- Find input file ----
input_file <- find_dagitty_file(exposure_name, outcome_name)

if (is.null(input_file)) {
  stop("Could not find DAGitty R file for ", exposure_name, "_", outcome_name, " in ", input_dir)
}

print_header("DAGitty Parser (Stage 1)", exposure_name, outcome_name)
cat("Input file:", input_file, "\n")
cat("Output directory:", output_dir, "\n\n")

# Function to parse DAGitty format
parse_dagitty_file <- function(file_path) {
  cat("Reading DAGitty file...\n")

  # Read the entire file
  lines <- readLines(file_path)

  # Find the DAG definition (between 'dag {' and '}')
  start_line <- grep("dag \\{", lines)
  # Look for closing brace - could be "}')$" or just "^}$"
  end_line <- grep("^\\}\\s*\\')\\s*$|^\\}\\s*$", lines)

  if (length(start_line) == 0 || length(end_line) == 0) {
    stop("Could not find DAG definition in file")
  }

  # Use the first match for start and end
  start_line <- start_line[1]
  end_line <- end_line[1]

  # Extract DAG content
  dag_lines <- lines[(start_line + 1):(end_line - 1)]

  cat("Found", length(dag_lines), "lines of DAG definition\n")

  # Parse nodes and edges
  nodes_info <- list()
  edges_list <- list()

  for (line in dag_lines) {
    line <- trimws(line)
    if (nchar(line) == 0) next

    # Check if line contains an arrow (edge)
    if (grepl("->", line)) {
      # Parse edge: "node1 -> node2"
      edge_parts <- strsplit(line, " -> ")[[1]]
      if (length(edge_parts) == 2) {
        from_node <- trimws(edge_parts[1])
        to_node <- trimws(edge_parts[2])
        edges_list <- append(edges_list, list(c(from_node, to_node)))
      }
    } else {
      # Parse node: "node_name [exposure]" or just "node_name"
      node_line <- line
      node_type <- "regular"

      # Check for annotations
      if (grepl("\\[exposure\\]", node_line)) {
        node_type <- "exposure"
        node_name <- gsub("\\s*\\[exposure\\]", "", node_line)
      } else if (grepl("\\[outcome\\]", node_line)) {
        node_type <- "outcome"
        node_name <- gsub("\\s*\\[outcome\\]", "", node_line)
      } else {
        node_name <- node_line
      }

      nodes_info[[node_name]] <- node_type
    }
  }

  # Create edge matrix
  if (length(edges_list) > 0) {
    edge_matrix <- do.call(rbind, edges_list)
  } else {
    edge_matrix <- matrix(nrow = 0, ncol = 2)
  }

  cat("Parsed:", length(nodes_info), "nodes and", nrow(edge_matrix), "edges\n")

  # Print summary
  cat("\nNode types:\n")
  node_types <- table(unlist(nodes_info))
  print(node_types)

  cat("\nExposure nodes:", names(nodes_info)[nodes_info == "exposure"], "\n")
  cat("Outcome nodes:", names(nodes_info)[nodes_info == "outcome"], "\n")

  return(list(
    nodes = nodes_info,
    edges = edge_matrix,
    raw_lines = dag_lines
  ))
}


# Function to create igraph object
create_igraph_from_parsed <- function(parsed_dag) {

  cat("\nCreating igraph object...\n")

  # Get all unique node names
  all_nodes <- unique(c(names(parsed_dag$nodes),
                        as.vector(parsed_dag$edges)))

  # Create igraph
  if (nrow(parsed_dag$edges) > 0) {
    g <- graph_from_edgelist(parsed_dag$edges, directed = TRUE)
  } else {
    g <- make_empty_graph(n = length(all_nodes), directed = TRUE)
    V(g)$name <- all_nodes
  }

  # Add node attributes
  for (node_name in names(parsed_dag$nodes)) {
    if (node_name %in% V(g)$name) {
      V(g)[node_name]$type <- parsed_dag$nodes[[node_name]]
    }
  }

  # Add type for nodes not explicitly defined
  for (v in V(g)) {
    if (is.null(V(g)[v]$type) || is.na(V(g)[v]$type)) {
      V(g)[v]$type <- "regular"
    }
  }

  cat("Created igraph with", vcount(g), "vertices and", ecount(g), "edges\n")

  return(g)
}

# Main execution
tryCatch({

  # Parse the DAGitty file
  parsed_dag <- parse_dagitty_file(input_file)

  # Create igraph object
  graph <- create_igraph_from_parsed(parsed_dag)

  # Extract exposure and outcome names from graph
  exposure_nodes <- names(parsed_dag$nodes)[parsed_dag$nodes == "exposure"]
  outcome_nodes <- names(parsed_dag$nodes)[parsed_dag$nodes == "outcome"]

  if (length(exposure_nodes) == 0 || length(outcome_nodes) == 0) {
    stop("Could not find exposure and/or outcome nodes in the graph")
  }

  # Use first exposure and outcome if multiple exist
  graph_exposure <- exposure_nodes[1]
  graph_outcome <- outcome_nodes[1]

  if (length(exposure_nodes) > 1) {
    cat("Warning: Multiple exposure nodes found, using:", graph_exposure, "\n")
  }
  if (length(outcome_nodes) > 1) {
    cat("Warning: Multiple outcome nodes found, using:", graph_outcome, "\n")
  }

  # Create output directory
  ensure_dir(output_dir)

  # Save metadata
  metadata <- list(
    exposure = graph_exposure,
    outcome = graph_outcome,
    input_file = input_file,
    parse_date = Sys.time(),
    n_nodes = vcount(graph),
    n_edges = ecount(graph)
  )
  saveRDS(metadata, file = file.path(output_dir, "metadata.rds"))

  # Save results
  saveRDS(graph, file = file.path(output_dir, "parsed_graph.rds"))
  saveRDS(parsed_dag, file = file.path(output_dir, "parsed_dag_raw.rds"))

  cat("\n=== RESULTS ===\n")
  cat("Output directory:", output_dir, "\n")
  cat("Files saved:\n")
  cat("  - parsed_graph.rds (igraph object)\n")
  cat("  - parsed_dag_raw.rds (raw parsed data)\n")
  cat("  - metadata.rds (exposure/outcome info)\n")
  cat("\nGraph summary:\n")
  cat("  Exposure:", graph_exposure, "\n")
  cat("  Outcome:", graph_outcome, "\n")
  cat("  Nodes:", vcount(graph), "\n")
  cat("  Edges:", ecount(graph), "\n")

  print_complete("DAGitty Parser (Stage 1)")

}, error = function(e) {
  cat("ERROR:", e$message, "\n")
})
