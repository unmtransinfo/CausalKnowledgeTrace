# Test script for path-based filtering functionality
# This script tests the filter_exposure_outcome_paths function

library(dagitty)
library(igraph)

# Set working directory to shiny_app for module loading
original_wd <- getwd()
current_dir <- basename(getwd())
parent_dir <- basename(dirname(getwd()))

if (current_dir == "shiny_app" && parent_dir == "tests") {
    # Running from tests/shiny_app, go up two levels then into shiny_app
    setwd(file.path(dirname(dirname(getwd())), "shiny_app"))
} else if (current_dir == "tests") {
    # Running from tests directory
    setwd(file.path(dirname(getwd()), "shiny_app"))
} else if (current_dir == "shiny_app" && dir.exists("modules")) {
    # Already in the correct shiny_app directory
    # Do nothing
} else {
    # Try to find and navigate to shiny_app directory
    if (dir.exists("shiny_app") && dir.exists("shiny_app/modules")) {
        setwd("shiny_app")
    } else if (dir.exists("../../shiny_app")) {
        setwd("../../shiny_app")
    } else {
        stop("Cannot find shiny_app directory with modules. Current dir: ", getwd())
    }
}

# Source the data_upload module
source("modules/data_upload.R")

# Create a test DAG with nodes that connect exposure to outcome
# and some nodes that only connect to one or the other
test_dag <- dagitty('dag {
    Exposure [exposure]
    Outcome [outcome]
    Mediator1
    Mediator2
    OnlyExposure1
    OnlyExposure2
    OnlyOutcome1
    OnlyOutcome2
    Isolated

    Exposure -> Mediator1
    Mediator1 -> Mediator2
    Mediator2 -> Outcome
    Exposure -> OnlyExposure1
    OnlyExposure1 -> OnlyExposure2
    OnlyOutcome1 -> OnlyOutcome2
    OnlyOutcome2 -> Outcome
}')

cat("=== Original DAG ===\n")
print(test_dag)
cat("\nOriginal nodes:", length(names(test_dag)), "\n")
cat("Original edges:", nrow(as.data.frame(dagitty::edges(test_dag))), "\n")

all_nodes <- names(test_dag)
cat("\nAll nodes:", paste(all_nodes, collapse = ", "), "\n")

# Test path-based filtering
cat("\n=== Testing path-based filtering ===\n")
result <- filter_exposure_outcome_paths(test_dag)

if (result$success) {
    cat("\n✓ Path filtering successful!\n")
    cat(result$message, "\n")
    cat("\nFiltered DAG:\n")
    print(result$dag)
    
    cat("\nStatistics:\n")
    cat("  Original nodes:", result$original_nodes, "\n")
    cat("  Original edges:", result$original_edges, "\n")
    cat("  Final nodes:", result$final_nodes, "\n")
    cat("  Final edges:", result$final_edges, "\n")
    cat("  Removed nodes:", result$removed_nodes, "\n")
    cat("  Removed edges:", result$removed_edges, "\n")
    
    cat("\nKept nodes:", paste(result$kept_nodes, collapse = ", "), "\n")
    
    # Expected: Exposure, Mediator1, Mediator2, Outcome
    # Should remove: OnlyExposure1, OnlyExposure2, OnlyOutcome1, OnlyOutcome2, Isolated
    expected_kept <- c("Exposure", "Mediator1", "Mediator2", "Outcome")
    expected_removed <- c("OnlyExposure1", "OnlyExposure2", "OnlyOutcome1", "OnlyOutcome2", "Isolated")
    
    cat("\n=== Validation ===\n")
    all_kept <- all(expected_kept %in% result$kept_nodes)
    none_removed_kept <- !any(expected_removed %in% result$kept_nodes)
    
    if (all_kept && none_removed_kept) {
        cat("✓ Filtering is correct!\n")
        cat("  - All expected nodes kept:", paste(expected_kept, collapse = ", "), "\n")
        cat("  - All expected nodes removed:", paste(expected_removed, collapse = ", "), "\n")
    } else {
        cat("✗ Filtering has issues:\n")
        if (!all_kept) {
            missing <- setdiff(expected_kept, result$kept_nodes)
            cat("  - Missing expected nodes:", paste(missing, collapse = ", "), "\n")
        }
        if (!none_removed_kept) {
            wrongly_kept <- intersect(expected_removed, result$kept_nodes)
            cat("  - Wrongly kept nodes:", paste(wrongly_kept, collapse = ", "), "\n")
        }
    }
    
    # Check if exposure and outcome are preserved
    remaining_exposures <- tryCatch(exposures(result$dag), error = function(e) character(0))
    remaining_outcomes <- tryCatch(outcomes(result$dag), error = function(e) character(0))
    
    cat("\nExposure nodes preserved:", paste(remaining_exposures, collapse = ", "), "\n")
    cat("Outcome nodes preserved:", paste(remaining_outcomes, collapse = ", "), "\n")
    
} else {
    cat("\n✗ Path filtering failed!\n")
    cat("Error:", result$message, "\n")
}

cat("\n=== Test complete ===\n")

