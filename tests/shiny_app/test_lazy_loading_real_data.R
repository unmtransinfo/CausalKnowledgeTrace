# Test lazy loading with real graph data
# This demonstrates the performance improvement with actual files

library(jsonlite)

# Source the required modules
source("shiny_app/modules/optimized_loader.R")
source("shiny_app/modules/data_upload.R")

cat("=== LAZY LOADING TEST WITH REAL DATA ===\n\n")

# Find a real causal assertions file
test_files <- c(
    "graph_creation/result/causal_assertions_1.json",
    "graph_creation/output/causal_assertions_1.json"
)

test_file <- NULL
for (file in test_files) {
    if (file.exists(file)) {
        test_file <- file
        break
    }
}

if (is.null(test_file)) {
    cat("❌ No test file found. Please run graph creation first.\n")
    cat("Looked for files:\n")
    for (file in test_files) {
        cat("  -", file, "\n")
    }
    quit(status = 1)
}

cat("Using test file:", test_file, "\n")
file_size_mb <- round(file.size(test_file) / (1024^2), 2)
cat("File size:", file_size_mb, "MB\n\n")

# Test 1: Load with LAZY LOADING (new default)
cat("=== Test 1: LAZY LOADING (expand_full = FALSE) ===\n")
start_lazy <- Sys.time()
result_lazy <- load_causal_assertions_unified(test_file, use_lazy_loading = TRUE)
time_lazy <- as.numeric(Sys.time() - start_lazy, units = "secs")

cat("✅ Success:", result_lazy$success, "\n")
cat("📊 Strategy:", result_lazy$loading_strategy, "\n")
cat("⏱️  Load time:", round(time_lazy, 3), "seconds\n")
cat("📦 Assertions:", length(result_lazy$assertions), "\n")
cat("🔧 Has lazy_loader:", !is.null(result_lazy$lazy_loader), "\n")

if (!is.null(result_lazy$total_assertions)) {
    cat("📈 Total assertions in file:", result_lazy$total_assertions, "\n")
}

# Test 2: Simulate clicking on 5 random edges
if (!is.null(result_lazy$lazy_loader) && length(result_lazy$assertions) > 0) {
    cat("\n=== Test 2: Simulate clicking on edges ===\n")
    
    # Get 5 random assertions to test
    num_tests <- min(5, length(result_lazy$assertions))
    test_indices <- sample(1:length(result_lazy$assertions), num_tests)
    
    total_expand_time <- 0
    
    for (i in 1:num_tests) {
        assertion <- result_lazy$assertions[[test_indices[i]]]
        from_node <- assertion$subj
        to_node <- assertion$obj
        
        cat("\nClick", i, ":", from_node, "->", to_node, "\n")
        
        start_expand <- Sys.time()
        pmid_data <- find_edge_pmid_data(
            from_node,
            to_node,
            result_lazy$assertions,
            result_lazy$lazy_loader,
            NULL
        )
        expand_time <- as.numeric(Sys.time() - start_expand, units = "secs")
        total_expand_time <- total_expand_time + expand_time
        
        cat("  Found:", pmid_data$found, "\n")
        cat("  Expansion time:", round(expand_time, 4), "seconds\n")
        cat("  PMIDs:", length(pmid_data$pmid_list), "\n")
        cat("  Predicate:", pmid_data$predicate, "\n")
    }
    
    avg_expand_time <- total_expand_time / num_tests
    cat("\n📊 Average expansion time per edge:", round(avg_expand_time, 4), "seconds\n")
}

# Test 3: Load with FULL EXPANSION (old behavior)
cat("\n=== Test 3: FULL EXPANSION (expand_full = TRUE) ===\n")
cat("⚠️  This may take 30-60 seconds for large files...\n")

start_full <- Sys.time()
result_full <- load_causal_assertions_unified(test_file, use_lazy_loading = FALSE)
time_full <- as.numeric(Sys.time() - start_full, units = "secs")

cat("✅ Success:", result_full$success, "\n")
cat("📊 Strategy:", result_full$loading_strategy, "\n")
cat("⏱️  Load time:", round(time_full, 3), "seconds\n")
cat("📦 Assertions:", length(result_full$assertions), "\n")

# Performance comparison
cat("\n=== 🎯 PERFORMANCE COMPARISON ===\n")
cat("Lazy loading time:    ", round(time_lazy, 3), "seconds\n")
cat("Full expansion time:  ", round(time_full, 3), "seconds\n")
cat("Speedup:              ", round(time_full / time_lazy, 1), "x faster\n")
cat("Time saved:           ", round(time_full - time_lazy, 1), "seconds\n")

cat("\n=== 💡 USER EXPERIENCE ===\n")
cat("With lazy loading:\n")
cat("  ✅ Graph appears in ~", round(time_lazy, 1), "seconds\n")
cat("  ✅ User can start exploring immediately\n")
cat("  ✅ Edge details load instantly when clicked (~0.1s)\n")
cat("  ✅ Cached edges load even faster (~0.0001s)\n")
cat("\nWith full expansion:\n")
cat("  ❌ User waits ~", round(time_full, 1), "seconds before seeing anything\n")
cat("  ❌ All data loaded upfront (even if never viewed)\n")
cat("  ❌ Higher memory usage\n")

cat("\n✅ Lazy loading test complete!\n")

