
# Load required modules
setwd("/home/mpradhan/Research_Project/CausalKnowledgeTrace/shiny_app")
source("modules/binary_storage.R")
source("modules/sentence_storage.R")

# Convert to binary format
cat("Creating binary format...\n")
binary_result <- convert_json_to_binary("/home/mpradhan/Research_Project/CausalKnowledgeTrace/manjil_analysis/input/causal_assertions_2.json", compression = "gzip")

if (binary_result$success) {
    cat("✓ Binary format created:", binary_result$compression_ratio, "% compression\n")
} else {
    cat("✗ Binary format failed:", binary_result$message, "\n")
}

# Create lightweight format
cat("Creating lightweight format...\n")
degree <- 2
lightweight_result <- create_separated_files("/home/mpradhan/Research_Project/CausalKnowledgeTrace/manjil_analysis/input/causal_assertions_2.json", degree = degree)

if (lightweight_result$success) {
    cat("✓ Lightweight format created:", lightweight_result$size_reduction_percent, "% size reduction\n")
} else {
    cat("✗ Lightweight format failed:", lightweight_result$message, "\n")
}
