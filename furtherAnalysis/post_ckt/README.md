# Post-CKT Analysis Pipeline

This directory contains the refactored analysis pipeline for Causal Knowledge Trace (CKT). The code is designed to be portable and configurable.

## Directory Structure

- `scripts/`: Contains all R analysis scripts, utility functions, and shell scripts.
- `configs/`: Contains YAML configuration files for graph generation.
- `input/`: (Created locally) Stores the generated graph files (`.R` and `.json`). **Not tracked in git.**
- `output/`: (Created locally) Stores analysis results, plots, and cycle data. **Not tracked in git.**

## 1. Setup

Before running any analysis, ensure you have the necessary directories. These are not tracked in git, so you must create them if they don't exist (though scripts will try to create them).

```bash
mkdir -p input
mkdir -p output
```

## 2. Generate Graph Data

The first step is to generate the graph data from the CausalEHR database. Use the `generate_graph.sh` script located in the `scripts/` directory.

You need a YAML configuration file defining your exposure, outcome, and parameters. See `configs/` for examples.

**Usage:**

```bash
./scripts/generate_graph.sh --yaml-config configs/your_config.yaml \
    --db-user <your_username> \
    --db-password <your_password>
```

**Example:**

```bash
./scripts/generate_graph.sh --yaml-config configs/depression_alzheimers.yaml \
    --db-user mpradhan \
    --db-password "Software292$"
```

This script will:
1.  Query the database.
2.  Generate `degree_X.R` and `causal_assertions_X.json` in the `input/` folder.
3.  Automatically rename them to `{Exposure}_{Outcome}_degree_{N}.R` (e.g., `Depression_Alzheimers_degree_2.R`) based on the YAML config.

## 3. Database Configuration

The analysis scripts (specifically `03a_semantic_type_analysis.R`) require database access. For security, credentials are read from environment variables.

You can set these variables in your terminal session before running scripts:

```bash
export CKT_DB_HOST="localhost"
export CKT_DB_PORT="5432"
export CKT_DB_NAME="causalehr_db"
export CKT_DB_USER="your_username"
export CKT_DB_PASSWORD="your_password"
```

## 4. Running the Analysis

You have two options to run the analysis: running the entire pipeline at once or running individual scripts.

### Option A: Run Complete Pipeline (Recommended)

The `run_pipeline.sh` script executes the full suite of analysis scripts in the correct order. It also handles setting default environment variables if they are not already set.

**Syntax:**
```bash
./scripts/run_pipeline.sh <Exposure> <Outcome>
```

**Example:**
```bash
./scripts/run_pipeline.sh Hypertension Alzheimers
```

This will run:
1.  `01_parse_dagitty.R`
2.  `02_basic_analysis.R`
3.  `04a_cycle_detection.R`
4.  `03a_semantic_type_analysis.R` (Requires DB)
5.  `03b_semantic_distribution.R`
6.  `04b_extract_analyze_cycle.R`
7.  `04c_visualize_cycles.R`

### Option B: Run Individual Scripts

You can run individual scripts using `Rscript`. Make sure to provide the **Exposure** and **Outcome** as arguments.

**Important:** If running `03a_semantic_type_analysis.R`, you **must** export the `CKT_DB_*` environment variables first (see Section 3).

```bash
cd scripts

# 1. Parse DAGitty file
Rscript 01_parse_dagitty.R Hypertension Alzheimers

# 2. Basic Analysis
Rscript 02_basic_analysis.R Hypertension Alzheimers

# 3. Cycle Detection
Rscript 04a_cycle_detection.R Hypertension Alzheimers

# 4. Semantic Type Analysis (Ensure DB env vars are set!)
export CKT_DB_USER="mpradhan"
export CKT_DB_PASSWORD="Software292$"
Rscript 03a_semantic_type_analysis.R Hypertension Alzheimers

# 5. Semantic Distribution
Rscript 03b_semantic_distribution.R Hypertension Alzheimers

# 6. Extract Cycles
Rscript 04b_extract_analyze_cycle.R Hypertension Alzheimers

# 7. Visualize Cycles
Rscript 04c_visualize_cycles.R Hypertension Alzheimers
```

## Configuration

Parameters for analysis (like max path length, output image size, etc.) are stored in `scripts/config.R`. You can edit this file to adjust settings without changing the analysis code.

-   `DB_CONFIG`: Database defaults (overridden by env vars).
-   `GRAPH_CONFIG`: Graph generation defaults.
-   `CYCLE_CONFIG`: Cycle detection limits.
-   `SEMANTIC_CONFIG`: Thresholds for semantic analysis.
-   `VIZ_CONFIG`: Plot dimensions and DPI.
