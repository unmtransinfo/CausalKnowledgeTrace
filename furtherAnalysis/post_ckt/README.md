# Post-CKT Analysis Pipeline

Analyze causal knowledge graphs, detect and remove cycles, and prepare clean DAGs for confounder analysis.

## Quick Start

## Step 1: Get Your Graph

1. Generate the graph with the Python pipeline.
2. Use the files already written to `graph_creation/result/`:
   - `<Exposure>_to_<Outcome>_degreeN.json` - graph JSON used by Stage 1
   - `<Exposure>_to_<Outcome>_degreeN_causal_assertions.json` - assertions JSON used by semantic analysis
3. Example:
   ```bash
   ls ../../graph_creation/result/Hypertension_to_Alzheimers_degree2.json
   ls ../../graph_creation/result/Hypertension_to_Alzheimers_degree2_causal_assertions.json
   ```

---

## Step 2: Setup

```bash
# Create required directories
mkdir -p data

# Set up database credentials (for semantic type analysis)
cp .env.example .env
# Edit .env with your PostgreSQL credentials
```

---

## Step 3: Run the Analysis Pipeline

### Run Individual Scripts

```bash
cd scripts

# Stage 1: Load graph_creation/result JSON graph
# (script name kept for compatibility)
Rscript 01_parse_dagitty.R Hypertension Alzheimers

# Stage 2: Basic analysis & cycle detection
Rscript 02_basic_analysis.R Hypertension Alzheimers
Rscript 04a_cycle_detection.R Hypertension Alzheimers
Rscript 03a_semantic_type_analysis.R Hypertension Alzheimers
Rscript 03b_semantic_distribution.R Hypertension Alzheimers

# Stage 3: Extract cycles
Rscript 04b_extract_analyze_cycle.R Hypertension Alzheimers
Rscript 04c_visualize_cycles.R Hypertension Alzheimers
Rscript 04d_visualize_cycle_stats.R Hypertension Alzheimers

# Stage 4: Prune generic nodes
Rscript 05_node_removal_impact.R Hypertension Alzheimers

# Stage 5: Post-pruning analysis
Rscript 06_post_node_removal_analysis.R Hypertension Alzheimers
```

---

## Step 4: Get the Pruned Graph

The **pruned graph** is saved at:
```
data/<Exposure>_<Outcome>/s4_node_removal/reduced_graph.rds
```

### Load in R

```r
library(igraph)

pruned_graph <- readRDS("data/Hypertension_Alzheimers/s4_node_removal/reduced_graph.rds")

cat("Nodes:", vcount(pruned_graph), "\n")
cat("Edges:", ecount(pruned_graph), "\n")
cat("Is DAG:", is_dag(pruned_graph), "\n")
```

### Nodes Removed During Pruning

Generic/non-specific nodes removed (configurable in `config.R`):
- Disease, Functional_disorder, Complication, Syndrome
- Symptoms, Diagnosis, Obstruction, Physical_findings, Adverse_effects

---

## Step 5: Confounder-by-Confounder Analysis

```r
library(igraph)

pruned_graph <- readRDS("data/Hypertension_Alzheimers/s4_node_removal/reduced_graph.rds")

# Get exposure and outcome
exposure <- V(pruned_graph)[V(pruned_graph)$type == "exposure"]$name
outcome <- V(pruned_graph)[V(pruned_graph)$type == "outcome"]$name

# Get all potential confounders
confounders <- V(pruned_graph)$name
confounders <- confounders[!confounders %in% c(exposure, outcome)]

# Analyze each confounder
for (conf in confounders) {
  paths <- all_simple_paths(pruned_graph, from = exposure, to = outcome, mode = "out")
  on_path <- any(sapply(paths, function(p) conf %in% names(p)))
  cat(conf, "- On causal path:", on_path, "\n")
}
```

---

## Key Output Files

| Stage | File | Description |
|-------|------|-------------|
| S1 | `s1_graph/parsed_graph.rds` | igraph built from `graph_creation/result/*.json` |
| S2 | `s2_semantic/node_centrality_and_cycles.csv` | Node metrics + cycle info |
| S3 | `s3_cycles/node_cycle_participation.csv` | Cycle counts per node |
| S4 | `s4_node_removal/reduced_graph.rds` | **Pruned graph** |
| S5 | `s5_post_removal/top_nodes_by_cycles.csv` | Remaining problematic nodes |

---

## Configuration

Edit `scripts/config.R` to customize:
- `GENERIC_NODES`: Nodes to remove during pruning
- `CYCLE_CONFIG`: Cycle detection parameters
- `DB_CONFIG`: Database connection (for semantic analysis)
