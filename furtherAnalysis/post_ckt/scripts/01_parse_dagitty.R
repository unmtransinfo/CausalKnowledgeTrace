# 01_parse_dagitty.R
# Parse DAGitty R script and convert to igraph object

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
  default_exposure = "Depression",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
input_dir <- get_input_dir()
base_output_dir <- get_parsed_graphs_dir()

# ---- Find input file ----
input_file <- find_dagitty_file(exposure_name, outcome_name)

if (is.null(input_file)) {
  stop("Could not find DAGitty R file for ", exposure_name, "_", outcome_name, " in ", input_dir)
}

print_header("DAGitty Parser", exposure_name, outcome_name)
cat("Input file:", input_file, "\n")

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

  # Extract exposure and outcome names
  exposure_nodes <- names(parsed_dag$nodes)[parsed_dag$nodes == "exposure"]
  outcome_nodes <- names(parsed_dag$nodes)[parsed_dag$nodes == "outcome"]

  if (length(exposure_nodes) == 0 || length(outcome_nodes) == 0) {
    stop("Could not find exposure and/or outcome nodes in the graph")
  }

  # Use first exposure and outcome if multiple exist
  exposure_name <- exposure_nodes[1]
  outcome_name <- outcome_nodes[1]

  if (length(exposure_nodes) > 1) {
    cat("Warning: Multiple exposure nodes found, using:", exposure_name, "\n")
  }
  if (length(outcome_nodes) > 1) {
    cat("Warning: Multiple outcome nodes found, using:", outcome_name, "\n")
  }

  # Create subdirectory name using utility function
  subdir_name <- get_subdir_name(exposure_name, outcome_name)
  output_dir <- file.path(base_output_dir, subdir_name)

  # Create output directory if it doesn't exist
  ensure_dir(output_dir)

  # Save metadata
  metadata <- list(
    exposure = exposure_name,
    outcome = outcome_name,
    input_file = input_file,
    parse_date = Sys.time(),
    n_nodes = vcount(graph),
    n_edges = ecount(graph)
  )
  saveRDS(metadata, file = file.path(output_dir, "metadata.rds"))

  # Save results
  saveRDS(graph, file = file.path(output_dir, "parsed_graph.rds"))
  saveRDS(parsed_dag, file = file.path(output_dir, "parsed_dag_raw.rds"))

  cat("\nResults saved to:", output_dir, "\n")
  cat("- parsed_graph.rds (igraph object)\n")
  cat("- parsed_dag_raw.rds (raw parsed data)\n")
  cat("- metadata.rds (exposure/outcome info)\n")
  cat("\nExposure:", exposure_name, "\n")
  cat("Outcome:", outcome_name, "\n")

  print_complete("DAGitty Parser")

}, error = function(e) {
  cat("ERROR:", e$message, "\n")
})