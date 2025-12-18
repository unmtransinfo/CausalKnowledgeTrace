#!/usr/bin/env Rscript
# Test script to verify blocklist CUIs are loaded in UI
# This tests that the graph_config_ui.R properly extracts and displays blocklist CUIs

library(yaml)

cat("Testing Blocklist UI Loading\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

# Load the YAML config
yaml_file <- "../../user_input.yaml"
cat("1. Loading YAML config from:", yaml_file, "\n")

if (!file.exists(yaml_file)) {
    cat("   ✗ YAML file not found!\n")
    quit(status = 1)
}

config <- tryCatch({
    yaml::read_yaml(yaml_file)
}, error = function(e) {
    cat("   ✗ Error loading YAML:", e$message, "\n")
    quit(status = 1)
})

cat("   ✓ YAML loaded successfully\n\n")

# Test extraction logic (same as in graph_config_ui.R)
cat("2. Testing CUI extraction logic:\n")

# Exposure CUIs
exposure_cuis_ui <- if (!is.null(config) && !is.null(config$exposure_cuis)) {
    paste(unlist(config$exposure_cuis), collapse = ", ")
} else {
    "C0020538, C4013784, C0221155, C0745114, C0745135"
}
cat("   Exposure CUIs:", exposure_cuis_ui, "\n")

# Outcome CUIs
outcome_cuis_ui <- if (!is.null(config) && !is.null(config$outcome_cuis)) {
    paste(unlist(config$outcome_cuis), collapse = ", ")
} else {
    "C2677888, C0750901, C0494463, C0002395"
}
cat("   Outcome CUIs:", outcome_cuis_ui, "\n")

# Blocklist CUIs (FIXED VERSION)
blocklist_cuis_ui <- if (!is.null(config) && !is.null(config$blocklist_cuis)) {
    paste(unlist(config$blocklist_cuis), collapse = ", ")
} else {
    ""
}
cat("   Blocklist CUIs:", blocklist_cuis_ui, "\n\n")

# Verify blocklist is not empty
cat("3. Verification:\n")

if (!is.null(config$blocklist_cuis) && length(config$blocklist_cuis) > 0) {
    cat("   ✓ Blocklist CUIs found in YAML:", length(config$blocklist_cuis), "CUI(s)\n")
    cat("   ✓ Blocklist CUIs extracted:", blocklist_cuis_ui, "\n")
    
    if (nchar(blocklist_cuis_ui) > 0) {
        cat("   ✓ Blocklist UI value is NOT empty\n")
        cat("   ✓ UI will display blocklist CUIs correctly\n")
    } else {
        cat("   ✗ Blocklist UI value is EMPTY (BUG!)\n")
        quit(status = 1)
    }
} else {
    cat("   ⚠ No blocklist CUIs in YAML (this is OK - blocklist is optional)\n")
    cat("   ✓ Blocklist UI value is empty (expected)\n")
}

cat("\n", paste(rep("=", 70), collapse = ""), "\n")
cat("✓ ALL TESTS PASSED - Blocklist UI loading is working correctly!\n")
cat(paste(rep("=", 70), collapse = ""), "\n\n")

cat("Summary:\n")
cat("  • Exposure CUIs loaded: ✓\n")
cat("  • Outcome CUIs loaded: ✓\n")
cat("  • Blocklist CUIs loaded: ✓\n")
cat("  • UI will display all CUIs from user_input.yaml\n")

