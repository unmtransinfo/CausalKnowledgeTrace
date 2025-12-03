# Test script for filtered assertion loading
# This tests that we only expand the assertions we need

library(jsonlite)

# Source the optimized loader
source("shiny_app/modules/optimized_loader.R")

# Create mock optimized data
mock_optimized_data <- list(
    pmid_sentences = list(
        "12345" = c("Sentence 1 for PMID 12345", "Sentence 2 for PMID 12345"),
        "67890" = c("Sentence 1 for PMID 67890"),
        "11111" = c("Sentence 1 for PMID 11111"),
        "22222" = c("Sentence 1 for PMID 22222"),
        "33333" = c("Sentence 1 for PMID 33333")
    ),
    assertions = list(
        list(subj = "A", obj = "B", subj_cui = "C001", obj_cui = "C002", 
             predicate = "CAUSES", ev_count = 2, pmid_refs = c("12345", "67890")),
        list(subj = "B", obj = "C", subj_cui = "C002", obj_cui = "C003", 
             predicate = "CAUSES", ev_count = 1, pmid_refs = c("11111")),
        list(subj = "C", obj = "D", subj_cui = "C003", obj_cui = "C004", 
             predicate = "CAUSES", ev_count = 2, pmid_refs = c("22222", "33333")),
        list(subj = "A", obj = "E", subj_cui = "C001", obj_cui = "C005", 
             predicate = "CAUSES", ev_count = 1, pmid_refs = c("12345")),
        list(subj = "F", obj = "D", subj_cui = "C006", obj_cui = "C004", 
             predicate = "CAUSES", ev_count = 1, pmid_refs = c("67890"))
    )
)

cat("=== Test 1: Expand ALL assertions (no filtering) ===\n")
start_time <- Sys.time()
all_expanded <- expand_optimized_format(mock_optimized_data, filtered_edges = NULL)
time_all <- as.numeric(Sys.time() - start_time, units = "secs")

cat("Expanded", length(all_expanded), "assertions in", round(time_all, 3), "seconds\n")
cat("Assertions:\n")
for (i in seq_along(all_expanded)) {
    cat("  ", i, ":", all_expanded[[i]]$subject_name, "->", all_expanded[[i]]$object_name, "\n")
}

cat("\n=== Test 2: Expand ONLY filtered assertions ===\n")
# Create filtered edges - only keep A->B, B->C, C->D (the path)
filtered_edges <- data.frame(
    v = c("A", "B", "C"),
    w = c("B", "C", "D"),
    stringsAsFactors = FALSE
)

cat("Filter: keeping only", nrow(filtered_edges), "edges\n")
for (i in 1:nrow(filtered_edges)) {
    cat("  ", filtered_edges$v[i], "->", filtered_edges$w[i], "\n")
}

start_time <- Sys.time()
filtered_expanded <- expand_optimized_format(mock_optimized_data, filtered_edges = filtered_edges)
time_filtered <- as.numeric(Sys.time() - start_time, units = "secs")

cat("\nExpanded", length(filtered_expanded), "assertions in", round(time_filtered, 3), "seconds\n")
cat("Assertions:\n")
for (i in seq_along(filtered_expanded)) {
    cat("  ", i, ":", filtered_expanded[[i]]$subject_name, "->", filtered_expanded[[i]]$object_name, "\n")
}

cat("\n=== Results ===\n")
cat("Without filtering:", length(all_expanded), "assertions\n")
cat("With filtering:", length(filtered_expanded), "assertions\n")
cat("Reduction:", length(all_expanded) - length(filtered_expanded), "assertions skipped\n")
cat("Speedup:", round(time_all / time_filtered, 2), "x faster (for this small test)\n")

# Verify correctness
expected_edges <- c("A->B", "B->C", "C->D")
actual_edges <- sapply(filtered_expanded, function(a) paste0(a$subject_name, "->", a$object_name))

if (all(actual_edges %in% expected_edges) && length(actual_edges) == length(expected_edges)) {
    cat("\n✓ Filtering is CORRECT! Only kept the expected edges.\n")
} else {
    cat("\n✗ Filtering has issues!\n")
    cat("Expected:", paste(expected_edges, collapse = ", "), "\n")
    cat("Got:", paste(actual_edges, collapse = ", "), "\n")
}

cat("\n=== Test complete ===\n")
cat("\nFor large graphs (e.g., 50,000 assertions filtered to 15,000),\n")
cat("this optimization will save ~70% of expansion time!\n")

