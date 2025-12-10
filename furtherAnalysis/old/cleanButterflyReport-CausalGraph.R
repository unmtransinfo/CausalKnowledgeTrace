library(dagitty)

# Helper function: Check if all paths from V to Y go through A (true IV test)
is_instrumental_variable <- function(dag, v, exp, out) {
  # Must be ancestor of exposure
  if (!(v %in% ancestors(dag, exp))) {
    return(FALSE)
  }
  
  # Get all paths from v to out
  all_paths_v_to_y <- paths(dag, from = v, to = out)$paths
  
  # If no paths, not relevant
  if (length(all_paths_v_to_y) == 0) {
    return(FALSE)
  }
  
  # Check if ALL paths go through exposure
  all_through_exp <- all(sapply(all_paths_v_to_y, function(path) {
    grepl(exp, path, fixed = TRUE)
  }))
  
  return(all_through_exp)
}

# Main function
analyze_and_get_valid_sets <- function(dag) {
  exp <- exposures(dag)
  out <- outcomes(dag)
  expOut <- c(exp, out)
  
  if (length(exp) == 0 || length(out) == 0) {
    stop("DAG must have exposure and outcome defined")
  }
  
  # Get dagitty's adjustment sets
  dagitty_all_sets <- adjustmentSets(dag, exp, out, type = "all")
  dagitty_minimal_sets <- adjustmentSets(dag, exp, out, type = "minimal")
  variables_in_adjustment_sets <- unique(unlist(dagitty_all_sets))
  
  # Identify ancestors and descendants
  exp_ancestors <- setdiff(ancestors(dag, exp), exp)
  out_ancestors <- setdiff(ancestors(dag, out), out)
  exp_descendants <- descendants(dag, exp)
  out_descendants <- descendants(dag, out)
  
  # Identify mediators FIRST (needed for precision variable identification)
  raw_mediators <- setdiff(setdiff(intersect(exp_descendants, out_ancestors), out), exp)
  print("'Raw' Mediators")
  print(raw_mediators)
  
  # INSTRUMENTAL VARIABLES: Test each ancestor of A
  instrumentalVariables <- character(0)
  for (v in exp_ancestors) {
    if (is_instrumental_variable(dag, v, exp, out)) {
      instrumentalVariables <- c(instrumentalVariables, v)
    }
  }
  print("Instrumental Variables (all paths to Y go through A)")
  print(instrumentalVariables)
  
  # PRECISION VARIABLES: Ancestors of Y only (not A, not mediators, not exposure/outcome)
  # These affect Y directly but not through A
  raw_precision <- setdiff(out_ancestors, exp_ancestors)
  # Exclude the exposure itself and mediators
  precisionVariables <- setdiff(setdiff(raw_precision, expOut), raw_mediators)
  print("Precision Variables (affect Y only, not through A)")
  print(precisionVariables)
  
  # TRUE CONFOUNDERS: Ancestors of both that are NOT IVs and appear in adjustment sets
  raw_confounders <- intersect(exp_ancestors, out_ancestors)
  confounders <- setdiff(raw_confounders, instrumentalVariables)
  confounders <- intersect(confounders, variables_in_adjustment_sets)
  print("'Genuine' Confounders (create backdoor paths)")
  print(confounders)
  
  # Identify colliders
  raw_colliders <- setdiff(setdiff(intersect(exp_descendants, out_descendants), out), exp)
  print("'Raw' Colliders")
  print(raw_colliders)
  
  # Classify pure types
  colliders <- setdiff(setdiff(raw_colliders, raw_mediators), confounders)
  print("'Pure' Colliders")
  print(colliders)
  
  mediators <- setdiff(setdiff(raw_mediators, raw_colliders), confounders)
  print("'Pure' Mediators")
  print(mediators)
  
  # Multi-role variables
  colliderConfounders <- setdiff(intersect(confounders, raw_colliders), raw_mediators)
  print("'Multi-Role Variables:' Collider-Confounders")
  print(colliderConfounders)
  
  colliderMediators <- setdiff(intersect(raw_colliders, raw_mediators), confounders)
  print("'Multi-Role Variables:' Collider-Mediators")
  print(colliderMediators) 
  
  confounderMediators <- setdiff(intersect(confounders, raw_mediators), raw_colliders)
  print("'Multi-Role Variables:' Confounder-Mediators")
  print(confounderMediators) 
  
  confounderMediatorColliders <- intersect(raw_colliders, intersect(confounders, raw_mediators))
  print("'Multi-Role Variables:' Confounder-Mediator-Colliders")
  print(confounderMediatorColliders)
  
  # Identify butterfly bias variables
  butterfly_vars <- character(0)
  butterfly_parents <- list()
  non_butterfly_confounders <- confounders
  
  if (length(confounders) > 0) {
    for (v in confounders) {
      pars <- parents(dag, v)
      confounder_parents <- intersect(pars, confounders)
      
      if (length(confounder_parents) >= 2) {
        butterfly_vars <- c(butterfly_vars, v)
        butterfly_parents[[v]] <- confounder_parents
      }
    }
    
    if (length(butterfly_vars) > 0) {
      for (bfly in butterfly_vars) {
        non_butterfly_confounders <- setdiff(non_butterfly_confounders, 
                                             c(bfly, butterfly_parents[[bfly]]))
      }
    }
  }
  
  # Generate valid adjustment sets considering butterfly bias
  if (length(butterfly_vars) > 0) {
    butterfly_options <- list()
    
    for (bfly in butterfly_vars) {
      pars <- butterfly_parents[[bfly]]
      options <- list()
      options[[1]] <- pars
      
      if (length(pars) >= 2) {
        for (k in 1:(length(pars)-1)) {
          subsets <- combn(pars, k, simplify = FALSE)
          for (subset in subsets) {
            options <- append(options, list(c(bfly, subset)))
          }
        }
      }
      
      butterfly_options[[bfly]] <- options
    }
    
    option_indices <- expand.grid(lapply(butterfly_options, function(opts) 1:length(opts)))
    
    valid_sets <- list()
    for (i in 1:nrow(option_indices)) {
      adj_set <- non_butterfly_confounders
      for (j in 1:length(butterfly_vars)) {
        bfly <- butterfly_vars[j]
        option_idx <- option_indices[i, j]
        adj_set <- c(adj_set, butterfly_options[[bfly]][[option_idx]])
      }
      valid_sets[[i]] <- sort(unique(adj_set))
    }
    
    valid_sets <- unique(valid_sets)
    
  } else {
    if (length(confounders) > 0) {
      valid_sets <- list(sort(confounders))
    } else {
      valid_sets <- list(character(0))
    }
  }
  
  # Print results
  cat(strrep("=", 50), "\n", sep="")
  cat("BUTTERFLY BIAS ANALYSIS\n")
  cat(strrep("=", 50), "\n", sep="")
  cat("Exposure:", exp, "\n")
  cat("Outcome:", out, "\n\n")
  
  if (length(butterfly_vars) > 0) {
    cat("Butterfly bias variables detected:\n")
    for (bfly in butterfly_vars) {
      cat("  -", bfly, "(parents:", paste(butterfly_parents[[bfly]], collapse = ", "), ")\n")
    }
    cat("\n")
  } else {
    cat("No butterfly bias detected.\n\n")
  }
  
  cat("Valid minimal sufficient adjustment sets:\n")
  if (length(valid_sets) > 0 && length(valid_sets[[1]]) > 0) {
    for (i in seq_along(valid_sets)) {
      cat("  ", i, ". { ", paste(valid_sets[[i]], collapse = ", "), " }\n", sep="")
    }
  } else if (length(valid_sets) > 0 && length(valid_sets[[1]]) == 0) {
    cat("  { } (empty set - no adjustment needed)\n")
  }
  
  cat("\nNote: dagitty's adjustmentSets() returns:\n")
  for (i in seq_along(dagitty_minimal_sets)) {
    if (length(dagitty_minimal_sets[[i]]) > 0) {
      cat("  ", i, ". { ", paste(dagitty_minimal_sets[[i]], collapse = ", "), " }\n", sep="")
    } else {
      cat("  { } (empty set)\n", sep="")
    }
  }
  if (length(butterfly_vars) > 0) {
    cat("(dagitty's sets may cause butterfly bias)\n")
  }
  
  cat("\nVariables EXCLUDED from adjustment:\n")
  cat("  Instrumental Variables:", 
      ifelse(length(instrumentalVariables) > 0, paste(instrumentalVariables, collapse = ", "), "None"), "\n")
  cat("  Precision Variables:", 
      ifelse(length(precisionVariables) > 0, paste(precisionVariables, collapse = ", "), "None"), "\n")
  cat("  Mediators:", 
      ifelse(length(mediators) > 0, paste(mediators, collapse = ", "), "None"), "\n")
  cat("  Colliders:", 
      ifelse(length(colliders) > 0, paste(colliders, collapse = ", "), "None"), "\n")
  
  cat("\n")
  
  invisible(list(
    butterfly_vars = butterfly_vars,
    confounders = confounders,
    instrumental_variables = instrumentalVariables,
    precision_variables = precisionVariables,
    valid_minimal_sets = valid_sets
  ))
}

# Example with M (mediator):
dag <- dagitty('dag { 
  A [exposure] 
  Y [outcome] 
  A <- C1 -> Y
  A <- C2 -> Y
  A <- C3 -> Y 
  A <- C4 -> Y
  A <- C5 -> Y
  A <- C6 -> Y
  C4 -> C6 <- C5
  C1 -> C3 <- C2 
  A <- C7 <- C8 <- C9 -> C10 -> Y ###
  PR1 -> Y
  PR2 -> Y
  parent_of_IV -> IV -> A
  A -> M -> Y
  A -> Collider <- Y
  A -> Y 
}')

result <- analyze_and_get_valid_sets(dag)% 
