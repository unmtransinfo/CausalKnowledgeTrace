library(dagitty)
library(compiler)

# Helper function: Check if all paths from V to Y go through A (true IV test)
is_instrumental_variable_uncompiled <- function(dag, v, exp, out) {
  cat("  Testing if", v, "is an instrumental variable...\n")
  
  # Must be ancestor of exposure
  if (!(v %in% ancestors(dag, exp))) {
    cat("    ->", v, "is NOT an ancestor of", exp, "\n")
    return(FALSE)
  }
  
  # Get all paths from v to out
  all_paths_v_to_y <- paths(dag, from = v, to = out)$paths
  
  # If no paths, not relevant
  if (length(all_paths_v_to_y) == 0) {
    cat("    -> No paths from", v, "to", out, "\n")
    return(FALSE)
  }
  
  cat("    -> Paths from", v, "to", out, ":\n")
  for (p in all_paths_v_to_y) {
    cat("       ", p, "\n")
  }
  
  # Check if ALL paths go through exposure
  all_through_exp <- all(sapply(all_paths_v_to_y, function(path) {
    grepl(exp, path, fixed = TRUE)
  }))
  
  if (all_through_exp) {
    cat("    -> ALL paths go through", exp, "- this IS an IV!\n")
  } else {
    cat("    -> Some paths DON'T go through", exp, "- NOT an IV\n")
  }
  
  return(all_through_exp)
}

# Compile the helper function
is_instrumental_variable <- cmpfun(is_instrumental_variable_uncompiled)

