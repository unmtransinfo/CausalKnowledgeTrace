# 01_parse_dagitty.R
# Parse graph input and convert to igraph object
#
# Output: data/{Exposure}_{Outcome}/s1_graph/
#   - parsed_graph.rds (igraph object)
#   - parsed_dag_raw.rds (raw parsed data; JSON or DAGitty)
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
library(jsonlite)

# ---- Argument handling (CLI + interactive safe) ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 2
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths using utility functions ----
<<<<<<< HEAD
input_dir <- get_input_dir()
output_dir <- get_s1_graph_dir(exposure_name, outcome_name, degree)

# ---- Find input file ----
input_file <- find_dagitty_file(exposure_name, outcome_name, degree)

if (is.null(input_file)) {
  stop("Could not find DAGitty R file for ", exposure_name, "_", outcome_name, "_degree_", degree, " in ", input_dir)
}

print_header(paste0("DAGitty Parser (Stage 1) - Degree ", degree), exposure_name, outcome_name)
cat("Input file:", input_file, "\n")
cat("Output directory:", output_dir, "\n\n")
=======
output_dir <- get_s1_graph_dir(exposure_name, outcome_name)

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0) y else x
}

normalize_node_type <- function(node_type) {
  node_type <- as.character(node_type %||% "regular")
  if (node_type %in% c("default", "", NA)) {
    return("regular")
  }
  node_type
}

parse_graph_json_file <- function(file_path) {
  cat("Reading Cytoscape JSON graph...\n")

  graph_json <- jsonlite::fromJSON(file_path, simplifyVector = FALSE)
  if (is.null(graph_json$elements) ||
      is.null(graph_json$elements$nodes) ||
      is.null(graph_json$elements$edges)) {
    stop("JSON graph must contain elements.nodes and elements.edges")
  }

  nodes <- graph_json$elements$nodes
  edges <- graph_json$elements$edges

  vertices <- data.frame(
    name = vapply(nodes, function(node) as.character(node$data$id %||% NA_character_), character(1)),
    label = vapply(nodes, function(node) as.character(node$data$label %||% node$data$id %||% NA_character_), character(1)),
    type = vapply(nodes, function(node) normalize_node_type(node$data$node_type %||% node$data$type), character(1)),
    stringsAsFactors = FALSE
  )

  if (any(is.na(vertices$name) | vertices$name == "")) {
    stop("Every JSON graph node must contain data.id")
  }

  if (length(edges) > 0) {
    edge_df <- data.frame(
      from = vapply(edges, function(edge) as.character(edge$data$source %||% NA_character_), character(1)),
      to = vapply(edges, function(edge) as.character(edge$data$target %||% NA_character_), character(1)),
      stringsAsFactors = FALSE
    )

    if (any(is.na(edge_df$from) | is.na(edge_df$to) | edge_df$from == "" | edge_df$to == "")) {
      stop("Every JSON graph edge must contain data.source and data.target")
    }
  } else {
    edge_df <- data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
  }

  cat("Parsed:", nrow(vertices), "nodes and", nrow(edge_df), "edges\n")
  cat("\nNode types:\n")
  print(table(vertices$type))
  cat("\nExposure nodes:", paste(vertices$name[vertices$type == "exposure"], collapse = ", "), "\n")
  cat("Outcome nodes:", paste(vertices$name[vertices$type == "outcome"], collapse = ", "), "\n")

  list(
    vertices = unique(vertices),
    edges = edge_df,
    raw_data = graph_json,
    input_format = "json_graph"
  )
}
>>>>>>> feature/django

parse_dagitty_file <- function(file_path) {
  cat("Reading legacy DAGitty file...\n")

  lines <- readLines(file_path)
  start_line <- grep("dag \\{", lines)
  end_line <- grep("^\\}\\s*\\')\\s*$|^\\}\\s*$", lines)

  if (length(start_line) == 0 || length(end_line) == 0) {
    stop("Could not find DAG definition in file")
  }

  dag_lines <- lines[(start_line[1] + 1):(end_line[1] - 1)]
  nodes_info <- list()
  edges_list <- list()

  for (line in dag_lines) {
    line <- trimws(line)
    if (nchar(line) == 0) next

    if (grepl("->", line, fixed = TRUE)) {
      edge_parts <- strsplit(line, " -> ", fixed = TRUE)[[1]]
      if (length(edge_parts) == 2) {
        edges_list <- append(edges_list, list(c(trimws(edge_parts[1]), trimws(edge_parts[2]))))
      }
    } else {
      node_type <- "regular"
      node_name <- line

      if (grepl("\\[exposure\\]", line)) {
        node_type <- "exposure"
        node_name <- gsub("\\s*\\[exposure\\]", "", line)
      } else if (grepl("\\[outcome\\]", line)) {
        node_type <- "outcome"
        node_name <- gsub("\\s*\\[outcome\\]", "", line)
      }

      nodes_info[[node_name]] <- node_type
    }
  }

  vertices <- data.frame(
    name = names(nodes_info),
    label = names(nodes_info),
    type = unlist(nodes_info),
    stringsAsFactors = FALSE
  )

  if (length(edges_list) > 0) {
    edge_matrix <- do.call(rbind, edges_list)
    edge_df <- data.frame(from = edge_matrix[, 1], to = edge_matrix[, 2], stringsAsFactors = FALSE)
  } else {
    edge_df <- data.frame(from = character(0), to = character(0), stringsAsFactors = FALSE)
  }

  cat("Parsed:", nrow(vertices), "nodes and", nrow(edge_df), "edges\n")

  list(
    vertices = vertices,
    edges = edge_df,
    raw_data = dag_lines,
    input_format = "legacy_dagitty"
  )
}

