# 04d_visualize_cycle_stats.R
# Visualize cycle statistics: cycle length distribution and node participation
#
# Input: data/{Exposure}_{Outcome}/s3_cycles/
#   - cycle_length_distribution.csv
#   - node_cycle_participation.csv
# Output: data/{Exposure}_{Outcome}/s3_cycles/plots/
#   - cycle_length_distribution.png
#   - top_nodes_cycle_participation.png

# ---- Load configuration and utilities ----
get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    return(dirname(normalizePath(sub("--file=", "", file_arg))))
  }
  return(getwd())
}
script_dir <- get_script_dir()
source(file.path(script_dir, "config.R"))
source(file.path(script_dir, "utils.R"))

# ---- Load required libraries ----
library(ggplot2)
library(dplyr)
library(scales)

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Hypertension",
  default_outcome = "Alzheimers",
  default_degree = 2
)
exposure_name <- args$exposure
outcome_name <- args$outcome
degree <- args$degree

# ---- Set paths ----
cycles_dir <- get_s3_cycles_dir(exposure_name, outcome_name, degree)
plots_dir <- file.path(cycles_dir, "plots")

# ---- Validate inputs and create output directory ----
ensure_dir(plots_dir)

print_header(paste0("Cycle Statistics Visualization (Stage 3d) - Degree ", degree), exposure_name, outcome_name)

# ==========================================
# 1. LOAD DATA
# ==========================================
cat("=== 1. LOADING DATA ===\n")

# Load cycle length distribution
length_dist_file <- file.path(cycles_dir, "cycle_length_distribution.csv")
if (!file.exists(length_dist_file)) {
  stop("Cycle length distribution file not found. Run 04b_extract_analyze_cycle.R first.")
}
length_dist <- read.csv(length_dist_file)
cat("Loaded cycle length distribution:", nrow(length_dist), "length categories\n")

# Load node cycle participation
node_participation_file <- file.path(cycles_dir, "node_cycle_participation.csv")
if (!file.exists(node_participation_file)) {
  stop("Node cycle participation file not found. Run 04b_extract_analyze_cycle.R first.")
}
node_participation <- read.csv(node_participation_file)
cat("Loaded node participation data:", nrow(node_participation), "nodes\n\n")

# Calculate total cycles
total_cycles <- sum(length_dist$count)
cat("Total cycles:", format(total_cycles, big.mark = ","), "\n\n")

# ==========================================
# 2. VISUALIZE CYCLE LENGTH DISTRIBUTION
# ==========================================
cat("=== 2. VISUALIZING CYCLE LENGTH DISTRIBUTION ===\n")

# Calculate percentage for each length
length_dist <- length_dist %>%
  mutate(
    percentage = count / total_cycles * 100,
    label = ifelse(percentage >= 1, sprintf("%.1f%%", percentage), "")
  )

# Find the peak
peak_length <- length_dist$cycle_length[which.max(length_dist$count)]
peak_count <- max(length_dist$count)
cat("Peak cycle length:", peak_length, "with", format(peak_count, big.mark = ","), "cycles\n")

# Create cycle length distribution plot
p1 <- ggplot(length_dist, aes(x = cycle_length, y = count)) +
  geom_bar(stat = "identity", fill = "#3498db", color = "#2980b9", width = 0.8) +
  geom_text(aes(label = label), vjust = -0.5, size = 3, color = "#2c3e50") +
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.1))
  ) +
  scale_x_continuous(breaks = seq(min(length_dist$cycle_length), max(length_dist$cycle_length), by = 2)) +
  labs(
    title = paste0("Cycle Length Distribution: ", exposure_name, " → ", outcome_name),
    subtitle = paste0("Total cycles: ", format(total_cycles, big.mark = ","),
                      " | Peak at length ", peak_length, " (",
                      sprintf("%.1f%%", length_dist$percentage[length_dist$cycle_length == peak_length]), ")"),
    x = "Cycle Length (number of nodes)",
    y = "Number of Cycles"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "#666666", size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    axis.text = element_text(color = "#2c3e50"),
    axis.title = element_text(color = "#2c3e50", face = "bold")
  )

# Save plot
length_dist_plot_file <- file.path(plots_dir, "cycle_length_distribution.png")
ggsave(length_dist_plot_file, p1, width = 12, height = 6, dpi = 300)
cat("Saved cycle length distribution plot to:", length_dist_plot_file, "\n\n")

# ==========================================
# 3. VISUALIZE TOP NODES BY CYCLE PARTICIPATION
# ==========================================
cat("=== 3. VISUALIZING TOP NODES BY CYCLE PARTICIPATION ===\n")

# Get top 20 nodes
top_n <- 20
top_nodes <- head(node_participation, top_n)