# Main function
analyze_and_get_valid_sets_uncompiled <- function(dag) {
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("STARTING CAUSAL ANALYSIS\n")
  cat(strrep("=", 70), "\n\n")
  
  exp <- exposures(dag)
  out <- outcomes(dag)
  expOut <- c(exp, out)
  
  cat("Exposure:", exp, "\n")
  cat("Outcome:", out, "\n\n")
  
  if (length(exp) == 0 || length(out) == 0) {
    stop("DAG must have exposure and outcome defined")
  }
  
  # Get dagitty's adjustment sets
  cat(strrep("-", 70), "\n")
  cat("STEP 0: Getting dagitty's adjustment sets (for comparison)\n")
  cat(strrep("-", 70), "\n")
  dagitty_all_sets <- adjustmentSets(dag, exp, out, type = "all")
  dagitty_minimal_sets <- adjustmentSets(dag, exp, out, type = "minimal")
  variables_in_adjustment_sets <- unique(unlist(dagitty_all_sets))
  
  cat("Variables appearing in dagitty's adjustment sets:", 
      ifelse(length(variables_in_adjustment_sets) > 0, 
             paste(variables_in_adjustment_sets, collapse = ", "), 
             "None"), "\n\n")
  
  # Identify ancestors and descendants
  cat(strrep("-", 70), "\n")
  cat("STEP 1: Identifying ancestors and descendants\n")
  cat(strrep("-", 70), "\n")
  exp_ancestors <- setdiff(ancestors(dag, exp), exp)
  out_ancestors <- setdiff(ancestors(dag, out), out)
  exp_descendants <- descendants(dag, exp)
  out_descendants <- descendants(dag, out)
  
  cat("Ancestors of", exp, ":", paste(exp_ancestors, collapse = ", "), "\n")
  cat("Ancestors of", out, ":", paste(out_ancestors, collapse = ", "), "\n")
  cat("Descendants of", exp, ":", paste(exp_descendants, collapse = ", "), "\n")
  cat("Descendants of", out, ":", paste(out_descendants, collapse = ", "), "\n\n")
  
  # Identify mediators FIRST
  cat(strrep("-", 70), "\n")
  cat("STEP 2: Identifying mediators (A -> M -> Y)\n")
  cat(strrep("-", 70), "\n")
  raw_mediators <- setdiff(setdiff(intersect(exp_descendants, out_ancestors), out), exp)
  cat("Raw mediators (descendants of A AND ancestors of Y):", 
      ifelse(length(raw_mediators) > 0, paste(raw_mediators, collapse = ", "), "None"), "\n\n")
  
  # INSTRUMENTAL VARIABLES
  cat(strrep("-", 70), "\n")
  cat("STEP 3: Identifying instrumental variables\n")
  cat(strrep("-", 70), "\n")
  cat("Testing each ancestor of", exp, "to see if ALL paths to", out, "go through", exp, "\n\n")
  
  instrumentalVariables <- character(0)
  for (v in exp_ancestors) {
    if (is_instrumental_variable(dag, v, exp, out)) {
      instrumentalVariables <- c(instrumentalVariables, v)
    }
  }
  cat("\nFinal instrumental variables:", 
      ifelse(length(instrumentalVariables) > 0, paste(instrumentalVariables, collapse = ", "), "None"), "\n\n")
  
  # PRECISION VARIABLES
  cat(strrep("-", 70), "\n")
  cat("STEP 4: Identifying precision variables (affect Y only)\n")
  cat(strrep("-", 70), "\n")
  raw_precision <- setdiff(out_ancestors, exp_ancestors)
  cat("Variables that are ancestors of Y but NOT A:", 
      ifelse(length(raw_precision) > 0, paste(raw_precision, collapse = ", "), "None"), "\n")
  
  # Exclude exposure/outcome and mediators
  precisionVariables <- setdiff(setdiff(raw_precision, expOut), raw_mediators)
  cat("After excluding exposure/outcome and mediators:", 
      ifelse(length(precisionVariables) > 0, paste(precisionVariables, collapse = ", "), "None"), "\n\n")
  
  # TRUE CONFOUNDERS
  cat(strrep("-", 70), "\n")
  cat("STEP 5: Identifying true confounders (create backdoor paths)\n")
  cat(strrep("-", 70), "\n")
  raw_confounders <- intersect(exp_ancestors, out_ancestors)
  cat("Raw confounders (ancestors of both A and Y):", 
      ifelse(length(raw_confounders) > 0, paste(raw_confounders, collapse = ", "), "None"), "\n")
  
  confounders <- setdiff(raw_confounders, instrumentalVariables)
  cat("After excluding instrumental variables:", 
      ifelse(length(confounders) > 0, paste(confounders, collapse = ", "), "None"), "\n")
  
  confounders <- intersect(confounders, variables_in_adjustment_sets)
  cat("Final confounders (appear in adjustment sets):", 
      ifelse(length(confounders) > 0, paste(confounders, collapse = ", "), "None"), "\n\n")
  
  # Identify colliders
  cat(strrep("-", 70), "\n")
  cat("STEP 6: Identifying colliders (common effects)\n")
  cat(strrep("-", 70), "\n")
  raw_colliders <- setdiff(setdiff(intersect(exp_descendants, out_descendants), out), exp)
  cat("Raw colliders (descendants of both A and Y):", 
      ifelse(length(raw_colliders) > 0, paste(raw_colliders, collapse = ", "), "None"), "\n\n")
  
  # Classify pure types
  cat(strrep("-", 70), "\n")
  cat("STEP 7: Classifying pure variable types\n")
  cat(strrep("-", 70), "\n")
  
  colliders <- setdiff(setdiff(raw_colliders, raw_mediators), confounders)
  cat("Pure colliders:", 
      ifelse(length(colliders) > 0, paste(colliders, collapse = ", "), "None"), "\n")
  
  mediators <- setdiff(setdiff(raw_mediators, raw_colliders), confounders)
  cat("Pure mediators:", 
      ifelse(length(mediators) > 0, paste(mediators, collapse = ", "), "None"), "\n\n")
  
  # Multi-role variables
  cat(strrep("-", 70), "\n")
  cat("STEP 8: Identifying multi-role variables\n")
  cat(strrep("-", 70), "\n")
  
  colliderConfounders <- setdiff(intersect(confounders, raw_colliders), raw_mediators)
  cat("Collider-Confounders:", 
      ifelse(length(colliderConfounders) > 0, paste(colliderConfounders, collapse = ", "), "None"), "\n")
  
  colliderMediators <- setdiff(intersect(raw_colliders, raw_mediators), confounders)
  cat("Collider-Mediators:", 
      ifelse(length(colliderMediators) > 0, paste(colliderMediators, collapse = ", "), "None"), "\n")
  
  confounderMediators <- setdiff(intersect(confounders, raw_mediators), raw_colliders)
  cat("Confounder-Mediators:", 
      ifelse(length(confounderMediators) > 0, paste(confounderMediators, collapse = ", "), "None"), "\n")
  
  confounderMediatorColliders <- intersect(raw_colliders, intersect(confounders, raw_mediators))
  cat("Confounder-Mediator-Colliders:", 
      ifelse(length(confounderMediatorColliders) > 0, paste(confounderMediatorColliders, collapse = ", "), "None"), "\n\n")
  
  # Identify butterfly bias variables
  cat(strrep("-", 70), "\n")
  cat("STEP 9: Identifying butterfly bias structures\n")
  cat(strrep("-", 70), "\n")
  cat("Looking for confounders that have 2+ confounder parents (collider+confounder)\n\n")
  
  butterfly_vars <- character(0)
  butterfly_parents <- list()
  non_butterfly_confounders <- confounders
  
  if (length(confounders) > 0) {
    for (v in confounders) {
      pars <- parents(dag, v)
      confounder_parents <- intersect(pars, confounders)
      
      cat("Checking", v, "- parents:", paste(pars, collapse = ", "), 
          "- confounder parents:", paste(confounder_parents, collapse = ", "), "\n")
      
      if (length(confounder_parents) >= 2) {
        cat("  -> BUTTERFLY BIAS DETECTED:", v, "has", length(confounder_parents), "confounder parents!\n")
        butterfly_vars <- c(butterfly_vars, v)
        butterfly_parents[[v]] <- confounder_parents
      }
    }
    
    if (length(butterfly_vars) > 0) {
      cat("\nRemoving butterfly variables and their parents from simple confounders list\n")
      for (bfly in butterfly_vars) {
        non_butterfly_confounders <- setdiff(non_butterfly_confounders, 
                                             c(bfly, butterfly_parents[[bfly]]))
      }
    }
  }
  
  cat("\nButterfly variables:", 
      ifelse(length(butterfly_vars) > 0, paste(butterfly_vars, collapse = ", "), "None"), "\n")
  cat("Non-butterfly confounders:", 
      ifelse(length(non_butterfly_confounders) > 0, paste(non_butterfly_confounders, collapse = ", "), "None"), "\n\n")
  
  # Generate valid adjustment sets
  cat(strrep("-", 70), "\n")
  cat("STEP 10: Generating valid adjustment sets\n")
  cat(strrep("-", 70), "\n")
  
  if (length(butterfly_vars) > 0) {
    cat("Butterfly bias detected - generating multiple adjustment strategies\n\n")
    butterfly_options <- list()
    
    for (bfly in butterfly_vars) {
      pars <- butterfly_parents[[bfly]]
      options <- list()
      
      cat("For butterfly variable", bfly, "with parents", paste(pars, collapse = ", "), ":\n")
      
      # Option 1: Adjust for all parents
      options[[1]] <- pars
      cat("  Option 1: Adjust for parents { ", paste(pars, collapse = ", "), " }\n", sep="")
      
      # Option 2+: Adjust for butterfly with subsets of parents
      if (length(pars) >= 2) {
        opt_num <- 2
        for (k in 1:(length(pars)-1)) {
          subsets <- combn(pars, k, simplify = FALSE)
          for (subset in subsets) {
            options <- append(options, list(c(bfly, subset)))
            cat("  Option", opt_num, ": Adjust for { ", paste(c(bfly, subset), collapse = ", "), " }\n", sep="")
            opt_num <- opt_num + 1
          }
        }
      }
      
      butterfly_options[[bfly]] <- options
      cat("\n")
    }
    
    cat("Generating all combinations across butterfly variables...\n")
    option_indices <- expand.grid(lapply(butterfly_options, function(opts) 1:length(opts)))
    cat("Total combinations:", nrow(option_indices), "\n\n")
    
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
    
    # Remove duplicates
    valid_sets <- unique(valid_sets)
    cat("After removing duplicates:", length(valid_sets), "unique adjustment sets\n\n")
    
  } else {
    cat("No butterfly bias - using simple confounder adjustment\n\n")
    if (length(confounders) > 0) {
      valid_sets <- list(sort(confounders))
    } else {
      valid_sets <- list(character(0))
    }
  }
  
  # Print final results
  cat("\n")
  cat(strrep("=", 70), "\n")
  cat("FINAL RESULTS\n")
  cat(strrep("=", 70), "\n\n")
  
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
  cat(strrep("=", 70), "\n\n")
  
  invisible(list(
    butterfly_vars = butterfly_vars,
    butterfly_parents = butterfly_parents,
    confounders = confounders,
    instrumental_variables = instrumentalVariables,
    precision_variables = precisionVariables,
    valid_minimal_sets = valid_sets
  ))
}

# Compile the main function for faster execution
cat("Compiling functions for optimized performance...\n")
analyze_and_get_valid_sets <- cmpfun(analyze_and_get_valid_sets_uncompiled)
cat("Functions compiled successfully!\n\n")

# Toy Example with M (mediator):
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
  A <- C7 <- C8 <- C9 -> C10 -> Y
  PR1 -> Y
  PR2 -> Y
  IV -> A
  A -> M -> Y
  A -> Collider <- Y
  A -> Y 
}')

# Run with compiled version (faster!)
result <- analyze_and_get_valid_sets(dag)%  