apply_expected_node_roles <- function(parsed_graph, exposure_name, outcome_name) {
  if (!any(parsed_graph$vertices$type == "exposure") && exposure_name %in% parsed_graph$vertices$name) {
    parsed_graph$vertices$type[parsed_graph$vertices$name == exposure_name] <- "exposure"
  }

  if (!any(parsed_graph$vertices$type == "outcome") && outcome_name %in% parsed_graph$vertices$name) {
    parsed_graph$vertices$type[parsed_graph$vertices$name == outcome_name] <- "outcome"
  }

  parsed_graph
}

create_igraph_from_parsed <- function(parsed_graph) {
  cat("\nCreating igraph object...\n")

  g <- graph_from_data_frame(
    d = parsed_graph$edges,
    directed = TRUE,
    vertices = parsed_graph$vertices
  )
  g <- set_graph_attr(g, "input_format", parsed_graph$input_format)

  cat("Created igraph with", vcount(g), "vertices and", ecount(g), "edges\n")
  g
}

# Main execution
tryCatch({

  json_input_file <- find_graph_json_file(exposure_name, outcome_name)
  dagitty_input_file <- if (is.null(json_input_file)) find_dagitty_file(exposure_name, outcome_name) else NULL

  if (!is.null(json_input_file)) {
    input_file <- json_input_file
    parsed_graph <- parse_graph_json_file(input_file)
  } else if (!is.null(dagitty_input_file)) {
    input_file <- dagitty_input_file
    parsed_graph <- parse_dagitty_file(input_file)
  } else {
    stop(
      "Could not find graph JSON for ", exposure_name, "_", outcome_name,
      " in ", get_graph_creation_result_dir(),
      " or a legacy DAGitty R file in ", get_input_dir()
    )
  }

  print_header("Graph Parser (Stage 1)", exposure_name, outcome_name)
  cat("Input file:", input_file, "\n")
  cat("Input format:", parsed_graph$input_format, "\n")
  cat("Output directory:", output_dir, "\n\n")

  parsed_graph <- apply_expected_node_roles(parsed_graph, exposure_name, outcome_name)

  # Create igraph object
  graph <- create_igraph_from_parsed(parsed_graph)

  # Extract exposure and outcome names from graph
  exposure_nodes <- parsed_graph$vertices$name[parsed_graph$vertices$type == "exposure"]
  outcome_nodes <- parsed_graph$vertices$name[parsed_graph$vertices$type == "outcome"]

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
    input_format = parsed_graph$input_format,
    parse_date = Sys.time(),
    n_nodes = vcount(graph),
    n_edges = ecount(graph)
  )
  saveRDS(metadata, file = file.path(output_dir, "metadata.rds"))

  # Save results
  saveRDS(graph, file = file.path(output_dir, "parsed_graph.rds"))
  saveRDS(parsed_graph, file = file.path(output_dir, "parsed_dag_raw.rds"))

  cat("\n=== RESULTS ===\n")
  cat("Output directory:", output_dir, "\n")
  cat("Files saved:\n")
  cat("  - parsed_graph.rds (igraph object)\n")
  cat("  - parsed_dag_raw.rds (raw parsed source data)\n")
  cat("  - metadata.rds (exposure/outcome info)\n")
  cat("\nGraph summary:\n")
  cat("  Input format:", parsed_graph$input_format, "\n")
  cat("  Exposure:", graph_exposure, "\n")
  cat("  Outcome:", graph_outcome, "\n")
  cat("  Nodes:", vcount(graph), "\n")
  cat("  Edges:", ecount(graph), "\n")

  print_complete("Graph Parser (Stage 1)")

}, error = function(e) {
  cat("ERROR:", e$message, "\n")
})
