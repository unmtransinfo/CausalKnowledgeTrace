library(dagitty)

# causal analysis
# IV Report
# Clean
#### consolidation, 
# butterfly-bias Report (etc.)
# M-bias Report
# Data-on-Hand Assessment, Proxy Variables, ANANKE integration, Comparison with Reported Literature, Study Quality/Transferrability Assessment
#


# Main function using backdoor criterion for valid adjustment
analyze_mbias_and_get_valid_sets <- function(dag) {
  exp <- exposures(dag)
  out <- outcomes(dag)
  
  if (length(exp) == 0 || length(out) == 0) {
    stop("DAG must have exposure and outcome defined")
  }
  
  # Step 1: Use dagitty's backdoor criterion to find valid adjustment sets
  # This correctly identifies confounders (variables that create OPEN backdoor paths)
  minimal_sets <- adjustmentSets(dag, exp, out, type = "minimal")
  
  # Step 2: Identify M-bias structures
  # M-bias = colliders NOT in the adjustment set that would open biasing paths if conditioned
  all_nodes <- setdiff(names(dag), c(exp, out))  # Exclude exposure and outcome
  
  mbias_vars <- character(0)
  mbias_details <- list()
  
  for (v in all_nodes) {
    pars <- parents(dag, v)
    
    # Must be a collider (2+ parents)
    if (length(pars) >= 2) {
      # Check if v is in ANY minimal adjustment set
      in_adjustment_set <- any(sapply(minimal_sets, function(s) v %in% s))
      
      # M-bias: collider NOT in adjustment sets
      if (!in_adjustment_set) {
        # Verify it creates bias if adjusted (check if it opens a path)
        # Get all backdoor paths
        all_paths <- paths(dag, from = exp, to = out)$paths
        
        # Check if any path goes through this variable
        paths_through_v <- grep(v, all_paths, value = TRUE)
        
        if (length(paths_through_v) > 0) {
          mbias_vars <- c(mbias_vars, v)
          mbias_details[[v]] <- list(
            parents = pars,
            paths = paths_through_v
          )
        }
      }
    }
  }
  
  # Step 3: Extract confounders from minimal sets
  # Use the first minimal set (they should all block the same backdoor paths)
  if (length(minimal_sets) > 0) {
    valid_adjustment_set <- minimal_sets[[1]]
  } else {
    valid_adjustment_set <- character(0)
  }
  
  # Step 4: Print results
  print(paste(strrep("=", 50), "\n", sep=""))
  print(paste("M-BIAS ANALYSIS\n"))
  print(paste(strrep("=", 50), "\n", sep=""))
  print(paste("Exposure:", exp, "\n"))
  print(paste("Outcome:", out, "\n\n"))
  
  if (length(mbias_vars) > 0) {
    print(paste("M-bias variables detected (DO NOT ADJUST):\n"))
    for (mb in mbias_vars) {
      print(paste("  -", mb, "(parents:", paste(mbias_details[[mb]]$parents, collapse = ", "), ")\n"))
      print(paste("    Paths through", mb, ":", paste(mbias_details[[mb]]$paths, collapse = "; "), "\n"))
    }
    print(paste("\n"))
  } else {
    print(paste("No M-bias detected.\n\n"))
  }
  
  print(paste("Confounders (create OPEN backdoor paths):\n"))
  if (length(valid_adjustment_set) > 0) {
    print(paste(" ", paste(sort(valid_adjustment_set), collapse = ", "), "\n\n"))
  } else {
    print(paste("  None\n\n"))
  }
  
  print(paste("Valid minimal sufficient adjustment set(s):\n"))
  if (length(minimal_sets) > 0) {
    for (i in seq_along(minimal_sets)) {
      print(paste("  ", i, ". { ", paste(sort(minimal_sets[[i]]), collapse = ", "), " }\n", sep=""))
    }
  } else {
    print(paste("  { } (empty set - no adjustment needed)\n"))
  }
  
  print(paste("\n"))
  
  # Verify paths
  print(paste("Path verification:\n"))
  print(paste("Without adjustment:\n"))
  paths_no_adj <- paths(dag, from = exp, to = out)
  print(paste("  Open paths:", sum(paths_no_adj$open), "/", length(paths_no_adj$open), "\n"))
  
  if (length(valid_adjustment_set) > 0) {
    print(paste("\nWith valid adjustment (", paste(sort(valid_adjustment_set), collapse = ", "), "):\n", sep=""))
    paths_with_adj <- paths(dag, from = exp, to = out, Z = valid_adjustment_set)
    print(paste("  Open paths:", sum(paths_with_adj$open), "/", length(paths_with_adj$open), "\n"))
    print(paste("  (Only causal path should be open)\n"))
  }
  
  if (length(mbias_vars) > 0) {
    print(paste("\nIf incorrectly adjusting for M-bias variable (", mbias_vars[1], "):\n", sep=""))
    paths_with_mbias <- paths(dag, from = exp, to = out, Z = c(valid_adjustment_set, mbias_vars[1]))
    print(paste("  Open paths:", sum(paths_with_mbias$open), "/", length(paths_with_mbias$open), "\n"))
    print(paste("  WARNING: Adjusting for M-bias opens biasing paths!\n"))
  }
  
  print(paste("\n"))
  
  # Return results
  invisible(list(
    mbias_vars = mbias_vars,
    mbias_details = mbias_details,
    confounders = valid_adjustment_set,
    valid_adjustment_sets = minimal_sets
  ))
}

# Example with M-bias:
dag <- dagitty('dag { 
  A [exposure] 
  Y [outcome] 
  C1 -> C3 <- C2
  C4 -> C6 <- C5 
  A <- C7 -> Y
  A <- C8 -> Y 
  C1 -> A
  C4 -> A
  C2 -> Y
  C5 -> Y 
  A -> Y 
}')

# Run analysis
result <- analyze_mbias_and_get_valid_sets(dag)%     
print(result)
                                      
