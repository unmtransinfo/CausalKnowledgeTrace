# Post-CKT Analysis Pipeline

This directory contains the refactored analysis pipeline for Causal Knowledge Trace (CKT). The code is designed to be portable and configurable.

## Directory Structure

```
post_ckt/
├── scripts/                          # R analysis scripts
├── configs/                          # YAML configuration files
├── input/                            # Original CKT files (.R, .json) - not tracked
├── .env                              # Database credentials - not tracked
├── .env.example                      # Template for .env file
└── data/                             # Analysis outputs - not tracked
    └── {Exposure}_{Outcome}/
        ├── s1_graph/                 # Parsed igraph object (01)
        ├── s2_semantic/              # Semantic type analysis (02, 03a, 03b, 04a)
        │   └── plots/
        ├── s3_cycles/                # Cycle detection & extraction (04b, 04c)
        │   ├── plots/
        │   └── subgraphs/
        ├── s4_node_removal/          # Generic node removal analysis (05)
        │   └── plots/
        └── s5_post_removal/          # Post-removal cycle analysis (06)
            └── plots/
```

## 1. Setup

### Create Required Directories

```bash
mkdir -p input
mkdir -p data
```

### Configure Database Credentials

Copy the example environment file and fill in your credentials:

```bash
cp .env.example .env
```

Edit `.env` with your database credentials:

```
CKT_DB_HOST=localhost
CKT_DB_PORT=5432
CKT_DB_NAME=causalehr_db
CKT_DB_USER=your_username
CKT_DB_PASSWORD=your_password
```

> **Note:** The `.env` file is gitignored for security. Never commit credentials to git.

If running inside Docker, use the container name instead of localhost:
```
CKT_DB_HOST=db
```

## 2. Generate Graph Data

Generate the graph data from the CausalEHR database using the `generate_graph.sh` script.

**Usage:**

```bash
./scripts/generate_graph.sh --yaml-config configs/your_config.yaml \
    --db-user <your_username> \
    --db-password <your_password>
```

**Example:**

```bash
./scripts/generate_graph.sh --yaml-config configs/hypertension_alzheimers.yaml \
    --db-user myuser \
    --db-password "mypassword"
```

This script will:
1. Query the database
2. Generate `degree_X.R` and `causal_assertions_X.json` in the `input/` folder
3. Automatically rename them based on the YAML config

## 3. Running the Analysis Pipeline

### Pipeline Stages

| Stage | Script | Description | Output Directory |
|-------|--------|-------------|------------------|
| S1 | `01_parse_dagitty.R` | Parse DAGitty file to igraph | `s1_graph/` |
| S2 | `02_basic_analysis.R` | Basic graph analysis, centrality, cycles | `s2_semantic/` |
| S2 | `03a_semantic_type_analysis.R` | Extract semantic types from DB | `s2_semantic/` |
| S2 | `03b_semantic_distribution.R` | Visualize semantic distributions | `s2_semantic/plots/` |
| S2 | `04a_cycle_detection.R` | Detect SCCs and cycles | `s2_semantic/` |
| S3 | `04b_extract_analyze_cycle.R` | Extract and count all cycles | `s3_cycles/` |
| S3 | `04c_visualize_cycles.R` | Visualize cycle subgraphs | `s3_cycles/plots/` |
| S4 | `05_node_removal_impact.R` | Analyze generic node removal impact | `s4_node_removal/` |
| S5 | `06_post_node_removal_analysis.R` | Analyze cycles after node removal | `s5_post_removal/` |

### Option A: Run Complete Pipeline (Recommended)

```bash
./scripts/run_pipeline.sh <Exposure> <Outcome>
```

**Example:**
```bash
./scripts/run_pipeline.sh Hypertension Alzheimers
```

### Option B: Run Individual Scripts

```bash
cd furtherAnalysis/post_ckt/scripts

# Stage 1: Parse graph
Rscript 01_parse_dagitty.R Hypertension Alzheimers

# Stage 2: Basic analysis and semantic types
Rscript 02_basic_analysis.R Hypertension Alzheimers
Rscript 04a_cycle_detection.R Hypertension Alzheimers
Rscript 03a_semantic_type_analysis.R Hypertension Alzheimers  # Requires DB credentials
Rscript 03b_semantic_distribution.R Hypertension Alzheimers

# Stage 3: Cycle extraction
Rscript 04b_extract_analyze_cycle.R Hypertension Alzheimers
Rscript 04c_visualize_cycles.R Hypertension Alzheimers

# Stage 4: Node removal analysis
Rscript 05_node_removal_impact.R Hypertension Alzheimers

# Stage 5: Post-removal analysis
Rscript 06_post_node_removal_analysis.R Hypertension Alzheimers
```

## 4. Configuration

Parameters are stored in `scripts/config.R`:

- `DB_CONFIG`: Database connection settings (loaded from `.env`)
- `GRAPH_CONFIG`: Graph generation defaults
- `CYCLE_CONFIG`: Cycle detection limits
- `SEMANTIC_CONFIG`: Thresholds for semantic analysis
- `NODE_REMOVAL_CONFIG`: Node removal parameters
- `GENERIC_NODES`: List of generic biomedical terms to remove
- `VIZ_CONFIG`: Plot dimensions and DPI

## 5. Output Files

### Stage 1 (s1_graph)
- `parsed_graph.rds` - igraph object

### Stage 2 (s2_semantic)
- `node_centrality_and_cycles.csv` - Node metrics
- `nodes_with_semantic_types.csv` - Nodes mapped to UMLS semantic types
- `semantic_type_cycle_stats.csv` - Semantic type statistics
- `problematic_semantic_types.csv` - High cycle participation types
- `plots/semantic_type_distribution.png`
- `plots/semantic_type_comparison.png`

### Stage 3 (s3_cycles)
- `node_cycle_participation.csv` - Cycle count per node
- `cycle_summary.csv` - Overall cycle statistics
- `cycle_length_distribution.csv`
- `plots/` - Cycle visualizations
- `subgraphs/` - Saved cycle subgraphs (.rds)

### Stage 4 (s4_node_removal)
- `reduced_graph.rds` - Graph after removing generic nodes
- `node_removal_individual_impact.csv` - Impact of each node removal
- `node_removal_summary.csv`
- `removed_generic_nodes.txt`
- `plots/reduced_graph_full.png`
- `plots/node_removal_impact_comparison.png`

### Stage 5 (s5_post_removal)
- `top_nodes_by_cycles.csv` - Top problematic nodes after removal
- `all_node_cycle_participation.csv`
- `analysis_summary.csv`
- `plots/top_nodes_cycle_participation.png`
- `plots/cycle_subgraph.png`