# Calculate percentage of total cycles
top_nodes <- top_nodes %>%
  mutate(
    percentage = num_cycles / total_cycles * 100,
    label = sprintf("%s (%.1f%%)", format(num_cycles, big.mark = ","), percentage),
    # Clean node names for display (replace underscores with spaces)
    node_display = gsub("_", " ", node)
  )

# Reorder factor for plotting
top_nodes$node_display <- factor(top_nodes$node_display,
                                  levels = rev(top_nodes$node_display))

# Create horizontal bar chart
p2 <- ggplot(top_nodes, aes(x = node_display, y = num_cycles)) +
  geom_bar(stat = "identity", fill = "#e74c3c", color = "#c0392b", width = 0.7) +
  geom_text(aes(label = label), hjust = -0.05, size = 3, color = "#2c3e50") +
  coord_flip() +
  scale_y_continuous(
    labels = label_comma(),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title = paste0("Top ", top_n, " Nodes by Cycle Participation"),
    subtitle = paste0(exposure_name, " → ", outcome_name, " | Total cycles: ",
                      format(total_cycles, big.mark = ",")),
    x = NULL,
    y = "Number of Cycles Participated"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "#666666", size = 10),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_blank(),
    axis.text.y = element_text(color = "#2c3e50", size = 10),
    axis.text.x = element_text(color = "#2c3e50"),
    axis.title = element_text(color = "#2c3e50", face = "bold")
  )

# Save plot
top_nodes_plot_file <- file.path(plots_dir, "top_nodes_cycle_participation.png")
ggsave(top_nodes_plot_file, p2, width = 12, height = 8, dpi = 300)
cat("Saved top nodes plot to:", top_nodes_plot_file, "\n\n")

# ==========================================
# 4. ADDITIONAL: CUMULATIVE DISTRIBUTION
# ==========================================
cat("=== 4. VISUALIZING CUMULATIVE DISTRIBUTION ===\n")

# Calculate cumulative percentage
length_dist <- length_dist %>%
  arrange(cycle_length) %>%
  mutate(
    cumulative_count = cumsum(count),
    cumulative_pct = cumulative_count / total_cycles * 100
  )

# Create cumulative distribution plot
p3 <- ggplot(length_dist, aes(x = cycle_length, y = cumulative_pct)) +
  geom_line(color = "#9b59b6", linewidth = 1.2) +
  geom_point(color = "#8e44ad", size = 2) +
  geom_hline(yintercept = c(25, 50, 75), linetype = "dashed", color = "#bdc3c7", linewidth = 0.5) +
  scale_y_continuous(
    breaks = seq(0, 100, by = 25),
    labels = function(x) paste0(x, "%"),
    limits = c(0, 100)
  ) +
  scale_x_continuous(breaks = seq(min(length_dist$cycle_length), max(length_dist$cycle_length), by = 2)) +
  labs(
    title = paste0("Cumulative Cycle Length Distribution: ", exposure_name, " → ", outcome_name),
    subtitle = "Percentage of cycles at or below each length",
    x = "Cycle Length (number of nodes)",
    y = "Cumulative Percentage"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", hjust = 0.5, size = 14),
    plot.subtitle = element_text(hjust = 0.5, color = "#666666", size = 10),
    panel.grid.minor = element_blank(),
    axis.text = element_text(color = "#2c3e50"),
    axis.title = element_text(color = "#2c3e50", face = "bold")
  )

# Save plot
cumulative_plot_file <- file.path(plots_dir, "cycle_length_cumulative.png")
ggsave(cumulative_plot_file, p3, width = 10, height = 6, dpi = 300)
cat("Saved cumulative distribution plot to:", cumulative_plot_file, "\n\n")

# ==========================================
# 5. SUMMARY STATISTICS
# ==========================================
cat("=== SUMMARY ===\n")
cat("Plots saved to:", plots_dir, "\n")
cat("  - cycle_length_distribution.png\n")
cat("  - top_nodes_cycle_participation.png\n")
cat("  - cycle_length_cumulative.png\n\n")

# Print key statistics
cat("Key Statistics:\n")
cat("  Total cycles:", format(total_cycles, big.mark = ","), "\n")
cat("  Cycle lengths range:", min(length_dist$cycle_length), "to", max(length_dist$cycle_length), "\n")
cat("  Peak length:", peak_length, "(", sprintf("%.2f%%", length_dist$percentage[length_dist$cycle_length == peak_length]), "of cycles)\n")
cat("  Median length:", length_dist$cycle_length[which.min(abs(length_dist$cumulative_pct - 50))], "\n")
cat("  Top node:", top_nodes$node[1], "participates in", sprintf("%.2f%%", top_nodes$percentage[1]), "of all cycles\n")

print_complete("Cycle Statistics Visualization")
