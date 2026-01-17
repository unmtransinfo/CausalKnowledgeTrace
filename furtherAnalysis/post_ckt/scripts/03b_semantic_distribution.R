# 03b_semantic_distribution.R
# Visualize semantic type distributions and cycle participation

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
library(tidyr)

# ---- Argument handling ----
args <- parse_exposure_outcome_args(
  default_exposure = "Depression",
  default_outcome = "Alzheimers"
)
exposure_name <- args$exposure
outcome_name <- args$outcome

# ---- Set paths using utility functions ----
analysis_dir <- get_analysis_output_dir(exposure_name, outcome_name)
plots_dir <- get_plots_output_dir(exposure_name, outcome_name)

# Create plots directory if needed
ensure_dir(plots_dir)

print_header("Semantic Distribution Analysis", exposure_name, outcome_name)

# Read the semantic type stats
stats_file <- file.path(analysis_dir, "semantic_type_cycle_stats.csv")
if (!file.exists(stats_file)) {
  stop("Could not find semantic_type_cycle_stats.csv. Run 03a_semantic_type_analysis.R first.")
}
semtype_stats <- read.csv(stats_file)
cat("Loaded semantic type stats from:", stats_file, "\n\n")

# Get top 15 by total nodes
top15 <- semtype_stats %>%
  arrange(desc(Total_Nodes)) %>%
  head(15)

# Create factor with ordered levels for proper bar ordering
top15$semtype <- factor(top15$semtype, levels = rev(top15$semtype))

# Create the bar plot
p <- ggplot(top15, aes(x = semtype, y = Total_Nodes)) +
  geom_bar(stat = "identity", fill = "steelblue", width = 0.7) +
  geom_text(aes(label = Total_Nodes), hjust = -0.2, size = 3.5) +
  coord_flip() +
  labs(
    title = "Distribution of Top 15 Semantic Types",
    x = "Semantic Type",
    y = "Number of Nodes"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    axis.text.y = element_text(size = 10),
    axis.text.x = element_text(size = 10),
    panel.grid.major.y = element_blank()
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15)))

# Save the distribution figure
output_file1 <- file.path(plots_dir, "semantic_type_distribution.png")
ggsave(output_file1, p, width = 8, height = 6, dpi = 300)

cat("Saved distribution plot to:", output_file1, "\n")

# ==========================================
# SEMANTIC TYPE COMPARISON: IN CYCLES VS NOT IN CYCLES
# ==========================================

# Focus on semantic types that have nodes in cycles
in_cycle_types <- semtype_stats %>%
  filter(Nodes_In_Cycles > 0) %>%
  select(semtype, Nodes_In_Cycles, Nodes_Not_In_Cycles)

# Calculate percentages within each group
total_in_cycles <- sum(in_cycle_types$Nodes_In_Cycles)
total_not_in_cycles <- sum(in_cycle_types$Nodes_Not_In_Cycles)

in_cycle_types <- in_cycle_types %>%
  mutate(
    Pct_In_Cycles = round(100 * Nodes_In_Cycles / total_in_cycles, 1),
    Pct_Not_In_Cycles = round(100 * Nodes_Not_In_Cycles / total_not_in_cycles, 1)
  )

# Reshape for grouped bar chart
comparison_data <- in_cycle_types %>%
  select(semtype, Pct_In_Cycles, Pct_Not_In_Cycles) %>%
  pivot_longer(cols = c(Pct_In_Cycles, Pct_Not_In_Cycles),
               names_to = "Group", values_to = "Percentage") %>%
  mutate(Group = ifelse(Group == "Pct_In_Cycles", "In Cycles", "Not In Cycles"))

# Order by percentage in cycles
order_levels <- in_cycle_types %>% arrange(desc(Pct_In_Cycles)) %>% pull(semtype)
comparison_data$semtype <- factor(comparison_data$semtype, levels = order_levels)

# Create grouped bar chart
p2 <- ggplot(comparison_data, aes(x = semtype, y = Percentage, fill = Group)) +
  geom_bar(stat = "identity", position = position_dodge(width = 0.8), width = 0.7) +
  geom_text(aes(label = paste0(Percentage, "%")),
            position = position_dodge(width = 0.8),
            vjust = -0.3, size = 3.5) +
  scale_fill_manual(values = c("In Cycles" = "#E74C3C", "Not In Cycles" = "#3498DB")) +
  labs(
    title = "Semantic Type Distribution: In Cycles vs Not In Cycles",
    x = "Semantic Type",
    y = "Percentage of Nodes (%)",
    fill = "Node Group"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    axis.text.x = element_text(size = 11, angle = 0),
    legend.position = "top"
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.15)))

# Save the comparison figure
output_file2 <- file.path(plots_dir, "semantic_type_comparison.png")
ggsave(output_file2, p2, width = 10, height = 6, dpi = 300)

cat("Saved comparison plot to:", output_file2, "\n")
print_complete("Semantic Distribution Analysis")