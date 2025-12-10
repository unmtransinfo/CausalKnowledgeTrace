library(dagitty)

# ---- Helper utilities 

# Ensure the DAG declares exactly one exposure and one outcome for clarity.
validate_exposure_outcome <- function(dag) {
  exp <- exposures(dag)
  out <- outcomes(dag)
  
  if (length(exp) == 0 || length(out) == 0) {
    stop("DAG must have exposure and outcome defined")
  }
  if (length(exp) > 1 || length(out) > 1) {
    stop("Provide exactly one exposure and one outcome for this report")
  }
  
  list(exp = exp, out = out)
}

# Check whether every path from the candidate to the outcome flows through the
# exposure (instrumental variable test).
is_instrumental_variable <- function(dag, candidate, exp, out) {
  if (!(candidate %in% ancestors(dag, exp))) {
    return(FALSE)
  }
  
  all_paths <- paths(dag, from = candidate, to = out)$paths
  if (length(all_paths) == 0) {
    return(FALSE)
  }
  
  all(sapply(all_paths, function(path) grepl(exp, path, fixed = TRUE)))
}

format_set <- function(values) {
  if (length(values) == 0) {
    "{ }"
  } else {
    paste0("{ ", paste(sort(unique(values)), collapse = ", "), " }")
  }
}

# ---- Role identification 

identify_variable_roles <- function(dag) {
  eo <- validate_exposure_outcome(dag)
  exp <- eo$exp
  out <- eo$out
  exp_out <- c(exp, out)
  
  # All dagitty minimal adjustment sets for later intersection
  dagitty_minimal_sets <- adjustmentSets(dag, exp, out, type = "minimal")
  variables_in_adjustment_sets <- unique(unlist(adjustmentSets(dag, exp, out, type = "all")))
  
  exp_ancestors <- setdiff(ancestors(dag, exp), exp)
  out_ancestors <- setdiff(ancestors(dag, out), out)
  exp_descendants <- descendants(dag, exp)
  out_descendants <- descendants(dag, out)
  
  raw_mediators <- setdiff(intersect(exp_descendants, out_ancestors), exp_out)
  raw_colliders <- setdiff(intersect(exp_descendants, out_descendants), exp_out)
  
  instrumental_variables <- vapply(exp_ancestors, function(v) {
    is_instrumental_variable(dag, v, exp, out)
  }, logical(1))
  instrumental_variables <- exp_ancestors[instrumental_variables]
  
  raw_precision <- setdiff(out_ancestors, exp_ancestors)
  precision_variables <- setdiff(setdiff(raw_precision, exp_out), raw_mediators)
  
  raw_confounders <- intersect(exp_ancestors, out_ancestors)
  confounders <- intersect(setdiff(raw_confounders, instrumental_variables),
                           variables_in_adjustment_sets)
  
  colliders <- setdiff(setdiff(raw_colliders, raw_mediators), confounders)
  mediators <- setdiff(setdiff(raw_mediators, raw_colliders), confounders)
  
  list(
    exp = exp,
    out = out,
    dagitty_minimal_sets = dagitty_minimal_sets,
    instrumental_variables = instrumental_variables,
    precision_variables = precision_variables,
    confounders = confounders,
    raw_colliders = raw_colliders,
    raw_mediators = raw_mediators,
    colliders = colliders,
    mediators = mediators
  )
}

# ---- Butterfly bias analysis 

