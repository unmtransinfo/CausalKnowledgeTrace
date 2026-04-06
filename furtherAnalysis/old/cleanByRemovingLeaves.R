library(dagitty)
library(igraph)

removeLeaves <- function(g, Exposures, Outcomes) {
    # Starting with dagitty object 'g'
    dag <- g
  
  # Extract edges from dagitty
  edges_df <- as.data.frame(dagitty::edges(dag))
  
  # Get all nodes
  all_nodes <- names(dag)
  
  # Create a data frame of nodes
  nodes_df <- data.frame(name = all_nodes)
  
  # Convert to igraph
  ig <- graph_from_data_frame(edges_df[, c("v", "w")],
                              directed = TRUE,
                              vertices = nodes_df)
  
  # Remove self-loops (zero-length arrows)
  ig <- simplify(ig, remove.loops = TRUE, remove.multiple = FALSE)
  
  print(paste("Starting with", vcount(ig), "vertices and", ecount(ig), "edges"))
  
  # Iteratively remove nodes with total degree = 1
  iteration <- 0
  repeat {
    iteration <- iteration + 1
    
    if (vcount(ig) == 0) break
    
    # Get total degree (in + out)
    total_deg <- degree(ig, mode = "all")
    
    # Find nodes with total degree = 1
    nodes_to_remove <- which(total_deg == 1)
    
    if (length(nodes_to_remove) == 0) break
    
    cat("Iteration", iteration, ": Removing", length(nodes_to_remove), "nodes with degree 1\n")
    
    ig <- delete_vertices(ig, nodes_to_remove)
  }
  
  print(paste("Final graph has", vcount(ig), "vertices and", ecount(ig), "edges"))
  
  # Convert back to dagitty
  if (vcount(ig) > 0 && ecount(ig) > 0) {
    edge_list <- as_edgelist(ig)
    dag_edges <- paste(edge_list[,1], "->", edge_list[,2])
    dag_back <- dagitty(paste0("dag {", paste(dag_edges, collapse = "; "), "}"))
  } else {
    dag_back <- dagitty("dag {}")
  }
  
  # Verify
  print(paste("Result: graph with", vcount(ig), "nodes"))
  
  #my_dag <- dagitty("dag {mdd -> alz; osa -> mdd; osa -> alz}")
  #Exposures <- "alz"
  #Outcomes <- "mdd"
  # Set "x" as the exposure
  my_dag_with_exposure <- setVariableStatus(dag_back, status = "exposure", value = Exposures)
  # Set "y" as the outcome
  my_dag_with_exposure_outcome <- setVariableStatus(my_dag_with_exposure, status = "outcome", value = Outcomes)
  #print(my_dag_with_exposure_outcome)
  dag_back <- my_dag_with_exposure_outcome
  
  print(dag_back)
  dag_original <- dag
  dag <- dag_back
  }
