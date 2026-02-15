# Post-CKT Analysis Pipeline

Analyze CKT-generated causal graphs, prune generic hubs, discover confounders, and detect butterfly bias.

## Quick Start

```bash
cd furtherAnalysis/post_ckt

# Configure DB credentials (used by semantic analysis and evidence extraction)
cp .env.example .env

# Run full pipeline for degree 3
bash scripts/run_pipeline.sh Hypertension Alzheimers 3

# Output: data/Hypertension_Alzheimers/degree3/
```

---

## Step 1: Get Your Input Files

You need at least one DAGitty graph file:

```text
input/{Exposure}_{Outcome}_degree_<N>.R
```

Recommended additional provenance file (for evidence extraction in `03b`):

```text
input/{Exposure}_{Outcome}_causal_assertions_<N>.json
```

Examples:

```text
input/Hypertension_Alzheimers_degree_3.R
input/Hypertension_Alzheimers_causal_assertions_3.json
```

You can get these files either by:

1. Downloading from the CKT app.
2. Generating from YAML config via `scripts/generate_graph.sh`.

---

## Step 2: Setup

```bash
cd furtherAnalysis/post_ckt
mkdir -p input data
cp .env.example .env
# Edit .env with your PostgreSQL credentials
```

Notes:

1. `02_basic_analysis.R` will still run if DB lookup fails, but semantic type distribution outputs may be missing.
2. `03b_extract_confounder_evidence.R` can be slow on large JSON files.

---

## Step 3: Run the Analysis Pipeline

### Run Full Pipeline

```bash
bash scripts/run_pipeline.sh <Exposure> <Outcome> <Degree>

# Examples
bash scripts/run_pipeline.sh Hypertension Alzheimers 1
bash scripts/run_pipeline.sh Hypertension Alzheimers 2
bash scripts/run_pipeline.sh Hypertension Alzheimers 3
```

The full pipeline runs these scripts in order:

1. `01_parse_dagitty.R`
2. `01a_calculate_centrality.R`
3. `01b_node_removal_impact.R`
4. `01c_prune_generic_hubs.R`
5. `01d_post_node_removal_analysis.R`
6. `02_basic_analysis.R`
7. `03_confounder_analysis.R`
8. `03b_extract_confounder_evidence.R`
9. `03c_confounder_relationships.R`
10. `04_butterfly_bias_analysis.R`
11. `04b_confounder_subgraphs.R`

### Run Individual Scripts

```bash
cd scripts

# Stage 1: Graph preparation and pruning
Rscript 01_parse_dagitty.R Hypertension Alzheimers 3
Rscript 01a_calculate_centrality.R Hypertension Alzheimers 3
Rscript 01b_node_removal_impact.R Hypertension Alzheimers 3
Rscript 01c_prune_generic_hubs.R Hypertension Alzheimers 3
Rscript 01d_post_node_removal_analysis.R Hypertension Alzheimers 3

# Stage 2: Basic + semantic analysis
Rscript 02_basic_analysis.R Hypertension Alzheimers 3

# Stage 3: Confounder analysis
Rscript 03_confounder_analysis.R Hypertension Alzheimers 3

# Optional (can be long-running)
Rscript 03b_extract_confounder_evidence.R Hypertension Alzheimers 3

# Downstream confounder structure and bias analysis
Rscript 03c_confounder_relationships.R Hypertension Alzheimers 3
Rscript 04_butterfly_bias_analysis.R Hypertension Alzheimers 3
Rscript 04b_confounder_subgraphs.R Hypertension Alzheimers 3
```

---

## Output Directory Structure

```text
data/<Exposure>_<Outcome>/
├── degree1/
│   ├── s1_graph/                 # Parsed graph, centrality, pruning outputs
│   │   └── plots/
│   ├── s2_semantic/              # Basic stats and semantic outputs
│   │   └── plots/
│   ├── s3_confounders/           # Confounder discovery + cycle-broken graph
│   │   └── reports/
│   ├── s3b_evidence/             # Evidence matching outputs (only if 03b is run)
│   ├── s3c_relationships/        # Confounder relationship network
│   └── s4_butterfly_bias/        # Butterfly bias outputs + confounder subgraphs
│       └── graphs/
├── degree2/
│   └── ...
└── degree3/
    └── ...
```

---

## Key Output Files

| Stage | File | Description |
|-------|------|-------------|
| S1 | `s1_graph/parsed_graph.rds` | Parsed graph from DAGitty input |
| S1 | `s1_graph/all_nodes_centrality.csv` | Degree/betweenness for all nodes |
| S1 | `s1_graph/pruned_graph.rds` | Graph after removing generic hubs |
| S1 | `s1_graph/post_removal_summary.csv` | SCC and centrality summary after pruning |
| S2 | `s2_semantic/graph_statistics.txt` | Node/edge/density summary |
| S2 | `s2_semantic/nodes_with_semantic_types.csv` | Node table with semantic fields |
| S2 | `s2_semantic/semantic_type_distribution.csv` | Created only when DB semantic lookup succeeds |
| S3 | `s3_confounders/valid_confounders.csv` | Stage-3 valid confounders |
| S3 | `s3_confounders/graph_cycle_broken.rds` | Graph after strong-confounder feedback edge removal |
| S3b | `s3b_evidence/full_evidence_database.csv` | Full extracted provenance evidence |
| S3b | `s3b_evidence/all_evidence.csv` | Evidence matched to confounder report edges |
| S3c | `s3c_relationships/confounder_relationships_2nd.csv` | Direct parent-child links among confounders |
| S4 | `s4_butterfly_bias/butterfly_analysis_results.csv` | Structural confounder hierarchy (dagitty) |
| S4 | `s4_butterfly_bias/butterfly_nodes.csv` | Confounders with 2+ confounder parents |
| S4 | `s4_butterfly_bias/independent_confounders.csv` | Confounders with no confounder parents |
| S4 | `s4_butterfly_bias/graphs/*.png` | Per-confounder visualization subgraphs |

---

## Interpreting Confounder Counts

The pipeline can report different confounder counts by design:

1. `s3_confounders/valid_confounders.csv`: Stage-3 valid confounders (direct-parent criteria, excludes direct children).
2. `s4_butterfly_bias/butterfly_analysis_results.csv`: Structural confounders from dagitty parents/children logic.

These are related but not guaranteed to be equal.

---

## Configuration

Edit `scripts/config.R` to customize:

1. `GENERIC_NODES`: Nodes removed in pruning.
2. `STRONG_CONFOUNDERS`: Nodes used in cycle-breaking step.
3. `DB_CONFIG`: DB connection defaults via environment variables.

Also relevant:

1. `scripts/run_pipeline.sh`: Orchestrates all 11 steps.
2. `scripts/generate_graph.sh`: Generates input graph files from YAML config.

---

## Related Docs

1. `pipeline_flowchart.html`: Step-by-step flowchart with script IO.
2. `user_guide.html`: Detailed user guide and output interpretation.