analyze_butterfly_bias <- function(dag) {
  roles <- identify_variable_roles(dag)
  
  butterfly_vars <- character(0)
  butterfly_parents <- list()
  non_butterfly_confounders <- roles$confounders
  
  if (length(roles$confounders) > 0) {
    for (v in roles$confounders) {
      pars <- intersect(parents(dag, v), roles$confounders)
      if (length(pars) >= 2) {
        butterfly_vars <- c(butterfly_vars, v)
        butterfly_parents[[v]] <- pars
      }
    }
    
    if (length(butterfly_vars) > 0) {
      for (bfly in butterfly_vars) {
        non_butterfly_confounders <- setdiff(non_butterfly_confounders,
                                             c(bfly, butterfly_parents[[bfly]]))
      }
    }
  }
  
  # Build valid adjustment sets that avoid butterfly bias
  if (length(butterfly_vars) > 0) {
    butterfly_options <- lapply(butterfly_vars, function(bfly) {
      pars <- butterfly_parents[[bfly]]
      options <- list(pars)
      
      if (length(pars) >= 2) {
        for (k in 1:(length(pars) - 1)) {
          subsets <- combn(pars, k, simplify = FALSE)
          for (subset in subsets) {
            options <- append(options, list(c(bfly, subset)))
          }
        }
      }
      
      options
    })
    names(butterfly_options) <- butterfly_vars
    
    option_indices <- expand.grid(lapply(butterfly_options, function(opts) seq_along(opts)))
    valid_sets <- vector("list", nrow(option_indices))
    
    for (i in seq_len(nrow(option_indices))) {
      adj_set <- non_butterfly_confounders
      for (j in seq_along(butterfly_vars)) {
        bfly <- butterfly_vars[j]
        option_idx <- option_indices[i, j]
        adj_set <- c(adj_set, butterfly_options[[bfly]][[option_idx]])
      }
      valid_sets[[i]] <- sort(unique(adj_set))
    }
    
    valid_sets <- unique(valid_sets)
  } else if (length(roles$confounders) > 0) {
    valid_sets <- list(sort(roles$confounders))
  } else {
    valid_sets <- list(character(0))
  }
  
  list(
    roles = roles,
    butterfly_vars = butterfly_vars,
    butterfly_parents = butterfly_parents,
    valid_sets = valid_sets,
    non_butterfly_confounders = non_butterfly_confounders
  )
}

# ---- M-bias analysis ------------------------------------------------------

analyze_m_bias <- function(dag) {
  eo <- validate_exposure_outcome(dag)
  exp <- eo$exp
  out <- eo$out
  
  minimal_sets <- adjustmentSets(dag, exp, out, type = "minimal")
  all_nodes <- setdiff(names(dag), c(exp, out))
  
  mbias_vars <- character(0)
  mbias_details <- list()
  
  for (v in all_nodes) {
    pars <- parents(dag, v)
    if (length(pars) < 2) next
    
    in_adjustment_set <- any(vapply(minimal_sets, function(s) v %in% s, logical(1)))
    if (in_adjustment_set) next
    
    all_paths <- paths(dag, from = exp, to = out)$paths
    paths_through_v <- grep(v, all_paths, value = TRUE)
    
    if (length(paths_through_v) > 0) {
      mbias_vars <- c(mbias_vars, v)
      mbias_details[[v]] <- list(parents = pars, paths = paths_through_v)
    }
  }
  
  valid_adjustment_set <- if (length(minimal_sets) > 0) minimal_sets[[1]] else character(0)
  
  list(
    exp = exp,
    out = out,
    minimal_sets = minimal_sets,
    valid_adjustment_set = valid_adjustment_set,
    mbias_vars = mbias_vars,
    mbias_details = mbias_details
  )
}

# ---- Reporting 

print_section_header <- function(title) {
  cat(strrep("=", 50), "\n", sep = "")
  cat(title, "\n", sep = "")
  cat(strrep("=", 50), "\n\n", sep = "")
}

print_vector <- function(label, values) {
  cat(label, ifelse(length(values) > 0, paste(sort(unique(values)), collapse = ", "), "None"), "\n", sep = "")
}

run_butterfly_mbias_report <- function(dag) {
  butterfly <- analyze_butterfly_bias(dag)
  mbias <- analyze_m_bias(dag)
  roles <- butterfly$roles
  
  print_section_header("BUTTERFLY & M-BIAS ANALYSIS")
  cat("Exposure: ", roles$exp, "\n", sep = "")
  cat("Outcome:  ", roles$out, "\n\n", sep = "")
  
  cat("Variable roles:\n")
  print_vector("  Instrumental variables: ", roles$instrumental_variables)
  print_vector("  Precision variables:    ", roles$precision_variables)
  print_vector("  Confounders:            ", roles$confounders)
  print_vector("  Mediators:              ", roles$mediators)
  print_vector("  Colliders:              ", roles$colliders)
  cat("\n")
  
  if (length(butterfly$butterfly_vars) > 0) {
    cat("Butterfly bias candidates (confounders with >1 confounder parent):\n")
    for (bfly in butterfly$butterfly_vars) {
      cat("  - ", bfly, " (parents: ", paste(sort(butterfly$butterfly_parents[[bfly]]), collapse = ", "), ")\n", sep = "")
    }
    cat("\n")
  } else {
    cat("No butterfly bias detected.\n\n")
  }
  
  cat("Valid minimal sufficient adjustment sets (butterfly-safe):\n")
  if (length(butterfly$valid_sets) > 0) {
    for (i in seq_along(butterfly$valid_sets)) {
      cat("  ", i, ". ", format_set(butterfly$valid_sets[[i]]), "\n", sep = "")
    }
  }
  cat("\n")
  
  cat("dagitty minimal adjustment sets (may include butterfly candidates):\n")
  if (length(roles$dagitty_minimal_sets) > 0) {
    for (i in seq_along(roles$dagitty_minimal_sets)) {
      cat("  ", i, ". ", format_set(roles$dagitty_minimal_sets[[i]]), "\n", sep = "")
    }
  } else {
    cat("  { } (empty set - no adjustment needed)\n")
  }
  cat("\n")
  
  if (length(mbias$mbias_vars) > 0) {
    cat("M-bias variables (colliders that should NOT be adjusted):\n")
    for (mb in mbias$mbias_vars) {
      cat("  - ", mb, " (parents: ", paste(sort(mbias$mbias_details[[mb]]$parents), collapse = ", "), ")\n", sep = "")
      cat("    Paths through ", mb, ": ", paste(mbias$mbias_details[[mb]]$paths, collapse = "; "), "\n", sep = "")
    }
  } else {
    cat("No M-bias detected.\n")
  }
  cat("\n")
  
  cat("Path verification:\n")
  paths_no_adj <- paths(dag, from = roles$exp, to = roles$out)
  cat("  Open paths without adjustment: ", sum(paths_no_adj$open), "/", length(paths_no_adj$open), "\n", sep = "")
  
  if (length(mbias$valid_adjustment_set) > 0) {
    paths_with_adj <- paths(dag, from = roles$exp, to = roles$out, Z = mbias$valid_adjustment_set)
    cat("  Open paths with valid adjustment ", format_set(mbias$valid_adjustment_set), ": ",
        sum(paths_with_adj$open), "/", length(paths_with_adj$open), "\n", sep = "")
  }
  
  invisible(list(butterfly = butterfly, mbias = mbias))
}

# ---- Toy Example 

# Execute an example report when this file is run directly with `Rscript`.
if (sys.nframe() == 0) {
  example_dag <- dagitty('dag {
    A [exposure]
    Y [outcome]
    A <- C1 -> Y
    A <- C2 -> Y
    A <- C3 -> Y
    C1 -> C3 <- C2
    A <- C4 -> Y
    C1 -> C4
    C2 -> C4
    A -> M -> Y
    A -> Collider <- Y
    parent_of_IV -> IV -> A
    Precision1 -> Y
  }')

  # Annotated Example
  # -----------------
  # A [exposure]
  # Y [outcome]
  ## Confounding structure
  # A <- C1 -> Y
  # A <- C2 -> Y
  # A <- C3 -> Y
  # C1 -> C3 <- C2
  # Butterfly candidate: C4 has two confounder parents
  # A <- C4 -> Y
  # C1 -> C4
  # C2 -> C4
  # Mediator and collider examples
  # A -> M -> Y
  # A -> Collider <- Y
  # Additional structure
  # parent_of_IV -> IV -> A
  # Precision1 -> Y
  #
  
  run_butterfly_mbias_report(example_dag)
}
